import '../models/palette_color.dart';
import 'color.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Themes.kt.
///
/// A [Theme] is a flat bag of colour and size tokens plus a 20-entry habit
/// palette. Charts read tokens straight off the theme instance they were given,
/// so the values below are load-bearing for every golden image.
///
/// Kotlin marks each colour token `open val` and each size token a plain `val`;
/// the Dart equivalent is an overridable getter for the former and a final
/// field for the latter.
abstract class Theme {
  Color get appBackgroundColor => const Color.fromRgb(0xf4f4f4);

  Color get cardBackgroundColor => const Color.fromRgb(0xFAFAFA);

  Color get headerBackgroundColor => const Color.fromRgb(0xeeeeee);

  Color get headerBorderColor => const Color.fromRgb(0xcccccc);

  Color get headerTextColor => const Color.fromRgb(0x9E9E9E);

  Color get highContrastTextColor => const Color.fromRgb(0x202020);

  Color get itemBackgroundColor => const Color.fromRgb(0xffffff);

  Color get lowContrastTextColor => const Color.fromRgb(0xe0e0e0);

  Color get mediumContrastTextColor => const Color.fromRgb(0x9E9E9E);

  Color get statusBarBackgroundColor => const Color.fromRgb(0x333333);

  Color get toolbarBackgroundColor => const Color.fromRgb(0xf4f4f4);

  Color get toolbarColor => const Color.fromRgb(0xffffff);

  /// Kotlin: the non-`open` overload `fun color(paletteColor: PaletteColor)`.
  /// Dart has no constructor/method overloading, hence the separate name; the
  /// delegation to the overridable [color] is the whole point of the helper.
  Color colorOf(PaletteColor paletteColor) => color(paletteColor.paletteIndex);

  /// Kotlin: `open fun color(paletteIndex: Int)`. Out-of-range indices fall
  /// back to black rather than throwing — unlike [PaletteColor.toCsvColor],
  /// which does throw.
  Color color(int paletteIndex) {
    switch (paletteIndex) {
      case 0:
        return const Color.fromRgb(0xD32F2F);
      case 1:
        return const Color.fromRgb(0xE64A19);
      case 2:
        return const Color.fromRgb(0xF57C00);
      case 3:
        return const Color.fromRgb(0xFF8F00);
      case 4:
        return const Color.fromRgb(0xF9A825);
      case 5:
        return const Color.fromRgb(0xAFB42B);
      case 6:
        return const Color.fromRgb(0x7CB342);
      case 7:
        return const Color.fromRgb(0x388E3C);
      case 8:
        return const Color.fromRgb(0x00897B);
      case 9:
        return const Color.fromRgb(0x00ACC1);
      case 10:
        return const Color.fromRgb(0x039BE5);
      case 11:
        return const Color.fromRgb(0x1976D2);
      case 12:
        return const Color.fromRgb(0x303F9F);
      case 13:
        return const Color.fromRgb(0x5E35B1);
      case 14:
        return const Color.fromRgb(0x8E24AA);
      case 15:
        return const Color.fromRgb(0xD81B60);
      case 16:
        return const Color.fromRgb(0x5D4037);
      case 17:
        return const Color.fromRgb(0x424242);
      case 18:
        return const Color.fromRgb(0x757575);
      case 19:
        return const Color.fromRgb(0x9E9E9E);
      default:
        return const Color.fromRgb(0x000000);
    }
  }

  /// Logical units, and the same in every variant: Kotlin declares these as
  /// plain (non-`open`) `val`s on the base class.
  final double checkmarkButtonSize = 48.0;
  final double smallTextSize = 10.0;
  final double regularTextSize = 17.0;
}

/// Kotlin: `open class LightTheme : Theme()` — deliberately empty, so the base
/// values above *are* the light theme.
class LightTheme extends Theme {}

/// Kotlin: `open class DarkTheme : Theme()`.
///
/// Note that seven of the twelve tokens are re-declared with exactly the light
/// values (headerBorderColor, headerTextColor, itemBackgroundColor,
/// mediumContrastTextColor, statusBarBackgroundColor, toolbarBackgroundColor
/// and toolbarColor). They are kept here rather than dropped, so the Kotlin
/// source and this file stay line-for-line comparable.
class DarkTheme extends Theme {
  @override
  Color get appBackgroundColor => const Color.fromRgb(0x212121);

  @override
  Color get cardBackgroundColor => const Color.fromRgb(0x303030);

  @override
  Color get headerBackgroundColor => const Color.fromRgb(0x212121);

  @override
  Color get headerBorderColor => const Color.fromRgb(0xcccccc);

  @override
  Color get headerTextColor => const Color.fromRgb(0x9E9E9E);

  @override
  Color get highContrastTextColor => const Color.fromRgb(0xF5F5F5);

  @override
  Color get itemBackgroundColor => const Color.fromRgb(0xffffff);

  @override
  Color get lowContrastTextColor => const Color.fromRgb(0x424242);

  @override
  Color get mediumContrastTextColor => const Color.fromRgb(0x9E9E9E);

  @override
  Color get statusBarBackgroundColor => const Color.fromRgb(0x333333);

  @override
  Color get toolbarBackgroundColor => const Color.fromRgb(0xf4f4f4);

  @override
  Color get toolbarColor => const Color.fromRgb(0xffffff);

  /// Out-of-range indices fall back to white here, not black.
  @override
  Color color(int paletteIndex) {
    switch (paletteIndex) {
      case 0:
        return const Color.fromRgb(0xEF9A9A);
      case 1:
        return const Color.fromRgb(0xFFAB91);
      case 2:
        return const Color.fromRgb(0xFFCC80);
      case 3:
        return const Color.fromRgb(0xFFECB3);
      case 4:
        return const Color.fromRgb(0xFFF59D);
      case 5:
        return const Color.fromRgb(0xE6EE9C);
      case 6:
        return const Color.fromRgb(0xC5E1A5);
      case 7:
        return const Color.fromRgb(0x69F0AE);
      case 8:
        return const Color.fromRgb(0x80CBC4);
      case 9:
        return const Color.fromRgb(0x80DEEA);
      case 10:
        return const Color.fromRgb(0x81D4FA);
      case 11:
        return const Color.fromRgb(0x64B5F6);
      case 12:
        return const Color.fromRgb(0x9FA8DA);
      case 13:
        return const Color.fromRgb(0xB39DDB);
      case 14:
        return const Color.fromRgb(0xCE93D8);
      case 15:
        return const Color.fromRgb(0xF48FB1);
      case 16:
        return const Color.fromRgb(0xBCAAA4);
      case 17:
        return const Color.fromRgb(0xF5F5F5);
      case 18:
        return const Color.fromRgb(0xE0E0E0);
      case 19:
        return const Color.fromRgb(0x9E9E9E);
      default:
        return const Color.fromRgb(0xFFFFFF);
    }
  }
}

/// Kotlin: `class PureBlackTheme : DarkTheme()` — final, and it touches only
/// three tokens. The palette and every other token come from [DarkTheme].
final class PureBlackTheme extends DarkTheme {
  @override
  Color get appBackgroundColor => const Color.fromRgb(0x000000);

  @override
  Color get cardBackgroundColor => const Color.fromRgb(0x000000);

  @override
  Color get lowContrastTextColor => const Color.fromRgb(0x212121);
}

/// Kotlin: `class WidgetTheme : LightTheme()`.
///
/// [cardBackgroundColor] being exactly [Color.TRANSPARENT] is load-bearing:
/// HistoryChart tests `theme.cardBackgroundColor == Color.TRANSPARENT` to
/// decide whether to skip its contrast comparison for day numbers, and
/// BarChart's background fill becomes a no-op.
class WidgetTheme extends LightTheme {
  @override
  Color get cardBackgroundColor => Color.TRANSPARENT;

  @override
  Color get highContrastTextColor => Color.WHITE;

  @override
  Color get mediumContrastTextColor => Color.WHITE.withAlpha(0.50);

  @override
  Color get lowContrastTextColor => Color.WHITE.withAlpha(0.10);

  /// The light palette with two substitutions: a brighter indigo at 12 and a
  /// lighter dark grey at 17, both needed to stay legible over a home-screen
  /// wallpaper.
  @override
  Color color(int paletteIndex) {
    switch (paletteIndex) {
      case 0:
        return const Color.fromRgb(0xD32F2F);
      case 1:
        return const Color.fromRgb(0xE64A19);
      case 2:
        return const Color.fromRgb(0xF57C00);
      case 3:
        return const Color.fromRgb(0xFF8F00);
      case 4:
        return const Color.fromRgb(0xF9A825);
      case 5:
        return const Color.fromRgb(0xAFB42B);
      case 6:
        return const Color.fromRgb(0x7CB342);
      case 7:
        return const Color.fromRgb(0x388E3C);
      case 8:
        return const Color.fromRgb(0x00897B);
      case 9:
        return const Color.fromRgb(0x00ACC1);
      case 10:
        return const Color.fromRgb(0x039BE5);
      case 11:
        return const Color.fromRgb(0x1976D2);
      case 12:
        return const Color.fromRgb(0x6275f0);
      case 13:
        return const Color.fromRgb(0x5E35B1);
      case 14:
        return const Color.fromRgb(0x8E24AA);
      case 15:
        return const Color.fromRgb(0xD81B60);
      case 16:
        return const Color.fromRgb(0x5D4037);
      case 17:
        return const Color.fromRgb(0x757575);
      case 18:
        return const Color.fromRgb(0x757575);
      case 19:
        return const Color.fromRgb(0x9E9E9E);
      default:
        return const Color.fromRgb(0x000000);
    }
  }
}

/// The habit colour used when nothing else is specified: teal, index 8.
///
/// Kotlin declares it inline as the default value of `Habit.color`
/// (`var color: PaletteColor = PaletteColor(8)`); it lives here until the
/// Habit model is ported, because the palette is the thing that gives it
/// meaning.
const PaletteColor defaultPaletteColor = PaletteColor(8);
