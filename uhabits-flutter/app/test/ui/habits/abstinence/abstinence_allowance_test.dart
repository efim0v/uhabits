/// Допуск больше нуля: жест спрашивает величину, и трое отвечают одинаково.
///
/// «Не более 30 минут» без числа не выражается. Молчаливый `amount = 1` при
/// допуске 30 записал бы день, который обещание держит, а покрасил бы его как
/// срыв — и тогда ячейка говорила бы «сорвался», счётчик «сорок дней без
/// срыва», а балл не шелохнулся бы. Здесь эти трое спрошены об одном дне.
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
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;
  late Habit habit;

  /// «Не более [allowance] минут в день», обещание дано сорок дней назад.
  ///
  /// Допуск пишется в двух местах одним движением, потому что судьи два лица
  /// одного числа: `payload` читает интерфейс, `targetValue` — оценка
  /// (`computed.allowance#1`).
  void commit({required double allowance}) {
    habit.targetValue = allowance;
    scope.habitList.update(<Habit>[habit]);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: getToday().daysSince2000 - 40,
        payload: abstinencePayload(
          allowance: allowance,
          unit: allowance == 0.0
              ? abstinenceUnitCount
              : abstinenceUnitMinutes,
        ),
      ),
    );
    attachDefinition(habit, scope.definitions);
    habit.recompute();
  }

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_allowance');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;

    habit = scope.modelFactory.buildHabit()
      ..name = 'Screen time'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 30
      ..unit = 'minutes';
    scope.habitList.add(habit);
    commit(allowance: 30.0);
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  Widget list() => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  Widget screen() => MaterialApp(
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

  AbstinenceCell cellToday(WidgetTester tester) => (tester
          .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(getToday())))
          .view as AbstinenceButtonView)
      .cell;

  Future<void> tapToday(WidgetTester tester) async {
    await tester.pumpWidget(list());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, String amount) async {
    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8 — при допуске больше нуля тап '
            'спрашивает величину');
    await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')), amount);
    await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
    await tester.pumpAndSettle();
  }

  // Локальным геттером это не выразить: `get` внутри тела функции
  // Dart не принимает.
  int todayDay() => getToday().daysSince2000;

  testWidgets('computed.abstinence-cell#8 двадцать минут при допуске тридцать '
      'обещание держат, и трое согласны', (tester) async {
    await tapToday(tester);
    await answer(tester, '20');

    // Журнал записал двадцать, а не «единицу»: величина есть факт дня.
    expect(scope.lapses.forDay(habit.id!, todayDay()), 20,
        reason: 'computed.abstinence-cell#8');

    // Первый из троих — ячейка списка.
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2 — «не более 30» обещание держит');

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // Второй — кнопка карточки.
    expect(find.text('Отметить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5 — предлагать «Отменить срыв» '
            'там, где срыва не было, значит спорить с ячейкой');
    // Третий — счётчик.
    expect(find.text('40'), findsOneWidget,
        reason: 'computed.streak#4 — двадцать минут серию не рвут');
  });

  testWidgets('computed.abstinence-cell#8 сорок пять минут — срыв, и трое '
      'согласны с этим', (tester) async {
    await tapToday(tester);
    await answer(tester, '45');

    expect(scope.lapses.forDay(habit.id!, todayDay()), 45,
        reason: 'computed.abstinence-cell#8');
    expect(cellToday(tester), AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Отменить срыв'), findsOneWidget,
        reason: 'computed.abstinence-screen#5');
    expect(find.text('0'), findsWidgets,
        reason: 'computed.streak#5 — срыв сегодня обнуляет счётчик');
  });

  testWidgets('computed.abstinence-cell#8 вопрос без ответа фактом не '
      'становится', (tester) async {
    await tapToday(tester);

    expect(find.byType(NumberDialog), findsOneWidget,
        reason: 'computed.abstinence-cell#8');
    Navigator.of(tester.element(find.byType(NumberDialog))).pop();
    await tester.pumpAndSettle();

    expect(scope.lapses.forDay(habit.id!, todayDay()), isNull,
        reason: 'computed.abstinence-cell#8');
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#5 — и оптимистичная краска снята: '
            'перерисовать список тут нечему, и крест остался бы висеть');
  });

  testWidgets('computed.abstinence-cell#8 ноль — это молчание, а не срыв',
      (tester) async {
    // Ноль удовлетворяет «не больше допуска» при любом допуске, то есть
    // означает «ничего не было». Молчание есть отсутствие строки
    // (`computed.lapses#1`, `#2`), поэтому ноль в ответе равен отказу.
    await tapToday(tester);
    await answer(tester, '0');

    expect(scope.lapses.forDay(habit.id!, todayDay()), isNull,
        reason: 'computed.abstinence-cell#8');
    expect(cellToday(tester), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#8');
  });

  testWidgets('computed.abstinence-cell#8 при допуске ноль вопроса нет',
      (tester) async {
    commit(allowance: 0.0);

    await tapToday(tester);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#6 — общая дверь числа закрыта, и на '
            'умолчании лишнего шага нет');
    expect(scope.lapses.forDay(habit.id!, todayDay()),
        LapseRepository.minimumAmount,
        reason: 'computed.abstinence-cell#8 — тап пишет одну единицу, как и '
            'было');
    expect(cellToday(tester), AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#2');
  });

  testWidgets('computed.abstinence-cell#8 снятие срыва величины не спрашивает',
      (tester) async {
    await tapToday(tester);
    await answer(tester, '45');

    await tester.tap(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#8 — «этого не было» количества не '
            'имеет');
    expect(scope.lapses.forDay(habit.id!, todayDay()), isNull,
        reason: 'computed.abstinence-cell#5');
  });
}
