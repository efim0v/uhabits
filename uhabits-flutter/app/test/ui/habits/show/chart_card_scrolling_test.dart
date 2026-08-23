/// What each chart card does with the scroller it hosts.
///
/// `audit3.charts-on-the-habit-detail-screen#1` is asserted end to end in
/// test/journeys/chart_scrolling_journey_test.dart, on the screen the app
/// builds for itself. What is left to a card is the bookkeeping the screen
/// cannot show: which host each chart gets, and what a refresh does to a chart
/// the user has already scrolled — `resetDataOffset()` on the Bar card,
/// `reset()` on the Score card, a brand-new chart object on the Calendar card,
/// and nothing at all on the Frequency card.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/common/scrollable_chart.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/bar_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/frequency_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/score_card_view.dart';
import 'package:uhabits_core/src/ui/views/bar_chart.dart' show BarChart;
import 'package:uhabits_core/src/ui/views/history_chart.dart'
    show HistoryChart, Square;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  // The date the Android goldens were captured on: Sunday, 25 January 2015.
  final core.LocalDate today = core.LocalDate.ymd(2015, 1, 25);
  final core.Theme theme = core.LightTheme();
  const core.PaletteColor habitColor = core.PaletteColor(7);

  setUp(() => core.setToday(today));
  tearDown(core.resetToday);

  BarCardState barState({int boolSpinnerPosition = 0}) => BarCardState(
        theme: theme,
        boolSpinnerPosition: boolSpinnerPosition,
        bucketSize: BarCardPresenter.boolBucketSizes[boolSpinnerPosition],
        color: habitColor,
        entries: <core.Entry>[
          core.Entry(today, 5000),
          core.Entry(today.minus(7), 3000),
        ],
        isNumerical: false,
        numericalSpinnerPosition: 0,
      );

  ScoreCardState scoreState({int spinnerPosition = 1}) => ScoreCardState(
        scores: <core.Score>[
          for (int i = 0; i < 40; i++) core.Score(today.minus(i * 7), 0.5),
        ],
        bucketSize: 7,
        spinnerPosition: spinnerPosition,
        color: habitColor,
        theme: theme,
      );

  HistoryCardState historyState() => HistoryCardState(
        color: habitColor,
        firstWeekday: core.DayOfWeek.sunday,
        series: <Square>[Square.on, Square.off, Square.hatched],
        defaultSquare: Square.off,
        notesIndicators: <bool>[true, false, false],
        theme: theme,
        today: today,
      );

  FrequencyCardState frequencyState({bool isNumerical = false}) =>
      FrequencyCardState(
        color: habitColor,
        firstWeekday: core.DayOfWeek.sunday,
        frequency: <core.LocalDate, List<int>>{
          core.LocalDate.ymd(2015, 1, 1): <int>[0, 4, 2, 0, 0, 0, 0],
        },
        theme: theme,
        isNumerical: isNumerical,
      );

  group('show-habit.chart-scrolling', () {
    testWidgets('#1 #4 the Bar card scrolls, and a refresh resets it',
        (tester) async {
      await _pump(tester, BarCardView(state: barState()));

      await _dragBy(tester, 90);
      final BarChart scrolled = _viewOf<BarChart>(tester);
      expect(scrolled.dataOffset, (90 / scrolled.dataColumnWidth).floor(),
          reason: 'show-habit.chart-scrolling#1 — the Bar chart is hosted in '
              'an AndroidDataView, and dataOffset = scrollerX / '
              'dataColumnWidth');
      expect(scrolled.dataOffset, greaterThan(0),
          reason: 'show-habit.chart-scrolling#1');

      // `BarCardView.setState` ends with `binding.chart.resetDataOffset()`.
      await _pump(tester, BarCardView(state: barState(boolSpinnerPosition: 2)));
      expect(_viewOf<BarChart>(tester).dataOffset, 0,
          reason: 'show-habit.chart-scrolling#4 — BarCardView.setState calls '
              'resetDataOffset(), so any refresh jumps back to the most '
              'recent bucket');

      // And the scroller itself is back at zero, not merely reporting zero:
      // one bucket of travel is one column again.
      await _dragBy(tester, 18);
      expect(_viewOf<BarChart>(tester).dataOffset, 1,
          reason: 'show-habit.chart-scrolling#4');
    });

    testWidgets('#2 #5 the Score card scrolls, and a refresh resets it',
        (tester) async {
      await _pump(tester, ScoreCardView(state: scoreState()));

      await _dragBy(tester, 120);
      final ScoreChartView scrolled = _viewOf<ScoreChartView>(tester);
      expect(scrolled.dataColumnWidth, greaterThan(0.0),
          reason: 'show-habit.chart-scrolling#2 — '
              'setScrollerBucketSize(columnWidth)');
      expect(scrolled.dataOffset, (120 / scrolled.dataColumnWidth).floor(),
          reason: 'show-habit.chart-scrolling#2 — ScoreChart is a '
              'ScrollableChart, whose bucket is one column');
      expect(scrolled.dataOffset, greaterThan(0),
          reason: 'show-habit.chart-scrolling#2');

      // `ScoreCardView.setState` ends with `binding.scoreView.reset()`.
      await _pump(tester, ScoreCardView(state: scoreState(spinnerPosition: 3)));
      expect(_viewOf<ScoreChartView>(tester).dataOffset, 0,
          reason: 'show-habit.chart-scrolling#5 — ScoreCardView.setState calls '
              'reset(), so changing the bucket snaps back to the newest '
              'column');
    });

    testWidgets('#1 #7 the Calendar card scrolls, and a refresh resets it',
        (tester) async {
      await _pump(tester, HistoryCardView(state: historyState()));

      await _dragBy(tester, 63);
      final HistoryChart scrolled = _viewOf<HistoryChart>(tester);
      expect(scrolled.dataOffset, (63 / scrolled.dataColumnWidth).floor(),
          reason: 'show-habit.chart-scrolling#1 — the History chart is hosted '
              'in an AndroidDataView too');
      expect(scrolled.dataOffset, greaterThan(0),
          reason: 'show-habit.chart-scrolling#1');

      await _pump(tester, HistoryCardView(state: historyState()));
      final HistoryChart refreshed = _viewOf<HistoryChart>(tester);
      expect(identical(refreshed, scrolled), isFalse,
          reason: 'show-habit.chart-scrolling#7 — HistoryCardView replaces the '
              'whole HistoryChart object on every setState');
      expect(refreshed.dataOffset, 0,
          reason: 'show-habit.chart-scrolling#7 — which resets its dataOffset '
              'to 0');
    });

    testWidgets('#2 #6 the Frequency card scrolls, and a refresh does not '
        'reset it', (tester) async {
      await _pump(tester, FrequencyCardView(state: frequencyState()));

      await _dragBy(tester, 100);
      final FrequencyChartView scrolled = _viewOf<FrequencyChartView>(tester);
      expect(scrolled.dataColumnWidth, FrequencyCardView.chartHeight ~/ 8,
          reason: 'show-habit.chart-scrolling#2 — '
              'setScrollerBucketSize(baseSize), and baseSize is height / 8');
      expect(scrolled.dataOffset, (100 / scrolled.dataColumnWidth).floor(),
          reason: 'show-habit.chart-scrolling#2 — one bucket is one month');
      final int reached = scrolled.dataOffset;
      expect(reached, greaterThan(0), reason: 'show-habit.chart-scrolling#2');

      // `FrequencyCardView.setState` never touches the scroller.
      await _pump(
        tester,
        FrequencyCardView(state: frequencyState(isNumerical: true)),
      );
      expect(_viewOf<FrequencyChartView>(tester).dataOffset, reached,
          reason: 'show-habit.chart-scrolling#6 — the Frequency chart does not '
              'reset, so its scroll position survives a refresh');
    });

    testWidgets('#6 a card opened on an older column scrolls on from there',
        (tester) async {
      await _pump(
        tester,
        FrequencyCardView(state: frequencyState(), dataOffset: 3),
      );
      final FrequencyChartView chart = _viewOf<FrequencyChartView>(tester);
      expect(chart.dataOffset, 3,
          reason: 'show-habit.chart-scrolling#6 — the card hands its '
              'dataOffset to the chart');

      // The scroller has to agree with the offset it was opened on, the way
      // `onRestoreInstanceState` puts both back: one more bucket is the fourth
      // column, not the first.
      await _dragBy(tester, chart.dataColumnWidth);
      expect(_viewOf<FrequencyChartView>(tester).dataOffset, 4,
          reason: 'show-habit.chart-scrolling#6');
    });
  });
}

/// Pumps [card] into a 400dp-wide slot, the way chart_cards_test.dart does.
Future<void> _pump(WidgetTester tester, Widget card) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 400, child: card),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The core view the card handed to its [CoreView].
T _viewOf<T extends core.View>(WidgetTester tester) =>
    tester.widget<CoreView>(find.byType(CoreView)).view as T;

/// One horizontal drag of exactly [dx] logical pixels over the card's chart.
///
/// The first move only pays the touch slop — the recogniser swallows whatever
/// it took to win the arena against the page the card sits in — so the second
/// move is the one the chart sees.
Future<void> _dragBy(WidgetTester tester, double dx) async {
  final TestGesture gesture =
      await tester.startGesture(tester.getCenter(find.byType(ScrollableChart)));
  await gesture.moveBy(Offset(dx.isNegative ? -20 : 20, 0));
  await gesture.moveBy(Offset(dx, 0));
  await gesture.up();
  await tester.pumpAndSettle();
}
