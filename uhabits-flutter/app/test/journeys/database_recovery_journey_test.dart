/// Journey: the app is opened on a database file it cannot use.
///
/// This is the worst thing a startup bug can be: `main()` awaits
/// `AppScope.boot()` *before* `runApp`, so an exception thrown down there is a
/// blank window with no screen, no error and no way out but reinstalling.
///
/// Four files a user can really arrive with are driven here, and Kotlin answers
/// them in two different ways.
///
/// ## The file is a database, but not one this build can use
///
/// `user_version` below 8 (older than migration 09) or above 25 (a backup from
/// a newer phone, or a downgrade install). `HabitsDatabaseOpener.onUpgrade`
/// and `onDowngrade` throw `UnsupportedDatabaseVersionException`, and the
/// Android app **does not recover**: `DatabaseUtils.initializeDatabase`
/// (DatabaseUtils.kt:52-58) only constructs the `SQLiteOpenHelper`, which by
/// contract opens nothing, so the `try`/`catch` at HabitsApplication.kt:54-60
/// has nothing to catch and its rename is dead code. The file is first opened
/// lazily at `component.habitList` (:73), thirteen lines past the catch, and
/// the throw escapes `Application.onCreate` — the launcher icon opens
/// "Loop Habit Tracker keeps stopping", every launch, with the user's habits
/// still sitting untouched in `databases/uhabits.db`.
///
/// This port renames the file to `<absolutePath>.invalid` and boots empty
/// instead. That is a **deliberate divergence**, not parity
/// (`audit10.the-invalid-quarantine-is-the-ports-own#1`, DEVIATIONS.md): a
/// crash loop leaves the user with an app that cannot be opened at all, and
/// setting the file aside keeps the data recoverable where Kotlin's own
/// recovery path — had it ever run — would have done the same.
///
/// ## The file is not a readable database at all
///
/// A zeroed header, a truncated copy, a page killed mid-write. Here Android
/// *does* recover, in the framework rather than in `HabitsApplication`:
/// `HabitsDatabaseOpener` passes a null `errorHandler` to `SQLiteOpenHelper`
/// (HabitsDatabaseOpener.kt:35), so `SQLiteDatabase.open()` catches the
/// `SQLiteDatabaseCorruptException` that SQLITE_NOTADB and SQLITE_CORRUPT map
/// to, hands the file to `DefaultDatabaseErrorHandler.onCorruption()` — which
/// deletes it — and reopens with `CREATE_IF_NECESSARY`. The app launches empty
/// (`audit10.a-corrupt-database-file-recovers#1`). The port reaches the same
/// outcome, differing only in setting the file aside instead of deleting it.
///
/// All four are driven the way the user meets them: the device keeps its files
/// between launches, so a launch, a change to the file the app left behind, and
/// a second launch is exactly the sequence a downgrade or a killed write
/// produces. Nothing here calls `AppDatabase.openAndMigrate` itself — a test
/// that opens the file directly proves the opener throws and says nothing about
/// whether anyone catches it.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits_core/uhabits_core.dart'
    show Database, DatabaseExtensions, Sqlite3DatabaseOpener, databaseVersion;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_database');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// `File(db.absolutePath + ".invalid")`.
  File invalidFile() => File('${device.databaseFile.path}.invalid');

  /// Rewrites `PRAGMA user_version` on the file the app left behind, which is
  /// the only thing that distinguishes a database written by another build.
  void stampUserVersion(int version) {
    final Database db =
        const Sqlite3DatabaseOpener().open(device.databaseFile.path);
    db.setVersion(version);
    db.close();
  }

  /// What the app's own file says its schema version is.
  int storedUserVersion() {
    final Database db =
        const Sqlite3DatabaseOpener().open(device.databaseFile.path);
    final int version = db.getVersion();
    db.close();
    return version;
  }

  /// Zeroes the 16-byte SQLite header magic: the smallest edit that turns a
  /// real database into "file is not a database".
  void corruptHeader() {
    final Uint8List bytes = device.databaseFile.readAsBytesSync();
    final Uint8List patched = Uint8List.fromList(bytes);
    patched.fillRange(0, 16, 0);
    device.databaseFile.writeAsBytesSync(patched, flush: true);
  }

  /// Keeps the first [length] bytes and drops the rest, the way an interrupted
  /// write or a partial copy leaves the file.
  void truncateTo(int length) {
    final Uint8List bytes = device.databaseFile.readAsBytesSync();
    device.databaseFile.writeAsBytesSync(bytes.sublist(0, length), flush: true);
  }

  /// A device that has been used: one launch, the intro skipped, one habit.
  Future<void> useTheAppOnce(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Wake up early');
    await app.quit();
  }

  testWidgets('a database newer than this build is renamed and left alone',
      (WidgetTester tester) async {
    await useTheAppOnce(tester);

    // The user restores a backup taken on a phone running a newer Loop, or
    // downgrades the app. `onDowngrade` upstream always throws.
    stampUserVersion(databaseVersion + 1);

    await app.launch();

    expect(find.byType(HabitListScreen), findsOneWidget,
        reason: 'audit10.the-invalid-quarantine-is-the-ports-own#1: the port '
            'opens on a fresh empty app. Android crash-loops here instead — '
            'the catch at HabitsApplication.kt:54-60 cannot fire, because '
            'DatabaseUtils.initializeDatabase never opens the file — so this '
            'is the port\'s deliberate divergence, not parity. A boot that '
            'throws happens before runApp, so there would be no screen at '
            'all.');
    expect(invalidFile().existsSync(), isTrue,
        reason: 'audit10.the-invalid-quarantine-is-the-ports-own#1: the file '
            'is renamed to `<absolutePath>.invalid` rather than deleted, so '
            'the habits Android would have left in place are still recoverable '
            'here.');
    expect(storedUserVersion(), databaseVersion,
        reason: 'audit10.the-invalid-quarantine-is-the-ports-own#1: and a '
            'fresh database takes its place, so the file the app now runs on '
            'is this build\'s schema. persistence.android-opener#5: the newer '
            'file is refused rather than silently used — that half IS what '
            'onDowngrade does.');
    verifyDoesNotDisplayText('Wake up early',
        reason: 'the fresh database is empty; the old habits went with the '
            'file that was set aside');
  });

  testWidgets('a database older than the first migration is renamed too',
      (WidgetTester tester) async {
    await useTheAppOnce(tester);

    // `onUpgrade` throws for anything below 8: there is no migration script
    // that low, so the file cannot be brought forward.
    stampUserVersion(5);

    await app.launch();

    expect(find.byType(HabitListScreen), findsOneWidget,
        reason: 'audit10.the-invalid-quarantine-is-the-ports-own#1: '
            'persistence.android-opener#4 — user_version below 8 makes the '
            'opener throw, which is parity; what follows is not. Upstream that '
            'throw escapes Application.onCreate; here it is caught and turned '
            'into a fresh empty app rather than a startup that never reaches '
            'runApp.');
    expect(invalidFile().existsSync(), isTrue,
        reason: 'audit10.the-invalid-quarantine-is-the-ports-own#1: renamed to '
            '`<absolutePath>.invalid` — the port\'s own recovery');
    expect(storedUserVersion(), databaseVersion,
        reason: 'audit10.the-invalid-quarantine-is-the-ports-own#1: and a '
            'fresh database takes its place');
  });

  testWidgets('a corrupt database file is set aside and the app still starts',
      (WidgetTester tester) async {
    await useTheAppOnce(tester);

    // A killed write, a half-synced copy, a bad restore: the file is still a
    // file, but the 16-byte SQLite header no longer says so. `PRAGMA
    // user_version` raises `SqliteException(26): file is not a database`.
    corruptHeader();

    await app.launch();

    expect(find.byType(HabitListScreen), findsOneWidget,
        reason: 'audit10.a-corrupt-database-file-recovers#1: the framework '
            'hands the unreadable file to DefaultDatabaseErrorHandler and the '
            'app comes up on a fresh database. A boot that throws happens '
            'before runApp, so there would be no screen at all.');
    expect(invalidFile().existsSync(), isTrue,
        reason: 'audit10.a-corrupt-database-file-recovers#1: Android deletes '
            'the file; the port sets it aside as `<absolutePath>.invalid` '
            'instead, so the bytes are still there to be recovered.');
    expect(storedUserVersion(), databaseVersion,
        reason: 'audit10.a-corrupt-database-file-recovers#1: the replacement '
            "is this build's own schema, built by onCreate + the migrations.");
    verifyDoesNotDisplayText('Wake up early',
        reason: 'the fresh database is empty; the old habits went with the '
            'file that was set aside');
  });

  testWidgets('a truncated database file recovers the same way',
      (WidgetTester tester) async {
    await useTheAppOnce(tester);

    // The likelier artifact of a killed write than a zeroed header: the header
    // is intact and the pages behind it are gone. sqlite answers
    // `SqliteException(11): database disk image is malformed`.
    truncateTo(2048);

    await app.launch();

    expect(find.byType(HabitListScreen), findsOneWidget,
        reason: 'audit10.a-corrupt-database-file-recovers#1: SQLITE_CORRUPT '
            'and SQLITE_NOTADB both reach SQLiteDatabaseCorruptException, so '
            'Android recovers from a truncated file too.');
    expect(invalidFile().existsSync(), isTrue,
        reason: 'audit10.a-corrupt-database-file-recovers#1: set aside as '
            '`<absolutePath>.invalid` rather than deleted');
  });

  testWidgets('a usable database is never renamed', (WidgetTester tester) async {
    await useTheAppOnce(tester);

    await app.launch();

    expect(invalidFile().existsSync(), isFalse,
        reason: 'audit10.the-invalid-quarantine-is-the-ports-own#1: only a '
            'file the app cannot use is set aside; an ordinary launch keeps '
            'its data');
    verifyDisplaysText('Wake up early',
        reason: 'and the habits are still there');
  });
}
