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
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.View
import android.view.ViewGroup
import org.isoron.uhabits.widgets.WidgetDimens
import org.isoron.uhabits.widgets.WidgetTheme
import org.isoron.uhabits.widgets.dpToPixels
import org.isoron.uhabits.widgets.spToPixels
import org.isoron.uhabits.widgets.toShortString
import kotlin.math.max
import kotlin.math.min

/**
 * Port of `uhabits-android/.../activities/common/views/TargetChart.kt`.
 *
 * The drawing is upstream's, row for row. What feeds it is not: see
 * [org.isoron.uhabits.widgets.TargetWidget] for which of the five windows the
 * published document can actually fill.
 */
class TargetChartView(context: Context) : View(context) {

    var color: Int = 0

    var values: List<Double> = emptyList()

    var targets: List<Double> = emptyList()

    /** `widgets.target#4`: 'Today', 'Week', 'Month', 'Quarter', 'Year'. */
    var labels: List<String> = emptyList()

    private val paint = Paint().apply { isAntiAlias = true }
    private val rect = RectF()
    private val barRect = RectF()

    private var baseSize = 0
    private var maxLabelSize = 0f
    private var tinyTextSize = 0f

    init {
        tinyTextSize = spToPixels(context, WidgetDimens.TINY_TEXT_SIZE_SP)
    }

    override fun onMeasure(widthSpec: Int, heightSpec: Int) {
        baseSize = dpToPixels(context, WidgetDimens.BASE_SIZE_DP).toInt()
        val width = MeasureSpec.getSize(widthSpec)
        var height = labels.size * baseSize
        val params = layoutParams
        if (params != null && params.height == ViewGroup.LayoutParams.MATCH_PARENT) {
            height = MeasureSpec.getSize(heightSpec)
            if (labels.isNotEmpty()) baseSize = height / labels.size
        }
        setMeasuredDimension(
            MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
            MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
        )
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (labels.isEmpty() || values.size < labels.size || targets.size < labels.size) return
        maxLabelSize = 0f
        paint.textSize = tinyTextSize
        for (label in labels) maxLabelSize = max(maxLabelSize, paint.measureText(label))
        val marginTop = (height - baseSize * labels.size) / 2.0f
        rect.set(0f, marginTop, width.toFloat(), marginTop + baseSize)
        for (i in labels.indices) {
            drawRow(canvas, i, rect)
            rect.offset(0f, baseSize.toFloat())
        }
    }

    private fun drawRow(canvas: Canvas, row: Int, rect: RectF) {
        val padding = dpToPixels(context, 4f)
        val round = dpToPixels(context, 2f)
        val stop = maxLabelSize + padding * 2
        paint.style = Paint.Style.FILL
        paint.color = WidgetTheme.MEDIUM_CONTRAST_TEXT_COLOR

        paint.textSize = tinyTextSize
        paint.textAlign = Paint.Align.RIGHT
        var yTextAdjust = (paint.descent() + paint.ascent()) / 2.0f
        canvas.drawText(labels[row], rect.left + stop - padding, rect.centerY() - yTextAdjust, paint)

        paint.color = WidgetTheme.LOW_CONTRAST_TEXT_COLOR
        barRect.set(
            rect.left + stop + padding,
            rect.top + baseSize * 0.05f,
            rect.right - padding,
            rect.bottom - baseSize * 0.05f
        )
        canvas.drawRoundRect(barRect, round, round, paint)

        var percentage = if (targets[row] > 0) (values[row] / targets[row]).toFloat() else 1.0f
        percentage = min(1.0f, max(0f, percentage))

        var completedWidth = percentage * barRect.width()
        if (completedWidth > 0 && completedWidth < 2 * round) completedWidth = 2 * round
        val remainingWidth = barRect.width() - completedWidth
        paint.color = color
        barRect.set(barRect.left, barRect.top, barRect.left + completedWidth, barRect.bottom)
        canvas.drawRoundRect(barRect, round, round, paint)

        paint.color = Color.WHITE
        paint.textSize = tinyTextSize
        paint.textAlign = Paint.Align.CENTER
        yTextAdjust = (paint.descent() + paint.ascent()) / 2.0f
        val remaining = targets[row] - values[row]
        val completedText = values[row].toShortString()
        val remainingText = remaining.toShortString()
        if (completedWidth > paint.measureText(completedText) + 2 * padding) {
            paint.color = WidgetTheme.HIGH_CONTRAST_TEXT_COLOR
            canvas.drawText(completedText, barRect.centerX(), barRect.centerY() - yTextAdjust, paint)
        }
        if (remainingWidth > paint.measureText(remainingText) + 2 * padding) {
            paint.color = WidgetTheme.MEDIUM_CONTRAST_TEXT_COLOR
            barRect.set(
                rect.left + stop + padding + completedWidth,
                barRect.top,
                rect.right - padding,
                barRect.bottom
            )
            canvas.drawText(remainingText, barRect.centerX(), barRect.centerY() - yTextAdjust, paint)
        }
    }
}
