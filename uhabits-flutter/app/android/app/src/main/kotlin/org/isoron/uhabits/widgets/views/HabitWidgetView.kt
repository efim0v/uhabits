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
package org.isoron.uhabits.widgets.views

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.InsetDrawable
import android.graphics.drawable.ShapeDrawable
import android.graphics.drawable.shapes.RoundRectShape
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import org.isoron.uhabits.R
import org.isoron.uhabits.widgets.WidgetTheme
import org.isoron.uhabits.widgets.dpToPixels
import kotlin.math.max

/**
 * Port of `uhabits-android/.../widgets/views/HabitWidgetView.kt`.
 *
 * `widgets.card-chrome#1`: a FrameLayout that inflates its inner layout and
 * looks up `id=frame` to hold the card background.
 *
 * ## The one thing that is missing
 *
 * `settings.preferences.widget-opacity` — the `pref_widget_opacity` list
 * preference — has no Flutter settings row and is not in the published document,
 * so [setBackgroundAlpha] is only ever called with 255. Every consequence of a
 * lower alpha is therefore unreachable: `widgets.card-chrome#6`'s "shadow only
 * when fully opaque" is always true, and
 * `settings.preferences.widget-opacity#6`..`#8` describe a state this build
 * cannot enter. The plumbing is kept intact so that adding the preference to the
 * document is the only change needed.
 */
abstract class HabitWidgetView(context: Context) : FrameLayout(context) {

    protected var cardBackground: InsetDrawable? = null

    protected var backgroundPaint: Paint? = null

    protected var frame: ViewGroup? = null

    /** `widgets.card-chrome#4`: `WidgetTheme` sets `widgetShadowAlpha` = 0. */
    private var shadowAlpha: Int = (255 * WidgetTheme.WIDGET_SHADOW_ALPHA).toInt()

    private var backgroundAlpha: Int = 0

    protected abstract val innerLayoutId: Int

    /** `widgets.card-chrome#8`: rebuilds the whole drawable. */
    fun setShadowAlpha(shadowAlpha: Int) {
        this.shadowAlpha = shadowAlpha
        rebuildBackground()
    }

    /** `widgets.card-chrome#8`: rebuilds the whole drawable. */
    fun setBackgroundAlpha(backgroundAlpha: Int) {
        this.backgroundAlpha = backgroundAlpha
        rebuildBackground()
    }

    /**
     * `widgets.card-chrome#2`, `#3`: an 18dp RoundRectShape inside an
     * InsetDrawable (left/top = max(shadowRadius - shadowOffset, 0) = 1dp,
     * right/bottom = shadowRadius + shadowOffset = 3dp, with shadowRadius = 2dp
     * and shadowOffset = 1dp), painted `cardBgColor` at the current alpha, with
     * a black shadow layer at `shadowAlpha`.
     */
    fun rebuildBackground() {
        val shadowRadius = dpToPixels(context, 2f).toInt()
        val shadowOffset = dpToPixels(context, 1f).toInt()
        val shadowColor = Color.argb(shadowAlpha, 0, 0, 0)
        val cornerRadius = dpToPixels(context, 18f)
        val radii = FloatArray(8) { cornerRadius }
        val innerDrawable = ShapeDrawable(RoundRectShape(radii, null, null))
        val insetLeftTop = max(shadowRadius - shadowOffset, 0)
        val insetRightBottom = shadowRadius + shadowOffset
        cardBackground = InsetDrawable(
            innerDrawable,
            insetLeftTop,
            insetLeftTop,
            insetRightBottom,
            insetRightBottom
        )
        backgroundPaint = innerDrawable.paint
        backgroundPaint?.setShadowLayer(
            shadowRadius.toFloat(),
            shadowOffset.toFloat(),
            shadowOffset.toFloat(),
            shadowColor
        )
        backgroundPaint?.color = WidgetTheme.CARD_BG_COLOR
        backgroundPaint?.alpha = backgroundAlpha
        frame = findViewById<View>(R.id.frame) as? ViewGroup
        frame?.background = cardBackground
    }

    /**
     * Called by every subclass at the end of its own construction, not from this
     * constructor: inflating the inner layout runs the subclass's view lookups,
     * and a Kotlin subclass has not initialised its fields while its superclass
     * constructor is still running.
     */
    protected fun inflateAndBuild() {
        inflate(context, innerLayoutId, this)
        // The shadow layer is a software-only Paint effect; the whole widget is
        // rasterised into a Bitmap-backed Canvas, which is software, but the
        // layer type is pinned anyway so a stray hardware canvas cannot silently
        // drop the shadow.
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        rebuildBackground()
    }
}
