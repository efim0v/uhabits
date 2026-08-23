/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/BaseExceptionHandler.kt.
///
/// ```kotlin
/// class BaseExceptionHandler(private val activity: Activity) :
///     Thread.UncaughtExceptionHandler {
///     private val originalHandler = Thread.getDefaultUncaughtExceptionHandler()
///
///     override fun uncaughtException(thread: Thread?, ex: Throwable?) {
///         if (ex == null || thread == null) return
///         try {
///             ex.printStackTrace()
///             AndroidBugReporter(activity).dumpBugReportToFile()
///         } catch (e: Exception) {
///             e.printStackTrace()
///         }
///         originalHandler?.uncaughtException(thread, ex)
///     }
/// }
/// ```
///
/// ## What "the default uncaught exception handler" is in Flutter
///
/// A JVM has one process-wide `Thread.UncaughtExceptionHandler`; Flutter has
/// two entry points that between them catch the same class of failure, and
/// both are plain mutable fields, which is what makes "capture the previous
/// one and delegate to it" portable:
///
///  * `FlutterError.onError` — anything thrown inside the framework: a build,
///    a layout, a paint, a gesture callback.
///  * `PlatformDispatcher.instance.onError` — anything that escapes an
///    asynchronous callback and reaches the root zone.
///
/// [CrashHandlerHooks] is the seam over the two, so the sequence can be driven
/// from a test without arming a process-wide handler.
///
/// ## The Android details that survive, and the one that does not
///
/// The null guard of rule #3 has a direct counterpart: `FlutterError.onError`
/// is handed a `FlutterErrorDetails` whose `exception` is non-null by
/// construction, but `PlatformDispatcher.onError` is handed `(Object, Stack
/// Trace)` from a zone that may report anything — so [uncaughtException] takes
/// nullable arguments and returns early exactly as the Kotlin does.
///
/// What does not survive is the *thread*: Dart's unit of execution here is the
/// zone, and there is nothing to hand back to a delegate. The parameter is
/// kept — nullable, and part of the early-return condition — because the
/// return is observable, and the delegate is called with the same pair it
/// would have received.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
// The core's list-screen presenter interfaces are reached by their `src` path,
// exactly as lib/state/habit_list_model.dart reaches them.
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart';

/// The two mutable error sinks [BaseExceptionHandler] installs itself on.
///
/// `Thread.getDefaultUncaughtExceptionHandler()` /
/// `Thread.setDefaultUncaughtExceptionHandler(...)`, split in two because
/// Flutter has two.
abstract interface class CrashHandlerHooks {
  /// The handler currently installed, or null when the platform has none —
  /// which is what `Thread.getDefaultUncaughtExceptionHandler()` returns
  /// before anything sets one.
  void Function(Object error, StackTrace? stackTrace)? get current;

  set current(void Function(Object error, StackTrace? stackTrace)? handler);
}

/// [CrashHandlerHooks] over the real `FlutterError.onError` and
/// `PlatformDispatcher.instance.onError`.
class FlutterCrashHandlerHooks implements CrashHandlerHooks {
  FlutterCrashHandlerHooks();

  void Function(Object error, StackTrace? stackTrace)? _installed;

  @override
  void Function(Object error, StackTrace? stackTrace)? get current => _installed;

  @override
  set current(void Function(Object error, StackTrace? stackTrace)? handler) {
    _installed = handler;
    if (handler == null) return;
    final FlutterExceptionHandler? previousFramework = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      handler(details.exception, details.stack);
      previousFramework?.call(details);
    };
    final bool Function(Object, StackTrace)? previousPlatform =
        PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      handler(error, stack);
      return previousPlatform?.call(error, stack) ?? false;
    };
  }
}

/// A `ListHabitsBehavior.BugReporter` whose every method throws.
///
/// It was the app's own reporter while `io.bug-report-dump` was unported; the
/// app now dumps through the finished `FlutterBugReporter` that
/// `AppScope.bugReporter` holds (`verify.crash-handler-stubbed`), and what is
/// left here is the case rule #4 exists for: a reporter that fails. The dump is
/// wrapped precisely so that a failing bug report cannot swallow the crash, and
/// the wrapper is what keeps the delegation of rule #5 happening — which is
/// only observable against a reporter like this one.
class UnportedBugReporter implements ListHabitsBehaviorBugReporter {
  const UnportedBugReporter();

  @override
  void dumpBugReportToFile() =>
      throw UnsupportedError('The bug reporter is not ported yet');

  @override
  String getBugReport() =>
      throw UnsupportedError('The bug reporter is not ported yet');
}

/// Port of `BaseExceptionHandler`.
class BaseExceptionHandler {
  /// `private val originalHandler = Thread.getDefaultUncaughtExceptionHandler()`
  /// — read at *construction* time, so an instance built after another handler
  /// was installed chains onto that one.
  BaseExceptionHandler(
    this._bugReporter, {
    required CrashHandlerHooks hooks,
    StringSink? err,
  })  : _hooks = hooks,
        _err = err ?? stderr,
        originalHandler = hooks.current;

  final ListHabitsBehaviorBugReporter _bugReporter;

  final CrashHandlerHooks _hooks;

  /// `Throwable.printStackTrace()` writes to stderr; injectable so a test can
  /// read it back.
  final StringSink _err;

  /// The handler that was installed when this one was built. Null when there
  /// was none.
  final void Function(Object error, StackTrace? stackTrace)? originalHandler;

  /// `Thread.setDefaultUncaughtExceptionHandler(BaseExceptionHandler(this))`.
  ///
  /// Called from the screen, not from `main()` — see the note on rule #6:
  /// installing it earlier would change which crashes get dumped.
  void install() {
    _hooks.current = uncaughtException;
  }

  /// `override fun uncaughtException(thread: Thread?, ex: Throwable?)`.
  void uncaughtException(
    Object? ex, [
    StackTrace? stackTrace,
    Object? thread = _defaultThread,
  ]) {
    // `if (ex == null || thread == null) return` — nothing is printed, nothing
    // is dumped, and the original handler is NOT called either.
    if (ex == null || thread == null) return;
    try {
      _printStackTrace(ex, stackTrace);
      _bugReporter.dumpBugReportToFile();
    } on Object catch (e, s) {
      // Kotlin catches `Exception`; Dart's `Error` subtypes stand for the Java
      // RuntimeExceptions that would have been caught, so this is untyped.
      _printStackTrace(e, s);
    }
    // `originalHandler?.uncaughtException(thread, ex)`: the platform's normal
    // crash path still runs.
    originalHandler?.call(ex, stackTrace);
  }

  /// The non-null `thread` the two Flutter sinks always have.
  static const Object _defaultThread = 'root';

  void _printStackTrace(Object error, StackTrace? stackTrace) {
    _err.writeln(error);
    if (stackTrace != null) _err.writeln(stackTrace);
  }
}
