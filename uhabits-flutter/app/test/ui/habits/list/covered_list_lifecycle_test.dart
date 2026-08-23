/// What the habit list must *not* do while another screen is on top of it.
///
/// `ListHabitsActivity.onPause` ends with `dismissCurrentDialog()` and
/// `onResume` starts the command-toast listener with `screen.onAttached()`.
/// Both are activity callbacks, so both are unreachable once another activity
/// covers the list: starting `EditHabitActivity` pauses and stops the list, and
/// a Home press, an incoming call or a notification-shade pull-down from there
/// runs *the editor's* lifecycle, never the list's. `EditHabitActivity`
/// dismisses nothing on a pause, so its colour picker, frequency picker,
/// target-type list, radial time picker and weekday picker all survive the
/// round trip (`audit7.backgrounding-the-app-or-just-pulling#1`), and the list
/// stays unregistered from the `CommandRunner` for the whole visit, so a
/// command finished up there produces that screen's own message and never the
/// list's toast (`audit7.after-a-background-round-trip-the#1`).
///
/// A Flutter app has one activity for the whole process: the list widget stays
/// mounted under the pushed route and hears every lifecycle callback the engine
/// sends. That is what the two rules above regressed on, and what is pinned
/// here — together with the control cases, because the sixth-pass behaviour
/// they narrow is correct whenever the list really is the screen on top.
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
import 'package:uhabits/ui/common/dialogs/color_picker_dialog.dart';
import 'package:uhabits/ui/common/dialogs/current_dialog.dart';
import 'package:uhabits/ui/common/screen_route_observer.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';
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
    tempDir = Directory.systemTemp.createTempSync('uhabits_covered_lifecycle');
  });

  tearDown(() {
    // The dialog slot is process-wide and a Dart test process is not torn down
    // between cases.
    resetCurrentDialog();
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final path = '${tempDir.path}/habits.db';
    final scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      databasePath: path,
      // Synchronous dispatchers, so `commandRunner.run(...)` has notified every
      // listener by the time it returns — what makes an assertion about
      // *whether* a listener ran deterministic.
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    // `BaseUserInterfaceTest.setUp`: an empty preference store IS a first run,
    // and a first run opens the intro over the list.
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
        // First wins, so this is the L10n the screens read; it writes down
        // every command toast it is asked for.
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

  /// The states the engine sends on the way out of the foreground, in the order
  /// the framework insists on — Android's `onPause` / `onStop` pair.
  void goToBackground(WidgetTester tester) {
    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  /// …and the way back in.
  Future<void> returnToForeground(WidgetTester tester) async {
    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  /// `startActivity(EditHabitActivity)` from the list.
  Future<void> openEditor(
    WidgetTester tester,
    AppScope scope,
    Habit habit,
  ) async {
    unawaited(navigatorOf(tester).push(
      EditHabitScreen.route(
        scope: scope,
        habitId: habit.id,
        habitType: habit.type,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('audit7.backgrounding-the-app-or-just-pulling', () {
    testWidgets('#1 a picker open on the edit-habit screen survives the app '
        'going to the background', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      await openEditor(tester, scope, habit);
      await tester.tap(find.byKey(EditHabitScreen.colorButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(ColorPickerDialog), findsOneWidget,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1 — the '
              'fixture is a picker open on the screen above the list');

      // The user presses Home, takes a call, and comes back.
      goToBackground(tester);
      await returnToForeground(tester);

      expect(find.byType(ColorPickerDialog), findsOneWidget,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1 — '
              'dismissCurrentDialog() is reached only from '
              'ListHabitsActivity.onPause, and that cannot run while '
              'EditHabitActivity is on top');
      expect(hasCurrentDialog, isTrue,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1 — and the '
              'slot still holds it, so the next picker still replaces it');
    });

    testWidgets('#1 pulling the notification shade down over the edit-habit '
        'screen leaves the picker alone', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      await openEditor(tester, scope, habit);
      await tester.tap(find.byKey(EditHabitScreen.colorButtonKey));
      await tester.pumpAndSettle();
      expect(find.byType(ColorPickerDialog), findsOneWidget,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1');

      // A shade pull-down is the mildest of the three: the app loses focus
      // without ever leaving the screen.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byType(ColorPickerDialog), findsOneWidget,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1 — the '
              'pickers stay on screen across a notification-shade pull-down');
    });

    testWidgets("#1 the list's own picker is still dismissed when the list is "
        'the screen on top', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final color = habit.color;
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      // The colour picker of the selection menu, opened from the list itself.
      await tester.longPress(find.text('Meditate'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('listHabitsSelection.overflowMenu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ListHabitsSelectionMenuItems.keyOf(
            ListHabitsSelectionMenuItems.color,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ColorPickerDialog), findsOneWidget,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1');

      goToBackground(tester);
      await returnToForeground(tester);

      expect(find.byType(ColorPickerDialog), findsNothing,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1 — with no '
              'activity above it the list is the one being paused, and its '
              'onPause still ends with dismissCurrentDialog() '
              '(`audit6.an-open-entry-popup-or-colour#1`)');
      expect(habit.color, color,
          reason: 'audit7.backgrounding-the-app-or-just-pulling#1 — a '
              'dismissal runs no command');
    });
  });

  group('audit7.after-a-background-round-trip-the', () {
    testWidgets('#1 a command finished after a background round trip taken '
        'from another screen raises no list toast', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      // The fixture: with the list in the foreground the listener is live.
      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();
      expect(toasts, <String>['Habit archived'],
          reason: 'audit7.after-a-background-round-trip-the#1 — the fixture '
              'has to start from a screen whose listener is attached');

      // `startActivity(ShowHabitActivity)`: the list is paused and unregistered
      // for as long as the pushed screen is on top of it.
      final navigator = navigatorOf(tester);
      unawaited(navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('detail')),
        ),
      ));
      await tester.pumpAndSettle();

      // …and the user backgrounds the app from up there and comes back. Only
      // that screen's onResume runs; the list's does not.
      goToBackground(tester);
      await returnToForeground(tester);
      toasts.clear();

      scope.commandRunner
          .run(UnarchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(toasts, isEmpty,
          reason: 'audit7.after-a-background-round-trip-the#1 — nothing '
              're-registers the list until the list activity itself resumes, '
              'so the screen on top shows only its own message');

      // Finishing that screen is what resumes the list — once.
      navigator.pop();
      await tester.pumpAndSettle();

      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(toasts, <String>['Habit archived'],
          reason: 'audit7.after-a-background-round-trip-the#1 — and the toast '
              'comes back exactly once when the list is on top again');
    });

    testWidgets('#1 the list toast still returns after a background round trip '
        'taken from the list itself', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      goToBackground(tester);
      await returnToForeground(tester);
      toasts.clear();

      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(toasts, <String>['Habit archived'],
          reason: 'audit7.after-a-background-round-trip-the#1 — the list '
              'activity really does run onResume when it is the one coming '
              'back, and registers the listener exactly once '
              '(`commands.listener-list-habits-toasts#1`)');
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
