/// The pair: a sleep goal and the definition that says the habit is computed.
///
/// Half the app asks "is this a sleep habit" of `SleepGoals` and half asks "is
/// this computed" of `HabitDefinitions`. The two answers agree only because
/// every path that makes a sleep habit writes both rows — and nothing in the
/// schema says so. A path that wrote one and not the other would leave a habit
/// that half the app treats as computed and half does not: its widget taps
/// refused but its calendar still typing values in, or the sync writing nights
/// into a habit randomise is happy to clear.
///
/// So the invariant is asserted here, once, against every way a sleep habit can
/// come to exist on a device: made here, inherited from an older file, or
/// restored from a backup.
library;

// The core's repositories and importers are reached by their `src` path,
// exactly as lib/state and lib/ui do.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits/ui/settings/data_actions.dart' show buildGenericImporter;
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/extension_migrations.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_session_repository.dart';
import 'package:uhabits_core/src/time/local_date.dart';

const String pairing = 'computed.definition#8';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    setToday(LocalDate.ymd(2016, 3, 20));
    tempDir = Directory.systemTemp.createTempSync('uhabits_sleep_pairing');
  });

  tearDown(() {
    resetToday();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Every habit with a sleep goal, and every habit marked computed by sleep.
  /// The invariant is that these two lists are the same list.
  (List<int>, List<int>) pairsIn(Database db) {
    final List<int> goals = <int>[];
    db.query('select habit from SleepGoals order by habit', const <String>[],
        (stmt) => goals.add(stmt.getInt(0)));
    final List<int> definitions = <int>[];
    db.query(
        "select habit from HabitDefinitions where kind = 'sleep' "
        'order by habit',
        const <String>[],
        (stmt) => definitions.add(stmt.getInt(0)));
    return (goals, definitions);
  }

  void expectPaired(Database db, {required int count}) {
    final (List<int> goals, List<int> definitions) = pairsIn(db);
    expect(goals, hasLength(count),
        reason: '$pairing — the check is only worth making if the database '
            'holds the sleep habits the test made');
    expect(definitions, goals,
        reason: '$pairing — a habit with a sleep goal has a definition of '
            'kind sleep, and a habit marked sleep has a goal');
  }

  test('a sleep habit made on this device has both rows', () async {
    final Database db = AppDatabase.openAndMigrate('${tempDir.path}/made.db');
    final AppScope scope = AppScope.open(db);
    addTearDown(scope.close);

    final EditHabitModel model = EditHabitModel(scope: scope, sleep: true);
    model.nameController.text = 'Sleep';
    model.save();
    await pumpEventQueue(times: 20);

    expectPaired(db, count: 1);
  });

  test('a sleep habit inherited from an older file gets both', () {
    // A file written by the build before the definitions table existed: the
    // goal is there and there is nowhere yet for the mark to go.
    final String path = '${tempDir.path}/older.db';
    // The app's opener refuses to create a missing file, exactly as Android's
    // OPEN_READWRITE does, so the empty file is placed first.
    File(path).createSync(recursive: true);
    final Database old = const Sqlite3DatabaseOpener().open(path);
    old.setVersion(8);
    old.migrateTo(
        firstExtensionVersion + 1, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(old);
    final SQLModelFactory factory = SQLModelFactory(old);
    final Habit habit = factory.buildHabit()..name = 'Sleep';
    factory.buildHabitList().add(habit);
    SleepSessionRepository(old, () => 0).saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    old.close();

    // And now this build opens it, which is the only thing that happens.
    final Database db = AppDatabase.openAndMigrate(path);
    addTearDown(db.close);

    expectPaired(db, count: 1);
  });

  test('a sleep habit restored from a backup gets both', () async {
    // The backup is a byte-for-byte copy, so both rows are inside the file —
    // but under the id the other device used. The restore re-keys the habit.
    final String backupPath = '${tempDir.path}/backup.db';
    final Database source = AppDatabase.openAndMigrate(backupPath);
    final AppScope there = AppScope.open(source);
    final EditHabitModel making = EditHabitModel(scope: there, sleep: true);
    making.nameController.text = 'Sleep';
    making.save();
    await pumpEventQueue(times: 20);
    there.close();

    final Database db = AppDatabase.openAndMigrate('${tempDir.path}/here.db');
    final AppScope scope = AppScope.open(db);
    addTearDown(scope.close);
    // This device is not empty, so the restored habit takes an id that is not
    // the one it had in the file.
    for (int i = 0; i < 4; i++) {
      scope.habitList.add(scope.modelFactory.buildHabit()..name = 'Mine $i');
    }

    await buildGenericImporter(
      scope: scope,
      fileOpener: const _UnusedFileOpener(),
    ).importHabitsFromFile(LocalUserFile(backupPath));

    expectPaired(db, count: 1);
  });
}

/// The backup is already at this build's schema version, so no migration
/// script is ever read; anything asking for one is a change of behaviour that
/// should be seen rather than quietly served.
class _UnusedFileOpener implements FileOpener {
  const _UnusedFileOpener();

  @override
  ResourceFile openResourceFile(String path) =>
      throw UnsupportedError('No resource file should be opened: $path');

  @override
  UserFile openUserFile(String path) =>
      throw UnsupportedError('No user file should be opened: $path');
}
