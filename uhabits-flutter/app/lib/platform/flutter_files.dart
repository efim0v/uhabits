/// Port of the file plumbing that surrounds the ported exporter and importers:
///
///  * `uhabits-android/.../AndroidDirFinder.kt` and
///    `uhabits-android/.../utils/FileUtils.kt` — pick the first writable
///    external files directory and make a subfolder inside it,
///  * `uhabits-android/.../activities/HabitsDirFinder.kt` — the
///    `ListHabitsBehavior.DirFinder` / `ShowHabitMenuPresenter.System` binding
///    that hands the CSV exporter its output directory,
///  * `uhabits-android/.../utils/DatabaseUtils.kt` (`saveDatabaseCopy` for a
///    plain `File` destination) plus `DateFormats.getBackupDateFormat()`,
///  * `uhabits-android/.../platform/io/AndroidFiles.kt`
///    (`AndroidFileOpener`, `AndroidResourceFile`).
///
/// The three plugins this app reaches the operating system through —
/// file_picker, share_plus and path_provider — cannot run in a widget test, so
/// each one sits behind a one-method interface with a plugin-backed
/// implementation next to it: [FileChooser] / [PlatformFileChooser],
/// [FileSharer] / [PlatformFileSharer], and [AppDirectories.resolve].
///
/// What is deliberately NOT here: the Storage Access Framework. The
/// `publicBackupFolder` preference, `DocumentFile` tree URIs and the automatic
/// daily backup have no cross-platform equivalent, so the private-directory
/// half of `ExportDBTask` is the whole of what is ported, exactly as the
/// settings screen already says with its disabled `publicBackupFolder` row.
library;

// The core io layer is reached by its `src` path, exactly as
// lib/state/app_scope.dart reaches the commands and preferences layers.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart' show Offset, Rect, WidgetsBinding;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit_menu_presenter.dart';
import 'package:uhabits_core/uhabits_core.dart' show Image, migrationSql;

// ---------------------------------------------------------------------------
// The directories the app writes into
// ---------------------------------------------------------------------------

/// The directories `ExportDBTask`, `ExportCSVTask` and the import flow reach
/// for, resolved once at startup.
///
/// Android reads them off the `Context`:
///
///  * [filesDir] is `context.filesDir` — where the database lives,
///  * [cacheDir] is `context.externalCacheDir` — where the file being imported
///    is copied before the importer touches it,
///  * [externalFilesDirs] is `ContextCompat.getExternalFilesDirs(context,
///    null)` — the ordered list `FileUtils.getDir` picks the first writable
///    entry of.
///
/// [resolve] is the only thing in this file that calls a plugin; every other
/// entry point takes plain path strings so it can be driven from a test.
class AppDirectories {
  const AppDirectories({
    required this.filesDir,
    required this.cacheDir,
    required this.externalFilesDirs,
  });

  final String filesDir;

  final String cacheDir;

  final List<String> externalFilesDirs;

  /// `getExternalStorageDirectories()` in path_provider IS
  /// `ContextCompat.getExternalFilesDirs(context, null)`, but it exists on
  /// Android only. Everywhere else the app-support directory stands in for it:
  /// there is no second "external" storage to fall back to, and the exports
  /// still land somewhere the share sheet can read.
  static Future<AppDirectories> resolve() async {
    final support = await getApplicationSupportDirectory();
    final cache = await getTemporaryDirectory();
    var candidates = <String>[support.path];
    if (Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectories();
        if (external != null && external.isNotEmpty) {
          candidates = external.map((dir) => dir.path).toList();
        }
      } on Exception {
        // `getExternalFilesDirs` can legitimately come back empty; the
        // app-private fallback above already covers that.
      }
    }
    return AppDirectories(
      filesDir: support.path,
      cacheDir: cache.path,
      externalFilesDirs: candidates,
    );
  }
}

/// Port of `FileUtils.getDir(potentialParentDirs, relativePath)`.
///
/// Returns the absolute path of `<first writable parent>/<relativePath>`,
/// creating it when missing, or null when no parent is writable or the
/// directory cannot be created. Kotlin logs both failures to `Log.e`.
///
/// Java's `File("$parent/$rel/")` swallows the trailing separator, so the
/// returned path never has one.
String? getDir(List<String> potentialParentDirs, String relativePath) {
  String? chosenDir;
  for (final dir in potentialParentDirs) {
    if (_canWrite(dir)) {
      chosenDir = dir;
      break;
    }
  }
  if (chosenDir == null) {
    // Log.e("FileUtils", "getDir: all potential parents are null or
    // non-writable")
    return null;
  }
  final path = '$chosenDir/$relativePath';
  final dir = Directory(path);
  if (!dir.existsSync()) {
    try {
      dir.createSync(recursive: true);
    } on FileSystemException {
      // Log.e("FileUtils", "getDir: chosen dir does not exist and cannot be
      // created")
      return null;
    }
    if (!dir.existsSync()) return null;
  }
  return path;
}

/// Port of `FileUtils.getSDCardDir(relativePath)`.
///
/// The one-candidate variant of [getDir]: Android builds
/// `arrayOf(Environment.getExternalStorageDirectory())` and hands it straight
/// to `getDir`, so every rule of [getDir] — first writable parent wins, create
/// on demand, silent null on failure — applies unchanged, with the list
/// reduced to a single entry.
///
/// [externalStorageDir] is that entry. It is a parameter rather than a lookup
/// because `Environment.getExternalStorageDirectory()` is the *shared* storage
/// root, which only Android has and which no plugin this app depends on
/// exposes: `path_provider.getExternalStorageDirectory()` answers with the
/// app-private external directory instead, which is a different place.
/// Upstream's only caller is `BaseViewTest`, which writes rendered-view
/// screenshots to `<sdcard>/test-screenshots`; nothing in the shipping app
/// calls it.
String? getSDCardDir(String relativePath, {required String externalStorageDir}) {
  final parents = <String>[externalStorageDir];
  return getDir(parents, relativePath);
}

/// `File.canWrite()`, which is false for a path that does not exist.
///
/// `dart:io` has no `canWrite`, so this reads the owner write bit out of the
/// stat mode. That is exact on POSIX and meaningless on Windows, where the
/// mode is synthesised — the Android original has no Windows behaviour to be
/// faithful to.
bool _canWrite(String path) {
  final stat = FileStat.statSync(path);
  if (stat.type == FileSystemEntityType.notFound) return false;
  return stat.mode & 0x80 != 0;
}

/// Port of `AndroidDirFinder` and of `HabitsDirFinder`, which are one class
/// here because the Flutter app has a single "context".
///
/// `HabitsDirFinder` implements both `ListHabitsBehavior.DirFinder` (the
/// list-screen export) and `ShowHabitMenuPresenter.System` (the single-habit
/// export), and both interfaces declare the same single method.
class HabitsDirFinder
    implements ListHabitsBehaviorDirFinder, ShowHabitMenuPresenterSystem {
  HabitsDirFinder(this.potentialParentDirs);

  factory HabitsDirFinder.of(AppDirectories directories) =>
      HabitsDirFinder(directories.externalFilesDirs);

  /// `ContextCompat.getExternalFilesDirs(context, null)`.
  final List<String> potentialParentDirs;

  /// `AndroidDirFinder.getFilesDir(relativePath)`.
  UserFile? getFilesDir(String relativePath) {
    final path = getDir(potentialParentDirs, relativePath);
    if (path == null) return null;
    return LocalUserFile(path);
  }

  /// `JavaUserFile(androidDirFinder.getFilesDir("CSV")!!.toPath())`.
  ///
  /// The `!!` is upstream's: when no external files directory is writable the
  /// export crashes rather than reporting a failure. Dart's `!` throws a
  /// [TypeError] where Kotlin throws an NPE; the wart is kept.
  @override
  UserFile getCSVOutputDir() => getFilesDir(csvDirName)!;

  /// `system.getFilesDir("CSV")`.
  static const String csvDirName = 'CSV';

  /// `system.getFilesDir("Backups")`.
  static const String backupsDirName = 'Backups';
}

// ---------------------------------------------------------------------------
// Full backup file naming and copying
// ---------------------------------------------------------------------------

/// `DateFormats.getBackupDateFormat()`: `SimpleDateFormat("yyyy-MM-dd HHmmss",
/// Locale.US)` with the time zone forced to UTC.
///
/// Written by hand rather than through `intl` because the pattern must not
/// follow the device locale — a Persian or Thai calendar would rename the
/// backups — and because `Locale.US` digits are ASCII.
String backupDateString(DateTime instant) => _formatYmdHms(instant.toUtc());

/// `"Loop Habits Backup $date.db"`.
String backupFileName(DateTime instant) =>
    'Loop Habits Backup ${backupDateString(instant)}.db';

/// The `yyyy-MM-dd HHmmss` pattern itself, applied to an already zone-adjusted
/// value. `Locale.US` only matters for the digits, which are ASCII here by
/// construction.
///
/// `AndroidBugReporter.dumpBugReportToFile()` builds its log filename from the
/// same pattern, constructed independently — see `FlutterBugReporter
/// .logFileName`, whose time zone is the device's default rather than UTC
/// (`platform-glue.time-and-date-formatting#4`).
String _formatYmdHms(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
      '${two(value.day)} ${two(value.hour)}${two(value.minute)}'
      '${two(value.second)}';
}

/// Port of `DatabaseUtils.saveDatabaseCopy(context, dir: File)`.
///
/// A raw byte-for-byte copy of the SQLite file: no VACUUM, no checkpoint, no
/// transaction. WAL is disabled on the database, so the single file is a
/// complete snapshot.
///
/// Kotlin declares `@Throws(IOException)` and `ExportDBTask` rethrows that
/// wrapped in a `RuntimeException`; the two steps are folded together here,
/// since Dart has no checked exceptions and the [StateError] is what stands in
/// for the unchecked Java exception.
Future<String> saveDatabaseCopy({
  required String databasePath,
  required UserFile dir,
  required DateTime now,
}) async {
  final filename = '${dir.pathString}/${backupFileName(now)}';
  try {
    await File(databasePath).copy(filename);
  } on FileSystemException catch (e) {
    throw StateError('$e');
  }
  return filename;
}

// ---------------------------------------------------------------------------
// The temp copy the importer reads
// ---------------------------------------------------------------------------

/// Port of `File.createTempFile("import", "", activity.externalCacheDir)`.
///
/// The copy matters beyond hiding the content URI: `LoopDBImporter` migrates
/// the file it is given IN PLACE, so importing must never hand it the user's
/// original.
Future<UserFile> createImportTempFile(String cacheDir) async {
  await Directory(cacheDir).create(recursive: true);
  final random = Random();
  while (true) {
    final suffix = (random.nextInt(1 << 32)).toRadixString(16).padLeft(8, '0');
    final candidate = File('$cacheDir/import$suffix');
    if (candidate.existsSync()) continue;
    await candidate.create();
    return LocalUserFile(candidate.path);
  }
}

/// `inStream.copyTo(tempFile)` — the 1024-byte-buffer loop of
/// `uhabits-android/.../utils/FileUtils.kt`, which `dart:io` does in one call.
///
/// Throws a [FileSystemException] when the source cannot be read, which is the
/// `IOException` the caller reports as "Failed to import data.".
Future<void> copyFileContents(String from, UserFile to) async {
  final bytes = await File(from).readAsBytes();
  await to.writeBytes(bytes);
}

// ---------------------------------------------------------------------------
// FileOpener
// ---------------------------------------------------------------------------

/// Port of `AndroidFileOpener`.
///
/// User files resolve against the app's data directory — `context.filesDir` on
/// Android, the application support directory here. Resource files are asset
/// paths on Android; the only one production code ever asks for is
/// `migrations/NN.sql`, and those scripts are compiled into the Dart core
/// (`migrations.g.dart`), so [BuiltInResourceFile] serves them from there
/// instead of from an `AssetManager`.
class FlutterFileOpener implements FileOpener {
  const FlutterFileOpener({required this.userDataDir});

  final String userDataDir;

  @override
  UserFile openUserFile(String path) =>
      LocalUserFile(joinPath(userDataDir, path));

  @override
  ResourceFile openResourceFile(String path) => BuiltInResourceFile(path);
}

/// The `ResourceFile` half of `AndroidFileOpener`, backed by the migration
/// scripts the core ships as Dart source.
class BuiltInResourceFile implements ResourceFile {
  const BuiltInResourceFile(this.path);

  /// Path relative to the assets folder, e.g. `migrations/09.sql`.
  final String path;

  static final RegExp _migrationPath = RegExp(r'^migrations/(\d+)\.sql$');

  String? get _content {
    final match = _migrationPath.firstMatch(path);
    if (match == null) return null;
    return migrationSql[int.parse(match.group(1)!)];
  }

  /// `AndroidResourceFile.exists()` opens the asset and catches `IOException`.
  @override
  Future<bool> exists() async => _content != null;

  /// `lines()` throws when the file does not exist, like every other
  /// `ResourceFile`.
  @override
  Future<List<String>> lines() async {
    final content = _content;
    if (content == null) {
      throw FileSystemException('Resource file not found', path);
    }
    return const LineSplitter().convert(content);
  }

  /// `AndroidResourceFile.copyTo` reads the asset bytes and calls
  /// `dest.writeBytes`, which replaces an existing destination.
  @override
  Future<void> copyTo(UserFile dest) async {
    await dest.writeString((await lines()).join('\n'));
  }

  /// `BitmapFactory.decodeStream`. Nothing in this app decodes a bundled
  /// image through the core, and the core ships no codec.
  @override
  Future<Image> toImage() =>
      throw UnimplementedError('Resource images are not used by this app');

  @override
  String toString() => 'BuiltInResourceFile($path)';
}

// ---------------------------------------------------------------------------
// The two plugin seams
// ---------------------------------------------------------------------------

/// `IntentFactory.openDocument()`: `ACTION_OPEN_DOCUMENT`, `CATEGORY_OPENABLE`,
/// type `*/*`.
///
/// Returns the chosen file's path, or null when the user cancelled — which is
/// the `resultCode != RESULT_OK || data == null` branch.
abstract interface class FileChooser {
  Future<String?> pickFile();
}

/// [FileChooser] over file_picker.
class PlatformFileChooser implements FileChooser {
  const PlatformFileChooser();

  @override
  Future<String?> pickFile() async {
    // `type: FileType.any` is `*/*`; file_picker already copies the content
    // URI into a readable cache file on Android, and the import flow copies it
    // once more into its own temp file, as the Kotlin screen does.
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }
}

/// `Activity.showSendFileScreen(filename)`: an `ACTION_SEND` intent carrying
/// the file and a MIME type.
///
/// Throws when nothing can handle the request, which is the
/// `ActivityNotFoundException` `startActivitySafely` catches.
abstract interface class FileSharer {
  /// [origin] is the rectangle the share sheet is anchored to. Android ignores
  /// it; iOS needs it wherever the sheet is a popover — see
  /// [PlatformFileSharer.shareFile].
  Future<void> shareFile(String path, {required String mimeType, Rect? origin});
}

/// [FileSharer] over share_plus.
///
/// share_plus does on Android exactly what `showSendFileScreen` does by hand:
/// it wraps the file in a `FileProvider` URI and grants read permission on it.
class PlatformFileSharer implements FileSharer {
  const PlatformFileSharer();

  @override
  Future<void> shareFile(
    String path, {
    required String mimeType,
    Rect? origin,
  }) async {
    await Share.shareXFiles(
      <XFile>[XFile(path, mimeType: mimeType)],
      sharePositionOrigin: origin ?? _viewCentre(),
    );
  }

  /// A one-point rectangle in the middle of the window.
  ///
  /// The Android chooser needs no anchor, and neither does the iPhone sheet.
  /// Any device that presents it as a popover does — iPad and Mac Catalyst —
  /// and share_plus refuses rather than guessing: an origin that is empty, or
  /// outside the root view, comes back as a `FlutterError` (FPPSharePlusPlugin.m
  /// :378-394), which both callers report as "No app was found to support this
  /// action". That is every export path on an iPad
  /// (`feedback.share-sheet-has-no-anchor-on-ipad#1`).
  ///
  /// The centre of the window is the honest default: the sheet is opened from a
  /// menu item that has already closed by the time the export finishes, so
  /// there is no live widget left to point at.
  static Rect? _viewCentre() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    final view = views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    if (size.isEmpty) return null;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }
}
