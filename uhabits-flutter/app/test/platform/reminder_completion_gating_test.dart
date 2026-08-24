/// The two halves of `NotificationTray`'s first gate, in the places this port
/// had to move them to.
///
/// `test/journeys/reminder_completion_journey_test.dart` drives both rules from
/// `main()` — a habit checked off in the morning, and a value entered that does
/// not complete one. What is left here is what a journey cannot reach without
/// inventing a user: an AT_MOST habit, a reminder that covers one weekday a
/// week, and the exact order in which the tray talks to the platform.
///
///  * `audit3.a-habit-already-completed-today-still` — gate 1 itself:
///    `if (isCompleted && habit.targetType != NumericalHabitType.AT_MOST)
///    return`, which upstream runs when the alarm fires and this port has to
///    run when the alarm is armed.
///  * `audit3.recording-a-non-completing-entry-silently` — the cancel that
///    takes the day's alarm down with the notification, and the re-arm behind
///    it.
library;

// The classes under test implement core interfaces reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _ScheduledAlarm {
  _ScheduledAlarm(this.spec, this.whenMillis);

  final NotificationSpec spec;
  final int whenMillis;
}

class _FakeAlarmPlugin implements AlarmPlugin {
  final List<_ScheduledAlarm> scheduled = <_ScheduledAlarm>[];
  final List<int> cancelled = <int>[];

  /// Every call, in the order the platform saw it.
  final List<String> order = <String>[];

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async {
    scheduled.add(_ScheduledAlarm(spec, whenMillis));
    order.add('scheduleExact');
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    order.add('cancelAlarm');
  }

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;
}

/// `NotificationManagerCompat`, recording into a shared call log.
class _RecordingPresenter implements NotificationPresenter {
  _RecordingPresenter(this.order);

  final List<String> order;
  final List<int> cancelled = <int>[];

  @override
  Future<void> show(NotificationSpec spec) async => order.add('show');

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    order.add('cancelNotification');
  }
}

/// The narrow scheduler interface the tray is handed, recording into the same
/// log so that "which reached the platform first" is answerable.
class _RecordingScheduler implements ReminderSchedulerApi {
  _RecordingScheduler(this.order);

  final List<String> order;
  int scheduleAllCount = 0;

  @override
  void scheduleAll() {
    scheduleAllCount++;
    order.add('scheduleAll');
  }

  @override
  void snoozeReminder(Habit habit, int minutes) {}

  @override
  void scheduleAtTime(Habit habit, int reminderTime) {}

  @override
  void snoozeUntil(Habit habit, int reminderTime) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const TimeZone gmt = FixedTimeZone(0);

  const NotificationStrings strings = NotificationStrings(
    yes: 'Yes',
    no: 'No',
    enter: 'Enter',
    snooze: 'Later',
    defaultReminderQuestion: 'Have you completed this habit today?',
    channelName: 'Reminder',
  );

  int unixTime(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;

  // 2015-01-26 is a Monday, which is index (daysSinceSunday + 1) % 7 = 2.
  final LocalDate monday = LocalDate.ymd(2015, 1, 26);
  final LocalDate tuesday = LocalDate.ymd(2015, 1, 27);
  final LocalDate wednesday = LocalDate.ymd(2015, 1, 28);
  final LocalDate thursday = LocalDate.ymd(2015, 1, 29);
  final LocalDate nextMonday = LocalDate.ymd(2015, 2, 2);

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late Preferences preferences;
  late _FakeAlarmPlugin plugin;

  setUp(() {
    setToday(monday);
    DateUtils.setFixedTimeZone(gmt);
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    preferences = Preferences(MemoryStorage());
    plugin = _FakeAlarmPlugin();
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  ReminderNotificationBuilder buildBuilder() => ReminderNotificationBuilder(
        preferences: preferences,
        strings: strings,
      );

  /// 06:00 on the Monday: two and a half hours before every reminder below.
  FlutterAlarmScheduler buildScheduler() => FlutterAlarmScheduler(
        plugin: plugin,
        builder: buildBuilder(),
        logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        nowMillis: () => unixTime(2015, 1, 26, 6, 0),
      );

  Habit yesNoHabit({Reminder? reminder}) {
    final habit = fixtures.createEmptyHabit();
    habit.id = 10;
    habit.reminder = reminder ?? Reminder(8, 30, WeekdayList.everyDay);
    return habit;
  }

  Habit numericalHabit(NumericalHabitType targetType, {double target = 10}) {
    final habit = fixtures.createEmptyNumericalHabit(targetType);
    habit.id = 11;
    habit.targetValue = target;
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    return habit;
  }

  void record(Habit habit, LocalDate date, int value) {
    habit.originalEntries.add(Entry(date, value));
    habit.recompute();
  }

  /// Arms [habit]'s reminder for [date] at 08:30 and returns the alarms filed.
  ///
  /// The arguments are the pair `ReminderScheduler.scheduleAtTime` computes:
  /// the alarm instant, and that instant floored to local midnight.
  Future<List<_ScheduledAlarm>> armFor(Habit habit, LocalDate date) async {
    final scheduler = buildScheduler();
    scheduler.scheduleShowReminder(
      unixTime(date.year, date.month, date.day, 8, 30),
      habit,
      date.unixTime,
    );
    await scheduler.settle();
    return plugin.scheduled;
  }

  // -------------------------------------------------------------------------
  // audit3.a-habit-already-completed-today-still — gate 1 at schedule time
  // -------------------------------------------------------------------------

  group('the completion gate', () {
    test('a habit already checked off today is not given today\'s alarm',
        () async {
      final habit = yesNoHabit();
      record(habit, monday, Entry.yesManual);

      final alarms = await armFor(habit, monday);

      expect(alarms.single.whenMillis, unixTime(2015, 1, 27, 8, 30),
          reason: 'audit3.a-habit-already-completed-today-still#1: gate 1 '
              'computes habit.isCompletedToday() and drops the notification '
              'when the habit is done for the day. This port files the '
              'notification with the alarm, so the day gate 1 would reject is '
              'skipped and the alarm lands on the next one.');
      expect(
        ReminderPayload.decode(alarms.single.spec.payload)?.date,
        tuesday,
        reason: 'audit3.a-habit-already-completed-today-still#1: and the '
            'notification carries that day, so the checkmark it writes is '
            'that day\'s',
      );
    });

    test('an entry that does not complete the habit keeps today\'s alarm',
        () async {
      final habit = numericalHabit(NumericalHabitType.atLeast, target: 10);
      record(habit, monday, 3000);

      final alarms = await armFor(habit, monday);

      expect(habit.isCompletedToday(), isFalse,
          reason: 'the precondition: 3 is below the AT_LEAST target of 10');
      expect(alarms.single.whenMillis, unixTime(2015, 1, 26, 8, 30),
          reason: 'audit3.recording-a-non-completing-entry-silently#1: a '
              'numeric value below an AT_LEAST target does not complete the '
              'habit, so the alarm still fires later that day and the reminder '
              'is still shown');
    });

    test('an AT_MOST habit is never "completed", so its reminder always fires',
        () async {
      final habit = numericalHabit(NumericalHabitType.atMost, target: 10);
      record(habit, monday, 3000);

      final alarms = await armFor(habit, monday);

      expect(alarms.single.whenMillis, unixTime(2015, 1, 26, 8, 30),
          reason: 'audit3.a-habit-already-completed-today-still#1: gate 1 is '
              '"isCompleted && habit.targetType != NumericalHabitType.AT_MOST" '
              '— an AT_MOST habit is never dropped by it '
              '(notifications.show-gating#11), whatever was entered today');
    });

    test('tomorrow\'s alarm is not judged by today\'s entry', () async {
      final habit = yesNoHabit();
      record(habit, monday, Entry.yesManual);

      // What ReminderScheduler files once today's 08:30 has passed.
      final alarms = await armFor(habit, tuesday);

      expect(alarms.single.whenMillis, unixTime(2015, 1, 27, 8, 30),
          reason: 'audit3.a-habit-already-completed-today-still#1: gate 1 reads '
              'the computed entry for the day the alarm names. A daily habit '
              'ticked on Monday builds Interval(Mon, Mon, Mon), so Tuesday is '
              'UNKNOWN and upstream — asking the question when the alarm '
              'fires, by which time tomorrow is today — shows the reminder');
    });

    test('a habit its own frequency has already completed skips those days',
        () async {
      final habit = yesNoHabit();
      habit.frequency = Frequency(1, 3);
      record(habit, monday, Entry.yesManual);

      // buildIntervals: Interval(Mon, Mon, Mon + 3 - 1), and
      // buildEntriesFromInterval fills every day of it — future days included.
      expect(habit.computedEntries.get(tuesday).value, Entry.yesAuto,
          reason: 'the precondition');
      expect(habit.computedEntries.get(wednesday).value, Entry.yesAuto,
          reason: 'the precondition');
      expect(habit.computedEntries.get(thursday).value, Entry.unknown,
          reason: 'the precondition: the interval ends on Wednesday');

      final alarms = await armFor(habit, monday);

      expect(alarms.single.whenMillis, unixTime(2015, 1, 29, 8, 30),
          reason: 'audit18.the-completion-gate-must-judge-the-alarms-own-day#1: '
              'upstream gate 1 runs at fire time and asks '
              'isCompletedToday(), which reads computedEntries.get(getToday()) '
              '— on Tuesday and on Wednesday that is YES_AUTO, so the Android '
              'app posts nothing on either day and the "Every 3 days" habit is '
              'next reminded on Thursday. Here the alarm IS the notification, '
              'so those two days have to be skipped before it is filed');
      expect(
        ReminderPayload.decode(alarms.single.spec.payload)?.date,
        thursday,
        reason: 'audit18.the-completion-gate-must-judge-the-alarms-own-day#1: '
            'and the notification carries the day it will actually be shown on',
      );
    });

    test('a "3 times per week" target met by Wednesday skips the rest of the '
        'week', () async {
      setToday(wednesday);
      final habit = yesNoHabit();
      habit.frequency = Frequency.threeTimesPerWeek;
      record(habit, monday, Entry.yesManual);
      record(habit, tuesday, Entry.yesManual);
      record(habit, wednesday, Entry.yesManual);

      // Interval(Mon, Wed, Mon + 7 - 1): Thursday through Sunday are YES_AUTO.
      expect(habit.computedEntries.get(LocalDate.ymd(2015, 2, 1)).value,
          Entry.yesAuto,
          reason: 'the precondition: the interval runs to Sunday');
      expect(habit.computedEntries.get(nextMonday).value, Entry.unknown,
          reason: 'the precondition: and no further');

      final alarms = await armFor(habit, wednesday);

      expect(alarms.single.whenMillis, unixTime(2015, 2, 2, 8, 30),
          reason: 'audit18.the-completion-gate-must-judge-the-alarms-own-day#1: '
              'the week\'s target is met, so every remaining day of it is '
              'YES_AUTO and upstream\'s gate 1 drops the notification on each '
              'of them. The next reminder is the following Monday');
    });

    test('a weekly reminder completed on its own day moves a week, not off the '
        'calendar', () async {
      final mondaysOnly = WeekdayList.fromArray(
        <bool>[false, false, true, false, false, false, false],
      );
      final habit = yesNoHabit(reminder: Reminder(8, 30, mondaysOnly));
      record(habit, monday, Entry.yesManual);

      final alarms = await armFor(habit, monday);

      expect(alarms, hasLength(1),
          reason: 'audit3.a-habit-already-completed-today-still#1: the habit '
              'still has a reminder — only today\'s firing is suppressed — so '
              'the scan has to look a full week past the day gate 1 rejected, '
              'not six days');
      expect(alarms.single.whenMillis, unixTime(2015, 2, 2, 8, 30),
          reason: 'notifications.show-gating#6 and #7: the next Monday');
      expect(
        ReminderPayload.decode(alarms.single.spec.payload)?.date,
        nextMonday,
      );
      expect(plugin.cancelled, isEmpty,
          reason: 'audit3.a-habit-already-completed-today-still#1: this is not '
              'the "not supposed to run on any day" case, so nothing is '
              'disarmed');
    });
  });

  // -------------------------------------------------------------------------
  // audit3.recording-a-non-completing-entry-silently — the tray's re-arm
  // -------------------------------------------------------------------------
  // audit19.a-long-frequency-must-not-cancel-the-reminder
  // -------------------------------------------------------------------------

  group('audit19.a-long-frequency-must-not-cancel-the-reminder', () {
    const String rule =
        'audit19.a-long-frequency-must-not-cancel-the-reminder#1 — gate 1 '
        'suppresses one day at a time upstream, and the alarm chain re-arms '
        'itself every firing, so however long the auto-completed run is the '
        'reminder always comes back at the end of it. A port that decides at '
        'schedule time has to look as far as that run can actually reach.';

    /// "Every 60 days" — the picker takes three digits, so up to 999, and an
    /// imported database can carry anything.
    Future<List<_ScheduledAlarm>> armWithFrequency(int denominator) async {
      final habit = yesNoHabit();
      habit.frequency = Frequency(1, denominator);
      habitList.add(habit);
      record(habit, monday, Entry.yesManual);
      return armFor(habit, monday);
    }

    test('a 60-day habit still has a reminder after it is ticked off',
        () async {
      final alarms = await armWithFrequency(60);

      expect(alarms, isNotEmpty,
          reason: '$rule Scanning 38 days and giving up cancels the alarm '
              'outright: the user who set "Every 60 days: replace the filter" '
              'is never reminded again, and nothing in the app says so.');
      expect(plugin.cancelled, isEmpty, reason: rule);
    });

    test('the alarm lands on the first day the frequency leaves uncovered',
        () async {
      final alarms = await armWithFrequency(60);

      // buildIntervals fills days 0..59 with YES_AUTO from the Monday tick, so
      // the first day gate 1 lets through is 60 days later.
      final LocalDate expected = LocalDate(monday.daysSince2000 + 60);
      expect(
        alarms.single.whenMillis,
        unixTime(expected.year, expected.month, expected.day, 8, 30),
        reason: '$rule …and it is that day, not merely some day.',
      );
    });

    test('a short frequency is unaffected', () async {
      final alarms = await armWithFrequency(3);
      final LocalDate expected = LocalDate(monday.daysSince2000 + 3);
      expect(
        alarms.single.whenMillis,
        unixTime(expected.year, expected.month, expected.day, 8, 30),
        reason: '$rule The control: the common case does not move.',
      );
    });
  });

  // -------------------------------------------------------------------------

  group('cancelling a reminder', () {
    late List<String> order;
    late _RecordingPresenter presenter;
    late _RecordingScheduler scheduler;
    late FlutterNotificationTray tray;

    setUp(() {
      order = <String>[];
      presenter = _RecordingPresenter(order);
      scheduler = _RecordingScheduler(order);
      tray = FlutterNotificationTray(
        presenter: presenter,
        builder: buildBuilder(),
        scheduler: scheduler,
      );
    });

    test('re-arms the day\'s alarm, because the cancel disarmed it', () async {
      tray.removeNotification(10);
      await tray.settle();

      expect(presenter.cancelled, <int>[10],
          reason: 'notifications.id-and-registry#3: cancel(habit) still calls '
              'NotificationManagerCompat.cancel(getNotificationId(habit))');
      expect(scheduler.scheduleAllCount, 1,
          reason: 'audit3.recording-a-non-completing-entry-silently#1: '
              'upstream the AlarmManager alarm is untouched by the cancel, so '
              'a reminder the user has not completed still fires later that '
              'day. Here the alarm IS the notification that cancel just '
              'removed, so it has to be armed again — and gate 1, in '
              'FlutterAlarmScheduler, is what then decides whether it lands '
              'today or on the next day the habit is not already done for.');
    });

    test('the platform sees the cancel before the alarm that replaces it',
        () async {
      tray.removeNotification(10);
      await tray.settle();

      expect(order, <String>['cancelNotification', 'scheduleAll'],
          reason: 'audit3.recording-a-non-completing-entry-silently#1: the '
              'plugin cancels and schedules by the same id, so a re-arm that '
              'reached it first would be the alarm that disappeared. The '
              're-arm is queued behind the cancel for that reason — and it is '
              'also why ReminderController.onSnoozeDelayPicked, which snoozes '
              'first and cancels second, still ends up with its snoozed alarm: '
              'scheduleAll re-reads the snooze from WidgetPreferences.');
    });

    test('a tray with no scheduler behind it still cancels', () async {
      final lonely = FlutterNotificationTray(
        presenter: presenter,
        builder: buildBuilder(),
      );

      lonely.removeNotification(10);
      await lonely.settle();

      expect(presenter.cancelled, <int>[10],
          reason: 'the scheduler is optional: a host without the alarm half of '
              'the pipeline is still a working notification tray');
      expect(scheduler.scheduleAllCount, 0);
    });
  });
}
