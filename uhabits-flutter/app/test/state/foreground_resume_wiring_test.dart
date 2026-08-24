/// What the app does when it comes back to the foreground.
///
/// `ListHabitsActivity.onResume` is one block of six statements, and the port
/// spread them over objects with the matching lifetimes. Two of them were
/// written and then never driven by anything:
///
///  * `adapter.refresh()` / `screen.onAttached()` — that is
///    [HabitListModel.attach] / [HabitListModel.detach], which until now were
///    called only when the list *widget* mounted and unmounted, and a
///    background/foreground round trip mounts nothing;
///  * `appComponent.widgetUpdater.updateWidgets()`, the second half of the
///    `taskRunner.run { AutoBackup(this).run(); … }` block.
///
/// Every test here drives the real entry point — `UhabitsApp(scope: …)`, the
/// widget `main()` hands to `runApp` — and sends the platform's own
/// `flutter/lifecycle` message, exactly as the engine does when the user
/// switches away and comes back. Nothing calls `attach`, `detach` or
/// `updateWidgets` by hand: the point of these features is that the app never
/// makes those calls itself.
library;

// The core layers are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/reminder_permission_gate.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

// ---------------------------------------------------------------------------
// Platform seams. The three services the app starts at launch, reduced to what
// a test can observe: nothing at all for the tray and the alarm scheduler, and
// a publish counter for the home-screen widgets.
// ---------------------------------------------------------------------------

class _SilentTray implements SystemTray {
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

class _SilentScheduler implements SystemScheduler {
  /// The habits whose next reminder has been armed — `AlarmManager.setExact`,
  /// the last thing `reminderScheduler.scheduleAll()` reaches.
  final List<String> armed = <String>[];

  @override
  void log(String componentName, String msg) {}

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) {
    armed.add(habit.name);
    return SchedulerResult.ok;
  }

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => SchedulerResult.ok;
}

/// A scripted `checkSelfPermission` / `requestPermissionLauncher` pair — the
/// same shape test/state/reminder_startup_test.dart drives the gate through.
/// "The user is on Android 13" and "the user tapped Deny" are answers no test
/// process can produce for real.
class _ScriptedPermissions implements NotificationPermissions {
  _ScriptedPermissions({this.answerToRequest = true});

  /// `checkSelfPermission(POST_NOTIFICATIONS) == PERMISSION_GRANTED`. Starts
  /// false — a fresh install has never been granted anything — and follows
  /// whatever the user answers.
  bool granted = false;

  /// What the user taps in the system dialog.
  bool answerToRequest;

  /// `permissionLauncher.launch(POST_NOTIFICATIONS)` calls.
  int requests = 0;

  @override
  Future<bool> get needsRuntimePermission async => true;

  @override
  Future<bool> isGranted() async => granted;

  /// Run when the system dialog is raised, so a test can record what the app
  /// had already done by then. This is what makes "the grant is *followed by*
  /// scheduleAll()" an assertion rather than a hope: saving the habit arms it
  /// too, so only the ordering distinguishes the two.
  void Function()? onRequest;

  @override
  Future<bool> request() async {
    requests++;
    onRequest?.call();
    granted = answerToRequest;
    return answerToRequest;
  }
}

/// The `home_widget` plugin, counting publishes the way
/// test/ui/settings/widget_opacity_refresh_test.dart does: one note per
/// `updateWidgets()`, not one per provider.
class _CountingWidgetPlatform implements HomeWidgetPlatform {
  int publishes = 0;

  /// The last `uhabits.index` document written, decoded. It is the payload the
  /// launcher's process reads, so it is where "the widgets know about this
  /// preference" is observable.
  Map<String, Object?>? lastIndex;

  @override
  Future<void> saveWidgetData(String id, String? value) async {
    if (id == HomeWidgetBridge.indexKey && value != null) {
      lastIndex = jsonDecode(value) as Map<String, Object?>;
    }
  }

  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {
    if (name == HomeWidgetBridge.providerNames.first) publishes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_resume_wiring');
  });

  tearDown(() {
    // The clock hooks, released whether or not a test pinned them.
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    getDefaultTimeZone = systemDefaultTimeZone;
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits${databaseIndex++}.db'),
      preferencesStorage: MemoryStorage(),
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, String name, {Reminder? reminder}) {
    final Habit habit = scope.modelFactory.buildHabit()..name = name;
    if (reminder != null) habit.reminder = reminder;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  /// Steps (7) to (10) of `HabitsApplication.onCreate`, over seams a test can
  /// watch. This is what publishes `scope.widgetSync`.
  _CountingWidgetPlatform startServices(
    AppScope scope, {
    NotificationPermissions? permissions,
    _SilentScheduler? alarms,
  }) {
    final _CountingWidgetPlatform widgets = _CountingWidgetPlatform();
    scope.startServices(
      permissions: permissions,
      tray: NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _SilentTray(),
      ),
      scheduler: ReminderScheduler(
        scope.commandRunner,
        scope.habitList,
        alarms ?? _SilentScheduler(),
        WidgetPreferences(scope.preferencesStorage),
      ),
      sync: WidgetSync(
        bridge: HomeWidgetBridge(
          habitList: scope.habitList,
          registry: WidgetRegistry(scope.preferencesStorage),
          platform: widgets,
          preferences: scope.preferences,
        ),
        commandRunner: scope.commandRunner,
        taskRunner: scope.taskRunner,
        midnightTimer: scope.midnightTimer,
        preferences: scope.preferences,
      ),
    );
    return widgets;
  }

  /// The `flutter/lifecycle` message the engine sends on every foreground and
  /// background transition. Delivering it through the binary messenger — and
  /// not by calling `didChangeAppLifecycleState` on some state object — is what
  /// makes these tests about the app rather than about an observer.
  Future<void> sendLifecycle(
    WidgetTester tester,
    AppLifecycleState state,
  ) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage(state.toString()),
      (ByteData? _) {},
    );
    await tester.pumpAndSettle();
  }

  // -----------------------------------------------------------------------
  // verify.list-not-refreshed-on-resume
  // -----------------------------------------------------------------------

  group('verify.list-not-refreshed-on-resume', () {
    testWidgets('#1, #2 backgrounding detaches the habit list and coming back '
        'refreshes it', (tester) async {
      final AppScope scope = openScope();
      final Habit habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      final LocalDate today = getToday();
      expect(scope.adapter.bindCardView(0), isNotNull,
          reason: 'verify.list-not-refreshed-on-resume#2: the list is attached '
              'while the app is in the foreground.');

      // `onPause`: `midnightTimer.onPause()`, `screen.onDetached()`,
      // `adapter.cancelRefresh()`.
      await sendLifecycle(tester, AppLifecycleState.paused);

      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          today,
          Entry.yesManual,
          '',
        ),
      );
      await tester.pumpAndSettle();

      expect(scope.adapter.bindCardView(0), isNull,
          reason: 'verify.list-not-refreshed-on-resume#2: `HabitListModel'
              '.attach()` / `detach()` are the port of `onResume` / `onPause`, '
              'so going to the background has to run the `detach()` half — '
              'today they are driven only by widget mount/unmount, and a '
              'background/foreground round trip mounts nothing.');

      // `onResume`: `adapter.refresh()` then `screen.onAttached()`.
      await sendLifecycle(tester, AppLifecycleState.resumed);

      expect(scope.adapter.bindCardView(0), isNotNull,
          reason: 'verify.list-not-refreshed-on-resume#1: every time the '
              'activity comes back to the foreground it re-runs '
              '`adapter.refresh()`.');
      expect(scope.cache.getCheckmarks(habit.id!).first, Entry.yesManual,
          reason: 'verify.list-not-refreshed-on-resume#1: the refresh '
              'recomputes the whole HabitCardListCache, so the cache catches '
              'up with everything that happened while it was detached.');

      // …and the subscription really is live again, which is
      // `screen.onAttached()`.
      scope.commandRunner.run(
        CreateRepetitionCommand(scope.habitList, habit, today, Entry.no, ''),
      );
      await tester.pumpAndSettle();
      expect(scope.cache.getCheckmarks(habit.id!).first, Entry.no,
          reason: 'verify.list-not-refreshed-on-resume#1');
    });

    testWidgets('#1, #2 a day that turned while the app was backgrounded is '
        'visible the moment it returns', (tester) async {
      // The clock the whole core reads, pinned before the scope is opened —
      // `AppScope.open` is what runs `setToday(computeToday(…))` for the first
      // time.
      int nowMillis = DateTime.utc(2024, 3, 10, 12).millisecondsSinceEpoch;
      systemCurrentTimeMillis = () => nowMillis;
      getDefaultTimeZone = () => gmt;

      final AppScope scope = openScope();
      final Habit habit = addHabit(scope, 'Meditate');
      final LocalDate firstDay = getToday();
      expect(firstDay, LocalDate.ymd(2024, 3, 10));

      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          firstDay,
          Entry.yesManual,
          '',
        ),
      );
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      expect(find.byKey(EntryPanel.buttonKey(firstDay)), findsOneWidget,
          reason: 'verify.list-not-refreshed-on-resume#1: the strip starts at '
              "the day the app was launched on.");

      // The user switches away, midnight passes — the midnight timer is
      // paused for exactly this interval — and the user comes back.
      await sendLifecycle(tester, AppLifecycleState.paused);
      nowMillis += DateUtils.dayLength;
      await sendLifecycle(tester, AppLifecycleState.resumed);

      final LocalDate secondDay = firstDay.plus(1);
      expect(getToday(), secondDay,
          reason: 'verify.list-not-refreshed-on-resume#1: upstream '
              '`adapter.refresh()` recomputes against *the current* '
              '`getToday()`, which on Android is read straight off the clock. '
              'The port caches it in a process-global that only the midnight '
              'timer writes, and #2: `MidnightTimerLifecycle.onResume()` '
              're-schedules for the next midnight and does not fire for a '
              'boundary already crossed — so the resume has to re-stamp it '
              'before it refreshes, or the refresh recomputes yesterday.');
      expect(find.byKey(EntryPanel.buttonKey(secondDay)), findsOneWidget,
          reason: 'verify.list-not-refreshed-on-resume#2: leaving the app '
              'backgrounded across midnight and returning must not show the '
              "previous day's date columns.");
      expect(scope.cache.getCheckmarks(habit.id!).first, Entry.unknown,
          reason: 'verify.list-not-refreshed-on-resume#2: …nor the previous '
              "day's checkmark values: today is empty again.");
      expect(scope.cache.getCheckmarks(habit.id!)[1], Entry.yesManual,
          reason: 'verify.list-not-refreshed-on-resume#1: what was marked has '
              'moved one column along, which is what a whole-cache recompute '
              'against the new today looks like.');
    });
  });

  // -----------------------------------------------------------------------
  // verify.widgets-not-refreshed-on-resume
  // -----------------------------------------------------------------------

  group('verify.widgets-not-refreshed-on-resume', () {
    testWidgets('#1, #2 a resume republishes the home-screen widget data',
        (tester) async {
      final AppScope scope = openScope();
      addHabit(scope, 'Meditate');
      final _CountingWidgetPlatform widgets = startServices(scope);

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();
      await scope.widgetSync!.settle();
      // Everything the startup sequence and the first resume publish is
      // already counted; what follows is the round trip alone.
      final int afterStartup = widgets.publishes;

      await sendLifecycle(tester, AppLifecycleState.paused);
      await sendLifecycle(tester, AppLifecycleState.resumed);
      await scope.widgetSync!.settle();

      expect(widgets.publishes, greaterThan(afterStartup),
          reason: 'verify.widgets-not-refreshed-on-resume#1: every time the '
              'habit list resumes, the same background block runs the '
              'auto-backup and then pushes fresh data to all six widget '
              'providers, so returning to the app repaints the home-screen '
              'widgets even when nothing in this process ran a command. #2: '
              '`_runAutoBackup` builds and executes an `AutoBackupTask` and '
              'stops there.');
    });
  });

  // -----------------------------------------------------------------------
  // audit9.settings-return-does-not-republish-widgets
  // -----------------------------------------------------------------------

  group('audit9.settings-return-does-not-republish-widgets', () {
    const String rule =
        'audit9.settings-return-does-not-republish-widgets#1 — '
        '`SettingsActivity` is a separate activity, so backing out of it '
        'resumes `ListHabitsActivity`, whose `onResume` ends with '
        '`taskRunner.run { AutoBackup(this).run(); '
        'appComponent.widgetUpdater.updateWidgets() }`. Every preference the '
        'settings screen wrote — `pref_first_weekday` among them — is '
        'therefore republished to the six widget providers the moment the '
        'user returns to the habit list, before they can press Home and look '
        'at a widget.';

    testWidgets(
        '#1 changing the first weekday in Settings and backing out '
        'republishes the widget data with the new weekday', (tester) async {
      // The whole preference screen is one scroll view; a tall surface keeps
      // the row hit-testable, as test/ui/settings/settings_screen_test.dart
      // does.
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final AppScope scope = openScope();
      addHabit(scope, 'Meditate');
      final _CountingWidgetPlatform widgets = startServices(scope);

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();
      await scope.widgetSync!.settle();
      expect(widgets.lastIndex!['firstWeekday'], DayOfWeek.sunday.daysSinceSunday,
          reason: '$rule The home screen starts on the default weekday.');
      final int beforeSettings = widgets.publishes;

      // `res/menu/list_habits.xml` -> `SettingsActivity`.
      await tester.tap(
        find.byKey(const ValueKey<String>('listHabits.overflowMenu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.settings)),
      );
      await tester.pumpAndSettle();

      // The "First day of the week" `ListPreference`, set to Monday.
      await tester.tap(find.byKey(const ValueKey<String>('pref_first_weekday')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();
      await scope.widgetSync!.settle();

      expect(scope.preferences.firstWeekday, DayOfWeek.monday,
          reason: '$rule The preference really was written.');
      expect(widgets.publishes, beforeSettings,
          reason: '$rule `SettingsFragment.onSharedPreferenceChanged` '
              'special-cases `pref_widget_opacity` and nothing else, so the '
              'write itself refreshes no widget '
              '(`settings.preferences.widget-opacity#4`) — the republish is '
              "the returning activity's job.");

      // The Back button, which is `SettingsActivity` finishing.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await scope.widgetSync!.settle();

      expect(widgets.publishes, greaterThan(beforeSettings), reason: rule);
      expect(widgets.lastIndex!['firstWeekday'],
          DayOfWeek.monday.daysSinceSunday,
          reason: '$rule Otherwise the History and Frequency widgets keep '
              'drawing their week grids from the old weekday, with every '
              'column shifted, until the next command, the next day rollover '
              'or the next background/foreground round trip.');
    });

    testWidgets('#1 returning from any screen pushed over the list '
        'republishes, exactly as `onResume` does', (tester) async {
      final AppScope scope = openScope();
      addHabit(scope, 'Meditate');
      final _CountingWidgetPlatform widgets = startServices(scope);

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();
      await scope.widgetSync!.settle();
      final int afterStartup = widgets.publishes;

      // `startActivity(...)`: any activity over the list, not just settings.
      final NavigatorState navigator =
          Navigator.of(tester.element(find.byType(HabitListScreen)));
      unawaited(navigator.push<void>(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SizedBox.shrink()),
      )));
      await tester.pumpAndSettle();
      await scope.widgetSync!.settle();
      expect(widgets.publishes, afterStartup,
          reason: '$rule Nothing is published on the way *out* of the list: '
              '`onPause` has no such block.');

      navigator.pop();
      await tester.pumpAndSettle();
      await scope.widgetSync!.settle();
      expect(widgets.publishes, greaterThan(afterStartup),
          reason: '$rule The block is `onResume`\'s, and `onResume` runs '
              'whichever activity was on top.');
    });
  });

  // -----------------------------------------------------------------------
  // audit15.the-notification-permission-prompt-is-never
  // -----------------------------------------------------------------------

  group('audit15.the-notification-permission-prompt-is-never', () {
    const String rule =
        'audit15.the-notification-permission-prompt-is-never#1 — '
        '`ListHabitsActivity.onResume` runs its POST_NOTIFICATIONS block on '
        '*every* resume of the list activity, and finishing '
        '`EditHabitActivity` is a resume. On a fresh install the user creates '
        'their first habit with a reminder and presses Save; the editor '
        'finishes, the list resumes, `hasHabitsWithReminders()` is true for '
        'the first time, and `permissionLauncher.launch(POST_NOTIFICATIONS)` '
        'fires right there — before the user has left the app, and in time for '
        'the reminder they just set.';

    /// `IntentFactory.startEditActivity(context, habitType)` — CREATE mode,
    /// which is where `EditHabitScreen.selectTypeAndOpen` ends up.
    Future<void> openEditor(WidgetTester tester, AppScope scope) async {
      unawaited(
        Navigator.of(tester.element(find.byType(HabitListScreen)))
            .push<void>(EditHabitScreen.route(scope: scope)),
      );
      await tester.pumpAndSettle();
    }

    /// Name it, give it the default 08:00 reminder, press Save — which is
    /// `EditHabitActivity` running `CreateHabitCommand` and finishing.
    Future<void> fillAndSave(WidgetTester tester, String name) async {
      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        name,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();
      final MaterialLocalizations localizations = MaterialLocalizations.of(
        tester.element(find.byType(TimePickerDialog)),
      );
      await tester.tap(find.text(localizations.okButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();
    }

    testWidgets(
        '#1 saving the first habit with a reminder asks for the notification '
        'permission the moment the editor closes', (tester) async {
      // The radial time picker wants more room than the default surface.
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A fresh install: no habits at all.
      final AppScope scope = openScope();
      final _ScriptedPermissions permissions = _ScriptedPermissions();
      final _SilentScheduler alarms = _SilentScheduler();
      startServices(scope, permissions: permissions, alarms: alarms);

      // How many alarms had been armed by the time the dialog went up.
      int? armedWhenAsked;
      permissions.onRequest = () => armedWhenAsked = alarms.armed.length;

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();
      expect(permissions.requests, 0,
          reason: '$rule The launch itself asks nothing: '
              '`hasHabitsWithReminders()` is false, which is the guard the '
              'whole block sits behind.');

      await openEditor(tester, scope);
      await fillAndSave(tester, 'Meditate');

      expect(scope.habitList.getByPosition(0).hasReminder(), isTrue,
          reason: '$rule The fixture: the habit really was saved with a '
              'reminder.');
      expect(permissions.requests, 1, reason: rule);
      expect(armedWhenAsked, isNotNull,
          reason: '$rule The dialog really was raised.');
      expect(alarms.armed.length, greaterThan(armedWhenAsked!),
          reason: '$rule …and the grant is followed by `scheduleReminders()` '
              '= `reminderScheduler.scheduleAll()`, so the reminder the user '
              'just configured is armed *because of the grant*. Counting arms '
              'across the dialog is what makes this load-bearing: saving the '
              'habit arms it as well, through '
              '`ReminderScheduler.onCommandFinished`, so `contains(...)` alone '
              'passes with the gate removed entirely.');
    });

    testWidgets('#4 starting the services again rebuilds the gate', (tester) async {
      // The gate is cached because `permissionAlreadyRequested` is one field
      // per activity and must survive an editor round trip. But it holds the
      // scheduler and the permissions seam it was built with, so a second
      // `startServices` — a test reusing a scope, or any future restart path —
      // must not leave it bound to the pair that call has just replaced.
      final AppScope scope = openScope();
      addHabit(scope, 'Meditate',
          reminder: Reminder(8, 30, WeekdayList.everyDay));

      final _ScriptedPermissions first = _ScriptedPermissions();
      startServices(scope, permissions: first);
      final ReminderPermissionGate? before = scope.reminderPermissionGate;
      expect(before, isNotNull, reason: rule);
      await before!.onResume();
      expect(first.requests, 1, reason: rule);

      final _ScriptedPermissions second = _ScriptedPermissions();
      startServices(scope, permissions: second);
      final ReminderPermissionGate? after = scope.reminderPermissionGate;

      expect(after, isNot(same(before)),
          reason: '$rule A gate that outlived the services it was built from '
              'would ask the previous seam, while the scope reads as the new '
              'one — a stale answer no caller could see was stale.');
      await after!.onResume();
      expect(second.requests, 1,
          reason: '$rule The rebuilt gate asks the seam that is installed now.');
    });

    testWidgets('#1 a user who denied the permission is not asked again on '
        'the next return to the list', (tester) async {
      final AppScope scope = openScope();
      addHabit(scope, 'Meditate',
          reminder: Reminder(8, 0, WeekdayList.everyDay));
      final _ScriptedPermissions permissions =
          _ScriptedPermissions(answerToRequest: false);
      startServices(scope, permissions: permissions);

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();
      expect(permissions.requests, 1,
          reason: '$rule A habit with a reminder is already there, so the '
              'launch asks — and the user taps Deny.');

      // Any screen over the list, opened and backed out of, twice.
      final NavigatorState navigator =
          Navigator.of(tester.element(find.byType(HabitListScreen)));
      for (int i = 0; i < 2; i++) {
        unawaited(navigator.push<void>(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SizedBox.shrink()),
        )));
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
      }

      expect(permissions.requests, 1,
          reason: '$rule `permissionAlreadyRequested` is a field of '
              '`ListHabitsActivity`, and `EditHabitActivity` does not destroy '
              'it — the flag survives the round trip, which is exactly the '
              'infinite `onResume` loop the comment upstream warns about '
              '(`reminders.app-start-and-permission#4`).');
    });

    testWidgets('#1 returning to a list with no reminders anywhere asks '
        'nothing', (tester) async {
      final AppScope scope = openScope();
      addHabit(scope, 'Meditate');
      final _ScriptedPermissions permissions = _ScriptedPermissions();
      startServices(scope, permissions: permissions);

      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      final NavigatorState navigator =
          Navigator.of(tester.element(find.byType(HabitListScreen)));
      unawaited(navigator.push<void>(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SizedBox.shrink()),
      )));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();

      expect(permissions.requests, 0,
          reason: '$rule The block is guarded on '
              '`reminderScheduler.hasHabitsWithReminders()`, so a user with no '
              'reminders is never shown the system dialog — on a pop no more '
              'than on a launch (`reminders.app-start-and-permission#6`).');
    });
  });
}
