import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/score.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreTest.kt
///
/// The Kotlin test asserts each number to 1e-6, so this port keeps the same
/// epsilon and the same literals.
const double e = 1e-6;

/// The decay multiplier, spelled out independently of the implementation so
/// that the test pins the formula rather than echoing it.
double multiplierOf(double frequency) =>
    pow(0.5, sqrt(frequency) / 13.0).toDouble();

void main() {
  group('models.score-formula', () {
    test('#1 Score is an immutable pair of date and value', () {
      final date = LocalDate.ymd(2015, 1, 25);
      final score = Score(date, 0.5);

      expect(score.date, date, reason: 'models.score-formula#1');
      expect(score.value, 0.5, reason: 'models.score-formula#1');

      // Value semantics: equal components means equal scores.
      expect(Score(LocalDate.ymd(2015, 1, 25), 0.5), score,
          reason: 'models.score-formula#1');
      expect(Score(LocalDate.ymd(2015, 1, 25), 0.5).hashCode, score.hashCode,
          reason: 'models.score-formula#1');
      expect(Score(LocalDate.ymd(2015, 1, 26), 0.5) == score, isFalse,
          reason: 'models.score-formula#1');
      expect(Score(LocalDate.ymd(2015, 1, 25), 0.25) == score, isFalse,
          reason: 'models.score-formula#1');

      // value is a Double, never an int.
      expect(Score(date, 1).value, isA<double>(),
          reason: 'models.score-formula#1');
    });

    test('#2 compute is previousScore * m + checkmarkValue * (1 - m)', () {
      for (final frequency in <double>[1.0, 1 / 2, 1 / 3, 3 / 8, 1 / 7, 1 / 30]) {
        final m = multiplierOf(frequency);
        for (final previous in <double>[0.0, 0.25, 0.5, 0.75, 1.0]) {
          for (final checkmark in <double>[0.0, 0.5, 1.0]) {
            expect(
              Score.compute(frequency, previous, checkmark),
              closeTo(previous * m + checkmark * (1 - m), 1e-15),
              reason: 'models.score-formula#2',
            );
          }
        }
      }

      // The multiplier itself is observable: previous=1, checkmark=0 leaves m,
      // and previous=0, checkmark=1 leaves 1 - m.
      final m1 = multiplierOf(1.0);
      expect(Score.compute(1.0, 1.0, 0.0), closeTo(m1, 1e-15),
          reason: 'models.score-formula#2');
      expect(Score.compute(1.0, 0.0, 1.0), closeTo(1 - m1, 1e-15),
          reason: 'models.score-formula#2');
    });

    test('#3 frequency is numerator/denominator; 0.5 and 13.0 are the only '
        'constants', () {
      // 3 times per 8 days -> 0.375.
      expect(3.0 / 8.0, 0.375, reason: 'models.score-formula#3');
      expect(Score.compute(3.0 / 8.0, 0.5, 1.0), Score.compute(0.375, 0.5, 1.0),
          reason: 'models.score-formula#3');

      // The multiplier is exactly 0.5 ^ (sqrt(frequency) / 13.0).
      for (final frequency in <double>[1.0, 0.375, 1 / 7, 1 / 30]) {
        expect(Score.compute(frequency, 1.0, 0.0),
            closeTo(pow(0.5, sqrt(frequency) / 13.0).toDouble(), 1e-15),
            reason: 'models.score-formula#3');
      }

      // There is no separate half-life constant: for a daily habit the 13.0
      // divisor *is* the half-life, so 13 days of misses halve the score.
      var score = 1.0;
      for (var i = 0; i < 13; i++) {
        score = Score.compute(1.0, score, 0.0);
      }
      expect(score, closeTo(0.5, 1e-12), reason: 'models.score-formula#3');

      // For a habit repeated 4 times as often, decay is twice as fast
      // (sqrt(4) = 2), which is what makes sqrt the only shaping function.
      expect(multiplierOf(4.0), closeTo(multiplierOf(1.0) * multiplierOf(1.0), 1e-15),
          reason: 'models.score-formula#3');
    });

    test('#4 concrete values for a daily habit', () {
      const freq = 1.0;
      expect(multiplierOf(freq), closeTo(0.948077514, e),
          reason: 'models.score-formula#4');
      expect(1 - multiplierOf(freq), closeTo(0.051922486, e),
          reason: 'models.score-formula#4');

      var check = 1;
      expect(Score.compute(freq, 0.0, check.toDouble()), closeTo(0.051922, e),
          reason: 'models.score-formula#4');
      expect(Score.compute(freq, 0.5, check.toDouble()), closeTo(0.525961, e),
          reason: 'models.score-formula#4');
      expect(Score.compute(freq, 0.75, check.toDouble()), closeTo(0.762981, e),
          reason: 'models.score-formula#4');
      check = 0;
      expect(Score.compute(freq, 0.0, check.toDouble()), closeTo(0.0, e),
          reason: 'models.score-formula#4');
      expect(Score.compute(freq, 0.5, check.toDouble()), closeTo(0.474039, e),
          reason: 'models.score-formula#4');
      expect(Score.compute(freq, 0.75, check.toDouble()), closeTo(0.711058, e),
          reason: 'models.score-formula#4');
    });

    test('#5 concrete values for a non-daily habit (1/3)', () {
      final freq = 1 / 3.0;
      expect(multiplierOf(freq), closeTo(0.969685248, e),
          reason: 'models.score-formula#5');

      var check = 1;
      expect(Score.compute(freq, 0.0, check.toDouble()), closeTo(0.030314, e),
          reason: 'models.score-formula#5');
      expect(Score.compute(freq, 0.5, check.toDouble()), closeTo(0.515157, e),
          reason: 'models.score-formula#5');
      expect(Score.compute(freq, 0.75, check.toDouble()), closeTo(0.757578, e),
          reason: 'models.score-formula#5');
      check = 0;
      expect(Score.compute(freq, 0.0, check.toDouble()), closeTo(0.0, e),
          reason: 'models.score-formula#5');
      expect(Score.compute(freq, 0.5, check.toDouble()), closeTo(0.484842, e),
          reason: 'models.score-formula#5');
      expect(Score.compute(freq, 0.75, check.toDouble()), closeTo(0.727263, e),
          reason: 'models.score-formula#5');
    });

    test('#6 checkmarkValue is a completion fraction, not a raw entry value',
        () {
      const freq = 1.0;

      // Half credit lands exactly halfway between a miss and a full check.
      final miss = Score.compute(freq, 0.4, 0.0);
      final full = Score.compute(freq, 0.4, 1.0);
      expect(Score.compute(freq, 0.4, 0.5), closeTo((miss + full) / 2, 1e-15),
          reason: 'models.score-formula#6');

      // A 2-out-of-5 numerical day contributes 0.4 of the full step.
      expect(Score.compute(freq, 0.0, 2 / 5),
          closeTo((2 / 5) * (1 - multiplierOf(freq)), 1e-15),
          reason: 'models.score-formula#6');

      // Feeding a raw entry value (YES_MANUAL == 2) instead of a fraction
      // would drive the score outside [0, 1]; that is why callers must
      // normalise first.
      expect(Score.compute(freq, 1.0, Entry.yesManual.toDouble()),
          greaterThan(1.0),
          reason: 'models.score-formula#6');
      expect(Score.compute(freq, 0.0, Entry.unknown.toDouble()), lessThan(0.0),
          reason: 'models.score-formula#6');
    });

    test('#7 scores stay in [0, 1] and converge upward', () {
      const frequencies = <double>[1.0, 1 / 2, 1 / 3, 0.375, 1 / 7, 1 / 30];
      for (final frequency in frequencies) {
        for (var p = 0; p <= 10; p++) {
          for (var c = 0; c <= 10; c++) {
            final result = Score.compute(frequency, p / 10, c / 10);
            expect(result, inInclusiveRange(0.0, 1.0),
                reason: 'models.score-formula#7');
          }
        }
      }

      // A run of consecutive checks converges to 1. One "check" covers the
      // whole interval of the frequency (a weekly habit's check counts for
      // seven days), so the number of compute() steps is checks * interval.
      double afterChecks(double frequency, int interval, int checks) {
        var score = 0.0;
        for (var i = 0; i < checks * interval; i++) {
          score = Score.compute(frequency, score, 1.0);
        }
        return score;
      }

      expect(afterChecks(1.0, 1, 90), greaterThan(0.99),
          reason: 'models.score-formula#7');
      expect(afterChecks(1 / 7, 7, 39), greaterThan(0.99),
          reason: 'models.score-formula#7');
      expect(afterChecks(1 / 30, 30, 18), greaterThan(0.99),
          reason: 'models.score-formula#7');

      // and never overshoots the ceiling.
      expect(afterChecks(1.0, 1, 5000), lessThanOrEqualTo(1.0),
          reason: 'models.score-formula#7');

      // Symmetrically, a run of misses decays down to 0 without going below.
      var score = 1.0;
      for (var i = 0; i < 5000; i++) {
        score = Score.compute(1.0, score, 0.0);
      }
      expect(score, inInclusiveRange(0.0, 1.0),
          reason: 'models.score-formula#7');
      expect(score, lessThan(0.01), reason: 'models.score-formula#7');
    });
  });
}
