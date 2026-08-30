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
import 'package:uhabits/ui/habits/abstinence/abstinence_counter.dart';
import 'package:uhabits/ui/habits/show/cards/overview_card_view.dart';
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

  testWidgets('computed.abstinence-screen#1 счётчик считается от дня '
      'обязательства', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.text('40'), findsOneWidget,
        reason: 'computed.abstinence-screen#1 — сорок чистых дней до первого '
            'срыва существуют, и считаются они от обещания, а не от первой '
            'записи');
    expect(find.text('дней без срыва'), findsOneWidget,
        reason: 'computed.abstinence-screen#1 — по-русски, множественное '
            'число от 40');
    expect(find.textContaining('С '), findsWidgets,
        reason: 'computed.abstinence-screen#1 — пока срывов не было, под '
            'числом стоит день обещания');
  });

  testWidgets('computed.abstinence-screen#2 после срыва счётчик считается от '
      'него', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);
    scope.abstinence.setLapse(habit, LocalDate(today - 3), true);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    // Срыв был три дня назад: серия началась два дня назад, и прошедшего
    // времени в ней два дня (`computed.streak#4`).
    expect(find.text('2'), findsOneWidget,
        reason: 'computed.abstinence-screen#2');
    expect(find.text('дня без срыва'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — «2 дня», не «2 дней»');
    expect(find.textContaining('Последний срыв:'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — подпись меняется вместе с '
            'числом');
  });

  testWidgets('computed.abstinence-screen#2 запись под допуском — не срыв '
      'нигде на экране', (tester) async {
    // Ревью нашло: подпись брала последний день с записью в журнале
    // (`lapses.lastDay`), а кнопка, счётчик и ячейка списка судят срывом
    // `core.isAbstinenceLapse(definition, величина)`. При допуске 0 эти два
    // вопроса совпадают — сюда попадает только он один. При допуске 30 они
    // расходятся: запись в двадцать минут есть, а срыва нет, и карточка
    // говорила разом «40 дней без срыва», «Отметить срыв» и «Последний срыв:
    // сегодня». Один судья на экран — не три ответа на один вопрос.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(
      committedFrom: today - 40,
      allowance: 30,
      unit: 'minutes',
    );
    scope.abstinence.setLapse(habit, LocalDate(today), true, amount: 20);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.text('40'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — запись под допуском не '
            'обнуляет счётчик');
    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — кнопка предлагает отметить '
            'срыв, а не отменить: сегодня в пределах допуска');
    expect(find.textContaining('С '), findsWidgets,
        reason: 'computed.abstinence-screen#2 — подпись говорит «С …», как '
            'счётчик и кнопка; запись под допуском не срыв, и подпись не '
            'вправе называть её иначе, чем они');
    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.abstinence-screen#2 — единственный судья на '
            'экране это isAbstinenceLapse, а не «есть ли строка в журнале»');
  });

  testWidgets('computed.abstinence-screen#2 строка журнала без дня подписи не '
      'даёт', (tester) async {
    // Ревью нашло: судья был один — `isAbstinenceLapse`, — а входа два.
    // Подпись спрашивала журнал, а число, ячейка, сетка календаря и «Всего» —
    // значения дней. Расходятся они на пропуске: он приезжает восстановлением
    // копии из Loop, `DayWriter` его не переписывает
    // (`computed.day-write#4`), и строка журнала, поданная на такой день,
    // остаётся строкой без дня. Карточка говорила разом «40 дней без срыва» и
    // «Последний срыв: <дата>», пока сетка показывала пропуск, а «Всего» —
    // ноль. Снять этот призрак человеку было нечем: обе двери записи пропуск
    // охраняют, и кнопка карточки не стала бы «Отменить срыв» никогда.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);
    habit.originalEntries.add(Entry(LocalDate(today - 5), Entry.skip));
    habit.recompute();

    // Ровно то, что делал тап по такому дню: строка журнала появляется,
    // значение дня — нет.
    scope.abstinence.setLapse(habit, LocalDate(today - 5), true);
    expect(scope.lapses.lastDay(habit.id!), today - 5,
        reason: 'вход номер два: журнал строку принял');
    expect(habit.computedEntries.get(LocalDate(today - 5)).value, Entry.skip,
        reason: 'вход номер один: день остался пропуском');

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.abstinence-screen#2 — подпись читает те же значения '
            'дней, что и всё остальное на экране: один судья и один вход '
            '(`computed.abstinence-cell#2`, `computed.lapse-score#5`)');
    expect(find.textContaining('С '), findsWidgets,
        reason: 'computed.abstinence-screen#2 — срыва не было, и подпись '
            'говорит «С <день обещания>», как число рядом с ней');
    expect(find.text('40'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — сорок дней без срыва, и '
            'подпись не вправе называть их иначе');
    expect(
        tester
            .widget<Text>(find.byKey(OverviewCardView.totalCountLabelKey))
            .data,
        '0',
        reason: 'computed.abstinence-screen#4 — «Всего» считает те же дни, и '
            'этого дня среди них нет');
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
            .widget<TextButton>(
                find.byKey(AbstinenceCounterCard.todayButtonKey))
            .enabled,
        isFalse,
        reason: 'computed.abstinence-screen#5 — сегодня стоит пропуск, и '
            'кнопка не обещает того, чего дверь записи не сделает');

    await tester.tap(find.byKey(AbstinenceCounterCard.todayButtonKey));
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
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);
    habit.originalEntries.add(Entry(LocalDate(today - 3), Entry.skip));
    habit.recompute();

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.text('40'), findsOneWidget,
        reason: 'computed.streak#7 — «сегодня меня тут нет» не есть срыв, и '
            'сорок дней обещания остаются сорока');
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

    expect(find.text('40'), findsWidgets,
        reason: 'computed.streak#8 — карточка серий говорит то же число, что '
            'счётчик над ней');
    expect(find.text('41'), findsNothing,
        reason: 'computed.streak#8 — включительный счёт остался порту');

    // Число серии красится на канвасе, а не пишется виджетом `Text`, — та же
    // причина, по которой даты-подписи читает `streak_date_labels_test.dart`
    // прямо с построенного графика, а не через `find.text`. Две проверки
    // выше только удостоверяют, что «41» нет нигде на экране, а эта смотрит
    // туда, где число действительно живёт.
    final StreakChartView chart = tester
        .widget<CoreView>(find.descendant(
          of: find.byType(StreakCardView),
          matching: find.byType(CoreView),
        ))
        .view as StreakChartView;
    expect(chart.streaks.single.length, 40,
        reason: 'computed.streak#8 — карточка серий сама держит сорок, не '
            'сорок один');
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

    expect(find.text('19'), findsOneWidget,
        reason: 'computed.commitment#2 — счётчик считает от дня обещания, а '
            'не от срыва, которого обещание не застало');
    expect(find.text('дней без срыва'), findsOneWidget,
        reason: 'computed.commitment#2');
    expect(find.textContaining('С '), findsWidgets,
        reason: 'computed.commitment#2 — подпись говорит «С <день обещания>», '
            'и число обязано считаться от того же дня');
    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.commitment#2 — срыв старше обещания не последний '
            'срыв обещания');
  });

  testWidgets('computed.abstinence-screen#3 счётчик стоит в шве после '
      'ведущей четвёрки', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    double dyOf(Key key) => tester.getTopLeft(find.byKey(key)).dy;

    // Тот же шов, что и у сна: после ведущей четвёрки (subtitle, notes,
    // overview, score) и до всего остального — не выше всего экрана.
    // `counter < subtitle` держится и когда счётчик стоит над всей колонкой,
    // и потому не различает два размещения; здесь счётчик прижат к обоим
    // соседям по шву — ниже score, выше bar, первой карточки, что идёт за
    // четвёркой у привычки-воздержания (цель скрыта, `#4`).
    final double subtitle = dyOf(ShowHabitScreen.cardKey(ShowHabitCard.subtitle));
    final double score = dyOf(ShowHabitScreen.cardKey(ShowHabitCard.score));
    final double counter = dyOf(AbstinenceCounterCard.cardKey);
    final double bar = dyOf(ShowHabitScreen.cardKey(ShowHabitCard.bar));

    expect(subtitle, lessThan(score),
        reason: 'computed.abstinence-screen#3 — ведущая четвёрка идёт в '
            'портированном порядке');
    expect(score, lessThan(counter),
        reason: 'computed.abstinence-screen#3 — счётчик ниже ведущей '
            'четвёрки, а не выше всего экрана');
    expect(counter, lessThan(bar),
        reason: 'computed.abstinence-screen#3 — счётчик выше первой '
            'портированной карточки, что идёт после шва');
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

  testWidgets('computed.abstinence-screen#4 «Всего» считает срывы, а не ноль',
      (tester) async {
    // Портированный счёт складывает дни, равные `Entry.yesManual`, — отметки
    // рукой. Воздержание их не пишет никогда, и «Всего» показывало ноль
    // вечно, рядом с кольцом, счётчиком и календарём, которым было что
    // сказать. Считаются срывы: единственное, что эта привычка записывает.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);
    scope.abstinence.setLapse(habit, LocalDate(today - 5), true);
    scope.abstinence.setLapse(habit, LocalDate(today - 12), true);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<Text>(find.byKey(OverviewCardView.totalCountLabelKey))
            .data,
        '2',
        reason: 'computed.abstinence-screen#4 — два срыва под обещанием, и '
            'это ровно те два дня, которые сетка красит крестом');
  });

  testWidgets('computed.abstinence-screen#4 день до обещания в «Всего» не '
      'идёт', (tester) async {
    // Тот же охранник, что не красит клетку до обещания
    // (`computed.abstinence-cell#3`): судья один, и счёт спрашивает его же.
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 10);
    scope.abstinence.setLapse(habit, LocalDate(today - 50), true);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<Text>(find.byKey(OverviewCardView.totalCountLabelKey))
            .data,
        '0',
        reason: 'computed.abstinence-screen#4 — срыв старше обещания не срыв '
            'этого обещания');
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

    await tester.tap(find.byKey(AbstinenceCounterCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(scope.lapses.lastDay(habit.id!), today,
        reason: 'computed.abstinence-screen#5');
    expect(find.text('0'), findsWidgets,
        reason: 'computed.abstinence-screen#2 — срыв сегодня обнуляет счётчик');
    expect(find.text('Отменить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — надпись меняется вместе с '
            'состоянием дня');

    await tester.tap(find.byKey(AbstinenceCounterCard.todayButtonKey));
    await tester.pumpAndSettle();

    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-screen#5');
  });

  testWidgets('Bar и Frequency остаются на экране намеренно', (tester) async {
    // Спецификация выносит решение по ним отдельно, и оно принято: отложить.
    // Тест держит это как решение, а не как забывчивость, — когда карточки
    // решат прятать, падёт именно он (DEVIATIONS.md, «computed: воздержание не
    // трогает виджеты, Bar и Frequency»).
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.bar)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#4 — скрывается только карточка '
            'цели; Bar и Frequency оставлены, решение отложено спецификацией');
    expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.frequency)),
        findsOneWidget,
        reason: 'computed.abstinence-screen#4');
  });
}
