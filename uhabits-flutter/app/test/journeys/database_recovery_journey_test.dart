/// Journey: the app is opened on a database file it cannot use.
///
/// `audit3.an-unusable-database-file-is-no#1` — "A database file the app cannot
/// use — user_version below 8, or newer than the app's 25 — makes the opener
/// throw; HabitsApplication catches it, renames the file to
/// `<absolutePath>.invalid`, and re-initialises, so the user gets a fresh empty
/// app instead of a permanent crash loop."
///
/// This is the worst thing a startup bug can be: `main()` awaits
/// `AppScope.boot()` *before* `runApp`, so an exception thrown down there is a
/// blank window with no screen, no error and no way out but reinstalling. The
/// two files a user can arrive with are the two ends of the supported range —
/// a database written by a build older than migration 09, and a database
/// written by a build newer than this one, which is what happens when someone
/// downgrades the app or restores a backup from a newer phone.
///
/// Both are driven the way the user meets them: the device keeps its files
/// between launches, so a launch, a stamp on the file the app left behind, and
/// a second launch is exactly the sequence a downgrade produces. Nothing here
/// calls `AppDatabase.openAndMigrate` itself — a test that opens the file
/// directly proves the opener throws and says nothing about whether anyone
/// catches it.
library;

import 'dart:io';

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
        reason: 'audit3.an-unusable-database-file-is-no#1: the user gets a '
            'fresh empty app instead of a permanent crash loop. A boot that '
            'throws happens before runApp, so there is no screen at all.');
    expect(invalidFile().existsSync(), isTrue,
        reason: 'audit3.an-unusable-database-file-is-no#1: HabitsApplication '
            'renames the file to `<absolutePath>.invalid`. Keeping it is what '
            'lets the data be recovered afterwards.');
    expect(storedUserVersion(), databaseVersion,
        reason: 'audit3.an-unusable-database-file-is-no#1: and re-initialises, '
            'so the file the app now runs on is this build\'s schema — the '
            'newer file is refused rather than silently used.');
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
        reason: 'audit3.an-unusable-database-file-is-no#1: user_version below '
            '8 makes the opener throw, and the catch turns that into a fresh '
            'empty app rather than a startup that never reaches runApp.');
    expect(invalidFile().existsSync(), isTrue,
        reason: 'audit3.an-unusable-database-file-is-no#1: renamed to '
            '`<absolutePath>.invalid`');
    expect(storedUserVersion(), databaseVersion,
        reason: 'audit3.an-unusable-database-file-is-no#1: and re-initialised');
  });

  testWidgets('a usable database is never renamed', (WidgetTester tester) async {
    await useTheAppOnce(tester);

    await app.launch();

    expect(invalidFile().existsSync(), isFalse,
        reason: 'audit3.an-unusable-database-file-is-no#1: only a file the app '
            'cannot use is set aside; an ordinary launch keeps its data');
    verifyDisplaysText('Wake up early',
        reason: 'and the habits are still there');
  });
}
