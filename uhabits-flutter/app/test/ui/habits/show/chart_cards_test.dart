/// Widget tests for the six chart cards of the habit detail screen.
///
/// Two things are pinned here. The first is the card chrome the Android
/// layouts describe — which title, which colour, which spinner, how tall the
/// chart is — asserted against the real widget tree. The second is what each
/// chart actually paints: every card hosts a `core.View`, so the view is
/// pulled back out of its [CoreView] and replayed onto [_RecordingCanvas],
/// whose call trace is what a golden image would show. Colour, font size,
/// stroke width and text alignment are sticky on a `Canvas`, so each recorded
/// call carries the state it was made under.
///
/// Rule ids come from docs/parity/FEATURES.md.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/list/list_header.dart'
    show IntlLocalDateFormatter;
import 'package:uhabits/ui/habits/show/cards/bar_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/frequency_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/history_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/score_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/streak_card_view.dart';
import 'package:uhabits/ui/habits/show/cards/target_card_view.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart' as core;
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/ui/views/bar_chart.dart' show BarChart;
import 'package:uhabits_core/src/ui/views/history_chart.dart'
    show HistoryChart, OnDateClickedListener, Square;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  // The date the Android goldens were captured on: Sunday, 25 January 2015.
  final today = core.LocalDate.ymd(2015, 1, 25);
  final theme = core.LightTheme();

  // PaletteColor(7) is green; LightTheme resolves it to 0x388E3C.
  const habitColor = core.PaletteColor(7);
  final green = theme.color(7);
  const flutterGreen = Color(0xFF388E3C);

  final formatter = IntlLocalDateFormatter('en_US');

  setUp(() => core.setToday(today));
  tearDown(core.resetToday);

  // -------------------------------------------------------------------------
  // Score card
  // -------------------------------------------------------------------------

  core.Score score(core.LocalDate date, double value) => core.Score(date, value);

  ScoreCardState scoreState({
    List<core.Score>? scores,
    int bucketSize = 7,
    int spinnerPosition = 1,
  }) =>
      ScoreCardState(
        scores: scores ??
            <core.Score>[
              score(today, 1.0),
              score(today.minus(7), 0.5),
              score(today.minus(14), 0.0),
            ],
        bucketSize: bucketSize,
        spinnerPosition: spinnerPosition,
        color: habitColor,
        theme: theme,
      );

  group('show-habit.score-card', () {
    testWidgets('#11 the card is titled "Score" over a 220dp chart',
        (tester) async {
      await _pump(tester, ScoreCardView(state: scoreState()));

      expect(find.text('Score'), findsOneWidget,
          reason: 'show-habit.score-card#11');
      expect(tester.getSize(find.byType(CoreView)).height, 220.0,
          reason: 'show-habit.score-card#11');
    });

    testWidgets('#8 the title is tinted with theme.color(habit.color)',
        (tester) async {
      await _pump(tester, ScoreCardView(state: scoreState()));

      expect(tester.widget<Text>(find.text('Score')).style?.color, flutterGreen,
          reason: 'show-habit.score-card#8');
    });

    testWidgets('#1 the spinner offers the five bucket names, selected one '
        'showing', (tester) async {
      await _pump(
        tester,
        ScoreCardView(state: scoreState(spinnerPosition: 3)),
      );

      // A DropdownButton keeps the unselected items in the tree but offstage,
      // which is where a closed Android Spinner keeps them too.
      for (final label in <String>[
        'Day',
        'Week',
        'Month',
        'Quarter',
        'Year',
      ]) {
        expect(find.text(label, skipOffstage: false), findsOneWidget,
            reason: 'show-habit.score-card#1');
      }
      expect(find.text('Quarter'), findsOneWidget,
          reason: 'show-habit.score-card#1');
      final spinner = tester.widget<BucketSpinner>(
        find.byKey(ScoreCardView.spinnerKey),
      );
      expect(spinner.value, 3, reason: 'show-habit.score-card#1');
    });

    testWidgets('#7 picking a bucket persists it, then updates the widgets, '
        'then refreshes', (tester) async {
      final preferences = core.Preferences(core.MemoryStorage());
      final screen = _RecordingScoreScreen();
      final presenter =
          ScoreCardPresenter(preferences: preferences, screen: screen);

      await _pump(
        tester,
        ScoreCardView(
          state: scoreState(spinnerPosition: 1),
          onSpinnerPosition: presenter.onSpinnerPosition,
        ),
      );

      await tester.tap(find.byKey(ScoreCardView.spinnerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quarter').last);
      await tester.pumpAndSettle();

      expect(preferences.scoreCardSpinnerPosition, 3,
          reason: 'show-habit.score-card#7');
      expect(screen.calls, <String>['updateWidgets', 'refresh'],
          reason: 'show-habit.widget-refresh#1');
    });

    testWidgets('#1 the bucket sizes the spinner indexes are 1, 7, 31, 92, 365',
        (tester) async {
      expect(ScoreCardPresenter.bucketSizes, <int>[1, 7, 31, 92, 365],
          reason: 'show-habit.score-card#1');
    });
  });

  group('charts-canvas-theming.score-chart', () {
    /// 300x220, the chart slot of a card on a phone-width screen.
    _RecordingCanvas drawScore(ScoreCardState state) {
      final view = ScoreChartView(
        scores: state.scores,
        color: theme.colorOf(state.color),
        theme: theme,
        dateFormatter: formatter,
        bucketSize: state.bucketSize,
      );
      final canvas = _RecordingCanvas(width: 300, height: 220);
      view.draw(canvas);
      return canvas;
    }

    testWidgets('#7 five labelled grid rows, plus a closing line',
        (tester) async {
      final canvas = drawScore(scoreState());

      expect(canvas.texts.take(5).toList(),
          <String>['100%', '80%', '60%', '40%', '20%'],
          reason: 'charts-canvas-theming.score-chart#7');
      for (final op in canvas.opsNamed('drawText').take(5)) {
        expect(op.textAlign, core.TextAlign.left,
            reason: 'charts-canvas-theming.score-chart#7');
        expect(op.color, theme.mediumContrastTextColor,
            reason: 'charts-canvas-theming.score-chart#15');
      }

      // baseSize = (220 - 35 - 11) ~/ 8 = 21, so the plot is 168 tall and
      // starts at paddingTop = 11. Six lines: one per row, one to close.
      final grid = canvas
          .opsNamed('drawLine')
          .where((op) => op.strokeWidth == 1.0)
          .toList();
      expect(grid.length, 6, reason: 'charts-canvas-theming.score-chart#7');
      const expectedRows = <double>[11.0, 44.6, 78.2, 111.8, 145.4, 179.0];
      for (var i = 0; i < expectedRows.length; i++) {
        expect(grid[i].args[1], closeTo(expectedRows[i], 1e-9),
            reason: 'charts-canvas-theming.score-chart#7');
      }
      for (final op in grid) {
        expect(op.color, theme.lowContrastTextColor,
            reason: 'charts-canvas-theming.score-chart#15');
      }
    });

    testWidgets('#9 a score of 1.0 reaches the top of the plot',
        (tester) async {
      final canvas = drawScore(scoreState());

      // Markers are two concentric circles; the newest score is the last pair.
      final circles = canvas.opsNamed('fillCircle');
      expect(circles.length, 6, reason: 'charts-canvas-theming.score-chart#11');
      final newest = circles[4];
      // y = paddingTop + columnHeight - (columnHeight * 1.0) - baseSize ~/ 2
      //     + baseSize / 2 = 11 + 168 - 168 - 10 + 10.5.
      expect(newest.args[1], 11.5,
          reason: 'charts-canvas-theming.score-chart#9');
    });

    testWidgets('#11 a marker is the card background under the habit colour',
        (tester) async {
      final canvas = drawScore(scoreState());
      final circles = canvas.opsNamed('fillCircle');

      // baseSize 21: outer = 10.5 - 4.725, inner = outer - 2.1.
      expect(circles[0].color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.score-chart#11');
      expect(circles[0].args[2], closeTo(5.775, 1e-9),
          reason: 'charts-canvas-theming.score-chart#11');
      expect(circles[1].color, green,
          reason: 'charts-canvas-theming.score-chart#11');
      expect(circles[1].args[2], closeTo(3.675, 1e-9),
          reason: 'charts-canvas-theming.score-chart#11');
    });

    testWidgets('#8 the newest score sits in the rightmost column',
        (tester) async {
      final canvas = drawScore(scoreState());
      final circles = canvas.opsNamed('fillCircle');

      // nColumns = floor(300 / 27) = 11, columnWidth = 300/11.
      const columnWidth = 300.0 / 11;
      expect(circles[4].args[0], closeTo(10 * columnWidth + 27.272 / 2, 0.01),
          reason: 'charts-canvas-theming.score-chart#8');
      // Three scores in eleven columns: eight columns stay blank.
      expect(circles.length ~/ 2, 3,
          reason: 'charts-canvas-theming.score-chart#8');
    });

    testWidgets('#10 consecutive markers are joined by a line in the habit '
        'colour', (tester) async {
      final canvas = drawScore(scoreState());
      final lines = canvas
          .opsNamed('drawLine')
          .where((op) => op.strokeWidth != 1.0)
          .toList();

      expect(lines.length, 2, reason: 'charts-canvas-theming.score-chart#10');
      for (final op in lines) {
        expect(op.color, green,
            reason: 'charts-canvas-theming.score-chart#10');
        // pGraph.strokeWidth = baseSize * 0.1.
        expect(op.strokeWidth, closeTo(2.1, 1e-9),
            reason: 'charts-canvas-theming.score-chart#5');
      }
    });

    testWidgets('#13 the footer prints a month once, then day numbers',
        (tester) async {
      final canvas = drawScore(scoreState());

      expect(canvas.texts.skip(5).toList(),
          <String>['2015', 'Jan', '18', '25'],
          reason: 'charts-canvas-theming.score-chart#13');
    });

    testWidgets('#12 a yearly bucket skips odd years and the column after a '
        'year', (tester) async {
      final canvas = drawScore(scoreState(
        bucketSize: 365,
        scores: <core.Score>[
          score(core.LocalDate.ymd(2015, 1, 1), 1.0),
          score(core.LocalDate.ymd(2014, 1, 1), 1.0),
          score(core.LocalDate.ymd(2013, 1, 1), 1.0),
          score(core.LocalDate.ymd(2012, 1, 1), 1.0),
        ],
      ));

      // 2012 prints and arms skipYear, which eats 2013 (also odd anyway);
      // 2014 prints and arms it again, which eats 2015.
      expect(canvas.texts.skip(5).toList(), <String>['2012', '2014'],
          reason: 'charts-canvas-theming.score-chart#12');
    });
  });

  // -------------------------------------------------------------------------
  // Bar card
  // -------------------------------------------------------------------------

  BarCardState barState({
    bool isNumerical = false,
    int boolSpinnerPosition = 0,
    int numericalSpinnerPosition = 0,
  }) =>
      BarCardState(
        theme: theme,
        boolSpinnerPosition: boolSpinnerPosition,
        bucketSize: isNumerical
            ? BarCardPresenter.numericalBucketSizes[numericalSpinnerPosition]
            : BarCardPresenter.boolBucketSizes[boolSpinnerPosition],
        color: habitColor,
        entries: <core.Entry>[
          core.Entry(today, 5000),
          core.Entry(today.minus(7), 3000),
        ],
        isNumerical: isNumerical,
        numericalSpinnerPosition: numericalSpinnerPosition,
      );

  group('show-habit.bar-card', () {
    testWidgets('#12 the card is titled "History", not "Bar"', (tester) async {
      await _pump(tester, BarCardView(state: barState()));

      expect(find.text('History'), findsOneWidget,
          reason: 'show-habit.bar-card#12');
      expect(tester.widget<Text>(find.text('History')).style?.color,
          flutterGreen,
          reason: 'show-habit.bar-card#12');
    });

    testWidgets('#3 a boolean habit gets the spinner without a Day option',
        (tester) async {
      await _pump(tester, BarCardView(state: barState()));

      expect(find.byKey(BarCardView.boolSpinnerKey), findsOneWidget,
          reason: 'show-habit.bar-card#3');
      expect(find.byKey(BarCardView.numericalSpinnerKey), findsNothing,
          reason: 'show-habit.bar-card#3');
      expect(find.text('Day', skipOffstage: false), findsNothing,
          reason: 'show-habit.bar-card#3');
      for (final label in <String>['Week', 'Month', 'Quarter', 'Year']) {
        expect(find.text(label, skipOffstage: false), findsOneWidget,
            reason: 'show-habit.bar-card#3');
      }
    });

    testWidgets('#2 a numerical habit gets the spinner with one',
        (tester) async {
      await _pump(tester, BarCardView(state: barState(isNumerical: true)));

      expect(find.byKey(BarCardView.numericalSpinnerKey), findsOneWidget,
          reason: 'show-habit.bar-card#2');
      expect(find.byKey(BarCardView.boolSpinnerKey), findsNothing,
          reason: 'show-habit.bar-card#2');
      expect(find.text('Day', skipOffstage: false), findsOneWidget,
          reason: 'show-habit.bar-card#2');
    });

    testWidgets('#1 the two bucket tables differ only by the Day entry',
        (tester) async {
      expect(BarCardPresenter.numericalBucketSizes, <int>[1, 7, 31, 92, 365],
          reason: 'show-habit.bar-card#1');
      expect(BarCardPresenter.boolBucketSizes, <int>[7, 31, 92, 365],
          reason: 'show-habit.bar-card#1');
    });

    testWidgets('#3 the boolean spinner reports its position', (tester) async {
      final reported = <int>[];
      await _pump(
        tester,
        BarCardView(
          state: barState(),
          onBoolSpinnerPosition: reported.add,
        ),
      );

      await tester.tap(find.byKey(BarCardView.boolSpinnerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quarter').last);
      await tester.pumpAndSettle();

      expect(reported, <int>[2], reason: 'show-habit.bar-card#3');
    });

    testWidgets('#6 #13 one series of value/1000 against the entry dates, in '
        'the habit colour, 220dp tall', (tester) async {
      await _pump(tester, BarCardView(state: barState()));

      final chart = _viewOf<BarChart>(tester);
      expect(chart.series, <List<double>>[
        <double>[5.0, 3.0],
      ], reason: 'show-habit.bar-card#6');
      expect(chart.colors, <core.Color>[green],
          reason: 'show-habit.bar-card#6');
      expect(chart.axis, <core.LocalDate>[today, today.minus(7)],
          reason: 'show-habit.bar-card#6');
      expect(tester.getSize(find.byType(CoreView)).height, 220.0,
          reason: 'show-habit.bar-card#13');
    });

    testWidgets('#7 every refresh starts back at the newest bucket',
        (tester) async {
      await _pump(tester, BarCardView(state: barState()));

      expect(_viewOf<BarChart>(tester).dataOffset, 0,
          reason: 'show-habit.bar-card#7');
    });
  });

  // -------------------------------------------------------------------------
  // History card
  // -------------------------------------------------------------------------

  HistoryCardState historyState({
    core.DayOfWeek firstWeekday = core.DayOfWeek.sunday,
  }) =>
      HistoryCardState(
        color: habitColor,
        firstWeekday: firstWeekday,
        series: <Square>[Square.on, Square.off, Square.hatched],
        defaultSquare: Square.off,
        notesIndicators: <bool>[true, false, false],
        theme: theme,
        today: today,
      );

  group('show-habit.history-card', () {
    testWidgets('#13 the card is titled "Calendar" over a 160dp chart',
        (tester) async {
      await _pump(tester, HistoryCardView(state: historyState()));

      expect(find.text('Calendar'), findsOneWidget,
          reason: 'show-habit.history-card#13');
      expect(tester.widget<Text>(find.text('Calendar')).style?.color,
          flutterGreen,
          reason: 'show-habit.history-card#13');
      expect(tester.getSize(find.byType(CoreView)).height, 160.0,
          reason: 'show-habit.history-card#13');
    });

    testWidgets('#14 an "Edit" button sits under the chart', (tester) async {
      var clicks = 0;
      await _pump(
        tester,
        HistoryCardView(
          state: historyState(),
          onClickEditButton: () => clicks++,
        ),
      );

      final button = find.byKey(HistoryCardView.editButtonKey);
      expect(button, findsOneWidget, reason: 'show-habit.history-card#14');
      expect(find.text('Edit'), findsOneWidget,
          reason: 'show-habit.history-card#14');
      expect(tester.getCenter(button).dy,
          greaterThan(tester.getCenter(find.byType(CoreView)).dy),
          reason: 'show-habit.history-card#14');

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(clicks, 1, reason: 'show-habit.history-card#14');
    });

    testWidgets('#1 #5 the state is handed to the core HistoryChart verbatim',
        (tester) async {
      await _pump(tester, HistoryCardView(state: historyState()));

      final chart = _viewOf<HistoryChart>(tester);
      expect(chart.series, <Square>[Square.on, Square.off, Square.hatched],
          reason: 'show-habit.history-card#1');
      expect(chart.defaultSquare, Square.off,
          reason: 'show-habit.history-card#5');
      expect(chart.notesIndicators, <bool>[true, false, false],
          reason: 'show-habit.history-card#4');
      expect(chart.today, today, reason: 'show-habit.history-card#1');
      expect(chart.paletteColor, habitColor,
          reason: 'show-habit.history-card#6');
      expect(chart.firstWeekday, core.DayOfWeek.sunday,
          reason: 'show-habit.history-card#10');
    });
  });

  group('show-habit.history-interaction', () {
    testWidgets('#13 the presenter is installed as the chart\'s date listener',
        (tester) async {
      final listener = _RecordingDateListener();
      await _pump(
        tester,
        HistoryCardView(state: historyState(), listener: listener),
      );

      expect(_viewOf<HistoryChart>(tester).onDateClickedListener,
          same(listener),
          reason: 'show-habit.history-interaction#13');
    });

    testWidgets('#1 #2 a tap becomes a short press on the hit-tested date',
        (tester) async {
      final listener = _RecordingDateListener();
      await _pump(
        tester,
        HistoryCardView(state: historyState(), listener: listener),
      );
      final chart = _viewOf<HistoryChart>(tester);

      // 300x160: squareSize 20, thirteen columns, and today is a Sunday under
      // a Sunday-first week, so the top-left cell is today - 84 days.
      chart.draw(_RecordingCanvas(width: 300, height: 160));

      chart.onClick(10, 30);
      expect(listener.shortPresses, <core.LocalDate>[today.minus(84)],
          reason: 'show-habit.history-interaction#1');

      // Row 0 is the month header, so it is not a date.
      chart.onClick(10, 10);
      expect(listener.shortPresses.length, 1,
          reason: 'show-habit.history-interaction#1');

      // The last column's bottom rows run past today.
      chart.onClick(250, 150);
      expect(listener.shortPresses.length, 1,
          reason: 'show-habit.history-interaction#2');

      chart.onLongClick(250, 30);
      expect(listener.longPresses, <core.LocalDate>[today],
          reason: 'show-habit.history-interaction#1');
    });
  });

  // -------------------------------------------------------------------------
  // Streak card
  // -------------------------------------------------------------------------

  core.Streak streak(core.LocalDate end, int length) =>
      core.Streak(end.minus(length - 1), end);

  StreakCardState streakState({List<core.Streak>? streaks}) => StreakCardState(
        color: habitColor,
        bestStreaks: streaks ??
            <core.Streak>[
              streak(core.LocalDate.ymd(2015, 1, 25), 10),
              streak(core.LocalDate.ymd(2014, 12, 18), 8),
              streak(core.LocalDate.ymd(2014, 11, 13), 4),
            ],
        theme: theme,
      );

  group('show-habit.streak-card', () {
    testWidgets('#10 the card is titled "Best streaks"', (tester) async {
      await _pump(tester, StreakCardView(state: streakState()));

      expect(find.text('Best streaks'), findsOneWidget,
          reason: 'show-habit.streak-card#10');
      expect(tester.widget<Text>(find.text('Best streaks')).style?.color,
          flutterGreen,
          reason: 'show-habit.streak-card#10');
    });

    testWidgets('#9 the chart is one 20dp row per streak', (tester) async {
      await _pump(tester, StreakCardView(state: streakState()));

      expect(tester.getSize(find.byType(CoreView)).height, 60.0,
          reason: 'show-habit.streak-card#9');
    });

    testWidgets('#5 #6 bar width follows the longest streak, and so does the '
        'colour', (tester) async {
      final view = StreakChartView(
        streaks: streakState().bestStreaks,
        color: green,
        theme: theme,
        dateFormatter: formatter,
      );
      final canvas = _RecordingCanvas(width: 300, height: 60);
      view.draw(canvas);

      final bars = canvas.opsNamed('fillRoundRect');
      expect(bars.length, 3, reason: 'show-habit.streak-card#5');

      // Labels are "Jan 25, 2015": 12 glyphs at 0.6 em, so maxLabelWidth is
      // 72 and availableWidth is 300 - 144 - 2 * (0.5 * 1.171 * 10).
      const available = 300.0 - 2 * 72.0 - 11.71;
      expect(bars[0].args[2], closeTo(available, 1e-9),
          reason: 'show-habit.streak-card#5');
      expect(bars[1].args[2], closeTo(0.8 * available, 1e-9),
          reason: 'show-habit.streak-card#5');
      expect(bars[2].args[2], closeTo(0.4 * available, 1e-9),
          reason: 'show-habit.streak-card#5');

      expect(bars[0].color, green, reason: 'show-habit.streak-card#6');
      expect(bars[1].color, green.withAlpha(192 / 255),
          reason: 'show-habit.streak-card#6');
      expect(bars[2].color, theme.lowContrastTextColor,
          reason: 'show-habit.streak-card#6');

      // Every bar is centred on the view.
      for (final bar in bars) {
        expect(bar.args[0] + bar.args[2] / 2, closeTo(150.0, 1e-9),
            reason: 'show-habit.streak-card#5');
      }
    });

    testWidgets('#7 #8 the length sits in the bar, the dates flank it',
        (tester) async {
      final view = StreakChartView(
        streaks: streakState().bestStreaks,
        color: green,
        theme: theme,
        dateFormatter: formatter,
      );
      final canvas = _RecordingCanvas(width: 300, height: 60);
      view.draw(canvas);

      expect(canvas.texts.take(3).toList(),
          <String>['10', 'Jan 16, 2015', 'Jan 25, 2015'],
          reason: 'show-habit.streak-card#8');
      final length = canvas.opsNamed('drawText').first;
      expect(length.textAlign, core.TextAlign.center,
          reason: 'show-habit.streak-card#7');
      // A full-length bar is over the 0.5 threshold, so contrast0.
      expect(length.color, theme.cardBackgroundColor,
          reason: 'show-habit.streak-card#7');
      // The short streak is under it.
      final short = canvas
          .opsNamed('drawText')
          .firstWhere((op) => op.text == '4');
      expect(short.color, theme.mediumContrastTextColor,
          reason: 'show-habit.streak-card#7');
    });

    testWidgets('#8 the dates disappear when the bars would be squeezed',
        (tester) async {
      final view = StreakChartView(
        streaks: streakState().bestStreaks,
        color: green,
        theme: theme,
        dateFormatter: formatter,
      );
      // 100 wide: 100 - 2 * 72 is negative, well under 100 * 0.25.
      final canvas = _RecordingCanvas(width: 100, height: 60);
      view.draw(canvas);

      expect(canvas.texts, <String>['10', '8', '4'],
          reason: 'show-habit.streak-card#8');
    });

    testWidgets('#11 an empty streak list draws nothing at all',
        (tester) async {
      final view = StreakChartView(
        streaks: const <core.Streak>[],
        color: green,
        theme: theme,
        dateFormatter: formatter,
      );
      final canvas = _RecordingCanvas(width: 300, height: 60);
      view.draw(canvas);

      expect(canvas.ops, isEmpty, reason: 'show-habit.streak-card#11');
    });
  });

  // -------------------------------------------------------------------------
  // Frequency card
  // -------------------------------------------------------------------------

  FrequencyCardState frequencyState({
    Map<core.LocalDate, List<int>>? frequency,
    bool isNumerical = false,
  }) =>
      FrequencyCardState(
        color: habitColor,
        firstWeekday: core.DayOfWeek.sunday,
        frequency: frequency ??
            <core.LocalDate, List<int>>{
              // Index 1 is Sunday; January 2015 has four of them.
              core.LocalDate.ymd(2015, 1, 1): <int>[0, 4, 2, 0, 0, 0, 0],
            },
        theme: theme,
        isNumerical: isNumerical,
      );

  _RecordingCanvas drawFrequency(
    FrequencyCardState state, {
    core.LocalDate? chartToday,
  }) {
    final view = FrequencyChartView(
      frequency: state.frequency,
      color: theme.colorOf(state.color),
      theme: theme,
      dateFormatter: formatter,
      firstWeekday: state.firstWeekday,
      isNumerical: state.isNumerical,
      today: chartToday,
    );
    final canvas = _RecordingCanvas(width: 300, height: 200);
    view.draw(canvas);
    return canvas;
  }

  group('show-habit.frequency-card', () {
    testWidgets('#11 #12 the card is titled "Frequency" over a 200dp chart',
        (tester) async {
      await _pump(tester, FrequencyCardView(state: frequencyState()));

      expect(find.text('Frequency'), findsOneWidget,
          reason: 'show-habit.frequency-card#12');
      expect(tester.widget<Text>(find.text('Frequency')).style?.color,
          flutterGreen,
          reason: 'show-habit.frequency-card#12');
      expect(tester.getSize(find.byType(CoreView)).height, 200.0,
          reason: 'show-habit.frequency-card#11');
    });

    testWidgets('#8 seven weekday rows in first-weekday order down the right',
        (tester) async {
      final canvas = drawFrequency(frequencyState());

      expect(canvas.texts.take(7).toList(),
          <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          reason: 'show-habit.frequency-card#8');
      // baseSize = 200 ~/ 8 = 25, columnWidth = 25, nColumns = 12: the labels
      // live in the reserved rightmost column.
      for (final op in canvas.opsNamed('drawText').take(7)) {
        expect(op.args[0], closeTo(275.0, 1e-9),
            reason: 'show-habit.frequency-card#8');
        expect(op.textAlign, core.TextAlign.left,
            reason: 'show-habit.frequency-card#8');
      }
      // Seven separators plus one closing line.
      expect(canvas.opsNamed('drawLine').length, 8,
          reason: 'show-habit.frequency-card#8');
    });

    testWidgets('#9 the footer names each month, and only February carries a '
        'year', (tester) async {
      final months = drawFrequency(frequencyState())
          .texts
          .skip(7)
          .where((text) => int.tryParse(text) == null)
          .toList();
      expect(
        months,
        <String>[
          'Mar', 'Apr', 'May', 'Jun', 'Jul', //
          'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan',
        ],
        reason: 'show-habit.frequency-card#9',
      );
      expect(drawFrequency(frequencyState()).texts, isNot(contains('2014')),
          reason: 'show-habit.frequency-card#9');

      final withFebruary = drawFrequency(
        frequencyState(),
        chartToday: core.LocalDate.ymd(2015, 6, 25),
      );
      expect(withFebruary.texts, contains('Feb'),
          reason: 'show-habit.frequency-card#9');
      expect(withFebruary.texts, contains('2015'),
          reason: 'show-habit.frequency-card#9');
    });

    testWidgets('#6 #7 a weekday performed every time gets a full-size bubble '
        'in the habit colour', (tester) async {
      final canvas = drawFrequency(frequencyState());
      final bubbles = canvas.opsNamed('fillCircle');

      // Only the month that is in the map draws bubbles: seven of them, one
      // per weekday row.
      expect(bubbles.length, 7, reason: 'show-habit.frequency-card#4');

      // Sunday: 4 of 4 possible, so scale 1.0 and radius (25 - 2*5)/2.
      expect(bubbles[0].args[2], closeTo(7.5, 1e-9),
          reason: 'show-habit.frequency-card#6');
      expect(bubbles[0].color, green,
          reason: 'show-habit.frequency-card#7');

      // Monday: 2 of 4, so scale 0.5 and colour index round(3 * 0.5) = 2.
      expect(bubbles[1].args[2], closeTo(3.75, 1e-9),
          reason: 'show-habit.frequency-card#6');
      expect(
        bubbles[1].color,
        core.Color.fromRgb(core.ColorUtils.mixColors(
          theme.lowContrastTextColor.toInt(),
          green.toInt(),
          0.33,
        )),
        reason: 'show-habit.frequency-card#7',
      );

      // A weekday that was never performed still draws, with radius 0.
      expect(bubbles[2].args[2], 0.0,
          reason: 'show-habit.frequency-card#6');
      expect(bubbles[2].color, theme.lowContrastTextColor,
          reason: 'show-habit.frequency-card#7');
    });

    testWidgets('#6 a numerical habit scales against the whole map instead',
        (tester) async {
      final canvas = drawFrequency(frequencyState(isNumerical: true));
      final bubbles = canvas.opsNamed('fillCircle');

      // maxFreq is 4, so Sunday still fills the cell and Monday is half of it
      // — but the divisor is now the map maximum, not the weekday count.
      expect(bubbles[0].args[2], closeTo(7.5, 1e-9),
          reason: 'show-habit.frequency-card#6');
      expect(bubbles[1].args[2], closeTo(3.75, 1e-9),
          reason: 'show-habit.frequency-card#6');
    });
  });

  // -------------------------------------------------------------------------
  // Target card
  // -------------------------------------------------------------------------

  TargetCardState targetState({
    List<double> values = const <double>[50.0],
    List<double> targets = const <double>[100.0],
    List<int> intervals = const <int>[1],
  }) =>
      TargetCardState(
        color: habitColor,
        values: values,
        targets: targets,
        intervals: intervals,
        theme: theme,
      );

  group('show-habit.target-card', () {
    testWidgets('#18 the card is titled "Target" in the habit colour',
        (tester) async {
      await _pump(tester, TargetCardView(state: targetState()));

      expect(find.text('Target'), findsOneWidget,
          reason: 'show-habit.target-card#18');
      expect(tester.widget<Text>(find.text('Target')).style?.color,
          flutterGreen,
          reason: 'show-habit.target-card#18');
    });

    testWidgets('#14 the five intervals map to their labels', (tester) async {
      await _pump(
        tester,
        TargetCardView(
          state: targetState(
            values: const <double>[1, 2, 3, 4, 5],
            targets: const <double>[10, 20, 30, 40, 50],
            intervals: const <int>[1, 7, 30, 91, 365],
          ),
        ),
      );

      final card = tester.widget<TargetCardView>(find.byType(TargetCardView));
      expect(
        card.labels(L10n.of(tester.element(find.byType(TargetCardView)))),
        <String>['Today', 'Week', 'Month', 'Quarter', 'Year'],
        reason: 'show-habit.target-card#14',
      );
      // Anything else is "Year" too.
      expect(
        TargetCardView(state: targetState(intervals: const <int>[999]))
            .labels(L10n.of(tester.element(find.byType(TargetCardView)))),
        <String>['Year'],
        reason: 'show-habit.target-card#14',
      );
    });

    testWidgets('the chart is one 20dp row per interval, not the 300dp the '
        'layout asks for', (tester) async {
      await _pump(
        tester,
        TargetCardView(
          state: targetState(
            values: const <double>[1, 2, 3],
            targets: const <double>[10, 20, 30],
            intervals: const <int>[30, 91, 365],
          ),
        ),
      );

      // show_habit_target.xml says 300dp, but `TargetChart.onMeasure` only
      // reads the height spec when layoutParams.height is MATCH_PARENT; with
      // a fixed one it answers labels.size * baseSize and the 300dp is never
      // used. (Rule 19 of the target-card ledger entry reads the other way
      // round; the Kotlin is what is reproduced here, so that rule is left
      // uncited on purpose.)
      expect(tester.getSize(find.byType(CoreView)).height, 60.0,
          reason: 'charts-canvas-theming.target-chart#3');
    });

    testWidgets('#15 #18 the bar is a grey track with the habit colour over '
        'the completed fraction', (tester) async {
      final canvas = _drawTarget(
        values: const <double>[50.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );

      final bars = canvas.opsNamed('fillRoundRect');
      expect(bars.length, 2, reason: 'show-habit.target-card#15');
      // maxLabelSize = 5 glyphs * 10 * 0.6 = 30, stop = 38, so the track runs
      // from 42 to 296.
      expect(bars[0].args[0], closeTo(42.0, 1e-9),
          reason: 'show-habit.target-card#15');
      expect(bars[0].args[2], closeTo(254.0, 1e-9),
          reason: 'show-habit.target-card#15');
      expect(bars[0].color, theme.lowContrastTextColor,
          reason: 'show-habit.target-card#18');

      expect(bars[1].args[2], closeTo(127.0, 1e-9),
          reason: 'show-habit.target-card#15');
      expect(bars[1].color, green, reason: 'show-habit.target-card#18');
    });

    testWidgets('#15 a non-positive target counts as complete', (tester) async {
      final canvas = _drawTarget(
        values: const <double>[0.0],
        targets: const <double>[0.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );

      final bars = canvas.opsNamed('fillRoundRect');
      expect(bars[1].args[2], closeTo(254.0, 1e-9),
          reason: 'show-habit.target-card#15');
    });

    testWidgets('#16 a sliver of progress is widened so it stays visible',
        (tester) async {
      final canvas = _drawTarget(
        values: const <double>[1.0],
        targets: const <double>[100000.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );

      // 254 * 1e-5 would be a quarter of a logical pixel; the floor is 2*2dp.
      expect(canvas.opsNamed('fillRoundRect')[1].args[2], 4.0,
          reason: 'show-habit.target-card#16');
    });

    testWidgets('#17 completed and remaining are written where they fit',
        (tester) async {
      final canvas = _drawTarget(
        values: const <double>[50.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );

      expect(canvas.texts, <String>['Today', '50', '50'],
          reason: 'show-habit.target-card#17');
      final label = canvas.opsNamed('drawText').first;
      expect(label.textAlign, core.TextAlign.right,
          reason: 'show-habit.target-card#18');
      expect(label.color, theme.mediumContrastTextColor,
          reason: 'show-habit.target-card#18');
      expect(canvas.opsNamed('drawText')[1].color, theme.cardBackgroundColor,
          reason: 'show-habit.target-card#17');
      expect(canvas.opsNamed('drawText')[2].color,
          theme.mediumContrastTextColor,
          reason: 'show-habit.target-card#17');
    });

    testWidgets('#17 an over-target row fills the bar and never gets to show '
        'its negative remainder', (tester) async {
      final canvas = _drawTarget(
        values: const <double>[8.25],
        targets: const <double>[5.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );

      // The remaining text is documented as possibly negative, but the
      // completed width is clamped to the whole bar first, which leaves the
      // remaining region exactly zero wide — so the branch never runs.
      expect(canvas.opsNamed('fillRoundRect')[1].args[2], closeTo(254.0, 1e-9),
          reason: 'show-habit.target-card#15');
      // Android's toShortString, not the core one: under 10 it is a
      // DecimalFormat("#.##").
      expect(canvas.texts, <String>['Today', '8.25'],
          reason: 'show-habit.number-formatting#2');
    });

    testWidgets('#17 neither text is drawn when it does not fit',
        (tester) async {
      final canvas = _drawTarget(
        values: const <double>[500000.0],
        targets: const <double>[1000000.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
        width: 70,
      );

      expect(canvas.texts, <String>['Today'],
          reason: 'show-habit.target-card#17');
    });
  });

  // -------------------------------------------------------------------------
  // Shared chrome
  // -------------------------------------------------------------------------

  group('show-habit.theme-colors', () {
    testWidgets('#1 every card title is tinted with theme.color(habit.color)',
        (tester) async {
      const purple = core.PaletteColor(14);
      final expected = Color(0xFF000000 | theme.color(14).toInt());

      await _pump(
        tester,
        Column(
          children: <Widget>[
            ScoreCardView(
              state: ScoreCardState(
                scores: <core.Score>[score(today, 1.0)],
                bucketSize: 7,
                spinnerPosition: 1,
                color: purple,
                theme: theme,
              ),
            ),
            StreakCardView(
              state: StreakCardState(
                color: purple,
                bestStreaks: <core.Streak>[streak(today, 3)],
                theme: theme,
              ),
            ),
          ],
        ),
      );

      for (final title in <String>['Score', 'Best streaks']) {
        expect(tester.widget<Text>(find.text(title)).style?.color, expected,
            reason: 'show-habit.theme-colors#1');
      }
    });

    testWidgets('#4 the card body is the theme card background', (tester) async {
      await _pump(tester, ScoreCardView(state: scoreState()));

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ScoreCardView),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, const Color(0xFFFAFAFA),
          reason: 'show-habit.theme-colors#4');
      expect(material.elevation, 1.0, reason: 'show-habit.theme-colors#4');
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pumps [card] into a 400dp-wide column, the width of a phone screen.
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

_RecordingCanvas _drawTarget({
  required List<double> values,
  required List<double> targets,
  required List<String> labels,
  required core.Color color,
  required core.Theme theme,
  double width = 300,
}) {
  final view = TargetChartView(
    values: values,
    targets: targets,
    labels: labels,
    color: color,
    theme: theme,
  );
  final canvas = _RecordingCanvas(
    width: width,
    height: labels.length * TargetChartView.baseSize,
  );
  view.draw(canvas);
  return canvas;
}

class _RecordingScoreScreen implements ScoreCardScreen {
  final List<String> calls = <String>[];

  @override
  void updateWidgets() => calls.add('updateWidgets');

  @override
  void refresh() => calls.add('refresh');
}

class _RecordingDateListener extends OnDateClickedListener {
  final List<core.LocalDate> shortPresses = <core.LocalDate>[];
  final List<core.LocalDate> longPresses = <core.LocalDate>[];

  @override
  void onDateShortPress(core.LocalDate date) => shortPresses.add(date);

  @override
  void onDateLongPress(core.LocalDate date) => longPresses.add(date);
}

class _Op {
  _Op(
    this.name,
    this.args, {
    this.text,
    required this.color,
    required this.font,
    required this.fontSize,
    required this.strokeWidth,
    required this.textAlign,
  });

  final String name;
  final List<double> args;
  final String? text;
  final core.Color color;
  final core.Font font;
  final double fontSize;
  final double strokeWidth;
  final core.TextAlign textAlign;

  @override
  String toString() => '$name(${text == null ? '' : '"$text", '}$args)';
}

/// A [core.Canvas] that logs every call together with the sticky paint state
/// it was made under.
///
/// [measureText] is the same crude stub the header tests use — the glyph count
/// times 0.6 em — which keeps every layout number in this file predictable.
class _RecordingCanvas extends core.Canvas {
  _RecordingCanvas({required this.width, required this.height});

  final double width;
  final double height;
  final List<_Op> ops = <_Op>[];

  core.Color _color = core.Color.BLACK;
  core.Font _font = core.Font.regular;
  double _fontSize = 12.0;
  double _strokeWidth = 1.0;
  core.TextAlign _textAlign = core.TextAlign.center;

  List<_Op> opsNamed(String name) =>
      ops.where((op) => op.name == name).toList();

  List<String> get texts =>
      opsNamed('drawText').map((op) => op.text!).toList();

  void _record(String name, List<double> args, {String? text}) {
    ops.add(_Op(
      name,
      args,
      text: text,
      color: _color,
      font: _font,
      fontSize: _fontSize,
      strokeWidth: _strokeWidth,
      textAlign: _textAlign,
    ));
  }

  @override
  double getWidth() => width;

  @override
  double getHeight() => height;

  @override
  void setColor(core.Color color) => _color = color;

  @override
  void setFont(core.Font font) => _font = font;

  @override
  void setFontSize(double size) => _fontSize = size;

  @override
  void setStrokeWidth(double size) => _strokeWidth = size;

  @override
  void setTextAlign(core.TextAlign align) => _textAlign = align;

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _record('drawLine', <double>[x1, y1, x2, y2]);

  @override
  void drawText(String text, double x, double y) =>
      _record('drawText', <double>[x, y], text: text);

  @override
  void fillRect(double x, double y, double w, double h) =>
      _record('fillRect', <double>[x, y, w, h]);

  @override
  void drawRect(double x, double y, double w, double h) =>
      _record('drawRect', <double>[x, y, w, h]);

  @override
  void fillRoundRect(double x, double y, double w, double h, double radius) =>
      _record('fillRoundRect', <double>[x, y, w, h, radius]);

  @override
  void fillCircle(double cx, double cy, double radius) =>
      _record('fillCircle', <double>[cx, cy, radius]);

  @override
  void fillArc(
    double cx,
    double cy,
    double radius,
    double startAngle,
    double swipeAngle,
  ) =>
      _record('fillArc', <double>[cx, cy, radius, startAngle, swipeAngle]);

  @override
  double measureText(String text) => text.length * _fontSize * 0.6;

  @override
  core.Image toImage() => throw UnsupportedError('not recorded');
}
