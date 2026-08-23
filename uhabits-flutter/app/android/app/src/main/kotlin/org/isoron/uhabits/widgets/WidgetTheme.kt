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

import android.content.Context
import android.graphics.Color
import android.util.TypedValue

/**
 * The widget palette, inlined.
 *
 * Upstream this lives in two places at once: `R.style.WidgetTheme` supplies the
 * Android `?attr/` colours (`widgets.theme#1`) and the core class
 * `org.isoron.uhabits.core.ui.views.WidgetTheme` supplies the habit colours
 * (`widgets.theme#2`). A widget provider runs in the launcher's process with no
 * Flutter engine and no core library, so both tables are constants here.
 *
 * `widgets.theme#5`: widgets ignore the user's light/dark app theme entirely —
 * there is deliberately no light variant of anything below.
 */
object WidgetTheme {

    // ---- R.style.WidgetTheme, resolved (widgets.theme#1) --------------------

    /** `cardBgColor` = grey_850. */
    const val CARD_BG_COLOR: Int = 0xFF303030.toInt()

    /** `contrast0` = white. */
    const val CONTRAST_0: Int = 0xFFFFFFFF.toInt()

    /** `contrast20` = white_a0. */
    const val CONTRAST_20: Int = 0x0FFFFFFF

    /** `contrast60` = white_aa. */
    const val CONTRAST_60: Int = 0xAFFFFFFF.toInt()

    /** `contrast80` = grey_800. */
    const val CONTRAST_80: Int = 0xFF424242.toInt()

    /** `contrast100` = white. */
    const val CONTRAST_100: Int = 0xFFFFFFFF.toInt()

    /** `widgetShadowAlpha` = 0 (widgets.card-chrome#4). */
    const val WIDGET_SHADOW_ALPHA: Float = 0f

    // ---- core WidgetTheme (widgets.theme#2, #3) ----------------------------

    /**
     * `WidgetTheme.color(paletteIndex)` for indices 0..19; every other index is
     * black. Values are opaque ARGB.
     */
    private val PALETTE: IntArray = intArrayOf(
        0xD32F2F, 0xE64A19, 0xF57C00, 0xFF8F00, 0xF9A825,
        0xAFB42B, 0x7CB342, 0x388E3C, 0x00897B, 0x00ACC1,
        0x039BE5, 0x1976D2, 0x6275f0, 0x5E35B1, 0x8E24AA,
        0xD81B60, 0x5D4037, 0x757575, 0x757575, 0x9E9E9E
    ).map { it or 0xFF000000.toInt() }.toIntArray()

    fun color(paletteIndex: Int): Int =
        if (paletteIndex in PALETTE.indices) PALETTE[paletteIndex] else 0xFF000000.toInt()

    /** `widgets.theme#3`: `cardBackgroundColor = TRANSPARENT`. */
    const val CARD_BACKGROUND_COLOR: Int = Color.TRANSPARENT

    /** `widgets.theme#3`: `highContrastTextColor = WHITE`. */
    const val HIGH_CONTRAST_TEXT_COLOR: Int = 0xFFFFFFFF.toInt()

    /** `widgets.theme#3`: `mediumContrastTextColor = WHITE` at 50% alpha. */
    const val MEDIUM_CONTRAST_TEXT_COLOR: Int = 0x80FFFFFF.toInt()

    /** `widgets.theme#3`: `lowContrastTextColor = WHITE` at 10% alpha. */
    const val LOW_CONTRAST_TEXT_COLOR: Int = 0x1AFFFFFF
}

/** `res/values/dimens.xml`, the handful of entries the widgets read. */
object WidgetDimens {
    /** `R.dimen.baseSize` = 20dp. */
    const val BASE_SIZE_DP: Float = 20f

    /** `R.dimen.tinyTextSize` = 10sp. */
    const val TINY_TEXT_SIZE_SP: Float = 10f

    /** `R.dimen.smallTextSize` = 14sp. */
    const val SMALL_TEXT_SIZE_SP: Float = 14f

    /** `R.dimen.regularTextSize` = 16sp. */
    const val REGULAR_TEXT_SIZE_SP: Float = 16f
}

/** `InterfaceUtils.dpToPixels`. */
fun dpToPixels(context: Context, dp: Float): Float = TypedValue.applyDimension(
    TypedValue.COMPLEX_UNIT_DIP,
    dp,
    context.resources.displayMetrics
)

/** `InterfaceUtils.spToPixels`. */
fun spToPixels(context: Context, sp: Float): Float = TypedValue.applyDimension(
    TypedValue.COMPLEX_UNIT_SP,
    sp,
    context.resources.displayMetrics
)

/** `ColorUtils.setAlpha`. */
fun setAlpha(color: Int, alpha: Float): Int = Color.argb(
    (255 * alpha).toInt(),
    Color.red(color),
    Color.green(color),
    Color.blue(color)
)

/** `ColorUtils.mixColors`. */
fun mixColors(color1: Int, color2: Int, amount: Float): Int {
    val b = 1 - amount
    return Color.argb(
        (Color.alpha(color1) * amount + Color.alpha(color2) * b).toInt(),
        (Color.red(color1) * amount + Color.red(color2) * b).toInt(),
        (Color.green(color1) * amount + Color.green(color2) * b).toInt(),
        (Color.blue(color1) * amount + Color.blue(color2) * b).toInt()
    )
}
