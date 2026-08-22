/// Migrations 18..25 — behavioural assertions about the embedded SQL.
///
/// This slice creates no library code: migrations 18..25 are verbatim copies of
/// `uhabits-core/assets/main/migrations/NN.sql` already shipped in
/// `lib/src/database/migrations.g.dart`. What is ported here is the *contract*
/// each script must keep, driven through the real runner
/// (`DatabaseExtensions.migrateTo`) on a fresh in-memory database, plus the two
/// legacy fixture databases the Kotlin tests use
/// (`uhabits-core/assets/test/databases/021.db` and `022.db`, always opened as
/// a copy, never in place).
///
/// Kotlin counterparts:
///   uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/
///     migrations/Version22Test.kt
///     migrations/Version23Test.kt
///
/// Known gap, deliberately NOT asserted (see the slice report):
/// `persistence.migration-v22#6` also requires foreign key enforcement on
/// *every* connection. `pragma foreign_keys` is per-connection and sqlite
/// defaults it to OFF, so a connection that opens an already-migrated database
/// (migrateTo returns immediately, the pragma never runs) has foreign keys
/// disabled. Fixing that belongs to `Sqlite3Database`/`Sqlite3DatabaseOpener`,
/// which are another slice's files.
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sql_parser.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';

import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

/// The statements migration [version] is split into by the real parser.
List<String> parseMigration(int version) =>
    SQLParser.parse(migrationSql[version]!);

/// A fresh in-memory database migrated up to [version] and closed after the
/// test. Kotlin's equivalent is a temp copy of a fixture database.
Database dbAt(int version) {
  final db = openMigratedDatabase(version: version);
  addTearDown(db.close);
  return db;
}

/// Applies migrations up to [version] with the bundled scripts, exactly as the
/// app does.
void migrateTo(Database db, int version) {
  db.migrateTo(version, (v) => migrationSql[v]!);
}

int queryCount(Database db, String sql) =>
    db.querySingle(sql, const [], (stmt) => stmt.getInt(0))!;

int? queryIntOrNull(Database db, String sql) =>
    db.querySingle<int?>(sql, const [], (stmt) => stmt.getIntOrNull(0));

double? queryRealOrNull(Database db, String sql) =>
    db.querySingle<double?>(sql, const [], (stmt) => stmt.getRealOrNull(0));

String? queryTextOrNull(Database db, String sql) =>
    db.querySingle<String?>(sql, const [], (stmt) => stmt.getTextOrNull(0));

List<String> queryTextColumn(Database db, String sql) {
  final result = <String>[];
  db.query(sql, const [], (stmt) => result.add(stmt.getText(0)));
  return result;
}

List<int> queryIntColumn(Database db, String sql) {
  final result = <int>[];
  db.query(sql, const [], (stmt) => result.add(stmt.getInt(0)));
  return result;
}

/// One row of `pragma table_info(...)`.
class ColumnInfo {
  ColumnInfo(this.name, this.type, this.notNull, this.defaultValue);

  final String name;
  final String type;
  final bool notNull;
  final String? defaultValue;
}

List<ColumnInfo> tableInfo(Database db, String table) {
  final columns = <ColumnInfo>[];
  db.query('pragma table_info($table)', const [], (stmt) {
    columns.add(
      ColumnInfo(
        stmt.getText(1),
        stmt.getText(2),
        stmt.getInt(3) != 0,
        stmt.getTextOrNull(4),
      ),
    );
  });
  return columns;
}

List<String> tableNames(Database db) => queryTextColumn(
      db,
      "select name from sqlite_master where type = 'table' "
      "and name not like 'sqlite_%' order by lower(name)",
    );

/// Runs [body] and returns the driver's error message, or null when it
/// succeeded. Mirrors Kotlin's `assertFailsWith<Throwable> { ... }.message`.
String? errorMessage(void Function() body) {
  try {
    body();
    return null;
  } on SqliteException catch (e) {
    return e.message;
  } catch (e) {
    return e.toString();
  }
}

final List<Directory> _tempDirs = <Directory>[];

String fixturePath(String name) {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final candidate =
        File('${dir.path}/uhabits-core/assets/test/databases/$name');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('Fixture $name not found above ${Directory.current.path}');
}

/// Opens a COPY of a legacy fixture database, never the original file: the
/// migrations rewrite it in place. Kotlin's `openDatabaseResource` copies the
/// resource to a temp file for the same reason.
Database openFixtureCopy(String name) {
  final dir = Directory.systemTemp.createTempSync('uhabits_fixture');
  _tempDirs.add(dir);
  final copy = File('${dir.path}/$name')
    ..writeAsBytesSync(File(fixturePath(name)).readAsBytesSync());
  final db = const Sqlite3DatabaseOpener().open(copy.path);
  addTearDown(db.close);
  return db;
}

/// Directory `lib/` of this package, wherever the test runner was started.
Directory packageLibDir() {
  var dir = Directory.current;
  for (var i = 0; i < 10; i++) {
    final candidate = Directory('${dir.path}/lib');
    if (candidate.existsSync() &&
        File('${dir.path}/pubspec.yaml').existsSync()) {
      return candidate;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('lib/ not found above ${Directory.current.path}');
}

void main() {
  tearDownAll(() {
    for (final dir in _tempDirs) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
    _tempDirs.clear();
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v18 — numerical target columns
  // -------------------------------------------------------------------------
  group('migration 18', () {
    test('executes three ALTER TABLE statements in order', () {
      expect(
        parseMigration(18),
        [
          'alter table Habits add column target_type integer not null default 0',
          'alter table Habits add column target_value real not null default 0',
          'alter table Habits add column unit text not null default ""',
        ],
        reason: 'persistence.migration-v18#1 — three ALTER TABLE statements on '
            'Habits, in the order target_type, target_value, unit',
      );
    });

    test('adds the three columns to Habits', () {
      final db = dbAt(17);
      expect(
        tableInfo(db, 'Habits').map((c) => c.name),
        isNot(contains('target_type')),
        reason: 'persistence.migration-v18#1 — the columns do not exist before '
            'the migration runs',
      );

      migrateTo(db, 18);

      final columns = {for (final c in tableInfo(db, 'Habits')) c.name: c};
      expect(columns.containsKey('target_type'), isTrue,
          reason: 'persistence.migration-v18#1 — target_type is added');
      expect(columns['target_type']!.type.toLowerCase(), 'integer',
          reason: 'persistence.migration-v18#1 — target_type is integer');
      expect(columns['target_type']!.notNull, isTrue,
          reason: 'persistence.migration-v18#1 — target_type is not null');
      expect(columns['target_type']!.defaultValue, '0',
          reason: 'persistence.migration-v18#1 — target_type defaults to 0');
      expect(columns['target_value']!.type.toLowerCase(), 'real',
          reason: 'persistence.migration-v18#1 — target_value is real');
      expect(columns['target_value']!.defaultValue, '0',
          reason: 'persistence.migration-v18#1 — target_value defaults to 0');
      expect(columns['unit']!.type.toLowerCase(), 'text',
          reason: 'persistence.migration-v18#1 — unit is text');
      expect(columns['unit']!.notNull, isTrue,
          reason: 'persistence.migration-v18#1 — unit is not null');
    });

    test('backfills existing habits with 0, 0.0 and the empty string', () {
      final db = dbAt(17);
      db.run("insert into Habits(name, description) values ('Wake up', 'd')");
      migrateTo(db, 18);

      expect(queryIntOrNull(db, 'select target_type from Habits'), 0,
          reason: 'persistence.migration-v18#3 — existing habits get '
              'target_type = 0');
      expect(queryRealOrNull(db, 'select target_value from Habits'), 0.0,
          reason: 'persistence.migration-v18#3 — existing habits get '
              'target_value = 0.0');
      expect(queryTextOrNull(db, 'select unit from Habits'), '',
          reason: 'persistence.migration-v18#3 — existing habits get unit = '
              "''");
    });

    test('the "" default is the empty-string literal, not NULL and not quotes',
        () {
      final db = dbAt(17);
      db.run("insert into Habits(name) values ('Wake up')");
      migrateTo(db, 18);

      expect(queryTextOrNull(db, 'select typeof(unit) from Habits'), 'text',
          reason: 'persistence.migration-v18#2 — SQLite reads "" as a string '
              'literal, so unit is text, not NULL');
      expect(queryTextOrNull(db, 'select unit from Habits'), isNotNull,
          reason: 'persistence.migration-v18#2 — unit is not NULL');
      expect(queryIntOrNull(db, 'select length(unit) from Habits'), 0,
          reason: 'persistence.migration-v18#2 — unit is the empty string');
      expect(queryTextOrNull(db, 'select unit from Habits'), isNot('""'),
          reason: 'persistence.migration-v18#2 — unit is not the literal two '
              'quote characters');
      expect(queryCount(db, "select count(*) from Habits where unit = ''"), 1,
          reason: "persistence.migration-v18#2 — unit compares equal to ''");
    });
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v19 — Events table
  // -------------------------------------------------------------------------
  group('migration 19', () {
    test('executes exactly one create table statement', () {
      final commands = parseMigration(19);
      expect(commands.length, 1,
          reason: 'persistence.migration-v19#1 — exactly one statement');
      expect(
        commands.single,
        'create table Events ( id integer primary key autoincrement, '
        'timestamp integer, message text, server_id integer )',
        reason: 'persistence.migration-v19#1 — creates Events(id integer '
            'primary key autoincrement, timestamp integer, message text, '
            'server_id integer)',
      );
    });

    test('creates the Events table with the declared columns', () {
      final db = dbAt(18);
      expect(tableNames(db), isNot(contains('Events')),
          reason: 'persistence.migration-v19#1 — Events does not exist at 18');

      migrateTo(db, 19);

      final columns = tableInfo(db, 'Events');
      expect(columns.map((c) => c.name).toList(),
          ['id', 'timestamp', 'message', 'server_id'],
          reason: 'persistence.migration-v19#1 — column names and order');
      expect(columns.map((c) => c.type.toLowerCase()).toList(),
          ['integer', 'integer', 'text', 'integer'],
          reason: 'persistence.migration-v19#1 — column types');
    });

    test('survives to version 25 as dead schema, never written to', () {
      final db = dbAt(19);
      final schemaAt19 = queryTextOrNull(
          db, "select sql from sqlite_master where name = 'Events'");
      db.run("insert into Habits(name) values ('Wake up')");

      migrateTo(db, 25);

      expect(tableNames(db), contains('Events'),
          reason: 'persistence.migration-v19#2 — Events survives to version 25 '
              'as dead schema');
      expect(
          queryTextOrNull(
              db, "select sql from sqlite_master where name = 'Events'"),
          schemaAt19,
          reason: 'persistence.migration-v19#2 — no later migration alters or '
              'drops Events');
      expect(queryCount(db, 'select count(*) from Events'), 0,
          reason: 'persistence.migration-v19#2 — nothing ever inserts into '
              'Events');
    });

    test('no code in lib/ reads, writes or drops the Events table', () {
      final offenders = <String>[];
      final pattern = RegExp(
        r'\b(insert\s+into|from|update|drop\s+table|delete\s+from)\s+events\b',
        caseSensitive: false,
      );
      for (final entity in packageLibDir().listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // migrations.g.dart holds 19.sql itself, which is the create table.
        if (entity.path.endsWith('migrations.g.dart')) continue;
        if (pattern.hasMatch(entity.readAsStringSync())) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'persistence.migration-v19#2 — no application code inserts '
              'into, selects from or drops the Events table');
    });
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v20 — drop derived tables
  // -------------------------------------------------------------------------
  group('migration 20', () {
    test('executes exactly three drop statements in order', () {
      expect(
        parseMigration(20),
        [
          'drop table checkmarks',
          'drop table streak',
          'drop table score',
        ],
        reason: 'persistence.migration-v20#1 — exactly three statements: drop '
            'checkmarks, then streak, then score',
      );
    });

    test('leaves only Habits, Repetitions and Events behind', () {
      final db = dbAt(19);
      expect(tableNames(db), containsAll(['Checkmarks', 'Streak', 'Score']),
          reason: 'persistence.migration-v20#1 — the three derived tables '
              'exist before the migration');

      migrateTo(db, 20);

      expect(tableNames(db), ['Events', 'Habits', 'Repetitions'],
          reason: 'persistence.migration-v20#2 — only habits, repetitions and '
              'the unused Events table persist');
      expect(tableNames(db), isNot(contains('Checkmarks')),
          reason: 'persistence.migration-v20#1 — checkmarks is dropped');
      expect(tableNames(db), isNot(contains('Streak')),
          reason: 'persistence.migration-v20#1 — streak is dropped');
      expect(tableNames(db), isNot(contains('Score')),
          reason: 'persistence.migration-v20#1 — score is dropped');
    });

    test('scores, streaks and checkmarks stay dropped through version 25', () {
      final db = dbAt(25);
      expect(tableNames(db), ['Events', 'Habits', 'Repetitions'],
          reason: 'persistence.migration-v20#2 — at version 25 all scores, '
              'streaks and checkmarks are purely computed values');
    });
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v21 — second color remap
  // -------------------------------------------------------------------------
  group('migration 21', () {
    // Source -> target, in the order the script applies them.
    const mappings = <List<int>>[
      [12, 19],
      [11, 17],
      [10, 15],
      [9, 14],
      [8, 13],
      [7, 10],
      [6, 9],
      [5, 8],
      [4, 7],
      [3, 5],
      [2, 4],
    ];

    /// A version 20 database holding one habit per color in [colors]; returns
    /// the habit id of each color.
    (Database, Map<int, int>) habitsWithColors(List<int> colors) {
      final db = dbAt(20);
      final ids = <int, int>{};
      for (final color in colors) {
        db.run("insert into Habits(name, color) values ('h$color', $color)");
        ids[color] = queryCount(db, 'select max(id) from Habits');
      }
      return (db, ids);
    }

    int colorOf(Database db, int id) =>
        queryIntOrNull(db, 'select color from Habits where id = $id')!;

    test('applies eleven mappings as separate updates in descending order', () {
      final commands = parseMigration(21);
      expect(
        commands.sublist(0, 11),
        [
          for (final m in mappings)
            'update habits set color=${m[1]} where color=${m[0]}',
        ],
        reason: 'persistence.migration-v21#1 — 12->19, 11->17, 10->15, 9->14, '
            '8->13, 7->10, 6->9, 5->8, 4->7, 3->5, 2->4 as separate UPDATE '
            'statements in exactly this descending-source order',
      );
      expect(commands.length, 12,
          reason: 'persistence.migration-v21#1 — eleven mappings plus the '
              'final clamp');
    });

    test('remaps every pre-existing color exactly once', () {
      final (db, ids) = habitsWithColors([for (var c = 0; c <= 12; c++) c]);
      migrateTo(db, 21);

      for (final m in mappings) {
        expect(colorOf(db, ids[m[0]]!), m[1],
            reason: 'persistence.migration-v21#1 — color ${m[0]} becomes '
                '${m[1]}');
      }
    });

    test('leaves colors 0 and 1 unchanged', () {
      final (db, ids) = habitsWithColors([0, 1]);
      migrateTo(db, 21);

      expect(colorOf(db, ids[0]!), 0,
          reason: 'persistence.migration-v21#2 — color 0 is left unchanged');
      expect(colorOf(db, ids[1]!), 1,
          reason: 'persistence.migration-v21#2 — color 1 is left unchanged');
      final sources = parseMigration(21).sublist(0, 11);
      expect(sources, isNot(contains('update habits set color=0 where color=0')),
          reason: 'persistence.migration-v21#2 — no statement touches color 0');
      expect(sources.where((c) => c.endsWith('where color=1')), isEmpty,
          reason: 'persistence.migration-v21#2 — no statement touches color 1');
    });

    test('the descending order prevents double remapping', () {
      final (db, ids) = habitsWithColors([2, 7, 10]);
      migrateTo(db, 21);
      expect(colorOf(db, ids[10]!), 15,
          reason: 'persistence.migration-v21#3 — 10->15 runs before 7->10, so '
              'the original 10 is not remapped again');
      expect(colorOf(db, ids[7]!), 10,
          reason: 'persistence.migration-v21#3 — the 10 produced by 7->10 '
              'stays 10');
      expect(colorOf(db, ids[2]!), 4,
          reason: 'persistence.migration-v21#3 — 2 is remapped exactly once, '
              'to 4');

      // The same statements in ascending-source order cascade instead:
      // 2 -> 4 -> 7 -> 10 -> 15.
      final (ascending, ascendingIds) = habitsWithColors([2]);
      for (final m in mappings.reversed) {
        ascending.run('update habits set color=${m[1]} where color=${m[0]}');
      }
      expect(colorOf(ascending, ascendingIds[2]!), 15,
          reason: 'persistence.migration-v21#3 — the descending order is '
              'load-bearing: ascending order would remap 2 four times, to 15');
    });

    test('clamps out-of-range colors to 0', () {
      expect(parseMigration(21).last,
          'update habits set color=0 where color<0 or color>19',
          reason: 'persistence.migration-v21#4 — the final statement clamps '
              'out-of-range values');
      final (db, ids) = habitsWithColors([-5, 13, 20, 100]);
      migrateTo(db, 21);
      expect(colorOf(db, ids[-5]!), 0,
          reason: 'persistence.migration-v21#4 — a negative color is clamped '
              'to 0');
      expect(colorOf(db, ids[20]!), 0,
          reason: 'persistence.migration-v21#4 — color 20 is clamped to 0');
      expect(colorOf(db, ids[100]!), 0,
          reason: 'persistence.migration-v21#4 — color 100 is clamped to 0');
      expect(colorOf(db, ids[13]!), 13,
          reason: 'persistence.migration-v21#4 — an in-range color that is not '
              'a mapping source survives the clamp');
    });

    test('leaves palette indices 2, 3, 6, 11, 12, 16 and 18 unreachable', () {
      final (db, _) = habitsWithColors(
          [for (var c = -3; c <= 15; c++) c]); // every legacy value and more
      migrateTo(db, 21);
      final colors = queryIntColumn(db, 'select color from Habits').toSet();
      for (final unreachable in [2, 3, 6, 11, 12, 16, 18]) {
        expect(colors, isNot(contains(unreachable)),
            reason: 'persistence.migration-v21#5 — palette index $unreachable '
                'is unreachable for pre-existing habits');
      }
      expect(colors, containsAll([0, 4, 5, 7, 8, 9, 10, 13, 14, 15, 17, 19]),
          reason: 'persistence.migration-v21#5 — every other index below 20 is '
              'reachable');
    });
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v22 — Repetitions cleanup and constraint rebuild
  // -------------------------------------------------------------------------
  group('migration 22', () {
    /// A version 21 database with one habit; returns its id.
    (Database, int) dbWithOneHabit() {
      final db = dbAt(21);
      db.run("insert into Habits(name, color) values ('Wake up', 0)");
      return (db, queryCount(db, 'select max(id) from Habits'));
    }

    test('runs four deletes, in order, before the transaction', () {
      final commands = parseMigration(22);
      expect(
        commands.sublist(0, 4),
        [
          'delete from repetitions where habit not in (select id from habits)',
          'delete from repetitions where timestamp is null',
          'delete from repetitions where habit is null',
          'delete from repetitions where rowid not in ( select min(rowid) from '
              'repetitions group by habit, timestamp )',
        ],
        reason: 'persistence.migration-v22#1 — the four DELETE statements, in '
            'this exact order',
      );
      expect(commands[4], 'begin transaction',
          reason: 'persistence.migration-v22#1 — the deletes run BEFORE the '
              'transaction',
      );
    });

    test('deletes repetitions whose habit does not exist', () {
      final (db, _) = dbWithOneHabit();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values (99999, 100, 2)');
      expect(
          queryCount(
              db, 'select count(*) from repetitions where habit = 99999'),
          1,
          reason: 'persistence.migration-v22#1 — the orphan row exists before '
              'the migration');

      migrateTo(db, 22);

      expect(
          queryCount(
              db, 'select count(*) from repetitions where habit = 99999'),
          0,
          reason: 'persistence.migration-v22#1 — delete from repetitions where '
              'habit not in (select id from habits)');
    });

    test('deletes repetitions with a null timestamp or a null habit', () {
      final (db, habitId) = dbWithOneHabit();
      db.run('insert into Repetitions(habit, value) values ($habitId, 2)');
      db.run('insert into Repetitions(timestamp, value) values (100, 2)');
      expect(
          queryCount(
              db, 'select count(*) from repetitions where timestamp is null'),
          1,
          reason: 'persistence.migration-v22#1 — the null-timestamp row exists '
              'before the migration');
      expect(
          queryCount(db, 'select count(*) from repetitions where habit is null'),
          1,
          reason: 'persistence.migration-v22#1 — the null-habit row exists '
              'before the migration');

      migrateTo(db, 22);

      expect(
          queryCount(
              db, 'select count(*) from repetitions where timestamp is null'),
          0,
          reason: 'persistence.migration-v22#1 — delete from repetitions where '
              'timestamp is null');
      expect(
          queryCount(db, 'select count(*) from repetitions where habit is null'),
          0,
          reason: 'persistence.migration-v22#1 — delete from repetitions where '
              'habit is null');
    });

    test('deduplication keeps the smallest rowid, so the first value wins', () {
      final (db, habitId) = dbWithOneHabit();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 2)');
      final firstId = queryCount(db, 'select max(id) from Repetitions');
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 5)');
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 10)');
      expect(
          queryCount(db,
              'select count(*) from repetitions where timestamp = 100 and '
              'habit = $habitId'),
          3,
          reason: 'persistence.migration-v22#1 — three duplicates exist before '
              'the migration');

      migrateTo(db, 22);

      expect(
          queryCount(db,
              'select count(*) from repetitions where timestamp = 100 and '
              'habit = $habitId'),
          1,
          reason: 'persistence.migration-v22#1 — delete from repetitions where '
              'rowid not in (select min(rowid) ... group by habit, timestamp)');
      expect(
          queryIntOrNull(db,
              'select value from repetitions where timestamp = 100 and '
              'habit = $habitId'),
          2,
          reason: 'persistence.migration-v22#2 — the smallest rowid survives, '
              'so the first-inserted value (2) wins over 5 and 10');
      expect(
          queryIntOrNull(db,
              'select id from repetitions where timestamp = 100 and '
              'habit = $habitId'),
          firstId,
          reason: 'persistence.migration-v22#2 — later duplicates are '
              'discarded regardless of their value');
    });

    test('rebuilds the table inside a transaction, in order', () {
      final commands = parseMigration(22);
      expect(
        commands.sublist(4, 12),
        [
          'begin transaction',
          'alter table Repetitions rename to RepetitionsBak',
          'create table Repetitions ( id integer primary key autoincrement, '
              'habit integer not null references habits(id), timestamp integer '
              'not null, value integer not null)',
          'drop index if exists idx_repetitions_habit_timestamp',
          'create unique index idx_repetitions_habit_timestamp on Repetitions( '
              'habit, timestamp)',
          'insert into Repetitions select * from RepetitionsBak',
          'drop table RepetitionsBak',
          'commit',
        ],
        reason: 'persistence.migration-v22#3 — rename, create, drop index, '
            'create unique index, insert, drop table, all between begin '
            'transaction and commit',
      );
    });

    test('the rebuilt table has the unique index and the FK reference', () {
      final (db, habitId) = dbWithOneHabit();
      migrateTo(db, 22);

      expect(tableNames(db), isNot(contains('RepetitionsBak')),
          reason: 'persistence.migration-v22#3 — RepetitionsBak is dropped');
      expect(
        // SQLite normalises the leading CREATE ... keywords to upper case in
        // sqlite_master, so compare case-insensitively.
        queryTextOrNull(
                db,
                'select sql from sqlite_master where '
                "name = 'idx_repetitions_habit_timestamp'")
            ?.toLowerCase(),
        contains('unique'),
        reason: 'persistence.migration-v22#3 — idx_repetitions_habit_timestamp '
            'is recreated as a unique index',
      );
      expect(
          queryCount(db, 'select count(*) from pragma_foreign_key_list('
              "'Repetitions') where \"table\" = 'habits'"),
          1,
          reason: 'persistence.migration-v22#3 — habit references habits(id)');
      expect(
        errorMessage(() => db.run('insert into Repetitions(habit, timestamp, '
            'value) values ($habitId, 100, 2)')),
        isNull,
        reason: 'persistence.migration-v22#3 — the rebuilt table still accepts '
            'a valid repetition',
      );
    });

    test('the copy is positional, so the column order must line up', () {
      final (db, habitId) = dbWithOneHabit();
      expect(tableInfo(db, 'Repetitions').map((c) => c.name).toList(),
          ['id', 'habit', 'timestamp', 'value'],
          reason: 'persistence.migration-v22#4 — the old table column order is '
              'exactly id, habit, timestamp, value');
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 555, 7)');
      final oldId = queryCount(db, 'select max(id) from Repetitions');

      migrateTo(db, 22);

      expect(tableInfo(db, 'Repetitions').map((c) => c.name).toList(),
          ['id', 'habit', 'timestamp', 'value'],
          reason: 'persistence.migration-v22#4 — the new table repeats that '
              'column order, which is what makes select * line up');
      expect(parseMigration(22),
          contains('insert into Repetitions select * from RepetitionsBak'),
          reason: 'persistence.migration-v22#4 — the copy is positional '
              '(select *)');
      final row = db.querySingle(
          'select id, habit, timestamp, value from Repetitions',
          const [],
          (stmt) => [
                stmt.getInt(0),
                stmt.getInt(1),
                stmt.getInt(2),
                stmt.getInt(3),
              ]);
      expect(row, [oldId, habitId, 555, 7],
          reason: 'persistence.migration-v22#4 — every field lands in the '
              'matching column of the new table');
    });

    test('the new value column is not null with no default', () {
      final (db, habitId) = dbWithOneHabit();
      final before = {for (final c in tableInfo(db, 'Repetitions')) c.name: c};
      expect(before['value']!.defaultValue, '2',
          reason: 'persistence.migration-v22#5 — the old value column had '
              'default 2');

      migrateTo(db, 22);

      final after = {for (final c in tableInfo(db, 'Repetitions')) c.name: c};
      expect(after['value']!.notNull, isTrue,
          reason: 'persistence.migration-v22#5 — the new value column is not '
              'null');
      expect(after['value']!.defaultValue, isNull,
          reason: 'persistence.migration-v22#5 — the new value column has NO '
              'default');
      expect(
        errorMessage(() => db.run(
            'insert into Repetitions(habit, timestamp) values ($habitId, 7)')),
        contains('constraint'),
        reason: 'persistence.migration-v22#5 — with no default, an insert that '
            'omits value violates the not null constraint',
      );
    });

    test('the last statement turns foreign keys on for the connection', () {
      expect(parseMigration(22).last, 'pragma foreign_keys=ON',
          reason: 'persistence.migration-v22#6 — the last statement is pragma '
              'foreign_keys=ON');
      final (db, _) = dbWithOneHabit();
      expect(db.queryInt('pragma foreign_keys'), 0,
          reason: 'persistence.migration-v22#6 — foreign key enforcement is a '
              'per-connection setting and sqlite defaults it to OFF');

      migrateTo(db, 22);

      expect(db.queryInt('pragma foreign_keys'), 1,
          reason: 'persistence.migration-v22#6 — after the migration the '
              'migrating connection enforces foreign keys');
      expect(dbAt(25).queryInt('pragma foreign_keys'), 1,
          reason: 'persistence.migration-v22#6 — the setting survives the '
              'later migrations on that connection');
    });

    test('rejects a repetition referencing a missing habit', () {
      final (db, _) = dbWithOneHabit();
      migrateTo(db, 22);
      expect(
        errorMessage(() => db.run('insert into Repetitions(habit, timestamp, '
            'value) values (99999, 100, 2)')),
        contains('constraint'),
        reason: 'persistence.migration-v22#7 — inserting (habit=99999, '
            'timestamp=100, value=2) fails with a "constraint" error',
      );
    });

    test('rejects missing timestamp, missing habit and duplicates', () {
      final (db, habitId) = dbWithOneHabit();
      migrateTo(db, 22);

      expect(
        errorMessage(() => db
            .run('insert into Repetitions(habit, value) values ($habitId, 2)')),
        contains('constraint'),
        reason: 'persistence.migration-v22#8 — a missing timestamp fails with '
            'a "constraint" error',
      );
      expect(
        errorMessage(
            () => db.run('insert into Repetitions(timestamp, value) '
                'values (5, 2)')),
        contains('constraint'),
        reason: 'persistence.migration-v22#8 — a missing habit fails with a '
            '"constraint" error',
      );
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 2)');
      expect(
        errorMessage(() => db.run('insert into Repetitions(habit, timestamp, '
            'value) values ($habitId, 100, 5)')),
        contains('constraint'),
        reason: 'persistence.migration-v22#8 — a duplicate (habit, timestamp) '
            'fails with a "constraint" error',
      );
    });

    test('valid repetitions survive the migration unchanged', () {
      final (db, habitId) = dbWithOneHabit();
      for (final timestamp in [1497830400000, 1497916800000, 1498003200000]) {
        db.run('insert into Repetitions(habit, timestamp, value) '
            'values ($habitId, $timestamp, 2)');
      }
      expect(queryCount(db, 'select count(*) from repetitions'), 3,
          reason: 'persistence.migration-v22#9 — three valid rows go in');

      migrateTo(db, 22);

      expect(queryCount(db, 'select count(*) from repetitions'), 3,
          reason: 'persistence.migration-v22#9 — three rows come out');
      expect(
          queryIntColumn(
              db, 'select timestamp from repetitions order by timestamp'),
          [1497830400000, 1497916800000, 1498003200000],
          reason: 'persistence.migration-v22#9 — rows referencing an existing '
              'habit with a non-null timestamp survive unchanged');
    });

    // Ports of Version22Test.kt, driven off the legacy 021.db fixture.
    group('legacy 021.db fixture', () {
      test('keeps the three valid repetitions', () {
        final db = openFixtureCopy('021.db');
        expect(db.getVersion(), 21,
            reason: 'persistence.migration-v22#9 — the fixture is a version 21 '
                'database');
        expect(queryCount(db, 'select count(*) from repetitions'), 3,
            reason: 'persistence.migration-v22#9 — 3 valid rows in');

        migrateTo(db, 22);

        expect(queryCount(db, 'select count(*) from repetitions'), 3,
            reason: 'persistence.migration-v22#9 — 3 rows out');
      });

      test('removes repetitions with an invalid habit id', () {
        final db = openFixtureCopy('021.db');
        db.run('insert into Repetitions(habit, timestamp, value) '
            'values (99999, 100, 2)');
        expect(
            queryCount(
                db, 'select count(*) from repetitions where habit = 99999'),
            1,
            reason: 'persistence.migration-v22#1 — orphan row present before');

        migrateTo(db, 22);

        expect(
            queryCount(
                db, 'select count(*) from repetitions where habit = 99999'),
            0,
            reason: 'persistence.migration-v22#1 — orphan rows are deleted');
      });

      test('removes repetitions with a null timestamp', () {
        final db = openFixtureCopy('021.db');
        db.run('insert into repetitions(habit, value) values (0, 2)');
        expect(
            queryCount(
                db, 'select count(*) from repetitions where timestamp is null'),
            1,
            reason: 'persistence.migration-v22#1 — null timestamp present '
                'before');

        migrateTo(db, 22);

        expect(
            queryCount(
                db, 'select count(*) from repetitions where timestamp is null'),
            0,
            reason: 'persistence.migration-v22#1 — null timestamps are '
                'deleted');
      });

      test('removes repetitions with a null habit', () {
        final db = openFixtureCopy('021.db');
        db.run('insert into repetitions(timestamp, value) values (0, 2)');
        expect(
            queryCount(
                db, 'select count(*) from repetitions where habit is null'),
            1,
            reason: 'persistence.migration-v22#1 — null habit present before');

        migrateTo(db, 22);

        expect(
            queryCount(
                db, 'select count(*) from repetitions where habit is null'),
            0,
            reason: 'persistence.migration-v22#1 — null habits are deleted');
      });

      test('removes duplicate repetitions, keeping the first', () {
        final db = openFixtureCopy('021.db');
        db.run('insert into repetitions(habit, timestamp, value)'
            'values (0, 100, 2)');
        db.run('insert into repetitions(habit, timestamp, value)'
            'values (0, 100, 5)');
        db.run('insert into repetitions(habit, timestamp, value)'
            'values (0, 100, 10)');
        expect(
            queryCount(db,
                'select count(*) from repetitions where timestamp=100 and '
                'habit=0'),
            3,
            reason: 'persistence.migration-v22#1 — three duplicates before');

        migrateTo(db, 22);

        expect(
            queryCount(db,
                'select count(*) from repetitions where timestamp=100 and '
                'habit=0'),
            1,
            reason: 'persistence.migration-v22#1 — duplicates are deleted');
        expect(
            queryIntOrNull(db,
                'select value from repetitions where timestamp=100 and '
                'habit=0'),
            2,
            reason: 'persistence.migration-v22#2 — the first-inserted value '
                'wins');
      });

      test('rejects new rows that break the rebuilt constraints', () {
        final db = openFixtureCopy('021.db');
        migrateTo(db, 22);

        expect(
          errorMessage(() => db.run('insert into Repetitions(habit, timestamp, '
              'value) values (99999, 100, 2)')),
          contains('constraint'),
          reason: 'persistence.migration-v22#7 — invalid habit reference',
        );
        expect(
          errorMessage(() =>
              db.run('insert into Repetitions(habit, value) values (0, 2)')),
          contains('constraint'),
          reason: 'persistence.migration-v22#8 — missing timestamp',
        );
        expect(
          errorMessage(() =>
              db.run('insert into Repetitions(timestamp, value) values (5, 2)')),
          contains('constraint'),
          reason: 'persistence.migration-v22#8 — missing habit',
        );
        db.run('insert into repetitions(habit, timestamp, value)'
            'values (0, 100, 2)');
        expect(
          errorMessage(() => db.run(
              'insert into repetitions(habit, timestamp, value)'
              'values (0, 100, 5)')),
          contains('constraint'),
          reason: 'persistence.migration-v22#8 — duplicate (habit, timestamp)',
        );
      });
    });
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v23 — description split into question
  // -------------------------------------------------------------------------
  group('migration 23', () {
    test('executes three statements in order', () {
      expect(
        parseMigration(23),
        [
          'alter table Habits add column question text',
          'update Habits set question = description',
          'update Habits set description = ""',
        ],
        reason: 'persistence.migration-v23#1 — add question, copy description '
            'into it, then blank description, in that order',
      );
    });

    test('moves description into question, preserving NULL', () {
      final db = dbAt(22);
      db.run("insert into Habits(name, description) "
          "values ('Work out', 'Did you work out?')");
      db.run("insert into Habits(name) values ('Test')");
      final descriptions = <String?>[];
      db.query('select description from Habits', const [],
          (stmt) => descriptions.add(stmt.getTextOrNull(0)));
      expect(descriptions, ['Did you work out?', null],
          reason: 'persistence.migration-v23#2 — one habit has a description, '
              'the other has NULL');

      migrateTo(db, 23);

      final questions = <String?>[];
      db.query('select question from Habits', const [],
          (stmt) => questions.add(stmt.getTextOrNull(0)));
      expect(questions, descriptions,
          reason: "persistence.migration-v23#2 — every habit's question equals "
              'its previous description, including NULL');
    });

    test('blanks description to the empty string, not NULL', () {
      final db = dbAt(22);
      db.run("insert into Habits(name, description) values ('a', 'Some text')");
      db.run("insert into Habits(name) values ('b')");

      migrateTo(db, 23);

      final descriptions = <String?>[];
      final types = <String?>[];
      db.query('select description, typeof(description) from Habits', const [],
          (stmt) {
        descriptions.add(stmt.getTextOrNull(0));
        types.add(stmt.getTextOrNull(1));
      });
      expect(descriptions, ['', ''],
          reason: 'persistence.migration-v23#3 — every description becomes the '
              'empty string');
      expect(types, ['text', 'text'],
          reason: 'persistence.migration-v23#3 — "" is parsed as an '
              'empty-string literal, so the value is text and not NULL');
      expect(descriptions, isNot(contains('""')),
          reason: 'persistence.migration-v23#3 — the value is not the '
              'two-character string ""');
    });

    test('the question column can be selected on every row', () {
      final db = dbAt(22);
      for (final name in ['a', 'b', 'c']) {
        db.run("insert into Habits(name) values ('$name')");
      }
      migrateTo(db, 23);

      var rows = 0;
      db.query('select question from Habits', const [], (stmt) {
        stmt.getTextOrNull(0);
        rows++;
      });
      expect(rows, 3,
          reason: 'persistence.migration-v23#4 — selecting question succeeds '
              'on every row');
      expect(tableInfo(db, 'Habits').map((c) => c.name), contains('question'),
          reason: 'persistence.migration-v23#4 — the question column exists');
    });

    // Ports of Version23Test.kt, driven off the legacy 022.db fixture.
    group('legacy 022.db fixture', () {
      test('creates the question column', () {
        final db = openFixtureCopy('022.db');
        expect(db.getVersion(), 22,
            reason: 'persistence.migration-v23#4 — the fixture is a version 22 '
                'database');
        migrateTo(db, 23);
        var rows = 0;
        db.query('select question from Habits', const [], (_) => rows++);
        expect(rows, greaterThan(0),
            reason: 'persistence.migration-v23#4 — select question from Habits '
                'succeeds');
      });

      test('moves description to the question column', () {
        final db = openFixtureCopy('022.db');
        final descriptions = <String?>[];
        db.query('select description from Habits', const [],
            (stmt) => descriptions.add(stmt.getTextOrNull(0)));

        migrateTo(db, 23);

        final questions = <String?>[];
        db.query('select question from Habits', const [],
            (stmt) => questions.add(stmt.getTextOrNull(0)));
        expect(questions, descriptions,
            reason: 'persistence.migration-v23#2 — question holds the previous '
                'description of each habit');
        expect(questions, contains('Did you work out?'),
            reason: 'persistence.migration-v23#2 — the fixture description '
                'survives in question');
      });

      test('sets every description to the empty string', () {
        final db = openFixtureCopy('022.db');
        migrateTo(db, 23);
        db.query('select description from Habits', const [], (stmt) {
          expect(stmt.getTextOrNull(0), '',
              reason: 'persistence.migration-v23#3 — description is "" for '
                  'every row');
        });
      });
    });
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v24 — uuid backfill
  // -------------------------------------------------------------------------
  group('migration 24', () {
    test('executes two statements', () {
      expect(
        parseMigration(24),
        [
          'alter table habits add column uuid text',
          'update habits set uuid = lower(hex(randomblob(16) || id))',
        ],
        reason: 'persistence.migration-v24#1 — add the uuid column, then '
            'backfill it with lower(hex(randomblob(16) || id))',
      );
    });

    test('backfills lowercase hex without dashes', () {
      final db = dbAt(23);
      db.run("insert into Habits(name) values ('Wake up')");

      migrateTo(db, 24);

      final uuid = queryTextOrNull(db, 'select uuid from Habits')!;
      expect(uuid, matches(RegExp(r'^[0-9a-f]+$')),
          reason: 'persistence.migration-v24#2 — the uuid is lowercase '
              'hexadecimal');
      expect(uuid, isNot(contains('-')),
          reason: 'persistence.migration-v24#2 — there are no dashes, so it is '
              'not an RFC-4122 UUID');
      expect(uuid.length, isNot(32),
          reason: 'persistence.migration-v24#2 — it is not a dashless RFC-4122 '
              'uuid either: the hex of the id is appended to the 16 random '
              'bytes');
    });

    test('length is 32 + 2 * the number of digits in the id', () {
      final db = dbAt(23);
      db.run("insert into Habits(id, name) values (7, 'Seven')");
      db.run("insert into Habits(id, name) values (42, 'Forty two')");

      migrateTo(db, 24);

      expect(queryTextOrNull(db, 'select uuid from Habits where id = 7')!.length,
          34,
          reason: 'persistence.migration-v24#3 — a habit with id 7 gets a '
              '34-character uuid');
      expect(
          queryTextOrNull(db, 'select uuid from Habits where id = 42')!.length,
          36,
          reason: 'persistence.migration-v24#3 — a habit with id 42 gets a '
              '36-character uuid');
      expect(
          queryTextOrNull(db, 'select uuid from Habits where id = 7')!
              .endsWith('37'),
          isTrue,
          reason: 'persistence.migration-v24#3 — the decimal text of the id is '
              "concatenated as bytes, so id 7 ends with hex('7') = 37");
    });

    test('uuids are unique in practice but not constrained to be', () {
      final db = dbAt(23);
      for (var i = 0; i < 50; i++) {
        db.run("insert into Habits(name) values ('h$i')");
      }

      migrateTo(db, 24);

      final uuids = queryTextColumn(db, 'select uuid from Habits');
      expect(uuids.length, 50,
          reason: 'persistence.migration-v24#4 — every row gets a uuid');
      expect(uuids.toSet().length, 50,
          reason: 'persistence.migration-v24#4 — 16 random bytes plus the '
              'unique id make the uuid unique in practice');
      expect(
        errorMessage(() => db.run("update habits set uuid = 'duplicated'")),
        isNull,
        reason: 'persistence.migration-v24#4 — there is no UNIQUE constraint '
            'on the column, so every row can hold the same value',
      );
      expect(
          queryCount(
              db, "select count(*) from habits where uuid = 'duplicated'"),
          50,
          reason: 'persistence.migration-v24#4 — all 50 rows now share one '
              'uuid');
    });

    test('rows inserted after the migration get no uuid from SQL', () {
      final db = dbAt(23);
      db.run("insert into Habits(name) values ('before')");

      migrateTo(db, 24);

      db.run("insert into Habits(name) values ('after')");
      expect(
          queryTextOrNull(
              db, "select uuid from Habits where name = 'before'"),
          isNotNull,
          reason: 'persistence.migration-v24#5 — the backfill covered the row '
              'that already existed');
      expect(
          queryTextOrNull(db, "select uuid from Habits where name = 'after'"),
          isNull,
          reason: 'persistence.migration-v24#5 — rows inserted after the '
              'migration do not get a uuid from SQL: there is no default and '
              'no trigger, so the column is SQL NULL unless the caller binds a '
              'value');
      expect(
          {for (final c in tableInfo(db, 'Habits')) c.name: c}['uuid']!
              .defaultValue,
          isNull,
          reason: 'persistence.migration-v24#5 — the uuid column has no '
              'default');
    });
  });

  // -------------------------------------------------------------------------
  // persistence.migration-v25 — repetition notes
  // -------------------------------------------------------------------------
  group('migration 25', () {
    test('executes exactly one statement', () {
      final commands = parseMigration(25);
      expect(commands.length, 1,
          reason: 'persistence.migration-v25#1 — exactly one statement');
      expect(commands.single, 'alter table Repetitions add column notes text',
          reason: 'persistence.migration-v25#1 — alter table Repetitions add '
              'column notes text');
    });

    test('adds a nullable notes column with no default', () {
      final db = dbAt(24);
      final habitId = () {
        db.run("insert into Habits(name) values ('Wake up')");
        return queryCount(db, 'select max(id) from Habits');
      }();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 2)');

      migrateTo(db, 25);

      final notes = {for (final c in tableInfo(db, 'Repetitions')) c.name: c}[
          'notes']!;
      expect(notes.type.toLowerCase(), 'text',
          reason: 'persistence.migration-v25#2 — notes is a text column');
      expect(notes.notNull, isFalse,
          reason: 'persistence.migration-v25#2 — notes is nullable');
      expect(notes.defaultValue, isNull,
          reason: 'persistence.migration-v25#2 — notes has no default');
      expect(queryTextOrNull(db, 'select notes from Repetitions'), isNull,
          reason: 'persistence.migration-v25#2 — every pre-existing repetition '
              'has notes = NULL');
      expect(
          queryTextOrNull(db, 'select typeof(notes) from Repetitions'), 'null',
          reason: 'persistence.migration-v25#2 — the stored value really is '
              'SQL NULL');
    });

    test('25 is the highest migration and the database version', () {
      expect(migrationSql.keys.reduce((a, b) => a > b ? a : b), 25,
          reason: 'persistence.migration-v25#4 — 25 is the highest migration '
              'script shipped');
      expect(databaseVersion, 25,
          reason: 'persistence.migration-v25#4 — DATABASE_VERSION equals 25');
      final db = dbAt(25);
      expect(db.getVersion(), 25,
          reason: 'persistence.migration-v25#4 — after 25.sql runs, '
              'user_version is 25');
      expect(migrationSql.containsKey(26), isFalse,
          reason: 'persistence.migration-v25#4 — there is no migration beyond '
              '25');
    });
  });

  test('#6 foreign key enforcement survives reopening a migrated database', () {
    final file = File(
        '${Directory.systemTemp.createTempSync('uhabits_fk').path}/uhabits.db');
    addTearDown(() => file.parent.deleteSync(recursive: true));

    const opener = Sqlite3DatabaseOpener();
    file.writeAsBytesSync(const <int>[]);
    final creating = opener.open(file.path);
    creating.setVersion(8);
    creating.migrateTo(25, (v) => migrationSql[v]!);
    creating.close();

    // Reopening skips migrateTo entirely, so the pragma inside 22.sql never
    // runs again. Enforcement must still be on.
    final reopened = opener.open(file.path);
    addTearDown(reopened.close);
    expect(reopened.queryInt('pragma foreign_keys'), 1,
        reason: 'persistence.migration-v22#6');

    reopened.run('insert into Habits(name, position) values (?, ?)', (stmt) {
      stmt
        ..bindText(1, 'Meditate')
        ..bindInt(2, 0);
    });
    expect(
      () => reopened.run(
          'insert into Repetitions(habit, timestamp, value) values (?, ?, ?)',
          (stmt) {
        stmt
          ..bindInt(1, 9999)
          ..bindLong(2, 0)
          ..bindInt(3, 2);
      }),
      throwsA(anything),
      reason: 'persistence.migration-v22#6',
    );
  });
}
