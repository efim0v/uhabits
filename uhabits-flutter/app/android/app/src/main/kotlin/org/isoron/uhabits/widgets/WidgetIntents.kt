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

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.isoron.uhabits.MainActivity

/**
 * Port of the widget half of `org.isoron.uhabits.intents.PendingIntentFactory`.
 *
 * ## Why every tap opens the app
 *
 * Upstream, tapping a boolean Checkmark widget broadcasts to `WidgetReceiver`,
 * which runs `WidgetBehavior.onToggleRepetition` inside the app process without
 * showing anything (`widgets.checkmark#6`). That receiver is gone: the toggle it
 * runs is `CreateRepetitionCommand` on the `CommandRunner`, which in this port is
 * Dart, and a broadcast receiver in the launcher's process cannot execute Dart.
 *
 * The brief offered two ways out — stage the change in shared storage and
 * reconcile at next launch, or launch the app with the toggle intent. This is
 * the second. The reasons, in order:
 *
 *  1. **One writer.** `widgets.behavior#7` and `#8` require every widget tap to
 *     end in `CreateRepetitionCommand(habitList, habit, date, value, notes)` run
 *     *through the CommandRunner*, because that is what notifies the list cache,
 *     the reminder scheduler and the widget updater, and what makes the change
 *     undoable. A staged toggle bypasses all of that until reconcile time, and
 *     for the length of that window the widget, the notification and the list
 *     screen disagree about what the entry is.
 *  2. **`nextToggleValue` needs preferences.** `widgets.behavior#3` computes the
 *     next value from `isSkipEnabled` and `areQuestionMarksEnabled`. Neither is
 *     in the published document, so a staged toggle would have to guess the
 *     cycle — and `widgets.checkmark#9`'s YES_MANUAL -> SKIP -> NO would come out
 *     wrong for anyone with skip disabled.
 *  3. **No new contract.** `HomeWidgetLaunchIntent` is delivered to Dart by the
 *     `home_widget` plugin itself, through `HomeWidget.widgetClicked` and
 *     `HomeWidget.initiallyLaunchedFromHomeWidget()`. A staging queue would need
 *     a second shared-storage contract, invented here, that the Dart side would
 *     have to learn to drain — and drain idempotently, since a reconcile that
 *     runs twice must not toggle twice.
 *
 * ## What it costs
 *
 * A boolean Checkmark tap now brings the app to the foreground, where upstream
 * toggled in place. That is the one visible regression, and it is not a small
 * one: the widget's whole point is toggling without opening anything.
 * `widgets.checkmark#6` is therefore reported as unmet. Everything else lands on
 * the upstream behaviour or better: numerical Checkmark taps already opened the
 * app upstream (`widgets.checkmark#7`), and the five graph widgets already
 * opened `ShowHabitActivity` (`widgets.frequency#6`, `widgets.history#5`,
 * `widgets.score#7`, `widgets.streak#6`, `widgets.target#9`).
 *
 * ## The URIs
 *
 * All four carry their arguments in the URI, never in extras: the plugin hands
 * Dart the intent's `data` and nothing else, and `FLAG_IMMUTABLE` means the
 * launcher could not add extras anyway.
 *
 * ```
 * uhabits://widget/toggle?habit=<id>&widgetId=<n>
 * uhabits://widget/edit?habit=<id>&widgetId=<n>&date=<yyyy-MM-dd>
 * uhabits://widget/show?habit=<id>&widgetId=<n>
 * uhabits://widget/configure?widgetId=<n>&filter=<all|boolean|numerical>
 * ```
 *
 * The Dart side is expected to route them like this:
 *
 *  - `toggle` -> `WidgetBehavior.onToggleRepetition(habit, today)`
 *    (`widgets.behavior#3`). No date: `widgets.checkmark#6` sends no timestamp
 *    either, so the receiver defaults to today.
 *  - `edit` -> `ListHabitsBehavior.onEdit(habit, date)`, the numeric value
 *    picker (`widgets.checkmark#7`, `widgets.checkmark#8`). The date is the
 *    document's `today`, which is the app-wide today including the midnight
 *    delay — a widget must not compute that itself.
 *  - `show` -> the habit detail screen.
 *  - `configure` -> the habit picker for a freshly placed widget; on confirm,
 *    `WidgetRegistry.addWidget(widgetId, [habitId])` then a publish
 *    (`widgets.config-picker#10`). `filter` carries the boolean/numerical
 *    restriction of `widgets.config-picker#4` and `#5`.
 */
object WidgetIntents {

    const val SCHEME = "uhabits"
    const val AUTHORITY = "widget"

    const val ACTION_TOGGLE = "toggle"
    const val ACTION_EDIT = "edit"
    const val ACTION_SHOW = "show"
    const val ACTION_CONFIGURE = "configure"

    const val FILTER_ALL = "all"
    const val FILTER_BOOLEAN = "boolean"
    const val FILTER_NUMERICAL = "numerical"

    /**
     * `widgets.checkmark#6`, as close as a Dart app allows: the boolean
     * Checkmark tap. No date argument, so the app toggles today.
     */
    fun toggleCheckmark(context: Context, widgetId: Int, habit: HabitData): PendingIntent =
        activity(context, uri(ACTION_TOGGLE, widgetId) { it.appendQueryParameter("habit", habit.id.toString()) })

    /**
     * `widgets.checkmark#7`: the numerical Checkmark tap opens the value picker
     * for today.
     */
    fun showNumberPicker(
        context: Context,
        widgetId: Int,
        habit: HabitData,
        today: LocalDate
    ): PendingIntent = activity(
        context,
        uri(ACTION_EDIT, widgetId) {
            it.appendQueryParameter("habit", habit.id.toString())
            it.appendQueryParameter("date", today.toString())
        }
    )

    /**
     * `widgets.frequency#6`, `widgets.history#5`, `widgets.score#7`,
     * `widgets.streak#6`, `widgets.target#9`: the five graph widgets open the
     * habit detail screen.
     *
     * Upstream builds this with a `TaskStackBuilder` so that Back from the
     * detail screen lands on the habit list. Flutter runs one activity, so the
     * synthetic back stack becomes the app's own route stack — the app pushes
     * the detail route on top of the list.
     */
    fun showHabit(context: Context, widgetId: Int, habit: HabitData): PendingIntent =
        activity(context, uri(ACTION_SHOW, widgetId) { it.appendQueryParameter("habit", habit.id.toString()) })

    /** The deep link `HabitPickerDialog` hands to the Flutter picker. */
    fun configureUri(widgetId: Int, filter: String): Uri =
        uri(ACTION_CONFIGURE, widgetId) { it.appendQueryParameter("filter", filter) }

    // -----------------------------------------------------------------------
    // Stack widget templates and fill-ins
    // -----------------------------------------------------------------------
    //
    // A StackView cannot carry one PendingIntent per page: it carries a single
    // *template*, and each page contributes a fill-in Intent that is merged
    // into it when the user taps. That is why the templates below are mutable
    // (`widgets.stack#11`) and why the fill-ins carry only data
    // (`widgets.stack-service#8`) — `Intent.fillIn` copies the data across
    // precisely because the template has none of its own.
    //
    // The request codes are upstream's: 0 for the habit screen, 1 for the value
    // picker, 2 for the toggle. Upstream needed them because its three
    // templates pointed at three different components; here they all point at
    // MainActivity, so the codes are the only thing keeping the three
    // PendingIntents distinct — which the launcher relies on when a home screen
    // holds several stacks of different types.

    /** `widgets.stack#10`: the template for the five graph stacks. */
    fun showHabitTemplate(context: Context): PendingIntent = template(context, 0)

    /** `widgets.stack#10`: the template for a Checkmark stack with a numerical habit. */
    fun showNumberPickerTemplate(context: Context): PendingIntent = template(context, 1)

    /** `widgets.stack#10`: the template for an all-boolean Checkmark stack. */
    fun toggleCheckmarkTemplate(context: Context): PendingIntent = template(context, 2)

    /** `widgets.stack-service#8`: `showHabitFillIn(habit)`. */
    fun showHabitFillIn(widgetId: Int, habit: HabitData): Intent =
        fillIn(uri(ACTION_SHOW, widgetId) { it.appendQueryParameter("habit", habit.id.toString()) })

    /** `widgets.stack-service#8`: `toggleCheckmarkFillIn(habit, date)`. */
    fun toggleCheckmarkFillIn(widgetId: Int, habit: HabitData, date: LocalDate): Intent =
        fillIn(
            uri(ACTION_TOGGLE, widgetId) {
                it.appendQueryParameter("habit", habit.id.toString())
                it.appendQueryParameter("date", date.toString())
            }
        )

    /** `widgets.stack-service#8`: `showNumberPickerFillIn(habit, date)`. */
    fun showNumberPickerFillIn(widgetId: Int, habit: HabitData, date: LocalDate): Intent =
        fillIn(
            uri(ACTION_EDIT, widgetId) {
                it.appendQueryParameter("habit", habit.id.toString())
                it.appendQueryParameter("date", date.toString())
            }
        )

    private fun fillIn(uri: Uri): Intent = Intent().apply { data = uri }

    /**
     * The bare, argument-less counterpart of [activity]: everything that
     * identifies the tap arrives later, in the fill-in.
     */
    private fun template(context: Context, requestCode: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            requestCode,
            Intent(context, MainActivity::class.java).apply {
                action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
            },
            intentTemplateFlags()
        )

    /**
     * `widgets.stack#11`, and `PendingIntentFactory.getIntentTemplateFlags()`
     * verbatim: mutable from API 31, plain 0 below it.
     *
     * A template that is not mutable cannot have anything filled into it, so
     * every page of a stack would open the same habit.
     */
    private fun intentTemplateFlags(): Int {
        var flags = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return flags
    }

    private fun uri(action: String, widgetId: Int, build: (Uri.Builder) -> Unit): Uri {
        val builder = Uri.Builder()
            .scheme(SCHEME)
            .authority(AUTHORITY)
            .appendPath(action)
            .appendQueryParameter("widgetId", widgetId.toString())
        build(builder)
        return builder.build()
    }

    /**
     * `HomeWidgetLaunchIntent.getActivity` stamps the intent with the plugin's
     * own launch action, which is the only thing that makes the plugin deliver
     * the URI to Dart, and applies `FLAG_IMMUTABLE or FLAG_UPDATE_CURRENT` —
     * the same flags `widgets.checkmark#6` and `#7` specify.
     *
     * Every widget shares request code 0, which upstream did not: it used
     * `(habit.id % Integer.MAX_VALUE) + 1` for the number picker. It does not
     * matter here because `PendingIntent` also keys on the intent's data, and
     * every URI above is distinct per habit, per widget and per action.
     */
    private fun activity(context: Context, uri: Uri): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
}
