import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/timezone_drift.dart';

/// Moscow and New York, seven hours apart.
const int moscow = 180;
const int newYork = -240;

void main() {
  group('a settled timezone', () {
    test('never drifts', () {
      final offsets = effectiveOffsets(
        firstDay: 100,
        lastDay: 105,
        observedByDay: <int, int>{for (var d = 100; d <= 105; d++) d: moscow},
        homeOffsetMinutes: moscow,
        ratePerDayMinutes: 60,
      );
      for (var d = 100; d <= 105; d++) {
        expect(offsets[d], moscow, reason: 'sleep.timezone#1');
      }
    });

    test('covers every day of the range and nothing outside it', () {
      final offsets = effectiveOffsets(
        firstDay: 100,
        lastDay: 103,
        observedByDay: const <int, int>{},
        homeOffsetMinutes: moscow,
        ratePerDayMinutes: 60,
      );
      expect(offsets.keys.toList()..sort(), <int>[100, 101, 102, 103],
          reason: 'sleep.timezone#1');
    });

    test('an empty range yields nothing', () {
      expect(
        effectiveOffsets(
          firstDay: 100,
          lastDay: 99,
          observedByDay: const <int, int>{},
          homeOffsetMinutes: 0,
          ratePerDayMinutes: 60,
        ),
        isEmpty,
        reason: 'sleep.timezone#1',
      );
    });
  });

  group('the first day', () {
    test('is pinned to the home offset whatever was observed', () {
      final offsets = effectiveOffsets(
        firstDay: 100,
        lastDay: 101,
        observedByDay: const <int, int>{100: newYork, 101: newYork},
        homeOffsetMinutes: moscow,
        ratePerDayMinutes: 60,
      );
      expect(offsets[100], moscow, reason: 'sleep.timezone#2');
    });
  });

  group('a seven hour flight', () {
    // Day 100 is the last night at home; day 101 is the night of arrival.
    Map<int, int> flight() {
      final observed = <int, int>{100: moscow};
      for (var d = 101; d <= 112; d++) {
        observed[d] = newYork;
      }
      return effectiveOffsets(
        firstDay: 100,
        lastDay: 112,
        observedByDay: observed,
        homeOffsetMinutes: moscow,
        ratePerDayMinutes: 60,
      );
    }

    test('does not move the goal on the night of arrival', () {
      // The step is driven by the previous day's observation: a body does not
      // adapt within the same night it lands.
      expect(flight()[101], moscow, reason: 'sleep.timezone#3');
    });

    test('takes seven days, one hour at a time', () {
      const expected = <int, int>{
        101: 180,
        102: 120,
        103: 60,
        104: 0,
        105: -60,
        106: -120,
        107: -180,
        108: -240,
      };
      final offsets = flight();
      expected.forEach((day, offset) {
        expect(offsets[day], offset, reason: 'sleep.timezone#6');
      });
    });

    test('stops once it has caught up', () {
      final offsets = flight();
      for (var d = 108; d <= 112; d++) {
        expect(offsets[d], newYork, reason: 'sleep.timezone#6');
      }
    });
  });

  group('the step', () {
    test('is bounded going east', () {
      final offsets = effectiveOffsets(
        firstDay: 0,
        lastDay: 3,
        observedByDay: const <int, int>{0: 0, 1: 600, 2: 600, 3: 600},
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 60,
      );
      expect(offsets[1], 0, reason: 'sleep.timezone#4');
      expect(offsets[2], 60, reason: 'sleep.timezone#4');
      expect(offsets[3], 120, reason: 'sleep.timezone#4');
    });

    test('is bounded going west', () {
      final offsets = effectiveOffsets(
        firstDay: 0,
        lastDay: 3,
        observedByDay: const <int, int>{0: 0, 1: -600, 2: -600, 3: -600},
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 60,
      );
      expect(offsets[2], -60, reason: 'sleep.timezone#4');
      expect(offsets[3], -120, reason: 'sleep.timezone#4');
    });

    test('never overshoots a small change', () {
      // Twenty minutes of change must not become a full hour of movement.
      final offsets = effectiveOffsets(
        firstDay: 0,
        lastDay: 3,
        observedByDay: const <int, int>{0: 0, 1: 20, 2: 20, 3: 20},
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 60,
      );
      expect(offsets[2], 20, reason: 'sleep.timezone#4');
      expect(offsets[3], 20, reason: 'sleep.timezone#4');
    });

    test('a negative rate is treated as its magnitude', () {
      final offsets = effectiveOffsets(
        firstDay: 0,
        lastDay: 2,
        observedByDay: const <int, int>{0: 0, 1: 600, 2: 600},
        homeOffsetMinutes: 0,
        ratePerDayMinutes: -60,
      );
      expect(offsets[2], 60, reason: 'sleep.timezone#4');
    });

    test('a zero rate freezes the goal at home', () {
      final offsets = effectiveOffsets(
        firstDay: 0,
        lastDay: 5,
        observedByDay: const <int, int>{0: 0, 1: 600, 2: 600, 3: 600},
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 0,
      );
      for (var d = 0; d <= 5; d++) {
        expect(offsets[d], 0, reason: 'sleep.timezone#4');
      }
    });
  });

  group('days without a night', () {
    test('keep drifting toward the last observation instead of freezing', () {
      // A change observed on day 1 starts moving the goal on day 2, and the
      // silent days that follow inherit that observation and keep closing the
      // gap until they reach it.
      final offsets = effectiveOffsets(
        firstDay: 0,
        lastDay: 5,
        observedByDay: const <int, int>{0: 0, 1: 180}, // days 2..5 have none
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 60,
      );
      expect(offsets[1], 0, reason: 'sleep.timezone#5');
      expect(offsets[2], 60, reason: 'sleep.timezone#5');
      expect(offsets[3], 120, reason: 'sleep.timezone#5');
      expect(offsets[4], 180, reason: 'sleep.timezone#5');
      expect(offsets[5], 180, reason: 'sleep.timezone#5');
    });

    test('fall back to home when there is no earlier observation at all', () {
      final offsets = effectiveOffsets(
        firstDay: 0,
        lastDay: 3,
        observedByDay: const <int, int>{},
        homeOffsetMinutes: moscow,
        ratePerDayMinutes: 60,
      );
      for (var d = 0; d <= 3; d++) {
        expect(offsets[d], moscow, reason: 'sleep.timezone#5');
      }
    });
  });

  group('purity', () {
    test('the same inputs always give the same result', () {
      Map<int, int> run() => effectiveOffsets(
            firstDay: 0,
            lastDay: 30,
            observedByDay: const <int, int>{0: 0, 5: 300, 12: -120, 20: 60},
            homeOffsetMinutes: 0,
            ratePerDayMinutes: 60,
          );
      expect(run(), equals(run()), reason: 'sleep.timezone#1');
    });

    test('a longer range does not change the days it shares', () {
      // History must be recomputable: asking for more days may not rewrite
      // the answer for the days already asked about.
      const observed = <int, int>{0: 0, 3: 300, 9: -120};
      final short = effectiveOffsets(
        firstDay: 0,
        lastDay: 10,
        observedByDay: observed,
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 60,
      );
      final long = effectiveOffsets(
        firstDay: 0,
        lastDay: 40,
        observedByDay: observed,
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 60,
      );
      for (var d = 0; d <= 10; d++) {
        expect(long[d], short[d], reason: 'sleep.timezone#1');
      }
    });

    test('the input map is not modified', () {
      final observed = <int, int>{0: 0, 2: 300};
      effectiveOffsets(
        firstDay: 0,
        lastDay: 6,
        observedByDay: observed,
        homeOffsetMinutes: 0,
        ratePerDayMinutes: 60,
      );
      expect(observed, <int, int>{0: 0, 2: 300}, reason: 'sleep.timezone#1');
    });
  });
}
