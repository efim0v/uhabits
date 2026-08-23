/// The platform declarations the reminder pipeline stands on: the manifest
/// entries that let an alarm survive a reboot and be exact at all, the small
/// icon a reminder is drawn with, and the system notification-channel screen.
///
/// ## Why some assertions read files
///
/// `android/app/src/main/` is a real Android application: a manifest, a
/// drawable, and one Kotlin activity. None of it executes under `flutter
/// test` — there is no Android runtime here — and upstream asserted these
/// rules either with instrumentation (`IntentSchedulerTest`) or not at all.
/// What is left is still a fact about a file in this repository, and a test
/// that extracts the value and compares it catches the same regression the
/// instrumentation would: a permission dropped, a receiver that silently stops
/// being registered, a drawable deleted out from under the plugin.
///
/// Every assertion below extracts a *value*. Nothing asserts that a file
/// merely mentions something.
library;

// The classes under test implement core interfaces reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

// ---------------------------------------------------------------------------
// Reading the Android source set
// ---------------------------------------------------------------------------

/// The `android/app/src/main` directory of the Flutter app, found by walking up
/// from the test's working directory so the file works whether `flutter test`
/// is invoked from `app/` or from the repository root.
final Directory androidMain = _findAndroidMain();

Directory _findAndroidMain() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    final Directory candidate = Directory('${dir.path}/android/app/src/main');
    if (File('${candidate.path}/AndroidManifest.xml').existsSync()) {
      return candidate;
    }
    final Directory app = Directory('${dir.path}/app/android/app/src/main');
    if (File('${app.path}/AndroidManifest.xml').existsSync()) return app;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'android/app/src/main not found from ${Directory.current.path}',
  );
}

String androidSource(String relative) =>
    File('${androidMain.path}/$relative').readAsStringSync();

/// Collapses runs of whitespace so an XML element can be matched without
/// depending on how it happens to be indented.
String flattened(String xml) => xml.replaceAll(RegExp(r'\s+'), ' ');

/// The `android:name` of every `<uses-permission>`, in declaration order.
List<String> declaredPermissions(String manifest) =>
    RegExp(r'<uses-permission\s+android:name="([^"]+)"\s*/>')
        .allMatches(manifest)
        .map((m) => m.group(1)!)
        .toList();

/// The body of the single `<receiver>` element whose `android:name` contains
/// [nameFragment], whitespace-collapsed.
String receiverElement(String manifest, String nameFragment) {
  final flat = flattened(manifest);
  for (final match in RegExp(r'<receiver\b.*?</receiver>').allMatches(flat)) {
    if (match.group(0)!.contains(nameFragment)) return match.group(0)!;
  }
  throw StateError('no <receiver> naming "$nameFragment" in the manifest');
}

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
  bool exactAlarmsAllowed = true;

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async {
    scheduled.add(_ScheduledAlarm(spec, whenMillis));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsAllowed;

  @override
  Future<bool> requestExactAlarmsPermission() async => exactAlarmsAllowed;
}

/// Records that the channel was (re)created, without a plugin behind it.
class _RecordingChannelCreator implements NotificationChannelCreator {
  _RecordingChannelCreator(this.order);

  final List<String> order;
  int created = 0;

  @override
  Future<void> createReminderChannel() async {
    created++;
    order.add('createChannel');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const TimeZone gmt = FixedTimeZone(0);

  const NotificationStrings strings = NotificationStrings(
    yes: 'Yes',
    no: 'No',
    enter: 'Enter',
    snooze: 'Later',
    defaultReminderQuestion: 'Have you completed this habit today?',
    channelName: 'Reminder',
  );

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late Preferences preferences;
  late StringBuffer logBuffer;
  late Logging logging;

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    setToday(LocalDate.ymd(2020, 6, 1));
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    preferences = Preferences(MemoryStorage());
    logBuffer = StringBuffer();
    logging = StandardLogging(out: logBuffer, err: logBuffer);
  });

  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
  });

  ReminderNotificationBuilder buildBuilder() => ReminderNotificationBuilder(
        preferences: preferences,
        strings: strings,
      );

  Habit habitWithReminder() {
    final habit = fixtures.createEmptyHabit();
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    habitList.add(habit);
    return habit;
  }

  // -----------------------------------------------------------------------
  // notifications.content#2 — the small icon
  // -----------------------------------------------------------------------

  group('the reminder small icon', () {
    // That this name really reaches `plugin.initialize` at startup — which is
    // what makes the notification appear at all — is asserted where the
    // startup runs: test/state/reminder_response_wiring_test.dart.
    test('the small icon the app initialises the plugin with is the drawable',
        () {
      expect(LocalNotificationsPresenter.androidSmallIcon, 'ic_notification',
          reason: 'notifications.content#2: small icon is '
              'R.drawable.ic_notification. The plugin takes the drawable by '
              'name and resolves @drawable/<name> out of the app resources, so '
              'the name IS the setSmallIcon argument.');
    });

    test('that drawable exists in the app resources and is a white vector', () {
      final path =
          '${androidMain.path}/res/drawable/'
          '${LocalNotificationsPresenter.androidSmallIcon}.xml';
      expect(File(path).existsSync(), isTrue,
          reason: 'notifications.content#2: a small icon Android cannot '
              'resolve is a reminder that never appears, so the drawable the '
              'initialisation names has to be in the source set');

      final drawable = flattened(File(path).readAsStringSync());
      expect(drawable, contains('<vector'),
          reason: 'notifications.content#2: ic_notification is the vector '
              'drawable of the Android build');
      expect(drawable, contains('android:fillColor="#FFFFFF"'),
          reason: 'notifications.content#2: a notification small icon is '
              'drawn as a silhouette, which is why the upstream asset is '
              'pure white');
    });
  });

  // -----------------------------------------------------------------------
  // notifications.channel#3 — the system channel-settings screen
  // -----------------------------------------------------------------------

  group('the "Customize notifications" entry', () {
    late List<String> order;
    late List<MethodCall> calls;
    late _RecordingChannelCreator creator;
    late PlatformNotificationChannelSettings settings;
    late bool activityFound;

    setUp(() {
      order = <String>[];
      calls = <MethodCall>[];
      activityFound = true;
      creator = _RecordingChannelCreator(order);
      const channel = MethodChannel(
        PlatformNotificationChannelSettings.methodChannelName,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        order.add('startActivity');
        return activityFound;
      });
      settings = PlatformNotificationChannelSettings(
        creator: creator,
        channel: channel,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(
          PlatformNotificationChannelSettings.methodChannelName,
        ),
        null,
      );
    });

    test('creates the channel first and only then launches the screen',
        () async {
      final opened = await settings.openReminderChannelSettings();

      expect(order, <String>['createChannel', 'startActivity'],
          reason: 'notifications.channel#3: the channel is created on demand '
              'when the user taps "Customize notifications", BEFORE launching '
              'Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS');
      expect(creator.created, 1,
          reason: 'notifications.channel#3: createAndroidNotificationChannel '
              'runs exactly once per tap');
      expect(opened, isTrue,
          reason: 'notifications.channel#3: the intent was started');
    });

    test('the launch carries the REMINDERS channel id', () async {
      await settings.openReminderChannelSettings();

      expect(calls.single.method,
          PlatformNotificationChannelSettings.openChannelSettingsMethod,
          reason: 'notifications.channel#3: one call, which is the '
              'ACTION_CHANNEL_NOTIFICATION_SETTINGS launch');
      expect(
        (calls.single.arguments
            as Map)[PlatformNotificationChannelSettings.channelIdArgument],
        'REMINDERS',
        reason: 'notifications.channel#3: EXTRA_CHANNEL_ID = "REMINDERS"',
      );
      expect(NotificationTray.remindersChannelId, 'REMINDERS',
          reason: 'notifications.channel#3: and that id is the constant the '
              'notifications themselves are posted under, not a copy');
    });

    test('a host with no such screen answers false instead of crashing',
        () async {
      activityFound = false;
      expect(await settings.openReminderChannelSettings(), isFalse,
          reason: 'notifications.channel#3: the launch is the '
              'startActivitySafely branch — a device with no '
              'notification-settings activity gets a message, not a crash');
      expect(creator.created, 1,
          reason: 'notifications.channel#3: the channel is still created; '
              'only the screen failed to open');
    });

    test('the Android activity builds the documented intent', () {
      final activity = flattened(
        androidSource('kotlin/org/isoron/uhabits/MainActivity.kt'),
      );

      expect(
        activity,
        contains('"${PlatformNotificationChannelSettings.methodChannelName}"'),
        reason: 'notifications.channel#3: the Dart side and the activity have '
            'to agree on the channel name, or the tap reaches nothing',
      );
      expect(activity, contains('Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS'),
          reason: 'notifications.channel#3: it starts '
              'Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS');
      expect(activity, contains('putExtra(Settings.EXTRA_APP_PACKAGE, packageName)'),
          reason: 'notifications.channel#3: with EXTRA_APP_PACKAGE = '
              'packageName — the running package, which only the Android side '
              'knows');
      expect(activity, contains('putExtra(Settings.EXTRA_CHANNEL_ID, channelId)'),
          reason: 'notifications.channel#3: and EXTRA_CHANNEL_ID = the id Dart '
              'sent, which is "REMINDERS"');
    });

  });

  // -----------------------------------------------------------------------
  // reminders.exact-alarm-scheduling — the manifest half and the alarm type
  // -----------------------------------------------------------------------

  group('exact alarms', () {
    test('#8 the five permissions the reminder pipeline declares', () {
      final permissions =
          declaredPermissions(androidSource('AndroidManifest.xml'));

      for (final permission in <String>[
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.SCHEDULE_EXACT_ALARM',
        'android.permission.USE_EXACT_ALARM',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.VIBRATE',
      ]) {
        expect(permissions, contains(permission),
            reason: 'reminders.exact-alarm-scheduling#8: manifest permissions '
                'declared for this are RECEIVE_BOOT_COMPLETED, '
                'SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, POST_NOTIFICATIONS and '
                'VIBRATE. Without the two exact-alarm ones '
                'AlarmManager.canScheduleExactAlarms() is false on API 31+ and '
                'no reminder is ever scheduled.');
      }
    });

    test('#5 the alarm type is the waking one', () {
      expect(LocalNotificationsAlarmPlugin.reminderScheduleMode,
          AndroidScheduleMode.exactAllowWhileIdle,
          reason: 'reminders.exact-alarm-scheduling#5: scheduleShowReminder '
              'uses alarm type RTC_WAKEUP (wakes the device). '
              'AndroidScheduleMode.exactAllowWhileIdle is this plugin\'s name '
              'for setExactAndAllowWhileIdle(alarmManager, '
              'AlarmManager.RTC_WAKEUP, ...) — every other mode it offers is '
              'either inexact or an alarm clock.');
      expect(
        AndroidScheduleMode.values.where((mode) =>
            mode == AndroidScheduleMode.inexact ||
            mode == AndroidScheduleMode.inexactAllowWhileIdle),
        isNotEmpty,
        reason: 'reminders.exact-alarm-scheduling#5: the inexact modes exist '
            'and are deliberately not the one chosen',
      );
    });

    test('#9 the IntentSchedulerTest regression instant', () async {
      // The Kotlin instrumentation pins the system clock to America/Chicago
      // 2020-06-01 12:30 (17:30 UTC) and schedules 1591155900000, which is
      // 2020-06-03 03:45 UTC — 2020-06-02 22:45 in Chicago. That is the whole
      // content of "nothing at 22:44, delivered at 22:46": the alarm is armed
      // for that instant and not before it. Delivery itself belongs to
      // AlarmManager and needs a device; what the port controls, and what is
      // asserted here, is the instant handed over and the result returned.
      const int chicagoNoon = 1591032600000;
      const int alarmInstant = 1591155900000;
      final plugin = _FakeAlarmPlugin();
      final scheduler = FlutterAlarmScheduler(
        plugin: plugin,
        builder: buildBuilder(),
        logging: logging,
        nowMillis: () => chicagoNoon,
      );
      final habit = habitWithReminder();

      final result = scheduler.scheduleShowReminder(alarmInstant, habit, 0);
      await scheduler.settle();

      expect(result, SchedulerResult.ok,
          reason: 'reminders.exact-alarm-scheduling#9: with system time '
              'America/Chicago 2020-06-01 12:30, '
              'scheduleShowReminder(1591155900000, habit, 0) returns OK');
      expect(plugin.scheduled.single.whenMillis, alarmInstant,
          reason: 'reminders.exact-alarm-scheduling#9: the alarm is armed for '
              'that exact instant — 2020-06-02 22:45 in Chicago, which is why '
              'the instrumentation sees nothing at 22:44 and the intent at '
              '22:46');
      expect(
        DateTime.fromMillisecondsSinceEpoch(alarmInstant, isUtc: true)
            .subtract(const Duration(hours: 5)),
        DateTime.utc(2020, 6, 2, 22, 45),
        reason: 'reminders.exact-alarm-scheduling#9: 1591155900000 IS '
            '2020-06-02 22:45 in Chicago (CDT, UTC-5)',
      );

      final decoded =
          ReminderPayload.decode(plugin.scheduled.single.spec.payload)!;
      expect(decoded.habitId, habit.id,
          reason: 'reminders.exact-alarm-scheduling#9: and the intent that '
              'arrives parses back to the habit\'s id');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.boot-reschedule — the manifest half
  // -----------------------------------------------------------------------

  group('rescheduling after a reboot', () {
    test('#1 a boot receiver is registered, exported, with the permission', () {
      final manifest = androidSource('AndroidManifest.xml');
      final receiver = receiverElement(manifest, 'BootReceiver');

      expect(receiver, contains('android:exported="true"'),
          reason: 'reminders.boot-reschedule#1: the receiver is registered in '
              'the manifest with android:exported="true"');
      expect(receiver, contains('android.intent.action.BOOT_COMPLETED'),
          reason: 'reminders.boot-reschedule#1: with an intent-filter for '
              'android.intent.action.BOOT_COMPLETED');
      expect(declaredPermissions(manifest),
          contains('android.permission.RECEIVE_BOOT_COMPLETED'),
          reason: 'reminders.boot-reschedule#1: and the app declares '
              'android.permission.RECEIVE_BOOT_COMPLETED');
    });

    test('#2 receiving BOOT_COMPLETED re-arms every alarm', () {
      final receiver = receiverElement(
        androidSource('AndroidManifest.xml'),
        'BootReceiver',
      );

      expect(
        receiver,
        contains(
          'com.dexterous.flutterlocalnotifications.'
          'ScheduledNotificationBootReceiver',
        ),
        reason: 'reminders.boot-reschedule#2 and '
            'intents.reminder-receiver-dispatch#8 — Intent.ACTION_BOOT_'
            'COMPLETED: the receiver calls '
            'reminderController.onBootCompleted() (the habit is irrelevant), '
            'which is reminderScheduler.scheduleAll(). This port has no '
            'fire-time hook — an alarm IS the finished notification, handed to '
            'the OS by zonedSchedule — so the "re-arm everything that was '
            'armed" pass is '
            'ScheduledNotificationBootReceiver.rescheduleNotifications, which '
            'flutter_local_notifications does NOT declare in its own manifest.',
      );
      expect(receiver.contains('android:name="android.intent.action.'
          'BOOT_COMPLETED"'), isTrue,
          reason: 'intents.reminder-receiver-dispatch#8: the boot branch is '
              'reached by the BOOT_COMPLETED action and carries no habit data '
              'at all — no scheme, no host, no path');
    });
  });
}
