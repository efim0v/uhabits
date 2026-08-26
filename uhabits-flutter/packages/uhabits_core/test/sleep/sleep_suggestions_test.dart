import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_suggestions.dart';

const SleepGoal goal = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

int startOfDay(int day) => (day + 10957) * 86400000;

SleepEpisode night({
  required int day,
  int bedMinutes = 1380,
  int wakeMinutes = 420,
  int asleepMinutes = 480,
  int utcOffsetMinutes = 0,
}) =>
    SleepEpisode(
      bedStartMillis: startOfDay(day - 1) +
          bedMinutes * 60000 -
          utcOffsetMinutes * 60000,
      wakeEndMillis:
          startOfDay(day) + wakeMinutes * 60000 - utcOffsetMinutes * 60000,
      asleepMinutes: asleepMinutes,
      utcOffsetMinutes: utcOffsetMinutes,
    );

/// [count] nights whose bed and wake times sit [shift] minutes past the goal,
/// give or take [jitter].
List<SleepEpisode> nightsShiftedBy(
  int shift, {
  int count = 14,
  int jitter = 0,
}) {
  return <SleepEpisode>[
    for (var i = 0; i < count; i++)
      night(
        day: 9000 - i,
        bedMinutes: 1380 + shift + (i.isEven ? jitter : -jitter),
        wakeMinutes: 420 + shift + (i.isEven ? jitter : -jitter),
      ),
  ];
}

void main() {
  group('a change of timezone', () {
    test('two hours or more raises a suggestion', () {
      final TimezoneSkipSuggestion? suggestion = suggestSkipForTimezone(today: 9000, <int, SleepEpisode>{
          8998: night(day: 8998, utcOffsetMinutes: 180),
          8999: night(day: 8999, utcOffsetMinutes: 180),
          9000: night(day: 9000, utcOffsetMinutes: -60),
        },
      );
      expect(suggestion, isNotNull, reason: 'sleep.skip#4');
      expect(suggestion!.fromDay, 9000, reason: 'sleep.skip#4');
      expect(suggestion.toDay, 9000, reason: 'sleep.skip#4');
      expect(suggestion.shiftMinutes, -240, reason: 'sleep.skip#4');
    });

    test('just under two hours raises nothing', () {
      expect(
        suggestSkipForTimezone(today: 9000, <int, SleepEpisode>{
          8999: night(day: 8999, utcOffsetMinutes: 180),
          9000: night(day: 9000, utcOffsetMinutes: 61),
        }),
        isNull,
        reason: 'sleep.skip#4',
      );
    });

    test('exactly two hours does raise one', () {
      expect(
        suggestSkipForTimezone(today: 9000, <int, SleepEpisode>{
          8999: night(day: 8999, utcOffsetMinutes: 180),
          9000: night(day: 9000, utcOffsetMinutes: 60),
        }),
        isNotNull,
        reason: 'sleep.skip#4',
      );
    });

    test('it works in both directions', () {
      final TimezoneSkipSuggestion? east = suggestSkipForTimezone(today: 9000, <int, SleepEpisode>{
          8999: night(day: 8999, utcOffsetMinutes: 0),
          9000: night(day: 9000, utcOffsetMinutes: 300),
        },
      );
      expect(east!.shiftMinutes, 300, reason: 'sleep.skip#4');
    });

    test('the range reaches from the jump to the newest night', () {
      final TimezoneSkipSuggestion? suggestion = suggestSkipForTimezone(today: 9000, <int, SleepEpisode>{
          8997: night(day: 8997, utcOffsetMinutes: 180),
          8998: night(day: 8998, utcOffsetMinutes: -240),
          8999: night(day: 8999, utcOffsetMinutes: -240),
          9000: night(day: 9000, utcOffsetMinutes: -240),
        },
      );
      expect(suggestion!.fromDay, 8998, reason: 'sleep.skip#4');
      expect(suggestion.toDay, 9000, reason: 'sleep.skip#4');
    });

    test('a settled schedule raises nothing', () {
      expect(
        suggestSkipForTimezone(today: 9000, <int, SleepEpisode>{
          for (var d = 8990; d <= 9000; d++)
            d: night(day: d, utcOffsetMinutes: 180),
        }),
        isNull,
        reason: 'sleep.skip#4',
      );
    });

    test('one night alone raises nothing', () {
      expect(
        suggestSkipForTimezone(today: 9000, <int, SleepEpisode>{9000: night(day: 9000)}),
        isNull,
        reason: 'sleep.skip#4',
      );
    });
  });

  group('how long the trip is worth mentioning', () {
    test('a jump within the week is offered', () {
      expect(
        suggestSkipForTimezone(
          today: 9000,
          <int, SleepEpisode>{
            8996: night(day: 8996, utcOffsetMinutes: 0),
            8997: night(day: 8997, utcOffsetMinutes: 480),
            9000: night(day: 9000, utcOffsetMinutes: 480),
          },
        ),
        isNotNull,
        reason: 'sleep.skip#4',
      );
    });

    test('a jump older than the week is not', () {
      // An offer to excuse last month's flight is an offer to rewrite settled
      // history, and it would stand on the screen for ever: a jump that
      // happened never stops having happened.
      expect(
        suggestSkipForTimezone(
          today: 9000,
          <int, SleepEpisode>{
            8989: night(day: 8989, utcOffsetMinutes: 0),
            8990: night(day: 8990, utcOffsetMinutes: 480),
            9000: night(day: 9000, utcOffsetMinutes: 480),
          },
        ),
        isNull,
        reason: 'sleep.skip#4',
      );
    });

    test('the boundary is the week itself', () {
      Map<int, SleepEpisode> tripStartingOn(int jump) => <int, SleepEpisode>{
            jump - 1: night(day: jump - 1, utcOffsetMinutes: 0),
            jump: night(day: jump, utcOffsetMinutes: 480),
            9000: night(day: 9000, utcOffsetMinutes: 480),
          };

      expect(
        suggestSkipForTimezone(
            today: 9000, tripStartingOn(9000 - timezoneSuggestionDays + 1)),
        isNotNull,
        reason: 'sleep.skip#4 — the last day inside the window',
      );
      expect(
        suggestSkipForTimezone(
            today: 9000, tripStartingOn(9000 - timezoneSuggestionDays)),
        isNull,
        reason: 'sleep.skip#4 — and the first day outside it',
      );
    });
  });

  group('a goal the nights suggest', () {
    test('needs ten nights out of the fortnight', () {
      expect(suggestGoal(nightsShiftedBy(60, count: 9), goal), isNull,
          reason: 'sleep.suggest-goal#1');
      expect(suggestGoal(nightsShiftedBy(60, count: 10), goal), isNotNull,
          reason: 'sleep.suggest-goal#1');
    });

    test('needs the median to be far enough from the goal', () {
      expect(suggestGoal(nightsShiftedBy(20), goal), isNull,
          reason: 'sleep.suggest-goal#2');
      expect(suggestGoal(nightsShiftedBy(45), goal), isNotNull,
          reason: 'sleep.suggest-goal#2');
    });

    test('needs the nights to cluster', () {
      // Shifted, but all over the place: a median of noise is still noise.
      expect(suggestGoal(nightsShiftedBy(60, jitter: 150), goal), isNull,
          reason: 'sleep.suggest-goal#3');
      expect(suggestGoal(nightsShiftedBy(60, jitter: 10), goal), isNotNull,
          reason: 'sleep.suggest-goal#3');
    });

    test('suggests the median it found', () {
      final GoalSuggestion? suggestion =
          suggestGoal(nightsShiftedBy(45), goal);
      expect(suggestion!.bedMinutes, 1380 + 45,
          reason: 'sleep.suggest-goal#2');
      expect(suggestion.wakeMinutes, 420 + 45,
          reason: 'sleep.suggest-goal#2');
      expect(suggestion.nightsConsidered, 14,
          reason: 'sleep.suggest-goal#1');
    });

    test('suggests only the half that moved', () {
      final List<SleepEpisode> nights = <SleepEpisode>[
        for (var i = 0; i < 14; i++)
          night(day: 9000 - i, bedMinutes: 1380 + 60, wakeMinutes: 420),
      ];
      final GoalSuggestion? suggestion = suggestGoal(nights, goal);
      // An hour past 23:00 is midnight, which as a time of day is 0.
      expect(suggestion!.bedMinutes, 0, reason: 'sleep.suggest-goal#2');
      expect(suggestion.wakeMinutes, isNull, reason: 'sleep.suggest-goal#2');
    });

    test('a schedule already on the goal suggests nothing', () {
      expect(suggestGoal(nightsShiftedBy(0), goal), isNull,
          reason: 'sleep.suggest-goal#2');
    });

    test('it never applies itself', () {
      // The suggestion is a value. Nothing here can change a goal, which is
      // the whole guarantee: the app proposes, and the person decides.
      const SleepGoal before = goal;
      suggestGoal(nightsShiftedBy(60), before);
      expect(before.bedMinutes, 1380, reason: 'sleep.suggest-goal#4');
      expect(before.wakeMinutes, 420, reason: 'sleep.suggest-goal#4');
    });
  });

  group('the circular median', () {
    test('is the middle of a plain cluster', () {
      expect(circularMedian(<int>[100, 110, 120], near: 110), 110,
          reason: 'sleep.suggest-goal#2');
    });

    test('does not fall apart across midnight', () {
      // 23:50, 00:00 and 00:10 have a middle of midnight, not of midday.
      expect(circularMedian(<int>[1430, 0, 10], near: 0), 0,
          reason: 'sleep.suggest-goal#2');
    });

    test('an even count takes the middle of the two', () {
      expect(circularMedian(<int>[100, 110, 120, 130], near: 110), 115,
          reason: 'sleep.suggest-goal#2');
    });

    test('an empty list falls back to the reference', () {
      expect(circularMedian(const <int>[], near: 420), 420,
          reason: 'sleep.suggest-goal#2');
    });
  });
}
