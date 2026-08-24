import Flutter
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // "Yes" and "No" are background actions — they answer the reminder without
    // opening anything, which is what `WidgetReceiver` does on Android. iOS
    // answers them by spinning up a second Flutter engine, and the plugin
    // registers this app's plugins into that engine through this callback.
    //
    // Without it `FlutterEngineManager` calls a nil block. The `NSAssert` that
    // would have named the problem is compiled out of a release build, so what
    // the user sees instead is the process dying and the tap recording
    // nothing — on every "Yes" and every "No", from the lock screen or a
    // banner, running or not
    // (`audit20.ios-background-notification-actions-need-a-registrant#1`).
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    // …and the callback above is only reachable through this delegate. Every
    // notification interaction on iOS — the body tap, the foreground actions
    // ("Enter", "Later") and the background ones ("Yes", "No") — is dispatched
    // from `-userNotificationCenter:didReceiveNotificationResponse:`, which the
    // system calls on the notification centre's delegate and nowhere else.
    // `FlutterAppDelegate` implements it and forwards to the registered
    // plugins, but it does not put itself in that seat; the plugin's own setup
    // instructions are this line. Without it a reminder on iOS is a dead end:
    // the body tap opens the plain list, both answer buttons record nothing,
    // and a reminder that fires with the app open is never shown at all —
    // while Android does all five correctly, because there the OS delivers to
    // manifest-declared components and nothing has to be handed a delegate
    // (`audit21.ios-must-own-the-notification-centre-delegate#1`).
    UNUserNotificationCenter.current().delegate =
      self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
