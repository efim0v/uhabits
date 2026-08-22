import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/color.dart';

/// Rules from docs/parity/FEATURES.md:
///   charts-canvas-theming.color-model
///   charts-canvas-theming.color-utils
///
/// No Kotlin unit tests exist for either; the cases below are derived from the
/// rules and from the Kotlin sources
///   uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Color.kt
///   uhabits-android/src/main/java/org/isoron/platform/gui/AndroidImage.kt
///   uhabits-android/src/main/java/org/isoron/uhabits/utils/ColorUtils.kt
/// plus the Skia RGB<->HSV routines that android.graphics.Color delegates to.
void main() {
  group('charts-canvas-theming.color-model', () {
    test('#1 immutable value of four doubles: red, green, blue, alpha', () {
      const c = Color(0.1, 0.2, 0.3, 0.4);
      expect(c.red, 0.1, reason: 'charts-canvas-theming.color-model#1');
      expect(c.green, 0.2, reason: 'charts-canvas-theming.color-model#1');
      expect(c.blue, 0.3, reason: 'charts-canvas-theming.color-model#1');
      expect(c.alpha, 0.4, reason: 'charts-canvas-theming.color-model#1');

      // Equality is componentwise on all four channels.
      expect(c, const Color(0.1, 0.2, 0.3, 0.4),
          reason: 'charts-canvas-theming.color-model#1');
      expect(c.hashCode, const Color(0.1, 0.2, 0.3, 0.4).hashCode,
          reason: 'charts-canvas-theming.color-model#1');
      expect(c == const Color(0.9, 0.2, 0.3, 0.4), isFalse,
          reason: 'charts-canvas-theming.color-model#1');
      expect(c == const Color(0.1, 0.9, 0.3, 0.4), isFalse,
          reason: 'charts-canvas-theming.color-model#1');
      expect(c == const Color(0.1, 0.2, 0.9, 0.4), isFalse,
          reason: 'charts-canvas-theming.color-model#1');
      expect(c == const Color(0.1, 0.2, 0.3, 0.9), isFalse,
          reason: 'charts-canvas-theming.color-model#1');

      // Immutable: every derived operation returns a new value and leaves the
      // receiver untouched.
      final derived = c.withAlpha(1.0).blendWith(Color.WHITE, 0.5);
      expect(derived == c, isFalse,
          reason: 'charts-canvas-theming.color-model#1');
      expect(c, const Color(0.1, 0.2, 0.3, 0.4),
          reason: 'charts-canvas-theming.color-model#1');
    });

    test('#2 the Int constructor ignores the top byte and forces alpha=1', () {
      expect(Color.fromRgb(0xFF0000), const Color(1.0, 0.0, 0.0, 1.0),
          reason: 'charts-canvas-theming.color-model#2');
      expect(Color.fromRgb(0x00FF00), const Color(0.0, 1.0, 0.0, 1.0),
          reason: 'charts-canvas-theming.color-model#2');
      expect(Color.fromRgb(0x0000FF), const Color(0.0, 0.0, 1.0, 1.0),
          reason: 'charts-canvas-theming.color-model#2');

      final c = Color.fromRgb(0x123456);
      expect(c.red, 0x12 / 255.0,
          reason: 'charts-canvas-theming.color-model#2');
      expect(c.green, 0x34 / 255.0,
          reason: 'charts-canvas-theming.color-model#2');
      expect(c.blue, 0x56 / 255.0,
          reason: 'charts-canvas-theming.color-model#2');
      expect(c.alpha, 1.0, reason: 'charts-canvas-theming.color-model#2');

      // The top byte of rgb is ignored: an opaque, a transparent and a bare
      // 24-bit literal all produce the same Color.
      expect(Color.fromRgb(0xFF123456), c,
          reason: 'charts-canvas-theming.color-model#2');
      expect(Color.fromRgb(0x00123456), c,
          reason: 'charts-canvas-theming.color-model#2');
      expect(Color.fromRgb(0xAB123456), c,
          reason: 'charts-canvas-theming.color-model#2');
    });

    test('#3 luminosity is 0.21*r + 0.72*g + 0.07*b, ungamma-ed, alpha-free',
        () {
      expect(const Color(1.0, 0.0, 0.0, 1.0).luminosity, 0.21,
          reason: 'charts-canvas-theming.color-model#3');
      expect(const Color(0.0, 1.0, 0.0, 1.0).luminosity, 0.72,
          reason: 'charts-canvas-theming.color-model#3');
      expect(const Color(0.0, 0.0, 1.0, 1.0).luminosity, 0.07,
          reason: 'charts-canvas-theming.color-model#3');
      expect(const Color(0.0, 0.0, 0.0, 1.0).luminosity, 0.0,
          reason: 'charts-canvas-theming.color-model#3');
      expect(const Color(1.0, 1.0, 1.0, 1.0).luminosity, closeTo(1.0, 1e-12),
          reason: 'charts-canvas-theming.color-model#3');

      // No gamma correction: mid grey is 0.5, not sRGB-linearised ~0.21.
      expect(const Color(0.5, 0.5, 0.5, 1.0).luminosity, closeTo(0.5, 1e-12),
          reason: 'charts-canvas-theming.color-model#3');

      // No alpha term: alpha does not enter the formula at all.
      expect(const Color(0.4, 0.5, 0.6, 0.0).luminosity,
          const Color(0.4, 0.5, 0.6, 1.0).luminosity,
          reason: 'charts-canvas-theming.color-model#3');
    });

    test('#4 blendWith interpolates all four channels and does not clamp', () {
      const from = Color(0.0, 0.0, 0.0, 0.0);
      const to = Color(1.0, 1.0, 1.0, 1.0);
      expect(from.blendWith(to, 0.25), const Color(0.25, 0.25, 0.25, 0.25),
          reason: 'charts-canvas-theming.color-model#4');
      expect(from.blendWith(to, 0.0), from,
          reason: 'charts-canvas-theming.color-model#4');
      expect(from.blendWith(to, 1.0), to,
          reason: 'charts-canvas-theming.color-model#4');

      // Alpha is blended too, not carried over from the receiver.
      expect(const Color(0.0, 0.0, 0.0, 1.0)
          .blendWith(const Color(0.0, 0.0, 0.0, 0.0), 0.5)
          .alpha,
          0.5,
          reason: 'charts-canvas-theming.color-model#4');

      // Componentwise this*(1-weight) + other*weight, per channel.
      const a = Color(0.2, 0.4, 0.6, 0.8);
      const b = Color(0.6, 0.8, 0.2, 0.4);
      final blended = a.blendWith(b, 0.5);
      expect(blended.red, a.red * 0.5 + b.red * 0.5,
          reason: 'charts-canvas-theming.color-model#4');
      expect(blended.green, a.green * 0.5 + b.green * 0.5,
          reason: 'charts-canvas-theming.color-model#4');
      expect(blended.blue, a.blue * 0.5 + b.blue * 0.5,
          reason: 'charts-canvas-theming.color-model#4');
      expect(blended.alpha, a.alpha * 0.5 + b.alpha * 0.5,
          reason: 'charts-canvas-theming.color-model#4');

      // weight is not clamped to 0..1 and the result is not clamped to 0..1.
      expect(from.blendWith(to, 2.0), const Color(2.0, 2.0, 2.0, 2.0),
          reason: 'charts-canvas-theming.color-model#4');
      expect(from.blendWith(to, -1.0), const Color(-1.0, -1.0, -1.0, -1.0),
          reason: 'charts-canvas-theming.color-model#4');
    });

    test('#5 contrast is (l+0.05) ratio, always >= 1 and symmetric', () {
      // (1.0 + 0.05) / (0.0 + 0.05) == 21
      expect(Color.WHITE.contrast(Color.BLACK), closeTo(21.0, 1e-9),
          reason: 'charts-canvas-theming.color-model#5');

      // Symmetric: the reciprocal branch gives the same ratio back.
      expect(Color.BLACK.contrast(Color.WHITE),
          closeTo(Color.WHITE.contrast(Color.BLACK), 1e-9),
          reason: 'charts-canvas-theming.color-model#5');

      // Always >= 1, whichever way round the arguments go.
      const dark = Color(0.1, 0.1, 0.1, 1.0);
      const light = Color(0.9, 0.9, 0.9, 1.0);
      expect(dark.contrast(light), greaterThanOrEqualTo(1.0),
          reason: 'charts-canvas-theming.color-model#5');
      expect(light.contrast(dark), greaterThanOrEqualTo(1.0),
          reason: 'charts-canvas-theming.color-model#5');
      expect(light.contrast(dark), closeTo(dark.contrast(light), 1e-9),
          reason: 'charts-canvas-theming.color-model#5');

      // A colour against itself has ratio exactly 1.
      expect(light.contrast(light), 1.0,
          reason: 'charts-canvas-theming.color-model#5');
      expect(Color.TRANSPARENT.contrast(Color.BLACK), 1.0,
          reason: 'charts-canvas-theming.color-model#5');

      // The exact formula, spelled out.
      const other = Color(0.25, 0.5, 0.75, 1.0);
      expect(light.contrast(other),
          closeTo((light.luminosity + 0.05) / (other.luminosity + 0.05), 1e-12),
          reason: 'charts-canvas-theming.color-model#5');
    });

    test('#6 withAlpha keeps rgb and replaces alpha', () {
      const c = Color(0.1, 0.2, 0.3, 0.4);
      expect(c.withAlpha(0.9), const Color(0.1, 0.2, 0.3, 0.9),
          reason: 'charts-canvas-theming.color-model#6');
      expect(c.withAlpha(0.0), const Color(0.1, 0.2, 0.3, 0.0),
          reason: 'charts-canvas-theming.color-model#6');
      // The receiver is untouched.
      expect(c.alpha, 0.4, reason: 'charts-canvas-theming.color-model#6');
    });

    test('#7 companion constants, including the BLUE == MAGENTA defect', () {
      expect(Color.TRANSPARENT, const Color(0.0, 0.0, 0.0, 0.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.RED, const Color(1.0, 0.0, 0.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.GREEN, const Color(0.0, 1.0, 0.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.YELLOW, const Color(1.0, 1.0, 0.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.MAGENTA, const Color(1.0, 0.0, 1.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.CYAN, const Color(0.0, 1.0, 1.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.WHITE, const Color(1.0, 1.0, 1.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.BLACK, const Color(0.0, 0.0, 0.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');

      // Upstream defect, deliberately preserved: BLUE is declared as
      // Color(1.0, 0.0, 1.0, 1.0) and is therefore identical to MAGENTA.
      expect(Color.BLUE, const Color(1.0, 0.0, 1.0, 1.0),
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.BLUE, Color.MAGENTA,
          reason: 'charts-canvas-theming.color-model#7');
      expect(Color.BLUE == const Color(0.0, 0.0, 1.0, 1.0), isFalse,
          reason: 'charts-canvas-theming.color-model#7');
    });

    test('#8 toInt packs ARGB with rounding, not truncation', () {
      expect(Color.WHITE.toInt(), 0xFFFFFFFF,
          reason: 'charts-canvas-theming.color-model#8');
      expect(Color.BLACK.toInt(), 0xFF000000,
          reason: 'charts-canvas-theming.color-model#8');
      expect(Color.TRANSPARENT.toInt(), 0x00000000,
          reason: 'charts-canvas-theming.color-model#8');
      expect(Color.RED.toInt(), 0xFFFF0000,
          reason: 'charts-canvas-theming.color-model#8');
      expect(Color.GREEN.toInt(), 0xFF00FF00,
          reason: 'charts-canvas-theming.color-model#8');
      expect(Color.CYAN.toInt(), 0xFF00FFFF,
          reason: 'charts-canvas-theming.color-model#8');

      // Channels land in the right bit positions, in a-r-g-b order.
      expect(Color.fromRgb(0x123456).toInt(), 0xFF123456,
          reason: 'charts-canvas-theming.color-model#8');
      expect(const Color(0.0, 0.0, 0.0, 0.5).toInt(), 0x80000000,
          reason: 'charts-canvas-theming.color-model#8');

      // roundToInt, not truncation: 255 * 0.5 == 127.5 rounds up to 128.
      expect(const Color(0.5, 0.5, 0.5, 0.5).toInt(), 0x80808080,
          reason: 'charts-canvas-theming.color-model#8');
      // 255 * 0.4 == 102.0, 255 * 0.7 == 178.5 -> 179 (0xB3).
      expect(const Color(0.4, 0.7, 0.4, 1.0).toInt(), 0xFF66B366,
          reason: 'charts-canvas-theming.color-model#8');
    });
  });

  group('charts-canvas-theming.color-utils', () {
    test('#1 mixColors blends all four ARGB channels, weighting color1', () {
      // amount weights color1, not color2.
      expect(ColorUtils.mixColors(0xFF000000, 0xFFFFFFFF, 1.0), 0xFF000000,
          reason: 'charts-canvas-theming.color-utils#1');
      expect(ColorUtils.mixColors(0xFF000000, 0xFFFFFFFF, 0.0), 0xFFFFFFFF,
          reason: 'charts-canvas-theming.color-utils#1');

      // Each channel is blended independently, then OR-ed back together.
      expect(ColorUtils.mixColors(0xFF000000, 0xFF0000FF, 0.5), 0xFF00007F,
          reason: 'charts-canvas-theming.color-utils#1');
      expect(ColorUtils.mixColors(0x00FFFFFF, 0xFFFFFFFF, 0.5), 0x7FFFFFFF,
          reason: 'charts-canvas-theming.color-utils#1');
      expect(ColorUtils.mixColors(0xFF33B5E5, 0xFFFF0000, 0.25), 0xFFCC2D39,
          reason: 'charts-canvas-theming.color-utils#1');

      // ".toInt() and 0xff" — the mask, not a clamp: an out-of-range amount
      // wraps the channel instead of saturating it. Blue 200 * 2.0 == 400,
      // 400 & 0xff == 0x90.
      expect(ColorUtils.mixColors(0xFF0000C8, 0xFF000000, 2.0), 0xFF000090,
          reason: 'charts-canvas-theming.color-utils#1');
    });

    test('#2 setAlpha truncates the alpha instead of rounding it', () {
      // (0.5 * 255).toInt() == 127, not 128.
      expect(ColorUtils.setAlpha(0xFF123456, 0.5), 0x7F123456,
          reason: 'charts-canvas-theming.color-utils#2');
      expect(ColorUtils.setAlpha(0x00123456, 1.0), 0xFF123456,
          reason: 'charts-canvas-theming.color-utils#2');
      expect(ColorUtils.setAlpha(0xFF123456, 0.0), 0x00123456,
          reason: 'charts-canvas-theming.color-utils#2');
      // red/green/blue survive untouched; only the top byte changes.
      expect(ColorUtils.setAlpha(0x11FF8800, 0.5) & 0x00FFFFFF, 0x00FF8800,
          reason: 'charts-canvas-theming.color-utils#2');
    });

    test('#3 changeHue rotates the hue with a non-negative mod 360', () {
      // Pure blue is hue 240; +180 degrees is yellow.
      expect(ColorUtils.changeHue(0xFF0000FF, 180.0), 0xFFFFFF00,
          reason: 'charts-canvas-theming.color-utils#3');
      // A zero delta round-trips through HSV unchanged.
      expect(ColorUtils.changeHue(0xFF0000FF, 0.0), 0xFF0000FF,
          reason: 'charts-canvas-theming.color-utils#3');

      // Kotlin's mod is always non-negative, so a negative delta is the same
      // as its positive complement — this is the ListHabitsScreen -20 case.
      expect(ColorUtils.changeHue(0xFFFF0000, -20.0),
          ColorUtils.changeHue(0xFFFF0000, 340.0),
          reason: 'charts-canvas-theming.color-utils#3');
      expect(ColorUtils.changeHue(0xFFFF0000, -20.0), 0xFFFF0055,
          reason: 'charts-canvas-theming.color-utils#3');
      expect(ColorUtils.changeHue(0xFF1976D2, -180.0),
          ColorUtils.changeHue(0xFF1976D2, 180.0),
          reason: 'charts-canvas-theming.color-utils#3');
      expect(ColorUtils.changeHue(0xFF1976D2, 180.0), 0xFFD27519,
          reason: 'charts-canvas-theming.color-utils#3');
      expect(ColorUtils.changeHue(0xFFFF0000, 20.0), 0xFFFF5500,
          reason: 'charts-canvas-theming.color-utils#3');

      // android.graphics.Color.HSVToColor(hsv) hardcodes alpha 0xFF, so the
      // input alpha is dropped. Upstream behaviour, preserved as-is.
      expect(ColorUtils.changeHue(0x800000FF, 180.0), 0xFFFFFF00,
          reason: 'charts-canvas-theming.color-utils#3');
    });

    test('#4 setMinValue raises V to max(v, newValue), keeping H and S', () {
      // Black has H=0, S=0; raising V to 0.5 gives mid grey (round(127.5)=128).
      expect(ColorUtils.setMinValue(0xFF000000, 0.5), 0xFF808080,
          reason: 'charts-canvas-theming.color-utils#4');
      // Already brighter than newValue: max() leaves it alone.
      expect(ColorUtils.setMinValue(0xFFFF0000, 0.5), 0xFFFF0000,
          reason: 'charts-canvas-theming.color-utils#4');
      // Hue and saturation are preserved; only V moves.
      expect(ColorUtils.setMinValue(0xFF400000, 0.5), 0xFF800000,
          reason: 'charts-canvas-theming.color-utils#4');
      expect(ColorUtils.setMinValue(0xFF1976D2, 0.9), 0xFF1B81E6,
          reason: 'charts-canvas-theming.color-utils#4');
      // HSVToColor drops alpha here too.
      expect(ColorUtils.setMinValue(0x80404040, 0.75), 0xFFBFBFBF,
          reason: 'charts-canvas-theming.color-utils#4');
    });

    test('#5 packed-int mixColors and normalised blendWith are inverted', () {
      // FrequencyChart's 4-step ramp: colors[0]=grid, colors[3]=primary.
      const grid = 0xFF000000;
      const primary = 0xFFFFFFFF;
      final ramp = <int>[
        grid,
        ColorUtils.mixColors(grid, primary, 0.66),
        ColorUtils.mixColors(grid, primary, 0.33),
        primary,
      ];
      expect(ramp[1], 0xFF565656,
          reason: 'charts-canvas-theming.color-utils#5');
      expect(ramp[2], 0xFFAAAAAA,
          reason: 'charts-canvas-theming.color-utils#5');

      // RingView's inactive colour.
      expect(ColorUtils.setAlpha(0xFF33B5E5, 0.15), 0x2633B5E5,
          reason: 'charts-canvas-theming.color-utils#5');

      // The two conventions are inverted: amount=1.0 gives mixColors' FIRST
      // argument, whereas weight=1.0 gives blendWith's OTHER colour.
      expect(ColorUtils.mixColors(0xFF000000, 0xFFFFFFFF, 1.0), 0xFF000000,
          reason: 'charts-canvas-theming.color-utils#5');
      expect(Color.BLACK.blendWith(Color.WHITE, 1.0), Color.WHITE,
          reason: 'charts-canvas-theming.color-utils#5');
      // At 0.25 the packed helper stays near black's counterpart (white),
      // while blendWith stays near black itself.
      expect(ColorUtils.mixColors(0xFF000000, 0xFFFFFFFF, 0.25), 0xFFBFBFBF,
          reason: 'charts-canvas-theming.color-utils#5');
      expect(Color.BLACK.blendWith(Color.WHITE, 0.25),
          const Color(0.25, 0.25, 0.25, 1.0),
          reason: 'charts-canvas-theming.color-utils#5');
    });

    test('#6 mixColors channel formula, bit offsets and float truncation', () {
      // Bit offsets 24 alpha, 16 red, 8 green, 0 blue: isolate each one by
      // mixing a colour that differs from black in exactly one channel.
      expect(ColorUtils.mixColors(0x00000000, 0xFF000000, 0.0), 0xFF000000,
          reason: 'charts-canvas-theming.color-utils#6');
      expect(ColorUtils.mixColors(0x00000000, 0x00FF0000, 0.0), 0x00FF0000,
          reason: 'charts-canvas-theming.color-utils#6');
      expect(ColorUtils.mixColors(0x00000000, 0x0000FF00, 0.0), 0x0000FF00,
          reason: 'charts-canvas-theming.color-utils#6');
      expect(ColorUtils.mixColors(0x00000000, 0x000000FF, 0.0), 0x000000FF,
          reason: 'charts-canvas-theming.color-utils#6');

      // amount=1.0 returns color1's channels, amount=0.0 returns color2's.
      expect(ColorUtils.mixColors(0x11223344, 0xAABBCCDD, 1.0), 0x11223344,
          reason: 'charts-canvas-theming.color-utils#6');
      expect(ColorUtils.mixColors(0x11223344, 0xAABBCCDD, 0.0), 0xAABBCCDD,
          reason: 'charts-canvas-theming.color-utils#6');

      // Truncated toward zero, not rounded: 0 * 0.5 + 255 * 0.5 == 127.5 -> 127.
      expect(ColorUtils.mixColors(0xFF000000, 0xFFFFFFFF, 0.5), 0xFF7F7F7F,
          reason: 'charts-canvas-theming.color-utils#6');

      // The arithmetic is done in 32-bit floats, exactly as Kotlin's Float
      // does: 50f * (1f - 0.66f) == 16.999998 -> 16, whereas the same
      // expression in doubles yields 17.0 -> 17.
      expect(ColorUtils.mixColors(0xFF000000, 0xFF000032, 0.66), 0xFF000010,
          reason: 'charts-canvas-theming.color-utils#6');
    });

    test('#7 setAlpha(color, 0.5) yields alpha 127', () {
      expect(ColorUtils.setAlpha(0x00FFFFFF, 0.5) >> 24 & 0xff, 127,
          reason: 'charts-canvas-theming.color-utils#7');
      expect(ColorUtils.setAlpha(0x00FFFFFF, 0.15) >> 24 & 0xff, 38,
          reason: 'charts-canvas-theming.color-utils#7');
      expect(ColorUtils.setAlpha(0x00FFFFFF, 1.0) >> 24 & 0xff, 255,
          reason: 'charts-canvas-theming.color-utils#7');
      expect(ColorUtils.setAlpha(0x00FFFFFF, 0.0) >> 24 & 0xff, 0,
          reason: 'charts-canvas-theming.color-utils#7');
    });
  });
}
