import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sql_parser.dart';
import 'package:uhabits_core/src/models/entry.dart';

import '../helpers/test_database.dart';

/// Assertions about migrations 09 through 17, the scripts embedded verbatim in
/// `lib/src/database/migrations.g.dart` from
/// `uhabits-core/assets/main/migrations/NN.sql`.
///
/// Each migration is driven through the real runner
/// (`Database.migrateTo` + `SQLParser.parse`) on a fresh in-memory database,
/// and the result is inspected with `pragma table_info` / `pragma index_list` /
/// `pragma index_info` and ordinary queries — never by re-reading the SQL text
/// alone, except where the rule is explicitly about statement ORDER, which is
/// unobservable in the resulting schema.
///
/// Kotlin counterpart:
/// `uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/MigrationTest.kt`.

/// One row of `pragma table_info`.
typedef ColumnInfo = ({
  int cid,
  String name,
  String type,
  int notnull,
  String? dflt,
  int pk,
});

/// One row of `pragma index_list`.
typedef IndexInfo = ({
  int seq,
  String name,
  int unique,
  String origin,
  int partial,
});

/// A fresh in-memory database migrated up to [version] (8 → [version]).
Database openAt(int version) => openMigratedDatabase(version: version);

/// Applies the bundled migrations up to [version] on an already-open database.
void migrateTo(Database db, int version) =>
    db.migrateTo(version, (v) => migrationSql[v]!);

List<ColumnInfo> tableInfo(Database db, String table) {
  final columns = <ColumnInfo>[];
  db.query('pragma table_info($table)', const [], (s) {
    columns.add((
      cid: s.getInt(0),
      name: s.getText(1),
      // SQLite reports the declared type; compare case-insensitively so the
      // test does not depend on the driver's SQLite build.
      type: s.getText(2).toUpperCase(),
      notnull: s.getInt(3),
      dflt: s.getTextOrNull(4),
      pk: s.getInt(5),
    ));
  });
  return columns;
}

List<String> columnNames(Database db, String table) =>
    tableInfo(db, table).map((c) => c.name).toList();

List<String> columnTypes(Database db, String table) =>
    tableInfo(db, table).map((c) => c.type).toList();

ColumnInfo column(Database db, String table, String name) =>
    tableInfo(db, table).firstWhere((c) => c.name == name);

/// `pragma foreign_key_list`, as `from -> table(to)` strings.
List<String> foreignKeys(Database db, String table) {
  final keys = <String>[];
  db.query('pragma foreign_key_list($table)', const [], (s) {
    keys.add('${s.getText(3)} -> ${s.getText(2)}(${s.getTextOrNull(4)})');
  });
  return keys;
}

List<IndexInfo> indexList(Database db, String table) {
  final indexes = <IndexInfo>[];
  db.query('pragma index_list($table)', const [], (s) {
    indexes.add((
      seq: s.getInt(0),
      name: s.getText(1),
      unique: s.getInt(2),
      origin: s.getText(3),
      partial: s.getInt(4),
    ));
  });
  return indexes;
}

/// The indexed columns of [index], in index order.
List<String> indexColumns(Database db, String index) {
  final columns = <String>[];
  db.query('pragma index_info($index)', const [], (s) {
    columns.add(s.getText(2));
  });
  return columns;
}

/// Table names in creation order (sqlite_master rowid order). SQLite's internal
/// `sqlite_sequence` bookkeeping table is filtered out: it materialises as soon
/// as the first AUTOINCREMENT table is created.
List<String> tablesInCreationOrder(Database db) {
  final names = <String>[];
  db.query(
    "select name from sqlite_master where type = 'table' "
    "and name <> 'sqlite_sequence' order by rowid",
    const [],
    (s) => names.add(s.getText(0)),
  );
  return names;
}

List<String> indexesInCreationOrder(Database db) {
  final names = <String>[];
  db.query(
    "select name from sqlite_master where type = 'index' order by rowid",
    const [],
    (s) => names.add(s.getText(0)),
  );
  return names;
}

/// Table names that own an AUTOINCREMENT counter, i.e. have a row in
/// `sqlite_sequence`. A table only appears once a row has been inserted.
List<String> autoincrementTables(Database db) {
  final names = <String>[];
  db.query(
    'select name from sqlite_sequence order by name',
    const [],
    (s) => names.add(s.getText(0)),
  );
  return names;
}

int count(Database db, String table) =>
    db.queryInt('select count(*) from $table');

List<int> intColumn(Database db, String sql) {
  final values = <int>[];
  db.query(sql, const [], (s) => values.add(s.getInt(0)));
  return values;
}

String typeofScore(Database db) =>
    db.querySingle('select typeof(score) from Score', const [], (s) {
      return s.getText(0);
    })!;

/// Fills every table that exists at schema version [version] with two rows.
/// Only columns that exist at version 9 are named, so the same helper works
/// for any version from 9 up to (but not including) 16.
void seedAllTables(Database db) {
  db.run(
    "insert into Habits(name, description, color, position, archived, "
    "freq_num, freq_den) values ('Meditate', 'daily', 3, 0, 0, 1, 1)",
  );
  db.run(
    "insert into Habits(name, description, color, position, archived, "
    "freq_num, freq_den) values ('Run', 'weekly', 7, 1, 0, 1, 7)",
  );
  db.run('insert into Repetitions(habit, timestamp) values (1, 100)');
  db.run('insert into Repetitions(habit, timestamp) values (2, 200)');
  db.run('insert into Checkmarks(habit, timestamp, value) values (1, 100, 2)');
  db.run('insert into Checkmarks(habit, timestamp, value) values (2, 200, 2)');
  db.run('insert into Score(habit, timestamp, score) values (1, 100, 1)');
  db.run('insert into Score(habit, timestamp, score) values (2, 200, 1)');
  db.run('insert into Streak(habit, start, end, length) values (1, 1, 2, 2)');
  db.run('insert into Streak(habit, start, end, length) values (2, 3, 4, 2)');
}

void main() {
  group('persistence.migration-v09', () {
    late Database db;

    setUp(() {
      db = openAt(9);
    });

    tearDown(() {
      db.close();
    });

    test('#1 creates Habits with 11 nullable, defaultless columns', () {
      final info = tableInfo(db, 'Habits');

      expect(
        info.map((c) => c.name).toList(),
        [
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
        ],
        reason: 'persistence.migration-v09#1 — Habits columns, in order',
      );
      expect(
        info.map((c) => c.type).toList(),
        [
          'INTEGER',
          'INTEGER',
          'INTEGER',
          'TEXT',
          'INTEGER',
          'INTEGER',
          'INTEGER',
          'TEXT',
          'INTEGER',
          'INTEGER',
          'INTEGER',
        ],
        reason: 'persistence.migration-v09#1 — description and name are text, '
            'every other Habits column is integer',
      );
      expect(
        info.map((c) => c.notnull).toList(),
        everyElement(0),
        reason: 'persistence.migration-v09#1 — no NOT NULL on any column',
      );
      expect(
        info.map((c) => c.dflt).toList(),
        everyElement(isNull),
        reason: 'persistence.migration-v09#1 — no DEFAULT on any column',
      );
      expect(
        info.map((c) => c.pk).toList(),
        [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        reason: 'persistence.migration-v09#1 — id is the primary key',
      );

      // Every column really is nullable: a bare insert must succeed.
      db.run('insert into Habits(name) values (null)');
      expect(
        count(db, 'Habits'),
        1,
        reason: 'persistence.migration-v09#1 — no NOT NULL, so a row of all '
            'NULLs is accepted',
      );
      expect(
        autoincrementTables(db),
        contains('Habits'),
        reason: 'persistence.migration-v09#1 — id is '
            'integer primary key autoincrement, so SQLite keeps a '
            'sqlite_sequence counter for Habits',
      );
    });

    test('#2 creates Checkmarks(id, habit -> habits(id), timestamp, value)',
        () {
      expect(
        columnNames(db, 'Checkmarks'),
        ['id', 'habit', 'timestamp', 'value'],
        reason: 'persistence.migration-v09#2 — Checkmarks columns, in order',
      );
      expect(
        columnTypes(db, 'Checkmarks'),
        ['INTEGER', 'INTEGER', 'INTEGER', 'INTEGER'],
        reason: 'persistence.migration-v09#2 — all Checkmarks columns integer',
      );
      expect(
        column(db, 'Checkmarks', 'id').pk,
        1,
        reason: 'persistence.migration-v09#2 — Checkmarks.id is the '
            'primary key',
      );
      expect(
        foreignKeys(db, 'Checkmarks'),
        ['habit -> habits(id)'],
        reason: 'persistence.migration-v09#2 — Checkmarks.habit references '
            'habits(id)',
      );
      db.run('insert into Checkmarks(habit, timestamp, value) values (1,2,3)');
      expect(
        autoincrementTables(db),
        contains('Checkmarks'),
        reason: 'persistence.migration-v09#2 — Checkmarks.id is autoincrement',
      );
    });

    test('#3 creates Repetitions with no value column yet', () {
      expect(
        columnNames(db, 'Repetitions'),
        ['id', 'habit', 'timestamp'],
        reason: 'persistence.migration-v09#3 — Repetitions columns, in order',
      );
      expect(
        columnNames(db, 'Repetitions'),
        isNot(contains('value')),
        reason: 'persistence.migration-v09#3 — there is no value column at '
            'version 9; it arrives with migration 16',
      );
      expect(
        columnTypes(db, 'Repetitions'),
        ['INTEGER', 'INTEGER', 'INTEGER'],
        reason: 'persistence.migration-v09#3 — all Repetitions columns integer',
      );
      expect(
        column(db, 'Repetitions', 'id').pk,
        1,
        reason: 'persistence.migration-v09#3 — Repetitions.id is the '
            'primary key',
      );
      expect(
        foreignKeys(db, 'Repetitions'),
        ['habit -> habits(id)'],
        reason: 'persistence.migration-v09#3 — Repetitions.habit references '
            'habits(id)',
      );
      db.run('insert into Repetitions(habit, timestamp) values (1, 2)');
      expect(
        autoincrementTables(db),
        contains('Repetitions'),
        reason: 'persistence.migration-v09#3 — Repetitions.id is autoincrement',
      );
    });

    test('#4 creates Streak(id, end, habit -> habits(id), length, start)', () {
      expect(
        columnNames(db, 'Streak'),
        ['id', 'end', 'habit', 'length', 'start'],
        reason: 'persistence.migration-v09#4 — Streak columns, in the '
            'alphabetical order the script declares them',
      );
      expect(
        columnTypes(db, 'Streak'),
        ['INTEGER', 'INTEGER', 'INTEGER', 'INTEGER', 'INTEGER'],
        reason: 'persistence.migration-v09#4 — all Streak columns integer',
      );
      expect(
        column(db, 'Streak', 'id').pk,
        1,
        reason: 'persistence.migration-v09#4 — Streak.id is the primary key',
      );
      expect(
        foreignKeys(db, 'Streak'),
        ['habit -> habits(id)'],
        reason:
            'persistence.migration-v09#4 — Streak.habit references habits(id)',
      );
      db.run('insert into Streak(habit, start, end, length) values (1,1,2,2)');
      expect(
        autoincrementTables(db),
        contains('Streak'),
        reason: 'persistence.migration-v09#4 — Streak.id is autoincrement',
      );
    });

    test('#5 creates Score with an INTEGER score column', () {
      expect(
        columnNames(db, 'Score'),
        ['id', 'habit', 'score', 'timestamp'],
        reason: 'persistence.migration-v09#5 — Score columns, in order',
      );
      expect(
        column(db, 'Score', 'score').type,
        'INTEGER',
        reason: 'persistence.migration-v09#5 — score is INTEGER at version 9; '
            'migration 17 turns it into REAL',
      );
      expect(
        columnTypes(db, 'Score'),
        ['INTEGER', 'INTEGER', 'INTEGER', 'INTEGER'],
        reason: 'persistence.migration-v09#5 — every Score column is integer',
      );
      expect(
        foreignKeys(db, 'Score'),
        ['habit -> habits(id)'],
        reason:
            'persistence.migration-v09#5 — Score.habit references habits(id)',
      );
      // INTEGER affinity is observable: a lossless real is stored as an int.
      db.run('insert into Score(habit, score, timestamp) values (1, 1.0, 0)');
      expect(
        typeofScore(db),
        'integer',
        reason: 'persistence.migration-v09#5 — the column has INTEGER '
            'affinity at version 9, so 1.0 is stored as the integer 1',
      );
      expect(
        autoincrementTables(db),
        contains('Score'),
        reason: 'persistence.migration-v09#5 — Score.id is autoincrement',
      );
    });

    test('#6 runs the five CREATE TABLE statements in the declared order', () {
      final commands = SQLParser.parse(migrationSql[9]!);

      expect(
        commands.length,
        5,
        reason: 'persistence.migration-v09#6 — migration 09 is exactly five '
            'CREATE TABLE statements',
      );
      expect(
        commands
            .map((c) => c.split('(').first.trim().toLowerCase())
            .toList(),
        [
          'create table habits',
          'create table checkmarks',
          'create table repetitions',
          'create table streak',
          'create table score',
        ],
        reason: 'persistence.migration-v09#6 — order: Habits, Checkmarks, '
            'Repetitions, Streak, Score',
      );
      expect(
        tablesInCreationOrder(db),
        ['Habits', 'Checkmarks', 'Repetitions', 'Streak', 'Score'],
        reason: 'persistence.migration-v09#6 — the tables really are created '
            'in that order (sqlite_master rowid order)',
      );
    });
  });

  group('persistence.migration-cache-resets', () {
    test('#1 migrations 10, 12 and 15 are identical three-statement scripts',
        () {
      expect(
        migrationSql[12],
        migrationSql[10],
        reason: 'persistence.migration-cache-resets#1 — migration 12 is '
            'byte-for-byte equal to migration 10',
      );
      expect(
        migrationSql[15],
        migrationSql[10],
        reason: 'persistence.migration-cache-resets#1 — migration 15 is '
            'byte-for-byte equal to migration 10',
      );
      for (final v in [10, 12, 15]) {
        expect(
          SQLParser.parse(migrationSql[v]!),
          ['delete from Score', 'delete from Streak', 'delete from Checkmarks'],
          reason: 'persistence.migration-cache-resets#1 — migration $v is '
              'exactly three statements, in the order Score, Streak, '
              'Checkmarks',
        );
      }
    });

    for (final step in [(9, 10), (11, 12), (14, 15)]) {
      final from = step.$1;
      final to = step.$2;

      test('#2/#3 migration $to clears the derived caches only', () {
        final db = openAt(from);
        addTearDown(db.close);
        seedAllTables(db);

        migrateTo(db, to);

        expect(
          count(db, 'Score'),
          0,
          reason: 'persistence.migration-cache-resets#1 — migration $to runs '
              'delete from Score',
        );
        expect(
          count(db, 'Streak'),
          0,
          reason: 'persistence.migration-cache-resets#1 — migration $to runs '
              'delete from Streak',
        );
        expect(
          count(db, 'Checkmarks'),
          0,
          reason: 'persistence.migration-cache-resets#1 — migration $to runs '
              'delete from Checkmarks',
        );
        expect(
          count(db, 'Habits'),
          2,
          reason: 'persistence.migration-cache-resets#2 — migration $to never '
              'touches Habits, so no user data is lost',
        );
        expect(
          count(db, 'Repetitions'),
          2,
          reason: 'persistence.migration-cache-resets#2 — migration $to never '
              'touches Repetitions, so no user data is lost',
        );
        expect(
          intColumn(db, 'select timestamp from Repetitions order by id'),
          [100, 200],
          reason: 'persistence.migration-cache-resets#2 — the surviving '
              'Repetitions rows are unchanged by migration $to',
        );
        expect(
          intColumn(db, 'select color from Habits order by id'),
          [3, 7],
          reason: 'persistence.migration-cache-resets#2 — the surviving '
              'Habits rows are unchanged by migration $to',
        );
        expect(
          db.getVersion(),
          to,
          reason: 'persistence.migration-cache-resets#3 — migration $to is a '
              'semantic no-op for a port that recomputes derived data, but it '
              'must still advance user_version $from → $to',
        );
      });
    }

    test('#3 the cache resets are the only thing standing between 9 and 16',
        () {
      // Applying all three in one run still lands on the expected version, so
      // a port that treats them as no-ops must not skip the version bump.
      final db = openAt(9);
      addTearDown(db.close);
      migrateTo(db, 15);
      expect(
        db.getVersion(),
        15,
        reason: 'persistence.migration-cache-resets#3 — migrating across 10, '
            '12 and 15 advances user_version through every one of them',
      );
    });
  });

  group('persistence.migration-v11', () {
    test('#1 executes exactly one ALTER TABLE statement', () {
      expect(
        SQLParser.parse(migrationSql[11]!),
        [
          'alter table Habits add column reminder_days integer '
              'not null default 127',
        ],
        reason: 'persistence.migration-v11#1 — migration 11 is exactly '
            '`alter table Habits add column reminder_days integer not null '
            'default 127`',
      );
    });

    test('#2 every pre-existing habit gets reminder_days = 127', () {
      final db = openAt(10);
      addTearDown(db.close);
      db.run("insert into Habits(name, color) values ('Meditate', 3)");
      db.run("insert into Habits(name, color) values ('Run', 7)");

      migrateTo(db, 11);

      final info = column(db, 'Habits', 'reminder_days');
      expect(
        info.type,
        'INTEGER',
        reason: 'persistence.migration-v11#1 — reminder_days is an integer '
            'column',
      );
      expect(
        info.notnull,
        1,
        reason: 'persistence.migration-v11#1 — reminder_days is NOT NULL',
      );
      expect(
        info.dflt,
        '127',
        reason: 'persistence.migration-v11#1 — reminder_days defaults to 127',
      );
      expect(
        intColumn(db, 'select reminder_days from Habits order by id'),
        [127, 127],
        reason: 'persistence.migration-v11#2 — every pre-existing habit row '
            'receives reminder_days = 127',
      );
      expect(
        127.toRadixString(2),
        '1111111',
        reason: 'persistence.migration-v11#2 — 127 is a WeekdayList bitmask '
            'with all seven days enabled',
      );
      db.run("insert into Habits(name, color) values ('New', 1)");
      expect(
        intColumn(db, 'select reminder_days from Habits order by id'),
        [127, 127, 127],
        reason: 'persistence.migration-v11#2 — habits inserted afterwards also '
            'default to 127',
      );
    });
  });

  group('persistence.migration-v13', () {
    late Database db;

    setUp(() {
      db = openAt(13);
    });

    tearDown(() {
      db.close();
    });

    test('#1 creates the four indexes in order', () {
      expect(
        SQLParser.parse(migrationSql[13]!),
        [
          'create index idx_score_habit_timestamp on Score(habit, timestamp)',
          'create index idx_checkmark_habit_timestamp '
              'on Checkmarks(habit, timestamp)',
          'create index idx_repetitions_habit_timestamp '
              'on Repetitions(habit, timestamp)',
          'create index idx_streak_habit_end on Streak(habit, end)',
        ],
        reason: 'persistence.migration-v13#1 — four CREATE INDEX statements, '
            'in the order Score, Checkmarks, Repetitions, Streak',
      );
      expect(
        indexesInCreationOrder(db),
        [
          'idx_score_habit_timestamp',
          'idx_checkmark_habit_timestamp',
          'idx_repetitions_habit_timestamp',
          'idx_streak_habit_end',
        ],
        reason: 'persistence.migration-v13#1 — the indexes really are created '
            'in that order (sqlite_master rowid order)',
      );
      expect(
        indexList(db, 'Score').map((i) => i.name).toList(),
        ['idx_score_habit_timestamp'],
        reason: 'persistence.migration-v13#1 — idx_score_habit_timestamp lives '
            'on Score',
      );
      expect(
        indexColumns(db, 'idx_score_habit_timestamp'),
        ['habit', 'timestamp'],
        reason: 'persistence.migration-v13#1 — idx_score_habit_timestamp '
            'covers Score(habit, timestamp)',
      );
      expect(
        indexList(db, 'Checkmarks').map((i) => i.name).toList(),
        ['idx_checkmark_habit_timestamp'],
        reason: 'persistence.migration-v13#1 — '
            'idx_checkmark_habit_timestamp lives on Checkmarks',
      );
      expect(
        indexColumns(db, 'idx_checkmark_habit_timestamp'),
        ['habit', 'timestamp'],
        reason: 'persistence.migration-v13#1 — idx_checkmark_habit_timestamp '
            'covers Checkmarks(habit, timestamp)',
      );
      expect(
        indexList(db, 'Repetitions').map((i) => i.name).toList(),
        ['idx_repetitions_habit_timestamp'],
        reason: 'persistence.migration-v13#1 — '
            'idx_repetitions_habit_timestamp lives on Repetitions',
      );
      expect(
        indexColumns(db, 'idx_repetitions_habit_timestamp'),
        ['habit', 'timestamp'],
        reason: 'persistence.migration-v13#1 — idx_repetitions_habit_timestamp '
            'covers Repetitions(habit, timestamp)',
      );
      expect(
        indexList(db, 'Streak').map((i) => i.name).toList(),
        ['idx_streak_habit_end'],
        reason: 'persistence.migration-v13#1 — idx_streak_habit_end lives on '
            'Streak',
      );
      expect(
        indexColumns(db, 'idx_streak_habit_end'),
        ['habit', 'end'],
        reason: 'persistence.migration-v13#1 — idx_streak_habit_end covers '
            'Streak(habit, end), not (habit, timestamp)',
      );
    });

    test('#2 all four indexes are non-unique', () {
      for (final table in ['Score', 'Checkmarks', 'Repetitions', 'Streak']) {
        final indexes = indexList(db, table);
        expect(
          indexes.map((i) => i.unique).toList(),
          everyElement(0),
          reason: 'persistence.migration-v13#2 — the index on $table is '
              'non-unique',
        );
        expect(
          indexes.map((i) => i.origin).toList(),
          everyElement('c'),
          reason: 'persistence.migration-v13#2 — the index on $table comes '
              'from CREATE INDEX, not from a UNIQUE constraint',
        );
      }
      // Behavioural proof: duplicate (habit, timestamp) pairs are accepted.
      db.run('insert into Score(habit, timestamp, score) values (1, 100, 1)');
      db.run('insert into Score(habit, timestamp, score) values (1, 100, 1)');
      db.run(
        'insert into Checkmarks(habit, timestamp, value) values (1, 100, 2)',
      );
      db.run(
        'insert into Checkmarks(habit, timestamp, value) values (1, 100, 2)',
      );
      db.run('insert into Repetitions(habit, timestamp) values (1, 100)');
      db.run('insert into Repetitions(habit, timestamp) values (1, 100)');
      db.run('insert into Streak(habit, start, end, length) values (1,1,2,2)');
      db.run('insert into Streak(habit, start, end, length) values (1,1,2,2)');
      expect(
        [
          count(db, 'Score'),
          count(db, 'Checkmarks'),
          count(db, 'Repetitions'),
          count(db, 'Streak'),
        ],
        [2, 2, 2, 2],
        reason: 'persistence.migration-v13#2 — duplicate keys are accepted, so '
            'none of the four indexes is unique',
      );
    });
  });

  group('persistence.migration-v14', () {
    /// The 13 ARGB colors migration 14 knows about, in the order the script
    /// rewrites them; the palette index is the position in this list.
    const argb = [
      -2937041,
      -1684967,
      -415707,
      -5262293,
      -13070788,
      -16742021,
      -16732991,
      -16540699,
      -10603087,
      -7461718,
      -2614432,
      -13619152,
      -5592406,
    ];

    test('#1 remaps the 13 known ARGB colors to palette indices 0..12', () {
      final db = openAt(13);
      addTearDown(db.close);
      for (var i = 0; i < argb.length; i++) {
        db.run("insert into Habits(name, color) values ('h$i', ${argb[i]})");
      }

      migrateTo(db, 14);

      expect(
        intColumn(db, 'select color from Habits order by id'),
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        reason: 'persistence.migration-v14#1 — the 13 ARGB values map to '
            'palette indices 0..12 in the documented order',
      );
      final commands = SQLParser.parse(migrationSql[14]!);
      expect(
        commands.take(13).toList(),
        [
          for (var i = 0; i < argb.length; i++)
            'update habits set color=$i where color=${argb[i]}',
        ],
        reason: 'persistence.migration-v14#1 — the 13 mappings are separate '
            'UPDATE statements, applied in that order',
      );
      expect(
        commands.length,
        14,
        reason: 'persistence.migration-v14#1 — 13 mapping statements plus the '
            'final clamp',
      );
    });

    test('#2 the final statement clamps anything outside 0..12 to 0', () {
      final db = openAt(13);
      addTearDown(db.close);
      // id 1..5: unknown colors. id 6..8: already-migrated palette indices.
      for (final color in [-1, -999999, 13, 9999, -16777216, 0, 5, 12]) {
        db.run("insert into Habits(name, color) values ('h', $color)");
      }

      migrateTo(db, 14);

      expect(
        intColumn(db, 'select color from Habits order by id'),
        [0, 0, 0, 0, 0, 0, 5, 12],
        reason: 'persistence.migration-v14#2 — colors outside 0..12 (including '
            'unmapped ARGB values) are clamped to 0, while values already in '
            'range are left alone',
      );
      expect(
        SQLParser.parse(migrationSql[14]!).last,
        'update habits set color=0 where color<0 or color>12',
        reason: 'persistence.migration-v14#2 — the final statement is '
            '`update habits set color=0 where color<0 or color>12`',
      );
    });

    test('#3 the clamp runs last and does not undo the 13 mappings', () {
      final db = openAt(13);
      addTearDown(db.close);
      for (var i = 0; i < argb.length; i++) {
        db.run("insert into Habits(name, color) values ('h$i', ${argb[i]})");
      }
      db.run("insert into Habits(name, color) values ('unknown', -424242)");

      migrateTo(db, 14);

      expect(
        intColumn(db, 'select color from Habits order by id'),
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0],
        reason: 'persistence.migration-v14#3 — had the clamp run first, every '
            'negative ARGB value would already be 0 and none of the mappings '
            'would match; the mapped habits keep their palette index',
      );
      expect(
        db.queryInt("select color from Habits where name = 'h12'"),
        12,
        reason: 'persistence.migration-v14#3 — 12 is the largest palette '
            'index, and color>12 is false for it, so the clamp leaves it alone',
      );
      expect(
        db.queryInt('select count(*) from Habits where color = 0'),
        2,
        reason: 'persistence.migration-v14#3 — only the habit mapped to 0 and '
            'the unmapped habit end up at 0',
      );
    });
  });

  group('persistence.migration-v16', () {
    late Database db;

    setUp(() {
      db = openAt(15);
      db.run("insert into Habits(name, color) values ('Meditate', 3)");
      db.run("insert into Habits(name, color) values ('Run', 7)");
      db.run('insert into Repetitions(habit, timestamp) values (1, 100)');
      db.run('insert into Repetitions(habit, timestamp) values (2, 200)');
      migrateTo(db, 16);
    });

    tearDown(() {
      db.close();
    });

    test('#1 adds Habits.type, defaulting every existing habit to 0', () {
      final info = column(db, 'Habits', 'type');
      expect(
        info.type,
        'INTEGER',
        reason: 'persistence.migration-v16#1 — type is an integer column',
      );
      expect(
        info.notnull,
        1,
        reason: 'persistence.migration-v16#1 — type is NOT NULL',
      );
      expect(
        info.dflt,
        '0',
        reason: 'persistence.migration-v16#1 — type defaults to 0',
      );
      expect(
        info.cid,
        columnNames(db, 'Habits').length - 1,
        reason: 'persistence.migration-v16#1 — ALTER TABLE ADD COLUMN appends '
            'type as the last Habits column',
      );
      expect(
        intColumn(db, 'select type from Habits order by id'),
        [0, 0],
        reason: 'persistence.migration-v16#1 — all existing habits become '
            'type 0 (boolean)',
      );
    });

    test('#2 adds Repetitions.value, defaulting every repetition to 2', () {
      final info = column(db, 'Repetitions', 'value');
      expect(
        info.type,
        'INTEGER',
        reason: 'persistence.migration-v16#2 — value is an integer column',
      );
      expect(
        info.notnull,
        1,
        reason: 'persistence.migration-v16#2 — value is NOT NULL',
      );
      expect(
        info.dflt,
        '2',
        reason: 'persistence.migration-v16#2 — value defaults to 2',
      );
      expect(
        columnNames(db, 'Repetitions'),
        ['id', 'habit', 'timestamp', 'value'],
        reason: 'persistence.migration-v16#2 — value is appended to '
            'Repetitions',
      );
      expect(
        intColumn(db, 'select value from Repetitions order by id'),
        [2, 2],
        reason: 'persistence.migration-v16#2 — every pre-existing repetition '
            'gets value 2, because a row existing used to mean a manual check',
      );
      expect(
        intColumn(db, 'select value from Repetitions order by id'),
        everyElement(Entry.yesManual),
        reason: 'persistence.migration-v16#2 — 2 is Entry.YES_MANUAL',
      );
    });

    test('#3 runs the Habits ALTER before the Repetitions ALTER', () {
      expect(
        SQLParser.parse(migrationSql[16]!),
        [
          'alter table Habits add column type integer not null default 0',
          'alter table Repetitions add column value integer not null default 2',
        ],
        reason: 'persistence.migration-v16#3 — exactly two statements, Habits '
            'first and Repetitions second',
      );
    });
  });

  group('persistence.migration-v17', () {
    late Database db;

    setUp(() {
      db = openAt(16);
      db.run("insert into Habits(name, color) values ('Meditate', 3)");
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values (1, 100, 2)');
      db.run('insert into Score(habit, timestamp, score) values (1, 100, 1)');
      db.run('insert into Score(habit, timestamp, score) values (1, 200, 0)');
      db.run('insert into Streak(habit, start, end, length) values (1,1,2,2)');
      db.run('insert into Checkmarks(habit, timestamp, value) '
          'values (1, 100, 2)');
    });

    tearDown(() {
      db.close();
    });

    test('#1 drops and recreates Score with a REAL score column', () {
      // Before: INTEGER affinity silently converts a lossless real to an int.
      db.run('insert into Score(habit, score, timestamp) values (9, 1.0, 0)');
      expect(
        db.querySingle('select typeof(score) from Score where habit = 9',
            const [], (s) => s.getText(0)),
        'integer',
        reason: 'persistence.migration-v17#1 — before migration 17 the score '
            'column is INTEGER',
      );

      migrateTo(db, 17);

      expect(
        SQLParser.parse(migrationSql[17]!).first,
        'drop table Score',
        reason: 'persistence.migration-v17#1 — the first statement is '
            '`drop table Score`',
      );
      expect(
        columnNames(db, 'Score'),
        ['id', 'habit', 'score', 'timestamp'],
        reason: 'persistence.migration-v17#1 — Score is recreated with the '
            'same four columns, in the same order',
      );
      expect(
        column(db, 'Score', 'score').type,
        'REAL',
        reason: 'persistence.migration-v17#1 — the score column changes from '
            'integer to real',
      );
      expect(
        columnTypes(db, 'Score'),
        ['INTEGER', 'INTEGER', 'REAL', 'INTEGER'],
        reason: 'persistence.migration-v17#1 — only score changes type; id, '
            'habit and timestamp stay integer',
      );
      expect(
        column(db, 'Score', 'id').pk,
        1,
        reason: 'persistence.migration-v17#1 — the recreated Score keeps '
            'id integer primary key autoincrement',
      );
      expect(
        foreignKeys(db, 'Score'),
        ['habit -> habits(id)'],
        reason: 'persistence.migration-v17#1 — the recreated Score keeps '
            'habit integer references habits(id)',
      );
      db.run('insert into Score(habit, score, timestamp) values (9, 1.0, 0)');
      expect(
        db.querySingle('select typeof(score) from Score where habit = 9',
            const [], (s) => s.getText(0)),
        'real',
        reason: 'persistence.migration-v17#1 — the recreated column has REAL '
            'affinity, so 1.0 stays a real',
      );
      expect(
        db.querySingle('select score from Score where habit = 9', const [],
            (s) => s.getReal(0)),
        closeTo(1.0, 1e-12),
        reason: 'persistence.migration-v17#1 — fractional scores now survive '
            'a round trip through the real column',
      );
    });

    test('#2 recreates idx_score_habit_timestamp', () {
      expect(
        indexList(db, 'Score').map((i) => i.name).toList(),
        ['idx_score_habit_timestamp'],
        reason: 'persistence.migration-v17#2 — the index exists before the '
            'migration (migration 13 created it)',
      );

      migrateTo(db, 17);

      // DROP TABLE also drops the table's indexes, so this proves the CREATE
      // INDEX in migration 17 ran.
      expect(
        indexList(db, 'Score').map((i) => i.name).toList(),
        ['idx_score_habit_timestamp'],
        reason: 'persistence.migration-v17#2 — dropping Score dropped its '
            'index, so migration 17 recreates idx_score_habit_timestamp',
      );
      expect(
        indexColumns(db, 'idx_score_habit_timestamp'),
        ['habit', 'timestamp'],
        reason: 'persistence.migration-v17#2 — the recreated index covers '
            'Score(habit, timestamp)',
      );
      expect(
        indexList(db, 'Score').single.unique,
        0,
        reason: 'persistence.migration-v17#2 — the recreated index is '
            'non-unique, like the original',
      );
      expect(
        SQLParser.parse(migrationSql[17]!)[2],
        'create index idx_score_habit_timestamp on Score(habit, timestamp)',
        reason: 'persistence.migration-v17#2 — the CREATE INDEX follows the '
            'CREATE TABLE',
      );
    });

    test('#3 clears streak and checkmarks, in that order', () {
      migrateTo(db, 17);

      expect(
        count(db, 'Streak'),
        0,
        reason: 'persistence.migration-v17#3 — `delete from streak;` forces '
            'streaks to be recomputed',
      );
      expect(
        count(db, 'Checkmarks'),
        0,
        reason: 'persistence.migration-v17#3 — `delete from checkmarks;` '
            'forces checkmarks to be recomputed',
      );
      expect(
        count(db, 'Habits'),
        1,
        reason: 'persistence.migration-v17#3 — Habits is untouched',
      );
      expect(
        count(db, 'Repetitions'),
        1,
        reason: 'persistence.migration-v17#3 — Repetitions is untouched',
      );
      expect(
        SQLParser.parse(migrationSql[17]!),
        [
          'drop table Score',
          'create table Score ( id integer primary key autoincrement, '
              'habit integer references habits(id), score real, '
              'timestamp integer)',
          'create index idx_score_habit_timestamp on Score(habit, timestamp)',
          'delete from streak',
          'delete from checkmarks',
        ],
        reason: 'persistence.migration-v17#3 — five statements: drop, create '
            'table, create index, delete from streak, delete from checkmarks — '
            'streak before checkmarks',
      );
    });

    test('#4 all existing Score rows are lost', () {
      expect(
        count(db, 'Score'),
        2,
        reason: 'persistence.migration-v17#4 — two score rows exist before the '
            'migration',
      );

      migrateTo(db, 17);

      expect(
        count(db, 'Score'),
        0,
        reason: 'persistence.migration-v17#4 — the table is dropped, not '
            'converted, so every Score row is lost',
      );
      expect(
        autoincrementTables(db),
        isNot(contains('Score')),
        reason: 'persistence.migration-v17#4 — dropping the table also drops '
            "its sqlite_sequence row, so Score's autoincrement counter "
            'restarts',
      );
      expect(
        count(db, 'Repetitions'),
        1,
        reason: 'persistence.migration-v17#4 — only Score loses its rows; the '
            'user data in Repetitions survives',
      );
    });
  });
}
