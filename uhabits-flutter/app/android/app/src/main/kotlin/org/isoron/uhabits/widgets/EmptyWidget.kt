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
import org.isoron.uhabits.widgets.views.EmptyWidgetView

/**
 * Port of `uhabits-android/.../widgets/EmptyWidget.kt`.
 *
 * `widgets.empty#3`: the placeholder a [StackRemoteViewsFactory] shows while it
 * is still building a page. It is the only reason this class exists, and
 * [StackWidgetService] is its only construction site.
 *
 * `widgets.empty#4`: `stacked` defaults to false even though the widget only
 * ever appears inside a stack, so the placeholder fades with the user's
 * widgetOpacity preference while the page it stands in for does not. Upstream's
 * default, kept.
 */
class EmptyWidget(
    context: Context,
    widgetId: Int,
    stacked: Boolean = false
) : BaseWidget(context, widgetId, stacked) {

    /** `widgets.empty#1`, `widgets.dimensions#5`. */
    override val defaultHeight: Int get() = 200
    override val defaultWidth: Int get() = 200

    /** `widgets.empty#1`: never clickable. */
    override fun getOnClickPendingIntent(context: Context): PendingIntent? = null

    /** `widgets.empty#1`: and nothing to refresh. */
    override fun refreshData(widgetView: View) {}

    override fun buildView(): View = EmptyWidgetView(context)
}
