import 'dart:math' as math;

import '../../gui/canvas.dart';
import '../../gui/color.dart';
import '../../gui/theme.dart';
import '../../gui/view.dart';
import '../../io/printf.dart';
import '../../time/local_date.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/BarChart.kt.
///
/// The bar/history card of the show-habit screen. One column per period, one
/// bar per series inside the column, value labels above the bars, a horizontal
/// major grid behind them and a date axis in the footer.
///
/// The chart is laid out from the right: column 0 is the leftmost one but shows
/// the *oldest* datum on screen, and the newest datum is always flush against
/// the right edge — see [dataOffset], which scrolls the window into the past.
///
/// Every number crossing [Canvas] is in logical units.
class BarChart extends DataView {
  BarChart(this.theme, this.dateFormatter);

  Theme theme;
  LocalDateFormatter dateFormatter;

  // Data
  List<List<double>> series = <List<double>>[];
  List<Color> colors = <Color>[];
  List<LocalDate> axis = <LocalDate>[];

  @override
  int dataOffset = 0;

  // Style
  double paddingTop = 20.0;
  double paddingLeft = 0.0;
  double paddingRight = 0.0;
  double footerHeight = 40.0;
  double barGroupMargin = 4.0;
  double barMargin = 3.0;
  double barWidth = 12.0;
  int nGridlines = 6;

  @override
  double get dataColumnWidth => barWidth + barMargin * 2;

  @override
  void draw(Canvas canvas) {
    final width = canvas.getWidth();
    final height = canvas.getHeight();

    final nSeries = series.length;
    final barGroupWidth =
        2 * barGroupMargin + nSeries * (barWidth + 2 * barMargin);
    final safeWidth = width - paddingLeft - paddingRight;
    final nColumns = (safeWidth / barGroupWidth).floor();
    final marginLeft = (safeWidth - nColumns * barGroupWidth) / 2;
    final maxBarHeight = height - footerHeight - paddingTop;
    // Kotlin: `series.map { it.maxOrNull()!! }.maxOrNull()!!`. Both `!!` throw
    // on an empty list — an upstream crash, reproduced here as Dart's null
    // check operator, which throws TypeError.
    var maxValue = _maxOrNull(series.map((it) => _maxOrNull(it)!).toList())!;
    maxValue = math.max(maxValue, 1.0);

    canvas.setColor(theme.cardBackgroundColor);
    canvas.fill();

    double barGroupOffset(int c) =>
        marginLeft + paddingLeft + c * barGroupWidth;

    double barOffset(int c, int s) =>
        barGroupOffset(c) +
        barGroupMargin +
        s * (barWidth + 2 * barMargin) +
        barMargin;

    void drawColumn(int s, int c) {
      final dataColumn = nColumns - c - 1 + dataOffset;
      final double value;
      if (dataColumn < 0 || dataColumn >= series[s].length) {
        value = 0.0;
      } else {
        value = series[s][dataColumn];
      }
      if (value <= 0) return;
      final perc = value / maxValue;
      final barHeight = _round(maxBarHeight * perc);
      final x = barOffset(c, s);
      final y = height - footerHeight - barHeight;
      canvas.setColor(colors[s]);
      final r = _round(barWidth * 0.15);
      if (2 * r < barHeight) {
        canvas.fillRect(x, y + r, barWidth, barHeight - r);
        canvas.fillRect(x + r, y, barWidth - 2 * r, r + 1);
        canvas.fillCircle(x + r, y + r, r);
        canvas.fillCircle(x + barWidth - r, y + r, r);
      } else {
        canvas.fillRect(x, y, barWidth, barHeight);
      }
      canvas.setFontSize(theme.smallTextSize);
      canvas.setTextAlign(TextAlign.center);
      canvas.setColor(colors[s]);
      canvas.drawText(
        _toShortString(value),
        x + barWidth / 2,
        y - theme.smallTextSize * 0.80,
      );
    }

    void drawSeries(int s) {
      for (var c = 0; c < nColumns; c++) {
        drawColumn(s, c);
      }
    }

    void drawMajorGrid() {
      canvas.setStrokeWidth(1.0);
      if (nSeries > 1) {
        canvas.setColor(theme.lowContrastTextColor.withAlpha(0.5));
        for (var c = 0; c < nColumns - 1; c++) {
          final x = barGroupOffset(c);
          canvas.drawLine(x, paddingTop, x, paddingTop + maxBarHeight);
        }
      }
      for (var k = 1; k < nGridlines; k++) {
        final pct = 1.0 - (k.toDouble() / (nGridlines - 1));
        final y = paddingTop + maxBarHeight * pct;
        canvas.setColor(theme.lowContrastTextColor);
        canvas.setStrokeWidth(0.5);
        canvas.drawLine(0.0, y, width, y);
      }
    }

    void drawAxis() {
      final y = paddingTop + maxBarHeight;
      canvas.setColor(theme.lowContrastTextColor);
      canvas.drawLine(0.0, y, width, y);
      canvas.setColor(theme.mediumContrastTextColor);
      canvas.setTextAlign(TextAlign.center);
      canvas.setFontSize(theme.smallTextSize);
      var prevMonth = -1;
      var prevYear = -1;
      // The presenter supplies the axis newest-first, so this difference is
      // normally negative and the branch is effectively only taken for an axis
      // with fewer than two entries. Preserved verbatim from the Kotlin.
      final isLargeInterval =
          axis.length < 2 || (axis[0].daysUntil(axis[1]) > 300);

      for (var c = 0; c < nColumns; c++) {
        final x = barGroupOffset(c);
        final dataColumn = nColumns - c - 1 + dataOffset;
        if (dataColumn < 0 || dataColumn >= axis.length) continue;
        final date = axis[dataColumn];
        if (isLargeInterval) {
          canvas.drawText(
            date.year.toString(),
            x + barGroupWidth / 2,
            y + theme.smallTextSize * 1.0,
          );
        } else {
          if (date.month != prevMonth) {
            canvas.drawText(
              dateFormatter.shortMonthName(date),
              x + barGroupWidth / 2,
              y + theme.smallTextSize * 1.0,
            );
          } else {
            canvas.drawText(
              date.day.toString(),
              x + barGroupWidth / 2,
              y + theme.smallTextSize * 1.0,
            );
          }
          if (date.year != prevYear) {
            canvas.drawText(
              date.year.toString(),
              x + barGroupWidth / 2,
              y + theme.smallTextSize * 2.3,
            );
          }
        }
        prevMonth = date.month;
        prevYear = date.year;
      }
    }

    drawMajorGrid();
    for (var k = 0; k < nSeries; k++) {
      drawSeries(k);
    }
    drawAxis();
  }
}

/// Kotlin `Iterable<Double>.maxOrNull()`.
double? _maxOrNull(List<double> values) =>
    values.isEmpty ? null : values.reduce(math.max);

/// Kotlin `kotlin.math.round`, which is `Math.rint` on the JVM: nearest
/// integer, ties rounded towards the *even* one. Dart's `roundToDouble()`
/// rounds ties away from zero instead, which would move a bar by one logical
/// unit whenever `maxBarHeight * perc` lands exactly on a half.
double _round(double x) {
  final floor = x.floorToDouble();
  final diff = x - floor;
  if (diff > 0.5) return floor + 1.0;
  if (diff < 0.5) return floor;
  return floor % 2 == 0 ? floor : floor + 1.0;
}

/// Port of `fun Double.toShortString()` from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/NumberButton.kt.
///
/// It is declared next to NumberButton upstream but used by BarChart's value
/// labels too. This copy is private to keep the slice self-contained; the
/// NumberButton port owns the public one.
String _toShortString(double v) {
  if (v >= 1e9) return format('%.1fG', v / 1e9);
  if (v >= 1e8) return format('%.0fM', v / 1e6);
  if (v >= 1e7) return format('%.1fM', v / 1e6);
  if (v >= 1e6) return format('%.1fM', v / 1e6);
  if (v >= 1e5) return format('%.0fk', v / 1e3);
  if (v >= 1e4) return format('%.1fk', v / 1e3);
  if (v >= 1e3) return format('%.1fk', v / 1e3);
  if (v >= 1e2) return format('%.0f', v);
  if (v >= 1e1) {
    return _round(v) == v ? format('%.0f', v) : format('%.1f', v);
  }
  if (_round(v) == v) return format('%.0f', v);
  if (_round(v * 10) == v * 10) return format('%.1f', v);
  return format('%.2f', v);
}
