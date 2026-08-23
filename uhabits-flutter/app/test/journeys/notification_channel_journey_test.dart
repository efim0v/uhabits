/// Journey: the user opens Settings and taps "Customize notifications".
///
/// `audit3.settings-customize-notification-is-permanently-disabled#1` and
/// `audit3.customize-notifications-settings-row-is-hard#1` — "Tapping the row
/// in the Reminder category creates the REMINDERS channel and opens Android's
/// per-channel notification settings, where the user changes the reminder
/// sound, vibration and importance." That is `notifications.channel#3` and
/// `settings.screen.reminder-category#7`.
///
/// Everything behind the row already shipped and was already tested:
/// `PlatformNotificationChannelSettings`, `LocalNotificationsChannelCreator`,
/// and the `openChannelSettings` handler in
/// `android/app/src/main/kotlin/org/isoron/uhabits/MainActivity.kt`. What was
/// missing was the one line that builds the object — so the row rendered
/// `enabled: false` with "No app was found to support this action" under it,
/// and no test could tell, because every test of that class constructed it
/// itself.
///
/// This journey therefore refuses to construct anything. It launches the app,
/// walks to the row through the overflow menu, taps it, and listens at the two
/// *platform channels* the flow ends at: the plugin's, where the REMINDERS
/// channel is created, and the app's own, where `MainActivity` is asked for
/// `Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart'
    show PlatformNotificationChannelSettings;
import 'package:uhabits/ui/settings/settings_screen.dart' show SettingsRow;
// The core's NotificationTray owns the channel id both sides agree on.
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/notification_tray.dart' show NotificationTray;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  /// Every call the app made to `MainActivity`'s method channel.
  late List<MethodCall> activityCalls;

  /// How many notification channels had been created by the time the intent
  /// was asked for. `notifications.channel#3` is an ordering rule: the screen
  /// the intent opens is a view onto one channel, so a channel Android has
  /// never been told about lands the user on an empty page.
  late List<int> channelsAtOpen;

  /// What `MainActivity.startActivitySafely` answers: true when something on
  /// the device handled the intent.
  late bool activityAnswer;

  TestDefaultBinaryMessenger messenger() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// The channel calls the plugin made, from the device's own recording.
  List<MethodCall> createdChannels() =>
      device.notifications.callsNamed('createNotificationChannel');

  setUp(() {
    device = TestDevice.create('uhabits_journey_channel');
    activityCalls = <MethodCall>[];
    channelsAtOpen = <int>[];
    activityAnswer = true;
    // `MainActivity`'s `MethodChannel.setMethodCallHandler`, which is the only
    // thing on the far side of this flow. Registered here rather than inside
    // the app, so that a row that never talks to the platform is visible as
    // silence.
    messenger().setMockMethodCallHandler(
      const MethodChannel(PlatformNotificationChannelSettings.methodChannelName),
      (MethodCall call) async {
        activityCalls.add(call);
        channelsAtOpen.add(createdChannels().length);
        return activityAnswer;
      },
    );
  });

  tearDown(() {
    messenger().setMockMethodCallHandler(
      const MethodChannel(PlatformNotificationChannelSettings.methodChannelName),
      null,
    );
    app.dispose();
    device.dispose();
  });

  Future<void> launchToSettings(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await openSettings(tester);
  }

  testWidgets('the row opens the system\'s per-channel notification settings',
      (WidgetTester tester) async {
    await launchToSettings(tester);

    // `AndroidNotificationTray.createAndroidNotificationChannel` also runs
    // once at startup, so the row's own creation is the one after this.
    final int channelsBefore = createdChannels().length;

    await tapSettingsRow(tester, 'reminderCustomize');

    expect(activityCalls.map((MethodCall call) => call.method),
        contains(PlatformNotificationChannelSettings.openChannelSettingsMethod),
        reason:
            'audit3.customize-notifications-settings-row-is-hard#1: tapping '
            'the row starts Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS. '
            'PlatformNotificationChannelSettings ships and is tested; nothing '
            'constructed it, so the tap reached no platform at all.');
    expect(
      (activityCalls.last.arguments
          as Map<Object?, Object?>)[PlatformNotificationChannelSettings
          .channelIdArgument],
      NotificationTray.remindersChannelId,
      reason: 'audit3.settings-customize-notification-is-permanently-disabled#1: '
          'EXTRA_CHANNEL_ID = "REMINDERS" — the screen is a view onto the '
          'reminder channel, and that is the channel whose sound, vibration '
          'and importance the user came to change.',
    );
    expect(createdChannels().length, channelsBefore + 1,
        reason: 'audit3.customize-notifications-settings-row-is-hard#1: '
            'tapping the row creates the REMINDERS channel');
    expect(channelsAtOpen, <int>[channelsBefore + 1],
        reason: 'audit3.customize-notifications-settings-row-is-hard#1: the '
            'channel is created BEFORE the intent is started, so the settings '
            'screen has a channel to show');
  });

  testWidgets('and the row is a live row, not a disabled one',
      (WidgetTester tester) async {
    await launchToSettings(tester);
    final L10n l10n = stringsOf(tester);

    final SettingsRow row = tester.widget<SettingsRow>(
      find.byKey(const ValueKey<String>('reminderCustomize')),
    );
    expect(row.enabled, isTrue,
        reason: 'audit3.settings-customize-notification-is-permanently-disabled'
            '#1: the row is permanently disabled although the whole Android '
            'integration behind it is implemented and tested. A greyed-out row '
            'cannot be tapped at all.');
    expect(row.onTap, isNotNull,
        reason: 'settings.screen.reminder-category#7: clicking it first calls '
            'createAndroidNotificationChannel and then starts '
            'ACTION_CHANNEL_NOTIFICATION_SETTINGS');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('reminderCustomize')),
        matching: find.text(l10n.activityNotFound),
      ),
      findsNothing,
      reason: 'audit3.customize-notifications-settings-row-is-hard#1: the '
          '"no app was found" note belongs to a row with nothing behind it; '
          'the whole implementation behind this one ships',
    );
  });

  testWidgets('a device with nothing to handle the intent says so',
      (WidgetTester tester) async {
    // `startActivitySafely`'s `ActivityNotFoundException` branch: the intent
    // was started and nothing answered.
    activityAnswer = false;
    await launchToSettings(tester);
    final L10n l10n = stringsOf(tester);

    await tapSettingsRow(tester, 'reminderCustomize');

    expect(activityCalls, isNotEmpty,
        reason: 'the intent is still attempted — that is what tells the app '
            'whether anything can handle it');
    // Scoped to the snackbar: the disabled `reminderSound` row above carries
    // the same sentence as a permanent note.
    expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(l10n.activityNotFound),
        ),
        findsOneWidget,
        reason: 'audit3.settings-customize-notification-is-permanently-disabled'
            '#1: Android answers a click it cannot serve with '
            '"No app was found to support this action". Hard-disabling the row '
            'in advance shows that message to everyone, including the users '
            'whose device does handle it.');
  });
}
