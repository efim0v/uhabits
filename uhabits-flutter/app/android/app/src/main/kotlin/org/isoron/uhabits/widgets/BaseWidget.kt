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
import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.LayoutInflater
import android.view.View
import android.view.View.MeasureSpec
import android.widget.RemoteViews
import org.isoron.uhabits.R
import kotlin.math.max

/**
 * Port of `uhabits-android/.../widgets/BaseWidget.kt`.
 *
 * The rendering strategy is upstream's, unchanged: build a real Android `View`
 * in the launcher's process, measure it, draw it into a `Bitmap`, and ship the
 * bitmap inside `R.layout.widget_wrapper`
 * (`widgets.remoteviews-rendering#1`..`#4`). `RemoteViews` cannot host a custom
 * view and cannot run the core's `Canvas` abstraction, so a rasterised view is
 * the only way to draw a ring, a history grid or a bar chart at all.
 *
 * What changed is where the data comes from: upstream's constructor resolved
 * `HabitsApplication.component`, and there is no such component here. Everything
 * a widget needs arrives as a [WidgetDocument] read from shared storage.
 */
abstract class BaseWidget(
    val context: Context,
    val id: Int,
    /**
     * `widgets.card-chrome#5`: a widget rendered inside a StackWidget is forced
     * opaque. Stack widgets are not reproduced, so this is always false and
     * exists only to keep [preferedBackgroundAlpha] honest about what it is.
     */
    val stacked: Boolean = false
) {

    /**
     * `widgets.dimensions#4`: until `setDimensions` is called the widget uses
     * `WidgetDimensions(defaultWidth, defaultHeight, defaultWidth,
     * defaultHeight)`.
     *
     * Resolved lazily rather than in the constructor, which is where upstream
     * does it. Upstream's version reads two abstract properties from the base
     * class's `init` block, so a subclass that writes `override val defaultWidth
     * = 125` (an initialiser, not a getter — and every upstream subclass does
     * exactly that) has not run its own initialiser yet and hands the base class
     * a 0. The defaults were therefore always 0x0 until the provider called
     * `setDimensions`. Reading them on demand is the same behaviour everywhere
     * `setDimensions` runs first, and the documented behaviour where it does not.
     */
    private var dimensions: WidgetDimensions? = null

    private val effectiveDimensions: WidgetDimensions
        get() = dimensions
            ?: WidgetDimensions(defaultWidth, defaultHeight, defaultWidth, defaultHeight)

    protected abstract val defaultHeight: Int

    protected abstract val defaultWidth: Int

    abstract fun getOnClickPendingIntent(context: Context): PendingIntent?

    abstract fun refreshData(widgetView: View)

    protected abstract fun buildView(): View?

    fun setDimensions(dimensions: WidgetDimensions) {
        this.dimensions = dimensions
    }

    val landscapeRemoteViews: RemoteViews
        get() = effectiveDimensions.let { getRemoteViews(it.landscapeWidth, it.landscapeHeight) }

    val portraitRemoteViews: RemoteViews
        get() = effectiveDimensions.let { getRemoteViews(it.portraitWidth, it.portraitHeight) }

    /**
     * `widgets.card-chrome#5` / `settings.preferences.widget-opacity#5`: 255
     * inside a stack, `Preferences.widgetOpacity` otherwise.
     */
    protected val preferedBackgroundAlpha: Int
        get() = if (stacked) 255 else widgetOpacity

    /**
     * `Preferences.widgetOpacity`, pinned at the preference's own default.
     *
     * `pref_widget_opacity` is not in the published document and has no Flutter
     * settings row, so 255 is the only value this build can produce. Everything
     * downstream of a lower alpha is therefore unreachable — see the KDoc on
     * [org.isoron.uhabits.widgets.views.HabitWidgetView].
     */
    private val widgetOpacity: Int get() = 255

    /**
     * `widgets.remoteviews-rendering#1`: build the view, measure it, refresh it,
     * measure again if the refresh requested layout, then rasterise.
     */
    protected open fun getRemoteViews(width: Int, height: Int): RemoteViews {
        val view = buildView()!!
        measureView(view, width, height)
        refreshData(view)
        if (view.isLayoutRequested) measureView(view, width, height)
        val remoteViews = RemoteViews(context.packageName, R.layout.widget_wrapper)
        buildRemoteViews(view, remoteViews, width, height)
        return remoteViews
    }

    private fun buildRemoteViews(
        view: View,
        remoteViews: RemoteViews,
        width: Int,
        height: Int
    ) {
        remoteViews.setImageViewBitmap(R.id.imageView, getBitmapFromView(view))
        adjustRemoteViewsPadding(remoteViews, view, width, height)
        // `widgets.remoteviews-rendering#5`: the click target exists only when
        // there is something to click.
        val onClickIntent = getOnClickPendingIntent(context)
        if (onClickIntent != null) remoteViews.setOnClickPendingIntent(R.id.button, onClickIntent)
    }

    /** `widgets.remoteviews-rendering#4`: centre the tap target on the bitmap. */
    private fun adjustRemoteViewsPadding(
        remoteViews: RemoteViews,
        view: View,
        width: Int,
        height: Int
    ) {
        val w = ((width.toFloat() - view.measuredWidth) / 2).toInt()
        val h = ((height.toFloat() - view.measuredHeight) / 2).toInt()
        remoteViews.setViewPadding(R.id.buttonOverlay, w, h, w, h)
    }

    /** `widgets.remoteviews-rendering#3`. */
    private fun getBitmapFromView(view: View): Bitmap {
        view.invalidate()
        val bitmap = Bitmap.createBitmap(
            max(1, view.measuredWidth),
            max(1, view.measuredHeight),
            Bitmap.Config.ARGB_8888
        )
        view.draw(Canvas(bitmap))
        return bitmap
    }

    /** `widgets.remoteviews-rendering#2`. */
    private fun measureView(view: View, w: Int, h: Int) {
        val inflater = LayoutInflater.from(context)
        val entireView = inflater.inflate(R.layout.widget_wrapper, null)
        entireView.measure(
            MeasureSpec.makeMeasureSpec(w, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(h, MeasureSpec.EXACTLY)
        )
        entireView.layout(0, 0, entireView.measuredWidth, entireView.measuredHeight)
        val imageView = entireView.findViewById<View>(R.id.imageView)
        view.measure(
            MeasureSpec.makeMeasureSpec(imageView.measuredWidth, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(imageView.measuredHeight, MeasureSpec.EXACTLY)
        )
        view.layout(0, 0, view.measuredWidth, view.measuredHeight)
    }
}
