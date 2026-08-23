/// The two toolbars `setupToolbar` colours through `?attr/useHabitColorAsPrimary`
/// — Settings and About — and the `<PreferenceCategory>` headers the app draws
/// with `?attr/aboutScreenColor`.
///
/// Both are audit findings: the branch and the attribute exist in the ported
/// core theme, and these two screens are the ones that never read them. Every
/// expectation quotes the rule id it stands for.
library;

// The preferences layer is reached by its `src` path, exactly as
// lib/state/app_scope.dart does.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart';
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  var databaseIndex = 0;

  setUp(() {
    core.resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_toolbar_theme');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope(PreferencesStorage storage) {
    final database = AppDatabase.openAndMigrate(
      '${tempDir.path}/habits${databaseIndex++}.db',
    );
    final scope = AppScope.open(database, preferencesStorage: storage);
    scopes.add(scope);
    return scope;
  }

  /// The Flutter colour a core token turns into on screen.
  Color flutter(core.Color color) => toFlutterColor(color);

  /// Pumps the settings screen under [coreTheme], with the user preferences
  /// that make `SettingsModel.currentTheme` return that same variant — which is
  /// what `AndroidThemeSwitcher.apply()` installs on the activity.
  Future<void> pumpSettings(WidgetTester tester, core.Theme coreTheme) async {
    final storage = MemoryStorage();
    final scope = openScope(storage);
    final preferences = scope.preferences;
    preferences.theme = coreTheme is core.DarkTheme
        ? SettingsModel.themeDark
        : SettingsModel.themeLight;
    preferences.isPureBlackEnabled = coreTheme is core.PureBlackTheme;

    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      theme: appThemeData(coreTheme),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        // A fresh key per pump: without it a second pumpWidget would reuse the
        // element, and with it the SettingsModel built for the first theme.
        child: SettingsScreen(
          key: ValueKey<String>('settings.${coreTheme.runtimeType}'),
          storage: storage,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pumpAbout(WidgetTester tester, core.Theme coreTheme) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      theme: appThemeData(coreTheme),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: AboutScreen(preferences: Preferences(MemoryStorage())),
    ));
    await tester.pumpAndSettle();
  }

  Color? appBarColor(WidgetTester tester) =>
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor;

  // -----------------------------------------------------------------------
  // audit.settings-and-about-toolbars-ignore-the
  // -----------------------------------------------------------------------

  group('audit.settings-and-about-toolbars-ignore-the', () {
    test('#1 the core theme carries the branch setupToolbar takes', () {
      expect(core.LightTheme().useHabitColorAsPrimary, isTrue,
          reason: 'audit.settings-and-about-toolbars-ignore-the#1 — the light '
              'theme sets useHabitColorAsPrimary true, both dark themes set it '
              'false');
      expect(core.DarkTheme().useHabitColorAsPrimary, isFalse,
          reason: 'audit.settings-and-about-toolbars-ignore-the#1');
      expect(core.PureBlackTheme().useHabitColorAsPrimary, isFalse,
          reason: 'audit.settings-and-about-toolbars-ignore-the#1');
      expect(core.DarkTheme().primaryColor, const core.Color.fromRgb(0x101010),
          reason: 'audit.settings-and-about-toolbars-ignore-the#1 — '
              '?attr/colorPrimary is grey_950 in the dark theme');
      expect(
        core.PureBlackTheme().primaryColor,
        const core.Color.fromRgb(0x000000),
        reason: 'audit.settings-and-about-toolbars-ignore-the#1 — and black in '
            'the pure-black one',
      );
    });

    testWidgets('#2 the Settings toolbar takes colorPrimary in both dark '
        'themes and PaletteColor(11) in the light one', (tester) async {
      await pumpSettings(tester, core.LightTheme());
      expect(
        appBarColor(tester),
        flutter(core.LightTheme().colorOf(const core.PaletteColor(11))),
        reason: 'audit.settings-and-about-toolbars-ignore-the#1 — in the light '
            'theme the bar is blue_700 #1976D2',
      );
      expect(appBarColor(tester), const Color(0xFF1976D2),
          reason: 'audit.settings-and-about-toolbars-ignore-the#1');

      await pumpSettings(tester, core.DarkTheme());
      expect(appBarColor(tester), const Color(0xFF101010),
          reason: 'audit.settings-and-about-toolbars-ignore-the#2 — '
              'SettingsActivity must take ?attr/colorPrimary (#101010), not '
              'darkPalette[11]');
      expect(
        appBarColor(tester),
        isNot(flutter(core.DarkTheme().colorOf(const core.PaletteColor(11)))),
        reason: 'audit.settings-and-about-toolbars-ignore-the#2 — the light '
            'blue #64B5F6 bar is the defect',
      );

      await pumpSettings(tester, core.PureBlackTheme());
      expect(appBarColor(tester), const Color(0xFF000000),
          reason: 'audit.settings-and-about-toolbars-ignore-the#1 — and black '
              'in the pure-black theme');
    });

    testWidgets('#2 the About toolbar takes the same branch', (tester) async {
      await pumpAbout(tester, core.LightTheme());
      expect(appBarColor(tester), const Color(0xFF1976D2),
          reason: 'audit.settings-and-about-toolbars-ignore-the#1 — '
              'AboutActivity calls setupToolbar with PaletteColor(11) too');

      await pumpAbout(tester, core.DarkTheme());
      expect(appBarColor(tester), const Color(0xFF101010),
          reason: 'audit.settings-and-about-toolbars-ignore-the#2 — '
              'app/lib/ui/about/about_screen.dart must branch on '
              'useHabitColorAsPrimary through Theme.toolbarColorFor');
      expect(
        appBarColor(tester),
        isNot(flutter(core.DarkTheme().colorOf(const core.PaletteColor(11)))),
        reason: 'audit.settings-and-about-toolbars-ignore-the#2',
      );
    });
  });

  // -----------------------------------------------------------------------
  // audit.settings-category-headers-lose-the-aboutscreencolor
  // -----------------------------------------------------------------------

  group('audit.settings-category-headers-lose-the-aboutscreencolor', () {
    test('#1 the core theme carries ?attr/aboutScreenColor', () {
      expect(
        core.LightTheme().aboutScreenColor,
        const core.Color.fromRgb(0x1565C0),
        reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#1 — '
            '@color/blue_800 #1565C0 in the light theme',
      );
      expect(
        core.DarkTheme().aboutScreenColor,
        const core.Color.fromRgb(0x64B5F6),
        reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#1 — '
            '@color/blue_300 #64B5F6 in the dark theme',
      );
      expect(
        core.PureBlackTheme().aboutScreenColor,
        core.DarkTheme().aboutScreenColor,
        reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#1 — '
            'AppBaseThemeDark.PureBlack restates no aboutScreenColor',
      );
      // The same blue the About screen's own card headers are written in.
      expect(toFlutterColor(core.LightTheme().aboutScreenColor),
          AboutScreen.aboutScreenColorLight,
          reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#1 '
              '— the headers match the blue card headers on the About screen');
      expect(toFlutterColor(core.DarkTheme().aboutScreenColor),
          AboutScreen.aboutScreenColorDark,
          reason:
              'audit.settings-category-headers-lose-the-aboutscreencolor#1');
    });

    testWidgets('#2 every category header is written in ?aboutScreenColor, in '
        'every theme', (tester) async {
      Future<List<Color?>> headerColorsUnder(core.Theme coreTheme) async {
        await pumpSettings(tester, coreTheme);
        return tester
            .widgetList<SettingsCategoryHeader>(
              find.byType(SettingsCategoryHeader),
            )
            .map((header) => tester
                .widget<Text>(
                  find.descendant(
                    of: find.byWidget(header),
                    matching: find.text(header.title),
                  ),
                )
                .style
                ?.color)
            .toList();
      }

      final light = await headerColorsUnder(core.LightTheme());
      expect(light, isNotEmpty,
          reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#2 '
              '— the screen draws its <PreferenceCategory> headers');
      expect(
        light,
        everyElement(toFlutterColor(core.LightTheme().aboutScreenColor)),
        reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#1 — '
            'preference_category_custom.xml colours the title '
            '?aboutScreenColor, #1565C0 in the light theme',
      );

      final dark = await headerColorsUnder(core.DarkTheme());
      expect(
        dark,
        everyElement(toFlutterColor(core.DarkTheme().aboutScreenColor)),
        reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#2 — '
            'the headers must not be colorScheme.primary (#333333), which is '
            'unreadable on the dark settings background',
      );
      expect(dark, isNot(contains(const Color(0xFF333333))),
          reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#2 '
              '— #333333 on #212121 is roughly 1.4:1 contrast');

      final pureBlack = await headerColorsUnder(core.PureBlackTheme());
      expect(
        pureBlack,
        everyElement(toFlutterColor(core.PureBlackTheme().aboutScreenColor)),
        reason: 'audit.settings-category-headers-lose-the-aboutscreencolor#2 — '
            'and #333333 on #000000 is roughly 2.2:1',
      );
    });
  });
}
