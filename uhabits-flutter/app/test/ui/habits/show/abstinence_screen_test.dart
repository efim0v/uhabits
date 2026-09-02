/// Экран привычки-воздержания.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
// `ShowHabitCard` is not re-exported by show_habit_screen.dart itself — the
// same reason sleep_habit_screen_test.dart imports it directly.
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_overview.dart';
import 'package:uhabits/ui/habits/show/cards/streak_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_screen');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  // `allowance` is stored twice, in `targetValue` and in the payload, on
  // purpose: that is what `computed.allowance#1` promises, and it is exactly
  // the thing whose two readers this fix's own test leans on. The real
  // editor (`_writeAbstinenceRow`) sets both from one parsed value; this
  // helper mirrors it rather than picking a shortcut that only one of the
  // two readers would notice.
  Habit addAbstinence({
    required int committedFrom,
    double allowance = 0.0,
    String unit = '',
  }) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sober'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = allowance
      ..unit = unit;
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
        payload: abstinencePayload(allowance: allowance, unit: unit),
      ),
    );
    // `definitions.save` only writes the row; the live `Habit` learns about
    // it — and turns on `silenceQualifies` for its streak — through
    // `attachDefinition` (`computed.definition#9`, `computed.streak#1`). The
    // real editor does both in `_writeAbstinenceRow`.
    attachDefinition(habit, scope.definitions);
    habit.recompute();
    return habit;
  }

  Widget wrap(Habit habit) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            key: ValueKey<String?>(habit.uuid),
            habit: habit,
          ),
        ),
      );

  testWidgets('the counter shows once, and it shows in the overview',
      (tester) async {
    final int today = getToday().daysSince2000;
    // Двадцать дней, а не сорок: сорокадневный отрезок счётчик прочитает
    // календарно, как «1 месяц 9 дней», а не как «40 дней»
    // (`computed.since#6`).
    final Habit habit = addAbstinence(committedFrom: today - 20);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.textContaining('20 дней'), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — одно число в одном месте: '
            'старая карточка-счётчик ушла вместе со своей секцией');
    expect(
      tester.getRect(find.byType(AbstinenceOverviewCard)).top,
      lessThan(tester
          .getRect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.score)))
          .top),
      reason: 'computed.abstinence-screen#3 — Overview занимает портированный '
          'слот целиком и потому стоит до `score`, там же, где у обычной '
          'привычки стоит кольцо',
    );
  });

  testWidgets('computed.abstinence-screen#5 кнопка не предлагает переписать '
      'пропуск', (tester) async {
    // Вторая половина того же дефекта. Кнопка на пропущенном дне читалась
    // «Отметить срыв» и нажималась; нажатие писало строку журнала, `DayWriter`
    // отказывался переписать отметку человека, `setLapse` честно отвечал
    // `false` — и на экране не менялось ничего, кроме появившегося призрака.
    // Тот же охранник, что закрывает ячейку списка (`entry_panel.dart`) и
    // клетку календаря (`computed.abstinence-screen#8`), закрывает и кнопку.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);
    habit.originalEntries.add(Entry(LocalDate(today), Entry.skip));
    habit.recompute();

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<FilledButton>(
                find.byKey(AbstinenceOverviewCard.todayButtonKey))
            .enabled,
        isFalse,
        reason: 'computed.abstinence-screen#5 — сегодня стоит пропуск, и '
            'кнопка не обещает того, чего дверь записи не сделает');

    await tester.tap(find.byKey(AbstinenceOverviewCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#5 — нажатие не оставило в журнале '
            'строки, которую потом нечем снять');
    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.abstinence-screen#5 — и подпись осталась при своём');
  });

  testWidgets('computed.streak#7 пропуск не обнуляет счётчик', (tester) async {
    // Пропуск защищён у оценки (`computed.lapse-score#8`), у свода
    // (`computed.abstinence-sync#4`), у двери записи (`computed.day-write#4`)
    // и у ячейки (`computed.abstinence-cell#4`) — и был уронен у серии:
    // `Entry.skip` есть 3, то есть 0.003, и при допуске ноль числовое
    // сравнение выбрасывало день из серии. Сегодня сюда не ведёт ни одна
    // дверь приложения, но пропуск приезжает восстановлением копии из Loop.
    //
    // Двадцать, не сорок: сорок настоящих суток от полуночи обязательства до
    // текущего момента теста всегда пересекают границу календарного месяца
    // (`computed.since#6`), и счётчик прочитал бы их как «1 месяц N дней», а
    // не как «40 дней». Двадцать суток короче любого месяца.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 20);
    habit.originalEntries.add(Entry(LocalDate(today - 3), Entry.skip));
    habit.recompute();

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.textContaining('20 дней'), findsOneWidget,
        reason: 'computed.streak#7 — «сегодня меня тут нет» не есть срыв, и '
            'двадцать дней обязательства остаются двадцатью');
    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.streak#7 — и подпись согласна: срыва не было');
  });

  testWidgets('the best-streaks card counts days lived through',
      (tester) async {
    // Обязательство сорок дней назад, ни одного срыва: идёт сороковая сутки.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    // Число серии красится на канвасе, а не пишется виджетом `Text`, поэтому
    // `find.text('40')`/`find.text('41')` тут ни при чём: оба видят только
    // счётчик над карточкой (уже проверен `computed.streak#7`), саму карточку
    // не видит ни один. Смотреть приходится прямо в построенный график, как
    // это уже делает `streak_date_labels_test.dart` для дат.
    final StreakChartView chart = tester
        .widget<CoreView>(find.descendant(
          of: find.byType(StreakCardView),
          matching: find.byType(CoreView),
        ))
        .view as StreakChartView;

    expect(chart.lengths?.single, 40,
        reason: 'computed.streak#8 — карточка серий сама держит сорок, не '
            'сорок один');
    expect(chart.streaks.single.length, 41,
        reason: 'computed.streak#8 — серия самой себе не изменяет: '
            'включительный счёт остался сорока одним, только показывать '
            'карточке велено другое число');
    expect(chart.streaks.single.end, getToday(),
        reason: 'computed.streak#8 — сорок прошедших суток не делают концом '
            'вчерашний день: серия идёт, и её настоящий конец остаётся '
            'сегодняшним');
  });

  testWidgets('computed.commitment#2 перенесённый вперёд день обещания '
      'разводил число и подпись', (tester) async {
    // Ревью нашло: подпись ищет срыв в [день обещания, сегодня], счётчик идёт
    // от серии, а окно пересчёта расширялось назад до старейшей записи. Срыв
    // старше обещания тянул границу окна на себя, серия начиналась от него, и
    // экран показывал «39 дней без срыва» под подписью «С <дата>», которой
    // девятнадцать. Тот же старый срыв делил оценку пополам, оставаясь при
    // этом пустой клеткой календаря, — невидимый крест, тянущий кольцо вниз.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 19);
    scope.abstinence.setLapse(habit, LocalDate(today - 40), true);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.textContaining('19 дней'), findsOneWidget,
        reason: 'computed.commitment#2 — счётчик считает от дня обещания, а '
            'не от срыва, которого обещание не застало');
    expect(find.textContaining('С '), findsWidgets,
        reason: 'computed.commitment#2 — подпись говорит «С <день обещания>», '
            'и число обязано считаться от того же дня');
    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.commitment#2 — срыв старше обещания не последний '
            'срыв обещания');
  });

  testWidgets('computed.abstinence-screen#4 цель скрыта, кольцо показано',
      (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.target)),
        findsNothing,
        reason: 'computed.abstinence-screen#4 — неделя без срывов это не '
            '«0% в неделю»');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.overview)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#4');
  });

  testWidgets('computed.abstinence-screen#5 кнопка пишет и снимает срыв за '
      'сегодня', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();
    // Текущая формулировка (арб уже правлен ради рода читателя и парности
    // двух кнопок, коммиты 259a7b09 и 0b0ef6d1): «Отметить срыв» —
    // называет действие, а не человека.
    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5');

    await tester.tap(find.byKey(AbstinenceOverviewCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(scope.lapses.lastDay(habit.id!), today,
        reason: 'computed.abstinence-screen#5');
    // Счётчик больше не пишет голую цифру: срыв записан мгновение назад,
    // счёт идёт от его момента (`computed.since#4`), и прошло меньше минуты
    // — карточка показывает «0 минут», а не «0» (`abstinence_overview.dart`).
    expect(find.text('0 минут'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — срыв сегодня начинает счёт '
            'заново, и в первую минуту после него это «0 минут»');
    expect(find.text('Отменить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — надпись меняется вместе с '
            'состоянием дня');

    await tester.tap(find.byKey(AbstinenceOverviewCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#5');
  });

  testWidgets('two cards that can say nothing about this kind are gone',
      (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.bar)), findsNothing,
        reason: 'computed.abstinence-screen#14 — столбцы считают сделанное, а '
            'воздержание ничего не делает');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.frequency)),
        findsNothing,
        reason: 'computed.abstinence-screen#14 — частота у воздержания '
            'ежедневная и другой не бывает, и таблице нечего показывать');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.history)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#14 — а календарь остаётся: он '
            'единственный отвечает на вопрос, ради которого экран открывают');
  });

  testWidgets('the goal says what is promised, not which way the arrow points',
      (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.text('Ни разу'), findsOneWidget,
        reason: 'computed.abstinence-screen#12 — обещание словами');
    expect(find.text('Каждый день'), findsNothing,
        reason: 'computed.abstinence-screen#12 — частота у воздержания есть '
            'подробность устройства, а не цель');
  });

  testWidgets('an allowance is quoted the way it was asked', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit =
        addAbstinence(committedFrom: today - 40, allowance: 30, unit: 'минут');

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.text('Не более 30 минут в день'), findsOneWidget,
        reason: 'computed.abstinence-screen#12 — одна формулировка, один '
            'смысл: та же фраза стоит в вопросе о величине');
  });
}
