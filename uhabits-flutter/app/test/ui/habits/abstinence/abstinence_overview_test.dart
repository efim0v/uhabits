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

  /// Привычка-воздержание, обязательство с [committedFrom], срывы в
  /// перечисленные дни [lapses] — как `addAbstinence` в
  /// `abstinence_screen_test.dart`.
  Habit addAbstinence({required int committedFrom}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sober'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0
      ..unit = '';
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
  });

  testWidgets('the button is here, because it has nowhere else to be',
      (tester) async {
    await pumpOverview(tester, committedFrom: today - 40, lapses: const []);

    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — жест переехал вместе с '
            'числами, а не потерялся между ними');
  });
}
