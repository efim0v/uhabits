/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/database/AutoBackup.kt.
///
/// One automatic copy of the database per day, kept in the app-private
/// `Backups` folder, with the five newest files retained and everything older
/// deleted.
///
/// ## What is ported and what is not
///
/// `AutoBackup.run` has two destinations. The public one is a Storage Access
/// Framework tree URI (`publicBackupFolder`) reached through `DocumentFile`;
/// nothing in Flutter — and nothing on iOS — corresponds to it, so this port
/// implements the *other* branch: the one Android takes when the preference is
/// unset, which is also the only branch this app's settings screen can ever
/// produce (its `publicBackupFolder` row is inert). The two branches differ
/// only in how they list and create files; the rotation and freshness
/// arithmetic — which is the part with all the edges — is shared, and it is
/// what lives here.
///
/// ## The order matters
///
/// `newestTimestamp` is read BEFORE anything is deleted, and the deletion runs
/// BEFORE the freshness test. Both are load-bearing:
///
///  * reading first means rotation can never make a fresh backup look stale
///    (delete the newest five and the sixth would suddenly be "newest");
///  * deleting first means a day on which no new backup is written still
///    prunes the old ones.
library;

// The core io and time layers are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches the commands layer.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';

import 'flutter_files.dart';

/// One entry of the backup directory, paired with its modification time.
///
/// `java.io.File.lastModified()` returns 0 for a file that cannot be stat'ed;
/// `dart:io` throws instead, so the read is guarded and answers 0 the same way.
class _BackupFile {
  _BackupFile(this.file, this.lastModified);

  final File file;
  final int lastModified;

  static _BackupFile of(FileSystemEntity entity) {
    final file = File(entity.path);
    int lastModified;
    try {
      lastModified = file.lastModifiedSync().millisecondsSinceEpoch;
    } on FileSystemException {
      lastModified = 0;
    }
    return _BackupFile(file, lastModified);
  }
}

/// What one [AutoBackup.run] did, so a caller — or a test — can see the
/// decision rather than infer it from the directory afterwards.
class AutoBackupResult {
  const AutoBackupResult({
    required this.directory,
    required this.newestTimestamp,
    required this.deleted,
    required this.written,
  });

  /// The `Backups` directory, or null when none could be obtained — in which
  /// case the whole run did nothing.
  final String? directory;

  /// `files.lastOrNull()?.lastModified() ?: 0L`, captured before any deletion.
  final int newestTimestamp;

  /// The paths rotation removed, oldest first.
  final List<String> deleted;

  /// The backup written by this run, or null when a fresh one already existed.
  final String? written;
}

/// `AutoBackup(context)`.
class AutoBackup {
  AutoBackup({
    required this.databasePath,
    required this.dirFinder,
    Logging? logging,
    DateTime Function()? clock,
    int Function()? localTime,
  })  : _logger = (logging ?? StandardLogging()).getLogger(_loggerName),
        _clock = clock ?? DateTime.now,
        _localTime = localTime ?? DateUtils.getLocalTime;

  static const String _loggerName = 'AutoBackup';

  /// `AutoBackup.run(keep: Int = 5)`.
  static const int defaultKeep = 5;

  /// `DatabaseUtils.getDatabaseFile(context)`. Null only when the app was
  /// booted on a database with no file behind it, which happens in tests.
  final String? databasePath;

  /// `AndroidDirFinder(context)`.
  final HabitsDirFinder dirFinder;

  final Logger _logger;

  /// `System.currentTimeMillis()`, which is what names the file.
  final DateTime Function() _clock;

  /// `DateUtils.getLocalTime()`, which is what the freshness test compares
  /// against. Upstream reads the two from different clocks — see the note on
  /// `io.auto-backup` in the ledger — and so does this.
  final int Function() _localTime;

  Future<AutoBackupResult> run({int keep = defaultKeep}) async {
    _logger.info('Starting automatic backups...');
    // The `publicBackupFolder` branch would go here. With the Storage Access
    // Framework gone, the preference can never be set, so the fallback is the
    // only path: AndroidDirFinder(context).getFilesDir("Backups"), and a null
    // answer means the whole run does nothing.
    final dir = dirFinder.getFilesDir(HabitsDirFinder.backupsDirName);
    if (dir == null) {
      return const AutoBackupResult(
        directory: null,
        newestTimestamp: 0,
        deleted: <String>[],
        written: null,
      );
    }
    return _runInPrivateDir(dir.pathString, keep);
  }

  Future<AutoBackupResult> _runInPrivateDir(String dir, int keep) async {
    // `dir.listFiles()?.toMutableList() ?: mutableListOf()` — every entry, with
    // no name filtering at all, and an empty list when the directory does not
    // exist or cannot be read.
    final files = <_BackupFile>[];
    final directory = Directory(dir);
    if (directory.existsSync()) {
      for (final entity in directory.listSync()) {
        files.add(_BackupFile.of(entity));
      }
    }
    // `files.sortBy { it.lastModified() }` — ascending, so the newest is last.
    files.sort((a, b) => a.lastModified.compareTo(b.lastModified));

    // Read BEFORE the deletion, so rotation cannot influence freshness.
    final newestTimestamp = files.isEmpty ? 0 : files.last.lastModified;

    final deleted = _removeOldest(files, keep);

    final now = _localTime();
    String? written;
    if (now - newestTimestamp > DateUtils.dayLength) {
      written = await saveDatabaseCopy(
        databasePath: databasePath!,
        dir: LocalUserFile(dir),
        now: _clock(),
      );
    } else {
      _logger.info('Fresh backup found (timestamp=$newestTimestamp)');
    }
    return AutoBackupResult(
      directory: dir,
      newestTimestamp: newestTimestamp,
      deleted: deleted,
      written: written,
    );
  }

  /// `for (k in 0 until (files.size - keep))`: with `files.size <= keep` the
  /// range is empty and nothing is deleted.
  List<String> _removeOldest(List<_BackupFile> files, int keep) {
    final deleted = <String>[];
    for (var k = 0; k < files.length - keep; k++) {
      final file = files[k].file;
      _logger.info('Removing ${file.path}');
      try {
        file.deleteSync();
        deleted.add(file.path);
      } on FileSystemException {
        // `File.delete()` returns false rather than throwing in Java; a file
        // that could not be removed is simply still there next time.
      }
    }
    return deleted;
  }
}

/// The `taskRunner` block `ListHabitsActivity.onResume` wraps the backup in.
///
/// ```kotlin
/// taskRunner.execute {
///     try {
///         AutoBackup(this).run()
///         widgetUpdater.updateWidgets()
///     } catch (e: Exception) {
///         Log.e("ListHabitActivity", "TaskRunner failed", e)
///     }
/// }
/// ```
///
/// Everything about it is in the `catch`: a backup that fails — no writable
/// directory, a full disk, a database file that vanished — must never take the
/// app down, and it must never stop the screen from resuming.
class AutoBackupTask extends Task {
  AutoBackupTask(this._backup, {int keep = AutoBackup.defaultKeep, Logging? logging})
      : _keep = keep,
        _logger = (logging ?? StandardLogging()).getLogger(_loggerName);

  static const String _loggerName = 'ListHabitActivity';

  final AutoBackup _backup;

  final int _keep;

  final Logger _logger;

  AutoBackupResult? result;

  Object? failure;

  @override
  Future<void> doInBackground() async {
    try {
      result = await _backup.run(keep: _keep);
    } on Object catch (error) {
      failure = error;
      _logger.error('TaskRunner failed');
      _logger.error(error);
    }
  }
}
