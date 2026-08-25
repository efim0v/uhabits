/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/AbstractImporter.kt
/// and of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/utils/FileExtensions.kt
/// (`isSQLite3File`), plus the `canHandle` half of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt.
///
/// Kotlin keeps `isSQLite3File` in `core/utils/FileExtensions.kt`, next to the
/// three importers that use it; it lives here because it is the shared gate of
/// every database importer and `AbstractImporter` is the file all of them
/// already import.
///
/// `LoopDBImporter` itself — the class, and its `importHabitsFromFile`, which
/// migrates the backup and copies its habits over — is the io.loop-db-migration
/// slice's file. Only the detection heuristic (io.loop-db-detection) lives
/// here, as [loopDBCanHandle], so that the class can be written as
///
/// ```dart
/// @override
/// Future<bool> canHandle(UserFile file) =>
///     loopDBCanHandle(file, opener: opener, logger: logger);
/// ```
///
/// which is the Kotlin body line for line.
library;

import 'dart:convert';

import '../database/database.dart';
import '../database/extension_migrations.dart';
import '../database/migrations.g.dart';
import 'files.dart';
import 'logging.dart';

/// Port of `AbstractImporter`.
///
/// Exactly two members, both `suspend` in Kotlin and therefore
/// `Future`-returning here.
abstract class AbstractImporter {
  Future<bool> canHandle(UserFile file);

  Future<void> importHabitsFromFile(UserFile file);
}

/// Port of `suspend fun isSQLite3File(file: UserFile): Boolean`.
///
/// Reads the first 16 bytes of the file and looks for the 15-character SQLite
/// magic. `ByteArray.decodeToString()` replaces malformed sequences with the
/// replacement character instead of throwing, which is what
/// `allowMalformed: true` does here, so an arbitrary binary file simply fails
/// the `startsWith` check.
Future<bool> isSQLite3File(UserFile file) async {
  if (!await file.exists()) return false;
  final header = await file.readBytes(16);
  return utf8
      .decode(header, allowMalformed: true)
      .startsWith('SQLite format 3');
}

/// The body of `LoopDBImporter.canHandle`.
///
/// Both checks always run — the version check is not skipped when the table
/// check has already failed — and the database is closed before returning, on
/// either path.
Future<bool> loopDBCanHandle(
  UserFile file, {
  required DatabaseOpener opener,
  required Logger logger,
}) async {
  if (!await isSQLite3File(file)) return false;
  final db = opener.open(file.pathString);
  var canHandle = true;
  final count = db.querySingle(
    "select count(*) from SQLITE_MASTER where name='Habits' "
    "or name='Repetitions'",
    const <String>[],
    (stmt) => stmt.getInt(0),
  );
  if (count == null || count != 2) {
    logger.error(cannotHandleFileTablesNotFound);
    canHandle = false;
  }
  // A version this build cannot migrate from. The extension versions widen
  // what is accepted, but the message still names the original's last version:
  // every file the original can produce is judged exactly as it judges them.
  if (!isKnownDatabaseVersion(db.getVersion())) {
    logger.error(incompatibleVersionMessage(db.getVersion(), databaseVersion));
    canHandle = false;
  }
  db.close();
  return canHandle;
}
