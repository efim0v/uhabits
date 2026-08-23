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
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.util.AttributeSet
import android.view.View
import org.isoron.uhabits.widgets.WidgetDimens
import org.isoron.uhabits.widgets.WidgetTheme
import org.isoron.uhabits.widgets.dpToPixels
import org.isoron.uhabits.widgets.setAlpha
import org.isoron.uhabits.widgets.spToPixels
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToLong

/**
 * Port of `uhabits-android/.../activities/common/views/RingView.kt`, trimmed to
 * what the Checkmark widget uses.
 *
 * `widgets.checkmark-view#12`: an arc from -90 degrees spanning
 * `360 * round(percentage / precision) * precision` degrees, the remainder in
 * `contrast100` at 15% alpha, the inner disc punched out with PorterDuff CLEAR
 * (transparency is always enabled for widgets), and the glyph centred at
 * `(centerX, centerY + 0.4 * em)` in the FontAwesome face; stroked text uses
 * `strokeWidth = textSize / 15`.
 */
class RingView : View {

    private var color: Int = WidgetTheme.color(0)
    private var precision = 0.01f
    private var percentage = 0f
    private var diameter = 1
    private var thickness: Float
    private var backgroundColor: Int = WidgetTheme.CARD_BG_COLOR
    private var inactiveColor: Int = setAlpha(WidgetTheme.CONTRAST_100, 0.15f)
    private var em = 0f
    private var text: String = ""
    private var textSize: Float
    private var isStrokedTextEnabled = false

    /**
     * `widgets.checkmark-view#12`: always true here.
     * `CheckmarkWidgetView.init` sets it unconditionally, and the widget is
     * drawn onto a transparent bitmap, so the inner disc has to be cleared
     * rather than painted over with the card colour.
     */
    private var isTransparencyEnabled = true

    private var enableFontAwesome = false

    private val pRing = TextPaint()
    private val rect = RectF()

    private var drawingCache: Bitmap? = null
    private var cacheCanvas: Canvas? = null

    constructor(context: Context) : super(context) {
        thickness = dpToPixels(context, 2f)
        textSize = spToPixels(context, WidgetDimens.SMALL_TEXT_SIZE_SP)
        init()
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        thickness = dpToPixels(context, 2f)
        textSize = spToPixels(context, WidgetDimens.SMALL_TEXT_SIZE_SP)
        init()
    }

    fun setPercentage(percentage: Float) {
        this.percentage = percentage
        invalidate()
    }

    fun setColor(color: Int) {
        this.color = color
        invalidate()
    }

    override fun setBackgroundColor(backgroundColor: Int) {
        this.backgroundColor = backgroundColor
        invalidate()
    }

    fun setText(text: String) {
        this.text = text
        invalidate()
    }

    fun setTextSize(textSize: Float) {
        this.textSize = textSize
    }

    fun setThickness(thickness: Float) {
        this.thickness = thickness
        invalidate()
    }

    fun setIsStrokedTextEnabled(isStroked: Boolean) {
        this.isStrokedTextEnabled = isStroked
    }

    fun setIsTransparencyEnabled(enabled: Boolean) {
        this.isTransparencyEnabled = enabled
    }

    fun setEnableFontAwesome(enabled: Boolean) {
        this.enableFontAwesome = enabled
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val activeCanvas: Canvas
        if (isTransparencyEnabled) {
            if (drawingCache == null) reallocateCache()
            val cache = drawingCache ?: return
            cache.eraseColor(Color.TRANSPARENT)
            activeCanvas = cacheCanvas ?: return
        } else {
            activeCanvas = canvas
        }

        pRing.style = Paint.Style.FILL
        pRing.color = color
        rect.set(0f, 0f, diameter.toFloat(), diameter.toFloat())
        val angle = 360 * (percentage / precision).roundToLong() * precision
        activeCanvas.drawArc(rect, -90f, angle, true, pRing)
        pRing.color = inactiveColor
        activeCanvas.drawArc(rect, angle - 90, 360 - angle, true, pRing)

        if (thickness > 0) {
            if (isTransparencyEnabled) {
                pRing.xfermode = XFERMODE_CLEAR
            } else {
                pRing.color = backgroundColor
            }
            rect.inset(thickness, thickness)
            activeCanvas.drawArc(rect, 0f, 360f, true, pRing)
            pRing.xfermode = null
            pRing.color = color
            pRing.textSize = textSize
            if (isStrokedTextEnabled) {
                pRing.style = Paint.Style.STROKE
                pRing.strokeWidth = textSize / 15f
            }
            if (enableFontAwesome) pRing.typeface = FontAwesome.typeface(context)
            activeCanvas.drawText(text, rect.centerX(), rect.centerY() + 0.4f * em, pRing)
            pRing.typeface = null
        }

        if (activeCanvas !== canvas) {
            drawingCache?.let { canvas.drawBitmap(it, 0f, 0f, null) }
        }
    }

    /** `widgets.checkmark-view#13`: the ring is always square. */
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = MeasureSpec.getSize(heightMeasureSpec)
        diameter = max(1, min(height, width))
        pRing.textSize = textSize
        em = pRing.measureText("M")
        setMeasuredDimension(diameter, diameter)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (isTransparencyEnabled) reallocateCache()
    }

    private fun init() {
        pRing.isAntiAlias = true
        pRing.color = color
        pRing.textAlign = Paint.Align.CENTER
    }

    private fun reallocateCache() {
        drawingCache?.recycle()
        val cache = Bitmap.createBitmap(diameter, diameter, Bitmap.Config.ARGB_8888)
        drawingCache = cache
        cacheCanvas = Canvas(cache)
    }

    companion object {
        private val XFERMODE_CLEAR = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
    }
}

/**
 * The four glyphs the Checkmark widget draws, and the face that renders them.
 *
 * `widgets.checkmark-view#6` names them by Android string resource
 * (`R.string.fa_check` and friends); those resources do not exist here, so the
 * code points come straight from `FontAwesome` in the Dart core, which is the
 * same table.
 */
object FontAwesome {

    /** `fa_check`, U+F00C. */
    const val CHECK = "\uF00C"

    /** `fa_times`, U+F00D. */
    const val TIMES = "\uF00D"

    /** `fa_skipped`, U+F068. */
    const val SKIPPED = "\uF068"

    /** `fa_question`, U+F128. */
    const val QUESTION = "\uF128"

    /**
     * The typeface, loaded out of the Flutter asset bundle.
     *
     * `InterfaceUtils.getFontAwesome` read `fonts/fontawesome-webfont.ttf` from
     * the Android assets. The Flutter build declares the same face in
     * `pubspec.yaml` and packs it at this path inside the APK, so the widget
     * process can load it with no extra asset copy. If it ever moves, the ring
     * falls back to the default face and the glyph shows as a box rather than
     * taking the widget down.
     */
    private const val ASSET_PATH = "flutter_assets/assets/fonts/FontAwesome.ttf"

    @Volatile
    private var cached: Typeface? = null

    fun typeface(context: Context): Typeface {
        cached?.let { return it }
        val loaded = try {
            Typeface.createFromAsset(context.assets, ASSET_PATH)
        } catch (e: RuntimeException) {
            e.printStackTrace()
            Typeface.DEFAULT
        } ?: Typeface.DEFAULT
        cached = loaded
        return loaded
    }
}
