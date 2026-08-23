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
        fileSharer: _FakeSharer(),
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
