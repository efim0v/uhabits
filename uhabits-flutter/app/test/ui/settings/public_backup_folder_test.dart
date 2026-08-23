/// The `publicBackupFolder` half of `settings.screen.database-category`.
///
/// Rules #1..#6 and #12..#16 — the four rows, their strings, the result codes
/// and the messages — are asserted in test/ui/settings/settings_screen_test
/// .dart. What is left is the folder the backups go to:
///
///  * `#9` is pure string arithmetic over a tree URI, and is ported verbatim as
///    [fullPathFor];
///  * `#10` and `#11` are `AutoBackup`, whose private-directory branch is the
///    whole of what this build can run.
///
/// `#7` and `#8` are the Storage Access Framework itself —
/// `ACTION_OPEN_DOCUMENT_TREE` with `FLAG_GRANT_PERSISTABLE_URI_PERMISSION`,
/// and `takePersistableUriPermission` on the way back. Neither has a Flutter
/// API, the `publicBackupFolder` row is rendered disabled for exactly that
/// reason, and they are deliberately left uncited rather than approximated.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/auto_backup.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_public_backup');
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  ({SettingsModel model, MemoryStorage storage}) buildModel() {
    final MemoryStorage storage = MemoryStorage();
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits${databaseIndex++}.db'),
      preferencesStorage: storage,
    );
    scopes.add(scope);
    final SettingsModel model = SettingsModel(scope, storage: storage);
    addTearDown(model.dispose);
    return (model: model, storage: storage);
  }

  group('settings.screen.database-category', () {
    test('#9 a tree URI is rendered as the path a user recognises', () {
      const String rule =
          'settings.screen.database-category#9 — '
          'updatePublicBackupFolderSummary() renders a human-readable path: for '
          'a "content" URI it takes DocumentsContract.getTreeDocumentId(uri), '
          'splits it on the first ":" into (type, rel), uses '
          'Environment.getExternalStorageDirectory().absolutePath as base when '
          'type equalsIgnoreCase "primary" and "/storage/<type>" otherwise, and '
          'appends "/<rel>" when rel is non-empty; for a "file" URI it uses '
          'File(uri.path).absolutePath; for any other scheme it falls back to '
          'the raw URI string.';

      // The everyday case: the primary volume, with a relative path.
      expect(
        fullPathFor(Uri.parse(
            'content://com.android.externalstorage.documents/tree/primary%3ADocuments%2FLoop')),
        '$primaryExternalStorageDir/Documents/Loop',
        reason: rule,
      );
      // …and without one: no trailing slash is added.
      expect(
        fullPathFor(Uri.parse(
            'content://com.android.externalstorage.documents/tree/primary%3A')),
        primaryExternalStorageDir,
        reason: '$rule rel is empty, so the base stands alone.',
      );
      // equalsIgnoreCase.
      expect(
        fullPathFor(Uri.parse(
            'content://com.android.externalstorage.documents/tree/PRIMARY%3ABackups')),
        '$primaryExternalStorageDir/Backups',
        reason: '$rule "primary" is matched case-insensitively.',
      );
      // A removable volume: the type becomes the volume directory.
      expect(
        fullPathFor(Uri.parse(
            'content://com.android.externalstorage.documents/tree/1A2B-3C4D%3ABackups')),
        '/storage/1A2B-3C4D/Backups',
        reason: rule,
      );
      // `limit = 2`: only the FIRST colon splits, so a path containing one
      // survives intact.
      expect(
        fullPathFor(Uri.parse(
            'content://com.android.externalstorage.documents/tree/primary%3Aa%3Ab')),
        '$primaryExternalStorageDir/a:b',
        reason: rule,
      );
      // A document id with no colon at all is all type and no relative path.
      expect(
        fullPathFor(Uri.parse(
            'content://com.android.externalstorage.documents/tree/downloads')),
        '/storage/downloads',
        reason: rule,
      );

      // "file" -> the absolute path.
      expect(fullPathFor(Uri.parse('file:///storage/emulated/0/Backups')),
          '/storage/emulated/0/Backups', reason: rule);

      // Any other scheme -> null, which is the caller's cue to show the raw
      // string instead.
      expect(fullPathFor(Uri.parse('http://example.org/backups')), isNull,
          reason: rule);
    });

    test('#9 the row summary is that path, the raw URI, or "no folder"', () {
      const String rule =
          'settings.screen.database-category#9 — the summary is '
          'fullPathFor(uri) ?: uriString, and rule #6\'s "No folder selected" '
          'when the key is unset.';

      final built = buildModel();
      expect(built.model.publicBackupFolderSummary, isNull,
          reason: '$rule Null is what the screen turns into "No folder '
              'selected".');

      built.storage.putString('publicBackupFolder',
          'content://com.android.externalstorage.documents/tree/primary%3ALoop');
      expect(built.model.publicBackupFolderSummary,
          '$primaryExternalStorageDir/Loop', reason: rule);

      // A scheme fullPathFor cannot render falls back to the stored string
      // rather than to "No folder selected".
      built.storage.putString('publicBackupFolder', 'weird://somewhere/else');
      expect(built.model.publicBackupFolderSummary, 'weird://somewhere/else',
          reason: rule);

      // A content URI that is not a tree URI throws, exactly as
      // DocumentsContract.getTreeDocumentId does — the original has no guard
      // either.
      built.storage.putString(
          'publicBackupFolder', 'content://com.example.provider/document/7');
      expect(() => built.model.publicBackupFolderSummary,
          throwsA(isA<ArgumentError>()), reason: rule);
    });

    test('#10 with no folder set the backup lands in the private Backups dir',
        () async {
      const String rule =
          'settings.screen.database-category#10 — AutoBackup and ExportDBTask '
          'both read "publicBackupFolder" directly from default '
          'SharedPreferences: when set they write into that DocumentFile tree '
          '(DocumentFile.fromTreeUri for content URIs, DocumentFile.fromFile '
          'for file URIs), otherwise they fall back to the app-private '
          '"Backups" files directory. Only the fallback is reachable here: the '
          'Storage Access Framework has no Flutter API, so the key is never '
          'written and the DocumentFile branch has nothing to build from '
          '(reported with #7 and #8).';

      // The key both sides agree on, and its unset state.
      final built = buildModel();
      expect(built.storage.getString('publicBackupFolder', 'unset'), 'unset',
          reason: '$rule Nothing writes it.');
      expect(built.model.publicBackupFolder, isNull, reason: rule);

      // The fallback directory, named the same on both sides.
      expect(HabitsDirFinder.backupsDirName, 'Backups', reason: rule);

      final String dbPath = '${tempDir.path}/backup-source.db';
      AppDatabase.openAndMigrate(dbPath).close();
      final AutoBackup backup = AutoBackup(
        databasePath: dbPath,
        dirFinder: HabitsDirFinder(<String>[tempDir.path]),
      );
      final AutoBackupResult result = await backup.run();

      expect(result.directory, '${tempDir.path}/Backups', reason: rule);
      expect(result.written, isNotNull,
          reason: '$rule …and the copy really went there.');
      expect(File(result.written!).existsSync(), isTrue, reason: rule);
      expect(result.written, startsWith('${tempDir.path}/Backups/'),
          reason: rule);
    });

    test('#11 five is the default, and the oldest go first', () async {
      const String rule =
          'settings.screen.database-category#11 — AutoBackup keeps the newest 5 '
          'backup files by default (keep = 5) and matches existing backups with '
          r'the regex ^Loop Habits Backup .+\.db\$' ' The regex belongs to the '
          'public-directory branch only — runInPrivateDir passes '
          'dir.listFiles() straight through, with no name filter — so the port, '
          'which has only the private branch, has nothing to filter with. What '
          'it does keep is the default and the rotation.';

      expect(AutoBackup.defaultKeep, 5, reason: '$rule keep = 5.');

      final String dir = '${tempDir.path}/Backups';
      Directory(dir).createSync(recursive: true);
      // Seven files, oldest first. The names follow the pattern the rule
      // quotes, which is also what `backupFileName` produces.
      final List<String> names = <String>[
        for (int day = 1; day <= 7; day++)
          backupFileName(DateTime.utc(2015, 1, day)),
      ];
      for (int i = 0; i < names.length; i++) {
        final File file = File('$dir/${names[i]}')..writeAsStringSync('$i');
        file.setLastModifiedSync(
          DateTime.fromMillisecondsSinceEpoch(1000000 + i * 1000),
        );
      }
      for (final String name in names) {
        expect(RegExp(r'^Loop Habits Backup .+\.db$').hasMatch(name), isTrue,
            reason: '$rule The names this build writes are the ones the '
                'upstream pattern matches ($name).');
      }

      final String dbPath = '${tempDir.path}/rotate-source.db';
      AppDatabase.openAndMigrate(dbPath).close();
      final AutoBackupResult result = await AutoBackup(
        databasePath: dbPath,
        dirFinder: HabitsDirFinder(<String>[tempDir.path]),
        // A clock far enough from the newest file that a new backup is due.
        localTime: () => 1000000 + 6 * 1000 + DateUtils.dayLength + 1,
      ).run();

      expect(result.deleted, hasLength(2),
          reason: '$rule Seven files, keep five: two go.');
      expect(
        result.deleted.map((String p) => p.split('/').last),
        <String>[names[0], names[1]],
        reason: '$rule …and they are the two oldest.',
      );
      expect(File('$dir/${names[6]}').existsSync(), isTrue,
          reason: '$rule The newest is never touched.');
    });
  });
}
