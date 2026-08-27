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

  /// Обещание «не более [allowance] [unit] в день», данное 400 дней назад —
  /// тот же запас, что у `addAbstinence`, ради той же причины: любая видимая
  /// клетка уже под обязательством, и день обязательства этому тесту не
  /// интересен.
  ///
  /// Допуск пишется дважды одним движением: `targetValue` читает оценка и
  /// рисунок ячейки числового календаря, `payload` — `toggleLapseDay`,
  /// спрашивающий величину (`computed.allowance#1`).
  Habit addAbstinenceWithAllowance({
    required double allowance,
    String unit = 'minutes',
  }) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Screen time'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = allowance
      ..unit = unit;
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: getToday().daysSince2000 - 400,
        payload: abstinencePayload(allowance: allowance, unit: unit),
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

  // Допуск больше нуля: тап в календаре открывает второй попап поверх уже
  // открытого `HistoryEditorDialog` — вложение, которого нет ни у ячейки
  // списка, ни у кнопки карточки, потому что ни там, ни там в момент жеста
  // никакой диалог не открыт. `abstinence_allowance_test.dart` спрашивает
  // тех же троих судей через список и карточку; здесь — тот же вопрос через
  // календарь, третьим.
  testWidgets(
      'computed.abstinence-screen#6 календарь спрашивает величину, и её '
      'ответ решает день', (tester) async {
    final Habit habit =
        addAbstinenceWithAllowance(allowance: 30.0, unit: 'minutes');

    await openEditorAndTapADay(tester, habit);

    // Второй диалог действительно открылся на этой глубине, и первый его не
    // уступил: `HistoryEditorDialog` держит свой собственный слот отдельно
    // от общего `dismissCurrentAndShow`, которым здесь открыт попап
    // (`history-editor.dialog#10`, `#16`).
    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8 — при допуске больше нуля тап '
            'спрашивает величину, и через календарь тоже');
    expect(find.byType(HistoryEditorDialog), findsOneWidget,
        reason: 'computed.abstinence-screen#6 — календарь не уступает место '
            'вложенному попапу, а держит его поверх себя');

    await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')), '45');
    await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
    await tester.pumpAndSettle();

    // Попап закрылся, календарь пережил вложение и остался на экране.
    expect(find.byType(NumberDialog), findsNothing);
    expect(find.byType(HistoryEditorDialog), findsOneWidget,
        reason: 'computed.abstinence-screen#6 — закрытие вложенного попапа '
            'не роняет календарь под ним');

    // Что стало с днём: журнал хранит ответ как факт, а не «единицу».
    final int? day = scope.lapses.lastDay(habit.id!);
    expect(day, isNotNull, reason: 'computed.abstinence-screen#6');
    expect(scope.lapses.forDay(habit.id!, day!), 45,
        reason: 'computed.abstinence-cell#8 — журнал хранит введённую '
            'величину, а не единицу');

    // Что показывает календарь: сорок пять больше тридцати — тот же
    // числовой at-most, которым порт красит любой день, — и сетка обязана
    // это показать сразу, не дожидаясь чужой команды
    // (`computed.abstinence-screen#9`). Запись срыва идёт через
    // `AbstinenceSync`/`DayWriter`, а не через `CommandRunner`, так что без
    // ручного `refresh()` кэш календаря остался бы на состоянии до тапа.
    final int daysAgo = getToday().daysSince2000 - day;
    final HistoryChart? chart = HistoryEditorDialog.current?.chart;
    expect(chart, isNotNull);
    expect(daysAgo, lessThan(chart!.series.length),
        reason: 'computed.abstinence-screen#9 — свежая запись обязана войти '
            'в перерисованную сетку');
    expect(chart.series[daysAgo], Square.grey,
        reason: 'computed.abstinence-screen#9 — сорок пять минут при '
            'допуске тридцать красятся так же, как любой день числовой '
            'привычки, не уложившийся в цель at-most');
  });

  testWidgets(
      'computed.abstinence-screen#6 календарь: величина в пределах допуска '
      'оставляет день чистым', (tester) async {
    final Habit habit =
        addAbstinenceWithAllowance(allowance: 30.0, unit: 'minutes');

    await openEditorAndTapADay(tester, habit);
    await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')), '20');
    await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryEditorDialog), findsOneWidget,
        reason: 'computed.abstinence-screen#6 — закрытие вложенного попапа '
            'не роняет календарь под ним');

    final int? day = scope.lapses.lastDay(habit.id!);
    expect(day, isNotNull, reason: 'computed.abstinence-screen#6');
    // Журнал хранит двадцать — обещание тридцати это держит, но запись есть
    // запись: величина, а не отсутствие строки (computed.lapses#1 говорит
    // про молчание, а тут человек ответил).
    expect(scope.lapses.forDay(habit.id!, day!), 20,
        reason: 'computed.abstinence-cell#8');

    // День остаётся чистым и на календаре: двадцать не больше тридцати.
    final int daysAgo = getToday().daysSince2000 - day;
    final HistoryChart? chart = HistoryEditorDialog.current?.chart;
    expect(chart, isNotNull);
    expect(daysAgo, lessThan(chart!.series.length),
        reason: 'computed.abstinence-screen#9');
    expect(chart.series[daysAgo], Square.on,
        reason: 'computed.abstinence-screen#9 — двадцать минут при допуске '
            'тридцать обещание держат, и календарь обязан согласиться с '
            'ячейкой и кнопкой карточки (computed.abstinence-cell#2)');
  });
}
