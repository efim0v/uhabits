import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Port of `org.isoron.uhabits.database.UnsupportedDatabaseVersionException`:
/// the file on disk was written by a build this one cannot work with.
///
/// `HabitsDatabaseOpener.onUpgrade` throws it when `db.version < 8` — older
/// than the first migration script, so there is nothing to bring it forward
/// with — and `onDowngrade` throws it unconditionally, so a file newer than
/// [databaseVersion] is refused rather than silently used.
///
/// Upstream it is `class UnsupportedDatabaseVersionException : RuntimeException()`
/// — a plain exception with no message (`persistence.android-opener#6`). The
/// version is kept here only so a log line can say what was found; nothing
/// branches on it.
class UnsupportedDatabaseVersionException implements Exception {
  const UnsupportedDatabaseVersionException(this.foundVersion);

  /// The `user_version` the file carried.
  final int foundVersion;

  @override
  String toString() =>
      'UnsupportedDatabaseVersionException(user_version $foundVersion, '
      'supported 8..$databaseVersion)';
}

/// The file exists but sqlite refuses to read it as a database: a zeroed
/// header (`SqliteException(26)`, "file is not a database"), a truncated or
/// half-synced copy (`SqliteException(11)`, "database disk image is
/// malformed"), or a page that went bad under a killed write.
///
/// Android has no exception of its own for this because it never surfaces one:
/// `HabitsDatabaseOpener` passes a null `errorHandler` to `SQLiteOpenHelper`
/// (HabitsDatabaseOpener.kt:35), so `SQLiteDatabase.open()` catches
/// `SQLiteDatabaseCorruptException` — what the framework maps SQLITE_NOTADB and
/// SQLITE_CORRUPT to — hands the file to `DefaultDatabaseErrorHandler
/// .onCorruption()`, which *deletes* it, and reopens with
/// `CREATE_IF_NECESSARY`. The user loses the data and the app starts empty.
///
/// This type is how the same outcome is reached here: [AppDatabase.open]
/// raises it, and `AppScope.boot` answers by setting the file aside and
/// opening a fresh one (`audit10.a-corrupt-database-file-recovers#1`).
class UnreadableDatabaseException implements Exception {
  const UnreadableDatabaseException(this.path, this.cause);

  /// The file that could not be read.
  final String path;

  /// The driver error that came back — kept so the log line can name the
  /// SQLite result code, which is the only clue to *how* the file broke.
  final Object cause;

  @override
  String toString() => 'UnreadableDatabaseException($path): $cause';
}

/// Opens the app's habit database, creating and migrating it when needed.
///
/// A brand-new file is stamped at user_version 8 and then migrated up, because
/// the Kotlin app has no migration script below 09 — script 09 IS the schema.
/// Doing the same here keeps one code path for fresh installs and for databases
/// imported from Loop.
///
/// A file outside the range 8..[databaseVersion] is not opened at all: it
/// raises [UnsupportedDatabaseVersionException], exactly as `onUpgrade`'s
/// `if (db.version < 8) throw` and `onDowngrade`'s unconditional throw do
/// (`persistence.android-opener#4`, `#5`). One sqlite cannot read raises
/// [UnreadableDatabaseException]. `AppScope.boot` answers both by setting the
/// file aside — the first is a deliberate divergence from Kotlin's crash loop
/// (`audit10.the-invalid-quarantine-is-the-ports-own#1`), the second matches
/// the framework's own delete-and-recreate
/// (`audit10.a-corrupt-database-file-recovers#1`).
class AppDatabase {
  AppDatabase._(this.database, this.path);

  final Database database;
  final String path;

  /// The version `onCreate` stamps before replaying migrations 09..25, and so
  /// also the oldest version `onUpgrade` will accept.
  static const int schemaBaseVersion = 8;

  /// `DatabaseUtils.getDatabaseFile(context)`, with its parent created.
  ///
  /// Split out of [open] because the recovery path needs the path of the file
  /// that failed, and the only thing that knows it is this resolution.
  static Future<File> resolveFile() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, databaseFilename));
    await file.parent.create(recursive: true);
    return file;
  }

  static Future<AppDatabase> open() async {
    final file = await resolveFile();
    return AppDatabase._(openAndMigrate(file.path), file.path);
  }

  /// Opens [path] and brings it up to [databaseVersion]. Exposed separately so
  /// tests and the importer can drive it against an arbitrary file.
  ///
  /// Throws [UnsupportedDatabaseVersionException] for a file this build cannot
  /// use, and [UnreadableDatabaseException] for one sqlite refuses to read at
  /// all, leaving it closed and untouched in both cases.
  static Database openAndMigrate(String path) {
    // The opener mirrors Android's OPEN_READWRITE and deliberately refuses to
    // create a missing file, so a first launch has to place an empty one; an
    // empty file is a valid empty SQLite database.
    final file = File(path);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    final Database database;
    try {
      // `Sqlite3DatabaseOpener.open` reads `PRAGMA user_version` on the way
      // out, so this is also where a file that is not a database announces
      // itself — the same moment `SQLiteDatabase.open()` finds out upstream.
      database = const Sqlite3DatabaseOpener().open(path);
    } on SqliteException catch (error) {
      throw _corruptionOr(path, error);
    }
    try {
      final version = database.getVersion();
      // 0 is the empty file just created above, and any file Loop never wrote:
      // `onCreate` stamps 8 and lets the migrations build the schema.
      if (version == 0) {
        database.setVersion(schemaBaseVersion);
      } else if (version < schemaBaseVersion || version > databaseVersion) {
        // `onUpgrade`'s `if (db.version < 8) throw` and `onDowngrade`'s
        // unconditional throw. Closed first: the caller is about to rename the
        // file, and a handle held open on it is a handle on the renamed file.
        database.close();
        throw UnsupportedDatabaseVersionException(version);
      }
      database.migrateTo(databaseVersion, (version) {
        final sql = migrationSql[version];
        if (sql == null) {
          throw StateError('No migration script for version $version');
        }
        return sql;
      });
    } on SqliteException catch (error) {
      // Damage far enough into the file that the header still reads: sqlite
      // only notices at the first statement that touches a broken page, which
      // here is a migration. Android's handler is installed on the connection
      // and fires at that point too, so the outcome has to be the same one.
      _closeQuietly(database);
      throw _corruptionOr(path, error);
    }
    return database;
  }

  /// `SQLITE_CORRUPT`, the result code for a file whose pages no longer make a
  /// database.
  static const int _sqliteCorrupt = 11;

  /// `SQLITE_NOTADB`, the result code for a file whose 16-byte header is not
  /// SQLite's at all.
  static const int _sqliteNotADb = 26;

  /// Turns the driver error into [UnreadableDatabaseException] when — and only
  /// when — it is one of the two result codes Android maps to
  /// `SQLiteDatabaseCorruptException`, which is the single exception
  /// `SQLiteDatabase.open()` hands to the error handler that deletes the file
  /// (`android_database_SQLiteCommon.cpp`: `case SQLITE_CORRUPT: case
  /// SQLITE_NOTADB:`). Every other sqlite failure — a locked file, a denied
  /// permission, a broken migration script — propagates unchanged, exactly as
  /// `SQLiteOpenHelper.getDatabaseLocked` rethrows it for a writable open.
  static Object _corruptionOr(String path, SqliteException error) {
    if (error.resultCode == _sqliteCorrupt ||
        error.resultCode == _sqliteNotADb) {
      return UnreadableDatabaseException(path, error);
    }
    return error;
  }

  /// The handle is being abandoned because the file under it is unusable;
  /// failing to close it must not replace the diagnosis with a second error.
  static void _closeQuietly(Database database) {
    try {
      database.close();
    } on Object {
      // Nothing left to do with it either way.
    }
  }

  void close() => database.close();
}
