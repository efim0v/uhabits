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
 * ## Where the rows come from
 *
 * Upstream `refreshData` builds `TargetCardPresenter.buildState(habit,
 * firstWeekday = prefs.firstWeekdayInt, WidgetTheme())` and draws its three
 * parallel lists. That presenter needs three things this process does not have:
 * `habit.frequency.denominator`, which decides *which* rows exist
 * (`widgets.target#5`) and scales every target (`widgets.target#7`), and the
 * habit's whole history, over which the window sums are calendar-truncated
 * (`widgets.target#6`). So the bridge runs the same presenter and publishes its
 * rows (`audit4.target-widget-shows-the-wrong-rows`), and this class draws
 * them.
 *
 * [windowSum] and [windowTarget] remain as the fallback for a document written
 * before `targetRows` existed: all five rows, `dailyTarget` taken to be the
 * target value itself, and sums clamped to the 60 published days — so Quarter
 * and Year read low.
 */
class TargetWidget(
    context: Context,
    widgetId: Int,
    private val habit: HabitData,
    private val today: LocalDate,
    /**
     * `widgets.stack#9`: true when this widget is one page of a StackWidget,
     * which forces it opaque (`widgets.card-chrome#5`).
     */
    stacked: Boolean = false
) : BaseWidget(context, widgetId, stacked) {

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
                val rows = habit.targetRows
                if (rows != null) {
                    labels = rows.map { intervalToLabel(it.interval) }
                    values = rows.map { it.value }
                    targets = rows.map { it.target }
                } else {
                    labels = INTERVALS.map { intervalToLabel(it) }
                    values = INTERVALS.map { windowSum(it) }
                    targets = INTERVALS.map { windowTarget(it) }
                }
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
