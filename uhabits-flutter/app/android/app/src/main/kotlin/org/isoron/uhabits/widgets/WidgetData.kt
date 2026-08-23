/*
 * Copyright (C) 2016-2025 Álinson Santos Xavier <git@axavier.org>
 *
 * This file is part of Loop Habit Tracker.
 *
 * Loop Habit Tracker is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Loop Habit Tracker is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */
package org.isoron.uhabits.widgets

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.util.Calendar
import java.util.GregorianCalendar

/**
 * The launcher-side reader of the JSON `lib/platform/home_widget_bridge.dart`
 * publishes.
 *
 * This is what replaced `BaseWidgetProvider.updateDependencies` +
 * `getHabitsFromWidgetId`. Upstream a widget provider reached straight into
 * `HabitsApplication.component.habitList`, because the provider and the app were
 * the same Kotlin program. Here the app is Dart and the provider is Kotlin
 * running in the launcher's process, so the only thing they share is
 * `SharedPreferences("HomeWidgetPreferences")` — the store the `home_widget`
 * plugin writes through — and the versioned documents inside it.
 *
 * Everything below is read-only. A widget never writes habit data; see
 * [WidgetIntents] for what a tap does instead.
 */
object WidgetData {

    /**
     * `HomeWidgetPlugin.PREFERENCES`. Hard-coded rather than referenced so the
     * providers do not have to link the plugin's Kotlin sources.
     */
    private const val PREFERENCES = "HomeWidgetPreferences"

    /** `HomeWidgetBridge.keyPrefix`. */
    private const val KEY_PREFIX = "uhabits"

    /** `HomeWidgetBridge.indexKey`. */
    const val INDEX_KEY = "$KEY_PREFIX.index"

    /**
     * `HomeWidgetBridge.schemaVersion`.
     *
     * A widget can outlive an app update by as long as the user leaves it on the
     * home screen, so a document whose version this code does not know is
     * refused rather than guessed at — [UnknownSchemaException] surfaces as the
     * ordinary error widget.
     */
    const val SCHEMA_VERSION = 1

    /**
     * `HomeWidgetPlugin.deletedKey`.
     *
     * Where [recordDeleted] leaves the widget ids the launcher reported gone,
     * as a JSON array, for `HomeWidgetBridge.reapDeletedWidgets` to consume
     * (`audit4.deleting-a-widget-from-the-launcher#1`).
     *
     * It has to be a record rather than a call: `onDeleted` arrives in a
     * broadcast receiver that may well have started this process, long before
     * any Dart exists to be told. And the registry it corrects is written only
     * by the Flutter side — two writers, two processes, no lock — so this side
     * reports and the other side edits.
     */
    const val DELETED_KEY = "$KEY_PREFIX.deleted"

    /** `HomeWidgetBridge.documentKey`. */
    fun documentKey(widgetId: Int): String = "$KEY_PREFIX.widget.$widgetId"

    /**
     * Appends [ids] to [DELETED_KEY], preserving whatever is already recorded.
     *
     * The app may not run again for days, and every deletion in between has to
     * survive: overwriting would leave the registry bound to widgets that no
     * longer exist. Anything already there that is not a JSON array of ids is
     * a record this code cannot read, and it is dropped rather than guessed at
     * — the same call the Dart reader makes.
     */
    fun recordDeleted(storage: SharedPreferences, ids: IntArray): String {
        val array = JSONArray()
        try {
            val existing = JSONArray(storage.getString(DELETED_KEY, "[]") ?: "[]")
            for (i in 0 until existing.length()) array.put(existing.optInt(i))
        } catch (e: JSONException) {
            // Not ours, or truncated. The ids below are still worth recording.
        }
        for (id in ids) array.put(id)
        return array.toString()
    }

    fun storage(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    /**
     * Reads the document bound to [widgetId].
     *
     * @throws WidgetNotConfiguredException when the Flutter side has never
     *   published anything for this widget — the widget was placed but the
     *   habit picker has not run yet, or the app has not started since.
     * @throws UnknownSchemaException when the document is from a future
     *   schema.
     */
    fun readWidget(context: Context, widgetId: Int): WidgetDocument {
        val raw = storage(context).getString(documentKey(widgetId), null)
            ?: throw WidgetNotConfiguredException()
        val json = JSONObject(raw)
        val version = json.optInt("version", -1)
        if (version != SCHEMA_VERSION) throw UnknownSchemaException(version)
        return WidgetDocument.parse(json)
    }
}

/** A widget id with no published document. */
class WidgetNotConfiguredException : RuntimeException("widget not configured")

/** A document written by a newer (or older) schema than this code knows. */
class UnknownSchemaException(version: Int) :
    RuntimeException("unknown widget schema version: $version")

/**
 * Port of `org.isoron.uhabits.core.models.HabitNotFoundException`.
 *
 * `widgets.provider-lifecycle#9`: upstream `getHabitsFromWidgetId` throws this
 * when a stored habit id no longer resolves, and `widgets.provider-lifecycle#6`
 * turns it into the 'Habit deleted / not found' error widget. The bridge cannot
 * throw across a process boundary, so it publishes the ids it could not resolve
 * as `missingHabitIds` and this class is raised here instead — same cause, same
 * error widget.
 */
class HabitNotFoundException : RuntimeException("habit deleted / not found")

/** One `uhabits.widget.<id>` document. */
class WidgetDocument(
    val widgetId: Int,
    val today: LocalDate,
    val habits: List<HabitData>,
    val missingHabitIds: List<Long>,
    /**
     * `Preferences.widgetOpacity`, the `pref_widget_opacity` list preference
     * (`settings.preferences.widget-opacity#1`, `#3`).
     *
     * `BaseWidget.preferedBackgroundAlpha` turns it into the alpha the card's
     * background paint is drawn at, except inside a stack
     * (`settings.preferences.widget-opacity#5`, `#7`). Read defensively: a
     * document written before the field existed carries no key, and 255 —
     * `android:defaultValue` on the row — is what the preference itself
     * defaults to.
     */
    val widgetOpacity: Int = DEFAULT_WIDGET_OPACITY,
    /**
     * `Preferences.firstWeekday` as `daysSinceSunday` (0 = Sunday … 6 =
     * Saturday) — the weekday the History grid and the Frequency grid start on
     * (`widgets.history#4`, `widgets.frequency#3`).
     *
     * A preference, not a habit property, so it rides on the document rather
     * than on [HabitData]. Read defensively: a document written before the
     * field existed carries no key, and Sunday is what both charts default to.
     */
    val firstWeekday: Int = DEFAULT_FIRST_WEEKDAY
) {
    /**
     * `widgets.stack#1`: upstream returns a single-habit widget only when
     * exactly one habit is bound, and a StackWidget for 0 or 2+.
     *
     * The unresolved ids are checked first, because upstream's
     * `getHabitsFromWidgetId` resolves every id — throwing for the whole widget
     * if one is gone — before anything looks at how many there are.
     */
    fun isStack(): Boolean {
        if (missingHabitIds.isNotEmpty()) throw HabitNotFoundException()
        return habits.size != 1
    }

    /** The one habit of a non-stack widget. */
    fun singleHabit(): HabitData {
        if (missingHabitIds.isNotEmpty()) throw HabitNotFoundException()
        if (habits.size != 1) throw HabitNotFoundException()
        return habits[0]
    }

    companion object {
        /** `HomeWidgetBridge.defaultWidgetOpacity`. */
        const val DEFAULT_WIDGET_OPACITY = 255

        /** Sunday, the default of `HistoryChartView.firstWeekday`. */
        const val DEFAULT_FIRST_WEEKDAY = 0

        fun parse(json: JSONObject): WidgetDocument {
            val habits = json.optJSONArray("habits") ?: JSONArray()
            val missing = json.optJSONArray("missingHabitIds") ?: JSONArray()
            return WidgetDocument(
                widgetId = json.optInt("widgetId", -1),
                today = LocalDate.parse(json.optString("today")),
                habits = (0 until habits.length()).map {
                    HabitData.parse(habits.getJSONObject(it))
                },
                missingHabitIds = (0 until missing.length()).map { missing.getLong(it) },
                widgetOpacity = json.optInt("widgetOpacity", DEFAULT_WIDGET_OPACITY),
                firstWeekday = json.optInt("firstWeekday", DEFAULT_FIRST_WEEKDAY)
            )
        }
    }
}

/**
 * One habit inside a widget document.
 *
 * The fields below [entries] are the ones a widget *draws* and cannot compute:
 * the score algorithm needs the habit's whole history and its frequency, the
 * streak list needs every entry ever recorded, the frequency buckets are the
 * user's manual marks month by month, and the target rows are calendar
 * truncated sums whose row list depends on `frequency.denominator`. The bridge
 * derives all of them from the same presenters the detail screen uses and
 * publishes the result (`audit4.harness-blind-spots#2`).
 *
 * Every one is still read defensively — a widget can outlive an app update by
 * as long as the user leaves it on the home screen, so a document written by an
 * older build carries none of them and each widget names its fallback.
 */
class HabitData(
    val id: Long,
    val name: String,
    val question: String,
    val color: Int,
    val isNumerical: Boolean,
    val unit: String,
    val target: Double,
    val isAtMost: Boolean,
    val isArchived: Boolean,
    /** Today's entry value, i.e. `entries[0]`. */
    val value: Int,
    /**
     * Exactly `HomeWidgetBridge.entryCount` (60) daily values from
     * `computedEntries`, newest first: `entries[0]` is today,
     * `entries[59]` is 59 days ago.
     */
    val entries: IntArray,
    /**
     * Today's score, 0..1 — `habit.scores[today].value`, which
     * `widgets.checkmark#2` sets the ring percentage from.
     *
     * Null only in a document written before the field existed; the ring is
     * then drawn empty rather than guessed at.
     */
    val score: Double?,
    /**
     * The score series the Score widget plots, newest first, one entry per
     * bucket of [bucketSize] days (`widgets.score#5`, `#6`).
     */
    val scores: DoubleArray?,
    /**
     * Bucket size in days for [scores] — the interval the user last chose on
     * the detail screen (`widgets.score#3`, `#4`).
     */
    val bucketSize: Int,
    /**
     * The habit's best streaks, computed over its whole history
     * (`widgets.streak#3`). Ordered newest-ending first among the longest, i.e.
     * `StreakList.getBest`.
     *
     * [entries] only reaches back 60 days, so a widget that rebuilt these from
     * it would lose every older run; [StreakWidget] falls back to that only for
     * a document that predates the field.
     */
    val streaks: List<StreakData>?,
    /**
     * The Frequency chart's buckets: one 7-slot array per month, indexed by
     * `(dayOfWeek.daysSinceSunday + 1) % 7`, counted from the habit's ORIGINAL
     * entries over its whole history (`widgets.frequency#3`, `#4`, `#5`).
     */
    val weekdayFrequency: Map<LocalDate, IntArray>?,
    /**
     * The Target chart's rows: the windows this habit's frequency admits, each
     * with its calendar-truncated sum and its scaled, skip-reduced target
     * (`widgets.target#5`, `#6`, `#7`).
     */
    val targetRows: List<TargetRow>?
) {
    /** `habit.isCompletedToday()`; `widgets.checkmark#4`. */
    fun isCompletedToday(): Boolean =
        if (isAtMost) false else value / 1000.0 >= target

    companion object {
        fun parse(json: JSONObject): HabitData {
            val entriesJson = json.optJSONArray("entries") ?: JSONArray()
            val entries = IntArray(entriesJson.length()) { entriesJson.getInt(it) }
            val scoresJson = json.optJSONArray("scores")
            val streaksJson = json.optJSONArray("streaks")
            val frequencyJson = json.optJSONObject("weekdayFrequency")
            val targetRowsJson = json.optJSONArray("targetRows")
            return HabitData(
                id = json.optLong("id", -1L),
                name = json.optString("name"),
                question = json.optString("question"),
                color = json.optInt("color", 0),
                isNumerical = json.optString("type") == "NUMERICAL",
                unit = json.optString("unit"),
                target = json.optDouble("target", 0.0),
                isAtMost = json.optString("targetType") == "AT_MOST",
                isArchived = json.optBoolean("isArchived", false),
                value = if (json.has("value")) json.getInt("value") else Entry.UNKNOWN,
                entries = entries,
                score = if (json.has("score")) json.getDouble("score") else null,
                scores = scoresJson?.let { arr ->
                    DoubleArray(arr.length()) { arr.getDouble(it) }
                },
                bucketSize = json.optInt("bucketSize", 7),
                streaks = streaksJson?.let { arr ->
                    (0 until arr.length()).map { StreakData.parse(arr.getJSONObject(it)) }
                },
                weekdayFrequency = frequencyJson?.let { obj ->
                    val buckets = HashMap<LocalDate, IntArray>()
                    for (key in obj.keys()) {
                        val slots = obj.optJSONArray(key) ?: continue
                        buckets[LocalDate.parse(key)] =
                            IntArray(slots.length()) { slots.getInt(it) }
                    }
                    buckets
                },
                targetRows = targetRowsJson?.let { arr ->
                    (0 until arr.length()).map { TargetRow.parse(arr.getJSONObject(it)) }
                }
            )
        }
    }
}

/** One entry of the optional `streaks` array. */
class StreakData(val start: LocalDate, val end: LocalDate, val length: Int) {
    companion object {
        fun parse(json: JSONObject) = StreakData(
            start = LocalDate.parse(json.optString("start")),
            end = LocalDate.parse(json.optString("end")),
            length = json.optInt("length", 0)
        )
    }
}

/**
 * One row of the optional `targetRows` array: a window, what the habit has
 * accumulated in it, and what it should have (`widgets.target#4`, `#6`, `#7`).
 *
 * [interval] is the row's key rather than its length in days: 1 -> today, 7 ->
 * week, 30 -> month, 91 -> quarter, anything else -> year.
 */
class TargetRow(val interval: Int, val value: Double, val target: Double) {
    companion object {
        fun parse(json: JSONObject) = TargetRow(
            interval = json.optInt("interval", 0),
            value = json.optDouble("value", 0.0),
            target = json.optDouble("target", 0.0)
        )
    }
}

/** `org.isoron.uhabits.core.models.Entry`'s value constants. */
object Entry {
    const val UNKNOWN = -1
    const val NO = 0
    const val YES_AUTO = 1
    const val YES_MANUAL = 2
    const val SKIP = 3
}

/**
 * The sliver of `org.isoron.platform.time.LocalDate` the widgets need.
 *
 * A widget never asks the system what day it is: `widgets.checkmark#5` says
 * 'today' is the app-wide today, which already accounts for the midnight-delay
 * offset, and only the Flutter side knows that. So today is whatever the
 * document says it is, and every other date is derived from it.
 */
class LocalDate private constructor(private val millis: Long) : Comparable<LocalDate> {

    private val calendar: GregorianCalendar
        get() = GregorianCalendar(UTC).apply { timeInMillis = millis }

    val year: Int get() = calendar.get(Calendar.YEAR)

    /** 1..12, like the core's `LocalDate.month`. */
    val month: Int get() = calendar.get(Calendar.MONTH) + 1

    val day: Int get() = calendar.get(Calendar.DAY_OF_MONTH)

    /** 0 = Sunday, matching `DayOfWeek.daysSinceSunday`. */
    val daysSinceSunday: Int get() = calendar.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY

    fun plus(days: Int): LocalDate = LocalDate(millis + days * DAY_MILLIS)

    fun minus(days: Int): LocalDate = plus(-days)

    /** The first day of this date's month. */
    fun startOfMonth(): LocalDate = of(year, month, 1)

    fun plusMonths(months: Int): LocalDate {
        var y = year
        var m = month + months
        while (m < 1) {
            m += 12
            y -= 1
        }
        while (m > 12) {
            m -= 12
            y += 1
        }
        return of(y, m, 1)
    }

    /** Days from [other] to this date. */
    fun daysSince(other: LocalDate): Int = ((millis - other.millis) / DAY_MILLIS).toInt()

    /** Number of days in this date's month. */
    fun daysInMonth(): Int = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

    override fun compareTo(other: LocalDate): Int = millis.compareTo(other.millis)

    override fun equals(other: Any?): Boolean = other is LocalDate && other.millis == millis

    override fun hashCode(): Int = millis.hashCode()

    override fun toString(): String =
        "%04d-%02d-%02d".format(year, month, day)

    companion object {
        private const val DAY_MILLIS = 24L * 60 * 60 * 1000

        private val UTC = java.util.TimeZone.getTimeZone("GMT")

        fun of(year: Int, month: Int, day: Int): LocalDate {
            val cal = GregorianCalendar(UTC)
            cal.clear()
            cal.set(year, month - 1, day)
            return LocalDate(cal.timeInMillis)
        }

        /**
         * `HomeWidgetBridge.formatDate` read back: a plain ISO-8601 calendar
         * date. A malformed value falls back to the epoch rather than throwing,
         * because a date is never the interesting part of a broken document.
         */
        fun parse(text: String?): LocalDate {
            val parts = text?.split("-") ?: emptyList()
            if (parts.size != 3) return of(1970, 1, 1)
            val y = parts[0].toIntOrNull() ?: return of(1970, 1, 1)
            val m = parts[1].toIntOrNull() ?: return of(1970, 1, 1)
            val d = parts[2].toIntOrNull() ?: return of(1970, 1, 1)
            return of(y, m, d)
        }
    }
}
