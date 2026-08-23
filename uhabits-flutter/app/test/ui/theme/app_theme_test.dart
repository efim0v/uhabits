// Preferences are not re-exported from uhabits_core.dart; like
// lib/state/app_scope.dart, this file reaches them by their `src` path.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/state/theme_model.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

/// Tests for the theme half of the settings domain: the three theme modes, the
/// pure-black switch that applies on top of dark, and the bridge that turns the
/// core [core.Theme] — the same palette the charts paint with — into a Flutter
/// [ThemeData].
///
/// The behaviour is the core `ThemeSwitcher` plus `AndroidThemeSwitcher`;
/// `ThemeModel` is their Flutter counterpart. Rule ids come from
/// docs/parity/FEATURES.md.
void main() {
  group('settings.theme.theme-modes', () {
    test('#1 three constants, and automatic is the default', () {
      expect(ThemeModel.themeAutomatic, 0,
          reason: 'settings.theme.theme-modes#1');
      expect(ThemeModel.themeDark, 1, reason: 'settings.theme.theme-modes#1');
      expect(ThemeModel.themeLight, 2, reason: 'settings.theme.theme-modes#1');

      // A storage that was never written to: Preferences.theme falls back to
      // THEME_AUTOMATIC, and so does the model that reads it.
      final preferences = Preferences(MemoryStorage());
      expect(preferences.theme, ThemeModel.themeAutomatic,
          reason: 'settings.theme.theme-modes#1');
      expect(ThemeModel(preferences).theme, ThemeModel.themeAutomatic,
          reason: 'settings.theme.theme-modes#1');
    });

    test('#6 currentTheme is LightTheme until apply() runs', () {
      final model = _model(
        theme: ThemeModel.themeDark,
        pureBlack: true,
        system: Brightness.dark,
      );

      expect(model.hasApplied, isFalse,
          reason: 'settings.theme.theme-modes#6');
      expect(model.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#6');

      model.apply();

      expect(model.hasApplied, isTrue, reason: 'settings.theme.theme-modes#6');
      expect(model.currentTheme.runtimeType, core.PureBlackTheme,
          reason: 'settings.theme.theme-modes#4');
    });

    test('#2 isNightMode == userTheme == DARK || (system DARK && automatic)',
        () {
      const rows = <(int, Brightness, bool)>[
        (ThemeModel.themeAutomatic, Brightness.light, false),
        (ThemeModel.themeAutomatic, Brightness.dark, true),
        (ThemeModel.themeLight, Brightness.light, false),
        // Explicitly light is never night mode, whatever the system says.
        (ThemeModel.themeLight, Brightness.dark, false),
        (ThemeModel.themeDark, Brightness.light, true),
        (ThemeModel.themeDark, Brightness.dark, true),
      ];

      for (final (theme, system, expected) in rows) {
        final model = _model(theme: theme, system: system);
        expect(model.isNightMode, expected,
            reason: 'settings.theme.theme-modes#2 '
                'theme=$theme system=$system');
      }
    });

    test('#2 getSystemTheme() reads the OS dark-mode setting', () {
      expect(_model(system: Brightness.light).getSystemTheme(),
          ThemeModel.themeLight,
          reason: 'settings.theme.theme-modes#2');
      expect(_model(system: Brightness.dark).getSystemTheme(),
          ThemeModel.themeDark,
          reason: 'settings.theme.theme-modes#2');
    });

    test('#4 apply() picks pure black, dark or light', () {
      final night = _model(theme: ThemeModel.themeDark)..apply();
      expect(night.currentTheme.runtimeType, core.DarkTheme,
          reason: 'settings.theme.theme-modes#4');

      final pureBlack = _model(theme: ThemeModel.themeDark, pureBlack: true)
        ..apply();
      expect(pureBlack.currentTheme.runtimeType, core.PureBlackTheme,
          reason: 'settings.theme.theme-modes#4');

      final day = _model(theme: ThemeModel.themeLight, pureBlack: true)
        ..apply();
      expect(day.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#4');
    });

    test('#3 automatic follows the system dark-mode setting', () {
      final model = _model(theme: ThemeModel.themeAutomatic)..apply();
      expect(model.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#3');

      model.systemBrightness = Brightness.dark;
      expect(model.currentTheme.runtimeType, core.DarkTheme,
          reason: 'settings.theme.theme-modes#3');

      model.systemBrightness = Brightness.light;
      expect(model.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#3');
    });

    test('#3 automatic has no time-of-day component', () {
      addTearDown(core.resetToday);
      final model = _model(theme: ThemeModel.themeAutomatic);

      core.setToday(core.LocalDate.ymd(2015, 1, 25));
      model.apply();
      final atNoon = model.currentTheme.runtimeType;

      core.setToday(core.LocalDate.ymd(2015, 6, 21));
      model.apply();

      expect(model.currentTheme.runtimeType, atNoon,
          reason: 'settings.theme.theme-modes#3');
      expect(model.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#3');
    });

    test('#7 #8 #9 each apply method installs its own core theme', () {
      final model = _model();

      model.applyLightTheme();
      expect(model.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#7');

      model.applyDarkTheme();
      expect(model.currentTheme.runtimeType, core.DarkTheme,
          reason: 'settings.theme.theme-modes#8');

      model.applyPureBlackTheme();
      expect(model.currentTheme.runtimeType, core.PureBlackTheme,
          reason: 'settings.theme.theme-modes#9');
    });

    test('#4 apply() notifies, so the widget tree rebuilds', () {
      final model = _model(theme: ThemeModel.themeDark);
      var notifications = 0;
      model.addListener(() => notifications++);

      model.apply();
      expect(notifications, 1, reason: 'settings.theme.theme-modes#4');

      // Writing the same value again changes nothing and notifies nobody.
      model.theme = ThemeModel.themeDark;
      expect(notifications, 1, reason: 'settings.theme.theme-modes#4');

      model.theme = ThemeModel.themeLight;
      expect(notifications, 2, reason: 'settings.theme.theme-modes#4');
      expect(model.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#4');
    });
  });

  group('settings.theme.toggle-night-mode', () {
    test('#3 the toggle truth table', () {
      const rows = <(int, Brightness, int)>[
        (ThemeModel.themeAutomatic, Brightness.light, ThemeModel.themeDark),
        (ThemeModel.themeAutomatic, Brightness.dark, ThemeModel.themeLight),
        (ThemeModel.themeLight, Brightness.light, ThemeModel.themeDark),
        (ThemeModel.themeLight, Brightness.dark, ThemeModel.themeAutomatic),
        (ThemeModel.themeDark, Brightness.light, ThemeModel.themeAutomatic),
        (ThemeModel.themeDark, Brightness.dark, ThemeModel.themeLight),
      ];

      for (final (theme, system, expected) in rows) {
        final model = _model(theme: theme, system: system)..toggleNightMode();
        expect(model.theme, expected,
            reason: 'settings.theme.toggle-night-mode#3 '
                'theme=$theme system=$system');
      }
    });

    test('#4 it cycles through three states, landing on automatic only when '
        'the appearance already matches the system', () {
      // System light: LIGHT -> DARK -> AUTOMATIC -> DARK -> ...
      final light = _model(theme: ThemeModel.themeLight);
      light.toggleNightMode();
      expect(light.theme, ThemeModel.themeDark,
          reason: 'settings.theme.toggle-night-mode#4');
      light.toggleNightMode();
      expect(light.theme, ThemeModel.themeAutomatic,
          reason: 'settings.theme.toggle-night-mode#4');
      expect(light.isNightMode, isFalse,
          reason: 'settings.theme.toggle-night-mode#4');

      // System dark: LIGHT -> AUTOMATIC, and automatic is night mode there.
      final dark = _model(theme: ThemeModel.themeLight, system: Brightness.dark)
        ..toggleNightMode();
      expect(dark.theme, ThemeModel.themeAutomatic,
          reason: 'settings.theme.toggle-night-mode#4');
      expect(dark.isNightMode, isTrue,
          reason: 'settings.theme.toggle-night-mode#4');
    });

    test('#6 the value is persisted under pref_theme', () {
      final storage = MemoryStorage();
      final model = ThemeModel(Preferences(storage));

      expect(storage.getInt('pref_theme', -1), -1,
          reason: 'settings.theme.toggle-night-mode#6');

      model.toggleNightMode();
      expect(storage.getInt('pref_theme', -1), ThemeModel.themeDark,
          reason: 'settings.theme.toggle-night-mode#6');

      model.theme = ThemeModel.themeLight;
      expect(storage.getInt('pref_theme', -1), 2,
          reason: 'settings.theme.toggle-night-mode#6');
    });

    test('#8 applying picks the pure black variant over the dark one', () {
      final model = _model(theme: ThemeModel.themeDark)..apply();
      expect(model.currentTheme.runtimeType, core.DarkTheme,
          reason: 'settings.theme.toggle-night-mode#8');

      model.isPureBlackEnabled = true;
      expect(model.currentTheme.runtimeType, core.PureBlackTheme,
          reason: 'settings.theme.toggle-night-mode#8');
      expect(model.darkThemeData.scaffoldBackgroundColor,
          const Color(0xFF000000),
          reason: 'settings.theme.toggle-night-mode#8');
    });

    testWidgets('#5 the theme is swapped in place, with no restart',
        (tester) async {
      final model = _model(theme: ThemeModel.themeLight);
      late ThemeData themeData;
      await tester.pumpWidget(_ThemedApp(
        model: model,
        onBuild: (data) => themeData = data,
      ));

      expect(themeData.scaffoldBackgroundColor, const Color(0xFFF4F4F4),
          reason: 'settings.theme.toggle-night-mode#5');

      // ListHabitsScreen.applyTheme() restarts the activity with a fade; the
      // Flutter port rebuilds the same tree instead — the widget below never
      // leaves the tree.
      final probe = tester.element(find.byKey(_probeKey));
      model.toggleNightMode();
      await tester.pumpAndSettle();

      expect(themeData.scaffoldBackgroundColor, const Color(0xFF212121),
          reason: 'settings.theme.toggle-night-mode#5');
      expect(tester.element(find.byKey(_probeKey)), same(probe),
          reason: 'settings.theme.toggle-night-mode#5');
    });

    testWidgets('#1 the checked state of the menu item is isNightMode',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final model = _model(theme: ThemeModel.themeAutomatic);
      await tester.pumpWidget(_ThemedApp(model: model, onBuild: (_) {}));
      await tester.pump();

      // The observer has fed the OS setting in, so the menu can read the same
      // flag the theme was applied from.
      expect(model.systemBrightness, Brightness.dark,
          reason: 'settings.theme.toggle-night-mode#1');
      expect(model.isNightMode, isTrue,
          reason: 'settings.theme.toggle-night-mode#1');
      expect(model.currentTheme.runtimeType, core.DarkTheme,
          reason: 'settings.theme.toggle-night-mode#1');
    });
  });

  group('settings.theme.pure-black', () {
    test('#1 key pref_pure_black, boolean, default false', () {
      final storage = MemoryStorage();
      final model = ThemeModel(Preferences(storage));

      expect(model.isPureBlackEnabled, isFalse,
          reason: 'settings.theme.pure-black#1');
      expect(storage.getString('pref_pure_black', 'absent'), 'absent',
          reason: 'settings.theme.pure-black#1');

      model.isPureBlackEnabled = true;
      expect(storage.getBoolean('pref_pure_black', false), isTrue,
          reason: 'settings.theme.pure-black#1');
    });

    test('#3 the flag has no visual effect in light mode', () {
      final plain = _model(theme: ThemeModel.themeLight)..apply();
      final amoled = _model(theme: ThemeModel.themeLight, pureBlack: true)
        ..apply();

      expect(amoled.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.pure-black#3');
      expect(amoled.themeData.scaffoldBackgroundColor,
          plain.themeData.scaffoldBackgroundColor,
          reason: 'settings.theme.pure-black#3');
      expect(amoled.themeData.cardColor, plain.themeData.cardColor,
          reason: 'settings.theme.pure-black#3');
    });

    test('#4 pure black overrides exactly three colours', () {
      final dark = appThemeData(core.DarkTheme());
      final amoled = appThemeData(core.PureBlackTheme());

      expect(amoled.scaffoldBackgroundColor, const Color(0xFF000000),
          reason: 'settings.theme.pure-black#4');
      expect(amoled.canvasColor, const Color(0xFF000000),
          reason: 'settings.theme.pure-black#4');
      expect(amoled.cardColor, const Color(0xFF000000),
          reason: 'settings.theme.pure-black#4');
      expect(amoled.dividerColor, const Color(0xFF212121),
          reason: 'settings.theme.pure-black#4');

      // Everything else is inherited from DarkTheme.
      expect(amoled.brightness, dark.brightness,
          reason: 'settings.theme.pure-black#4');
      expect(amoled.colorScheme.onSurface, dark.colorScheme.onSurface,
          reason: 'settings.theme.pure-black#4');
      expect(amoled.appBarTheme.backgroundColor,
          dark.appBarTheme.backgroundColor,
          reason: 'settings.theme.pure-black#4');
      expect(amoled.colorScheme.secondary, dark.colorScheme.secondary,
          reason: 'settings.theme.pure-black#4');
    });
  });

  group('the ThemeData bridge', () {
    test('light: every colour comes from the core palette', () {
      final theme = core.LightTheme();
      final data = appThemeData(theme);

      expect(data.brightness, Brightness.light,
          reason: 'settings.theme.theme-modes#7');
      expect(data.scaffoldBackgroundColor, const Color(0xFFF4F4F4),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.cardColor, const Color(0xFFFAFAFA),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.dividerColor, const Color(0xFFE0E0E0),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.colorScheme.onSurface, const Color(0xFF202020),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.colorScheme.primary, const Color(0xFF333333),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.colorScheme.onPrimary, const Color(0xFFFFFFFF),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.colorScheme.secondary,
          toFlutterColor(theme.colorOf(core.defaultPaletteColor)),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.textTheme.bodyMedium?.color, const Color(0xFF202020),
          reason: 'charts-canvas-theming.theme-variants#1');
    });

    test('dark: the dark token set, not a recoloured light one', () {
      final data = appThemeData(core.DarkTheme());

      expect(data.brightness, Brightness.dark,
          reason: 'settings.theme.theme-modes#8');
      expect(data.scaffoldBackgroundColor, const Color(0xFF212121),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.cardColor, const Color(0xFF303030),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.dividerColor, const Color(0xFF424242),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.colorScheme.onSurface, const Color(0xFFF5F5F5),
          reason: 'charts-canvas-theming.theme-variants#1');
      expect(data.colorScheme.secondary, const Color(0xFF80CBC4),
          reason: 'charts-canvas-theming.theme-variants#1');
    });

    test('the widget theme is a light theme', () {
      // WidgetTheme extends LightTheme, so it must not read as night mode.
      expect(appThemeData(core.WidgetTheme()).brightness, Brightness.light,
          reason: 'charts-canvas-theming.theme-variants#3');
    });

    test('core colours convert channel for channel', () {
      expect(toFlutterColor(const core.Color.fromRgb(0x123456)),
          const Color(0xFF123456));
      expect(toFlutterColor(core.Color.TRANSPARENT), const Color(0x00000000));
      expect(toFlutterColor(core.Color.WHITE.withAlpha(0.5)),
          const Color(0x80FFFFFF));
    });

    testWidgets('coreThemeOf hands the chart the theme the app was built from',
        (tester) async {
      late core.Theme resolved;
      await tester.pumpWidget(MaterialApp(
        theme: appThemeData(core.PureBlackTheme()),
        home: Builder(builder: (context) {
          resolved = coreThemeOf(context);
          return const SizedBox.shrink();
        }),
      ));

      expect(resolved.runtimeType, core.PureBlackTheme,
          reason: 'settings.theme.pure-black#4');
      expect(resolved.appBackgroundColor, const core.Color.fromRgb(0x000000),
          reason: 'settings.theme.pure-black#4');
    });

    testWidgets('coreThemeOf falls back to the ambient brightness',
        (tester) async {
      late core.Theme resolved;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(builder: (context) {
          resolved = coreThemeOf(context);
          return const SizedBox.shrink();
        }),
      ));

      expect(resolved.runtimeType, core.DarkTheme,
          reason: 'charts-canvas-theming.theme-variants#1');
    });
  });

  group('SystemBrightnessObserver', () {
    testWidgets('feeds MediaQuery.platformBrightness into the model',
        (tester) async {
      final model = _model(theme: ThemeModel.themeAutomatic);

      await tester.pumpWidget(_observer(model, Brightness.dark));
      await tester.pump();

      expect(model.systemBrightness, Brightness.dark,
          reason: 'settings.theme.theme-modes#3');
      expect(model.currentTheme.runtimeType, core.DarkTheme,
          reason: 'settings.theme.theme-modes#3');

      await tester.pumpWidget(_observer(model, Brightness.light));
      await tester.pump();

      expect(model.currentTheme.runtimeType, core.LightTheme,
          reason: 'settings.theme.theme-modes#3');
    });

    testWidgets('applies once even when the system setting never changes',
        (tester) async {
      // The model starts on light with THEME_DARK stored: without an apply on
      // the first frame the dark preference would never reach the screen.
      final model = _model(theme: ThemeModel.themeDark);
      var notifications = 0;
      model.addListener(() => notifications++);

      await tester.pumpWidget(_observer(model, Brightness.light));
      await tester.pump();
      await tester.pump();

      expect(model.currentTheme.runtimeType, core.DarkTheme,
          reason: 'settings.theme.theme-modes#6');
      expect(notifications, 1,
          reason: 'settings.theme.theme-modes#6 — one apply, not a loop');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ThemeModel _model({
  int theme = ThemeModel.themeAutomatic,
  bool pureBlack = false,
  Brightness system = Brightness.light,
}) {
  final preferences = Preferences(MemoryStorage())
    ..theme = theme
    ..isPureBlackEnabled = pureBlack;
  return ThemeModel(preferences, systemBrightness: system);
}

Widget _observer(ThemeModel model, Brightness platformBrightness) {
  return MediaQuery(
    data: MediaQueryData(platformBrightness: platformBrightness),
    child: ChangeNotifierProvider<ThemeModel>.value(
      value: model,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: SystemBrightnessObserver(child: SizedBox.shrink()),
      ),
    ),
  );
}

const Key _probeKey = ValueKey<String>('probe');

/// The wiring the integrator is expected to put in `lib/main.dart`.
class _ThemedApp extends StatelessWidget {
  const _ThemedApp({required this.model, required this.onBuild});

  final ThemeModel model;
  final ValueChanged<ThemeData> onBuild;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeModel>.value(
      value: model,
      child: Consumer<ThemeModel>(
        builder: (context, model, _) => MaterialApp(
          theme: model.lightThemeData,
          darkTheme: model.darkThemeData,
          themeMode: model.materialThemeMode,
          builder: (context, child) =>
              SystemBrightnessObserver(child: child ?? const SizedBox.shrink()),
          home: Builder(builder: (context) {
            onBuild(Theme.of(context));
            return const SizedBox.shrink(key: _probeKey);
          }),
        ),
      ),
    );
  }
}
