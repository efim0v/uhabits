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
import org.isoron.uhabits.widgets.views.FrequencyChartView
import org.isoron.uhabits.widgets.views.GraphWidgetView

/**
 * Port of `uhabits-android/.../widgets/FrequencyWidget.kt`.
 *
 * `widgets.frequency#1`: default 200x200 px, a GraphWidgetView wrapping a
 * FrequencyChart. `widgets.frequency#2`: the title is the habit name.
 */
class FrequencyWidget(
    context: Context,
    widgetId: Int,
    private val habit: HabitData,
    private val today: LocalDate,
    /**
     * `widgets.frequency#3`: `chart.setFirstWeekday(firstWeekday)` — the
     * weekday the seven rows start on, as `daysSinceSunday`. Published with the
     * document (`audit4.history-and-frequency-home-screen-widgets#1`).
     */
    private val firstWeekday: Int = WidgetDocument.DEFAULT_FIRST_WEEKDAY,
    /**
     * `widgets.stack#9`: true when this widget is one page of a StackWidget,
     * which forces it opaque (`widgets.card-chrome#5`).
     */
    stacked: Boolean = false
) : BaseWidget(context, widgetId, stacked) {

    override val defaultHeight: Int get() = 200
    override val defaultWidth: Int get() = 200

    /** `widgets.frequency#6`. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent =
        WidgetIntents.showHabit(context, id, habit)

    /** `widgets.frequency#3`. */
    override fun refreshData(widgetView: View) {
        (widgetView as GraphWidgetView).apply {
            setBackgroundAlpha(preferedBackgroundAlpha)
            // `widgets.card-chrome#6`: the shadow only at full opacity.
            if (preferedBackgroundAlpha >= 255) setShadowAlpha(0x4f)
            (dataView as FrequencyChartView).apply {
                this.today = this@FrequencyWidget.today
                this.firstWeekday = this@FrequencyWidget.firstWeekday
                color = WidgetTheme.color(habit.color)
                isNumerical = habit.isNumerical
                // `widgets.frequency#3`: the buckets are
                // `habit.originalEntries.computeWeekdayFrequency(...)` over the
                // habit's whole history, which the bridge publishes. The
                // fallback rebuilds them from the 60 published days — right
                // for the last two months and blind to everything before, and
                // reached only by a document that predates the field.
                frequency = habit.weekdayFrequency
                    ?: FrequencyChartView.computeWeekdayFrequency(habit, this@FrequencyWidget.today)
            }
        }
    }

    override fun buildView(): View = GraphWidgetView(context, FrequencyChartView(context)).apply {
        // Upstream sets the title here, not in refreshData, so the first
        // measuring pass already accounts for its height.
        setTitle(habit.name)
    }
}
