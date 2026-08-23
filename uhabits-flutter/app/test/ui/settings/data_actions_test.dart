/// Tests for the import half of `DataActions`, the Flutter counterpart of
/// `ListHabitsScreen.onOpenDocumentResult` / `onImportData`.
///
/// The Android screen is handed a content URI by `ACTION_OPEN_DOCUMENT` and
/// copies the stream into a temp file under the external cache dir before the
/// importer ever sees it; the Flutter screen is handed a path by the file
/// picker and does the same. What is asserted here is that copy, the deletion
/// that follows it, and the mapping from `ImportDataTask`'s three result codes
/// to the three messages.
///
/// The rest of `list-habits.data-io-actions` is asserted in
/// packages/uhabits_core/test/ui/screens/habits/list/list_habits_behavior_test.dart,
/// which owns the presenter side.
library;

// The io and task layers of the core are reached by their `src` path, exactly
// as lib/ui/settings/data_actions.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart' show SettingsResult;
import 'package:uhabits/ui/settings/data_actions.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/generic_importer.dart';

/// `FileChooser` over a canned answer — the `ACTION_OPEN_DOCUMENT` result.
class _FakeChooser implements FileChooser {
  _FakeChooser(this.path);

  final String? path;
  int calls = 0;

  @override
  Future<String?> pickFile() async {
    calls++;
    return path;
  }
}

class _FakeSharer implements FileSharer {
  @override
  Future<void> shareFile(String path, {required String mimeType}) async {}
}

/// Records what the share sheet was asked for, or refuses outright — the two
/// halves of `ACTION_SEND` plus `startActivitySafely`.
class _RecordingSharer implements FileSharer {
  _RecordingSharer({this.throws = false});

  final bool throws;
  final List<({String path, String mimeType})> shared =
      <({String path, String mimeType})>[];

  @override
  Future<void> shareFile(String path, {required String mimeType}) async {
    shared.add((path: path, mimeType: mimeType));
    if (throws) throw StateError('no activity found');
  }
}

class _FakeUrlOpener implements UrlOpener {
  @override
  Future<bool> open(String url) async => true;
}

/// An `ImportDataTask` that skips the importer and reports a canned result.
class _CannedImportTask extends ImportDataTask {
  _CannedImportTask(
    super.importer,
    super.modelFactory,
    super.file,
    super.listener,
    this.code,
  );

  final int code;

  @override
  Future<void> doInBackground() async {}

  @override
  void onPostExecute() => listener.onImportDataFinished(code);
}

class _CannedFactory extends ImportDataTaskFactory {
  _CannedFactory(super.importer, super.modelFactory, this.code);

  final int code;

  /// The file the task was handed, kept so the test can look at the copy.
  UserFile? file;

  /// Its contents, read while the task still had it.
  List<int>? bytes;

  @override
  ImportDataTask create(UserFile f, ImportDataTaskListener listener) {
    file = f;
    bytes = File(f.pathString).readAsBytesSync();
    return _CannedImportTask(importer, modelFactory, f, listener, code);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String cacheDir;
  final scopes = <AppScope>[];

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_data_actions');
    cacheDir = '${tempDir.path}/cache';
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scopes.add(scope);
    return scope;
  }

  ({
    DataActions actions,
    _CannedFactory factory,
    List<DataActionMessage> messages,
    List<String> refreshes,
  }) buildActions(
    AppScope scope, {
    required String? pickedPath,
    int result = ImportDataTask.success,
    FileSharer? fileSharer,
  }) {
    final messages = <DataActionMessage>[];
    final refreshes = <String>[];
    final factory = _CannedFactory(
      buildGenericImporter(
        scope: scope,
        fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
      ),
      scope.modelFactory,
      result,
    );
    return (
      actions: DataActions(
        scope: scope,
        dirFinder: HabitsDirFinder(<String>[tempDir.path]),
        cacheDir: cacheDir,
        fileChooser: _FakeChooser(pickedPath),
        fileSharer: fileSharer ?? _FakeSharer(),
        urlOpener: _FakeUrlOpener(),
        importTaskFactory: factory,
        showMessage: messages.add,
        refreshHabitList: () => refreshes.add('refresh'),
      ),
      factory: factory,
      messages: messages,
      refreshes: refreshes,
    );
  }

  group('list-habits.data-io-actions', () {
    test('#1 the five settings result codes and where each one goes',
        () async {
      // `ListHabitsScreen.onSettingsResult(resultCode)`: the data actions are
      // not on the list menu at all — they arrive as result codes from the
      // settings screen. The numbers are kept verbatim.
      expect(
        <SettingsResult, int>{
          for (final r in SettingsResult.values) r: r.code,
        },
        <SettingsResult, int>{
          SettingsResult.importData: 101,
          SettingsResult.exportCsv: 102,
          SettingsResult.exportDb: 103,
          SettingsResult.bugReport: 104,
          SettingsResult.repairDb: 105,
        },
        reason: 'list-habits.data-io-actions#1: 101 -> import, 102 -> export '
            'CSV, 103 -> export DB, 104 -> bug report, 105 -> repair',
      );

      // 101 reaches the file picker…
      final scope = openScope();
      final built = buildActions(scope, pickedPath: null);
      final actions = built.actions;
      await actions.onSettingsResult(SettingsResult.importData);
      expect((actions.fileChooser as _FakeChooser).calls, 1,
          reason: 'list-habits.data-io-actions#1: 101 shows the import file '
              'picker');

      // …102 and 103 write a file each…
      final csvDir = Directory(
        '${tempDir.path}/${HabitsDirFinder.csvDirName}',
      );
      final backupDir = Directory(
        '${tempDir.path}/${HabitsDirFinder.backupsDirName}',
      );
      await actions.onSettingsResult(SettingsResult.exportCsv);
      expect(csvDir.listSync(), hasLength(1),
          reason: 'list-habits.data-io-actions#1: 102 exports the CSV archive');
      // The DB export copies the database file, so this branch needs a scope
      // that knows where its file is.
      final dbPath = '${tempDir.path}/habits103.db';
      final dbScope = AppScope.open(
        AppDatabase.openAndMigrate(dbPath),
        databasePath: dbPath,
      );
      addTearDown(dbScope.close);
      await buildActions(dbScope, pickedPath: null)
          .actions
          .onSettingsResult(SettingsResult.exportDb);
      expect(backupDir.listSync(), hasLength(1),
          reason: 'list-habits.data-io-actions#1: 103 exports the database');

      // …and 104 / 105 are accepted without a crash, though the bug report and
      // the repair themselves belong to the troubleshooting slice.
      await actions.onSettingsResult(SettingsResult.bugReport);
      await actions.onSettingsResult(SettingsResult.repairDb);
      expect((actions.fileChooser as _FakeChooser).calls, 1,
          reason: 'list-habits.data-io-actions#1: 104 and 105 are not the '
              'import picker');
      expect(built.messages, isEmpty,
          reason: 'list-habits.data-io-actions#1');
    });

    test('platform-glue.time-and-date-formatting#3 — the backup filename is '
        '"yyyy-MM-dd HHmmss" in Locale.US', () async {
      const rule = 'platform-glue.time-and-date-formatting#3 — '
          'DateFormats.getBackupDateFormat() is fixed to the pattern '
          '"yyyy-MM-dd HHmmss" in Locale.US and is used both for backup '
          'filenames and for the alarm-scheduling log line.';

      final dbPath = '${tempDir.path}/habits_backup_name.db';
      final scope = AppScope.open(
        AppDatabase.openAndMigrate(dbPath),
        databasePath: dbPath,
      );
      addTearDown(scope.close);
      await buildActions(scope, pickedPath: null)
          .actions
          .onSettingsResult(SettingsResult.exportDb);

      final backupDir = Directory(
        '${tempDir.path}/${HabitsDirFinder.backupsDirName}',
      );
      final String name =
          backupDir.listSync().single.uri.pathSegments.last;

      expect(
        name,
        matches(RegExp(r'^Loop Habits Backup \d{4}-\d{2}-\d{2} \d{6}\.db$')),
        reason: rule,
      );

      // "in Locale.US": the digits are ASCII and the pattern is fixed, so a
      // device whose locale numbers differently still produces a filename the
      // importer can read back.
      expect(backupDateString(DateTime.utc(2015, 1, 26, 7, 4, 9)),
          '2015-01-26 070409',
          reason: '$rule — zero-padded, 24-hour, no separators in the time');
      expect(backupDateString(DateTime.utc(2015, 12, 31, 23, 59, 59)),
          '2015-12-31 235959',
          reason: rule);
      expect(backupFileName(DateTime.utc(2015, 1, 26, 7, 4, 9)),
          'Loop Habits Backup 2015-01-26 070409.db',
          reason: rule);
      for (final int unit in backupDateString(DateTime.utc(2015, 1, 26))
          .replaceAll(RegExp('[^0-9]'), '')
          .codeUnits) {
        expect(unit, inInclusiveRange(0x30, 0x39),
            reason: '$rule — every digit is ASCII');
      }
    });

    test('show-habit.export-csv#4 the archive goes to the share sheet as '
        'application/zip', () async {
      final scope = openScope();
      final sharer = _RecordingSharer();
      final built =
          buildActions(scope, pickedPath: null, fileSharer: sharer);
      final actions = built.actions;
      final messages = built.messages;

      await actions.exportCsv();

      expect(sharer.shared, hasLength(1),
          reason: 'show-habit.export-csv#4: on success the callback receives '
              'the archive path and the screen launches a share sheet');
      expect(sharer.shared.single.mimeType, DataActions.shareMimeType,
          reason: 'show-habit.export-csv#4: type "application/zip"');
      expect(DataActions.shareMimeType, 'application/zip',
          reason: 'show-habit.export-csv#4');
      expect(sharer.shared.single.path, endsWith('.zip'),
          reason: 'show-habit.export-csv#4: EXTRA_STREAM is a provider URI for '
              'the produced file — share_plus does the FileProvider wrapping '
              'and the read-permission grant that ACTION_SEND needs');
      expect(messages, isEmpty, reason: 'show-habit.export-csv#4');

      // A file:// URI is reduced to its path before it is handed over; a
      // content:// one is passed through untouched.
      await actions.showSendFileScreen('file:///tmp/backup.zip');
      expect(sharer.shared.last.path, '/tmp/backup.zip',
          reason: 'show-habit.export-csv#4');
      await actions
          .showSendFileScreen('content://org.isoron.uhabits/backup.zip');
      expect(sharer.shared.last.path,
          'content://org.isoron.uhabits/backup.zip',
          reason: 'show-habit.export-csv#4: a content URI is already what '
              'FileProvider would have produced');
    });

    test('show-habit.export-csv#5 nothing able to handle the share falls back '
        'to a message', () async {
      final scope = openScope();
      final sharer = _RecordingSharer(throws: true);
      final built =
          buildActions(scope, pickedPath: null, fileSharer: sharer);

      await built.actions.exportCsv();

      expect(built.messages,
          <DataActionMessage>[DataActionMessage.activityNotFound],
          reason: 'show-habit.export-csv#5: startActivitySafely catches the '
              'ActivityNotFoundException and shows R.string.activity_not_found '
              'instead of crashing');
    });

    test('#5 the picked file is copied into the cache dir, imported, then '
        'deleted', () async {
      final scope = openScope();
      final source = File('${tempDir.path}/backup.db')
        ..writeAsBytesSync(<int>[1, 2, 3, 4]);
      final h = buildActions(scope, pickedPath: source.path);

      await h.actions.importData();

      final copied = h.factory.file!;
      expect(copied.pathString, isNot(source.path),
          reason: 'list-habits.data-io-actions#5: the selected stream is '
              'copied into a temp file, never imported in place');
      expect(copied.pathString, startsWith(cacheDir),
          reason: 'list-habits.data-io-actions#5: the temp file lives in the '
              'external cache dir');
      expect(h.factory.bytes, <int>[1, 2, 3, 4],
          reason: 'list-habits.data-io-actions#5: with the contents of the '
              'chosen file');
      expect(File(copied.pathString).existsSync(), isFalse,
          reason: 'list-habits.data-io-actions#5: and it is deleted once the '
              'import has finished');
      expect(source.existsSync(), isTrue,
          reason: "list-habits.data-io-actions#5: the user's own file is left "
              'alone');
    });

    test('#5 a cancelled picker imports nothing', () async {
      final scope = openScope();
      final h = buildActions(scope, pickedPath: null);

      await h.actions.importData();

      expect(h.factory.file, isNull,
          reason: 'list-habits.data-io-actions#5: no document, no import');
      expect(h.messages, isEmpty,
          reason: 'list-habits.data-io-actions#5: and no message either');
    });

    test('#5 an unreadable source reports "Failed to import data."', () async {
      final scope = openScope();
      final h = buildActions(scope, pickedPath: '${tempDir.path}/missing.db');

      await h.actions.importData();

      expect(h.messages, <DataActionMessage>[DataActionMessage.importFailed],
          reason: 'list-habits.data-io-actions#5: an IOException while copying '
              "shows 'Failed to import data.'");
      expect(h.factory.file, isNull,
          reason: 'list-habits.data-io-actions#5: the importer never runs');
      // The copy failed before the temp file was created, so nothing is left
      // behind in the cache dir.
      expect(
        Directory(cacheDir).existsSync()
            ? Directory(cacheDir).listSync()
            : const <FileSystemEntity>[],
        isEmpty,
        reason: 'list-habits.data-io-actions#5: and no temp file is left over',
      );
    });

    test('#6 SUCCESS refreshes the adapter and reports "Habits imported."',
        () async {
      final scope = openScope();
      final source = File('${tempDir.path}/backup.db')..writeAsBytesSync(<int>[1]);
      final h = buildActions(
        scope,
        pickedPath: source.path,
        result: ImportDataTask.success,
      );

      await h.actions.importData();

      expect(h.refreshes, <String>['refresh'],
          reason: 'list-habits.data-io-actions#6: SUCCESS refreshes the '
              'adapter');
      expect(
        h.messages,
        <DataActionMessage>[DataActionMessage.importSuccessful],
        reason: "list-habits.data-io-actions#6: …and shows 'Habits imported.'",
      );
    });

    test('#6 NOT_RECOGNIZED reports "File not recognized."', () async {
      final scope = openScope();
      final source = File('${tempDir.path}/backup.db')..writeAsBytesSync(<int>[1]);
      final h = buildActions(
        scope,
        pickedPath: source.path,
        result: ImportDataTask.notRecognized,
      );

      await h.actions.importData();

      expect(
        h.messages,
        <DataActionMessage>[DataActionMessage.fileNotRecognized],
        reason: 'list-habits.data-io-actions#6: NOT_RECOGNIZED shows '
            "'File not recognized.'",
      );
      expect(h.refreshes, isEmpty,
          reason: 'list-habits.data-io-actions#6: and does not refresh');
    });

    test('#6 anything else reports "Failed to import data."', () async {
      final scope = openScope();
      final source = File('${tempDir.path}/backup.db')..writeAsBytesSync(<int>[1]);
      final h = buildActions(
        scope,
        pickedPath: source.path,
        result: ImportDataTask.failed,
      );

      await h.actions.importData();

      expect(h.messages, <DataActionMessage>[DataActionMessage.importFailed],
          reason: 'list-habits.data-io-actions#6: anything else shows '
              "'Failed to import data.'");
      expect(h.refreshes, isEmpty,
          reason: 'list-habits.data-io-actions#6: and does not refresh');

      // Whatever the result, the temp file goes.
      expect(File(h.factory.file!.pathString).existsSync(), isFalse,
          reason: 'list-habits.data-io-actions#5: the temp file is deleted on '
              'every path out of the import');
    });
  });
}
