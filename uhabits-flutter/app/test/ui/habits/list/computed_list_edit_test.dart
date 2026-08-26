/// The habit list's door onto a computed habit's day.
///
/// A tap on a numerical habit's cell in the list is `onEdit`, which opens the
/// number popup and writes what comes back with `CreateRepetitionCommand`. A
/// computed habit has no typed value to keep, so the list already turned that
/// gesture aside — but it asked whether the habit had a *sleep goal*, which is
/// a narrower question than the one it means: any computed habit's value is
/// the app's to write, and only some of them will ever have a goal.
///
/// The same door on the habit's own screen is pinned by
/// `test/ui/sleep/calendar_editor_guard_test.dart`.
library;

// The core's models and repositories are reached by their `src` path, exactly
// as lib/state and lib/ui do.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/sleep/manual_entry_sheet.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_computed_list_edit');
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
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Habit addNumerical(AppScope scope, String name) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = HabitType.numerical
      ..unit = 'pages'
      ..targetValue = 100;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Widget wrap(AppScope scope) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  Future<void> tapTodaysCell(WidgetTester tester, AppScope scope) async {
    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();
  }

  testWidgets('a computed habit that is not a sleep habit is refused the '
      'number popup', (tester) async {
    // The layer's second inhabitant: a definition and no sleep goal at all.
    final AppScope scope = openScope();
    final Habit habit = addNumerical(scope, 'Sober');
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.abstinence));

    await tapTodaysCell(tester, scope);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.write-paths#3');
    expect(habit.originalEntries.getKnown(), isEmpty,
        reason: 'computed.write-paths#3 — and nothing is written behind the '
            'refused popup either');
  });

  testWidgets('a sleep habit still opens the night behind the day',
      (tester) async {
    final AppScope scope = openScope();
    final Habit habit = addNumerical(scope, 'Sleep');
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));

    await tapTodaysCell(tester, scope);

    expect(find.byType(ManualEntrySheet), findsOneWidget,
        reason: 'computed.write-paths#4');
    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.write-paths#3');
  });

  testWidgets('an ordinary numerical habit still gets the number popup',
      (tester) async {
    final AppScope scope = openScope();
    addNumerical(scope, 'Read');

    await tapTodaysCell(tester, scope);

    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.write-paths#2 — nothing about the ported list moves '
            'for a habit the person fills in');
  });
}
