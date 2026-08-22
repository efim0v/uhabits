// The Kotlin originals use SCREAMING_CASE for their companion constants and
// for ColorUtils' channel offsets. Keeping those names makes the port
// traceable back to the Kotlin sources, which matters more here than the Dart
// naming lint.
// ignore_for_file: constant_identifier_names

import 'dart:typed_data';
import 'dart:math' as math;

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Color.kt,
/// plus the `Color.toInt()` extension from
/// uhabits-android/src/main/java/org/isoron/platform/gui/AndroidImage.kt.
///
/// An immutable colour of four normalised channels. The Kotlin original is a
/// `data class`, so equality is componentwise on all four fields.
class Color {
  const Color(this.red, this.green, this.blue, this.alpha);

  /// The Kotlin secondary constructor `Color(rgb: Int)`. Dart has no
  /// constructor overloading, hence the name.
  ///
  /// The top byte of [rgb] is ignored — alpha is always 1.0 — so
  /// `Color.fromRgb(0xFF0000)` is opaque red.
  const Color.fromRgb(int rgb)
      : red = ((rgb >> 16) & 0xFF) / 255.0,
        green = ((rgb >> 8) & 0xFF) / 255.0,
        blue = ((rgb >> 0) & 0xFF) / 255.0,
        alpha = 1.0;

  final double red;
  final double green;
  final double blue;
  final double alpha;

  /// Perceived brightness. Deliberately naive: no gamma correction and no
  /// alpha term, exactly as upstream.
  double get luminosity => 0.21 * red + 0.72 * green + 0.07 * blue;

  /// Componentwise linear interpolation towards [other]. Note that [weight]
  /// weights [other], not the receiver, and that it is not clamped: values
  /// outside 0..1 extrapolate, and the resulting channels may leave 0..1.
  ///
  /// Alpha is interpolated along with the colour channels.
  Color blendWith(Color other, double weight) {
    return Color(
      red * (1 - weight) + other.red * weight,
      green * (1 - weight) + other.green * weight,
      blue * (1 - weight) + other.blue * weight,
      alpha * (1 - weight) + other.alpha * weight,
    );
  }

  /// The WCAG-style contrast ratio between this colour and [other], computed
  /// from the naive [luminosity] above. Always >= 1 and symmetric:
  /// `a.contrast(b) == b.contrast(a)`.
  ///
  /// HistoryChart uses this to choose the day-number text colour, so the exact
  /// formula is user-visible.
  double contrast(Color other) {
    final l1 = luminosity;
    final l2 = other.luminosity;
    final relativeLuminosity = (l1 + 0.05) / (l2 + 0.05);
    return relativeLuminosity >= 1 ? relativeLuminosity : 1 / relativeLuminosity;
  }

  Color withAlpha(double newAlpha) => Color(red, green, blue, newAlpha);

  /// Packs the colour into a 32-bit ARGB integer, rounding each channel.
  ///
  /// Unlike the Kotlin/Java original this returns an unsigned value
  /// (0..0xFFFFFFFF) rather than a sign-extended 32-bit int, matching the
  /// convention already used elsewhere in this package for packed colours.
  int toInt() {
    return _argb(
      (255 * alpha).round(),
      (255 * red).round(),
      (255 * green).round(),
      (255 * blue).round(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Color &&
      other.red == red &&
      other.green == green &&
      other.blue == blue &&
      other.alpha == alpha;

  @override
  int get hashCode => Object.hash(red, green, blue, alpha);

  @override
  String toString() =>
      'Color(red=$red, green=$green, blue=$blue, alpha=$alpha)';

  static const Color TRANSPARENT = Color(0.0, 0.0, 0.0, 0.0);
  static const Color RED = Color(1.0, 0.0, 0.0, 1.0);
  static const Color GREEN = Color(0.0, 1.0, 0.0, 1.0);

  /// Upstream defect, preserved deliberately: BLUE is declared as
  /// `Color(1.0, 0.0, 1.0, 1.0)` in Color.kt and is therefore identical to
  /// [MAGENTA]. Nothing in the drawing layer reads BLUE today, so "fixing" it
  /// would change no pixel — but it would break traceability, so it stays.
  static const Color BLUE = Color(1.0, 0.0, 1.0, 1.0);
  static const Color YELLOW = Color(1.0, 1.0, 0.0, 1.0);
  static const Color MAGENTA = Color(1.0, 0.0, 1.0, 1.0);
  static const Color CYAN = Color(0.0, 1.0, 1.0, 1.0);
  static const Color WHITE = Color(1.0, 1.0, 1.0, 1.0);
  static const Color BLACK = Color(0.0, 0.0, 0.0, 1.0);
}

/// Port of uhabits-android/src/main/java/org/isoron/uhabits/utils/ColorUtils.kt.
///
/// These helpers operate on packed ARGB integers, not on [Color]. Beware: the
/// two conventions are inverted. `ColorUtils.mixColors(a, b, amount)` weights
/// `a` by `amount`, whereas `a.blendWith(b, weight)` weights `b` by `weight`.
///
/// The Kotlin code does its arithmetic in 32-bit `Float`s and truncates the
/// result toward zero. Dart has no `float`, so [_f32] rounds intermediate
/// values to single precision after every operation; without it the packed
/// channels differ from Android by one unit in roughly 0.5% of inputs.
class ColorUtils {
  ColorUtils._();

  static const int ALPHA_CHANNEL = 24;
  static const int RED_CHANNEL = 16;
  static const int GREEN_CHANNEL = 8;
  static const int BLUE_CHANNEL = 0;

  /// Blends each ARGB channel of [color1] and [color2] independently.
  /// `amount == 1.0` returns [color1], `amount == 0.0` returns [color2].
  static int mixColors(int color1, int color2, double amount) {
    final a = _mixColorChannel(color1, color2, amount, ALPHA_CHANNEL);
    final r = _mixColorChannel(color1, color2, amount, RED_CHANNEL);
    final g = _mixColorChannel(color1, color2, amount, GREEN_CHANNEL);
    final b = _mixColorChannel(color1, color2, amount, BLUE_CHANNEL);
    return a | r | g | b;
  }

  /// Rotates the hue of [color] by [delta] degrees. The rotation uses Kotlin's
  /// `mod`, which is always non-negative, so a delta of -20 is the same as 340.
  ///
  /// Note that `android.graphics.Color.HSVToColor(hsv)` hardcodes alpha to
  /// 0xFF, so the input alpha is dropped. Upstream behaviour, kept as-is.
  static int changeHue(int color, double delta) {
    final hsv = colorToHsv(color);
    hsv[0] = _mod(_f32(hsv[0] + _f32(delta)), 360.0);
    return hsvToColor(hsv);
  }

  /// Replaces the alpha channel of [color]. The float-to-int conversion
  /// truncates, so `newAlpha == 0.5` yields alpha 127, not 128.
  static int setAlpha(int color, double newAlpha) {
    final intAlpha = _f32(_f32(newAlpha) * 255.0).toInt();
    return _argb(
      intAlpha,
      (color >> RED_CHANNEL) & 0xFF,
      (color >> GREEN_CHANNEL) & 0xFF,
      (color >> BLUE_CHANNEL) & 0xFF,
    );
  }

  /// Raises the V (value) component of [color] to at least [newValue], leaving
  /// hue and saturation alone. Like [changeHue], the result is opaque.
  static int setMinValue(int color, double newValue) {
    final hsv = colorToHsv(color);
    hsv[2] = math.max(hsv[2], _f32(newValue));
    return hsvToColor(hsv);
  }

  static int _mixColorChannel(
      int color1, int color2, double amount, int channel) {
    final a = _f32(amount);
    final fl = _f32(((color1 >> channel) & 0xff).toDouble() * a);
    final f2 = _f32(((color2 >> channel) & 0xff).toDouble() * _f32(1.0 - a));
    return (_f32(fl + f2).toInt() & 0xff) << channel;
  }

  /// The RGB -> HSV conversion that `android.graphics.Color.colorToHSV`
  /// delegates to (Skia's `SkRGBToHSV`). Returns `[hue, saturation, value]`
  /// with hue in `[0, 360)` and the other two in `[0, 1]`.
  static Float32List colorToHsv(int color) {
    final r = (color >> RED_CHANNEL) & 0xFF;
    final g = (color >> GREEN_CHANNEL) & 0xFF;
    final b = (color >> BLUE_CHANNEL) & 0xFF;

    final min = math.min(r, math.min(g, b));
    final max = math.max(r, math.max(g, b));
    final delta = max - min;

    final hsv = Float32List(3);
    final v = _f32(max / 255.0);
    if (delta == 0) {
      // A shade of grey: hue and saturation are undefined, reported as zero.
      hsv[0] = 0.0;
      hsv[1] = 0.0;
      hsv[2] = v;
      return hsv;
    }

    final s = _f32(delta / max);
    double h;
    if (r == max) {
      h = _f32((g - b) / delta);
    } else if (g == max) {
      h = _f32(2.0 + _f32((b - r) / delta));
    } else {
      h = _f32(4.0 + _f32((r - g) / delta));
    }
    h = _f32(h * 60.0);
    if (h < 0) h = _f32(h + 360.0);

    hsv[0] = h;
    hsv[1] = s;
    hsv[2] = v;
    return hsv;
  }

  /// The HSV -> RGB conversion that `android.graphics.Color.HSVToColor`
  /// delegates to (Skia's `SkHSVToColor`). Alpha is always 0xFF, matching the
  /// single-argument Android overload that ColorUtils calls.
  static int hsvToColor(List<double> hsv) {
    final s = _f32(hsv[1].clamp(0.0, 1.0).toDouble());
    final v = _f32(hsv[2].clamp(0.0, 1.0).toDouble());
    final vByte = _roundToInt(_f32(v * 255.0));

    // SK_ScalarNearlyZero == 1 / (1 << 12).
    if (s.abs() < 1.0 / (1 << 12)) {
      return _argb(0xFF, vByte, vByte, vByte);
    }

    final hx = (hsv[0] < 0 || hsv[0] >= 360.0) ? 0.0 : _f32(hsv[0] / 60.0);
    final w = hx.floorToDouble();
    final f = _f32(hx - w);

    final p = _roundToInt(_f32(_f32(_f32(1.0 - s) * v) * 255.0));
    final q = _roundToInt(_f32(_f32(_f32(1.0 - _f32(s * f)) * v) * 255.0));
    final t = _roundToInt(
        _f32(_f32(_f32(1.0 - _f32(s * _f32(1.0 - f))) * v) * 255.0));

    final int r;
    final int g;
    final int b;
    switch (w.toInt()) {
      case 0:
        r = vByte;
        g = t;
        b = p;
      case 1:
        r = q;
        g = vByte;
        b = p;
      case 2:
        r = p;
        g = vByte;
        b = t;
      case 3:
        r = p;
        g = q;
        b = vByte;
      case 4:
        r = t;
        g = p;
        b = vByte;
      default:
        r = vByte;
        g = p;
        b = q;
    }
    return _argb(0xFF, r, g, b);
  }

  /// Kotlin's `Float.mod(Float)`: the result carries the sign of the divisor,
  /// so it is always non-negative for a positive [other].
  static double _mod(double value, double other) {
    final r = _f32(value % other);
    if (r != 0.0 && r.sign != other.sign) return _f32(r + other);
    return r;
  }

  /// Skia's `SkScalarRoundToInt`: floor(x + 0.5), i.e. ties go up.
  static int _roundToInt(double x) => (x + 0.5).floor();
}

/// android.graphics.Color.argb, minus Java's sign extension.
int _argb(int alpha, int red, int green, int blue) {
  return (alpha << 24) | (red << 16) | (green << 8) | blue;
}

final Float32List _f32Scratch = Float32List(1);

/// Rounds [value] to the nearest 32-bit float, so that a chain of Dart double
/// arithmetic reproduces Kotlin `Float` arithmetic bit for bit.
double _f32(double value) {
  _f32Scratch[0] = value;
  return _f32Scratch[0];
}
