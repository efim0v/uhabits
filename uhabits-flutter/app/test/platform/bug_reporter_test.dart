/// Generating a bug report: what it contains, where it is dumped, and how it
/// reaches the developer.
///
/// Ported from
/// uhabits-android/src/main/java/org/isoron/uhabits/AndroidBugReporter.kt and
/// the `showSendEmailScreen` extension of
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt.
///
/// `HabitsApplicationTest` asserts that a message printed via
/// `printStackTrace` comes back out of `getLogcat()`; the same round trip is
/// asserted here against [BugReportLog], which is what replaces `logcat -d`
/// (see the class comment on `lib/platform/bug_reporter.dart`).
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/bug_reporter.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart';
import 'package:uhabits/ui/settings/data_actions.dart';
import 'package:uhabits_core/src/io/generic_importer.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart'
    show ListHabitsBehaviorBugReporter;

/// Records what `startActivity(ACTION_VIEW)` was handed.
class _RecordingOpener implements UrlOpener {
  final List<String> urls = <String>[];
  bool result = true;
  Object? error;

  @override
  Future<bool> open(String url) async {
    urls.add(url);
    final error = this.error;
    if (error != null) throw error;
    return result;
  }
}

class _NoFileChooser implements FileChooser {
  @override
  Future<String?> pickFile() async => null;
}

class _NoFileSharer implements FileSharer {
  @override
  Future<void> shareFile(String path, {required String mimeType}) async {}
}

void main() {
  late Directory tempDir;
  late Directory externalDir;
  late HabitsDirFinder dirFinder;
  late BugReportLog log;

  const DeviceInfo sampleDevice = DeviceInfo(
    appVersionName: '2.3.4',
    appVersionCode: '234',
    osVersion: '4.14.117',
    osIncremental: '6934943',
    osApiLevel: '33',
    device: 'blueline',
    model: 'Pixel 3',
    product: 'blueline',
    manufacturer: 'Google',
    tags: 'release-keys',
    screenWidth: '1080',
    screenHeight: '2160',
    externalStorageState: 'mounted',
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_bug_report');
    externalDir = Directory('${tempDir.path}/external')
      ..createSync(recursive: true);
    dirFinder = HabitsDirFinder(<String>[externalDir.path]);
    log = BugReportLog();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  FlutterBugReporter reporterOver({
    HabitsDirFinder? finder,
    DeviceInfo device = sampleDevice,
    DateTime? now,
    void Function(Object, StackTrace)? onIoError,
  }) =>
      FlutterBugReporter(
        dirFinder: finder ?? dirFinder,
        log: log,
        deviceInfo: device,
        clock: () => now ?? DateTime(2015, 1, 26, 14, 30, 12),
        onIoError: onIoError ?? (_, _) {},
      );

  // -----------------------------------------------------------------------
  // The report itself
  // -----------------------------------------------------------------------

  group('getBugReport', () {
    test('#3 the four pieces in order, with the exact markers', () {
      log
        ..write('first line')
        ..write('second line');

      final report = reporterOver().getBugReport();

      expect(
        report,
        '---------- BUG REPORT BEGINS ----------\n'
        'first line\n'
        'second line\n'
        '\n'
        '${sampleDevice.format()}'
        '\n'
        '---------- BUG REPORT ENDS ------------\n',
        reason: "io.bug-report-dump#3: getBugReport() returns '---------- BUG "
            "REPORT BEGINS ----------\\n' + logcat + '\\n' + device info + "
            "'\\n' + '---------- BUG REPORT ENDS ------------\\n'",
      );
      expect(report, startsWith(FlutterBugReporter.beginMarker),
          reason: 'io.bug-report-dump#3: the opening marker is exactly '
              '"---------- BUG REPORT BEGINS ----------"');
      expect(FlutterBugReporter.endMarker,
          '---------- BUG REPORT ENDS ------------',
          reason: 'io.bug-report-dump#3: and the closing one has a different '
              'number of dashes — they are not symmetric');
    });

    test('#3 an empty log still produces a well-formed report', () {
      final report = reporterOver().getBugReport();

      expect(report.split('\n').first, FlutterBugReporter.beginMarker,
          reason: 'io.bug-report-dump#3: the markers do not depend on there '
              'being any log');
      expect(report.trimRight().split('\n').last, FlutterBugReporter.endMarker,
          reason: 'io.bug-report-dump#3');
    });
  });

  // -----------------------------------------------------------------------
  // The log capture
  // -----------------------------------------------------------------------

  group('getLogcat', () {
    test('#4 only the last 250 lines survive, each with a newline', () {
      for (var i = 0; i < 300; i++) {
        log.write('line $i');
      }

      final logcat = reporterOver().getLogcat();
      final lines = logcat.split('\n');

      expect(lines.last, '',
          reason: 'io.bug-report-dump#4: every kept line is terminated by a '
              'newline, including the last, so the split ends with an empty '
              'string');
      expect(lines.length - 1, 250,
          reason: 'io.bug-report-dump#4: getLogcat() keeps only the LAST 250 '
              'lines (a LinkedList that drops the head whenever size exceeds '
              '250). The source of the lines is an in-process ring buffer '
              'rather than the OS command ["logcat", "-d"], which has no '
              'Flutter or iOS equivalent — the cap and the framing are the '
              'ported part.');
      expect(lines.first, 'line 50',
          reason: 'io.bug-report-dump#4: the head is what gets dropped, so the '
              'oldest survivor is line 50 of 300');
      expect(lines[249], 'line 299',
          reason: 'io.bug-report-dump#4: and the newest line is kept');
    });

    test('#4 fewer than 250 lines are all kept', () {
      log
        ..write('a')
        ..write('b');

      expect(reporterOver().getLogcat(), 'a\nb\n',
          reason: 'io.bug-report-dump#4: with fewer lines than the cap nothing '
              'is dropped, and each line is still terminated by a newline');
    });

    test('#4 a stack trace printed into the log comes back out', () {
      // HabitsApplicationTest asserts exactly this round trip.
      try {
        throw StateError('something went wrong');
      } on StateError catch (error, stackTrace) {
        log.write('$error\n$stackTrace');
      }

      expect(reporterOver().getLogcat(), contains('something went wrong'),
          reason: 'io.bug-report-dump#4: what was printed is what the report '
              'reads back');
    });

    test('#4 the cap is the documented 250', () {
      expect(BugReportLog.defaultMaxLineCount, 250,
          reason: 'io.bug-report-dump#4: maxLineCount = 250');
    });
  });

  // -----------------------------------------------------------------------
  // The device block
  // -----------------------------------------------------------------------

  group('getDeviceInfo', () {
    test('#5 #9 eleven labelled lines in order, then a blank one', () {
      final lines = reporterOver().getDeviceInfo().split('\n');

      expect(
        lines.sublist(0, 11),
        <String>[
          'App Version Name: 2.3.4',
          'App Version Code: 234',
          'OS Version: 4.14.117 (6934943)',
          'OS API Level: 33',
          'Device: blueline',
          'Model (Product): Pixel 3 (blueline)',
          'Manufacturer: Google',
          'Other tags: release-keys',
          'Screen Width: 1080',
          'Screen Height: 2160',
          'External storage state: mounted',
        ],
        reason: 'io.bug-report-dump#9: getDeviceInfo() emits these lines in '
            'order: "App Version Name", "App Version Code", "OS Version: '
            '<os.version> (<Build.VERSION.INCREMENTAL>)", "OS API Level", '
            '"Device", "Model (Product): <Build.MODEL> (<Build.PRODUCT>)", '
            '"Manufacturer", "Other tags", "Screen Width", "Screen Height", '
            '"External storage state"',
      );
      expect(lines[11], '',
          reason: 'io.bug-report-dump#5: followed by a blank line');
      expect(lines[12], '',
          reason: 'io.bug-report-dump#9: buildString terminates the blank '
              'line too, so the block ends with two newlines');
    });

    test('#5 the order is what a reader relies on, not the values', () {
      const other = DeviceInfo(
        appVersionName: '1.0',
        appVersionCode: '1',
        osVersion: '23.0.0',
        device: 'iPhone',
      );
      final labels = other
          .format()
          .split('\n')
          .where((line) => line.contains(':'))
          .map((line) => line.split(':').first)
          .toList();

      expect(
        labels,
        <String>[
          'App Version Name',
          'App Version Code',
          'OS Version',
          'OS API Level',
          'Device',
          'Model (Product)',
          'Manufacturer',
          'Other tags',
          'Screen Width',
          'Screen Height',
          'External storage state',
        ],
        reason: 'io.bug-report-dump#5: device info lines are, in order, App '
            'Version Name, App Version Code, OS Version, OS API Level, '
            'Device, Model (Product), Manufacturer, Other tags, Screen Width, '
            'Screen Height, External storage state, then a blank line',
      );
    });
  });

  // -----------------------------------------------------------------------
  // The dump
  // -----------------------------------------------------------------------

  group('dumpBugReportToFile', () {
    test('#6 the file lands in Logs, named after the local wall clock', () {
      log.write('hello');

      reporterOver(now: DateTime(2015, 1, 26, 14, 30, 12)).dumpBugReportToFile();

      final logsDir = Directory('${externalDir.path}/Logs');
      expect(logsDir.existsSync(), isTrue,
          reason: 'io.bug-report-dump#6: the Logs dir is '
              "AndroidDirFinder.getFilesDir('Logs')");
      final written = logsDir.listSync().single;
      expect(written.uri.pathSegments.last, 'Log 2015-01-26 143012.txt',
          reason: "io.bug-report-dump#6: dumpBugReportToFile() writes the "
              "report to '<Logs dir>/Log <yyyy-MM-dd HHmmss>.txt' where the "
              "date uses SimpleDateFormat('yyyy-MM-dd HHmmss', Locale.US) in "
              'the DEFAULT time zone');
      expect(File(written.path).readAsStringSync(), contains('hello'),
          reason: 'io.bug-report-dump#6: and the contents are the report');
      expect(
        File(written.path).readAsStringSync(),
        reporterOver(now: DateTime(2015, 1, 26, 14, 30, 12)).getBugReport(),
        reason: 'io.bug-report-dump#6: byte for byte what getBugReport() '
            'returns',
      );
    });

    test('#6 the DEFAULT time zone, not UTC', () {
      // The backup file name forces UTC; this one does not, so a wall-clock
      // hour is what appears here.
      expect(FlutterBugReporter.logFileName(DateTime(2015, 12, 31, 23, 59, 59)),
          'Log 2015-12-31 235959.txt',
          reason: 'io.bug-report-dump#6: the date uses the DEFAULT time zone, '
              'so the local wall clock is what names the file');
      expect(FlutterBugReporter.logFileName(DateTime(2015, 1, 2, 3, 4, 5)),
          'Log 2015-01-02 030405.txt',
          reason: 'io.bug-report-dump#6: every field is zero-padded, and the '
              'time has no separators');
    });

    test('#6 a null Logs dir raises the documented IOException', () {
      Object? raised;
      final reporter = reporterOver(
        finder: HabitsDirFinder(<String>['${tempDir.path}/nowhere']),
        onIoError: (error, _) => raised = error,
      );

      reporter.dumpBugReportToFile();

      expect(raised, isA<FileSystemException>(),
          reason: "io.bug-report-dump#6: a null dir raises IOException('log "
              "dir should not be null')");
      expect((raised! as FileSystemException).message,
          'log dir should not be null',
          reason: 'io.bug-report-dump#6: with that exact message');
    });

    test('#7 every I/O failure is swallowed after printing the stack trace',
        () {
      final swallowed = <Object>[];
      final reporter = reporterOver(
        finder: HabitsDirFinder(<String>['${tempDir.path}/nowhere']),
        onIoError: (error, _) => swallowed.add(error),
      );

      expect(reporter.dumpBugReportToFile, returnsNormally,
          reason: 'io.bug-report-dump#7: every IOException inside '
              'dumpBugReportToFile is swallowed after printStackTrace, so a '
              'failed dump never aborts the flow');
      expect(swallowed, hasLength(1),
          reason: 'io.bug-report-dump#7: printStackTrace still runs');

      // The other I/O failure: the directory exists but the file cannot be
      // written, because a directory of that name is in the way.
      Directory('${externalDir.path}/Logs/Log 2015-01-26 143012.txt')
          .createSync(recursive: true);
      swallowed.clear();
      final blocked = reporterOver(onIoError: (error, _) => swallowed.add(error));
      expect(blocked.dumpBugReportToFile, returnsNormally,
          reason: 'io.bug-report-dump#7: a write that cannot happen is '
              'swallowed the same way');
      expect(swallowed, hasLength(1), reason: 'io.bug-report-dump#7');
    });

    test('#8 the crash handler dumps the same report', () {
      final crashLog = BugReportLog();
      var dumps = 0;
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);

      crashLog.captureUncaughtErrors(onCrash: () => dumps++);
      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('boom')),
      );

      expect(dumps, 1,
          reason: 'io.bug-report-dump#8: the same dump is invoked from '
              'BaseExceptionHandler when the app crashes');
      expect(crashLog.lines.join('\n'), contains('boom'),
          reason: 'io.bug-report-dump#8: and the crash is in the log the dump '
              'writes out');
    });
  });

  // -----------------------------------------------------------------------
  // Sending it
  // -----------------------------------------------------------------------

  group('showSendBugReportToDeveloperScreen', () {
    test('#10 the three extras of the ACTION_SEND intent', () async {
      final opener = _RecordingOpener();
      final screen = SendEmailScreen(opener: opener.open);

      await screen.showSendBugReportToDeveloperScreen('the whole log');

      final uri = Uri.parse(opener.urls.single);
      expect(uri.scheme, 'mailto',
          reason: 'io.bug-report-dump#10: '
              'showSendBugReportToDeveloperScreen(log) fires an ACTION_SEND '
              'intent — Flutter has no intent system, and the equivalent every '
              'mail client registers for is a mailto: URL');
      expect(uri.path, 'dev@loophabits.org',
          reason: 'io.bug-report-dump#10: EXTRA_EMAIL = '
              '[@string/bugReportTo]');
      expect(uri.queryParameters['subject'], 'Bug Report - Loop Habit Tracker',
          reason: 'io.bug-report-dump#10: EXTRA_SUBJECT = '
              '@string/bugReportSubject');
      expect(uri.queryParameters['body'], 'the whole log',
          reason: 'io.bug-report-dump#10: EXTRA_TEXT = the full log');
    });

    test('io.share-file-screen#8 the generic sender and its missing safety net',
        () async {
      final opener = _RecordingOpener();
      final screen = SendEmailScreen(opener: opener.open);

      await screen.send(
        to: const <String>['someone@example.org'],
        subject: 'Subject',
        content: 'Body',
      );
      final uri = Uri.parse(opener.urls.single);

      expect(SendEmailScreen.mimeType, 'message/rfc822',
          reason: 'io.share-file-screen#8: '
              'Activity.showSendEmailScreen(toResId, subjectResId, content) '
              'fires ACTION_SEND with type "message/rfc822"');
      expect(uri.path, 'someone@example.org',
          reason: 'io.share-file-screen#8: EXTRA_EMAIL = '
              'arrayOf(getString(toResId)) — an array even though one address '
              'is ever passed');
      expect(uri.queryParameters['subject'], 'Subject',
          reason: 'io.share-file-screen#8: EXTRA_SUBJECT = '
              'getString(subjectResId)');
      expect(uri.queryParameters['body'], 'Body',
          reason: 'io.share-file-screen#8: EXTRA_TEXT = content');

      // "is NOT wrapped in startActivitySafely, so a device with no mail
      // client throws ActivityNotFoundException".
      opener.error = const ProcessException('mail', <String>[]);
      await expectLater(
        screen.send(to: const <String>['a@b.c'], subject: 's', content: null),
        throwsA(isA<ProcessException>()),
        reason: 'io.share-file-screen#8: and is NOT wrapped in '
            'startActivitySafely, so a device with no mail client throws '
            'instead of showing a message',
      );
    });

    test('#10 a null body is sent as an empty one', () {
      expect(
        Uri.parse(
          SendEmailScreen.mailtoUrl(
            to: const <String>['a@b.c'],
            subject: 's',
            body: null,
          ),
        ).queryParameters['body'],
        '',
        reason: 'io.bug-report-dump#10: EXTRA_TEXT is a nullable String '
            'upstream; a missing body is an empty one, not a missing extra',
      );
    });
  });

  // -----------------------------------------------------------------------
  // The binding
  // -----------------------------------------------------------------------

  group('the settings row', () {
    test('#12 the reporter is what the list screen binds', () {
      final reporter = reporterOver();

      expect(reporter, isA<ListHabitsBehaviorBugReporter>(),
          reason: 'io.bug-report-dump#12: ListHabitsModule is an @Inject class '
              'extending AndroidBugReporter(appContext) and implementing '
              'ListHabitsBehavior.BugReporter — that is the DI binding used by '
              'the list screen');
      final ListHabitsBehaviorBugReporter bound = reporter;
      expect(bound.getBugReport(), contains(FlutterBugReporter.beginMarker),
          reason: 'io.bug-report-dump#12: reached through the interface, the '
              'binding is the reporter itself');
      expect(bound.dumpBugReportToFile, returnsNormally,
          reason: 'io.bug-report-dump#12: both interface methods are the '
              "reporter's");
    });

    test('#12 tapping "Generate bug report" dumps and then sends', () async {
      final opener = _RecordingOpener();
      final scope = AppScope.open(
        AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
        databasePath: '${tempDir.path}/habits.db',
        logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      addTearDown(scope.close);
      final messages = <DataActionMessage>[];
      final actions = DataActions(
        scope: scope,
        dirFinder: dirFinder,
        cacheDir: tempDir.path,
        fileChooser: _NoFileChooser(),
        fileSharer: _NoFileSharer(),
        urlOpener: opener,
        importTaskFactory: ImportDataTaskFactory(
          buildGenericImporter(
            scope: scope,
            fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
          ),
          scope.modelFactory,
          logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        ),
        showMessage: messages.add,
        bugReporter: reporterOver(),
        emailScreen: SendEmailScreen(opener: opener.open),
      );

      await actions.onSettingsResult(SettingsResult.bugReport);

      expect(Directory('${externalDir.path}/Logs').listSync(), hasLength(1),
          reason: 'io.bug-report-dump#12: the settings row reaches the bound '
              'reporter, which dumps the report to a file first');
      expect(opener.urls.single, startsWith('mailto:dev@loophabits.org'),
          reason: 'io.bug-report-dump#12: and then opens the send-email screen '
              'with it');
      expect(messages, isEmpty,
          reason: 'io.bug-report-dump#12: nothing failed, so no message');
    });

    test('#12 a failure to send shows the bug-report message', () async {
      final opener = _RecordingOpener()
        ..error = const ProcessException('mail', <String>[]);
      final scope = AppScope.open(
        AppDatabase.openAndMigrate('${tempDir.path}/habits2.db'),
        databasePath: '${tempDir.path}/habits2.db',
        logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      addTearDown(scope.close);
      final messages = <DataActionMessage>[];
      final actions = DataActions(
        scope: scope,
        dirFinder: dirFinder,
        cacheDir: tempDir.path,
        fileChooser: _NoFileChooser(),
        fileSharer: _NoFileSharer(),
        urlOpener: opener,
        importTaskFactory: ImportDataTaskFactory(
          buildGenericImporter(
            scope: scope,
            fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
          ),
          scope.modelFactory,
          logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        ),
        showMessage: messages.add,
        bugReporter: reporterOver(),
        emailScreen: SendEmailScreen(opener: opener.open),
      );

      await actions.onSettingsResult(SettingsResult.bugReport);

      expect(messages, <DataActionMessage>[
        DataActionMessage.couldNotGenerateBugReport,
      ],
          reason: 'io.bug-report-dump#12: the row is wired to the same '
              'failure path the behaviour has — COULD_NOT_GENERATE_BUG_REPORT');
      expect(dataActionMessageText(L10nEn(), messages.single),
          'Failed to generate bug report.',
          reason: 'io.bug-report-dump#12: whose English text is "Failed to '
              'generate bug report."');
    });
  });
}
