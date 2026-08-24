/// `audit11.reminders-channel-is-created-with-vibration`.
///
/// `AndroidNotificationTray.createAndroidNotificationChannel` builds the
/// REMINDERS channel with the three-argument constructor and hands it straight
/// to the manager:
///
/// ```kotlin
/// val channel = NotificationChannel(
///     REMINDERS_CHANNEL_ID,
///     context.resources.getString(R.string.reminder),
///     NotificationManager.IMPORTANCE_DEFAULT
/// )
/// notificationManager.createNotificationChannel(channel)
/// ```
///
/// In AOSP that constructor assigns id, name and importance and nothing else
/// (`NotificationChannel.java:350-353`). `mVibrationEnabled` is declared with
/// no initialiser (`:319`) and is therefore **false**, while `mSound` defaults
/// to `DEFAULT_NOTIFICATION_URI` (`:309`) and `mShowBadge` to true (`:320`). An
/// upstream reminder is sound-only: it chimes and does not buzz.
///
/// `flutter_local_notifications` 18.0.1 defaults `enableVibration` to **true**
/// — on `AndroidNotificationChannel` (notification_channel.dart:18) and on
/// `AndroidNotificationDetails` (notification_details.dart:111), and its Java
/// side calls `notificationChannel.enableVibration(...)` unconditionally. A
/// channel's sound and vibration are immutable once Android has seen it, so
/// whichever of the three sites below runs first on a fresh install is the one
/// that decides, permanently, whether every reminder this user ever gets
/// vibrates. All three therefore have to say the same thing.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

/// The channel `flutter_local_notifications` talks over.
const String _pluginChannel = 'dexterous.com/flutter/local_notifications';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const NotificationStrings strings = NotificationStrings(
    yes: 'Yes',
    no: 'No',
    enter: 'Enter',
    snooze: 'Later',
    defaultReminderQuestion: 'Have you completed this habit today?',
    channelName: 'Reminder',
  );

  late Preferences preferences;
  late FlutterLocalNotificationsPlugin plugin;
  late LocalNotificationsPresenter presenter;
  late List<MethodCall> platformCalls;

  TestDefaultBinaryMessenger messenger() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    // What the Flutter engine's plugin registrant does on a real device. The
    // test host has no registrant, so without it the plugin resolves to no
    // platform implementation and `createNotificationChannel` does nothing at
    // all — which is exactly how a channel property can go unnoticed.
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    preferences = Preferences(MemoryStorage());
    plugin = FlutterLocalNotificationsPlugin();
    presenter = LocalNotificationsPresenter(
      plugin: plugin,
      builder: ReminderNotificationBuilder(
        preferences: preferences,
        strings: () => strings,
      ),
    );
    platformCalls = <MethodCall>[];
    messenger().setMockMethodCallHandler(
      const MethodChannel(_pluginChannel),
      (MethodCall call) async {
        platformCalls.add(call);
        switch (call.method) {
          case 'getNotificationAppLaunchDetails':
            return <Object?, Object?>{'notificationLaunchedApp': false};
          default:
            return true;
        }
      },
    );
  });

  tearDown(() {
    messenger().setMockMethodCallHandler(
      const MethodChannel(_pluginChannel),
      null,
    );
  });

  /// The arguments of the last `createNotificationChannel` the plugin sent.
  Map<Object?, Object?> lastChannel() {
    final MethodCall call = platformCalls.lastWhere(
      (MethodCall call) => call.method == 'createNotificationChannel',
    );
    return call.arguments as Map<Object?, Object?>;
  }

  NotificationSpec spec() => NotificationSpec(
        id: 7,
        channelId: NotificationTray.remindersChannelId,
        channelName: strings.channelName,
        categoryId: ReminderCategories.yesNo,
        title: 'Meditate',
        body: 'Did you meditate this morning?',
        whenMillis: 1590000000000,
        ongoing: false,
        playSound: true,
        actions: const <ReminderNotificationAction>[],
        payload: 'payload',
      );

  group('the REMINDERS channel does not vibrate', () {
    test('the channel created when the plugin is initialised', () async {
      await LocalNotificationsPresenter.initialize(
        plugin: plugin,
        builder: ReminderNotificationBuilder(
          preferences: preferences,
          strings: () => strings,
        ),
      );

      final Map<Object?, Object?> channel = lastChannel();
      expect(channel['id'], NotificationTray.remindersChannelId,
          reason: 'notifications.channel#1: the channel is "REMINDERS"');
      expect(
        channel['enableVibration'],
        isFalse,
        reason: 'audit11.reminders-channel-is-created-with-vibration#1: the '
            'three-argument NotificationChannel(id, name, importance) leaves '
            'mVibrationEnabled at its false default, so a Loop reminder on '
            'Android chimes and does not buzz. flutter_local_notifications '
            'defaults enableVibration to true, and channel settings are '
            'immutable after first creation — this is the call that bakes the '
            'answer in on a fresh install.',
      );
      expect(
        channel['playSound'],
        isTrue,
        reason: 'audit11.reminders-channel-is-created-with-vibration#1: sound '
            'is at parity and must stay there. AOSP mSound defaults to '
            'DEFAULT_NOTIFICATION_URI (NotificationChannel.java:309) and the '
            'plugin resolves playSound: true to the same URI, so vibration is '
            'the sole divergence in the channel.',
      );
      expect(
        channel['enableLights'],
        isFalse,
        reason: 'audit11.reminders-channel-is-created-with-vibration#1: mLights '
            'is false on both sides too',
      );
      expect(
        channel['showBadge'],
        isTrue,
        reason: 'audit11.reminders-channel-is-created-with-vibration#1: '
            'mShowBadge defaults to true (NotificationChannel.java:320), which '
            'is also the plugin default',
      );
    });

    test('the channel created by the "Customize notifications" row', () async {
      await LocalNotificationsChannelCreator(
        plugin: plugin,
        channelName: strings.channelName,
      ).createReminderChannel();

      final Map<Object?, Object?> channel = lastChannel();
      expect(channel['id'], NotificationTray.remindersChannelId,
          reason: 'notifications.channel#3: the row creates the channel the '
              'settings screen is a view onto');
      expect(
        channel['enableVibration'],
        isFalse,
        reason: 'audit11.reminders-channel-is-created-with-vibration#1: both '
            'creation sites are the same Kotlin method — '
            'AndroidNotificationTray.createAndroidNotificationChannel — so '
            'they cannot disagree. On an install where the user has deleted '
            'the channel from Android settings, this is the call that '
            're-creates it.',
      );
    });

    test('the channel the plugin would build from a posted reminder', () {
      final AndroidNotificationDetails details =
          presenter.detailsFor(spec()).android!;

      expect(
        details.enableVibration,
        isFalse,
        reason: 'audit11.reminders-channel-is-created-with-vibration#1: '
            'AndroidNotificationDetails carries channelAction '
            'createIfNotExists by default, so the plugin builds a channel out '
            'of these details whenever one does not exist yet '
            '(NotificationChannelDetails.fromNotificationDetails). A third '
            'site with the plugin default would re-introduce the vibrating '
            'channel the two above avoid.',
      );
      expect(
        details.channelId,
        NotificationTray.remindersChannelId,
        reason: 'notifications.channel#1: and it is the same channel',
      );
    });

    test('a reminder posted through the plugin carries the same answer',
        () async {
      await presenter.show(spec());

      final MethodCall call = platformCalls
          .lastWhere((MethodCall call) => call.method == 'show');
      final Map<Object?, Object?> arguments =
          call.arguments as Map<Object?, Object?>;
      final Map<Object?, Object?> android =
          arguments['platformSpecifics'] as Map<Object?, Object?>;

      expect(
        android['enableVibration'],
        isFalse,
        reason: 'audit11.reminders-channel-is-created-with-vibration#1: what '
            'detailsFor decides is what reaches the platform — the assertion '
            'above is not about a field nobody reads',
      );
    });
  });
}
