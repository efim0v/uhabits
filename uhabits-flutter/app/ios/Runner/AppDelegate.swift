import Flutter
import UIKit
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
