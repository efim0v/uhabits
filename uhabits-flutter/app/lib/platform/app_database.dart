import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Opens the app's habit database, creating and migrating it when needed.
///
/// A brand-new file is stamped at user_version 8 and then migrated up, because
/// the Kotlin app has no migration script below 09 — script 09 IS the schema.
/// Doing the same here keeps one code path for fresh installs and for databases
/// imported from Loop.
class AppDatabase {
  AppDatabase._(this.database, this.path);

  final Database database;
  final String path;

  static const int _schemaBaseVersion = 8;

  static Future<AppDatabase> open() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, databaseFilename));
    await file.parent.create(recursive: true);
    return AppDatabase._(openAndMigrate(file.path), file.path);
  }

  /// Opens [path] and brings it up to [databaseVersion]. Exposed separately so
  /// tests and the importer can drive it against an arbitrary file.
  static Database openAndMigrate(String path) {
    // The opener mirrors Android's OPEN_READWRITE and deliberately refuses to
    // create a missing file, so a first launch has to place an empty one; an
    // empty file is a valid empty SQLite database.
    final file = File(path);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    final database = const Sqlite3DatabaseOpener().open(path);
    if (database.getVersion() == 0) {
      database.setVersion(_schemaBaseVersion);
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
