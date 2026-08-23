import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/canvas.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/image.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/gui/view.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/views/bar_chart.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/BarChart.kt
/// and uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/views/BarChartTest.kt.
///
/// The Kotlin test is a golden-image test: it renders the chart at 300x200
/// logical units and compares the PNG against
/// uhabits-core/assets/test/views/BarChart/{base,offset,themeDark,themeWidget}.png.
/// There is no image codec in this package, so the same fixture is asserted
/// here against [RecordingCanvas] — a fake backend that logs every drawing call
/// together with the sticky paint state it was made under. The layout
/// arithmetic, not the pixels, is the contract.
///
/// Fixture, identical to BarChartTest.kt: today = 2015-01-25, 101 descending
/// axis dates, one series of 11 values, colour index 8, canvas 300x200.
///
/// Derived geometry used throughout (all logical units):
///   nSeries        = 1
///   barGroupWidth  = 2*4 + 1*(12 + 2*3)        = 26
///   safeWidth      = 300 - 0 - 0               = 300
///   nColumns       = floor(300 / 26)           = 11
///   marginLeft     = (300 - 11*26) / 2         = 7
///   maxBarHeight   = 200 - 40 - 20             = 140
///   maxValue       = max(500, 1)               = 500
///   barGroupOffset(c) = 7 + 26c
///   barOffset(c, 0)   = 14 + 26c
///   axis baseline y   = 20 + 140               = 160
void main() {
  final today = LocalDate.ymd(2015, 1, 25);
  final fmt = TestDateFormatter();
  final series1 = <double>[
    200.0, 0.0, 150.0, 137.0, 0.0, 0.0, 500.0, 30.0, 100.0, 0.0, 300.0, //
  ];

  /// The BarChartTest.kt fixture.
  BarChart fixture({Theme? theme, LocalDate? origin}) {
    final t = theme ?? LightTheme();
    final o = origin ?? today;
    return BarChart(t, fmt)
      ..axis = List.generate(101, (i) => o.minus(i))
      ..series.add(series1)
      ..colors.add(t.color(8));
  }

  RecordingCanvas canvas300x200() => RecordingCanvas(300.0, 200.0);

  group('charts-canvas-theming.barchart', () {
    test('#1 DataView with mutable series/colors/axis/dataOffset', () {
      final theme = LightTheme();
      final chart = BarChart(theme, fmt);

      expect(chart, isA<DataView>(),
          reason: 'charts-canvas-theming.barchart#1: BarChart is a DataView');
      expect(chart, isA<View>(),
          reason: 'charts-canvas-theming.barchart#1: DataView is a View');
      expect(chart.theme, same(theme),
          reason: 'charts-canvas-theming.barchart#1: theme comes from the '
              'constructor');
      expect(chart.dateFormatter, same(fmt),
          reason: 'charts-canvas-theming.barchart#1: dateFormatter comes from '
              'the constructor');

      expect(chart.series, isEmpty,
          reason: 'charts-canvas-theming.barchart#1: series defaults to empty');
      expect(chart.colors, isEmpty,
          reason: 'charts-canvas-theming.barchart#1: colors defaults to empty');
      expect(chart.axis, isEmpty,
          reason: 'charts-canvas-theming.barchart#1: axis defaults to empty');
      expect(chart.dataOffset, 0,
          reason: 'charts-canvas-theming.barchart#1: dataOffset defaults to 0');

      // All four are mutable state, not constructor arguments: `series` and
      // `colors` are MutableList in Kotlin and are mutated in place by the
      // Android host, `axis` and `dataOffset` are reassigned wholesale.
      chart.series.add(const <double>[1.0, 2.0]);
      chart.colors.add(Color.RED);
      chart.axis = <LocalDate>[today];
      chart.dataOffset = 3;
      chart.theme = DarkTheme();

      expect(chart.series, [
        const <double>[1.0, 2.0]
      ], reason: 'charts-canvas-theming.barchart#1: series is mutable');
      expect(chart.colors, [Color.RED],
          reason: 'charts-canvas-theming.barchart#1: colors is mutable');
      expect(chart.axis, [today],
          reason: 'charts-canvas-theming.barchart#1: axis is mutable');
      expect(chart.dataOffset, 3,
          reason: 'charts-canvas-theming.barchart#1: dataOffset is mutable');
      expect(chart.theme, isA<DarkTheme>(),
          reason: 'charts-canvas-theming.barchart#1: theme is mutable');
    });

    test('#2 style defaults, in logical units', () {
      final chart = BarChart(LightTheme(), fmt);
      expect(chart.paddingTop, 20.0,
          reason: 'charts-canvas-theming.barchart#2: paddingTop');
      expect(chart.paddingLeft, 0.0,
          reason: 'charts-canvas-theming.barchart#2: paddingLeft');
      expect(chart.paddingRight, 0.0,
          reason: 'charts-canvas-theming.barchart#2: paddingRight');
      expect(chart.footerHeight, 40.0,
          reason: 'charts-canvas-theming.barchart#2: footerHeight');
      expect(chart.barGroupMargin, 4.0,
          reason: 'charts-canvas-theming.barchart#2: barGroupMargin');
      expect(chart.barMargin, 3.0,
          reason: 'charts-canvas-theming.barchart#2: barMargin');
      expect(chart.barWidth, 12.0,
          reason: 'charts-canvas-theming.barchart#2: barWidth');
      expect(chart.nGridlines, 6,
          reason: 'charts-canvas-theming.barchart#2: nGridlines');
    });

    test('#3 dataColumnWidth == barWidth + 2*barMargin', () {
      final chart = BarChart(LightTheme(), fmt);
      expect(chart.dataColumnWidth, 18.0,
          reason: 'charts-canvas-theming.barchart#3: 12 + 2*3 with the '
              'defaults');
      expect(chart.dataColumnWidth, chart.barWidth + 2 * chart.barMargin,
          reason: 'charts-canvas-theming.barchart#3: it is a computed getter');

      chart.barWidth = 20.0;
      chart.barMargin = 1.0;
      expect(chart.dataColumnWidth, 22.0,
          reason: 'charts-canvas-theming.barchart#3: recomputed from the '
              'current style, not cached');
    });

    test('#4 barGroupWidth = 2*barGroupMargin + nSeries*(barWidth+2*barMargin)',
        () {
      // One series: barGroupWidth = 8 + 18 = 26, so consecutive bar groups sit
      // exactly 26 apart and 11 of them fit into 300.
      final one = fixture();
      final c1 = canvas300x200();
      one.draw(c1);
      final xs1 = c1.barBodies.map((op) => op.args[0] as double).toList();
      expect(xs1.first, near(14.0),
          reason: 'charts-canvas-theming.barchart#4: barOffset(0,0) with '
              'barGroupWidth 26');
      expect(xs1[1] - xs1[0], near(26.0 * 2),
          reason: 'charts-canvas-theming.barchart#4: the second drawn bar is '
              'two groups (2*26) to the right, since column 1 is empty');
      expect(c1.axisLabelXs.toSet().length, 11,
          reason: 'charts-canvas-theming.barchart#4: floor(300/26) = 11 '
              'columns fit');

      // Two series: barGroupWidth = 8 + 2*18 = 44, so only floor(300/44) = 6
      // columns fit.
      final theme = LightTheme();
      final two = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(series1)
        ..series.add(series1)
        ..colors.add(theme.color(8))
        ..colors.add(theme.color(2));
      final c2 = canvas300x200();
      two.draw(c2);
      expect(c2.axisLabelXs.toSet().length, 6,
          reason: 'charts-canvas-theming.barchart#4: floor(300/44) = 6 columns '
              'fit once nSeries is 2');
      expect(c2.axisLabelXs.first, near(18.0 + 44.0 / 2),
          reason: 'charts-canvas-theming.barchart#4: labels are centred on a '
              '44-wide group');
    });

    test('#5 safeWidth, nColumns and the centring marginLeft', () {
      // Defaults: safeWidth 300, nColumns 11, marginLeft (300-286)/2 = 7.
      final a = fixture();
      final ca = canvas300x200();
      a.draw(ca);
      expect(ca.barBodies.first.args[0] as double, near(14.0),
          reason: 'charts-canvas-theming.barchart#5: marginLeft 7 + '
              'paddingLeft 0 + barGroupMargin 4 + barMargin 3');
      expect(ca.axisLabelXs.toSet().length, 11,
          reason: 'charts-canvas-theming.barchart#5: nColumns = '
              'floor(300/26) = 11');

      // paddingLeft 10 / paddingRight 20: safeWidth 270, nColumns
      // floor(270/26) = 10, marginLeft (270 - 260)/2 = 5, so the first bar sits
      // at 5 + 10 + 4 + 3 = 22.
      final b = fixture()
        ..paddingLeft = 10.0
        ..paddingRight = 20.0;
      final cb = canvas300x200();
      b.draw(cb);
      // barOffset(c, 0) = 5 + 10 + 26c + 4 + 3 = 22 + 26c. Column 0 now shows
      // series[9] = 0 and is skipped, so the leftmost drawn bar is column 1.
      expect(cb.axisLabelXs.first, near(28.0),
          reason: 'charts-canvas-theming.barchart#5: marginLeft = '
              '(safeWidth - nColumns*barGroupWidth)/2 = 5, plus paddingLeft, '
              'plus half a bar group');
      expect(cb.barBodies.first.args[0] as double, near(48.0),
          reason: 'charts-canvas-theming.barchart#5: marginLeft 5 + '
              'paddingLeft 10 + barGroupMargin 4 + barMargin 3, one group in');
      expect(cb.axisLabelXs.toSet().length, 10,
          reason: 'charts-canvas-theming.barchart#5: nColumns = '
              'floor(270/26) = 10');
      // The leftover is split evenly, so the grid is centred inside safeWidth:
      // right gap = 300 - 20 - (5 + 10 + 10*26) = 5 = left gap.
      final lastX = cb.axisLabelXs.last + 26.0 / 2;
      expect(300.0 - 20.0 - lastX, near(5.0),
          reason: 'charts-canvas-theming.barchart#5: the leftover is split '
              'evenly so the grid is centred');
    });

    test('#6 maxBarHeight = height - footerHeight - paddingTop', () {
      final chart = fixture();
      final canvas = canvas300x200();
      chart.draw(canvas);

      // The 500 bar is the tallest, so it is exactly maxBarHeight tall and its
      // top sits at paddingTop. It lives in column 4, at x = 118.
      expect(canvas.barHeightAt(118.0), near(140.0),
          reason: 'charts-canvas-theming.barchart#6: maxBarHeight = '
              '200 - 40 - 20 = 140');
      expect(canvas.barTop(118.0), near(20.0),
          reason: 'charts-canvas-theming.barchart#6: a full-height bar starts '
              'at paddingTop 20');
      expect(canvas.gridLines.last.args[1] as double, near(20.0),
          reason: 'charts-canvas-theming.barchart#6: the topmost gridline is '
              'paddingTop + maxBarHeight*0');
      expect(canvas.baseline.args[1] as double, near(160.0),
          reason: 'charts-canvas-theming.barchart#6: the axis sits at '
              'paddingTop + maxBarHeight = 160');

      // Same canvas, different footer/padding: maxBarHeight = 200 - 20 - 10.
      final other = fixture()
        ..footerHeight = 20.0
        ..paddingTop = 10.0;
      final canvas2 = canvas300x200();
      other.draw(canvas2);
      expect(canvas2.baseline.args[1] as double, near(180.0),
          reason: 'charts-canvas-theming.barchart#6: 10 + (200 - 20 - 10)');
    });

    test('#7 maxValue is the max of series maxima, floored at 1.0', () {
      // 500 is the largest value of the only series, so 300/500 = 0.6 of 140.
      final chart = fixture();
      final canvas = canvas300x200();
      chart.draw(canvas);
      expect(canvas.barTop(14.0), near(76.0),
          reason: 'charts-canvas-theming.barchart#7: maxValue 500 makes the '
              '300 bar round(140*0.6) = 84 tall');

      // Two series: the maximum is taken across every series.
      final theme = LightTheme();
      final two = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[10.0])
        ..series.add(<double>[20.0])
        ..colors.add(theme.color(8))
        ..colors.add(theme.color(2));
      final c2 = canvas300x200();
      two.draw(c2);
      // barGroupWidth 44, nColumns 6, marginLeft 18; only dataColumn 0 (c = 5)
      // holds data, so the bars sit at barOffset(5, 0) = 245 and
      // barOffset(5, 1) = 263. Series 0 gets 10/20 = half height, series 1 the
      // full one.
      expect(c2.barHeightAt(263.0), near(140.0),
          reason: 'charts-canvas-theming.barchart#7: maxValue 20 comes from '
              'the second series');
      expect(c2.barHeightAt(245.0), near(70.0),
          reason: 'charts-canvas-theming.barchart#7: 10/20 of maxBarHeight');

      // Everything below 1.0: maxValue is floored at 1.0, so a 0.5 value is
      // drawn at half height rather than full height.
      final small = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[0.5])
        ..colors.add(theme.color(8));
      final c3 = canvas300x200();
      small.draw(c3);
      expect(c3.barHeightAt(274.0), near(70.0),
          reason: 'charts-canvas-theming.barchart#7: max(0.5, 1.0) = 1.0, so '
              '0.5 is half of maxBarHeight');

      // maxOrNull()!! on an empty list is an upstream crash, preserved here as
      // Dart's null-check TypeError.
      final noSeries = BarChart(theme, fmt)..axis = <LocalDate>[today];
      expect(() => noSeries.draw(canvas300x200()), throwsA(isA<TypeError>()),
          reason: 'charts-canvas-theming.barchart#7: drawing with an empty '
              'series list throws (Kotlin: NullPointerException from '
              'maxOrNull()!!)');

      final emptySeries = BarChart(theme, fmt)
        ..axis = <LocalDate>[today]
        ..series.add(<double>[])
        ..colors.add(theme.color(8));
      expect(() => emptySeries.draw(canvas300x200()), throwsA(isA<TypeError>()),
          reason: 'charts-canvas-theming.barchart#7: drawing with an empty '
              'series throws (Kotlin: NullPointerException from '
              'maxOrNull()!!)');
    });

    test('#8 draw order: background, grid, series, axis labels', () {
      final chart = fixture();
      final canvas = canvas300x200();
      chart.draw(canvas);

      expect(canvas.names[0], 'setColor',
          reason: 'charts-canvas-theming.barchart#8: the background colour is '
              'set first');
      expect(canvas.ops[0].args[0], LightTheme().cardBackgroundColor,
          reason: 'charts-canvas-theming.barchart#8: the background is '
              'theme.cardBackgroundColor');
      expect(canvas.names[1], 'fillRect',
          reason: 'charts-canvas-theming.barchart#8: fill() covers the canvas '
              'before anything else is drawn');
      expect(canvas.ops[1].args, [0.0, 0.0, 300.0, 200.0],
          reason: 'charts-canvas-theming.barchart#8: fill() covers the WHOLE '
              'canvas');

      final firstGridline = canvas.indexOfOp('drawLine');
      final firstBar = canvas.indexOfOp('fillCircle');
      final baselineIndex = canvas.lastIndexOfOp('drawLine');
      final firstAxisLabel = canvas.ops.indexWhere((op) =>
          op.name == 'drawText' &&
          op.color == LightTheme().mediumContrastTextColor);

      expect(firstGridline > 1, isTrue,
          reason: 'charts-canvas-theming.barchart#8: the major grid is drawn '
              'after the background');
      expect(firstBar > firstGridline, isTrue,
          reason: 'charts-canvas-theming.barchart#8: the series are drawn '
              'after the major grid');
      expect(baselineIndex > firstBar, isTrue,
          reason: 'charts-canvas-theming.barchart#8: the axis is drawn after '
              'the series');
      expect(firstAxisLabel > baselineIndex, isTrue,
          reason: 'charts-canvas-theming.barchart#8: the axis labels sit on '
              'top of everything else');

      // Series are drawn in index order: series 0 fully, then series 1.
      final theme = LightTheme();
      final two = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[10.0])
        ..series.add(<double>[10.0])
        ..colors.add(theme.color(8))
        ..colors.add(theme.color(2));
      final c2 = canvas300x200();
      two.draw(c2);
      expect(c2.barBodies.map((op) => op.color).toList(),
          [theme.color(8), theme.color(2)],
          reason: 'charts-canvas-theming.barchart#8: every series is drawn in '
              'index order');
    });

    test('#9 barGroupOffset(c) and barOffset(c, s)', () {
      // One series: barOffset(c, 0) = 7 + 0 + 26c + 4 + 0 + 3 = 14 + 26c.
      final one = fixture();
      final c1 = canvas300x200();
      one.draw(c1);
      final xs = c1.barBodies.map((op) => op.args[0] as double).toList();
      // Positive values live at columns 0, 2, 3, 4, 7, 8 and 10.
      expect(xs, [
        near(14.0),
        near(66.0),
        near(92.0),
        near(118.0),
        near(196.0),
        near(222.0),
        near(274.0),
      ], reason: 'charts-canvas-theming.barchart#9: barOffset(c, 0) = 14 + 26c');

      // Two series: barGroupOffset(c) = 18 + 44c, barOffset(c, 0) = 25 + 44c
      // and barOffset(c, 1) = 25 + 18 + 44c = 43 + 44c.
      final theme = LightTheme();
      final two = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[10.0])
        ..series.add(<double>[10.0])
        ..colors.add(theme.color(8))
        ..colors.add(theme.color(2));
      final c2 = canvas300x200();
      two.draw(c2);
      // nColumns = 6, so the only data column (index 0) is c = 5.
      expect(c2.barBodies[0].args[0] as double, near(25.0 + 44.0 * 5),
          reason: 'charts-canvas-theming.barchart#9: barOffset(5, 0) = '
              'barGroupOffset(5) + barGroupMargin + barMargin');
      expect(c2.barBodies[1].args[0] as double, near(43.0 + 44.0 * 5),
          reason: 'charts-canvas-theming.barchart#9: barOffset(5, 1) adds '
              's*(barWidth + 2*barMargin) = 18');
      expect(c2.verticalSeparators.first.args[0] as double, near(18.0),
          reason: 'charts-canvas-theming.barchart#9: barGroupOffset(0) = '
              'marginLeft + paddingLeft');
      expect(c2.verticalSeparators[1].args[0] as double, near(62.0),
          reason: 'charts-canvas-theming.barchart#9: barGroupOffset(1) = '
              'marginLeft + paddingLeft + barGroupWidth');
    });

    test('#10 dataColumn = nColumns - c - 1 + dataOffset', () {
      // dataOffset 0: column c shows series1[10 - c], newest datum on the
      // right. Heights are round(140 * value/500).
      final chart = fixture();
      final canvas = canvas300x200();
      chart.draw(canvas);
      expect(canvas.barHeightAt(14.0), near(84.0),
          reason: 'charts-canvas-theming.barchart#10: column 0 shows '
              'series[10] = 300');
      expect(canvas.barHeightAt(274.0), near(56.0),
          reason: 'charts-canvas-theming.barchart#10: the rightmost column '
              'shows series[0] = 200, the newest datum');
      expect(canvas.barHeightAt(118.0), near(140.0),
          reason: 'charts-canvas-theming.barchart#10: column 4 shows '
              'series[6] = 500');

      // dataOffset 5 scrolls five columns into the past: dataColumn = 15 - c,
      // so series[10] = 300 moves from column 0 to column 5.
      final offset = fixture()..dataOffset = 5;
      final c2 = canvas300x200();
      offset.draw(c2);
      expect(c2.barHeightAt(14.0 + 26.0 * 5), near(84.0),
          reason: 'charts-canvas-theming.barchart#10: dataOffset 5 moves '
              'series[10] to column 5');
      expect(c2.barBodies.map((op) => op.args[0] as double).toList(),
          everyElement(greaterThan(14.0 + 26.0 * 4)),
          reason: 'charts-canvas-theming.barchart#10: dataColumn >= '
              'series.length is treated as 0.0, so columns 0..4 stay empty');

      // Negative dataColumns are treated as 0.0 too: dataOffset -5 gives
      // dataColumn = 5 - c, which goes negative from column 6 on.
      final back = fixture()..dataOffset = -5;
      final c3 = canvas300x200();
      back.draw(c3);
      expect(c3.barBodies.map((op) => op.args[0] as double).toList(), [
        near(14.0 + 26.0 * 2),
        near(14.0 + 26.0 * 3),
        near(14.0 + 26.0 * 5),
      ], reason: 'charts-canvas-theming.barchart#10: dataColumn < 0 is treated '
          'as 0.0, leaving only series[3], series[2] and series[0] drawn');
    });

    test('#11 a bar with value <= 0 draws nothing at all', () {
      final chart = fixture();
      final canvas = canvas300x200();
      chart.draw(canvas);

      // series1 has 7 positive values out of 11.
      expect(canvas.barBodies.length, 7,
          reason: 'charts-canvas-theming.barchart#11: the four zero values '
              'draw no rectangle');
      expect(canvas.valueLabels.length, 7,
          reason: 'charts-canvas-theming.barchart#11: and no value label '
              'either');
      expect(canvas.barBodies.map((op) => op.args[0] as double),
          isNot(contains(near(40.0))),
          reason: 'charts-canvas-theming.barchart#11: column 1 (series[9] = 0) '
              'is skipped entirely');

      // Negative values are skipped by the same `value <= 0` guard.
      final theme = LightTheme();
      final negative = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[-5.0, 10.0])
        ..colors.add(theme.color(8));
      final c2 = canvas300x200();
      negative.draw(c2);
      expect(c2.barRects.length, 2,
          reason: 'charts-canvas-theming.barchart#11: only the positive value '
              'is drawn (two fillRects: body and rounded cap)');
      expect(c2.valueLabels.length, 1,
          reason: 'charts-canvas-theming.barchart#11: negative values get no '
              'label');
    });

    test('#12 perc, barHeight, x, y and the corner radius', () {
      final chart = fixture();
      final canvas = canvas300x200();
      chart.draw(canvas);

      // Column 0, value 300: perc = 0.6, barHeight = round(140*0.6) = 84,
      // x = 14, y = 200 - 40 - 84 = 76, r = round(12*0.15) = 2.
      expect(canvas.barBodies[0].args[0] as double, near(14.0),
          reason: 'charts-canvas-theming.barchart#12: x = barOffset(0, 0)');
      expect(canvas.barTop(14.0), near(76.0),
          reason: 'charts-canvas-theming.barchart#12: y = height - '
              'footerHeight - barHeight');
      expect(canvas.barHeightAt(14.0), near(84.0),
          reason: 'charts-canvas-theming.barchart#12: barHeight = '
              'round(maxBarHeight * perc)');
      expect(canvas.opsNamed('fillCircle').first.args[2] as double, near(2.0),
          reason: 'charts-canvas-theming.barchart#12: r = round(barWidth*0.15) '
              '= 2 with the default barWidth of 12');

      // Column 3, value 30: perc = 0.06, barHeight = round(8.4) = 8, so the
      // rounding is a genuine round(), not a truncation.
      expect(canvas.barHeightAt(92.0), near(8.0),
          reason: 'charts-canvas-theming.barchart#12: round(140*30/500) = 8');
      expect(canvas.barTop(92.0), near(152.0),
          reason: 'charts-canvas-theming.barchart#12: y = 200 - 40 - 8');
      // Column 7, value 137: round(140*0.274) = round(38.36) = 38.
      expect(canvas.barHeightAt(196.0), near(38.0),
          reason: 'charts-canvas-theming.barchart#12: round(140*137/500) = 38');
    });

    test('#13 rounded top corners as four primitives, else a single rect', () {
      final theme = LightTheme();
      // series[0] = 500 (barHeight 140, rounded) and series[1] = 3
      // (barHeight = round(0.84) = 1, so 2*r = 4 is not < 1: a single rect).
      final chart = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[500.0, 3.0])
        ..colors.add(theme.color(8));
      final canvas = canvas300x200();
      chart.draw(canvas);

      // Column 10 (x = 274) holds the 500; column 9 (x = 248) the 3.
      final tall = canvas.barOpsAt(274.0);
      expect(tall.map((op) => op.name).toList(),
          ['fillRect', 'fillRect', 'fillCircle', 'fillCircle'],
          reason: 'charts-canvas-theming.barchart#13: 2*r < barHeight draws '
              'four primitives');
      expect(tall[0].args, [near(274.0), near(22.0), near(12.0), near(138.0)],
          reason: 'charts-canvas-theming.barchart#13: fillRect(x, y+r, '
              'barWidth, barHeight-r)');
      expect(tall[1].args, [near(276.0), near(20.0), near(8.0), near(3.0)],
          reason: 'charts-canvas-theming.barchart#13: fillRect(x+r, y, '
              'barWidth-2*r, r+1)');
      expect(tall[2].args, [near(276.0), near(22.0), near(2.0)],
          reason: 'charts-canvas-theming.barchart#13: fillCircle(x+r, y+r, r)');
      expect(tall[3].args, [near(284.0), near(22.0), near(2.0)],
          reason: 'charts-canvas-theming.barchart#13: fillCircle(x+barWidth-r, '
              'y+r, r)');

      final flat = canvas.barOpsAt(248.0);
      expect(flat.map((op) => op.name).toList(), ['fillRect'],
          reason: 'charts-canvas-theming.barchart#13: 2*r >= barHeight draws a '
              'single fillRect');
      expect(flat[0].args, [near(248.0), near(159.0), near(12.0), near(1.0)],
          reason: 'charts-canvas-theming.barchart#13: fillRect(x, y, barWidth, '
              'barHeight)');
    });

    test('#14 value labels: colour, alignment, size, position and text', () {
      final theme = LightTheme();
      final chart = fixture(theme: theme);
      final canvas = canvas300x200();
      chart.draw(canvas);

      final first = canvas.valueLabels.first;
      expect(first.args[0], '300',
          reason: 'charts-canvas-theming.barchart#14: the text is '
              'value.toShortString()');
      expect(first.args[1] as double, near(20.0),
          reason: 'charts-canvas-theming.barchart#14: x + barWidth/2');
      expect(first.args[2] as double, near(68.0),
          reason: 'charts-canvas-theming.barchart#14: y - '
              'theme.smallTextSize*0.80 = 76 - 8');
      expect(first.color, theme.color(8),
          reason: 'charts-canvas-theming.barchart#14: the label is drawn in '
              'colors[s]');
      expect(first.textAlign, TextAlign.center,
          reason: 'charts-canvas-theming.barchart#14: labels are centred');
      expect(first.fontSize, theme.smallTextSize,
          reason: 'charts-canvas-theming.barchart#14: fontSize is '
              'theme.smallTextSize (10.0)');
      expect(theme.smallTextSize, 10.0,
          reason: 'charts-canvas-theming.barchart#14: theme.smallTextSize is '
              '10.0');

      expect(canvas.valueLabels.map((op) => op.args[0]).toList(),
          ['300', '100', '30', '500', '137', '150', '200'],
          reason: 'charts-canvas-theming.barchart#14: every drawn bar gets a '
              'label, left to right');

      // toShortString on non-integral and large values.
      final small = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[0.5])
        ..colors.add(theme.color(8));
      final c2 = canvas300x200();
      small.draw(c2);
      expect(c2.valueLabels.single.args[0], '0.5',
          reason: 'charts-canvas-theming.barchart#14: toShortString of 0.5');

      final big = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(<double>[1234.0])
        ..colors.add(theme.color(8));
      final c3 = canvas300x200();
      big.draw(c3);
      expect(c3.valueLabels.single.args[0], '1.2k',
          reason: 'charts-canvas-theming.barchart#14: toShortString of 1234');
    });

    test('#15 major grid: separators only when nSeries > 1, then gridlines',
        () {
      final theme = LightTheme();
      final chart = fixture(theme: theme);
      final canvas = canvas300x200();
      chart.draw(canvas);

      expect(canvas.ops[2].name, 'setStrokeWidth',
          reason: 'charts-canvas-theming.barchart#15: strokeWidth is set to '
              '1.0 first');
      expect(canvas.ops[2].args[0], 1.0,
          reason: 'charts-canvas-theming.barchart#15: strokeWidth 1.0');

      expect(canvas.verticalSeparators, isEmpty,
          reason: 'charts-canvas-theming.barchart#15: no vertical separators '
              'when nSeries == 1');

      // Five horizontal gridlines at fractions 0.8, 0.6, 0.4, 0.2 and 0.0 of
      // maxBarHeight below paddingTop.
      expect(canvas.gridLines.length, 5,
          reason: 'charts-canvas-theming.barchart#15: k in 1 until nGridlines '
              'draws 5 lines with nGridlines = 6');
      expect(canvas.gridLines.map((op) => op.args[1] as double).toList(), [
        near(132.0),
        near(104.0),
        near(76.0),
        near(48.0),
        near(20.0),
      ], reason: 'charts-canvas-theming.barchart#15: y = paddingTop + '
          'maxBarHeight * (1 - k/(nGridlines-1))');
      for (final line in canvas.gridLines) {
        expect([line.args[0], line.args[2]], [0.0, 300.0],
            reason: 'charts-canvas-theming.barchart#15: gridlines span the '
                'full width');
        expect(line.args[1], line.args[3],
            reason: 'charts-canvas-theming.barchart#15: gridlines are '
                'horizontal');
        expect(line.color, theme.lowContrastTextColor,
            reason: 'charts-canvas-theming.barchart#15: gridlines use '
                'theme.lowContrastTextColor');
        expect(line.strokeWidth, 0.5,
            reason: 'charts-canvas-theming.barchart#15: gridlines use '
                'strokeWidth 0.5');
      }

      // Two series: 5 vertical separators (c in 0 until nColumns-1 = 0..4).
      final two = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(i))
        ..series.add(series1)
        ..series.add(series1)
        ..colors.add(theme.color(8))
        ..colors.add(theme.color(2));
      final c2 = canvas300x200();
      two.draw(c2);
      final separators = c2.verticalSeparators;
      expect(separators.length, 5,
          reason: 'charts-canvas-theming.barchart#15: one separator for each c '
              'in 0 until nColumns-1');
      expect(separators.map((op) => op.args[0] as double).toList(), [
        near(18.0),
        near(62.0),
        near(106.0),
        near(150.0),
        near(194.0),
      ], reason: 'charts-canvas-theming.barchart#15: separators sit at '
          'barGroupOffset(c)');
      for (final s in separators) {
        expect([s.args[1], s.args[3]], [20.0, 160.0],
            reason: 'charts-canvas-theming.barchart#15: separators span '
                'paddingTop..paddingTop+maxBarHeight');
        expect(s.color, theme.lowContrastTextColor.withAlpha(0.5),
            reason: 'charts-canvas-theming.barchart#15: separators use '
                'lowContrastTextColor.withAlpha(0.5)');
        expect(s.strokeWidth, 1.0,
            reason: 'charts-canvas-theming.barchart#15: separators inherit '
                'strokeWidth 1.0');
      }
    });

    test('#16 axis baseline and label style', () {
      final theme = LightTheme();
      final chart = fixture(theme: theme);
      final canvas = canvas300x200();
      chart.draw(canvas);

      final baseline = canvas.baseline;
      expect(baseline.args, [0.0, near(160.0), 300.0, near(160.0)],
          reason: 'charts-canvas-theming.barchart#16: a full-width baseline at '
              'y = paddingTop + maxBarHeight');
      expect(baseline.color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.barchart#16: the baseline uses '
              'theme.lowContrastTextColor');
      expect(baseline.strokeWidth, 0.5,
          reason: 'charts-canvas-theming.barchart#16: strokeWidth 0.5 is '
              'inherited from the gridline loop, never set again');

      for (final label in canvas.axisLabels) {
        expect(label.color, theme.mediumContrastTextColor,
            reason: 'charts-canvas-theming.barchart#16: axis labels use '
                'theme.mediumContrastTextColor');
        expect(label.textAlign, TextAlign.center,
            reason: 'charts-canvas-theming.barchart#16: axis labels are '
                'centred');
        expect(label.fontSize, theme.smallTextSize,
            reason: 'charts-canvas-theming.barchart#16: axis labels use '
                'theme.smallTextSize');
      }
    });

    test('#17 isLargeInterval = axis.size < 2 || axis[0].daysUntil(axis[1])>300',
        () {
      final a = LocalDate.ymd(2015, 1, 25);
      final b = LocalDate.ymd(2015, 1, 24);
      expect(a.daysUntil(b), b.daysSince2000 - a.daysSince2000,
          reason: 'charts-canvas-theming.barchart#17: daysUntil(other) == '
              'other.daysSince2000 - this.daysSince2000');
      expect(a.daysUntil(b), -1,
          reason: 'charts-canvas-theming.barchart#17: a newest-first axis '
              'yields a negative difference');

      // Newest-first axis (what the presenter supplies): NOT a large interval,
      // so day numbers and month names are printed.
      final theme = LightTheme();
      final normal = fixture(theme: theme);
      final c1 = canvas300x200();
      normal.draw(c1);
      expect(c1.axisLabels.map((op) => op.args[0] as String).toList(),
          contains('Jan'),
          reason: 'charts-canvas-theming.barchart#17: a descending axis is not '
              'a large interval, so month names are printed');

      // A single-entry axis: axis.size < 2 makes it a large interval.
      final single = BarChart(theme, fmt)
        ..axis = <LocalDate>[today]
        ..series.add(series1)
        ..colors.add(theme.color(8));
      final c2 = canvas300x200();
      single.draw(c2);
      expect(c2.axisLabels.map((op) => op.args[0] as String).toList(), ['2015'],
          reason: 'charts-canvas-theming.barchart#17: axis.size < 2 is a large '
              'interval, so only the year is printed');

      // An ASCENDING axis whose first gap exceeds 300 days: also large.
      final yearly = BarChart(theme, fmt)
        ..axis = List.generate(11, (i) => LocalDate.ymd(2005 + i, 3, 15))
        ..series.add(series1)
        ..colors.add(theme.color(8));
      final c3 = canvas300x200();
      yearly.draw(c3);
      expect(c3.axisLabels.every((op) => (op.args[0] as String).length == 4),
          isTrue,
          reason: 'charts-canvas-theming.barchart#17: axis[0].daysUntil('
              'axis[1]) = 365 > 300 is a large interval');

      // An ascending axis with a one-day gap: not large.
      final ascending = BarChart(theme, fmt)
        ..axis = List.generate(101, (i) => today.minus(100 - i))
        ..series.add(series1)
        ..colors.add(theme.color(8));
      final c4 = canvas300x200();
      ascending.draw(c4);
      expect(c4.axisLabels.any((op) => (op.args[0] as String) == 'Oct'), isTrue,
          reason: 'charts-canvas-theming.barchart#17: a +1 day gap is not a '
              'large interval');
    });

    test('#18 large interval prints only the year, centred on the group', () {
      final theme = LightTheme();
      final yearly = BarChart(theme, fmt)
        ..axis = List.generate(11, (i) => LocalDate.ymd(2005 + i, 3, 15))
        ..series.add(series1)
        ..colors.add(theme.color(8));
      final canvas = canvas300x200();
      yearly.draw(canvas);

      expect(canvas.axisLabels.map((op) => op.args[0] as String).toList(), [
        '2015', '2014', '2013', '2012', '2011', //
        '2010', '2009', '2008', '2007', '2006', '2005',
      ], reason: 'charts-canvas-theming.barchart#18: every column prints only '
          'date.year');
      expect(canvas.axisLabels.map((op) => op.args[1] as double).toList(), [
        near(20.0), near(46.0), near(72.0), near(98.0), near(124.0), //
        near(150.0), near(176.0), near(202.0), near(228.0), near(254.0),
        near(280.0),
      ], reason: 'charts-canvas-theming.barchart#18: x = barGroupOffset(c) + '
          'barGroupWidth/2');
      for (final label in canvas.axisLabels) {
        expect(label.args[2] as double, near(170.0),
            reason: 'charts-canvas-theming.barchart#18: y = axisY + '
                'theme.smallTextSize*1.0');
      }
    });

    test('#19 month name on change, else day; plus year on change', () {
      // An axis that crosses a month AND a year boundary: today = 2015-01-05,
      // so the eleven drawn columns run 2014-12-26 .. 2015-01-05.
      final theme = LightTheme();
      final chart = fixture(theme: theme, origin: LocalDate.ymd(2015, 1, 5));
      final canvas = canvas300x200();
      chart.draw(canvas);

      expect(canvas.axisLabels.map((op) => op.args[0] as String).toList(), [
        'Dec', '2014', '27', '28', '29', '30', '31', //
        'Jan', '2015', '2', '3', '4', '5',
      ], reason: 'charts-canvas-theming.barchart#19: shortMonthName when the '
          'month changes, otherwise the day number');

      final byText = {
        for (final op in canvas.axisLabels) op.args[0] as String: op
      };
      expect(byText['Dec']!.args[2] as double, near(170.0),
          reason: 'charts-canvas-theming.barchart#19: month/day labels sit at '
              'axisY + theme.smallTextSize*1.0');
      expect(byText['27']!.args[2] as double, near(170.0),
          reason: 'charts-canvas-theming.barchart#19: day labels share that y');
      expect(byText['2014']!.args[2] as double, near(183.0),
          reason: 'charts-canvas-theming.barchart#19: the year sits at axisY + '
              'theme.smallTextSize*2.3');
      expect(byText['2015']!.args[2] as double, near(183.0),
          reason: 'charts-canvas-theming.barchart#19: the year is printed '
              'again when it changes');
      expect(byText['Jan']!.args[1] as double, near(176.0),
          reason: 'charts-canvas-theming.barchart#19: column 6 is centred at '
              'barGroupOffset(6) + 13 = 176');
      expect(byText['2015']!.args[1] as double, near(176.0),
          reason: 'charts-canvas-theming.barchart#19: the year shares the '
              'column centre');
    });

    test('#20 prevMonth and prevYear restart at -1 for every draw', () {
      final theme = LightTheme();
      final chart = fixture(theme: theme);
      final canvas = canvas300x200();
      chart.draw(canvas);

      // Every drawn column is mid-January 2015, yet the leftmost still prints
      // both a month name and a year because prevMonth/prevYear start at -1.
      final texts = canvas.axisLabels.map((op) => op.args[0] as String).toList();
      expect(texts.take(2).toList(), ['Jan', '2015'],
          reason: 'charts-canvas-theming.barchart#20: the leftmost drawn '
              'column always prints both a month name and a year');
      expect(texts.sublist(2), ['16', '17', '18', '19', '20', '21', '22', '23',
          '24', '25'],
          reason: 'charts-canvas-theming.barchart#20: columns are iterated '
              'left to right while data runs newest-on-the-right, so '
              '"previous" is the older neighbour');

      // Drawing again resets the state; the same labels come out.
      final second = canvas300x200();
      chart.draw(second);
      expect(second.axisLabels.map((op) => op.args[0] as String).toList(), texts,
          reason: 'charts-canvas-theming.barchart#20: prevMonth/prevYear are '
              'local to draw(), so a redraw is identical');
    });

    test('#21 columns outside the axis are skipped for labelling only', () {
      final theme = LightTheme();
      // A two-entry axis with the full eleven-value series: only dataColumn 0
      // and 1 (columns 10 and 9) can be labelled.
      final chart = BarChart(theme, fmt)
        ..axis = <LocalDate>[today, today.minus(1)]
        ..series.add(series1)
        ..colors.add(theme.color(8));
      final canvas = canvas300x200();
      chart.draw(canvas);

      expect(canvas.axisLabels.map((op) => op.args[0] as String).toList(),
          ['Jan', '2015', '25'],
          reason: 'charts-canvas-theming.barchart#21: dataColumn >= axis.size '
              'is skipped (continue) for labelling');
      expect(canvas.axisLabels.map((op) => op.args[1] as double).toList(),
          [near(254.0), near(254.0), near(280.0)],
          reason: 'charts-canvas-theming.barchart#21: only columns 9 and 10 '
              'fall inside the axis');
      expect(canvas.valueLabels.length, 7,
          reason: 'charts-canvas-theming.barchart#21: the bars are unaffected '
              'by the short axis');

      // Negative dataColumns are skipped for labelling as well, and their bars
      // are treated as value 0 and therefore skipped.
      final back = fixture(theme: theme)..dataOffset = -5;
      final c2 = canvas300x200();
      back.draw(c2);
      expect(c2.axisLabels.map((op) => op.args[0] as String).toList(),
          ['Jan', '2015', '21', '22', '23', '24', '25'],
          reason: 'charts-canvas-theming.barchart#21: dataColumn < 0 is '
              'skipped for labelling');
      expect(c2.valueLabels.map((op) => op.args[0] as String).toList(),
          ['137', '150', '200'],
          reason: 'charts-canvas-theming.barchart#21: their bars are drawn as '
              'value 0, i.e. skipped');
    });
  });
}

Matcher near(double value) => closeTo(value, 1e-9);

/// A recording fake [Canvas]: it paints nothing and logs every call together
/// with the sticky paint state that was in force. Mirrors the fake used by
/// test/gui/canvas_test.dart, minus the device-pixel bookkeeping, which BarChart
/// never observes.
class RecordingCanvas extends Canvas {
  RecordingCanvas(this._width, this._height);

  final double _width;
  final double _height;

  final List<Op> ops = [];

  Color _color = Color.BLACK;
  double _fontSize = 12.0;
  double _strokeWidth = 1.0;
  TextAlign _textAlign = TextAlign.left;
  Font _font = Font.regular;

  void _record(String name, List<Object?> args) {
    ops.add(Op(name, args,
        color: _color,
        fontSize: _fontSize,
        strokeWidth: _strokeWidth,
        textAlign: _textAlign,
        font: _font));
  }

  List<String> get names => ops.map((op) => op.name).toList();

  List<Op> opsNamed(String name) =>
      ops.where((op) => op.name == name).toList(growable: false);

  int indexOfOp(String name) => ops.indexWhere((op) => op.name == name);

  int lastIndexOfOp(String name) => ops.lastIndexWhere((op) => op.name == name);

  /// Every fillRect except the very first one, which is the background fill.
  List<Op> get barRects => opsNamed('fillRect').sublist(1);

  /// The full-width body rectangle of each bar, in draw order. A rounded bar
  /// also emits a narrower cap rectangle, which this filter drops.
  List<Op> get barBodies =>
      barRects.where((op) => op.args[2] == 12.0).toList(growable: false);

  /// drawLine calls whose endpoints share a y: the horizontal major gridlines,
  /// minus the axis baseline, which is the last one.
  List<Op> get gridLines {
    final horizontal =
        opsNamed('drawLine').where((op) => op.args[1] == op.args[3]).toList();
    return horizontal.sublist(0, horizontal.length - 1);
  }

  Op get baseline => opsNamed('drawLine').last;

  List<Op> get verticalSeparators =>
      opsNamed('drawLine').where((op) => op.args[0] == op.args[2]).toList();

  /// drawText calls issued while the colour was the axis-label colour. The
  /// axis is drawn last, so anything after the baseline is an axis label.
  List<Op> get axisLabels {
    final start = ops.lastIndexWhere((op) => op.name == 'drawLine');
    return ops
        .sublist(start)
        .where((op) => op.name == 'drawText')
        .toList(growable: false);
  }

  List<double> get axisLabelXs =>
      axisLabels.map((op) => op.args[1] as double).toList();

  /// Bar value labels: every drawText before the axis begins.
  List<Op> get valueLabels {
    final end = ops.lastIndexWhere((op) => op.name == 'drawLine');
    return ops
        .sublist(0, end)
        .where((op) => op.name == 'drawText')
        .toList(growable: false);
  }

  /// The drawing primitives of the bar whose left edge is at [x].
  List<Op> barOpsAt(double x) => ops
      .where((op) =>
          (op.name == 'fillRect' &&
              ((op.args[0] as double) - x).abs() < 1e-9 &&
              op.args[2] == 12.0) ||
          (op.name == 'fillRect' &&
              ((op.args[0] as double) - x - 2.0).abs() < 1e-9 &&
              op.args[2] == 8.0) ||
          (op.name == 'fillCircle' &&
              (((op.args[0] as double) - x - 2.0).abs() < 1e-9 ||
                  ((op.args[0] as double) - x - 10.0).abs() < 1e-9)))
      .toList(growable: false);

  /// Height of the bar body at [x]; the body rect is the one that is barWidth
  /// wide.
  double barHeightAt(double x) {
    final body = barRects.firstWhere((op) =>
        ((op.args[0] as double) - x).abs() < 1e-9 && op.args[2] == 12.0);
    // For a rounded bar the body starts r below the top and is barHeight - r
    // tall; the cap rect adds r back.
    final cap = barRects.where((op) =>
        ((op.args[0] as double) - x - 2.0).abs() < 1e-9 && op.args[2] == 8.0);
    if (cap.isEmpty) return body.args[3] as double;
    return (body.args[3] as double) + 2.0;
  }

  /// Top edge (y) of the bar at [x], as the chart computed it.
  double barTop(double x) {
    final cap = barRects.where((op) =>
        ((op.args[0] as double) - x - 2.0).abs() < 1e-9 && op.args[2] == 8.0);
    if (cap.isNotEmpty) return cap.first.args[1] as double;
    final body = barRects.firstWhere((op) =>
        ((op.args[0] as double) - x).abs() < 1e-9 && op.args[2] == 12.0);
    return body.args[1] as double;
  }

  @override
  void setColor(Color color) {
    _color = color;
    _record('setColor', [color]);
  }

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _record('drawLine', [x1, y1, x2, y2]);

  @override
  void drawText(String text, double x, double y) =>
      _record('drawText', [text, x, y]);

  @override
  void fillRect(double x, double y, double width, double height) =>
      _record('fillRect', [x, y, width, height]);

  @override
  void fillRoundRect(double x, double y, double width, double height,
          double cornerRadius) =>
      _record('fillRoundRect', [x, y, width, height, cornerRadius]);

  @override
  void drawRect(double x, double y, double width, double height) =>
      _record('drawRect', [x, y, width, height]);

  @override
  double getHeight() => _height;

  @override
  double getWidth() => _width;

  @override
  void setFont(Font font) {
    _font = font;
    _record('setFont', [font]);
  }

  @override
  void setFontSize(double size) {
    _fontSize = size;
    _record('setFontSize', [size]);
  }

  @override
  void setStrokeWidth(double size) {
    _strokeWidth = size;
    _record('setStrokeWidth', [size]);
  }

  @override
  void fillArc(double centerX, double centerY, double radius, double startAngle,
          double swipeAngle) =>
      _record('fillArc', [centerX, centerY, radius, startAngle, swipeAngle]);

  @override
  void fillCircle(double centerX, double centerY, double radius) =>
      _record('fillCircle', [centerX, centerY, radius]);

  @override
  void setTextAlign(TextAlign align) {
    _textAlign = align;
    _record('setTextAlign', [align]);
  }

  @override
  Image toImage() => throw UnimplementedError();

  @override
  double measureText(String text) => text.length * 0.6 * _fontSize;
}

class Op {
  Op(
    this.name,
    this.args, {
    required this.color,
    required this.fontSize,
    required this.strokeWidth,
    required this.textAlign,
    required this.font,
  });

  final String name;
  final List<Object?> args;
  final Color color;
  final double fontSize;
  final double strokeWidth;
  final TextAlign textAlign;
  final Font font;

  @override
  String toString() => '$name(${args.join(', ')})';
}

/// Stands in for `createTestDateFormatter()`, which returns
/// `JavaLocalDateFormatter(Locale.US)` on the JVM.
class TestDateFormatter implements LocalDateFormatter {
  static const List<String> _shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _longMonths = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> _shortWeekdays = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', //
  ];

  static const List<String> _longWeekdays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', //
    'Thursday', 'Friday', 'Saturday',
  ];

  @override
  String shortWeekdayNameOf(DayOfWeek weekday) =>
      _shortWeekdays[weekday.daysSinceSunday];

  @override
  String shortWeekdayName(LocalDate date) => shortWeekdayNameOf(date.dayOfWeek);

  @override
  String shortMonthName(LocalDate date) => _shortMonths[date.month - 1];

  @override
  String longWeekdayNameOf(DayOfWeek weekday) =>
      _longWeekdays[weekday.daysSinceSunday];

  @override
  String longMonthName(LocalDate date) => _longMonths[date.month - 1];
}
