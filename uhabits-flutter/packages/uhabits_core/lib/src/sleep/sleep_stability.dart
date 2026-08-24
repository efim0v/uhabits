import 'dart:math' as math;

import 'sleep_episode.dart';

/// How regular a stretch of nights was.
class SleepStability {
  const SleepStability({
    required this.bedSpreadMinutes,
    required this.wakeSpreadMinutes,
    required this.meanAsleepMinutes,
    required this.nightCount,
  });

  final double bedSpreadMinutes;
  final double wakeSpreadMinutes;
  final double meanAsleepMinutes;
  final int nightCount;
}

/// Standard deviation of times of day, measured the short way round the clock.
///
/// A plain standard deviation is unusable here: 23:50 and 00:10 are twenty
/// minutes apart, and treating them as 1420 would report the steadiest
/// possible schedule as chaos. Unaffected by shifting every time by the same
/// amount, because spread is about consistency and not about which hour it
/// happens at.
double circularSpread(List<int> minutes) {
  if (minutes.isEmpty) return 0;

  var sumSin = 0.0;
  var sumCos = 0.0;
  for (final m in minutes) {
    final double theta = 2 * math.pi * m / 1440;
    sumSin += math.sin(theta);
    sumCos += math.cos(theta);
  }

  final double r =
      math.sqrt(sumSin * sumSin + sumCos * sumCos) / minutes.length;
  if (r >= 1) return 0;
  // Fully opposed times leave no resultant at all; report the largest spread
  // the measure can express rather than an infinity.
  if (r <= 0) return 1440 / 4;
  return 1440 / (2 * math.pi) * math.sqrt(-2 * math.log(r));
}

/// Measures how regular the given nights were.
///
/// Which nights those are is the caller's decision: skips and days without
/// data are filtered out before this point, so that one week of travel cannot
/// inflate the spread for a fortnight afterwards.
///
/// Each night is read in the offset it was *recorded* in, deliberately unlike
/// [scoreNight], which reads it in the goal's drifting frame. The two answer
/// different questions: scoring asks how far the night was from the goal,
/// while spread asks whether the person kept to their own schedule wherever
/// they were. Aligning one to the other would look tidy and be wrong.
///
/// Returns null below [minNights], because a spread over two or three nights
/// says more about the arithmetic than about the person.
SleepStability? computeStability(
  List<SleepEpisode> episodes, {
  required int minNights,
}) {
  if (episodes.length < minNights) return null;

  final bed = <int>[];
  final wake = <int>[];
  var asleepTotal = 0;
  for (final episode in episodes) {
    bed.add(localMinutesOf(episode.bedStartMillis, episode.utcOffsetMinutes));
    wake.add(localMinutesOf(episode.wakeEndMillis, episode.utcOffsetMinutes));
    asleepTotal += episode.asleepMinutes;
  }

  return SleepStability(
    bedSpreadMinutes: circularSpread(bed),
    wakeSpreadMinutes: circularSpread(wake),
    meanAsleepMinutes: asleepTotal / episodes.length,
    nightCount: episodes.length,
  );
}
