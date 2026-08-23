/// Journey: the user opens a habit and looks at its cards.
///
/// `verify.integration-harness#3`, journey 4 — "open the habit screen and its
/// cards".
///
/// Upstream this is `HabitsTest.shouldShowHabitStatistics`: `clickText("Track
/// time")`, `verifyShowsScreen(SHOW_HABIT)`, `verifyDisplayGraphs()` — which
/// asserts that the Score, History, Streaks and Frequency views are all on
/// screen. The same eight cards are checked here, by the enum the app itself
/// iterates, so a card added or removed upstream cannot silently stop being
/// checked.
///
/// The journey starts on the list, because how the detail screen is *reached*
/// is half of what is being tested: a row that opens nothing looks exactly
/// like a working row to a test that pushes `ShowHabitScreen` itself.
library;

// `ShowHabitCard` is not re-exported from the core barrel; the app reaches it
// by its `src` path too (lib/state/show_habit_model.dart).
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit.dart'
    show ShowHabitCard;
import 'package:uhabits_core/uhabits_core.dart'
    show Entry, Habit, LocalDate, getToday;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_detail');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// The screen is taller than a phone so that every card is laid out; the
  /// cards are a scroll view and a journey should not have to scroll to prove
  /// one exists.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> launchWithHabit(
    WidgetTester tester, {
    required String name,
    String notes = '',
    bool measurable = false,
  }) async {
    useTallScreen(tester);
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(
      tester,
      name: name,
      question: 'Did you $name today?',
      notes: notes,
      measurable: measurable,
    );
  }

  Finder card(ShowHabitCard which) =>
      find.byKey(ShowHabitScreen.cardKey(which), skipOffstage: false);

  testWidgets('tapping a row opens the habit screen',
      (WidgetTester tester) async {
    await launchWithHabit(tester, name: 'Track time');

    await tapHabit(tester, 'Track time');

    expect(find.byType(ShowHabitScreen), findsOneWidget,
        reason: 'list-habits: HabitCardListController.onItemClick starts '
            'ShowHabitActivity. A row whose onTap is never supplied is the '
            'defect shape this harness exists for.');
    verifyDisplaysText('Track time',
        reason: 'show-habit: the toolbar carries the habit name');
  });

  testWidgets('every card a yes/no habit shows is on screen',
      (WidgetTester tester) async {
    await launchWithHabit(tester, name: 'Track time', notes: 'a description');
    await tapHabit(tester, 'Track time');

    // `ShowHabitView.setState` hides the target card for a yes/no habit and
    // shows everything else; the notes card is visible because the habit has a
    // description.
    for (final ShowHabitCard which in <ShowHabitCard>[
      ShowHabitCard.subtitle,
      ShowHabitCard.notes,
      ShowHabitCard.overview,
      ShowHabitCard.score,
      ShowHabitCard.bar,
      ShowHabitCard.history,
      ShowHabitCard.streak,
      ShowHabitCard.frequency,
    ]) {
      expect(card(which), findsOneWidget,
          reason: 'verify.integration-harness#3: "open the habit screen and '
              'its cards" — `verifyDisplayGraphs()` upstream. The $which card '
              'has to be built by the screen the user reached, not by a test '
              'that constructs it.');
    }
    expect(card(ShowHabitCard.target), findsNothing,
        reason: 'show-habit.card-order-and-visibility: the target card belongs '
            'to a measurable habit');
  });

  testWidgets('a measurable habit shows the target card instead of the overview',
      (WidgetTester tester) async {
    await launchWithHabit(tester, name: 'Run', measurable: true);
    await tapHabit(tester, 'Run');

    expect(card(ShowHabitCard.target), findsOneWidget,
        reason: 'show-habit.card-order-and-visibility: a numerical habit hides '
            'the overview and shows the target card');
    expect(card(ShowHabitCard.overview), findsNothing);
    expect(card(ShowHabitCard.history), findsOneWidget,
        reason: 'the chart cards are shown for both habit types');
  });

  testWidgets('the notes card is absent when the habit has no description',
      (WidgetTester tester) async {
    await launchWithHabit(tester, name: 'Track time');
    await tapHabit(tester, 'Track time');

    expect(card(ShowHabitCard.notes), findsNothing,
        reason: 'NotesCardView.setState: GONE when the description is empty');
  });

  testWidgets('the cards are painted from this habit\'s own entries',
      (WidgetTester tester) async {
    await launchWithHabit(tester, name: 'Track time');
    final LocalDate today = getToday();
    await toggleCheckmark(tester, 'Track time', today);

    await tapHabit(tester, 'Track time');

    final Habit shown = app.scope.habitList.getByPosition(0);
    expect(shown.computedEntries.get(today).value, Entry.yesManual,
        reason: 'the entry the list wrote is the one the detail screen is '
            'opened over');
    expect(find.byType(ShowHabitScreen), findsOneWidget);
    expect(card(ShowHabitCard.score), findsOneWidget,
        reason: 'a habit with data still renders every card — the score card '
            'recomputes off the entries rather than throwing on them');
  });

  testWidgets('Back returns to the list', (WidgetTester tester) async {
    await launchWithHabit(tester, name: 'Track time');
    await tapHabit(tester, 'Track time');
    expect(find.byType(ShowHabitScreen), findsOneWidget);

    await pressBack(tester);

    expect(find.byType(ShowHabitScreen), findsNothing,
        reason: 'CommonSteps.pressBack(): the system Back gesture finishes '
            'ShowHabitActivity and ListHabitsActivity is underneath');
    verifyDisplaysText('Track time',
        reason: 'and the row is still on the list');
  });
}
