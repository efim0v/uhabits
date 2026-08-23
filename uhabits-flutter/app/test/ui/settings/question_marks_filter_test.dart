/// `verify.question-marks-filter`: the habit list has to hear about the
/// question-marks preference.
///
/// `ListHabitsActivity` is a `Preferences.Listener` — `prefs.addListener(this)`
/// in `onCreate` — and its one override is
///
/// ```kotlin
/// override fun onQuestionMarksChanged() {
///     invalidateOptionsMenu()
///     menu.behavior.onPreferencesChanged()
/// }
/// ```
///
/// which swaps the adapter filter from `HabitMatcher(isCompletedAllowed = …)`
/// to `HabitMatcher(isEnteredAllowed = …)` while the settings screen is still
/// on top.
///
/// The whole test is driven through the UI: the "Hide completed" item comes
/// from the toolbar's filter menu and the switch is the real settings row, so
/// nothing here reaches into `ListHabitsMenuBehavior` — `onPreferencesChanged`
/// having no caller in `app/lib` is the defect.
///
/// The habit it uses is *entered but not completed*: a boolean habit whose
/// entry for today is `Entry.NO`. That is the one state the two matchers
/// disagree about — `isCompletedToday()` is false, `isEnteredToday()` is true —
/// so it is visible under "hide completed" until question marks are switched
/// on and invisible afterwards.
library;

// The core layers are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_question_marks');
  });

  tearDown(() {
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

  Future<void> tapMenuItem(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ListHabitsMenuItems.keyOf(id)));
    await tester.pumpAndSettle();
  }

  testWidgets('#1, #2 turning question marks on re-applies the list filter '
      'while the user is still in Settings', (tester) async {
    final AppScope scope = openScope();
    final Habit habit = scope.modelFactory.buildHabit()..name = 'Meditate';
    scope.habitList.add(habit);
    habit.recompute();

    await tester.pumpWidget(UhabitsApp(scope: scope));
    await tester.pumpAndSettle();

    // A lapse: an entry for today, and not a completion.
    scope.commandRunner.run(
      CreateRepetitionCommand(scope.habitList, habit, getToday(), Entry.no, ''),
    );
    await tester.pumpAndSettle();
    expect(habit.isEnteredToday(), isTrue);
    expect(habit.isCompletedToday(), isFalse);

    // Toolbar -> filter -> "Hide completed".
    await tester.tap(
      find.byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.filter)),
    );
    await tester.pumpAndSettle();
    await tapMenuItem(tester, ListHabitsMenuItems.hideCompleted);

    expect(scope.preferences.showCompleted, isFalse,
        reason: 'verify.question-marks-filter#1: the user has "Hide '
            'completed" on.');
    expect(find.text('Meditate'), findsOneWidget,
        reason: 'verify.question-marks-filter#1: with question marks off the '
            'filter is HabitMatcher(isCompletedAllowed: showCompleted), and a '
            'lapse is not a completion — the habit is still listed.');

    // Toolbar -> overflow -> Settings.
    await tester.tap(
      find.byKey(const ValueKey<String>('listHabits.overflowMenu')),
    );
    await tester.pumpAndSettle();
    await tapMenuItem(tester, ListHabitsMenuItems.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // The real "Show question marks for missing data" row.
    final Finder questionMarks = find.descendant(
      of: find.byKey(const ValueKey<String>('pref_unknown_enabled')),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(questionMarks);
    await tester.pumpAndSettle();
    await tester.tap(questionMarks);
    await tester.pumpAndSettle();

    expect(scope.preferences.areQuestionMarksEnabled, isTrue,
        reason: 'verify.question-marks-filter#1: flipping the switch fires '
            'Preferences.Listener.onQuestionMarksChanged().');
    expect(scope.adapter.itemCount, 0,
        reason: 'verify.question-marks-filter#1: the list activity rebuilds '
            'its menu and calls menu.behavior.onPreferencesChanged(), which '
            'swaps the adapter filter from HabitMatcher(isCompletedAllowed: '
            'showCompleted) to HabitMatcher(isEnteredAllowed: showCompleted) '
            'immediately. #2: the port never registers the list screen or its '
            'model as a Preferences.Listener, so `onPreferencesChanged` has '
            'no caller outside packages/uhabits_core/test.');

    // Back to the list.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Meditate'), findsNothing,
        reason: 'verify.question-marks-filter#2: a user who has "Hide '
            'completed" on and then enables question marks must not come back '
            'to a list still filtered by isCompletedAllowed.');

    // …and the swap is a swap, not a one-way door: turning question marks
    // back off restores the isCompletedAllowed filter, and the lapse returns.
    await tester.tap(
      find.byKey(const ValueKey<String>('listHabits.overflowMenu')),
    );
    await tester.pumpAndSettle();
    await tapMenuItem(tester, ListHabitsMenuItems.settings);
    await tester.ensureVisible(questionMarks);
    await tester.pumpAndSettle();
    await tester.tap(questionMarks);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(scope.preferences.areQuestionMarksEnabled, isFalse);
    expect(find.text('Meditate'), findsOneWidget,
        reason: 'verify.question-marks-filter#1: the filter follows the '
            'preference in both directions — ListHabitsMenuBehavior'
            '._updateAdapterFilter picks its matcher from '
            'areQuestionMarksEnabled every time it runs.');
  });
}
