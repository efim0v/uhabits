/// The `ReminderController` entry points that belong to the reminder
/// scheduling slices rather than to the notification tray: booting, snoozing
/// by a fixed delay, and snoozing until a custom wall-clock time.
///
/// Ported from
/// uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt,
/// with the scenarios of
/// uhabits-android/src/test/java/org/isoron/uhabits/receivers/ReminderControllerTest.kt.
///
/// The Kotlin test builds the controller over three mokkery mocks and verifies
/// the calls; the two doubles below are the same idea written by hand, with a
/// shared `order` list so the *sequence* of calls — which is what two of these
/// rules are entirely about — can be asserted and not just the counts.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

const TimeZone gmt = FixedTimeZone(0);

int unixTime(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;

/// `mock<ReminderScheduler>()`: records every call, runs none of them.
class _MockScheduler implements ReminderSchedulerApi {
  _MockScheduler(this.order);

  final List<String> order;
  int scheduleAllCount = 0;
  final List<({Habit habit, int minutes})> snoozed =
      <({Habit habit, int minutes})>[];
  final List<({Habit habit, int time})> scheduledAtTime =
      <({Habit habit, int time})>[];
  final List<({Habit habit, int time})> snoozedUntil =
      <({Habit habit, int time})>[];

  @override
  void scheduleAll() {
    scheduleAllCount++;
    order.add('scheduleAll');
  }

  @override
  void snoozeReminder(Habit habit, int minutes) {
    snoozed.add((habit: habit, minutes: minutes));
    order.add('snoozeReminder');
  }

  @override
  void scheduleAtTime(Habit habit, int reminderTime) {
    scheduledAtTime.add((habit: habit, time: reminderTime));
    order.add('scheduleAtTime');
  }

  @override
  void snoozeUntil(Habit habit, int reminderTime) {
    snoozedUntil.add((habit: habit, time: reminderTime));
    order.add('snoozeUntil');
  }
}

/// `mock<NotificationTray>()`.
class _MockTray extends NotificationTray {
  _MockTray(
    super.taskRunner,
    super.commandRunner,
    super.preferences,
    super.systemTray,
    this.order,
  );

  final List<String> order;
  final List<Habit> cancelCalls = <Habit>[];
  final List<Habit> showCalls = <Habit>[];

  @override
  void cancel(Habit habit) {
    cancelCalls.add(habit);
    order.add('cancel');
  }

  @override
  void show(Habit habit, LocalDate date, int reminderTime) {
    showCalls.add(habit);
    order.add('show');
  }
}

class _NullSystemTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}

/// The `SystemScheduler` half is irrelevant to these rules: everything under
/// test happens before an alarm reaches the platform.
class _NullSystemScheduler implements SystemScheduler {
  final List<int> reminderTimes = <int>[];

  @override
  void log(String componentName, String msg) {}

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) {
    reminderTimes.add(reminderTime);
    return SchedulerResult.ok;
  }

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => null;
}

void main() {
  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late MemoryStorage storage;
  late Preferences preferences;
  late CoroutineTaskRunner taskRunner;
  late CommandRunner commandRunner;
  late List<String> order;
  late _MockScheduler scheduler;
  late _MockTray tray;
  late ReminderController controller;

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    setToday(LocalDate.ymd(2015, 1, 26));
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    storage = MemoryStorage();
    preferences = Preferences(storage);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = CommandRunner(taskRunner);
    order = <String>[];
    scheduler = _MockScheduler(order);
    tray = _MockTray(
      taskRunner,
      commandRunner,
      preferences,
      _NullSystemTray(),
      order,
    );
    controller = ReminderController(scheduler, tray, preferences);
  });

  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
  });

  Habit habitWithReminder() {
    final habit = fixtures.createEmptyHabit();
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    habitList.add(habit);
    return habit;
  }

  // -----------------------------------------------------------------------
  // reminders.boot-reschedule
  // -----------------------------------------------------------------------

  group('onBootCompleted', () {
    test('ReminderControllerTest.testOnBootCompleted', () {
      controller.onBootCompleted();

      expect(scheduler.scheduleAllCount, 1,
          reason: 'reminders.boot-reschedule#5: verified by '
              'ReminderControllerTest.testOnBootCompleted, which asserts '
              'verify { reminderScheduler.scheduleAll() }');
      expect(order, <String>['scheduleAll'],
          reason: 'reminders.boot-reschedule#3: '
              'ReminderController.onBootCompleted() does exactly one thing: '
              'reminderScheduler.scheduleAll()');
      expect(tray.cancelCalls, isEmpty,
          reason: 'reminders.boot-reschedule#3: the notification tray is not '
              'touched');
      expect(tray.showCalls, isEmpty,
          reason: 'reminders.boot-reschedule#3: nothing is shown on boot');
    });

    test('the habit does not matter — nothing is passed in', () {
      habitWithReminder();
      controller.onBootCompleted();
      controller.onBootCompleted();

      expect(scheduler.scheduleAllCount, 2,
          reason: 'reminders.boot-reschedule#3: onBootCompleted takes no '
              'argument and re-arms every habit each time it is called');
    });

    test('a snooze still in the future survives a reboot, an expired one does '
        'not', () {
      final widgetPreferences = WidgetPreferences(storage);
      final sys = _NullSystemScheduler();
      final real = ReminderScheduler(
        commandRunner,
        habitList,
        sys,
        widgetPreferences,
      );
      final habit = habitWithReminder();
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 0));
      final int live = unixTime(2015, 1, 26, 7, 0);
      widgetPreferences.setSnoozeTime(habit.id!, live);

      // The reboot: nothing in memory survives it, so the only thing the
      // scheduler can read is the preference.
      ReminderController(real, tray, preferences).onBootCompleted();

      expect(sys.reminderTimes, <int>[live],
          reason: 'reminders.boot-reschedule#4: because snooze times are '
              'persisted, a habit snoozed before the reboot keeps its snooze '
              'after the reboot as long as the snoozed-until instant is still '
              'in the future');

      sys.reminderTimes.clear();
      widgetPreferences.setSnoozeTime(habit.id!, unixTime(2015, 1, 26, 5, 0));
      ReminderController(real, tray, preferences).onBootCompleted();

      expect(sys.reminderTimes, <int>[unixTime(2015, 1, 26, 8, 30)],
          reason: 'reminders.boot-reschedule#4: a snoozed-until instant that '
              'is already in the past is discarded and the habit falls back '
              'to its regular reminder');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.snooze-by-delay
  // -----------------------------------------------------------------------

  group('onSnoozeDelayPicked', () {
    test('snoozes first and cancels second', () {
      final habit = habitWithReminder();

      controller.onSnoozeDelayPicked(habit, 60);

      expect(order, <String>['snoozeReminder', 'cancel'],
          reason: 'reminders.snooze-by-delay#3: '
              'ReminderController.onSnoozeDelayPicked(habit, delayInMinutes) '
              'calls reminderScheduler.snoozeReminder(habit, '
              'delayInMinutes.toLong()) and then notificationTray.cancel('
              'habit), in that order');
      expect(scheduler.snoozed.single.habit, same(habit),
          reason: 'reminders.snooze-by-delay#3: the habit that was picked for '
              'is the habit that is snoozed');
      expect(scheduler.snoozed.single.minutes, 60,
          reason: 'reminders.snooze-by-delay#3: delayInMinutes is passed '
              'straight through, widened from Int to Long');
      expect(tray.cancelCalls.single, same(habit),
          reason: 'reminders.snooze-by-delay#3: and the same habit is the one '
              'whose notification is cancelled');
      expect(scheduler.scheduleAllCount, 0,
          reason: 'reminders.snooze-by-delay#3: scheduleAll is not part of '
              'this path — snoozeReminder reschedules the one habit itself');
    });

    test('every delay of the picker reaches the scheduler unchanged', () {
      final habit = habitWithReminder();

      for (final minutes in <int>[15, 30, 60, 120, 240, 480, 1440]) {
        controller.onSnoozeDelayPicked(habit, minutes);
      }

      expect(
        scheduler.snoozed.map((entry) => entry.minutes).toList(),
        <int>[15, 30, 60, 120, 240, 480, 1440],
        reason: 'reminders.snooze-by-delay#3: onSnoozeDelayPicked does no '
            'arithmetic of its own; snoozeReminder is what turns minutes into '
            'an instant',
      );
      expect(tray.cancelCalls.length, 7,
          reason: 'reminders.snooze-by-delay#3: each pick cancels exactly one '
              'notification');
    });

    test('over the real scheduler the snooze is stored before the cancel', () {
      final widgetPreferences = WidgetPreferences(storage);
      final real = ReminderScheduler(
        commandRunner,
        habitList,
        _NullSystemScheduler(),
        widgetPreferences,
      );
      final habit = habitWithReminder();
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 0));

      ReminderController(real, tray, preferences)
          .onSnoozeDelayPicked(habit, 15);

      expect(widgetPreferences.getSnoozeTime(habit.id!),
          unixTime(2015, 1, 26, 6, 15),
          reason: 'reminders.snooze-by-delay#3: the delay picked reaches '
              'ReminderScheduler.snoozeReminder, which is what writes '
              'now + minutes * 60 * 1000');
      expect(order, <String>['cancel'],
          reason: 'reminders.snooze-by-delay#3: and the tray is cancelled '
              'after it, not before');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.snooze-custom-time, the other half of the same picker
  // -----------------------------------------------------------------------

  group('onSnoozeTimePicked', () {
    test('snoozes until the upcoming wall-clock time and then cancels', () {
      final habit = habitWithReminder();
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 0));

      controller.onSnoozeTimePicked(habit, 9, 45);

      expect(scheduler.snoozedUntil.single.time, unixTime(2015, 1, 26, 9, 45),
          reason: 'reminders.snooze-custom-time#1: onSnoozeTimePicked(habit, '
              'hour, minute) computes time = '
              'DateUtils.getUpcomingTimeInMillis(hour, minute) and arms the '
              "habit's alarm there. "
              'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
              'Kotlin arms it with scheduleAtTime, which records nothing; this '
              'port has to record it, because the cancel on the next line '
              'destroys an unrecorded one-off alarm.');
      expect(order, <String>['snoozeUntil', 'cancel'],
          reason: 'reminders.snooze-custom-time#1: the alarm is armed first '
              'and notificationTray.cancel(habit) second, exactly as upstream');
      expect(scheduler.scheduledAtTime, isEmpty,
          reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
              'the un-recorded path is no longer reachable from the picker');
    });

    test('a time already past today lands tomorrow', () {
      final habit = habitWithReminder();
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 12, 0));

      controller.onSnoozeTimePicked(habit, 9, 45);

      expect(scheduler.snoozedUntil.single.time, unixTime(2015, 1, 27, 9, 45),
          reason: 'reminders.snooze-custom-time#3: if the chosen hour:minute '
              'is still ahead today the alarm lands today; otherwise it lands '
              'tomorrow');
    });

    test('the picked instant is recorded, so a re-arm cannot overwrite it',
        () {
      final widgetPreferences = WidgetPreferences(storage);
      final sys = _NullSystemScheduler();
      final real = ReminderScheduler(
        commandRunner,
        habitList,
        sys,
        widgetPreferences,
      );
      final habit = habitWithReminder();
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 0));

      ReminderController(real, tray, preferences)
          .onSnoozeTimePicked(habit, 9, 45);

      expect(widgetPreferences.getSnoozeTime(habit.id!),
          unixTime(2015, 1, 26, 9, 45),
          reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
              'upstream nothing is written (reminders.snooze-custom-time#2) '
              'because AndroidNotificationTray.removeNotification is '
              'NotificationManagerCompat.cancel(id) and cannot reach an '
              'AlarmManager alarm. This port files the alarm and the '
              'notification under one id and re-arms every habit on every '
              'notification cancel '
              '(audit3.recording-a-non-completing-entry-silently#1), so the '
              'cancel that closes onSnoozeTimePicked would wipe an unrecorded '
              'instant within the same user action.');
      expect(sys.reminderTimes, <int>[unixTime(2015, 1, 26, 9, 45)],
          reason: 'reminders.snooze-custom-time#1: the one-off alarm is armed');

      sys.reminderTimes.clear();
      real.scheduleAll();

      expect(sys.reminderTimes, <int>[unixTime(2015, 1, 26, 9, 45)],
          reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
              'and it is what every later scheduleAll() re-arms, the way a '
              'snooze by delay already is. This is the deliberate deviation: '
              "upstream the alarm would be replaced by the habit's regular "
              '08:30 reminder here.');
    });

    test('the recorded instant expires the way a delayed snooze does', () {
      final widgetPreferences = WidgetPreferences(storage);
      final sys = _NullSystemScheduler();
      final real = ReminderScheduler(
        commandRunner,
        habitList,
        sys,
        widgetPreferences,
      );
      final habit = habitWithReminder();
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 0));

      ReminderController(real, tray, preferences)
          .onSnoozeTimePicked(habit, 9, 45);

      // The picked instant has now passed: this is the moment the reminder
      // has just fired and ReminderController.onShowReminder re-arms.
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 10, 0));
      sys.reminderTimes.clear();
      real.scheduleAll();

      expect(sys.reminderTimes, <int>[unixTime(2015, 1, 27, 8, 30)],
          reason: 'audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1: '
              'the instant is stored in the same WidgetPreferences slot a '
              'delayed snooze uses, so ReminderScheduler.schedule discards it '
              'once it is in the past and the habit falls back to its regular '
              'reminder. Nothing accumulates.');
      expect(widgetPreferences.getSnoozeTime(habit.id!), 0,
          reason: 'reminders.snooze-by-delay#1: an expired snooze is removed, '
              'not merely ignored');
    });
  });
}
