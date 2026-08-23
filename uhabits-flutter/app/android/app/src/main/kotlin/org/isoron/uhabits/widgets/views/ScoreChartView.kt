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
import android.view.View
import org.isoron.uhabits.widgets.LocalDate
import org.isoron.uhabits.widgets.WidgetDimens
import org.isoron.uhabits.widgets.WidgetTheme
import org.isoron.uhabits.widgets.dpToPixels
import org.isoron.uhabits.widgets.spToPixels
import kotlin.math.max

/**
 * Stand-in for `uhabits-android/.../activities/common/views/ScoreChart.kt`.
 *
 * ## What the contract cannot supply
 *
 * This widget needs a score series, and the published document has none.
 * `widgets.score#3` builds it with
 * `ScoreCardPresenter.buildState(habit, firstWeekday, spinnerPosition, WidgetTheme())`,
 * and `widgets.score#6` averages the scores into buckets from the oldest known
 * entry to today. A score is not a function of the last 60 entries — the
 * algorithm walks the habit's whole history and needs its frequency — so there
 * is nothing here to compute it from, and no approximation worth drawing.
 *
 * So this renders the chart's furniture — the axis, the percentage grid and the
 * date labels — and plots the series only if the optional `scores` field ever
 * appears (`HabitData.scores`). Until it does, the Score widget shows an empty
 * grid, and `widgets.score#1`..`#6` stay unmet.
 */
class ScoreChartView(context: Context) : View(context) {

    var color: Int = 0

    /** Newest first, 0..1, one value per bucket of [bucketSize] days. */
    var scores: DoubleArray = DoubleArray(0)

    /** `widgets.score#4`: BUCKET_SIZES = [1, 7, 31, 92, 365]. */
    var bucketSize: Int = 7

    var today: LocalDate = LocalDate.of(1970, 1, 1)

    private val paint = Paint().apply { isAntiAlias = true }

    private var baseSize = 0
    private var em = 0f

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        baseSize = max(1, h / 8)
        paint.textSize = spToPixels(context, WidgetDimens.SMALL_TEXT_SIZE_SP)
        em = paint.fontSpacing
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) return

        val footerHeight = 2 * baseSize.toFloat()
        val plotBottom = height - footerHeight
        val plotTop = baseSize * 0.5f
        val plotHeight = plotBottom - plotTop
        if (plotHeight <= 0) return

        // Five horizontal rules at 20%..100%, labelled on the left, exactly as
        // ScoreChart draws them.
        paint.textAlign = Paint.Align.LEFT
        paint.strokeWidth = dpToPixels(context, 1f)
        for (i in 1..5) {
            val value = i * 0.2f
            val y = plotBottom - plotHeight * value
            paint.style = Paint.Style.STROKE
            paint.color = WidgetTheme.CONTRAST_20
            canvas.drawLine(0f, y, width.toFloat(), y, paint)
            paint.style = Paint.Style.FILL
            paint.color = WidgetTheme.CONTRAST_60
            canvas.drawText("${(value * 100).toInt()}%", 0f, y + em * 0.9f, paint)
        }
        paint.style = Paint.Style.STROKE
        paint.color = WidgetTheme.CONTRAST_20
        canvas.drawLine(0f, plotBottom, width.toFloat(), plotBottom, paint)

        if (scores.isEmpty()) return

        // The series is newest-first; the newest bucket sits on the right edge.
        val columnWidth = max(1f, width / 6f)
        val nVisible = ((width / columnWidth).toInt()).coerceAtMost(scores.size)
        val radius = dpToPixels(context, 3.5f)
        paint.color = color
        paint.strokeWidth = dpToPixels(context, 2f)

        var previousX = 0f
        var previousY = 0f
        for (k in 0 until nVisible) {
            val x = width - columnWidth * (k + 0.5f)
            val y = plotBottom - plotHeight * scores[k].toFloat().coerceIn(0f, 1f)
            if (k > 0) {
                paint.style = Paint.Style.STROKE
                canvas.drawLine(previousX, previousY, x, y, paint)
            }
            previousX = x
            previousY = y
        }
        for (k in 0 until nVisible) {
            val x = width - columnWidth * (k + 0.5f)
            val y = plotBottom - plotHeight * scores[k].toFloat().coerceIn(0f, 1f)
            paint.style = Paint.Style.FILL
            canvas.drawCircle(x, y, radius, paint)
        }

        // Footer: one date label per plotted bucket.
        paint.color = WidgetTheme.CONTRAST_60
        paint.textAlign = Paint.Align.CENTER
        paint.style = Paint.Style.FILL
        var lastMonth = ""
        for (k in nVisible - 1 downTo 0) {
            val date = today.minus(k * bucketSize)
            val x = width - columnWidth * (k + 0.5f)
            val month = WidgetDateFormatter.shortMonthName(date.month)
            val label = if (month != lastMonth) month else date.day.toString()
            lastMonth = month
            canvas.drawText(label, x, plotBottom + em, paint)
        }
    }
}
