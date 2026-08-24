import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_scorer.dart';

/// Лечь в 23:00, встать в 07:00, спать не менее 7:30.
const SleepGoal goal = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

/// An exact UTC midnight, so a test can name times in plain minutes.
const int midnight = 1756080000000;

/// Builds a night from local minutes, so tests read like the specification.
///
/// [bedMinutes] may exceed 1440, which means a bedtime after midnight.
SleepEpisode night(int bedMinutes, int wakeMinutes, int asleepMinutes) =>
    SleepEpisode(
      bedStartMillis: midnight + bedMinutes * 60000,
      wakeEndMillis: midnight + (wakeMinutes + 1440) * 60000,
      asleepMinutes: asleepMinutes,
      utcOffsetMinutes: 0,
    );

void main() {
  group('circular distance', () {
    test('wraps around midnight', () {
      expect(circularDistance(1430, 10), 20, reason: 'sleep.scoring#1');
      expect(circularDistance(10, 1430), 20, reason: 'sleep.scoring#1');
      expect(circularDistance(1439, 0), 1, reason: 'sleep.scoring#1');
    });

    test('is zero for identical times and symmetric everywhere', () {
      expect(circularDistance(420, 420), 0, reason: 'sleep.scoring#1');
      for (var a = 0; a < 1440; a += 37) {
        for (var b = 0; b < 1440; b += 53) {
          expect(circularDistance(a, b), circularDistance(b, a),
              reason: 'sleep.scoring#1');
        }
      }
    });

    test('never exceeds half a day', () {
      expect(circularDistance(0, 720), 720, reason: 'sleep.scoring#1');
      for (var a = 0; a < 1440; a += 17) {
        for (var b = 0; b < 1440; b += 19) {
          expect(circularDistance(a, b), lessThanOrEqualTo(720),
              reason: 'sleep.scoring#1');
        }
      }
    });
  });

  group('component score', () {
    test('is exactly one at zero deviation', () {
      expect(componentScore(0, 90), closeTo(1.0, 1e-12),
          reason: 'sleep.scoring#4');
      expect(componentScore(0, 60), closeTo(1.0, 1e-12),
          reason: 'sleep.scoring#4');
      expect(componentScore(0, 1), closeTo(1.0, 1e-12),
          reason: 'sleep.scoring#4');
    });

    test('follows the curve for time components', () {
      const expected = <int, double>{
        0: 1.000,
        15: 0.988,
        30: 0.963,
        45: 0.915,
        60: 0.827,
        90: 0.506,
        120: 0.184,
        150: 0.048,
        180: 0.011,
      };
      expected.forEach((deviation, value) {
        expect(componentScore(deviation, 90), closeTo(value, 0.0005),
            reason: 'sleep.scoring#3');
      });
    });

    test('follows the curve for the duration component', () {
      const expected = <int, double>{
        0: 1.000,
        15: 0.950,
        30: 0.858,
        45: 0.713,
        60: 0.525,
        90: 0.192,
        120: 0.050,
      };
      expected.forEach((deviation, value) {
        expect(componentScore(deviation, 60), closeTo(value, 0.0005),
            reason: 'sleep.scoring#3');
      });
    });

    test('gives half credit at the half credit point', () {
      // Slightly above a half, because the curve is normalised to reach
      // exactly one at zero rather than approaching it.
      expect(componentScore(90, 90), closeTo(0.5056, 0.0005),
          reason: 'sleep.scoring#3');
      expect(componentScore(60, 60), closeTo(0.5249, 0.0005),
          reason: 'sleep.scoring#3');
    });

    test('decreases monotonically and stays in range', () {
      var previous = componentScore(0, 90);
      for (var d = 1; d <= 720; d++) {
        final current = componentScore(d, 90);
        expect(current, lessThan(previous), reason: 'sleep.scoring#3');
        expect(current, inInclusiveRange(0.0, 1.0),
            reason: 'sleep.scoring#3');
        previous = current;
      }
    });

    test('is flat near the target and steep in the middle', () {
      // The shape is the point: half an hour off costs almost nothing, an
      // hour and a half costs half the credit, three hours is a write-off.
      final nearCost = 1 - componentScore(30, 90);
      final middleCost = componentScore(60, 90) - componentScore(120, 90);
      final farCost = componentScore(180, 90) - componentScore(240, 90);
      expect(nearCost, lessThan(0.05), reason: 'sleep.scoring#3');
      expect(middleCost, greaterThan(0.5), reason: 'sleep.scoring#3');
      expect(farCost, lessThan(0.02), reason: 'sleep.scoring#3');
    });
  });

  group('scoring a night', () {
    test('oversleeping is never penalised', () {
      final exact = scoreNight(night(1380, 420, 450), goal, 0)!;
      final long = scoreNight(night(1380, 420, 600), goal, 0)!;
      expect(exact.scoreSleep, closeTo(1.0, 1e-12), reason: 'sleep.scoring#2');
      expect(long.scoreSleep, closeTo(1.0, 1e-12), reason: 'sleep.scoring#2');
      expect(long.devSleep, 0, reason: 'sleep.scoring#2');
    });

    test('bedtime deviation is two sided', () {
      final late = scoreNight(night(1440, 420, 480), goal, 0)!;
      final early = scoreNight(night(1320, 420, 480), goal, 0)!;
      expect(late.devBed, 60, reason: 'sleep.scoring#1');
      expect(early.devBed, 60, reason: 'sleep.scoring#1');
      expect(early.scoreBed, closeTo(late.scoreBed, 1e-12),
          reason: 'sleep.scoring#1');
    });

    test('duration is actual sleep, not the span between the two times', () {
      // In bed at 23:00, asleep at 02:00, up at 07:00: both times are perfect
      // and only the duration is short.
      final result = scoreNight(night(1380, 420, 300), goal, 0)!;
      expect(result.devBed, 0, reason: 'sleep.scoring#6');
      expect(result.devWake, 0, reason: 'sleep.scoring#6');
      expect(result.devSleep, 150, reason: 'sleep.scoring#6');
      expect(result.scoreBed, closeTo(1.0, 1e-12), reason: 'sleep.scoring#6');
      expect(result.scoreWake, closeTo(1.0, 1e-12), reason: 'sleep.scoring#6');
      expect(result.total, lessThan(0.5), reason: 'sleep.scoring#6');
    });

    test('control vectors from the specification', () {
      // The fourth night lands on 53.5074 percent, all but exactly on a
      // rounding boundary, so the fraction is what is checked and the rounded
      // percent only confirms it.
      const vectors = <_Vector>[
        _Vector(1390, 425, 475, 0.996939, 100), // 23:10 / 07:05 / 7:55
        _Vector(1421, 432, 408, 0.868280, 87), //  23:41 / 07:12 / 6:48
        _Vector(1440, 480, 480, 0.892062, 89), //  00:00 / 08:00 / 8:00
        _Vector(1500, 480, 420, 0.535074, 54), //  01:00 / 08:00 / 7:00
        _Vector(1560, 540, 420, 0.146865, 15), //  02:00 / 09:00 / 7:00
      ];
      for (final v in vectors) {
        final result = scoreNight(night(v.bed, v.wake, v.asleep), goal, 0)!;
        expect(result.total, closeTo(v.total, 5e-7),
            reason: 'sleep.scoring#7');
        expect((result.total * 100).round(), v.percent,
            reason: 'sleep.scoring#7');
      }
    });

    test('combination is geometric, not arithmetic', () {
      // The worst vector: an arithmetic mean would rate this night 40 percent
      // on the strength of seven hours of sleep alone.
      final result = scoreNight(night(1560, 540, 420), goal, 0)!;
      final w = goal.normalizedWeights;
      final arithmetic = w.sleep * result.scoreSleep +
          w.bed * result.scoreBed +
          w.wake * result.scoreWake;
      expect(arithmetic, greaterThan(0.35), reason: 'sleep.scoring#5');
      expect(result.total, lessThan(0.20), reason: 'sleep.scoring#5');
    });

    test('one ruined component drags the whole night down', () {
      final ruined = scoreNight(night(1560, 420, 480), goal, 0)!;
      expect(ruined.scoreWake, closeTo(1.0, 1e-12), reason: 'sleep.scoring#5');
      expect(ruined.scoreSleep, closeTo(1.0, 1e-12), reason: 'sleep.scoring#5');
      expect(ruined.total, lessThan(0.5), reason: 'sleep.scoring#5');
    });

    test('a perfect night scores exactly one', () {
      final perfect = scoreNight(night(1380, 420, 450), goal, 0)!;
      expect(perfect.total, closeTo(1.0, 1e-12), reason: 'sleep.scoring#4');
      expect(perfect.storedValue, 100000, reason: 'sleep.habit-type#3');
    });

    test('the breakdown names the component that cost the most', () {
      expect(scoreNight(night(1380, 420, 300), goal, 0)!.weakest,
          SleepComponent.sleep, reason: 'sleep.scoring#8');
      expect(scoreNight(night(1560, 420, 480), goal, 0)!.weakest,
          SleepComponent.bed, reason: 'sleep.scoring#8');
      expect(scoreNight(night(1380, 600, 480), goal, 0)!.weakest,
          SleepComponent.wake, reason: 'sleep.scoring#8');
    });

    test('the breakdown reports the local times it scored', () {
      final result = scoreNight(night(1421, 432, 408), goal, 0)!;
      expect(result.bedMinutes, 1421, reason: 'sleep.scoring#8');
      expect(result.wakeMinutes, 432, reason: 'sleep.scoring#8');
      expect(result.asleepMinutes, 408, reason: 'sleep.scoring#8');
    });

    test('an unconfigured goal scores nothing at all', () {
      const empty = SleepGoal(
        bedMinutes: 1380,
        wakeMinutes: 420,
        weightSleep: 0,
        weightBed: 0,
        weightWake: 0,
      );
      expect(scoreNight(night(1380, 420, 480), empty, 0), isNull,
          reason: 'sleep.goal#3');
    });
  });

  group('the effective timezone shifts the whole night', () {
    test('a night is read in the offset it is scored against', () {
      // The same instants, read three hours east, are three hours later.
      final home = scoreNight(night(1380, 420, 480), goal, 0)!;
      final east = scoreNight(night(1380, 420, 480), goal, 180)!;
      expect(home.bedMinutes, 1380, reason: 'sleep.scoring#1');
      expect(east.bedMinutes, 120, reason: 'sleep.scoring#1');
      expect(east.devBed, 180, reason: 'sleep.scoring#1');
      expect(east.total, lessThan(home.total), reason: 'sleep.scoring#1');
    });

    test('a negative offset is handled without going negative', () {
      final west = scoreNight(night(60, 420, 480), goal, -240)!;
      expect(west.bedMinutes, inInclusiveRange(0, 1439),
          reason: 'sleep.scoring#1');
      expect(west.wakeMinutes, inInclusiveRange(0, 1439),
          reason: 'sleep.scoring#1');
    });
  });

  group('local minutes', () {
    test('never leaves the day', () {
      for (var offset = -840; offset <= 840; offset += 30) {
        for (var m = 0; m < 1440; m += 61) {
          final value = localMinutesOf(midnight + m * 60000, offset);
          expect(value, inInclusiveRange(0, 1439), reason: 'sleep.scoring#1');
        }
      }
    });
  });
}

/// One row of the specification's control table.
class _Vector {
  const _Vector(this.bed, this.wake, this.asleep, this.total, this.percent);

  final int bed;
  final int wake;
  final int asleep;
  final double total;
  final int percent;
}
