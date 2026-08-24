/// What happens to a reminder between the moment its alarm is armed and the
/// moment it stops being wanted.
///
/// Both rules below are fire-time behaviour upstream, and this port has no
/// fire-time hook: `zonedSchedule` hands the OS a finished notification and no
/// Dart runs when it is posted. Everything `ReminderReceiver` and
/// `NotificationTray.ShowNotificationTask` would have done in the app process
/// therefore has to happen either when the alarm is armed or the next time the
/// app is in the foreground.
///
///  * `audit9.fired-reminder-enters-the-registry` — `ReminderController
///    .onShowReminder` runs `NotificationTray.show`, whose first act is
///    `active[habit] = data`. Everything that reads that registry — `reshow`
///    for a sticky dismissal, `reshowAll` for the sticky preference, and the
///    port's own swipe detector — depends on the entry being there.
///  * `audit9.obsolete-reminder-alarm-withdrawn` — gates 2 and 3 of
///    `ShowNotificationTask.onPostExecute`: an alarm left over from a reminder
///    the user has removed, or from a habit they have archived, fires into a
///    task that re-reads the habit and posts nothing.
library;

// The classes under test implement core interfaces reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/logging.dart';
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

/// `NotificationManagerCompat` plus the shade it posts into.
///
/// [live] is what `getActiveNotifications()` answers — the set the OS would
/// report, which the test drives by hand because the only thing that ever puts
/// a scheduled reminder there is the OS itself.
class _FakePresenter implements NotificationPresenter, ActiveNotificationQuery {
  final List<NotificationSpec> shown = <NotificationSpec>[];
  final List<int> cancelled = <int>[];

  /// Null reproduces a host that cannot see its own shade.
  Set<int>? live = <int>{};

  @override
  Future<void> show(NotificationSpec spec) async {
    shown.add(spec);
    live?.add(spec.id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    live?.remove(id);
  }

  @override
  Future<Set<int>?> activeNotificationIds() async {
    final Set<int>? current = live;
    return current == null ? null : Set<int>.of(current);
  }
}

class _ScheduledAlarm {
  _ScheduledAlarm(this.spec, this.whenMillis);

  final NotificationSpec spec;
  final int whenMillis;
}

/// `AlarmManager`, with the pending-alarm query the plugin exposes as
/// `pendingNotificationRequests()`.
class _FakeAlarmPlugin implements AlarmPlugin, PendingAlarmQuery {
  final List<_ScheduledAlarm> scheduled = <_ScheduledAlarm>[];
  final List<int> cancelled = <int>[];

  /// The alarms the platform still holds, keyed by notification id.
  final Set<int> pending = <int>{};

  @override
  Future<Set<int>?> pendingAlarmIds() async => Set<int>.of(pending);

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async {
    scheduled.add(_ScheduledAlarm(spec, whenMillis));
    pending.add(spec.id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }

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

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late Preferences preferences;
  late MemoryStorage storage;
  late Logging logging;
  late _FakePresenter presenter;
  late _FakeAlarmPlugin plugin;

  setUp(() {
    setToday(monday);
    DateUtils.setFixedTimeZone(gmt);
    // 09:00 on the Monday: half an hour after the 08:30 reminder fired.
    DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 9, 0));
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    storage = MemoryStorage();
    preferences = Preferences(storage);
    logging = StandardLogging(out: StringBuffer(), err: StringBuffer());
    presenter = _FakePresenter();
    plugin = _FakeAlarmPlugin();
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  ReminderNotificationBuilder buildBuilder() => ReminderNotificationBuilder(
        preferences: preferences,
        strings: () => strings,
      );

  Habit habitWithReminder({int id = 10}) {
    final habit = fixtures.createEmptyHabit();
    habit.id = id;
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    habitList.add(habit);
    return habit;
  }

  // -------------------------------------------------------------------------
  // audit9.fired-reminder-enters-the-registry
  // -------------------------------------------------------------------------

  group('a reminder the OS posted while no Dart was running', () {
    late FlutterNotificationTray tray;
    late NotificationTray core;
    late ReminderController controller;
    late DismissedReminderDetector detector;

    setUp(() {
      tray = FlutterNotificationTray(
        presenter: presenter,
        builder: buildBuilder(),
        logging: logging,
      );
      final taskRunner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      core = NotificationTray(
        taskRunner,
        CommandRunner(taskRunner),
        preferences,
        tray,
      );
      controller = ReminderController(_NoopScheduler(), core, preferences);
      detector = DismissedReminderDetector(
        tray: tray,
        registry: core,
        habits: habitList,
        platform: presenter,
        onDismiss: controller.onDismiss,
        logging: logging,
      );
    });

    /// The OS posting the alarm the scheduler armed: the notification appears
    /// in the shade with no Dart involved.
    Future<void> fireArmedAlarm(Habit habit) async {
      final scheduler = FlutterAlarmScheduler(
        plugin: plugin,
        builder: buildBuilder(),
        logging: logging,
        nowMillis: () => unixTime(2015, 1, 26, 6, 0),
      );
      scheduler.scheduleShowReminder(
        unixTime(2015, 1, 26, 8, 30),
        habit,
        monday.unixTime,
      );
      await scheduler.settle();
      presenter.live!.add(plugin.scheduled.single.spec.id);
    }

    test('is in the tray registry once the app is in the foreground',
        () async {
      final habit = habitWithReminder();
      await fireArmedAlarm(habit);

      await detector.reconcile();

      expect(tray.activeReminders.keys, contains(10),
          reason: 'audit9.fired-reminder-enters-the-registry#1: upstream the '
              'alarm fires into ReminderReceiver, which calls '
              'ReminderController.onShowReminder -> NotificationTray.show, and '
              'AndroidNotificationTray.showNotification ends with '
              'active.add(notificationId). Every reminder the user sees is in '
              'the registry. Here the OS posted it, so the registry has to be '
              'caught up at the next foreground.');
      expect(tray.activeReminders[10], same(habit),
          reason: 'audit9.fired-reminder-enters-the-registry#1: and it names '
              'the habit, because the delete intent upstream carries the habit '
              'and this port has to recover it from the id alone');
    });

    test('is in the core registry, so reshow can put it back', () async {
      final habit = habitWithReminder();
      await fireArmedAlarm(habit);

      await detector.reconcile();
      presenter.shown.clear();
      core.reshow(habit);
      await tray.settle();

      expect(presenter.shown, hasLength(1),
          reason: 'audit9.fired-reminder-enters-the-registry#1: '
              'NotificationTray.show writes active[habit] = data before it '
              'posts anything, and reshow(habit) is active[habit]?.let { ... } '
              '— a habit that never entered the map can never be re-posted');
      expect(presenter.shown.single.id, 10,
          reason: 'audit9.fired-reminder-enters-the-registry#1: under the same '
              'notification id the OS posted it with');
    });

    test('comes back after a swipe when notifications are sticky', () async {
      preferences.setNotificationsSticky(true);
      final habit = habitWithReminder();
      await fireArmedAlarm(habit);

      // The user opens the app: the registry catches up with the shade.
      await detector.reconcile();
      // ... backgrounds it, and swipes the reminder away.
      presenter.live!.clear();
      presenter.shown.clear();
      // ... and opens it again.
      await detector.reconcile();
      await tray.settle();

      expect(presenter.shown, hasLength(1),
          reason: 'audit9.fired-reminder-enters-the-registry#1: the delete '
              'intent reaches ReminderController.onDismiss, which for '
              'shouldMakeNotificationsSticky() calls notificationTray.reshow'
              '(habit) — and reshow reads the registry the fired reminder has '
              'to be in');
      expect(presenter.cancelled, isEmpty,
          reason: 'audit9.fired-reminder-enters-the-registry#1: the sticky '
              'branch re-posts, it does not cancel');
    });

    test('is not adopted twice, and a host that cannot see the shade adopts '
        'nothing', () async {
      final habit = habitWithReminder();
      await fireArmedAlarm(habit);

      await detector.reconcile();
      await detector.reconcile();
      expect(tray.activeReminders, hasLength(1),
          reason: 'audit9.fired-reminder-enters-the-registry#1: the registry '
              'is a map keyed by notification id, so a second foreground '
              'finds the entry already there');

      presenter.live = null;
      await detector.reconcile();
      expect(tray.activeReminders, hasLength(1),
          reason: 'audit9.fired-reminder-enters-the-registry#1: "I cannot see '
              'what is posted" must not be read as "everything is posted" — '
              'only Android answers this query at all');
    });
  });

  // -------------------------------------------------------------------------
  // audit9.obsolete-reminder-alarm-withdrawn
  // -------------------------------------------------------------------------

  group('an alarm that has become obsolete', () {
    late FlutterReminderScheduler scheduler;
    late FlutterAlarmScheduler alarms;

    setUp(() {
      alarms = FlutterAlarmScheduler(
        plugin: plugin,
        builder: buildBuilder(),
        logging: logging,
        nowMillis: () => unixTime(2015, 1, 26, 9, 0),
      );
      scheduler = FlutterReminderScheduler(
        commandRunner: CommandRunner(CoroutineTaskRunner(
          mainDispatcher: const UnconfinedTestDispatcher(),
          ioDispatcher: const UnconfinedTestDispatcher(),
        )),
        habitList: habitList,
        alarms: alarms,
        widgetPreferences: WidgetPreferences(storage),
      );
    });

    test('is withdrawn when the habit\'s reminder is switched off', () async {
      final habit = habitWithReminder();
      scheduler.scheduleAll();
      await alarms.settle();
      expect(plugin.pending, <int>{10},
          reason: 'the alarm is armed before the user changes anything');

      // The user clears the reminder in the editor and saves; the command
      // reaches ReminderScheduler.onCommandFinished, which is scheduleAll().
      habit.reminder = null;
      scheduler.scheduleAll();
      await alarms.settle();

      expect(plugin.cancelled, contains(10),
          reason: 'audit9.obsolete-reminder-alarm-withdrawn#1: gate 2 of '
              'NotificationTray.ShowNotificationTask.onPostExecute — '
              'if (!habit.hasReminder()) { log("does not have a reminder. '
              'Skipping."); return }. Upstream the stale alarm fires and is '
              'dropped in silence; here the alarm IS the finished '
              'notification, so it has to be withdrawn instead.');
      expect(plugin.pending, isEmpty,
          reason: 'audit9.obsolete-reminder-alarm-withdrawn#1: nothing is left '
              'to fire at 08:30 tomorrow');
    });

    test('is withdrawn when the habit is archived', () async {
      final habit = habitWithReminder();
      scheduler.scheduleAll();
      await alarms.settle();
      expect(plugin.pending, <int>{10},
          reason: 'the alarm is armed before the user changes anything');

      habit.isArchived = true;
      scheduler.scheduleAll();
      await alarms.settle();

      expect(plugin.cancelled, contains(10),
          reason: 'audit9.obsolete-reminder-alarm-withdrawn#1: gate 3 — '
              'if (habit.isArchived) { log("is archived. Skipping."); return }. '
              'An archived habit shows no reminder upstream, so its alarm must '
              'post nothing here either.');
      expect(plugin.pending, isEmpty,
          reason: 'audit9.obsolete-reminder-alarm-withdrawn#1');
    });

    test('a habit that is still wanted keeps its alarm', () async {
      habitWithReminder();
      habitWithReminder(id: 11);
      scheduler.scheduleAll();
      await alarms.settle();

      scheduler.scheduleAll();
      await alarms.settle();

      expect(plugin.cancelled, isEmpty,
          reason: 'audit9.obsolete-reminder-alarm-withdrawn#1: the withdrawal '
              'is for alarms that no longer have a habit to show, and a habit '
              'with a live reminder is not one of them');
      expect(plugin.pending, <int>{10, 11},
          reason: 'audit9.obsolete-reminder-alarm-withdrawn#1');
    });
  });
}

/// `ReminderScheduler` as far as `ReminderController` can see it.
class _NoopScheduler implements ReminderSchedulerApi {
  @override
  void scheduleAll() {}

  @override
  void snoozeReminder(Habit habit, int minutes) {}

  @override
  void scheduleAtTime(Habit habit, int reminderTime) {}

  @override
  void snoozeUntil(Habit habit, int reminderTime) {}
}
