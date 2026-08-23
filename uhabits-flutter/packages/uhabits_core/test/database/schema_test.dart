/// Migration runner and the physical shape of the Habits / Repetitions tables.
///
/// Ported from
/// `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/MigrationTest.kt`,
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/HabitRepositoryTest.kt`,
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/EntryRepositoryTest.kt`
/// and
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/migrations/Version22Test.kt`,
/// against `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Database.kt`
/// (`migrateTo`), `org/isoron/uhabits/core/Constants.kt` and the migration
/// scripts in `uhabits-core/assets/main/migrations/`.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sql_parser.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

/// One row of `pragma table_info(<table>)`.
class ColumnInfo {
  const ColumnInfo({
    required this.cid,
    required this.name,
    required this.type,
    required this.notNull,
    required this.defaultValue,
    required this.primaryKey,
  });

  final int cid;
  final String name;
  final String type;
  final bool notNull;
  final String? defaultValue;
  final int primaryKey;

  @override
  String toString() => 'ColumnInfo($cid, $name, $type, notNull: $notNull, '
      'default: $defaultValue, pk: $primaryKey)';
}

/// Reads `pragma table_info(<table>)` in physical column order.
List<ColumnInfo> tableInfo(Database db, String table) {
  final stmt = db.prepareStatement('pragma table_info($table)');
  final columns = <ColumnInfo>[];
  while (stmt.step() == StepResult.row) {
    columns.add(
      ColumnInfo(
        cid: stmt.getInt(0),
        name: stmt.getText(1),
        type: stmt.getText(2),
        notNull: stmt.getInt(3) != 0,
        defaultValue: stmt.getTextOrNull(4),
        primaryKey: stmt.getInt(5),
      ),
    );
  }
  stmt.finalizeStatement();
  return columns;
}

ColumnInfo columnNamed(List<ColumnInfo> columns, String name) =>
    columns.firstWhere((c) => c.name == name);

/// Collects the values of column [column] of every row produced by [sql].
List<Object?> selectColumn(Database db, String sql, {int column = 0}) {
  final stmt = db.prepareStatement(sql);
  final values = <Object?>[];
  while (stmt.step() == StepResult.row) {
    values.add(stmt.getTextOrNull(column));
  }
  stmt.finalizeStatement();
  return values;
}

/// Collects one row of `pragma foreign_key_list(<table>)` as raw text.
///
/// Columns are: id, seq, table, from, to, on_update, on_delete, match.
List<String?> foreignKeyList(Database db, String table) {
  final stmt = db.prepareStatement('pragma foreign_key_list($table)');
  final rows = <List<String?>>[];
  while (stmt.step() == StepResult.row) {
    rows.add([for (var i = 0; i < 8; i++) stmt.getTextOrNull(i)]);
  }
  stmt.finalizeStatement();
  return rows.single;
}

/// The Kotlin tests assert `assertContains(exception.message!!, "constraint")`;
/// this is the same check.
final Matcher throwsConstraintViolation = throwsA(
  predicate<Object>(
    (e) => e.toString().toLowerCase().contains('constraint'),
    'an error mentioning "constraint"',
  ),
);

/// Locates `uhabits-core/assets/main/migrations`, the Kotlin resource directory
/// whose files `migrations.g.dart` is generated from, by walking up from the
/// current directory. Returns null outside the monorepo.
/// The Android module's build script, walked up to from the test's cwd the
/// same way [findKotlinMigrationsDir] finds the asset folder.
File? findKotlinAndroidBuildFile() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 10; i++) {
    final candidate = File('${dir.path}/uhabits-android/build.gradle.kts');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

Directory? findKotlinMigrationsDir() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 10; i++) {
    final candidate =
        Directory('${dir.path}/uhabits-core/assets/main/migrations');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

void main() {
  group('persistence.migration-runner', () {
    test('DATABASE_VERSION is 25 and DATABASE_FILENAME is uhabits.db', () {
      expect(databaseVersion, 25,
          reason: 'persistence.migration-runner#1 — DATABASE_VERSION = 25');
      expect(databaseFilename, 'uhabits.db',
          reason: 'persistence.migration-runner#1 — '
              'DATABASE_FILENAME = "uhabits.db"');

      final db = openMigratedDatabase();
      addTearDown(db.close);
      expect(db.getVersion(), databaseVersion,
          reason: 'persistence.migration-runner#1 — a database migrated to '
              'DATABASE_VERSION reports user_version 25');
    });

    test('getVersion reads PRAGMA user_version; setVersion interpolates it',
        () {
      final db = openMemoryDatabase();
      addTearDown(db.close);

      db.setVersion(0);
      expect(db.getVersion(), 0,
          reason: 'persistence.migration-runner#2 — getVersion() executes '
              'PRAGMA user_version and reads column 0 as an Int');
      db.setVersion(25);
      expect(db.getVersion(), 25,
          reason: 'persistence.migration-runner#2 — setVersion(v) writes '
              'user_version');
      expect(db.queryInt('PRAGMA user_version'), 25,
          reason: 'persistence.migration-runner#2 — getVersion() is nothing '
              'but queryInt("PRAGMA user_version"), column 0');

      // The value must be interpolated into the SQL text: SQLite does not
      // accept a bound parameter in a PRAGMA assignment at all, so the literal
      // string `PRAGMA user_version = $v` is the only thing that can work.
      expect(
        () => db.run('PRAGMA user_version = ?', (stmt) => stmt.bindInt(1, 7)),
        throwsA(anything),
        reason: 'persistence.migration-runner#2 — the version is interpolated '
            'into the SQL, not bound; a bound PRAGMA fails to even compile',
      );
      expect(db.getVersion(), 25,
          reason: 'persistence.migration-runner#2 — the failed bound PRAGMA '
              'left user_version untouched');
    });

    test('migrateTo is a no-op when already at or past the target version', () {
      final db = openMigratedDatabase();
      addTearDown(db.close);
      var loadCalls = 0;
      var parseCalls = 0;

      String loader(int v) {
        loadCalls++;
        return 'create table should_not_exist_$v(a integer)';
      }

      List<String> recordingParse(String script) {
        parseCalls++;
        return SQLParser.parse(script);
      }

      // Equal to the current version.
      db.migrateTo(25, loader, parse: recordingParse);
      expect(db.getVersion(), 25,
          reason: 'persistence.migration-runner#8 — migrateTo(v) where v is '
              'the current version leaves user_version unchanged');
      expect(loadCalls, 0,
          reason: 'persistence.migration-runner#8 — migrateTo(v) at the '
              'current version executes no SQL: no migration is even loaded');
      expect(parseCalls, 0,
          reason: 'persistence.migration-runner#3 — getVersion() >= '
              'targetVersion returns immediately without executing anything');

      // Below the current version.
      db.migrateTo(10, loader, parse: recordingParse);
      expect(db.getVersion(), 25,
          reason: 'persistence.migration-runner#3 — migrateTo is idempotent: '
              'a lower target never downgrades user_version');
      expect(loadCalls, 0,
          reason: 'persistence.migration-runner#3 — getVersion() >= '
              'targetVersion returns before loading any migration SQL');
      expect(
        selectColumn(
          db,
          "select name from sqlite_master where name like 'should_not_exist%'",
        ),
        isEmpty,
        reason: 'persistence.migration-runner#3 — nothing was executed, so no '
            'statement from the loader reached the database',
      );
    });

    test('migrateTo applies every version in ascending order, splitting each '
        'script and stamping user_version afterwards', () {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      db.setVersion(0);

      final loadedVersions = <int>[];
      final versionsSeenWhileLoading = <int>[];
      final parsedScripts = <String>[];

      db.migrateTo(
        3,
        (v) {
          loadedVersions.add(v);
          versionsSeenWhileLoading.add(db.getVersion());
          return 'create table t$v(a integer);\n'
              'insert into t$v(a) values (${v * 10});\n'
              'insert into t$v(a) values (${v * 10 + 1});\n';
        },
        parse: (script) {
          parsedScripts.add(script);
          return SQLParser.parse(script);
        },
      );

      expect(loadedVersions, [1, 2, 3],
          reason: 'persistence.migration-runner#4 — for v from currentVersion '
              '+ 1 up to and including targetVersion, in ascending order');
      expect(parsedScripts.length, 3,
          reason: 'persistence.migration-runner#4 — each migration script is '
              'split with SQLParser.parse');
      expect(parsedScripts.first, contains('create table t1'),
          reason: 'persistence.migration-runner#4 — the text handed to the '
              'parser is exactly what loadMigrationSQL returned');
      expect(selectColumn(db, 'select a from t1'), ['10', '11'],
          reason: 'persistence.migration-runner#4 — each resulting statement '
              'is executed in order with Database.run');
      expect(selectColumn(db, 'select a from t3'), ['30', '31'],
          reason: 'persistence.migration-runner#4 — every version of the range '
              'is applied, not just the first');
      expect(versionsSeenWhileLoading, [0, 1, 2],
          reason: 'persistence.migration-runner#4 — setVersion(v) is called '
              'after the script for v has run, so while loading v the database '
              'still reports v - 1');
      expect(db.getVersion(), 3,
          reason: 'persistence.migration-runner#4 — user_version ends at the '
              'target version');
    });

    test('an interrupted upgrade resumes at the first unapplied version', () {
      final db = openMemoryDatabase();
      addTearDown(db.close);
      db.setVersion(8);

      expect(
        () => db.migrateTo(databaseVersion, (v) {
          if (v == 15) throw StateError('interrupted');
          return migrationSql[v]!;
        }),
        throwsA(isA<StateError>()),
        reason: 'persistence.migration-runner#5 — an upgrade can be '
            'interrupted part way through the range',
      );
      expect(db.getVersion(), 14,
          reason: 'persistence.migration-runner#5 — user_version is written '
              'after each individual migration completes, so it stands at the '
              'last version that fully applied');

      final resumedVersions = <int>[];
      db.migrateTo(databaseVersion, (v) {
        resumedVersions.add(v);
        return migrationSql[v]!;
      });
      expect(resumedVersions.first, 15,
          reason: 'persistence.migration-runner#5 — the next attempt resumes '
              'at the first unapplied version');
      expect(resumedVersions, List<int>.generate(11, (i) => 15 + i),
          reason: 'persistence.migration-runner#5 — and applies 15..25, never '
              'replaying 09..14');
      expect(db.getVersion(), databaseVersion,
          reason: 'persistence.migration-runner#5 — the resumed upgrade '
              'finishes the range');
      expect(tableInfo(db, 'Habits').length, 18,
          reason: 'persistence.migration-runner#5 — the resumed database has '
              'the same schema as an uninterrupted one');
    });

    test('migration scripts are the zero-padded migrations/NN.sql resources',
        () {
      // migrations.g.dart is a generated, verbatim copy of the Kotlin resource
      // directory; the Dart port addresses the scripts by integer version
      // instead of by asset path, so the naming rule is checked against the
      // resources the generator copied.
      final dir = findKotlinMigrationsDir();
      expect(dir, isNotNull,
          reason: 'persistence.migration-runner#6 — the migration resources '
              'live in uhabits-core/assets/main/migrations');

      final names = dir!
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.sql'))
          .toList()
        ..sort();
      final expectedNames = [
        for (var v = 9; v <= databaseVersion; v++)
          '${v.toString().padLeft(2, '0')}.sql',
      ];
      expect(names, expectedNames,
          reason: 'persistence.migration-runner#6 — resources are named with a '
              'zero-padded two-digit version, "%02d.sql": migrations/09.sql '
              'through migrations/25.sql');
      expect(names, contains('09.sql'),
          reason: 'persistence.migration-runner#6 — version 9 is padded to '
              '"09.sql", never "9.sql"');

      for (final v in migrationSql.keys) {
        final file =
            File('${dir.path}/${v.toString().padLeft(2, '0')}.sql');
        expect(file.existsSync(), isTrue,
            reason: 'persistence.migration-runner#6 — migrationSql[$v] is the '
                'resource loaded from migrations/'
                '${v.toString().padLeft(2, '0')}.sql');
        // The compiled script matches the resource except for one documented
        // rewrite: SQLite's double-quoted empty string becomes the standard
        // single-quoted one, because the build bundled on iOS and Android
        // rejects `""` in DML. See docs/parity/DEVIATIONS.md.
        expect(file.readAsStringSync().replaceAll('""', "''"), migrationSql[v],
            reason: 'persistence.migration-runner#6 — the compiled script for '
                'version \$v is that resource, modulo the quote rewrite');
      }
    });

    test('migrations exist only for 09..25; a new database stamps 8 first', () {
      expect(migrationSql.keys.toList()..sort(),
          List<int>.generate(17, (i) => 9 + i),
          reason: 'persistence.migration-runner#7 — migration files exist only '
              'for versions 09 through 25 inclusive');
      for (var v = 0; v <= 8; v++) {
        expect(migrationSql.containsKey(v), isFalse,
            reason: 'persistence.migration-runner#7 — there is no file for '
                'versions 0-8 (missing: $v)');
      }

      // A brand-new database: stamp 8, then migrate. This is exactly what
      // TestDatabaseHelper.createEmptyDatabase does in Kotlin.
      final db = openMemoryDatabase();
      addTearDown(db.close);
      expect(selectColumn(db, "select name from sqlite_master where type='table'"),
          isEmpty,
          reason: 'persistence.migration-runner#7 — a brand-new database has '
              'no tables of its own');
      db.setVersion(8);
      db.migrateTo(9, (v) => migrationSql[v]!);
      expect(db.getVersion(), 9,
          reason: 'persistence.migration-runner#7 — stamping user_version = 8 '
              'makes migration 09 the first one applied');
      expect(tableInfo(db, 'Habits'), isNotEmpty,
          reason: 'persistence.migration-runner#7 — migration 09 is the '
              'effective CREATE TABLE script');
      expect(tableInfo(db, 'Repetitions'), isNotEmpty,
          reason: 'persistence.migration-runner#7 — migration 09 creates '
              'Repetitions as well');

      db.migrateTo(databaseVersion, (v) => migrationSql[v]!);
      expect(db.getVersion(), 25,
          reason: 'persistence.migration-runner#7 — and the same database then '
              'migrates all the way to 25');
    });

    test('the scripts ship with the app: an assets source dir upstream, a '
        'compiled-in map here', () {
      // Upstream half: the Android module adds the shared core's asset folder
      // as a second assets source dir, which is what makes the resource path
      // `migrations/NN.sql` resolvable through `context.assets.open`.
      final gradle = findKotlinAndroidBuildFile();
      expect(gradle, isNotNull,
          reason: 'persistence.migration-runner#9 — the claim is about '
              'uhabits-android/build.gradle.kts');
      expect(
        gradle!.readAsStringSync(),
        contains('assets.srcDirs("src/main/assets", "../uhabits-core/assets/main")'),
        reason: 'persistence.migration-runner#9 — uhabits-android/'
            'build.gradle.kts adds "../uhabits-core/assets/main" as an assets '
            'source dir',
      );

      final dir = findKotlinMigrationsDir();
      expect(dir, isNotNull,
          reason: 'persistence.migration-runner#9 — that source dir is the '
              'folder holding migrations/');
      final asset = File('${dir!.path}/25.sql');
      expect(asset.existsSync(), isTrue,
          reason: 'persistence.migration-runner#9 — so '
              'context.assets.open("migrations/25.sql") resolves');

      // Port half: Dart has no asset stream in the core, so the generator
      // copies the same folder into migrations.g.dart and the scripts are
      // compiled into the library instead of bundled beside it.
      expect(
        migrationSql[databaseVersion],
        asset.readAsStringSync().replaceAll('""', "''"),
        reason: 'persistence.migration-runner#9 — the port ships the very same '
            'script for version 25, compiled in rather than opened as an asset',
      );
      expect(
        migrationSql.length,
        databaseVersion - 8,
        reason: 'persistence.migration-runner#9 — and every other script the '
            'assets folder holds ships the same way, so no version of the '
            'migration path depends on an asset lookup',
      );
    });
  });

  group('persistence.schema-habits', () {
    late Database db;
    late List<ColumnInfo> columns;

    setUp(() {
      db = openMigratedDatabase();
      columns = tableInfo(db, 'Habits');
    });

    tearDown(() => db.close());

    test('has exactly 18 columns in the documented physical order', () {
      expect(columns.length, 18,
          reason: 'persistence.schema-habits#1 — the final (user_version = 25) '
              'schema of table Habits has exactly 18 columns');
      expect(columns.map((c) => c.name).toList(), [
        'id',
        'archived',
        'color',
        'description',
        'freq_den',
        'freq_num',
        'highlight',
        'name',
        'position',
        'reminder_hour',
        'reminder_min',
        'reminder_days',
        'type',
        'target_type',
        'target_value',
        'unit',
        'question',
        'uuid',
      ],
          reason: 'persistence.schema-habits#1 — in this physical order: id, '
              'archived, color, description, freq_den, freq_num, highlight, '
              'name, position, reminder_hour, reminder_min, reminder_days, '
              'type, target_type, target_value, unit, question, uuid');
      expect(columns.map((c) => c.cid).toList(), List<int>.generate(18, (i) => i),
          reason: 'persistence.schema-habits#1 — the order asserted above is '
              'the physical column order reported by pragma table_info');
    });

    test('id is an autoincrement integer primary key that never reuses ids',
        () {
      final id = columnNamed(columns, 'id');
      expect(id.type, 'INTEGER',
          reason: 'persistence.schema-habits#2 — id is `integer primary key '
              'autoincrement`');
      expect(id.primaryKey, 1,
          reason: 'persistence.schema-habits#2 — id is the primary key');
      expect(
        selectColumn(db, "select sql from sqlite_master where name = 'Habits'")
            .single
            .toString()
            .toLowerCase(),
        contains('autoincrement'),
        reason: 'persistence.schema-habits#2 — the column is declared '
            'AUTOINCREMENT, not merely a rowid alias',
      );

      db.run("insert into Habits(name) values ('first')");
      expect(db.queryLong('select last_insert_rowid()'), 1,
          reason: 'persistence.schema-habits#2 — the first inserted habit gets '
              'id = 1');
      expect(
        selectColumn(db, "select seq from sqlite_sequence where name='Habits'"),
        ['1'],
        reason: 'persistence.schema-habits#2 — with AUTOINCREMENT SQLite keeps '
            'a sqlite_sequence row',
      );

      db.run('delete from Habits where id = 1');
      db.run("insert into Habits(name) values ('second')");
      expect(db.queryLong('select last_insert_rowid()'), 2,
          reason: 'persistence.schema-habits#2 — SQLite never reuses a deleted '
              'id');
    });

    test('the migration 09 columns are nullable with no default', () {
      const createdByMigration09 = [
        'archived',
        'color',
        'description',
        'freq_den',
        'freq_num',
        'highlight',
        'name',
        'position',
        'reminder_hour',
        'reminder_min',
      ];
      const declaredTypes = {
        'archived': 'INTEGER',
        'color': 'INTEGER',
        'description': 'TEXT',
        'freq_den': 'INTEGER',
        'freq_num': 'INTEGER',
        'highlight': 'INTEGER',
        'name': 'TEXT',
        'position': 'INTEGER',
        'reminder_hour': 'INTEGER',
        'reminder_min': 'INTEGER',
      };
      for (final name in createdByMigration09) {
        final column = columnNamed(columns, name);
        expect(column.type, declaredTypes[name],
            reason: 'persistence.schema-habits#3 — $name is declared '
                '${declaredTypes[name]!.toLowerCase()}');
        expect(column.notNull, isFalse,
            reason: 'persistence.schema-habits#3 — columns created in '
                'migration 09 are all nullable ($name)');
        expect(column.defaultValue, isNull,
            reason: 'persistence.schema-habits#3 — columns created in '
                'migration 09 have no default ($name)');
      }

      db.run('insert into Habits(id) values (7)');
      expect(
        selectColumn(db, 'select name from Habits where id = 7'),
        [null],
        reason: 'persistence.schema-habits#3 — an unset migration-09 column '
            'really does store NULL',
      );
    });

    test('reminder_days is not null with default 127', () {
      final column = columnNamed(columns, 'reminder_days');
      expect(column.type, 'INTEGER',
          reason: 'persistence.schema-habits#4 — reminder_days integer');
      expect(column.notNull, isTrue,
          reason: 'persistence.schema-habits#4 — reminder_days is not null');
      expect(column.defaultValue, '127',
          reason: 'persistence.schema-habits#4 — reminder_days defaults to '
              '127 (added by migration 11)');
      expect(int.parse(column.defaultValue!), 0x7f,
          reason: 'persistence.schema-habits#4 — 127 = 0b1111111 = all seven '
              'weekdays enabled');

      db.run("insert into Habits(name) values ('defaults')");
      expect(selectColumn(db, 'select reminder_days from Habits'), ['127'],
          reason: 'persistence.schema-habits#4 — a row inserted without '
              'reminder_days gets 127');
    });

    test('type is not null with default 0', () {
      final column = columnNamed(columns, 'type');
      expect(column.type, 'INTEGER',
          reason: 'persistence.schema-habits#5 — type integer');
      expect(column.notNull, isTrue,
          reason: 'persistence.schema-habits#5 — type is not null '
              '(migration 16)');
      expect(column.defaultValue, '0',
          reason: 'persistence.schema-habits#5 — type defaults to 0 = boolean '
              'habit (1 = numerical habit)');

      db.run("insert into Habits(name) values ('defaults')");
      expect(selectColumn(db, 'select type from Habits'), ['0'],
          reason: 'persistence.schema-habits#5 — a row inserted without a type '
              'is a boolean habit');
    });

    test('migration 18 added target_type, target_value and unit in that order',
        () {
      expect(
        columns.map((c) => c.name).skip(13).take(3).toList(),
        ['target_type', 'target_value', 'unit'],
        reason: 'persistence.schema-habits#6 — migration 18 added target_type, '
            'target_value and unit, in that order',
      );

      final targetType = columnNamed(columns, 'target_type');
      expect(targetType.type, 'INTEGER',
          reason: 'persistence.schema-habits#6 — target_type integer');
      expect(targetType.notNull, isTrue,
          reason: 'persistence.schema-habits#6 — target_type is not null');
      expect(targetType.defaultValue, '0',
          reason: 'persistence.schema-habits#6 — target_type default 0');

      final targetValue = columnNamed(columns, 'target_value');
      expect(targetValue.type, 'REAL',
          reason: 'persistence.schema-habits#6 — target_value real');
      expect(targetValue.notNull, isTrue,
          reason: 'persistence.schema-habits#6 — target_value is not null');
      expect(targetValue.defaultValue, '0',
          reason: 'persistence.schema-habits#6 — target_value default 0');

      final unit = columnNamed(columns, 'unit');
      expect(unit.type, 'TEXT',
          reason: 'persistence.schema-habits#6 — unit text');
      expect(unit.notNull, isTrue,
          reason: 'persistence.schema-habits#6 — unit is not null');
      // Migration 18 writes `default ''`; SQLite keeps the literal verbatim
      // in the schema and, because it is a string rather than an identifier,
      // falls back to reading it as the string constant.
      expect(unit.defaultValue, "''",
          reason: "persistence.schema-habits#6 — unit default '' (spelled "
              '`default ""` in migration 18)');

      db.run("insert into Habits(name) values ('defaults')");
      expect(
        selectColumn(
            db, 'select target_type, target_value, unit from Habits'),
        ['0'],
        reason: 'persistence.schema-habits#6 — target_type defaults to 0',
      );
      expect(selectColumn(db, 'select target_value from Habits'), ['0.0'],
          reason: 'persistence.schema-habits#6 — target_value defaults to 0');
      expect(selectColumn(db, 'select unit from Habits'), [''],
          reason: 'persistence.schema-habits#6 — unit defaults to the empty '
              'string, not to the two-character text `""`');
    });

    test('question and uuid are nullable with no default', () {
      final question = columnNamed(columns, 'question');
      expect(question.type, 'TEXT',
          reason: 'persistence.schema-habits#7 — question text '
              '(migration 23)');
      expect(question.notNull, isFalse,
          reason: 'persistence.schema-habits#7 — question is nullable');
      expect(question.defaultValue, isNull,
          reason: 'persistence.schema-habits#7 — question has no default');

      final uuid = columnNamed(columns, 'uuid');
      expect(uuid.type, 'TEXT',
          reason: 'persistence.schema-habits#7 — uuid text (migration 24)');
      expect(uuid.notNull, isFalse,
          reason: 'persistence.schema-habits#7 — uuid is nullable');
      expect(uuid.defaultValue, isNull,
          reason: 'persistence.schema-habits#7 — uuid has no default');

      db.run("insert into Habits(name) values ('defaults')");
      expect(selectColumn(db, 'select question from Habits'), [null],
          reason: 'persistence.schema-habits#7 — an unset question stores '
              'NULL');
      expect(selectColumn(db, 'select uuid from Habits'), [null],
          reason: 'persistence.schema-habits#7 — an unset uuid stores NULL');
    });
  });

  group('persistence.schema-repetitions', () {
    late Database db;
    late List<ColumnInfo> columns;

    /// Inserts the habit used as the foreign-key parent, exactly as
    /// EntryRepositoryTest.insertTestHabit does.
    int insertTestHabit() {
      db.run(
        'insert into Habits(name, freq_num, freq_den, color, position, '
        "archived, type) values ('Test', 1, 1, 0, 0, 0, 0)",
      );
      return db.queryLong('select last_insert_rowid()');
    }

    setUp(() {
      db = openMigratedDatabase();
      columns = tableInfo(db, 'Repetitions');
    });

    tearDown(() => db.close());

    test('has the documented final schema', () {
      expect(columns.map((c) => c.name).toList(),
          ['id', 'habit', 'timestamp', 'value', 'notes'],
          reason: 'persistence.schema-repetitions#1 — the final schema of '
              'table Repetitions is id, habit, timestamp, value, notes');

      final id = columnNamed(columns, 'id');
      expect([id.type, id.primaryKey], ['INTEGER', 1],
          reason: 'persistence.schema-repetitions#1 — id integer primary key '
              'autoincrement');
      expect(
        selectColumn(
                db, "select sql from sqlite_master where name = 'Repetitions'")
            .single
            .toString()
            .toLowerCase(),
        contains('autoincrement'),
        reason: 'persistence.schema-repetitions#1 — id is AUTOINCREMENT',
      );

      final habit = columnNamed(columns, 'habit');
      expect([habit.type, habit.notNull], ['INTEGER', true],
          reason: 'persistence.schema-repetitions#1 — habit integer not null');
      final fk = foreignKeyList(db, 'Repetitions');
      expect([fk[2], fk[3], fk[4]], ['habits', 'habit', 'id'],
          reason: 'persistence.schema-repetitions#1 — habit references '
              'habits(id)');

      final timestamp = columnNamed(columns, 'timestamp');
      expect([timestamp.type, timestamp.notNull], ['INTEGER', true],
          reason: 'persistence.schema-repetitions#1 — timestamp integer not '
              'null');

      final value = columnNamed(columns, 'value');
      expect([value.type, value.notNull], ['INTEGER', true],
          reason: 'persistence.schema-repetitions#1 — value integer not null');

      final notes = columnNamed(columns, 'notes');
      expect([notes.type, notes.notNull], ['TEXT', false],
          reason: 'persistence.schema-repetitions#1 — notes text');
    });

    test('notes is nullable with no default and reads back as NULL', () {
      final notes = columnNamed(columns, 'notes');
      expect(notes.notNull, isFalse,
          reason: 'persistence.schema-repetitions#2 — notes is nullable');
      expect(notes.defaultValue, isNull,
          reason: 'persistence.schema-repetitions#2 — notes has no default');

      final habitId = insertTestHabit();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 1000, 2)');

      final stmt = db.prepareStatement(
          'select notes from Repetitions where habit = $habitId');
      expect(stmt.step(), StepResult.row);
      expect(stmt.getTextOrNull(0), isNull,
          reason: 'persistence.schema-repetitions#2 — a row inserted without '
              'notes stores NULL, so readers must not use getText');
      expect(stmt.getTextOrNull(0) ?? '', '',
          reason: 'persistence.schema-repetitions#2 — every reader coerces '
              'NULL to the empty string ""');
      stmt.finalizeStatement();
    });

    test('(habit, timestamp) is unique', () {
      expect(
        selectColumn(
          db,
          "select name from sqlite_master where type = 'index' "
          "and tbl_name = 'Repetitions'",
        ),
        ['idx_repetitions_habit_timestamp'],
        reason: 'persistence.schema-repetitions#3 — an index named '
            'idx_repetitions_habit_timestamp exists on Repetitions',
      );
      final indexColumns = <String?>[];
      final stmt = db
          .prepareStatement('pragma index_info(idx_repetitions_habit_timestamp)');
      while (stmt.step() == StepResult.row) {
        indexColumns.add(stmt.getTextOrNull(2));
      }
      stmt.finalizeStatement();
      expect(indexColumns, ['habit', 'timestamp'],
          reason: 'persistence.schema-repetitions#3 — the index is on '
              '(habit, timestamp)');
      expect(
        selectColumn(
          db,
          "select \"unique\" from pragma_index_list('Repetitions') "
          "where name = 'idx_repetitions_habit_timestamp'",
        ),
        ['1'],
        reason: 'persistence.schema-repetitions#3 — the index is UNIQUE',
      );

      final habitId = insertTestHabit();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 2)');
      expect(
        () => db.run('insert into Repetitions(habit, timestamp, value) '
            'values ($habitId, 100, 5)'),
        throwsConstraintViolation,
        reason: 'persistence.schema-repetitions#3 — inserting a second row '
            'with the same (habit, timestamp) pair fails with a constraint '
            'violation',
      );
    });

    test('foreign keys are enforced against Habits', () {
      expect(db.queryInt('pragma foreign_keys'), 1,
          reason: 'persistence.schema-repetitions#4 — migration 22 executes '
              'pragma foreign_keys=ON');
      expect(
        () => db.run('insert into Repetitions(habit, timestamp, value) '
            'values (99999, 100, 2)'),
        throwsConstraintViolation,
        reason: 'persistence.schema-repetitions#4 — inserting a row whose '
            'habit does not exist in Habits fails with a constraint violation',
      );

      final habitId = insertTestHabit();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 2)');
      expect(db.queryInt('select count(*) from Repetitions'), 1,
          reason: 'persistence.schema-repetitions#4 — a row pointing at an '
              'existing habit is accepted');
    });

    test('habit and timestamp reject NULL', () {
      final habitId = insertTestHabit();
      expect(
        () => db.run(
            'insert into Repetitions(habit, value) values ($habitId, 2)'),
        throwsConstraintViolation,
        reason: 'persistence.schema-repetitions#5 — inserting a row with NULL '
            'timestamp fails with a constraint violation',
      );
      expect(
        () => db.run('insert into Repetitions(timestamp, value) values (5, 2)'),
        throwsConstraintViolation,
        reason: 'persistence.schema-repetitions#5 — inserting a row with NULL '
            'habit fails with a constraint violation',
      );
      expect(db.queryInt('select count(*) from Repetitions'), 0,
          reason: 'persistence.schema-repetitions#5 — neither rejected row was '
              'stored');
    });

    test('timestamp is UTC midnight of the date, in epoch milliseconds', () {
      final habitId = insertTestHabit();
      final dates = [
        LocalDate.ymd(2000, 1, 1),
        LocalDate.ymd(2017, 1, 1),
        LocalDate.ymd(2020, 2, 29),
        LocalDate.ymd(1999, 12, 31),
        LocalDate.ymd(1980, 6, 15),
      ];
      for (final date in dates) {
        expect(date.unixTime, 946684800000 + date.daysSince2000 * 86400000,
            reason: 'persistence.schema-repetitions#6 — timestamp = '
                '946684800000 + daysSince2000 * 86400000');
        db.run('insert into Repetitions(habit, timestamp, value) '
            'values ($habitId, ${date.unixTime}, ${Entry.yesManual})');
      }

      final stored = selectColumn(
              db, 'select timestamp from Repetitions order by timestamp')
          .map((v) => int.parse(v! as String))
          .toList();
      expect(stored, [for (final d in dates) d.unixTime]..sort(),
          reason: 'persistence.schema-repetitions#6 — the column stores the '
              'epoch-millisecond value verbatim');
      expect(
        stored.map((t) => LocalDate.fromUnixTime(t).daysSince2000).toList(),
        [for (final d in dates) d.daysSince2000]..sort(),
        reason: 'persistence.schema-repetitions#6 — the reverse mapping is '
            'LocalDate.fromUnixTime',
      );

      // Time-zone independence: the value is derived from the day number
      // alone, so it never depends on the machine's local offset.
      expect(LocalDate.ymd(2017, 1, 1).unixTime, 1483228800000,
          reason: 'persistence.schema-repetitions#6 — it is time-zone '
              'independent: 2017-01-01 is always 1483228800000');

      // Pre-2000 dates floor toward negative infinity.
      const oneDayBefore2000 = 946684800000 - 86400000;
      expect(LocalDate.fromUnixTime(oneDayBefore2000).daysSince2000, -1,
          reason: 'persistence.schema-repetitions#6 — floors toward negative '
              'infinity for pre-2000 dates');
      expect(LocalDate.fromUnixTime(oneDayBefore2000 + 1).daysSince2000, -1,
          reason: 'persistence.schema-repetitions#6 — days = diff >= 0 ? diff '
              '/ 86400000 : (diff - 86400000 + 1) / 86400000');
      expect(LocalDate.fromUnixTime(946684800000 - 1).daysSince2000, -1,
          reason: 'persistence.schema-repetitions#6 — one millisecond before '
              'the 2000 epoch is still the previous day');
    });

    test('value stores Entry values, or the amount times 1000', () {
      expect(
        [Entry.unknown, Entry.no, Entry.yesAuto, Entry.yesManual, Entry.skip],
        [-1, 0, 1, 2, 3],
        reason: 'persistence.schema-repetitions#7 — UNKNOWN = -1, NO = 0, '
            'YES_AUTO = 1, YES_MANUAL = 2, SKIP = 3',
      );

      final habitId = insertTestHabit();
      const values = [
        Entry.unknown,
        Entry.no,
        Entry.yesAuto,
        Entry.yesManual,
        Entry.skip,
      ];
      for (var i = 0; i < values.length; i++) {
        db.run('insert into Repetitions(habit, timestamp, value) '
            'values ($habitId, ${i * 86400000}, ${values[i]})');
      }
      expect(
        selectColumn(db, 'select value from Repetitions order by timestamp')
            .map((v) => int.parse(v! as String))
            .toList(),
        values,
        reason: 'persistence.schema-repetitions#7 — the value column stores '
            'Entry values verbatim, including the negative UNKNOWN',
      );

      // Numerical habits: the amount is multiplied by 1000.
      const numericalTimestamp = 10 * 86400000;
      final scaled = (80.0 * 1000).toInt();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, $numericalTimestamp, $scaled)');
      expect(
        selectColumn(db,
                'select value from Repetitions where timestamp = $numericalTimestamp')
            .map((v) => int.parse(v! as String))
            .single,
        80000,
        reason: 'persistence.schema-repetitions#7 — for numerical habits it '
            'stores the numeric amount multiplied by 1000 as an integer '
            '(80000 means 80.0)',
      );
    });

    test('deleting a habit does not cascade to its repetitions', () {
      final fk = foreignKeyList(db, 'Repetitions');
      expect(fk[6], 'NO ACTION',
          reason: 'persistence.schema-repetitions#9 — the foreign key declares '
              'no ON DELETE action, so deleting a habit does NOT cascade in '
              'SQL');

      final habitId = insertTestHabit();
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values ($habitId, 100, 2)');
      expect(
        () => db.run('delete from Habits where id = $habitId'),
        throwsConstraintViolation,
        reason: 'persistence.schema-repetitions#9 — with the repetitions still '
            'present, deleting the Habits row is refused rather than cascading',
      );
      expect(db.queryInt('select count(*) from Repetitions'), 1,
          reason: 'persistence.schema-repetitions#9 — the repetitions survive '
              'the refused delete');

      // What the application does instead: delete the repetitions explicitly,
      // then the habit.
      db.run('delete from Repetitions where habit = $habitId');
      db.run('delete from Habits where id = $habitId');
      expect(db.queryInt('select count(*) from Habits'), 0,
          reason: 'persistence.schema-repetitions#9 — the application deletes '
              "the habit's repetitions explicitly before deleting the Habits "
              'row');
      expect(db.queryInt('select count(*) from Repetitions'), 0,
          reason: 'persistence.schema-repetitions#9 — leaving no orphan rows');
    });
  });
}
