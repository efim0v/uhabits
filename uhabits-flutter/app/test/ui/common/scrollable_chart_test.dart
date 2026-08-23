/// Widget tests for the horizontal scroller that wraps a core `DataView`.
///
/// Two Android classes are collapsed into one widget here, so the rules of two
/// features are asserted against the same file:
///
///  * `charts-canvas-theming.scrollable-chart` — ScrollableChart.kt, the base
///    class of the legacy Paint-based charts (Score, Frequency, HeaderView).
///  * `show-habit.chart-scrolling` — AndroidDataView.kt, the host of the core
///    Canvas charts (History, Bar), plus what the show-habit cards do with it.
///
/// Rules deliberately left uncited, because the port replaces what they
/// describe:
///
///  * `charts-canvas-theming.scrollable-chart#11` — Parcelable instance state
///    in a BundleSavedState. Flutter has no configuration-change teardown: the
///    State object survives every rebuild, which is what #6 asks for.
///  * `charts-canvas-theming.scrollable-chart#12` — the
///    GestureDetector.OnGestureListener contract (onDown true, onSingleTapUp
///    false, onTouchEvent delegating to the detector). Flutter's gesture arena
///    replaces all of it; what remains observable is that a legacy chart
///    ignores taps, which is simply what happens when nothing is wired to
///    [ScrollableChart.onTap].
///  * `show-habit.chart-scrolling#7` — HistoryCardView replacing the chart
///    object, which drops its dataOffset back to 0. The Flutter cards rebuild
///    their chart on every frame, so honouring that here would make the chart
///    unscrollable; history_card_view.dart carries the rule instead.
library;

// The core drawing vocabulary wins over Flutter's: Canvas, Color and TextAlign
// below are the ones the ported views speak.
import 'package:flutter/material.dart' hide Canvas, Color, Image, TextAlign;
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/common/scrollable_chart.dart';
// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/views/bar_chart.dart';
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/views/history_chart.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  group('charts-canvas-theming.scrollable-chart', () {
    testWidgets('#1 #2 the offset starts at 0, with ScrollableChart defaults',
        (tester) async {
      final view = _FakeView(columnWidth: 10.0);
      final controller = ScrollableChartController();
      await _pump(tester, ScrollableChart(view: view, controller: controller));

      expect(controller.dataOffset, 0,
          reason: 'charts-canvas-theming.scrollable-chart#1');
      expect(view.paintedOffsets.last, 0,
          reason: 'charts-canvas-theming.scrollable-chart#1');
      expect(ScrollableChart.defaultMaxDataOffset, 12 * 200,
          reason: 'charts-canvas-theming.scrollable-chart#2');
      expect(ScrollableChart.defaultMaxDataOffset, 2400,
          reason: 'charts-canvas-theming.scrollable-chart#2');
      expect(ScrollableChart.defaultDirection, 1,
          reason: 'charts-canvas-theming.scrollable-chart#2');
      expect(ScrollableChart.defaultBucketSize, 1.0,
          reason: 'charts-canvas-theming.scrollable-chart#2');
    });

    testWidgets('#2 with no view to measure, the bucket is one logical pixel',
        (tester) async {
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(
          builder: (context, dataOffset) => _label(dataOffset),
          onDataOffsetChanged: reported.add,
        ),
      );

      // One drag event of three pixels crosses three one-pixel buckets, and is
      // reported once — the offset is a position, not a step count.
      await _dragBy(tester, 3);
      expect(reported, [3], reason: 'charts-canvas-theming.scrollable-chart#2');

      await _dragBy(tester, 1);
      expect(reported, [3, 4],
          reason: 'charts-canvas-theming.scrollable-chart#2');
      expect(find.text('offset 4'), findsOneWidget,
          reason: 'charts-canvas-theming.scrollable-chart#2');
    });

    testWidgets('#3 maxX is maxDataOffset * scrollerBucketSize',
        (tester) async {
      final controller = ScrollableChartController();
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          controller: controller,
          maxDataOffset: 7,
        ),
      );
      expect(controller.maxX, 70.0,
          reason: 'charts-canvas-theming.scrollable-chart#3');

      final other = ScrollableChartController();
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          controller: other,
          bucketSize: 4.0,
        ),
      );
      expect(other.maxX, 2400 * 4.0,
          reason: 'charts-canvas-theming.scrollable-chart#3');
    });

    testWidgets('#4 a bucket size of 0 swallows the drag', (tester) async {
      final view = _FakeView(columnWidth: 0.0);
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(view: view, onDataOffsetChanged: reported.add),
      );

      await _dragBy(tester, 300);

      expect(reported, isEmpty,
          reason: 'charts-canvas-theming.scrollable-chart#4');
      expect(view.paintedOffsets.last, 0,
          reason: 'charts-canvas-theming.scrollable-chart#4');
    });

    testWidgets('#4 the drag is clamped to maxX, so nothing piles up past it',
        (tester) async {
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          maxDataOffset: 3,
          onDataOffsetChanged: reported.add,
        ),
      );

      // Ten columns of travel in one event stop at the third.
      await _dragBy(tester, 1000);
      expect(reported.last, 3,
          reason: 'charts-canvas-theming.scrollable-chart#4');

      // Coming back is immediate: the scroller sits exactly on maxX.
      await _dragBy(tester, -10);
      expect(reported.last, 2,
          reason: 'charts-canvas-theming.scrollable-chart#4');
    });

    testWidgets(
        '#4 a horizontal drag does not scroll the page the chart sits in',
        (tester) async {
      final list = ScrollController();
      addTearDown(list.dispose);
      final reported = <int>[];
      final view = _FakeView(columnWidth: 10.0);
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            controller: list,
            children: <Widget>[
              SizedBox(
                height: 200,
                child: ScrollableChart(
                  view: view,
                  onDataOffsetChanged: reported.add,
                ),
              ),
              for (var i = 0; i < 20; i++)
                SizedBox(height: 100, child: Text('row $i')),
            ],
          ),
        ),
      );

      await _dragBy(tester, 100);

      expect(reported.last, 10,
          reason: 'charts-canvas-theming.scrollable-chart#4 and '
              'show-habit.chart-scrolling#3 — requestDisallowInterceptTouchEvent');
      expect(list.offset, 0.0,
          reason: 'charts-canvas-theming.scrollable-chart#4 and '
              'show-habit.chart-scrolling#3');

      // The other half of the bargain: a vertical drag still belongs to the
      // page, and leaves the chart alone.
      await tester.drag(find.byType(ScrollableChart), const Offset(0, -150));
      await tester.pumpAndSettle();

      expect(list.offset, greaterThan(0.0),
          reason: 'show-habit.chart-scrolling#3');
      expect(reported.last, 10, reason: 'show-habit.chart-scrolling#3');
    });

    testWidgets('#5 #6 a fling keeps scrolling after the finger is up',
        (tester) async {
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          onDataOffsetChanged: reported.add,
        ),
      );

      expect(ScrollableChart.flingVelocityFactor, 0.5,
          reason: 'charts-canvas-theming.scrollable-chart#5 — '
              'direction * velocityX / 2');

      await tester.fling(
          find.byType(ScrollableChart), const Offset(200, 0), 2000);
      await tester.pump();
      final afterFinger = reported.last;

      // One frame of the animator is enough to move further than the drag did.
      await tester.pump(const Duration(milliseconds: 32));
      expect(reported.last, greaterThan(afterFinger),
          reason: 'charts-canvas-theming.scrollable-chart#6');

      await tester.pumpAndSettle();
      final afterFling = reported.last;
      expect(afterFling, greaterThan(afterFinger),
          reason: 'charts-canvas-theming.scrollable-chart#5');

      // And the animator cancels itself once the scroller is finished, rather
      // than ticking forever.
      await tester.pump(const Duration(seconds: 5));
      expect(reported.last, afterFling,
          reason: 'charts-canvas-theming.scrollable-chart#6');
    });

    testWidgets('#5 a fling is bounded by 0 and maxX', (tester) async {
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          maxDataOffset: 4,
          onDataOffsetChanged: reported.add,
        ),
      );

      await tester.fling(find.byType(ScrollableChart), const Offset(400, 0), 8000);
      await tester.pumpAndSettle();
      expect(reported.last, 4,
          reason: 'charts-canvas-theming.scrollable-chart#5');

      await tester.fling(
          find.byType(ScrollableChart), const Offset(-400, 0), 8000);
      await tester.pumpAndSettle();
      expect(reported.last, 0,
          reason: 'charts-canvas-theming.scrollable-chart#5');
    });

    testWidgets('#7 the offset is whole buckets, reported only when it changes',
        (tester) async {
      final reported = <int>[];
      final view = _FakeView(columnWidth: 10.0);
      await _pump(
        tester,
        ScrollableChart(view: view, onDataOffsetChanged: reported.add),
      );

      // Nine pixels of a ten-pixel bucket: nothing yet.
      await _dragBy(tester, 9);
      expect(reported, isEmpty,
          reason: 'charts-canvas-theming.scrollable-chart#7');
      expect(view.paintedOffsets.last, 0,
          reason: 'charts-canvas-theming.scrollable-chart#7');

      // Crossing the boundary reports exactly one column, once.
      await _dragBy(tester, 1);
      await _dragBy(tester, 5);
      await _dragBy(tester, -5);
      expect(reported, [1], reason: 'charts-canvas-theming.scrollable-chart#7');
      expect(view.paintedOffsets.last, 1,
          reason: 'charts-canvas-theming.scrollable-chart#7');
    });

    testWidgets('#7 the offset is clamped to maxDataOffset', (tester) async {
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          maxDataOffset: 2,
          onDataOffsetChanged: reported.add,
        ),
      );

      await _dragBy(tester, 10);
      await _dragBy(tester, 30);

      expect(reported, [1, 2],
          reason: 'charts-canvas-theming.scrollable-chart#7');
    });

    testWidgets('#8 the scroll direction is 1 or -1, and nothing else',
        (tester) async {
      expect(
        () => ScrollableChart(view: _FakeView(), direction: 0),
        throwsArgumentError,
        reason: 'charts-canvas-theming.scrollable-chart#8',
      );
      expect(
        () => ScrollableChart(view: _FakeView(), direction: 2),
        throwsArgumentError,
        reason: 'charts-canvas-theming.scrollable-chart#8',
      );
      expect(
        () => ScrollableChart(view: _FakeView(), direction: -2),
        throwsArgumentError,
        reason: 'charts-canvas-theming.scrollable-chart#8',
      );
      expect(ScrollableChart(view: _FakeView(), direction: -1).direction, -1,
          reason: 'charts-canvas-theming.scrollable-chart#8');
    });

    testWidgets('#8 direction -1 walks into the past the other way',
        (tester) async {
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          direction: -1,
          onDataOffsetChanged: reported.add,
        ),
      );

      // Mirrored: a leftward drag is the one that walks into the past.
      await _dragBy(tester, -30);
      expect(reported, [3], reason: 'charts-canvas-theming.scrollable-chart#8');

      await _dragBy(tester, 30);
      expect(reported, [3, 0],
          reason: 'charts-canvas-theming.scrollable-chart#8');

      // And there is no future to reach on this side either.
      await _dragBy(tester, 10);
      expect(reported, [3, 0],
          reason: 'charts-canvas-theming.scrollable-chart#8');

      // The fling is mirrored with it: `scroller.fling(…, direction *
      // velocityX / 2, …)`.
      await tester.fling(
          find.byType(ScrollableChart), const Offset(-200, 0), 3000);
      await tester.pump();
      final afterFinger = reported.last;
      await tester.pumpAndSettle();
      expect(reported.last, greaterThan(afterFinger),
          reason: 'charts-canvas-theming.scrollable-chart#8 and '
              'charts-canvas-theming.scrollable-chart#5');
    });

    testWidgets('#9 a smaller maxDataOffset clamps the offset and says so',
        (tester) async {
      final reported = <int>[];
      final view = _FakeView(columnWidth: 10.0);
      final controller = ScrollableChartController();
      await _pump(
        tester,
        ScrollableChart(
          view: view,
          controller: controller,
          maxDataOffset: 10,
          onDataOffsetChanged: reported.add,
        ),
      );
      await _dragBy(tester, 80);
      expect(reported.last, 8,
          reason: 'charts-canvas-theming.scrollable-chart#9');

      await _pump(
        tester,
        ScrollableChart(
          view: view,
          controller: controller,
          maxDataOffset: 3,
          onDataOffsetChanged: reported.add,
        ),
      );

      expect(controller.dataOffset, 3,
          reason: 'charts-canvas-theming.scrollable-chart#9');
      expect(reported.last, 3,
          reason: 'charts-canvas-theming.scrollable-chart#9');
      expect(view.paintedOffsets.last, 3,
          reason: 'charts-canvas-theming.scrollable-chart#9');

      // Wart, faithfully reproduced: `setMaxDataOffset` clamps the offset but
      // leaves the scroller eighty pixels along, past the new maxX of thirty.
      // The next drag — in either direction — is `min(dx, maxX - currX)`, so
      // it yanks the position back onto the limit before anything else.
      await _dragBy(tester, 10);
      expect(controller.dataOffset, 3,
          reason: 'charts-canvas-theming.scrollable-chart#9 and '
              'charts-canvas-theming.scrollable-chart#4');
      await _dragBy(tester, -10);
      expect(controller.dataOffset, 2,
          reason: 'charts-canvas-theming.scrollable-chart#9 and '
              'charts-canvas-theming.scrollable-chart#4');
    });

    testWidgets('#10 reset snaps back to the newest data', (tester) async {
      final reported = <int>[];
      final view = _FakeView(columnWidth: 10.0);
      final controller = ScrollableChartController();
      await _pump(
        tester,
        ScrollableChart(
          view: view,
          controller: controller,
          onDataOffsetChanged: reported.add,
        ),
      );
      await _dragBy(tester, 50);
      expect(controller.dataOffset, 5,
          reason: 'charts-canvas-theming.scrollable-chart#10');

      controller.reset();
      await tester.pump();

      expect(controller.dataOffset, 0,
          reason: 'charts-canvas-theming.scrollable-chart#10');
      expect(reported.last, 0,
          reason: 'charts-canvas-theming.scrollable-chart#10');
      expect(view.paintedOffsets.last, 0,
          reason: 'charts-canvas-theming.scrollable-chart#10');

      // The scroller is back at zero, not merely reporting zero: one bucket of
      // travel is one column again.
      await _dragBy(tester, 10);
      expect(controller.dataOffset, 1,
          reason: 'charts-canvas-theming.scrollable-chart#10');
    });

    testWidgets('#10 reset stops a fling in flight', (tester) async {
      final controller = ScrollableChartController();
      await _pump(
        tester,
        ScrollableChart(
          view: _FakeView(columnWidth: 10.0),
          controller: controller,
        ),
      );

      await tester.fling(
          find.byType(ScrollableChart), const Offset(300, 0), 4000);
      await tester.pump();
      controller.reset();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.dataOffset, 0,
          reason: 'charts-canvas-theming.scrollable-chart#10');
    });

    testWidgets('#13 with nothing listening, scrolling is still silent',
        (tester) async {
      final view = _FakeView(columnWidth: 10.0);
      await _pump(tester, ScrollableChart(view: view));

      await _dragBy(tester, 50);

      expect(view.paintedOffsets.last, 5,
          reason: 'charts-canvas-theming.scrollable-chart#13');
    });
  });

  group('show-habit.chart-scrolling', () {
    testWidgets('#1 dragging right walks backwards in time', (tester) async {
      final view = _FakeView(columnWidth: 10.0);
      await _pump(tester, ScrollableChart(view: view));

      await _dragBy(tester, 25);

      expect(view.paintedOffsets.last, 2,
          reason: 'show-habit.chart-scrolling#1');
    });

    testWidgets('#1 the offset never goes below 0', (tester) async {
      final reported = <int>[];
      final view = _FakeView(columnWidth: 10.0);
      await _pump(
        tester,
        ScrollableChart(view: view, onDataOffsetChanged: reported.add),
      );

      await _dragBy(tester, -100);

      expect(reported, isEmpty, reason: 'show-habit.chart-scrolling#1');
      expect(view.paintedOffsets.last, 0,
          reason: 'show-habit.chart-scrolling#1');

      // Wart, faithfully reproduced: android.widget.Scroller lets currX run
      // negative, and only max(0, currX / bucket) is clamped — so the hundred
      // pixels of debt above have to be dragged back before the chart moves.
      await _dragBy(tester, 100);
      expect(reported, isEmpty, reason: 'show-habit.chart-scrolling#1');
      await _dragBy(tester, 10);
      expect(reported, [1], reason: 'show-habit.chart-scrolling#1');
    });

    testWidgets('#2 a bucket width and 2400 buckets, the Score/Frequency way',
        (tester) async {
      final reported = <int>[];
      final controller = ScrollableChartController();
      await _pump(
        tester,
        ScrollableChart(
          builder: (context, dataOffset) => _label(dataOffset),
          controller: controller,
          bucketSize: 40.0,
          onDataOffsetChanged: reported.add,
        ),
      );

      expect(controller.maxX, 2400 * 40.0,
          reason: 'show-habit.chart-scrolling#2');

      await _dragBy(tester, 120);
      expect(reported, [3], reason: 'show-habit.chart-scrolling#2');
      expect(find.text('offset 3'), findsOneWidget,
          reason: 'show-habit.chart-scrolling#2');

      // Thirty-nine more pixels are still the third bucket.
      await _dragBy(tester, 39);
      expect(reported, [3], reason: 'show-habit.chart-scrolling#2');
      await _dragBy(tester, 1);
      expect(reported, [3, 4], reason: 'show-habit.chart-scrolling#2');
    });

    testWidgets('#4 #5 a card that refreshes resets the chart to the newest '
        'bucket', (tester) async {
      final view = _FakeView(columnWidth: 10.0);
      final controller = ScrollableChartController();
      await _pump(
        tester,
        ScrollableChart(view: view, controller: controller),
      );
      await _dragBy(tester, 70);
      expect(controller.dataOffset, 7,
          reason: 'show-habit.chart-scrolling#4 and '
              'show-habit.chart-scrolling#5');

      // What BarCardView.setState does with `binding.chart.resetDataOffset()`
      // and ScoreCardView.setState with `binding.scoreView.reset()`.
      controller.reset();
      await tester.pump();

      expect(controller.dataOffset, 0,
          reason: 'show-habit.chart-scrolling#4 and '
              'show-habit.chart-scrolling#5');
      expect(view.paintedOffsets.last, 0,
          reason: 'show-habit.chart-scrolling#4 and '
              'show-habit.chart-scrolling#5');
    });

    testWidgets('#6 without a reset the scroll position survives a refresh',
        (tester) async {
      final controller = ScrollableChartController();
      // The Frequency card rebuilds its chart on every refresh, and — unlike
      // the Bar and Score cards — never resets the scroller.
      ScrollableChart chart() => ScrollableChart(
            view: _FakeView(columnWidth: 10.0),
            controller: controller,
          );

      await _pump(tester, chart());
      await _dragBy(tester, 40);
      expect(controller.dataOffset, 4, reason: 'show-habit.chart-scrolling#6');

      await _pump(tester, chart());

      expect(controller.dataOffset, 4, reason: 'show-habit.chart-scrolling#6');
      final refreshed = tester
          .widget<ScrollableChart>(find.byType(ScrollableChart))
          .view! as _FakeView;
      expect(refreshed.paintedOffsets.last, 4,
          reason: 'show-habit.chart-scrolling#6');

      // Half a bucket further is still the fourth column: the scroller kept
      // its sub-bucket remainder too.
      await _dragBy(tester, 5);
      expect(controller.dataOffset, 4, reason: 'show-habit.chart-scrolling#6');
      await _dragBy(tester, 5);
      expect(controller.dataOffset, 5, reason: 'show-habit.chart-scrolling#6');
    });

    testWidgets('#8 dataColumnWidth: 18 for the Bar chart', (tester) async {
      final chart = BarChart(LightTheme(), _Formatter())
        ..series = <List<double>>[
          <double>[1.0, 2.0, 3.0, 4.0, 5.0],
        ]
        ..colors = <Color>[Color.RED]
        ..axis = <LocalDate>[
          for (var i = 0; i < 5; i++) LocalDate.ymd(2015, 1, 20 + i),
        ];
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(view: chart, onDataOffsetChanged: reported.add),
      );

      expect(chart.dataColumnWidth, 18.0,
          reason: 'show-habit.chart-scrolling#8');
      expect(chart.barWidth + 2 * chart.barMargin, 18.0,
          reason: 'show-habit.chart-scrolling#8');

      await _dragBy(tester, 18);
      expect(reported, [1], reason: 'show-habit.chart-scrolling#8');
      expect(chart.dataOffset, 1, reason: 'show-habit.chart-scrolling#8');
    });

    testWidgets('#8 dataColumnWidth: squareSpacing + squareSize for History',
        (tester) async {
      final chart = HistoryChart(
        dateFormatter: _Formatter(),
        firstWeekday: DayOfWeek.sunday,
        paletteColor: const PaletteColor(0),
        series: <Square>[],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
        theme: LightTheme(),
        today: LocalDate.ymd(2015, 1, 25),
      );
      final reported = <int>[];
      await _pump(
        tester,
        ScrollableChart(view: chart, onDataOffsetChanged: reported.add),
        height: 160,
      );

      // A 160dp card: squareSize is (height - 2 * padding) / 8, and the column
      // is that plus the 1dp gap between squares.
      expect(chart.dataColumnWidth, chart.squareSpacing + 20.0,
          reason: 'show-habit.chart-scrolling#8');
      expect(chart.dataColumnWidth, 21.0,
          reason: 'show-habit.chart-scrolling#8');

      await _dragBy(tester, 21);
      expect(reported, [1], reason: 'show-habit.chart-scrolling#8');
      expect(chart.dataOffset, 1, reason: 'show-habit.chart-scrolling#8');
    });

    testWidgets('#9 a tap is a click and a long press a long click, in '
        'logical units', (tester) async {
      final view = _FakeView(columnWidth: 10.0);
      var taps = 0;
      var longPresses = 0;
      await _pump(
        tester,
        ScrollableChart(
          view: view,
          onTap: () => taps++,
          onLongPress: () => longPresses++,
        ),
      );

      await tester.tapAt(const Offset(30, 40));
      await tester.pump();
      expect(view.clicks, <List<double>>[
        <double>[30.0, 40.0],
      ], reason: 'show-habit.chart-scrolling#9');
      expect(taps, 1, reason: 'show-habit.chart-scrolling#9');

      await tester.longPressAt(const Offset(50, 60));
      await tester.pump();
      expect(view.longClicks, <List<double>>[
        <double>[50.0, 60.0],
      ], reason: 'show-habit.chart-scrolling#9');
      expect(longPresses, 1, reason: 'show-habit.chart-scrolling#9');
      expect(view.clicks.length, 1, reason: 'show-habit.chart-scrolling#9');
    });

    testWidgets('#9 a drag is not a tap', (tester) async {
      final view = _FakeView(columnWidth: 10.0);
      await _pump(tester, ScrollableChart(view: view));

      await _dragBy(tester, 60);

      expect(view.clicks, isEmpty, reason: 'show-habit.chart-scrolling#9');
      expect(view.paintedOffsets.last, 6,
          reason: 'show-habit.chart-scrolling#9');
    });
  });
}

/// Pumps [chart] into a 600x[height] slot pinned to the top left, so a local
/// coordinate and a global one are the same number.
Future<void> _pump(
  WidgetTester tester,
  Widget chart, {
  double height = 200,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 600, height: height, child: chart),
      ),
    ),
  );
}

/// What the `builder` form is given: a stand-in for a show-habit card, which
/// always carries tap handlers of its own (every card paints through a
/// `CoreView`).
///
/// The handlers matter to the tests, not to the assertions: they keep the
/// gesture arena contested, so the horizontal drag recogniser has to pay the
/// touch slop before it wins. A bare `Text` would leave the recogniser alone in
/// the arena, where it wins at the pointer-down and counts the slop movement
/// too.
Widget _label(int dataOffset) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      onLongPress: () {},
      child: Text('offset $dataOffset'),
    );

/// One horizontal drag of exactly [dx] logical pixels.
///
/// The first move only pays the touch slop: with the default
/// DragStartBehavior.start the recogniser swallows whatever it took to win the
/// arena, so the second move is the one the chart sees.
Future<void> _dragBy(WidgetTester tester, double dx) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.byType(ScrollableChart)));
  await gesture.moveBy(Offset(dx.isNegative ? -20 : 20, 0));
  await gesture.moveBy(Offset(dx, 0));
  await gesture.up();
  await tester.pump();
}

/// A [DataView] that records what it was asked to draw and where it was
/// clicked. [columnWidth] stands in for the `dataColumnWidth` of a real chart.
class _FakeView extends DataView {
  _FakeView({this.columnWidth = 10.0});

  double columnWidth;

  @override
  int dataOffset = 0;

  @override
  double get dataColumnWidth => columnWidth;

  final List<int> paintedOffsets = <int>[];
  final List<List<double>> clicks = <List<double>>[];
  final List<List<double>> longClicks = <List<double>>[];

  @override
  void draw(Canvas canvas) => paintedOffsets.add(dataOffset);

  @override
  void onClick(double x, double y) => clicks.add(<double>[x, y]);

  @override
  void onLongClick(double x, double y) => longClicks.add(<double>[x, y]);
}

/// The few names the two real charts ask a [LocalDateFormatter] for.
class _Formatter implements LocalDateFormatter {
  static const List<String> _weekdays = <String>[
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', //
  ];

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  @override
  String shortWeekdayNameOf(DayOfWeek weekday) =>
      _weekdays[weekday.daysSinceSunday];

  @override
  String shortWeekdayName(LocalDate date) => shortWeekdayNameOf(date.dayOfWeek);

  @override
  String longWeekdayNameOf(DayOfWeek weekday) => shortWeekdayNameOf(weekday);

  @override
  String shortMonthName(LocalDate date) => _months[date.month - 1];

  @override
  String longMonthName(LocalDate date) => shortMonthName(date);
}
