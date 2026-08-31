/// Overview воздержания: счётчик, кольцо, две доли, число срывов и кнопка.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/common/views/ring_view.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_overview.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;
  late int today;

  setUp(() {
    resetToday();
    tempDir =
        Directory.systemTemp.createTempSync('uhabits_abstinence_overview');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
    today = getToday().daysSince2000;
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  /// Привычка-воздержание, обязательство с [committedFrom], допуск
  /// [allowance] — как `addAbstinence` в `abstinence_screen_test.dart`.
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
    attachDefinition(habit, scope.definitions);
    habit.recompute();
    return habit;
  }

  /// То же самое, что делает `pumpOverview` внизу, но для привычки, которую
  /// вызывающий уже построил и уже наполнил журналом сам — там, где простого
  /// списка дней-срывов не хватает: величина под допуском, день-пропуск.
  Future<void> pumpHabit(WidgetTester tester, Habit habit) async {
    final HabitDefinition definition = habit.definition!;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('ru'),
      home: Provider<AppScope>.value(
        value: scope,
        child: Scaffold(
          body: AbstinenceOverviewCard(
            habit: habit,
            definition: definition,
            scope: scope,
            onLapse: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Строит карточку для привычки, обязавшейся с [committedFrom], со срывами
  /// в дни [lapses].
  Future<void> pumpOverview(
    WidgetTester tester, {
    required int committedFrom,
    required List<int> lapses,
  }) async {
    final Habit habit = addAbstinence(committedFrom: committedFrom);
    for (final int day in lapses) {
      scope.abstinence.setLapse(habit, LocalDate(day), true);
    }
    final HabitDefinition definition = habit.definition!;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('ru'),
      home: Provider<AppScope>.value(
        value: scope,
        child: Scaffold(
          body: AbstinenceOverviewCard(
            habit: habit,
            definition: definition,
            scope: scope,
            onLapse: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the counter, the ring and the two shares', (tester) async {
    // Двадцать, не сорок: счётчик читает `since` календарно
    // (`computed.since#6`), а `since` без единого срыва — полночь дня
    // обязательства (`computed.since#3`). Сорок реальных суток от полуночи
    // до настоящего момента переваливают за длину любого календарного
    // месяца (максимум тридцать один), и `formatAbstinenceDuration` честно
    // показал бы «1 месяц N дней» вместо «40 дней» — календарная арифметика
    // тут работает верно, а вот число «сорок» для голой демонстрации не
    // годится. Двадцать суток короче любого месяца (минимум двадцать
    // восемь, невисокосный февраль) и месяц никогда не набежит.
    await pumpOverview(tester, committedFrom: today - 20, lapses: const []);

    // `textContaining`, не `text`: `since` стоит на полуночи, а «сейчас» —
    // это настоящее время теста, и часы с минутами с полуночи почти никогда
    // не нулевые. Число дней от этого не плывёт — оно ровно двадцать в любое
    // время суток, — а часы и минуты сверху не отменяют этого числа.
    expect(find.textContaining('20 дней'), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — счётчик крупно и сверху');
    expect(find.byType(RingView), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — уровень кольцом');
    expect(find.text('рекорд'), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — сто процентов от самого себя '
            'не новость, а рекорд — новость');
    expect(find.text('от прошлой серии'), findsNothing,
        reason: 'computed.streak#10 — первой попытке сравнивать не с чем, и '
            'строка не рисуется вовсе');
    // Перекочевало из удалённого `abstinence_screen_test.dart` (Задача 12):
    // пока срывов не было, под счётчиком стоит день обязательства, а не
    // журнальная запись — тот же факт, что раньше проверяла отдельная
    // карточка-счётчик.
    expect(find.textContaining('С '), findsOneWidget,
        reason: 'computed.abstinence-screen#1 — пока срывов не было, под '
            'числом стоит день обязательства');
  });

  testWidgets('the shares appear once there is something to compare with',
      (tester) async {
    await pumpOverview(tester,
        committedFrom: today - 40, lapses: <int>[today - 20, today - 10]);

    expect(find.textContaining('от рекорда'), findsOneWidget,
        reason: 'computed.streak#10');
    expect(find.textContaining('от прошлой серии'), findsOneWidget,
        reason: 'computed.streak#10');
    // Значения, не только надписи. Три серии: сорок дней обязательства до
    // первого срыва дают двадцать прошедших суток — лучшая; девять суток до
    // второго срыва — прошлая; девять суток идущей серии — нынешняя. Доля от
    // рекорда — 9/20 (45%), доля от прошлой — 9/9 (100%). Число, а не только
    // подпись рядом с ним, обязано совпасть: подмена числителя или
    // знаменателя длиной серии вместо прошедшего времени
    // (`computed.streak#8`) разошлась бы с карточкой серий на один день, и
    // проверка одной надписи этого бы не заметила.
    expect(find.text('45%'), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — доля от рекорда считается '
            'прошедшим временем, тем же, что и на карточке серий');
    expect(find.text('100%'), findsOneWidget,
        reason: 'computed.abstinence-screen#11 — доля от прошлой серии тем '
            'же счётом');
    // Перекочевало из удалённого `abstinence_screen_test.dart` (Задача 12):
    // «Всего» отвечал портированный `OverviewCardView`, которого у
    // воздержания больше нет — слот `overview` целиком достался этой
    // карточке. Судья тот же — `abstinenceCountsTowardsTotal`, — что красит
    // крестом сетку календаря, и оба срыва под обязательством считает он.
    expect(find.text('2'), findsOneWidget,
        reason: 'computed.abstinence-screen#4 — два срыва под обязательством, '
            'и это ровно те два дня, которые сетка красит крестом');
  });

  testWidgets('the button is here, because it has nowhere else to be',
      (tester) async {
    await pumpOverview(tester, committedFrom: today - 40, lapses: const []);

    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — жест переехал вместе с '
            'числами, а не потерялся между ними');
  });

  testWidgets('the subtitle names the last lapse', (tester) async {
    // Перекочевало из удалённого `abstinence_screen_test.dart` (Задача 12):
    // как только срыв случился, подпись меняется на «Последний срыв: {дата}».
    await pumpOverview(tester,
        committedFrom: today - 40, lapses: <int>[today - 3]);

    expect(find.textContaining('Последний срыв:'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — подпись меняется вместе с '
            'числом');
  });

  testWidgets(
      'the button, the subtitle and the counter agree when today is under '
      'the allowance', (tester) async {
    // Перекочевало из удалённого `abstinence_screen_test.dart` (Задача 12).
    // Ревью нашло: подпись брала последний день с записью в журнале
    // (`lapses.lastDay`), а кнопка, счётчик и ячейка списка судят срывом
    // `isAbstinenceLapse(definition, величина)`. При допуске 0 эти два
    // вопроса совпадают; при допуске 30 расходятся — запись в двадцать минут
    // есть, а срыва нет, и карточка говорила разом «40 дней без срыва»,
    // «Отметить срыв» и «Последний срыв: сегодня». Один судья на карточку —
    // не три ответа на один вопрос.
    //
    // Двадцать, не сорок: `computed.since#6` читает разрыв календарно, и
    // сорок настоящих суток от полуночи обязательства до настоящего момента
    // теста пересекли бы границу месяца.
    final Habit habit = addAbstinence(
      committedFrom: today - 20,
      allowance: 30,
      unit: 'minutes',
    );
    scope.abstinence.setLapse(habit, LocalDate(today), true, amount: 20);
    await pumpHabit(tester, habit);

    expect(find.textContaining('20 дней'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — запись под допуском не '
            'обнуляет счётчик');
    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — кнопка предлагает отметить '
            'срыв, а не отменить: сегодня в пределах допуска');
    expect(find.textContaining('С '), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — подпись говорит «С …», как '
            'счётчик и кнопка; запись под допуском не срыв, и подпись не '
            'вправе называть её иначе, чем они');
    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.abstinence-screen#2 — единственный судья на '
            'карточке это isAbstinenceLapse, а не «есть ли строка в '
            'журнале»');
  });

  testWidgets(
      'a journal line that never became a day value gives the subtitle '
      'nothing to say', (tester) async {
    // Перекочевало из удалённого `abstinence_screen_test.dart` (Задача 12).
    // Ревью нашло: судья был один — `isAbstinenceLapse`, — а входа два.
    // Подпись спрашивала журнал, а число, ячейка, сетка календаря и «Всего» —
    // значения дней. Расходятся они на пропуске: он приезжает восстановлением
    // копии из Loop, `DayWriter` его не переписывает
    // (`computed.day-write#4`), и строка журнала, поданная на такой день,
    // остаётся строкой без дня. Карточка говорила разом «40 дней без срыва» и
    // «Последний срыв: <дата>», пока сетка показывала пропуск, а «Всего» —
    // ноль.
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

    await pumpHabit(tester, habit);

    expect(find.textContaining('Последний срыв'), findsNothing,
        reason: 'computed.abstinence-screen#2 — подпись читает те же '
            'значения дней, что и всё остальное на карточке: один судья и '
            'один вход (`computed.abstinence-cell#2`, '
            '`computed.lapse-score#5`)');
    expect(find.textContaining('С '), findsOneWidget,
        reason: 'computed.abstinence-screen#2 — срыва не было, и подпись '
            'говорит «С <день обязательства>», как счётчик рядом с ней');
    expect(find.text('0'), findsOneWidget,
        reason: 'computed.abstinence-screen#4 — «Всего» считает те же дни, '
            'и этого дня среди них нет');
  });

  testWidgets('a lapse before the commitment day does not count toward the '
      'total', (tester) async {
    // Перекочевало из удалённого `abstinence_screen_test.dart` (Задача 12):
    // тот же охранник, что не красит клетку до обязательства
    // (`computed.abstinence-cell#3`) — судья один, и счёт спрашивает его же.
    await pumpOverview(tester,
        committedFrom: today - 10, lapses: <int>[today - 50]);

    expect(find.text('0'), findsOneWidget,
        reason: 'computed.abstinence-screen#4 — срыв старше обязательства не '
            'срыв этого обязательства');
  });
}
