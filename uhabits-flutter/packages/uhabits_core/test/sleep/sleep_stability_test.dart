import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_stability.dart';

const int midnight = 1756080000000;

SleepEpisode night(int bedMinutes, int wakeMinutes, int asleepMinutes) =>
    SleepEpisode(
      bedStartMillis: midnight + bedMinutes * 60000,
      wakeEndMillis: midnight + (wakeMinutes + 1440) * 60000,
      asleepMinutes: asleepMinutes,
      utcOffsetMinutes: 0,
    );

void main() {
  group('circular spread', () {
    test('times around midnight stay close together', () {
      // 23:50, 00:10, 23:55, 00:05 are minutes apart, not most of a day.
      // A plain standard deviation would call this schedule chaos.
      expect(circularSpread(const <int>[1430, 10, 1435, 5]), lessThan(30),
          reason: 'sleep.stability#1');
    });

    test('identical times have no spread', () {
      expect(circularSpread(const <int>[420, 420, 420]), closeTo(0, 1e-9),
          reason: 'sleep.stability#1');
    });

    test('grows as times scatter', () {
      final tight = circularSpread(const <int>[1380, 1385, 1375, 1382]);
      final loose = circularSpread(const <int>[1380, 1440, 1320, 1500]);
      expect(tight, lessThan(loose), reason: 'sleep.stability#1');
      expect(tight, lessThan(15), reason: 'sleep.stability#1');
      expect(loose, greaterThan(45), reason: 'sleep.stability#1');
    });

    test('is unchanged by rotating every time by the same amount', () {
      // Spread is about consistency, not about what hour it happens at.
      const base = <int>[1380, 1410, 1350, 1395];
      final rotated = base.map((m) => (m + 500) % 1440).toList();
      expect(circularSpread(rotated), closeTo(circularSpread(base), 1e-9),
          reason: 'sleep.stability#1');
    });

    test('an empty list has no spread', () {
      expect(circularSpread(const <int>[]), 0, reason: 'sleep.stability#1');
    });

    test('opposite times give a very large spread', () {
      final spread = circularSpread(const <int>[0, 720]);
      expect(spread, greaterThan(200), reason: 'sleep.stability#1');
      expect(spread.isFinite, isTrue, reason: 'sleep.stability#1');
    });
  });

  group('computing stability', () {
    test('reports both spreads and the mean sleep', () {
      final result = computeStability(
        <SleepEpisode>[
          night(1380, 420, 480),
          night(1380, 420, 480),
          night(1380, 420, 420),
          night(1380, 420, 420),
        ],
        minNights: 4,
      )!;
      expect(result.bedSpreadMinutes, closeTo(0, 0.5),
          reason: 'sleep.stability#1');
      expect(result.wakeSpreadMinutes, closeTo(0, 0.5),
          reason: 'sleep.stability#1');
      expect(result.meanAsleepMinutes, closeTo(450, 0.5),
          reason: 'sleep.stability#1');
      expect(result.nightCount, 4, reason: 'sleep.stability#1');
    });

    test('a scattered schedule shows a large bedtime spread', () {
      final result = computeStability(
        <SleepEpisode>[
          night(1320, 400, 450), // 22:00
          night(1440, 480, 450), // 00:00
          night(1560, 540, 450), // 02:00
          night(1380, 420, 450), // 23:00
        ],
        minNights: 4,
      )!;
      expect(result.bedSpreadMinutes, greaterThan(60),
          reason: 'sleep.stability#1');
    });

    test('a night is read in the offset it was recorded in', () {
      // The same instant, recorded three hours east, is three hours later
      // locally — and so is not evidence of an irregular schedule.
      final result = computeStability(
        <SleepEpisode>[
          const SleepEpisode(
              bedStartMillis: midnight + 1380 * 60000,
              wakeEndMillis: midnight + 1860 * 60000,
              asleepMinutes: 450,
              utcOffsetMinutes: 0),
          const SleepEpisode(
              bedStartMillis: midnight + 1200 * 60000,
              wakeEndMillis: midnight + 1680 * 60000,
              asleepMinutes: 450,
              utcOffsetMinutes: 180),
        ],
        minNights: 2,
      )!;
      expect(result.bedSpreadMinutes, closeTo(0, 0.5),
          reason: 'sleep.stability#1');
    });

    test('too few nights yield nothing at all', () {
      expect(computeStability(<SleepEpisode>[night(1380, 420, 480)], minNights: 4),
          isNull, reason: 'sleep.stability#3');
      expect(computeStability(const <SleepEpisode>[], minNights: 4), isNull,
          reason: 'sleep.stability#3');
      expect(
          computeStability(List<SleepEpisode>.filled(3, night(1380, 420, 480)),
              minNights: 4),
          isNull,
          reason: 'sleep.stability#3');
    });

    test('exactly the minimum is enough', () {
      expect(
          computeStability(List<SleepEpisode>.filled(4, night(1380, 420, 480)),
              minNights: 4),
          isNotNull,
          reason: 'sleep.stability#3');
    });

    test('the caller decides what goes in, and only that is counted', () {
      // Skips and days without data are filtered out before this point, so a
      // travel week cannot inflate the spread for a fortnight afterwards.
      final result = computeStability(
        <SleepEpisode>[
          night(1380, 420, 480),
          night(1385, 425, 470),
          night(1375, 415, 490),
          night(1382, 422, 480),
        ],
        minNights: 4,
      )!;
      expect(result.nightCount, 4, reason: 'sleep.stability#2');
      expect(result.bedSpreadMinutes, lessThan(10),
          reason: 'sleep.stability#2');
    });
  });
}
