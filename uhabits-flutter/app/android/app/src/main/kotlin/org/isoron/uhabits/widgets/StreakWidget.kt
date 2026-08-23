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
import org.isoron.uhabits.widgets.views.StreakChartView

/**
 * Port of `uhabits-android/.../widgets/StreakWidget.kt`.
 *
 * `widgets.streak#1`: default 200x200 px, a GraphWidgetView wrapping a
 * StreakChart, given MATCH_PARENT x MATCH_PARENT. `widgets.streak#2`: the title
 * is the habit name. `widgets.streak#5`: the configure activity is
 * BooleanHabitPickerDialog, so a numerical habit can never reach this widget.
 */
class StreakWidget(
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

    /** `widgets.streak#6`. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent =
        WidgetIntents.showHabit(context, id, habit)

    /** `widgets.streak#3`, `#4`: maxStreakCount is read after measuring. */
    override fun refreshData(widgetView: View) {
        (widgetView as GraphWidgetView).apply {
            setBackgroundAlpha(preferedBackgroundAlpha)
            if (preferedBackgroundAlpha >= 255) setShadowAlpha(0x4f)
            (dataView as StreakChartView).apply {
                color = WidgetTheme.color(habit.color)
                streaks = habit.streaks?.take(maxStreakCount)
                    ?: StreakChartView.streaksFrom(habit, today, maxStreakCount)
            }
        }
    }

    override fun buildView(): View {
        val chart = StreakChartView(context)
        val view = GraphWidgetView(context, chart)
        // Upstream sets the title here, not in refreshData.
        view.setTitle(habit.name)
        view.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        return view
    }
}
