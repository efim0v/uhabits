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
 * Port of `uhabits-android/.../activities/common/views/ScoreChart.kt`.
 *
 * The bridge publishes the series the detail screen's Score card plots, at the
 * bucket the `scoreCardSpinnerPosition` preference holds
 * (`widgets.score#3`..`#6`, `audit4.score-widget-draws-an-empty-chart#1`), so
 * this draws a real chart: the percentage grid, the poly-line with its markers,
 * and the two-row date footer.
 *
 * What the document cannot supply is a *date* per bucket — it carries values
 * only — so the labels are stepped back `offset * bucketSize` days from today
 * rather than read off `scores[offset].date`. Upstream truncates each bucket to
 * its calendar start (week, month, quarter), so a Month or Quarter column can
 * be captioned a few days off. The port's iOS Score widget derives its dates
 * the same way, and changing it means publishing bucket dates on the wire.
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

        // `footerHeight = (3 * em).toInt()`. Two rows hang below the plot — the
        // month-or-day line at 1.2 em and the year line at 2.2 em — so a band
        // any shallower clips the years off the bottom of the widget.
        val footerHeight = 3 * em
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

        // `ScoreChart.onSizeChanged`: the column is at least one baseSize wide,
        // at least 1.5x `maxDayWidth` and at least 1.2x `maxMonthWidth` — and
        // upstream's `maxDayWidth` measures the twelve short month names too,
        // so the 1.5x factor is the one that ever wins. The chart then fills
        // the width with however many of those columns fit, which is what makes
        // a widget the user has widened show more history instead of a fixed
        // six points.
        var columnWidth = max(baseSize.toFloat(), maxMonthWidth * 1.5f)
        columnWidth = max(columnWidth, maxMonthWidth * 1.2f)
        val nColumns = max(1, (width / columnWidth).toInt())
        columnWidth = width.toFloat() / nColumns

        val radius = dpToPixels(context, 3.5f)
        paint.color = color
        paint.strokeWidth = dpToPixels(context, 2f)

        // The series is newest-first and the newest bucket sits on the right
        // edge, so column k carries `scores[nColumns - k - 1]`; a column with
        // no datum behind it draws nothing at all, as upstream's
        // `if (offset >= scores.size) continue` does.
        var previousX = 0f
        var previousY = 0f
        var hasPrevious = false
        for (k in 0 until nColumns) {
            val offset = nColumns - k - 1
            if (offset >= scores.size) continue
            val x = k * columnWidth + columnWidth / 2
            val y = plotBottom - plotHeight * scores[offset].toFloat().coerceIn(0f, 1f)
            if (hasPrevious) {
                paint.style = Paint.Style.STROKE
                canvas.drawLine(previousX, previousY, x, y, paint)
            }
            previousX = x
            previousY = y
            hasPrevious = true
        }
        for (k in 0 until nColumns) {
            val offset = nColumns - k - 1
            if (offset >= scores.size) continue
            val x = k * columnWidth + columnWidth / 2
            val y = plotBottom - plotHeight * scores[offset].toFloat().coerceIn(0f, 1f)
            paint.style = Paint.Style.FILL
            canvas.drawCircle(x, y, radius, paint)
        }

        // `ScoreChart.drawFooter`, both rows.
        paint.color = WidgetTheme.CONTRAST_60
        paint.textAlign = Paint.Align.CENTER
        paint.style = Paint.Style.FILL
        var previousMonthText = ""
        var previousYearText = ""
        var skipYear = 0
        for (k in 0 until nColumns) {
            val offset = nColumns - k - 1
            if (offset >= scores.size) continue
            val date = today.minus(offset * bucketSize)
            val x = k * columnWidth + columnWidth / 2
            val yearText = date.year.toString()
            val monthText = WidgetDateFormatter.shortMonthName(date.month)
            val dayText = date.day.toString()

            var shouldPrintYear = true
            if (yearText == previousYearText) shouldPrintYear = false
            // Annual buckets would otherwise print a year under every column.
            if (bucketSize >= 365 && date.year % 2 != 0) shouldPrintYear = false
            if (skipYear > 0) {
                skipYear--
                shouldPrintYear = false
            }
            if (shouldPrintYear) {
                previousYearText = yearText
                previousMonthText = ""
                canvas.drawText(yearText, x, plotBottom + em * 2.2f, paint)
                skipYear = 1
            }
            // With the spinner on "Year" this row is dropped entirely, so the
            // axis reads 2022, 2024, 2026 instead of a run of month
            // abbreviations and repeated day numbers.
            if (bucketSize < 365) {
                val text: String
                if (monthText != previousMonthText) {
                    previousMonthText = monthText
                    text = monthText
                } else {
                    text = dayText
                }
                canvas.drawText(text, x, plotBottom + em * 1.2f, paint)
            }
        }
    }

    /**
     * `ScoreChart.maxMonthWidth` — and `maxDayWidth`, which measures the same
     * twelve strings.
     */
    private val maxMonthWidth: Float
        get() {
            var maxWidth = 0f
            for (i in 1..12) {
                maxWidth = max(maxWidth, paint.measureText(WidgetDateFormatter.shortMonthName(i)))
            }
            return maxWidth
        }
}
