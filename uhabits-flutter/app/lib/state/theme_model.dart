// Preferences are not re-exported from uhabits_core.dart yet; like
// app_scope.dart, this file reaches them by their `src` path.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../ui/theme/app_theme.dart';
import 'app_preferences.dart';

/// Port of `ThemeSwitcher` (uhabits-core) and `AndroidThemeSwitcher`
/// (uhabits-android), as a [ChangeNotifier].
///
/// Three theme modes exist — automatic, light and dark — and a separate
/// pure-black switch that applies on top of dark. All four values live in
/// [Preferences] (`pref_theme` and `pref_pure_black`); this class only decides
/// which [core.Theme] they add up to, and tells the widget tree when that
/// changes.
///
/// Two deliberate departures from Android:
///
///  * `getSystemTheme()` reads `MediaQuery.platformBrightness` instead of
///    `Configuration.uiMode`, and there is no `SDK_INT < 29` branch forcing
///    light (`settings.theme.theme-modes#5` is Android-only). The value is fed
///    in by [SystemBrightnessObserver] rather than read from a `Context`.
///  * Applying a theme rebuilds the widget tree in place. Android restarts the
///    activity with a fade (`settings.theme.toggle-night-mode#5`, `#7`, `#9`
///    and `settings.theme.pure-black#6`), which has no Flutter analogue — and
///    with it goes the quirk where a pure-black change only restarted the
///    activity while `theme == THEME_DARK`.
///
/// Installing a theme also re-declares the system chrome the Android style
/// declared: `AppBaseTheme` paints `android:navigationBarColor` #363636 and the
/// two dark styles leave it alone (`audit.the-light-theme-s-navigation-bar#1`).
/// That is [systemUiOverlayStyleFor], written through
/// [setSystemUiOverlayStyle] from [_install] — the point that corresponds to
/// `AndroidThemeSwitcher.applyLightTheme()`'s `setTheme(R.style.AppBaseTheme)`.
///
/// Wiring, for `main.dart`:
///
/// ```dart
/// ChangeNotifierProvider<ThemeModel>(
///   create: (_) => ThemeModel(scope.preferences),
///   child: Consumer<ThemeModel>(
///     builder: (context, themeModel, _) => MaterialApp(
///       theme: themeModel.lightThemeData,
///       darkTheme: themeModel.darkThemeData,
///       themeMode: themeModel.materialThemeMode,
///       builder: (context, child) => SystemBrightnessObserver(child: child!),
///       ...
///     ),
///   ),
/// )
/// ```
///
/// `theme`/`darkTheme`/`themeMode` are what actually paints the screen — the
/// follow-the-system case is then handled by `MaterialApp` itself, on the very
/// first frame. [currentTheme] is the same decision made explicitly, for the
/// charts and for the menu's "Dark theme" checkbox.
typedef SystemUiOverlayStyleSetter = void Function(SystemUiOverlayStyle style);

class ThemeModel extends ChangeNotifier {
  ThemeModel(
    this.preferences, {
    Brightness systemBrightness = Brightness.light,
    SystemUiOverlayStyleSetter? setSystemUiOverlayStyle,
  })  : _systemBrightness = systemBrightness,
        setSystemUiOverlayStyle =
            setSystemUiOverlayStyle ?? SystemChrome.setSystemUIOverlayStyle {
    // `ListHabitsActivity.onCreate` does two things with the preferences: it
    // applies the theme, and it takes a copy of `isPureBlackEnabled` so that
    // `onResume` can notice a change made in Settings and restart the activity
    // with a fade (`settings.theme.pure-black#6`). The port has no activity to
    // restart — this object *is* what paints, and it repaints in place — so
    // the copy-and-compare becomes a subscription: whoever writes `pref_theme`
    // or `pref_pure_black`, from wherever, the theme is re-applied and the
    // whole app comes back in it (`audit3.toggling-use-pure-black-background-in#1`).
    final preferences = this.preferences;
    if (preferences is AppPreferences) {
      preferences.addChangeListener(_onPreferenceChanged);
    }
  }

  /// `ThemeSwitcher.THEME_AUTOMATIC` — follow the system dark-mode setting.
  /// This is the default of `pref_theme`.
  static const int themeAutomatic = 0;

  /// `ThemeSwitcher.THEME_DARK`.
  static const int themeDark = 1;

  /// `ThemeSwitcher.THEME_LIGHT`.
  static const int themeLight = 2;

  /// The two keys `ThemeSwitcher.apply()` reads: `pref_theme`
  /// (`settings.theme.theme-modes#1`) and `pref_pure_black`
  /// (`settings.theme.pure-black#1`). A write to anything else changes nothing
  /// about which theme this model would choose.
  static const Set<String> themeKeys = <String>{
    'pref_theme',
    'pref_pure_black',
  };

  final Preferences preferences;

  /// How the chosen [SystemUiOverlayStyle] reaches the platform.
  ///
  /// `SystemChrome.setSystemUIOverlayStyle` in the app; a test passes its own,
  /// because the SDK call keeps a static `_latestStyle` and silently drops a
  /// repeat, which would make the order of the tests decide what they observe.
  final SystemUiOverlayStyleSetter setSystemUiOverlayStyle;

  Brightness _systemBrightness;

  /// `AndroidThemeSwitcher.currentTheme`, which starts as `LightTheme()`
  /// before any `apply()` (`settings.theme.theme-modes#6`).
  core.Theme _currentTheme = core.LightTheme();

  bool _hasApplied = false;

  core.Theme get currentTheme => _currentTheme;

  /// False until [apply] has run at least once, i.e. while [currentTheme] is
  /// still the initial `LightTheme()` rather than a computed one.
  bool get hasApplied => _hasApplied;

  /// The OS dark-mode setting, as last reported by [SystemBrightnessObserver].
  Brightness get systemBrightness => _systemBrightness;

  set systemBrightness(Brightness value) => setSystemBrightness(value);

  /// Records the OS dark-mode setting and re-applies the theme.
  ///
  /// Re-applies on the first call even when the value is unchanged, so that a
  /// stored `THEME_DARK` reaches [currentTheme] on the first frame.
  void setSystemBrightness(Brightness value) {
    if (_hasApplied && _systemBrightness == value) return;
    _systemBrightness = value;
    apply();
  }

  /// `AndroidThemeSwitcher.getSystemTheme()`.
  int getSystemTheme() =>
      _systemBrightness == Brightness.dark ? themeDark : themeLight;

  /// `pref_theme`: one of [themeAutomatic], [themeLight], [themeDark].
  int get theme => preferences.theme;

  set theme(int value) {
    if (preferences.theme == value) return;
    _write(() => preferences.theme = value);
    apply();
  }

  /// `pref_pure_black`, default false. Honoured only in night mode.
  bool get isPureBlackEnabled => preferences.isPureBlackEnabled;

  set isPureBlackEnabled(bool value) {
    if (preferences.isPureBlackEnabled == value) return;
    _write(() => preferences.isPureBlackEnabled = value);
    apply();
  }

  /// True while one of this model's own setters is writing a preference.
  ///
  /// Those setters apply the theme themselves, on the next line; without the
  /// flag the change callback would apply it a second time for the same write.
  bool _writing = false;

  void _write(void Function() write) {
    _writing = true;
    try {
      write();
    } finally {
      _writing = false;
    }
  }

  /// `SharedPreferencesStorage.onSharedPreferenceChanged`, narrowed to the two
  /// keys `apply()` reads.
  ///
  /// This is what replaces `ListHabitsActivity.onResume`'s
  /// `if (prefs.theme == THEME_DARK && prefs.isPureBlackEnabled != pureBlack)
  /// restartWithFade(...)`: the port repaints in place instead of restarting,
  /// and it does so for every writer rather than only for the settings screen
  /// (`audit3.toggling-use-pure-black-background-in#1`).
  void _onPreferenceChanged(String? key) {
    if (_writing) return;
    // A null key is a committed `clear()`, which takes `pref_theme` and
    // `pref_pure_black` back to their defaults along with everything else.
    if (key != null && !themeKeys.contains(key)) return;
    apply();
  }

  @override
  void dispose() {
    final preferences = this.preferences;
    if (preferences is AppPreferences) {
      preferences.removeChangeListener(_onPreferenceChanged);
    }
    super.dispose();
  }

  /// `ThemeSwitcher.isNightMode`. An explicit [themeLight] is never night mode,
  /// whatever the system says.
  bool get isNightMode {
    final systemTheme = getSystemTheme();
    final userTheme = preferences.theme;
    return userTheme == themeDark ||
        (systemTheme == themeDark && userTheme == themeAutomatic);
  }

  /// `ThemeSwitcher.apply()`, plus the notification that stands in for the
  /// activity restart.
  void apply() {
    if (isNightMode) {
      if (preferences.isPureBlackEnabled) {
        applyPureBlackTheme();
      } else {
        applyDarkTheme();
      }
    } else {
      applyLightTheme();
    }
  }

  /// `AndroidThemeSwitcher.applyLightTheme()` — `setTheme(R.style.AppBaseTheme)`
  /// plus `currentTheme = LightTheme()`.
  ///
  /// The Android style is [appThemeData]; the one thing it declares that a
  /// `ThemeData` cannot carry is `android:navigationBarColor`, and [_install]
  /// writes that (`audit.the-light-theme-s-navigation-bar#1`).
  void applyLightTheme() => _install(core.LightTheme());

  /// `AndroidThemeSwitcher.applyDarkTheme()`.
  void applyDarkTheme() => _install(core.DarkTheme());

  /// `AndroidThemeSwitcher.applyPureBlackTheme()`.
  void applyPureBlackTheme() => _install(core.PureBlackTheme());

  void _install(core.Theme theme) {
    _currentTheme = theme;
    _hasApplied = true;
    // `setTheme(R.style.AppBaseTheme)`'s `android:navigationBarColor`. Null for
    // the two dark styles, which declare no such attribute and therefore leave
    // the platform default in place (`audit.the-light-theme-s-navigation-bar#1`).
    final style = systemUiOverlayStyleFor(theme);
    if (style != null) setSystemUiOverlayStyle(style);
    notifyListeners();
  }

  /// `ThemeSwitcher.toggleNightMode()` followed by
  /// `ListHabitsScreen.applyTheme()`, which is how the overflow menu's "Dark
  /// theme" item is handled (`ListHabitsMenuBehavior.onToggleNightMode`).
  ///
  /// The cycle has three stops and lands back on automatic only when the
  /// resulting appearance matches the system setting.
  void toggleNightMode() {
    final systemTheme = getSystemTheme();
    final userTheme = preferences.theme;
    // The write is this model's own, and `apply()` below is its repaint, so
    // the change callback stays out of it.
    _write(() {
      if (userTheme == themeAutomatic) {
        if (systemTheme == themeLight) preferences.theme = themeDark;
        if (systemTheme == themeDark) preferences.theme = themeLight;
      } else if (userTheme == themeLight) {
        if (systemTheme == themeLight) preferences.theme = themeDark;
        if (systemTheme == themeDark) preferences.theme = themeAutomatic;
      } else if (userTheme == themeDark) {
        if (systemTheme == themeLight) preferences.theme = themeAutomatic;
        if (systemTheme == themeDark) preferences.theme = themeLight;
      }
    });
    apply();
  }

  // ---------------------------------------------------------------------
  // The Material side
  // ---------------------------------------------------------------------

  /// The theme built from [currentTheme].
  ThemeData get themeData => appThemeData(_currentTheme);

  /// `MaterialApp.theme`.
  ThemeData get lightThemeData => appThemeData(core.LightTheme());

  /// `MaterialApp.darkTheme`: the pure-black variant replaces the dark one when
  /// the preference is on, exactly as `apply()` chooses it.
  ThemeData get darkThemeData => appThemeData(
        preferences.isPureBlackEnabled
            ? core.PureBlackTheme()
            : core.DarkTheme(),
      );

  /// `MaterialApp.themeMode`. Automatic is `ThemeMode.system`, which is what
  /// "automatic" has always meant here: follow the system dark-mode setting,
  /// with no time-of-day component.
  ThemeMode get materialThemeMode {
    switch (preferences.theme) {
      case themeDark:
        return ThemeMode.dark;
      case themeLight:
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}

/// Feeds `MediaQuery.platformBrightness` into [ThemeModel.systemBrightness].
///
/// This is the Flutter replacement for `AndroidThemeSwitcher.getSystemTheme()`
/// reading `resources.configuration.uiMode`: the OS setting is only visible
/// below the app widget, so the model is told about it from the tree instead of
/// reaching for it. Mount it in `MaterialApp.builder` — the model is read from
/// the nearest provider unless one is passed explicitly.
///
/// It also guarantees the first [ThemeModel.apply] happens, so a stored dark
/// preference reaches the charts on the first frame.
class SystemBrightnessObserver extends StatefulWidget {
  const SystemBrightnessObserver({super.key, this.model, required this.child});

  /// Defaults to `context.read<ThemeModel>()`.
  final ThemeModel? model;

  final Widget child;

  @override
  State<SystemBrightnessObserver> createState() =>
      _SystemBrightnessObserverState();
}

class _SystemBrightnessObserverState extends State<SystemBrightnessObserver> {
  @override
  Widget build(BuildContext context) {
    final model = widget.model ?? context.read<ThemeModel>();
    final brightness = MediaQuery.platformBrightnessOf(context);
    // Applying notifies, and notifying rebuilds this widget, so the write is
    // both deferred out of the build phase and guarded by the same condition
    // setSystemBrightness uses: the second pass finds nothing to do.
    if (!model.hasApplied || model.systemBrightness != brightness) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        model.setSystemBrightness(brightness);
      });
    }
    return widget.child;
  }
}
