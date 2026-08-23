/// The lifetime of the habit list's command-toast listener.
///
/// `ListHabitsScreen.onAttached()` registers with the `CommandRunner` and is
/// called from `ListHabitsActivity.onResume`; `onDetached()` unregisters and is
/// called from `onPause`. Starting `ShowHabitActivity`, `EditHabitActivity` or
/// `SettingsActivity` pauses the list activity, so a command run from one of
/// those screens produces no list toast at all — the detail screen shows its
/// own `ShowHabitMenuPresenter.Message` instead
/// (`commands.listener-list-habits-toasts#1`, `#6`).
///
/// The port attached the listener in `initState` and detached it in `dispose`,
/// which are mount and unmount rather than resume and pause, so the listener
/// kept firing under whatever screen was on top.
///
/// The listener is watched here through the strings it looks up rather than
/// through the snackbar it raises: a `ScaffoldMessenger` whose route is covered
/// keeps the snackbar it is showing and renders nothing new, so the pixels say
/// the same thing whether the listener ran or not. `getExecuteString` asks the
/// ambient [L10n] for the toast text before it hands it to `showMessage`, so a
/// recording localization is a direct account of every toast the screen tried
/// to show.
library;

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/screen_route_observer.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_command_toasts.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart'
    show UnconfinedTestDispatcher;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  final toasts = <String>[];

  setUp(() {
    resetToday();
    toasts.clear();
    tempDir = Directory.systemTemp.createTempSync('uhabits_toast_lifecycle');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
      // Synchronous dispatchers, so `commandRunner.run(...)` has notified every
      // listener by the time it returns — the property `BaseUnitTest` gives the
      // Kotlin command tests, and the one that makes the assertions below about
      // *whether* a listener ran deterministic.
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    // `BaseUserInterfaceTest.setUp`: a scope over an empty preference store is
    // a first run, and a first run opens the intro over the list.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, String name) {
    final habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Widget wrap(AppScope scope) => MaterialApp(
        // First wins, so this is the L10n the screen reads.
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          _RecordingL10nDelegate(toasts),
          ...L10n.localizationsDelegates,
        ],
        supportedLocales: L10n.supportedLocales,
        // What `UhabitsApp` installs: the observer that tells a screen another
        // screen has been pushed over it.
        navigatorObservers: <NavigatorObserver>[screenRouteObserver],
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  NavigatorState navigatorOf(WidgetTester tester) =>
      Navigator.of(tester.element(find.byType(HabitListScreen)));

  group('audit5.the-habit-list-command-toast-listener', () {
    testWidgets('a command run while another screen is on top produces no '
        'list toast', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      // The fixture: with the list in the foreground the listener is live.
      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();
      expect(toasts, <String>['Habit archived'],
          reason: 'commands.listener-list-habits-toasts#1 — the fixture has to '
              'start from a screen whose listener is attached');

      // `startActivity(ShowHabitActivity)`: the list activity is paused for as
      // long as the pushed screen is on top of it.
      final navigator = navigatorOf(tester);
      unawaited(navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail')),
        ),
      ));
      await tester.pumpAndSettle();
      toasts.clear();

      scope.commandRunner
          .run(UnarchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(toasts, isEmpty,
          reason: 'audit5.the-habit-list-command-toast-listener#1 — '
              'ListHabitsActivity.onPause runs screen.onDetached(), so a '
              'command run from the screen on top never reaches the list');

      // `onResume` -> `onAttached()`: back on the list, the toasts return.
      navigator.pop();
      await tester.pumpAndSettle();

      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(toasts, <String>['Habit archived'],
          reason: 'audit5.the-habit-list-command-toast-listener#1 — and '
              'onResume registers it again, exactly once');
    });

    testWidgets('a command run while the app is in the background produces no '
        'list toast either', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      // `ListHabitsActivity.onPause`, the other half of the Android pair.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      toasts.clear();

      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(toasts, isEmpty,
          reason: 'audit5.the-habit-list-command-toast-listener#1 — toasts '
              'appear only while the habit list screen is in the foreground');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      scope.commandRunner
          .run(UnarchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(toasts, <String>['Habit unarchived'],
          reason: 'audit5.the-habit-list-command-toast-listener#1 — and one '
              'toast, not two, when it comes back');
    });

    test('a second onAttached does not register the listener twice', () {
      // `CommandRunner.addListener` appends without a duplicate check, so a
      // resume that re-attaches an already-attached listener would show every
      // toast twice. Android cannot reach that state — onResume always follows
      // an onPause — and neither may the port.
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final messages = <String>[];
      final listener = ListHabitsCommandToasts(
        commandRunner: scope.commandRunner,
        strings: L10nEn.new,
        showMessage: messages.add,
      )
        ..onAttached()
        ..onAttached();

      scope.commandRunner.notifyListeners(
        ArchiveHabitsCommand(scope.habitList, <Habit>[habit]),
      );

      expect(messages, hasLength(1),
          reason: 'audit5.the-habit-list-command-toast-listener#1 — the '
              'listener is registered once, whatever the sequence of resumes');

      listener.onDetached();
      scope.commandRunner.notifyListeners(
        UnarchiveHabitsCommand(scope.habitList, <Habit>[habit]),
      );
      expect(messages, hasLength(1),
          reason: 'audit5.the-habit-list-command-toast-listener#1 — and one '
              'onDetached is enough to stop it');
    });
  });
}

/// An English [L10n] that writes down every command toast it is asked for.
class _RecordingL10n extends L10nEn {
  _RecordingL10n(this.toasts);

  final List<String> toasts;

  @override
  String toastHabitsArchived(num count) {
    final message = super.toastHabitsArchived(count);
    toasts.add(message);
    return message;
  }

  @override
  String toastHabitsUnarchived(num count) {
    final message = super.toastHabitsUnarchived(count);
    toasts.add(message);
    return message;
  }
}

class _RecordingL10nDelegate extends LocalizationsDelegate<L10n> {
  const _RecordingL10nDelegate(this.toasts);

  final List<String> toasts;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<L10n> load(Locale locale) =>
      SynchronousFuture<L10n>(_RecordingL10n(toasts));

  @override
  bool shouldReload(_RecordingL10nDelegate old) => false;
}
