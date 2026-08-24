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
import android.graphics.Paint
import android.graphics.Rect
import android.text.TextPaint
import java.text.DateFormat
import java.text.DateFormatSymbols
import java.util.GregorianCalendar
import java.util.Locale
import java.util.TimeZone

/**
 * The launcher-side stand-in for `org.isoron.platform.gui.AndroidCanvas`.
 *
 * The core's chart code — `HistoryChart` and friends — draws in **dp**, and
 * `AndroidCanvas` is what turns those into pixels. That code cannot be reused
 * from a widget provider (it is Dart now, and `RemoteViews` could not run it
 * even when it was Kotlin), but its coordinate system can be, and keeping it is
 * what lets the chart views below stay recognisable ports rather than
 * re-inventions. Every method here matches `AndroidCanvas`'s semantics,
 * including the two that are easy to get subtly wrong:
 *
 *  - coordinates and font sizes are in dp and multiplied by [density] on the way
 *    out;
 *  - [drawText] treats `y` as the text's *middle*, not its baseline, offsetting
 *    by `0.6 * height-of-"m"` exactly as `AndroidCanvas.drawText` does.
 */
class WidgetCanvas(
    private val canvas: Canvas,
    private val density: Float,
    /** Width in dp. */
    val width: Double,
    /** Height in dp. */
    val height: Double
) {
    val paint = Paint().apply { isAntiAlias = true }
    val textPaint = TextPaint().apply {
        isAntiAlias = true
        textAlign = Paint.Align.CENTER
    }

    private val textBounds = Rect()
    private var mHeight = 15f

    private fun Double.px() = (this * density).toFloat()

    fun setColor(color: Int) {
        paint.color = color
        textPaint.color = color
    }

    fun setStrokeWidth(width: Double) {
        paint.strokeWidth = width.px()
    }

    fun setFontSize(size: Double) {
        textPaint.textSize = size.px()
        textPaint.getTextBounds("m", 0, 1, textBounds)
        mHeight = textBounds.height().toFloat()
    }

    fun setTextAlign(align: Paint.Align) {
        textPaint.textAlign = align
    }

    /** In dp. */
    fun measureText(text: String): Double = (textPaint.measureText(text) / density).toDouble()

    fun drawText(text: String, x: Double, y: Double) {
        canvas.drawText(text, x.px(), y.px() + 0.6f * mHeight, textPaint)
    }

    fun fillRect(x: Double, y: Double, w: Double, h: Double) {
        paint.style = Paint.Style.FILL
        canvas.drawRect(x.px(), y.px(), (x + w).px(), (y + h).px(), paint)
    }

    fun fillRoundRect(x: Double, y: Double, w: Double, h: Double, radius: Double) {
        paint.style = Paint.Style.FILL
        canvas.drawRoundRect(
            x.px(),
            y.px(),
            (x + w).px(),
            (y + h).px(),
            radius.px(),
            radius.px(),
            paint
        )
    }

    fun fillCircle(cx: Double, cy: Double, radius: Double) {
        paint.style = Paint.Style.FILL
        canvas.drawCircle(cx.px(), cy.px(), radius.px(), paint)
    }

    fun drawLine(x1: Double, y1: Double, x2: Double, y2: Double) {
        paint.style = Paint.Style.STROKE
        canvas.drawLine(x1.px(), y1.px(), x2.px(), y2.px(), paint)
    }
}

/**
 * The slice of `JavaLocalDateFormatter` the charts need, in the default locale.
 */
object WidgetDateFormatter {

    private val symbols: DateFormatSymbols get() = DateFormatSymbols.getInstance(Locale.getDefault())

    /** 'Sun'..'Sat'; [daysSinceSunday] is 0 for Sunday. */
    fun shortWeekdayName(daysSinceSunday: Int): String =
        symbols.shortWeekdays[(daysSinceSunday % 7) + 1]

    /**
     * 'Jan'..'Dec'; [month] is 1-based.
     *
     * `JavaLocalDateFormatter.shortMonthName` reads BOTH display names and
     * returns the LONG one when it is three characters or shorter — "for some
     * locales, such as Japan, SHORT name is exceedingly short". It changes the
     * answer for zh-CN, whose LONG January is 一月 and whose SHORT one is 1月
     * (`audit3.shortmonthname-drops-the-use-the-long#1`).
     */
    fun shortMonthName(month: Int): String {
        val s = symbols
        val long = s.months[month - 1]
        return if (long.length <= 3) long else s.shortMonths[month - 1]
    }

    /**
     * `JavaLocalDateFormatter.longFormat` — the DEVICE LOCALE's medium date,
     * which is what flanks every bar of the streak chart.
     *
     * The home-screen Streak widget is the app's own `StreakChart` upstream
     * (`StreakWidget.buildView()` returns `GraphWidgetView(context,
     * StreakChart(context))`), so it inherits the chart's formatter whole:
     * `DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault())`
     * with `df.timeZone = TimeZone.getTimeZone("UTC")`. That is a pattern, not
     * a template: it carries the locale's field ORDER and separators, so a
     * German device reads "24.11.2014" and a Chinese one "2014年11月24日".
     * Building the string out of [shortMonthName] instead — "Nov 24, 2014" —
     * localizes only the month word and pins everybody else to the American
     * shape (`audit21.android-widget-streak-labels-use-the-locale-medium-date
     * #1`). The in-app Streak card (`IntlLocalDateFormatter._mediumDate`) and
     * the iOS widget (`DateNames.longFormat`) already do it this way.
     *
     * The UTC pin is the second half and it is not optional: the arguments are
     * a `LocalDate`, i.e. the UTC midnight `LocalDate.toGregorianCalendar()`
     * builds, so a formatter left on the device zone prints the day before
     * everywhere west of GMT.
     *
     * The [DateFormat] is built per call rather than cached, exactly as
     * upstream's `longFormat` builds one per call: `java.text.DateFormat` is
     * not thread-safe, and this object is a singleton reachable both from the
     * provider's own background thread (`BaseWidgetProvider`) and from the
     * launcher's binder pool (`StackWidgetService`). A chart asks for at most
     * four labels per bar per redraw, and a redraw happens on the update
     * period; re-reading [Locale.getDefault] each time also means a locale
     * switch is picked up by a provider process that outlived it.
     */
    fun longFormat(year: Int, month: Int, day: Int): String {
        val cal = GregorianCalendar(TimeZone.getTimeZone("UTC"))
        cal.clear()
        cal.set(year, month - 1, day)
        val df = DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault())
        df.timeZone = TimeZone.getTimeZone("UTC")
        return df.format(cal.time)
    }
}
