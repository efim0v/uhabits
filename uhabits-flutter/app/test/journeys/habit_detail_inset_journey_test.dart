/// Journey: the user scrolls to the bottom of a habit's detail screen.
///
/// `audit4.habit-detail-screen-never-applies-the` — the last card sits under
/// the Android navigation bar because the scrolling card column is never
/// padded by the bottom window inset.
///
/// It is a journey rather than a widget test for the reason the harness
/// exists: the inset is applied by the screen the *list* pushes, and a test
/// that builds `ShowHabitScreen` itself supplies the `MediaQuery` too, so it
/// can prove the padding widget works while the running app still shows a card
/// under the gesture bar. Here the phone declares a navigation bar before the
/// app boots, and the journey walks list → detail exactly as the user does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/common/window_insets.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  /// The phone's navigation bar, in logical pixels — the number
  /// `WindowInsetsCompat.Type.systemBars().bottom` reports on a gesture-bar
  /// device.
  const double navigationBar = 48;

  setUp(() {
    device = TestDevice.create('uhabits_journey_detail_inset');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// A phone whose window is intruded on at the bottom by the navigation bar.
  ///
  /// `viewPadding` is the one Flutter reports whether or not the keyboard is
  /// up, which is what `applyBottomInset`'s `systemBars` half is; the screen is
  /// tall so that every card is laid out without scrolling.
  void useDeviceWithNavigationBar(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: navigationBar);
    tester.view.padding = const FakeViewPadding(bottom: navigationBar);
    addTearDown(tester.view.reset);
  }

  testWidgets('the card column clears the navigation bar',
      (WidgetTester tester) async {
    const String rule =
        'audit4.habit-detail-screen-never-applies-the#1 — After every state '
        'push, the scrolling card column is padded at the bottom by '
        'max(systemBars.bottom, ime.bottom), so the ninth card (Frequency, or '
        'Streaks for a numerical habit) can be scrolled entirely clear of the '
        'Android navigation bar / gesture bar.';

    useDeviceWithNavigationBar(tester);
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(
      tester,
      name: 'Track time',
      question: 'Did you track time today?',
    );

    await tapHabit(tester, 'Track time');
    expect(find.byType(ShowHabitScreen), findsOneWidget,
        reason: '$rule The journey has to be on the detail screen first.');

    // `binding.linearLayout.applyBottomInset()` — the LinearLayout is the
    // ScrollView's child, so the padding travels with the content rather than
    // shrinking the viewport. That is the difference between a card that can
    // be scrolled clear of the bar and one that merely starts above it.
    final Finder scrollable = find.descendant(
      of: find.byType(ShowHabitScreen),
      matching: find.byType(Scrollable),
    );
    final Finder inset = find.descendant(
      of: scrollable.first,
      matching: find.byType(BottomInset),
    );
    expect(inset, findsOneWidget,
        reason: '$rule The padding is applied inside the scroll view, on the '
            'card column itself — `binding.linearLayout`, not the ScrollView.');

    // And it is the window's bottom inset, not a constant.
    final Finder column = find.descendant(
      of: inset,
      matching: find.byType(Column),
    );
    final Rect padded = tester.getRect(inset);
    final Rect cards = tester.getRect(column.first);
    expect(padded.bottom - cards.bottom, navigationBar,
        reason: '$rule The gap below the last card is exactly the system-bars '
            'inset the phone reported.');

    // The helper the whole port shares says the same number, so a phone with a
    // keyboard up gets `max(systemBars.bottom, ime.bottom)` for free.
    final MediaQueryData media =
        MediaQuery.of(tester.element(find.byType(ShowHabitScreen)));
    expect(bottomInsetOf(media), navigationBar, reason: rule);
  });
}
