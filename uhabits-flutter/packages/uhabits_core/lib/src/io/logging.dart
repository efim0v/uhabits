/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/Logging.kt.
///
/// The Android adapter
/// (uhabits-android/src/main/java/org/isoron/uhabits/io/AndroidLogging.kt), which
/// maps info/debug/error onto `Log.i`/`Log.d`/`Log.e` and is bound as an
/// `@AppScope` singleton in `HabitsApplicationComponent`, belongs to the app
/// package: it needs `android.util.Log`, which has no pure-Dart counterpart.
/// The app package implements [Logging] there.
library;

import 'dart:io';

abstract class Logging {
  Logger getLogger(String name);
}

/// Kotlin declares four methods: `info(msg)`, `debug(msg)`, `error(msg)` and
/// `error(exception)`. Dart has no overloading, so the two `error` overloads
/// collapse into one method that dispatches on the runtime type of its
/// argument: a `String` is logged as a message, anything else is treated as the
/// thrown object and printed with its stack trace.
abstract class Logger {
  void info(String msg);

  void debug(String msg);

  /// [msgOrException] is either the message (Kotlin's `error(msg: String)`) or
  /// the thrown object (Kotlin's `error(exception: Exception)`). Dart
  /// exceptions do not carry a stack trace, so callers may pass the one caught
  /// alongside them.
  void error(Object msgOrException, [StackTrace? stackTrace]);
}

class StandardLogging implements Logging {
  /// [out] defaults to `stdout` and [err] to `stderr`, matching `println` and
  /// `Throwable.printStackTrace()`. Both are injectable so that tests can
  /// capture the output.
  StandardLogging({StringSink? out, StringSink? err})
      : _out = out,
        _err = err;

  final StringSink? _out;
  final StringSink? _err;

  @override
  Logger getLogger(String name) => StandardLogger(name, out: _out, err: _err);
}

class StandardLogger implements Logger {
  StandardLogger(this.name, {StringSink? out, StringSink? err})
      : _out = out ?? stdout,
        _err = err ?? stderr;

  final String name;
  final StringSink _out;
  final StringSink _err;

  @override
  void info(String msg) {
    _out.writeln('[$name] $msg');
  }

  @override
  void debug(String msg) {
    _out.writeln('[$name] $msg');
  }

  @override
  void error(Object msgOrException, [StackTrace? stackTrace]) {
    if (msgOrException is String) {
      _out.writeln('[$name] $msgOrException');
    } else {
      _printStackTrace(msgOrException, stackTrace);
    }
  }

  /// `Throwable.printStackTrace()`: the exception's own description followed by
  /// its frames, on stderr.
  void _printStackTrace(Object exception, StackTrace? stackTrace) {
    _err.writeln(exception);
    if (stackTrace != null) _err.writeln(stackTrace.toString().trimRight());
  }
}

// ---------------------------------------------------------------------------
// Messages the importers emit.
//
// The importers themselves live in their own slices; these builders keep the
// exact wording in one place so the port cannot drift from the Kotlin strings.
// ---------------------------------------------------------------------------

/// The logger name `LoopDBImporter` passes to `Logging.getLogger`.
const String loopDBImporterLoggerName = 'LoopDBImporter';

/// The logger name `HabitBullCSVImporter` passes to `Logging.getLogger`.
/// `RewireDBImporter` and `TickmateDBImporter` do not log at all.
const String habitBullCSVImporterLoggerName = 'HabitBullCSVImporter';

/// `HabitBullCSVImporter`: `logger.info("Creating habit: $name")`.
String creatingHabitMessage(String name) => 'Creating habit: $name';

/// `HabitBullCSVImporter`: `logger.info("Found a value of $value, considering
/// this habit as numerical.")`.
String foundNumericalValueMessage(Object value) =>
    'Found a value of $value, considering this habit as numerical.';

/// `HabitBullCSVImporter`: `logger.error("Could not parse int: $rawValue.
/// Replacing by zero.")`.
String couldNotParseIntMessage(String rawValue) =>
    'Could not parse int: $rawValue. Replacing by zero.';

/// `LoopDBImporter`: `logger.error("Cannot handle file: tables not found")`.
const String cannotHandleFileTablesNotFound =
    'Cannot handle file: tables not found';

/// `LoopDBImporter`: `logger.error("Cannot handle file: incompatible version:
/// ${db.getVersion()} > $DATABASE_VERSION")`.
String incompatibleVersionMessage(int version, int databaseVersion) =>
    'Cannot handle file: incompatible version: $version > $databaseVersion';
