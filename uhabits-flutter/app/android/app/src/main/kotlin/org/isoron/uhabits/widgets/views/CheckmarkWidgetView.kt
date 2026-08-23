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
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import org.isoron.uhabits.R
import org.isoron.uhabits.widgets.Entry
import org.isoron.uhabits.widgets.WidgetDimens
import org.isoron.uhabits.widgets.WidgetTheme
import org.isoron.uhabits.widgets.spToPixels
import org.isoron.uhabits.widgets.toShortString
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Port of `uhabits-android/.../widgets/views/CheckmarkWidgetView.kt`.
 */
class CheckmarkWidgetView(context: Context) : HabitWidgetView(context) {

    var activeColor: Int = 0
    var percentage = 0f
    var name: String? = null
    var entryValue = 0
    var entryState = 0
    var isNumerical = false

    /**
     * `widgets.checkmark-view#6`: with question marks enabled an UNKNOWN entry
     * shows `fa_question` rather than `fa_times`.
     *
     * `pref_unknown_enabled` is not part of the published document, so this
     * stays at the preference's own default (false) and the UNKNOWN glyph is
     * always `fa_times`. The branch is kept so that publishing the preference is
     * the only change needed.
     */
    var areQuestionMarksEnabled = false

    private lateinit var ring: RingView
    private lateinit var label: TextView

    override val innerLayoutId: Int
        get() = R.layout.widget_checkmark

    init {
        inflateAndBuild()
        ring = findViewById<View>(R.id.scoreRing) as RingView
        label = findViewById<View>(R.id.label) as TextView
        ring.setIsTransparencyEnabled(true)
        ring.setEnableFontAwesome(true)
        // `widgets.checkmark-view#11`: what the layout editor draws when it
        // instantiates this view with no data behind it.
        //
        // `activeColor` is upstream's `PaletteUtils.getAndroidTestColor(6)`,
        // i.e. `PaletteColor(6).toFixedAndroidColor()` = #7CB342. That fixed
        // palette is an app-side table which does not exist in the launcher's
        // process; the widget palette is the one that does, and the two agree
        // at index 6.
        //
        // Note it is `entryValue` that is seeded and not `entryState`, so the
        // preview card renders unsatisfied — upstream's own behaviour,
        // reproduced rather than corrected.
        if (isInEditMode) {
            percentage = 0.75f
            name = "Wake up early"
            activeColor = WidgetTheme.color(6)
            entryValue = Entry.YES_MANUAL
            refresh()
        }
    }

    /** `widgets.checkmark-view#2`..`#5`. */
    fun refresh() {
        // `widgets.checkmark-view#2`
        if (backgroundPaint == null || frame == null) return
        val bgColor: Int
        val fgColor: Int
        // `widgets.card-chrome#7`: unconditional, regardless of opacity.
        setShadowAlpha(0x4f)
        when (entryState) {
            Entry.YES_MANUAL, Entry.SKIP, Entry.YES_AUTO -> {
                // `widgets.checkmark-view#3`
                bgColor = activeColor
                fgColor = WidgetTheme.CONTRAST_0
                backgroundPaint!!.color = bgColor
                frame!!.background = cardBackground
            }
            else -> {
                // `widgets.checkmark-view#4`: NO, UNKNOWN and anything else; the
                // frame background is deliberately NOT re-applied here.
                bgColor = WidgetTheme.CARD_BG_COLOR
                fgColor = WidgetTheme.CONTRAST_60
            }
        }
        ring.setPercentage(percentage)
        ring.setColor(fgColor)
        ring.setBackgroundColor(bgColor)
        ring.setText(text)
        ring.setIsStrokedTextEnabled(strokedTextEnabled)
        label.text = name
        label.setTextColor(fgColor)
        requestLayout()
        postInvalidate()
    }

    /** `widgets.checkmark-view#8`. */
    private val strokedTextEnabled: Boolean
        get() = !isNumerical && entryState == Entry.YES_AUTO

    /** `widgets.checkmark-view#6`, `#7`. */
    private val text: String
        get() = if (isNumerical) {
            (max(0, entryValue) / 1000.0).toShortString()
        } else {
            when (entryState) {
                Entry.YES_MANUAL, Entry.YES_AUTO -> FontAwesome.CHECK
                Entry.SKIP -> FontAwesome.SKIPPED
                Entry.UNKNOWN ->
                    if (areQuestionMarksEnabled) FontAwesome.QUESTION else FontAwesome.TIMES
                else -> FontAwesome.TIMES
            }
        }

    /** `widgets.checkmark-view#9`, `#10`. */
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        var width = MeasureSpec.getSize(widthMeasureSpec)
        var height = MeasureSpec.getSize(heightMeasureSpec)
        if (height >= width) {
            height = min(height, (width * 1.5).roundToInt())
        } else {
            width = min(width, height)
        }
        val textSize = min(
            0.175f * width,
            spToPixels(context, WidgetDimens.SMALL_TEXT_SIZE_SP)
        )
        label.setTextSize(TypedValue.COMPLEX_UNIT_PX, textSize)
        ring.setTextSize(if (isNumerical) textSize * 0.9f else textSize)
        ring.setThickness(0.03f * width)
        super.onMeasure(
            MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
        )
    }
}
