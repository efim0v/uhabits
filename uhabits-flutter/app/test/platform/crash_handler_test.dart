/// `platform-glue.crash-handler`: the last thing that runs before the process
/// dies.
///
/// `BaseExceptionHandler` is four lines of Kotlin and every one of them is a
/// decision that only shows up in a crash: whether a null argument is
/// delegated, whether a failing bug report can swallow the crash, and whether
/// the platform's own handler still runs afterwards. The port keeps all four
/// in `lib/platform/crash_handler.dart`, behind [CrashHandlerHooks] so the
/// sequence can be driven here without arming a process-wide handler — which a
/// test cannot do without taking the rest of the suite down with it.
library;

// The core's list-screen presenter interfaces are reached by their `src` path.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/crash_handler.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart';

/// `Thread.getDefaultUncaughtExceptionHandler()` / `set...`, as a field.
class FakeHooks implements CrashHandlerHooks {
  FakeHooks([this._installed]);

  void Function(Object error, StackTrace? stackTrace)? _installed;

  int installs = 0;

  @override
  void Function(Object error, StackTrace? stackTrace)? get current => _installed;

  @override
  set current(void Function(Object error, StackTrace? stackTrace)? handler) {
    installs++;
    _installed = handler;
  }
}

/// `AndroidBugReporter`, counting dumps and optionally failing.
class ProbeBugReporter implements ListHabitsBehaviorBugReporter {
  ProbeBugReporter({this.throwOnDump});

  final Object? throwOnDump;
  int dumps = 0;

  @override
  void dumpBugReportToFile() {
    dumps++;
    final Object? failure = throwOnDump;
    if (failure != null) throw failure;
  }

  @override
  String getBugReport() => 'report';
}

void main() {
  group('platform-glue.crash-handler', () {
    test('#1 the original handler is captured at construction time', () {
      const String rule =
          'platform-glue.crash-handler#1 — BaseExceptionHandler captures '
          'Thread.getDefaultUncaughtExceptionHandler() at construction time '
          'and stores it as originalHandler.';

      final List<String> platform = <String>[];
      final FakeHooks hooks =
          FakeHooks((Object e, StackTrace? s) => platform.add('platform:$e'));

      final BaseExceptionHandler handler = BaseExceptionHandler(
        ProbeBugReporter(),
        hooks: hooks,
        err: StringBuffer(),
      );
      expect(handler.originalHandler, isNotNull,
          reason: '$rule It read the handler that was already installed.');

      // "at construction time": installing this one, then building a second,
      // gives the second the first as its original — and the first keeps the
      // platform one. A capture at *call* time would make the first delegate
      // to itself.
      handler.install();
      final BaseExceptionHandler second = BaseExceptionHandler(
        ProbeBugReporter(),
        hooks: hooks,
        err: StringBuffer(),
      );
      expect(second.originalHandler, handler.uncaughtException,
          reason: rule);
      expect(handler.originalHandler, isNot(handler.uncaughtException),
          reason: '$rule …and the first is still chained to the platform.');
      second.uncaughtException(StateError('chained'), null);
      expect(platform, <String>['platform:Bad state: chained'],
          reason: '$rule …so the chain really reaches the platform through '
              'the first handler.');

      // With nothing installed beforehand, the original is null — which is
      // what a JVM answers before anything sets a default handler.
      expect(
        BaseExceptionHandler(ProbeBugReporter(),
                hooks: FakeHooks(), err: StringBuffer())
            .originalHandler,
        isNull,
        reason: rule,
      );
    });

    test('#2 install() replaces the platform handler, once', () {
      const String rule =
          'platform-glue.crash-handler#2 — It is installed exactly once, in '
          'ListHabitsActivity.onCreate, via Thread'
          '.setDefaultUncaughtExceptionHandler(BaseExceptionHandler(this)) — '
          'after the DI component and views are built, before '
          'behavior.onStartup(). In the port the same point is '
          '_ThemedAppState.initState: main() has already awaited AppScope.boot'
          '(), and the list screen has not been built yet.';

      final FakeHooks hooks = FakeHooks();
      final BaseExceptionHandler handler = BaseExceptionHandler(
        ProbeBugReporter(),
        hooks: hooks,
        err: StringBuffer(),
      );

      expect(hooks.installs, 0,
          reason: '$rule Constructing does not install.');
      handler.install();
      expect(hooks.installs, 1, reason: rule);
      expect(hooks.current, handler.uncaughtException,
          reason: '$rule …and what is installed is this handler.');
    });

    test('#3 a null throwable or a null thread is a silent return', () {
      const String rule =
          'platform-glue.crash-handler#3 — uncaughtException returns '
          'immediately (doing nothing, not even delegating) if either the '
          'throwable or the thread argument is null.';

      final List<String> delegated = <String>[];
      final StringBuffer err = StringBuffer();
      final ProbeBugReporter reporter = ProbeBugReporter();
      final BaseExceptionHandler handler = BaseExceptionHandler(
        reporter,
        hooks: FakeHooks((Object e, StackTrace? s) => delegated.add('$e')),
        err: err,
      );

      handler.uncaughtException(null);
      handler.uncaughtException(null, StackTrace.current);
      handler.uncaughtException(StateError('boom'), null, null);

      expect(reporter.dumps, 0, reason: '$rule No dump.');
      expect(err.toString(), isEmpty, reason: '$rule Nothing printed.');
      expect(delegated, isEmpty,
          reason: '$rule "not even delegating" — the original handler is not '
              'called either.');
    });

    test('#4 the trace is printed, then the report is dumped, and a failing '
        'dump is caught', () {
      const String rule =
          'platform-glue.crash-handler#4 — Otherwise it calls '
          'ex.printStackTrace(), then AndroidBugReporter(activity)'
          '.dumpBugReportToFile(), each wrapped so that any Exception from the '
          'dump is caught and its stack trace printed.';

      // The happy path: print, then dump, in that order.
      final StringBuffer err = StringBuffer();
      final ProbeBugReporter reporter = ProbeBugReporter();
      final BaseExceptionHandler handler = BaseExceptionHandler(
        reporter,
        hooks: FakeHooks(),
        err: err,
      );
      final StateError crash = StateError('the original failure');
      handler.uncaughtException(crash, StackTrace.fromString('#0 frame'));

      expect(err.toString(), contains('the original failure'), reason: rule);
      expect(err.toString(), contains('#0 frame'),
          reason: '$rule printStackTrace() prints the frames, not just the '
              'message.');
      expect(reporter.dumps, 1, reason: rule);

      // The wrapped path: the dump throws and is swallowed, with its own trace
      // printed next to the crash's.
      final StringBuffer wrapped = StringBuffer();
      final ProbeBugReporter failing =
          ProbeBugReporter(throwOnDump: StateError('log dir should not be null'));
      final BaseExceptionHandler guarded = BaseExceptionHandler(
        failing,
        hooks: FakeHooks(),
        err: wrapped,
      );
      expect(
        () => guarded.uncaughtException(crash, StackTrace.fromString('#0 f')),
        returnsNormally,
        reason: '$rule A failing bug report must not become the crash.',
      );
      expect(failing.dumps, 1, reason: rule);
      expect(wrapped.toString(), contains('the original failure'),
          reason: '$rule The crash is still printed…');
      expect(wrapped.toString(), contains('log dir should not be null'),
          reason: '$rule …and so is the dump\'s own failure.');

      // The port catches Error as well as Exception, because Dart's Error
      // subtypes stand for the Java RuntimeExceptions `catch (Exception)`
      // would have caught. UnportedBugReporter is exactly that case.
      final StringBuffer unported = StringBuffer();
      expect(
        () => BaseExceptionHandler(const UnportedBugReporter(),
                hooks: FakeHooks(), err: unported)
            .uncaughtException(crash, StackTrace.fromString('#0 f')),
        returnsNormally,
        reason: '$rule The bug-report dump is not ported yet '
            '(io.bug-report-dump), and the wrapper is what keeps that from '
            'breaking the crash path.',
      );
      expect(unported.toString(), contains('not ported yet'), reason: rule);
    });

    test('#5 the platform handler still runs, with the same pair', () {
      const String rule =
          'platform-glue.crash-handler#5 — Finally it delegates to '
          'originalHandler?.uncaughtException(thread, ex) so the platform\'s '
          'normal crash dialog / process kill still happens.';

      final List<Object> seen = <Object>[];
      final StackTrace trace = StackTrace.fromString('#0 original');
      final BaseExceptionHandler handler = BaseExceptionHandler(
        ProbeBugReporter(throwOnDump: StateError('dump failed')),
        hooks: FakeHooks((Object e, StackTrace? s) => seen.addAll(<Object>[e, s!])),
        err: StringBuffer(),
      );

      final StateError crash = StateError('boom');
      handler.uncaughtException(crash, trace);

      expect(seen, <Object>[crash, trace],
          reason: '$rule The delegate gets the very same throwable and trace, '
              'and it runs even though the dump threw.');

      // `originalHandler?` — a null original is not an error.
      expect(
        () => BaseExceptionHandler(ProbeBugReporter(),
                hooks: FakeHooks(), err: StringBuffer())
            .uncaughtException(crash, trace),
        returnsNormally,
        reason: '$rule The call is null-safe.',
      );
    });

    test('#6 nothing before the screen is covered', () {
      const String rule =
          'platform-glue.crash-handler#6 — Because installation happens in '
          'onCreate of the list activity only, crashes occurring before that '
          'activity opens (e.g. in Application.onCreate or in a broadcast '
          'receiver) are NOT dumped to a log file. The port keeps the gap: '
          'the handler is installed from _ThemedAppState.initState, so a '
          'failure inside AppScope.boot() — which main() awaits before runApp '
          '— reaches nothing of this.';

      final FakeHooks hooks = FakeHooks();
      final ProbeBugReporter reporter = ProbeBugReporter();
      final BaseExceptionHandler handler =
          BaseExceptionHandler(reporter, hooks: hooks, err: StringBuffer());

      // Before install(): the hook is empty, so a crash at this moment has
      // nowhere to land.
      expect(hooks.current, isNull, reason: rule);
      expect(reporter.dumps, 0, reason: rule);

      handler.install();
      hooks.current!(StateError('after the screen opened'), null);
      expect(reporter.dumps, 1,
          reason: '$rule After installation the same crash is dumped — so the '
              'gap really is about when, not about whether.');
    });
  });
}
