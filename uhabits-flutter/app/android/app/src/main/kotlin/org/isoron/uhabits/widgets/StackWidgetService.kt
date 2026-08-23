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

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Looper
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.widget.RemoteViewsService.RemoteViewsFactory
import org.isoron.uhabits.R

/**
 * Port of `uhabits-android/.../widgets/StackWidgetService.kt`.
 *
 * The launcher binds this service to fill a [StackWidget]'s `StackView`, one
 * page per habit. `widgets.registration#7`: it is declared non-exported and
 * guarded by BIND_REMOTEVIEWS, so only the system can reach it.
 */
class StackWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return StackRemoteViewsFactory(this.applicationContext, intent)
    }

    companion object {
        const val WIDGET_TYPE = "WIDGET_TYPE"
        const val HABIT_IDS = "HABIT_IDS"
    }
}

/**
 * `widgets.stack-service#1`..`#10`.
 *
 * Upstream this class reached into `HabitsApplication.component` for the habit
 * list and the preferences. There is no component in the launcher's process, so
 * the habits come from the same published [WidgetData] document the providers
 * read, and the ids in the adapter Intent are resolved against it — which is
 * what makes `widgets.stack-service#5`'s HabitNotFoundException reachable here.
 */
internal class StackRemoteViewsFactory(private val context: Context, intent: Intent) :
    RemoteViewsFactory {

    private val widgetId: Int = intent.getIntExtra(
        AppWidgetManager.EXTRA_APPWIDGET_ID,
        AppWidgetManager.INVALID_APPWIDGET_ID
    )
    private val habitIds: LongArray
    private val widgetType: StackWidgetType

    /** `widgets.stack-service#3`. */
    override fun onCreate() {}
    override fun onDestroy() {}
    override fun onDataSetChanged() {}
    override fun getCount(): Int = habitIds.size
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = habitIds[position]
    override fun hasStableIds(): Boolean = true

    /**
     * `widgets.dimensions#6`: the same body as
     * `BaseWidgetProvider.getDimensionsFromOptions`, duplicated rather than
     * shared — as upstream duplicates it — so the two can never drift apart
     * silently while a stack sizes its children from the parent's bundle.
     */
    fun getDimensionsFromOptions(ctx: Context, options: Bundle): WidgetDimensions {
        val maxWidth = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).toFloat()
        ).toInt()
        val maxHeight = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).toFloat()
        ).toInt()
        val minWidth = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).toFloat()
        ).toInt()
        val minHeight = dpToPixels(
            ctx,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).toFloat()
        ).toInt()
        return WidgetDimensions(minWidth, maxHeight, maxWidth, minHeight)
    }

    /** `widgets.stack-service#4`, `#5`, `#6`. */
    override fun getViewAt(position: Int): RemoteViews? {
        Log.i("StackRemoteViewsFactory", "getViewAt $position started")
        if (position < 0 || position >= habitIds.size) return null
        val document = WidgetData.readWidget(context, widgetId)
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        // Inflating a View off the main thread needs a Looper on that thread,
        // and the launcher calls this from its own binder pool.
        if (Looper.myLooper() == null) Looper.prepare()
        val habits = habitIds.map { habitId ->
            document.habits.firstOrNull { it.id == habitId } ?: throw HabitNotFoundException()
        }
        val h = habits[position]
        val widget = constructWidget(h, document.today)
        widget.setDimensions(getDimensionsFromOptions(context, options))
        val landscapeViews = widget.landscapeRemoteViews
        val portraitViews = widget.portraitRemoteViews
        val intent =
            StackWidgetType.getIntentFillIn(widgetId, widgetType, h, habits, document.today)
        landscapeViews.setOnClickFillInIntent(R.id.button, intent)
        portraitViews.setOnClickFillInIntent(R.id.button, intent)
        val remoteViews = RemoteViews(landscapeViews, portraitViews)
        Log.i("StackRemoteViewsFactory", "getViewAt $position ended")
        return remoteViews
    }

    /**
     * `widgets.stack-service#5`: every child is built stacked, which is what
     * forces it opaque (`widgets.card-chrome#5`).
     *
     * Upstream hands `FrequencyWidget` the `prefs.firstWeekday` preference. It
     * is not part of the published document, so this port's `FrequencyWidget`
     * takes the document's today instead and buckets from there, exactly as the
     * non-stacked one does.
     */
    private fun constructWidget(habit: HabitData, today: LocalDate): BaseWidget {
        return when (widgetType) {
            StackWidgetType.CHECKMARK -> CheckmarkWidget(context, widgetId, habit, today, true)
            StackWidgetType.FREQUENCY -> FrequencyWidget(context, widgetId, habit, today, true)
            StackWidgetType.SCORE -> ScoreWidget(context, widgetId, habit, today, true)
            StackWidgetType.HISTORY -> HistoryWidget(context, widgetId, habit, today, true)
            StackWidgetType.STREAKS -> StreakWidget(context, widgetId, habit, today, true)
            StackWidgetType.TARGET -> TargetWidget(context, widgetId, habit, today, true)
        }
    }

    /** `widgets.stack-service#9`, `widgets.empty#3`, `widgets.error-states#5`. */
    override fun getLoadingView(): RemoteViews {
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(widgetId)
        val widget = EmptyWidget(context, widgetId)
        widget.setDimensions(getDimensionsFromOptions(context, options))
        val landscapeViews = widget.landscapeRemoteViews
        val portraitViews = widget.portraitRemoteViews
        return RemoteViews(landscapeViews, portraitViews)
    }

    /** `widgets.stack-service#2`: everything the adapter Intent must carry. */
    init {
        val widgetTypeValue = intent.getIntExtra(StackWidgetService.WIDGET_TYPE, -1)
        val habitIdsStr = intent.getStringExtra(StackWidgetService.HABIT_IDS)
        if (widgetTypeValue < 0) throw RuntimeException("invalid widget type")
        if (habitIdsStr == null) throw RuntimeException("habitIdsStr is null")
        widgetType = StackWidgetType.getWidgetTypeFromValue(widgetTypeValue)
            ?: throw RuntimeException("unknown widget type value: $widgetTypeValue")
        habitIds = StringUtils.splitLongs(habitIdsStr)
    }
}
