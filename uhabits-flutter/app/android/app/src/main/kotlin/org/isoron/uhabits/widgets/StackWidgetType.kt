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
import org.isoron.uhabits.R

/**
 * Port of `uhabits-android/.../widgets/StackWidgetType.kt`.
 *
 * `widgets.stack#2`: the values are explicit and persisted — they travel in the
 * adapter Intent as `WIDGET_TYPE`, so renumbering them would silently repoint
 * every stack widget already on a home screen.
 */
enum class StackWidgetType(val value: Int) {
    CHECKMARK(0), FREQUENCY(1), SCORE(2), // habit strength widget
    HISTORY(3), STREAKS(4), TARGET(5);

    companion object {
        fun getWidgetTypeFromValue(value: Int): StackWidgetType? {
            return when (value) {
                CHECKMARK.value -> CHECKMARK
                FREQUENCY.value -> FREQUENCY
                SCORE.value -> SCORE
                HISTORY.value -> HISTORY
                STREAKS.value -> STREAKS
                TARGET.value -> TARGET
                else -> null
            }
        }

        /** `widgets.stack#3`. */
        fun getStackWidgetLayoutId(type: StackWidgetType?): Int {
            return when (type) {
                CHECKMARK -> R.layout.checkmark_stackview_widget
                FREQUENCY -> R.layout.frequency_stackview_widget
                SCORE -> R.layout.score_stackview_widget
                HISTORY -> R.layout.history_stackview_widget
                STREAKS -> R.layout.streak_stackview_widget
                TARGET -> R.layout.target_stackview_widget
                else -> throw IllegalStateException()
            }
        }

        /** `widgets.stack#7`: the StackView inside that layout. */
        fun getStackWidgetAdapterViewId(type: StackWidgetType?): Int {
            return when (type) {
                CHECKMARK -> R.id.checkmarkStackWidgetView
                FREQUENCY -> R.id.frequencyStackWidgetView
                SCORE -> R.id.scoreStackWidgetView
                HISTORY -> R.id.historyStackWidgetView
                STREAKS -> R.id.streakStackWidgetView
                TARGET -> R.id.targetStackWidgetView
                else -> throw IllegalStateException()
            }
        }

        /** `widgets.stack#7`, `widgets.error-states#4`: the empty label. */
        fun getStackWidgetEmptyViewId(type: StackWidgetType?): Int {
            return when (type) {
                CHECKMARK -> R.id.checkmarkStackWidgetEmptyView
                FREQUENCY -> R.id.frequencyStackWidgetEmptyView
                SCORE -> R.id.scoreStackWidgetEmptyView
                HISTORY -> R.id.historyStackWidgetEmptyView
                STREAKS -> R.id.streakStackWidgetEmptyView
                TARGET -> R.id.targetStackWidgetEmptyView
                else -> throw IllegalStateException()
            }
        }

        /**
         * `widgets.stack#10`: one template for the whole StackView, chosen from
         * the type and from whether the stack holds a numerical habit at all.
         *
         * The mixed case is why it cannot be per-item: a Checkmark stack that
         * contains one numerical habit opens the value picker for *every* page,
         * because a StackView carries a single template and only the fill-in
         * varies. Upstream's behaviour, reproduced.
         */
        fun getPendingIntentTemplate(
            context: Context,
            widgetType: StackWidgetType,
            habits: List<HabitData>
        ): PendingIntent {
            val containsNumerical = habits.any { it.isNumerical }
            return when (widgetType) {
                CHECKMARK -> if (containsNumerical) {
                    WidgetIntents.showNumberPickerTemplate(context)
                } else {
                    WidgetIntents.toggleCheckmarkTemplate(context)
                }
                FREQUENCY, SCORE, HISTORY, STREAKS, TARGET ->
                    WidgetIntents.showHabitTemplate(context)
            }
        }

        /** `widgets.stack-service#7`: the per-page half of the same choice. */
        fun getIntentFillIn(
            widgetId: Int,
            widgetType: StackWidgetType,
            habit: HabitData,
            allHabitsInStackWidget: List<HabitData>,
            today: LocalDate
        ): Intent {
            val containsNumerical = allHabitsInStackWidget.any { it.isNumerical }
            return when (widgetType) {
                CHECKMARK -> if (containsNumerical) {
                    WidgetIntents.showNumberPickerFillIn(widgetId, habit, today)
                } else {
                    WidgetIntents.toggleCheckmarkFillIn(widgetId, habit, today)
                }
                FREQUENCY, SCORE, HISTORY, STREAKS, TARGET ->
                    WidgetIntents.showHabitFillIn(widgetId, habit)
            }
        }
    }
}
