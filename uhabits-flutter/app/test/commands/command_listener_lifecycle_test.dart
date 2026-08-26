/// Who listens to the command runner, in what order, and for how long.
///
/// Two features meet here:
///
///  * `commands.listener-screen-refresh` — `ShowHabitActivity` and
///    `HistoryEditorDialog` both implement `CommandRunner.Listener`, both
///    register in `onResume` and unregister in `onPause`, and both refresh
///    everything they show for *every* command, whatever it was and whichever
///    habit it touched.
///  * `commands.command-runner-listeners#6` and `#8` — the three app-scoped
///    listeners register at startup in a fixed order and stop in a different
///    fixed order at terminate, with screen-level listeners always behind them.
library;

// The commands, preferences, tasks and presenters are reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart' show AlarmPlugin;
import 'package:uhabits/platform/flutter_notification_tray.dart'
    show NotificationSpec, ReminderNotificationBuilder;
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/platform/sleep_prompt_scheduler.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/theme/app_theme.dart' show appThemeData;
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  var nextDatabase = 0;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() {
    core.resetToday();
    HistoryEditorDialog.currentDialog = null;
    tempDir = Directory.systemTemp.createTempSync('uhabits_command_listeners');
    nextDatabase = 0;
  });

  tearDown(() {
    for (final scope in scopes) {
      try {
        scope.close();
      } on Object {
        // Already closed by the test itself.
      }
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
    core.resetToday();
  });

  /// Synchronous dispatchers, so `commandRunner.run(...)` has notified every
  /// listener by the time it returns — the property `BaseUnitTest` gives the
  /// Kotlin command tests.
  AppScope openScope({
    Dispatcher dispatcher = const UnconfinedTestDispatcher(),
  }) {
    final path = '${tempDir.path}/habits${nextDatabase++}.db';
    final scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      databasePath: path,
      mainDispatcher: dispatcher,
      ioDispatcher: dispatcher,
    );
    scopes.add(scope);
    return scope;
  }

  core.Habit addHabit(
    AppScope scope,
    String name, {
    core.PaletteColor color = const core.PaletteColor(8),
    core.Reminder? reminder,
  }) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..color = color
      ..reminder = reminder;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  // =======================================================================
  // commands.listener-screen-refresh
  // =======================================================================

  group('commands.listener-screen-refresh', () {
    test('#1 ShowHabitActivity registers in onResume, unregisters in onPause, '
        'and refreshes for every command type', () {
      final scope = openScope();
      // `AppScope.open` is `HabitsApplication.onCreate`: it stamps today.
      final today = core.getToday();
      final habit = addHabit(scope, 'Meditate');
      final model = ShowHabitModel(
        scope: scope,
        habit: habit,
        theme: core.LightTheme(),
      );
      addTearDown(model.dispose);

      // Before onResume nothing is registered, so nothing refreshes.
      final beforeAttach = model.state;
      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <core.Habit>[habit]));
      expect(identical(model.state, beforeAttach), isTrue,
          reason: 'commands.listener-screen-refresh#1 — the listener is only '
              'registered from onResume');

      model.attach();
      // `attach()` is onResume, which registers AND refreshes.
      for (final command in <Command>[
        UnarchiveHabitsCommand(scope.habitList, <core.Habit>[habit]),
        ChangeHabitColorCommand(
          scope.habitList,
          <core.Habit>[habit],
          const core.PaletteColor(2),
        ),
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          today,
          core.Entry.yesManual,
          '',
        ),
      ]) {
        final before = model.state;
        scope.commandRunner.run(command);
        expect(identical(model.state, before), isFalse,
            reason: 'commands.listener-screen-refresh#1 — onCommandFinished '
                'calls screen.refresh() for EVERY command type without '
                'inspecting the command (${command.runtimeType})');
      }

      model.detach();
      final afterDetach = model.state;
      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <core.Habit>[habit]));
      expect(identical(model.state, afterDetach), isTrue,
          reason: 'commands.listener-screen-refresh#1 — onPause unregisters, '
              'so a paused detail screen no longer refreshes');
    });

    test('#2 refresh() rebuilds the whole presenter state from the habit', () {
      final scope = openScope();
      // `AppScope.open` is `HabitsApplication.onCreate`: it stamps today.
      final today = core.getToday();
      final habit = addHabit(scope, 'Meditate');
      final model = ShowHabitModel(
        scope: scope,
        habit: habit,
        theme: core.LightTheme(),
      )..attach();
      addTearDown(model.dispose);

      final before = model.state;
      expect(before.streaks.bestStreaks, isEmpty,
          reason: 'commands.listener-screen-refresh#2 — nothing to show yet');

      // Three consecutive days, written straight onto the model — the state is
      // only rebuilt when a command finishes.
      for (var i = 0; i < 3; i++) {
        habit.originalEntries
            .add(core.Entry(today.minus(i), core.Entry.yesManual));
      }
      habit.recompute();
      expect(identical(model.state, before), isTrue,
          reason: 'commands.listener-screen-refresh#2 — and nothing rebuilds '
              'it on its own');

      scope.commandRunner.run(
        ChangeHabitColorCommand(
          scope.habitList,
          <core.Habit>[habit],
          const core.PaletteColor(3),
        ),
      );

      final after = model.state;
      expect(identical(after, before), isFalse,
          reason: 'commands.listener-screen-refresh#2 — screen.refresh() '
              'rebuilds the whole ShowHabitPresenter state and re-renders');
      expect(after.streaks.bestStreaks, isNotEmpty,
          reason: 'commands.listener-screen-refresh#2 — streaks are rebuilt');
      expect(after.scores.scores, isNotEmpty,
          reason: 'commands.listener-screen-refresh#2 — scores are rebuilt');
      expect(after.frequency.frequency, isNotEmpty,
          reason: 'commands.listener-screen-refresh#2 — the frequency card is '
              'rebuilt');
      expect(after.history.series, isNotEmpty,
          reason: 'commands.listener-screen-refresh#2 — so is the history');
      expect(after.bar.entries, isNotEmpty,
          reason: 'commands.listener-screen-refresh#2 — and the bar card');
      expect(after.color, const core.PaletteColor(3),
          reason: 'commands.listener-screen-refresh#2 — everything comes from '
              'the CURRENT habit, including the colour the command just wrote');
    });

    testWidgets('#3 HistoryEditorDialog refreshes its chart on every command',
        (tester) async {
      final scope = openScope();
      // `AppScope.open` is `HabitsApplication.onCreate`: it stamps today.
      final today = core.getToday();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: appThemeData(core.LightTheme()),
          home: Scaffold(
            body: HistoryEditorDialog(
              habit: habit,
              habitList: scope.habitList,
              commandRunner: scope.commandRunner,
              preferences: scope.preferences,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      HistoryChart chart() => tester
          .widget<CoreView>(
            find.descendant(
              of: find.byType(HistoryEditorDialog),
              matching: find.byType(CoreView),
            ),
          )
          .view as HistoryChart;

      expect(chart().series.every((s) => s == Square.off), isTrue,
          reason: 'commands.listener-screen-refresh#3 — an empty habit draws '
              'nothing but OFF squares');

      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          today,
          core.Entry.yesManual,
          '',
        ),
      );
      await tester.pumpAndSettle();

      expect(chart().series.first, Square.on,
          reason: 'commands.listener-screen-refresh#3 — onCommandFinished '
              'calls refreshData(), rebuilding the series via '
              'HistoryCardPresenter.buildState');
      expect(chart().notesIndicators, isNotEmpty,
          reason: 'commands.listener-screen-refresh#3 — refreshData() rebuilds '
              'the notes indicators too');

      // A command of an entirely different kind refreshes it just the same.
      scope.commandRunner.run(
        ChangeHabitColorCommand(
          scope.habitList,
          <core.Habit>[habit],
          const core.PaletteColor(5),
        ),
      );
      await tester.pumpAndSettle();
      expect(chart().series.first, Square.on,
          reason: 'commands.listener-screen-refresh#3 — for every command '
              'type, not just entry edits');

      // onPause: the dialog goes away and takes its subscription with it.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(
        () => scope.commandRunner.run(
          ChangeHabitColorCommand(
            scope.habitList,
            <core.Habit>[habit],
            const core.PaletteColor(6),
          ),
        ),
        returnsNormally,
        reason: 'commands.listener-screen-refresh#3 — after onPause the dialog '
            'is no longer on the runner, so a later command reaches nobody '
            'inside it',
      );
    });

    testWidgets('#4 one CreateRepetitionCommand refreshes the detail screen '
        'and the open history editor together', (tester) async {
      final scope = openScope();
      // `AppScope.open` is `HabitsApplication.onCreate`: it stamps today.
      final today = core.getToday();
      final habit = addHabit(scope, 'Meditate');
      final model = ShowHabitModel(
        scope: scope,
        habit: habit,
        theme: core.LightTheme(),
      )..attach();
      addTearDown(model.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: appThemeData(core.LightTheme()),
          home: Scaffold(
            body: HistoryEditorDialog(
              habit: habit,
              habitList: scope.habitList,
              commandRunner: scope.commandRunner,
              preferences: scope.preferences,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      HistoryChart chart() => tester
          .widget<CoreView>(
            find.descendant(
              of: find.byType(HistoryEditorDialog),
              matching: find.byType(CoreView),
            ),
          )
          .view as HistoryChart;

      final beforeState = model.state;
      expect(chart().series.first, Square.off);

      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          today,
          core.Entry.yesManual,
          '',
        ),
      );
      await tester.pumpAndSettle();

      expect(identical(model.state, beforeState), isFalse,
          reason: 'commands.listener-screen-refresh#4 — both listeners are '
              'active while the history editor is open over the detail '
              'screen, so the detail screen refreshed');
      expect(chart().series.first, Square.on,
          reason: 'commands.listener-screen-refresh#4 — and a single '
              'CreateRepetitionCommand refreshed the dialog as well');
    });

    testWidgets('#5 a command touching a different habit still refreshes both',
        (tester) async {
      final scope = openScope();
      // `AppScope.open` is `HabitsApplication.onCreate`: it stamps today.
      final today = core.getToday();
      final shown = addHabit(scope, 'Meditate');
      final other = addHabit(scope, 'Run');
      final model = ShowHabitModel(
        scope: scope,
        habit: shown,
        theme: core.LightTheme(),
      )..attach();
      addTearDown(model.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: appThemeData(core.LightTheme()),
          home: Scaffold(
            body: HistoryEditorDialog(
              habit: shown,
              habitList: scope.habitList,
              commandRunner: scope.commandRunner,
              preferences: scope.preferences,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      HistoryChart chart() => tester
          .widget<CoreView>(
            find.descendant(
              of: find.byType(HistoryEditorDialog),
              matching: find.byType(CoreView),
            ),
          )
          .view as HistoryChart;

      // A change to the *shown* habit that no command announced: neither
      // listener has any reason to know about it yet.
      shown.originalEntries.add(core.Entry(today, core.Entry.yesManual));
      shown.recompute();
      final before = model.state;
      expect(chart().series.first, Square.off,
          reason: 'commands.listener-screen-refresh#5 — nothing has refreshed '
              'yet, so neither view shows the new entry');

      // A command about an entirely different habit.
      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          other,
          today,
          core.Entry.yesManual,
          '',
        ),
      );
      await tester.pumpAndSettle();

      expect(identical(model.state, before), isFalse,
          reason: 'commands.listener-screen-refresh#5 — neither listener '
              'filters by habit: a command touching a different habit still '
              'triggers a full refresh of the visible one');
      expect(model.state.title, 'Meditate',
          reason: 'commands.listener-screen-refresh#5 — and what it refreshes '
              'is still the habit it was opened with');
      expect(chart().series.first, Square.on,
          reason: 'commands.listener-screen-refresh#5 — the history editor '
              'refreshed too, and picked up the shown habit\'s entry, even '
              'though the command named another habit entirely');
    });
  });

  // =======================================================================
  // commands.command-runner-listeners#6 and #8
  // =======================================================================

  group('commands.command-runner-listeners', () {
    test('#6 the three app-scoped listeners register in order, and a '
        'screen-level listener lands behind them', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final calls = <String>[];

      final tray = NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _FakeSystemTray(calls),
      );
      final scheduler = ReminderScheduler(
        scope.commandRunner,
        scope.habitList,
        _FakeSystemScheduler(calls),
        WidgetPreferences(scope.preferencesStorage),
      );
      final sync = WidgetSync(
        bridge: HomeWidgetBridge(
          habitList: scope.habitList,
          registry: WidgetRegistry(scope.preferencesStorage),
          platform: _SilentHomeWidgetPlatform(),
        ),
        commandRunner: scope.commandRunner,
        // The widget publish itself is asynchronous; the note is taken at the
        // moment `WidgetUpdater.onCommandFinished` hands its work over, which
        // is synchronous and therefore ordered.
        taskRunner: _RecordingTaskRunner(scope.taskRunner, calls),
        midnightTimer: scope.midnightTimer,
        preferences: scope.preferences,
      );

      // Steps (7), (8) and (9) of HabitsApplication.onCreate.
      scope.startServices(tray: tray, scheduler: scheduler, sync: sync);
      calls.clear();

      // A screen-level listener, registered later — ListHabitsScreen.onAttached,
      // ShowHabitActivity.onResume, HistoryEditorDialog.onResume.
      final screen = _NamedListener(calls, 'screen');
      scope.commandRunner.addListener(screen);

      // DeleteHabitsCommand is the one command all three react to.
      scope.commandRunner
          .run(DeleteHabitsCommand(scope.habitList, <core.Habit>[habit]));

      expect(
        calls,
        <String>[
          'widgets.update',
          'scheduler.scheduleAll',
          'tray.remove(${habit.id})',
          'screen',
        ],
        reason: 'commands.command-runner-listeners#6 — listeners register as '
            'WidgetUpdater, then ReminderScheduler, then NotificationTray, and '
            'screen-level listeners register later, so they are always '
            'notified after the three app-scoped ones',
      );

      // onPause: the screen listener leaves, the three stay.
      scope.commandRunner.removeListener(screen);
      calls.clear();
      final second = addHabit(scope, 'Run');
      scope.commandRunner
          .run(DeleteHabitsCommand(scope.habitList, <core.Habit>[second]));
      expect(calls, isNot(contains('screen')),
          reason: 'commands.command-runner-listeners#6 — screen-level '
              'listeners unregister in onPause');
      expect(calls.first, 'widgets.update',
          reason: 'commands.command-runner-listeners#6 — while the app-scoped '
              'three keep their order for the life of the process');
    });

    test('#8 close() stops the three in the order onTerminate uses', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final calls = <String>[];

      final tray = _RecordingTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _FakeSystemTray(calls),
        calls,
      );
      final scheduler = _RecordingScheduler(
        scope.commandRunner,
        scope.habitList,
        _FakeSystemScheduler(calls),
        WidgetPreferences(scope.preferencesStorage),
        calls,
      );
      final sync = _RecordingSync(
        calls,
        bridge: HomeWidgetBridge(
          habitList: scope.habitList,
          registry: WidgetRegistry(scope.preferencesStorage),
          platform: _SilentHomeWidgetPlatform(),
        ),
        commandRunner: scope.commandRunner,
        taskRunner: _RecordingTaskRunner(scope.taskRunner, calls),
        midnightTimer: scope.midnightTimer,
        preferences: scope.preferences,
      );
      scope.startServices(tray: tray, scheduler: scheduler, sync: sync);
      calls.clear();

      scope.close();
      scopes.remove(scope);

      expect(
        calls,
        <String>['scheduler.stop', 'widgets.stop', 'tray.stop'],
        reason: 'commands.command-runner-listeners#8 — on app terminate the '
            'order is reminderScheduler.stopListening(), '
            'widgetUpdater.stopListening(), notificationTray.stopListening()',
      );

      // And they really left the registry: notifying the scope's own runner
      // after close() must reach none of them.
      calls.clear();
      scope.commandRunner.notifyListeners(
        DeleteHabitsCommand(scope.habitList, <core.Habit>[habit]),
      );
      expect(calls, isEmpty,
          reason: 'commands.command-runner-listeners#8 — stopListening() means '
              'removeListener(this): a later command reaches none of them');
    });

    test('the computed-habit hooks come off with the scope', () {
      final scope = openScope();
      final tray = NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _FakeSystemTray(<String>[]),
      );
      final scheduler = ReminderScheduler(
        scope.commandRunner,
        scope.habitList,
        _FakeSystemScheduler(<String>[]),
        WidgetPreferences(scope.preferencesStorage),
      );
      final sync = WidgetSync(
        bridge: HomeWidgetBridge(
          habitList: scope.habitList,
          registry: WidgetRegistry(scope.preferencesStorage),
          platform: _SilentHomeWidgetPlatform(),
        ),
        commandRunner: scope.commandRunner,
        taskRunner: scope.taskRunner,
        midnightTimer: scope.midnightTimer,
        preferences: scope.preferences,
      );
      // Steps (7), (8) and (9) — the same sequence that registers the
      // computed-habit hooks alongside the three app-scoped listeners.
      scope.startServices(tray: tray, scheduler: scheduler, sync: sync);

      final int before = scope.commandRunner.listenerCount;
      scope.close();
      scopes.remove(scope);

      expect(scope.commandRunner.listenerCount, lessThan(before),
          reason: 'computed.lifecycle#2');
    });

    // =====================================================================
    // computed.lifecycle#2, exercised through the real wiring rather than
    // the count above: `listenerCount` proves *a* listener came off, not
    // that it was the right one and not that it did anything while it was
    // on. These three call through a real `SleepPromptScheduler` into a
    // recording `AlarmPlugin`, so the assertion is on the notification id
    // the fake actually saw rather than on a boolean "something happened".
    // =====================================================================

    test(
        'deleting a habit cancels its sleep prompt through the real '
        'scheduler', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Sleep');
      final alarms = _RecordingAlarms();
      final prompts = SleepPromptScheduler(
        alarms: alarms,
        builder: ReminderNotificationBuilder(preferences: scope.preferences),
      );

      scope.startServices(
        tray: NotificationTray(
          scope.taskRunner,
          scope.commandRunner,
          scope.preferences,
          _FakeSystemTray(<String>[]),
        ),
        scheduler: ReminderScheduler(
          scope.commandRunner,
          scope.habitList,
          _FakeSystemScheduler(<String>[]),
          WidgetPreferences(scope.preferencesStorage),
        ),
        sync: WidgetSync(
          bridge: HomeWidgetBridge(
            habitList: scope.habitList,
            registry: WidgetRegistry(scope.preferencesStorage),
            platform: _SilentHomeWidgetPlatform(),
          ),
          commandRunner: scope.commandRunner,
          taskRunner: scope.taskRunner,
          midnightTimer: scope.midnightTimer,
          preferences: scope.preferences,
        ),
        sleepPrompts: prompts,
      );

      scope.commandRunner
          .run(DeleteHabitsCommand(scope.habitList, <core.Habit>[habit]));

      // Not merely "a callback ran": the id the fake saw is derived from
      // this exact habit, so a closure that dropped the argument, cancelled
      // the wrong habit, or never reached the scheduler at all would not
      // produce it either.
      expect(alarms.cancelled, <int>[sleepPromptNotificationId(habit)],
          reason: 'computed.lifecycle#2');
    });

    test('archiving a habit cancels its sleep prompt too', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Sleep');
      final alarms = _RecordingAlarms();
      final prompts = SleepPromptScheduler(
        alarms: alarms,
        builder: ReminderNotificationBuilder(preferences: scope.preferences),
      );

      scope.startServices(
        tray: NotificationTray(
          scope.taskRunner,
          scope.commandRunner,
          scope.preferences,
          _FakeSystemTray(<String>[]),
        ),
        scheduler: ReminderScheduler(
          scope.commandRunner,
          scope.habitList,
          _FakeSystemScheduler(<String>[]),
          WidgetPreferences(scope.preferencesStorage),
        ),
        sync: WidgetSync(
          bridge: HomeWidgetBridge(
            habitList: scope.habitList,
            registry: WidgetRegistry(scope.preferencesStorage),
            platform: _SilentHomeWidgetPlatform(),
          ),
          commandRunner: scope.commandRunner,
          taskRunner: scope.taskRunner,
          midnightTimer: scope.midnightTimer,
          preferences: scope.preferences,
        ),
        sleepPrompts: prompts,
      );

      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <core.Habit>[habit]));

      expect(alarms.cancelled, <int>[sleepPromptNotificationId(habit)],
          reason: 'computed.lifecycle#2');
    });

    test('after close(), a finished command cancels no sleep prompt', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Sleep');
      final alarms = _RecordingAlarms();
      final prompts = SleepPromptScheduler(
        alarms: alarms,
        builder: ReminderNotificationBuilder(preferences: scope.preferences),
      );

      scope.startServices(
        tray: NotificationTray(
          scope.taskRunner,
          scope.commandRunner,
          scope.preferences,
          _FakeSystemTray(<String>[]),
        ),
        scheduler: ReminderScheduler(
          scope.commandRunner,
          scope.habitList,
          _FakeSystemScheduler(<String>[]),
          WidgetPreferences(scope.preferencesStorage),
        ),
        sync: WidgetSync(
          bridge: HomeWidgetBridge(
            habitList: scope.habitList,
            registry: WidgetRegistry(scope.preferencesStorage),
            platform: _SilentHomeWidgetPlatform(),
          ),
          commandRunner: scope.commandRunner,
          taskRunner: scope.taskRunner,
          midnightTimer: scope.midnightTimer,
          preferences: scope.preferences,
        ),
        sleepPrompts: prompts,
      );

      // The mechanism really is live before close() — otherwise its silence
      // afterwards would prove nothing.
      scope.commandRunner
          .run(DeleteHabitsCommand(scope.habitList, <core.Habit>[habit]));
      expect(alarms.cancelled, isNotEmpty,
          reason: 'computed.lifecycle#2 — sanity check that the hook is '
              'wired before close(), so its silence afterwards means '
              'something');
      alarms.cancelled.clear();

      scope.close();
      scopes.remove(scope);

      // Bypasses run(): close() just released the connection, the same
      // reason commands.command-runner-listeners#8 above calls
      // notifyListeners directly rather than running a command post-close.
      scope.commandRunner.notifyListeners(
        DeleteHabitsCommand(scope.habitList, <core.Habit>[habit]),
      );
      expect(alarms.cancelled, isEmpty,
          reason: 'computed.lifecycle#2 — close() takes the hook off the '
              'runner, the same as the three platform listeners above');
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _NamedListener implements CommandRunnerListener {
  _NamedListener(this.calls, this.name);

  final List<String> calls;
  final String name;

  @override
  void onCommandFinished(Command command) => calls.add(name);
}

/// [AlarmPlugin], reduced to a note of the ids it was told to cancel.
class _RecordingAlarms implements AlarmPlugin {
  final List<int> cancelled = <int>[];

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async {}

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;
}

/// `AndroidNotificationTray`, reduced to a note.
class _FakeSystemTray implements SystemTray {
  _FakeSystemTray(this.calls);

  final List<String> calls;

  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) =>
      calls.add('tray.remove($notificationId)');

  @override
  void showNotification(
    core.Habit habit,
    int notificationId,
    core.LocalDate date,
    int reminderTime,
  ) =>
      calls.add('tray.show(${habit.id})');
}

/// `IntentScheduler`, reduced to a note.
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
    core.Habit habit,
    int timestamp,
  ) =>
      SchedulerResult.ok;

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => SchedulerResult.ok;
}

/// The `home_widget` plugin, doing nothing at all.
class _SilentHomeWidgetPlatform implements HomeWidgetPlatform {
  @override
  Future<void> saveWidgetData(String id, String? value) async {}

  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> updateWidget({
    required String name,
    required String qualifiedAndroidName,
    required String iOSName,
  }) async {}
}

/// Notes the instant `WidgetUpdater.onCommandFinished` hands its publish to the
/// task runner — the synchronous half of an otherwise asynchronous step.
class _RecordingTaskRunner implements TaskRunner {
  _RecordingTaskRunner(this.inner, this.calls);

  final TaskRunner inner;
  final List<String> calls;

  @override
  void execute(Task task) {
    calls.add('widgets.update');
    inner.execute(task);
  }

  @override
  void addListener(TaskRunnerListener listener) => inner.addListener(listener);

  @override
  void removeListener(TaskRunnerListener listener) =>
      inner.removeListener(listener);

  @override
  void publishProgress(Task task, int progress) =>
      inner.publishProgress(task, progress);

  @override
  int get activeTaskCount => inner.activeTaskCount;

  @override
  Future<void> awaitAll() => inner.awaitAll();
}

class _RecordingTray extends NotificationTray {
  _RecordingTray(
    super.taskRunner,
    super.commandRunner,
    super.preferences,
    super.systemTray,
    this.calls,
  );

  final List<String> calls;

  @override
  void stopListening() {
    calls.add('tray.stop');
    super.stopListening();
  }
}

class _RecordingScheduler extends ReminderScheduler {
  _RecordingScheduler(
    super.commandRunner,
    super.habitList,
    super.sys,
    super.widgetPreferences,
    this.calls,
  );

  final List<String> calls;

  @override
  void stopListening() {
    calls.add('scheduler.stop');
    super.stopListening();
  }
}

class _RecordingSync extends WidgetSync {
  _RecordingSync(
    this.calls, {
    required super.bridge,
    required super.commandRunner,
    required super.taskRunner,
    required super.midnightTimer,
    required super.preferences,
  });

  final List<String> calls;

  @override
  void stopListening() {
    calls.add('widgets.stop');
    super.stopListening();
  }
}
