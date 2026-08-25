/// Tests for the Loop backup (.db) importer.
///
/// Ports `testLoopDB` from
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt`
/// and `MigrationTest.kt`, and covers the rules of io.loop-db-migration,
/// io.loop-db-habit-mapping and io.loop-db-entry-mapping.
///
/// The fixture `uhabits-core/assets/test/loop.db` is always opened as a COPY:
/// the importer migrates the file it is given, in place.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'dart:typed_data';

import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/habit_repository.dart';
import 'package:uhabits_core/src/database/extension_migrations.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sql_parser.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/io/loop_db_importer.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  setUp(() => setToday(LocalDate.ymd(2016, 3, 20)));
  tearDown(resetToday);

  group('io.loop-db-migration', () {
    test('#1 migrates the imported file itself, in place, before reading it',
        () async {
      final file = copyLoopFixture();

      final before = const Sqlite3DatabaseOpener().open(file.pathString);
      expect(before.getVersion(), 12,
          reason: 'io.loop-db-migration#1 the fixture starts at user_version '
              '12, below DATABASE_VERSION');
      before.close();

      final habitList = MemoryHabitList();
      final modelFactory = MemoryModelFactory();
      final fileOpener = RecordingFileOpener(assetsFileOpener());
      await buildImporter(
        habitList: habitList,
        modelFactory: modelFactory,
        fileOpener: fileOpener,
      ).importHabitsFromFile(file);

      final after = const Sqlite3DatabaseOpener().open(file.pathString);
      addTearDown(after.close);
      expect(after.getVersion(), appDatabaseVersion,
          reason: 'io.loop-db-migration#1 importHabitsFromFile migrates the '
              'uploaded copy in place, up to the schema this build ships '
              '(the rule says DATABASE_VERSION; for this build that is '
              '$appDatabaseVersion, not the original\'s 25)');
      expect(
        after.querySingle<int>(
          "select count(*) from pragma_table_info('Repetitions') "
          "where name = 'value'",
          const <String>[],
          (stmt) => stmt.getInt(0),
        ),
        1,
        reason: 'io.loop-db-migration#1 the migration chain really ran against '
            'the imported file: Repetitions gained the value column',
      );
      expect(fileOpener.resourcePaths, <String>[
        for (var v = 13; v <= 25; v++) 'migrations/${twoDigits(v)}.sql',
      ], reason: 'io.loop-db-migration#1 only the versions above the file\'s '
          'own are applied (13..25 for a v12 backup)');
    });

    test('#2 returns immediately when already at or past the target version',
        () async {
      final db = Sqlite3Database.memory();
      addTearDown(db.close);
      db.setVersion(databaseVersion);

      final requested = <int>[];
      Future<String> loader(int v) async {
        requested.add(v);
        return '';
      }

      await db.migrateToAsync(databaseVersion, loader);
      expect(requested, isEmpty,
          reason: 'io.loop-db-migration#2 currentVersion == targetVersion '
              'returns without loading any migration');
      expect(db.getVersion(), databaseVersion,
          reason: 'io.loop-db-migration#2 the version is left untouched');

      await db.migrateToAsync(20, loader);
      expect(requested, isEmpty,
          reason: 'io.loop-db-migration#2 currentVersion > targetVersion also '
              'returns immediately, doing nothing');
      expect(db.getVersion(), databaseVersion,
          reason: 'io.loop-db-migration#2 a lower target never downgrades');
    });

    test('#3 loads migrations/%02d.sql, joins lines with \\n, parses and '
        'stamps the version once per step', () async {
      final db = Sqlite3Database.memory();
      addTearDown(db.close);
      db.setVersion(8);

      final fileOpener = RecordingFileOpener(assetsFileOpener());
      final scripts = <String>[];
      await db.migrateToAsync(
        9,
        (v) async =>
            (await fileOpener.openResourceFile('migrations/${twoDigits(v)}.sql')
                    .lines())
                .join('\n'),
        parse: (script) {
          scripts.add(script);
          return SQLParser.parse(script);
        },
      );

      expect(fileOpener.resourcePaths, <String>['migrations/09.sql'],
          reason: 'io.loop-db-migration#3 the resource path is '
              "'migrations/' + format('%02d.sql', version)");
      expect(
        scripts.single,
        File('${repoRoot().path}/uhabits-core/assets/main/migrations/09.sql')
            .readAsLinesSync()
            .join('\n'),
        reason: 'io.loop-db-migration#3 the resource lines are joined with '
            "'\\n' before being parsed",
      );
      expect(SQLParser.parse(scripts.single).length, 5,
          reason: 'io.loop-db-migration#3 SQLParser.parse splits 09.sql into '
              'its five create-table statements, which are run one by one');
      expect(tableNames(db), containsAll(<String>['Habits', 'Repetitions']),
          reason: 'io.loop-db-migration#3 every parsed statement is executed');
      expect(db.getVersion(), 9,
          reason: 'io.loop-db-migration#3 PRAGMA user_version is set to v '
              'after that version has been applied');

      // The version is stamped per step, not once at the end: version 11 is
      // applied and stamped before version 12 is even loaded.
      final stepwise = Sqlite3Database.memory();
      addTearDown(stepwise.close);
      stepwise.setVersion(8);
      await stepwise.migrateToAsync(10, (v) async => migrationSql[v]!);
      await expectLater(
        stepwise.migrateToAsync(12, (v) async {
          if (v == 12) throw StateError('boom');
          return migrationSql[v]!;
        }),
        throwsA(isA<StateError>()),
      );
      expect(stepwise.getVersion(), 11,
          reason: 'io.loop-db-migration#3 the loop bumps user_version once per '
              'version, immediately after running that version scripts');

      // The importer's own loader zero-pads to two digits: a version-8 backup
      // asks for 09.sql, not 9.sql, and migrates all the way up.
      final scratch = Sqlite3Database.memory();
      final importerOpener = RecordingFileOpener(assetsFileOpener());
      scratch.setVersion(8);
      await buildImporter(
        habitList: MemoryHabitList(),
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(scratch),
        fileOpener: importerOpener,
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));
      expect(importerOpener.resourcePaths, <String>[
        for (var v = 9; v <= 25; v++) 'migrations/${twoDigits(v)}.sql',
      ], reason: "io.loop-db-migration#3 the importer builds the resource name "
          "with format('%02d.sql', version), so version 9 reads 09.sql");
    });

    test('#4 migration assets exist for versions 09 through 25 (17 files)', () {
      final dir =
          Directory('${repoRoot().path}/uhabits-core/assets/main/migrations');
      final names = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.sql'))
          .toList()
        ..sort();
      expect(names, <String>[for (var v = 9; v <= 25; v++) '${twoDigits(v)}.sql'],
          reason: 'io.loop-db-migration#4 assets/main/migrations holds 09.sql '
              'through 25.sql');
      expect(names.length, 17,
          reason: 'io.loop-db-migration#4 seventeen migration files');
      expect(migrationSql.keys.toList()..sort(),
          <int>[for (var v = 9; v <= 25; v++) v],
          reason: 'io.loop-db-migration#4 the generated Dart copy carries the '
              'same seventeen versions');
    });

    test('#5 a database already at version 25 is left byte-identical',
        () async {
      final file = copyLoopFixture();

      final first = const Sqlite3DatabaseOpener().open(file.pathString);
      await first.migrateToAsync(
        databaseVersion,
        (v) async =>
            (await assetsFileOpener()
                    .openResourceFile('migrations/${twoDigits(v)}.sql')
                    .lines())
                .join('\n'),
      );
      first.close();
      final bytesBefore = File(file.pathString).readAsBytesSync();

      final requested = <int>[];
      final second = const Sqlite3DatabaseOpener().open(file.pathString);
      await second.migrateToAsync(databaseVersion, (v) async {
        requested.add(v);
        return '';
      });
      second.close();
      final bytesAfter = File(file.pathString).readAsBytesSync();

      expect(requested, isEmpty,
          reason: 'io.loop-db-migration#5 migrating a database that is already '
              'at 25 loads nothing');
      expect(bytesAfter, bytesBefore,
          reason: 'io.loop-db-migration#5 migration is idempotent: the file is '
              'left byte-identical');
    });

    test('#6 a missing migration resource yields no lines, zero statements and '
        'only a version bump', () async {
      final source = newSourceDatabase(version: 24);
      final recording = RecordingDatabase(source);

      await buildImporter(
        habitList: MemoryHabitList(),
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(recording),
        fileOpener: MissingResourceFileOpener(),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      final List<String> beforeReading =
          recording.sql.takeWhile((s) => !s.startsWith('SELECT id')).toList();
      // Everything the missing resource contributed: nothing. The statements
      // that do appear are version stamps, plus migration 100's own script,
      // which comes from the source rather than from a resource file.
      // Every extension script, not just the newest: the file is migrated all
      // the way to the version this build ships, so each of them runs.
      final Set<String> extensionStatements = <String>{
        for (final String script in extensionMigrationSql.values)
          ...SQLParser.parse(script),
      };
      expect(
        beforeReading
            .where((s) => !s.startsWith('PRAGMA user_version'))
            .where((s) => !extensionStatements.contains(s)),
        isEmpty,
        reason: 'io.loop-db-migration#6 a resource with no lines yields an '
            'empty script and SQLParser.parse produces zero statements from '
            'it — 25.sql would otherwise have run '
            "'alter table Repetitions add column notes text'",
      );
      expect(
        beforeReading.take(2),
        <String>['PRAGMA user_version', 'PRAGMA user_version = 25'],
        reason: 'io.loop-db-migration#6 a resource with no lines yields an '
            'empty script, SQLParser.parse produces zero statements, and the '
            'migration is nothing but a version bump — 25.sql would otherwise '
            "have run 'alter table Repetitions add column notes text'",
      );
      expect(recording.sql, contains('PRAGMA user_version = 25'),
          reason: 'io.loop-db-migration#6 the version is still bumped, even '
              'though the resource had no lines');
    });
  });

  group('io.loop-db-habit-mapping', () {
    test('#1 habits are loaded with the full 18-column query ordered by '
        'position', () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 2, name: 'B', position: 1, uuid: 'u2');
      insertHabit(source, id: 1, name: 'A', position: 0, uuid: 'u1');
      final recording = RecordingDatabase(source);

      final habitList = MemoryHabitList();
      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(recording),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      expect(
        recording.sql,
        contains('SELECT id, name, description, question, freq_num, freq_den, '
            'color, position, reminder_hour, reminder_min, reminder_days, '
            'highlight, archived, type, target_value, target_type, unit, uuid '
            'FROM Habits ORDER BY position'),
        reason: 'io.loop-db-habit-mapping#1 the habit query is issued verbatim',
      );
      expect(<String>[for (final h in habitList) h.name], <String>['A', 'B'],
          reason: 'io.loop-db-habit-mapping#1 rows arrive ordered by position, '
              'not by id');
    });

    test('#2 NULL columns fall back to the documented defaults', () {
      final source = newSourceDatabase();
      source.run('insert into Habits(id) values (7)');
      final data = LoopDBImporter.loadHabits(source).single;

      expect(data.id, 7,
          reason: 'io.loop-db-habit-mapping#2 id is read as a nullable Long');
      expect(data.name, '',
          reason: 'io.loop-db-habit-mapping#2 NULL name defaults to empty');
      expect(data.description, '',
          reason:
              'io.loop-db-habit-mapping#2 NULL description defaults to empty');
      expect(data.question, '',
          reason: 'io.loop-db-habit-mapping#2 NULL question defaults to empty');
      expect(data.unit, '',
          reason: 'io.loop-db-habit-mapping#2 NULL unit defaults to empty');
      expect(data.freqNum, 1,
          reason: 'io.loop-db-habit-mapping#2 NULL freq_num defaults to 1');
      expect(data.freqDen, 1,
          reason: 'io.loop-db-habit-mapping#2 NULL freq_den defaults to 1');
      expect(data.color, 0,
          reason: 'io.loop-db-habit-mapping#2 NULL color defaults to 0');
      expect(data.position, 0,
          reason: 'io.loop-db-habit-mapping#2 NULL position defaults to 0');
      expect(data.reminderDays, 0,
          reason:
              'io.loop-db-habit-mapping#2 NULL reminder_days defaults to 0');
      expect(data.highlight, 0,
          reason: 'io.loop-db-habit-mapping#2 NULL highlight defaults to 0');
      expect(data.archived, 0,
          reason: 'io.loop-db-habit-mapping#2 NULL archived defaults to 0');
      expect(data.type, 0,
          reason: 'io.loop-db-habit-mapping#2 NULL type defaults to 0');
      expect(data.targetType, 0,
          reason: 'io.loop-db-habit-mapping#2 NULL target_type defaults to 0');
      expect(data.targetValue, 0.0,
          reason:
              'io.loop-db-habit-mapping#2 NULL target_value defaults to 0.0');
      expect(data.reminderHour, isNull,
          reason: 'io.loop-db-habit-mapping#2 reminder_hour stays null');
      expect(data.reminderMin, isNull,
          reason: 'io.loop-db-habit-mapping#2 reminder_min stays null');
      expect(data.uuid, isNull,
          reason: 'io.loop-db-habit-mapping#2 uuid stays null');
      source.close();
    });

    test('#3 an unknown UUID creates a new habit, with the source id dropped',
        () async {
      final file = copyLoopFixture();
      final habitList = MemoryHabitList();
      await importLoopFixture(habitList: habitList, file: file);

      expect(habitList.size(), 9,
          reason: 'io.loop-db-habit-mapping#3 every row with an unseen UUID is '
              'created through CreateHabitCommand');
      expect(habitList.getById(15), isNull,
          reason: 'io.loop-db-habit-mapping#3 the row is copied with id = null, '
              'so the source ids (15..26) are never reused');
      expect(<int?>[for (final h in habitList) h.id], <int>[0, 1, 2, 3, 4, 5, 6, 7, 8],
          reason: 'io.loop-db-habit-mapping#3 the destination list assigns the '
              'ids of the newly created habits');
      expect(habitList.getByUUID(firstSourceUuid(file)), isNotNull,
          reason: 'io.loop-db-habit-mapping#3 the imported UUID is preserved, '
              'which is what makes the merge in #4 possible');
    });

    test('#4 a known UUID edits the existing habit in place', () async {
      // The very same file, twice: the importer migrated it in place on the
      // first pass, so the UUIDs it hands out the second time are identical.
      final file = copyLoopFixture();
      final habitList = MemoryHabitList();
      await importLoopFixture(habitList: habitList, file: file);
      final first = habitList.getByPosition(0);
      final firstId = first.id;
      first.name = 'Renamed by the user';

      await importLoopFixture(habitList: habitList, file: file);

      expect(habitList.size(), 9,
          reason: 'io.loop-db-habit-mapping#4 importing the same backup twice '
              'updates habits instead of duplicating them');
      expect(habitList.getByPosition(0).id, firstId,
          reason: 'io.loop-db-habit-mapping#4 EditHabitCommand runs against the '
              "existing habit's id");
      expect(habitList.getByPosition(0).name, 'Wake up early',
          reason: 'io.loop-db-habit-mapping#4 the backup overwrites the local '
              'habit fields');
    });

    test('#5 every column is mapped onto the habit the documented way',
        () async {
      final source = newSourceDatabase();
      insertHabit(
        source,
        id: 3,
        name: 'Run',
        description: 'the description',
        question: 'How far did you run?',
        freqNum: 3,
        freqDen: 7,
        color: 5,
        position: 2,
        archived: 1,
        type: 1,
        targetValue: 25.5,
        targetType: 1,
        unit: 'miles',
        uuid: 'uuid-run',
      );
      final habitList = MemoryHabitList();
      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));
      final habit = habitList.getByUUID('uuid-run')!;

      expect(habit.name, 'Run',
          reason: 'io.loop-db-habit-mapping#5 name copies directly');
      expect(habit.description, 'the description',
          reason: 'io.loop-db-habit-mapping#5 description copies directly');
      expect(habit.question, 'How far did you run?',
          reason: 'io.loop-db-habit-mapping#5 question copies directly');
      expect(habit.unit, 'miles',
          reason: 'io.loop-db-habit-mapping#5 unit copies directly');
      expect(habit.frequency, Frequency(3, 7),
          reason: 'io.loop-db-habit-mapping#5 frequency = '
              'Frequency(freqNum, freqDen)');
      expect(habit.color, const PaletteColor(5),
          reason: 'io.loop-db-habit-mapping#5 color = PaletteColor(color)');
      expect(habit.isArchived, isTrue,
          reason: 'io.loop-db-habit-mapping#5 isArchived = (archived != 0)');
      expect(habit.type, HabitType.numerical,
          reason: 'io.loop-db-habit-mapping#5 type = HabitType.fromInt(type)');
      expect(habit.targetType, NumericalHabitType.atMost,
          reason: 'io.loop-db-habit-mapping#5 targetType = '
              'NumericalHabitType.fromInt(targetType)');
      expect(habit.targetValue, 25.5,
          reason: 'io.loop-db-habit-mapping#5 targetValue copies directly');
      expect(habit.position, 2,
          reason: 'io.loop-db-habit-mapping#5 position copies directly');
      expect(habit.uuid, 'uuid-run',
          reason: 'io.loop-db-habit-mapping#5 uuid copies directly');
    });

    test('#6 a reminder is set only when both hour and minute are non-null',
        () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'both',
          reminderHour: 8, reminderMin: 30, reminderDays: 126);
      insertHabit(source, id: 2, position: 1, uuid: 'hour-only',
          reminderHour: 8, reminderDays: 126);
      insertHabit(source, id: 3, position: 2, uuid: 'min-only',
          reminderMin: 30, reminderDays: 126);
      final habitList = MemoryHabitList();
      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      final both = habitList.getByUUID('both')!;
      expect(both.hasReminder(), isTrue,
          reason: 'io.loop-db-habit-mapping#6 both columns present sets a '
              'reminder');
      expect(both.reminder!.hour, 8,
          reason: 'io.loop-db-habit-mapping#6 Reminder(hour, min, days)');
      expect(both.reminder!.minute, 30,
          reason: 'io.loop-db-habit-mapping#6 Reminder(hour, min, days)');
      expect(both.reminder!.days.toInteger(), 126,
          reason: 'io.loop-db-habit-mapping#6 the day mask comes from '
              'WeekdayList(reminderDays)');
      expect(habitList.getByUUID('hour-only')!.hasReminder(), isFalse,
          reason: 'io.loop-db-habit-mapping#6 a NULL reminder_min leaves the '
              'habit with no reminder');
      expect(habitList.getByUUID('min-only')!.hasReminder(), isFalse,
          reason: 'io.loop-db-habit-mapping#6 a NULL reminder_hour leaves the '
              'habit with no reminder');
    });

    test('#7 highlight is read into HabitData but never copied onto the habit',
        () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'hl', highlight: 7);

      expect(LoopDBImporter.loadHabits(source).single.highlight, 7,
          reason: 'io.loop-db-habit-mapping#7 the highlight column IS read '
              'into HabitData');

      final habitList = MemoryHabitList();
      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      expect(SQLiteHabitList.copyFrom(habitList.getByUUID('hl')!).highlight, 0,
          reason: 'io.loop-db-habit-mapping#7 copyTo never puts it on the '
              'Habit, so a round trip loses it');
    });

    test('#8 resort is called once after every habit, and the database is '
        'closed', () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'a');
      insertHabit(source, id: 2, position: 1, uuid: 'b');
      final recording = RecordingDatabase(source);
      final habitList = LoggingHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(recording),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      expect(habitList.log.last, 'resort',
          reason: 'io.loop-db-habit-mapping#8 habitList.resort() is the last '
              'thing the import does to the list');
      expect(habitList.log.where((op) => op == 'resort').length,
          habitList.log.where((op) => op == 'add').length + 1,
          reason: 'io.loop-db-habit-mapping#8 exactly one resort beyond the '
              'ones each add already triggers');
      expect(recording.closed, isTrue,
          reason: 'io.loop-db-habit-mapping#8 the source database is closed');
    });

    test('#9 the loop.db fixture yields nine habits, Wake up early first',
        () async {
      final habitList = MemoryHabitList();
      await importLoopFixture(habitList: habitList);

      expect(habitList.size(), 9,
          reason: 'io.loop-db-habit-mapping#9 loop.db holds nine habits');
      final habit = habitList.getByPosition(0);
      expect(habit.name, 'Wake up early',
          reason: 'io.loop-db-habit-mapping#9 the habit displayed first');
      expect(habit.frequency, Frequency.threeTimesPerWeek,
          reason: 'io.loop-db-habit-mapping#9 its frequency is 3/7');
      expect(habit.frequency.numerator, 3,
          reason: 'io.loop-db-habit-mapping#9 freq_num 3');
      expect(habit.frequency.denominator, 7,
          reason: 'io.loop-db-habit-mapping#9 freq_den 7');
    });
  });

  group('io.loop-db-entry-mapping', () {
    test('#1 entries are read per habit, binding the source id as TEXT',
        () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 42, position: 0, uuid: 'a');
      insertEntry(source, habit: 42, timestamp: 1458259200000, value: 2);
      final recording = RecordingDatabase(source);
      final habitList = MemoryHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(recording),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      final stmt = recording.statements
          .firstWhere((s) => s.sql.startsWith('SELECT timestamp'));
      expect(
        stmt.sql,
        'SELECT timestamp, value, notes FROM Repetitions WHERE habit = ? '
        'ORDER BY timestamp DESC',
        reason: 'io.loop-db-entry-mapping#1 the entry query is issued verbatim',
      );
      expect(stmt.boundText, <String>['42'],
          reason: "io.loop-db-entry-mapping#1 the SOURCE habit's id "
              '(habitData.id) is bound as TEXT');
      expect(habitList.getByUUID('a')!.originalEntries.getKnown().length, 1,
          reason: 'io.loop-db-entry-mapping#1 binding the id as text still '
              'matches the integer habit column');
    });

    test('#2 NULL timestamps and values are skipped, NULL notes become empty',
        () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'a');
      insertEntry(source, habit: 1, timestamp: null, value: 2);
      insertEntry(source, habit: 1, timestamp: 1458259200000, value: null);
      insertEntry(source, habit: 1, timestamp: 1458086400000, value: 2);
      final habitList = MemoryHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      final entries = habitList.getByUUID('a')!.originalEntries;
      expect(entries.getKnown().length, 1,
          reason: 'io.loop-db-entry-mapping#2 the NULL timestamp row and the '
              'NULL value row are both skipped');
      expect(entries.get(LocalDate.ymd(2016, 3, 16)).value, 2,
          reason: 'io.loop-db-entry-mapping#2 the surviving row is imported');
      expect(entries.get(LocalDate.ymd(2016, 3, 16)).notes, '',
          reason: 'io.loop-db-entry-mapping#2 a NULL notes column becomes an '
              'empty string');
      expect(entries.get(LocalDate.ymd(2016, 3, 18)).value, Entry.unknown,
          reason: 'io.loop-db-entry-mapping#2 the NULL-value row leaves no '
              'entry behind');
    });

    test('#3 the date comes from LocalDate.fromUnixTime', () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'a');
      insertEntry(source, habit: 1, timestamp: 1458259200000, value: 2);
      insertEntry(source, habit: 1, timestamp: 946684800000, value: 2);
      // One millisecond before the 2000-01-01 epoch: the negative branch.
      insertEntry(source, habit: 1, timestamp: 946684799999, value: 2);
      final habitList = MemoryHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      final entries = habitList.getByUUID('a')!.originalEntries;
      expect(entries.get(LocalDate.ymd(2016, 3, 18)).value, 2,
          reason: 'io.loop-db-entry-mapping#3 1458259200000 ms maps to '
              '2016-03-18 through LocalDate.fromUnixTime');
      expect(entries.get(LocalDate(0)).value, 2,
          reason: 'io.loop-db-entry-mapping#3 the 946684800000 ms epoch maps '
              'to day 0');
      expect(entries.get(LocalDate(-1)).value, 2,
          reason: 'io.loop-db-entry-mapping#3 a negative difference floors '
              'through (diff - 86400000 + 1) / 86400000, giving day -1');
      expect(LocalDate.fromUnixTime(946684799999).daysSince2000, -1,
          reason: 'io.loop-db-entry-mapping#3 fromUnixTime subtracts the '
              '946684800000 ms epoch and floor-divides by 86400000');
    });

    test('#4 an entry is written only when it differs from what is there',
        () async {
      final file = copyLoopFixture();
      final counter = Counter();
      final habitList = MemoryHabitList();
      final modelFactory = CountingModelFactory(counter);

      await importLoopFixture(
          habitList: habitList, modelFactory: modelFactory, file: file);
      final firstPass = counter.value;
      expect(firstPass, 164,
          reason: 'io.loop-db-entry-mapping#4 the first import writes every '
              'row of the backup');

      counter.value = 0;
      await importLoopFixture(
          habitList: habitList, modelFactory: modelFactory, file: file);
      expect(counter.value, 0,
          reason: 'io.loop-db-entry-mapping#4 re-importing an identical backup '
              'produces no entry writes at all');

      // A changed value (and a changed note) does reach the list.
      final habit = habitList.getByPosition(0);
      habit.originalEntries
          .add(Entry(LocalDate.ymd(2016, 3, 18), Entry.no, notes: 'edited'));
      counter.value = 0;
      await importLoopFixture(
          habitList: habitList, modelFactory: modelFactory, file: file);
      expect(counter.value, 1,
          reason: 'io.loop-db-entry-mapping#4 only the one entry whose value '
              'or notes differ is added back');
      expect(habit.originalEntries.get(LocalDate.ymd(2016, 3, 18)).value,
          Entry.yesManual,
          reason: 'io.loop-db-entry-mapping#4 the differing entry is replaced '
              'by Entry(date, value, notes)');

      // A note that differs while the value matches is a difference too.
      habit.originalEntries.add(
          Entry(LocalDate.ymd(2016, 3, 16), Entry.yesManual, notes: 'edited'));
      counter.value = 0;
      await importLoopFixture(
          habitList: habitList, modelFactory: modelFactory, file: file);
      expect(counter.value, 1,
          reason: 'io.loop-db-entry-mapping#4 the comparison is '
              'existingValue != value || existingNotes != notes, so a '
              'notes-only difference is written back as well');
      expect(habit.originalEntries.get(LocalDate.ymd(2016, 3, 16)).notes, '',
          reason: 'io.loop-db-entry-mapping#4 the backup notes (empty here) '
              'replace the local ones');
    });

    test('#5 habit.recompute() runs after the entries loop', () async {
      final habitList = MemoryHabitList();
      await importLoopFixture(habitList: habitList);
      final habit = habitList.getByPosition(0);

      expect(habit.computedEntries.getKnown(), isNotEmpty,
          reason: 'io.loop-db-entry-mapping#5 recompute() after the loop fills '
              'computedEntries from the freshly imported originals');
      expect(habit.computedEntries.get(LocalDate.ymd(2016, 3, 17)).value,
          Entry.yesAuto,
          reason: 'io.loop-db-entry-mapping#5 the 3/7 frequency turns the gap '
              'between two manual checks into YES_AUTO, which only recompute() '
              'can produce');
      expect(habit.scores[LocalDate.ymd(2016, 3, 18)].value, greaterThan(0.0),
          reason: 'io.loop-db-entry-mapping#5 recompute() also refreshes the '
              'scores of that habit');
    });

    test('#6 values are stored raw', () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'yesno');
      insertEntry(source, habit: 1, timestamp: day(0), value: 0);
      insertEntry(source, habit: 1, timestamp: day(1), value: 1);
      insertEntry(source, habit: 1, timestamp: day(2), value: 2);
      insertEntry(source, habit: 1, timestamp: day(3), value: 3);
      insertEntry(source, habit: 1, timestamp: day(4), value: -1);
      insertHabit(source, id: 2, position: 1, uuid: 'numerical', type: 1);
      insertEntry(source, habit: 2, timestamp: day(0), value: 30000);
      final habitList = MemoryHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      final yesNo = habitList.getByUUID('yesno')!.originalEntries;
      expect(yesNo.get(LocalDate(0)).value, Entry.no,
          reason: 'io.loop-db-entry-mapping#6 0 = NO');
      expect(yesNo.get(LocalDate(1)).value, Entry.yesAuto,
          reason: 'io.loop-db-entry-mapping#6 1 = YES_AUTO');
      expect(yesNo.get(LocalDate(2)).value, Entry.yesManual,
          reason: 'io.loop-db-entry-mapping#6 2 = YES_MANUAL');
      expect(yesNo.get(LocalDate(3)).value, Entry.skip,
          reason: 'io.loop-db-entry-mapping#6 3 = SKIP');
      expect(yesNo.get(LocalDate(4)).value, Entry.unknown,
          reason: 'io.loop-db-entry-mapping#6 -1 = UNKNOWN, stored as it is');
      expect(habitList.getByUUID('numerical')!.originalEntries
          .get(LocalDate(0))
          .value, 30000,
          reason: 'io.loop-db-entry-mapping#6 numerical habits store '
              'value * 1000, and the importer never rescales it');
    });
  });

  // -------------------------------------------------------------------------
  // persistence.loop-db-import — the DB-side view of the same importer.
  //
  // #1..#4 are the detection gate, #5..#12 the import itself. Every assertion
  // here drives the real LoopDBImporter, never the standalone
  // `loopDBCanHandle` helper.
  // -------------------------------------------------------------------------
  group('persistence.loop-db-import', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('uhabits_loop_import');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    UserFile writeBytes(String name, List<int> bytes) {
      final path = '${tmp.path}/$name';
      File(path).writeAsBytesSync(bytes);
      return LocalUserFile(path);
    }

    LoopDBImporter gate(DatabaseOpener opener, {Logging? logging}) =>
        buildImporter(
          habitList: MemoryHabitList(),
          modelFactory: MemoryModelFactory(),
          opener: opener,
          logging: logging,
        );

    test('#1 isSQLite3File gates canHandle on the first 16 bytes', () async {
      final missing = LocalUserFile('${tmp.path}/nothing-here.db');
      expect(await gate(ExplodingOpener()).canHandle(missing), isFalse,
          reason: 'persistence.loop-db-import#1 isSQLite3File returns false '
              'when the file does not exist, and canHandle stops there');

      final text = writeBytes('notes.txt', 'hello, not a database'.codeUnits);
      expect(await gate(ExplodingOpener()).canHandle(text), isFalse,
          reason: 'persistence.loop-db-import#1 a file whose first 16 bytes do '
              'not start with the magic is not a SQLite file');

      final offByOne = writeBytes('offset.db', ' SQLite format 3 '.codeUnits);
      expect(await gate(ExplodingOpener()).canHandle(offByOne), isFalse,
          reason: 'persistence.loop-db-import#1 the 16 bytes are read from the '
              'START of the file: a magic at offset 1 does not count');

      // Only the header is inspected: the rest of the file is never parsed,
      // and the database itself arrives through the opener.
      final headerOnly =
          writeBytes('header.db', 'SQLite format 3 JUNK'.codeUnits);
      final source = newSourceDatabase();
      final reader = RecordingUserFile(headerOnly);
      expect(await gate(FixedDatabaseOpener(source)).canHandle(reader), isTrue,
          reason: 'persistence.loop-db-import#1 a file whose decoded header '
              'starts with "SQLite format 3" passes the magic check');
      expect(reader.readLimits, <int>[16],
          reason: 'persistence.loop-db-import#1 exactly 16 bytes are read');
    });

    test('#2 the table probe must count exactly 2', () async {
      final header = writeBytes('h.db', 'SQLite format 3 '.codeUnits);

      final both = RecordingDatabase(newSourceDatabase());
      expect(await gate(FixedDatabaseOpener(both)).canHandle(header), isTrue,
          reason: 'persistence.loop-db-import#2 both Habits and Repetitions '
              'present: the count is 2 and the file is accepted');
      expect(
        both.sql.map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim()),
        contains("select count(*) from SQLITE_MASTER where name='Habits' "
            "or name='Repetitions'"),
        reason: 'persistence.loop-db-import#2 the probe is that exact query',
      );

      final out = StringBuffer();
      final capturing = StandardLogging(out: out, err: StringBuffer());
      final onlyHabits = Sqlite3Database.memory();
      addTearDown(() {
        try {
          onlyHabits.close();
        } catch (_) {
          // Already closed by canHandle.
        }
      });
      onlyHabits.run('create table Habits (id integer primary key)');
      expect(
          await gate(FixedDatabaseOpener(onlyHabits), logging: capturing)
              .canHandle(header),
          isFalse,
          reason: 'persistence.loop-db-import#2 a count of 1 rejects the file');
      expect(out.toString(),
          contains('[LoopDBImporter] Cannot handle file: tables not found'),
          reason: "persistence.loop-db-import#2 it logs 'Cannot handle file: "
              "tables not found'");

      // A file with neither table is rejected for the same reason.
      final neither = Sqlite3Database.memory();
      addTearDown(() {
        try {
          neither.close();
        } catch (_) {
          // Already closed by canHandle.
        }
      });
      expect(await gate(FixedDatabaseOpener(neither)).canHandle(header), isFalse,
          reason: 'persistence.loop-db-import#2 zero matching tables is not 2 '
              'either');
    });

    test('#3 a schema newer than 25 is rejected, an older one accepted',
        () async {
      final header = writeBytes('h.db', 'SQLite format 3 '.codeUnits);

      final out = StringBuffer();
      final capturing = StandardLogging(out: out, err: StringBuffer());
      final newer = newSourceDatabase(version: 26);
      expect(
          await gate(FixedDatabaseOpener(newer), logging: capturing)
              .canHandle(header),
          isFalse,
          reason: 'persistence.loop-db-import#3 PRAGMA user_version 26 is '
              'greater than DATABASE_VERSION 25, so the file is rejected');
      expect(
          out.toString(),
          contains('[LoopDBImporter] Cannot handle file: incompatible '
              'version: 26 > 25'),
          reason: "persistence.loop-db-import#3 it logs 'Cannot handle file: "
              "incompatible version: 26 > 25'");

      expect(
          await gate(FixedDatabaseOpener(newSourceDatabase(version: 25)))
              .canHandle(header),
          isTrue,
          reason: 'persistence.loop-db-import#3 a file at exactly 25 is '
              'accepted');
      expect(
          await gate(FixedDatabaseOpener(newSourceDatabase(version: 12)))
              .canHandle(header),
          isTrue,
          reason: 'persistence.loop-db-import#3 a file with a LOWER version is '
              'accepted: it is migrated during the import');
    });

    test('#4 canHandle closes the database on both paths', () async {
      final header = writeBytes('h.db', 'SQLite format 3 '.codeUnits);

      final accepted = RecordingDatabase(newSourceDatabase());
      expect(await gate(FixedDatabaseOpener(accepted)).canHandle(header), isTrue,
          reason: 'persistence.loop-db-import#4 the accept path');
      expect(accepted.closed, isTrue,
          reason: 'persistence.loop-db-import#4 the database is closed on the '
              'accept path');

      final rejected = RecordingDatabase(newSourceDatabase(version: 26));
      expect(
          await gate(FixedDatabaseOpener(rejected)).canHandle(header), isFalse,
          reason: 'persistence.loop-db-import#4 the reject path');
      expect(rejected.closed, isTrue,
          reason: 'persistence.loop-db-import#4 and it is closed on the reject '
              'path too');
    });

    test('#5 the backup is migrated in place before any row is read', () async {
      // A version-13 source ON DISK, so migrations 14..25 replay — including
      // BOTH colour remappings (14 maps the old ARGB values, 21 renumbers the
      // palette) — and the file itself can be reopened afterwards.
      const opener = Sqlite3DatabaseOpener();
      final path = '${tmp.path}/backup.db';
      File(path).writeAsBytesSync(const <int>[]);
      final creating = opener.open(path);
      creating.setVersion(8);
      creating.migrateTo(13, (v) => migrationSql[v]!);
      creating.run('insert into Habits(name, freq_num, freq_den, color, '
          "position, archived) values ('Old palette', 1, 1, 12, 0, 0)");
      creating.run('insert into Habits(name, freq_num, freq_den, color, '
          "position, archived) values ('Old ARGB', 1, 1, -2937041, 1, 0)");
      expect(creating.getVersion(), 13,
          reason: 'persistence.loop-db-import#5 the source starts below 25');
      creating.close();

      final habitList = MemoryHabitList();
      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
      ).importHabitsFromFile(LocalUserFile(path));

      final reopened = opener.open(path);
      addTearDown(reopened.close);
      expect(reopened.getVersion(), appDatabaseVersion,
          reason: "persistence.loop-db-import#5 the user's own file is "
              'migrated, IN PLACE, up to DATABASE_VERSION');
      expect(habitList.getByPosition(0).color.paletteIndex, 19,
          reason: 'persistence.loop-db-import#5 migration 21 remapped colour '
              '12 to 19 before the row was read');
      expect(habitList.getByPosition(1).color.paletteIndex, 0,
          reason: 'persistence.loop-db-import#5 migration 14 remapped the old '
              'ARGB colour -2937041 to 0 before the row was read');
    });

    test('#6 the habit projection is the one HabitRepository.findAll uses',
        () async {
      final source = RecordingDatabase(newSourceDatabase());
      insertHabit(source, id: 1, position: 1, name: 'second', uuid: 'b');
      insertHabit(source, id: 2, position: 0, name: 'first', uuid: 'a');

      final habitList = MemoryHabitList();
      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/does/not/matter.db'));

      List<String> columnsOf(String sql) => sql
          .replaceAll(RegExp(r'\s+'), ' ')
          .split(RegExp(' FROM ', caseSensitive: false))
          .first
          .replaceAll(RegExp('^ *SELECT ', caseSensitive: false), '')
          .split(', ')
          .map((c) => c.trim())
          .toList();

      final importerSql = source.sql.singleWhere(
          (s) => s.toUpperCase().contains('FROM HABITS ORDER BY POSITION'));
      // The very statement `HabitRepository` prepares, taken from a repository
      // built over this database, so the two can never drift apart.
      final repositorySql =
          repositoryFindAllSql(RecordingDatabase(newSourceDatabase()));
      expect(columnsOf(importerSql), columnsOf(repositorySql),
          reason: 'persistence.loop-db-import#6 the same 18-column projection '
              'as HabitRepository.findAll');
      expect(columnsOf(importerSql), hasLength(18),
          reason: 'persistence.loop-db-import#6 eighteen columns');
      expect(importerSql.toUpperCase(), contains('ORDER BY POSITION'),
          reason: 'persistence.loop-db-import#6 rows arrive ORDER BY position');
      expect(habitList.toList().map((h) => h.name), <String>['first', 'second'],
          reason: 'persistence.loop-db-import#6 and are imported in that '
              'order');

      // The NULL fallbacks, straight off a row where every column is NULL.
      final nulls = newSourceDatabase();
      nulls.run('insert into Habits(id) values (7)');
      final data = LoopDBImporter.loadHabits(nulls).single;
      expect(
        <Object?>[
          data.name, data.description, data.question, data.unit,
          data.freqNum, data.freqDen, data.color, data.position,
          data.reminderDays, data.highlight, data.archived, data.type,
          data.targetType, data.targetValue,
        ],
        <Object?>['', '', '', '', 1, 1, 0, 0, 0, 0, 0, 0, 0, 0.0],
        reason: 'persistence.loop-db-import#6 name/description/question/unit '
            'fall back to "", freq_num and freq_den to 1, and every other '
            'numeric column to 0 (target_value to 0.0)',
      );
      expect(<Object?>[data.reminderHour, data.reminderMin, data.uuid],
          <Object?>[null, null, null],
          reason: 'persistence.loop-db-import#6 reminder_hour, reminder_min '
              'and uuid stay nullable');
    });

    test('#7 habits are matched by uuid: create, then edit', () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 41, position: 0, name: 'Meditate', uuid: 'u-1');
      final habitList = LoggingHabitList();
      final modelFactory = MemoryModelFactory();

      await buildImporter(
        habitList: habitList,
        modelFactory: modelFactory,
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/a.db'));

      final created = habitList.getByUUID('u-1')!;
      expect(habitList.log, contains('add'),
          reason: 'persistence.loop-db-import#7 an unknown uuid runs '
              'CreateHabitCommand, which adds the habit to the list');
      expect(created.id, isNot(41),
          reason: 'persistence.loop-db-import#7 HabitData is copied with '
              'id = null, so the destination list assigns a fresh local id');

      // Second pass: same uuid, changed name.
      final second = newSourceDatabase();
      insertHabit(second, id: 41, position: 0, name: 'Meditate daily',
          uuid: 'u-1');
      habitList.log.clear();
      await buildImporter(
        habitList: habitList,
        modelFactory: modelFactory,
        opener: FixedDatabaseOpener(second),
      ).importHabitsFromFile(LocalUserFile('/b.db'));

      expect(habitList.size(), 1,
          reason: 'persistence.loop-db-import#7 getByUUID found the habit, so '
              'nothing new was created');
      expect(habitList.log, isNot(contains('add')),
          reason: 'persistence.loop-db-import#7 the second pass runs '
              'EditHabitCommand, not CreateHabitCommand');
      expect(habitList.getByUUID('u-1')!.name, 'Meditate daily',
          reason: 'persistence.loop-db-import#7 the backup overwrites the '
              'local habit');
      expect(habitList.getByUUID('u-1')!.id, created.id,
          reason: 'persistence.loop-db-import#7 HabitData is copied with '
              'id = the EXISTING local id, so the habit keeps it');
    });

    test('#8 entries are read with the SOURCE habit id', () async {
      final source = RecordingDatabase(newSourceDatabase());
      insertHabit(source, id: 77, position: 0, uuid: 'u');
      insertEntry(source, habit: 77, timestamp: day(2), value: 2);
      insertEntry(source, habit: 77, timestamp: day(0), value: 2);
      insertEntry(source, habit: 99, timestamp: day(1), value: 2);
      final habitList = MemoryHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/a.db'));

      expect(
        source.sql,
        contains('SELECT timestamp, value, notes FROM Repetitions '
            'WHERE habit = ? ORDER BY timestamp DESC'),
        reason: 'persistence.loop-db-import#8 the entry query is issued '
            'verbatim',
      );
      final entryStmt = source.statements
          .lastWhere((s) => s.sql.contains('FROM Repetitions'));
      expect(entryStmt.boundText, <String>['77'],
          reason: 'persistence.loop-db-import#8 it is bound with the SOURCE '
              "habit's id (77), not the local one");
      expect(habitList.getByUUID('u')!.id, isNot(77),
          reason: 'persistence.loop-db-import#8 the local id really is a '
              'different number');
      expect(habitList.getByUUID('u')!.originalEntries.getKnown().length, 2,
          reason: 'persistence.loop-db-import#8 only the rows of habit 77 are '
              'imported');
    });

    test('#9 rows with a NULL timestamp or value are skipped, NULL notes ""',
        () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'u');
      insertEntry(source, habit: 1, timestamp: null, value: 2);
      insertEntry(source, habit: 1, timestamp: day(1), value: null);
      insertEntry(source, habit: 1, timestamp: day(2), value: 2, notes: null);
      final habitList = MemoryHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/a.db'));

      final entries = habitList.getByUUID('u')!.originalEntries;
      expect(entries.getKnown().length, 1,
          reason: 'persistence.loop-db-import#9 the NULL-timestamp row and the '
              'NULL-value row are both skipped');
      expect(entries.get(LocalDate(2)).value, 2,
          reason: 'persistence.loop-db-import#9 the surviving row is imported');
      expect(entries.get(LocalDate(2)).notes, '',
          reason: 'persistence.loop-db-import#9 a NULL notes column becomes '
              'the empty string; persistence.migration-v25#3 — the importer '
              'coerces NULL notes to "" exactly as EntryRepository does');
      expect(entries.get(LocalDate(1)).value, Entry.unknown,
          reason: 'persistence.loop-db-import#9 the NULL-value row leaves no '
              'entry behind at all');
    });

    test('#10 an entry is written only when value or notes differ', () async {
      final source = newSourceDatabase();
      insertHabit(source, id: 1, position: 0, uuid: 'u');
      insertEntry(source, habit: 1, timestamp: day(0), value: 2, notes: 'a');
      insertEntry(source, habit: 1, timestamp: day(1), value: 2, notes: 'b');
      final counter = Counter();
      final habitList = MemoryHabitList();
      final modelFactory = CountingModelFactory(counter);

      await buildImporter(
        habitList: habitList,
        modelFactory: modelFactory,
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/a.db'));
      expect(counter.value, 2,
          reason: 'persistence.loop-db-import#10 the first import writes both '
              'entries');

      // The same file again: nothing differs, so nothing is rewritten.
      final same = newSourceDatabase();
      insertHabit(same, id: 1, position: 0, uuid: 'u');
      insertEntry(same, habit: 1, timestamp: day(0), value: 2, notes: 'a');
      insertEntry(same, habit: 1, timestamp: day(1), value: 2, notes: 'b');
      counter.value = 0;
      await buildImporter(
        habitList: habitList,
        modelFactory: modelFactory,
        opener: FixedDatabaseOpener(same),
      ).importHabitsFromFile(LocalUserFile('/b.db'));
      expect(counter.value, 0,
          reason: 'persistence.loop-db-import#10 identical entries are not '
              'rewritten');

      // One differing value, one differing note.
      final changed = newSourceDatabase();
      insertHabit(changed, id: 1, position: 0, uuid: 'u');
      insertEntry(changed, habit: 1, timestamp: day(0), value: 3, notes: 'a');
      insertEntry(changed, habit: 1, timestamp: day(1), value: 2, notes: 'B!');
      counter.value = 0;
      await buildImporter(
        habitList: habitList,
        modelFactory: modelFactory,
        opener: FixedDatabaseOpener(changed),
      ).importHabitsFromFile(LocalUserFile('/c.db'));
      expect(counter.value, 2,
          reason: 'persistence.loop-db-import#10 a different value OR a '
              'different note is enough to rewrite the entry');
      final entries = habitList.getByUUID('u')!.originalEntries;
      expect(entries.get(LocalDate(0)).value, 3,
          reason: 'persistence.loop-db-import#10 the changed value wins');
      expect(entries.get(LocalDate(1)).notes, 'B!',
          reason: 'persistence.loop-db-import#10 the changed note wins');
    });

    test('#11 recompute per habit, then resort, then close', () async {
      final source = RecordingDatabase(newSourceDatabase());
      insertHabit(source, id: 1, position: 0, uuid: 'a', freqNum: 3, freqDen: 7);
      insertEntry(source, habit: 1, timestamp: day(10), value: 2);
      insertEntry(source, habit: 1, timestamp: day(12), value: 2);
      insertHabit(source, id: 2, position: 1, uuid: 'b');
      final habitList = LoggingHabitList();

      await buildImporter(
        habitList: habitList,
        modelFactory: MemoryModelFactory(),
        opener: FixedDatabaseOpener(source),
      ).importHabitsFromFile(LocalUserFile('/a.db'));

      expect(habitList.log.last, 'resort',
          reason: 'persistence.loop-db-import#11 habitList.resort() is the '
              'last list call the import makes, after every habit');
      expect(source.closed, isTrue,
          reason: 'persistence.loop-db-import#11 the source database is '
              'closed');
      expect(habitList.getByUUID('a')!.computedEntries.getKnown(), isNotEmpty,
          reason: 'persistence.loop-db-import#11 habit.recompute() ran after '
              "that habit's entries were merged, so the computed list is "
              'populated');
      expect(habitList.getByUUID('a')!.scores[LocalDate(12)].value,
          greaterThan(0.0),
          reason: 'persistence.loop-db-import#11 the recompute really ran: the '
              'scores of that habit were refreshed from the merged entries');
    });

    test('#12 the loop.db fixture imports nine habits', () async {
      final habitList = MemoryHabitList();
      await importLoopFixture(habitList: habitList);

      expect(habitList.size(), 9,
          reason: 'persistence.loop-db-import#12 uhabits-core/assets/test/'
              'loop.db yields 9 habits');
      final first = habitList.getByPosition(0);
      expect(first.name, 'Wake up early',
          reason: 'persistence.loop-db-import#12 the habit at position 0 is '
              '"Wake up early"');
      expect(first.frequency, Frequency(3, 7),
          reason: 'persistence.loop-db-import#12 with frequency 3/7');
      final entries = first.originalEntries;
      expect(entries.get(LocalDate.ymd(2016, 3, 14)).value, Entry.yesManual,
          reason: 'persistence.loop-db-import#12 checked on 2016-03-14');
      expect(entries.get(LocalDate.ymd(2016, 3, 16)).value, Entry.yesManual,
          reason: 'persistence.loop-db-import#12 checked on 2016-03-16');
      expect(entries.get(LocalDate.ymd(2016, 3, 17)).value,
          isNot(Entry.yesManual),
          reason: 'persistence.loop-db-import#12 NOT checked on 2016-03-17');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String twoDigits(int v) => v.toString().padLeft(2, '0');

/// Milliseconds of `2000-01-01 + n days`, the timestamps the Repetitions table
/// stores.
int day(int n) => LocalDate(n).unixTime;

Directory repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    if (Directory('${dir.path}/uhabits-core/assets/main/migrations')
        .existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Repository root not found above ${Directory.current.path}');
}

FileOpener assetsFileOpener() => LocalFileOpener(
      userDataDir: Directory.systemTemp.path,
      resourceRoots: <String>[
        '${repoRoot().path}/uhabits-core/assets/main',
        '${repoRoot().path}/uhabits-core/assets/test',
      ],
    );

/// Copies `uhabits-core/assets/test/loop.db` to a fresh temporary directory.
/// The importer migrates the file it is handed, so the fixture itself must
/// never be opened.
UserFile copyLoopFixture() {
  final dir = Directory.systemTemp.createTempSync('uhabits_loop_db');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final source = File('${repoRoot().path}/uhabits-core/assets/test/loop.db');
  final copy = File('${dir.path}/loop.db')
    ..writeAsBytesSync(source.readAsBytesSync());
  return LocalUserFile(copy.path);
}

LoopDBImporter buildImporter({
  required HabitList habitList,
  required ModelFactory modelFactory,
  DatabaseOpener opener = const Sqlite3DatabaseOpener(),
  FileOpener? fileOpener,
  Logging? logging,
}) =>
    LoopDBImporter(
      habitList: habitList,
      modelFactory: modelFactory,
      opener: opener,
      runner: CommandRunner(CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      )),
      logging: logging ??
          StandardLogging(out: StringBuffer(), err: StringBuffer()),
      fileOpener: fileOpener ?? assetsFileOpener(),
    );

Future<void> importLoopFixture({
  required HabitList habitList,
  ModelFactory? modelFactory,
  UserFile? file,
}) async {
  await buildImporter(
    habitList: habitList,
    modelFactory: modelFactory ?? MemoryModelFactory(),
  ).importHabitsFromFile(file ?? copyLoopFixture());
}

/// The UUID migration 24 stamped on the first habit of the (already migrated)
/// backup: `lower(hex(randomblob(16) || id))`, so it is different for every
/// copy of the fixture and can only be read back from the file itself.
String firstSourceUuid(UserFile file) {
  final db = const Sqlite3DatabaseOpener().open(file.pathString);
  final uuid = db.querySingle<String>(
    'select uuid from Habits order by position',
    const <String>[],
    (stmt) => stmt.getText(0),
  )!;
  db.close();
  return uuid;
}

/// A source database with the v25 column set, but every column nullable, so
/// that the NULL fallbacks of io.loop-db-habit-mapping#2 can be exercised.
Database newSourceDatabase({int version = databaseVersion}) {
  final db = Sqlite3Database.memory();
  addTearDown(() {
    try {
      db.close();
    } catch (_) {
      // Already closed by the importer.
    }
  });
  db.run('create table Habits (id integer primary key, name text, '
      'description text, question text, freq_num integer, freq_den integer, '
      'color integer, position integer, reminder_hour integer, '
      'reminder_min integer, reminder_days integer, highlight integer, '
      'archived integer, type integer, target_value real, '
      'target_type integer, unit text, uuid text)');
  db.run('create table Repetitions (id integer primary key, habit integer, '
      'timestamp integer, value integer, notes text)');
  db.setVersion(version);
  return db;
}

void insertHabit(
  Database db, {
  required int id,
  String name = 'habit',
  String description = '',
  String question = '',
  int freqNum = 1,
  int freqDen = 1,
  int color = 0,
  int position = 0,
  int? reminderHour,
  int? reminderMin,
  int reminderDays = 0,
  int highlight = 0,
  int archived = 0,
  int type = 0,
  double targetValue = 0.0,
  int targetType = 0,
  String unit = '',
  String? uuid,
}) {
  db.run(
    'insert into Habits(id, name, description, question, freq_num, freq_den, '
    'color, position, reminder_hour, reminder_min, reminder_days, highlight, '
    'archived, type, target_value, target_type, unit, uuid) '
    'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    (stmt) {
      stmt.bindLong(1, id);
      stmt.bindText(2, name);
      stmt.bindText(3, description);
      stmt.bindText(4, question);
      stmt.bindInt(5, freqNum);
      stmt.bindInt(6, freqDen);
      stmt.bindInt(7, color);
      stmt.bindInt(8, position);
      if (reminderHour == null) {
        stmt.bindNull(9);
      } else {
        stmt.bindInt(9, reminderHour);
      }
      if (reminderMin == null) {
        stmt.bindNull(10);
      } else {
        stmt.bindInt(10, reminderMin);
      }
      stmt.bindInt(11, reminderDays);
      stmt.bindInt(12, highlight);
      stmt.bindInt(13, archived);
      stmt.bindInt(14, type);
      stmt.bindReal(15, targetValue);
      stmt.bindInt(16, targetType);
      stmt.bindText(17, unit);
      if (uuid == null) {
        stmt.bindNull(18);
      } else {
        stmt.bindText(18, uuid);
      }
    },
  );
}

void insertEntry(
  Database db, {
  required int habit,
  required int? timestamp,
  required int? value,
  String? notes,
}) {
  db.run(
    'insert into Repetitions(habit, timestamp, value, notes) '
    'values (?, ?, ?, ?)',
    (stmt) {
      stmt.bindLong(1, habit);
      if (timestamp == null) {
        stmt.bindNull(2);
      } else {
        stmt.bindLong(2, timestamp);
      }
      if (value == null) {
        stmt.bindNull(3);
      } else {
        stmt.bindInt(3, value);
      }
      if (notes == null) {
        stmt.bindNull(4);
      } else {
        stmt.bindText(4, notes);
      }
    },
  );
}

List<String> tableNames(Database db) {
  final result = <String>[];
  db.query(
    "select name from sqlite_master where type = 'table' "
    "and name not like 'sqlite_%' order by lower(name)",
    const <String>[],
    (stmt) => result.add(stmt.getText(0)),
  );
  return result;
}

/// Always hands out the same [Database], whatever path it is asked for.
class FixedDatabaseOpener implements DatabaseOpener {
  FixedDatabaseOpener(this.db);

  final Database db;

  @override
  Database open(String path) => db;
}

/// Records every statement prepared through it, and whether it was closed.
class RecordingDatabase implements Database {
  RecordingDatabase(this.delegate);

  final Database delegate;
  final List<String> sql = <String>[];
  final List<RecordingStatement> statements = <RecordingStatement>[];
  bool closed = false;

  @override
  PreparedStatement prepareStatement(String sql) {
    this.sql.add(sql);
    final stmt = RecordingStatement(delegate.prepareStatement(sql), sql);
    statements.add(stmt);
    return stmt;
  }

  @override
  void close() {
    closed = true;
    delegate.close();
  }
}

class RecordingStatement implements PreparedStatement {
  RecordingStatement(this.delegate, this.sql);

  final PreparedStatement delegate;
  final String sql;
  final List<String> boundText = <String>[];

  @override
  void bindText(int index, String value) {
    boundText.add(value);
    delegate.bindText(index, value);
  }

  @override
  void bindInt(int index, int value) => delegate.bindInt(index, value);

  @override
  void bindLong(int index, int value) => delegate.bindLong(index, value);

  @override
  void bindNull(int index) => delegate.bindNull(index);

  @override
  void bindReal(int index, double value) => delegate.bindReal(index, value);

  @override
  void finalizeStatement() => delegate.finalizeStatement();

  @override
  int getInt(int index) => delegate.getInt(index);

  @override
  int? getIntOrNull(int index) => delegate.getIntOrNull(index);

  @override
  int getLong(int index) => delegate.getLong(index);

  @override
  int? getLongOrNull(int index) => delegate.getLongOrNull(index);

  @override
  double getReal(int index) => delegate.getReal(index);

  @override
  double? getRealOrNull(int index) => delegate.getRealOrNull(index);

  @override
  String getText(int index) => delegate.getText(index);

  @override
  String? getTextOrNull(int index) => delegate.getTextOrNull(index);

  @override
  void reset() => delegate.reset();

  @override
  StepResult step() => delegate.step();
}

/// Records which resource paths the importer asks for.
class RecordingFileOpener implements FileOpener {
  RecordingFileOpener(this.delegate);

  final FileOpener delegate;
  final List<String> resourcePaths = <String>[];

  @override
  ResourceFile openResourceFile(String path) {
    resourcePaths.add(path);
    return delegate.openResourceFile(path);
  }

  @override
  UserFile openUserFile(String path) => delegate.openUserFile(path);
}

/// The FileOpener contract says openResourceFile always succeeds, even for a
/// file that does not exist; such a resource yields no lines.
class MissingResourceFileOpener implements FileOpener {
  @override
  ResourceFile openResourceFile(String path) => EmptyResourceFile();

  @override
  UserFile openUserFile(String path) => LocalUserFile(path);
}

class EmptyResourceFile implements ResourceFile {
  @override
  Future<void> copyTo(UserFile dest) async {}

  @override
  Future<bool> exists() async => false;

  @override
  Future<List<String>> lines() async => <String>[];

  @override
  Future<Never> toImage() => Future<Never>.error(UnimplementedError());
}

/// Logs the list mutations the import performs, in order.
class LoggingHabitList extends MemoryHabitList {
  final List<String> log = <String>[];

  @override
  void add(Habit habit) {
    log.add('add');
    super.add(habit);
  }

  @override
  void update(List<Habit> habits) {
    log.add('update');
    super.update(habits);
  }

  @override
  void resort() {
    log.add('resort');
    super.resort();
  }
}

class Counter {
  int value = 0;
}

/// Counts the writes into `habit.originalEntries`.
class CountingEntryList extends EntryList {
  CountingEntryList(this.counter);

  final Counter counter;

  @override
  void add(Entry entry) {
    counter.value++;
    super.add(entry);
  }
}

class CountingModelFactory extends MemoryModelFactory {
  CountingModelFactory(this.counter);

  final Counter counter;

  @override
  EntryList buildOriginalEntries() => CountingEntryList(counter);
}

/// The SQL `HabitRepository` prepares for `findAll`, read off a real
/// repository so it can never drift from the production statement.
String repositoryFindAllSql(RecordingDatabase db) {
  HabitRepository(db).findAllStmt; // forces the lazy prepare
  return db.sql.last;
}

/// A [DatabaseOpener] that must never be reached.
class ExplodingOpener implements DatabaseOpener {
  @override
  Database open(String path) =>
      throw StateError('the database must not be opened: $path');
}

/// Wraps a [UserFile] and records the `limit` of every `readBytes` call.
class RecordingUserFile implements UserFile {
  RecordingUserFile(this.delegate);

  final UserFile delegate;

  final List<int> readLimits = <int>[];

  @override
  Future<Uint8List> readBytes(int limit) {
    readLimits.add(limit);
    return delegate.readBytes(limit);
  }

  @override
  String get pathString => delegate.pathString;

  @override
  Future<void> delete() => delegate.delete();

  @override
  Future<bool> exists() => delegate.exists();

  @override
  Future<List<String>> lines() => delegate.lines();

  @override
  Future<List<UserFile>?> listFiles() => delegate.listFiles();

  @override
  Future<void> mkdirs() => delegate.mkdirs();

  @override
  UserFile resolve(String child) => delegate.resolve(child);

  @override
  Future<void> writeBytes(List<int> bytes) => delegate.writeBytes(bytes);

  @override
  Future<void> writeString(String content) => delegate.writeString(content);
}
