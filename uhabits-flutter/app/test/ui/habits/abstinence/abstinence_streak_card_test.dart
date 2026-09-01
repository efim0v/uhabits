/// «Лучшие серии» воздержания: точная длительность в полосе.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_overview.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_streak_card.dart';
import 'package:uhabits/ui/habits/show/cards/streak_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;
  late int today;
  late int Function() realClock;

  /// Шесть часов двенадцать минут после полуночи сегодняшнего дня.
  ///
  /// Часы прибиты, и зона вместе с ними: длительность серии считается от
  /// полуночи в зоне человека, и на плавающей зоне перевод часов внутри
  /// проверяемого отрезка сдвинул бы ответ на час.
  late int nowMillis;

  setUp(() {
    realClock = core_time.systemCurrentTimeMillis;
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_streak');
    // `AppScope.open` и назначает сегодняшний день; читать его до этого
    // нечего, а прибивать часы раньше незачем.
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
    today = getToday().daysSince2000;
    nowMillis = LocalDate(today).unixTime + 6 * 3600000 + 12 * 60000;
    core_time.systemCurrentTimeMillis = () => nowMillis;
  });

  tearDown(() {
    core_time.systemCurrentTimeMillis = realClock;
    core_time.DateUtils.setFixedTimeZone(null);
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  /// Привычка-воздержание, обязательство с [committedFrom] — как
  /// `addAbstinence` в `abstinence_overview_test.dart`.
  Habit addAbstinence({required int committedFrom}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sober'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0;
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
        payload: abstinencePayload(),
      ),
    );
    attachDefinition(habit, scope.definitions);
    habit.recompute();
    return habit;
  }

  Future<void> pumpScreen(WidgetTester tester, Habit habit) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('ru'),
      home: Provider<AppScope>.value(
        value: scope,
        child: ShowHabitScreen(habit: habit),
      ),
    ));
    await tester.pumpAndSettle();
  }

  StreakChartView chartOf(WidgetTester tester) => tester
      .widget<CoreView>(find.descendant(
        of: find.byType(StreakCardView),
        matching: find.byType(CoreView),
      ))
      .view as StreakChartView;

  testWidgets('computed.since#8 the card prints the exact length of every '
      'streak', (tester) async {
    // Обязательство сорок дней назад, срывы на тридцатом и на двадцатом:
    // две завершённые серии и одна идущая.
    final Habit habit = addAbstinence(committedFrom: today - 40);
    for (final int day in <int>[today - 30, today - 20]) {
      scope.abstinence.setLapse(habit, LocalDate(day), true);
    }
    await pumpScreen(tester, habit);

    expect(
      chartOf(tester).durations,
      <String>['19 дней 06:12', '9 дней 00:00', '10 дней 00:00'],
      reason: 'computed.since#8 — идущая серия считается до «сейчас», а '
          'завершённая — от мгновения одного срыва до мгновения следующего. '
          'Моментов у отмеченных задним числом срывов нет вовсе '
          '(`computed.since#7`), и от полуночи до полуночи между ними ровно '
          'целые сутки: «00:00» — не выдумка, а всё, что про такую серию '
          'известно',
    );
  });

  testWidgets('computed.since#8 the days it prints are the days the counter '
      'counts', (tester) async {
    // Двадцать суток: короче месяца, и потому счётчик читает их сутками, а
    // не «месяц и девять дней» (`computed.since#6`) — сравнивать есть что.
    final Habit habit = addAbstinence(committedFrom: today - 20);
    await pumpScreen(tester, habit);

    expect(chartOf(tester).durations, <String>['20 дней 06:12'],
        reason: 'computed.since#8 — двадцать суток от полуночи обязательства '
            'плюс шесть часов двенадцать минут сегодняшних');
    expect(
      tester.widget<Text>(find.byKey(AbstinenceOverviewCard.counterKey)).data,
      '20 дней 6 часов 12 минут',
      reason: 'computed.since#8 — счётчик над карточкой и надпись в полосе '
          'считают одни и те же два мгновения, и расходиться им не в чем',
    );
    expect(chartOf(tester).lengths, <int>[20],
        reason: 'computed.streak#6 — полосу по-прежнему меряет число чистых '
            'суток, то же самое, что едет в документ виджета, и здесь оно '
            'совпадает с напечатанным: моментов срыва в журнале нет, а от '
            'полуночи до «сейчас» полных суток ровно столько же');
  });

  testWidgets('computed.since#10 midnight does not stop a streak no lapse '
      'stopped', (tester) async {
    final Habit habit = addAbstinence(committedFrom: today - 20);
    await pumpScreen(tester, habit);
    expect(chartOf(tester).durations, <String>['20 дней 06:12'],
        reason: 'computed.since#10 — до полуночи');

    // Полночь. «Сегодня» переезжает, а список серий — нет: экран привычки
    // полуночи не слушает и привычку не пересчитывает. Часы двигаются тем же
    // крюком, каким их двигает поминутный таймер карточки.
    setToday(LocalDate(today + 1));
    nowMillis = LocalDate(today + 1).unixTime + 6 * 3600000 + 13 * 60000;
    await tester.pump(const Duration(minutes: 1));

    expect(chartOf(tester).streaks.single.end, LocalDate(today),
        reason: 'computed.since#10 — список серий остался вчерашним, и это '
            'условие проверки, а не её вывод');
    expect(chartOf(tester).durations, <String>['21 день 06:13'],
        reason: 'computed.since#10 — серия идёт: срыва на дне после её конца '
            'нет. Спроси карточка «конец старше сегодня?», она напечатала бы '
            '«21 день 00:00» — главное число на карточке молча стало бы '
            'неверным и стояло бы так до следующей перерисовки экрана');
  });

  testWidgets('computed.since#10 only a lapse ends a streak — a skip on the '
      'day after does not', (tester) async {
    // Пропуск, поставленный диапазоном на завтра: значение у дня после конца
    // серии есть, а срывом оно не является. Судья на этом и стоит — грубое
    // «что-то записано» ответило бы «серия кончена» и заморозило бы надпись
    // (`computed.abstinence-cell#4`, `computed.streak#7`).
    final Habit habit = addAbstinence(committedFrom: today - 20);
    habit.originalEntries.add(Entry(LocalDate(today + 1), Entry.skip));
    habit.recompute();
    await pumpScreen(tester, habit);

    expect(habit.computedEntries.get(LocalDate(today + 1)).value, Entry.skip,
        reason: 'computed.since#10 — условие проверки: у дня после конца '
            'серии значение есть');
    expect(chartOf(tester).streaks.single.end, LocalDate(today),
        reason: 'computed.streak#6 — хвост окна в серию не входит, и конец '
            'у неё сегодняшний');
    expect(chartOf(tester).durations, <String>['20 дней 06:12'],
        reason: 'computed.since#10 — серия идёт: пропуск не срыв, и судья тут '
            'тот же, что не даёт клетке календаря принять пропуск за срыв');
  });

  testWidgets('computed.since#8 a habit the original knows keeps the ported '
      'card', (tester) async {
    final Habit habit = scope.modelFactory.buildHabit()..name = 'Meditate';
    scope.habitList.add(habit);
    habit.recompute();

    await pumpScreen(tester, habit);

    expect(find.byType(AbstinenceStreakCard), findsNothing,
        reason: 'computed.since#8 — обёртка ставится только воздержанию');
    expect(chartOf(tester).durations, isNull,
        reason: 'computed.since#8 — без шва карточка печатает число суток, '
            'как порт');
  });

  testWidgets('computed.since#8 the running streak moves with the clock, and '
      'the timer does not survive the card', (tester) async {
    final Habit habit = addAbstinence(committedFrom: today - 20);
    await pumpScreen(tester, habit);

    expect(chartOf(tester).durations, <String>['20 дней 06:12'],
        reason: 'computed.since#8');

    // Минута вперёд — граница, на которой обязана сдвинуться младшая единица
    // надписи, ровно как она сдвигается у счётчика.
    nowMillis += 60000;
    await tester.pump(const Duration(minutes: 1));

    expect(chartOf(tester).durations, <String>['20 дней 06:13'],
        reason: 'computed.since#8 — надпись идущей серии идёт сама, а не '
            'ждёт, когда экран перерисуют по другому поводу');

    // Карточка уходит с экрана — и таймер уходит с ней: не отменённый в
    // `dispose`, он позвал бы `setState` на мёртвом `State`, а прогон упал бы
    // на проверке «A Timer is still pending even after the widget tree was
    // disposed».
    await tester.pumpWidget(const SizedBox.shrink());
    nowMillis += 60000;
    await tester.pump(const Duration(minutes: 1));

    expect(tester.takeException(), isNull,
        reason: 'computed.since#8 — таймер остановлен в dispose');
  });
}
