import 'dart:math' as math;

import 'sleep_episode.dart';
import 'sleep_goal.dart';
import 'stored_value.dart';

/// Steepness of the logistic curve, per minute.
///
/// A constant, not a setting: the shape of the penalty is part of the model,
/// and exposing it would let a person tune away the very judgement they asked
/// the app to make.
const double steepness = 0.05;

/// Which part of a night a score belongs to.
enum SleepComponent { sleep, bed, wake }

/// Distance between two times of day, in minutes, going the short way round.
///
/// 23:50 and 00:10 are twenty minutes apart, not one thousand four hundred and
/// twenty. Never exceeds half a day.
int circularDistance(int a, int b) {
  final int d = (a - b).abs() % 1440;
  return math.min(d, 1440 - d);
}

/// Credit for one component, given how far it missed and where half credit
/// lies.
///
/// An S-curve, deliberately: small deviations are nearly free, middling ones
/// cost sharply, and large ones are indistinguishable from each other, because
/// two hours late and three hours late are both simply a missed bedtime.
/// Normalised so that no deviation at all scores exactly one.
double componentScore(int deviationMinutes, int halfCreditMinutes) {
  final double m = halfCreditMinutes.toDouble();
  final double d = deviationMinutes.toDouble();
  return (1 + math.exp(-steepness * m)) / (1 + math.exp(steepness * (d - m)));
}

/// A scored night: what it was, how far each part missed, and what that cost.
class SleepBreakdown {
  const SleepBreakdown({
    required this.bedMinutes,
    required this.wakeMinutes,
    required this.asleepMinutes,
    required this.devBed,
    required this.devWake,
    required this.devSleep,
    required this.scoreBed,
    required this.scoreWake,
    required this.scoreSleep,
    required this.total,
  });

  /// Bedtime as minutes from midnight, in the offset it was scored against.
  final int bedMinutes;

  /// Wake time as minutes from midnight, in the offset it was scored against.
  final int wakeMinutes;

  final int asleepMinutes;

  final int devBed;
  final int devWake;

  /// Shortfall against the sleep floor. Zero when the person slept enough or
  /// more, because the goal is a floor and not a target.
  final int devSleep;

  final double scoreBed;
  final double scoreWake;
  final double scoreSleep;

  /// Completion for the night, in `[0, 1]`.
  final double total;

  /// The day's value as the entry table stores it.
  int get storedValue => storedValueOf(total);

  /// The component that cost the most credit.
  SleepComponent get weakest {
    if (scoreSleep <= scoreBed && scoreSleep <= scoreWake) {
      return SleepComponent.sleep;
    }
    return scoreBed <= scoreWake ? SleepComponent.bed : SleepComponent.wake;
  }
}

/// Scores one night against a goal, read in a given UTC offset.
///
/// Returns null when the goal carries no weight at all, so an unconfigured
/// habit leaves its days alone instead of failing them.
SleepBreakdown? scoreNight(
  SleepEpisode episode,
  SleepGoal goal,
  int effectiveOffsetMinutes,
) {
  if (!goal.isConfigured) return null;

  final int bedMinutes =
      localMinutesOf(episode.bedStartMillis, effectiveOffsetMinutes);
  final int wakeMinutes =
      localMinutesOf(episode.wakeEndMillis, effectiveOffsetMinutes);

  final int devBed = circularDistance(bedMinutes, goal.bedMinutes);
  final int devWake = circularDistance(wakeMinutes, goal.wakeMinutes);
  // One sided: the goal says "at least", so sleeping longer is not a miss.
  final int devSleep =
      math.max(0, goal.minSleepMinutes - episode.asleepMinutes);

  final double scoreBed = componentScore(devBed, goal.halfCreditTimeMinutes);
  final double scoreWake = componentScore(devWake, goal.halfCreditTimeMinutes);
  final double scoreSleep =
      componentScore(devSleep, goal.halfCreditSleepMinutes);

  final SleepWeights w = goal.normalizedWeights;
  // A weighted geometric mean. An arithmetic one would let seven hours of
  // sleep pay for a two in the morning bedtime, which is the substitution that
  // stops a tracker being honest.
  final double total = math.exp(
    w.sleep * math.log(scoreSleep) +
        w.bed * math.log(scoreBed) +
        w.wake * math.log(scoreWake),
  );

  return SleepBreakdown(
    bedMinutes: bedMinutes,
    wakeMinutes: wakeMinutes,
    asleepMinutes: episode.asleepMinutes,
    devBed: devBed,
    devWake: devWake,
    devSleep: devSleep,
    scoreBed: scoreBed,
    scoreWake: scoreWake,
    scoreSleep: scoreSleep,
    total: total,
  );
}
