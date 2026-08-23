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
import org.isoron.uhabits.widgets.views.CheckmarkWidgetView

/**
 * Port of `uhabits-android/.../widgets/CheckmarkWidget.kt`.
 *
 * The only one of the six that both reads a value and writes one back, and the
 * only one whose behaviour the port had to change: see [WidgetIntents] for why
 * a tap now opens the app.
 */
class CheckmarkWidget(
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

    /** `widgets.checkmark#1`, `widgets.dimensions#5`. */
    override val defaultHeight: Int get() = 125
    override val defaultWidth: Int get() = 125

    /** `widgets.checkmark#6`, `#7`. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent = if (habit.isNumerical) {
        WidgetIntents.showNumberPicker(context, id, habit, today)
    } else {
        WidgetIntents.toggleCheckmark(context, id, habit)
    }

    /** `widgets.checkmark#2`: the order below is upstream's, exactly. */
    override fun refreshData(widgetView: View) {
        (widgetView as CheckmarkWidgetView).apply {
            setBackgroundAlpha(preferedBackgroundAlpha)
            activeColor = WidgetTheme.color(habit.color)
            name = habit.name
            // `widgets.checkmark#5`: 'today' is the app-wide today, which the
            // document carries; a widget must not ask the system for it, or the
            // midnight delay is lost.
            entryValue = habit.value
            if (habit.isNumerical) {
                // `widgets.checkmark#4`
                isNumerical = true
                entryState = if (habit.isCompletedToday()) Entry.YES_MANUAL else Entry.NO
            } else {
                // `widgets.checkmark#3`
                entryState = habit.value
            }
            // `widgets.checkmark#2`: percentage is habit.scores[today].value.
            // Not published; see HabitData.score. The ring reads empty until it
            // is.
            percentage = (habit.score ?: 0.0).toFloat()
            refresh()
        }
    }

    override fun buildView(): View = CheckmarkWidgetView(context)
}
