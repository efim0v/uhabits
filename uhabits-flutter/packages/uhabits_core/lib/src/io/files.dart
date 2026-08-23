/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Files.kt and of
/// its JVM actuals in
/// uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaFiles.kt
/// (`JavaUserFile`, `JavaResourceFile`, `JavaFileOpener`).
///
/// The Kotlin members are `suspend`; here they are `Future`-returning, so the
/// call sites read the same way. `dart:io` covers everything `java.nio.file`
/// did.
///
/// The Android actuals (`AndroidFileOpener`, `AndroidResourceFile`) resolve
/// user files against `context.filesDir` and resource files against the APK's
/// `assets/` through an `AssetManager`; neither exists in pure Dart, so they
/// belong to the app package. [LocalFileOpener] takes both roots as
/// constructor arguments so the app can supply its own without reimplementing
/// [UserFile].
library;

import 'dart:io';
import 'dart:typed_data';

import '../gui/image.dart';

/// Decodes the bytes of a bundled image resource. The JVM actual uses
/// `ImageIO.read`, Android uses `BitmapFactory`; the core ships no codec, so
/// the host supplies one. Mirrors the way [Image.export] takes an
/// `ImageExporter`.
typedef ResourceImageDecoder = Future<Image> Function(Uint8List bytes);

abstract class FileOpener {
  /// Opens a file which was shipped bundled with the application, such as a
  /// migration file.
  ///
  /// The path is relative to the assets folder. For example, to open
  /// assets/main/migrations/09.sql you should provide migrations/09.sql
  /// as the path.
  ///
  /// This function always succeed, even if the file does not exist.
  ResourceFile openResourceFile(String path);

  /// Opens a file which was not shipped with the application, such as
  /// databases and logs.
  ///
  /// The path is relative to the user folder. For example, if the application
  /// stores the user data at /home/user/.loop/ and you wish to open the file
  /// /home/user/.loop/crash.log, you should provide crash.log as the path.
  ///
  /// This function always succeed, even if the file does not exist.
  UserFile openUserFile(String path);
}

/// Represents a file that was created after the application was installed, as a
/// result of some user action, such as databases and logs.
abstract class UserFile {
  /// The resolved absolute path string.
  String get pathString;

  /// Deletes the user file.
  ///
  /// The Kotlin interface documents "If the file does not exist, nothing
  /// happens", but `JavaUserFile` calls `Files.delete`, which throws. The
  /// implementation wins: see [LocalUserFile.delete].
  Future<void> delete();

  /// Returns true if the file exists.
  Future<bool> exists();

  /// Returns the lines of the file. If the file does not exist, throws an
  /// exception.
  Future<List<String>> lines();

  /// Overwrites the file with [content], creating it if it doesn't exist.
  Future<void> writeString(String content);

  /// Overwrites the file with [bytes], creating it if it doesn't exist.
  Future<void> writeBytes(List<int> bytes);

  /// Reads the first [limit] bytes from the file.
  Future<Uint8List> readBytes(int limit);

  /// Returns a [UserFile] whose path is [child] resolved against this path.
  ///
  /// The Kotlin doc comment says "resolved against this file's parent
  /// directory (or this file itself, if it represents a directory)", but
  /// `JavaUserFile` delegates to `java.nio.Path.resolve`, which always
  /// resolves against the path itself.
  UserFile resolve(String child);

  /// Returns the list of files and directories within this directory, or null
  /// if this path is not a directory or does not exist.
  Future<List<UserFile>?> listFiles();

  /// Creates this directory and any necessary parent directories.
  Future<void> mkdirs();
}

/// Represents a file that was shipped with the application, such as migration
/// files or database templates.
abstract class ResourceFile {
  /// Copies the resource file to the specified user file. If the user file
  /// already exists, it is replaced. If not, a new file is created.
  Future<void> copyTo(UserFile dest);

  /// Returns the lines of the resource file. If the file does not exist,
  /// throws an exception.
  Future<List<String>> lines();

  /// Returns true if the file exists.
  Future<bool> exists();

  /// Loads resource file as an image.
  Future<Image> toImage();
}

/// Port of `JavaUserFile`.
class LocalUserFile implements UserFile {
  LocalUserFile(this.path);

  /// The `java.nio.Path` equivalent: a plain path string.
  final String path;

  @override
  String get pathString => path;

  @override
  Future<List<String>> lines() => File(path).readAsLines();

  /// `Files.exists(path)`, which is also true for directories — unlike
  /// `File.exists` in `dart:io`.
  @override
  Future<bool> exists() async =>
      await FileSystemEntity.type(path) != FileSystemEntityType.notFound;

  /// `Files.delete(path)`: throws when the file does not exist.
  @override
  Future<void> delete() async {
    if (await FileSystemEntity.type(path) == FileSystemEntityType.directory) {
      await Directory(path).delete();
    } else {
      await File(path).delete();
    }
  }

  @override
  Future<void> writeString(String content) async {
    await _mkParentDirs();
    await File(path).writeAsString(content);
  }

  @override
  Future<void> writeBytes(List<int> bytes) async {
    await _mkParentDirs();
    await File(path).writeAsBytes(bytes);
  }

  @override
  Future<Uint8List> readBytes(int limit) async {
    final stream = await File(path).open();
    try {
      final bytes = await stream.read(limit);
      // `n <= 0` in the Kotlin version: an empty file reads -1 bytes.
      if (bytes.isEmpty) return Uint8List(0);
      return Uint8List.fromList(bytes);
    } finally {
      await stream.close();
    }
  }

  /// `java.nio.Path.resolve`: an absolute [child] replaces this path, an empty
  /// [child] leaves it alone, anything else is appended.
  @override
  UserFile resolve(String child) {
    if (child.isEmpty) return LocalUserFile(path);
    if (child.startsWith('/')) return LocalUserFile(child);
    return LocalUserFile(joinPath(path, child));
  }

  @override
  Future<List<UserFile>?> listFiles() async {
    if (await FileSystemEntity.type(path) != FileSystemEntityType.directory) {
      // `File.listFiles()` returns null for a non-directory or missing path.
      return null;
    }
    final children =
        await Directory(path).list(followLinks: false).toList();
    return children
        .map<UserFile>((entity) => LocalUserFile(entity.path))
        .toList();
  }

  @override
  Future<void> mkdirs() async {
    await Directory(path).create(recursive: true);
  }

  /// `path.toFile().parentFile?.mkdirs()`.
  Future<void> _mkParentDirs() async {
    final parent = parentPath(path);
    if (parent != null) await Directory(parent).create(recursive: true);
  }

  @override
  String toString() => 'LocalUserFile($path)';
}

/// Port of `JavaResourceFile`.
class LocalResourceFile implements ResourceFile {
  LocalResourceFile(
    this.path, {
    this.roots = defaultResourceRoots,
    this.decodeImage,
  });

  /// `assets/main/<path>` is searched first and `assets/test/<path>` is the
  /// fallback: that is how the CSV export fixtures and the test databases are
  /// loaded in unit tests.
  static const List<String> defaultResourceRoots = <String>[
    'assets/main',
    'assets/test',
  ];

  /// Path relative to the assets folder, e.g. `migrations/09.sql`.
  final String path;

  final List<String> roots;

  final ResourceImageDecoder? decodeImage;

  /// The `javaPath` getter: the first root under which the file exists, or the
  /// last root when it exists under none of them.
  String get resolvedPathString {
    for (var i = 0; i < roots.length - 1; i++) {
      final candidate = joinPath(roots[i], path);
      if (FileSystemEntity.typeSync(candidate) !=
          FileSystemEntityType.notFound) {
        return candidate;
      }
    }
    return joinPath(roots.last, path);
  }

  @override
  Future<bool> exists() async =>
      await FileSystemEntity.type(resolvedPathString) !=
      FileSystemEntityType.notFound;

  @override
  Future<List<String>> lines() => File(resolvedPathString).readAsLines();

  @override
  Future<void> copyTo(UserFile dest) async {
    if (await dest.exists()) await dest.delete();
    final parent = parentPath(dest.pathString);
    if (parent != null) await Directory(parent).create(recursive: true);
    await File(resolvedPathString).copy(dest.pathString);
  }

  @override
  Future<Image> toImage() async {
    final decode = decodeImage;
    if (decode == null) {
      // Same posture as `AndroidImage.export`: the core cannot decode a PNG on
      // its own.
      throw UnimplementedError(
          'toImage requires a ResourceImageDecoder supplied by the host');
    }
    return decode(await File(resolvedPathString).readAsBytes());
  }

  @override
  String toString() => 'LocalResourceFile($path)';
}

/// Port of `JavaFileOpener`, which resolves user files against `/tmp/` and
/// resource files against `assets/main` then `assets/test`.
///
/// `AndroidFileOpener` differs only in its two roots — `context.filesDir` and
/// the APK assets — so both are constructor arguments here.
class LocalFileOpener implements FileOpener {
  LocalFileOpener({
    this.userDataDir = defaultUserDataDir,
    this.resourceRoots = LocalResourceFile.defaultResourceRoots,
    this.decodeImage,
  });

  /// `Paths.get("/tmp/$path")` in `JavaFileOpener.openUserFile`.
  static const String defaultUserDataDir = '/tmp';

  final String userDataDir;

  final List<String> resourceRoots;

  final ResourceImageDecoder? decodeImage;

  @override
  UserFile openUserFile(String path) =>
      LocalUserFile(joinPath(userDataDir, path));

  @override
  ResourceFile openResourceFile(String path) => LocalResourceFile(
        path,
        roots: resourceRoots,
        decodeImage: decodeImage,
      );
}

/// Joins two path segments with a single separator, the way `Paths.get` would
/// normalise `"$dir/$child"`.
String joinPath(String dir, String child) {
  if (dir.isEmpty) return child;
  if (dir.endsWith('/')) return '$dir$child';
  return '$dir/$child';
}

/// `File.getParentFile()`: null when the path has no parent.
String? parentPath(String path) {
  final index = path.lastIndexOf('/');
  if (index < 0) return null;
  if (index == 0) return '/';
  return path.substring(0, index);
}
