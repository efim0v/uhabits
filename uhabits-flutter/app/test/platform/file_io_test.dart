/// Tests for the file plumbing around the ported CSV exporter and the four
/// importers: choosing a file to import, writing an export somewhere the
/// system share sheet can reach it, and opening the two link rows of the
/// settings screen.
///
/// The Kotlin originals are
/// uhabits-android/.../tasks/{ExportDBTask,ImportDataTask}.kt,
/// uhabits-android/.../activities/HabitsDirFinder.kt,
/// uhabits-android/.../AndroidDirFinder.kt,
/// uhabits-android/.../utils/{FileUtils,DatabaseUtils,ViewExtensions}.kt and
/// the `onOpenDocumentResult` / `onSettingsResult` half of
/// uhabits-android/.../activities/habits/list/ListHabitsScreen.kt.
///
/// Three plugins stand between this code and the operating system —
/// file_picker, share_plus and url_launcher — and none of them runs in a
/// widget test, so each one sits behind a one-method interface
/// ([FileChooser], [FileSharer], [UrlOpener]) that the fakes below implement.
/// Everything else is real: a real SQLite database, the real
/// `HabitsCSVExporter`, the real `ImportDataTask`.
///
/// Every expectation cites the ledger rule it stands for.
library;

// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart';
import 'package:uhabits/ui/settings/data_actions.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/src/io/abstract_importer.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/generic_importer.dart';
import 'package:uhabits_core/uhabits_core.dart';

// ---------------------------------------------------------------------------
// Fakes for the three plugin seams
// ---------------------------------------------------------------------------

/// Stands in for `FilePicker.platform.pickFiles()`, i.e. for the
/// `ACTION_OPEN_DOCUMENT` intent the Android screen fires.
class FakeFileChooser implements FileChooser {
  FakeFileChooser([this.result]);

  String? result;
  int calls = 0;

  @override
  Future<String?> pickFile() async {
    calls++;
    return result;
  }
}

/// Stands in for `Share.shareXFiles`, i.e. for the `ACTION_SEND` intent.
class FakeFileSharer implements FileSharer {
  final List<String> paths = <String>[];
  final List<String> mimeTypes = <String>[];

  /// Set to reproduce `ActivityNotFoundException`.
  Object? error;

  @override
  Future<void> shareFile(String path, {required String mimeType}) async {
    paths.add(path);
    mimeTypes.add(mimeType);
    final error = this.error;
    if (error != null) throw error;
  }
}

/// Stands in for `launchUrl`, i.e. for `startActivitySafely(ACTION_VIEW)`.
class FakeUrlOpener implements UrlOpener {
  final List<String> urls = <String>[];
  bool result = true;
  Object? error;

  @override
  Future<bool> open(String url) async {
    urls.add(url);
    final error = this.error;
    if (error != null) throw error;
    return result;
  }
}

/// An [AbstractImporter] that records what it was handed and claims (or not)
/// whatever it is given. `GenericImporter` never looks at the concrete type of
/// its importers, so this is the whole surface the import flow exercises.
class RecordingImporter extends AbstractImporter {
  bool claims = false;
  Object? throwOnImport;
  final List<String> canHandlePaths = <String>[];
  final List<String> importedPaths = <String>[];

  /// Recorded at `canHandle` time: the flow must delete the temp file only
  /// after the importer is done with it.
  final List<bool> existedWhenImported = <bool>[];

  @override
  Future<bool> canHandle(UserFile file) async {
    canHandlePaths.add(file.pathString);
    return claims;
  }

  @override
  Future<void> importHabitsFromFile(UserFile file) async {
    importedPaths.add(file.pathString);
    existedWhenImported.add(await file.exists());
    final error = throwOnImport;
    if (error != null) throw error;
  }
}

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  var databaseIndex = 0;

  setUp(() {
    // AppScope.open stamps today; nothing may read a habit before it has.
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_file_io');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String makeDir(String name) {
    final dir = Directory('${tempDir.path}/$name');
    dir.createSync(recursive: true);
    return dir.path;
  }

  /// The app's live database, at `<dir>/uhabits.db`, so that the full backup
  /// copies the same file the Android app copies out of
  /// `filesDir/../databases/`.
  AppScope openScope() {
    final dir = makeDir('app${databaseIndex++}');
    final database = AppDatabase.openAndMigrate('$dir/$databaseFilename');
    final scope = AppScope.open(database, databasePath: '$dir/$databaseFilename');
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, String name) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..color = const PaletteColor(3);
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  // -------------------------------------------------------------------
  // FileUtils.getDir / AndroidDirFinder / HabitsDirFinder
  // -------------------------------------------------------------------

  group('io.export-csv-entry-points', () {
    test('#4 the CSV output dir is the first writable parent plus /CSV', () {
      final missing = '${tempDir.path}/does-not-exist';
      final parent = makeDir('external0');
      final finder = HabitsDirFinder(<String>[missing, parent]);

      final dir = finder.getCSVOutputDir();

      expect(dir.pathString, '$parent/CSV',
          reason: 'io.export-csv-entry-points#4');
      expect(Directory('$parent/CSV').existsSync(), isTrue,
          reason: 'io.export-csv-entry-points#4 mkdirs() when missing');
    });

    test('#5 dereferencing a null dir throws', () {
      final finder = HabitsDirFinder(<String>['${tempDir.path}/nope']);

      expect(finder.getFilesDir('CSV'), isNull,
          reason: 'io.export-csv-entry-points#5');
      expect(() => finder.getCSVOutputDir(), throwsA(isA<TypeError>()),
          reason: 'io.export-csv-entry-points#5 the `!!` in HabitsDirFinder');
    });

    test('#6 settings result 102 exports the list into the CSV dir', () async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      final parent = makeDir('external1');
      final sharer = FakeFileSharer();
      final actions = DataActions(
        scope: scope,
        dirFinder: HabitsDirFinder(<String>[parent]),
        cacheDir: makeDir('cache1'),
        fileChooser: FakeFileChooser(),
        fileSharer: sharer,
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          scope.modelFactory,
        ),
        showMessage: (_) {},
      );

      expect(SettingsResult.exportCsv.code, 102,
          reason: 'io.export-csv-entry-points#6');
      await actions.onSettingsResult(SettingsResult.exportCsv);

      final expected = '$parent/CSV/Loop Habits CSV '
          '${getToday().toCSVString()}.zip';
      expect(File(expected).existsSync(), isTrue,
          reason: 'io.export-csv-entry-points#6');
      expect(sharer.paths, <String>[expected],
          reason: 'io.export-csv-entry-points#3');
    });
  });

  // -------------------------------------------------------------------
  // ListHabitsScreen.showImportScreen / onOpenDocumentResult
  // -------------------------------------------------------------------

  group('io.import-file-picker', () {
    late AppScope scope;
    late RecordingImporter importer;
    late FakeFileChooser chooser;
    late DataActions actions;
    late List<DataActionMessage> messages;
    late int refreshes;
    late String cacheDir;

    setUp(() {
      scope = openScope();
      importer = RecordingImporter();
      chooser = FakeFileChooser();
      messages = <DataActionMessage>[];
      refreshes = 0;
      cacheDir = makeDir('cache');
      actions = DataActions(
        scope: scope,
        dirFinder: HabitsDirFinder(<String>[makeDir('external')]),
        cacheDir: cacheDir,
        fileChooser: chooser,
        fileSharer: FakeFileSharer(),
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            importer,
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          scope.modelFactory,
        ),
        showMessage: messages.add,
        refreshHabitList: () => refreshes++,
      );
    });

    /// A file to import, outside the cache directory.
    String sourceFile(String content) {
      final file = File('${tempDir.path}/backup.db')
        ..writeAsStringSync(content);
      return file.path;
    }

    test('#1 settings result 101 opens the document picker', () async {
      expect(SettingsResult.importData.code, 101,
          reason: 'io.import-file-picker#1');

      await actions.onSettingsResult(SettingsResult.importData);

      expect(chooser.calls, 1, reason: 'io.import-file-picker#1');
    });

    test('#2 the chosen file is copied into a temp file in the cache dir',
        () async {
      chooser.result = sourceFile('SQLite format 3 payload');
      importer.claims = true;

      await actions.importData();

      expect(importer.importedPaths, hasLength(1),
          reason: 'io.import-file-picker#2');
      final tempPath = importer.importedPaths.single;
      expect(File(tempPath).parent.path, cacheDir,
          reason: 'io.import-file-picker#2 createTempFile(.., externalCacheDir)');
      expect(tempPath.split('/').last, startsWith('import'),
          reason: 'io.import-file-picker#2 createTempFile("import", "")');
      expect(File(chooser.result!).readAsStringSync(),
          'SQLite format 3 payload',
          reason: 'io.import-file-picker#2 the original is left alone');
    });

    test('#3 the temp file reaches the task and is deleted afterwards',
        () async {
      chooser.result = sourceFile('anything');
      importer.claims = true;

      await actions.importData();

      expect(importer.existedWhenImported, <bool>[true],
          reason: 'io.import-file-picker#3');
      expect(File(importer.importedPaths.single).existsSync(), isFalse,
          reason: 'io.import-file-picker#3 deleted whatever the result');
      expect(Directory(cacheDir).listSync(), isEmpty,
          reason: 'io.import-file-picker#3');
    });

    test('#3 #4 an unrecognized file is reported and still cleaned up',
        () async {
      chooser.result = sourceFile('not a database');
      importer.claims = false;

      await actions.importData();

      expect(messages, <DataActionMessage>[DataActionMessage.fileNotRecognized],
          reason: 'io.import-file-picker#4 result 2');
      expect(refreshes, 0, reason: 'io.import-file-picker#4');
      expect(Directory(cacheDir).listSync(), isEmpty,
          reason: 'io.import-file-picker#3');
    });

    test('#4 a successful import refreshes the list and reports it', () async {
      chooser.result = sourceFile('anything');
      importer.claims = true;

      await actions.importData();

      expect(messages, <DataActionMessage>[DataActionMessage.importSuccessful],
          reason: 'io.import-file-picker#4 result 1');
      expect(refreshes, 1, reason: 'io.import-file-picker#4 adapter.refresh()');
    });

    test('#3 #4 a failing import reports failure and still cleans up',
        () async {
      chooser.result = sourceFile('anything');
      importer
        ..claims = true
        ..throwOnImport = Exception('boom');

      await actions.importData();

      expect(messages, <DataActionMessage>[DataActionMessage.importFailed],
          reason: 'io.import-file-picker#4 any other result');
      expect(Directory(cacheDir).listSync(), isEmpty,
          reason: 'io.import-file-picker#3 whatever the result');
    });

    test('#5 an unreadable file fails without starting the task', () async {
      chooser.result = '${tempDir.path}/gone.db';

      await actions.importData();

      expect(messages, <DataActionMessage>[DataActionMessage.importFailed],
          reason: 'io.import-file-picker#5');
      expect(importer.canHandlePaths, isEmpty,
          reason: 'io.import-file-picker#5 the task never starts');
      expect(Directory(cacheDir).listSync(), isEmpty,
          reason: 'io.import-file-picker#5');
    });

    test('#6 a cancelled picker does nothing at all', () async {
      chooser.result = null;

      await actions.importData();

      expect(messages, isEmpty, reason: 'io.import-file-picker#6');
      expect(importer.canHandlePaths, isEmpty,
          reason: 'io.import-file-picker#6');
      expect(Directory(cacheDir).listSync(), isEmpty,
          reason: 'io.import-file-picker#6');
    });

    test('#7 the settings summary states the supported formats', () {
      final summary = L10nEn().importDataSummary;

      expect(summary, contains('full backups exported by this app'),
          reason: 'io.import-file-picker#7');
      expect(summary, contains('Tickmate'), reason: 'io.import-file-picker#7');
      expect(summary, contains('HabitBull'), reason: 'io.import-file-picker#7');
      expect(summary, contains('Rewire'), reason: 'io.import-file-picker#7');
    });
  });

  // -------------------------------------------------------------------
  // ExportDBTask + DatabaseUtils.saveDatabaseCopy
  // -------------------------------------------------------------------

  group('io.export-db-backup', () {
    test('#5 #10 #13 the backup file name is the UTC timestamp', () {
      // 14:30:12 UTC on 2025-08-22, given in another zone to prove the
      // formatter converts.
      final instant = DateTime.utc(2025, 8, 22, 14, 30, 12).toLocal();

      expect(backupFileName(instant), 'Loop Habits Backup 2025-08-22 143012.db',
          reason: 'io.export-db-backup#5');
      expect(backupFileName(DateTime.fromMillisecondsSinceEpoch(40 * 86400000)),
          'Loop Habits Backup 1970-02-10 000000.db',
          reason: 'io.export-db-backup#13 the same format as AutoBackup');
    });

    test('#1 #3 #7 #9 #14 #16 settings result 103 copies the live database',
        () async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      final parent = makeDir('external2');
      final sharer = FakeFileSharer();
      final messages = <DataActionMessage>[];
      final actions = DataActions(
        scope: scope,
        dirFinder: HabitsDirFinder(<String>[parent]),
        cacheDir: makeDir('cache2'),
        fileChooser: FakeFileChooser(),
        fileSharer: sharer,
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          scope.modelFactory,
        ),
        showMessage: messages.add,
        clock: () => DateTime.utc(2025, 8, 22, 14, 30, 12),
      );

      expect(SettingsResult.exportDb.code, 103,
          reason: 'io.export-db-backup#1 io.export-db-backup#10');
      await actions.onSettingsResult(SettingsResult.exportDb);

      final expected =
          '$parent/Backups/Loop Habits Backup 2025-08-22 143012.db';
      expect(File(expected).existsSync(), isTrue,
          reason: 'io.export-db-backup#3 the app-private Backups folder');
      expect(File(expected).readAsBytesSync(),
          File(scope.databasePath!).readAsBytesSync(),
          reason: 'io.export-db-backup#7 a byte-for-byte copy of the live db');
      expect(sharer.paths, <String>[expected],
          reason: 'io.export-db-backup#9 io.export-db-backup#14 '
              'the absolute path reaches the share sheet');
      expect(messages, isEmpty, reason: 'io.export-db-backup#9');

      // The copy is a valid Loop database that can be reopened and imported.
      final copy = AppDatabase.openAndMigrate(expected);
      expect(copy.getVersion(), databaseVersion,
          reason: 'io.export-db-backup#16');
      expect(copy.queryInt('select count(*) from Habits'), 1,
          reason: 'io.export-db-backup#16');
      copy.close();
    });

    test('#12 exporting twice writes two files, with no rotation', () async {
      final scope = openScope();
      final parent = makeDir('external3');
      var seconds = 10;
      final actions = DataActions(
        scope: scope,
        dirFinder: HabitsDirFinder(<String>[parent]),
        cacheDir: makeDir('cache3'),
        fileChooser: FakeFileChooser(),
        fileSharer: FakeFileSharer(),
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          scope.modelFactory,
        ),
        showMessage: (_) {},
        clock: () => DateTime.utc(2025, 8, 22, 14, 30, seconds++),
      );

      await actions.exportDb();
      await actions.exportDb();

      expect(Directory('$parent/Backups').listSync(), hasLength(2),
          reason: 'io.export-db-backup#12 no rotation, no freshness check');
    });

    test('#4 #9 a missing backup dir reports failure', () async {
      final scope = openScope();
      final messages = <DataActionMessage>[];
      final sharer = FakeFileSharer();
      final actions = DataActions(
        scope: scope,
        // Nothing writable: AndroidDirFinder.getFilesDir returns null.
        dirFinder: HabitsDirFinder(<String>['${tempDir.path}/nowhere']),
        cacheDir: makeDir('cache4'),
        fileChooser: FakeFileChooser(),
        fileSharer: sharer,
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          scope.modelFactory,
        ),
        showMessage: messages.add,
      );

      await actions.exportDb();

      expect(messages, <DataActionMessage>[DataActionMessage.couldNotExport],
          reason: 'io.export-db-backup#4 io.export-db-backup#9 '
              'io.export-db-backup#14 a null filename shows the message');
      expect(sharer.paths, isEmpty, reason: 'io.export-db-backup#9');
    });

    test('#8 #15 a failed copy escapes as an unchecked error', () {
      final dir = HabitsDirFinder(<String>[makeDir('external4')])
          .getFilesDir('Backups')!;

      expect(
        () => saveDatabaseCopy(
          databasePath: '${tempDir.path}/not-a-database.db',
          dir: dir,
          now: DateTime.utc(2025, 8, 22, 14, 30, 12),
        ),
        throwsA(isA<StateError>()),
        reason: 'io.export-db-backup#8 io.export-db-backup#15 '
            'IOException rethrown as a RuntimeException',
      );
    });
  });

  // -------------------------------------------------------------------
  // The production wiring, end to end
  // -------------------------------------------------------------------

  group('buildGenericImporter', () {
    test('a full backup exported by this app can be imported back', () async {
      final source = openScope();
      addHabit(source, 'Meditate');
      final backupParent = makeDir('external-roundtrip');
      final sharer = FakeFileSharer();
      final exporter = DataActions(
        scope: source,
        dirFinder: HabitsDirFinder(<String>[backupParent]),
        cacheDir: makeDir('cache-roundtrip'),
        fileChooser: FakeFileChooser(),
        fileSharer: sharer,
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          source.modelFactory,
        ),
        showMessage: (_) {},
        clock: () => DateTime.utc(2025, 8, 22, 14, 30, 12),
      );
      await exporter.exportDb();

      // A second, empty app: the real four importers, reading their migration
      // scripts through the real FileOpener.
      final destination = openScope();
      final messages = <DataActionMessage>[];
      final importer = DataActions(
        scope: destination,
        dirFinder: HabitsDirFinder(<String>[makeDir('external-roundtrip2')]),
        cacheDir: makeDir('cache-roundtrip2'),
        fileChooser: FakeFileChooser(sharer.paths.single),
        fileSharer: FakeFileSharer(),
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          buildGenericImporter(
            scope: destination,
            fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
          ),
          destination.modelFactory,
        ),
        showMessage: messages.add,
        refreshHabitList: () {},
      );

      await importer.importData();

      expect(messages, <DataActionMessage>[DataActionMessage.importSuccessful],
          reason: 'io.export-db-backup#16');
      expect(destination.habitList.toList().map((Habit h) => h.name),
          <String>['Meditate'],
          reason: 'io.export-db-backup#16');
    });
  });

  // -------------------------------------------------------------------
  // Activity.showSendFileScreen
  // -------------------------------------------------------------------

  group('io.share-file-screen', () {
    late FakeFileSharer sharer;
    late List<DataActionMessage> messages;
    late DataActions actions;

    setUp(() {
      final scope = openScope();
      sharer = FakeFileSharer();
      messages = <DataActionMessage>[];
      actions = DataActions(
        scope: scope,
        dirFinder: HabitsDirFinder(<String>[makeDir('external5')]),
        cacheDir: makeDir('cache5'),
        fileChooser: FakeFileChooser(),
        fileSharer: sharer,
        urlOpener: FakeUrlOpener(),
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          scope.modelFactory,
        ),
        showMessage: messages.add,
      );
    });

    test('#1 a plain path, a file: URI and a content: URI', () async {
      await actions.showSendFileScreen('/tmp/Loop Habits CSV 2025-08-22.zip');
      await actions.showSendFileScreen('file:///tmp/backup.db');
      await actions.showSendFileScreen('content://org.isoron.uhabits/backup.db');

      expect(
        sharer.paths,
        <String>[
          '/tmp/Loop Habits CSV 2025-08-22.zip',
          '/tmp/backup.db',
          'content://org.isoron.uhabits/backup.db',
        ],
        reason: 'io.share-file-screen#1',
      );
    });

    test('#3 #4 the MIME type is always application/zip', () async {
      await actions.showSendFileScreen('/tmp/export.zip');
      await actions.showSendFileScreen('/tmp/Loop Habits Backup.db');

      expect(sharer.mimeTypes, <String>['application/zip', 'application/zip'],
          reason: 'io.share-file-screen#3 io.share-file-screen#4 '
              'hard-coded even for a .db backup');
      expect(DataActions.shareMimeType, 'application/zip',
          reason: 'io.share-file-screen#3');
    });

    test('#5 a missing share target shows a message instead of crashing',
        () async {
      sharer.error = Exception('no activity found');

      await actions.showSendFileScreen('/tmp/export.zip');

      expect(messages, <DataActionMessage>[DataActionMessage.activityNotFound],
          reason: 'io.share-file-screen#5');
      expect(dataActionMessageText(L10nEn(), DataActionMessage.activityNotFound),
          L10nEn().activityNotFound,
          reason: 'io.share-file-screen#5 R.string.activity_not_found');
    });
  });

  // -------------------------------------------------------------------
  // startActivitySafely(Intent(ACTION_VIEW, ...))
  // -------------------------------------------------------------------

  group('settings.screen.troubleshooting-and-links', () {
    late FakeUrlOpener opener;
    late List<DataActionMessage> messages;
    late DataActions actions;

    setUp(() {
      final scope = openScope();
      opener = FakeUrlOpener();
      messages = <DataActionMessage>[];
      actions = DataActions(
        scope: scope,
        dirFinder: HabitsDirFinder(<String>[makeDir('external6')]),
        cacheDir: makeDir('cache6'),
        fileChooser: FakeFileChooser(),
        fileSharer: FakeFileSharer(),
        urlOpener: opener,
        importTaskFactory: ImportDataTaskFactory(
          GenericImporter(
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
            RecordingImporter(),
          ),
          scope.modelFactory,
        ),
        showMessage: messages.add,
      );
    });

    test('#5 the two link rows open their URLs', () async {
      await actions.openUrl(SettingsScreen.helpUrl);
      await actions.openUrl(SettingsScreen.rateAppUrl);

      expect(
        opener.urls,
        <String>[
          'http://loophabits.org/faq.html',
          'market://details?id=org.isoron.uhabits',
        ],
        reason: 'settings.screen.troubleshooting-and-links#5',
      );
      expect(messages, isEmpty,
          reason: 'settings.screen.troubleshooting-and-links#5');
    });

    test('#6 a URL nothing can open shows a message', () async {
      opener.result = false;
      await actions.openUrl(SettingsScreen.rateAppUrl);

      opener
        ..result = true
        ..error = Exception('ActivityNotFoundException');
      await actions.openUrl(SettingsScreen.helpUrl);

      expect(
        messages,
        <DataActionMessage>[
          DataActionMessage.activityNotFound,
          DataActionMessage.activityNotFound,
        ],
        reason: 'settings.screen.troubleshooting-and-links#6',
      );
      expect(
          dataActionMessageText(L10nEn(), DataActionMessage.activityNotFound),
          'No app was found to support this action',
          reason: 'settings.screen.troubleshooting-and-links#6');
    });
  });

  // -------------------------------------------------------------------
  // The FileOpener the Loop importer reads its migrations through
  // -------------------------------------------------------------------

  group('FlutterFileOpener', () {
    test('user files resolve against the app data directory', () {
      final opener = FlutterFileOpener(userDataDir: tempDir.path);

      expect(opener.openUserFile('Backups/x.db').pathString,
          '${tempDir.path}/Backups/x.db');
    });

    test('a migration resource file serves the built-in script', () async {
      final opener = FlutterFileOpener(userDataDir: tempDir.path);
      final file = opener.openResourceFile('migrations/09.sql');

      expect(await file.exists(), isTrue);
      // `lines()` drops the line terminators, so the script comes back without
      // its trailing newline — the same as every other ResourceFile.
      expect(await file.lines(), const LineSplitter().convert(migrationSql[9]!));
      expect(await opener.openResourceFile('migrations/99.sql').exists(),
          isFalse);
    });

    test('a missing resource file throws when read', () {
      final opener = FlutterFileOpener(userDataDir: tempDir.path);

      expect(opener.openResourceFile('migrations/99.sql').lines(),
          throwsA(isA<FileSystemException>()));
    });

    test('copyTo writes the script where the caller asked', () async {
      final opener = FlutterFileOpener(userDataDir: tempDir.path);
      final dest = LocalUserFile('${tempDir.path}/copy/09.sql');

      await opener.openResourceFile('migrations/09.sql').copyTo(dest);

      expect(File(dest.pathString).readAsStringSync(),
          const LineSplitter().convert(migrationSql[9]!).join('\n'));
    });
  });
}
