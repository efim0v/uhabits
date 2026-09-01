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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/l10n/app_localizations_es.dart';
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

    testWidgets(
        'platform-glue.localized-arrays#4 — the two interval-name arrays, '
        'with and without the day', (tester) async {
      final L10n l10n = L10nEn();

      expect(
        bucketLabels(l10n),
        <String>['Day', 'Week', 'Month', 'Quarter', 'Year'],
        reason: 'platform-glue.localized-arrays#4 — strengthIntervalNames has 5 '
            'entries: day, week, month, quarter, year; '
            'strengthIntervalNamesWithoutDay has 4: week, month, quarter, '
            'year. ARB has no array concept, so each becomes an explicit '
            'ordered list of message ids.',
      );
      expect(
        bucketLabelsWithoutDay(l10n),
        <String>['Week', 'Month', 'Quarter', 'Year'],
        reason: 'platform-glue.localized-arrays#4: the shorter array is the '
            'longer one without its first entry',
      );
      expect(bucketLabelsWithoutDay(l10n), bucketLabels(l10n).skip(1).toList(),
          reason: 'platform-glue.localized-arrays#4: which is what makes the '
              'two index contracts compatible below index 0');

      // Every entry really is a localized message, not a literal: the Spanish
      // build says something else.
      expect(bucketLabels(L10nEs()), isNot(bucketLabels(l10n)),
          reason: 'platform-glue.localized-arrays#4: the array is localizable');
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

  /// A `HistoryChart` hosted the way the *history editor* hosts one: with a
  /// date listener installed.
  ///
  /// The Calendar card installs none. Upstream `HistoryCardView.setState`
  /// builds its chart without an `onDateClickedListener`, so the card is
  /// read-only and only the editor's chart is given the presenter
  /// (`audit3.the-calendar-card-on-the-habit#1`, pinned at screen level by
  /// test/ui/habits/show/calendar_card_readonly_test.dart). The rules about
  /// what a press on a day square does are therefore exercised here on a
  /// listening chart rather than on the card.
  Widget listeningChart(
    HistoryCardState state,
    OnDateClickedListener listener,
  ) {
    final chart = HistoryChart(
      today: state.today,
      paletteColor: state.color,
      theme: state.theme,
      dateFormatter: formatter,
      series: state.series,
      defaultSquare: state.defaultSquare,
      notesIndicators: state.notesIndicators,
      firstWeekday: state.firstWeekday,
    )..onDateClickedListener = listener;
    return SizedBox(
      height: HistoryCardView.chartHeight,
      child: CoreView(view: chart),
    );
  }

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
    // Corrected: this test used to assert that the Calendar card installs a
    // date listener on its chart, which is the behaviour
    // `audit3.the-calendar-card-on-the-habit#1` says is wrong — upstream's
    // `setState` builds the chart without one and `setListener(presenter)`
    // wires only the Edit button. Where the presenter really is installed —
    // the history-editor dialog — is pinned by
    // test/ui/habits/show/show_habit_screen_test.dart (`history-editor.dialog#17`).
    testWidgets('#13 the card leaves the chart\'s no-op listener in place',
        (tester) async {
      await _pump(tester, HistoryCardView(state: historyState()));
      final chart = _viewOf<HistoryChart>(tester);

      final HistoryChart untouched = HistoryChart(
        today: today,
        paletteColor: habitColor,
        theme: theme,
        dateFormatter: formatter,
        series: const <Square>[],
        defaultSquare: Square.off,
        notesIndicators: const <bool>[],
        firstWeekday: core.DayOfWeek.sunday,
      );
      expect(
        identical(chart.onDateClickedListener,
            untouched.onDateClickedListener),
        isTrue,
        reason: 'audit3.the-calendar-card-on-the-habit#1 — the card must hand '
            'the chart nothing, so it keeps the const no-op default declared '
            'in HistoryChart.',
      );
    });

    testWidgets('#1 #2 a tap becomes a short press on the hit-tested date',
        (tester) async {
      final listener = _RecordingDateListener();
      await _pump(tester, listeningChart(historyState(), listener));
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
  // -------------------------------------------------------------------------
  // Score chart: the sizing arithmetic and the footer state machine
  // -------------------------------------------------------------------------

  group('charts-canvas-theming.score-chart (sizing)', () {
    _RecordingCanvas drawScoreAt(
      ScoreCardState state, {
      double width = 300,
      double height = 220,
    }) {
      final view = ScoreChartView(
        scores: state.scores,
        color: theme.colorOf(state.color),
        theme: theme,
        dateFormatter: formatter,
        bucketSize: state.bucketSize,
      );
      final canvas = _RecordingCanvas(width: width, height: height);
      view.draw(canvas);
      return canvas;
    }

    testWidgets('#1 a line of markers over a five-row percentage grid, with a '
        'date footer underneath', (tester) async {
      final canvas = drawScoreAt(scoreState());

      expect(canvas.texts.take(5).toList(),
          <String>['100%', '80%', '60%', '40%', '20%'],
          reason: 'charts-canvas-theming.score-chart#1 — a 5-row percentage '
              'grid');
      // Two concentric circles per marker, one per score.
      expect(canvas.opsNamed('fillCircle').length ~/ 2, 3,
          reason: 'charts-canvas-theming.score-chart#1 — one marker per score');
      expect(
          canvas
              .opsNamed('drawLine')
              .where((op) => op.strokeWidth != 1.0)
              .length,
          2,
          reason: 'charts-canvas-theming.score-chart#1 — joined by a line');
      expect(canvas.texts.skip(5).toList(), <String>['2015', 'Jan', '18', '25'],
          reason: 'charts-canvas-theming.score-chart#1 — and a date footer '
              'below the plot');
    });

    testWidgets('#2 a height under 9 is treated as 200, and the text size, em, '
        'footer, padding and baseSize follow from the height',
        (tester) async {
      // 220 tall: textSize = min(13.2, 10) = 10, em = 11.71, footer = 35,
      // paddingTop = 11, baseSize = (220 - 35 - 11) ~/ 8 = 21.
      final canvas = drawScoreAt(scoreState());
      final grid = canvas
          .opsNamed('drawLine')
          .where((op) => op.strokeWidth == 1.0)
          .toList();
      expect(grid.first.args[1], closeTo(11.0, 1e-9),
          reason: 'charts-canvas-theming.score-chart#2 — internalPaddingTop = '
              'em.toInt()');
      expect(grid.last.args[1] - grid.first.args[1], closeTo(8 * 21.0, 1e-9),
          reason: 'charts-canvas-theming.score-chart#2 — the plot is '
              '8 * baseSize tall');
      expect(canvas.opsNamed('drawText').first.fontSize, 10.0,
          reason: 'charts-canvas-theming.score-chart#2 — pText.textSize = '
              'min(height * 0.06, tinyTextSize)');

      // 100 tall: 100 * 0.06 = 6 is under the 10sp ceiling, so the whole
      // layout shrinks with it. em = 7.026, footer = 21, paddingTop = 7,
      // baseSize = (100 - 21 - 7) ~/ 8 = 9.
      final small = drawScoreAt(scoreState(), height: 100);
      expect(small.opsNamed('drawText').first.fontSize, closeTo(6.0, 1e-9),
          reason: 'charts-canvas-theming.score-chart#2');
      final smallGrid = small
          .opsNamed('drawLine')
          .where((op) => op.strokeWidth == small.opsNamed('drawLine').first.strokeWidth)
          .toList();
      expect(smallGrid.first.args[1], closeTo(7.0, 1e-9),
          reason: 'charts-canvas-theming.score-chart#2');

      // Under 9 the height is replaced by 200 outright, so the chart draws
      // exactly as if it had been given 200.
      final tiny = drawScoreAt(scoreState(), height: 5);
      final asIf200 = drawScoreAt(scoreState(), height: 200);
      expect(tiny.ops.map((op) => op.toString()).toList(),
          asIf200.ops.map((op) => op.toString()).toList(),
          reason: 'charts-canvas-theming.score-chart#2 — a height < 9 is '
              'replaced by 200');
    });

    testWidgets('#3 #4 the column pitch comes from the month name, and the '
        'columns tile the view exactly', (tester) async {
      final canvas = drawScoreAt(scoreState());

      // maxMonthWidth is 3 glyphs * 10 * 0.6 = 18, so columnWidth starts at
      // baseSize 21, is raised to 18*1.5 = 27 and left alone by 18*1.2 = 21.6.
      // nColumns = (300 / 27).toInt() = 11, then columnWidth = 300 / 11.
      const columnWidth = 300.0 / 11;
      final circles = canvas.opsNamed('fillCircle');
      // Markers sit at k*columnWidth + (columnWidth - baseSize)/2 + baseSize/2.
      final newest = circles[4].args[0];
      final previous = circles[2].args[0];
      expect(newest - previous, closeTo(columnWidth, 1e-9),
          reason: 'charts-canvas-theming.score-chart#3 — columnWidth is reset '
              'to width / nColumns so the columns tile the view');
      expect(newest,
          closeTo(10 * columnWidth + (columnWidth - 21) / 2 + 10.5, 1e-9),
          reason: 'charts-canvas-theming.score-chart#3');
      // The pitch is 27.27, not the 21 that baseSize alone would have given:
      // the day-width term measured a month name (the upstream getter never
      // looks at a day number) and 1.5 * 18 won.
      expect(columnWidth, greaterThan(21.0),
          reason: 'charts-canvas-theming.score-chart#4 — maxDayWidth is a '
              'month measurement, so the 1.5 factor applies to it');
      expect(columnWidth, closeTo(18.0 * 1.5 + (300 - 11 * 27) / 11, 1e-9),
          reason: 'charts-canvas-theming.score-chart#4');
    });

    testWidgets('#14 previousMonth, previousYear and skipYear restart on every '
        'draw', (tester) async {
      final view = ScoreChartView(
        scores: scoreState().scores,
        color: green,
        theme: theme,
        dateFormatter: formatter,
        bucketSize: 7,
      );
      final first = _RecordingCanvas(width: 300, height: 220);
      view.draw(first);
      final second = _RecordingCanvas(width: 300, height: 220);
      view.draw(second);

      expect(second.texts, first.texts,
          reason: 'charts-canvas-theming.score-chart#14 — the same view drawn '
              'twice prints the same footer, so nothing carries over');
      expect(second.texts.skip(5).toList(), <String>['2015', 'Jan', '18', '25'],
          reason: 'charts-canvas-theming.score-chart#14 — the leftmost drawn '
              'column always prints its year and month afresh');
    });

    testWidgets('#17 the presenter supplies exactly {1, 7, 31, 92, 365}',
        (tester) async {
      expect(ScoreCardPresenter.bucketSizes, <int>[1, 7, 31, 92, 365],
          reason: 'charts-canvas-theming.score-chart#17');
      for (var position = 0; position < 5; position++) {
        expect(ScoreCardPresenter.bucketSizes[position],
            <int>[1, 7, 31, 92, 365][position],
            reason: 'charts-canvas-theming.score-chart#17 — indexed by the '
                'spinner position 0..4 (day, week, month, quarter, year)');
      }
    });

    testWidgets('show-habit.score-card#9 #10 and '
        'show-habit.number-formatting#6: the grid labels and the footer rules',
        (tester) async {
      final canvas = drawScoreAt(scoreState());

      expect(canvas.texts.take(5).toList(),
          <String>['100%', '80%', '60%', '40%', '20%'],
          reason: 'show-habit.score-card#9 — five rows labelled 100 - i*100/5');
      expect(canvas.texts.take(5).toList(),
          <String>['100%', '80%', '60%', '40%', '20%'],
          reason: 'show-habit.number-formatting#6 — String.format("%d%%", '
              '100 - i*100/5)');

      // A score of 1.0 lands on the top row: the plot is 8 * baseSize tall.
      final circles = canvas.opsNamed('fillCircle');
      expect(circles[4].args[1], closeTo(11.5, 1e-9),
          reason: 'show-habit.score-card#9 — the plot area is 8*baseSize tall, '
              'so a score of 1.0 reaches the top row');

      // Footer: the year prints on change, then the month on change, then day
      // numbers.
      expect(canvas.texts.skip(5).toList(), <String>['2015', 'Jan', '18', '25'],
          reason: 'show-habit.score-card#10 — the short month name is printed '
              'when the month changes, otherwise the day number');

      // Yearly buckets skip odd years and the column right after a year.
      final yearly = drawScoreAt(scoreState(
        bucketSize: 365,
        scores: <core.Score>[
          score(core.LocalDate.ymd(2015, 1, 1), 1.0),
          score(core.LocalDate.ymd(2014, 1, 1), 1.0),
          score(core.LocalDate.ymd(2013, 1, 1), 1.0),
          score(core.LocalDate.ymd(2012, 1, 1), 1.0),
        ],
      ));
      expect(yearly.texts.skip(5).toList(), <String>['2012', '2014'],
          reason: 'show-habit.score-card#10 — the year is skipped when '
              'bucketSize >= 365 and the year is odd, and for one column '
              'immediately after a year was printed');
    });
  });

  // -------------------------------------------------------------------------
  // Frequency chart
  // -------------------------------------------------------------------------

  group('charts-canvas-theming.frequency-chart', () {
    testWidgets('#1 #2 #3 one column per month, seven weekday rows, sized off '
        'the height', (tester) async {
      final canvas = drawFrequency(frequencyState());

      // baseSize = 200 ~/ 8 = 25; textSize = 10; columnWidth = max(25, 18*1.2)
      // = 25; nColumns = (300 / 25).toInt() = 12.
      expect(canvas.opsNamed('drawText').first.fontSize, closeTo(10.0, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#2 — pText.textSize = '
              'baseSize * 0.4');
      final rows = canvas.opsNamed('drawLine').map((op) => op.args[1]).toList();
      expect(rows, <double>[0, 25, 50, 75, 100, 125, 150, 175],
          reason: 'charts-canvas-theming.frequency-chart#3 — columnHeight = '
              '8 * baseSize and internalPaddingTop = 0');
      expect(canvas.texts.take(7).toList(),
          <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          reason: 'charts-canvas-theming.frequency-chart#1 — seven weekday '
              'rows');
      expect(
          canvas.texts.skip(7).where((t) => int.tryParse(t) == null).length, 11,
          reason: 'charts-canvas-theming.frequency-chart#1 — one column per '
              'month');

      // A height under 9 is replaced by 200 outright.
      final view = FrequencyChartView(
        frequency: frequencyState().frequency,
        color: green,
        theme: theme,
        dateFormatter: formatter,
        firstWeekday: core.DayOfWeek.sunday,
        isNumerical: false,
      );
      final tiny = _RecordingCanvas(width: 300, height: 4);
      view.draw(tiny);
      expect(tiny.ops.map((op) => op.toString()).toList(),
          canvas.ops.map((op) => op.toString()).toList(),
          reason: 'charts-canvas-theming.frequency-chart#2 — a height < 9 is '
              'replaced by 200');
    });

    testWidgets('#4 only nColumns - 1 months are drawn; the last column is the '
        'weekday gutter', (tester) async {
      final canvas = drawFrequency(frequencyState());

      final months =
          canvas.texts.skip(7).where((t) => int.tryParse(t) == null).toList();
      expect(months, hasLength(11),
          reason: 'charts-canvas-theming.frequency-chart#4 — 12 columns fit, '
              'but the rightmost is reserved');
      for (final op in canvas.opsNamed('drawText').take(7)) {
        expect(op.args[0], closeTo(300.0 - 25.0, 1e-9),
            reason: 'charts-canvas-theming.frequency-chart#4 — the weekday '
                'names live in that reserved column');
      }
    });

    testWidgets('#5 the leftmost month is the current one stepped back '
        'nColumns - 2 + dataOffset months, wrapping the year', (tester) async {
      final canvas = drawFrequency(frequencyState());
      final months =
          canvas.texts.skip(7).where((t) => int.tryParse(t) == null).toList();
      // 12 columns, so -12 + 2 = -10 months from January 2015 is March 2014.
      expect(months.first, 'Mar',
          reason: 'charts-canvas-theming.frequency-chart#5 — the year wraps '
              'backwards when the month number drops below 1');
      expect(months.last, 'Jan',
          reason: 'charts-canvas-theming.frequency-chart#5 — and each column '
              'steps forward one month');

      final june = drawFrequency(
        frequencyState(),
        chartToday: core.LocalDate.ymd(2015, 6, 25),
      );
      final juneMonths =
          june.texts.skip(7).where((t) => int.tryParse(t) == null).toList();
      expect(juneMonths.first, 'Aug',
          reason: 'charts-canvas-theming.frequency-chart#5 — June 2015 minus '
              '10 months is August 2014');
      expect(juneMonths.last, 'Jun',
          reason: 'charts-canvas-theming.frequency-chart#5');
    });

    testWidgets('#6 the grid: weekday names left-aligned in contrast60, '
        'hairlines in contrast20 at every row top', (tester) async {
      final canvas = drawFrequency(frequencyState());

      for (final op in canvas.opsNamed('drawText').take(7)) {
        expect(op.textAlign, core.TextAlign.left,
            reason: 'charts-canvas-theming.frequency-chart#6');
        expect(op.color, theme.mediumContrastTextColor,
            reason: 'charts-canvas-theming.frequency-chart#6 — contrast60');
      }
      final lines = canvas.opsNamed('drawLine');
      expect(lines, hasLength(8),
          reason: 'charts-canvas-theming.frequency-chart#6 — one line per row '
              'plus one after the loop');
      for (final op in lines) {
        expect(op.color, theme.lowContrastTextColor,
            reason: 'charts-canvas-theming.frequency-chart#6 — contrast20');
        expect(op.strokeWidth, 1.0,
            reason: 'charts-canvas-theming.frequency-chart#6 — strokeWidth is '
                'forced to 1');
      }
    });

    testWidgets('#7 row j is getWeekdaySequence(firstWeekday)[j], read at '
        'index (daysSinceSunday + 1) % 7', (tester) async {
      // The fixture puts 4 in index 1 (Sunday) and 2 in index 2 (Monday).
      final sunday = drawFrequency(frequencyState());
      final sundayBubbles = sunday.opsNamed('fillCircle');
      expect(sundayBubbles[0].args[2], closeTo(7.5, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#7 — row 0 of a '
              'Sunday-first week reads index (0 + 1) % 7 = 1');
      expect(sundayBubbles[1].args[2], closeTo(3.75, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#7 — row 1 reads '
              'index 2');

      final monday = drawFrequency(
        FrequencyCardState(
          color: habitColor,
          firstWeekday: core.DayOfWeek.monday,
          frequency: frequencyState().frequency,
          theme: theme,
          isNumerical: false,
        ),
      );
      expect(monday.texts.take(7).toList(),
          <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          reason: 'charts-canvas-theming.frequency-chart#7 — the row order '
              'follows getWeekdaySequence(firstWeekday)');
      final mondayBubbles = monday.opsNamed('fillCircle');
      // Monday is now row 0 and Sunday row 6.
      expect(mondayBubbles[0].args[2], closeTo(3.75, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#7');
      expect(mondayBubbles[6].args[2], closeTo(7.5, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#7');
    });

    testWidgets('#8 a month absent from the map draws no bubbles but keeps its '
        'footer', (tester) async {
      final canvas = drawFrequency(frequencyState());

      expect(canvas.opsNamed('fillCircle'), hasLength(7),
          reason: 'charts-canvas-theming.frequency-chart#8 — only the one '
              'month in the map draws its seven rows');
      expect(
          canvas.texts.skip(7).where((t) => int.tryParse(t) == null).length, 11,
          reason: 'charts-canvas-theming.frequency-chart#8 — every column '
              'still draws its footer');
    });

    testWidgets('#9 #11 bubble radius, the two scaling factors and the maxFreq '
        'floor', (tester) async {
      // Boolean: the divisor is how often that weekday occurred in the month.
      final boolean = drawFrequency(frequencyState()).opsNamed('fillCircle');
      // padding = 25 * 0.2 = 5, maxRadius = (25 - 10) / 2 = 7.5.
      expect(boolean[0].args[2], closeTo(7.5, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#9 — 4 of the 4 '
              'Sundays in January 2015');
      expect(boolean[1].args[2], closeTo(3.75, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#9 — 2 of 4 Mondays');
      expect(boolean[2].args[2], 0.0,
          reason: 'charts-canvas-theming.frequency-chart#9 — a weekday never '
              'performed has radius 0');

      // Numerical: the divisor is maxFreq over the whole map.
      final numerical =
          drawFrequency(frequencyState(isNumerical: true)).opsNamed('fillCircle');
      expect(numerical[0].args[2], closeTo(7.5, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#9');
      expect(numerical[1].args[2], closeTo(3.75, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#9');

      // maxFreq is floored at 1, so an all-zero map divides by 1 rather than
      // by 0 and every bubble collapses to nothing.
      final zeros = drawFrequency(frequencyState(
        isNumerical: true,
        frequency: <core.LocalDate, List<int>>{
          core.LocalDate.ymd(2015, 1, 1): <int>[0, 0, 0, 0, 0, 0, 0],
        },
      ));
      expect(zeros.opsNamed('fillCircle').map((op) => op.args[2]).toSet(),
          <double>{0.0},
          reason: 'charts-canvas-theming.frequency-chart#11 — maxFreq has a '
              'floor of 1');
      expect(zeros.opsNamed('fillCircle'), hasLength(7),
          reason: 'charts-canvas-theming.frequency-chart#11');

      // A negative (skipped) entry is clamped to zero rather than inverting
      // the bubble.
      final negative = drawFrequency(frequencyState(
        isNumerical: true,
        frequency: <core.LocalDate, List<int>>{
          core.LocalDate.ymd(2015, 1, 1): <int>[0, -4, 2, 0, 0, 0, 0],
        },
      ));
      expect(negative.opsNamed('fillCircle')[0].args[2], 0.0,
          reason: 'charts-canvas-theming.frequency-chart#9 — max(0, value)');
    });

    testWidgets('#10 the four-step colour ramp is mixed with ColorUtils',
        (tester) async {
      final canvas = drawFrequency(frequencyState());
      final bubbles = canvas.opsNamed('fillCircle');
      final grid = theme.lowContrastTextColor;

      // scale 1.0 -> index min(3, round(3)) = 3.
      expect(bubbles[0].color, green,
          reason: 'charts-canvas-theming.frequency-chart#10 — colors[3] is the '
              'habit colour');
      // scale 0.5 -> index round(1.5) = 2.
      expect(
        bubbles[1].color,
        core.Color.fromRgb(
          core.ColorUtils.mixColors(grid.toInt(), green.toInt(), 0.33),
        ),
        reason: 'charts-canvas-theming.frequency-chart#10 — colors[2] is '
            'mixColors(grid, habit, 0.33), i.e. 67% habit colour',
      );
      // scale 0 -> index 0.
      expect(bubbles[2].color, grid,
          reason: 'charts-canvas-theming.frequency-chart#10 — colors[0] is the '
              'grid colour');

      final quarter = drawFrequency(frequencyState(
        frequency: <core.LocalDate, List<int>>{
          core.LocalDate.ymd(2015, 1, 1): <int>[0, 1, 0, 0, 0, 0, 0],
        },
      ));
      // 1 of 4 -> scale 0.25 -> index round(0.75) = 1.
      expect(
        quarter.opsNamed('fillCircle')[0].color,
        core.Color.fromRgb(
          core.ColorUtils.mixColors(grid.toInt(), green.toInt(), 0.66),
        ),
        reason: 'charts-canvas-theming.frequency-chart#10 — colors[1] is '
            'mixColors(grid, habit, 0.66), i.e. 66% grid colour',
      );
    });

    testWidgets('#12 the footer centres the month name, and February also '
        'carries the year', (tester) async {
      final canvas = drawFrequency(frequencyState());
      final footer = canvas
          .opsNamed('drawText')
          .skip(7)
          .where((op) => int.tryParse(op.text!) == null)
          .toList();
      for (final op in footer) {
        expect(op.textAlign, core.TextAlign.center,
            reason: 'charts-canvas-theming.frequency-chart#12');
      }
      // cellCentreY = 6*25 + 25 + 12.5 = 187.5, em = 11.71.
      expect(footer.first.args[1],
          closeTo(187.5 - 0.1 * 11.71 - 0.34 * 10, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#12 — the month name '
              'sits at cellCentreY - 0.1*em');

      final withFebruary = drawFrequency(
        frequencyState(),
        chartToday: core.LocalDate.ymd(2015, 6, 25),
      );
      final year = withFebruary
          .opsNamed('drawText')
          .firstWhere((op) => op.text == '2015');
      expect(year.args[1], closeTo(187.5 + 0.9 * 11.71 - 0.34 * 10, 1e-9),
          reason: 'charts-canvas-theming.frequency-chart#12 — February adds '
              'the year at cellCentreY + 0.9*em');
      expect(withFebruary.texts.where((t) => t == '2015'), hasLength(1),
          reason: 'charts-canvas-theming.frequency-chart#12 — and only '
              'February does');
    });

    testWidgets('show-habit.frequency-card#5 #10: maxFreq is floored at 1 and '
        'the scroll position survives a rebuild', (tester) async {
      final zeros = drawFrequency(frequencyState(
        isNumerical: true,
        frequency: <core.LocalDate, List<int>>{
          core.LocalDate.ymd(2015, 1, 1): <int>[0, 0, 0, 0, 0, 0, 0],
        },
      ));
      expect(zeros.opsNamed('fillCircle'), hasLength(7),
          reason: 'show-habit.frequency-card#5 — a maxFreq of 0 would divide '
              'by zero; the floor of 1 keeps the bubbles at radius 0');

      final months =
          drawFrequency(frequencyState()).texts.skip(7).toList();
      expect(months.first, 'Mar',
          reason: 'show-habit.frequency-card#10 — columns start at the current '
              'month minus (nColumns - 2 + dataOffset) months');
      final scrolled = drawFrequency(frequencyState());
      expect(scrolled.texts.skip(7).toList(), months,
          reason: 'show-habit.frequency-card#10');

      // The card hands its dataOffset straight to the chart and never resets
      // it, so a rebuild with fresh state keeps the same scroll position.
      await _pump(
        tester,
        FrequencyCardView(state: frequencyState(), dataOffset: 3, today: today),
      );
      expect(_viewOf<FrequencyChartView>(tester).dataOffset, 3,
          reason: 'show-habit.frequency-card#10 — the frequency chart is not '
              'reset on refresh');
      await _pump(
        tester,
        FrequencyCardView(
          state: frequencyState(isNumerical: true),
          dataOffset: 3,
          today: today,
        ),
      );
      expect(_viewOf<FrequencyChartView>(tester).dataOffset, 3,
          reason: 'show-habit.frequency-card#10');
    });
  });

  // -------------------------------------------------------------------------
  // Streak chart
  // -------------------------------------------------------------------------

  group('charts-canvas-theming.streak-chart', () {
    _RecordingCanvas drawStreaks(
      List<core.Streak> streaks, {
      double width = 300,
      double? height,
    }) {
      final view = StreakChartView(
        streaks: streaks,
        color: green,
        theme: theme,
        dateFormatter: formatter,
      );
      final canvas = _RecordingCanvas(
        width: width,
        height: height ?? streaks.length * StreakChartView.baseSize,
      );
      view.draw(canvas);
      return canvas;
    }

    testWidgets('#1 #4 one 20dp row per streak, top to bottom, each centred',
        (tester) async {
      final streaks = streakState().bestStreaks;
      final canvas = drawStreaks(streaks);

      expect(StreakChartView.baseSize, 20.0,
          reason: 'charts-canvas-theming.streak-chart#1 — baseSize is 20dp');
      final bars = canvas.opsNamed('fillRoundRect');
      expect(bars, hasLength(3),
          reason: 'charts-canvas-theming.streak-chart#1 — one bar per Streak');
      for (var i = 0; i < bars.length; i++) {
        expect(bars[i].args[1], closeTo(i * 20.0 + 1.0, 1e-9),
            reason: 'charts-canvas-theming.streak-chart#1 — rows run top to '
                'bottom, one baseSize apart');
        expect(bars[i].args[0] + bars[i].args[2] / 2, closeTo(150.0, 1e-9),
            reason: 'charts-canvas-theming.streak-chart#1 — every bar is '
                'horizontally centred');
      }

      await _pump(tester, StreakCardView(state: streakState()));
      expect(tester.getSize(find.byType(CoreView)).height, 60.0,
          reason: 'charts-canvas-theming.streak-chart#4 — a wrap_content chart '
              'measures streaks.size * baseSize');
    });

    testWidgets('#2 an empty streak list draws nothing at all', (tester) async {
      expect(drawStreaks(const <core.Streak>[], height: 60).ops, isEmpty,
          reason: 'charts-canvas-theming.streak-chart#2 — onDraw returns '
              'immediately when the list is empty');
      await _pump(
        tester,
        StreakCardView(state: streakState(streaks: const <core.Streak>[])),
      );
      expect(tester.getSize(find.byType(CoreView)).height, 0.0,
          reason: 'charts-canvas-theming.streak-chart#2 — the default streak '
              'list after construction is empty');
    });

    testWidgets('#5 #6 the text size, em and textMargin, and the zero-length '
        'guard', (tester) async {
      final canvas = drawStreaks(streakState().bestStreaks);
      // max(min(20 * 0.5, 17), 10) = 10, em = 11.71, textMargin = 5.855.
      expect(canvas.opsNamed('drawText').first.fontSize, closeTo(10.0, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#5');
      // availableWidth = 300 - 2*72 - 2*5.855.
      const available = 300.0 - 2 * 72.0 - 11.71;
      expect(canvas.opsNamed('fillRoundRect').first.args[2],
          closeTo(available, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#5 — textMargin is '
              '0.5 * em');

      // percentage = streak.length / maxLength, and Streak.length counts both
      // endpoints.
      expect(streakState().bestStreaks.first.length, 10,
          reason: 'charts-canvas-theming.streak-chart#6');
      expect(canvas.opsNamed('fillRoundRect')[1].args[2],
          closeTo(0.8 * available, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#6 — 8 / 10');

      // maxLength == 0 makes drawRow bail on every row.
      final zero = core.Streak(today, today.minus(-0));
      expect(drawStreaks(<core.Streak>[zero]).opsNamed('fillRoundRect'),
          hasLength(1),
          reason: 'charts-canvas-theming.streak-chart#6 — a one-day streak '
              'still has length 1, so it draws');
    });

    testWidgets('#7 the bar never shrinks below its own number', (tester) async {
      // A single one-day streak among a very long one: 1/100 of the available
      // width is far narrower than the label.
      final canvas = drawStreaks(<core.Streak>[
        core.Streak(today.minus(99), today),
        core.Streak(today.minus(200), today.minus(200)),
      ]);
      final bars = canvas.opsNamed('fillRoundRect');
      // measureText("1") + em = 6 + 11.71.
      expect(bars[1].args[2], closeTo(6.0 + 11.71, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#7 — barWidth = '
              'max(percentage * availableWidth, measureText(length) + em)');
      expect(bars[1].args[0], closeTo((300.0 - bars[1].args[2]) / 2, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#7 — gap = '
              '(viewWidth - barWidth) / 2');
    });

    testWidgets('#8 the bar is a 2dp round rect inset by baseSize*0.05',
        (tester) async {
      final canvas = drawStreaks(streakState().bestStreaks);
      for (final bar in canvas.opsNamed('fillRoundRect')) {
        expect(bar.args[4], 2.0,
            reason: 'charts-canvas-theming.streak-chart#8 — corner radius 2dp');
        expect(bar.args[3], closeTo(20.0 - 2 * 1.0, 1e-9),
            reason: 'charts-canvas-theming.streak-chart#8 — inset vertically '
                'by baseSize * 0.05 on both sides');
      }
    });

    testWidgets('#9 #10 the bar and number colour ramps', (tester) async {
      final canvas = drawStreaks(<core.Streak>[
        core.Streak(today.minus(9), today), // 10 -> 1.0
        core.Streak(today.minus(8), today), // 9  -> 0.9
        core.Streak(today.minus(5), today), // 6  -> 0.6
        core.Streak(today.minus(2), today), // 3  -> 0.3
      ]);
      final bars = canvas.opsNamed('fillRoundRect');
      expect(bars[0].color, green,
          reason: 'charts-canvas-theming.streak-chart#9 — >= 1.0');
      expect(bars[1].color, green.withAlpha(192 / 255),
          reason: 'charts-canvas-theming.streak-chart#9 — >= 0.8');
      expect(bars[2].color, green.withAlpha(96 / 255),
          reason: 'charts-canvas-theming.streak-chart#9 — >= 0.5');
      expect(bars[3].color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.streak-chart#9 — contrast20 below '
              '0.5');

      final numbers = canvas
          .opsNamed('drawText')
          .where((op) => int.tryParse(op.text!) != null)
          .toList();
      expect(numbers.map((op) => op.text).toList(),
          <String>['10', '9', '6', '3'],
          reason: 'charts-canvas-theming.streak-chart#10');
      expect(numbers[0].color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.streak-chart#10 — contrast0 at '
              '>= 0.5');
      expect(numbers[3].color, theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.streak-chart#10 — contrast60 below '
              'it');
      for (var i = 0; i < numbers.length; i++) {
        expect(numbers[i].textAlign, core.TextAlign.center,
            reason: 'charts-canvas-theming.streak-chart#10 — drawn CENTER');
        expect(numbers[i].args[0], closeTo(150.0, 1e-9),
            reason: 'charts-canvas-theming.streak-chart#10 — at the row '
                'centre');
        expect(numbers[i].args[1],
            closeTo(i * 20.0 + 10.0 + 0.3 * 11.71 - 0.34 * 10.0, 1e-9),
            reason: 'charts-canvas-theming.streak-chart#10 — rowCentreY + '
                '0.3 * em');
      }
    });

    testWidgets('#11 #12 the flanking dates, and when they disappear',
        (tester) async {
      final canvas = drawStreaks(streakState().bestStreaks);
      final labels = canvas
          .opsNamed('drawText')
          .where((op) => int.tryParse(op.text!) == null)
          .toList();
      expect(labels.map((op) => op.text).take(2).toList(),
          <String>['Jan 16, 2015', 'Jan 25, 2015'],
          reason: 'charts-canvas-theming.streak-chart#11 — the start date to '
              'the left and the end date to the right');
      expect(labels[0].textAlign, core.TextAlign.right,
          reason: 'charts-canvas-theming.streak-chart#11');
      expect(labels[1].textAlign, core.TextAlign.left,
          reason: 'charts-canvas-theming.streak-chart#11');
      final bar = canvas.opsNamed('fillRoundRect').first;
      expect(labels[0].args[0], closeTo(bar.args[0] - 5.855, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#11 — at gap - '
              'textMargin');
      expect(labels[1].args[0],
          closeTo(300.0 - bar.args[0] + 5.855, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#11 — and at '
              'viewWidth - gap + textMargin');
      for (final label in labels) {
        expect(label.color, theme.mediumContrastTextColor,
            reason: 'charts-canvas-theming.streak-chart#11 — both in '
                'contrast60');
      }

      // 100 wide: 100 - 2*72 is negative, well below 100 * 0.25.
      final squeezed = drawStreaks(streakState().bestStreaks, width: 100);
      expect(squeezed.texts, <String>['10', '8', '4'],
          reason: 'charts-canvas-theming.streak-chart#12 — labels are '
              'suppressed and maxLabelWidth reset to 0');
      // With the gutter gone the longest bar can use the whole width.
      expect(squeezed.opsNamed('fillRoundRect').first.args[2],
          closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#12');
    });

    testWidgets('show-habit.number-formatting#7: a streak label is the plain '
        'length integer', (tester) async {
      final canvas = drawStreaks(<core.Streak>[
        core.Streak(today.minus(1233), today),
        core.Streak(today.minus(2), today),
      ]);
      final numbers = canvas
          .opsNamed('drawText')
          .where((op) => int.tryParse(op.text!) != null)
          .map((op) => op.text)
          .toList();
      expect(numbers, <String>['1234', '3'],
          reason: 'show-habit.number-formatting#7 — no grouping separator and '
              'no toShortString abbreviation');
    });
  });

  // -------------------------------------------------------------------------
  // Точная длительность в полосе: шов `durations`
  // -------------------------------------------------------------------------

  group('computed.since — точная длительность серии', () {
    /// Рисует [streaks] с надписями [durations] или без них.
    _RecordingCanvas draw(
      List<core.Streak> streaks, {
      List<String>? durations,
      double width = 300,
    }) {
      final view = StreakChartView(
        streaks: streaks,
        color: green,
        theme: theme,
        dateFormatter: formatter,
        durations: durations,
      );
      final canvas = _RecordingCanvas(
        width: width,
        height: streaks.length * StreakChartView.baseSize,
      );
      view.draw(canvas);
      return canvas;
    }

    /// Надписи, которые стоят в полосах: даты по краям выровнены к краю, а
    /// эти — по центру строки.
    List<_Op> inBars(_RecordingCanvas c) => c
        .opsNamed('drawText')
        .where((op) => op.textAlign == core.TextAlign.center)
        .toList();

    /// Пять серий разной длины, от стодневной до однодневной.
    final spread = <core.Streak>[
      streak(core.LocalDate.ymd(2015, 1, 25), 100),
      streak(core.LocalDate.ymd(2014, 9, 30), 40),
      streak(core.LocalDate.ymd(2014, 8, 10), 10),
      streak(core.LocalDate.ymd(2014, 7, 20), 4),
      streak(core.LocalDate.ymd(2014, 6, 30), 1),
    ];

    /// Те же пять, каждая со своей точной длительностью — самая длинная
    /// надпись, какую карточка печатает по-русски.
    const spreadDurations = <String>[
      '100 дней 06:12',
      '40 дней 00:00',
      '10 дней 00:00',
      '4 дня 00:00',
      '1 день 00:00',
    ];

    testWidgets('#9 the exact text does not touch a single bar width',
        (tester) async {
      final before = draw(spread);
      final after = draw(spread, durations: spreadDurations);

      List<double> widths(_RecordingCanvas c) =>
          c.opsNamed('fillRoundRect').map((op) => op.args[2]).toList();
      expect(widths(after), widths(before),
          reason: 'computed.since#9 — полоса меряется числом суток, и точная '
              'надпись в этот минимум не попадает');

      // availableWidth = 300 - 2 * 72 - 11.71; measureText = 6 за глиф.
      const available = 300.0 - 2 * 72.0 - 11.71;
      expect(widths(after), <Object>[
        available,
        closeTo(0.4 * available, 1e-9),
        closeTo(2 * 6.0 + 11.71, 1e-9),
        closeTo(1 * 6.0 + 11.71, 1e-9),
        closeTo(1 * 6.0 + 11.71, 1e-9),
      ], reason: 'computed.since#9 — сотня занимает всю ширину, сорок — свои '
          'сорок процентов, а короткие серии стоят на портированном минимуме '
          '«число плюс em», каждая на своём');

      // Тот же минимум, посчитанный от надписи, а не от числа: «100 дней
      // 06:12» есть четырнадцать глифов, то есть 84 + 11.71. Он поднял бы
      // все четыре короткие полосы к одной ширине, и однодневная серия
      // встала бы вровень с сорокадневной.
      const naiveFloor = 14 * 6.0 + 11.71;
      expect(naiveFloor, greaterThan(0.4 * available),
          reason: 'computed.since#9 — вот эта ловушка: минимум по надписи '
              'выше, чем настоящая полоса сорокадневной серии');
    });

    testWidgets('#8 the bar prints the seam, and the port still prints the '
        'number', (tester) async {
      expect(inBars(draw(spread, durations: spreadDurations))
              .map((op) => op.text)
              .toList(),
          spreadDurations,
          reason: 'computed.since#8 — в полосе стоит точная длительность');
      expect(inBars(draw(spread)).map((op) => op.text).toList(),
          <String>['100', '40', '10', '4', '1'],
          reason: 'computed.since#8 — без шва карточка печатает то же число, '
              'что и раньше: у привычки оригинала не меняется ничего');

      // Узкая карточка гасит подписи дат целиком
      // (`charts-canvas-theming.streak-chart#12`). Время, повешенное на них,
      // погасло бы вместе с ними; в полосе оно остаётся.
      final squeezed = draw(spread, durations: spreadDurations, width: 100);
      expect(squeezed.texts, spreadDurations,
          reason: 'computed.since#8 — дат не осталось ни одной, а точная '
              'длительность на месте: она стоит в полосе, а не на подписи');
    });

    testWidgets('#9 a text that overflows its bar is drawn in contrast60',
        (tester) async {
      // Две серии, 24 и 12: доля второй ровно половина, и порт красит её
      // надпись цветом текста по полосе.
      final halved = <core.Streak>[
        streak(core.LocalDate.ymd(2015, 1, 25), 24),
        streak(core.LocalDate.ymd(2014, 12, 1), 12),
      ];
      const durations = <String>['24 дня 00:00', '12 дней 06:12'];

      final ported = inBars(draw(halved));
      expect(ported[0].color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.streak-chart#10 — доля 1.0');
      expect(ported[1].color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.streak-chart#10 — доля ровно 0.5, и '
              'порт всё ещё пишет цветом текста по полосе');

      final exact = inBars(draw(halved, durations: durations));
      const available = 300.0 - 2 * 72.0 - 11.71;
      expect(12 * 6.0, lessThan(available),
          reason: 'computed.since#9 — первая надпись в свою полосу входит');
      expect(13 * 6.0, greaterThan(0.5 * available),
          reason: 'computed.since#9 — вторая из своей выходит');
      expect(exact[0].color, theme.cardBackgroundColor,
          reason: 'computed.since#9 — надпись лежит на полосе целиком, и её '
              'цвет — цвет текста по полосе');
      expect(exact[1].color, theme.mediumContrastTextColor,
          reason: 'computed.since#9 — а эта с полосы свешивается, и цветом '
              'текста по полосе её края легли бы на подложку карточки и '
              'пропали: доля стояла за «надпись помещается», и спрашивается '
              'теперь именно это');
    });
  });

  // -------------------------------------------------------------------------
  // Target chart
  // -------------------------------------------------------------------------

  group('charts-canvas-theming.target-chart', () {
    testWidgets('#1 #2 one labelled bar per row from three parallel lists, and '
        'nothing at all when there are no labels', (tester) async {
      final canvas = _drawTarget(
        values: const <double>[1.0, 2.0, 3.0],
        targets: const <double>[10.0, 20.0, 30.0],
        labels: const <String>['Week', 'Month', 'Year'],
        color: green,
        theme: theme,
      );
      // Two round rects per row: the track and the completed part.
      expect(canvas.opsNamed('fillRoundRect'), hasLength(6),
          reason: 'charts-canvas-theming.target-chart#1 — one progress bar per '
              'row');
      expect(
          canvas
              .opsNamed('drawText')
              .where((op) => op.textAlign == core.TextAlign.right)
              .map((op) => op.text)
              .toList(),
          <String>['Week', 'Month', 'Year'],
          reason: 'charts-canvas-theming.target-chart#1 — labelled from the '
              'labels list, in order');

      final empty = _drawTarget(
        values: const <double>[],
        targets: const <double>[],
        labels: const <String>[],
        color: green,
        theme: theme,
      );
      expect(empty.ops, isEmpty,
          reason: 'charts-canvas-theming.target-chart#2 — onDraw returns '
              'immediately when labels is empty');
    });

    testWidgets('#4 the block of rows is vertically centred', (tester) async {
      final view = TargetChartView(
        values: const <double>[1.0],
        targets: const <double>[10.0],
        labels: const <String>['Week'],
        color: green,
        theme: theme,
      );
      final canvas = _RecordingCanvas(width: 300, height: 100);
      view.draw(canvas);

      // marginTop = (100 - 20 * 1) / 2 = 40.
      final track = canvas.opsNamed('fillRoundRect').first;
      expect(track.args[1], closeTo(40.0 + 20.0 * 0.05, 1e-9),
          reason: 'charts-canvas-theming.target-chart#4 — marginTop = '
              '(viewHeight - baseSize*labels.size) / 2');
    });

    testWidgets('#5 #6 the label gutter is the widest label plus 2*padding, '
        'right-aligned in contrast60', (tester) async {
      final canvas = _drawTarget(
        values: const <double>[50.0],
        targets: const <double>[100.0],
        labels: const <String>['Quarter'],
        color: green,
        theme: theme,
      );
      // 7 glyphs at tinyTextSize 10 * 0.6 = 42, stop = 42 + 8 = 50.
      final label = canvas.opsNamed('drawText').first;
      expect(label.fontSize, theme.smallTextSize,
          reason: 'charts-canvas-theming.target-chart#5 — measured at '
              'tinyTextSize');
      expect(label.args[0], closeTo(50.0 - 4.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#6 — drawn at '
              'rowLeft + stop - padding');
      expect(label.textAlign, core.TextAlign.right,
          reason: 'charts-canvas-theming.target-chart#6');
      expect(label.color, theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.target-chart#6 — contrast60');
      expect(canvas.opsNamed('fillRoundRect').first.args[0],
          closeTo(50.0 + 4.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#5 — the bar starts one '
              'padding past the gutter');
    });

    testWidgets('#7 #13 the background bar is a 2dp round rect in contrast20',
        (tester) async {
      final canvas = _drawTarget(
        values: const <double>[50.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      final track = canvas.opsNamed('fillRoundRect').first;
      // maxLabelSize = 5 * 6 = 30, stop = 38, so the track runs 42 .. 296.
      expect(track.args[0], closeTo(42.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#7');
      expect(track.args[0] + track.args[2], closeTo(300.0 - 4.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#7 — to rowRight - '
              'padding');
      expect(track.args[1], closeTo(20.0 * 0.05, 1e-9),
          reason: 'charts-canvas-theming.target-chart#7');
      expect(track.args[3], closeTo(20.0 - 2 * 20.0 * 0.05, 1e-9),
          reason: 'charts-canvas-theming.target-chart#7');
      expect(track.args[4], 2.0,
          reason: 'charts-canvas-theming.target-chart#7 — radius 2dp');
      expect(track.color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.target-chart#13 — '
              'lowContrastTextColor is contrast20');
    });

    testWidgets('#8 #10 percentage is clamped above but not below, and a '
        'non-positive target counts as complete', (tester) async {
      final half = _drawTarget(
        values: const <double>[50.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      expect(half.opsNamed('fillRoundRect')[1].args[2], closeTo(127.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#8 — values/targets');
      expect(half.opsNamed('fillRoundRect')[1].color, green,
          reason: 'charts-canvas-theming.target-chart#10 — the completed part '
              'is the habit colour, from the bar left edge');
      expect(half.opsNamed('fillRoundRect')[1].args[0],
          closeTo(half.opsNamed('fillRoundRect')[0].args[0], 1e-9),
          reason: 'charts-canvas-theming.target-chart#10');

      final over = _drawTarget(
        values: const <double>[500.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      expect(over.opsNamed('fillRoundRect')[1].args[2], closeTo(254.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#8 — clamped with '
              'min(1.0, percentage)');

      final zeroTarget = _drawTarget(
        values: const <double>[0.0],
        targets: const <double>[0.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      expect(zeroTarget.opsNamed('fillRoundRect')[1].args[2],
          closeTo(254.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#8 — a target of 0 gives '
              'a percentage of 1.0');

      final negative = _drawTarget(
        values: const <double>[-50.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      expect(negative.opsNamed('fillRoundRect')[1].args[2],
          closeTo(-127.0, 1e-9),
          reason: 'charts-canvas-theming.target-chart#8 — but never clamped '
              'below, so a negative value gives a negative width');
    });

    testWidgets('#9 a sliver of progress is bumped up to 2*round',
        (tester) async {
      final canvas = _drawTarget(
        values: const <double>[1.0],
        targets: const <double>[100000.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      expect(canvas.opsNamed('fillRoundRect')[1].args[2], 4.0,
          reason: 'charts-canvas-theming.target-chart#9 — a completedWidth '
              'strictly between 0 and 2*round becomes 2*round');

      final none = _drawTarget(
        values: const <double>[0.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      expect(none.opsNamed('fillRoundRect')[1].args[2], 0.0,
          reason: 'charts-canvas-theming.target-chart#9 — exactly zero is left '
              'alone');
    });

    testWidgets('#11 #12 the two value texts, and the width conditions on them',
        (tester) async {
      final canvas = _drawTarget(
        values: const <double>[50.0],
        targets: const <double>[100.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
      );
      final texts = canvas.opsNamed('drawText');
      expect(texts.map((op) => op.text).toList(),
          <String>['Today', '50', '50'],
          reason: 'charts-canvas-theming.target-chart#11 — the completed value '
              'and the remainder');
      expect(texts[1].color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.target-chart#11 — contrast0 inside '
              'the completed box');
      expect(texts[1].textAlign, core.TextAlign.center,
          reason: 'charts-canvas-theming.target-chart#11');
      expect(texts[1].args[0], closeTo(42.0 + 127.0 / 2, 1e-9),
          reason: 'charts-canvas-theming.target-chart#11 — centred inside the '
              'completed box');
      expect(texts[2].color, theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.target-chart#12 — contrast60 in the '
              'remaining region');
      expect(texts[2].args[0], closeTo((42.0 + 127.0 + 296.0) / 2, 1e-9),
          reason: 'charts-canvas-theming.target-chart#12 — centred in what is '
              'left');

      final tight = _drawTarget(
        values: const <double>[500000.0],
        targets: const <double>[1000000.0],
        labels: const <String>['Today'],
        color: green,
        theme: theme,
        width: 70,
      );
      expect(tight.texts, <String>['Today'],
          reason: 'charts-canvas-theming.target-chart#11 — neither text is '
              'drawn when it does not fit');
    });
  });

  // -------------------------------------------------------------------------
  // Card chrome, heights and scroll resets
  // -------------------------------------------------------------------------

  group('card chrome and hosting', () {
    testWidgets('show-habit.card-order-and-visibility#5 and '
        'charts-canvas-theming.chart-host-contracts#2: the Card style, and the '
        "history card's zero bottom padding", (tester) async {
      expect(ChartCard.cardPadding.top, 16.0,
          reason: 'show-habit.card-order-and-visibility#5 — 16dp top padding');
      expect(ChartCard.cardPadding.bottom, 16.0,
          reason: 'show-habit.card-order-and-visibility#5 — and 16dp bottom');
      expect(ChartCard.cardMargin.bottom, 1.0,
          reason: 'show-habit.card-order-and-visibility#5 — 1dp bottom margin');
      expect(ChartCard.elevation, 1.0,
          reason: 'show-habit.card-order-and-visibility#5 — 1dp elevation');

      await _pump(tester, BarCardView(state: barState()));
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(CoreView),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, const Color(0xFFFAFAFA),
          reason: 'show-habit.card-order-and-visibility#5 — the cardBgColor '
              'background');
      expect(material.elevation, 1.0,
          reason: 'show-habit.card-order-and-visibility#5');
      expect(tester.getSize(find.byType(ChartCard)).width, 400.0,
          reason: 'show-habit.card-order-and-visibility#5 — match_parent '
              'width');

      await _pump(tester, HistoryCardView(state: historyState()));
      final historyPadding = tester
          .widgetList<Padding>(find.byType(Padding))
          .map((p) => p.padding)
          .whereType<EdgeInsets>()
          .firstWhere((p) => p.left == 16.0 && p.right == 4.0);
      expect(historyPadding.bottom, 0.0,
          reason: 'show-habit.card-order-and-visibility#5 — the History card '
              'overrides paddingBottom to 0dp');
    });

    testWidgets('show-habit.card-order-and-visibility#7 and '
        'charts-canvas-theming.chart-host-contracts#2: the fixed chart heights',
        (tester) async {
      expect(ScoreCardView.chartHeight, 220.0,
          reason: 'show-habit.card-order-and-visibility#7 — Score chart 220dp');
      expect(BarCardView.chartHeight, 220.0,
          reason: 'show-habit.card-order-and-visibility#7 — Bar chart 220dp');
      expect(HistoryCardView.chartHeight, 160.0,
          reason: 'show-habit.card-order-and-visibility#7 — History chart '
              '160dp');
      expect(FrequencyCardView.chartHeight, 200.0,
          reason: 'show-habit.card-order-and-visibility#7 — Frequency chart '
              '200dp');

      await _pump(tester, ScoreCardView(state: scoreState()));
      expect(tester.getSize(find.byType(CoreView)).height, 220.0,
          reason: 'charts-canvas-theming.chart-host-contracts#2');
      await _pump(tester, BarCardView(state: barState()));
      expect(tester.getSize(find.byType(CoreView)).height, 220.0,
          reason: 'charts-canvas-theming.chart-host-contracts#2');
      await _pump(tester, HistoryCardView(state: historyState()));
      expect(tester.getSize(find.byType(CoreView)).height, 160.0,
          reason: 'charts-canvas-theming.chart-host-contracts#2');
      await _pump(tester, FrequencyCardView(state: frequencyState()));
      expect(tester.getSize(find.byType(CoreView)).height, 200.0,
          reason: 'charts-canvas-theming.chart-host-contracts#2');

      // The streak chart is WRAP_CONTENT, sized by streaks.size * 20dp.
      await _pump(tester, StreakCardView(state: streakState()));
      expect(tester.getSize(find.byType(CoreView)).height, 60.0,
          reason: 'show-habit.card-order-and-visibility#7 — the Streak chart '
              'is wrap_content (baseSize per streak row)');
      expect(tester.getSize(find.byType(CoreView)).height, 60.0,
          reason: 'charts-canvas-theming.chart-host-contracts#2');

      // The target chart is the one exception: show_habit_target.xml asks for
      // 300dp, but TargetChart.onMeasure only honours a MATCH_PARENT height,
      // so the port sizes it at labels.size * baseSize instead — the very
      // behaviour charts-canvas-theming.target-chart#3 describes.
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
      expect(tester.getSize(find.byType(CoreView)).height, 60.0,
          reason: 'charts-canvas-theming.target-chart#3');
    });

    testWidgets('charts-canvas-theming.barchart#22 and '
        'charts-canvas-theming.chart-host-contracts#5: how the bar card wires '
        'the chart', (tester) async {
      await _pump(
        tester,
        BarCardView(state: barState(isNumerical: true)),
      );
      final chart = _viewOf<BarChart>(tester);

      expect(chart.series, <List<double>>[
        <double>[5.0, 3.0]
      ], reason: 'charts-canvas-theming.barchart#22 — series = '
          '[entries.map { it.value / 1000.0 }]');
      expect(chart.colors, <core.Color>[theme.color(habitColor.paletteIndex)],
          reason: 'charts-canvas-theming.barchart#22 — colors = '
              '[theme.color(state.color.paletteIndex)]');
      expect(chart.axis, <core.LocalDate>[today, today.minus(7)],
          reason: 'charts-canvas-theming.barchart#22 — axis = '
              'entries.map { it.date }');
      expect(chart.dataOffset, 0,
          reason: 'charts-canvas-theming.barchart#22 — resetDataOffset() runs '
              'on every state change');

      // A new state builds a new chart, always back at the newest bucket.
      await _pump(
        tester,
        BarCardView(state: barState(isNumerical: true, numericalSpinnerPosition: 2)),
      );
      final rebuilt = _viewOf<BarChart>(tester);
      expect(identical(rebuilt, chart), isFalse,
          reason: 'charts-canvas-theming.chart-host-contracts#5 — the card '
              'hands its host a fresh chart on every state');
      expect(rebuilt.dataOffset, 0,
          reason: 'charts-canvas-theming.chart-host-contracts#5 — so changing '
              'the bucket spinner always snaps back to today');
    });

    testWidgets('show-habit.chart-scrolling#4 #5 #7: which charts jump back to '
        'today on refresh', (tester) async {
      await _pump(tester, BarCardView(state: barState()));
      expect(_viewOf<BarChart>(tester).dataOffset, 0,
          reason: 'show-habit.chart-scrolling#4 — BarCardView.setState calls '
              'resetDataOffset()');
      await _pump(tester, BarCardView(state: barState(boolSpinnerPosition: 2)));
      expect(_viewOf<BarChart>(tester).dataOffset, 0,
          reason: 'show-habit.chart-scrolling#4');

      await _pump(tester, ScoreCardView(state: scoreState()));
      expect(_viewOf<ScoreChartView>(tester).dataOffset, 0,
          reason: 'show-habit.chart-scrolling#5 — ScoreCardView.setState calls '
              'reset()');
      await _pump(tester, ScoreCardView(state: scoreState(spinnerPosition: 3)));
      expect(_viewOf<ScoreChartView>(tester).dataOffset, 0,
          reason: 'show-habit.chart-scrolling#5');

      await _pump(tester, HistoryCardView(state: historyState()));
      final first = _viewOf<HistoryChart>(tester);
      first.dataOffset = 4;
      await _pump(tester, HistoryCardView(state: historyState()));
      final second = _viewOf<HistoryChart>(tester);
      expect(identical(second, first), isFalse,
          reason: 'show-habit.chart-scrolling#7 — HistoryCardView replaces the '
              'whole HistoryChart object on every setState');
      expect(second.dataOffset, 0,
          reason: 'show-habit.chart-scrolling#7 — which resets its dataOffset '
              'to 0');
    });

    testWidgets('show-habit.chart-scrolling#9: a tap is onClick and a long '
        'press is onLongClick, in logical coordinates', (tester) async {
      final listener = _RecordingDateListener();
      await _pump(tester, listeningChart(historyState(), listener));
      final chart = _viewOf<HistoryChart>(tester);
      final origin = tester.getTopLeft(find.byType(CoreView));

      await tester.tapAt(origin + const Offset(10, 30));
      await tester.pump();
      expect(listener.shortPresses, hasLength(1),
          reason: 'show-habit.chart-scrolling#9 — a single tap is routed to '
              'onClick');
      // The same offset handed straight to the chart lands on the same date,
      // which is what "already divided by density" means here.
      chart.onClick(10, 30);
      expect(listener.shortPresses[1], listener.shortPresses[0],
          reason: 'show-habit.chart-scrolling#9 — with coordinates local to '
              'the chart, in logical units');

      await tester.longPressAt(origin + const Offset(10, 50));
      await tester.pump();
      expect(listener.longPresses, hasLength(1),
          reason: 'show-habit.chart-scrolling#9 — a long press is routed to '
              'onLongClick');
      chart.onLongClick(10, 50);
      expect(listener.longPresses[1], listener.longPresses[0],
          reason: 'show-habit.chart-scrolling#9');
    });
  });

  // -------------------------------------------------------------------------
  // The rules that survive only as methods on the chart views
  // -------------------------------------------------------------------------

  group('chart view internals', () {
    test('charts-canvas-theming.streak-chart#3: maxStreakCount is the row '
        'count the current height allows', () {
      expect(StreakChartView.maxStreakCount(100.0), 5,
          reason: 'charts-canvas-theming.streak-chart#3 — '
              'floor(measuredHeight / baseSize)');
      expect(StreakChartView.maxStreakCount(0.0), 0,
          reason: 'charts-canvas-theming.streak-chart#3');
      expect(StreakChartView.maxStreakCount(19.0), 0,
          reason: 'charts-canvas-theming.streak-chart#3 — a view shorter than '
              'one row shows none');
      expect(StreakChartView.maxStreakCount(59.0), 2,
          reason: 'charts-canvas-theming.streak-chart#3 — the remainder is '
              'floored, not rounded');
      expect(StreakChartView.maxStreakCount(60.0), 3,
          reason: 'charts-canvas-theming.streak-chart#3');
    });

    test('charts-canvas-theming.streak-chart#13: maxLabelWidth is never reset, '
        'so it only grows within one view instance', () {
      final view = StreakChartView(
        streaks: <core.Streak>[
          core.Streak(core.LocalDate.ymd(2015, 1, 16), today),
        ],
        color: green,
        theme: theme,
        dateFormatter: formatter,
        // measureText is 0.6 em per glyph, so a longer label is a wider one.
        dateLabel: (date) => 'XXXXXXXXXXXXXXXX',
      );
      final wide = _RecordingCanvas(width: 1200, height: 20);
      view.draw(wide);
      final grown = view.maxLabelWidth;
      expect(grown, greaterThan(0.0),
          reason: 'charts-canvas-theming.streak-chart#13 — the first draw '
              'measures the labels');

      // A second draw with *shorter* labels leaves the field alone: Kotlin's
      // updateMaxMinLengths resets maxLength and minLength but never
      // maxLabelWidth.
      final narrow = StreakChartView(
        streaks: view.streaks,
        color: green,
        theme: theme,
        dateFormatter: formatter,
        dateLabel: (date) => 'X',
      )..maxLabelWidth = grown;
      narrow.draw(_RecordingCanvas(width: 1200, height: 20));
      expect(narrow.maxLabelWidth, grown,
          reason: 'charts-canvas-theming.streak-chart#13 — a narrower label '
              'never shrinks it back');

      // The one place it *is* cleared is the label-suppression branch of #12.
      final squeezed = StreakChartView(
        streaks: view.streaks,
        color: green,
        theme: theme,
        dateFormatter: formatter,
        dateLabel: (date) => 'XXXXXXXXXXXXXXXX',
      );
      squeezed.draw(_RecordingCanvas(width: 100, height: 20));
      expect(squeezed.maxLabelWidth, 0.0,
          reason: 'charts-canvas-theming.streak-chart#13 — only #12 resets it');
    });

    test('charts-canvas-theming.streak-chart#14: the four-entry bar ramp and '
        'the three-entry text ramp', () {
      final view = StreakChartView(
        streaks: const <core.Streak>[],
        color: green,
        theme: theme,
        dateFormatter: formatter,
      );

      expect(view.colors, hasLength(4),
          reason: 'charts-canvas-theming.streak-chart#14 — IntArray(4)');
      expect(view.colors[0], theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.streak-chart#14 — colors[0] is '
              'contrast20');
      for (var i = 1; i <= 3; i++) {
        expect(view.colors[i].red, green.red,
            reason: 'charts-canvas-theming.streak-chart#14 — colors[$i] keeps '
                "the primary colour's red");
        expect(view.colors[i].green, green.green,
            reason: 'charts-canvas-theming.streak-chart#14');
        expect(view.colors[i].blue, green.blue,
            reason: 'charts-canvas-theming.streak-chart#14');
      }
      expect(view.colors[1].alpha, closeTo(96 / 255, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#14 — Color.argb(96, …)');
      expect(view.colors[2].alpha, closeTo(192 / 255, 1e-9),
          reason: 'charts-canvas-theming.streak-chart#14 — Color.argb(192, …)');
      expect(view.colors[3].alpha, 1.0,
          reason: 'charts-canvas-theming.streak-chart#14 — index 3 is the '
              'primary colour itself, alpha 255');

      expect(view.textColors, hasLength(3),
          reason: 'charts-canvas-theming.streak-chart#14 — IntArray(3)');
      expect(view.textColors[0], theme.highContrastTextColor,
          reason: 'charts-canvas-theming.streak-chart#14 — textColors[0] is '
              "contrast80, the port's high-contrast text colour");
      expect(view.textColors[1], theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.streak-chart#14 — textColors[1] is '
              'contrast60');
      expect(view.textColors[2], theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.streak-chart#14 — textColors[2] is '
              'contrast0');
    });

    test('charts-canvas-theming.streak-chart#15: populateWithRandomData builds '
        'ten consecutive streaks starting today', () {
      final streaks =
          StreakChartView.populateWithRandomData(random: Random(1234));

      expect(streaks, hasLength(10),
          reason: 'charts-canvas-theming.streak-chart#15 — `for (i in 0..9)`');
      expect(streaks.first.start, today,
          reason: 'charts-canvas-theming.streak-chart#15 — the first one '
              'starts today');
      for (final streak in streaks) {
        // end = start.plus(nextInt(100)), so the length is 1..100 days.
        final length = streak.start.daysUntil(streak.end);
        expect(length, inInclusiveRange(0, 99),
            reason: 'charts-canvas-theming.streak-chart#15 — random length '
                '0..99');
      }
      for (var i = 1; i < streaks.length; i++) {
        expect(streaks[i].start, streaks[i - 1].end.plus(1),
            reason: 'charts-canvas-theming.streak-chart#15 — each one begins '
                'the day after the previous ends');
      }
    });

    test('charts-canvas-theming.frequency-chart#14: populateWithRandomData '
        'fills forty months backwards with seven values each', () {
      final frequency =
          FrequencyChartView.populateWithRandomData(random: Random(7));

      expect(frequency, hasLength(40),
          reason: 'charts-canvas-theming.frequency-chart#14 — `for (i in '
              '0..39)`');
      var date = core.LocalDate.ymd(today.year, today.month, 1);
      for (var i = 0; i < 40; i++) {
        expect(frequency.containsKey(date), isTrue,
            reason: 'charts-canvas-theming.frequency-chart#14 — consecutive '
                'months walking backwards from the current one');
        final values = frequency[date]!;
        expect(values, hasLength(7),
            reason: 'charts-canvas-theming.frequency-chart#14 — IntArray(7)');
        for (final value in values) {
          expect(value, inInclusiveRange(0, 4),
              reason: 'charts-canvas-theming.frequency-chart#14 — '
                  'rand.nextInt(5)');
        }
        date = core.LocalDate.ymd(
          date.month == 1 ? date.year - 1 : date.year,
          date.month == 1 ? 12 : date.month - 1,
          1,
        );
      }
    });

    test('charts-canvas-theming.frequency-chart#13: a transparent background '
        'changes the colours and nothing else', () {
      final widgetTheme = core.WidgetTheme();
      _RecordingCanvas render(core.Theme t) {
        final view = FrequencyChartView(
          frequency: <core.LocalDate, List<int>>{
            core.LocalDate.ymd(2015, 1, 1): <int>[0, 4, 2, 1, 0, 3, 0],
            core.LocalDate.ymd(2014, 12, 1): <int>[1, 1, 1, 1, 1, 1, 1],
          },
          color: t.colorOf(habitColor),
          theme: t,
          dateFormatter: formatter,
          firstWeekday: core.DayOfWeek.sunday,
          isNumerical: false,
          today: today,
        );
        final canvas = _RecordingCanvas(width: 300, height: 200);
        view.draw(canvas);
        return canvas;
      }

      final light = render(theme);
      final transparent = render(widgetTheme);

      // `setIsBackgroundTransparent(true)` only re-runs initColors(): there is
      // no offscreen bitmap and no xfermode, so the call *sequence* is
      // identical and only the paint colours move.
      expect(
        transparent.ops.map((op) => op.name).toList(),
        light.ops.map((op) => op.name).toList(),
        reason: 'charts-canvas-theming.frequency-chart#13 — the same calls, in '
            'the same order',
      );
      expect(
        transparent.ops.map((op) => op.args).toList(),
        light.ops.map((op) => op.args).toList(),
        reason: 'charts-canvas-theming.frequency-chart#13 — with the same '
            'geometry',
      );
      expect(
        transparent.ops.map((op) => op.text).toList(),
        light.ops.map((op) => op.text).toList(),
        reason: 'charts-canvas-theming.frequency-chart#13',
      );
      expect(
        transparent.ops.map((op) => op.color).toList(),
        isNot(light.ops.map((op) => op.color).toList()),
        reason: 'charts-canvas-theming.frequency-chart#13 — only the colours '
            'differ, which is exactly what initColors changes',
      );
    });

    test('charts-canvas-theming.score-chart#6: a chart with no scores yet '
        'draws nothing at all', () {
      final canvas = _RecordingCanvas(width: 300, height: 200);
      ScoreChartView(
        color: green,
        theme: theme,
        dateFormatter: formatter,
        bucketSize: 7,
      ).draw(canvas);
      expect(canvas.ops, isEmpty,
          reason: 'charts-canvas-theming.score-chart#6 — onDraw returns before '
              'the grid when scores is null');

      // An *empty* list is not the same thing: the grid is still drawn.
      final empty = _RecordingCanvas(width: 300, height: 200);
      ScoreChartView(
        scores: const <core.Score>[],
        color: green,
        theme: theme,
        dateFormatter: formatter,
        bucketSize: 7,
      ).draw(empty);
      expect(empty.ops, isNotEmpty,
          reason: 'charts-canvas-theming.score-chart#6 — only null short '
              'circuits');
    });

    test('charts-canvas-theming.score-chart#18: populateWithRandomData is a '
        '99-step random walk from 0.5', () {
      final scores =
          ScoreChartView.populateWithRandomData(random: Random(99));

      expect(scores, hasLength(99),
          reason: 'charts-canvas-theming.score-chart#18 — `for (i in 1..99)`');
      for (var i = 0; i < scores.length; i++) {
        expect(scores[i].date, today.minus(i + 1),
            reason: 'charts-canvas-theming.score-chart#18 — walking backwards '
                'from today, starting at today - 1');
        expect(scores[i].value, inInclusiveRange(0.0, 1.0),
            reason: 'charts-canvas-theming.score-chart#18 — clamped to 0..1');
      }
      var previous = 0.5;
      for (final score in scores) {
        expect((score.value - previous).abs(), lessThanOrEqualTo(0.1 + 1e-9),
            reason: 'charts-canvas-theming.score-chart#18 — a random walk of '
                'step 0.1 starting at 0.5');
        previous = score.value;
      }
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
