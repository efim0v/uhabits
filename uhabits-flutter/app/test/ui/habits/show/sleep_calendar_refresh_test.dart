/// The calendar editor's own grid, for a night entered by hand from inside it.
///
/// `enterNightByHand` writes through `sleepRepository`/`sleepSync`/
/// `SkipRange`, deliberately outside `CommandRunner` (`sleep_section.dart`'s
/// `_wrote` doc), so `HistoryEditorDialog`'s own `onCommandFinished` never
/// hears about it. Task 38 found and fixed the identical gap for abstinence
/// (`computed.abstinence-screen#9`); this is the same gap on the sleep
/// gesture, and the same fix (`computed.write-paths#6`).
library;

// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
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
        (9000 + 10957) * 86400000 + 10 * 3600000);
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

  /// A sleep habit with one night recorded 400 days back — the same margin
  /// `abstinence_calendar_test.dart`'s `addAbstinence` gives itself, and for
  /// the same reason: the calendar cell this test taps sits a fixed number of
  /// weeks behind today regardless of what is recorded, so the series has to
  /// reach back far enough to cover it.
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
    final int farDay = getToday().daysSince2000 - 400;
    final int farWake = (farDay + 10957) * 86400000 + 7 * 3600000;
    scope.sleepRepository.upsert(
      habit.id!,
      farDay,
      SleepEpisode(
        bedStartMillis: farWake - 450 * 60000,
        wakeEndMillis: farWake,
        asleepMinutes: 450,
        utcOffsetMinutes: 0,
      ),
      manual: false,
    );
    // Through the writer, not a bare `habit.recompute()`: only a value that
    // has actually landed in `originalEntries` extends what the history card
    // considers known, and that is what widens the calendar's series far
    // enough back to cover the cell this test taps.
    scope.sleepSync.recomputeDays(habit, farDay, farDay);
    return habit;
  }

  final Finder chartFinder = find.descendant(
    of: find.byType(HistoryEditorDialog),
    matching: find.byType(CoreView),
  );

  /// The centre of the calendar cell at [col], [row] — the same geometry
  /// `calendar_editor_guard_test.dart` uses for a column well inside the
  /// history, so the cell is not in the future and the chart dispatches the
  /// press.
  Offset cellAt(WidgetTester tester, {int col = 3, int row = 3}) {
    const double padding = HistoryEditorDialog.chartPadding;
    final Size size = tester.getSize(chartFinder);
    final double square = ((size.height - 2 * padding) / 8.0).roundToDouble();
    return tester.getTopLeft(chartFinder) +
        Offset(padding + (col + 0.5) * square, padding + (row + 0.5) * square);
  }

  testWidgets(
      'computed.write-paths#6 a night entered by hand repaints the open '
      'calendar', (tester) async {
    final Habit habit = addSleepHabit();

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: ShowHabitScreen(
          key: ValueKey<String?>(habit.uuid),
          habit: habit,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryEditorDialog), findsOneWidget,
        reason: 'the editor has to be open for the tap to mean anything');

    await tester.tapAt(cellAt(tester));
    await tester.pumpAndSettle();
    expect(find.byType(ManualEntrySheet), findsOneWidget,
        reason: 'computed.write-paths#4');

    final LocalDate day =
        HistoryEditorDialog.current!.chart!.lastClickedDate!;
    final int daysAgo = getToday().daysSince2000 - day.daysSince2000;

    // Nothing recorded on this day yet, so the grid shows it unknown.
    expect(HistoryEditorDialog.current!.chart!.series[daysAgo], Square.off,
        reason: 'computed.write-paths#6 — the day starts with nothing on it');

    // Mark the night skipped and confirm — the same write `sleep.skip#3`
    // proves happens through the toggle, done here from inside the open
    // calendar rather than the card's own Edit button.
    await tester.tap(find.byKey(ManualEntrySheet.skipToggleKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enter night'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualEntrySheet), findsNothing);
    expect(find.byType(HistoryEditorDialog), findsOneWidget,
        reason: 'computed.write-paths#6 — closing the sheet does not drop the '
            'calendar under it');
    expect(habit.originalEntries.get(day).value, Entry.skip,
        reason: 'sleep.skip#3 — the write itself landed');

    // The write went through `sleepRepository`/`SkipRange`, not
    // `CommandRunner`, so the dialog's own `onCommandFinished` never fired for
    // it. Without a manual `HistoryEditorHandle.refresh()` call, the grid
    // would still be showing what it showed before the sheet opened.
    expect(HistoryEditorDialog.current!.chart!.series[daysAgo], Square.hatched,
        reason: 'computed.write-paths#6 — the freshly written skip has to '
            'enter the repainted grid, the same way an abstinence lapse does '
            '(computed.abstinence-screen#9)');
  });
}
