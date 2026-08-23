import 'package:test/test.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart';
import 'package:uhabits_core/src/ui/views/ring.dart' show notesIndicatorRadius;
import 'package:uhabits_core/uhabits_core.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt
/// and uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/HistoryChartTest.kt.
///
/// The Kotlin test is a golden-image test: it renders the chart onto a
/// JavaCanvas and diffs the PNG. This package has no raster backend, so the
/// same behaviour is pinned against [RecordingCanvas], a fake that logs every
/// drawing call together with the paint state it was made under. Every
/// coordinate the Kotlin renderer would have produced is therefore asserted
/// directly, which is strictly more precise than a 1.0-luminosity image diff.
///
/// The base fixture is the Kotlin one: a 400x200 logical chart, today =
/// 2015-01-25 (a Sunday), palette index 7, LightTheme, a US date formatter and
/// 85 series entries. With [TestDateFormatter]'s metrics this yields
/// nColumns = 14 and topLeftDate = 2014-10-26, exactly the geometry the
/// upstream click test in `HistoryChartTest.testClick` depends on.
void main() {
  group('charts-canvas-theming.historychart-layout', () {
    test('#1 constructed as a DataView from the eight required parts plus two '
        'defaulted ones', () {
      // No onDateClickedListener and no padding: both are defaulted.
      final chart = HistoryChart(
        dateFormatter: const TestDateFormatter(),
        firstWeekday: DayOfWeek.sunday,
        paletteColor: const PaletteColor(7),
        series: <Square>[Square.on],
        defaultSquare: Square.off,
        notesIndicators: <bool>[true],
        theme: LightTheme(),
        today: LocalDate.ymd(2015, 1, 25),
      );

      expect(chart, isA<DataView>(),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart, isA<View>(),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.padding, 0.0,
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.onDateClickedListener, isA<OnDateClickedListener>(),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.dateFormatter, isA<LocalDateFormatter>(),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.firstWeekday, DayOfWeek.sunday,
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.paletteColor, const PaletteColor(7),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.series, <Square>[Square.on],
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.defaultSquare, Square.off,
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.notesIndicators, <bool>[true],
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.theme, isA<Theme>(),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.today, LocalDate.ymd(2015, 1, 25),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.dataOffset, 0,
          reason: 'charts-canvas-theming.historychart-layout#1');

      // Every constructor parameter is a Kotlin `var`, i.e. reassignable.
      final listener = RecordingListener();
      chart
        ..dateFormatter = const TestDateFormatter()
        ..firstWeekday = DayOfWeek.monday
        ..paletteColor = const PaletteColor(3)
        ..series = <Square>[Square.grey]
        ..defaultSquare = Square.dimmed
        ..notesIndicators = <bool>[false]
        ..theme = DarkTheme()
        ..today = LocalDate.ymd(2020, 2, 2)
        ..onDateClickedListener = listener
        ..padding = 4.0;
      expect(chart.firstWeekday, DayOfWeek.monday,
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.paletteColor, const PaletteColor(3),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.defaultSquare, Square.dimmed,
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.today, LocalDate.ymd(2020, 2, 2),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.onDateClickedListener, same(listener),
          reason: 'charts-canvas-theming.historychart-layout#1');
      expect(chart.padding, 4.0,
          reason: 'charts-canvas-theming.historychart-layout#1');
    });

    test('#2 Square has exactly ON, OFF, GREY, DIMMED, HATCHED in that order',
        () {
      expect(Square.values.length, 5,
          reason: 'charts-canvas-theming.historychart-layout#2');
      expect(Square.values, <Square>[
        Square.on,
        Square.off,
        Square.grey,
        Square.dimmed,
        Square.hatched,
      ], reason: 'charts-canvas-theming.historychart-layout#2');
      expect(Square.on.index, 0,
          reason: 'charts-canvas-theming.historychart-layout#2');
      expect(Square.off.index, 1,
          reason: 'charts-canvas-theming.historychart-layout#2');
      expect(Square.grey.index, 2,
          reason: 'charts-canvas-theming.historychart-layout#2');
      expect(Square.dimmed.index, 3,
          reason: 'charts-canvas-theming.historychart-layout#2');
      expect(Square.hatched.index, 4,
          reason: 'charts-canvas-theming.historychart-layout#2');
    });

    test('#3 draw() fills the whole canvas then sizes the 8-row grid', () {
      final theme = LightTheme();
      final chart = baseChart(theme: theme);
      final canvas = RecordingCanvas();
      chart.draw(canvas);

      // The background fill is the very first thing drawn, and it covers the
      // whole surface — padding included.
      expect(canvas.ops[0].name, 'setColor',
          reason: 'charts-canvas-theming.historychart-layout#3');
      expect(canvas.ops[0].color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.historychart-layout#3');
      expect(canvas.ops[1].name, 'fillRect',
          reason: 'charts-canvas-theming.historychart-layout#3');
      expect(canvas.ops[1].args, <double>[0.0, 0.0, 400.0, 200.0],
          reason: 'charts-canvas-theming.historychart-layout#3');

      // squareSize = round((200 - 0) / 8) = 25: one header row plus seven
      // weekday rows. The header occupies y in [0,25) and row r the band
      // [25*(r+1), 25*(r+2)).
      expect(squareSizeOf(canvas), closeTo(25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#3');
      expect(rowTops(canvas), <double>[25, 50, 75, 100, 125, 150, 175],
          reason: 'charts-canvas-theming.historychart-layout#3');
      expect(rowTops(canvas).length, 7,
          reason: 'charts-canvas-theming.historychart-layout#3');

      // Padding is subtracted twice before the division:
      // round((200 - 2*10) / 8) = round(22.5) = 22, because Kotlin's
      // kotlin.math.round is Math.rint and breaks ties towards the even
      // integer (Dart's double.round() would answer 23 here).
      final padded = baseChart(padding: 10.0);
      final paddedCanvas = RecordingCanvas();
      padded.draw(paddedCanvas);
      expect(paddedCanvas.ops[1].args, <double>[0.0, 0.0, 400.0, 200.0],
          reason: 'charts-canvas-theming.historychart-layout#3');
      expect(squareSizeOf(paddedCanvas), closeTo(22.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#3');

      // round((400 - 0) / 8) = 50 on a taller canvas.
      final tall = baseChart();
      final tallCanvas = RecordingCanvas(logicalHeight: 400.0);
      tall.draw(tallCanvas);
      expect(squareSizeOf(tallCanvas), closeTo(50.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#3');
    });

    test('#4 the font size is set once, to min(14, height * 0.06)', () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);
      expect(canvas.opsNamed('setFontSize').length, 1,
          reason: 'charts-canvas-theming.historychart-layout#4');
      // 200 * 0.06 = 12 < 14.
      expect(canvas.opsNamed('setFontSize').single.args, <double>[12.0],
          reason: 'charts-canvas-theming.historychart-layout#4');

      final tall = RecordingCanvas(logicalHeight: 400.0);
      baseChart().draw(tall);
      // 400 * 0.06 = 24, clamped down to 14.
      expect(tall.opsNamed('setFontSize').length, 1,
          reason: 'charts-canvas-theming.historychart-layout#4');
      expect(tall.opsNamed('setFontSize').single.args, <double>[14.0],
          reason: 'charts-canvas-theming.historychart-layout#4');
    });

    test('#5 the weekday gutter is as wide as the widest of all seven names',
        () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      // All seven DayOfWeek values are measured, before anything else is.
      expect(canvas.measured.take(7).toList(),
          <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          reason: 'charts-canvas-theming.historychart-layout#5');
      // Every name is 3 chars => 3 * 12 * 0.6 = 21.6, plus 25 * 0.15 = 3.75,
      // so weekdayColumnWidth = 25.35 and nColumns = floor(374.65 / 25) = 14.
      expect(columnCount(canvas), 14,
          reason: 'charts-canvas-theming.historychart-layout#5');

      // Widen a single weekday and the whole gutter widens with it: the max,
      // not the first entry and not the name of the first weekday.
      // 'Wednesday!' measures 10 * 12 * 0.6 = 72, so the gutter becomes 75.75
      // and nColumns = floor(324.25 / 25) = 12.
      final wide = RecordingCanvas();
      baseChart(dateFormatter: const WideWeekdayFormatter(DayOfWeek.wednesday))
          .draw(wide);
      expect(columnCount(wide), 12,
          reason: 'charts-canvas-theming.historychart-layout#5');
      expect(weekdayLabels(wide).first.d(1), closeTo(12 * 25.0 + 3.75, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#5');

      // Same widening applied to the last weekday instead of the middle one:
      // the maximum is taken over the whole list either way.
      final wideLast = RecordingCanvas();
      baseChart(dateFormatter: const WideWeekdayFormatter(DayOfWeek.saturday))
          .draw(wideLast);
      expect(columnCount(wideLast), 12,
          reason: 'charts-canvas-theming.historychart-layout#5');
    });

    test('#6 nColumns fills the width left of the right-hand weekday gutter',
        () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      expect(columnCount(canvas), 14,
          reason: 'charts-canvas-theming.historychart-layout#6');
      // Squares start flush against the left edge and the gutter sits to the
      // right of the last column, not to the left of the first one.
      expect(columnLefts(canvas).first, closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#6');
      expect(columnLefts(canvas).last, closeTo(13 * 25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#6');
      expect(weekdayLabels(canvas).first.d(1), closeTo(353.75, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#6');
      expect(weekdayLabels(canvas).first.d(1) > columnLefts(canvas).last,
          isTrue,
          reason: 'charts-canvas-theming.historychart-layout#6');

      // Padding is subtracted from both ends before the division, and the
      // squareSize used is the padded one:
      // squareSize = 22, gutter = 21.6 + 3.3 = 24.9,
      // nColumns = floor((400 - 20 - 24.9) / 22) = floor(16.14) = 16.
      final padded = RecordingCanvas();
      baseChart(padding: 10.0).draw(padded);
      expect(columnCount(padded), 16,
          reason: 'charts-canvas-theming.historychart-layout#6');
      expect(columnLefts(padded).first, closeTo(10.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#6');
    });

    test('#7 firstWeekdayOffset rotates the grid onto the chosen first weekday',
        () {
      // today = 2015-01-25 is a Sunday.
      expect(LocalDate.ymd(2015, 1, 25).dayOfWeek, DayOfWeek.sunday,
          reason: 'charts-canvas-theming.historychart-layout#7');

      // (SUNDAY - SUNDAY + 7) % 7 == 0.
      final sunday = RecordingCanvas();
      baseChart().draw(sunday);
      expect(weekdayLabels(sunday).map((o) => o.text).toList(),
          <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          reason: 'charts-canvas-theming.historychart-layout#7');
      expect(topLeftDayNumber(sunday), '26',
          reason: 'charts-canvas-theming.historychart-layout#7');

      // (SUNDAY - MONDAY + 7) % 7 == 6, so the grid starts six days earlier:
      // 2015-01-25 - (13*7 + 6) = 2014-10-20, a Monday.
      final monday = RecordingCanvas();
      baseChart(firstWeekday: DayOfWeek.monday).draw(monday);
      expect(weekdayLabels(monday).map((o) => o.text).toList(),
          <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          reason: 'charts-canvas-theming.historychart-layout#7');
      expect(topLeftDayNumber(monday), '20',
          reason: 'charts-canvas-theming.historychart-layout#7');

      // today = 2015-01-28 is a Wednesday: (WEDNESDAY - SUNDAY + 7) % 7 == 3.
      final wednesday = RecordingCanvas();
      baseChart(today: LocalDate.ymd(2015, 1, 28)).draw(wednesday);
      expect(weekdayLabels(wednesday).first.text, 'Sun',
          reason: 'charts-canvas-theming.historychart-layout#7');
      // 2015-01-28 - (13*7 + 3) = 2014-10-26.
      expect(topLeftDayNumber(wednesday), '26',
          reason: 'charts-canvas-theming.historychart-layout#7');

      // (WEDNESDAY - FRIDAY + 7) % 7 == 5, i.e. the modulo keeps it positive.
      final friday = RecordingCanvas();
      baseChart(
        today: LocalDate.ymd(2015, 1, 28),
        firstWeekday: DayOfWeek.friday,
      ).draw(friday);
      expect(weekdayLabels(friday).first.text, 'Fri',
          reason: 'charts-canvas-theming.historychart-layout#7');
      // 2015-01-28 - (13*7 + 5) = 2014-10-24.
      expect(topLeftDayNumber(friday), '24',
          reason: 'charts-canvas-theming.historychart-layout#7');
    });

    test('#8 topLeftDate is today - ((nColumns-1+dataOffset)*7 + offset)', () {
      final listener = RecordingListener();

      // dataOffset 0: topLeftOffset = 13*7 = 91, topLeftDate = 2014-10-26.
      final chart = baseChart(listener: listener);
      final canvas = RecordingCanvas();
      chart.draw(canvas);
      expect(columnDayNumbers(canvas, 0),
          <String>['26', '27', '28', '29', '30', '31', '1'],
          reason: 'charts-canvas-theming.historychart-layout#8');
      chart.onClick(2.0, 30.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 10, 26),
          reason: 'charts-canvas-theming.historychart-layout#8');

      // Each extra dataOffset step moves the whole calendar exactly 7 days
      // into the past; nothing else about the layout changes.
      for (var offset = 1; offset <= 3; offset++) {
        chart.dataOffset = offset;
        final scrolled = RecordingCanvas();
        chart.draw(scrolled);
        listener.reset();
        chart.onClick(2.0, 30.0);
        expect(listener.shortPresses.single,
            LocalDate.ymd(2014, 10, 26).minus(7 * offset),
            reason: 'charts-canvas-theming.historychart-layout#8');
        expect(columnCount(scrolled), 14,
            reason: 'charts-canvas-theming.historychart-layout#8');
        expect(weekdayLabels(scrolled).first.text, 'Sun',
            reason: 'charts-canvas-theming.historychart-layout#8');
      }
    });

    test('#9 columns run left to right, each one week later than the last', () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      // Squares are emitted column by column, left to right.
      expect(columnLefts(canvas),
          List<double>.generate(14, (c) => c * 25.0),
          reason: 'charts-canvas-theming.historychart-layout#9');
      final squares = canvas.opsNamed('fillRoundRect');
      var previousLeft = -1.0;
      for (final square in squares) {
        expect(square.d(0) >= previousLeft, isTrue,
            reason: 'charts-canvas-theming.historychart-layout#9');
        previousLeft = square.d(0);
      }

      // topDate = topLeftDate + 7*column: the top row walks 2014-10-26,
      // 11-02, 11-09, ... one week per column.
      final expectedTops = <String>[
        '26', '2', '9', '16', '23', '30', '7', //
        '14', '21', '28', '4', '11', '18', '25',
      ];
      expect(
          List<String>.generate(14, (c) => columnDayNumbers(canvas, c).first),
          expectedTops,
          reason: 'charts-canvas-theming.historychart-layout#9');
      // topOffset = topLeftOffset - 7*column, so the last column's top offset
      // is 0 and everything below it is in the future (see #10).
      expect(columnDayNumbers(canvas, 13), <String>['25'],
          reason: 'charts-canvas-theming.historychart-layout#9');
    });

    test('#10 a column is abandoned as soon as its offset goes negative', () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      // 13 full columns of 7 plus the last column's single square.
      expect(canvas.opsNamed('fillRoundRect').length, 92,
          reason: 'charts-canvas-theming.historychart-layout#10');
      for (var column = 0; column < 13; column++) {
        expect(columnDayNumbers(canvas, column).length, 7,
            reason: 'charts-canvas-theming.historychart-layout#10');
      }
      expect(columnDayNumbers(canvas, 13).length, 1,
          reason: 'charts-canvas-theming.historychart-layout#10');
      // date = topDate + row inside a column: consecutive days downwards.
      expect(columnDayNumbers(canvas, 5),
          <String>['30', '1', '2', '3', '4', '5', '6'],
          reason: 'charts-canvas-theming.historychart-layout#10');
      // The header of the abandoned column is still drawn (drawHeader runs
      // before the row loop).
      expect(headers(canvas).length, 14,
          reason: 'charts-canvas-theming.historychart-layout#10');
    });

    test('#11 square geometry: squareSize minus squareSpacing, rounded corners',
        () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      final first = squareAt(canvas, 0.0, 25.0);
      expect(first.d(0), closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
      expect(first.d(1), closeTo(25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
      expect(first.d(2), closeTo(24.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
      expect(first.d(3), closeTo(24.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
      expect(first.d(4), closeTo(24.0 * 0.15, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
      expect(first.name, 'fillRoundRect',
          reason: 'charts-canvas-theming.historychart-layout#11');

      // Column 3, row 4 => x = 3*25, y = (4+1)*25.
      final middle = squareAt(canvas, 75.0, 125.0);
      expect(middle.d(2), closeTo(24.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
      expect(middle.d(3), closeTo(24.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');

      // Padding shifts the whole grid: x = 10 + column*22,
      // y = 10 + (row+1)*22, size = 22 - 1 = 21.
      final padded = RecordingCanvas();
      baseChart(padding: 10.0).draw(padded);
      final paddedFirst = squareAt(padded, 10.0, 32.0);
      expect(paddedFirst.d(2), closeTo(21.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
      expect(paddedFirst.d(4), closeTo(21.0 * 0.15, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#11');
    });

    test('#12 offsets index the series and the notes list, 0 being today', () {
      final theme = LightTheme();
      // series has 4 entries and notesIndicators 3; everything past the end
      // falls back to defaultSquare / false.
      final chart = baseChart(
        theme: theme,
        series: <Square>[Square.grey, Square.on, Square.dimmed, Square.hatched],
        defaultSquare: Square.off,
        notesIndicators: <bool>[true, false, true],
      );
      final canvas = RecordingCanvas();
      chart.draw(canvas);

      // Offset 0 is today: the single square of the last column, carrying
      // today's day number.
      expect(columnDayNumbers(canvas, 13), <String>['25'],
          reason: 'charts-canvas-theming.historychart-layout#12');
      expect(squareAt(canvas, 325.0, 25.0).color, theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#12');

      // Offsets 1..3 walk backwards up the previous column.
      expect(squareAt(canvas, 300.0, 175.0).color, theme.color(7),
          reason: 'charts-canvas-theming.historychart-layout#12');
      expect(
          squareAt(canvas, 300.0, 150.0).color,
          theme.color(7).blendWith(theme.cardBackgroundColor, 0.5),
          reason: 'charts-canvas-theming.historychart-layout#12');
      expect(
          squareAt(canvas, 300.0, 125.0).color,
          theme.color(7).blendWith(theme.cardBackgroundColor, 0.5),
          reason: 'charts-canvas-theming.historychart-layout#12');
      // Offset 4 is past the end of the series: defaultSquare (OFF).
      expect(squareAt(canvas, 300.0, 100.0).color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#12');
      // ... and so is every square further to the left.
      expect(squareAt(canvas, 0.0, 25.0).color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#12');

      // notesIndicators is indexed by the same offset: true, false, true, then
      // out of range and therefore false.
      expect(blockAt(canvas, 325.0, 25.0).any((o) => o.name == 'fillCircle'),
          isTrue,
          reason: 'charts-canvas-theming.historychart-layout#12');
      expect(blockAt(canvas, 300.0, 175.0).any((o) => o.name == 'fillCircle'),
          isFalse,
          reason: 'charts-canvas-theming.historychart-layout#12');
      expect(blockAt(canvas, 300.0, 150.0).any((o) => o.name == 'fillCircle'),
          isTrue,
          reason: 'charts-canvas-theming.historychart-layout#12');
      expect(blockAt(canvas, 300.0, 125.0).any((o) => o.name == 'fillCircle'),
          isFalse,
          reason: 'charts-canvas-theming.historychart-layout#12');

      // The upstream fixture has one series entry per drawn offset (92) but
      // only 85 notesIndicators, so the two lists run out at different points.
      final upstream = RecordingCanvas();
      baseChart().draw(upstream);
      // Offset 87 => column 0, row 4. series[87] == DIMMED, still in range.
      expect(squareAt(upstream, 0.0, 125.0).color,
          theme.color(7).blendWith(theme.cardBackgroundColor, 0.5),
          reason: 'charts-canvas-theming.historychart-layout#12');
      // ... but 87 >= notesIndicators.length, so its flag reads false even
      // though 87 % 3 == 0 would have made it true.
      expect(blockAt(upstream, 0.0, 125.0).any((o) => o.name == 'fillCircle'),
          isFalse,
          reason: 'charts-canvas-theming.historychart-layout#12');
      // Offset 9 => column 11, row 5, well inside both lists.
      expect(blockAt(upstream, 275.0, 150.0).any((o) => o.name == 'fillCircle'),
          isTrue,
          reason: 'charts-canvas-theming.historychart-layout#12');
    });

    test('#13 each Square state has its own fill colour', () {
      final theme = LightTheme();
      final chart = baseChart(
        theme: theme,
        series: <Square>[Square.grey, Square.on, Square.dimmed, Square.hatched],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      );
      final canvas = RecordingCanvas();
      chart.draw(canvas);

      final dimmed = theme.color(7).blendWith(theme.cardBackgroundColor, 0.5);
      expect(squareAt(canvas, 325.0, 25.0).color, theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#13');
      expect(squareAt(canvas, 300.0, 175.0).color, theme.color(7),
          reason: 'charts-canvas-theming.historychart-layout#13');
      expect(squareAt(canvas, 300.0, 150.0).color, dimmed,
          reason: 'charts-canvas-theming.historychart-layout#13');
      expect(squareAt(canvas, 300.0, 125.0).color, dimmed,
          reason: 'charts-canvas-theming.historychart-layout#13');
      expect(squareAt(canvas, 300.0, 100.0).color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#13');

      // ON follows the habit's palette index, not a fixed colour, and the
      // blend is 50% towards the card background.
      final blue = baseChart(
        theme: theme,
        paletteColor: const PaletteColor(11),
        series: <Square>[Square.on, Square.dimmed],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      );
      final blueCanvas = RecordingCanvas();
      blue.draw(blueCanvas);
      expect(squareAt(blueCanvas, 325.0, 25.0).color, theme.color(11),
          reason: 'charts-canvas-theming.historychart-layout#13');
      expect(squareAt(blueCanvas, 300.0, 175.0).color,
          theme.color(11).blendWith(theme.cardBackgroundColor, 0.5),
          reason: 'charts-canvas-theming.historychart-layout#13');

      // The same states resolved against a dark theme's tokens.
      final dark = DarkTheme();
      final darkCanvas = RecordingCanvas();
      baseChart(
        theme: dark,
        series: <Square>[Square.grey, Square.on],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      ).draw(darkCanvas);
      expect(squareAt(darkCanvas, 325.0, 25.0).color, dark.mediumContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#13');
      expect(squareAt(darkCanvas, 300.0, 175.0).color, dark.color(7),
          reason: 'charts-canvas-theming.historychart-layout#13');
      expect(squareAt(darkCanvas, 300.0, 150.0).color, dark.lowContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#13');
    });

    test('#14 HATCHED is overdrawn with ten diagonal card-coloured strokes',
        () {
      final theme = LightTheme();
      final chart = baseChart(
        theme: theme,
        series: <Square>[Square.on, Square.on, Square.on, Square.hatched],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      );
      final canvas = RecordingCanvas();
      chart.draw(canvas);

      // Offset 3 => column 12, row 4 => x = 300, y = 125; width = height = 24.
      final block = blockAt(canvas, 300.0, 125.0);
      expect(block[1].name, 'setStrokeWidth',
          reason: 'charts-canvas-theming.historychart-layout#14');
      expect(block[1].args, <double>[0.75],
          reason: 'charts-canvas-theming.historychart-layout#14');
      expect(block[2].name, 'setColor',
          reason: 'charts-canvas-theming.historychart-layout#14');
      expect(block[2].color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.historychart-layout#14');

      const x = 300.0;
      const y = 125.0;
      const w = 24.0;
      final expectedLines = <List<double>>[];
      var k = w / 10;
      for (var i = 0; i < 5; i++) {
        expectedLines.add(<double>[x + k, y, x, y + k]);
        expectedLines.add(<double>[x + w - k, y + w, x + w, y + w - k]);
        k += w / 5;
      }
      final lines = block.where((o) => o.name == 'drawLine').toList();
      expect(lines.length, 10,
          reason: 'charts-canvas-theming.historychart-layout#14');
      for (var i = 0; i < 10; i++) {
        expect(lines[i].args.cast<double>(),
            <Matcher>[
              closeTo(expectedLines[i][0], 1e-9),
              closeTo(expectedLines[i][1], 1e-9),
              closeTo(expectedLines[i][2], 1e-9),
              closeTo(expectedLines[i][3], 1e-9),
            ],
            reason: 'charts-canvas-theming.historychart-layout#14');
        expect(lines[i].color, theme.cardBackgroundColor,
            reason: 'charts-canvas-theming.historychart-layout#14');
        expect(lines[i].strokeWidth, 0.75,
            reason: 'charts-canvas-theming.historychart-layout#14');
      }

      // Only HATCHED is hatched: a DIMMED square shares its fill colour but
      // draws no lines at all.
      expect(blockAt(canvas, 325.0, 25.0).any((o) => o.name == 'drawLine'),
          isFalse,
          reason: 'charts-canvas-theming.historychart-layout#14');
      final dimmed = RecordingCanvas();
      baseChart(
        series: <Square>[Square.dimmed],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      ).draw(dimmed);
      expect(dimmed.opsNamed('drawLine'), isEmpty,
          reason: 'charts-canvas-theming.historychart-layout#14');
    });

    test('#15 the day number takes whichever of the two tokens contrasts more',
        () {
      final theme = LightTheme();
      final canvas = RecordingCanvas();
      baseChart(
        theme: theme,
        series: <Square>[Square.on],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      ).draw(canvas);

      // ON, a dark green on a near-white card: the card background wins.
      final onSquare = theme.color(7);
      expect(onSquare.contrast(theme.cardBackgroundColor) >
              onSquare.contrast(theme.mediumContrastTextColor),
          isTrue,
          reason: 'charts-canvas-theming.historychart-layout#15');
      expect(dayNumberOf(canvas, 325.0, 25.0).color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.historychart-layout#15');

      // OFF, a very light grey barely distinguishable from the card: the
      // medium-contrast token wins instead.
      final offSquare = theme.lowContrastTextColor;
      expect(offSquare.contrast(theme.cardBackgroundColor) >
              offSquare.contrast(theme.mediumContrastTextColor),
          isFalse,
          reason: 'charts-canvas-theming.historychart-layout#15');
      expect(dayNumberOf(canvas, 0.0, 25.0).color, theme.mediumContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#15');

      // A transparent card short-circuits the comparison entirely.
      final widget = WidgetTheme();
      expect(widget.cardBackgroundColor, Color.TRANSPARENT,
          reason: 'charts-canvas-theming.historychart-layout#15');
      final widgetCanvas = RecordingCanvas();
      baseChart(
        theme: widget,
        series: <Square>[Square.on],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      ).draw(widgetCanvas);
      expect(dayNumberOf(widgetCanvas, 325.0, 25.0).color,
          widget.highContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#15');
      expect(dayNumberOf(widgetCanvas, 0.0, 25.0).color,
          widget.highContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#15');
    });

    test('#16 the day number is centred inside the square', () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      // width == height == 24 here, so `y + width / 2` and `y + height / 2`
      // are indistinguishable from the outside; the assertion pins the value
      // the Kotlin expression produces.
      final first = dayNumberOf(canvas, 0.0, 25.0);
      expect(first.textAlign, TextAlign.center,
          reason: 'charts-canvas-theming.historychart-layout#16');
      expect(first.d(1), closeTo(0.0 + 24.0 / 2, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#16');
      expect(first.d(2), closeTo(25.0 + 24.0 / 2, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#16');
      expect(first.text, '26',
          reason: 'charts-canvas-theming.historychart-layout#16');

      final today = dayNumberOf(canvas, 325.0, 25.0);
      expect(today.text, '25',
          reason: 'charts-canvas-theming.historychart-layout#16');
      expect(today.d(1), closeTo(325.0 + 12.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#16');
      expect(today.d(2), closeTo(25.0 + 12.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#16');

      // Every square carries exactly one centred day number.
      final centred =
          canvas.opsNamed('drawText').where((o) => o.textAlign == TextAlign.center);
      expect(centred.length, 92,
          reason: 'charts-canvas-theming.historychart-layout#16');
    });

    test('#17 the notes indicator is a small circle in the top-right corner',
        () {
      final theme = LightTheme();
      final chart = baseChart(
        theme: theme,
        series: <Square>[
          Square.on,
          Square.grey,
          Square.off,
          Square.dimmed,
          Square.hatched,
        ],
        defaultSquare: Square.off,
        notesIndicators: <bool>[true, true, true, true, true],
      );
      final canvas = RecordingCanvas();
      chart.draw(canvas);

      // Offset 0: x = 325, y = 25, width = 24.
      final circle = blockAt(canvas, 325.0, 25.0)
          .firstWhere((o) => o.name == 'fillCircle');
      expect(circle.d(0), closeTo(325.0 + 24.0 - 24.0 / 5, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#17');
      expect(circle.d(1), closeTo(25.0 + 24.0 / 5, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#17');
      expect(circle.d(2), closeTo(24.0 / 12, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#17');

      // ON and GREY use the low-contrast token; the other three use the
      // habit's palette colour.
      expect(circle.color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#17');
      expect(circleColorAt(canvas, 300.0, 175.0), theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.historychart-layout#17');
      expect(circleColorAt(canvas, 300.0, 150.0), theme.color(7),
          reason: 'charts-canvas-theming.historychart-layout#17');
      expect(circleColorAt(canvas, 300.0, 125.0), theme.color(7),
          reason: 'charts-canvas-theming.historychart-layout#17');
      expect(circleColorAt(canvas, 300.0, 100.0), theme.color(7),
          reason: 'charts-canvas-theming.historychart-layout#17');

      // No indicator at all when the flag is false.
      final none = RecordingCanvas();
      baseChart(
        series: <Square>[Square.on],
        defaultSquare: Square.off,
        notesIndicators: <bool>[false],
      ).draw(none);
      expect(none.opsNamed('fillCircle'), isEmpty,
          reason: 'charts-canvas-theming.historychart-layout#17');
    });

    test('#18 each column header prints a month, else a year, else nothing',
        () {
      final theme = LightTheme();
      final canvas = RecordingCanvas();
      baseChart(theme: theme).draw(canvas);

      // Column top dates run 2014-10-26, 11-02 ... 2015-01-25.
      expect(headers(canvas).map((o) => o.text).toList(), <String>[
        'Oct', // month differs from the initial ""
        'Nov', // month differs from "Oct"
        '2014', // month repeats, year differs from the initial ""
        '', // both repeat
        '', '', //
        'Dec', //
        '', '', '', //
        'Jan', //
        '2015', // month repeats, year differs from "2014"
        '', '', //
      ], reason: 'charts-canvas-theming.historychart-layout#18');

      for (final header in headers(canvas)) {
        expect(header.color, theme.mediumContrastTextColor,
            reason: 'charts-canvas-theming.historychart-layout#18');
        expect(header.textAlign, TextAlign.left,
            reason: 'charts-canvas-theming.historychart-layout#18');
        // y = padding + squareSize / 2.
        expect(header.d(2), closeTo(12.5, 1e-9),
            reason: 'charts-canvas-theming.historychart-layout#18');
      }
      // x = headerOverflow + padding + column * squareSize; headerOverflow is
      // zero for every column whose predecessor fitted.
      expect(headers(canvas)[0].d(1), closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#18');
      expect(headers(canvas)[1].d(1), closeTo(25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#18');
      expect(headers(canvas)[6].d(1), closeTo(150.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#18');

      final padded = RecordingCanvas();
      baseChart(padding: 10.0).draw(padded);
      expect(headers(padded)[0].d(1), closeTo(10.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#18');
      expect(headers(padded)[0].d(2), closeTo(10.0 + 11.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#18');
    });

    test('#19 headerOverflow pushes a too-wide label into the next column', () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      // measureText(text) = text.length * fontSize * 0.6 = length * 7.2 here,
      // and 0.1 * squareSize = 2.5.
      final xs = headers(canvas).map((o) => o.d(1)).toList();
      // "Oct" (21.6) and "Nov" (21.6) both fit inside a 25-wide column:
      // max(0, 0 + 21.6 + 2.5 - 25) = 0.
      expect(xs[0], closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      expect(xs[1], closeTo(25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      expect(xs[2], closeTo(50.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      // "2014" measures 28.8, so it overflows by 28.8 + 2.5 - 25 = 6.3 and
      // shoves the next header right by exactly that much.
      expect(xs[3], closeTo(6.3 + 75.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      // The empty header that follows measures 0, so max(0, 6.3 + 0 + 2.5 -
      // 25) clamps the overflow straight back to zero.
      expect(xs[4], closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      // Same story around "2015" in column 11.
      expect(xs[11], closeTo(275.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      expect(xs[12], closeTo(6.3 + 300.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      expect(xs[13], closeTo(325.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');

      // Wide labels accumulate: with a formatter whose month names measure
      // 10 * 7.2 = 72, each header overflows by 72 + 2.5 - 25 = 49.5 and the
      // next one starts that much further right.
      final wide = RecordingCanvas();
      baseChart(dateFormatter: const WideMonthFormatter()).draw(wide);
      final wideXs = headers(wide).map((o) => o.d(1)).toList();
      expect(wideXs[0], closeTo(0.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');
      expect(wideXs[1], closeTo(49.5 + 25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#19');

      // headerOverflow starts at 0.0 on every draw, so a redraw of the same
      // chart lands on exactly the same x positions.
      final again = RecordingCanvas();
      baseChart().draw(again);
      expect(headers(again).map((o) => o.d(1)).toList(), xs,
          reason: 'charts-canvas-theming.historychart-layout#19');
    });

    test('#20 the printed month and year reset on every draw', () {
      final chart = baseChart();
      final first = RecordingCanvas();
      chart.draw(first);
      final second = RecordingCanvas();
      chart.draw(second);

      expect(headers(second).map((o) => o.text).toList(),
          headers(first).map((o) => o.text).toList(),
          reason: 'charts-canvas-theming.historychart-layout#20');
      expect(headers(second).first.text, 'Oct',
          reason: 'charts-canvas-theming.historychart-layout#20');
      expect(headers(second)[2].text, '2014',
          reason: 'charts-canvas-theming.historychart-layout#20');

      // The discriminating case. The draws above finished with
      // lastPrintedMonth = "Jan" and lastPrintedYear = "2015". Moving today to
      // 2015-04-19 puts topLeftDate at 2015-01-18, so without the reset the
      // leftmost column would print neither its month (it repeats "Jan") nor
      // its year (it repeats "2015") and the calendar would open unlabelled.
      chart.today = LocalDate.ymd(2015, 4, 19);
      final third = RecordingCanvas();
      chart.draw(third);
      expect(headers(third).first.text, 'Jan',
          reason: 'charts-canvas-theming.historychart-layout#20');
      expect(headers(third)[1].text, '2015',
          reason: 'charts-canvas-theming.historychart-layout#20');
    });

    test('#21 weekday names are drawn last, one per row, in the right gutter',
        () {
      final theme = LightTheme();
      final canvas = RecordingCanvas();
      baseChart(theme: theme).draw(canvas);

      final labels = weekdayLabels(canvas);
      expect(labels.length, 7,
          reason: 'charts-canvas-theming.historychart-layout#21');
      // They are the very last thing the chart draws.
      expect(canvas.ops.last, same(labels.last),
          reason: 'charts-canvas-theming.historychart-layout#21');
      final lastSquare = canvas.ops.lastIndexWhere(
          (o) => o.name == 'fillRoundRect' || o.name == 'fillCircle');
      expect(canvas.ops.indexOf(labels.first) > lastSquare, isTrue,
          reason: 'charts-canvas-theming.historychart-layout#21');

      for (var row = 0; row < 7; row++) {
        expect(labels[row].color, theme.mediumContrastTextColor,
            reason: 'charts-canvas-theming.historychart-layout#21');
        expect(labels[row].textAlign, TextAlign.left,
            reason: 'charts-canvas-theming.historychart-layout#21');
        expect(labels[row].d(1), closeTo(14 * 25.0 + 25.0 * 0.15, 1e-9),
            reason: 'charts-canvas-theming.historychart-layout#21');
        expect(labels[row].d(2), closeTo(25.0 * (row + 1) + 12.5, 1e-9),
            reason: 'charts-canvas-theming.historychart-layout#21');
      }
      // Names come from topLeftDate + row, so they follow firstWeekday for
      // free: topLeftDate is a Sunday here.
      expect(labels.map((o) => o.text).toList(),
          <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
          reason: 'charts-canvas-theming.historychart-layout#21');

      final monday = RecordingCanvas();
      baseChart(firstWeekday: DayOfWeek.monday).draw(monday);
      expect(weekdayLabels(monday).map((o) => o.text).toList(),
          <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
          reason: 'charts-canvas-theming.historychart-layout#21');

      // x = padding + nColumns * squareSize + squareSize * 0.15,
      // y = padding + squareSize * (row + 1) + squareSize / 2.
      final padded = RecordingCanvas();
      baseChart(padding: 10.0).draw(padded);
      expect(weekdayLabels(padded).first.d(1),
          closeTo(10.0 + 16 * 22.0 + 22.0 * 0.15, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#21');
      expect(weekdayLabels(padded)[3].d(2),
          closeTo(10.0 + 22.0 * 4 + 11.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#21');
    });

    test('#22 squareSpacing defaults to 1.0 and drives dataColumnWidth', () {
      final chart = baseChart();
      expect(chart.squareSpacing, 1.0,
          reason: 'charts-canvas-theming.historychart-layout#22');
      // squareSize is still zero before the first draw.
      expect(chart.dataColumnWidth, closeTo(1.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#22');

      final canvas = RecordingCanvas();
      chart.draw(canvas);
      expect(chart.dataColumnWidth, closeTo(1.0 + 25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#22');

      chart.squareSpacing = 3.0;
      final wider = RecordingCanvas();
      chart.draw(wider);
      expect(chart.dataColumnWidth, closeTo(3.0 + 25.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#22');
      // The spacing is taken out of the square, not out of the column pitch.
      expect(squareAt(wider, 0.0, 25.0).d(2), closeTo(22.0, 1e-9),
          reason: 'charts-canvas-theming.historychart-layout#22');
      expect(columnLefts(wider), List<double>.generate(14, (c) => c * 25.0),
          reason: 'charts-canvas-theming.historychart-layout#22');
    });
  });

  group('charts-canvas-theming.historychart-hittest', () {
    test('#1 onClick and onLongClick share one geometry, differing only in kind',
        () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      chart.draw(RecordingCanvas());

      const probes = <List<double>>[
        <double>[20.0, 46.0],
        <double>[163.0, 113.0],
        <double>[336.0, 37.0],
      ];
      for (final probe in probes) {
        listener.reset();
        chart.onClick(probe[0], probe[1]);
        final short = listener.shortPresses.single;
        expect(listener.longPresses, isEmpty,
            reason: 'charts-canvas-theming.historychart-hittest#1');

        listener.reset();
        chart.onLongClick(probe[0], probe[1]);
        expect(listener.longPresses.single, short,
            reason: 'charts-canvas-theming.historychart-hittest#1');
        expect(listener.shortPresses, isEmpty,
            reason: 'charts-canvas-theming.historychart-hittest#1');
      }

      // The rejections are shared too.
      listener.reset();
      chart.onClick(160.0, 15.0);
      chart.onLongClick(160.0, 15.0);
      expect(listener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#1');
      expect(listener.longPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#1');
    });

    test('#2 hit-testing before the first draw is an error', () {
      final chart = baseChart(listener: RecordingListener());
      expect(
          () => chart.onClick(20.0, 46.0),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              'onClick must be called after draw(canvas)')),
          reason: 'charts-canvas-theming.historychart-hittest#2');
      expect(
          () => chart.onLongClick(20.0, 46.0),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              'onClick must be called after draw(canvas)')),
          reason: 'charts-canvas-theming.historychart-hittest#2');

      // A completed draw arms it.
      chart.draw(RecordingCanvas());
      expect(() => chart.onClick(20.0, 46.0), returnsNormally,
          reason: 'charts-canvas-theming.historychart-hittest#2');
    });

    test('#3 col and row are the truncated square indices', () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      chart.draw(RecordingCanvas());

      // Anywhere inside the first square's 25x25 cell resolves to col 0,
      // row 1, i.e. topLeftDate.
      const topLeft = <List<double>>[
        <double>[0.0, 25.0],
        <double>[12.0, 37.0],
        <double>[24.9, 49.9],
      ];
      for (final probe in topLeft) {
        listener.reset();
        chart.onClick(probe[0], probe[1]);
        expect(listener.shortPresses.single, LocalDate.ymd(2014, 10, 26),
            reason: 'charts-canvas-theming.historychart-hittest#3');
      }
      // One pixel further and the indices step: x = 25 is col 1, y = 50 is
      // row 2.
      listener.reset();
      chart.onClick(25.0, 49.9);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 11, 2),
          reason: 'charts-canvas-theming.historychart-hittest#3');
      listener.reset();
      chart.onClick(24.9, 50.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 10, 27),
          reason: 'charts-canvas-theming.historychart-hittest#3');

      // Padding is subtracted before the division, and the squareSize is the
      // padded one (22): x = 10 lands on col 0, x = 32 on col 1.
      final paddedListener = RecordingListener();
      final padded = baseChart(padding: 10.0, listener: paddedListener);
      padded.draw(RecordingCanvas());
      // topLeftOffset = (16 - 1) * 7 = 105; 2015-01-25 - 105 = 2014-10-12.
      padded.onClick(10.0, 32.0);
      expect(paddedListener.shortPresses.single, LocalDate.ymd(2014, 10, 12),
          reason: 'charts-canvas-theming.historychart-hittest#3');
      paddedListener.reset();
      padded.onClick(32.0, 32.0);
      expect(paddedListener.shortPresses.single, LocalDate.ymd(2014, 10, 19),
          reason: 'charts-canvas-theming.historychart-hittest#3');
      paddedListener.reset();
      padded.onClick(10.0, 54.0);
      expect(paddedListener.shortPresses.single, LocalDate.ymd(2014, 10, 13),
          reason: 'charts-canvas-theming.historychart-hittest#3');
    });

    test('#4 taps left of the padding, on the header, below row 7 or on the '
        'gutter are dropped', () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      chart.draw(RecordingCanvas());

      // row == 0: the month-header band.
      chart.onClick(160.0, 15.0);
      chart.onClick(0.0, 0.0);
      expect(listener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#4');

      // row > 7: below the seven weekday rows.
      chart.onClick(20.0, 200.0);
      chart.onClick(20.0, 260.0);
      expect(listener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#4');
      // row == 7 is still live.
      chart.onClick(20.0, 190.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 11, 1),
          reason: 'charts-canvas-theming.historychart-hittest#4');

      // col == nColumns: the weekday-name gutter.
      listener.reset();
      chart.onClick(360.0, 60.0);
      expect(listener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#4');

      // x - padding < 0.
      final paddedListener = RecordingListener();
      final padded = baseChart(padding: 10.0, listener: paddedListener);
      padded.draw(RecordingCanvas());
      padded.onClick(5.0, 40.0);
      padded.onClick(-3.0, 40.0);
      expect(paddedListener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#4');
      paddedListener.reset();
      padded.onClick(10.0, 40.0);
      expect(paddedListener.shortPresses, hasLength(1),
          reason: 'charts-canvas-theming.historychart-hittest#4');

      // Upstream quirk, reproduced deliberately: the guard is `col ==
      // nColumns`, not `col >= nColumns`, so a tap past the gutter is only
      // stopped by the future-date check. Scrolled back two weeks, column 15
      // row 1 resolves to today and fires.
      final scrolledListener = RecordingListener();
      final scrolled = baseChart(listener: scrolledListener);
      scrolled.dataOffset = 2;
      scrolled.draw(RecordingCanvas());
      scrolled.onClick(380.0, 30.0);
      expect(scrolledListener.shortPresses.single, LocalDate.ymd(2015, 1, 25),
          reason: 'charts-canvas-theming.historychart-hittest#4');
      // ... whereas column 14 itself, the gutter, stays inert.
      scrolledListener.reset();
      scrolled.onClick(355.0, 30.0);
      expect(scrolledListener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#4');
    });

    test('#5 the clicked date is topLeftDate + col*7 + (row-1)', () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      chart.draw(RecordingCanvas());

      // Row 1 is the first weekday row, so it contributes nothing.
      listener.reset();
      chart.onClick(2.0, 30.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 10, 26),
          reason: 'charts-canvas-theming.historychart-hittest#5');

      // Walking down a column advances one day per row.
      for (var row = 1; row <= 7; row++) {
        listener.reset();
        chart.onClick(2.0, 25.0 * row + 5.0);
        expect(listener.shortPresses.single,
            LocalDate.ymd(2014, 10, 26).plus(row - 1),
            reason: 'charts-canvas-theming.historychart-hittest#5');
      }

      // Walking right advances a full week per column.
      for (var col = 0; col < 13; col++) {
        listener.reset();
        chart.onClick(25.0 * col + 5.0, 30.0);
        expect(listener.shortPresses.single,
            LocalDate.ymd(2014, 10, 26).plus(col * 7),
            reason: 'charts-canvas-theming.historychart-hittest#5');
      }

      // A diagonal probe combining both terms: col 6, row 4.
      listener.reset();
      chart.onClick(163.0, 113.0);
      expect(listener.shortPresses.single,
          LocalDate.ymd(2014, 10, 26).plus(6 * 7 + 3),
          reason: 'charts-canvas-theming.historychart-hittest#5');
    });

    test('#6 taps on the empty future cells past today do nothing', () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      chart.draw(RecordingCanvas());

      // Column 13 holds today in row 1; rows 2..7 of that column are the
      // undrawn future.
      chart.onClick(336.0, 37.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2015, 1, 25),
          reason: 'charts-canvas-theming.historychart-hittest#6');
      listener.reset();
      for (var row = 2; row <= 7; row++) {
        chart.onClick(336.0, 25.0 * row + 5.0);
      }
      expect(listener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#6');
      expect(listener.longPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#6');

      chart.onLongClick(336.0, 62.0);
      expect(listener.longPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#6');
    });

    test('#7 short and long presses reach the listener; no listener is a no-op',
        () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      chart.draw(RecordingCanvas());

      chart.onClick(163.0, 113.0);
      expect(listener.shortPresses, <LocalDate>[LocalDate.ymd(2014, 12, 10)],
          reason: 'charts-canvas-theming.historychart-hittest#7');
      expect(listener.longPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#7');

      chart.onLongClick(163.0, 113.0);
      expect(listener.longPresses, <LocalDate>[LocalDate.ymd(2014, 12, 10)],
          reason: 'charts-canvas-theming.historychart-hittest#7');
      expect(listener.shortPresses, <LocalDate>[LocalDate.ymd(2014, 12, 10)],
          reason: 'charts-canvas-theming.historychart-hittest#7');

      // The default listener swallows both without complaint.
      final bare = HistoryChart(
        dateFormatter: const TestDateFormatter(),
        firstWeekday: DayOfWeek.sunday,
        paletteColor: const PaletteColor(7),
        series: upstreamSeries,
        defaultSquare: Square.off,
        notesIndicators: upstreamNotes,
        theme: LightTheme(),
        today: LocalDate.ymd(2015, 1, 25),
      );
      bare.draw(RecordingCanvas());
      expect(() => bare.onClick(163.0, 113.0), returnsNormally,
          reason: 'charts-canvas-theming.historychart-hittest#7');
      expect(() => bare.onLongClick(163.0, 113.0), returnsNormally,
          reason: 'charts-canvas-theming.historychart-hittest#7');
    });

    test('#8 the upstream 400x200 probe table', () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      final canvas = RecordingCanvas();
      chart.draw(canvas);
      // The geometry the upstream golden was captured under.
      expect(columnCount(canvas), 14,
          reason: 'charts-canvas-theming.historychart-hittest#8');

      listener.reset();
      chart.onClick(20.0, 46.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 10, 26),
          reason: 'charts-canvas-theming.historychart-hittest#8');

      listener.reset();
      chart.onClick(2.0, 28.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 10, 26),
          reason: 'charts-canvas-theming.historychart-hittest#8');

      listener.reset();
      chart.onClick(163.0, 113.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2014, 12, 10),
          reason: 'charts-canvas-theming.historychart-hittest#8');

      listener.reset();
      chart.onClick(336.0, 37.0);
      expect(listener.shortPresses.single, LocalDate.ymd(2015, 1, 25),
          reason: 'charts-canvas-theming.historychart-hittest#8');

      listener.reset();
      chart.onClick(160.0, 15.0);
      expect(listener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#8');

      chart.onClick(360.0, 60.0);
      expect(listener.shortPresses, isEmpty,
          reason: 'charts-canvas-theming.historychart-hittest#8');

      // The long-press half of the upstream table walks the same points.
      listener.reset();
      chart.onLongClick(20.0, 46.0);
      chart.onLongClick(2.0, 28.0);
      chart.onLongClick(163.0, 113.0);
      chart.onLongClick(336.0, 37.0);
      chart.onLongClick(160.0, 15.0);
      chart.onLongClick(360.0, 60.0);
      expect(listener.longPresses, <LocalDate>[
        LocalDate.ymd(2014, 10, 26),
        LocalDate.ymd(2014, 10, 26),
        LocalDate.ymd(2014, 12, 10),
        LocalDate.ymd(2015, 1, 25),
      ], reason: 'charts-canvas-theming.historychart-hittest#8');
    });
  });
  // -------------------------------------------------------------------------
  // The same chart read against the show-habit history card's own rules.
  // -------------------------------------------------------------------------
  group('show-habit.history-card', () {
    test('#7 a HATCHED square gets five pairs of diagonal card-coloured '
        'strokes at width 0.75', () {
      final theme = LightTheme();
      final canvas = RecordingCanvas();
      baseChart(
        theme: theme,
        series: <Square>[Square.hatched],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      ).draw(canvas);

      // Offset 0 is the last column's only square: x = 325, y = 25, w = 24.
      final lines =
          blockAt(canvas, 325.0, 25.0).where((o) => o.name == 'drawLine');
      expect(lines, hasLength(10),
          reason: 'show-habit.history-card#7 — five hatch steps, each drawing '
              'the line and its mirror');
      for (final line in lines) {
        expect(line.color, theme.cardBackgroundColor,
            reason: 'show-habit.history-card#7 — in the card background '
                'colour');
        expect(line.strokeWidth, 0.75,
            reason: 'show-habit.history-card#7 — stroke width 0.75');
      }
      // The step is width/5, so the five k values are 2.4, 7.2, 12.0, 16.8,
      // 21.6 measured from the square's top-left corner.
      expect(
          lines.map((o) => o.d(0) - 325.0).toList(),
          <double>[2.4, 21.6, 7.2, 16.8, 12.0, 12.0, 16.8, 7.2, 21.6, 2.4]
              .map((v) => closeTo(v, 1e-9))
              .toList(),
          reason: 'show-habit.history-card#7');

      // No other square state is hatched.
      final plain = RecordingCanvas();
      baseChart(
        series: <Square>[Square.on],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      ).draw(plain);
      expect(plain.opsNamed('drawLine'), isEmpty,
          reason: 'show-habit.history-card#7');
    });

    test('#8 rounded corners at 0.15 of the width, 1.0 of spacing, and a '
        'centred day number in the more contrasting token', () {
      final theme = LightTheme();
      final chart = baseChart(theme: theme);
      final canvas = RecordingCanvas();
      chart.draw(canvas);

      expect(chart.squareSpacing, 1.0,
          reason: 'show-habit.history-card#8 — 1.0 spacing between squares');
      final square = squareAt(canvas, 0.0, 25.0);
      // squareSize is 25, so the drawn square is 24 wide with a 3.6 radius.
      expect(square.d(2), closeTo(24.0, 1e-9),
          reason: 'show-habit.history-card#8');
      expect(square.d(3), closeTo(24.0, 1e-9),
          reason: 'show-habit.history-card#8');
      expect(square.d(4), closeTo(24.0 * 0.15, 1e-9),
          reason: 'show-habit.history-card#8 — corner radius = width * 0.15');

      final day = dayNumberOf(canvas, 0.0, 25.0);
      expect(day.textAlign, TextAlign.center,
          reason: 'show-habit.history-card#8 — the day number is centred');
      expect(day.d(1), closeTo(0.0 + 12.0, 1e-9),
          reason: 'show-habit.history-card#8 — at x + width / 2');
      expect(day.d(2), closeTo(25.0 + 12.0, 1e-9),
          reason: 'show-habit.history-card#8 — and y + width / 2');

      // An OFF square is the low-contrast token, against which the medium
      // one contrasts more than the card background does.
      final off = RecordingCanvas();
      baseChart(
        theme: theme,
        series: <Square>[Square.off],
        defaultSquare: Square.off,
        notesIndicators: <bool>[],
      ).draw(off);
      final offSquare = theme.lowContrastTextColor;
      final expected = offSquare.contrast(theme.cardBackgroundColor) >
              offSquare.contrast(theme.mediumContrastTextColor)
          ? theme.cardBackgroundColor
          : theme.mediumContrastTextColor;
      expect(dayNumberOf(off, 325.0, 25.0).color, expected,
          reason: 'show-habit.history-card#8 — whichever of '
              'cardBackgroundColor / mediumContrastTextColor has the higher '
              'contrast against the square colour');
    });

    test('#9 the notes dot is width/12 across, in the square top-right corner',
        () {
      final theme = LightTheme();
      final canvas = RecordingCanvas();
      baseChart(
        theme: theme,
        series: <Square>[
          Square.on,
          Square.grey,
          Square.off,
          Square.dimmed,
          Square.hatched,
        ],
        defaultSquare: Square.off,
        notesIndicators: <bool>[true, true, true, true, true],
      ).draw(canvas);

      final dot = blockAt(canvas, 325.0, 25.0)
          .firstWhere((o) => o.name == 'fillCircle');
      expect(dot.d(0), closeTo(325.0 + 24.0 - 24.0 / 5, 1e-9),
          reason: 'show-habit.history-card#9 — x + width - width/5');
      expect(dot.d(1), closeTo(25.0 + 24.0 / 5, 1e-9),
          reason: 'show-habit.history-card#9 — y + width/5');
      expect(dot.d(2), closeTo(24.0 / 12, 1e-9),
          reason: 'show-habit.history-card#9 — radius width/12');

      // Offsets 1..4 are the last-but-one column's bottom four rows.
      expect(dot.color, theme.lowContrastTextColor,
          reason: 'show-habit.history-card#9 — lowContrastTextColor for ON');
      expect(circleColorAt(canvas, 300.0, 175.0), theme.lowContrastTextColor,
          reason: 'show-habit.history-card#9 — and for GREY');
      expect(circleColorAt(canvas, 300.0, 150.0), theme.color(7),
          reason: 'show-habit.history-card#9 — the habit colour otherwise');
      expect(circleColorAt(canvas, 300.0, 125.0), theme.color(7),
          reason: 'show-habit.history-card#9');
      expect(circleColorAt(canvas, 300.0, 100.0), theme.color(7),
          reason: 'show-habit.history-card#9');

      expect(
          blockAt(canvas, 300.0, 75.0).where((o) => o.name == 'fillCircle'),
          isEmpty,
          reason: 'show-habit.history-card#9 — an entry with no notes gets no '
              'dot');
    });

    test('charts-canvas-theming.notes-indicator#4: the calendar dot is the '
        "chart's own, not the 8px button one", () {
      final canvas = RecordingCanvas();
      baseChart(
        series: <Square>[Square.on],
        defaultSquare: Square.off,
        notesIndicators: <bool>[true],
      ).draw(canvas);

      final dot = canvas.opsNamed('fillCircle').single;
      expect(dot.d(2), closeTo(24.0 / 12, 1e-9),
          reason: 'charts-canvas-theming.notes-indicator#4 — the radius scales '
              'with the square, unlike the flat 8 device pixels of '
              'drawNotesIndicator');
      expect(dot.d(2), isNot(closeTo(notesIndicatorRadius, 1e-9)),
          reason: 'charts-canvas-theming.notes-indicator#4 — the two '
              'indicators are unrelated');
      expect(dot.d(0), closeTo(325.0 + 24.0 - 24.0 / 5, 1e-9),
          reason: 'charts-canvas-theming.notes-indicator#4 — at '
              '(x + width - width/5, y + width/5) of the calendar square');
      expect(dot.d(1), closeTo(25.0 + 24.0 / 5, 1e-9),
          reason: 'charts-canvas-theming.notes-indicator#4');
    });

    test('#11 a column header is the month on change, else the year on '
        'change, else nothing', () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      expect(headers(canvas).map((o) => o.text).toList(), <String>[
        'Oct', 'Nov', '2014', '', '', '', 'Dec', //
        '', '', '', 'Jan', '2015', '', '',
      ], reason: 'show-habit.history-card#11 — the short month name when it '
          'differs from the previously printed month, else the year when the '
          'year differs, else nothing');
    });

    test('#12 the top-left date is today minus (nColumns-1+dataOffset)*7 plus '
        'the first-weekday offset', () {
      final listener = RecordingListener();
      final chart = baseChart(listener: listener);
      final canvas = RecordingCanvas();
      chart.draw(canvas);

      // today is a Sunday and the week starts on Sunday, so the weekday term
      // is (0 - 0 + 7) % 7 = 0 and topLeftDate = today - 13*7.
      chart.onClick(2.0, 30.0);
      expect(listener.shortPresses.single,
          LocalDate.ymd(2015, 1, 25).minus(13 * 7),
          reason: 'show-habit.history-card#12');

      // A Monday-first week pushes the top-left cell one more day back:
      // (0 - 1 + 7) % 7 = 6.
      listener.reset();
      final monday = baseChart(
        firstWeekday: DayOfWeek.monday,
        listener: listener,
      );
      monday.draw(RecordingCanvas());
      monday.onClick(2.0, 30.0);
      expect(listener.shortPresses.single,
          LocalDate.ymd(2015, 1, 25).minus(13 * 7 + 6),
          reason: 'show-habit.history-card#12');

      // And each dataOffset step is another whole week.
      listener.reset();
      chart.dataOffset = 2;
      chart.draw(RecordingCanvas());
      chart.onClick(2.0, 30.0);
      expect(listener.shortPresses.single,
          LocalDate.ymd(2015, 1, 25).minus(15 * 7),
          reason: 'show-habit.history-card#12');
    });

    test('show-habit.number-formatting#8: the square label is the plain '
        'day-of-month integer', () {
      final canvas = RecordingCanvas();
      baseChart().draw(canvas);

      expect(columnDayNumbers(canvas, 0),
          <String>['26', '27', '28', '29', '30', '31', '1'],
          reason: 'show-habit.number-formatting#8 — no padding, no ordinal '
              'suffix, no month');
      expect(columnDayNumbers(canvas, 13), <String>['25'],
          reason: 'show-habit.number-formatting#8');
    });

    test('show-habit.chart-scrolling#8: dataColumnWidth is squareSpacing + '
        'squareSize', () {
      final chart = baseChart();
      chart.draw(RecordingCanvas());
      expect(chart.dataColumnWidth, closeTo(1.0 + 25.0, 1e-9),
          reason: 'show-habit.chart-scrolling#8 — the History chart scrolls by '
              'squareSpacing + squareSize');

      chart.squareSpacing = 4.0;
      chart.draw(RecordingCanvas());
      expect(chart.dataColumnWidth, closeTo(4.0 + 25.0, 1e-9),
          reason: 'show-habit.chart-scrolling#8');
    });
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// The 85-entry series from `HistoryChartTest`, with its 3/2/1/else mapping.
final List<Square> upstreamSeries = <int>[
  2, // today
  2, 1, 2, 1, 2, 1, 2, //
  2, 3, 3, 3, 3, 1, 2, //
  2, 1, 2, 1, 2, 2, 1, //
  1, 1, 1, 1, 2, 2, 2, //
  1, 3, 3, 3, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 1, 1, 1, 1, //
  2, 2, 2, 3, 3, 3, 1, //
  1, 2, 1, 2, 1, 1, 2, //
  1, 2, 1, 1, 1, 1, 2, //
  2, 2, 2, 2, 2, 1, 1, //
  1, 1, 2, 2, 1, 2, 1, //
  1, 1, 1, 1, 2, 2, 2, //
].map((int it) {
  switch (it) {
    case 3:
      return Square.hatched;
    case 2:
      return Square.on;
    case 1:
      return Square.dimmed;
    default:
      return Square.off;
  }
}).toList();

final List<bool> upstreamNotes =
    List<bool>.generate(85, (int index) => index % 3 == 0);

HistoryChart baseChart({
  LocalDateFormatter dateFormatter = const TestDateFormatter(),
  DayOfWeek firstWeekday = DayOfWeek.sunday,
  PaletteColor paletteColor = const PaletteColor(7),
  List<Square>? series,
  Square defaultSquare = Square.off,
  List<bool>? notesIndicators,
  Theme? theme,
  LocalDate? today,
  RecordingListener? listener,
  double padding = 0.0,
}) {
  final chart = HistoryChart(
    dateFormatter: dateFormatter,
    firstWeekday: firstWeekday,
    paletteColor: paletteColor,
    series: series ?? upstreamSeries,
    defaultSquare: defaultSquare,
    notesIndicators: notesIndicators ?? upstreamNotes,
    theme: theme ?? LightTheme(),
    today: today ?? LocalDate.ymd(2015, 1, 25),
    padding: padding,
  );
  if (listener != null) chart.onDateClickedListener = listener;
  return chart;
}

/// `JavaLocalDateFormatter(Locale.US)`, reduced to the three members the chart
/// uses plus the two the interface requires.
class TestDateFormatter implements LocalDateFormatter {
  const TestDateFormatter();

  static const List<String> shortWeekdays = <String>[
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', //
  ];
  static const List<String> longWeekdays = <String>[
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', //
    'Thursday', 'Friday', 'Saturday',
  ];
  static const List<String> shortMonths = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const List<String> longMonths = <String>[
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  String shortWeekdayNameOf(DayOfWeek weekday) =>
      shortWeekdays[weekday.daysSinceSunday];

  @override
  String shortWeekdayName(LocalDate date) => shortWeekdayNameOf(date.dayOfWeek);

  @override
  String shortMonthName(LocalDate date) => shortMonths[date.month - 1];

  @override
  String longWeekdayNameOf(DayOfWeek weekday) =>
      longWeekdays[weekday.daysSinceSunday];

  @override
  String longMonthName(LocalDate date) => longMonths[date.month - 1];
}

/// Gives one chosen weekday an abnormally long short name, so that the gutter
/// width has to be the maximum over the whole list rather than any one entry.
class WideWeekdayFormatter extends TestDateFormatter {
  const WideWeekdayFormatter(this.wide);

  final DayOfWeek wide;

  @override
  String shortWeekdayNameOf(DayOfWeek weekday) =>
      weekday == wide ? 'Wednesday!' : super.shortWeekdayNameOf(weekday);
}

/// Ten-character month names, wide enough to overflow a 25-wide column.
class WideMonthFormatter extends TestDateFormatter {
  const WideMonthFormatter();

  @override
  String shortMonthName(LocalDate date) =>
      TestDateFormatter.longMonths[date.month - 1].padRight(10, '.');
}

class RecordingListener extends OnDateClickedListener {
  final List<LocalDate> shortPresses = <LocalDate>[];
  final List<LocalDate> longPresses = <LocalDate>[];

  void reset() {
    shortPresses.clear();
    longPresses.clear();
  }

  @override
  void onDateShortPress(LocalDate date) => shortPresses.add(date);

  @override
  void onDateLongPress(LocalDate date) => longPresses.add(date);
}

// ---------------------------------------------------------------------------
// A Canvas that records instead of painting
// ---------------------------------------------------------------------------

class CanvasOp {
  CanvasOp(
    this.name,
    this.args,
    this.color,
    this.textAlign,
    this.font,
    this.fontSize,
    this.strokeWidth,
  );

  final String name;
  final List<Object?> args;
  final Color color;
  final TextAlign textAlign;
  final Font font;
  final double fontSize;
  final double strokeWidth;

  double d(int index) => args[index] as double;

  String get text => args[0] as String;

  @override
  String toString() => '$name(${args.join(', ')})';
}

class RecordingCanvas extends Canvas {
  RecordingCanvas({this.logicalWidth = 400.0, this.logicalHeight = 200.0});

  final double logicalWidth;
  final double logicalHeight;

  final List<CanvasOp> ops = <CanvasOp>[];
  final List<String> measured = <String>[];

  Color _color = Color.BLACK;
  TextAlign _textAlign = TextAlign.left;
  Font _font = Font.regular;
  double _fontSize = 10.0;
  double _strokeWidth = 1.0;

  List<CanvasOp> opsNamed(String name) =>
      ops.where((CanvasOp op) => op.name == name).toList();

  void _record(String name, List<Object?> args) {
    ops.add(CanvasOp(
        name, args, _color, _textAlign, _font, _fontSize, _strokeWidth));
  }

  @override
  double getWidth() => logicalWidth;

  @override
  double getHeight() => logicalHeight;

  @override
  void setColor(Color color) {
    _color = color;
    _record('setColor', <Object?>[color]);
  }

  @override
  void setFont(Font font) {
    _font = font;
    _record('setFont', <Object?>[font]);
  }

  @override
  void setFontSize(double size) {
    _fontSize = size;
    _record('setFontSize', <Object?>[size]);
  }

  @override
  void setStrokeWidth(double size) {
    _strokeWidth = size;
    _record('setStrokeWidth', <Object?>[size]);
  }

  @override
  void setTextAlign(TextAlign align) {
    _textAlign = align;
    _record('setTextAlign', <Object?>[align]);
  }

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _record('drawLine', <Object?>[x1, y1, x2, y2]);

  @override
  void drawText(String text, double x, double y) =>
      _record('drawText', <Object?>[text, x, y]);

  @override
  void fillRect(double x, double y, double width, double height) =>
      _record('fillRect', <Object?>[x, y, width, height]);

  @override
  void fillRoundRect(double x, double y, double width, double height,
          double cornerRadius) =>
      _record('fillRoundRect', <Object?>[x, y, width, height, cornerRadius]);

  @override
  void drawRect(double x, double y, double width, double height) =>
      _record('drawRect', <Object?>[x, y, width, height]);

  @override
  void fillArc(double centerX, double centerY, double radius,
          double startAngle, double swipeAngle) =>
      _record('fillArc',
          <Object?>[centerX, centerY, radius, startAngle, swipeAngle]);

  @override
  void fillCircle(double centerX, double centerY, double radius) =>
      _record('fillCircle', <Object?>[centerX, centerY, radius]);

  /// A deliberately simple metric: proportional to the character count and to
  /// the font size, like a real proportional font's advance width but exactly
  /// predictable. At font size 12 a three-letter weekday name measures 21.6,
  /// which reproduces the nColumns = 14 that the upstream click fixture was
  /// captured under.
  @override
  double measureText(String text) {
    measured.add(text);
    return text.length * _fontSize * 0.6;
  }

  @override
  Image toImage() =>
      RgbaImage(logicalWidth.toInt(), logicalHeight.toInt());
}

// ---------------------------------------------------------------------------
// Readers over the recorded op stream
// ---------------------------------------------------------------------------

bool _near(double a, double b) => (a - b).abs() < 1e-9;

/// The column headers: every LEFT-aligned text drawn before the last square.
/// Day numbers are CENTER-aligned and weekday labels come after every square,
/// so this picks out exactly the one header per column.
List<CanvasOp> headers(RecordingCanvas canvas) {
  final lastSquare = canvas.ops.lastIndexWhere((o) => o.name == 'fillRoundRect');
  final result = <CanvasOp>[];
  for (var i = 0; i <= lastSquare; i++) {
    final op = canvas.ops[i];
    if (op.name == 'drawText' && op.textAlign == TextAlign.left) {
      result.add(op);
    }
  }
  return result;
}

/// The seven weekday labels: the LEFT-aligned texts drawn after every square.
List<CanvasOp> weekdayLabels(RecordingCanvas canvas) {
  final lastSquare = canvas.ops.lastIndexWhere((o) => o.name == 'fillRoundRect');
  return canvas.ops
      .asMap()
      .entries
      .where((e) =>
          e.key > lastSquare &&
          e.value.name == 'drawText' &&
          e.value.textAlign == TextAlign.left)
      .map((e) => e.value)
      .toList();
}

/// The distinct x coordinates the squares were drawn at, left to right.
List<double> columnLefts(RecordingCanvas canvas) {
  final lefts = <double>[];
  for (final square in canvas.opsNamed('fillRoundRect')) {
    if (lefts.isEmpty || !_near(lefts.last, square.d(0))) lefts.add(square.d(0));
  }
  return lefts;
}

int columnCount(RecordingCanvas canvas) => headers(canvas).length;

double squareSizeOf(RecordingCanvas canvas) {
  final square = canvas.opsNamed('fillRoundRect').first;
  final second = canvas.opsNamed('fillRoundRect')[1];
  return second.d(1) - square.d(1);
}

/// The tops of the seven weekday rows, taken from the leftmost column.
List<double> rowTops(RecordingCanvas canvas) {
  final left = columnLefts(canvas).first;
  return canvas
      .opsNamed('fillRoundRect')
      .where((o) => _near(o.d(0), left))
      .map((o) => o.d(1))
      .toList();
}

CanvasOp squareAt(RecordingCanvas canvas, double x, double y) =>
    canvas.opsNamed('fillRoundRect').firstWhere(
        (o) => _near(o.d(0), x) && _near(o.d(1), y),
        orElse: () => throw StateError('no square at ($x, $y)'));

/// Every op belonging to one square: from its fillRoundRect up to the next.
List<CanvasOp> blockAt(RecordingCanvas canvas, double x, double y) {
  final start = canvas.ops.indexWhere((o) =>
      o.name == 'fillRoundRect' && _near(o.d(0), x) && _near(o.d(1), y));
  if (start < 0) throw StateError('no square at ($x, $y)');
  var end = canvas.ops.length;
  for (var i = start + 1; i < canvas.ops.length; i++) {
    if (canvas.ops[i].name == 'fillRoundRect') {
      end = i;
      break;
    }
  }
  return canvas.ops.sublist(start, end);
}

/// The day number of one square: the only CENTER-aligned text in its block.
CanvasOp dayNumberOf(RecordingCanvas canvas, double x, double y) => blockAt(
        canvas, x, y)
    .firstWhere((o) => o.name == 'drawText' && o.textAlign == TextAlign.center);

Color circleColorAt(RecordingCanvas canvas, double x, double y) =>
    blockAt(canvas, x, y).firstWhere((o) => o.name == 'fillCircle').color;

/// The day numbers drawn in one column, top to bottom.
List<String> columnDayNumbers(RecordingCanvas canvas, int column) {
  final x = columnLefts(canvas)[column];
  return canvas
      .opsNamed('fillRoundRect')
      .where((o) => _near(o.d(0), x))
      .map((o) => dayNumberOf(canvas, o.d(0), o.d(1)).text)
      .toList();
}

String topLeftDayNumber(RecordingCanvas canvas) =>
    columnDayNumbers(canvas, 0).first;
