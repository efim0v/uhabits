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

    /** `HomeWidgetBridge.documentKey`. */
    fun documentKey(widgetId: Int): String = "$KEY_PREFIX.widget.$widgetId"

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
    val missingHabitIds: List<Long>
) {
    /**
     * `widgets.stack#1` inverted: upstream returns a single-habit widget only
     * when exactly one habit is bound, and a StackWidget otherwise. Stack
     * widgets are not reproduced (upstream removed the option to create new
     * ones), so a document that resolves to anything but one habit is an error.
     */
    fun singleHabit(): HabitData {
        if (missingHabitIds.isNotEmpty()) throw HabitNotFoundException()
        if (habits.size != 1) throw HabitNotFoundException()
        return habits[0]
    }

    companion object {
        fun parse(json: JSONObject): WidgetDocument {
            val habits = json.optJSONArray("habits") ?: JSONArray()
            val missing = json.optJSONArray("missingHabitIds") ?: JSONArray()
            return WidgetDocument(
                widgetId = json.optInt("widgetId", -1),
                today = LocalDate.parse(json.optString("today")),
                habits = (0 until habits.length()).map {
                    HabitData.parse(habits.getJSONObject(it))
                },
                missingHabitIds = (0 until missing.length()).map { missing.getLong(it) }
            )
        }
    }
}

/**
 * One habit inside a widget document.
 *
 * The optional fields at the bottom are the ones a faithful render needs and the
 * v1 contract does not carry; see the KDoc on each. They are read defensively so
 * that the day the bridge starts publishing them, these widgets pick them up
 * without a native change.
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
     * NOT in schema v1. Scores cannot be recomputed here: the algorithm needs
     * the habit's whole history and its frequency, and the contract carries
     * neither. Absent, the ring is drawn empty.
     */
    val score: Double?,
    /**
     * The score series the Score widget plots, newest first, one entry per
     * bucket of `bucketSize` days.
     *
     * NOT in schema v1, and not derivable from [entries] for the same reason as
     * [score].
     */
    val scores: DoubleArray?,
    /** Bucket size in days for [scores]; `widgets.score#4`. */
    val bucketSize: Int,
    /**
     * Streak lengths, longest first — `habit.streaks.getBest(n)`.
     *
     * NOT in schema v1. [entries] only reaches back 60 days, so streaks derived
     * from it are truncated; [StreakWidget] falls back to that and says so.
     */
    val streaks: List<StreakData>?
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
