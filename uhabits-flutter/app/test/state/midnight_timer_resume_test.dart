import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';

/// Records what the app logs, so the timer can be observed through the seam it
/// already has rather than by adding one to the core.
class _RecordingLogging implements Logging {
  final List<String> lines = <String>[];

  @override
  Logger getLogger(String name) => _RecordingLogger(name, lines);
}

class _RecordingLogger implements Logger {
  _RecordingLogger(this.name, this.lines);

  final String name;
  final List<String> lines;

  @override
  void debug(String message) => lines.add('$name: $message');

  @override
  void error(Object msgOrException, [StackTrace? stackTrace]) =>
      lines.add('$name: $msgOrException');

  @override
  void info(String message) => lines.add('$name: $message');
}

/// `ListHabitsActivity.onResume` arms the midnight timer as its fourth
/// statement — unconditionally, and before the reminder block, which is
/// separately guarded by `hasHabitsWithReminders()`.
///
/// The port had the call nested inside the reminder branch, so on any run where
/// the notification plugin or the timezone data failed to load — a failure
/// `AppScope.startPlatformServices` swallows by design, so the app still opens
/// — the day boundary never moved again: the header kept yesterday's columns
/// and a tap on the newest one wrote the entry to yesterday.
void main() {
  testWidgets(
      'the day boundary still moves when the reminder subsystem is absent',
      (tester) async {
    final logging = _RecordingLogging();
    // A scope built without startPlatformServices() is exactly the state a
    // failed platform start leaves behind: no scheduler, everything else live.
    final directory = Directory.systemTemp.createTempSync('uhabits_midnight');
    addTearDown(() => directory.deleteSync(recursive: true));
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${directory.path}/uhabits.db'),
      preferencesStorage: MemoryStorage(),
      logging: logging,
    );
    addTearDown(scope.close);

    expect(scope.reminderScheduler, isNull,
        reason: 'audit4.the-midnight-day-rollover-timer-is#1 — the fixture has '
            'to reproduce the state a failed platform start leaves');

    await tester.pumpWidget(UhabitsApp(scope: scope));
    await tester.pumpAndSettle();

    logging.lines.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      logging.lines.where((l) => l.startsWith('MidnightTimer: Scheduling')),
      isNotEmpty,
      reason: 'audit4.the-midnight-day-rollover-timer-is#1 — arming the timer '
          'and scheduling reminders are two independent steps upstream, so a '
          'missing scheduler must not freeze the day boundary',
    );
  });
}
