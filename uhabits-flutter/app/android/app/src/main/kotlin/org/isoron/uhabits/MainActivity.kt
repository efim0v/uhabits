package org.isoron.uhabits

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Port of the one thing `SettingsFragment` does that no Flutter package
 * exposes: opening the system's notification-channel screen for the reminders
 * channel.
 *
 * Upstream (`notifications.channel#3`):
 *
 * ```kotlin
 * AndroidNotificationTray.createAndroidNotificationChannel(context)
 * val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
 *     .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
 *     .putExtra(Settings.EXTRA_CHANNEL_ID, NotificationTray.REMINDERS_CHANNEL_ID)
 * startActivity(intent)
 * ```
 *
 * The channel is created on the Dart side, through
 * `flutter_local_notifications`, immediately before this method is invoked —
 * see `PlatformNotificationChannelSettings.openReminderChannelSettings`. The
 * channel id therefore arrives as an argument rather than being duplicated
 * here, while `EXTRA_APP_PACKAGE` is supplied by the activity, which is the
 * only side that knows its own package name.
 *
 * `startActivitySafely`'s catch is the `false` return: a device with no
 * notification-settings activity gets a message, not a crash.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_OPEN_CHANNEL_SETTINGS -> {
                    val channelId = call.argument<String>(ARG_CHANNEL_ID)
                    result.success(openChannelSettings(channelId))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openChannelSettings(channelId: String?): Boolean {
        if (channelId == null) return false
        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    companion object {
        const val METHOD_CHANNEL_NAME = "org.isoron.uhabits/notifications"
        const val METHOD_OPEN_CHANNEL_SETTINGS = "openChannelSettings"
        const val ARG_CHANNEL_ID = "channelId"
    }
}
