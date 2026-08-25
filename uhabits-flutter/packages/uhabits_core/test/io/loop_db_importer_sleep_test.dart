/// What a restored backup does with a sleep habit.
///
/// A backup is a byte-for-byte copy of the database, so the goal and every
/// recorded night are always inside the file. The import is where they can be
/// lost: habits are matched by uuid and take whatever id is free here, while
/// every sleep row in the file is filed under the id the other device used.
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/extension_migrations.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/io/loop_db_importer.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_importer.dart';
import 'package:uhabits_core/src/sleep/sleep_session_repository.dart';
import 'package:uhabits_core/src/sleep/stored_value.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import 'loop_db_importer_test.dart' show assetsFileOpener;

const SleepGoal goal = SleepGoal(
  bedMinutes: 1385,
  wakeMinutes: 405,
  minSleepMinutes: 460,
  weightSleep: 0.5,
  weightBed: 0.2,
  weightWake: 0.3,
  homeUtcOffsetMinutes: 300,
);

SleepEpisode nightOn(int day, {int offsetMinutes = 300}) {
  final int wake = (day + 10957) * 86400000 + 405 * 60000 - offsetMinutes * 60000;
  return SleepEpisode(
    bedStartMillis: wake - 470 * 60000,
    wakeEndMillis: wake,
    asleepMinutes: 455,
    utcOffsetMinutes: offsetMinutes,
    sourceId: 'watch',
  );
}

/// A database file with the current schema, empty.
(Database, String) makeDatabaseFile(String prefix) {
  final Directory dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final String path = '${dir.path}/habits.db';
  // The opener only opens what is already there — it is the app's own opener,
  // and the app's database file is created for it elsewhere.
  final Database db = Sqlite3Database(sqlite3.open(path));
  db.setVersion(8);
  db.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
  applyConnectionSettings(db);
  return (db, path);
}

void main() {
  setUp(() => setToday(LocalDate.ymd(2016, 3, 20)));
  tearDown(resetToday);

  late Database destination;
  late HabitList destinationList;
  late SleepSessionRepository here;

  setUp(() {
    final (Database db, _) = makeDatabaseFile('uhabits_sleep_dest');
    destination = db;
    destinationList = SQLModelFactory(destination).buildHabitList();
    here = SleepSessionRepository(destination, () => 1770000000000);
  });

  tearDown(() => destination.close());

  /// A file holding one sleep habit, its goal, and [days] nights.
  UserFile backupWith({
    required String uuid,
    required List<int> days,
    Set<int> manualDays = const <int>{},
    // Deliberately several: the whole point is that the habit's id in the file
    // is not the id it will be given here.
    int decoys = 3,
  }) {
    final (Database source, String path) = makeDatabaseFile('uhabits_sleep_src');
    final HabitList list = SQLModelFactory(source).buildHabitList();
    final SQLModelFactory factory = SQLModelFactory(source);
    for (int i = 0; i < decoys; i++) {
      list.add(factory.buildHabit()..name = 'Other $i');
    }
    final Habit habit = factory.buildHabit()
      ..name = 'Sleep'
      ..uuid = uuid
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    list.add(habit);

    final SleepSessionRepository there =
        SleepSessionRepository(source, () => 1760000000000);
    there.saveGoal(habit.id!, goal);
    for (final int day in days) {
      there.upsert(habit.id!, day, nightOn(day),
          manual: manualDays.contains(day));
    }
    source.close();
    return LocalUserFile(path);
  }

  Future<void> importFile(UserFile file, {SleepImporter? sleep}) =>
      LoopDBImporter(
        habitList: destinationList,
        modelFactory: SQLModelFactory(destination),
        opener: const Sqlite3DatabaseOpener(),
        runner: CommandRunner(CoroutineTaskRunner(
          mainDispatcher: const UnconfinedTestDispatcher(),
          ioDispatcher: const UnconfinedTestDispatcher(),
        )),
        logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        fileOpener: assetsFileOpener(),
        sleepImporter: sleep ?? SleepImporter(here),
      ).importHabitsFromFile(file);

  group('restoring a sleep habit', () {
    test('brings its goal across', () async {
      await importFile(backupWith(uuid: 'sleep-uuid', days: <int>[9000]));

      final Habit habit = destinationList.getByUUID('sleep-uuid')!;
      expect(here.goalFor(habit.id!), goal,
          reason: 'sleep.backup#1 — without the goal the habit is no longer a '
              'sleep habit at all, and the screen loses every block');
    });

    test('brings every night across, onto the id this device gave it',
        () async {
      // This device is not empty: the restored habit takes the next id free
      // here, which is not the id it had in the file.
      final SQLModelFactory factory = SQLModelFactory(destination);
      for (int i = 0; i < 5; i++) {
        destinationList.add(factory.buildHabit()..name = 'Mine $i');
      }
      final UserFile file =
          backupWith(uuid: 'sleep-uuid', days: <int>[8990, 8995, 9000]);
      final int idInFile = const Sqlite3DatabaseOpener()
          .open(file.pathString)
          .querySingle<int>(
            'select habit from SleepGoals',
            const <String>[],
            (stmt) => stmt.getInt(0),
          )!;
      await importFile(file);

      final Habit habit = destinationList.getByUUID('sleep-uuid')!;
      expect(habit.id, isNot(idInFile),
          reason: 'the check is only worth making if the ids differ');
      expect(
        here.range(habit.id!, 8990, 9000).keys.toList(),
        <int>[8990, 8995, 9000],
        reason: 'sleep.backup#2',
      );
      expect(here.forDay(habit.id!, 9000)!.asleepMinutes, 455,
          reason: 'sleep.backup#2');
    });

    test('remembers which nights were typed rather than measured', () async {
      await importFile(backupWith(
        uuid: 'sleep-uuid',
        days: <int>[8999, 9000],
        manualDays: <int>{9000},
      ));

      final Habit habit = destinationList.getByUUID('sleep-uuid')!;
      expect(here.isManual(habit.id!, 9000), isTrue, reason: 'sleep.backup#3');
      expect(here.isManual(habit.id!, 8999), isFalse, reason: 'sleep.backup#3');
    });

    test('a measured night does not overwrite one typed on this device',
        () async {
      // The habit has to exist here first, with a night of its own.
      final Habit mine = SQLModelFactory(destination).buildHabit()
        ..name = 'Sleep'
        ..uuid = 'sleep-uuid'
        ..type = sleepHabitType
        ..targetValue = sleepTargetValue
        ..unit = sleepUnit;
      destinationList.add(mine);
      here.upsert(
        mine.id!,
        9000,
        SleepEpisode(
          bedStartMillis: nightOn(9000).bedStartMillis,
          wakeEndMillis: nightOn(9000).wakeEndMillis,
          asleepMinutes: 300,
          utcOffsetMinutes: 300,
        ),
        manual: true,
      );

      await importFile(backupWith(uuid: 'sleep-uuid', days: <int>[9000]));

      expect(here.forDay(mine.id!, 9000)!.asleepMinutes, 300,
          reason: 'sleep.backup#4 — a watch reading restored from a backup is '
              'not a reason to discard what the person typed here');
    });

    test('a habit that is not about sleep gains nothing', () async {
      final UserFile file = backupWith(uuid: 'sleep-uuid', days: <int>[9000]);
      await importFile(file);

      for (final Habit habit in destinationList) {
        if (habit.uuid == 'sleep-uuid') continue;
        expect(here.goalFor(habit.id!), isNull, reason: 'sleep.backup#1');
        expect(here.firstDay(habit.id!), isNull, reason: 'sleep.backup#2');
      }
    });
  });

  test('an import with no sleep importer still works', () async {
    // Every importer test that predates the feature passes null here.
    await importFile(
      backupWith(uuid: 'sleep-uuid', days: <int>[9000]),
      sleep: null,
    );
    expect(destinationList.getByUUID('sleep-uuid'), isNotNull);
  });
}
