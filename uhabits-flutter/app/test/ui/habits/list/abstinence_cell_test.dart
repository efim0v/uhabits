/// Тап по ячейке воздержания на настоящем экране списка.
///
/// Запрет на ввод числа вычисляемой привычке уже стоит и проверен
/// `computed_list_edit_test.dart`. Здесь проверяется, что второй житель слоя
/// проходит мимо этого запрета не в обход его, а другой дверью: журнал срывов.
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
import 'package:uhabits/ui/habits/list/entry_button_views.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/sleep/manual_entry_sheet.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_cell');
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  /// Воздержание: числовая привычка с целью «не больше нуля» и определением,
  /// у которого есть день обещания.
  ///
  /// [committedFrom] принимает и null: неполное определение — тоже определение
  /// воздержания, и признаком ячейки оно быть не должно
  /// (`computed.abstinence-cell#7`).
  Habit addAbstinence(AppScope scope, {required int? committedFrom}) {
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

  /// Сон, чья строка определения несёт день обещания.
  ///
  /// Столбец `committed_from` принадлежит строке, а не виду: `save` берёт его у
  /// любого вида, а `DefinitionImporter` копирует строку целиком — значит такая
  /// строка приезжает с чужого устройства и лежит в базе, не спросив никого.
  /// Признаком воздержания она быть не должна: метка вида есть `kind`.
  Habit addSleep(AppScope scope, {required int committedFrom}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = HabitType.numerical
      ..unit = 'h'
      ..targetValue = 100;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.sleep,
        committedFrom: committedFrom,
      ),
    );
    habit.recompute();
    return habit;
  }

  Widget wrap(AppScope scope) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  Future<void> tapToday(WidgetTester tester) async {
    await tester.tap(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();
  }

  AbstinenceCell cellAt(WidgetTester tester, LocalDate date) => (tester
          .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(date)))
          .view as AbstinenceButtonView)
      .cell;

  /// Срыв ли этот день — спрошено у того же судьи, что судит оценку.
  ///
  /// Не `значение > Entry.skip`: при допуске больше нуля запись в дне есть, а
  /// срыва нет, и «есть запись» ответило бы не на тот вопрос.
  bool lapsedOn(AppScope scope, Habit habit, LocalDate date) =>
      isAbstinenceLapseDay(scope.definitions.forHabit(habit.id!)!,
          habit.originalEntries.get(date).value);

  testWidgets('computed.abstinence-cell#5 тап записывает срыв, повторный '
      'снимает', (tester) async {
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);

    expect(scope.lapses.lastDay(habit.id!), today,
        reason: 'computed.abstinence-cell#5');
    expect(lapsedOn(scope, habit, getToday()), isTrue,
        reason: 'computed.abstinence-cell#5 — день пересчитан, а не только '
            'записан в журнал');

    await tapToday(tester);

    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-cell#5');
    expect(lapsedOn(scope, habit, getToday()), isFalse,
        reason: 'computed.abstinence-cell#5 — отмена возвращает день в тишину');
  });

  testWidgets('computed.abstinence-cell#6 числового окна нет ни на тапе, ни '
      'на долгом нажатии', (tester) async {
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    addAbstinence(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);
    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#6');

    await tester.longPress(find.byKey(EntryPanel.buttonKey(getToday())));
    await tester.pumpAndSettle();
    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#6 — тот же запрет, что у сна без '
            'ночи (computed.write-paths#3)');
  });

  testWidgets('computed.abstinence-cell#5 список перерисовывается сам',
      (tester) async {
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    addAbstinence(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);
    // Кэш списка обязан отдать пересчитанное значение: оптимистичная краска
    // стирается в didUpdateWidget, и если хук инвалидации не дёрнут, ячейка
    // вернётся к чистой.
    await tester.pumpAndSettle();

    final AbstinenceButtonView view = tester
        .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(getToday())))
        .view as AbstinenceButtonView;
    expect(view.cell, AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#5 — onComputedDataChanged');
  });

  testWidgets('computed.abstinence-cell#2 ячейка идёт за допуском, а не за '
      'тем, что её однажды нарисовало', (tester) async {
    // Единственный случай, где «нарисовано» и «сорвался» расходятся: запись за
    // день осталась прежней, а допуск под ней стал другим. Тап тут ни при чём,
    // и перекрасить ячейку обязано определение.
    //
    // Две памяти на этом пути, и обе живут ровно до следующего
    // [HabitListModel.notifyListeners]: мемо определения в модели и
    // оптимистичная краска в панели. Пережившая своё, любая из них показала бы
    // крест на дне, который допуск простил.
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    final Habit habit = addAbstinence(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);
    expect(cellAt(tester, getToday()), AbstinenceCell.lapse,
        reason: 'computed.abstinence-cell#5 — при допуске ноль одна единица '
            'уже срыв');

    // Ровно то, что делает редактор, сохраняя новый допуск
    // (`_writeAbstinenceRow` в state/edit_habit_model.dart). Целевое значение
    // идёт вместе с ним: допуск и `targetValue` — одно и то же число, названное
    // дважды (`computed.allowance#1`).
    habit.targetValue = 30;
    scope.habitList.update(<Habit>[habit]);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: today - 40,
        payload: abstinencePayload(allowance: 30),
      ),
    );
    attachDefinition(habit, scope.definitions);
    habit.recompute();
    scope.onComputedDataChanged(habit.id!);
    await tester.pumpAndSettle();

    expect(cellAt(tester, getToday()), AbstinenceCell.clean,
        reason: 'computed.abstinence-cell#2 — одна единица тридцати не больше, '
            'и своего порога у интерфейса нет');
  });

  testWidgets('computed.abstinence-cell#7 определение без дня обещания '
      'оставляет ячейку числовой', (tester) async {
    // Не «не воздержание»: `isNot(isA<AbstinenceButtonView>())` зелено и тогда,
    // когда ячейку не рисует вообще ничего. Спрошено, чем она стала.
    final AppScope scope = openScope();
    final Habit habit = addAbstinence(scope, committedFrom: null);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<EntryButton>(find.byKey(EntryPanel.buttonKey(getToday())))
            .view,
        isA<NumberButtonView>(),
        reason: 'computed.abstinence-cell#7 — судить день как чистый или '
            'сорванный тогда не от чего, и привычка остаётся числовой');

    await tapToday(tester);

    expect(find.byType(NumberDialog), findsNothing,
        reason: 'computed.abstinence-cell#7 — и упирается в общий отказ '
            '(computed.write-paths#3)');
    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.abstinence-cell#7 — и второй дверью тоже ничего не '
            'пишет');
  });

  testWidgets('computed.write-paths#4 день обещания в строке сна ячейкой '
      'воздержания её не делает', (tester) async {
    final AppScope scope = openScope();
    final int today = getToday().daysSince2000;
    final Habit habit = addSleep(scope, committedFrom: today - 40);

    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
    await tapToday(tester);

    expect(find.byType(ManualEntrySheet), findsOneWidget,
        reason: 'computed.write-paths#4 — жест сна открывает ночь, из которой '
            'день считается');
    expect(scope.lapses.lastDay(habit.id!), isNull,
        reason: 'computed.write-paths#4 — и не заводит сну журнал срывов: '
            'меткой воздержания служит вид, а не день обещания');
  });
}
