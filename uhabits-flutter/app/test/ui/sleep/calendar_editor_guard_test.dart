/// The calendar editor, opened from a computed habit's own screen.
///
/// The Calendar card's Edit button opens the ported history editor, and a tap
/// on one of its days goes to the very same `HistoryCardPresenter` the card
/// uses (`history-editor.dialog#17`). That presenter offers the person a value
/// to type — a number for a numerical habit, a check mark for a yes/no one —
/// and writes whatever comes back with `CreateRepetitionCommand`.
///
/// A computed habit has no typed value to keep. `DayWriter` only ever writes a
/// day that has something recorded behind it, so a value typed onto a day with
/// nothing behind it — a gap in the health store, a day before the app was
/// installed, a day still to come — is never revisited and stands for ever,
/// with the app showing a figure it never computed.
///
/// This file pins the door on the inside of the habit's own screen; the habit
/// list has a door of its own onto the same gesture.
library;

// uhabits_core exports neither lib/src/ui nor lib/src/commands yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits/ui/habits/sleep/manual_entry_sheet.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;

  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    core_time.DateUtils.setFixedLocalTime(
        (9000 + 10957) * 86400000 + 3 * 3600000);
    setToday(LocalDate(9000));
    // The slot is process-wide upstream too; a leftover route from the
    // previous test belongs to a tree that no longer exists.
    HistoryEditorDialog.currentDialog = null;
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
  });

  tearDown(() {
    scope.close();
    core_time.DateUtils.setFixedTimeZone(null);
    core_time.DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  /// A habit with a sleep goal and the definition that goes with it: the two
  /// always travel together, in the app and therefore here.
  Habit addSleepHabit() {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    habit.recompute();
    return habit;
  }

  /// A computed habit that is not a sleep habit: the layer's second planned
  /// inhabitant, which has a definition and no sleep goal at all.
  Habit addComputedHabit({required HabitType type}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sober'
      ..type = type;
    if (type == HabitType.numerical) {
      habit
        ..targetValue = 1
        ..unit = 'days';
    }
    scope.habitList.add(habit);
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.abstinence));
    habit.recompute();
    return habit;
  }

  Habit addOrdinaryHabit() {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Pages'
      ..type = HabitType.numerical
      ..targetValue = 30
      ..unit = 'pages';
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Widget wrap(Habit habit) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            key: ValueKey<String?>(habit.uuid),
            habit: habit,
          ),
        ),
      );

  final Finder chartFinder = find.descendant(
    of: find.byType(HistoryEditorDialog),
    matching: find.byType(CoreView),
  );

  /// The centre of the calendar cell at [col], [row], using the geometry
  /// `HistoryChart.draw` computes: an eight-row grid — a header row plus seven
  /// weekday rows — inside the chart's padding.
  Offset cellAt(WidgetTester tester, {int col = 0, int row = 1}) {
    const double padding = HistoryEditorDialog.chartPadding;
    final Size size = tester.getSize(chartFinder);
    final double square = ((size.height - 2 * padding) / 8.0).roundToDouble();
    return tester.getTopLeft(chartFinder) +
        Offset(padding + (col + 0.5) * square, padding + (row + 0.5) * square);
  }

  /// Calendar card → Edit → tap a day, on the real screen the app builds.
  Future<void> openEditorAndTapADay(WidgetTester tester, Habit habit) async {
    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryEditorDialog), findsOneWidget,
        reason: 'the editor has to be open for the tap to mean anything');
    // A column well inside the history, so the cell is not in the future and
    // the chart dispatches the press.
    await tester.tapAt(cellAt(tester, col: 3, row: 3));
    await tester.pumpAndSettle();
  }

  group('a habit whose days the app computes', () {
    testWidgets('is not offered a number to type for a day', (tester) async {
      final Habit habit = addSleepHabit();

      await openEditorAndTapADay(tester, habit);

      expect(find.byType(NumberDialog), findsNothing,
          reason: 'computed.write-paths#3');
    });

    testWidgets('opens the night behind the day instead, when it is a sleep '
        'habit', (tester) async {
      final Habit habit = addSleepHabit();

      await openEditorAndTapADay(tester, habit);

      expect(find.byType(ManualEntrySheet), findsOneWidget,
          reason: 'computed.write-paths#4');
    });

    testWidgets('is refused the number even when it is not a sleep habit',
        (tester) async {
      // The guard cannot be "has a sleep goal": the layer's second inhabitant
      // has a definition and no goal, and a habit whose kind came from a newer
      // build has neither a goal nor a kind this build can read.
      final Habit habit = addComputedHabit(type: HabitType.numerical);

      await openEditorAndTapADay(tester, habit);

      expect(find.byType(NumberDialog), findsNothing,
          reason: 'computed.write-paths#3');
      expect(habit.originalEntries.getKnown(), isEmpty,
          reason: 'computed.write-paths#3 — and nothing is written behind the '
              'refused popup either');
    });

    testWidgets('is refused the check mark too, when it is a yes/no habit',
        (tester) async {
      final Habit habit = addComputedHabit(type: HabitType.yesNo);

      await openEditorAndTapADay(tester, habit);

      expect(find.byType(CheckmarkDialog), findsNothing,
          reason: 'computed.write-paths#3');
      expect(habit.originalEntries.getKnown(), isEmpty,
          reason: 'computed.write-paths#3');
    });
  });

  group('a habit whose days the person enters', () {
    testWidgets('still gets the number popup', (tester) async {
      final Habit habit = addOrdinaryHabit();

      await openEditorAndTapADay(tester, habit);

      expect(find.byType(NumberDialog), findsOneWidget,
          reason: 'computed.write-paths#2 — nothing about the ported editor '
              'moves for an ordinary habit');
    });
  });
}
