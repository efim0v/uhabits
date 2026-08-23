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
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews

/**
 * Port of `uhabits-android/.../widgets/StackWidget.kt`.
 *
 * ## Why this still exists
 *
 * Creating stack widgets was removed from the picker upstream (commit 1df9cc76),
 * so no new one can be placed. The rendering path stayed, because a widget whose
 * stored preference holds anything other than exactly one habit id is still a
 * stack, and those placements survive an app update — including an update that
 * replaces the whole app with this port. `settings.widget-preferences.habit-ids`
 * reads the same `widget-%06d-habit` keys a Loop install already has, and
 * `HomeWidgetBridge` publishes every habit it finds under one, so a home screen
 * carried across from the Kotlin build arrives here with multi-habit documents
 * intact. Without this class they would all draw the "habit not found" card.
 *
 * ## What it is
 *
 * Not a widget that draws anything: a `StackView` plus a `RemoteViewsService`
 * that builds one child widget per habit. [getRemoteViews] is overridden whole,
 * so none of [BaseWidget]'s measure-and-rasterise path runs
 * (`widgets.stack#3`, `#8`).
 */
class StackWidget(
    context: Context,
    widgetId: Int,
    private val widgetType: StackWidgetType,
    private val habits: List<HabitData>,
    stacked: Boolean = true
) : BaseWidget(context, widgetId, stacked) {

    /** `widgets.stack#8`, `widgets.dimensions#5`. */
    override val defaultHeight: Int get() = 0
    override val defaultWidth: Int get() = 0

    /** `widgets.stack#8`: the pages are clickable, the stack itself is not. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent? = null

    override fun refreshData(widgetView: View) {
        // unused
    }

    override fun buildView(): View? {
        // unused
        return null
    }

    /**
     * `widgets.stack#3`, `#6`, `#7`. The requested width and height are ignored
     * outright: a StackView fills whatever the launcher gives it, and the
     * children are measured by the factory from the same options bundle.
     */
    override fun getRemoteViews(width: Int, height: Int): RemoteViews {
        val manager = AppWidgetManager.getInstance(context)
        val remoteViews =
            RemoteViews(context.packageName, StackWidgetType.getStackWidgetLayoutId(widgetType))
        val serviceIntent = Intent(context, StackWidgetService::class.java)
        val habitIds = StringUtils.joinLongs(habits.map { it.id }.toLongArray())

        serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        serviceIntent.putExtra(StackWidgetService.WIDGET_TYPE, widgetType.value)
        serviceIntent.putExtra(StackWidgetService.HABIT_IDS, habitIds)
        // Android caches one adapter per service Intent, comparing them with
        // `filterEquals` — which ignores extras. Naming the Intent after itself
        // puts the extras into the data, so two stacks of the same type do not
        // share one adapter.
        serviceIntent.data = Uri.parse(serviceIntent.toUri(Intent.URI_INTENT_SCHEME))
        remoteViews.setRemoteAdapter(
            StackWidgetType.getStackWidgetAdapterViewId(widgetType),
            serviceIntent
        )
        manager.notifyAppWidgetViewDataChanged(
            id,
            StackWidgetType.getStackWidgetAdapterViewId(widgetType)
        )
        remoteViews.setEmptyView(
            StackWidgetType.getStackWidgetAdapterViewId(widgetType),
            StackWidgetType.getStackWidgetEmptyViewId(widgetType)
        )
        remoteViews.setPendingIntentTemplate(
            StackWidgetType.getStackWidgetAdapterViewId(widgetType),
            StackWidgetType.getPendingIntentTemplate(context, widgetType, habits)
        )
        return remoteViews
    }
}
