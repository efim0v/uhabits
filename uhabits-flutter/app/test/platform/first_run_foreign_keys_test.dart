/// Foreign keys on the connection a first run is handed.
///
/// `pragma foreign_keys` is per connection and defaults to OFF, and
/// `applyConnectionSettings` deliberately withholds it below schema 22: a file
/// older than that still holds the orphaned rows migration 22 exists to
/// delete. The opener applies the settings the moment the file is open, which
/// for a brand new file is version 0 — so that call is a no-op, and it is fair
/// to ask what turns the keys on for the rest of the session.
///
/// The answer is `migrateTo`, which replays a script's connection pragmas once
/// the upgrade has committed, exactly so that migration 22's own
/// `pragma foreign_keys=ON` is not lost inside the transaction
/// (`persistence.migration-v22#6`). A fresh file is stamped 8 and climbs
/// through 22, so it gets the pragma on the way past.
///
/// Nothing asserted that against the path the app really opens with: every
/// existing assertion goes through `migrateTo` directly or through the test
/// helper `openAppSchemaDatabase()`, which applies the settings itself
/// afterwards and would keep passing however `AppDatabase.openAndMigrate`
/// behaved. This file asks the production path, because the cascade
/// `computed.schema#2` rests on the answer.
library;

// The task runner's test dispatcher is reached by its `src` path, exactly as
// the other app tests reach it.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    setToday(LocalDate(9000));
    tempDir = Directory.systemTemp.createTempSync('uhabits_first_run_fk');
  });

  tearDown(() {
    resetToday();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// A first run: the file does not exist until the app opens it.
  Database openFirstRun() {
    final Database db = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    addTearDown(db.close);
    return db;
  }

  AppScope scopeOver(Database db) {
    final AppScope scope = AppScope.open(
      db,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    addTearDown(scope.close);
    return scope;
  }

  test('the connection a first run gets enforces foreign keys', () {
    final Database db = openFirstRun();

    expect(db.getVersion(), appDatabaseVersion,
        reason: 'persistence.migration-v22#6 — a fresh file really is brought '
            'all the way up on this connection');
    expect(db.queryInt('pragma foreign_keys'), 1,
        reason: 'persistence.migration-v22#6 — enforcement is a '
            'per-connection setting, and the connection a first run is handed '
            'is a connection like any other');
  });

  test('so deleting a habit on a first run takes its definition with it', () {
    final Database db = openFirstRun();
    final AppScope scope = scopeOver(db);

    final Habit habit = scope.modelFactory.buildHabit()..name = 'Sleep';
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    LapseRepository(db).save(habit.id!, 9000, amount: 45);

    scope.habitList.remove(habit);

    expect(db.queryInt('select count(*) from HabitDefinitions'), 0,
        reason: 'computed.schema#2');
    expect(db.queryInt('select count(*) from SleepGoals'), 0,
        reason: 'computed.schema#2 — the goal is on the same cascade');
    expect(db.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.schema#5 — the lapse journal is on the same '
            'cascade');
  });

  test('and no later habit can inherit the mark, because ids are not reused',
      () {
    // `Habits.id` is `integer primary key autoincrement`, so sqlite keeps the
    // counter in sqlite_sequence and never hands a deleted id out again. If a
    // migration ever rebuilt the table without AUTOINCREMENT, the next habit
    // created after a deletion would take the deleted one's id — and, on any
    // connection where the cascade had not run, its mark.
    final Database db = openFirstRun();
    final AppScope scope = scopeOver(db);

    final Habit first = scope.modelFactory.buildHabit()..name = 'Sleep';
    scope.habitList.add(first);
    final int idUsed = first.id!;
    scope.definitions
        .save(idUsed, const HabitDefinition(kind: ComputedKind.sleep));
    scope.habitList.remove(first);

    final Habit second = scope.modelFactory.buildHabit()..name = 'Meditate';
    scope.habitList.add(second);

    expect(second.id, isNot(idUsed), reason: 'computed.schema#2');
    expect(scope.definitions.isComputed(second.id!), isFalse,
        reason: 'computed.schema#2 — a new habit is not computed because an '
            'older one at its id was');
  });
}
