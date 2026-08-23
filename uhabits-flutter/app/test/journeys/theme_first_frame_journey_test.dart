/// Journey: the app is launched by a user whose theme is Dark.
///
/// `audit3.one-light-themed-frame-on-every#1` — "The theme is applied before
/// the first layout, so the window is already dark on the very first frame."
/// Upstream that is `ListHabitsActivity.onCreate` calling
/// `component.themeSwitcher.apply()` *before* `setContentView`.
///
/// The defect this file exists for cannot be seen after a `pumpAndSettle`: by
/// then the post-frame callback has run, the theme has been applied and the
/// second frame is dark. It is only visible in the frame the user actually
/// sees first. So these tests stop the app after exactly one `pumpWidget` —
/// which is one frame — and read what `MaterialApp` was painting with.
///
/// `main()` is inlined rather than borrowed from [JourneySession.launch],
/// because that helper settles the app before handing it back and settling is
/// precisely what hides the flash. Everything else is the same two lines the
/// application starts with, with nothing supplied.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;

  /// Only the first test needs a full session; the other two are a single
  /// launch each.
  JourneySession? app;

  /// The scope of an app launched by [launchOneFrame], so that [quitOneFrame]
  /// can tear it down the way `JourneySession.quit` does.
  AppScope? running;

  setUp(() {
    device = TestDevice.create('uhabits_journey_theme');
  });

  tearDown(() {
    app?.dispose();
    app = null;
    try {
      running?.close();
    } on Object {
      // Already closed.
    }
    running = null;
    device.dispose();
  });

  /// What `MaterialApp.theme` is painting the whole window with, on whichever
  /// frame is currently on screen.
  Color windowBackground(WidgetTester tester) =>
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .scaffoldBackgroundColor;

  final Color lightBackground =
      appThemeData(core.LightTheme()).scaffoldBackgroundColor;
  final Color darkBackground =
      appThemeData(core.DarkTheme()).scaffoldBackgroundColor;

  /// `void main()`, stopped after the first frame.
  ///
  /// `pumpWidget` builds, lays out and paints exactly once, so what the tester
  /// finds afterwards is the window the user's eye lands on.
  Future<AppScope> launchOneFrame(WidgetTester tester) async {
    late final AppScope scope;
    await tester.runAsync(() async {
      scope = await AppScope.boot();
    });
    await tester.pumpWidget(UhabitsApp(scope: scope));
    running = scope;
    return scope;
  }

  /// `onDestroy` + `onTerminate` for a [launchOneFrame] app: the tree goes
  /// first, so `_ThemedApp.dispose()` stops the midnight timer.
  Future<void> quitOneFrame(WidgetTester tester) async {
    final AppScope? scope = running;
    if (scope == null) return;
    running = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    scope.close();
  }

  testWidgets('a stored Dark theme paints the very first frame of the launch',
      (WidgetTester tester) async {
    // The system is light; the user is the one who chose Dark. That is the
    // case `pref_theme == THEME_DARK` exists for, and the one where a
    // `MaterialApp` that defaults to its light theme is visibly wrong.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    // Launch one: the user turns the theme dark from the overflow menu, the
    // way `ListHabitsMenuBehavior.onToggleNightMode` does it.
    final JourneySession session = app = JourneySession(tester, device);
    await session.launch();
    await skipIntro(tester);
    await openOverflowMenu(tester);
    await tapListMenuItem(tester, ListHabitsMenuItems.toggleNightMode);
    await settleIo(tester);
    expect(windowBackground(tester), darkBackground,
        reason: 'the precondition: the running app went dark when the menu '
            'item was tapped');
    await session.quit();

    // Launch two: the user opens the app again the next morning.
    await launchOneFrame(tester);

    expect(windowBackground(tester), darkBackground,
        reason: 'audit3.one-light-themed-frame-on-every#1: the theme is '
            'applied before the first layout, so the window is already dark '
            'on the very first frame. Applying it from a post-frame callback '
            'means frame 1 is painted with the initial LightTheme() and every '
            'launch flashes white.');
    expect(windowBackground(tester), isNot(lightBackground),
        reason: 'and never the light one, not for a single frame');

    // And it stays dark once the app has settled — the fix is an earlier
    // apply, not a different one.
    await settleIo(tester);
    expect(windowBackground(tester), darkBackground,
        reason: 'audit3.one-light-themed-frame-on-every#1: the applied theme '
            'is the same theme the running app keeps');

    await quitOneFrame(tester);
  });

  testWidgets('and a phone in dark mode gets a dark first frame too',
      (WidgetTester tester) async {
    // `pref_theme` is still THEME_AUTOMATIC — the shipped default — and the OS
    // is dark, which `AndroidThemeSwitcher.getSystemTheme()` reads before
    // `apply()` in the same `onCreate`.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await launchOneFrame(tester);

    expect(windowBackground(tester), darkBackground,
        reason: 'audit3.one-light-themed-frame-on-every#1: the window is '
            'already dark on the very first frame. A first run resolves the '
            'system brightness during onCreate, not one frame later.');

    // The app is only torn down after it has finished starting: `onResume`
    // arms the midnight timer, and `dispose()` is what stops it again.
    await settleIo(tester);
    await quitOneFrame(tester);
  });

  testWidgets('a light-themed phone still gets a light first frame',
      (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await launchOneFrame(tester);

    expect(windowBackground(tester), lightBackground,
        reason: 'audit3.one-light-themed-frame-on-every#1: applying earlier '
            'must not change *which* theme is applied — an automatic theme on '
            'a light phone is still LightTheme');

    await settleIo(tester);
    await quitOneFrame(tester);
  });
}
