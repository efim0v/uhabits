/// Journey: the user exports their data.
///
/// `verify.integration-harness#3`, journey 7 — "export data".
///
/// Upstream this is `BackupTest.shouldExportAndImportBackup`, whose first half
/// is `exportFullBackup()` — open Settings, tap "Export full backup", and a
/// `.db` copy appears in the app's `Backups` folder and is handed to the share
/// sheet.
///
/// The whole point of driving it from Settings is that upstream the settings
/// screen does none of the work: every database row is `setResult(code);
/// finish()`, and `ListHabitsActivity.onActivityResult` is what actually
/// exports. `audit.every-data-troubleshooting-row-in-settings` was exactly
/// that seam left unplugged, so this journey walks it end to end: tap the row,
/// watch the file appear on disk, and watch the share sheet be handed it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_export');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  Future<void> launchWithHabit(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(
      tester,
      name: 'Wake up early',
      question: 'Did you wake up early today?',
    );
  }

  List<String> filesIn(Directory dir) => dir.existsSync()
      ? (dir.listSync().whereType<File>().map((File f) => f.path).toList()
        ..sort())
      : <String>[];

  testWidgets('"Export full backup" writes a database copy and shares it',
      (WidgetTester tester) async {
    await launchWithHabit(tester);
    // `ListHabitsActivity.onResume` runs AutoBackup into the very same folder,
    // so the journey compares against what was already there rather than
    // assuming an empty directory.
    final List<String> before = filesIn(device.backupsDir);

    await openSettings(tester);
    await tapSettingsRow(tester, 'exportDB');

    expect(find.byType(SettingsScreen), findsNothing,
        reason: 'settings.screen.database-category: the row is setResult(103); '
            'finish() — the screen closes and the list acts on the code');
    expect(find.byType(HabitListScreen), findsOneWidget);

    final List<String> after = filesIn(device.backupsDir);
    final Set<String> created = after.toSet().difference(before.toSet());
    expect(created, hasLength(1),
        reason: 'verify.integration-harness#3: "export data". '
            'RESULT_EXPORT_DB -> onExportDB() -> ExportDBTask, which copies '
            'the live uhabits.db into <external files>/Backups. A settings '
            'screen whose result nobody reads writes no file at all.');
    expect(created.single, endsWith('.db'),
        reason: 'DatabaseUtils.saveDatabaseCopy names the copy '
            '"Loop Habits Backup <yyyy-MM-dd HHmmss>.db"');
    expect(File(created.single).lengthSync(), greaterThan(0),
        reason: 'and it is a real copy of the database, not an empty file');

    expect(device.sharedFiles, <String>[created.single],
        reason: 'ListHabitsScreen.showSendFileScreen(filename): the export ends '
            'in an ACTION_SEND intent carrying the file. The share sheet is '
            'the only way the user gets the backup off the device.');
  });

  testWidgets('"Export as CSV" writes an archive and shares it',
      (WidgetTester tester) async {
    await launchWithHabit(tester);
    expect(device.csvDir.existsSync(), isFalse,
        reason: 'the precondition: nothing has exported yet');

    await openSettings(tester);
    await tapSettingsRow(tester, 'exportCSV');

    final List<String> written = filesIn(device.csvDir);
    expect(written, hasLength(1),
        reason: 'RESULT_EXPORT_CSV -> behavior.onExportCSV() -> ExportCSVTask, '
            'which zips the CSV files into <external files>/CSV');
    expect(File(written.single).lengthSync(), greaterThan(0));
    expect(device.sharedFiles, <String>[written.single],
        reason: 'and the archive is handed to the share sheet, exactly as the '
            'full backup is');
  });

  testWidgets('the exported backup is a database the app can open again',
      (WidgetTester tester) async {
    await launchWithHabit(tester);
    final List<String> before = filesIn(device.backupsDir);

    await openSettings(tester);
    await tapSettingsRow(tester, 'exportDB');

    final String backup =
        filesIn(device.backupsDir).toSet().difference(before.toSet()).single;
    // The bytes of the live database, byte for byte: this is what makes the
    // backup restorable at all. `BackupTest.shouldExportAndImportBackup` proves
    // the same thing by importing the file back.
    expect(File(backup).readAsBytesSync(),
        device.databaseFile.readAsBytesSync(),
        reason: 'saveDatabaseCopy is a plain file copy of the live database, '
            'so an export made while the app is running has to contain the '
            'habit the user just created');
  });
}
