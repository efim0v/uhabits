/// `platform-glue.permissions`: what the app declares, and when it asks.
///
/// Rules #1 and #2 are statements about `AndroidManifest.xml` and are asserted
/// against the port's own manifest, the way test/platform/android_widgets_test
/// .dart asserts the widget receivers. Rules #3 to #6 are the runtime flow,
/// which lives in `lib/state/reminder_permission_gate.dart` — a class rather
/// than a few lines in a `State` precisely so that `permissionAlreadyRequested`
/// and the three branches around it can be driven from here.
///
/// Nothing below touches a plugin: [NotificationPermissions] is the seam that
/// stands for `checkSelfPermission` and the `ActivityResultLauncher`, and its
/// plugin-backed implementation (`LocalNotificationsPermissions`) is out of
/// reach of `flutter test` by construction.
library;

// The core's reminder, preference and model layers are reached by their `src`
// path, exactly as lib/ reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/reminder_permission_gate.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/uhabits_core.dart';

// ---------------------------------------------------------------------------
// Reading the manifest
// ---------------------------------------------------------------------------

final File manifestFile = _findManifest();

File _findManifest() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String suffix in <String>[
      'android/app/src/main/AndroidManifest.xml',
      'app/android/app/src/main/AndroidManifest.xml',
    ]) {
      final File candidate = File('${dir.path}/$suffix');
      if (candidate.existsSync()) return candidate;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('AndroidManifest.xml not found from ${Directory.current.path}');
}

/// Every `android:name` of a `<uses-permission>`, in declaration order.
List<String> declaredPermissions() => RegExp(
      r'<uses-permission\s+android:name="([^"]+)"',
    )
        .allMatches(manifestFile.readAsStringSync())
        .map((RegExpMatch m) => m.group(1)!)
        .toList();

// ---------------------------------------------------------------------------
// The seams
// ---------------------------------------------------------------------------

/// `ContextCompat.checkSelfPermission` and the permission launcher, scripted.
class ScriptedPermissions implements NotificationPermissions {
  ScriptedPermissions({
    this.runtime = true,
    this.granted = false,
    this.answer = false,
  });

  /// `SDK_INT >= TIRAMISU`.
  bool runtime;

  /// `checkSelfPermission(POST_NOTIFICATIONS) == PERMISSION_GRANTED`.
  bool granted;

  /// What the user taps in the system dialog.
  bool answer;

  int requests = 0;
  int checks = 0;

  @override
  Future<bool> get needsRuntimePermission async => runtime;

  @override
  Future<bool> isGranted() async {
    checks++;
    return granted;
  }

  @override
  Future<bool> request() async {
    requests++;
    granted = answer;
    return answer;
  }
}

/// `IntentScheduler`, counting the alarms it is asked to set.
class CountingScheduler implements SystemScheduler {
  int reminders = 0;

  @override
  void log(String componentName, String msg) {}

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) {
    reminders++;
    return SchedulerResult.ok;
  }

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => SchedulerResult.ok;
}

/// A scheduler over an in-memory habit list, plus the gate that guards it.
class Fixture {
  Fixture({required bool withReminder}) {
    final MemoryModelFactory factory = MemoryModelFactory();
    final HabitList habits = factory.buildHabitList();
    final Habit habit =
        HabitFixtures(factory, habits).createEmptyHabit(name: 'Meditate');
    if (withReminder) habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    habits.add(habit);

    scheduler = ReminderScheduler(
      CommandRunner(CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      )),
      habits,
      system,
      WidgetPreferences(MemoryStorage()),
    );
  }

  final CountingScheduler system = CountingScheduler();
  final ScriptedPermissions permissions = ScriptedPermissions();
  final StringBuffer log = StringBuffer();
  late final ReminderScheduler scheduler;

  late final ReminderPermissionGate gate = ReminderPermissionGate(
    scheduler: scheduler,
    permissions: permissions,
    logging: StandardLogging(out: log, err: log),
  );
}

void main() {
  setUpAll(() => setToday(computeToday()));
  tearDownAll(resetToday);

  group('platform-glue.permissions', () {
    test('#1 #2 the five declares, in order, and no storage permission', () {
      const String rule =
          'platform-glue.permissions#1 — Exactly 5 <uses-permission> entries '
          'are declared, in this order: POST_NOTIFICATIONS, '
          'RECEIVE_BOOT_COMPLETED, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, '
          'VIBRATE.';

      expect(declaredPermissions(), <String>[
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
        'android.permission.VIBRATE',
      ], reason: rule);

      expect(
        declaredPermissions().where((String p) => p.contains('EXTERNAL_STORAGE')),
        isEmpty,
        reason: 'platform-glue.permissions#2 — No storage permissions '
            '(READ/WRITE_EXTERNAL_STORAGE) are declared; all file output goes '
            'through app-private external dirs or SAF/DocumentFile tree URIs '
            '(here: path_provider, file_picker and share_plus).',
      );
    });

    test('#3 the request happens on resume, and at most once per instance',
        () async {
      const String rule =
          'platform-glue.permissions#3 — POST_NOTIFICATIONS is requested '
          'lazily, not at startup: on every ListHabitsActivity.onResume, if '
          'reminderScheduler.hasHabitsWithReminders() is true AND SDK_INT >= 33 '
          '(TIRAMISU) AND checkSelfPermission(POST_NOTIFICATIONS) != '
          'PERMISSION_GRANTED, the permission is requested — but only once per '
          'activity instance, guarded by a boolean permissionAlreadyRequested, '
          'specifically to avoid an infinite onResume request loop when the '
          'user denies.';

      final Fixture f = Fixture(withReminder: true)
        ..permissions.runtime = true
        ..permissions.granted = false
        ..permissions.answer = false;

      expect(f.gate.permissionAlreadyRequested, isFalse,
          reason: '$rule Nothing is asked before the first resume.');
      expect(f.permissions.requests, 0, reason: rule);

      await f.gate.onResume();
      expect(f.permissions.requests, 1,
          reason: '$rule The first resume asks, because there is a habit with '
              'a reminder, the host gates notifications, and the grant is '
              'missing.');
      expect(f.gate.permissionAlreadyRequested, isTrue, reason: rule);

      // The dialog itself resumes the activity when it closes, so this is the
      // loop the flag exists to break.
      await f.gate.onResume();
      await f.gate.onResume();
      expect(f.permissions.requests, 1,
          reason: '$rule Denying once must not produce a second dialog, on '
              'this resume or any later one.');

      // "per activity instance": a new screen asks again.
      final ReminderPermissionGate fresh = ReminderPermissionGate(
        scheduler: f.scheduler,
        permissions: f.permissions,
        logging: StandardLogging(out: f.log, err: f.log),
      );
      await fresh.onResume();
      expect(f.permissions.requests, 2,
          reason: '$rule The flag is a field of the activity, not of the app: '
              'a relaunch asks once more.');
    });

    test('#4 below the runtime-permission threshold, alarms are just scheduled',
        () async {
      const String rule =
          'platform-glue.permissions#4 — If SDK_INT < 33, reminders are '
          'scheduled directly (reminderScheduler.scheduleAll()) with no '
          'permission request.';

      final Fixture f = Fixture(withReminder: true)
        ..permissions.runtime = false
        ..permissions.granted = false;

      expect(await f.gate.onResume(), isTrue, reason: rule);
      expect(f.system.reminders, 1,
          reason: '$rule scheduleAll() really armed the habit.');
      expect(f.permissions.requests, 0, reason: '$rule …and asked for nothing.');
      expect(f.permissions.checks, 0,
          reason: '$rule The grant is not even inspected: the SDK check comes '
              'first and short-circuits.');
    });

    test('#5 granted schedules; denied logs one line and does nothing else',
        () async {
      const String rule =
          'platform-glue.permissions#5 — If the permission request result is '
          'granted, reminderScheduler.scheduleAll() is called; if denied, the '
          'app logs "POST_NOTIFICATIONS denied" at INFO level and does nothing '
          'else (no dialog, no toast).';

      // Already granted: no dialog, straight to scheduleAll.
      final Fixture granted = Fixture(withReminder: true)
        ..permissions.runtime = true
        ..permissions.granted = true;
      expect(await granted.gate.onResume(), isTrue, reason: rule);
      expect(granted.system.reminders, 1, reason: rule);
      expect(granted.permissions.requests, 0, reason: rule);

      // Asked and allowed: the same scheduleAll, after the dialog.
      final Fixture allowed = Fixture(withReminder: true)
        ..permissions.runtime = true
        ..permissions.granted = false
        ..permissions.answer = true;
      expect(await allowed.gate.onResume(), isTrue, reason: rule);
      expect(allowed.permissions.requests, 1, reason: rule);
      expect(allowed.system.reminders, 1,
          reason: '$rule "If the permission request result is granted, '
              'scheduleAll() is called".');
      expect(allowed.log.toString(), isNot(contains('denied')), reason: rule);

      // Asked and refused: one INFO line, no alarms.
      final Fixture denied = Fixture(withReminder: true)
        ..permissions.runtime = true
        ..permissions.granted = false
        ..permissions.answer = false;
      expect(await denied.gate.onResume(), isFalse, reason: rule);
      expect(denied.system.reminders, 0,
          reason: '$rule Nothing is scheduled from this path.');
      expect(denied.log.toString(), contains('POST_NOTIFICATIONS denied'),
          reason: '$rule The message, verbatim.');
      expect(denied.log.toString(), contains('[ListHabitsActivity]'),
          reason: '$rule …logged by the activity, at INFO — StandardLogger '
              'writes info to the out sink, and error(Object) to the err one.');
      expect('POST_NOTIFICATIONS denied\n'.allMatches(denied.log.toString()).length,
          1,
          reason: '$rule "does nothing else": one line, and no second attempt.');
    });

    test('#6 a user with no reminders is never asked', () async {
      const String rule =
          'platform-glue.permissions#6 — If there are no habits with '
          'reminders, the permission is never requested at all.';

      final Fixture f = Fixture(withReminder: false)
        ..permissions.runtime = true
        ..permissions.granted = false;

      expect(await f.gate.onResume(), isFalse, reason: rule);
      expect(f.permissions.requests, 0, reason: rule);
      expect(f.permissions.checks, 0,
          reason: '$rule hasHabitsWithReminders() is the outermost condition, '
              'so nothing below it runs.');
      expect(f.gate.permissionAlreadyRequested, isFalse,
          reason: '$rule …and the once-per-instance flag is not spent either.');
    });
  });
}
