/// `audit.the-light-theme-s-navigation-bar` and
/// `audit6.dark-and-pure-black-themes-never`: the system navigation bar tint.
///
/// Upstream the colour comes from two different places, and that is the whole
/// subject of this file. The light theme takes it from a style attribute —
/// `res/values/styles.xml` declares `<item name="android:navigationBarColor">`
/// on `AppBaseTheme` only, pointing at that style's `colorPrimary`, the literal
/// `#363636`. The two dark themes take it from code:
/// `AndroidThemeSwitcher.applyDarkTheme()` runs `(context as Activity).window
/// .navigationBarColor = ContextCompat.getColor(context, R.color.grey_900)`
/// (#212121) and `applyPureBlackTheme()` does the same with `R.color.black`
/// (#000000), every time a theme is applied.
///
/// So all three themes paint the bar, and the bar changes the moment the user
/// toggles the theme. This file used to assert the opposite for the dark half —
/// "AppBaseThemeDark deliberately does not set android:navigationBarColor",
/// read out of styles.xml alone and never checked against
/// `AndroidThemeSwitcher` — and so it *asserted the defect*: with the port
/// writing nothing for a dark theme, a user who toggled Light -> Dark kept the
/// light theme's #363636 bar for ever, and the test called that correct. The
/// dark assertions below are now the Kotlin behaviour, cited to
/// `audit6.dark-and-pure-black-themes-never#1`.
///
/// The port has no activity to re-theme, so both halves survive as one call to
/// `SystemChrome.setSystemUIOverlayStyle` made from the place the port installs
/// a theme — `ThemeModel._install`, the counterpart of `setTheme(...)` plus the
/// imperative `window.navigationBarColor` assignment.
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
    'matching the dark toolbar chrome. The asymmetry is a deliberate theme '
    'declaration, not an accident.';

const String rule2 =
    'audit.the-light-theme-s-navigation-bar#2 — The port must do the same. '
    'Today it does this instead: Nothing — the port never calls '
    '`SystemChrome.setSystemUIOverlayStyle`; the only SystemChrome use in '
    'app/lib is `setEnabledSystemUIMode` in app/lib/ui/intro/intro_screen.dart. '
    'The navigation bar keeps whatever the Flutter embedding default is, in '
    'both themes.';

const String rule6 =
    'audit6.dark-and-pure-black-themes-never#1 — In the Kotlin app: '
    'applyDarkTheme() sets currentTheme = DarkTheme(), applies '
    '@style/AppBaseThemeDark AND runs `(context as Activity).window'
    '.navigationBarColor = ContextCompat.getColor(context, R.color.grey_900)` '
    '(#212121). applyPureBlackTheme() does the same with R.color.black '
    '(#000000). The light theme is the only one that gets its navigation-bar '
    'colour from a style attribute (AppBaseTheme\'s android:navigationBarColor '
    '= ?attr/colorPrimary = #363636); the two dark themes set it imperatively, '
    'every time a theme is applied. So on Android the gesture/navigation bar '
    'is #363636 in Light, #212121 in Dark and #000000 in Pure Black, and it '
    'changes the moment the user toggles the theme. These are exactly rules '
    '`settings.theme.theme-modes#8` and `#9`.';

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

  /// The colours of every style written so far.
  List<Color?> colors() => written
      .map((SystemUiOverlayStyle s) => s.systemNavigationBarColor)
      .toList();

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
  });

  group('audit6.dark-and-pure-black-themes-never', () {
    test('#1 the dark theme paints the navigation bar grey_900', () {
      model(theme: ThemeModel.themeDark).apply();

      expect(written, hasLength(1),
          reason: '$rule6 `applyDarkTheme()` assigns window.navigationBarColor '
              'unconditionally, so installing the dark theme has to write a '
              'style rather than stay silent.');
      expect(written.single.systemNavigationBarColor, const Color(0xFF212121),
          reason: '$rule6 R.color.grey_900 is #212121 in '
              'res/values/material_colors.xml.');
    });

    test('#1 the pure black theme paints it black', () {
      model(theme: ThemeModel.themeDark, pureBlack: true).apply();

      expect(written, hasLength(1), reason: rule6);
      expect(written.single.systemNavigationBarColor, const Color(0xFF000000),
          reason: '$rule6 R.color.black is #000000.');
    });

    test('#1 a dark style declares the bar and nothing else', () {
      model(theme: ThemeModel.themeDark).apply();

      final SystemUiOverlayStyle style = written.single;
      expect(style.statusBarColor, isNull,
          reason: '$rule6 The Kotlin assignment touches '
              'window.navigationBarColor alone; every other system-bar '
              'property stays where the platform put it.');
      expect(style.systemNavigationBarIconBrightness, isNull, reason: rule6);
      expect(style.systemNavigationBarDividerColor, isNull, reason: rule6);
    });

    test('#1 toggling Light -> Dark -> Light repaints the bar each time', () {
      final ThemeModel switcher = model(theme: ThemeModel.themeLight)..apply();
      switcher.theme = ThemeModel.themeDark;
      switcher.theme = ThemeModel.themeLight;

      expect(
        colors(),
        <Color>[
          const Color(0xFF363636),
          const Color(0xFF212121),
          const Color(0xFF363636),
        ],
        reason: '$rule6 This is the user-visible defect: with the dark themes '
            'writing nothing, the light theme\'s #363636 stayed on the bar for '
            'the whole dark session, and the only theme that could ever change '
            'it was the one that had already been applied.',
      );
    });

    test('#1 turning pure black on and off inside the dark theme repaints too',
        () {
      final ThemeModel switcher = model(theme: ThemeModel.themeDark)..apply();
      switcher.isPureBlackEnabled = true;
      switcher.isPureBlackEnabled = false;

      expect(
        colors(),
        <Color>[
          const Color(0xFF212121),
          const Color(0xFF000000),
          const Color(0xFF212121),
        ],
        reason: '$rule6 applyDarkTheme() and applyPureBlackTheme() differ in '
            'exactly this colour, and upstream the switch between them is an '
            'activity restart that re-runs the assignment.',
      );
    });

    test('#1 automatic follows the system, and so does the navigation bar', () {
      model(theme: ThemeModel.themeAutomatic, system: Brightness.light).apply();
      expect(colors(), <Color>[const Color(0xFF363636)], reason: rule1);

      written.clear();
      model(theme: ThemeModel.themeAutomatic, system: Brightness.dark).apply();
      expect(colors(), <Color>[const Color(0xFF212121)], reason: rule6);
    });

    test('#1 the decision is a function of the core theme alone', () {
      expect(
        systemUiOverlayStyleFor(core.LightTheme()),
        const SystemUiOverlayStyle(systemNavigationBarColor: Color(0xFF363636)),
        reason: rule1,
      );
      expect(
        systemUiOverlayStyleFor(core.DarkTheme()),
        const SystemUiOverlayStyle(systemNavigationBarColor: Color(0xFF212121)),
        reason: rule6,
      );
      expect(
        systemUiOverlayStyleFor(core.PureBlackTheme()),
        const SystemUiOverlayStyle(systemNavigationBarColor: Color(0xFF000000)),
        reason: '$rule6 PureBlackTheme extends DarkTheme, so a single '
            '`is DarkTheme` check would answer grey_900 for both and the pure '
            'black bar would never appear.',
      );
    });
  });
}
