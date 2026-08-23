/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/RingView.kt,
/// with its XML attribute defaults from
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/AttributeSetUtils.kt.
///
/// `RingView` is the Android progress ring: a pie sector in the habit colour,
/// the remainder in a 15%-alpha `contrast100`, and — when a thickness is set —
/// a hole punched in the middle with the card background, with a label centred
/// in it. Three layouts use it: the show-habit overview card (30dp, thickness
/// 5dp), the habit list card (15dp, thickness 3dp) and the checkmark widget
/// (thickness 2dp, FontAwesome glyphs).
///
/// It is deliberately *not* the core `Ring` view (`charts-canvas-theming.ring-core`),
/// which draws a stroked circle on a `core.Canvas`. This one needs three things
/// the shared canvas API has no vocabulary for — `PorterDuff.CLEAR`,
/// `Paint.Style.STROKE` on text, and an offscreen ARGB_8888 layer — so it is
/// written straight against `dart:ui`.
///
/// A note on the transparency path. Upstream allocates a bitmap of
/// diameter x diameter, erases it to `Color.TRANSPARENT` every frame, draws
/// into it and blits the result. `Canvas.saveLayer` is the same thing: a fresh
/// transparent buffer, composited onto the parent on `restore`. It exists so
/// that the hole can be a *true* hole — `BlendMode.clear` against the widget's
/// own layer rather than against the launcher's wallpaper.
///
/// A note on where it is used. The show-habit overview card draws its 30dp ring
/// with `RingPainter`, declared next to it in
/// `ui/habits/show/cards/overview_card_view.dart` — the same arithmetic with no
/// label, no stroked text and no offscreen layer, because that card needs none
/// of the three. This file is the complete view: the two remaining usages
/// ([RingViewUsages], the list card and the checkmark widget) are the ones that
/// do, and the checkmark widget's ring is native Kotlin today
/// (`app/android/.../widgets/views/RingView.kt`). Folding the overview card's
/// painter into this one is a straight substitution and belongs to whoever
/// touches that card next.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

/// `AttributeSetUtils.ISORON_NAMESPACE`.
const String isoronNamespace = 'http://isoron.org/android';

/// The `app:` attributes a `RingView` reads out of a layout, with the defaults
/// its two-argument constructor supplies
/// (`charts-canvas-theming.ring-view-android#2`).
@immutable
class RingViewAttributes {
  const RingViewAttributes({
    this.percentage = defaultPercentage,
    this.precision = defaultPrecision,
    this.color = defaultColor,
    this.backgroundColor,
    this.inactiveColor,
    this.thickness = defaultThickness,
    this.textSize = defaultTextSize,
    this.text = defaultText,
    this.enableFontAwesome = defaultEnableFontAwesome,
  });

  /// `getFloatAttribute(ctx, attrs, "percentage", 0f)`.
  static const double defaultPercentage = 0.0;

  /// `getFloatAttribute(ctx, attrs, "precision", 0.01f)`.
  static const double defaultPrecision = 0.01;

  /// `getColorAttribute(ctx, attrs, "color", 0)!!` — palette index 0 as an
  /// Android colour int, i.e. transparent black before a `setColor` call.
  static const Color defaultColor = Color(0x00000000);

  /// `getFloatAttribute(ctx, attrs, "thickness", 0f)`, then `dpToPixels`.
  static const double defaultThickness = 0.0;

  /// `getDimension(ctx, R.dimen.smallTextSize)`, 14sp.
  ///
  /// Upstream this default is converted twice. `getDimension` already returns
  /// *pixels* (28 at density 2), and the very next line runs the result through
  /// `spToPixels` again, so a `RingView` with no `textSize` attribute draws at
  /// 56px on that device rather than 28. The port cannot reproduce the doubling
  /// because a Flutter logical pixel *is* a dp and a sp: both conversions are
  /// multiplications by 1, and 14 stays 14. Unobservable either way — both
  /// layouts that inflate a `RingView` set `habit:textSize` explicitly, and the
  /// third usage builds the view in code — but worth knowing before comparing
  /// this against an Android golden captured without the attribute.
  static const double defaultTextSize = 14.0;

  /// `getAttribute(ctx, attrs, "text", "")`.
  static const String defaultText = '';

  /// `getBooleanAttribute(ctx, attrs, "enableFontAwesome", false)`.
  static const bool defaultEnableFontAwesome = false;

  final double percentage;
  final double precision;
  final Color color;

  /// `getColorAttribute(ctx, attrs, "backgroundColor", null)`: null in the
  /// layout, resolved to `?attr/cardBgColor` by `init()`.
  final Color? backgroundColor;

  /// `getColorAttribute(ctx, attrs, "inactiveColor", null)`: null in the
  /// layout, resolved to `?attr/contrast100` by `init()`.
  final Color? inactiveColor;

  final double thickness;
  final double textSize;
  final String text;
  final bool enableFontAwesome;

  /// Parses one `AttributeSet`, in the `http://isoron.org/android` namespace.
  ///
  /// `getFloatAttribute` wraps `toFloat()` in a `try`/`catch
  /// (NumberFormatException)` and returns the default, so a typo in a layout
  /// degrades to the default instead of taking the inflater down.
  factory RingViewAttributes.fromAttributeSet(Map<String, String?> attrs) {
    double float(String name, double defaultValue) {
      final text = attrs[name];
      if (text == null) return defaultValue;
      return double.tryParse(text) ?? defaultValue;
    }

    return RingViewAttributes(
      percentage: float('percentage', defaultPercentage),
      precision: float('precision', defaultPrecision),
      color: _parseColor(attrs['color']) ?? defaultColor,
      backgroundColor: _parseColor(attrs['backgroundColor']),
      inactiveColor: _parseColor(attrs['inactiveColor']),
      thickness: float('thickness', defaultThickness),
      textSize: float('textSize', defaultTextSize),
      text: attrs['text'] ?? defaultText,
      enableFontAwesome:
          attrs['enableFontAwesome'] == null
              ? defaultEnableFontAwesome
              // `java.lang.Boolean.parseBoolean`: anything but a
              // case-insensitive "true" is false, and nothing throws.
              : attrs['enableFontAwesome']!.toLowerCase() == 'true',
    );
  }

  static Color? _parseColor(String? text) {
    if (text == null) return null;
    final value = int.tryParse(text.replaceFirst('#', ''), radix: 16);
    if (value == null) return null;
    return Color(text.replaceFirst('#', '').length <= 6 ? 0xFF000000 | value : value);
  }
}

/// `ColorUtils.setAlpha(inactiveColor, 0.15f)`, applied to `?attr/contrast100`
/// in `init()` and never undone
/// (`charts-canvas-theming.ring-view-android#3`).
const double ringInactiveAlpha = 0.15;

/// The three layouts that put a `RingView` on screen
/// (`charts-canvas-theming.ring-view-android#10`).
class RingViewUsages {
  const RingViewUsages._();

  /// `show_habit_overview.xml`: 30dp square, `habit:thickness="5"`,
  /// `habit:textSize="12"`.
  static const double overviewSize = 30.0;
  static const double overviewThickness = 5.0;
  static const double overviewTextSize = 12.0;

  /// `HabitCardView.init`: `dp(15f)` square, `dp(3f)` thick, `dp(8f)`
  /// horizontal margins.
  static const double listCardSize = 15.0;
  static const double listCardThickness = 3.0;
  static const double listCardMargin = 8.0;

  /// `widget_checkmark.xml`: `habit:thickness="2"`, `habit:textSize="16"`,
  /// `habit:enableFontAwesome="true"`.
  static const double widgetThickness = 2.0;
  static const double widgetTextSize = 16.0;
  static const bool widgetEnableFontAwesome = true;
}

/// The Android `RingView`, as a widget.
///
/// `onMeasure` reports a square of `max(1, min(height, width))` whatever it is
/// asked for (`charts-canvas-theming.ring-view-android#1`), which is what the
/// [AspectRatio] below reproduces: a `RingView` given a 200x100 box paints a
/// 100x100 ring.
class RingView extends StatelessWidget {
  const RingView({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
    required this.inactiveColor,
    this.precision = RingViewAttributes.defaultPrecision,
    this.thickness = RingViewAttributes.defaultThickness,
    this.textSize = RingViewAttributes.defaultTextSize,
    this.text = RingViewAttributes.defaultText,
    this.enableFontAwesome = RingViewAttributes.defaultEnableFontAwesome,
    this.isStrokedTextEnabled = false,
    this.isTransparencyEnabled = false,
    super.key,
  });

  /// Builds one from a parsed attribute set, resolving the two colours the
  /// layout leaves null against [theme] exactly as `init()` does:
  /// `?attr/cardBgColor` and `?attr/contrast100` at 15% alpha.
  factory RingView.fromAttributes(
    RingViewAttributes attributes, {
    required core.Theme theme,
    bool isStrokedTextEnabled = false,
    bool isTransparencyEnabled = false,
    Key? key,
  }) {
    return RingView(
      key: key,
      percentage: attributes.percentage,
      precision: attributes.precision,
      color: attributes.color,
      backgroundColor:
          attributes.backgroundColor ?? _toFlutterColor(theme.cardBgColor),
      inactiveColor: applyInactiveAlpha(
        attributes.inactiveColor ?? _toFlutterColor(theme.contrast100),
      ),
      // `thickness = dpToPixels(ctx, thickness)`: the XML number is dp, and a
      // Flutter logical pixel already is one.
      thickness: attributes.thickness,
      textSize: attributes.textSize,
      text: attributes.text,
      enableFontAwesome: attributes.enableFontAwesome,
      isStrokedTextEnabled: isStrokedTextEnabled,
      isTransparencyEnabled: isTransparencyEnabled,
    );
  }

  /// `inactiveColor = setAlpha(inactiveColor!!, 0.15f)`.
  ///
  /// `ColorUtils.setAlpha` *truncates* — `(0.15f * 255).toInt()` is 38 — so the
  /// result is 38/255, not 0.15 exactly.
  static Color applyInactiveAlpha(Color color) =>
      color.withValues(alpha: (ringInactiveAlpha * 255).toInt() / 255.0);

  final double percentage;
  final double precision;
  final Color color;
  final Color backgroundColor;
  final Color inactiveColor;
  final double thickness;
  final double textSize;
  final String text;
  final bool enableFontAwesome;
  final bool isStrokedTextEnabled;
  final bool isTransparencyEnabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // `onMeasure` takes the *sizes* out of the two measure specs, so an
        // unbounded axis contributes its minimum here.
        final double diameter = RingViewPainter.diameterOf(
          Size(
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : constraints.minWidth,
            constraints.hasBoundedHeight
                ? constraints.maxHeight
                : constraints.minHeight,
          ),
        );
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox.square(
            dimension: diameter,
            child: _paint(),
          ),
        );
      },
    );
  }

  CustomPaint _paint() {
    return CustomPaint(
      painter: RingViewPainter(
        percentage: percentage,
        precision: precision,
        color: color,
        backgroundColor: backgroundColor,
        inactiveColor: inactiveColor,
        thickness: thickness,
        textSize: textSize,
        text: text,
        enableFontAwesome: enableFontAwesome,
        isStrokedTextEnabled: isStrokedTextEnabled,
        isTransparencyEnabled: isTransparencyEnabled,
      ),
    );
  }
}

/// `RingView.onDraw`, one statement at a time.
class RingViewPainter extends CustomPainter {
  const RingViewPainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
    required this.inactiveColor,
    required this.thickness,
    this.precision = RingViewAttributes.defaultPrecision,
    this.textSize = RingViewAttributes.defaultTextSize,
    this.text = RingViewAttributes.defaultText,
    this.enableFontAwesome = false,
    this.isStrokedTextEnabled = false,
    this.isTransparencyEnabled = false,
  });

  final double percentage;
  final double precision;
  final Color color;
  final Color backgroundColor;
  final Color inactiveColor;
  final double thickness;
  final double textSize;
  final String text;
  final bool enableFontAwesome;
  final bool isStrokedTextEnabled;
  final bool isTransparencyEnabled;

  /// `val angle = 360 * (percentage / precision).roundToLong() * precision`
  /// (`charts-canvas-theming.ring-view-android#4`).
  ///
  /// `roundToLong` is half-away-from-zero, like Dart's `round()`.
  double get sweepDegrees => 360 * (percentage / precision).round() * precision;

  /// `pRing.strokeWidth = textSize / 15f` when the text is stroked
  /// (`charts-canvas-theming.ring-view-android#7`).
  double get strokeTextWidth => textSize / 15.0;

  /// `em = pRing.measureText("M")` at the current text size, cached by
  /// `onMeasure` (`charts-canvas-theming.ring-view-android#1`).
  double measureEm() => _layout('M').width;

  /// `diameter = max(1, min(height, width))`.
  static double diameterOf(Size size) =>
      math.max(1.0, math.min(size.height, size.width));

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = diameterOf(size);
    final em = measureEm();

    // `if (isTransparencyEnabled) { … internalDrawingCache.eraseColor(
    // Color.TRANSPARENT) }`: an offscreen ARGB_8888 buffer that starts fully
    // transparent and is blitted onto the real canvas at the end
    // (`charts-canvas-theming.ring-view-android#8`).
    final layerBounds = Rect.fromLTWH(0, 0, diameter, diameter);
    if (isTransparencyEnabled) canvas.saveLayer(layerBounds, Paint());

    var rect = layerBounds;
    final angle = sweepDegrees;
    final paint = Paint()..isAntiAlias = true;

    // `activeCanvas.drawArc(rect, -90f, angle, true, pRing)` in the habit
    // colour, then the remainder in inactiveColor
    // (`charts-canvas-theming.ring-view-android#5`).
    canvas.drawArc(
      rect,
      _radians(-90),
      _radians(angle),
      true,
      paint..color = color,
    );
    canvas.drawArc(
      rect,
      _radians(angle - 90),
      _radians(360 - angle),
      true,
      paint..color = inactiveColor,
    );

    if (thickness > 0) {
      // `rect.inset(thickness, thickness)` — the *same* rect the text is then
      // centred in.
      rect = rect.deflate(thickness);
      canvas.drawArc(
        rect,
        0,
        _radians(360),
        true,
        isTransparencyEnabled
            // `pRing.xfermode = XFERMODE_CLEAR`: a true hole, not a repaint.
            ? (Paint()
              ..isAntiAlias = true
              ..blendMode = BlendMode.clear)
            : (paint..color = backgroundColor),
      );

      // `charts-canvas-theming.ring-view-android#6`: the label is drawn only
      // inside this branch, in the habit colour, centred at
      // (centerX, centerY + 0.4 * em) of the inset rect.
      final painter = _layout(
        text,
        foreground: isStrokedTextEnabled
            ? (Paint()
              ..isAntiAlias = true
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeTextWidth)
            : null,
      );
      painter.paint(
        canvas,
        Offset(
          rect.center.dx - painter.width / 2,
          rect.center.dy + 0.4 * em - painter.height / 2,
        ),
      );
    }

    if (isTransparencyEnabled) canvas.restore();
  }

  TextPainter _layout(String text, {Paint? foreground}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: foreground == null ? color : null,
          foreground: foreground,
          fontSize: textSize,
          // `if (enableFontAwesome) pRing.typeface = getFontAwesome(context)`.
          fontFamily: enableFontAwesome ? 'FontAwesome' : 'NotoSans',
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  /// `charts-canvas-theming.ring-view-android#9`, as a repaint predicate.
  ///
  /// Six setters call `invalidate()` — `setColor`, `setPercentage`,
  /// `setPrecision`, `setText`, `setThickness` and `setBackgroundColor` — and
  /// three do not: `setTextSize`, `setIsStrokedTextEnabled` and
  /// `setIsTransparencyEnabled`. A ring whose text size changes and nothing
  /// else therefore keeps the old drawing until something else invalidates it,
  /// and that is reproduced here rather than fixed.
  @override
  bool shouldRepaint(RingViewPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.percentage != percentage ||
      oldDelegate.precision != precision ||
      oldDelegate.text != text ||
      oldDelegate.thickness != thickness ||
      oldDelegate.backgroundColor != backgroundColor;

  static double _radians(double degrees) => degrees * math.pi / 180.0;
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
