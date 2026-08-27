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

  testWidgets('computed.abstinence-screen#3 счётчик стоит выше портированных '
      'карточек', (tester) async {
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(committedFrom: today - 40);

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    final double counter =
        tester.getTopLeft(find.byKey(AbstinenceCounterCard.cardKey)).dy;
    final double subtitle = tester
        .getTopLeft(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.subtitle)))
        .dy;
    expect(counter, lessThan(subtitle),
        reason: 'computed.abstinence-screen#3');
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
