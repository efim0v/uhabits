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
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.View
import org.isoron.uhabits.widgets.Entry
import org.isoron.uhabits.widgets.HabitData
import org.isoron.uhabits.widgets.LocalDate
import org.isoron.uhabits.widgets.WidgetTheme
import org.isoron.uhabits.widgets.mixColors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Port of `uhabits-android/.../activities/common/views/FrequencyChart.kt`,
 * minus the scrolling (`dataOffset` is pinned at 0: a widget bitmap has no
 * gestures).
 *
 * ## What the contract cannot supply
 *
 * `widgets.frequency#3` and `#4` want
 * `habit.originalEntries.computeWeekdayFrequency(...)` — a bucket per weekday
 * per month over the habit's **whole history**. The published document carries
 * 60 days, so [computeWeekdayFrequency] below sees roughly two months and every
 * older column draws empty. The widget is therefore correct in shape and wrong
 * in extent, and it will stay that way until the bridge publishes the buckets.
 *
 * `widgets.frequency#5` — the widget reads `originalEntries`, so YES_AUTO days
 * must not count — is also unmet, and in the opposite direction: the document
 * carries `computedEntries`, in which those days are already filled in. The
 * YES_MANUAL test below is what keeps the damage to boolean habits down to the
 * auto-satisfied days only.
 */
class FrequencyChartView(context: Context) : View(context) {

    var color: Int = 0
        set(value) {
            field = value
            initColors()
        }

    var isNumerical: Boolean = false

    /** `pref_first_weekday` as `daysSinceSunday`; see [HistoryChartView.firstWeekday]. */
    var firstWeekday: Int = 0

    /** Month start -> 7 buckets indexed by `(daysSinceSunday + 1) % 7`. */
    var frequency: Map<LocalDate, IntArray> = emptyMap()
        set(value) {
            field = value
            maxFreq = value.values.flatMap { it.asIterable() }.fold(1) { a, b -> max(a, b) }
        }

    var today: LocalDate = LocalDate.of(1970, 1, 1)

    private var maxFreq = 1
    private val pText = Paint().apply { isAntiAlias = true }
    private val pGraph = Paint().apply {
        isAntiAlias = true
        textAlign = Paint.Align.CENTER
    }
    private val pGrid = Paint().apply { isAntiAlias = true }
    private val rect = RectF()
    private val prevRect = RectF()

    private var colors = IntArray(4)
    private var baseSize = 0
    private var columnWidth = 0f
    private var columnHeight = 0
    private var nColumns = 0
    private var em = 0f

    init {
        initColors()
    }

    private fun initColors() {
        val gridColor = WidgetTheme.CONTRAST_20
        colors = IntArray(4)
        colors[0] = gridColor
        colors[3] = color
        colors[1] = mixColors(colors[0], colors[3], 0.66f)
        colors[2] = mixColors(colors[0], colors[3], 0.33f)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            MeasureSpec.getSize(widthMeasureSpec),
            MeasureSpec.getSize(heightMeasureSpec)
        )
    }

    override fun onSizeChanged(width: Int, height: Int, oldWidth: Int, oldHeight: Int) {
        val h = if (height < 9) 200 else height
        baseSize = h / 8
        pText.textSize = baseSize * 0.4f
        pGraph.textSize = baseSize * 0.4f
        pGraph.strokeWidth = baseSize * 0.1f
        pGrid.strokeWidth = baseSize * 0.05f
        em = pText.fontSpacing
        columnWidth = max(baseSize.toFloat(), maxMonthWidth * 1.2f)
        columnHeight = 8 * baseSize
        nColumns = if (columnWidth > 0) (width / columnWidth).toInt() else 0
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (nColumns < 2 || baseSize <= 0) return
        rect.set(0f, 0f, nColumns * columnWidth, columnHeight.toFloat())
        drawGrid(canvas, rect)
        pText.textAlign = Paint.Align.CENTER
        pText.color = WidgetTheme.CONTRAST_60
        pGraph.color = color
        prevRect.setEmpty()
        var currentDate = today.startOfMonth().plusMonths(-nColumns + 2)
        for (i in 0 until nColumns - 1) {
            rect.set(0f, 0f, columnWidth, columnHeight.toFloat())
            rect.offset(i * columnWidth, 0f)
            drawColumn(canvas, rect, currentDate)
            currentDate = currentDate.plusMonths(1)
        }
    }

    private fun drawColumn(canvas: Canvas, rect: RectF, date: LocalDate) {
        val values = frequency[date]
        val weekDaysInMonth = countWeekdayOccurrencesInMonth(date)
        val rowHeight = rect.height() / 8.0f
        prevRect.set(rect)
        for (j in 0 until 7) {
            rect.set(0f, 0f, baseSize.toFloat(), baseSize.toFloat())
            rect.offset(prevRect.left, prevRect.top + baseSize * j)
            val i = ((firstWeekday + j) % 7 + 1) % 7
            if (values != null) drawMarker(canvas, rect, values[i], weekDaysInMonth[i])
            rect.offset(0f, rowHeight)
        }
        drawFooter(canvas, rect, date)
    }

    private fun drawFooter(canvas: Canvas, rect: RectF, date: LocalDate) {
        canvas.drawText(
            WidgetDateFormatter.shortMonthName(date.month),
            rect.centerX(),
            rect.centerY() - 0.1f * em,
            pText
        )
        // Upstream prints the year under February, not under January.
        if (date.month == 2) {
            canvas.drawText(date.year.toString(), rect.centerX(), rect.centerY() + 0.9f * em, pText)
        }
    }

    private fun drawGrid(canvas: Canvas, rGrid: RectF) {
        val rowHeight = rGrid.height() / 8
        pText.textAlign = Paint.Align.LEFT
        pText.color = WidgetTheme.CONTRAST_60
        pGrid.color = WidgetTheme.CONTRAST_20
        for (row in 0 until 7) {
            canvas.drawText(
                WidgetDateFormatter.shortWeekdayName((firstWeekday + row) % 7),
                rGrid.right - columnWidth,
                rGrid.top + rowHeight / 2 + 0.25f * em,
                pText
            )
            pGrid.strokeWidth = 1f
            canvas.drawLine(rGrid.left, rGrid.top, rGrid.right, rGrid.top, pGrid)
            rGrid.offset(0f, rowHeight)
        }
        canvas.drawLine(rGrid.left, rGrid.top, rGrid.right, rGrid.top, pGrid)
    }

    private fun drawMarker(canvas: Canvas, rect: RectF, value: Int, weekdayFrequency: Int) {
        // A skipped entry can make the raw value negative; clamp before scaling.
        val clamped = max(0, value)
        val padding = rect.height() * 0.2f
        val maxRadius = (rect.height() - 2 * padding) / 2.0f
        val scalingFactor = if (isNumerical) maxFreq else weekdayFrequency
        if (scalingFactor <= 0) return
        val scale = 1.0f / scalingFactor * clamped
        val colorIndex = min(colors.size - 1, ((colors.size - 1) * scale).roundToInt())
        pGraph.color = colors[colorIndex]
        canvas.drawCircle(rect.centerX(), rect.centerY(), maxRadius * scale, pGraph)
    }

    private val maxMonthWidth: Float
        get() {
            var maxWidth = 0f
            for (i in 1..12) {
                maxWidth = max(maxWidth, pText.measureText(WidgetDateFormatter.shortMonthName(i)))
            }
            return maxWidth
        }

    /** `countWeekdayOccurrencesInMonth`, indexed by `(daysSinceSunday + 1) % 7`. */
    private fun countWeekdayOccurrencesInMonth(monthStart: LocalDate): IntArray {
        val counts = IntArray(7)
        val days = monthStart.daysInMonth()
        for (d in 0 until days) {
            val date = monthStart.plus(d)
            counts[(date.daysSinceSunday + 1) % 7]++
        }
        return counts
    }

    companion object {
        /**
         * Port of `EntryList.computeWeekdayFrequency` (`widgets.frequency#4`),
         * over the published 60-day window rather than the whole history.
         *
         * Buckets every KNOWN entry by its month start; within each month it
         * accumulates into a 7-slot array indexed by
         * `(daysSinceSunday + 1) % 7`, adding the raw value for numerical
         * habits and 1 for a boolean entry that is exactly YES_MANUAL.
         */
        fun computeWeekdayFrequency(habit: HabitData, today: LocalDate): Map<LocalDate, IntArray> {
            val result = HashMap<LocalDate, IntArray>()
            habit.entries.forEachIndexed { index, value ->
                if (value == Entry.UNKNOWN) return@forEachIndexed
                val date = today.minus(index)
                val bucket = result.getOrPut(date.startOfMonth()) { IntArray(7) }
                val slot = (date.daysSinceSunday + 1) % 7
                if (habit.isNumerical) {
                    bucket[slot] += value
                } else if (value == Entry.YES_MANUAL) {
                    bucket[slot] += 1
                }
            }
            return result
        }
    }
}
