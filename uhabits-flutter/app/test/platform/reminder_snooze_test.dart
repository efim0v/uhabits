/// The two branches of the snooze picker, driven end to end over the real
/// scheduler, the real tray and one fake plugin.
///
/// `ReminderController.onSnoozeDelayPicked` and `onSnoozeTimePicked` both arm
/// an alarm and then cancel the notification, in that order. On Android the
/// cancel cannot reach the alarm — `AndroidNotificationTray.removeNotification`
/// is `NotificationManagerCompat.cancel(id)` and nothing else, and the alarm is
/// a separate object under an `AlarmManager` `PendingIntent`.
///
/// In this port the alarm *is* the notification: `FlutterAlarmScheduler` files
/// it under `reminderNotificationId(habit)`, the same id the core tray cancels,
/// and `flutter_local_notifications`' `cancel` drops the pending scheduled
/// notification as well as the posted one. That is why
/// `FlutterNotificationTray.removeNotification` re-arms
/// (`audit3.recording-a-non-completing-entry-silently#1`). Whatever the two
/// snooze branches arm therefore has to survive a cancel *and* the re-arm
/// behind it, which is what these tests assert against the end state of the
/// platform rather than against the calls made to it.
library;

// The classes under test implement core interfaces reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// One `flutter_local_notifications` instance, which is what the app really
/// has: the alarm half and the shade half are the same plugin, keyed by the
/// same id.
///
/// `cancel(id)` therefore drops the *pending* scheduled notification too, the
/// way `FlutterLocalNotificationsPlugin.cancel` does. Splitting the two into
/// independent doubles is what hid this defect: it made the cancel look
/// harmless to an alarm the same call really destroys.
class _FakePlugin
    implements AlarmPlugin, NotificationPresenter, PendingAlarmQuery {
  /// Notification id -> the instant the OS will post it at.
  final Map<int, int> pending = <int, int>{};

  /// Notification id -> the notification currently in the shade.
  final Map<int, NotificationSpec> posted = <int, NotificationSpec>{};

  final List<String> order = <String>[];

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async {
    pending[spec.id] = whenMillis;
    order.add('scheduleExact(${spec.id}@$whenMillis)');
  }

  @override
  Future<void> show(NotificationSpec spec) async {
    posted[spec.id] = spec;
    order.add('show(${spec.id})');
  }

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
    posted.remove(id);
    order.add('cancel($id)');
  }

  @override
  Future<Set<int>?> pendingAlarmIds() async => pending.keys.toSet();

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;
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

  // 2015-01-26 is a Monday.
  final LocalDate monday = LocalDate.ymd(2015, 1, 26);

  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late WidgetPreferences widgetPreferences;
  late _FakePlugin plugin;
  late FlutterAlarmScheduler alarms;
  late FlutterReminderScheduler scheduler;
  late FlutterNotificationTray flutterTray;
  late ReminderController controller;

  setUp(() {
    setToday(monday);
    DateUtils.setFixedTimeZone(gmt);
    // 09:00, half an hour after every reminder below has already gone off.
    DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 9, 0));

    final modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    final storage = MemoryStorage();
    final preferences = Preferences(storage);
    widgetPreferences = WidgetPreferences(storage);
    final taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    final commandRunner = CommandRunner(taskRunner);
    final builder = ReminderNotificationBuilder(
      preferences: preferences,
      strings: strings,
    );
    plugin = _FakePlugin();
    alarms = FlutterAlarmScheduler(
      plugin: plugin,
      builder: builder,
      logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
    );
    scheduler = FlutterReminderScheduler(
      commandRunner: commandRunner,
      habitList: habitList,
      alarms: alarms,
      widgetPreferences: widgetPreferences,
    );
    flutterTray = FlutterNotificationTray(
      presenter: plugin,
      builder: builder,
      logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
      scheduler: scheduler,
    );
    controller = ReminderController(
      scheduler,
      NotificationTray(taskRunner, commandRunner, preferences, flutterTray),
      preferences,
    );
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  /// Drains both queues until neither feeds the other any more: the tray's
  /// cancel enqueues onto the scheduler's queue, and the scheduler's
  /// `withdrawObsoleteAlarms` reads the platform back.
  Future<void> settleAll() async {
    for (var i = 0; i < 6; i++) {
      await flutterTray.settle();
      await alarms.settle();
    }
  }

  Habit habitWithReminder() {
    final habit = fixtures.createEmptyHabit();
    habit.id = 10;
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    habitList.add(habit);
    return habit;
  }

  group('audit13.a-snooze-overtaken-by-completion-moves', () {
    const String rule =
        'audit13.a-snooze-overtaken-by-completion-moves#1 — a snoozed instant '
        'belongs to the day it names. Any later day the alarm is pushed to has '
        "to carry the habit's own reminder time, not the snoozed one.";

    test('the day after an overtaken snooze keeps the habit\'s reminder time',
        () async {
      // 08:30 daily. The user snoozed at 08:30 for an hour, so the alarm is
      // live at 09:30 today; then they actually did the habit and ticked it
      // off. The tray cancels on the entry and re-arms behind it
      // (`audit3.recording-a-non-completing-entry-silently#1`), which re-enters
      // schedule() while the snooze is still in the future — and gate 1 now
      // answers "already completed", so today is skipped.
      final habit = habitWithReminder();
      widgetPreferences.setSnoozeTime(habit.id!, unixTime(2015, 1, 26, 9, 30));
      habit.originalEntries.add(Entry(monday, Entry.yesManual));
      habit.recompute();

      scheduler.scheduleAll();
      await settleAll();

      final int id = plugin.pending.keys.single;
      expect(plugin.pending[id], unixTime(2015, 1, 27, 8, 30),
          reason: '$rule Tuesday at 08:30, not Tuesday at 09:30.');
    });

    test('a snooze that lands on an uncovered weekday does not move the next',
        () async {
      // Mon-Fri at 20:00. On Friday the user snoozes four hours, to Saturday
      // 00:00 — a day the reminder does not cover — so the alarm has to walk
      // forward to Monday. Monday's reminder is 20:00.
      final habit = fixtures.createEmptyHabit();
      habit.id = 11;
      // The scheduler indexes days from Saturday: (daysSinceSunday + 1) % 7,
      // so Monday..Friday are bits 2..6.
      habit.reminder = Reminder(20, 0, WeekdayList(0x7C));
      habitList.add(habit);

      final LocalDate friday = LocalDate.ymd(2015, 1, 30);
      setToday(friday);
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 30, 23, 0));
      widgetPreferences.setSnoozeTime(habit.id!, unixTime(2015, 1, 31, 0, 0));
      habit.originalEntries.add(Entry(friday, Entry.yesManual));
      habit.recompute();

      scheduler.scheduleAll();
      await settleAll();

      final int id = plugin.pending.keys.single;
      expect(plugin.pending[id], unixTime(2015, 2, 2, 20, 0),
          reason: '$rule Monday at 20:00, not Monday at midnight.');
    });

    test('an un-overtaken snooze still fires at the snoozed instant', () async {
      // The control: nothing was completed, so the snoozed day is the day the
      // alarm belongs to and the snoozed time is exactly right.
      final habit = habitWithReminder();
      widgetPreferences.setSnoozeTime(habit.id!, unixTime(2015, 1, 26, 9, 30));

      scheduler.scheduleAll();
      await settleAll();

      final int id = plugin.pending.keys.single;
      expect(plugin.pending[id], unixTime(2015, 1, 26, 9, 30), reason: rule);
    });
  });

  group('snoozing until a custom wall-clock time', () {
    test('leaves the platform holding an alarm at the time that was picked',
        () async {
      final habit = habitWithReminder();

      controller.onSnoozeTimePicked(habit, 15, 0);
      await settleAll();

      expect(
        plugin.pending[reminderNotificationId(habit)],
        unixTime(2015, 1, 26, 15, 0),
        reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
            'ReminderController.onSnoozeTimePicked arms the alarm and then '
            'cancels the notification. Upstream the cancel is '
            'NotificationManagerCompat.cancel(id) and cannot touch the '
            'AlarmManager alarm, so 15:00 is what the phone is left holding. '
            'Here the cancel disarms it and the re-arm behind the cancel '
            're-files the habit\'s ordinary reminder under the same id, so the '
            'whole "Later -> Custom..." branch is inert.',
      );
    });

    test('and not the ordinary reminder of the following day', () async {
      final habit = habitWithReminder();

      controller.onSnoozeTimePicked(habit, 15, 0);
      await settleAll();

      expect(
        plugin.pending[reminderNotificationId(habit)],
        isNot(unixTime(2015, 1, 27, 8, 30)),
        reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
            'tomorrow 08:30 is what scheduleAll() re-files when it cannot see '
            'the picked time. The user gets no reminder at 15:00 and none for '
            'the rest of the day, and nothing tells them their choice was '
            'discarded.',
      );
    });

    test('a time already past today is armed for tomorrow, not dropped',
        () async {
      final habit = habitWithReminder();

      controller.onSnoozeTimePicked(habit, 7, 0);
      await settleAll();

      expect(
        plugin.pending[reminderNotificationId(habit)],
        unixTime(2015, 1, 27, 7, 0),
        reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
            'DateUtils.getUpcomingTimeInMillis rolls an hour:minute that has '
            'already passed onto the next day, and that instant has to survive '
            'the cancel like any other',
      );
    });

    test('the notification itself is gone from the shade', () async {
      final habit = habitWithReminder();
      flutterTray.showNotification(habit, reminderNotificationId(habit),
          monday, unixTime(2015, 1, 26, 8, 30));
      await settleAll();
      expect(plugin.posted, isNotEmpty, reason: 'the precondition');

      controller.onSnoozeTimePicked(habit, 15, 0);
      await settleAll();

      expect(
        plugin.posted[reminderNotificationId(habit)],
        isNull,
        reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
            'notificationTray.cancel(habit) is still the second half of '
            'onSnoozeTimePicked — the reminder leaves the shade, it is only '
            'the alarm that must not leave with it',
      );
    });
  });

  group('snoozing by one of the fixed delays', () {
    test('leaves the platform holding an alarm at the snoozed instant',
        () async {
      final habit = habitWithReminder();

      controller.onSnoozeDelayPicked(habit, 60);
      await settleAll();

      expect(
        plugin.pending[reminderNotificationId(habit)],
        unixTime(2015, 1, 26, 10, 0),
        reason: 'reminders.snooze-by-delay#3: this branch already survives the '
            'cancel, because ReminderScheduler.snoozeReminder writes the '
            'instant to WidgetPreferences and the re-arm re-reads it. It is '
            'the control for the custom-time branch above.',
      );
    });
  });
}
