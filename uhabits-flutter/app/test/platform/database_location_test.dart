/// `persistence.db-file-location` — where the database file lives, and what
/// opening it actually does.
///
/// Upstream is `DatabaseUtils.getDatabaseFile(context)`:
/// `File("${context.filesDir.path}/../databases/$databaseFilename")`, plus
/// `initializeDatabase`/`openDatabase` and the instrumentation-only test mode.
/// Flutter has no `filesDir`; the counterpart is `path_provider`'s application
/// support directory, which is the same per-app, per-platform private root, and
/// the filename constant is shared with the Kotlin core.
///
/// Two halves of this feature have no counterpart and are called out where they
/// come up: there is no `isTestMode()` in the port, so the filename is never
/// "test.db" (`#2`) and startup never deletes the file (`#3`).
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uhabits/platform/app_database.dart';
// SQLModelFactory is not re-exported from uhabits_core.dart.
// ignore: implementation_imports
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory supportDir;

  setUp(() {
    resetToday();
    supportDir = Directory.systemTemp.createTempSync('uhabits_db_location');
    // `flutter test` registers no plugins, so answering the channel is what
    // points `getApplicationSupportDirectory()` at a temporary root.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => supportDir.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    supportDir.deleteSync(recursive: true);
    resetToday();
  });

  group('persistence.db-file-location', () {
    test('#1 the file is the app-private storage root plus the filename '
        'constant', () async {
      final opened = await AppDatabase.open();
      addTearDown(opened.close);

      expect(opened.path, p.join(supportDir.path, databaseFilename),
          reason: 'persistence.db-file-location#1 — '
              'DatabaseUtils.getDatabaseFile(context) is the app\'s own '
              'storage directory plus the database filename; Android spells it '
              '"\${filesDir.path}/../databases/\$databaseFilename", this port '
              'spells it getApplicationSupportDirectory() + databaseFilename');
      expect(File(opened.path).existsSync(), isTrue,
          reason: 'persistence.db-file-location#1 — and that is the file that '
              'is actually opened');
      expect(p.dirname(opened.path), supportDir.path,
          reason: 'persistence.db-file-location#1 — it is inside the private '
              'per-app directory the platform hands back, never the working '
              'directory');
    });

    test('#2 the filename is always uhabits.db: there is no test mode',
        () async {
      expect(databaseFilename, 'uhabits.db',
          reason: 'persistence.db-file-location#2 — databaseFilename is '
              '"uhabits.db" normally');

      // `HabitsApplication.isTestMode()` is `Class.forName(
      // "org.isoron.uhabits.BaseAndroidTest")`, a JVM-only trick with no Dart
      // counterpart; this very test runs under the test binding and still gets
      // the production name.
      final opened = await AppDatabase.open();
      addTearDown(opened.close);
      expect(p.basename(opened.path), 'uhabits.db',
          reason: 'persistence.db-file-location#2 — the "test.db" branch has '
              'no counterpart in this port, so even a test run opens '
              'uhabits.db');
      expect(File(p.join(supportDir.path, 'test.db')).existsSync(), isFalse,
          reason: 'persistence.db-file-location#2 — nothing ever writes a '
              'test.db');
    });

    test('#3 startup never deletes the database file', () async {
      final first = await AppDatabase.open();
      final factory = SQLModelFactory(first.database);
      final list = factory.buildHabitList();
      setToday(LocalDate.ymd(2015, 1, 25));
      final habit = factory.buildHabit()..name = 'Meditate';
      list.add(habit);
      first.close();
      resetToday();

      final second = await AppDatabase.open();
      addTearDown(second.close);
      final reopened = SQLModelFactory(second.database).buildHabitList();

      expect(reopened.size(), 1,
          reason: 'persistence.db-file-location#3 — in test mode Android '
              'deletes the file before initializing; this port has no test '
              'mode, so nothing is ever deleted at startup');
      expect(reopened.first.name, 'Meditate',
          reason: 'persistence.db-file-location#3 — a second launch finds the '
              'same data');
    });

    test('#4 building the opener neither opens nor migrates anything', () {
      final path = p.join(supportDir.path, databaseFilename);

      // `DatabaseUtils.initializeDatabase(context)` only constructs and stores
      // the HabitsDatabaseOpener.
      const opener = Sqlite3DatabaseOpener();

      expect(opener, isA<DatabaseOpener>(),
          reason: 'persistence.db-file-location#4 — what initialization builds '
              'is an opener, nothing more');
      expect(File(path).existsSync(), isFalse,
          reason: 'persistence.db-file-location#4 — constructing it does not '
              'open or create the database file');

      // Only asking it to open touches the disk.
      File(path).createSync();
      final database = opener.open(path);
      addTearDown(database.close);
      expect(database.getVersion(), 0,
          reason: 'persistence.db-file-location#4 — and opening alone does not '
              'migrate: the file is still at user_version 0');
    });

    test('#5 opening for writing is what triggers create and upgrade', () {
      final path = p.join(supportDir.path, databaseFilename);
      expect(File(path).existsSync(), isFalse);

      final database = AppDatabase.openAndMigrate(path);
      addTearDown(database.close);

      expect(database.getVersion(), databaseVersion,
          reason: 'persistence.db-file-location#5 — openDatabase() returns '
              'opener.writableDatabase, which is what actually triggers '
              'onCreate/onUpgrade');
      expect(
        database.queryInt(
          "select count(*) from sqlite_master where type='table' and name='Habits'",
        ),
        1,
        reason: 'persistence.db-file-location#5 — the schema exists only after '
            'that call',
      );

      // The Kotlin `checkNotNull(opener)` guards against opening before
      // initialization; the port's equivalent failure is refusing a path it
      // cannot open at all.
      expect(
        () => const Sqlite3DatabaseOpener().open(p.join(supportDir.path, 'no.db')),
        throwsA(anything),
        reason: 'persistence.db-file-location#5 — and there is no silent '
            'fallback when the database cannot be opened',
      );
    });

    test('#6 there is exactly one database file for the whole app', () async {
      final first = await AppDatabase.open();
      final firstPath = first.path;
      first.close();

      final second = await AppDatabase.open();
      addTearDown(second.close);

      expect(second.path, firstPath,
          reason: 'persistence.db-file-location#6 — every open resolves the '
              'same path: there is no per-profile or per-user separation');
      expect(
        supportDir
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .where((name) => name.endsWith('.db'))
            .toList(),
        <String>[databaseFilename],
        reason: 'persistence.db-file-location#6 — and only one database file '
            'is ever created',
      );
    });
  });
}
