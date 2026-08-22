/// Shared test fixtures for the persistence slices.
///
/// The Kotlin counterpart is
/// `uhabits-core/src/jvmTest/java/org/isoron/platform/io/TestDatabaseHelper.kt`.
/// Both helpers are synchronous: `package:sqlite3` is a blocking FFI driver, so
/// no test needs to await anything.
library;

import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';

/// A fresh, empty in-memory database with no schema and `user_version` 0.
///
/// Close it with `db.close()` when the test is done.
Database openMemoryDatabase() => Sqlite3Database.memory();

/// A fresh in-memory database stamped to `user_version` 8 and migrated up to
/// [version] with the bundled [migrationSql] scripts.
///
/// This is how the Kotlin app creates a new database: there are no migration
/// files below 09, so stamping 8 makes migration 09 the effective CREATE TABLE
/// script. Defaults to the current schema version (25).
///
/// Close it with `db.close()` when the test is done.
Database openMigratedDatabase({int version = databaseVersion}) {
  final db = openMemoryDatabase();
  db.setVersion(8);
  db.migrateTo(version, (v) => migrationSql[v]!);
  return db;
}
