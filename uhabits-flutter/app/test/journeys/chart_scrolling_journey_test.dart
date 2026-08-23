/// Journey: the user walks the habit-detail charts backwards through time.
///
/// `audit3.charts-on-the-habit-detail-screen#1`. Upstream every chart on
/// `ShowHabitActivity` is hosted by a scroller — `AndroidDataView` for the
/// History (bar) and Calendar (history) charts, `ScrollableChart` for the Score
/// and Frequency charts — and the calendar inside the history-editor dialog is
/// hosted by `AndroidDataView` too. A horizontal drag on any of them advances
/// `dataOffset`, which is how a user reaches last month's data at all; none of
/// them can be dragged into the future.
///
/// The drags below are made on the screen the running app built for itself, so
/// what is asserted is the wiring: a card that hosts its chart in a bare
/// `CoreView` looks exactly like a working card to a test that sets
/// `dataOffset` by hand.
library;

// `ShowHabitCard` and `BarChart` are not re-exported from the core barrel.
// ignore_for_file: implementation_imports

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart'
    show HistoryChart, HistoryEditorDialog;
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/frequency_card_view.dart'
    show FrequencyChartView;
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart'
    show HistoryCardView;
import 'package:uhabits/ui/habits/show/cards/score_card_view.dart'
    show ScoreChartView;
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit.dart'
    show ShowHabitCard;
import 'package:uhabits_core/src/ui/views/bar_chart.dart' show BarChart;

import 'journey.dart';

/// The rule, verbatim, for every `reason:` below.
const String rule = 'audit3.charts-on-the-habit-detail-screen#1 — In the '
    'Kotlin app: On the habit detail screen a horizontal drag or fling on the '
    'History (bar), Calendar (history), Score or Frequency chart advances the '
    "chart's dataOffset, so the user walks backwards through weeks/months/"
    'years of data; the same is true of the calendar inside the history-editor '
    'dialog, which is how past days are edited at all. Score/Frequency use '
    'ScrollableChart (clamped to maxDataOffset = 12*200), History/Bar use '
    "AndroidDataView's Scroller, and both refuse to scroll into the future.";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_chart_scroll');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// Taller than a phone so every card is laid out at once: a journey should
  /// not have to scroll the page to reach the chart it is dragging.
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openHabit(WidgetTester tester, {String name = 'Meditate'}) async {
    useTallScreen(tester);
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: name, question: 'Did you $name today?');
    await tapHabit(tester, name);
    expect(find.byType(ShowHabitScreen), findsOneWidget);
  }

  Finder chartOf(ShowHabitCard which) => find.descendant(
        of: find.byKey(ShowHabitScreen.cardKey(which), skipOffstage: false),
        matching: find.byType(CoreView),
      );

  T viewOf<T>(WidgetTester tester, Finder chart) =>
      tester.widget<CoreView>(chart).view as T;

  /// One horizontal drag of [dx] logical pixels across [chart].
  ///
  /// The first move only pays the touch slop — with the default
  /// DragStartBehavior.start the recogniser swallows whatever it took to win
  /// the arena against the page's own vertical scroll — so the second move is
  /// the one the chart sees.
  Future<void> dragChart(
    WidgetTester tester,
    Finder chart,
    double dx,
  ) async {
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(chart));
    await gesture.moveBy(Offset(dx.isNegative ? -20 : 20, 0));
    await gesture.moveBy(Offset(dx, 0));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('the Calendar card scrolls into the past', (tester) async {
    await openHabit(tester);
    final Finder chart = chartOf(ShowHabitCard.history);
    expect(viewOf<HistoryChart>(tester, chart).dataOffset, 0,
        reason: '$rule The chart opens on today.');

    await dragChart(tester, chart, 120);

    final HistoryChart scrolled = viewOf<HistoryChart>(tester, chart);
    expect(scrolled.dataOffset, greaterThan(0), reason: rule);
    expect(scrolled.dataOffset, (120 / scrolled.dataColumnWidth).floor(),
        reason: '$rule dataOffset = scrollerX / dataColumnWidth.');
  });

  testWidgets('the Calendar card refuses to scroll into the future',
      (tester) async {
    await openHabit(tester);
    final Finder chart = chartOf(ShowHabitCard.history);

    await dragChart(tester, chart, -300);
    expect(viewOf<HistoryChart>(tester, chart).dataOffset, 0,
        reason: '$rule max(0, …) — there is no future to scroll to.');

    // And back: the same drag rightwards has to reach the past again, rather
    // than being eaten by the negative distance above… once the scroller has
    // paid that debt back, which is what Android's Scroller does too.
    await dragChart(tester, chart, 300);
    await dragChart(tester, chart, 120);
    expect(viewOf<HistoryChart>(tester, chart).dataOffset, greaterThan(0),
        reason: rule);
  });

  testWidgets('the History (bar) card scrolls into the past', (tester) async {
    await openHabit(tester);
    final Finder chart = chartOf(ShowHabitCard.bar);
    expect(viewOf<BarChart>(tester, chart).dataOffset, 0, reason: rule);

    await dragChart(tester, chart, 120);

    final BarChart scrolled = viewOf<BarChart>(tester, chart);
    expect(scrolled.dataOffset, greaterThan(0), reason: rule);
    expect(scrolled.dataOffset, (120 / scrolled.dataColumnWidth).floor(),
        reason: '$rule dataOffset = scrollerX / dataColumnWidth.');

    await dragChart(tester, chart, -1000);
    expect(viewOf<BarChart>(tester, chart).dataOffset, 0,
        reason: '$rule and no bar chart scrolls into the future either.');
  });

  testWidgets('the Score card scrolls into the past', (tester) async {
    await openHabit(tester);
    final Finder chart = chartOf(ShowHabitCard.score);
    expect(viewOf<ScoreChartView>(tester, chart).dataOffset, 0, reason: rule);

    await dragChart(tester, chart, 300);

    expect(viewOf<ScoreChartView>(tester, chart).dataOffset, greaterThan(0),
        reason: rule);

    await dragChart(tester, chart, -1000);
    expect(viewOf<ScoreChartView>(tester, chart).dataOffset, 0,
        reason: '$rule ScrollableChart clamps the offset to >= 0.');
  });

  testWidgets('the Frequency card scrolls into the past', (tester) async {
    await openHabit(tester);
    final Finder chart = chartOf(ShowHabitCard.frequency);
    expect(viewOf<FrequencyChartView>(tester, chart).dataOffset, 0,
        reason: rule);

    await dragChart(tester, chart, 300);

    expect(viewOf<FrequencyChartView>(tester, chart).dataOffset, greaterThan(0),
        reason: rule);

    await dragChart(tester, chart, -1000);
    expect(viewOf<FrequencyChartView>(tester, chart).dataOffset, 0,
        reason: '$rule ScrollableChart clamps the offset to >= 0.');
  });

  testWidgets('the calendar inside the history editor scrolls into the past',
      (tester) async {
    await openHabit(tester);
    await tester.ensureVisible(find.byKey(HistoryCardView.editButtonKey));
    await tester.tap(find.byKey(HistoryCardView.editButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryEditorDialog), findsOneWidget,
        reason: '$rule The Edit button is the way in.');

    final Finder chart = find.descendant(
      of: find.byType(HistoryEditorDialog),
      matching: find.byType(CoreView),
    );
    expect(HistoryEditorDialog.current!.chart!.dataOffset, 0, reason: rule);

    await dragChart(tester, chart, 120);

    final HistoryChart scrolled = HistoryEditorDialog.current!.chart!;
    expect(scrolled.dataOffset, greaterThan(0),
        reason: '$rule Without this the dialog can only edit the days that '
            'happen to be on screen.');
    expect(scrolled.dataOffset, (120 / scrolled.dataColumnWidth).floor(),
        reason: '$rule dataOffset = scrollerX / dataColumnWidth.');

    await dragChart(tester, chart, -1000);
    expect(HistoryEditorDialog.current!.chart!.dataOffset, 0,
        reason: '$rule and not into the future.');
  });

  /// The same journeys again, on a screen the app actually ships on.
  ///
  /// `useTallScreen` above lays every card out at once, which is convenient —
  /// and which removes the two things a phone has: a page with a real scroll
  /// range, and (on iOS) a route transition that carries its own horizontal
  /// gesture. `feedback.chart-scrolling-is-only-proven-on-android#1`.
  group('on a phone-sized screen', () {
    const String phoneRule =
        'feedback.chart-scrolling-is-only-proven-on-android#1 — In the Kotlin '
        'app: the habit screen scrolls vertically while each chart scrolls '
        'horizontally, on every device the app runs on. A journey run on a '
        'screen too tall to scroll, on the one platform whose page transition '
        'has no gesture of its own, cannot see either half break.';

    /// iPhone 17: 402x874 logical points. The habit page is ~1357 points tall,
    /// so this is a viewport with a genuine scroll range.
    Future<void> openOnPhone(WidgetTester tester,
        {TargetPlatform? platform}) async {
      if (platform != null) {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
      }
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      app = JourneySession(tester, device);
      await app.launch();
      await skipIntro(tester);
      await createHabit(tester,
          name: 'Meditate', question: 'Did you Meditate today?');
      await tapHabit(tester, 'Meditate');
      expect(find.byType(ShowHabitScreen), findsOneWidget);
    }

    ScrollableState pageOf(WidgetTester tester) =>
        tester.state<ScrollableState>(find.descendant(
          of: find.byType(ShowHabitScreen),
          matching: find.byType(Scrollable),
        ));

    testWidgets('the Calendar card still scrolls inside a scrolling page',
        (tester) async {
      await openOnPhone(tester);
      final Finder card = find.byKey(
          ShowHabitScreen.cardKey(ShowHabitCard.history),
          skipOffstage: false);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final Finder chart =
          find.descendant(of: card, matching: find.byType(CoreView));

      expect(viewOf<HistoryChart>(tester, chart).dataOffset, 0,
          reason: phoneRule);
      await dragChart(tester, chart, 120);

      final HistoryChart scrolled = viewOf<HistoryChart>(tester, chart);
      expect(scrolled.dataOffset, (120 / scrolled.dataColumnWidth).floor(),
          reason: '$phoneRule The page must not eat the horizontal drag.');
    });

    testWidgets('a vertical drag that starts on a chart scrolls the page',
        (tester) async {
      await openOnPhone(tester);
      final ScrollableState page = pageOf(tester);
      expect(page.position.pixels, 0.0, reason: '$phoneRule It opens at the '
          'top, and has somewhere to go.');
      expect(page.position.maxScrollExtent, greaterThan(200.0),
          reason: '$phoneRule Without a scroll range this proves nothing.');

      // The Score card sits in the upper half at rest, so this drag starts on
      // a chart and has room to travel.
      final Finder chart = chartOf(ShowHabitCard.score);
      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(chart));
      await gesture.moveBy(const Offset(0, -20));
      await gesture.moveBy(const Offset(0, -180));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(page.position.pixels, greaterThan(0.0),
          reason: "$phoneRule The chart's horizontal recogniser must lose the "
              'arena to the page for a vertical drag, or the user cannot '
              'reach the cards below the first chart at all.');
    });

    testWidgets('on iOS a drag on a chart scrolls it and does not pop the page',
        (tester) async {
      // `flutter test` reports TargetPlatform.android, so every other journey
      // here builds a Zoom page transition, which has no gesture of its own.
      // On iOS the route is a Cupertino transition with an interactive back
      // gesture, and that gesture is a horizontal drag.
      await openOnPhone(tester, platform: TargetPlatform.iOS);
      expect(defaultTargetPlatform, TargetPlatform.iOS, reason: phoneRule);

      final Finder card = find.byKey(
          ShowHabitScreen.cardKey(ShowHabitCard.history),
          skipOffstage: false);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final Finder chart =
          find.descendant(of: card, matching: find.byType(CoreView));

      await dragChart(tester, chart, 120);
      // The override has done its work; the binding checks after the body that
      // no foundation debug variable is still set.
      debugDefaultTargetPlatformOverride = null;

      expect(find.byType(ShowHabitScreen), findsOneWidget,
          reason: '$phoneRule A drag towards the past must not be taken for '
              'the back gesture and close the habit.');
      expect(viewOf<HistoryChart>(tester, chart).dataOffset, greaterThan(0),
          reason: phoneRule);
    });
  });
}
