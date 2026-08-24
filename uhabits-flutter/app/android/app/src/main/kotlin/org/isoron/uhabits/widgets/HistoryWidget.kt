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
import org.isoron.uhabits.widgets.views.HistoryChartView

/**
 * Port of `uhabits-android/.../widgets/HistoryWidget.kt`.
 *
 * `widgets.history#1`: default 250x250 px, a GraphWidgetView wrapping the core
 * HistoryChart. `widgets.history#3`: the title is the habit name.
 *
 * Its series is published rather than derived from the entry window: the grid
 * sizes its columns from the widget's geometry and asks for up to 735 days,
 * where `entries` holds sixty, so everything past the ninth column was drawn as
 * a lapse (`audit10.history-home-screen-widget-draws-more#1`). Its origin is a
 * preference, and that has to be published too — see [firstWeekday].
 */
class HistoryWidget(
    context: Context,
    widgetId: Int,
    private val habit: HabitData,
    private val today: LocalDate,
    /**
     * `widgets.history#4`: `HistoryCardPresenter.buildState(habit, firstWeekday
     * = prefs.firstWeekday, …)` — the weekday the grid's rows start on, as
     * `daysSinceSunday`. It arrives on the document
     * (`audit4.history-and-frequency-home-screen-widgets#1`); a widget cannot
     * read the preference store, which lives in the app's process.
     */
    private val firstWeekday: Int = WidgetDocument.DEFAULT_FIRST_WEEKDAY,
    /**
     * `widgets.stack#9`: true when this widget is one page of a StackWidget,
     * which forces it opaque (`widgets.card-chrome#5`).
     */
    stacked: Boolean = false
) : BaseWidget(context, widgetId, stacked) {

    override val defaultHeight: Int get() = 250
    override val defaultWidth: Int get() = 250

    /** `widgets.history#5`. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent =
        WidgetIntents.showHabit(context, id, habit)

    /** `widgets.history#4`. */
    override fun refreshData(widgetView: View) {
        (widgetView as GraphWidgetView).apply {
            setBackgroundAlpha(preferedBackgroundAlpha)
            if (preferedBackgroundAlpha >= 255) setShadowAlpha(0x4f)
            (dataView as HistoryChartView).apply {
                this.today = this@HistoryWidget.today
                this.firstWeekday = this@HistoryWidget.firstWeekday
                paletteColor = habit.color
                series = HistoryChartView.seriesOf(habit)
                // `HistoryWidget.refreshData`'s third assignment upstream:
                // `historyChart.notesIndicators = model.notesIndicators`. The
                // presenter that computes it runs in the app's process, so the
                // flags arrive on the document next to the entries they index
                // (`audit6.history-home-screen-widget-never-draws#1`).
                notesIndicators = HistoryChartView.notesOf(habit)
                defaultSquare = HistoryChartView.Square.OFF
            }
        }
    }

    override fun buildView(): View = GraphWidgetView(context, HistoryChartView(context)).apply {
        // Upstream sets the title here, not in refreshData, so the first
        // measuring pass already accounts for its height.
        setTitle(habit.name)
    }
}
