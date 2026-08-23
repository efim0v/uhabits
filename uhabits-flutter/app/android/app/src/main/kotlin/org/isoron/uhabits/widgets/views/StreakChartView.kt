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

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.content.Context
import android.view.View
import org.isoron.uhabits.widgets.Entry
import org.isoron.uhabits.widgets.HabitData
import org.isoron.uhabits.widgets.LocalDate
import org.isoron.uhabits.widgets.StreakData
import org.isoron.uhabits.widgets.WidgetDimens
import org.isoron.uhabits.widgets.WidgetTheme
import org.isoron.uhabits.widgets.dpToPixels
import org.isoron.uhabits.widgets.spToPixels
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/**
 * Port of `uhabits-android/.../activities/common/views/StreakChart.kt`.
 *
 * ## Where the streaks come from
 *
 * `widgets.streak#3` wants `habit.streaks.getBest(chart.maxStreakCount)`, over
 * the habit's whole history. The bridge publishes `getBest(30)` and [bestOf]
 * narrows that to the bars this widget's height admits
 * (`audit4.streak-and-frequency-widgets-only-see`).
 *
 * [streaksFrom] is the fallback for a document written before that field
 * existed: it rebuilds runs from the 60 daily values the contract has always
 * carried, which is right for recent streaks and wrong for anything older or
 * longer — a streak that started before the window is reported as starting at
 * its edge, and streaks that ended before it vanish.
 */
class StreakChartView(context: Context) : View(context) {

    var color: Int = 0
        set(value) {
            field = value
            initColors()
        }

    var streaks: List<StreakData> = emptyList()
        set(value) {
            field = value
            initColors()
            updateMaxMinLengths()
            requestLayout()
        }

    private val paint = Paint().apply {
        isAntiAlias = true
        textAlign = Paint.Align.CENTER
    }
    private val rect = RectF()

    private var colors = IntArray(4)
    private var textColors = IntArray(3)
    private var baseSize = 0
    private var internalWidth = 0
    private var maxLength = 0
    private var em = 0f
    private var maxLabelWidth = 0f
    private var textMargin = 0f
    private var shouldShowLabels = false

    init {
        baseSize = dpToPixels(context, WidgetDimens.BASE_SIZE_DP).toInt()
        initColors()
    }

    /**
     * `widgets.streak#4`: how many bars fit, read after the view is measured.
     */
    val maxStreakCount: Int
        get() = if (baseSize <= 0) 0 else floor(measuredHeight.toDouble() / baseSize).toInt()

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        internalWidth = width
        val minTextSize = spToPixels(context, WidgetDimens.TINY_TEXT_SIZE_SP)
        val maxTextSize = spToPixels(context, WidgetDimens.REGULAR_TEXT_SIZE_SP)
        paint.textSize = max(min(baseSize * 0.5f, maxTextSize), minTextSize)
        em = paint.fontSpacing
        textMargin = 0.5f * em
        updateMaxMinLengths()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (streaks.isEmpty()) return
        rect.set(0f, 0f, internalWidth.toFloat(), baseSize.toFloat())
        for (s in streaks) {
            drawRow(canvas, s, rect)
            rect.offset(0f, baseSize.toFloat())
        }
    }

    private fun drawRow(canvas: Canvas, streak: StreakData, rect: RectF) {
        if (maxLength == 0) return
        val percentage = streak.length.toFloat() / maxLength
        var availableWidth = internalWidth - 2 * maxLabelWidth
        if (shouldShowLabels) availableWidth -= 2 * textMargin
        val lengthText = streak.length.toString()
        val minBarWidth = paint.measureText(lengthText) + em
        val barWidth = max(percentage * availableWidth, minBarWidth)
        val gap = (internalWidth - barWidth) / 2
        val paddingTopBottom = baseSize * 0.05f
        paint.style = Paint.Style.FILL
        paint.color = percentageToColor(percentage)
        val round = dpToPixels(context, 2f)
        canvas.drawRoundRect(
            rect.left + gap,
            rect.top + paddingTopBottom,
            rect.right - gap,
            rect.bottom - paddingTopBottom,
            round,
            round,
            paint
        )
        val yOffset = rect.centerY() + 0.3f * em
        paint.color = percentageToTextColor(percentage)
        paint.textAlign = Paint.Align.CENTER
        canvas.drawText(lengthText, rect.centerX(), yOffset, paint)
        if (shouldShowLabels) {
            paint.color = textColors[1]
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(longFormat(streak.start), gap - textMargin, yOffset, paint)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(longFormat(streak.end), internalWidth - gap + textMargin, yOffset, paint)
        }
    }

    private fun longFormat(date: LocalDate) =
        WidgetDateFormatter.longFormat(date.year, date.month, date.day)

    private fun initColors() {
        val red = Color.red(color)
        val green = Color.green(color)
        val blue = Color.blue(color)
        colors = IntArray(4)
        colors[3] = color
        colors[2] = Color.argb(192, red, green, blue)
        colors[1] = Color.argb(96, red, green, blue)
        colors[0] = WidgetTheme.CONTRAST_20
        textColors = IntArray(3)
        textColors[2] = WidgetTheme.CONTRAST_0
        textColors[1] = WidgetTheme.CONTRAST_60
        textColors[0] = WidgetTheme.CONTRAST_80
    }

    private fun percentageToColor(percentage: Float): Int = when {
        percentage >= 1.0f -> colors[3]
        percentage >= 0.8f -> colors[2]
        percentage >= 0.5f -> colors[1]
        else -> colors[0]
    }

    private fun percentageToTextColor(percentage: Float): Int =
        if (percentage >= 0.5f) textColors[2] else textColors[1]

    private fun updateMaxMinLengths() {
        maxLength = 0
        shouldShowLabels = true
        for (s in streaks) {
            maxLength = max(maxLength, s.length)
            maxLabelWidth = max(
                maxLabelWidth,
                max(paint.measureText(longFormat(s.start)), paint.measureText(longFormat(s.end)))
            )
        }
        // Not enough room for both date labels: drop them and let the bars use
        // the full width.
        if (internalWidth - 2 * maxLabelWidth < internalWidth * 0.25f) {
            maxLabelWidth = 0f
            shouldShowLabels = false
        }
    }

    companion object {
        /**
         * `StreakList.getBest(limit)` over an already-published list: the
         * [limit] longest streaks — ties broken by the later end date, as
         * `Streak.compareLonger` does — re-sorted newest-ending first, which is
         * the order the chart draws them in.
         *
         * The bridge publishes the best thirty; every count a widget can show
         * is smaller, and the longest k of the longest thirty are the longest k
         * outright, so this is the same list upstream's
         * `habit.streaks.getBest(chart.maxStreakCount)` would produce.
         */
        fun bestOf(streaks: List<StreakData>, limit: Int): List<StreakData> = streaks
            .sortedWith(
                compareByDescending<StreakData> { it.length }.thenByDescending { it.end }
            )
            .take(max(0, limit))
            .sortedByDescending { it.end }

        /**
         * Rebuilds `habit.streaks` from the published 60-day window.
         *
         * A day counts towards a streak when its entry is YES_MANUAL, YES_AUTO
         * or SKIP — the same three values `widgets.checkmark-view#3` paints as
         * the habit colour, and the same ones `StreakList` treats as unbroken.
         * The result is sorted longest-first to stand in for `getBest(n)`.
         */
        fun streaksFrom(habit: HabitData, today: LocalDate, limit: Int): List<StreakData> {
            val found = ArrayList<StreakData>()
            var runEnd = -1
            habit.entries.forEachIndexed { index, value ->
                val isOn = value == Entry.YES_MANUAL ||
                    value == Entry.YES_AUTO ||
                    value == Entry.SKIP
                if (isOn) {
                    if (runEnd < 0) runEnd = index
                } else if (runEnd >= 0) {
                    found.add(streak(today, runEnd, index - 1))
                    runEnd = -1
                }
            }
            if (runEnd >= 0) found.add(streak(today, runEnd, habit.entries.size - 1))
            return found.sortedByDescending { it.length }.take(max(0, limit))
        }

        /** [newest] and [oldest] are offsets back from [today]. */
        private fun streak(today: LocalDate, newest: Int, oldest: Int) = StreakData(
            start = today.minus(oldest),
            end = today.minus(newest),
            length = oldest - newest + 1
        )
    }
}
