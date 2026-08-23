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
import org.isoron.uhabits.widgets.views.GraphWidgetView
import org.isoron.uhabits.widgets.views.ScoreChartView

/**
 * Port of `uhabits-android/.../widgets/ScoreWidget.kt`.
 *
 * `widgets.score#1`: default 300x300 px — the largest of any widget.
 * `widgets.score#2`: the title is the habit name.
 *
 * `widgets.score#3`: the widget honours `scoreCardSpinnerPosition`, the bucket
 * the user last picked on the detail screen. The bridge builds the series with
 * `ScoreCardPresenter.buildState(habit, firstWeekday, spinnerPosition =
 * prefs.scoreCardSpinnerPosition, WidgetTheme())` — the same presenter the card
 * uses — and publishes the result with the bucket it was built at, so the two
 * can never disagree. A document from a build that predates those fields leaves
 * the chart empty at the preference's own default bucket of 7
 * (`widgets.score#4`).
 */
class ScoreWidget(
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

    override val defaultHeight: Int get() = 300
    override val defaultWidth: Int get() = 300

    /** `widgets.score#7`. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent =
        WidgetIntents.showHabit(context, id, habit)

    /** `widgets.score#5`. */
    override fun refreshData(widgetView: View) {
        (widgetView as GraphWidgetView).apply {
            setBackgroundAlpha(preferedBackgroundAlpha)
            if (preferedBackgroundAlpha >= 255) setShadowAlpha(0x4f)
            (dataView as ScoreChartView).apply {
                this.today = this@ScoreWidget.today
                color = WidgetTheme.color(habit.color)
                bucketSize = habit.bucketSize
                scores = habit.scores ?: DoubleArray(0)
            }
        }
    }

    override fun buildView(): View = GraphWidgetView(context, ScoreChartView(context)).apply {
        // Upstream sets the title here, not in refreshData, so the first
        // measuring pass already accounts for its height.
        setTitle(habit.name)
    }
}
