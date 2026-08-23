/// `verify.intro-never-shown`: the first-run intro, driven from the entry
/// point rather than from a constructor.
///
/// `test/ui/intro/intro_screen_test.dart` covers the screen itself — the three
/// slides, the crossfade, Skip and Done — by building `IntroScreen(...)` by
/// hand. That is precisely why it could not see this defect: the screen was
/// finished and nobody opened it. These tests therefore never name
/// `IntroScreen` as something to construct. They pump the habit list exactly
/// as `main.dart` does — `HabitListScreen()` with no callbacks supplied at all
/// — over a scope whose preferences are those of a device that has never run
/// the app, and assert that the intro is what the user is looking at.
library;

// The core's preference layers are reached by their `src` path, exactly as the
// app package reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/intro/intro_screen.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' show resetToday;

const String rule1 =
    'verify.intro-never-shown#1 — In the Kotlin app: On the very first launch '
    'ListHabitsBehavior.onStartup() clears isFirstRun, seeds '
    'updateLastHint(-1, today) and calls screen.showIntroScreen(), which '
    'starts IntroActivity: three full-screen slides (Welcome / Create some '
    'new habits / Track your progress) with Skip and Done.';

const String rule2 =
    'verify.intro-never-shown#2 — The port must do the same. Today: The core '
    'behaviour is ported faithfully and does call showIntroScreen(), '
    'HabitListModel.showIntroScreen() forwards to onShowIntroScreen?.call() — '
    'but nothing ever assigns that field. A first-time user goes straight to '
    'an empty habit list; the intro is dead code, and because isFirstRun is '
    'cleared anyway it can never appear later.';

void main() {
  late Directory tempDir;

  /// The device's SharedPreferences: shared by every scope in a test, so that
  /// a second launch sees what the first one wrote.
  late MemoryStorage storage;

  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_intro_wiring');
    storage = MemoryStorage();
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final String path = '${tempDir.path}/habits${databaseIndex++}.db';
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      databasePath: path,
      preferencesStorage: storage,
    );
    scopes.add(scope);
    return scope;
  }

  /// One launch of the app: `AppScope` + the screen as `main.dart` builds it,
  /// with nothing wired by the test.
  Future<AppScope> launch(WidgetTester tester) async {
    final AppScope scope = openScope();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: const HabitListScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return scope;
  }

  group('verify.intro-never-shown', () {
    testWidgets('a first launch opens the intro over the habit list',
        (WidgetTester tester) async {
      expect(Preferences(storage).isFirstRun, isTrue,
          reason: '$rule1 The precondition: this is a device that has never '
              'run the app.');

      final AppScope launched = await launch(tester);

      expect(find.byType(IntroScreen), findsOneWidget,
          reason: '$rule1 $rule2 onStartup() -> onFirstRun() -> '
              'screen.showIntroScreen() has to end at a visible IntroScreen, '
              'the way startActivity(IntroActivity) does.');

      final L10n l10n = L10n.of(tester.element(find.byType(IntroScreen)));
      expect(find.text(l10n.introTitle1), findsOneWidget,
          reason: '$rule1 The first slide is what the user sees.');

      // `skipOffstage: false` because that is what "on top of" looks like in a
      // Navigator: the route below an opaque one keeps its state and goes
      // offstage rather than being torn down — `ListHabitsActivity` is stopped,
      // not finished.
      expect(find.byType(HabitListScreen, skipOffstage: false), findsOneWidget,
          reason: '$rule1 startActivity() puts IntroActivity ON TOP of '
              'ListHabitsActivity — the list is still there underneath, not '
              'replaced.');

      expect(launched.preferences.isFirstRun, isFalse,
          reason: '$rule1 onFirstRun() clears isFirstRun before showing the '
              'screen.');
    });

    testWidgets('Skip closes the intro and returns to the list',
        (WidgetTester tester) async {
      await launch(tester);

      await tester.tap(find.byKey(IntroScreen.skipButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(IntroScreen), findsNothing,
          reason: '$rule1 onSkipPressed is finish(): the intro closes and the '
              'list is what is left. $rule2');
      expect(find.byType(HabitListScreen), findsOneWidget, reason: rule1);
    });

    testWidgets('a later launch never shows it again',
        (WidgetTester tester) async {
      await launch(tester);
      expect(find.byType(IntroScreen), findsOneWidget, reason: rule2);

      await tester.tap(find.byKey(IntroScreen.skipButtonKey));
      await tester.pumpAndSettle();

      // The same preferences, a second launch: isFirstRun was cleared by the
      // first one, so onStartup() no longer calls onFirstRun().
      await launch(tester);

      expect(find.byType(IntroScreen), findsNothing,
          reason: '$rule1 isFirstRun is cleared by the first launch. $rule2 '
              '"because isFirstRun is cleared anyway it can never appear '
              'later" — which is only a defect while the first launch does '
              'not show it either.');
      expect(find.byType(HabitListScreen), findsOneWidget, reason: rule2);
    });
  });
}
