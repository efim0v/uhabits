import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

/// The bridge between the ported [core.Theme] and Flutter's [ThemeData].
///
/// Android keeps two descriptions of the same palette: the XML styles
/// (`AppBaseTheme`, `AppBaseThemeDark`, `AppBaseThemeDark.PureBlack` in
/// `res/values/styles.xml`) colour the widgets, while `Themes.kt` colours the
/// charts. This file collapses them into one: the core theme owns the values,
/// and [appThemeData] turns whichever variant `AndroidThemeSwitcher` would have
/// installed into the `ThemeData` the whole app is built from.
///
/// The mapping, token by token:
///
/// | core token                | ThemeData                                |
/// |---------------------------|------------------------------------------|
/// | appBackgroundColor        | scaffoldBackgroundColor, canvasColor     |
/// | cardBackgroundColor       | cardColor, colorScheme.surface, dialogs  |
/// | highContrastTextColor     | colorScheme.onSurface, text colours      |
/// | mediumContrastTextColor   | icons, hints, unselected controls        |
/// | lowContrastTextColor      | dividerColor                             |
/// | statusBarBackgroundColor  | colorScheme.primary — the toolbar        |
/// | toolbarColor              | colorScheme.onPrimary — on the toolbar   |
/// | colorOf(defaultPalette)   | colorScheme.secondary                    |
/// | color(0)                  | colorScheme.error — the palette red      |
///
/// `statusBarBackgroundColor` (0x333333) and `toolbarColor` (0xffffff) are the
/// two tokens `Themes.kt` names after the toolbar, and together they reproduce
/// the Android light theme's `colorPrimary` (#363636) with white icons on it.
/// Individual screens still tint their own toolbar with the habit's colour —
/// `setupToolbar(color = ...)` in `ViewExtensions.kt` — so this is the fallback
/// rather than the last word.

/// Converts a core colour into a Flutter one, rounding each 0..1 channel to a
/// byte. The core [core.Color] carries alpha, and so does the result.
Color toFlutterColor(core.Color color) {
  return Color.fromARGB(
    (color.alpha * 255).round().clamp(0, 255),
    (color.red * 255).round().clamp(0, 255),
    (color.green * 255).round().clamp(0, 255),
    (color.blue * 255).round().clamp(0, 255),
  );
}

/// Carries the [core.Theme] a [ThemeData] was built from, so a widget hosting a
/// chart can read the exact palette the surrounding Material widgets use.
///
/// It has to travel on the `ThemeData` rather than be re-derived from
/// [Brightness]: `DarkTheme` and `PureBlackTheme` are both dark, and only the
/// theme object itself says which of the two is on screen.
@immutable
class CoreThemeExtension extends ThemeExtension<CoreThemeExtension> {
  const CoreThemeExtension(this.theme);

  final core.Theme theme;

  @override
  CoreThemeExtension copyWith({core.Theme? theme}) =>
      CoreThemeExtension(theme ?? this.theme);

  /// A [core.Theme] is a bag of tokens with no interpolation of its own, so the
  /// two ends are swapped halfway through Material's theme crossfade. The
  /// colours the Material widgets animate come from the [ThemeData] fields,
  /// which lerp normally; this only decides which palette the charts read.
  @override
  CoreThemeExtension lerp(ThemeExtension<CoreThemeExtension>? other, double t) {
    if (other is! CoreThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// The core theme behind the ambient [ThemeData].
///
/// Falls back to [core.LightTheme] / [core.DarkTheme] chosen by brightness, so
/// it also works under a `ThemeData` that did not come from [appThemeData] —
/// which is what the habit list and the list header do today.
core.Theme coreThemeOf(BuildContext context) {
  final data = Theme.of(context);
  final extension = data.extension<CoreThemeExtension>();
  if (extension != null) return extension.theme;
  return data.brightness == Brightness.dark
      ? core.DarkTheme()
      : core.LightTheme();
}

/// Builds the Material theme for a core [theme].
///
/// Pass [core.LightTheme], [core.DarkTheme] or [core.PureBlackTheme] — the
/// three variants `ThemeSwitcher.apply()` chooses between
/// (`settings.theme.theme-modes#4`).
ThemeData appThemeData(core.Theme theme) {
  // PureBlackTheme extends DarkTheme, so the single type check covers both dark
  // variants; WidgetTheme extends LightTheme and stays light.
  final brightness =
      theme is core.DarkTheme ? Brightness.dark : Brightness.light;

  final appBackground = toFlutterColor(theme.appBackgroundColor);
  final card = toFlutterColor(theme.cardBackgroundColor);
  final highContrast = toFlutterColor(theme.highContrastTextColor);
  final mediumContrast = toFlutterColor(theme.mediumContrastTextColor);
  final lowContrast = toFlutterColor(theme.lowContrastTextColor);
  final toolbar = toFlutterColor(theme.statusBarBackgroundColor);
  final onToolbar = toFlutterColor(theme.toolbarColor);
  final accent = toFlutterColor(theme.colorOf(core.defaultPaletteColor));

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: toolbar,
    onPrimary: onToolbar,
    secondary: accent,
    onSecondary: onToolbar,
    // Index 0 of the palette is the red the app already uses for destructive
    // actions and for the lowest scores.
    error: toFlutterColor(theme.color(0)),
    onError: onToolbar,
    surface: card,
    onSurface: highContrast,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: appBackground,
    canvasColor: appBackground,
    cardColor: card,
    dividerColor: lowContrast,
    hintColor: mediumContrast,
    unselectedWidgetColor: mediumContrast,
    appBarTheme: AppBarThemeData(
      backgroundColor: toolbar,
      foregroundColor: onToolbar,
      // `toolbar.elevation = dp(2f)` in ViewExtensions.setupToolbar.
      elevation: 2,
      scrolledUnderElevation: 2,
    ),
    cardTheme: CardThemeData(color: card),
    dialogTheme: DialogThemeData(backgroundColor: card),
    dividerTheme: DividerThemeData(color: lowContrast),
    iconTheme: IconThemeData(color: mediumContrast),
    listTileTheme: ListTileThemeData(
      textColor: highContrast,
      iconColor: mediumContrast,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: toolbar,
      foregroundColor: onToolbar,
    ),
    extensions: <ThemeExtension<dynamic>>[CoreThemeExtension(theme)],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: highContrast,
      displayColor: highContrast,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: onToolbar,
      displayColor: onToolbar,
    ),
  );
}
