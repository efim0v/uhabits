/// The iOS half of "a reminder can be answered without opening the app".
///
/// "Yes" and "No" are background actions on both platforms: on Android they are
/// broadcasts to `WidgetReceiver`, which writes the entry with no UI whether or
/// not the process was alive. `audit5` found that half missing — three plugin
/// receivers undeclared in the manifest — and this is the same gap on the other
/// platform, which needs one thing Android has no equivalent of.
///
/// iOS answers a non-foreground action by starting a second Flutter engine, and
/// `FlutterEngineManager` registers the app's plugins into it through the
/// callback `setPluginRegistrantCallback` installs. Without that callback it
/// calls a nil block; the `NSAssert` that would name the problem is compiled
/// out of a release build, so the process dies and the tap records nothing.
///
/// Asserted against the source, as `manifest_components_test.dart` asserts the
/// Android declarations and for the same reason: the code that fails is
/// Objective-C reached only by a real `UNUserNotificationCenter` callback on a
/// device, which no test in this project can drive.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String delegateRule =
    'audit21.ios-must-own-the-notification-centre-delegate#1 — every iOS '
    'notification interaction is dispatched from the notification centre\'s '
    'delegate, and FlutterAppDelegate does not put itself in that seat.';

const String rule =
    'audit20.ios-background-notification-actions-need-a-registrant#1 — a '
    'reminder that cannot be answered from the notification is a reminder the '
    'user has to open the app to answer, which is the one thing the action '
    'buttons exist to avoid.';

void main() {
  final String source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

  test('the app delegate installs a plugin registrant callback', () {
    expect(source, contains('setPluginRegistrantCallback'),
        reason: '$rule FlutterEngineManager calls this block to build the '
            'background engine; nil means a dead process.');
    expect(source, contains('GeneratedPluginRegistrant.register(with: registry)'),
        reason: '$rule …and it has to register the real plugins, or the '
            'background isolate comes up without the channels '
            'reminderBackgroundResponse needs.');
  });

  test('the app delegate takes the notification centre seat', () {
    // The callback above is only ever reached from
    // `-userNotificationCenter:didReceiveNotificationResponse:`, which iOS
    // calls on the notification centre's delegate and nowhere else.
    // FlutterAppDelegate implements that method and forwards it to the
    // registered plugins, but it does not install itself as the delegate — the
    // plugin's own setup instructions are this line
    // (`audit21.ios-must-own-the-notification-centre-delegate#1`).
    expect(source, contains('UNUserNotificationCenter.current().delegate'),
        reason: '$delegateRule Without it every reminder on iOS is a dead end: '
            'the body tap opens the plain list, Yes and No record nothing, '
            'Enter and Later open nothing, and a reminder that fires with the '
            'app open is never shown.');
    expect(source, contains('import UserNotifications'), reason: delegateRule);

    final int delegate = source.indexOf('UNUserNotificationCenter.current().delegate');
    final int superCall =
        source.indexOf('super.application(application, didFinishLaunchingWithOptions');
    expect(superCall, greaterThan(delegate),
        reason: '$delegateRule A launch caused by a notification tap reaches '
            'the delegate during this call, so the seat has to be taken first.');
  });

  test('it is installed before the superclass finishes launching', () {
    final int callback = source.indexOf('setPluginRegistrantCallback');
    final int superCall =
        source.indexOf('super.application(application, didFinishLaunchingWithOptions');
    expect(callback, greaterThan(0), reason: rule);
    expect(superCall, greaterThan(callback),
        reason: '$rule The launch that follows a notification tap can reach '
            'the delegate immediately, so the callback cannot be installed '
            'afterwards.');
  });

  test('the actions it serves are still declared as background actions', () {
    // If "Yes" and "No" were ever made foreground, iOS would open the app
    // instead and this callback would stop mattering — but the port would then
    // differ from Android, where they never open anything.
    final String tray =
        File('lib/platform/flutter_notification_tray.dart').readAsStringSync();
    // The definition, not the call site above it.
    final int options =
        tray.indexOf('static Set<DarwinNotificationActionOption> _optionsFor');
    expect(options, greaterThan(0), reason: rule);
    final String body = tray.substring(options, options + 400);
    expect(body, contains('DarwinNotificationActionOption.foreground'),
        reason: '$rule The distinction has to still be made somewhere.');
    // Only Enter and Later are foreground; everything else — Yes and No among
    // them — takes the empty option set and therefore the background engine.
    expect(body, contains('ReminderActions.edit'), reason: rule);
    expect(body, contains('ReminderActions.snoozeReminder'), reason: rule);
    expect(body, isNot(contains('ReminderActions.addCheckmark')),
        reason: '$rule Yes must not open the app; on Android it is a broadcast '
            'that writes the entry with no UI at all.');
    expect(body, isNot(contains('ReminderActions.removeCheckmark')),
        reason: '$rule …nor No.');
  });
}
