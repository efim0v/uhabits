import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// | aboutScreenColor          | colorAccent — switch/radio/checkbox tint |
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

/// `AppBaseTheme`'s `colorPrimary`, the literal `#363636` in
/// `res/values/styles.xml`.
///
/// It is not one of the core `Theme` tokens: `Themes.kt` never names it, and
/// the closest neighbours — `statusBarBackgroundColor` (#333333) and
/// `toolbarColor` (#ffffff) — are a different pair of values used for a
/// different surface. The Android light theme points
/// `android:navigationBarColor` at it and nothing else does, so it lives here
/// as the constant it is upstream.
const Color navigationBarColorLight = Color(0xFF363636);

/// `@style/DialogButtonStyle`'s `android:textColor` — `@color/grey_100`.
///
/// `AppBaseThemeDark` points `buttonBarPositiveButtonStyle` and
/// `buttonBarNegativeButtonStyle` at that style, and `AppBaseThemeDark.
/// PureBlack` inherits the pair. It is the one control the dark themes take
/// *off* `colorAccent` (`audit4.coloraccent-aboutscreencolor-is-never-mapped-
/// so#1`), and it is a literal upstream rather than a theme token, so it is one
/// here too.
const Color dialogButtonColorDark = Color(0xFFF5F5F5);

/// The `SwitchCompat` track's opacity.
///
/// AppCompat tints `abc_switch_track_mtrl_alpha` with `colorControlActivated`
/// and the drawable carries ~30% alpha, which is what makes a checked switch a
/// solid accent thumb riding a pale accent track. Flutter's `Switch` paints the
/// two from `thumbColor` and `trackColor` instead, so the alpha has to be
/// applied here.
const double switchTrackOpacity = 0.3;

/// A [WidgetStateProperty] that answers [color] only while the control is
/// activated, and defers to the widget's own default otherwise.
///
/// This is `colorControlActivated`: an Android theme attribute tints the
/// *checked* state of a compound button and leaves the unchecked one to
/// `colorControlNormal`, which the port already supplies as
/// `unselectedWidgetColor`.
WidgetStateProperty<Color?> _whenSelected(Color color) =>
    WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) =>
        states.contains(WidgetState.selected) ? color : null);

/// The system-UI overlay style a core [theme] installs, or null when it
/// installs none.
///
/// `AppBaseTheme` declares the `android:navigationBarColor` item as
/// `?attr/colorPrimary`; `AppBaseThemeDark` and `AppBaseThemeDark.PureBlack`
/// deliberately do not, leaving the platform default in place
/// (`audit.the-light-theme-s-navigation-bar#1`). Null here is that same
/// silence, and so are the null fields of the style itself: the Android
/// embedding only touches a system-bar property the style actually names, so
/// the status bar, the divider and the icon brightness stay where the platform
/// put them, exactly as an undeclared attribute leaves them.
///
/// Applied by `ThemeModel._install`, which is where the port installs a theme —
/// `AndroidThemeSwitcher.applyLightTheme()`'s `setTheme(R.style.AppBaseTheme)`.
SystemUiOverlayStyle? systemUiOverlayStyleFor(core.Theme theme) {
  // PureBlackTheme extends DarkTheme, so the one check covers both dark styles.
  if (theme is core.DarkTheme) return null;
  return const SystemUiOverlayStyle(
    systemNavigationBarColor: navigationBarColorLight,
  );
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

  // `<item name="colorAccent">?aboutScreenColor</item>`, declared by
  // AppBaseTheme and AppBaseThemeDark alike — blue_800 (#1565C0) in the light
  // theme, blue_300 (#64B5F6) in both dark ones, which
  // AppBaseThemeDark.PureBlack inherits because it restates neither
  // (`audit4.coloraccent-aboutscreencolor-is-never-mapped-so#1`). It is
  // deliberately the same token the About card headers and the Settings
  // category headers read, so the screens read as one palette.
  //
  // It is NOT colorScheme.primary: that is the toolbar (#333333), and pointing
  // Material's accent role at it would repaint the toolbar with every control's
  // colour or the controls with the toolbar's. The three controls the attribute
  // actually tints are named one by one below instead.
  final colorAccent = toFlutterColor(theme.aboutScreenColor);

  // `buttonBarPositiveButtonStyle` / `buttonBarNegativeButtonStyle`: the light
  // theme leaves the dialog buttons on colorAccent; both dark themes override
  // them with @style/DialogButtonStyle.
  final dialogButtonColor =
      brightness == Brightness.dark ? dialogButtonColorDark : colorAccent;

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
    // The three compound controls `colorAccent` tints when activated: the seven
    // SwitchPreferenceCompat rows in Settings, the five radio buttons in the
    // frequency picker, and — the same attribute, the same rule — a checkbox.
    switchTheme: SwitchThemeData(
      thumbColor: _whenSelected(colorAccent),
      trackColor: _whenSelected(
        colorAccent.withValues(alpha: switchTrackOpacity),
      ),
    ),
    radioTheme: RadioThemeData(fillColor: _whenSelected(colorAccent)),
    checkboxTheme: CheckboxThemeData(fillColor: _whenSelected(colorAccent)),
    // The dialog buttons. Upstream the override is on
    // `buttonBarPositiveButtonStyle` / `buttonBarNegativeButtonStyle` rather
    // than on every borderless button, but every `TextButton` this app builds
    // is a dialog action, so the two sets are the same set here.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: dialogButtonColor),
    ),
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
