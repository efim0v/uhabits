package org.isoron.uhabits

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import org.json.JSONArray
import org.json.JSONObject

/**
 * Port of `ReminderReceiver`'s BOOT_COMPLETED branch
 * (uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderReceiver.kt),
 * whose whole body upstream is `reminderController.onBootCompleted()` —
 * `reminderScheduler.scheduleAll()`.
 *
 * ## What upstream re-arms, and what this has to imitate
 *
 * Android throws every `AlarmManager` alarm away across a reboot, so both apps
 * have to put them back. Upstream puts back *recomputed* alarms: `scheduleAll()`
 * goes through `ReminderScheduler.schedule()`, which takes each habit's reminder
 * through `DateUtils.getUpcomingTimeInMillis(hour, minute)` — an instant that is
 * in the future by construction — and `IntentScheduler.schedule` refuses
 * anything left over anyway:
 *
 * ```kotlin
 * if (timestamp < System.currentTimeMillis()) {
 *     log("Ignoring attempt to schedule intent in the past.")
 *     return
 * }
 * ```
 *
 * So a reminder whose instant passed while the phone was off is simply missed:
 * the user never sees it, and the next alarm is the next upcoming occurrence.
 *
 * This port has no fire-time hook — an alarm IS the finished notification, handed
 * to the OS by `zonedSchedule` — so the "re-arm everything that was armed" pass is
 * `flutter_local_notifications`' own
 * `ScheduledNotificationBootReceiver.rescheduleNotifications(context)`. That pass
 * re-arms every entry still in the plugin's cache (an entry leaves it only when
 * it actually fires) with its **original** `epochMilli`, and `AlarmManager`
 * delivers an alarm whose time has already passed immediately. Left to itself it
 * therefore posts the missed reminder the moment the phone finishes booting,
 * built from the spec frozen at schedule time: the `when` line shows an instant
 * that is already gone, and across a midnight boundary the payload writes
 * "Yes"/"No"/"Enter" to a day in the past.
 * (`audit12.boot-redelivers-an-elapsed-reminder#1`.)
 *
 * The app therefore owns the boot broadcast and spends it in two steps:
 *
 *  1. [dropElapsedAlarms] — `IntentScheduler.schedule`'s past-time refusal,
 *     moved to the one place it can still run. The Dart copy in
 *     `lib/platform/flutter_alarm_scheduler.dart` (`_schedule`) never sees a
 *     reboot, because no Dart runs at boot.
 *  2. the plugin's own receiver, which re-arms everything that is left — i.e.
 *     every reminder that is still due, exactly as before.
 *
 * A dropped entry is gone for good, which is what upstream's missed reminder is;
 * the chain resumes at the next `scheduleAll()`, which `AppScope.boot()` runs at
 * every app start and `ReminderScheduler.onCommandFinished` after every command.
 */
class ReminderBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (!BOOT_ACTIONS.contains(action)) return
        dropElapsedAlarms(context, System.currentTimeMillis())
        // The plugin's receiver is not declared in the manifest — it is reached
        // here by name, after the cache it reads has been filtered.
        ScheduledNotificationBootReceiver().onReceive(context, intent)
    }

    companion object {
        /**
         * The actions `ScheduledNotificationBootReceiver` answers. Upstream's
         * filter is BOOT_COMPLETED alone; the three others are here for the
         * same reason the plugin honours them — the alarms are lost on an app
         * update and on a quick-boot resume as well as on a cold reboot.
         */
        val BOOT_ACTIONS: Set<String> = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON"
        )

        /**
         * `FlutterLocalNotificationsPlugin.SCHEDULED_NOTIFICATIONS`, which the
         * plugin uses both as the SharedPreferences file name and as the key
         * inside it. The value is one JSON array of `NotificationDetails`.
         */
        const val SCHEDULED_NOTIFICATIONS = "scheduled_notifications"

        /**
         * Removes every one-shot alarm whose instant is already behind [now].
         *
         * Nothing is written back unless something was actually dropped, so a
         * boot with no missed reminder leaves the plugin's cache byte for byte
         * as it was.
         */
        fun dropElapsedAlarms(context: Context, now: Long) {
            val preferences = context.getSharedPreferences(
                SCHEDULED_NOTIFICATIONS,
                Context.MODE_PRIVATE
            )
            val stored = preferences.getString(SCHEDULED_NOTIFICATIONS, null)
                ?: return
            val entries = try {
                JSONArray(stored)
            } catch (error: RuntimeException) {
                // Not something this app wrote; leave it to the plugin.
                return
            }
            val kept = JSONArray()
            var elapsed = 0
            for (index in 0 until entries.length()) {
                val entry = entries.optJSONObject(index)
                if (entry == null) {
                    kept.put(entries.opt(index))
                    continue
                }
                val fireTime = fireTimeOf(entry)
                // Strictly less-than, as IntentScheduler.schedule: an alarm due
                // exactly now is still armed.
                if (fireTime != null && fireTime < now) {
                    elapsed++
                    continue
                }
                kept.put(entry)
            }
            if (elapsed == 0) return
            preferences.edit()
                .putString(SCHEDULED_NOTIFICATIONS, kept.toString())
                .apply()
        }

        /**
         * The instant one cached entry is armed for, or null when it is not a
         * one-shot alarm and therefore cannot have elapsed.
         *
         * The two shapes are the plugin's own: `zonedScheduleNotification`
         * rebuilds the instant out of `scheduledDateTime` + `timeZoneName`
         * (which is what this app always schedules with — see
         * `LocalNotificationsAlarmPlugin.scheduleExact`), and the deprecated
         * `scheduleNotification` uses `millisecondsSinceEpoch`.
         */
        fun fireTimeOf(entry: JSONObject): Long? {
            // A repeating alarm always has a next occurrence; only a one-shot
            // can be left behind by a reboot.
            for (field in REPEATING_FIELDS) {
                if (!entry.isNull(field)) return null
            }
            val zone = entry.optString("timeZoneName", "")
            val scheduledDateTime = entry.optString("scheduledDateTime", "")
            if (zone.isNotEmpty() && scheduledDateTime.isNotEmpty()) {
                return try {
                    ZonedDateTime.of(
                        LocalDateTime.parse(scheduledDateTime),
                        ZoneId.of(zone)
                    ).toInstant().toEpochMilli()
                } catch (error: RuntimeException) {
                    null
                }
            }
            if (entry.isNull("millisecondsSinceEpoch")) return null
            return entry.optLong("millisecondsSinceEpoch")
        }

        private val REPEATING_FIELDS = listOf(
            "repeatInterval",
            "repeatIntervalMilliseconds",
            "matchDateTimeComponents",
            "scheduledNotificationRepeatFrequency"
        )
    }
}
