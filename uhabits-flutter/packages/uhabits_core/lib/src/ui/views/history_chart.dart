import 'dart:math' as math;

import '../../gui/canvas.dart';
import '../../gui/color.dart';
import '../../gui/theme.dart';
import '../../gui/view.dart';
import '../../models/palette_color.dart';
import '../../time/local_date.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HistoryChart.kt.
///
/// The calendar grid on the habit screen: one header row carrying month and
/// year labels, then seven weekday rows, with the newest week flush against
/// the right-hand edge and a gutter of weekday names to the right of that.

/// Kotlin: `interface OnDateClickedListener`, whose two members both have
/// empty default bodies. Extend it (rather than implement it) to inherit those
/// defaults, exactly as a Kotlin implementor does.
abstract class OnDateClickedListener {
  const OnDateClickedListener();

  void onDateShortPress(LocalDate date) {}

  void onDateLongPress(LocalDate date) {}
}

/// Kotlin: `object : OnDateClickedListener {}`, the default argument of
/// [HistoryChart.onDateClickedListener].
class _NoOpOnDateClickedListener extends OnDateClickedListener {
  const _NoOpOnDateClickedListener();
}

/// Kotlin: `HistoryChart.Square`. Dart cannot nest an enum inside a class, so
/// it lives beside [HistoryChart]; the five values keep their ordinals.
enum Square { on, off, grey, dimmed, hatched }

class HistoryChart extends DataView {
  HistoryChart({
    required this.dateFormatter,
    required this.firstWeekday,
    required this.paletteColor,
    required this.series,
    required this.defaultSquare,
    required this.notesIndicators,
    required this.theme,
    required this.today,
    this.intensities = const <double?>[],
    this.onDateClickedListener = const _NoOpOnDateClickedListener(),
    this.padding = 0.0,
  });

  LocalDateFormatter dateFormatter;
  DayOfWeek firstWeekday;
  PaletteColor paletteColor;
  List<Square> series;
  Square defaultSquare;
  List<bool> notesIndicators;

  /// Not upstream. How strongly each day of [series] is coloured, in `[0, 1]`,
  /// parallel to it and consulted only where a day is [Square.on] or
  /// [Square.grey] — the two the target decides between.
  ///
  /// Empty means "as the original paints it", which is every habit but a sleep
  /// habit. A day can also carry `null` of its own, inside a non-empty list:
  /// that day has no shade regardless of which of the two squares it is, and
  /// paints exactly as [Square.on] or [Square.grey] always did. Abstinence
  /// needs both answers side by side — a lapse is [Square.grey] and stays flat
  /// [Theme.mediumContrastTextColor], never blended towards the habit colour,
  /// while every other day still climbs.
  List<double?> intensities;

  Theme theme;
  LocalDate today;
  OnDateClickedListener onDateClickedListener;
  double padding;

  double squareSpacing = 1.0;

  @override
  int dataOffset = 0;

  double _squareSize = 0.0;
  double _width = 0.0;
  double _height = 0.0;
  int _nColumns = 0;
  int _topLeftOffset = 0;
  LocalDate _topLeftDate = LocalDate.ymd(2020, 1, 1);
  String _lastPrintedMonth = '';
  String _lastPrintedYear = '';
  double _headerOverflow = 0.0;

  @override
  double get dataColumnWidth => squareSpacing + _squareSize;

  @override
  void onClick(double x, double y) {
    _onDateClicked(x, y, false);
  }

  @override
  void onLongClick(double x, double y) {
    _onDateClicked(x, y, true);
  }

  void _onDateClicked(double x, double y, bool isLongClick) {
    if (_width <= 0.0) {
      // Kotlin: IllegalStateException.
      throw StateError('onClick must be called after draw(canvas)');
    }
    final col = ((x - padding) / _squareSize).toInt();
    final row = ((y - padding) / _squareSize).toInt();
    final offset = col * 7 + (row - 1);
    if (x - padding < 0 || row == 0 || row > 7 || col == _nColumns) return;
    final clickedDate = _topLeftDate.plus(offset);
    if (clickedDate.isNewerThan(today)) return;
    _lastClickedDate = clickedDate;
    if (isLongClick) {
      onDateClickedListener.onDateLongPress(clickedDate);
    } else {
      onDateClickedListener.onDateShortPress(clickedDate);
    }
  }

  LocalDate? _lastClickedDate;

  /// The square the person last pressed, or null before any press.
  ///
  /// Recorded because a caller can need the date after the press has been
  /// dispatched: `onDateClickedListener` is a fixed object that a port must not
  /// substitute, and the presenter it leads to passes a value onwards without
  /// the day it belongs to.
  LocalDate? get lastClickedDate => _lastClickedDate;

  @override
  void draw(Canvas canvas) {
    _width = canvas.getWidth();
    _height = canvas.getHeight();

    canvas.setColor(theme.cardBackgroundColor);
    canvas.fill();

    _squareSize = _round((_height - 2 * padding) / 8.0);
    canvas.setFontSize(math.min(14.0, _height * 0.06));

    // Kotlin: DayOfWeek.values().map { ... }.maxOrNull() ?: 0.0
    double? maxWeekdayWidth;
    for (final weekday in DayOfWeek.values) {
      final width =
          canvas.measureText(dateFormatter.shortWeekdayNameOf(weekday)) +
              _squareSize * 0.15;
      if (maxWeekdayWidth == null || width > maxWeekdayWidth) {
        maxWeekdayWidth = width;
      }
    }
    final weekdayColumnWidth = maxWeekdayWidth ?? 0.0;

    _nColumns = ((_width - 2 * padding - weekdayColumnWidth) / _squareSize)
        .floorToDouble()
        .toInt();
    final firstWeekdayOffset =
        (today.dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday + 7) % 7;
    _topLeftOffset = (_nColumns - 1 + dataOffset) * 7 + firstWeekdayOffset;
    _topLeftDate = today.minus(_topLeftOffset);

    _lastPrintedYear = '';
    _lastPrintedMonth = '';
    _headerOverflow = 0.0;

    // Draw main columns
    for (var column = 0; column < _nColumns; column++) {
      final topOffset = _topLeftOffset - 7 * column;
      final topDate = _topLeftDate.plus(7 * column);
      _drawColumn(canvas, column, topDate, topOffset);
    }

    // Draw week day names
    canvas.setColor(theme.mediumContrastTextColor);
    for (var row = 0; row < 7; row++) {
      final date = _topLeftDate.plus(row);
      canvas.setTextAlign(TextAlign.left);
      canvas.drawText(
        dateFormatter.shortWeekdayName(date),
        padding + _nColumns * _squareSize + _squareSize * 0.15,
        padding + _squareSize * (row + 1) + _squareSize / 2,
      );
    }
  }

  void _drawColumn(
    Canvas canvas,
    int column,
    LocalDate topDate,
    int topOffset,
  ) {
    _drawHeader(canvas, column, topDate);
    for (var row = 0; row < 7; row++) {
      final offset = topOffset - row;
      final date = topDate.plus(row);
      // Kotlin returns out of drawColumn from inside the repeat lambda, which
      // abandons the whole remainder of the column.
      if (offset < 0) return;
      _drawSquare(
        canvas,
        padding + column * _squareSize,
        padding + (row + 1) * _squareSize,
        _squareSize - squareSpacing,
        _squareSize - squareSpacing,
        date,
        offset,
      );
    }
  }

  void _drawHeader(Canvas canvas, int column, LocalDate date) {
    canvas.setColor(theme.mediumContrastTextColor);
    final monthText = dateFormatter.shortMonthName(date);
    final yearText = date.year.toString();
    final String headerText;
    if (monthText != _lastPrintedMonth) {
      headerText = monthText;
      _lastPrintedMonth = monthText;
    } else if (yearText != _lastPrintedYear) {
      headerText = yearText;
      _lastPrintedYear = headerText;
    } else {
      headerText = '';
    }
    canvas.setTextAlign(TextAlign.left);
    canvas.drawText(
      headerText,
      _headerOverflow + padding + column * _squareSize,
      padding + _squareSize / 2,
    );

    _headerOverflow += canvas.measureText(headerText) + 0.1 * _squareSize;
    _headerOverflow = math.max(0.0, _headerOverflow - _squareSize);
  }

  /// How far towards the habit's colour a day with the worst possible value
  /// still travels.
  ///
  /// Not zero: the person recorded that day, and a day that reads as untouched
  /// hides the very thing the shade was added to show.
  static const double recordedFloor = 0.3;

  /// The original's five answers, plus a shade for a day that carries one.
  ///
  /// The shade replaces only [Square.on] and [Square.grey]: those are the two
  /// the target decides between, and they are the pair that throws away a
  /// percentage. Skipped, unknown and automatic days keep the appearance they
  /// have everywhere else in the app, because their meaning is not a quantity.
  Color _squareColor(Square value, Color color, int offset) {
    final double? intensity =
        offset < intensities.length ? intensities[offset] : null;
    if (intensity != null &&
        (value == Square.on || value == Square.grey)) {
      // From the colour of a day with nothing in it towards the habit's own,
      // never the other way. Blending towards the card background reads as
      // "no data" on a dark theme, where the background is darker than the
      // empty-day grey — so a badly kept day came out fainter than a day the
      // person never touched, which is exactly backwards. A recorded day
      // starts at [recordedFloor] of the way to the habit colour, so the worst
      // of them is still plainly the habit's colour and plainly recorded.
      return theme.lowContrastTextColor.blendWith(
        color,
        recordedFloor + (1 - recordedFloor) * intensity,
      );
    }
    return switch (value) {
      Square.on => color,
      Square.off => theme.lowContrastTextColor,
      Square.grey => theme.mediumContrastTextColor,
      Square.dimmed ||
      Square.hatched =>
        color.blendWith(theme.cardBackgroundColor, 0.5),
    };
  }

  void _drawSquare(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    LocalDate date,
    int offset,
  ) {
    final value = offset >= series.length ? defaultSquare : series[offset];
    final hasNotes =
        offset >= notesIndicators.length ? false : notesIndicators[offset];
    final color = theme.color(paletteColor.paletteIndex);
    final Color squareColor = _squareColor(value, color, offset);

    canvas.setColor(squareColor);
    canvas.fillRoundRect(x, y, width, height, width * 0.15);

    if (value == Square.hatched) {
      canvas.setStrokeWidth(0.75);
      canvas.setColor(theme.cardBackgroundColor);
      var k = width / 10;
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(x + k, y, x, y + k);
        canvas.drawLine(
          x + width - k,
          y + height,
          x + width,
          y + height - k,
        );
        k += width / 5;
      }
    }

    final Color textColor;
    if (theme.cardBackgroundColor == Color.TRANSPARENT) {
      textColor = theme.highContrastTextColor;
    } else {
      final c1 = squareColor.contrast(theme.cardBackgroundColor);
      final c2 = squareColor.contrast(theme.mediumContrastTextColor);
      textColor =
          c1 > c2 ? theme.cardBackgroundColor : theme.mediumContrastTextColor;
    }

    canvas.setColor(textColor);
    canvas.setTextAlign(TextAlign.center);
    // Upstream uses `width` for the vertical centre too; the two are equal for
    // these square cells, so it is kept as is.
    canvas.drawText(date.day.toString(), x + width / 2, y + width / 2);

    if (hasNotes) {
      final Color circleColor = switch (value) {
        Square.on || Square.grey => theme.lowContrastTextColor,
        _ => color,
      };
      canvas.setColor(circleColor);
      canvas.fillCircle(x + width - width / 5, y + width / 5, width / 12);
    }
  }
}

/// `kotlin.math.round`, which delegates to `Math.rint`: the nearest integer,
/// with ties going to the *even* one. Dart's `double.round()` rounds halves
/// away from zero instead, so it cannot stand in here — a 196-tall chart would
/// get a 25-unit square instead of a 24-unit one.
double _round(double x) {
  final floor = x.floorToDouble();
  final fraction = x - floor;
  if (fraction > 0.5) return floor + 1.0;
  if (fraction < 0.5) return floor;
  return floor % 2.0 == 0.0 ? floor : floor + 1.0;
}
