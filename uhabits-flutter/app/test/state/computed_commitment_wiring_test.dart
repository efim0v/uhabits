/// Определение доезжает до живой привычки.
///
/// Поле `Habit.definition` — единственный способ, которым пересчёт узнаёт день
/// обязательства, и заполняет его ровно одно место: открытие приложения. Если
/// прикрепление отвалится, привычка не сломается заметно — она просто станет
/// считаться с сегодняшнего дня, и «дней без срыва» навсегда останется единицей.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/computed/days_without_lapse.dart';
import 'package:uhabits_core/src/computed/definition_repository.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_commitment');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  // Абсолютная дата, а не смещение от сегодня: AppScope.open сам ставит
  // сегодня по часам устройства, так что заморозить его снаружи нельзя.
  final LocalDate committed = LocalDate.ymd(2020, 1, 1);

  /// Кладёт на диск привычку-воздержание с определением и поднимает над этим
  /// файлом настоящий `AppScope`, как это делает запуск приложения. Отдаёт ту
  /// привычку, которую подняла со старта сама область, а не ту, что положили.
  Habit openWithAbstinenceOnDisk() {
    final Database db =
        AppDatabase.openAndMigrate('${tempDir.path}/commitment.db');
    final SQLModelFactory factory = SQLModelFactory(db);
    final Habit habit = factory.buildHabit()
      ..name = 'No sugar'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0;
    factory.buildHabitList().add(habit);
    DefinitionRepository(db).save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committed.daysSince2000,
      ),
    );

    final AppScope scope = AppScope.open(db);
    addTearDown(scope.close);
    return scope.habitList.getById(habit.id!)!;
  }

  test('a habit loaded at startup knows the day it was committed to', () {
    final Habit loaded = openWithAbstinenceOnDisk();

    expect(loaded.definition?.kind, ComputedKind.abstinence,
        reason: 'computed.commitment#5');
    expect(loaded.definition?.committedFrom, committed.daysSince2000,
        reason: 'computed.commitment#5');
    // И, главное, пересчёт на старте уже это учёл: без прикрепления счёт был
    // бы равен единице — окно началось бы сегодня.
    expect(daysWithoutLapse(loaded), committed.daysUntil(getToday()),
        reason: 'computed.commitment#5');
    expect(daysWithoutLapse(loaded), greaterThan(2000),
        reason: 'computed.commitment#5');
  });

  // И включатель деления пополам — там же, одной дверью: правило
  // `computed.lapse-score#11` обязано быть процитировано и юнит-тестом функции,
  // и тестом проводки, иначе цитата означает «функция работает», а не «фича
  // включена» (`computed.lapse-score#12`). Двумя тестами, а не двумя ожиданиями
  // одного: снятие включателя роняет первое ожидание, и до балла — того самого,
  // ради которого всё и затевалось — очередь бы не дошла.
  test('a habit raised from disk is scored by halving', () {
    final Habit loaded = openWithAbstinenceOnDisk();

    expect(loaded.scores.halvesOnLapse, isTrue,
        reason: 'computed.lapse-score#11 — привычка, поднятая с диска, '
            'считается делением, а не затуханием порта');
  });

  test('and the halving is visible in the score that lapse produces', () {
    final Habit loaded = openWithAbstinenceOnDisk();

    loaded.originalEntries.add(Entry(getToday(), 1000));
    loaded.recompute();

    // Затухание порта на том же срыве оставило бы 0.948 — от идеального года
    // не отличить.
    expect(loaded.scores[getToday()].value, lessThan(0.6),
        reason: 'computed.lapse-score#12 — и это видно на настоящем балле');
  });
}
