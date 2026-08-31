/// How a day carrying a value is coloured.
///
/// The original knows two answers for a numerical day — met the target, or did
/// not — and a habit whose value IS a percentage loses everything it measures
/// to that pair. A day may carry a shade instead; this covers what the shade
/// does and, more importantly, what it must never do.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/canvas.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart';

import 'history_chart_test.dart' show CanvasOp, RecordingCanvas, TestDateFormatter;

/// The colour the one interesting cell was filled with.
///
/// The chart draws a whole grid, and every cell past the end of the series
/// takes [Square.off]. The fixtures below carry a single square, so exactly
/// one cell can differ from that background of empty days — and that is the
/// one under test. Found by difference rather than by position, because the
/// grid's geometry is a separate rule with its own tests.
Color fillFor({
  required Theme theme,
  required List<Square> series,
  required List<double?> intensities,
}) {
  final HistoryChart chart = HistoryChart(
    dateFormatter: const TestDateFormatter(),
    firstWeekday: DayOfWeek.sunday,
    paletteColor: const PaletteColor(7),
    series: series,
    defaultSquare: Square.off,
    notesIndicators: List<bool>.filled(series.length, false),
    intensities: intensities,
    theme: theme,
    today: LocalDate.ymd(2015, 1, 25),
  );

  final RecordingCanvas canvas = RecordingCanvas();
  chart.draw(canvas);

  final List<CanvasOp> ops = canvas.ops;
  final Color empty = theme.lowContrastTextColor;
  for (int i = 0; i < ops.length; i++) {
    if (ops[i].name != 'fillRoundRect') continue;
    for (int j = i - 1; j >= 0; j--) {
      if (ops[j].name != 'setColor') continue;
      if (ops[j].color != empty) return ops[j].color;
      break;
    }
  }
  return empty;
}

double distance(Color a, Color b) {
  final double dr = a.red - b.red;
  final double dg = a.green - b.green;
  final double db = a.blue - b.blue;
  return dr * dr + dg * dg + db * db;
}

void main() {
  for (final (String name, Theme theme) in <(String, Theme)>[
    ('light', LightTheme()),
    ('dark', DarkTheme()),
  ]) {
    group('on the $name theme', () {
      final Color habit = theme.color(const PaletteColor(7).paletteIndex);
      final Color empty = theme.lowContrastTextColor;

      test('a day with nothing in it keeps the colour it always had', () {
        expect(
          fillFor(
            theme: theme,
            series: <Square>[Square.off],
            intensities: <double>[0],
          ),
          empty,
          reason: 'sleep.calendar#3',
        );
      });

      test('the worst recorded day is nearer the habit colour than to empty',
          () {
        // The whole point on a dark theme: a recorded day must never read as
        // untouched. It used to be blended towards the card background, which
        // on dark is darker than the empty-day grey, so a bad night came out
        // fainter than a day nobody had touched.
        final Color worst = fillFor(
          theme: theme,
          series: <Square>[Square.grey],
          intensities: <double>[0],
        );
        expect(worst, isNot(empty), reason: 'sleep.calendar#3');
        expect(distance(worst, theme.cardBackgroundColor),
            greaterThan(distance(empty, theme.cardBackgroundColor)),
            reason: 'sleep.calendar#3 — and it stands further off the card '
                'than the empty day does, on either theme');
      });

      test('a perfect day is the habit colour exactly', () {
        expect(
          fillFor(
            theme: theme,
            series: <Square>[Square.on],
            intensities: <double>[1],
          ),
          habit,
          reason: 'sleep.calendar#3',
        );
      });

      test('a better day is always nearer the habit colour', () {
        double previous = double.infinity;
        for (final double i in <double>[0, 0.25, 0.5, 0.75, 1]) {
          final Color c = fillFor(
            theme: theme,
            series: <Square>[Square.grey],
            intensities: <double>[i],
          );
          final double d = distance(c, habit);
          expect(d, lessThan(previous), reason: 'sleep.calendar#3 — at $i');
          previous = d;
        }
      });
    });
  }

  test('without intensities nothing about the original changes', () {
    final Theme theme = DarkTheme();
    expect(
      fillFor(
        theme: theme,
        series: <Square>[Square.grey],
        intensities: const <double>[],
      ),
      theme.mediumContrastTextColor,
      reason: 'sleep.calendar#3 — every habit the original knows is untouched',
    );
  });

  test('a day carrying null keeps its plain colour even inside a shaded list',
      () {
    // Abstinence fills a shade for every day but a lapse, where the list
    // carries `null` at that one offset. A lapse is `Square.grey`, the very
    // value the blend above reaches for — so this is the one case the blend
    // must decline, not merely a day nobody happened to ask about.
    final Theme theme = DarkTheme();
    expect(
      fillFor(
        theme: theme,
        series: <Square>[Square.grey],
        intensities: const <double?>[null],
      ),
      theme.mediumContrastTextColor,
      reason: 'computed.abstinence-cell#2 — a lapse carries no shade of its '
          'own, so it stays the flat contrast60 the original always painted '
          'it, not a blend towards the habit colour',
    );
  });
}
