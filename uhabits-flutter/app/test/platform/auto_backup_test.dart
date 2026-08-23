/// The automatic daily backup: where it writes, what it deletes, and when it
/// decides there is nothing to do.
///
/// Ported from
/// uhabits-android/src/main/java/org/isoron/uhabits/database/AutoBackup.kt,
/// uhabits-android/src/main/java/org/isoron/uhabits/AndroidDirFinder.kt and
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/FileUtils.kt, with
/// the scenarios of
/// uhabits-android/src/androidTest/java/org/isoron/uhabits/database/AutoBackupTest.kt.
///
/// Everything here runs against a real directory in a temporary folder, with
/// real files whose modification times are set by hand — the rotation and the
/// freshness test are both `lastModified()` arithmetic, and a fake filesystem
/// would only test the fake.
///
/// ## What is deliberately not asserted
///
/// `io.auto-backup#2`, `#6` and `#12` are the Storage Access Framework branch:
/// a `publicBackupFolder` tree URI, `DocumentFile.fromTreeUri`, the
/// `^Loop Habits Backup .+\.db$` filter that only the public listing applies,
/// and `dir.createFile("application/octet-stream", name)`. There is no
/// cross-platform equivalent and this port drops the preference entirely, so
/// those three rule ids appear nowhere in this file and the coverage tool keeps
/// reporting them as the open work they are.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/auto_backup.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/settings/data_actions.dart';
import 'package:uhabits_core/src/io/generic_importer.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:flutter/widgets.dart' show Rect;

void main() {
  late Directory tempDir;
  late Directory externalDir;
  late String databasePath;
  late StringBuffer log;
  late Logging logging;

  /// `DateUtils.getLocalTime()` for the freshness test, and
  /// `System.currentTimeMillis()` for the file name.
  late int localTime;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_auto_backup');
    externalDir = Directory('${tempDir.path}/external')
      ..createSync(recursive: true);
    databasePath = '${tempDir.path}/uhabits.db';
    File(databasePath).writeAsBytesSync(<int>[1, 2, 3, 4]);
    log = StringBuffer();
    logging = StandardLogging(out: log, err: log);
    localTime = DateTime.utc(1970, 2, 10).millisecondsSinceEpoch;
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  HabitsDirFinder finderOver(List<String> parents) => HabitsDirFinder(parents);

  AutoBackup backupOver(
    HabitsDirFinder finder, {
    String? database,
    int? now,
  }) =>
      AutoBackup(
        databasePath: database ?? databasePath,
        dirFinder: finder,
        logging: logging,
        localTime: () => now ?? localTime,
        clock: () =>
            DateTime.fromMillisecondsSinceEpoch(now ?? localTime, isUtc: true),
      );

  String backupsDirOf(Directory parent) =>
      '${parent.path}/${HabitsDirFinder.backupsDirName}';

  /// Writes [name] into the backups folder with a given modification time.
  File seedBackup(String dir, String name, int millis) {
    Directory(dir).createSync(recursive: true);
    final file = File('$dir/$name')..writeAsStringSync('old');
    file.setLastModifiedSync(
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
    );
    return file;
  }

  List<String> namesIn(String dir) =>
      Directory(dir).listSync().map((e) => e.uri.pathSegments.last).toList()
        ..sort();

  // -----------------------------------------------------------------------
  // Where it writes
  // -----------------------------------------------------------------------

  group('the destination', () {
    test('#3 falls back to the private Backups folder', () async {
      final result = await backupOver(finderOver(<String>[externalDir.path]))
          .run();

      expect(result.directory, backupsDirOf(externalDir),
          reason: 'io.auto-backup#3: if "publicBackupFolder" is unset, or the '
              'DocumentFile is null, fall back to '
              'AndroidDirFinder(context).getFilesDir("Backups")');
      expect(Directory(result.directory!).existsSync(), isTrue,
          reason: 'io.auto-backup#3: the folder is created if it was missing');
      expect(result.written, isNotNull,
          reason: 'io.auto-backup#3: and the backup lands in it');
    });

    test('#3 a null directory means the whole run does nothing', () async {
      final result = await backupOver(
        finderOver(<String>['${tempDir.path}/does-not-exist']),
      ).run();

      expect(result.directory, isNull,
          reason: 'io.auto-backup#3: if getFilesDir returns null the whole run '
              'does nothing');
      expect(result.written, isNull,
          reason: 'io.auto-backup#3: nothing is written');
      expect(result.deleted, isEmpty,
          reason: 'io.auto-backup#3: and nothing is deleted either');
    });

    test('#4 the first writable external files dir wins', () async {
      final second = Directory('${tempDir.path}/second')
        ..createSync(recursive: true);

      expect(
        finderOver(<String>[
          '${tempDir.path}/missing',
          externalDir.path,
          second.path,
        ]).getFilesDir('Backups')?.pathString,
        backupsDirOf(externalDir),
        reason: 'io.auto-backup#4: AndroidDirFinder.getFilesDir(rel) picks the '
            'FIRST entry of ContextCompat.getExternalFilesDirs(context, null) '
            'that canWrite()',
      );
      expect(
        finderOver(<String>[externalDir.path]).getFilesDir('Backups')
            ?.pathString,
        backupsDirOf(externalDir),
        reason: 'io.auto-backup#4: then returns File("<thatDir>/<rel>/") — '
            "Java's File swallows the trailing separator",
      );
      expect(
        Directory(backupsDirOf(second)).existsSync(),
        isFalse,
        reason: 'io.auto-backup#4: the entries after the first are not even '
            'created',
      );
      expect(finderOver(<String>[]).getFilesDir('Backups'), isNull,
          reason: 'io.auto-backup#4: it returns null when no parent is '
              'writable');
      expect(
        finderOver(<String>['${tempDir.path}/nope']).getFilesDir('Backups'),
        isNull,
        reason: 'io.auto-backup#4: a parent that does not exist is not '
            'writable',
      );
    });

    test('#11 the manual export resolves its destination the same way',
        () async {
      // `io.export-db-backup#11` says ExportDBTask uses the same destination
      // resolution as AutoBackup. The Storage Access Framework half of that
      // resolution is dropped by this port (see the file comment), so what is
      // asserted is the half that remains: both paths ask the SAME dir finder
      // for the SAME "Backups" folder, rather than each computing one.
      final finder = finderOver(<String>[externalDir.path]);
      final scope = AppScope.open(
        AppDatabase.openAndMigrate('${tempDir.path}/exported.db'),
        databasePath: databasePath,
        logging: logging,
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      addTearDown(scope.close);

      final actions = DataActions(
        scope: scope,
        dirFinder: finder,
        cacheDir: tempDir.path,
        fileChooser: _NoFileChooser(),
        fileSharer: _RecordingSharer(),
        urlOpener: _NoUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          buildGenericImporter(
            scope: scope,
            fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
          ),
          scope.modelFactory,
          logging: logging,
        ),
        showMessage: (_) {},
        clock: () => DateTime.fromMillisecondsSinceEpoch(localTime, isUtc: true),
      );
      await actions.exportDb();

      final backups = namesIn(backupsDirOf(externalDir));
      expect(backups, hasLength(1),
          reason: 'io.export-db-backup#11: the export goes to '
              'AndroidDirFinder.getFilesDir("Backups")');

      // Age the exported copy past the freshness window, so the automatic
      // backup has a reason to write a second file into the same folder.
      final int wallClock = DateTime.now().millisecondsSinceEpoch;
      File('${backupsDirOf(externalDir)}/${backups.single}')
          .setLastModifiedSync(
        DateTime.fromMillisecondsSinceEpoch(wallClock - 2 * DateUtils.dayLength),
      );
      await backupOver(finder, now: wallClock).run();

      expect(namesIn(backupsDirOf(externalDir)), hasLength(2),
          reason: 'io.export-db-backup#11: and the automatic backup writes '
              'into that same folder — one resolution, two callers');
    });
  });

  // -----------------------------------------------------------------------
  // Listing and rotation
  // -----------------------------------------------------------------------

  group('rotation', () {
    test('#5 every file is listed, with no name filtering at all', () async {
      final dir = backupsDirOf(externalDir);
      seedBackup(dir, 'not-a-backup.txt', 1000);
      seedBackup(dir, 'Loop Habits Backup 1970-01-01 000000.db', 2000);
      seedBackup(dir, 'README', 3000);

      final result = await backupOver(
        finderOver(<String>[externalDir.path]),
      ).run(keep: 2);

      expect(result.newestTimestamp, 3000,
          reason: 'io.auto-backup#5: the private flow lists ALL files with no '
              'name filtering, sorts ascending by lastModified(), and takes '
              "the last file's lastModified()");
      expect(result.deleted, hasLength(1),
          reason: 'io.auto-backup#5: a file that is not a backup at all still '
              'counts towards the retention');
      expect(result.deleted.single.endsWith('not-a-backup.txt'), isTrue,
          reason: 'io.auto-backup#5: and the oldest one is the one dropped, '
              'whatever it is called');
    });

    test('#5 an empty directory has newestTimestamp 0', () async {
      Directory(backupsDirOf(externalDir)).createSync(recursive: true);

      final result =
          await backupOver(finderOver(<String>[externalDir.path])).run();

      expect(result.newestTimestamp, 0,
          reason: 'io.auto-backup#5: newestTimestamp is 0L when the directory '
              'is empty');
      expect(result.written, isNotNull,
          reason: 'io.auto-backup#9: an empty directory has newestTimestamp = '
              '0, so a backup is always written');
    });

    test('#7 with keep = 5 and 30 files the 25 oldest go', () async {
      final dir = backupsDirOf(externalDir);
      for (var i = 0; i < 30; i++) {
        seedBackup(dir, 'backup-$i.db', 1000 + i * 1000);
      }

      final result = await backupOver(
        finderOver(<String>[externalDir.path]),
        now: 1000 + 29 * 1000,
      ).run(keep: 5);

      expect(result.deleted, hasLength(25),
          reason: 'io.auto-backup#7: for k in 0 until (files.size - keep), '
              'delete files[k] — with keep = 5 and 30 files, files at indices '
              '0..24 are deleted');
      expect(
        namesIn(dir),
        <String>[
          'backup-25.db',
          'backup-26.db',
          'backup-27.db',
          'backup-28.db',
          'backup-29.db',
        ],
        reason: 'io.auto-backup#7: and the 5 newest remain',
      );
    });

    test('#7 nothing is deleted while the count is within the retention',
        () async {
      final dir = backupsDirOf(externalDir);
      for (var i = 0; i < 5; i++) {
        seedBackup(dir, 'backup-$i.db', 1000 + i * 1000);
      }

      final result = await backupOver(
        finderOver(<String>[externalDir.path]),
        now: 1000 + 4 * 1000,
      ).run(keep: 5);

      expect(result.deleted, isEmpty,
          reason: 'io.auto-backup#7: when files.size <= keep, nothing is '
              'deleted');
      expect(namesIn(dir), hasLength(5),
          reason: 'io.auto-backup#7: the directory is untouched');
    });

    test('#15 the default retention is five', () async {
      expect(AutoBackup.defaultKeep, 5,
          reason: 'io.auto-backup#15: the default retention is keep = 5');

      final dir = backupsDirOf(externalDir);
      for (var i = 0; i < 8; i++) {
        seedBackup(dir, 'backup-$i.db', 1000 + i * 1000);
      }
      final result =
          await backupOver(finderOver(<String>[externalDir.path])).run();

      expect(result.deleted, hasLength(3),
          reason: 'io.auto-backup#15: run() with no argument keeps five, so '
              'three of eight go');
    });

    test('#8 the freshness decision is taken before the deletion', () async {
      final dir = backupsDirOf(externalDir);
      // Six files: the newest is fresh, the other five are ancient. With
      // keep = 1 the rotation removes five of them — including, in a wrong
      // implementation, the one that decided freshness.
      seedBackup(dir, 'ancient-0.db', 1000);
      seedBackup(dir, 'ancient-1.db', 2000);
      seedBackup(dir, 'ancient-2.db', 3000);
      seedBackup(dir, 'ancient-3.db', 4000);
      seedBackup(dir, 'ancient-4.db', 5000);
      final fresh = localTime - 1000;
      seedBackup(dir, 'fresh.db', fresh);

      final result = await backupOver(
        finderOver(<String>[externalDir.path]),
      ).run(keep: 1);

      expect(result.newestTimestamp, fresh,
          reason: 'io.auto-backup#8: newestTimestamp is captured BEFORE '
              'deletion, so rotation never influences the freshness decision');
      expect(result.deleted, hasLength(5),
          reason: 'io.auto-backup#8: the rotation still runs');
      expect(result.written, isNull,
          reason: 'io.auto-backup#8: and the surviving fresh file is what '
              'stops a new one being written');
    });

    test('#16 old files are pruned even on a day nothing is written', () async {
      final dir = backupsDirOf(externalDir);
      for (var i = 0; i < 9; i++) {
        seedBackup(dir, 'backup-$i.db', localTime - 9000 + i * 1000);
      }

      final result = await backupOver(
        finderOver(<String>[externalDir.path]),
      ).run(keep: 5);

      expect(result.written, isNull,
          reason: 'io.auto-backup#16: the newest file is minutes old, so the '
              'freshness check writes nothing');
      expect(result.deleted, hasLength(4),
          reason: 'io.auto-backup#16: rotation happens BEFORE the freshness '
              'check, so old files are pruned even on a day when no new '
              'backup is written');
      expect(namesIn(dir), hasLength(5),
          reason: 'io.auto-backup#16');
    });
  });

  // -----------------------------------------------------------------------
  // Freshness
  // -----------------------------------------------------------------------

  group('freshness', () {
    test('#9 a backup is written only when the newest is more than a day old',
        () async {
      final dir = backupsDirOf(externalDir);
      // Exactly one day old: the comparison is strictly greater-than, so this
      // still counts as fresh.
      seedBackup(dir, 'backup.db', localTime - DateUtils.dayLength);

      final onTheBoundary =
          await backupOver(finderOver(<String>[externalDir.path])).run();
      expect(onTheBoundary.written, isNull,
          reason: 'io.auto-backup#9: a new backup is written only when '
              'DateUtils.getLocalTime() - newestTimestamp > '
              'DateUtils.DAY_LENGTH (86_400_000 ms)');
      expect(
        log.toString(),
        contains(
          'Fresh backup found (timestamp=${localTime - DateUtils.dayLength})',
        ),
        reason: 'io.auto-backup#9: otherwise it logs "Fresh backup found '
            '(timestamp=\$newestTimestamp)" and writes nothing',
      );

      final justOver = await backupOver(
        finderOver(<String>[externalDir.path]),
        now: localTime + 1,
      ).run();
      expect(justOver.written, isNotNull,
          reason: 'io.auto-backup#9: one millisecond past a full day and the '
              'backup is written');
    });

    test('#9 DAY_LENGTH is 86_400_000 ms', () {
      expect(DateUtils.dayLength, 86400000,
          reason: 'io.auto-backup#9: DateUtils.DAY_LENGTH (86_400_000 ms)');
    });

    test('#13 a directory that does not exist yet does not throw', () async {
      final finder = finderOver(<String>[externalDir.path]);
      expect(Directory(backupsDirOf(externalDir)).existsSync(), isFalse);

      AutoBackupResult? result;
      Object? thrown;
      try {
        result = await backupOver(finder).run();
      } on Object catch (error) {
        thrown = error;
      }
      expect(thrown, isNull,
          reason: 'io.auto-backup#13: running with a non-existent or empty '
              'backup directory must not throw');
      expect(result?.written, isNotNull,
          reason: 'io.auto-backup#13: it creates the directory and backs up '
              'into it');

      // And again, now that the directory exists but has been emptied.
      for (final entity in Directory(backupsDirOf(externalDir)).listSync()) {
        entity.deleteSync();
      }
      try {
        result = await backupOver(finder).run();
      } on Object catch (error) {
        thrown = error;
      }
      expect(thrown, isNull,
          reason: 'io.auto-backup#13: an empty directory is the same case');
      expect(result?.newestTimestamp, 0, reason: 'io.auto-backup#13');
    });
  });

  // -----------------------------------------------------------------------
  // How it is invoked
  // -----------------------------------------------------------------------

  group('the task it runs inside', () {
    test('#1 #14 it runs on the task runner and swallows every failure',
        () async {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const AsyncDispatcher(),
        ioDispatcher: const AsyncDispatcher(),
      );
      // A database file that is not there is the simplest real failure: the
      // copy throws, exactly as a full disk would.
      final task = AutoBackupTask(
        backupOver(
          finderOver(<String>[externalDir.path]),
          database: '${tempDir.path}/vanished.db',
        ),
        logging: logging,
      );

      runner.execute(task);
      await runner.awaitAll();

      expect(task.failure, isNotNull,
          reason: 'io.auto-backup#1: the backup really did fail');
      expect(task.result, isNull,
          reason: 'io.auto-backup#1: so it produced nothing');
      expect(log.toString(), contains('TaskRunner failed'),
          reason: 'io.auto-backup#14: exceptions are caught and logged as '
              "'ListHabitActivity'/'TaskRunner failed'");
      expect(log.toString(), contains('[ListHabitActivity]'),
          reason: 'io.auto-backup#14: under that tag');
    });

    test('#1 a failing backup never propagates out of the task runner',
        () async {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const AsyncDispatcher(),
        ioDispatcher: const AsyncDispatcher(),
      );
      runner.execute(
        AutoBackupTask(
          backupOver(
            finderOver(<String>[externalDir.path]),
            database: '${tempDir.path}/vanished.db',
          ),
          logging: logging,
        ),
      );

      await expectLater(runner.awaitAll(), completes,
          reason: 'io.auto-backup#1: any failure is logged ("TaskRunner '
              'failed") and swallowed — a failing backup never crashes the '
              'app');
    });

    test('#1 a successful run reports what it did', () async {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const AsyncDispatcher(),
        ioDispatcher: const AsyncDispatcher(),
      );
      final task = AutoBackupTask(
        backupOver(finderOver(<String>[externalDir.path])),
        logging: logging,
      );

      runner.execute(task);
      await runner.awaitAll();

      expect(task.failure, isNull,
          reason: 'io.auto-backup#1: nothing to swallow on the happy path');
      expect(task.result?.written, isNotNull,
          reason: 'io.auto-backup#1: AutoBackup(context).run(keep = 5) is '
              'invoked inside a background taskRunner block');
      expect(
        File(task.result!.written!).readAsBytesSync(),
        File(databasePath).readAsBytesSync(),
        reason: 'io.auto-backup#1: and what it wrote is the database',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes for the seams DataActions needs but this file does not exercise
// ---------------------------------------------------------------------------

class _NoFileChooser implements FileChooser {
  @override
  Future<String?> pickFile() async => null;
}

class _RecordingSharer implements FileSharer {
  final List<String> paths = <String>[];

  @override
  Future<void> shareFile(String path, {required String mimeType, Rect? origin}) async =>
      paths.add(path);
}

class _NoUrlOpener implements UrlOpener {
  @override
  Future<bool> open(String url) async => true;
}
