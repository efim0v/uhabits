import 'package:test/test.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';

/// Guards against a defect that host tests cannot see.
///
/// In SQL a double-quoted token is an identifier, not a string. SQLite has
/// always accepted `""` as a string anyway — the "double-quoted string literal
/// misfeature" — but modern builds compile with SQLITE_DQS=1, which keeps that
/// tolerance in DDL and drops it in DML.
///
/// macOS ships a permissive libsqlite3, so `dart test` accepted
/// `update Habits set description = ""` for as long as it existed. The build
/// bundled into the iOS app does not, and migration 23 threw during startup,
/// which killed the app before runApp() and left a blank white screen.
///
/// The generator rewrites these to standard single quotes; this test is what
/// keeps them from coming back.
void main() {
  test('no migration relies on double-quoted string literals', () {
    final offenders = <String>[];
    migrationSql.forEach((version, sql) {
      if (sql.contains('"')) offenders.add('migration $version');
    });
    expect(offenders, isEmpty,
        reason: 'double-quoted literals are rejected in DML by the SQLite '
            'build shipped on iOS and Android');
  });

  test('the empty string default survived the rewrite', () {
    expect(migrationSql[18], contains("default ''"));
    expect(migrationSql[23], contains("set description = ''"));
  });
}
