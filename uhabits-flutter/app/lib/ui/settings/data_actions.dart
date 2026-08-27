/// The glue behind the Database and Links rows of the settings screen.
///
/// Port of the parts of
/// uhabits-android/.../activities/habits/list/ListHabitsScreen.kt that the
/// settings screen hands work to — `onSettingsResult`, `showImportScreen`,
/// `onOpenDocumentResult`, `onImportData` and `onExportDB` — together with
/// `uhabits-android/.../tasks/ExportDBTask.kt`, the `showSendFileScreen` and
/// `startActivitySafely` extensions of
/// uhabits-android/.../utils/ViewExtensions.kt, and the two presenter entry
/// points those rows reach, `ListHabitsBehavior.onExportCSV` and
/// `ListHabitsBehavior.onRepairDB`.
///
/// The Android settings screen never does the work: each row calls
/// `setResult(code); finish()` and the list screen acts on the code. The
/// Flutter screen pops with a [SettingsResult], and [DataActions.onSettingsResult]
/// is the `when (resultCode)` block that receives it.
///
/// Everything here is plain Dart driven through three one-method seams —
/// [FileChooser], [FileSharer] and [UrlOpener] — because file_picker,
/// share_plus and url_launcher are plugins and a plugin cannot run in a widget
/// test. [DataActions.create] wires the real ones.
///
/// Two Android-only rows are deliberately left inert, exactly as the settings
/// screen already renders them: `publicBackupFolder` (a Storage Access
/// Framework tree URI) and the automatic daily backup that reads the same
/// preference. Every backup therefore goes to the app-private `Backups`
/// folder, which is the `publicBackupFolder == null` branch of `ExportDBTask`.
library;

// The io, task and importer layers of the core are reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches the commands layer.
// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/computed/definition_importer.dart';
import 'package:uhabits_core/src/computed/lapse_importer.dart';
import 'package:uhabits_core/src/io/abstract_importer.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/generic_importer.dart';
import 'package:uhabits_core/src/io/habit_bull_csv_importer.dart'
    show HabitBullCSVImporter;
import 'package:uhabits_core/src/io/habits_csv_exporter.dart';
import 'package:uhabits_core/src/io/loop_db_importer.dart';
import 'package:uhabits_core/src/io/rewire_db_importer.dart'
    show RewireDBImporter;
import 'package:uhabits_core/src/io/tickmate_db_importer.dart'
    show TickmateDBImporter;
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart'
    show
        Habit,
        HabitList,
        SleepImporter,
        Sqlite3DatabaseOpener,
        attachDefinitions;

import '../../l10n/app_localizations.dart';
import '../../platform/bug_reporter.dart';
import '../../platform/external_links.dart';
import '../../platform/flutter_files.dart';
import '../../state/app_scope.dart';
import '../../state/settings_model.dart';
import '../common/show_message.dart';

/// Everything [DataActions] asks the screen to show, and the string resource
/// each one stands for.
///
/// Android draws four of these through `ListHabitsBehavior.Message` and the
/// fifth (`activityNotFound`) straight from `startActivitySafely`. They are one
/// enum here because the caller shows them all the same way — as a snackbar.
enum DataActionMessage {
  /// `R.string.could_not_export` — "Failed to export data."
  couldNotExport,

  /// `R.string.habits_imported` — "Habits imported successfully."
  importSuccessful,

  /// `R.string.could_not_import` — "Failed to import data."
  importFailed,

  /// `R.string.file_not_recognized` — "File not recognized."
  fileNotRecognized,

  /// `R.string.activity_not_found` — "No app was found to support this action"
  activityNotFound,

  /// `ListHabitsBehavior.Message.COULD_NOT_GENERATE_BUG_REPORT`,
  /// `R.string.bug_report_failed` — "Failed to generate bug report."
  couldNotGenerateBugReport,

  /// `ListHabitsBehavior.Message.DATABASE_REPAIRED`,
  /// `R.string.database_repaired` — "Database repaired."
  databaseRepaired,
}

/// `Activity.startActivitySafely(Intent(ACTION_VIEW, Uri.parse(url)))`.
///
/// Returns false when nothing could handle the URL; throwing means the same
/// thing. Android has exactly one failure mode here,
/// `ActivityNotFoundException`, and url_launcher has both.
abstract interface class UrlOpener {
  Future<bool> open(String url);
}

/// [UrlOpener] over `platform/external_links.dart`, which is the one place
/// url_launcher is called from.
class PlatformUrlOpener implements UrlOpener {
  const PlatformUrlOpener();

  @override
  Future<bool> open(String url) => openExternalUrl(url);
}

/// The export, import, repair, share and link actions the settings screen
/// triggers.
class DataActions {
  DataActions({
    required this.scope,
    required this.dirFinder,
    required this.cacheDir,
    required this.fileChooser,
    required this.fileSharer,
    required this.urlOpener,
    required this.importTaskFactory,
    required this.showMessage,
    FlutterBugReporter? bugReporter,
    SendEmailScreen? emailScreen,
    void Function()? refreshHabitList,
    DateTime Function()? clock,
  })  : _refreshHabitList = refreshHabitList,
        _bugReporter = bugReporter,
        _emailScreen = emailScreen,
        _clock = clock ?? DateTime.now;

  /// Wires the real plugins. The one call the app makes at startup.
  static DataActions create({
    required AppScope scope,
    required AppDirectories directories,
    required void Function(DataActionMessage message) showMessage,
  }) {
    final fileOpener = FlutterFileOpener(userDataDir: directories.filesDir);
    return DataActions(
      scope: scope,
      dirFinder: HabitsDirFinder.of(directories),
      cacheDir: directories.cacheDir,
      fileChooser: const PlatformFileChooser(),
      fileSharer: const PlatformFileSharer(),
      urlOpener: const PlatformUrlOpener(),
      importTaskFactory: ImportDataTaskFactory(
        buildGenericImporter(scope: scope, fileOpener: fileOpener),
        scope.modelFactory,
        logging: scope.logging,
      ),
      showMessage: showMessage,
      bugReporter: FlutterBugReporter(
        dirFinder: HabitsDirFinder.of(directories),
        deviceInfo: DeviceInfo.current(),
      ),
      emailScreen: SendEmailScreen(opener: const PlatformUrlOpener().open),
    );
  }

  final AppScope scope;

  final HabitsDirFinder dirFinder;

  /// `activity.externalCacheDir`, where the file being imported is copied.
  final String cacheDir;

  final FileChooser fileChooser;

  final FileSharer fileSharer;

  final UrlOpener urlOpener;

  final ImportDataTaskFactory importTaskFactory;

  /// `activity.showMessage(...)`.
  final void Function(DataActionMessage message) showMessage;

  /// `adapter.refresh()` after a successful import. Overridable so a test can
  /// observe it without starting a background refresh.
  final void Function()? _refreshHabitList;

  /// `ListHabitsModule`, the `@Inject` class extending `AndroidBugReporter`
  /// that binds `ListHabitsBehavior.BugReporter` for the list screen. Null on
  /// a host that could not resolve its directories.
  final FlutterBugReporter? _bugReporter;

  /// `Activity.showSendEmailScreen(...)`.
  final SendEmailScreen? _emailScreen;

  /// `System.currentTimeMillis()`, which is what names a backup file.
  final DateTime Function() _clock;

  /// `type = "application/zip"` in `showSendFileScreen`, hard-coded even when
  /// what is being shared is a `.db` full backup.
  static const String shareMimeType = 'application/zip';

  TaskRunner get _taskRunner => scope.taskRunner;

  /// `ListHabitsScreen.onSettingsResult(resultCode)`:
  ///
  /// ```kotlin
  /// when (resultCode) {
  ///     RESULT_IMPORT_DATA -> showImportScreen()
  ///     RESULT_EXPORT_CSV -> behavior.value.onExportCSV()
  ///     RESULT_EXPORT_DB -> onExportDB()
  ///     RESULT_BUG_REPORT -> behavior.value.onSendBugReport()
  ///     RESULT_REPAIR_DB -> behavior.value.onRepairDB()
  /// }
  /// ```
  ///
  /// All five arms do their work; the `when` has no `else`, so a code the
  /// settings screen never sets cannot reach it.
  Future<void> onSettingsResult(SettingsResult result) async {
    switch (result) {
      case SettingsResult.importData:
        return importData();
      case SettingsResult.exportCsv:
        return exportCsv();
      case SettingsResult.exportDb:
        return exportDb();
      case SettingsResult.bugReport:
        return sendBugReport();
      case SettingsResult.repairDb:
        return repairDb();
    }
  }

  // -------------------------------------------------------------------
  // Repair database
  // -------------------------------------------------------------------

  /// `ListHabitsBehavior.onRepairDB()`, ported here for the same reason
  /// [exportCsv] is: this is the object the settings row hands its work to.
  ///
  /// The Kotlin body is an anonymous `object : Task` whose `doInBackground`
  /// repairs the list and whose `onPostExecute` reports it, which is why the
  /// message always follows the repair. It bypasses the command runner
  /// entirely, so nothing listening for commands is notified.
  Future<void> repairDb() async {
    _taskRunner.execute(
      _RepairDBTask(
        habitList: scope.habitList,
        listener: () => showMessage(DataActionMessage.databaseRepaired),
      ),
    );
    await _taskRunner.awaitAll();
  }

  // -------------------------------------------------------------------
  // Generate bug report
  // -------------------------------------------------------------------

  /// `ListHabitsBehavior.onSendBugReport()`, at the boundary where the
  /// reporter and the mail client live.
  ///
  /// The two steps and their order are the core's — dump to a file first, then
  /// build the text and hand it to the send-email screen — and the core's own
  /// test covers the presenter that runs them. What is here is the wiring the
  /// Android app does in `ListHabitsModule`: a real reporter and a real
  /// sender behind the settings row.
  Future<void> sendBugReport() async {
    final reporter = _bugReporter;
    final email = _emailScreen;
    if (reporter == null || email == null) return;
    reporter.dumpBugReportToFile();
    try {
      final log = reporter.getBugReport();
      await email.showSendBugReportToDeveloperScreen(log);
    } on Object catch (error, stackTrace) {
      // `catch (e: Exception) { e.printStackTrace(); showMessage(...) }`.
      stderr.writeln(error);
      stderr.writeln(stackTrace);
      showMessage(DataActionMessage.couldNotGenerateBugReport);
    }
  }

  // -------------------------------------------------------------------
  // Export as CSV
  // -------------------------------------------------------------------

  /// `ListHabitsBehavior.onExportCSV()`.
  ///
  /// The selected habits are the whole (currently filtered) list, and the
  /// output directory is the dir finder's `CSV` folder. On success the archive
  /// goes straight to the share sheet; on failure the message is shown.
  ///
  /// Kotlin's `taskRunner.execute(task)` is fire and forget; the returned
  /// future is a Dart addition, so that a caller — or a test — can tell when
  /// the whole flow, share sheet included, is over.
  Future<void> exportCsv() async {
    final selected = scope.habitList.toList();
    final outputDir = dirFinder.getCSVOutputDir();
    Future<void>? followUp;
    _taskRunner.execute(
      ExportCSVTask(
        scope.habitList,
        selected,
        outputDir,
        // The nights themselves, which the percentages in Checkmarks.csv
        // cannot be turned back into.
        sleepRepository: scope.sleepRepository,
        _ExportCsvListener((String? filename) {
          if (filename != null) {
            followUp = showSendFileScreen(filename);
          } else {
            showMessage(DataActionMessage.couldNotExport);
          }
        }),
      ),
    );
    await _taskRunner.awaitAll();
    await followUp;
  }

  // -------------------------------------------------------------------
  // Export full backup
  // -------------------------------------------------------------------

  /// `ListHabitsScreen.onExportDB()` plus `ExportDBTask`.
  ///
  /// The public-folder branch is dropped with the Storage Access Framework, so
  /// this is always the `publicBackupFolder == null` path: the app-private
  /// `Backups` directory, an absolute path handed to the share sheet, and a
  /// null filename — a `Backups` directory that cannot be created — reported
  /// as "Failed to export data.".
  ///
  /// There is no rotation and no freshness check: every call writes a new
  /// copy, even one second after the last.
  Future<void> exportDb() async {
    Future<void>? followUp;
    _taskRunner.execute(
      _ExportDBTask(
        databasePath: scope.databasePath,
        dir: dirFinder.getFilesDir(HabitsDirFinder.backupsDirName),
        now: _clock(),
        listener: (String? filename) {
          if (filename != null) {
            followUp = showSendFileScreen(filename);
          } else {
            showMessage(DataActionMessage.couldNotExport);
          }
        },
      ),
    );
    await _taskRunner.awaitAll();
    await followUp;
  }

  // -------------------------------------------------------------------
  // Import data
  // -------------------------------------------------------------------

  /// `ListHabitsScreen.showImportScreen()` followed by
  /// `onOpenDocumentResult(...)`.
  ///
  /// A cancelled picker does nothing at all. Otherwise the chosen file is
  /// copied byte for byte into a temp file in the cache directory — the
  /// importer migrates a Loop backup in place, so it must never see the user's
  /// original — and that copy is what the import task reads. The copy is
  /// deleted when the task finishes, whatever the result.
  Future<void> importData() async {
    final path = await fileChooser.pickFile();
    // `if (data == null) return` / `if (resultCode != RESULT_OK) return`.
    if (path == null) return;

    final UserFile tempFile;
    try {
      // `contentResolver.openInputStream(...)` comes before
      // `File.createTempFile`, so a source that cannot be read leaves no temp
      // file behind.
      final bytes = await File(path).readAsBytes();
      tempFile = await createImportTempFile(cacheDir);
      await tempFile.writeBytes(bytes);
    } on FileSystemException catch (e, stackTrace) {
      // `activity.showMessage(could_not_import); e.printStackTrace()`.
      showMessage(DataActionMessage.importFailed);
      stderr.writeln(e);
      stderr.writeln(stackTrace);
      return;
    }

    Future<void>? followUp;
    _taskRunner.execute(
      importTaskFactory.create(
        tempFile,
        _ImportListener((int result) {
          followUp = _onImportFinished(result, tempFile);
        }),
      ),
    );
    await _taskRunner.awaitAll();
    await followUp;
  }

  Future<void> _onImportFinished(int result, UserFile tempFile) async {
    switch (result) {
      case ImportDataTask.success:
        (_refreshHabitList ?? scope.adapter.refresh)();
        showMessage(DataActionMessage.importSuccessful);
      case ImportDataTask.notRecognized:
        showMessage(DataActionMessage.fileNotRecognized);
      default:
        showMessage(DataActionMessage.importFailed);
    }
    // `onFinished()`: `tempFile.delete()`, which returns false rather than
    // throwing when the file is already gone.
    try {
      await tempFile.delete();
    } on FileSystemException {
      // Ignored, as in Kotlin.
    }
  }

  // -------------------------------------------------------------------
  // Sharing and links
  // -------------------------------------------------------------------

  /// `Activity.showSendFileScreen(archiveFilename)`.
  ///
  /// The filename is parsed as a URI: a `content` URI is passed through, a
  /// `file` URI is reduced to its path, and anything else is already a plain
  /// path. Android then wraps the non-content cases in a `FileProvider` URI,
  /// which is what share_plus does for us.
  Future<void> showSendFileScreen(String filename) async {
    final uri = Uri.tryParse(filename);
    final String target;
    if (uri != null && uri.scheme == 'content') {
      target = filename;
    } else if (uri != null && uri.scheme == 'file') {
      target = uri.path;
    } else {
      target = filename;
    }
    try {
      await fileSharer.shareFile(target, mimeType: shareMimeType);
    } catch (_) {
      // `startActivitySafely` catches ActivityNotFoundException.
      showMessage(DataActionMessage.activityNotFound);
    }
  }

  /// `startActivitySafely(Intent(ACTION_VIEW, Uri.parse(url)))`, the callback
  /// the Help and "Rate this app" rows of the settings screen take.
  Future<void> openUrl(String url) async {
    try {
      final launched = await urlOpener.open(url);
      if (!launched) showMessage(DataActionMessage.activityNotFound);
    } catch (_) {
      showMessage(DataActionMessage.activityNotFound);
    }
  }
}

/// Port of `ExportDBTask`, minus its Storage Access Framework branch.
class _ExportDBTask extends Task {
  _ExportDBTask({
    required this.databasePath,
    required this.dir,
    required this.now,
    required this.listener,
  });

  /// `DatabaseUtils.getDatabaseFile(context)`, i.e. the live `uhabits.db`.
  /// Null only when the app was booted on a database that has no file, which
  /// happens in tests.
  final String? databasePath;

  /// `system.getFilesDir("Backups")`, null when nothing is writable.
  final UserFile? dir;

  final DateTime now;

  final void Function(String? filename) listener;

  String? _filename;

  @override
  Future<void> doInBackground() async {
    _filename = null;
    final dir = this.dir;
    final databasePath = this.databasePath;
    // `val dir = system.getFilesDir("Backups") ?: return`.
    if (dir == null || databasePath == null) return;
    _filename = await saveDatabaseCopy(
      databasePath: databasePath,
      dir: dir,
      now: now,
    );
  }

  @override
  void onPostExecute() => listener(_filename);
}

/// The anonymous `object : Task` of `ListHabitsBehavior.onRepairDB()`.
class _RepairDBTask extends Task {
  _RepairDBTask({required this.habitList, required this.listener});

  final HabitList habitList;

  final void Function() listener;

  @override
  void doInBackground() => habitList.repair();

  @override
  void onPostExecute() => listener();
}

/// `ExportCSVTask`'s `fun interface` listener, as a lambda.
class _ExportCsvListener implements ExportCSVListener {
  _ExportCsvListener(this._onFinished);

  final void Function(String? archiveFilename) _onFinished;

  @override
  void onExportCSVFinished(String? archiveFilename) =>
      _onFinished(archiveFilename);
}

/// `ImportDataTask.Listener`, as a lambda.
class _ImportListener implements ImportDataTaskListener {
  _ImportListener(this._onFinished);

  final void Function(int result) _onFinished;

  @override
  void onImportDataFinished(int result) => _onFinished(result);
}

/// The four importers, in the order `GenericImporter` probes them.
///
/// Every one of them goes in through [_FunctionImporter], because the Dart
/// core currently declares `AbstractImporter` TWICE — once in
/// `src/io/abstract_importer.dart`, which is what `GenericImporter` accepts,
/// and once in `src/io/habit_bull_csv_importer.dart`, which is what the
/// HabitBull, Rewire and Tickmate importers extend — while `LoopDBImporter`
/// extends neither. Nothing in the app package can fix that; until the two
/// declarations are merged in the core, the adapter is what lets the four be
/// assembled into a dispatcher at all.
GenericImporter buildGenericImporter({
  required AppScope scope,
  required FileOpener fileOpener,
}) {
  const opener = Sqlite3DatabaseOpener();
  final loop = LoopDBImporter(
    habitList: scope.habitList,
    modelFactory: scope.modelFactory,
    opener: opener,
    runner: scope.commandRunner,
    logging: scope.logging,
    fileOpener: fileOpener,
    // A restored backup carries a sleep habit's goal and every night it ever
    // recorded; nothing else in the import re-keys those onto this device.
    sleepImporter: SleepImporter(scope.sleepRepository),
    definitionImporter: DefinitionImporter(scope.definitions),
    // И журнал срывов: строки лежат под идентификатором чужого устройства,
    // и без этого восстановленная привычка возвращается с днём обязательства
    // и пустой историей за ним.
    lapseImporter: LapseImporter(scope.lapses),
  );
  final rewire =
      RewireDBImporter(scope.habitList, scope.modelFactory, opener);
  final tickmate =
      TickmateDBImporter(scope.habitList, scope.modelFactory, opener);
  final habitBull =
      HabitBullCSVImporter(scope.habitList, scope.modelFactory, scope.logging);
  return GenericImporter(
    _FunctionImporter(loop.canHandle, (UserFile file) async {
      await loop.importHabitsFromFile(file);
      // Оба сотрудника выше пишут в базу, а не в живую привычку, и пересчёт
      // внутри импорта проходит раньше их — с `definition == null`. Прикрепить
      // определения приходится здесь, когда импортёр вернулся: иначе сорок
      // дней обязательства и деление оценки пополам вернулись бы только после
      // перезапуска приложения.
      //
      // На этом импортёре, а не на всех четырёх: определение и журнал есть
      // только в нашем же файле базы, а Rewire, Tickmate и HabitBull приносят
      // обычные привычки, которым прикреплять нечего.
      attachDefinitions(scope.habitList, scope.definitions);
      for (final Habit habit in scope.habitList) {
        habit.recompute();
      }
    }),
    _FunctionImporter(rewire.canHandle, rewire.importHabitsFromFile),
    _FunctionImporter(tickmate.canHandle, tickmate.importHabitsFromFile),
    _FunctionImporter(habitBull.canHandle, habitBull.importHabitsFromFile),
  );
}

class _FunctionImporter extends AbstractImporter {
  _FunctionImporter(this._canHandle, this._import);

  final Future<bool> Function(UserFile file) _canHandle;
  final Future<void> Function(UserFile file) _import;

  @override
  Future<bool> canHandle(UserFile file) => _canHandle(file);

  @override
  Future<void> importHabitsFromFile(UserFile file) => _import(file);
}

/// The string resource behind each message.
String dataActionMessageText(L10n l10n, DataActionMessage message) {
  switch (message) {
    case DataActionMessage.couldNotExport:
      return l10n.couldNotExport;
    case DataActionMessage.importSuccessful:
      return l10n.habitsImported;
    case DataActionMessage.importFailed:
      return l10n.couldNotImport;
    case DataActionMessage.fileNotRecognized:
      return l10n.fileNotRecognized;
    case DataActionMessage.activityNotFound:
      return l10n.activityNotFound;
    case DataActionMessage.couldNotGenerateBugReport:
      return l10n.bugReportFailed;
    case DataActionMessage.databaseRepaired:
      return l10n.databaseRepaired;
  }
}

/// `Activity.showMessage(msg)`, which shows a snackbar over the list screen.
///
/// The whole widget half of this file: the screen passes this as
/// [DataActions.showMessage]. The snackbar itself is the app's one
/// [showMessage] helper — upstream every one of these results reaches the same
/// `ViewExtensions.showMessage`, so they cannot have their own lifetime
/// (`audit24.one-show-message-helper-one-lifetime#1`).
void showDataActionMessage(BuildContext context, DataActionMessage message) {
  showMessage(context, dataActionMessageText(L10n.of(context), message));
}
