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

  // -------------------------------------------------------------------------
  // The Android styled-resource attributes (res/values/attrs.xml)
  // -------------------------------------------------------------------------
  //
  // `charts-canvas-theming.android-contrast-attrs#1`: the legacy Android charts
  // — ScoreChart, FrequencyChart, StreakChart, TargetChart, RingView,
  // HeaderView, CheckmarkButtonView and NumberButtonView — never see a
  // `Theme` at all. They read `?attr/contrast60`, `?attr/cardBgColor` and the
  // rest off the activity's theme through `StyledResources`, and those
  // attributes are declared in styles.xml, not in Themes.kt.
  //
  // The two systems overlap but do not agree: `lowContrastTextColor` is
  // 0xE0E0E0 while `contrast40` is #D8D8D8, `cardBackgroundColor` is
  // TRANSPARENT under the widget theme while `cardBgColor` is #303030, and the
  // pure-black theme blackens the header attribute while leaving the Themes.kt
  // token at grey_900. A chart being ported from the Android side therefore has
  // to read the attribute, not the token — so both live here, side by side,
  // each keeping the name and the value of its own source file.

  /// `?attr/contrast0` — @color/white in the light theme.
  Color get contrast0 => const Color.fromRgb(0xFFFFFF);

  /// `?attr/contrast20` — @color/grey_300.
  Color get contrast20 => const Color.fromRgb(0xE0E0E0);

  /// `?attr/contrast40` — @color/grey_350. Note this is *not*
  /// [lowContrastTextColor] (0xE0E0E0), which is the Themes.kt token nearest
  /// to it.
  Color get contrast40 => const Color.fromRgb(0xD8D8D8);

  /// `?attr/contrast60` — @color/grey_500, the colour of every chart label.
  Color get contrast60 => const Color.fromRgb(0x9E9E9E);

  /// `?attr/contrast80` — @color/grey_700.
  Color get contrast80 => const Color.fromRgb(0x616161);

  /// `?attr/contrast100` — @color/grey_800.
  Color get contrast100 => const Color.fromRgb(0x424242);

  /// `?attr/cardBgColor` — @color/grey_50, the background a chart punches its
  /// marker holes with.
  Color get cardBgColor => const Color.fromRgb(0xFAFAFA);

  /// `?attr/windowBackgroundColor` — @color/grey_200.
  Color get windowBackgroundColor => const Color.fromRgb(0xEEEEEE);

  /// `?attr/highlightedBackgroundColor` — @color/grey_100, the background of a
  /// selected habit row.
  Color get highlightedBackgroundColor => const Color.fromRgb(0xF5F5F5);

  /// `?attr/headerBackgroundColor` — @color/grey_200.
  ///
  /// Deliberately *not* the same member as [headerBackgroundColor], which is
  /// the Themes.kt token of the same name. The two carry equal values in the
  /// light and dark themes and diverge in the pure-black one, where the
  /// attribute is black and the token stays grey_900; `HeaderView` reads the
  /// attribute and the KMP `HabitListHeader` reads the token.
  Color get attrHeaderBackgroundColor => const Color.fromRgb(0xEEEEEE);

  /// `?attr/aboutScreenColor` — @color/blue_800 (#1565C0) in `AppBaseTheme`.
  ///
  /// The blue accent `about.xml` and `about_translators.xml` write their card
  /// headers in, and — through the app's own `Preference.Category.Material`
  /// style, which points every `<PreferenceCategory>` at
  /// `res/layout/preference_category_custom.xml` — the colour of every settings
  /// category title as well. `AppBaseTheme` also aliases `colorAccent` to it.
  Color get aboutScreenColor => const Color.fromRgb(0x1565C0);

  /// `?attr/widgetShadowAlpha`, a float rather than a colour.
  double get widgetShadowAlpha => 0.25;

  /// The int-array `?attr/palette` points at, or null when the theme declares
  /// no `palette` attribute at all — which is what `StyledResources.getResource`
  /// reports as a resource id of -1
  /// (`charts-canvas-theming.android-contrast-attrs#8`).
  ///
  /// Every shipped variant declares one, so the null branch exists only for the
  /// sake of the exception it produces.
  List<Color>? get palette =>
      <Color>[for (var index = 0; index < 20; index++) color(index)];

  /// `R.attr.useHabitColorAsPrimary`. True in the light theme, false in both
  /// dark ones, where the toolbar takes [primaryColor] instead of the habit's
  /// palette colour (`charts-canvas-theming.android-contrast-attrs#2`, `#3`).
  bool get useHabitColorAsPrimary => true;

  /// `R.attr.colorPrimary`. Only consulted when [useHabitColorAsPrimary] is
  /// false; the light theme never reads it.
  Color get primaryColor => const Color.fromRgb(0xffffff);

  /// The toolbar background for a screen tinted by [habitColor], and the
  /// window status bar colour alongside it. Port of the branch in
  /// `ViewExtensions.setupToolbar` (`platform-glue.window-insets#6`).
  Color toolbarColorFor(Color habitColor) =>
      useHabitColorAsPrimary ? habitColor : primaryColor;

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
  /// `AppBaseThemeDark`'s attribute block
  /// (`charts-canvas-theming.android-contrast-attrs#3`).
  @override
  Color get contrast0 => const Color.fromRgb(0x212121);

  @override
  Color get contrast20 => const Color.fromRgb(0x424242);

  @override
  Color get contrast40 => const Color.fromRgb(0x525252);

  @override
  Color get contrast60 => const Color.fromRgb(0x9E9E9E);

  @override
  Color get contrast80 => const Color.fromRgb(0xE0E0E0);

  @override
  Color get contrast100 => const Color.fromRgb(0xF5F5F5);

  @override
  Color get cardBgColor => const Color.fromRgb(0x303030);

  @override
  Color get windowBackgroundColor => const Color.fromRgb(0x212121);

  @override
  Color get highlightedBackgroundColor => const Color.fromRgb(0x424242);

  @override
  Color get attrHeaderBackgroundColor => const Color.fromRgb(0x212121);

  /// `<item name="aboutScreenColor">@color/blue_300</item>` — #64B5F6, the
  /// lighter blue the dark styles accent with. `AppBaseThemeDark.PureBlack`
  /// restates no `aboutScreenColor`, so it inherits this one.
  @override
  Color get aboutScreenColor => const Color.fromRgb(0x64B5F6);

  /// `AppBaseThemeDark` sets useHabitColorAsPrimary=false, so the toolbar is
  /// grey_950 rather than the habit's colour.
  @override
  bool get useHabitColorAsPrimary => false;

  @override
  Color get primaryColor => const Color.fromRgb(0x101010);

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
  /// `AppBaseThemeDark.PureBlack` overrides colorPrimary to black
  /// (`settings.theme.pure-black#5`).
  @override
  Color get primaryColor => const Color.fromRgb(0x000000);

  @override
  Color get appBackgroundColor => const Color.fromRgb(0x000000);

  @override
  Color get cardBackgroundColor => const Color.fromRgb(0x000000);

  @override
  Color get lowContrastTextColor => const Color.fromRgb(0x212121);

  // `AppBaseThemeDark.PureBlack`'s attribute block
  // (`charts-canvas-theming.android-contrast-attrs#4`). It restates every
  // contrast level one step darker than the dark theme's, and blackens the four
  // background attributes. `palette` is not restated, so the dark palette is
  // inherited.

  @override
  Color get contrast0 => const Color.fromRgb(0x000000);

  @override
  Color get contrast20 => const Color.fromRgb(0x212121);

  @override
  Color get contrast40 => const Color.fromRgb(0x424242);

  @override
  Color get contrast60 => const Color.fromRgb(0x9E9E9E);

  @override
  Color get contrast80 => const Color.fromRgb(0xBDBDBD);

  @override
  Color get contrast100 => const Color.fromRgb(0xEEEEEE);

  @override
  Color get cardBgColor => const Color.fromRgb(0x000000);

  @override
  Color get windowBackgroundColor => const Color.fromRgb(0x000000);

  @override
  Color get highlightedBackgroundColor => const Color.fromRgb(0x000000);

  /// Black, where the Themes.kt [headerBackgroundColor] token stays grey_900.
  @override
  Color get attrHeaderBackgroundColor => const Color.fromRgb(0x000000);
}

/// Kotlin: `class WidgetTheme : LightTheme()`.
///
/// [cardBackgroundColor] being exactly [Color.TRANSPARENT] is load-bearing:
/// HistoryChart tests `theme.cardBackgroundColor == Color.TRANSPARENT` to
/// decide whether to skip its contrast comparison for day numbers, and
/// BarChart's background fill becomes a no-op.
class WidgetTheme extends LightTheme {
  // -------------------------------------------------------------------------
  // `<style name="WidgetTheme" parent="AppBaseThemeDark">`
  // (`charts-canvas-theming.android-contrast-attrs#5`)
  // -------------------------------------------------------------------------
  //
  // The attribute half of the widget theme inherits from the *dark* style,
  // while this class extends [LightTheme] because that is what `Themes.kt`
  // does. Everything AppBaseThemeDark contributes therefore has to be restated
  // below — contrast40, the window/header/highlight backgrounds and
  // useHabitColorAsPrimary — or the light values would leak in through the
  // Dart superclass.

  @override
  Color get contrast0 => Color.WHITE;

  /// `@color/white_a0` — #0fffffff, white at 15/255.
  @override
  Color get contrast20 => Color.WHITE.withAlpha(0x0F / 255.0);

  /// Not restated by the style, so grey_750 comes down from AppBaseThemeDark.
  @override
  Color get contrast40 => const Color.fromRgb(0x525252);

  /// `@color/white_aa` — #afffffff, white at 175/255.
  @override
  Color get contrast60 => Color.WHITE.withAlpha(0xAF / 255.0);

  @override
  Color get contrast80 => const Color.fromRgb(0x424242);

  @override
  Color get contrast100 => Color.WHITE;

  /// grey_850, where [cardBackgroundColor] — the Themes.kt token — is
  /// [Color.TRANSPARENT].
  @override
  Color get cardBgColor => const Color.fromRgb(0x303030);

  @override
  Color get windowBackgroundColor => const Color.fromRgb(0x212121);

  @override
  Color get highlightedBackgroundColor => const Color.fromRgb(0x424242);

  @override
  Color get attrHeaderBackgroundColor => const Color.fromRgb(0x212121);

  /// Not restated by the style either, so blue_300 comes down from
  /// AppBaseThemeDark. No widget layout reads it; it is here so that the
  /// class keeps saying what its Android parent says.
  @override
  Color get aboutScreenColor => const Color.fromRgb(0x64B5F6);

  @override
  bool get useHabitColorAsPrimary => false;

  /// `<item name="widgetShadowAlpha">0</item>`: a widget drawn over the user's
  /// wallpaper casts no shadow.
  @override
  double get widgetShadowAlpha => 0.0;

  /// `@array/transparentWidgetPalette`, the darker palette a widget needs to
  /// stay legible over a wallpaper.
  ///
  /// A third palette, distinct from both [color] (the `Themes.kt` widget
  /// palette) and from the light one the base class points at: the last three
  /// greys collapse into `@color/black_aa`, black at 175/255.
  @override
  List<Color>? get palette => <Color>[
        const Color.fromRgb(0xC62828), //  0 red_800
        const Color.fromRgb(0xD84315), //  1 deep_orange_800
        const Color.fromRgb(0xEF6C00), //  2 orange_800
        const Color.fromRgb(0xFF8F00), //  3 amber_800
        const Color.fromRgb(0xF9A825), //  4 yellow_800
        const Color.fromRgb(0x9E9D24), //  5 lime_800
        const Color.fromRgb(0x7CB342), //  6 light_green_600
        const Color.fromRgb(0x388E3C), //  7 green_700
        const Color.fromRgb(0x00796B), //  8 teal_700
        const Color.fromRgb(0x0097A7), //  9 cyan_700
        const Color.fromRgb(0x0288D1), // 10 light_blue_700
        const Color.fromRgb(0x1565C0), // 11 blue_800
        const Color.fromRgb(0x283593), // 12 indigo_800
        const Color.fromRgb(0x512DA8), // 13 deep_purple_700
        const Color.fromRgb(0x7B1FA2), // 14 purple_700
        const Color.fromRgb(0xC2185B), // 15 pink_700
        const Color.fromRgb(0x4E342E), // 16 brown_800
        Color.BLACK.withAlpha(0xAF / 255.0), // 17 black_aa
        Color.BLACK.withAlpha(0xAF / 255.0), // 18 black_aa
        Color.BLACK.withAlpha(0xAF / 255.0), // 19 black_aa
      ];

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
