import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';

/// Лечь в 23:00, встать в 07:00, спать не менее 7:30.
const SleepGoal goal = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

void main() {
  group('defaults', () {
    test('match the specification', () {
      expect(goal.minSleepMinutes, 450, reason: 'sleep.goal#1');
      expect(goal.weightSleep, 0.4, reason: 'sleep.goal#1');
      expect(goal.weightBed, 0.3, reason: 'sleep.goal#1');
      expect(goal.weightWake, 0.3, reason: 'sleep.goal#1');
      expect(goal.halfCreditTimeMinutes, 90, reason: 'sleep.goal#1');
      expect(goal.halfCreditSleepMinutes, 60, reason: 'sleep.goal#1');
      expect(goal.adaptationMinutesPerDay, 60, reason: 'sleep.goal#1');
      expect(goal.mergeGapMinutes, 60, reason: 'sleep.goal#1');
      expect(goal.promptAfterWakeMinutes, 60, reason: 'sleep.goal#1');
      expect(goal.homeUtcOffsetMinutes, 0, reason: 'sleep.goal#1');
    });

    test('the three weights already sum to one', () {
      expect(goal.weightSum, closeTo(1.0, 1e-12), reason: 'sleep.goal#1');
    });
  });

  group('weights', () {
    test('are normalized to sum one', () {
      const skewed = SleepGoal(
        bedMinutes: 1380,
        wakeMinutes: 420,
        weightSleep: 2,
        weightBed: 1,
        weightWake: 1,
      );
      final w = skewed.normalizedWeights;
      expect(w.sleep, closeTo(0.5, 1e-12), reason: 'sleep.goal#2');
      expect(w.bed, closeTo(0.25, 1e-12), reason: 'sleep.goal#2');
      expect(w.wake, closeTo(0.25, 1e-12), reason: 'sleep.goal#2');
      expect(w.sleep + w.bed + w.wake, closeTo(1.0, 1e-12),
          reason: 'sleep.goal#2');
    });

    test('normalization is scale invariant', () {
      // Doubling every weight must not change a single score.
      const small = SleepGoal(
          bedMinutes: 1380,
          wakeMinutes: 420,
          weightSleep: 0.4,
          weightBed: 0.3,
          weightWake: 0.3);
      const large = SleepGoal(
          bedMinutes: 1380,
          wakeMinutes: 420,
          weightSleep: 40,
          weightBed: 30,
          weightWake: 30);
      expect(large.normalizedWeights.sleep,
          closeTo(small.normalizedWeights.sleep, 1e-12),
          reason: 'sleep.goal#2');
      expect(large.normalizedWeights.bed,
          closeTo(small.normalizedWeights.bed, 1e-12),
          reason: 'sleep.goal#2');
    });

    test('a single non-zero weight takes everything', () {
      const only = SleepGoal(
        bedMinutes: 1380,
        wakeMinutes: 420,
        weightSleep: 1,
        weightBed: 0,
        weightWake: 0,
      );
      expect(only.normalizedWeights.sleep, closeTo(1.0, 1e-12),
          reason: 'sleep.goal#2');
      expect(only.normalizedWeights.bed, 0, reason: 'sleep.goal#2');
    });
  });

  group('configured', () {
    test('zero weights mean the goal is not configured', () {
      const empty = SleepGoal(
        bedMinutes: 1380,
        wakeMinutes: 420,
        weightSleep: 0,
        weightBed: 0,
        weightWake: 0,
      );
      expect(empty.isConfigured, isFalse, reason: 'sleep.goal#3');
      expect(empty.normalizedWeights.sleep, 0, reason: 'sleep.goal#3');
      expect(goal.isConfigured, isTrue, reason: 'sleep.goal#3');
    });
  });

  group('copyWith', () {
    test('changes one field and leaves the rest alone', () {
      final moved = goal.copyWith(bedMinutes: 1320);
      expect(moved.bedMinutes, 1320, reason: 'sleep.goal#1');
      expect(moved.wakeMinutes, goal.wakeMinutes, reason: 'sleep.goal#1');
      expect(moved.minSleepMinutes, goal.minSleepMinutes,
          reason: 'sleep.goal#1');
      expect(moved.weightSleep, goal.weightSleep, reason: 'sleep.goal#1');
    });
  });

  group('equality', () {
    test('two goals with the same fields are equal', () {
      const a = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);
      const b = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);
      const c = SleepGoal(bedMinutes: 1381, wakeMinutes: 420);
      expect(a, b, reason: 'sleep.goal#1');
      expect(a.hashCode, b.hashCode, reason: 'sleep.goal#1');
      expect(a, isNot(c), reason: 'sleep.goal#1');
    });
  });
}
