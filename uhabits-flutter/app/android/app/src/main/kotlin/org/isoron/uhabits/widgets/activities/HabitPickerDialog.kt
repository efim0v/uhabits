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
package org.isoron.uhabits.widgets.activities

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.TextView
import org.isoron.uhabits.MainActivity
import org.isoron.uhabits.R
import org.isoron.uhabits.widgets.WidgetData
import org.isoron.uhabits.widgets.WidgetIntents

/**
 * The widget's `APPWIDGET_CONFIGURE` activity.
 *
 * ## Why this is a hand-off and not a list
 *
 * Upstream this activity *is* the picker: it walks `habitList`, filters it and
 * shows a `ListView` of names (`widgets.config-picker#3`, `#8`, `#9`). It cannot
 * do that here. The habit catalogue is not part of what
 * `lib/platform/home_widget_bridge.dart` publishes — the contract carries one
 * document per *already configured* widget and an index of them, and nothing
 * that enumerates habits. A native picker would need a second source of habit
 * data in the launcher's process, which means either a second copy of the
 * catalogue in shared storage or a Kotlin reader of the app's SQLite file. The
 * first is the bridge's call to make, not this slice's; the second puts a second
 * reader on a schema Dart owns.
 *
 * So the picker lives on the Flutter side, where the habit list already is, and
 * this activity does the two things only an Android `Activity` can do: capture
 * the widget id the launcher assigned, and report the outcome back to it.
 *
 * ## The result protocol
 *
 * `widgets.config-picker#10` and `#11` are the contract that matters: confirming
 * must return RESULT_OK with EXTRA_APPWIDGET_ID, and backing out must leave
 * RESULT_CANCELED so the launcher drops the placement.
 *
 * Both are preserved without inventing a channel back from Flutter. The activity
 * launches the picker deep link and waits. When the user returns, it asks the
 * one question that settles it: does a document exist for this widget id? The
 * Flutter picker's confirm step is `WidgetRegistry.addWidget(widgetId, ids)`
 * followed by a publish, and publishing writes `uhabits.widget.<id>`. A document
 * present means the user picked; absent means they backed out.
 */
open class HabitPickerDialog : Activity() {

    private var widgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    private var launched = false

    /** `widgets.config-picker#3`: which habits the picker may offer. */
    protected open val filter: String get() = WidgetIntents.FILTER_ALL

    /**
     * `widgets.config-picker#6`: what to show when the filter leaves nothing.
     *
     * Deliberately unused here — only the Flutter picker knows whether the
     * filter emptied the list, and `widgets.config-picker#7` says that screen
     * must return without a result, which is already this activity's default.
     * The three strings live here because they belong to the three configure
     * activities, and the picker should render the one for the `filter` it was
     * handed.
     */
    protected open val emptyMessage: String get() = "No habits found"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // `widgets.config-picker#1`: the widget id comes from the extras, and an
        // intent with no extras at all leaves it at 0.
        widgetId = intent.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: 0

        // `widgets.config-picker#11`: cancelled unless something says otherwise.
        setResult(RESULT_CANCELED)

        setContentView(R.layout.widget_configure_activity)
        // `audit.android-widget-chrome-text-is-hard#1`: a string resource, not a
        // Kotlin literal, so this activity — which the launcher starts before
        // any Dart runs — speaks the device language like every other piece of
        // widget chrome. See app/test/platform/widget_strings_test.dart.
        findViewById<TextView>(R.id.label).text =
            getString(R.string.widget_picker_prompt)

        launched = savedInstanceState?.getBoolean(STATE_LAUNCHED) ?: false

        // Launchers recycle widget ids. If this id was used before and the Dart
        // registry still remembers it, a stale document would read as a
        // confirmation the user never gave, so clear it before asking.
        if (!launched) {
            WidgetData.storage(this).edit().remove(WidgetData.documentKey(widgetId)).apply()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(STATE_LAUNCHED, launched)
    }

    override fun onResume() {
        super.onResume()
        if (!launched) {
            launched = true
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = LAUNCH_ACTION
                    data = WidgetIntents.configureUri(widgetId, filter)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
            return
        }
        // Back from the picker. `widgets.config-picker#10`: a published document
        // is the confirmation.
        if (isConfigured()) {
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            )
        }
        finish()
    }

    private fun isConfigured(): Boolean =
        WidgetData.storage(this).contains(WidgetData.documentKey(widgetId))

    companion object {
        private const val STATE_LAUNCHED = "launched"

        /**
         * `HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION`, spelled out rather
         * than referenced: this intent is built by hand (the plugin's helper
         * only builds PendingIntents) and the string is what makes the plugin
         * hand the URI to Dart.
         */
        private const val LAUNCH_ACTION = "es.antonborri.home_widget.action.LAUNCH"
    }
}

/**
 * `widgets.config-picker#4`: the Streaks widget's picker hides numerical habits,
 * and says 'No yes-or-no habits found' when none are left.
 */
class BooleanHabitPickerDialog : HabitPickerDialog() {
    override val filter: String get() = WidgetIntents.FILTER_BOOLEAN
    override val emptyMessage: String get() = "No yes-or-no habits found"
}

/**
 * `widgets.config-picker#5`: the Target widget's picker hides boolean habits,
 * and says 'No measurable habits found' when none are left.
 */
class NumericalHabitPickerDialog : HabitPickerDialog() {
    override val filter: String get() = WidgetIntents.FILTER_NUMERICAL
    override val emptyMessage: String get() = "No measurable habits found"
}
