/// How strongly a night colours its day in the calendar.
///
/// The original knows two answers for a numerical day: the habit's colour when
/// the target was met, one flat grey when it was not. A sleep habit's value is
/// a percentage, so that throws away everything it measures.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/stored_value.dart';

/// A day that scored [percent].
int valueAt(double percent) => (percent / 100 * maxStoredValue).round();

void main() {
  group('the shape of the scale', () {
    test('nothing recorded colours nothing', () {
      expect(cellIntensityOf(0), 0, reason: 'sleep.calendar#1');
      expect(cellIntensityOf(-1), 0, reason: 'sleep.calendar#1');
    });

    test('a perfect night is the habit colour undiluted', () {
      expect(cellIntensityOf(maxStoredValue), 1.0, reason: 'sleep.calendar#1');
    });

    test('it never leaves the unit range', () {
      for (double p = 0; p <= 100; p += 0.5) {
        final double i = cellIntensityOf(valueAt(p));
        expect(i, inInclusiveRange(0, 1), reason: 'sleep.calendar#1 — at $p%');
      }
      expect(cellIntensityOf(maxStoredValue * 10), 1.0,
          reason: 'sleep.calendar#1 — a value above the maximum still fits');
    });

    test('a better night is never paler than a worse one', () {
      double previous = -1;
      for (double p = 0.1; p <= 100; p += 0.1) {
        final double i = cellIntensityOf(valueAt(p));
        expect(i, greaterThanOrEqualTo(previous),
            reason: 'sleep.calendar#1 — at $p%');
        previous = i;
      }
    });
  });

  group('where the range is spent', () {
    test('the bottom half of the percentage gets a sixth of the range', () {
      // Everything under it is a bad night, and the eye gains nothing from
      // telling one bad night from another.
      expect(cellIntensityOf(valueAt(dimmedBelowPercent)), closeTo(0.25, 1e-9),
          reason: 'sleep.calendar#2');
      expect(cellIntensityOf(valueAt(10)), lessThan(0.13),
          reason: 'sleep.calendar#2');
      expect(cellIntensityOf(valueAt(30)) - cellIntensityOf(valueAt(10)),
          lessThan(0.08),
          reason: 'sleep.calendar#2 — two bad nights look alike');
    });

    test('the range people actually sleep in is where the scale spends itself',
        () {
      // The point of the whole exercise: 70 and 90 have to be plainly
      // different shades, because that is the difference a person is working
      // on.
      final double at70 = cellIntensityOf(valueAt(70));
      final double at90 = cellIntensityOf(valueAt(90));
      expect(at90 - at70, greaterThan(0.25), reason: 'sleep.calendar#2');
      expect(at90 - at70,
          greaterThan(cellIntensityOf(valueAt(30)) - cellIntensityOf(valueAt(10))),
          reason: 'sleep.calendar#2 — and more different than two bad nights');
    });

    test('the two halves meet without a step', () {
      final double justBelow = cellIntensityOf(valueAt(dimmedBelowPercent - 0.01));
      final double justAbove = cellIntensityOf(valueAt(dimmedBelowPercent + 0.01));
      expect((justAbove - justBelow).abs(), lessThan(0.01),
          reason: 'sleep.calendar#1 — a joint the eye can find is a bug');
    });
  });

  group('the values the table was drawn from', () {
    // The numbers shown when the scale was chosen. If any of these move, the
    // picture someone approved is not the picture they get.
    // A double is not a map key with primitive equality, so these travel as
    // pairs.
    const List<(double, double)> expected = <(double, double)>[
      (20, 0.148),
      (40, 0.216),
      (60, 0.400),
      (75, 0.625),
      (85, 0.775),
      (95, 0.925),
      (100, 1.000),
    ];

    for (final (double percent, double intensity) in expected) {
      test('$percent% is $intensity', () {
        expect(cellIntensityOf(valueAt(percent)), closeTo(intensity, 5e-4),
            reason: 'sleep.calendar#2');
      });
    }
  });
}
