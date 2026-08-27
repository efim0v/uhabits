/// Календарь на экране воздержания: тот же жест, что и в ячейке списка.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_cal');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  Habit addAbstinence({required int committedFrom}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sober'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0
      ..unit = '';
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
      ),
    );
    habit.recompute();
    return habit;
  }

  final Finder chartFinder = find.descendant(
    of: find.byType(HistoryEditorDialog),
    matching: find.byType(CoreView),
  );

  Offset cellAt(WidgetTester tester, {int col = 3, int row = 3}) {
    const double padding = HistoryEditorDialog.chartPadding;
    final Size size = tester.getSize(chartFinder);
    final double square = ((size.height - 2 * padding) / 8.0).roundToDouble();
    return tester.getTopLeft(chartFinder) +
        Offset(padding + (col + 0.5) * square, padding + (row + 0.5) * square);
  }

  Future<void> openEditorAndTapADay(WidgetTester tester, Habit habit) async {
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
    await tester.tapAt(cellAt(tester));
    await tester.pumpAndSettle();
  }

  testWidgets('computed.abstinence-screen#6 тап по дню записывает срыв, а не '
      'открывает число', (tester) async {
    // Достаточно давно, чтобы любая видимая клетка была уже под
    // обязательством.
    final Habit habit =
        addAbstinence(committedFrom: getToday().daysSince2000 - 400);

    await openEditorAndTapADay(tester, habit);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.write-paths#3');
    final int? day = scope.lapses.lastDay(habit.id!);
    expect(day, isNotNull, reason: 'computed.abstinence-screen#6');
    expect(day, lessThan(getToday().daysSince2000),
        reason: 'computed.abstinence-screen#6 — срыв записан на ту клетку, по '
            'которой попали, а не на сегодня');

    // Второй тап по той же клетке снимает срыв — как в списке.
    await tester.tapAt(cellAt(tester));
    await tester.pumpAndSettle();
    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#6');
  });

  testWidgets(
      'computed.abstinence-screen#7 день до дня обязательства не пишет срыв '
      'и через календарь', (tester) async {
    // Обязательство начинается сегодня: клетка (col: 3, row: 3), которую
    // предыдущий тест уже доказал днём строго до сегодняшнего
    // (`day, lessThan(getToday().daysSince2000)`), лежит до этого дня
    // обязательства при любой геометрии панели.
    final Habit habit =
        addAbstinence(committedFrom: getToday().daysSince2000);

    await openEditorAndTapADay(tester, habit);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.write-paths#3');
    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#7 — день до обещания приложение '
            'себе не приписывает, даже когда за него берётся календарь');
  });

  testWidgets(
      'computed.abstinence-screen#8 пропуск на дне не становится срывом и '
      'через календарь', (tester) async {
    final Habit habit =
        addAbstinence(committedFrom: getToday().daysSince2000 - 400);

    // Первый тап узнаёт, какой день прячется за (col: 3, row: 3) — тот же,
    // что и в первом тесте, — и записывает на него срыв.
    await openEditorAndTapADay(tester, habit);
    final int day = scope.lapses.lastDay(habit.id!)!;

    // Второй тап снимает его: день возвращается в молчание.
    await tester.tapAt(cellAt(tester));
    await tester.pumpAndSettle();
    expect(scope.lapses.lastDay(habit.id!), isNull);

    // Теперь на этом дне — отметка человека, а не срыв: пропуск, записанный
    // так же, как его пишет `CreateRepetitionCommand` — прямой записью в
    // `originalEntries` и пересчётом.
    final LocalDate skippedDay = LocalDate(day);
    habit.originalEntries.add(Entry(skippedDay, Entry.skip));
    habit.recompute();

    // Третий тап по той же клетке не должен превратить пропуск в срыв.
    await tester.tapAt(cellAt(tester));
    await tester.pumpAndSettle();

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.write-paths#3');
    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#8');
    expect(habit.originalEntries.get(skippedDay).value, Entry.skip,
        reason: 'computed.abstinence-screen#8 — вычисленное значение не '
            'затирает отметку человека');
  });
}
