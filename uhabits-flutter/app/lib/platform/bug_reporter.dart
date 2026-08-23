/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/AndroidBugReporter.kt and
/// of the `showSendEmailScreen` extension in
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt.
///
/// ## The one thing that cannot be ported
///
/// `getLogcat()` shells out to `logcat -d` and keeps the last 250 lines. There
/// is no `logcat` off Android, no way to run a process from Dart on a phone,
/// and nothing on iOS that would answer such a call — so the *source* of the
/// lines is replaced by [BugReportLog], an in-process ring buffer of the same
/// depth, exactly as the ledger's note on `io.bug-report-dump` says a Flutter
/// port must. Everything downstream of it — the 250-line cap, the trailing
/// newline on each line, the report's markers, the device block, the file name
/// and the swallowed I/O errors — is the Android behaviour, line for line.
///
/// ## The device block
///
/// Half of `Build.*` has no Dart counterpart and this app depends on no
/// device-info plugin, so [DeviceInfo] is a value object: the *labels and their
/// order* are the ported part (that is what the rule specifies, and what a
/// developer reading a bug report relies on), and the values are supplied by
/// whoever builds it. [DeviceInfo.current] fills in what `dart:io` knows and
/// leaves the rest empty rather than inventing it.
library;

// The core io and screen layers are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches the commands layer.
// ignore_for_file: implementation_imports

import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart'
    show ListHabitsBehaviorBugReporter;

import 'flutter_files.dart';

// ---------------------------------------------------------------------------
// The replacement for `logcat -d`
// ---------------------------------------------------------------------------

/// An in-process ring buffer of log lines, capped at [maxLineCount].
///
/// `getLogcat()` reads `logcat -d` into a `LinkedList<String>` and drops the
/// head whenever the list grows past 250, so only the last 250 lines survive.
/// This is the same queue with the same cap, filled from inside the app
/// instead of from the system log.
class BugReportLog {
  BugReportLog({this.maxLineCount = defaultMaxLineCount});

  /// `val maxLineCount = 250`.
  static const int defaultMaxLineCount = 250;

  /// The buffer the application records into. A singleton for the same reason
  /// `logcat` is: a crash handler has to be able to read what happened before
  /// it, from anywhere, without having been handed anything.
  static final BugReportLog instance = BugReportLog();

  final int maxLineCount;

  final Queue<String> _lines = Queue<String>();

  /// Every line currently held, oldest first.
  List<String> get lines => List<String>.unmodifiable(_lines);

  /// `log.addLast(line); if (log.size > maxLineCount) log.removeFirst()`.
  ///
  /// A multi-line message counts as the several lines it is, which is what
  /// `BufferedReader.readLine()` would have produced.
  void write(String message) {
    for (final line in message.split('\n')) {
      _lines.addLast(line);
      if (_lines.length > maxLineCount) _lines.removeFirst();
    }
  }

  void clear() => _lines.clear();

  /// `for (l in log) builder.appendLine(l)` — every line terminated by a
  /// newline, including the last.
  String toLogcat() {
    final builder = StringBuffer();
    for (final line in _lines) {
      builder.writeln(line);
    }
    return builder.toString();
  }

  /// Records the uncaught errors that would have reached logcat.
  ///
  /// `BaseExceptionHandler` is the Android counterpart: it dumps the report and
  /// then delegates to the previous handler. [onCrash] is that dump.
  void captureUncaughtErrors({void Function()? onCrash}) {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      write('${details.exception}');
      onCrash?.call();
      previousOnError?.call(details);
    };
  }
}

/// A [Logging] that records into a [BugReportLog] as well as writing through.
///
/// `AndroidLogging` writes to `android.util.Log`, which is what `logcat -d`
/// reads back; this is the same relationship, expressed with the pieces a
/// Flutter app has.
class BugReportLogging implements Logging {
  BugReportLogging(this._delegate, this._log);

  final Logging _delegate;
  final BugReportLog _log;

  @override
  Logger getLogger(String name) =>
      _BugReportLogger(_delegate.getLogger(name), _log, name);
}

class _BugReportLogger implements Logger {
  _BugReportLogger(this._delegate, this._log, this._name);

  final Logger _delegate;
  final BugReportLog _log;
  final String _name;

  @override
  void info(String msg) {
    _log.write('[$_name] $msg');
    _delegate.info(msg);
  }

  @override
  void debug(String msg) {
    _log.write('[$_name] $msg');
    _delegate.debug(msg);
  }

  @override
  void error(Object msgOrException, [StackTrace? stackTrace]) {
    _log.write('[$_name] $msgOrException');
    _delegate.error(msgOrException, stackTrace);
  }
}

// ---------------------------------------------------------------------------
// The device block
// ---------------------------------------------------------------------------

/// The eleven `getDeviceInfo()` values, in the order the report prints them.
class DeviceInfo {
  const DeviceInfo({
    this.appVersionName = '',
    this.appVersionCode = '',
    this.osVersion = '',
    this.osIncremental = '',
    this.osApiLevel = '',
    this.device = '',
    this.model = '',
    this.product = '',
    this.manufacturer = '',
    this.tags = '',
    this.screenWidth = '',
    this.screenHeight = '',
    this.externalStorageState = '',
  });

  /// `BuildConfig.VERSION_NAME` / `BuildConfig.VERSION_CODE`.
  final String appVersionName;
  final String appVersionCode;

  /// `System.getProperty("os.version")` and `Build.VERSION.INCREMENTAL`, which
  /// the report prints as `<os.version> (<incremental>)`.
  final String osVersion;
  final String osIncremental;

  /// `Build.VERSION.SDK_INT`.
  final String osApiLevel;

  final String device;

  /// `Build.MODEL` and `Build.PRODUCT`, printed as `<model> (<product>)`.
  final String model;
  final String product;

  final String manufacturer;

  /// `Build.TAGS`.
  final String tags;

  final String screenWidth;
  final String screenHeight;

  /// `Environment.getExternalStorageState()`.
  final String externalStorageState;

  /// What `dart:io` can answer for real. Everything Android-specific is left
  /// empty rather than guessed: a wrong value in a bug report is worse than a
  /// missing one.
  factory DeviceInfo.current({
    String appVersionName = '',
    String appVersionCode = '',
  }) =>
      DeviceInfo(
        appVersionName: appVersionName,
        appVersionCode: appVersionCode,
        osVersion: Platform.operatingSystemVersion,
        device: Platform.operatingSystem,
        externalStorageState: '',
      );

  /// The eleven lines plus one blank one, in `getDeviceInfo()`'s exact order.
  ///
  /// `buildString { appendLine(...) }` terminates every line, including the
  /// final empty one, so the block ends with two newlines.
  String format() {
    final builder = StringBuffer()
      ..writeln('App Version Name: $appVersionName')
      ..writeln('App Version Code: $appVersionCode')
      ..writeln('OS Version: $osVersion ($osIncremental)')
      ..writeln('OS API Level: $osApiLevel')
      ..writeln('Device: $device')
      ..writeln('Model (Product): $model ($product)')
      ..writeln('Manufacturer: $manufacturer')
      ..writeln('Other tags: $tags')
      ..writeln('Screen Width: $screenWidth')
      ..writeln('Screen Height: $screenHeight')
      ..writeln('External storage state: $externalStorageState')
      ..writeln();
    return builder.toString();
  }
}

// ---------------------------------------------------------------------------
// The reporter
// ---------------------------------------------------------------------------

/// Port of `AndroidBugReporter`, which `ListHabitsModule` binds as the
/// `ListHabitsBehavior.BugReporter` the list screen uses.
class FlutterBugReporter implements ListHabitsBehaviorBugReporter {
  FlutterBugReporter({
    required this.dirFinder,
    BugReportLog? log,
    DeviceInfo deviceInfo = const DeviceInfo(),
    DateTime Function()? clock,
    void Function(Object error, StackTrace stackTrace)? onIoError,
  })  : log = log ?? BugReportLog.instance,
        _deviceInfo = deviceInfo,
        _clock = clock ?? DateTime.now,
        _onIoError = onIoError ?? _printStackTrace;

  /// `"---------- BUG REPORT BEGINS ----------"`.
  static const String beginMarker = '---------- BUG REPORT BEGINS ----------';

  /// `"---------- BUG REPORT ENDS ------------"`.
  static const String endMarker = '---------- BUG REPORT ENDS ------------';

  /// `AndroidDirFinder(context).getFilesDir("Logs")`.
  static const String logsDirName = 'Logs';

  final HabitsDirFinder dirFinder;

  final BugReportLog log;

  final DeviceInfo _deviceInfo;

  /// `Date()`, formatted in the DEFAULT time zone — unlike the backup file
  /// name, which is forced to UTC.
  final DateTime Function() _clock;

  final void Function(Object error, StackTrace stackTrace) _onIoError;

  static void _printStackTrace(Object error, StackTrace stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
  }

  /// `getLogcat()`.
  String getLogcat() => log.toLogcat();

  /// `getDeviceInfo()`.
  String getDeviceInfo() => _deviceInfo.format();

  @override
  String getBugReport() {
    var report = '$beginMarker\n';
    report += '${getLogcat()}\n';
    report += '${getDeviceInfo()}\n';
    report += '$endMarker\n';
    return report;
  }

  /// `"Log %s.txt"` with `SimpleDateFormat("yyyy-MM-dd HHmmss", Locale.US)` in
  /// the DEFAULT time zone.
  static String logFileName(DateTime instant) {
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${instant.year.toString().padLeft(4, '0')}-'
        '${two(instant.month)}-${two(instant.day)} '
        '${two(instant.hour)}${two(instant.minute)}${two(instant.second)}';
    return 'Log $date.txt';
  }

  /// The path the next dump would use, or null when there is no Logs dir.
  String? get _logDir => dirFinder.getFilesDir(logsDirName)?.pathString;

  @override
  void dumpBugReportToFile() {
    try {
      // The date is read BEFORE the directory, exactly as upstream, so two
      // dumps a second apart cannot collide on the name even if the first one
      // failed to find a directory.
      final name = logFileName(_clock());
      final dir = _logDir;
      if (dir == null) {
        throw const FileSystemException('log dir should not be null');
      }
      File('$dir/$name').writeAsStringSync(getBugReport());
    } on FileSystemException catch (error, stackTrace) {
      // `catch (e: IOException) { e.printStackTrace() }` — a failed dump never
      // aborts the flow.
      _onIoError(error, stackTrace);
    }
  }
}

// ---------------------------------------------------------------------------
// Sending it
// ---------------------------------------------------------------------------

/// `Activity.showSendEmailScreen(toResId, subjectResId, content)`.
///
/// Android fires `ACTION_SEND` with type `message/rfc822` and three extras.
/// Flutter has no intent system; the equivalent that every mail client
/// registers for is a `mailto:` URL, and its three query components carry the
/// same three values. `EXTRA_EMAIL` is an array upstream, so [to] is a list
/// here too even though only one address is ever passed.
///
/// Deliberately NOT wrapped in the `startActivitySafely` equivalent: upstream
/// this is the one sender that is not, so a device with no mail client throws
/// rather than showing "no app was found". The caller decides what to do with
/// that.
class SendEmailScreen {
  const SendEmailScreen({required this.opener});

  /// `@string/bugReportTo`. A `constants.xml` entry, not a translatable
  /// string, so it is a constant here too.
  static const String bugReportTo = 'dev@loophabits.org';

  /// `@string/bugReportSubject`.
  static const String bugReportSubject = 'Bug Report - Loop Habit Tracker';

  /// `type = "message/rfc822"`.
  static const String mimeType = 'message/rfc822';

  final Future<bool> Function(String url) opener;

  /// The `mailto:` URL carrying `EXTRA_EMAIL`, `EXTRA_SUBJECT` and
  /// `EXTRA_TEXT`.
  static String mailtoUrl({
    required List<String> to,
    required String subject,
    required String? body,
  }) =>
      Uri(
        scheme: 'mailto',
        path: to.join(','),
        queryParameters: <String, String>{
          'subject': subject,
          'body': body ?? '',
        },
      ).toString();

  Future<bool> send({
    required List<String> to,
    required String subject,
    required String? content,
  }) =>
      opener(mailtoUrl(to: to, subject: subject, body: content));

  /// `ListHabitsScreen.showSendBugReportToDeveloperScreen(log)`:
  /// `showSendEmailScreen(R.string.bugReportTo, R.string.bugReportSubject,
  /// log)`.
  Future<bool> showSendBugReportToDeveloperScreen(String log) => send(
        to: const <String>[bugReportTo],
        subject: bugReportSubject,
        content: log,
      );
}
