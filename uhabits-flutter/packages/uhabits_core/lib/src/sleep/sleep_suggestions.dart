import 'sleep_episode.dart';
import 'sleep_goal.dart';
import 'sleep_scorer.dart';
import 'sleep_stability.dart';

/// A change of timezone worth offering to set aside.
const int timezoneJumpMinutes = 120;

/// How many nights a goal suggestion looks at.
const int suggestionWindowNights = 14;

/// How many of those must have data before a suggestion is offered.
const int suggestionMinNights = 10;

/// How far the median must be from the goal before it is worth mentioning.
const int suggestionMinShiftMinutes = 30;

/// How tightly the nights must cluster before a median means anything.
const int suggestionMaxSpreadMinutes = 45;

/// Days the app offers to mark as not applicable.
class TimezoneSkipSuggestion {
  const TimezoneSkipSuggestion({
    required this.fromDay,
    required this.toDay,
    required this.shiftMinutes,
  });

  final int fromDay;
  final int toDay;

  /// How far the timezone moved, signed.
  final int shiftMinutes;
}

/// A goal the recent nights suggest.
class GoalSuggestion {
  const GoalSuggestion({
    required this.bedMinutes,
    required this.wakeMinutes,
    required this.nightsConsidered,
  });

  /// Null when that half of the goal is already where it should be.
  final int? bedMinutes;
  final int? wakeMinutes;

  final int nightsConsidered;

  bool get isEmpty => bedMinutes == null && wakeMinutes == null;
}

/// Whether the timezone moved far enough to be worth setting days aside.
///
/// Only ever a suggestion. Marking days skipped is the person's judgement
/// about their own week, and an app that made it for them would be deciding
/// which of their nights counted.
TimezoneSkipSuggestion? suggestSkipForTimezone(
  Map<int, SleepEpisode> nights,
) {
  final List<int> days = nights.keys.toList()..sort();
  if (days.length < 2) return null;

  for (var i = days.length - 1; i > 0; i--) {
    final int shift = nights[days[i]]!.utcOffsetMinutes -
        nights[days[i - 1]]!.utcOffsetMinutes;
    if (shift.abs() >= timezoneJumpMinutes) {
      return TimezoneSkipSuggestion(
        fromDay: days[i],
        toDay: days.last,
        shiftMinutes: shift,
      );
    }
  }
  return null;
}

/// The goal the last fortnight suggests, or null when it suggests nothing.
///
/// Three conditions, and all of them have to hold. Enough nights, so the
/// answer is about a habit rather than about a week. A median far enough from
/// the goal to be worth moving. And a tight enough spread that a median means
/// anything at all — a scattered fortnight has a median too, and following it
/// would be fitting a line to noise.
GoalSuggestion? suggestGoal(List<SleepEpisode> nights, SleepGoal goal) {
  if (nights.length < suggestionMinNights) return null;

  final List<int> bed = <int>[
    for (final SleepEpisode n in nights)
      localMinutesOf(n.bedStartMillis, n.utcOffsetMinutes),
  ];
  final List<int> wake = <int>[
    for (final SleepEpisode n in nights)
      localMinutesOf(n.wakeEndMillis, n.utcOffsetMinutes),
  ];

  final int? suggestedBed = _suggestOne(bed, goal.bedMinutes);
  final int? suggestedWake = _suggestOne(wake, goal.wakeMinutes);
  if (suggestedBed == null && suggestedWake == null) return null;

  return GoalSuggestion(
    bedMinutes: suggestedBed,
    wakeMinutes: suggestedWake,
    nightsConsidered: nights.length,
  );
}

int? _suggestOne(List<int> minutes, int target) {
  if (circularSpread(minutes) > suggestionMaxSpreadMinutes) return null;
  final int median = circularMedian(minutes, near: target);
  if (circularDistance(median, target) < suggestionMinShiftMinutes) return null;
  return median;
}

/// The middle of a set of times of day, measured the short way round.
///
/// Taken relative to [near] so that a cluster straddling midnight does not
/// average out to the middle of the afternoon.
int circularMedian(List<int> minutes, {required int near}) {
  if (minutes.isEmpty) return near;
  final List<int> relative = <int>[
    for (final int m in minutes) _signedDistance(m, near),
  ]..sort();
  final int middle = relative.length.isOdd
      ? relative[relative.length ~/ 2]
      : ((relative[relative.length ~/ 2 - 1] +
                  relative[relative.length ~/ 2]) /
              2)
          .round();
  final int result = (near + middle) % 1440;
  return result < 0 ? result + 1440 : result;
}

/// How far [m] is from [origin], signed, going the short way round.
int _signedDistance(int m, int origin) {
  var d = (m - origin) % 1440;
  if (d < 0) d += 1440;
  return d > 720 ? d - 1440 : d;
}
