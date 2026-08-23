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

/// Opens the app's habit database, creating and migrating it when needed.
///
/// A brand-new file is stamped at user_version 8 and then migrated up, because
/// the Kotlin app has no migration script below 09 — script 09 IS the schema.
/// Doing the same here keeps one code path for fresh installs and for databases
/// imported from Loop.
///
/// A file outside the range 8..[databaseVersion] is not opened at all: it
/// raises [UnsupportedDatabaseVersionException], which `AppScope.boot` answers
/// by setting the file aside (`persistence.android-opener#4`, `#5`).
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
  /// use, leaving it closed and untouched.
  static Database openAndMigrate(String path) {
    // The opener mirrors Android's OPEN_READWRITE and deliberately refuses to
    // create a missing file, so a first launch has to place an empty one; an
    // empty file is a valid empty SQLite database.
    final file = File(path);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    final database = const Sqlite3DatabaseOpener().open(path);
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
    return database;
  }

  void close() => database.close();
}
