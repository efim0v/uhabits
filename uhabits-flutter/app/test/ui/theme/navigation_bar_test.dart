/// `audit.the-light-theme-s-navigation-bar`: the system navigation bar tint.
///
/// `res/values/styles.xml` declares `<item name="android:navigationBarColor">`
/// on `AppBaseTheme` only, pointing at that style's `colorPrimary` — the
/// literal `#363636`. `AppBaseThemeDark` and `AppBaseThemeDark.PureBlack` leave
/// the attribute undeclared, so the dark themes keep the platform default. The
/// asymmetry is a deliberate theme declaration, and it survives here as one
/// call to `SystemChrome.setSystemUIOverlayStyle` made from the place the port
/// installs a theme — `ThemeModel._install`, the counterpart of
/// `AndroidThemeSwitcher.applyLightTheme()`'s `setTheme(R.style.AppBaseTheme)`.
///
/// The style is written through an injected sink rather than straight onto the
/// platform channel so the assertions can read what was written: `SystemChrome`
/// keeps a static `_latestStyle` and drops a repeat, which would make an
/// order-dependent mess of "light, then dark, then light again". The last test
/// in this file pins the sink's default to the real SDK call, so the seam
/// cannot quietly become a no-op.
library;

// ignore_for_file: implementation_imports

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/theme_model.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const String rule1 =
    'audit.the-light-theme-s-navigation-bar#1 — In the Kotlin app: In the '
    'light theme every activity\'s system navigation bar is painted #363636, '
    'matching the dark toolbar chrome; the dark themes leave it at the '
    'platform default. The asymmetry is a deliberate theme declaration, not an '
    'accident.';

const String rule2 =
    'audit.the-light-theme-s-navigation-bar#2 — The port must do the same. '
    'Today it does this instead: Nothing — the port never calls '
    '`SystemChrome.setSystemUIOverlayStyle`; the only SystemChrome use in '
    'app/lib is `setEnabledSystemUIMode` in app/lib/ui/intro/intro_screen.dart. '
    'The navigation bar keeps whatever the Flutter embedding default is, in '
    'both themes.';

void main() {
  /// Every style [ThemeModel] wrote, in order.
  late List<SystemUiOverlayStyle> written;

  ThemeModel model({
    int theme = ThemeModel.themeAutomatic,
    bool pureBlack = false,
    Brightness system = Brightness.light,
  }) {
    final Preferences preferences = Preferences(MemoryStorage())
      ..theme = theme
      ..isPureBlackEnabled = pureBlack;
    return ThemeModel(
      preferences,
      systemBrightness: system,
      setSystemUiOverlayStyle: written.add,
    );
  }

  setUp(() => written = <SystemUiOverlayStyle>[]);

  group('audit.the-light-theme-s-navigation-bar', () {
    test('#1 #2 installing the light theme paints the navigation bar #363636',
        () {
      model(theme: ThemeModel.themeLight).apply();

      expect(written, hasLength(1), reason: '$rule1 $rule2');
      expect(written.single.systemNavigationBarColor, const Color(0xFF363636),
          reason: '$rule1 `AppBaseTheme` sets android:navigationBarColor to '
              '?attr/colorPrimary, which that style declares as #363636.');
    });

    test('#1 the dark themes declare nothing, so nothing is written', () {
      model(theme: ThemeModel.themeDark).apply();
      expect(written, isEmpty,
          reason: '$rule1 AppBaseThemeDark deliberately does not set '
              'android:navigationBarColor.');

      model(theme: ThemeModel.themeDark, pureBlack: true).apply();
      expect(written, isEmpty,
          reason: '$rule1 …and neither does AppBaseThemeDark.PureBlack.');
    });

    test('#1 automatic follows the system, and so does the navigation bar', () {
      model(theme: ThemeModel.themeAutomatic, system: Brightness.light).apply();
      expect(written.map((SystemUiOverlayStyle s) => s.systemNavigationBarColor),
          <Color>[const Color(0xFF363636)], reason: rule1);

      written.clear();
      model(theme: ThemeModel.themeAutomatic, system: Brightness.dark).apply();
      expect(written, isEmpty, reason: rule1);
    });

    test('#1 toggling back into the light theme re-applies the tint', () {
      final ThemeModel switcher = model(theme: ThemeModel.themeDark)..apply();
      expect(written, isEmpty, reason: rule1);

      switcher.theme = ThemeModel.themeLight;
      expect(written, hasLength(1),
          reason: '$rule1 Upstream re-declares the attribute by restarting the '
              'activity with the light style; the port re-installs the theme '
              'in place, which has to have the same effect.');
      expect(written.single.systemNavigationBarColor, const Color(0xFF363636),
          reason: rule1);
    });

    test('#1 only the navigation bar is declared — the status bar is not', () {
      model(theme: ThemeModel.themeLight).apply();

      final SystemUiOverlayStyle style = written.single;
      expect(style.statusBarColor, isNull,
          reason: '$rule1 AppBaseTheme declares android:navigationBarColor and '
              'nothing else about the system bars, and a null field is the '
              'embedding\'s "leave it alone".');
      expect(style.systemNavigationBarIconBrightness, isNull,
          reason: '$rule1 android:windowLightNavigationBar is not declared '
              'either, so the icons stay at the platform default over the dark '
              'bar.');
      expect(style.systemNavigationBarDividerColor, isNull, reason: rule1);
    });

    test('#2 the sink really is SystemChrome.setSystemUIOverlayStyle', () {
      // Nothing is applied here: constructing the model is enough, and the
      // default must be the SDK call itself rather than a no-op left behind by
      // the test seam.
      expect(
        ThemeModel(Preferences(MemoryStorage())).setSystemUiOverlayStyle,
        same(SystemChrome.setSystemUIOverlayStyle),
        reason: rule2,
      );
    });

    test('#1 the decision is a function of the core theme alone', () {
      expect(
        systemUiOverlayStyleFor(core.LightTheme())?.systemNavigationBarColor,
        const Color(0xFF363636),
        reason: rule1,
      );
      expect(systemUiOverlayStyleFor(core.DarkTheme()), isNull, reason: rule1);
      expect(systemUiOverlayStyleFor(core.PureBlackTheme()), isNull,
          reason: rule1);
    });
  });
}
