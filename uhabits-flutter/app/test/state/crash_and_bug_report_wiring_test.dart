/// `verify.crash-handler-stubbed` and `verify.bug-report-log-empty`: the two
/// halves of a bug report that the running app never had.
///
/// `test/platform/crash_handler_test.dart` and
/// `test/platform/bug_reporter_test.dart` both pass, and both build their
/// subject by hand: a `BaseExceptionHandler` over a probe reporter, a
/// `FlutterBugReporter` over a `BugReportLog` the test filled itself. Neither
/// can see what the app hands those constructors. These tests never construct
/// either one. They boot the real `AppScope`, pump the real `UhabitsApp`, and
/// look at what a crash leaves on disk and at what the Troubleshooting row
/// puts in the mail composer.
library;

// The two platform interfaces are transitive dependencies of url_launcher /
// path_provider and exist so that a test can stand in for the plugin.
// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/platform/bug_reporter.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/uhabits_core.dart' show resetToday;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const String crashRule1 =
    'verify.crash-handler-stubbed#1 — In the Kotlin app: When an uncaught '
    'exception reaches BaseExceptionHandler, it prints the stack trace and '
    'then dumps a full bug report to <external files>/Logs/Log '
    '<yyyy-MM-dd HHmmss>.txt before delegating to the platform\'s crash path — '
    'so a crash leaves a retrievable post-mortem file on the device.';

const String crashRule2 =
    'verify.crash-handler-stubbed#2 — The port must do the same. Today: '
    'UnportedBugReporter.dumpBugReportToFile() unconditionally throws '
    'UnsupportedError(\'The bug reporter is not ported yet\'); '
    'BaseExceptionHandler.uncaughtException catches it, prints it, and moves '
    'on. No Log <timestamp>.txt is ever created on a crash. … FlutterBugReporter '
    'is fully implemented, writes exactly that file name to exactly that '
    'directory, and is already constructed by DataActions.create for the '
    'settings row. The crash path is the one caller that was never switched '
    'over.';

const String logRule1 =
    'verify.bug-report-log-empty#1 — In the Kotlin app: AndroidLogging writes '
    'every log line to the system log, and AndroidBugReporter.getLogcat() '
    'shells out to `logcat -d` and keeps the last 250 lines. The bug report '
    'emailed to dev@loophabits.org therefore contains the app\'s recent log — '
    'HabitsApplicationTest asserts that a message printed via printStackTrace '
    'shows up in getLogcat().';

const String logRule2 =
    'verify.bug-report-log-empty#2 — The port must do the same. Today: '
    'BugReportLog is the ring buffer that replaces logcat, and BugReportLogging '
    'is the Logging decorator that fills it … the app never installs it. '
    'AppScope.open builds a plain StandardLogging(), so BugReportLog.instance '
    'is permanently empty and FlutterBugReporter.getLogcat() always returns '
    'the empty string. Settings > Troubleshooting > \'Generate bug report\' '
    'opens the mail client with a report that is a begin marker, a blank line '
    'where 250 log lines should be, the device info block, and an end marker.';

/// `Activity.startActivitySafely(intent)`'s far side: whatever app the system
/// would have handed the mailto intent to.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

/// `ContextCompat.getExternalFilesDirs(context, null)` and
/// `activity.externalCacheDir`, both pointed at the test's temp directory.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => '$root/cache';
}

void main() {
  late Directory tempDir;
  late _FakeUrlLauncher launcher;
  final List<AppScope> scopes = <AppScope>[];

  /// The two process-wide error sinks `FlutterCrashHandlerHooks` installs on.
  /// Saved and restored so that arming the real handler cannot leak into the
  /// rest of the suite.
  FlutterExceptionHandler? savedOnError;
  bool Function(Object, StackTrace)? savedPlatformOnError;

  /// The handler that was installed when [BaseExceptionHandler] was built —
  /// `originalHandler`, i.e. the platform's own crash path.
  late List<FlutterErrorDetails> chained;

  setUp(() {
    resetToday();
    BugReportLog.instance.clear();
    tempDir = Directory.systemTemp.createTempSync('uhabits_crash_wiring');
    Directory('${tempDir.path}/cache').createSync(recursive: true);
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    savedOnError = FlutterError.onError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
    chained = <FlutterErrorDetails>[];
  });

  tearDown(() {
    FlutterError.onError = savedOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    BugReportLog.instance.clear();
    tempDir.deleteSync(recursive: true);
  });

  /// `main()`: `WidgetsFlutterBinding.ensureInitialized(); await
  /// AppScope.boot();`.
  ///
  /// Through [WidgetTester.runAsync] because booting opens real files, and the
  /// tester's fake clock never completes a real I/O future.
  Future<AppScope> boot(WidgetTester tester) async {
    final AppScope? scope = await tester.runAsync(AppScope.boot);
    scopes.add(scope!);
    return scope;
  }

  Directory logsDir() =>
      Directory('${tempDir.path}/${FlutterBugReporter.logsDirName}');

  // -----------------------------------------------------------------------
  // verify.crash-handler-stubbed
  // -----------------------------------------------------------------------

  group('verify.crash-handler-stubbed', () {
    testWidgets('an uncaught error leaves a Log <timestamp>.txt behind',
        (WidgetTester tester) async {
      final AppScope scope = await boot(tester);
      // The tail of the chain. `BaseExceptionHandler` captures whatever is
      // installed when it is built and delegates to it afterwards; putting a
      // recorder there rather than the test harness's own reporter is what
      // keeps the deliberate crash below from being counted as a failure of
      // this test.
      FlutterError.onError = chained.add;

      await tester.pumpWidget(UhabitsApp(scope: scope));
      // The app's own startup work — the list cache refresh, the resume, the
      // auto backup — runs on timers the tester has to flush.
      await tester.pumpAndSettle();

      // Read now, asserted below: while the app's handler is installed on
      // FlutterError.onError a failing expect() cannot be reported.
      final bool dumpedBeforeTheCrash = logsDir().existsSync();

      // The sink `FlutterCrashHandlerHooks` installs on: everything thrown
      // inside the framework goes through it, which is this port's
      // `Thread.setDefaultUncaughtExceptionHandler`.
      final StateError crash = StateError('an uncaught failure');
      FlutterError.reportError(FlutterErrorDetails(
        exception: crash,
        stack: StackTrace.fromString('#0 crash'),
        library: 'uhabits',
      ));
      // Disarm before asserting: a failing expectation is itself reported
      // through FlutterError.onError, and until this line that is the app's
      // process-wide handler rather than the harness's.
      FlutterError.onError = savedOnError;
      PlatformDispatcher.instance.onError = savedPlatformOnError;

      expect(dumpedBeforeTheCrash, isFalse,
          reason: '$crashRule1 Nothing is dumped before the crash.');
      expect(logsDir().existsSync(), isTrue,
          reason: '$crashRule1 $crashRule2 The crash path has to reach a '
              'reporter that can actually write the file.');
      final List<File> dumps = logsDir().listSync().whereType<File>().toList();
      expect(dumps, hasLength(1), reason: crashRule1);
      expect(
        p.basename(dumps.single.path),
        matches(RegExp(r'^Log \d{4}-\d{2}-\d{2} \d{6}\.txt$')),
        reason: '$crashRule1 `"Log %s.txt"` with SimpleDateFormat('
            '"yyyy-MM-dd HHmmss").',
      );

      final String dumped = dumps.single.readAsStringSync();
      expect(dumped, contains(FlutterBugReporter.beginMarker),
          reason: '$crashRule1 What is dumped is a FULL bug report. '
              '$crashRule2');
      expect(dumped, contains('App Version Name:'),
          reason: '$crashRule1 …including the device block.');
      expect(dumped, contains(FlutterBugReporter.endMarker),
          reason: crashRule1);

      expect(chained.map((FlutterErrorDetails d) => d.exception),
          contains(crash),
          reason: '$crashRule1 …"before delegating to the platform\'s crash '
              'path": the original handler still runs afterwards.');

      await tester.pumpAndSettle();
    });
  });

  // -----------------------------------------------------------------------
  // verify.bug-report-log-empty
  // -----------------------------------------------------------------------

  group('verify.bug-report-log-empty', () {
    testWidgets('the emailed report carries the log the app wrote',
        (WidgetTester tester) async {
      // `HabitsApplication.onCreate`. On a host with no notification plugin —
      // this test, and any device where the services cannot start — the app
      // logs why, through the Logging the graph was built with. That line is
      // the app's own log output, not the test's.
      final AppScope scope = await boot(tester);
      // `BaseUserInterfaceTest.setUp` does the same, and for the same reason:
      // otherwise the first-run intro (verify.intro-never-shown) covers the
      // list and there is no overflow menu to tap.
      scope.preferences.isFirstRun = false;

      // A tall surface keeps every settings row hit-testable without
      // scrolling.
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Settings > Troubleshooting > 'Generate bug report'.
      await tester
          .tap(find.byKey(const ValueKey<String>('listHabits.overflowMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ListHabitsMenuItems.keyOf(
        ListHabitsMenuItems.settings,
      )));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final Finder row = find.byKey(const ValueKey<String>('bugReport'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await tester.pump(const Duration(milliseconds: 50));

      expect(launcher.launched, hasLength(1),
          reason: '$logRule1 The report is what the mail composer opens with.');
      final String? body =
          Uri.parse(launcher.launched.single).queryParameters['body'];
      expect(body, isNotNull, reason: logRule1);
      printOnFailure('--- bug report body ---\n$body\n--- end ---');

      // "a report that is a begin marker, a blank line where 250 log lines
      // should be, the device info block, and an end marker".
      final int begin = body!.indexOf(FlutterBugReporter.beginMarker);
      final int device = body.indexOf('App Version Name:');
      expect(begin, isNonNegative, reason: logRule1);
      expect(device, isNonNegative, reason: logRule1);
      final String logSection = body
          .substring(begin + FlutterBugReporter.beginMarker.length, device)
          .trim();
      expect(logSection, isNotEmpty,
          reason: '$logRule1 $logRule2 getLogcat() has to answer with the '
              'lines the app logged, the way `logcat -d` answers with what '
              'android.util.Log was given.');
      expect(logSection, contains('Platform services unavailable'),
          reason: '$logRule1 $logRule2 The line the app itself wrote through '
              'AppScope.logging during startup is in the report.');
      expect(logSection, contains('[HabitsApplication]'),
          reason: '$logRule1 Log.i/d/e are given a tag, and getLogcat() keeps '
              'it.');
    });

    testWidgets('every line the app logs reaches the ring buffer',
        (WidgetTester tester) async {
      await boot(tester);

      expect(BugReportLog.instance.lines, isNotEmpty,
          reason: '$logRule1 $logRule2 grep -rn "BugReportLogging" lib test '
              'matches only its own declaration in bug_reporter.dart — the '
              'app never installs it, so BugReportLog.instance is permanently '
              'empty.');
      expect(
        BugReportLog.instance.lines
            .where((String line) => line.contains('Platform services '
                'unavailable'))
            .length,
        1,
        reason: '$logRule1 Every log line the app writes goes to the buffer '
            'that replaces logcat, exactly once. $logRule2',
      );
    });
  });
}
