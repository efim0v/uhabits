/// A migration that fails part-way must leave the file exactly as it was.
///
/// Upstream this is not `Database.migrateTo`'s doing. `HabitsDatabaseOpener`
/// extends `android.database.sqlite.SQLiteOpenHelper`, and the framework wraps
/// the whole upgrade — `beginTransaction()`, `onUpgrade(...)`, `setVersion(...)`,
/// `setTransactionSuccessful()`, `endTransaction()` — in one transaction. A
/// statement that throws therefore rolls the schema back to what it was, the
/// app crashes once, and the next launch retries the upgrade from a clean file.
///
/// The port has no SQLiteOpenHelper, so the atomicity has to live in
/// `migrateTo` itself (`feedback.migrations-are-not-atomic#1`).
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';

import '../helpers/test_database.dart';

const String rule = 'feedback.migrations-are-not-atomic#1 — a migration that '
    'fails part-way must leave the database exactly as it was, because the '
    'next launch replays that migration from its first statement.';

void main() {
  test('a failing migration leaves neither schema nor version behind', () {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    db.setVersion(8);

    // Two statements: the first succeeds, the second is invalid. This is the
    // exact shape of the crash the project already hit once — migration 23's
    // `alter table ... add column question` landing while a later statement of
    // the same script failed.
    expect(
      () => db.migrateTo(9, (v) => '''
        create table Marker (id integer primary key);
        this is not valid sql;
      '''),
      throwsA(anything),
      reason: '$rule The failure still has to be loud.',
    );

    expect(db.getVersion(), 8,
        reason: '$rule user_version must not move for a migration that failed.');
    expect(
      db.querySingle<int>(
        "select count(*) from sqlite_master where name = 'Marker'",
        const <String>[],
        (stmt) => stmt.getInt(0),
      ),
      0,
      reason: '$rule The statements that did run must be rolled back, or the '
          'retry fails on the DDL it already applied and the file is dead.',
    );
  });

  test('a later version failing rolls back the earlier ones too', () {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    db.setVersion(8);

    expect(
      () => db.migrateTo(10, (v) => switch (v) {
            9 => 'create table Nine (id integer primary key);',
            _ => 'oops;',
          }),
      throwsA(anything),
      reason: rule,
    );

    expect(db.getVersion(), 8,
        reason: '$rule Android wraps the whole upgrade, not one version of it, '
            'in a single transaction.');
    expect(
      db.querySingle<int>(
        "select count(*) from sqlite_master where name = 'Nine'",
        const <String>[],
        (stmt) => stmt.getInt(0),
      ),
      0,
      reason: rule,
    );
  });

  test('the retry after a failure succeeds', () {
    final db = openMemoryDatabase();
    addTearDown(db.close);
    db.setVersion(8);

    var attempt = 0;
    String load(int v) {
      attempt++;
      return attempt == 1
          ? 'create table Marker (id integer primary key); bad sql;'
          : 'create table Marker (id integer primary key);';
    }

    expect(() => db.migrateTo(9, load), throwsA(anything), reason: rule);
    db.migrateTo(9, load);

    expect(db.getVersion(), 9, reason: rule);
    expect(
      db.querySingle<int>(
        "select count(*) from sqlite_master where name = 'Marker'",
        const <String>[],
        (stmt) => stmt.getInt(0),
      ),
      1,
      reason: '$rule This is the whole point: the next launch has to be able to '
          'apply the same migration again.',
    );
  });

  test('the real migrations still apply, nested transaction and all', () {
    // Migration 22 carries its own `begin transaction` / `commit` around the
    // Repetitions rebuild. sqlite refuses a nested BEGIN outright, so the
    // runner has to translate those markers the way Android's SQLiteSession
    // does — into a savepoint.
    final db = openMemoryDatabase();
    addTearDown(db.close);
    db.setVersion(8);

    db.migrateTo(databaseVersion, (v) => migrationSql[v]!);

    expect(db.getVersion(), databaseVersion, reason: rule);
    expect(
      db.querySingle<int>(
        "select count(*) from sqlite_master where name = 'Repetitions'",
        const <String>[],
        (stmt) => stmt.getInt(0),
      ),
      1,
      reason: '$rule Migration 22 rebuilds this table inside its own '
          'transaction markers.',
    );
    expect(db.queryInt('pragma foreign_keys'), 1,
        reason: '$rule persistence.migration-v22#6 — the pragma is a no-op '
            'inside a transaction, so the runner has to let it take effect '
            'anyway.');
  });
}
