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
import org.isoron.uhabits.widgets.Entry
import org.isoron.uhabits.widgets.HabitData
import org.isoron.uhabits.widgets.LocalDate
import org.isoron.uhabits.widgets.WidgetTheme
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.round

/**
 * Port of `org.isoron.uhabits.core.ui.views.HistoryChart.draw`, drawn with
 * [WidgetCanvas] so the dp geometry survives intact.
 *
 * `widgets.history#2`: the widget's chart is built with `today = getToday()`,
 * the habit's palette colour, `WidgetTheme`, the locale date formatter, the
 * first weekday, `defaultSquare = OFF` and `padding = 2.5`.
 * `widgets.history#6`: it is a static bitmap — the scroll and tap gestures
 * `AndroidDataView` offers in the app do not exist here, so `dataOffset` is
 * pinned at 0.
 */
class HistoryChartView(context: Context) : View(context) {

    enum class Square { ON, OFF, GREY, DIMMED, HATCHED }

    var today: LocalDate = LocalDate.of(1970, 1, 1)
    var paletteColor: Int = 0

    /** Newest first: `series[0]` is [today]. */
    var series: List<Square> = emptyList()

    /** `widgets.history#2`. */
    var defaultSquare: Square = Square.OFF

    /**
     * `HistoryChart.notesIndicators`, newest first, parallel to [series]: true
     * where that day's entry carries a note
     * (`audit6.history-home-screen-widget-never-draws#1`).
     *
     * Empty until the widget assigns it — a view inflated with no document
     * behind it draws no dots — which is also what a document written before
     * the field existed leaves it at.
     */
    var notesIndicators: List<Boolean> = emptyList()

    /**
     * `pref_first_weekday`, as `daysSinceSunday`.
     *
     * Not in the published document, so it stays at Sunday — the preference's
     * own default. A user who set Monday sees a Sunday-first grid in the widget
     * and a Monday-first one in the app.
     */
    var firstWeekday: Int = 0

    private val padding = 2.5
    private val squareSpacing = 1.0

    private var squareSize = 0.0
    private var nColumns = 0
    private var topLeftOffset = 0
    private var topLeftDate: LocalDate = LocalDate.of(1970, 1, 1)
    private var lastPrintedMonth = ""
    private var lastPrintedYear = ""
    private var headerOverflow = 0.0

    override fun onDraw(androidCanvas: Canvas) {
        super.onDraw(androidCanvas)
        val density = resources.displayMetrics.density
        if (width <= 0 || height <= 0) return
        val canvas = WidgetCanvas(
            androidCanvas,
            density,
            width / density.toDouble(),
            height / density.toDouble()
        )

        squareSize = round((canvas.height - 2 * padding) / 8.0)
        canvas.setFontSize(min(14.0, canvas.height * 0.06))

        val weekdayColumnWidth = (0..6).maxOf { weekday ->
            canvas.measureText(WidgetDateFormatter.shortWeekdayName(weekday)) + squareSize * 0.15
        }

        nColumns = floor((canvas.width - 2 * padding - weekdayColumnWidth) / squareSize).toInt()
        if (nColumns <= 0 || squareSize <= 0.0) return
        val firstWeekdayOffset = (today.daysSinceSunday - firstWeekday + 7) % 7
        topLeftOffset = (nColumns - 1) * 7 + firstWeekdayOffset
        topLeftDate = today.minus(topLeftOffset)

        lastPrintedYear = ""
        lastPrintedMonth = ""
        headerOverflow = 0.0

        repeat(nColumns) { column ->
            drawColumn(canvas, column, topLeftDate.plus(7 * column), topLeftOffset - 7 * column)
        }

        canvas.setColor(WidgetTheme.MEDIUM_CONTRAST_TEXT_COLOR)
        repeat(7) { row ->
            val date = topLeftDate.plus(row)
            canvas.setTextAlign(Paint.Align.LEFT)
            canvas.drawText(
                WidgetDateFormatter.shortWeekdayName(date.daysSinceSunday),
                padding + nColumns * squareSize + squareSize * 0.15,
                padding + squareSize * (row + 1) + squareSize / 2
            )
        }
    }

    private fun drawColumn(canvas: WidgetCanvas, column: Int, topDate: LocalDate, topOffset: Int) {
        drawHeader(canvas, column, topDate)
        repeat(7) { row ->
            val offset = topOffset - row
            if (offset < 0) return
            drawSquare(
                canvas,
                padding + column * squareSize,
                padding + (row + 1) * squareSize,
                squareSize - squareSpacing,
                squareSize - squareSpacing,
                topDate.plus(row),
                offset
            )
        }
    }

    private fun drawHeader(canvas: WidgetCanvas, column: Int, date: LocalDate) {
        canvas.setColor(WidgetTheme.MEDIUM_CONTRAST_TEXT_COLOR)
        val monthText = WidgetDateFormatter.shortMonthName(date.month)
        val yearText = date.year.toString()
        val headerText: String
        when {
            monthText != lastPrintedMonth -> {
                headerText = monthText
                lastPrintedMonth = monthText
            }
            yearText != lastPrintedYear -> {
                headerText = yearText
                lastPrintedYear = headerText
            }
            else -> headerText = ""
        }
        canvas.setTextAlign(Paint.Align.LEFT)
        canvas.drawText(
            headerText,
            headerOverflow + padding + column * squareSize,
            padding + squareSize / 2
        )
        headerOverflow += canvas.measureText(headerText) + 0.1 * squareSize
        headerOverflow = max(0.0, headerOverflow - squareSize)
    }

    private fun drawSquare(
        canvas: WidgetCanvas,
        x: Double,
        y: Double,
        w: Double,
        h: Double,
        date: LocalDate,
        offset: Int
    ) {
        val value = if (offset >= series.size) defaultSquare else series[offset]
        val hasNotes = if (offset >= notesIndicators.size) false else notesIndicators[offset]
        val color = WidgetTheme.color(paletteColor)
        val squareColor = when (value) {
            Square.ON -> color
            Square.OFF -> WidgetTheme.LOW_CONTRAST_TEXT_COLOR
            Square.GREY -> WidgetTheme.MEDIUM_CONTRAST_TEXT_COLOR
            // `cardBackgroundColor` is TRANSPARENT under WidgetTheme, so
            // blending with it halves the alpha rather than the colour.
            Square.DIMMED, Square.HATCHED -> blendWithTransparent(color)
        }

        canvas.setColor(squareColor)
        canvas.fillRoundRect(x, y, w, h, w * 0.15)

        if (value == Square.HATCHED) {
            canvas.setStrokeWidth(0.75)
            canvas.setColor(WidgetTheme.CARD_BACKGROUND_COLOR)
            var k = w / 10
            repeat(5) {
                canvas.drawLine(x + k, y, x, y + k)
                canvas.drawLine(x + w - k, y + h, x + w, y + h - k)
                k += w / 5
            }
        }

        // The core picks the label colour by contrast unless the card is
        // transparent — which it always is under WidgetTheme, so the day number
        // is white on every square.
        canvas.setColor(WidgetTheme.HIGH_CONTRAST_TEXT_COLOR)
        canvas.setTextAlign(Paint.Align.CENTER)
        canvas.drawText(date.day.toString(), x + w / 2, y + w / 2)

        // `HistoryChart.drawSquare`'s last block: a dot in the square's
        // top-right corner for a day the user attached a note to
        // (`audit6.history-home-screen-widget-never-draws#1`). The low-contrast
        // colour is the readable one over a filled or grey square; everything
        // else — an empty, dimmed or hatched day — takes the habit's own
        // colour. Both offsets are measured in the square's *width*, as
        // upstream measures them, so the dot does not move if a square ever
        // stops being square.
        if (hasNotes) {
            val circleColor = when (value) {
                Square.ON, Square.GREY -> WidgetTheme.LOW_CONTRAST_TEXT_COLOR
                else -> color
            }
            canvas.setColor(circleColor)
            canvas.fillCircle(x + w - w / 5, y + w / 5, w / 12)
        }
    }

    private fun blendWithTransparent(color: Int): Int =
        (color and 0x00FFFFFF) or (((android.graphics.Color.alpha(color) / 2) and 0xFF) shl 24)

    companion object {
        /**
         * `HistoryCardPresenter.buildState(...).series`, as the document
         * carries it (`audit10.history-home-screen-widget-draws-more#1`).
         *
         * The grid's column count is geometric — `nColumns = floor((width - 2 *
         * padding - weekdayColumnWidth) / squareSize)`, `7 * nColumns` days —
         * and nothing bounds it by the data behind it, so a widget wider than
         * about 1.25x its height asks for more days than [HabitData.entries]
         * holds and every one of them is drawn `defaultSquare`. Upstream that
         * never happens: the presenter's series runs from the habit's oldest
         * known entry to today, so OFF past its end means "before the habit
         * existed" and nothing else. [HabitData.historySeries] is that series.
         *
         * [entriesSeriesOf] is the fallback, and only for a document written
         * before the field existed — a widget outlives an app update for as
         * long as the user leaves it on the home screen.
         */
        fun seriesOf(habit: HabitData): List<Square> {
            val published = habit.historySeries ?: return entriesSeriesOf(habit)
            val squares = Square.values()
            return published.map { digit ->
                val ordinal = digit - '0'
                if (ordinal in squares.indices) squares[ordinal] else Square.OFF
            }
        }

        /**
         * `HistoryChart.notesIndicators` (`audit6.history-home-screen-widget
         * -never-draws#1`), expanded from the sparse offsets the document
         * carries into the flag-per-day list the chart indexes.
         *
         * Falls back to [HabitData.notesIndicators] — the sixty-day array — for
         * a document written before [HabitData.historyNotes] existed.
         */
        fun notesOf(habit: HabitData): List<Boolean> {
            val offsets = habit.historyNotes ?: return habit.notesIndicators
            val length = habit.historySeries?.length ?: 0
            val flags = BooleanArray(length)
            for (offset in offsets) if (offset in 0 until length) flags[offset] = true
            return flags.toList()
        }

        /**
         * Port of `HistoryCardPresenter.buildState`'s series mapping
         * (`widgets.history#4`), reading the published entries instead of
         * `computedEntries`.
         *
         * The list is newest-first in both, so the index means the same thing.
         */
        private fun entriesSeriesOf(habit: HabitData): List<Square> = habit.entries.map { value ->
            if (habit.isNumerical) {
                when {
                    value == Entry.UNKNOWN -> Square.OFF
                    value == Entry.SKIP -> Square.HATCHED
                    habit.isAtMost && value / 1000.0 <= habit.target -> Square.ON
                    !habit.isAtMost && value / 1000.0 >= habit.target -> Square.ON
                    else -> Square.GREY
                }
            } else {
                when (value) {
                    Entry.YES_MANUAL -> Square.ON
                    Entry.YES_AUTO -> Square.DIMMED
                    Entry.SKIP -> Square.HATCHED
                    else -> Square.OFF
                }
            }
        }
    }
}
