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
import android.view.View
import android.view.ViewGroup
import org.isoron.uhabits.widgets.views.GraphWidgetView
import org.isoron.uhabits.widgets.views.TargetChartView
import kotlin.math.max
import kotlin.math.min

/**
 * Port of `uhabits-android/.../widgets/TargetWidget.kt`.
 *
 * `widgets.target#1`: default 200x200 px, a GraphWidgetView wrapping a
 * TargetChart with MATCH_PARENT x MATCH_PARENT. `widgets.target#2`: the title is
 * the habit name. `widgets.target#8`: the configure activity is
 * NumericalHabitPickerDialog, so a boolean habit can never reach this widget.
 *
 * ## What the contract cannot supply
 *
 * `widgets.target#5` makes the row list depend on `habit.frequency.denominator`:
 * 'Today' only for a daily habit, 'Week' only for a habit at most weekly, and
 * Month/Quarter/Year always. The frequency is not in the published document, so
 * the denominator is assumed to be 1 and all five rows are drawn — a weekly
 * habit shows a 'Today' row it should not have.
 *
 * `widgets.target#7` reduces each target by `dailyTarget * skippedDays`, where
 * `dailyTarget = targetValue / frequency.denominator`. Same missing field: the
 * daily target is taken to be the target value itself.
 *
 * The window sums (`widgets.target#6`) come out of the 60 published days, so
 * Today, Week and Month are right and Quarter and Year are truncated at 60 days.
 * The bars for those two therefore read low.
 */
class TargetWidget(
    context: Context,
    widgetId: Int,
    private val habit: HabitData,
    private val today: LocalDate
) : BaseWidget(context, widgetId) {

    override val defaultHeight: Int get() = 200
    override val defaultWidth: Int get() = 200

    /** `widgets.target#9`. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent =
        WidgetIntents.showHabit(context, id, habit)

    /** `widgets.target#3`. */
    override fun refreshData(widgetView: View) {
        (widgetView as GraphWidgetView).apply {
            setBackgroundAlpha(preferedBackgroundAlpha)
            if (preferedBackgroundAlpha >= 255) setShadowAlpha(0x4f)
            (dataView as TargetChartView).apply {
                color = WidgetTheme.color(habit.color)
                labels = INTERVALS.map { intervalToLabel(it) }
                values = INTERVALS.map { windowSum(it) }
                targets = INTERVALS.map { windowTarget(it) }
            }
        }
    }

    override fun buildView(): View {
        val chart = TargetChartView(context)
        val view = GraphWidgetView(context, chart)
        // Upstream sets the title here, not in refreshData.
        view.setTitle(habit.name)
        view.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        return view
    }

    /** `widgets.target#6`: grouped sums divided by 1000, milli-units to units. */
    private fun windowSum(interval: Int): Double {
        val days = min(interval, habit.entries.size)
        var total = 0L
        for (i in 0 until days) {
            val value = habit.entries[i]
            if (value > 0) total += value
        }
        return total / 1e3
    }

    /**
     * `widgets.target#7`, with `dailyTarget = habit.target` because the
     * frequency denominator is not published (see the class KDoc).
     */
    private fun windowTarget(interval: Int): Double {
        val skipped = (0 until min(interval, habit.entries.size))
            .count { habit.entries[it] == Entry.SKIP }
        return max(0.0, habit.target * interval - habit.target * skipped)
    }

    companion object {
        /**
         * `widgets.target#4`: 1 -> today, 7 -> week, 30 -> month, 91 ->
         * quarter, anything else -> year.
         */
        private val INTERVALS = listOf(1, 7, 30, 91, 365)

        private fun intervalToLabel(interval: Int) = when (interval) {
            1 -> "Today"
            7 -> "Week"
            30 -> "Month"
            91 -> "Quarter"
            else -> "Year"
        }
    }
}
