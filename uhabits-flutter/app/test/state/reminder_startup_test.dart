/// What the application does with the reminder scheduler at launch, and what
/// the habit list does with the notification permission when it comes back to
/// the foreground.
///
/// Ported from
/// uhabits-android/src/main/java/org/isoron/uhabits/HabitsApplication.kt and
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsActivity.kt.
///
/// Neither has a Kotlin test; the parity ledger is the only specification, and
/// every `expect` cites the rule it exercises. The two halves are driven
/// differently:
///
///  * the launch sequence runs the real [AppScope.startServices] over fake
///    platform seams and reads back the order the calls arrived in;
///  * the permission flow runs [ReminderPermissionGate] over a scripted
///    [NotificationPermissions], because "the user denied" and "this host is
///    Android 12" are answers no test process can produce for real.
library;

// The core layers are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/reminder_permission_gate.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';
import 'package:uhabits_core/uhabits_core.dart';

// ---------------------------------------------------------------------------
// Instrumentation
// ---------------------------------------------------------------------------

/// Records every platform call the three services make, in order.
class _FakeSystemTray implements SystemTray {
  _FakeSystemTray(this.calls);

  final List<String> calls;

  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) =>
      calls.add('tray.cancel:$notificationId');

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) =>
      calls.add('tray.show:$notificationId');
}

class _FakeSystemScheduler implements SystemScheduler {
  _FakeSystemScheduler(this.calls);

  final List<String> calls;

  @override
  void log(String componentName, String msg) {
    if (msg == 'Scheduling all alarms') calls.add('scheduler.scheduleAll');
  }

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) {
    calls.add('scheduler.show:${habit.id}');
    return SchedulerResult.ok;
  }

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => null;
}

class _FakeHomeWidgetPlatform implements HomeWidgetPlatform {
  _FakeHomeWidgetPlatform(this.calls);

  final List<String> calls;

  @override
  Future<void> saveWidgetData(String key, String? value) async {}

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {
    // One note per publish, not one per provider.
    if (name == HomeWidgetBridge.providerNames.first) {
      calls.add('widgets.update');
    }
  }

  @override
  Future<void> setAppGroupId(String groupId) async {}
}

/// A scripted `checkSelfPermission` / `requestPermissionLauncher` pair.
class _ScriptedPermissions implements NotificationPermissions {
  _ScriptedPermissions({
    required this.runtimePermissionRequired,
    required this.granted,
    required this.answerToRequest,
  });

  /// `SDK_INT >= TIRAMISU`.
  bool runtimePermissionRequired;

  /// `checkSelfPermission(...) == PERMISSION_GRANTED`.
  bool granted;

  /// What the user taps in the system dialog.
  bool answerToRequest;

  int requestCount = 0;

  @override
  Future<bool> get needsRuntimePermission async => runtimePermissionRequired;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCount++;
    // The system dialog grants the permission for real when the user accepts,
    // so a later checkSelfPermission answers true.
    if (answerToRequest) granted = true;
    return answerToRequest;
  }
}

/// `MidnightTimer.onResume(delay, testExecutor)`'s injection point.
class _FakeExecutor implements ScheduledExecutorService {
  final List<void Function()> scheduled = <void Function()>[];

  /// Every schedule ever made, including the ones a shutdown has since taken
  /// off the queue.
  int schedules = 0;
  int shutdowns = 0;

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelayMillis,
    int periodMillis,
  ) {
    schedules++;
    scheduled.add(command);
  }

  @override
  List<void Function()> shutdownNow() {
    shutdowns++;
    final pending = List<void Function()>.from(scheduled);
    scheduled.clear();
    return pending;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int nextDatabase = 0;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_reminder_startup');
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    setToday(LocalDate.ymd(2015, 1, 26));
  });

  tearDown(() async {
    await pumpEventQueue();
    for (final scope in scopes) {
      try {
        scope.close();
      } on Object {
        // Already closed by the test that opened it.
      }
    }
    scopes.clear();
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final path = '${tempDir.path}/habits${nextDatabase++}.db';
    final scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      databasePath: path,
      mainDispatcher: const AsyncDispatcher(),
      ioDispatcher: const AsyncDispatcher(),
      logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
    );
    scopes.add(scope);
    return scope;
  }

  Habit addHabitWithReminder(AppScope scope, {String name = 'Meditate'}) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = HabitType.yesNo
      ..frequency = Frequency.daily
      ..reminder = Reminder(8, 30, WeekdayList.everyDay);
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  /// The three singletons `startPlatformServices` would build, over fakes.
  ({NotificationTray tray, ReminderScheduler scheduler, WidgetSync sync})
      servicesFor(AppScope scope, List<String> calls) => (
            tray: NotificationTray(
              scope.taskRunner,
              scope.commandRunner,
              scope.preferences,
              _FakeSystemTray(calls),
            ),
            scheduler: ReminderScheduler(
              scope.commandRunner,
              scope.habitList,
              _FakeSystemScheduler(calls),
              WidgetPreferences(scope.preferencesStorage),
            ),
            sync: WidgetSync(
              bridge: HomeWidgetBridge(
                habitList: scope.habitList,
                registry: WidgetRegistry(scope.preferencesStorage),
                platform: _FakeHomeWidgetPlatform(calls),
              ),
              commandRunner: scope.commandRunner,
              taskRunner: scope.taskRunner,
              midnightTimer: scope.midnightTimer,
              preferences: scope.preferences,
            ),
          );

  // -----------------------------------------------------------------------
  // reminders.reschedule-on-command#4 and #5 — the application object
  // -----------------------------------------------------------------------

  group('the scheduler over the application lifetime', () {
    test('#4 startup subscribes first and only then arms every alarm',
        () async {
      final scope = openScope();
      addHabitWithReminder(scope);
      final calls = <String>[];
      final services = servicesFor(scope, calls);

      services.scheduler.scheduleAll();
      calls.clear();

      scope.startServices(
        tray: services.tray,
        scheduler: services.scheduler,
        sync: services.sync,
      );

      expect(calls, isEmpty,
          reason: 'reminders.reschedule-on-command#4: and only THEN, on a '
              'background task, reminderScheduler.scheduleAll() — so nothing '
              'has been scheduled by the time onCreate returns');

      await scope.taskRunner.awaitAll();

      expect(calls, contains('scheduler.scheduleAll'),
          reason: 'reminders.reschedule-on-command#4: the background task is '
              'what runs scheduleAll()');
      expect(calls.where((c) => c.startsWith('scheduler.show:')), isNotEmpty,
          reason: 'reminders.reschedule-on-command#4: and it really arms the '
              'habits that carry a reminder');
    });

    test('#4 the subscription is live: a later command reschedules', () async {
      final scope = openScope();
      final habit = addHabitWithReminder(scope);
      final calls = <String>[];
      final services = servicesFor(scope, calls);
      scope.startServices(
        tray: services.tray,
        scheduler: services.scheduler,
        sync: services.sync,
      );
      await scope.taskRunner.awaitAll();
      calls.clear();

      scope.commandRunner.run(
        ChangeHabitColorCommand(scope.habitList, <Habit>[habit],
            const PaletteColor(5)),
      );
      await scope.taskRunner.awaitAll();

      expect(calls, isEmpty,
          reason: 'reminders.reschedule-on-command#4: startListening() is what '
              'makes the scheduler a CommandRunner listener at all — and a '
              'colour change is one of the two commands it ignores');

      scope.commandRunner.run(
        ArchiveHabitsCommand(scope.habitList, <Habit>[habit]),
      );
      await scope.taskRunner.awaitAll();

      expect(calls, contains('scheduler.scheduleAll'),
          reason: 'reminders.reschedule-on-command#4: any other command '
              'reaches the scheduler, which is only possible because '
              'onCreate subscribed it');
    });

    test('#5 shutting the scope down unsubscribes the scheduler', () async {
      final scope = openScope();
      final habit = addHabitWithReminder(scope);
      final calls = <String>[];
      final services = servicesFor(scope, calls);
      scope.startServices(
        tray: services.tray,
        scheduler: services.scheduler,
        sync: services.sync,
      );
      await scope.taskRunner.awaitAll();
      final command = ArchiveHabitsCommand(scope.habitList, <Habit>[habit]);
      calls.clear();
      scope.commandRunner.notifyListeners(command);
      expect(calls, contains('scheduler.scheduleAll'),
          reason: 'reminders.reschedule-on-command#5: while the app is alive '
              'the scheduler is on the command runner');

      scope.close();
      scopes.remove(scope);

      calls.clear();
      scope.commandRunner.notifyListeners(command);
      expect(calls, isEmpty,
          reason: 'reminders.reschedule-on-command#5: '
              'HabitsApplication.onTerminate calls '
              'reminderScheduler.stopListening(), so a command finishing '
              'after teardown no longer reaches it');

      services.scheduler.onCommandFinished(command);
      expect(calls, contains('scheduler.scheduleAll'),
          reason: 'reminders.reschedule-on-command#5: the scheduler itself '
              'still works — what stopListening() removes is the '
              'subscription, not the behaviour');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.app-start-and-permission
  // -----------------------------------------------------------------------

  group('startup order', () {
    test('#1 onCreate stamps today, recomputes, subscribes, then schedules',
        () async {
      final scope = openScope();
      addHabitWithReminder(scope);
      final calls = <String>[];
      final services = servicesFor(scope, calls);

      expect(getToday(), isNotNull,
          reason: 'reminders.app-start-and-permission#1: '
              'setToday(computeToday(preferences.midnightDelayHours, 0)) has '
              'run by the time the graph exists — every matcher and every '
              'score reads it');
      expect(scope.habitList.getByPosition(0).scores, isNotNull,
          reason: 'reminders.app-start-and-permission#1: every habit is '
              'recomputed');

      scope.startServices(
        tray: services.tray,
        scheduler: services.scheduler,
        sync: services.sync,
      );

      expect(scope.reminderScheduler, same(services.scheduler),
          reason: 'reminders.app-start-and-permission#1: '
              'reminderScheduler.startListening() and '
              'notificationTray.startListening() are what publish the two '
              'singletons');
      expect(scope.notificationTray, same(services.tray),
          reason: 'reminders.app-start-and-permission#1');
      expect(scope.widgetSync, same(services.sync),
          reason: 'reminders.app-start-and-permission#1: the widget updater '
              'is started too');

      await scope.taskRunner.awaitAll();

      final scheduleAll = calls.indexOf('scheduler.scheduleAll');
      final widgetUpdate = calls.indexOf('widgets.update');
      expect(scheduleAll, isNonNegative,
          reason: 'reminders.app-start-and-permission#1: then on the task '
              'runner, reminderScheduler.scheduleAll()');
      expect(widgetUpdate, isNonNegative,
          reason: 'reminders.app-start-and-permission#1: followed by '
              'widgetUpdater.updateWidgets()');
      expect(scheduleAll, lessThan(widgetUpdate),
          reason: 'reminders.app-start-and-permission#1: in that order, '
              'inside the one background block');
    });
  });

  group('the midnight timer around the foreground', () {
    test('#2 #7 resume starts it, pause stops it, and neither is repeatable',
        () {
      final scope = openScope();
      final executor = _FakeExecutor();
      final lifecycle = MidnightTimerLifecycle(scope.midnightTimer);

      expect(lifecycle.onPause(), isEmpty,
          reason: 'reminders.app-start-and-permission#7: '
              'ListHabitsActivity.onPause calls midnightTimer.onPause() — but '
              'the timer\'s executor is a lateinit field, so a pause before '
              'the first resume must not reach it');

      lifecycle.onResume(testExecutor: executor);
      expect(lifecycle.isRunning, isTrue,
          reason: 'reminders.app-start-and-permission#2: '
              'ListHabitsActivity.onResume calls midnightTimer.onResume()');
      expect(executor.scheduled, hasLength(1),
          reason: 'reminders.app-start-and-permission#2: which arms the '
              'day-rollover schedule');

      lifecycle.onResume(testExecutor: executor);
      expect(executor.scheduled, hasLength(1),
          reason: 'reminders.app-start-and-permission#2: a second resume with '
              'no pause in between would replace the executor and leave the '
              'first one firing forever');

      expect(lifecycle.onPause(), hasLength(1),
          reason: 'reminders.app-start-and-permission#7: onPause hands back '
              'the commands that were still queued');
      expect(executor.shutdowns, 1,
          reason: 'reminders.app-start-and-permission#7: and really shuts the '
              'executor down');
      expect(lifecycle.isRunning, isFalse,
          reason: 'reminders.app-start-and-permission#7');

      expect(lifecycle.onPause(), isEmpty,
          reason: 'reminders.app-start-and-permission#7: pausing twice is a '
              'no-op, not a second shutdown');
      expect(executor.shutdowns, 1,
          reason: 'reminders.app-start-and-permission#7');
    });

    test('#2 it can be resumed again after a pause', () {
      final scope = openScope();
      final executor = _FakeExecutor();
      final lifecycle = MidnightTimerLifecycle(scope.midnightTimer)
        ..onResume(testExecutor: executor);
      lifecycle.onPause();

      lifecycle.onResume(testExecutor: executor);

      expect(executor.schedules, 2,
          reason: 'reminders.app-start-and-permission#2: every foreground '
              'stretch arms the rollover again — the timer only runs while '
              'the habit list is in the foreground');
    });
  });

  group('the POST_NOTIFICATIONS gate', () {
    late List<String> calls;
    late AppScope scope;
    late ReminderScheduler scheduler;

    setUp(() {
      calls = <String>[];
      scope = openScope();
      scheduler = ReminderScheduler(
        scope.commandRunner,
        scope.habitList,
        _FakeSystemScheduler(calls),
        WidgetPreferences(scope.preferencesStorage),
      );
    });

    ReminderPermissionGate gateOver(_ScriptedPermissions permissions) =>
        ReminderPermissionGate(
          scheduler: scheduler,
          permissions: permissions,
          logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        );

    test('#6 with no habit carrying a reminder nothing is asked', () async {
      final habit = scope.modelFactory.buildHabit()
        ..name = 'Run'
        ..frequency = Frequency.daily;
      scope.habitList.add(habit);
      final permissions = _ScriptedPermissions(
        runtimePermissionRequired: true,
        granted: false,
        answerToRequest: true,
      );

      expect(await gateOver(permissions).onResume(), isFalse,
          reason: 'reminders.app-start-and-permission#6: if the user has zero '
              'habits with reminders, no permission is ever requested');
      expect(permissions.requestCount, 0,
          reason: 'reminders.app-start-and-permission#6: the request is never '
              'even reached');
      expect(calls, isEmpty,
          reason: 'reminders.app-start-and-permission#2: the whole block is '
              'guarded by hasHabitsWithReminders()');
    });

    test('#3 below Android 13 it schedules straight away', () async {
      addHabitWithReminder(scope);
      final permissions = _ScriptedPermissions(
        runtimePermissionRequired: false,
        granted: false,
        answerToRequest: false,
      );

      expect(await gateOver(permissions).onResume(), isTrue,
          reason: 'reminders.app-start-and-permission#3: on SDK < 33 '
              '(TIRAMISU) it immediately calls reminderScheduler.scheduleAll()');
      expect(calls, contains('scheduler.scheduleAll'),
          reason: 'reminders.app-start-and-permission#3');
      expect(permissions.requestCount, 0,
          reason: 'reminders.app-start-and-permission#3: the runtime '
              'permission does not exist there, so nothing is asked');
    });

    test('#4 an already-granted permission schedules without asking', () async {
      addHabitWithReminder(scope);
      final permissions = _ScriptedPermissions(
        runtimePermissionRequired: true,
        granted: true,
        answerToRequest: false,
      );

      expect(await gateOver(permissions).onResume(), isTrue,
          reason: 'reminders.app-start-and-permission#4: on SDK >= 33, if '
              'POST_NOTIFICATIONS is already granted it calls scheduleAll()');
      expect(permissions.requestCount, 0,
          reason: 'reminders.app-start-and-permission#4: and does not launch '
              'the permission request');
      expect(calls, contains('scheduler.scheduleAll'),
          reason: 'reminders.app-start-and-permission#4');
    });

    test('#4 the request is launched exactly once per screen instance',
        () async {
      addHabitWithReminder(scope);
      final permissions = _ScriptedPermissions(
        runtimePermissionRequired: true,
        granted: false,
        answerToRequest: false,
      );
      final gate = gateOver(permissions);

      await gate.onResume();
      expect(permissions.requestCount, 1,
          reason: 'reminders.app-start-and-permission#4: otherwise it launches '
              'the permission request');
      expect(gate.permissionAlreadyRequested, isTrue,
          reason: 'reminders.app-start-and-permission#4: guarded by a '
              '`permissionAlreadyRequested` flag');

      // Dismissing the system dialog resumes the activity, which is exactly
      // the loop the flag exists to break.
      await gate.onResume();
      await gate.onResume();
      expect(permissions.requestCount, 1,
          reason: 'reminders.app-start-and-permission#4: exactly once per '
              'activity instance, whose purpose is explicitly to avoid an '
              'infinite onResume loop when the user denies');

      // A new activity instance asks again.
      final second = gateOver(permissions);
      await second.onResume();
      expect(permissions.requestCount, 2,
          reason: 'reminders.app-start-and-permission#4: the flag is per '
              'activity instance, not per process');
    });

    test('#5 granted schedules, denied schedules nothing', () async {
      addHabitWithReminder(scope);

      final accepting = _ScriptedPermissions(
        runtimePermissionRequired: true,
        granted: false,
        answerToRequest: true,
      );
      expect(await gateOver(accepting).onResume(), isTrue,
          reason: 'reminders.app-start-and-permission#5: if the permission '
              'result is granted, scheduleAll() runs');
      expect(calls, contains('scheduler.scheduleAll'),
          reason: 'reminders.app-start-and-permission#5');

      calls.clear();
      final refusing = _ScriptedPermissions(
        runtimePermissionRequired: true,
        granted: false,
        answerToRequest: false,
      );
      expect(await gateOver(refusing).onResume(), isFalse,
          reason: 'reminders.app-start-and-permission#5: if denied it only '
              'logs "POST_NOTIFICATIONS denied"');
      expect(calls, isEmpty,
          reason: 'reminders.app-start-and-permission#5: and no alarms are '
              '(re)scheduled from this path');
    });

    test('#5 the denial is logged under the activity that asked', () async {
      addHabitWithReminder(scope);
      final log = StringBuffer();
      final gate = ReminderPermissionGate(
        scheduler: scheduler,
        permissions: _ScriptedPermissions(
          runtimePermissionRequired: true,
          granted: false,
          answerToRequest: false,
        ),
        logging: StandardLogging(out: log, err: log),
      );

      await gate.onResume();

      expect(log.toString(), contains('POST_NOTIFICATIONS denied'),
          reason: 'reminders.app-start-and-permission#5: it only logs '
              '"POST_NOTIFICATIONS denied"');
    });
  });
}
