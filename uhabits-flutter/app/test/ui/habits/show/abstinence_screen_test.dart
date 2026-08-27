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
import 'package:uhabits/ui/habits/abstinence/abstinence_counter.dart';
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
