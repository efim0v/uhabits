/// `audit3.toggling-make-notifications-sticky-does-not#1`: flipping "Make
/// notifications sticky" applies to the very next reminder.
///
/// Upstream the flag is read inside `AndroidNotificationTray.buildNotification`
/// — `setOngoing(preferences.shouldMakeNotificationsSticky())` — which runs
/// when the alarm fires. Nothing has to be rescheduled: whatever the preference
/// says at fire time is what the notification gets.
///
/// This port has no fire-time hook (see the class comment on
/// [FlutterAlarmScheduler]): `zonedSchedule` is handed a finished notification
/// at *schedule* time, so every pending alarm carries the flag that was in
/// force when it was armed. Re-arming the alarms when the switch is flipped is
/// what restores the rule, and the switch is flipped on the settings screen —
/// so that is where these tests press.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

const String rule =
    'audit3.toggling-make-notifications-sticky-does-not#1 — In the Kotlin '
    'app: The ongoing flag is read when the notification is built, which is '
    'when the alarm fires. Flipping the setting in Settings applies to the '
    'very next reminder.';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _ScheduledAlarm {
  _ScheduledAlarm(this.spec, this.whenMillis);

  final NotificationSpec spec;
  final int whenMillis;
}

class _FakeAlarmPlugin implements AlarmPlugin {
  final List<_ScheduledAlarm> scheduled = <_ScheduledAlarm>[];
  final List<int> cancelled = <int>[];

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async =>
      scheduled.add(_ScheduledAlarm(spec, whenMillis));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;
}

class _SilentSystemTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}

class _SilentWidgetPlatform implements HomeWidgetPlatform {
  @override
  Future<void> saveWidgetData(String id, String? data) async {}

  @override
  Future<void> setAppGroupId(String groupId) async {}

  @override
  Future<void> updateWidget({String? name, String? androidName, String? iOSName,
      String? qualifiedAndroidName}) async {}
}

/// A bounded stand-in for `pumpAndSettle`.
///
/// A started [AppScope] owns a [MidnightTimer], and `pumpAndSettle` advances
/// the fake clock until nothing is scheduled — which a periodic timer never
/// satisfies. Two frames and half a second of animation is all any of these
/// assertions needs, and it is what keeps the zero-duration timers behind
/// `AsyncDispatcher` running.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_sticky');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  /// An app scope whose reminder scheduler is the real [FlutterAlarmScheduler]
  /// over a fake plugin, started through [AppScope.startServices] exactly as
  /// `HabitsApplication.onCreate` starts it.
  ({AppScope scope, _FakeAlarmPlugin plugin, PreferencesStorage storage})
      boot() {
    final storage = MemoryStorage();
    final database = AppDatabase.openAndMigrate(
      '${tempDir.path}/habits${databaseIndex++}.db',
    );
    final scope = AppScope.open(database, preferencesStorage: storage);
    scope.preferences.isFirstRun = false;
    scopes.add(scope);

    final plugin = _FakeAlarmPlugin();
    final builder = ReminderNotificationBuilder(
      preferences: scope.preferences,
      strings: () => NotificationStrings.from(L10nEn()),
    );
    scope.startServices(
      tray: NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _SilentSystemTray(),
      ),
      scheduler: ReminderScheduler(
        scope.commandRunner,
        scope.habitList,
        FlutterAlarmScheduler(plugin: plugin, builder: builder),
        WidgetPreferences(scope.preferencesStorage),
      ),
      sync: WidgetSync(
        bridge: HomeWidgetBridge(
          habitList: scope.habitList,
          registry: WidgetRegistry(scope.preferencesStorage),
          platform: _SilentWidgetPlatform(),
        ),
        commandRunner: scope.commandRunner,
        taskRunner: scope.taskRunner,
        midnightTimer: scope.midnightTimer,
        preferences: scope.preferences,
      ),
    );
    return (scope: scope, plugin: plugin, storage: storage);
  }

  Habit addHabitWithReminder(AppScope scope) {
    final habit = scope.modelFactory.buildHabit()
      ..name = 'Meditate'
      ..type = HabitType.yesNo
      ..frequency = Frequency.daily
      ..reminder = Reminder(8, 30, WeekdayList.everyDay);
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Future<void> openSettings(
    WidgetTester tester,
    AppScope scope,
    PreferencesStorage storage,
  ) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: SettingsScreen(storage: storage),
      ),
    ));
    await settle(tester);
  }

  Future<void> tapSwitch(WidgetTester tester, String key) async {
    await tester.tap(find.descendant(
      of: find.byKey(ValueKey<String>(key)),
      matching: find.byType(Switch),
    ));
    await settle(tester);
  }

  group('audit3.toggling-make-notifications-sticky-does-not', () {
    testWidgets('#1 flipping the switch re-arms the pending alarm with the '
        'new flag', (tester) async {
      final booted = boot();
      addHabitWithReminder(booted.scope);
      await settle(tester);
      booted.scope.reminderScheduler!.scheduleAll();
      await settle(tester);

      expect(booted.plugin.scheduled, isNotEmpty,
          reason: '$rule The precondition: an alarm is pending.');
      expect(booted.plugin.scheduled.last.spec.ongoing, isFalse,
          reason: '$rule Sticky is off by default.');

      await openSettings(tester, booted.scope, booted.storage);
      final int before = booted.plugin.scheduled.length;
      await tapSwitch(tester, 'pref_sticky_notifications');

      expect(booted.scope.preferences.shouldMakeNotificationsSticky(), isTrue,
          reason: '$rule The row writes the preference.');
      expect(booted.plugin.scheduled.length, greaterThan(before),
          reason: '$rule The port builds the notification at schedule time, '
              'so the flag only reaches the user if the pending alarms are '
              're-armed when the switch is flipped.');
      expect(booted.plugin.scheduled.last.spec.ongoing, isTrue,
          reason: '$rule The very next reminder is the sticky one.');
    });

    testWidgets('#1 flipping it back re-arms again, non-sticky',
        (tester) async {
      final booted = boot();
      booted.scope.preferences.setNotificationsSticky(true);
      addHabitWithReminder(booted.scope);
      await settle(tester);
      booted.scope.reminderScheduler!.scheduleAll();
      await settle(tester);
      expect(booted.plugin.scheduled.last.spec.ongoing, isTrue);

      await openSettings(tester, booted.scope, booted.storage);
      await tapSwitch(tester, 'pref_sticky_notifications');

      expect(booted.scope.preferences.shouldMakeNotificationsSticky(), isFalse,
          reason: rule);
      expect(booted.plugin.scheduled.last.spec.ongoing, isFalse,
          reason: '$rule The rule runs both ways: the flag in force when the '
              'reminder is shown is the flag the user last chose.');
    });
  });
}
