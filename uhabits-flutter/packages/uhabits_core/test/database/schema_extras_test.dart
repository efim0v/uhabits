/// Assertions about the legacy/unused tables and the index lifecycle of the
/// embedded migration scripts.
///
/// Features: `persistence.schema-legacy-tables`, `persistence.schema-indexes`.
///
/// There is no Dart source file for this slice: the contract lives entirely in
/// the verbatim SQL of `lib/src/database/migrations.g.dart`
/// (`uhabits-core/assets/main/migrations/*.sql`), so every rule is asserted by
/// migrating an in-memory database to a given version and inspecting the
/// resulting schema through `sqlite_master` and the SQLite pragmas.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sql_parser.dart';

import '../helpers/test_database.dart';

/// Every table in the database, including SQLite's own bookkeeping tables.
Set<String> tableNames(Database db) {
  final names = <String>{};
  db.query(
    "select name from sqlite_master where type = 'table'",
    const [],
    (stmt) => names.add(stmt.getText(0)),
  );
  return names;
}

/// Column names of [table], in declaration order.
List<String> columnNames(Database db, String table) {
  final names = <String>[];
  db.query(
    'pragma table_info($table)',
    const [],
    (stmt) => names.add(stmt.getText(1)),
  );
  return names;
}

/// Declared column types of [table], keyed by column name, lower-cased.
///
/// The bundled SQLite build reports declared types from `pragma table_info`
/// upper-cased (`integer` comes back as `INTEGER`), so the case is normalised
/// here — the migrations write them in lower case.
Map<String, String> columnTypes(Database db, String table) {
  final types = <String, String>{};
  db.query(
    'pragma table_info($table)',
    const [],
    (stmt) => types[stmt.getText(1)] = stmt.getText(2).toLowerCase(),
  );
  return types;
}

/// Every index in the database, auto-indexes included.
Set<String> allIndexNames(Database db) {
  final names = <String>{};
  db.query(
    "select name from sqlite_master where type = 'index'",
    const [],
    (stmt) => names.add(stmt.getText(0)),
  );
  return names;
}

/// Indexes that were created by an explicit `create index` statement.
///
/// `sqlite_master.sql` is NULL for the indexes SQLite creates on its own
/// (UNIQUE/PRIMARY KEY constraints), so a non-null `sql` means the migrations
/// asked for this index by name.
Set<String> declaredIndexNames(Database db) {
  final names = <String>{};
  db.query(
    "select name from sqlite_master where type = 'index' and sql is not null",
    const [],
    (stmt) => names.add(stmt.getText(0)),
  );
  return names;
}

/// The table an index belongs to, or null when the index does not exist.
String? indexTable(Database db, String index) => db.querySingle(
  "select tbl_name from sqlite_master where type = 'index' and name = ?",
  [index],
  (stmt) => stmt.getText(0),
);

/// Indexed columns of [index], in index order.
List<String> indexColumns(Database db, String index) {
  final columns = <String>[];
  db.query(
    'pragma index_info($index)',
    const [],
    (stmt) => columns.add(stmt.getText(2)),
  );
  return columns;
}

/// Whether [index] on [table] is UNIQUE, per `pragma index_list`.
bool indexIsUnique(Database db, String table, String index) {
  var unique = false;
  db.query('pragma index_list($table)', const [], (stmt) {
    if (stmt.getText(1) == index) unique = stmt.getInt(2) != 0;
  });
  return unique;
}

int countRows(Database db, String table) => db.queryInt('select count(*) from $table');

/// Matches the SqliteException raised by a UNIQUE constraint violation.
final Matcher throwsUniqueConstraintViolation = throwsA(
  isA<Exception>().having(
    (e) => e.toString().toLowerCase(),
    'message',
    contains('unique'),
  ),
);

void main() {
  group('persistence.schema-legacy-tables', () {
    test('migration 09 creates Checkmarks, Streak and Score (#1)', () {
      final db = openMigratedDatabase(version: 9);
      addTearDown(db.close);

      final tables = tableNames(db);
      expect(
        tables,
        containsAll(<String>['Checkmarks', 'Streak', 'Score']),
        reason: 'persistence.schema-legacy-tables#1: migration 09 creates the '
            'three derived-data tables alongside Habits and Repetitions',
      );
      expect(
        columnNames(db, 'Checkmarks'),
        <String>['id', 'habit', 'timestamp', 'value'],
        reason: 'persistence.schema-legacy-tables#1: '
            'Checkmarks(id, habit, timestamp, value)',
      );
      expect(
        columnNames(db, 'Streak'),
        <String>['id', 'end', 'habit', 'length', 'start'],
        reason: 'persistence.schema-legacy-tables#1: '
            'Streak(id, end, habit, length, start)',
      );
      expect(
        columnNames(db, 'Score'),
        <String>['id', 'habit', 'score', 'timestamp'],
        reason: 'persistence.schema-legacy-tables#1: '
            'Score(id, habit, score, timestamp)',
      );
    });

    test('the three derived-data tables are gone at version 25 (#1)', () {
      final db = openMigratedDatabase();
      addTearDown(db.close);

      final tables = tableNames(db);
      for (final table in <String>['Checkmarks', 'Streak', 'Score']) {
        expect(
          tables,
          isNot(contains(table)),
          reason: 'persistence.schema-legacy-tables#1: $table no longer exists '
              'at version 25',
        );
      }
      expect(
        tables,
        containsAll(<String>['Habits', 'Repetitions', 'Events']),
        reason: 'persistence.schema-legacy-tables#1: only the derived-data '
            'tables were removed; Habits, Repetitions and Events survive',
      );
    });

    test('migration 20 drops checkmarks, streak and score (#2)', () {
      expect(
        SQLParser.parse(migrationSql[20]!),
        <String>[
          'drop table checkmarks',
          'drop table streak',
          'drop table score',
        ],
        reason: 'persistence.schema-legacy-tables#2: migration 20 is exactly '
            '`drop table checkmarks; drop table streak; drop table score;`',
      );

      final before = openMigratedDatabase(version: 19);
      addTearDown(before.close);
      expect(
        tableNames(before),
        containsAll(<String>['Checkmarks', 'Streak', 'Score']),
        reason: 'persistence.schema-legacy-tables#2: the tables still exist at '
            'version 19, immediately before migration 20 runs',
      );

      final after = openMigratedDatabase(version: 20);
      addTearDown(after.close);
      final tables = tableNames(after);
      for (final table in <String>['Checkmarks', 'Streak', 'Score']) {
        expect(
          tables,
          isNot(contains(table)),
          reason: 'persistence.schema-legacy-tables#2: after version 20 '
              '$table must not exist — the lower-case `drop table` statements '
              'match the mixed-case table names because SQLite identifiers '
              'are case-insensitive',
        );
      }
      expect(
        () => countRows(after, 'Checkmarks'),
        throwsA(isA<Exception>()),
        reason: 'persistence.schema-legacy-tables#2: checkmarks are recomputed '
            'in memory after version 20; nothing can be read back from SQL',
      );
    });

    test('migration 19 creates the write-only Events table (#3)', () {
      final before = openMigratedDatabase(version: 18);
      addTearDown(before.close);
      expect(
        tableNames(before),
        isNot(contains('Events')),
        reason: 'persistence.schema-legacy-tables#3: Events does not exist '
            'before migration 19',
      );

      final db = openMigratedDatabase(version: 19);
      addTearDown(db.close);
      expect(
        columnNames(db, 'Events'),
        <String>['id', 'timestamp', 'message', 'server_id'],
        reason: 'persistence.schema-legacy-tables#3: '
            'Events(id, timestamp, message, server_id)',
      );
      expect(
        columnTypes(db, 'Events'),
        <String, String>{
          'id': 'integer',
          'timestamp': 'integer',
          'message': 'text',
          'server_id': 'integer',
        },
        reason: 'persistence.schema-legacy-tables#3: Events stores an integer '
            'id, an integer timestamp, a text message and an integer server_id',
      );
      final sql = db.querySingle(
        "select sql from sqlite_master where type = 'table' and name = 'Events'",
        const [],
        (stmt) => stmt.getText(0),
      );
      expect(
        sql?.toLowerCase(),
        contains('id integer primary key autoincrement'),
        reason: 'persistence.schema-legacy-tables#3: Events.id is an '
            'autoincrement primary key',
      );

      final v25 = openMigratedDatabase();
      addTearDown(v25.close);
      expect(
        tableNames(v25),
        contains('Events'),
        reason: 'persistence.schema-legacy-tables#3: Events still exists at '
            'version 25',
      );
      expect(
        countRows(v25, 'Events'),
        0,
        reason: 'persistence.schema-legacy-tables#3: no migration and no '
            'application code ever writes to Events — it has no behavior',
      );
      final mentions = <int>[
        for (final entry in migrationSql.entries)
          if (entry.key != 19 && entry.value.toLowerCase().contains('events'))
            entry.key,
      ];
      expect(
        mentions,
        isEmpty,
        reason: 'persistence.schema-legacy-tables#3: only migration 19 '
            'mentions Events; it is never read or written afterwards',
      );
    });

    test('android_metadata and sqlite_sequence are not created by the '
        'migrations (#4)', () {
      final scriptsMentioningAndroidMetadata = <int>[
        for (final entry in migrationSql.entries)
          if (entry.value.toLowerCase().contains('android_metadata')) entry.key,
      ];
      expect(
        scriptsMentioningAndroidMetadata,
        isEmpty,
        reason: 'persistence.schema-legacy-tables#4: android_metadata is '
            'created by Android, never by a migration script',
      );
      final scriptsMentioningSqliteSequence = <int>[
        for (final entry in migrationSql.entries)
          if (entry.value.toLowerCase().contains('sqlite_sequence')) entry.key,
      ];
      expect(
        scriptsMentioningSqliteSequence,
        isEmpty,
        reason: 'persistence.schema-legacy-tables#4: sqlite_sequence is '
            'created by SQLite for AUTOINCREMENT, never by a migration script',
      );

      final db = openMigratedDatabase();
      addTearDown(db.close);
      expect(
        tableNames(db),
        isNot(contains('android_metadata')),
        reason: 'persistence.schema-legacy-tables#4: a database built by the '
            'migrations alone has no android_metadata table',
      );
      expect(
        tableNames(db),
        contains('sqlite_sequence'),
        reason: 'persistence.schema-legacy-tables#4: sqlite_sequence is '
            'present at version 25 as a side effect of AUTOINCREMENT',
      );

      final v9 = openMigratedDatabase(version: 9);
      addTearDown(v9.close);
      expect(
        tableNames(v9),
        contains('sqlite_sequence'),
        reason: 'persistence.schema-legacy-tables#4: SQLite creates '
            'sqlite_sequence as soon as migration 09 declares the first '
            'AUTOINCREMENT table',
      );
    });
  });

  group('persistence.schema-indexes', () {
    test('migration 13 creates the four original indexes (#1)', () {
      final before = openMigratedDatabase(version: 12);
      addTearDown(before.close);
      expect(
        declaredIndexNames(before),
        isEmpty,
        reason: 'persistence.schema-indexes#1: there is no named index before '
            'migration 13',
      );

      final db = openMigratedDatabase(version: 13);
      addTearDown(db.close);
      expect(
        declaredIndexNames(db),
        <String>{
          'idx_score_habit_timestamp',
          'idx_checkmark_habit_timestamp',
          'idx_repetitions_habit_timestamp',
          'idx_streak_habit_end',
        },
        reason: 'persistence.schema-indexes#1: migration 13 creates exactly '
            'four indexes',
      );

      expect(
        indexTable(db, 'idx_score_habit_timestamp'),
        'Score',
        reason: 'persistence.schema-indexes#1: idx_score_habit_timestamp is on '
            'Score',
      );
      expect(
        indexColumns(db, 'idx_score_habit_timestamp'),
        <String>['habit', 'timestamp'],
        reason: 'persistence.schema-indexes#1: idx_score_habit_timestamp '
            'indexes (habit, timestamp)',
      );
      expect(
        indexTable(db, 'idx_checkmark_habit_timestamp'),
        'Checkmarks',
        reason: 'persistence.schema-indexes#1: idx_checkmark_habit_timestamp '
            'is on Checkmarks',
      );
      expect(
        indexColumns(db, 'idx_checkmark_habit_timestamp'),
        <String>['habit', 'timestamp'],
        reason: 'persistence.schema-indexes#1: idx_checkmark_habit_timestamp '
            'indexes (habit, timestamp)',
      );
      expect(
        indexTable(db, 'idx_repetitions_habit_timestamp'),
        'Repetitions',
        reason: 'persistence.schema-indexes#1: idx_repetitions_habit_timestamp '
            'is on Repetitions',
      );
      expect(
        indexColumns(db, 'idx_repetitions_habit_timestamp'),
        <String>['habit', 'timestamp'],
        reason: 'persistence.schema-indexes#1: idx_repetitions_habit_timestamp '
            'indexes (habit, timestamp)',
      );
      expect(
        indexTable(db, 'idx_streak_habit_end'),
        'Streak',
        reason: 'persistence.schema-indexes#1: idx_streak_habit_end is on '
            'Streak',
      );
      expect(
        indexColumns(db, 'idx_streak_habit_end'),
        <String>['habit', 'end'],
        reason: 'persistence.schema-indexes#1: idx_streak_habit_end indexes '
            '(habit, end)',
      );

      expect(
        indexIsUnique(db, 'Repetitions', 'idx_repetitions_habit_timestamp'),
        isFalse,
        reason: 'persistence.schema-indexes#1: at version 13 the repetitions '
            'index is NOT unique',
      );
      db.run('insert into Repetitions(habit, timestamp) values (1, 100)');
      db.run('insert into Repetitions(habit, timestamp) values (1, 100)');
      expect(
        countRows(db, 'Repetitions'),
        2,
        reason: 'persistence.schema-indexes#1: the non-unique repetitions '
            'index accepts a duplicated (habit, timestamp) pair at version 13',
      );
    });

    test('migration 17 rebuilds Score and recreates its index (#2)', () {
      final commands = SQLParser.parse(migrationSql[17]!);
      expect(
        commands.first,
        'drop table Score',
        reason: 'persistence.schema-indexes#2: migration 17 drops the Score '
            'table first',
      );
      expect(
        commands,
        contains('create index idx_score_habit_timestamp on Score(habit, '
            'timestamp)'),
        reason: 'persistence.schema-indexes#2: migration 17 recreates '
            'idx_score_habit_timestamp on Score(habit, timestamp)',
      );

      final before = openMigratedDatabase(version: 16);
      addTearDown(before.close);
      expect(
        columnTypes(before, 'Score')['score'],
        'integer',
        reason: 'persistence.schema-indexes#2: before migration 17 the Score '
            'table stores an integer score',
      );
      expect(
        declaredIndexNames(before),
        contains('idx_score_habit_timestamp'),
        reason: 'persistence.schema-indexes#2: idx_score_habit_timestamp '
            'exists at version 16, created by migration 13',
      );

      final db = openMigratedDatabase(version: 17);
      addTearDown(db.close);
      expect(
        columnTypes(db, 'Score')['score'],
        'real',
        reason: 'persistence.schema-indexes#2: migration 17 recreates Score '
            'with a real score column',
      );
      expect(
        declaredIndexNames(db),
        contains('idx_score_habit_timestamp'),
        reason: 'persistence.schema-indexes#2: dropping the table dropped the '
            'index with it, so migration 17 has to recreate it',
      );
      expect(
        indexTable(db, 'idx_score_habit_timestamp'),
        'Score',
        reason: 'persistence.schema-indexes#2: the recreated index is on the '
            'new Score table',
      );
      expect(
        indexColumns(db, 'idx_score_habit_timestamp'),
        <String>['habit', 'timestamp'],
        reason: 'persistence.schema-indexes#2: the recreated index covers '
            '(habit, timestamp)',
      );
    });

    test('migration 20 implicitly drops three of the four indexes (#3)', () {
      expect(
        migrationSql[20]!.toLowerCase(),
        isNot(contains('drop index')),
        reason: 'persistence.schema-indexes#3: migration 20 never mentions an '
            'index — dropping the tables is what removes them',
      );

      final before = openMigratedDatabase(version: 19);
      addTearDown(before.close);
      expect(
        declaredIndexNames(before),
        <String>{
          'idx_score_habit_timestamp',
          'idx_checkmark_habit_timestamp',
          'idx_repetitions_habit_timestamp',
          'idx_streak_habit_end',
        },
        reason: 'persistence.schema-indexes#3: all four indexes still exist at '
            'version 19',
      );

      final db = openMigratedDatabase(version: 20);
      addTearDown(db.close);
      expect(
        declaredIndexNames(db),
        <String>{'idx_repetitions_habit_timestamp'},
        reason: 'persistence.schema-indexes#3: dropping Checkmarks, Streak and '
            'Score implicitly drops idx_checkmark_habit_timestamp, '
            'idx_streak_habit_end and idx_score_habit_timestamp',
      );
    });

    test('migration 22 replaces the repetitions index with a unique one (#4)',
        () {
      final commands = SQLParser.parse(migrationSql[22]!);
      expect(
        commands,
        contains('drop index if exists idx_repetitions_habit_timestamp'),
        reason: 'persistence.schema-indexes#4: migration 22 executes '
            '`drop index if exists idx_repetitions_habit_timestamp`',
      );
      expect(
        commands.any(
          (c) => c.startsWith(
            'create unique index idx_repetitions_habit_timestamp on '
            'Repetitions(',
          ),
        ),
        isTrue,
        reason: 'persistence.schema-indexes#4: migration 22 then executes '
            '`create unique index idx_repetitions_habit_timestamp on '
            'Repetitions(habit, timestamp)`',
      );
      expect(
        commands.indexOf('drop index if exists idx_repetitions_habit_timestamp'),
        lessThan(
          commands.indexWhere(
            (c) => c.startsWith('create unique index '
                'idx_repetitions_habit_timestamp'),
          ),
        ),
        reason: 'persistence.schema-indexes#4: the drop comes before the '
            'create',
      );

      final before = openMigratedDatabase(version: 21);
      addTearDown(before.close);
      expect(
        indexIsUnique(before, 'Repetitions', 'idx_repetitions_habit_timestamp'),
        isFalse,
        reason: 'persistence.schema-indexes#4: at version 21 the index left by '
            'migration 13 is still non-unique',
      );
      before.run('insert into Repetitions(habit, timestamp, value) '
          'values (1, 100, 2)');
      before.run('insert into Repetitions(habit, timestamp, value) '
          'values (1, 100, 2)');
      expect(
        countRows(before, 'Repetitions'),
        2,
        reason: 'persistence.schema-indexes#4: duplicates are still accepted '
            'at version 21',
      );

      final db = openMigratedDatabase(version: 22);
      addTearDown(db.close);
      expect(
        indexIsUnique(db, 'Repetitions', 'idx_repetitions_habit_timestamp'),
        isTrue,
        reason: 'persistence.schema-indexes#4: migration 22 recreates the '
            'index as UNIQUE',
      );
      expect(
        indexColumns(db, 'idx_repetitions_habit_timestamp'),
        <String>['habit', 'timestamp'],
        reason: 'persistence.schema-indexes#4: the unique index covers '
            '(habit, timestamp)',
      );
      db.run("insert into Habits(id, name) values (1, 'Meditate')");
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values (1, 100, 2)');
      expect(
        () => db.run('insert into Repetitions(habit, timestamp, value) '
            'values (1, 100, 2)'),
        throwsUniqueConstraintViolation,
        reason: 'persistence.schema-indexes#4: after migration 22 a duplicated '
            '(habit, timestamp) pair violates the unique index',
      );
    });

    test('version 25 has exactly one application-created index (#5)', () {
      final db = openMigratedDatabase();
      addTearDown(db.close);

      expect(
        declaredIndexNames(db),
        <String>{'idx_repetitions_habit_timestamp'},
        reason: 'persistence.schema-indexes#5: idx_repetitions_habit_timestamp '
            'is the only application-created index at version 25',
      );
      expect(
        allIndexNames(db),
        <String>{'idx_repetitions_habit_timestamp'},
        reason: 'persistence.schema-indexes#5: no SQLite auto-index exists '
            'either — the index list at version 25 is a single entry',
      );
      expect(
        indexTable(db, 'idx_repetitions_habit_timestamp'),
        'Repetitions',
        reason: 'persistence.schema-indexes#5: it is on Repetitions',
      );
      expect(
        indexColumns(db, 'idx_repetitions_habit_timestamp'),
        <String>['habit', 'timestamp'],
        reason: 'persistence.schema-indexes#5: it covers (habit, timestamp)',
      );
      expect(
        indexIsUnique(db, 'Repetitions', 'idx_repetitions_habit_timestamp'),
        isTrue,
        reason: 'persistence.schema-indexes#5: it is UNIQUE',
      );
      db.run("insert into Habits(id, name) values (1, 'Meditate')");
      db.run('insert into Repetitions(habit, timestamp, value) '
          'values (1, 100, 2)');
      expect(
        () => db.run('insert into Repetitions(habit, timestamp, value) '
            'values (1, 100, 2)'),
        throwsUniqueConstraintViolation,
        reason: 'persistence.schema-indexes#5: the surviving index enforces '
            'uniqueness at version 25',
      );
    });
  });
}
