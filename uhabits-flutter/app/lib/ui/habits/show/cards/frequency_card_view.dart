/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/FrequencyCardView.kt,
/// the chart it hosts
/// (uhabits-android/.../activities/common/views/FrequencyChart.kt) and
/// res/layout/show_habit_frequency.xml.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/frequency_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';
import '../../../common/scrollable_chart.dart';
import '../../list/list_header.dart' show IntlLocalDateFormatter;
import 'score_card_view.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/views/frequency_card.dart'
    show FrequencyCardPresenter, FrequencyCardState;

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/FrequencyChart.kt.
///
/// One column per calendar month, seven weekday rows plus a footer row, and a
/// bubble in each cell whose radius grows with how often the habit was
/// performed on that weekday that month.
///
/// The two substitutions the core [core.Canvas] forces are the same as
/// everywhere else in this slice: `paint.fontSpacing` becomes
/// [chartFontSpacing] times the text size, and baselines go through
/// [chartTextCenter]. `drawCircle` maps straight onto
/// [core.Canvas.fillCircle], and the four-entry colour ramp is mixed with the
/// ported [core.ColorUtils.mixColors] so it matches Android channel for
/// channel.
///
/// Two upstream details worth naming, because they are easy to mistake for
/// bugs:
///
///  * only `nColumns - 1` months are drawn. The rightmost column's width is
///    spent on the weekday names;
///  * the month name under a column is centred on the first `baseSize` of that
///    column rather than on the column itself, because `drawColumn` reuses the
///    same `RectF` for its cells and hands the last, `baseSize`-wide one to
///    `drawFooter`. When the month names are wider than `baseSize` the column
///    is wider too, and the label sits left of centre.
class FrequencyChartView extends core.DataView {
  FrequencyChartView({
    required this.frequency,
    required this.color,
    required this.theme,
    required this.dateFormatter,
    required this.firstWeekday,
    required this.isNumerical,
    this.dataOffset = 0,
    core.LocalDate? today,
  }) : _today = today;

  /// Keyed by the first day of the month; the value is a 7-element histogram
  /// indexed `(dayOfWeek.daysSinceSunday + 1) % 7`, i.e. Saturday first.
  final Map<core.LocalDate, List<int>> frequency;

  final core.Color color;

  final core.Theme theme;

  final core.LocalDateFormatter dateFormatter;

  final core.DayOfWeek firstWeekday;

  final bool isNumerical;

  /// Months scrolled into the past, written back by the host on every scroll
  /// (`show-habit.chart-scrolling#2`). `FrequencyChart` never resets its
  /// scroll on refresh, so the position survives a new state
  /// (`show-habit.chart-scrolling#6`).
  @override
  int dataOffset;

  /// `setScrollerBucketSize(baseSize)`, one month per `height / 8`.
  ///
  /// Android computes it in `onSizeChanged`, before anything is drawn; the port
  /// has no size callback, so the value is remembered as [draw] works it out
  /// and a chart that has never been painted reports 0 — which the host reads
  /// as "nothing to scroll yet".
  @override
  double get dataColumnWidth => _dataColumnWidth;

  double _dataColumnWidth = 0.0;

  final core.LocalDate? _today;

  @override
  void draw(core.Canvas canvas) {
    final width = canvas.getWidth();
    var height = canvas.getHeight();
    // onSizeChanged: `if (height < 9) height = 200`.
    if (height < 9) height = 200.0;
    final baseSize = height ~/ 8;
    // `setScrollerBucketSize(baseSize)`, the second statement of
    // onSizeChanged: the bucket is a month, and a month is baseSize wide.
    _dataColumnWidth = baseSize.toDouble();
    if (baseSize <= 0 || width <= 0) return;

    final textSize = baseSize * 0.4;
    canvas.setFontSize(textSize);
    final em = textSize * chartFontSpacing;
    final columnWidth =
        math.max(baseSize.toDouble(), _maxMonthWidth(canvas) * 1.2);
    final columnHeight = 8 * baseSize;
    final nColumns = (width / columnWidth).toInt();
    if (nColumns <= 0) return;

    final maxFreq = _maxFreq();
    final ramp = _colorRamp();
    final weekdays = core.getWeekdaySequence(firstWeekday);

    _drawGrid(canvas, nColumns * columnWidth, columnHeight.toDouble(),
        columnWidth, weekdays, em, textSize);

    final today = _today ?? core.getToday();
    var currentDate = core.LocalDate.ymd(today.year, today.month, 1);
    currentDate = _stepMonth(currentDate, -nColumns + 2 - dataOffset);
    for (var i = 0; i < nColumns - 1; i++) {
      _drawColumn(canvas, i * columnWidth, baseSize, currentDate, weekdays,
          maxFreq, ramp, em, textSize);
      currentDate = _stepMonth(currentDate, 1);
    }
  }

  /// `drawGrid`: seven weekday labels down the rightmost column, a hairline
  /// above each row and one more under the last.
  void _drawGrid(
    core.Canvas canvas,
    double right,
    double chartHeight,
    double columnWidth,
    List<core.DayOfWeek> weekdays,
    double em,
    double textSize,
  ) {
    const nRows = 7;
    final rowHeight = chartHeight / (nRows + 1);
    var top = 0.0;
    canvas.setTextAlign(core.TextAlign.left);
    for (final weekday in weekdays) {
      canvas.setColor(theme.mediumContrastTextColor);
      canvas.drawText(
        dateFormatter.shortWeekdayNameOf(weekday),
        right - columnWidth,
        chartTextCenter(top + rowHeight / 2 + 0.25 * em, textSize),
      );
      canvas.setColor(theme.lowContrastTextColor);
      // `pGrid.strokeWidth = 1f`, overriding what onSizeChanged computed.
      canvas.setStrokeWidth(1.0);
      canvas.drawLine(0.0, top, right, top);
      top += rowHeight;
    }
    canvas.setColor(theme.lowContrastTextColor);
    canvas.setStrokeWidth(1.0);
    canvas.drawLine(0.0, top, right, top);
  }

  void _drawColumn(
    core.Canvas canvas,
    double left,
    int baseSize,
    core.LocalDate date,
    List<core.DayOfWeek> weekdays,
    int maxFreq,
    List<core.Color> ramp,
    double em,
    double textSize,
  ) {
    final values = frequency[date];
    final weekDaysInMonth = core.countWeekdayOccurrencesInMonth(date);
    // `rect.height() / 8.0f` over the 8 * baseSize column: exactly baseSize.
    final rowHeight = baseSize.toDouble();
    final cx = left + baseSize / 2.0;

    for (var j = 0; j < weekdays.length; j++) {
      final cellTop = baseSize * j.toDouble();
      final index = (weekdays[j].daysSinceSunday + 1) % 7;
      if (values != null) {
        _drawMarker(
          canvas,
          cx,
          cellTop + baseSize / 2.0,
          baseSize.toDouble(),
          values[index],
          weekDaysInMonth[index],
          maxFreq,
          ramp,
        );
      }
    }

    // drawFooter, against the cell the loop left behind: one row further down
    // and still only baseSize wide.
    final footerCy = baseSize * 6.0 + rowHeight + baseSize / 2.0;
    canvas.setColor(theme.mediumContrastTextColor);
    canvas.setTextAlign(core.TextAlign.center);
    canvas.drawText(
      dateFormatter.shortMonthName(date),
      cx,
      chartTextCenter(footerCy - 0.1 * em, textSize),
    );
    if (date.month == 2) {
      canvas.drawText(
        date.year.toString(),
        cx,
        chartTextCenter(footerCy + 0.9 * em, textSize),
      );
    }
  }

  void _drawMarker(
    core.Canvas canvas,
    double cx,
    double cy,
    double cellHeight,
    int rawValue,
    int weekdayFrequency,
    int maxFreq,
    List<core.Color> ramp,
  ) {
    // A skipped entry stores a negative value; it counts as zero.
    final value = math.max(0, rawValue);
    final padding = cellHeight * 0.2;
    final maxRadius = (cellHeight - 2 * padding) / 2.0;
    final scalingFactor = isNumerical ? maxFreq : weekdayFrequency;
    if (scalingFactor <= 0) return;
    final scale = 1.0 / scalingFactor * value;
    final radius = maxRadius * scale;
    final colorIndex =
        math.min(ramp.length - 1, ((ramp.length - 1) * scale).round());
    canvas.setColor(ramp[colorIndex]);
    canvas.fillCircle(cx, cy, radius);
  }

  /// `initColors`: [contrast20, mix(contrast20, habit, 0.66),
  /// mix(contrast20, habit, 0.33), habit].
  ///
  /// `ColorUtils.mixColors(a, b, amount)` weights `a`, so index 1 is mostly
  /// grid colour and index 2 mostly habit colour. It blends packed ARGB with
  /// 32-bit float arithmetic and truncation, which is why the ported
  /// [core.ColorUtils] is used rather than [core.Color.blendWith].
  List<core.Color> _colorRamp() {
    final grid = theme.lowContrastTextColor;
    final mix1 =
        core.ColorUtils.mixColors(grid.toInt(), color.toInt(), 0.66);
    final mix2 =
        core.ColorUtils.mixColors(grid.toInt(), color.toInt(), 0.33);
    return <core.Color>[
      grid,
      core.Color.fromRgb(mix1),
      core.Color.fromRgb(mix2),
      color,
    ];
  }

  /// `getMaxFreq`: the largest count anywhere in the map, floored at 1.
  int _maxFreq() {
    var maxValue = 1;
    for (final values in frequency.values) {
      for (final value in values) {
        maxValue = math.max(value, maxValue);
      }
    }
    return maxValue;
  }

  double _maxMonthWidth(core.Canvas canvas) {
    var maxWidth = 0.0;
    for (var i = 1; i <= 12; i++) {
      final name = dateFormatter.shortMonthName(core.LocalDate.ymd(2020, i, 1));
      maxWidth = math.max(maxWidth, canvas.measureText(name));
    }
    return maxWidth;
  }

  /// ```kotlin
  /// fun populateWithRandomData() {
  ///     val today = getToday()
  ///     var date = LocalDate(today.year, today.month, 1)
  ///     val rand = Random()
  ///     frequency.clear()
  ///     for (i in 0..39) {
  ///         val values = IntArray(7) { rand.nextInt(5) }.toTypedArray()
  ///         frequency[date] = values
  ///         date = stepMonth(date, -1)
  ///     }
  ///     maxFreq = getMaxFreq(frequency)
  /// }
  /// ```
  ///
  /// Forty consecutive months walking backwards from the current one, each
  /// with seven random values in 0..4
  /// (`charts-canvas-theming.frequency-chart#14`). The Dart view takes its
  /// map in the constructor rather than owning one, so this returns the map
  /// the Kotlin would have installed; `maxFreq` is derived on every draw here,
  /// so there is nothing else to update.
  static Map<core.LocalDate, List<int>> populateWithRandomData({
    math.Random? random,
  }) {
    final rand = random ?? math.Random();
    final today = core.getToday();
    var date = core.LocalDate.ymd(today.year, today.month, 1);
    final frequency = <core.LocalDate, List<int>>{};
    for (var i = 0; i <= 39; i++) {
      frequency[date] = <int>[
        for (var j = 0; j < 7; j++) rand.nextInt(5),
      ];
      date = _stepMonth(date, -1);
    }
    return frequency;
  }
}

/// `stepMonth`: month arithmetic that wraps the year and always lands on the
/// first of the month.
core.LocalDate _stepMonth(core.LocalDate date, int months) {
  var year = date.year;
  var month = date.month + months;
  while (month < 1) {
    month += 12;
    year -= 1;
  }
  while (month > 12) {
    month -= 12;
    year += 1;
  }
  return core.LocalDate.ymd(year, month, 1);
}

/// The Frequency card: a title and a 200dp [FrequencyChartView] inside its
/// scroller.
///
/// `show_habit_frequency.xml` gives `@+id/frequencyChart` as a
/// `FrequencyChart`, which *is* a `ScrollableChart`: a horizontal drag walks
/// the chart backwards a month at a time
/// (`show-habit.chart-scrolling#2`,
/// `audit3.charts-on-the-habit-detail-screen#1`).
///
/// Nothing here ever calls `reset()` — `FrequencyCardView.setState` does not,
/// and that is the whole of `show-habit.chart-scrolling#6`. The scroll position
/// therefore survives a refresh, which is what keeping the [ScrollableChart]
/// state across rebuilds gives for free.
class FrequencyCardView extends StatelessWidget {
  const FrequencyCardView({
    required this.state,
    this.dateFormatter,
    this.dataOffset = 0,
    this.today,
    super.key,
  });

  /// show_habit_frequency.xml: `android:layout_height="200dp"`.
  static const double chartHeight = 200.0;

  final FrequencyCardState state;

  final core.LocalDateFormatter? dateFormatter;

  /// The month the chart opens on, before anything is dragged.
  ///
  /// Nothing resets this card, so the offset the scroller reaches is the one it
  /// keeps (`show-habit.chart-scrolling#6`); the screen opens on the newest
  /// month.
  final int dataOffset;

  /// The chart reads `getToday()` itself upstream; an explicit date is only
  /// useful to tests and to a midnight tick.
  final core.LocalDate? today;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ChartCard(
      theme: state.theme,
      title: l10n.frequency,
      titleColor: state.theme.colorOf(state.color),
      child: SizedBox(
        height: chartHeight,
        width: double.infinity,
        child: ScrollableChart(
          view: FrequencyChartView(
            frequency: state.frequency,
            color: state.theme.colorOf(state.color),
            theme: state.theme,
            dateFormatter: dateFormatter ?? IntlLocalDateFormatter.of(context),
            firstWeekday: state.firstWeekday,
            isNumerical: state.isNumerical,
            dataOffset: dataOffset,
            today: today,
          ),
          initialDataOffset: dataOffset,
        ),
      ),
    );
  }
}
