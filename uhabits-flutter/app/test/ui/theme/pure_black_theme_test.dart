/// `audit.pure-black-amoled-theme-is-ignored`.
///
/// `AndroidThemeSwitcher.applyPureBlackTheme()` installs `PureBlackTheme`, and
/// every consumer of `currentTheme()` — `ListHabitsRootView`,
/// `HabitCardView.copyAttributesFrom`, `AboutView.init` — picks it up. In the
/// port the single place that answers "which core theme is on screen" is
/// `coreThemeOf`, which reads the `CoreThemeExtension` the `ThemeData` carries.
/// These tests pin that both the habit list and the About screen go through it
/// rather than re-deriving a theme from [Brightness], which cannot tell
/// `DarkTheme` and `PureBlackTheme` apart.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    core.resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_pure_black');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    final scope = AppScope.open(database);
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  core.Habit addHabit(AppScope scope, String name) {
    final habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Color flutter(core.Color color) => toFlutterColor(color);

  /// The whole app under one core theme, exactly as `ThemeModel` installs it:
  /// `appThemeData` stamps the `CoreThemeExtension` that `coreThemeOf` reads.
  Widget wrap(Widget home, core.Theme theme) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: appThemeData(theme),
        home: home,
      );

  group('the habit list under the pure-black theme', () {
    testWidgets('the scaffold, the header and the cards are all black',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scope = openScope();
      addHabit(scope, 'Meditate');

      await tester.pumpWidget(
        wrap(
          Provider<AppScope>.value(
            value: scope,
            child: const HabitListScreen(),
          ),
          core.PureBlackTheme(),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        flutter(core.PureBlackTheme().appBackgroundColor),
        reason: 'audit.pure-black-amoled-theme-is-ignored#1: with pref_pure_black '
            'on in dark mode AndroidThemeSwitcher installs PureBlackTheme, so '
            'ListHabitsRootView paints the list background #000000. '
            'audit.pure-black-amoled-theme-is-ignored#2: the port must do the '
            'same, instead of re-deriving DarkTheme from Brightness and leaving '
            'the list body #212121 under a black AppBar.',
      );

      final header = tester.widget<ListHeader>(find.byType(ListHeader));
      expect(
        header.theme,
        isA<core.PureBlackTheme>(),
        reason: 'audit.pure-black-amoled-theme-is-ignored#1: the header is one '
            'of the ListHabitsRootView children that reads currentTheme(). '
            'audit.pure-black-amoled-theme-is-ignored#2: the port must hand it '
            'the theme coreThemeOf resolves, not DarkTheme.',
      );

      final card = tester.widget<HabitCard>(find.byType(HabitCard).first);
      expect(
        card.theme,
        isA<core.PureBlackTheme>(),
        reason: 'audit.pure-black-amoled-theme-is-ignored#1: '
            'HabitCardView.copyAttributesFrom takes the same currentTheme(), so '
            'the cards are #000000 too. '
            'audit.pure-black-amoled-theme-is-ignored#2: the port passes the '
            'screen theme straight into HabitCard, so it inherits the defect.',
      );
      expect(
        card.theme.cardBackgroundColor,
        core.PureBlackTheme().cardBackgroundColor,
        reason: 'audit.pure-black-amoled-theme-is-ignored#2: DarkTheme cards are '
            '#303030 where the pure-black ones are #000000',
      );
    });

    testWidgets('a plain dark theme still resolves to DarkTheme',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final scope = openScope();

      await tester.pumpWidget(
        wrap(
          Provider<AppScope>.value(
            value: scope,
            child: const HabitListScreen(),
          ),
          core.DarkTheme(),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        flutter(core.DarkTheme().appBackgroundColor),
        reason: 'audit.pure-black-amoled-theme-is-ignored#1: pure black applies '
            'only when pref_pure_black is on; plain dark mode keeps DarkTheme. '
            'audit.pure-black-amoled-theme-is-ignored#2: reading the theme from '
            'the extension must not disturb the dark case.',
      );
    });
  });

  group('the About screen under the pure-black theme', () {
    testWidgets('the scaffold and the cards are black', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          AboutScreen(preferences: Preferences(MemoryStorage())),
          core.PureBlackTheme(),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        flutter(core.PureBlackTheme().appBackgroundColor),
        reason: 'audit.pure-black-amoled-theme-is-ignored#1: AboutView.init '
            'reads the same currentTheme(), so the About screen picks up the '
            'pure-black theme. '
            'audit.pure-black-amoled-theme-is-ignored#2: the port keeps it '
            '#212121 because about_screen.dart derives its core theme from '
            'Brightness instead of coreThemeOf.',
      );
    });

    testWidgets('a plain dark theme still resolves to DarkTheme',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrap(
          AboutScreen(preferences: Preferences(MemoryStorage())),
          core.DarkTheme(),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        flutter(core.DarkTheme().appBackgroundColor),
        reason: 'audit.pure-black-amoled-theme-is-ignored#1: only '
            'applyPureBlackTheme() installs PureBlackTheme. '
            'audit.pure-black-amoled-theme-is-ignored#2: the fix must leave the '
            'plain dark About screen at #212121.',
      );
    });
  });
}
