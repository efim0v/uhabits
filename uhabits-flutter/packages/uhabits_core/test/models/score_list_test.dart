import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/score.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/ScoreListTest.kt
///
/// The Kotlin test drives ScoreList through Habit.recompute() and the
/// HabitFixtures helpers. This file predates both, so it supplies its own:
/// [FakeComputedEntries] reproduces
/// EntryList.getByInterval() exactly (one entry per day in [from, to],
/// newest-first, UNKNOWN for days that hold nothing), and the local
/// `recompute` closure reproduces the [from, to] range Habit.recompute()
/// passes down (from = oldest known entry, to = today + 30).
///
/// The Kotlin fixtures also run originalEntries through
/// EntryList.recomputeFrom(), which inserts YES_AUTO entries for boolean
/// habits. YES_AUTO is inert in ScoreList's boolean branch — it is neither
/// YES_MANUAL (so it never enters the rolling sum) nor SKIP (so it never
/// freezes the score) — and the extra leading days it produces all score 0.0,
/// so feeding only the YES_MANUAL/SKIP entries yields the very same numbers.
const double e = 1e-6;

/// The decay multiplier of Score.compute, spelled out independently.
double multiplierOf(double frequency) =>
    pow(0.5, sqrt(frequency) / 13.0).toDouble();

/// Stands in for the not-yet-ported EntryList.
class FakeComputedEntries {
  final Map<LocalDate, Entry> _byDate = {};

  void add(Entry entry) => _byDate[entry.date] = entry;

  /// EntryList.getKnown() is sorted newest-first, so Habit.recompute() takes
  /// its last element as the start of the recomputed range.
  LocalDate? get oldestKnownDate {
    if (_byDate.isEmpty) return null;
    return _byDate.keys.reduce((a, b) => a.isOlderThan(b) ? a : b);
  }

  /// Line-for-line the same walk as EntryList.getByInterval in Kotlin.
  List<Entry> getByInterval(LocalDate from, LocalDate to) {
    final result = <Entry>[];
    if (from.isNewerThan(to)) return result;
    var current = to;
    while (!current.isOlderThan(from)) {
      result.add(_byDate[current] ?? Entry(current, Entry.unknown));
      current = current.minus(1);
    }
    return result;
  }
}

void main() {
  late LocalDate today;
  late FakeComputedEntries entries;
  late ScoreList scores;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
    entries = FakeComputedEntries();
    scores = ScoreList();
  });

  tearDown(resetToday);

  void reset() {
    entries = FakeComputedEntries();
    scores = ScoreList();
  }

  /// Mirrors Habit.recompute(): the computed entries, the oldest known day
  /// (today when there is none) and today + 30.
  void recompute({
    Frequency frequency = Frequency.daily,
    bool isNumerical = false,
    NumericalHabitType numericalHabitType = NumericalHabitType.atLeast,
    double targetValue = 2.0,
  }) {
    final to = today.plus(30);
    var from = entries.oldestKnownDate ?? today;
    if (from.isNewerThan(to)) from = to;
    scores.recompute(
      frequency: frequency,
      isNumerical: isNumerical,
      numericalHabitType: numericalHabitType,
      targetValue: targetValue,
      computedEntries: entries.getByInterval,
      from: from,
      to: to,
    );
  }

  // ---- fixture helpers, mirroring the Kotlin test's private helpers --------

  void check(int offset) =>
      entries.add(Entry(today.minus(offset), Entry.yesManual));

  void checkRange(int from, int to) {
    for (var i = from; i < to; i++) {
      check(i);
    }
  }

  void addSkip(int offset) =>
      entries.add(Entry(today.minus(offset), Entry.skip));

  void addEntry(int offset, int value) =>
      entries.add(Entry(today.minus(offset), value));

  void addEntries(int from, int to, int value) {
    for (var i = from; i < to; i++) {
      addEntry(i, value);
    }
  }

  /// The Kotlin `checkScoreValues`: expectedValues[0] is today, then one day
  /// back per element.
  void expectScoreSequence(List<double> expected, String rule) {
    var current = today;
    for (final value in expected) {
      expect(scores[current].value, closeTo(value, e), reason: rule);
      current = current.minus(1);
    }
  }

  group('models.score-list-recompute-boolean', () {
    test('#1 #2 one Score per date in [from, to], walked oldest to newest', () {
      // A single check one day before today: from == today - 1, to == today +
      // 30. values[0] is the newest day (to) and the loop writes
      // map[from.plus(i)], so the checked day - the OLDEST day of the range -
      // is the first one scored.
      check(1);
      recompute();

      final from = today.minus(1);
      final to = today.plus(30);
      final all = scores.getByInterval(from, to);
      expect(all.length, from.daysUntil(to) + 1,
          reason: 'models.score-list-recompute-boolean#1');
      for (var i = 0; i < all.length; i++) {
        expect(all[i].date, to.minus(i),
            reason: 'models.score-list-recompute-boolean#1');
      }

      // Nothing outside [from, to] was written.
      expect(scores[from.minus(1)].value, 0.0,
          reason: 'models.score-list-recompute-boolean#1');
      expect(scores[to.plus(1)].value, 0.0,
          reason: 'models.score-list-recompute-boolean#1');

      // i == 0 scores `from` (the checked day), i == 1 scores the day after it,
      // by which time the check has already left the 1-day rolling window.
      expect(scores[from].value, closeTo(0.051922, e),
          reason: 'models.score-list-recompute-boolean#2');
      expect(scores[today].value, closeTo(0.049226, e),
          reason: 'models.score-list-recompute-boolean#2');
      // Each stored Score carries its own date.
      expect(scores[from].date, from,
          reason: 'models.score-list-recompute-boolean#2');
    });

    test('#3 #4 freq is computed before the numerator/denominator doubling',
        () {
      // 1/7 boolean: freq stays 1/7 while the numerator becomes 2, so a single
      // check only completes half of the (doubled) requirement.
      check(0);
      recompute(frequency: Frequency(1, 7));
      expect(scores[today].value, closeTo(Score.compute(1 / 7, 0.0, 0.5), 1e-12),
          reason: 'models.score-list-recompute-boolean#4');
      // Had freq been doubled too, the multiplier would have been the one of
      // 2/7 instead.
      expect(scores[today].value,
          isNot(closeTo(Score.compute(2 / 7, 0.0, 0.5), 1e-9)),
          reason: 'models.score-list-recompute-boolean#3');

      // Daily habits are not doubled: one check completes the requirement.
      reset();
      check(0);
      recompute(frequency: Frequency.daily);
      expect(scores[today].value, closeTo(0.051922, e),
          reason: 'models.score-list-recompute-boolean#4');
      expect(scores[today].value, closeTo(Score.compute(1.0, 0.0, 1.0), 1e-12),
          reason: 'models.score-list-recompute-boolean#3');
    });

    test('#5 only YES_MANUAL enters the rolling sum', () {
      // YES_AUTO and NO never enter it, so the score stays at zero.
      entries.add(Entry(today.minus(2), Entry.yesAuto));
      entries.add(Entry(today.minus(1), Entry.no));
      recompute();
      expect(scores[today].value, 0.0,
          reason: 'models.score-list-recompute-boolean#5');
      expect(scores[today.minus(2)].value, 0.0,
          reason: 'models.score-list-recompute-boolean#5');

      // SKIP does not enter it either: with a 1/7 frequency (numerator doubled
      // to 2) yesterday's SKIP plus today's check gives 1/2, not 2/2.
      reset();
      addSkip(1);
      check(0);
      recompute(frequency: Frequency(1, 7));
      expect(scores[today].value, closeTo(Score.compute(1 / 7, 0.0, 0.5), 1e-12),
          reason: 'models.score-list-recompute-boolean#5');

      // The subtraction half: a check leaves the window `denominator` days
      // later, so the score decays instead of climbing again.
      reset();
      check(1);
      recompute();
      expect(scores[today.minus(1)].value, closeTo(0.051922, e),
          reason: 'models.score-list-recompute-boolean#5');
      expect(scores[today].value, closeTo(0.049226, e),
          reason: 'models.score-list-recompute-boolean#5');
    });

    test('#6 a SKIP day repeats the score of the day before it', () {
      // Kotlin: YesNoScoreListTest.test_getValueWithSkip2
      check(5);
      addSkip(4);
      recompute();
      expectScoreSequence(
        [
          0.041949,
          0.044247,
          0.046670,
          0.049226,
          0.051922, // the SKIP day
          0.051922, // the checked day
          0.0,
        ],
        'models.score-list-recompute-boolean#6',
      );
    });

    test('#7 percentageCompleted is min(1, rollingSum / numerator)', () {
      // 1/7 boolean: numerator 2, denominator 14. Five consecutive checks push
      // the rolling sum to 5, but the percentage is clamped at 1.
      checkRange(0, 5);
      recompute(frequency: Frequency(1, 7));

      const freq = 1 / 7;
      var expected = Score.compute(freq, 0.0, 0.5); // rollingSum 1 of 2
      for (final _ in [1, 2, 3, 4]) {
        expected = Score.compute(freq, expected, 1.0);
      }
      expect(scores[today].value, closeTo(expected, 1e-12),
          reason: 'models.score-list-recompute-boolean#7');
      expect(expected, lessThan(1.0),
          reason: 'models.score-list-recompute-boolean#7');
    });

    test('#8 previousValue starts at 0.0 for boolean habits', () {
      recompute();
      expect(scores[today].value, 0.0,
          reason: 'models.score-list-recompute-boolean#8');

      reset();
      entries.add(Entry(today, Entry.no));
      recompute();
      expect(scores[today].value, 0.0,
          reason: 'models.score-list-recompute-boolean#8');
    });

    test('#9 twenty daily checks produce the reference sequence', () {
      // Kotlin: YesNoScoreListTest.test_getValue
      checkRange(0, 20);
      recompute();
      expectScoreSequence(
        [
          0.655747,
          0.636894,
          0.617008,
          0.596033,
          0.573910,
          0.550574,
          0.525961,
          0.500000,
          0.472617,
          0.443734,
          0.413270,
          0.381137,
          0.347244,
          0.311495,
          0.273788,
          0.234017,
          0.192067,
          0.147820,
          0.101149,
          0.051922,
          0.000000,
          0.000000,
          0.000000,
        ],
        'models.score-list-recompute-boolean#9',
      );
    });

    test('#10 the same twenty days with three SKIPs', () {
      // Kotlin: YesNoScoreListTest.test_getValueWithSkip
      checkRange(0, 20);
      addSkip(5);
      addSkip(10);
      addSkip(11);
      recompute();
      expectScoreSequence(
        [
          0.596033,
          0.573910,
          0.550574,
          0.525961,
          0.500000,
          0.472617,
          0.472617,
          0.443734,
          0.413270,
          0.381137,
          0.347244,
          0.347244,
          0.347244,
          0.311495,
          0.273788,
          0.234017,
          0.192067,
          0.147820,
          0.101149,
          0.051922,
          0.000000,
          0.000000,
          0.000000,
        ],
        'models.score-list-recompute-boolean#10',
      );
    });

    test('#11 imperfect non-daily habits converge to the completed fraction',
        () {
      // Kotlin: YesNoScoreListTest.test_imperfectNonDaily. Two checks out of
      // three required per week.
      for (var k = 0; k < 100; k++) {
        check(7 * k);
        check(7 * k + 1);
      }
      recompute(frequency: Frequency(3, 7));
      expect(scores[today].value, closeTo(2 / 3.0, e),
          reason: 'models.score-list-recompute-boolean#11');

      // The very same entries against a 4-per-week frequency: two of four.
      scores = ScoreList();
      recompute(frequency: Frequency(4, 7));
      expect(scores[today].value, closeTo(0.5, e),
          reason: 'models.score-list-recompute-boolean#11');
    });

    test('#12 irregular weekly habits still converge to 1.0', () {
      // Kotlin: YesNoScoreListTest.test_irregularNonDaily. One check per week,
      // but on the first day of one week and the last day of the next.
      for (var k = 0; k < 100; k++) {
        check(14 * k);
        check(14 * k + 13);
      }
      recompute(frequency: Frequency(1, 7));
      expect(scores[today].value, closeTo(1.0, 1e-3),
          reason: 'models.score-list-recompute-boolean#12');
    });
  });

  group('models.score-list-recompute-numerical-at-least', () {
    test('#1 numerical habits never double the numerator/denominator', () {
      // 1/2 numerical: the rolling window is 2 days, not 4, so the value from
      // two days ago has already left it by today.
      addEntry(2, 1000);
      addEntry(0, 1000);
      recompute(
        frequency: Frequency(1, 2),
        isNumerical: true,
        targetValue: 2.0,
      );

      const freq = 0.5;
      final v0 = Score.compute(freq, 0.0, 0.5); // today - 2: 1.0 of 2.0
      final v1 = Score.compute(freq, v0, 0.5); // today - 1: still 1.0 in window
      final v2 = Score.compute(freq, v1, 0.5); // today: old value subtracted
      expect(scores[today].value, closeTo(v2, 1e-12),
          reason: 'models.score-list-recompute-numerical-at-least#1');
      // With a doubled denominator both values would still be in the window,
      // giving a full 2.0 and therefore a strictly larger score.
      expect(scores[today].value,
          lessThan(Score.compute(freq, v1, 1.0) - 1e-6),
          reason: 'models.score-list-recompute-numerical-at-least#1');
    });

    test('#2 rolling sum uses max(0, value) and drops values that age out', () {
      // UNKNOWN contributes 0, and the entry leaves the window after
      // `denominator` days.
      addEntry(2, 2000);
      recompute(
        frequency: Frequency(1, 2),
        isNumerical: true,
        targetValue: 2.0,
      );
      const freq = 0.5;
      final v0 = Score.compute(freq, 0.0, 1.0);
      final v1 = Score.compute(freq, v0, 1.0); // UNKNOWN adds 0, nothing leaves
      final v2 = Score.compute(freq, v1, 0.0); // the 2000 is subtracted
      expect(scores[today].value, closeTo(v2, 1e-12),
          reason: 'models.score-list-recompute-numerical-at-least#2');

      // SKIP == 3 leaks into the rolling sum of the following days: with a
      // target of 0.002, yesterday's SKIP alone completes today.
      reset();
      addSkip(1);
      addEntry(0, 0);
      recompute(
        frequency: Frequency(1, 7),
        isNumerical: true,
        targetValue: 0.002,
      );
      expect(scores[today].value, closeTo(Score.compute(1 / 7, 0.0, 1.0), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-least#2');
    });

    test('#3 #5 #8 the rolling sum is normalized by 1000 against the target',
        () {
      addEntry(0, 1000);
      recompute(isNumerical: true, targetValue: 1.0);
      expect(scores[today].value, closeTo(Score.compute(1.0, 0.0, 1.0), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-least#3');

      reset();
      addEntry(0, 500);
      recompute(isNumerical: true, targetValue: 1.0);
      expect(scores[today].value, closeTo(Score.compute(1.0, 0.0, 0.5), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-least#3');

      reset();
      addEntry(0, 500);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, closeTo(Score.compute(1.0, 0.0, 0.25), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-least#5');
      expect(scores[today].value, closeTo(0.012981, e),
          reason: 'models.score-list-recompute-numerical-at-least#8');
    });

    test('#6 a non-positive target completes every day and stays finite', () {
      // Kotlin: NumericalAtLeastScoreListTest.test_withZeroTarget, over the
      // entries of HabitFixtures.createNumericalHabit().
      const times = [0, 1, 3, 5, 7, 8, 9, 10];
      const values = [100, 200, 300, 400, 500, 600, 700, 800];
      for (var i = 0; i < times.length; i++) {
        addEntry(times[i], values[i]);
      }
      recompute(isNumerical: true, targetValue: 0.0);

      expect(scores[today].value.isFinite, isTrue,
          reason: 'models.score-list-recompute-numerical-at-least#6');
      // percentageCompleted is 1.0 on each of the 11 days of the range, so the
      // score is exactly 1 - multiplier^11.
      final m = multiplierOf(1.0);
      expect(scores[today].value, closeTo(1 - pow(m, 11).toDouble(), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-least#6');
    });

    test('#7 previousValue starts at 0.0 for AT_LEAST', () {
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, 0.0,
          reason: 'models.score-list-recompute-numerical-at-least#7');

      reset();
      addEntry(0, 0);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, 0.0,
          reason: 'models.score-list-recompute-numerical-at-least#7');
    });

    test('#9 twenty days at the target reproduce the boolean sequence', () {
      // Kotlin: NumericalAtLeastScoreListTest.test_getValue
      addEntries(0, 20, 2000);
      recompute(isNumerical: true, targetValue: 2.0);
      expectScoreSequence(
        [
          0.655747,
          0.636894,
          0.617008,
          0.596033,
          0.573910,
          0.550574,
          0.525961,
          0.500000,
          0.472617,
          0.443734,
          0.413270,
          0.381137,
          0.347244,
          0.311495,
          0.273788,
          0.234017,
          0.192067,
          0.147820,
          0.101149,
          0.051922,
          0.000000,
          0.000000,
          0.000000,
        ],
        'models.score-list-recompute-numerical-at-least#9',
      );
    });

    test('#10 overachieving is clamped', () {
      // Kotlin: NumericalAtLeastScoreListTest.overeachievingIsntRelevant
      addEntry(0, 10000000);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, closeTo(0.051922, e),
          reason: 'models.score-list-recompute-numerical-at-least#10');

      reset();
      addEntry(0, 2000);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, closeTo(0.051922, e),
          reason: 'models.score-list-recompute-numerical-at-least#10');
    });

    test('#11 a steady fraction of the target converges to that fraction', () {
      // Kotlin: NumericalAtLeastScoreListTest.shouldAchieveComparableScoreToProgress
      addEntries(0, 500, 1000);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, closeTo(0.5, e),
          reason: 'models.score-list-recompute-numerical-at-least#11');

      reset();
      addEntries(0, 500, 500);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, closeTo(0.25, e),
          reason: 'models.score-list-recompute-numerical-at-least#11');
    });

    test('#4 #12 SKIP days repeat the previous score and never change it', () {
      // Kotlin: NumericalAtLeastScoreListWithSkipTest.test_getValue
      addEntries(0, 10, 2000);
      addEntries(10, 11, Entry.skip);
      addEntries(11, 15, 2000);
      addEntries(15, 16, Entry.skip);
      addEntries(16, 20, 2000);
      recompute(isNumerical: true, targetValue: 2.0);
      expectScoreSequence(
        [
          0.617008,
          0.596033,
          0.573910,
          0.550574,
          0.525961,
          0.500000,
          0.472617,
          0.443734,
          0.413270,
          0.381137,
          0.347244, // skipped day: same score as the previous day
          0.347244,
          0.311495,
          0.273788,
          0.234017,
          0.192067, // skipped day: same score as the previous day
          0.192067,
          0.147820,
          0.101149,
          0.051922,
          0.000000,
          0.000000,
          0.000000,
        ],
        'models.score-list-recompute-numerical-at-least#4',
      );

      // Kotlin: NumericalAtLeastScoreListWithSkipTest.skipsShouldNotAffectScore
      reset();
      addEntries(0, 500, 1000);
      recompute(isNumerical: true, targetValue: 2.0);
      final initialScore = scores[today].value;

      addEntries(500, 1000, Entry.skip);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, closeTo(initialScore, e),
          reason: 'models.score-list-recompute-numerical-at-least#12');

      addEntries(0, 300, 1000);
      addEntries(300, 500, Entry.skip);
      addEntries(500, 700, 1000);
      recompute(isNumerical: true, targetValue: 2.0);
      expect(scores[today].value, closeTo(initialScore, e),
          reason: 'models.score-list-recompute-numerical-at-least#12');
    });
  });

  group('models.score-list-recompute-numerical-at-most', () {
    test('#1 previousValue starts at 1.0 for AT_MOST', () {
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(1.0, e),
          reason: 'models.score-list-recompute-numerical-at-most#1');
      // The AT_MOST initial value only applies to numerical habits.
      reset();
      recompute(
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, 0.0,
          reason: 'models.score-list-recompute-numerical-at-most#1');
    });

    test('#2 percentageCompleted mirrors the overshoot, clamped to [0, 1]', () {
      void singleDay(int value) {
        reset();
        addEntry(0, value);
        recompute(
          isNumerical: true,
          numericalHabitType: NumericalHabitType.atMost,
          targetValue: 2.0,
        );
      }

      // rollingSum == target -> 1.0
      singleDay(2000);
      expect(scores[today].value, closeTo(1.0, 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#2');

      // rollingSum == 2 * target -> 0.0
      singleDay(4000);
      expect(scores[today].value, closeTo(Score.compute(1.0, 1.0, 0.0), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#2');

      // rollingSum == 0 -> clamped from 2.0 down to 1.0
      singleDay(0);
      expect(scores[today].value, closeTo(1.0, 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#2');

      // halfway between target and twice the target -> 0.5
      singleDay(3000);
      expect(scores[today].value, closeTo(Score.compute(1.0, 1.0, 0.5), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#2');
    });

    test('#3 a non-positive target is all-or-nothing and stays finite', () {
      addEntry(0, 1000);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 0.0,
      );
      expect(scores[today].value.isFinite, isTrue,
          reason: 'models.score-list-recompute-numerical-at-most#3');
      expect(scores[today].value, closeTo(Score.compute(1.0, 1.0, 0.0), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#3');

      reset();
      addEntry(0, 0);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 0.0,
      );
      expect(scores[today].value.isFinite, isTrue,
          reason: 'models.score-list-recompute-numerical-at-most#3');
      expect(scores[today].value, closeTo(1.0, 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#3');
    });

    test('#4 SKIP days are carried over, as with AT_LEAST', () {
      addEntry(2, 5000);
      addSkip(1);
      addEntry(0, 5000);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      final skipped = scores[today.minus(1)].value;
      expect(skipped, closeTo(scores[today.minus(2)].value, 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#4');
      expect(skipped, closeTo(Score.compute(1.0, 1.0, 0.0), 1e-12),
          reason: 'models.score-list-recompute-numerical-at-most#4');
    });

    test('#5 the reference AT_MOST sequence', () {
      // Kotlin: NumericalAtMostScoreListTest.test_getValue
      addEntry(20, 1000);
      addEntries(0, 20, 5000);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expectScoreSequence(
        [
          0.344253,
          0.363106,
          0.382992,
          0.403967,
          0.426090,
          0.449426,
          0.474039,
          0.500000,
          0.527383,
          0.556266,
          0.586730,
          0.618863,
          0.652756,
          0.688505,
          0.726212,
          0.765983,
          0.807933,
          0.852180,
          0.898851,
          0.948078,
          1.0,
          0.0,
          0.0,
        ],
        'models.score-list-recompute-numerical-at-most#5',
      );
    });

    test('#6 empty, then two days over target, then a looser frequency', () {
      // Kotlin: NumericalAtMostScoreListTest.test_recompute
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(1.0, e),
          reason: 'models.score-list-recompute-numerical-at-most#6');

      addEntries(0, 2, 5000);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(0.898850, e),
          reason: 'models.score-list-recompute-numerical-at-most#6');

      recompute(
        frequency: Frequency(1, 2),
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(0.927369, e),
          reason: 'models.score-list-recompute-numerical-at-most#6');
    });

    test('#7 a steady overshoot converges to the mirrored fraction', () {
      // Kotlin: NumericalAtMostScoreListTest.shouldAchieveComparableScoreToProgress
      addEntries(0, 500, 3000);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(0.5, e),
          reason: 'models.score-list-recompute-numerical-at-most#7');

      reset();
      addEntries(0, 500, 3500);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(0.25, e),
          reason: 'models.score-list-recompute-numerical-at-most#7');
    });

    test('#8 undershooting and overshooting are both clamped', () {
      // Kotlin: NumericalAtMostScoreListTest.undereachievingIsntRelevant
      addEntry(1, 10000000);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(0.950773, e),
          reason: 'models.score-list-recompute-numerical-at-most#8');

      // Kotlin: NumericalAtMostScoreListTest.overeachievingIsntRelevant
      reset();
      addEntry(0, 5000);
      addEntry(1, 0);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(0.948077, e),
          reason: 'models.score-list-recompute-numerical-at-most#8');

      addEntry(1, 1000);
      recompute(
        isNumerical: true,
        numericalHabitType: NumericalHabitType.atMost,
        targetValue: 2.0,
      );
      expect(scores[today].value, closeTo(0.948077, e),
          reason: 'models.score-list-recompute-numerical-at-most#8');
    });

    test('#9 however good the score, isCompletedToday() is always false for a '
        'numerical AT_MOST habit', () {
      final factory = MemoryModelFactory();

      // A perfect AT_MOST day — nothing logged against a target of 2.0 — still
      // does not count as completed.
      final untouched = factory.buildHabit()
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atMost
        ..targetValue = 2.0;
      untouched.recompute();
      expect(untouched.scores[today].value, closeTo(1.0, e),
          reason: 'models.score-list-recompute-numerical-at-most#9');
      expect(untouched.isCompletedToday(), isFalse,
          reason: 'models.score-list-recompute-numerical-at-most#9');

      // And neither does any other value: below, at, or above the target.
      for (final value in <int>[Entry.unknown, 0, 1000, 2000, 5000]) {
        final habit = factory.buildHabit()
          ..type = HabitType.numerical
          ..targetType = NumericalHabitType.atMost
          ..targetValue = 2.0;
        habit.originalEntries.add(Entry(today, value));
        habit.recompute();
        expect(habit.isCompletedToday(), isFalse,
            reason:
                'models.score-list-recompute-numerical-at-most#9 (value $value)');
      }

      // The same habit read as AT_LEAST does complete, which is what makes the
      // AT_MOST answer a deliberate constant rather than an accident.
      final atLeast = factory.buildHabit()
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atLeast
        ..targetValue = 2.0;
      atLeast.originalEntries.add(Entry(today, 5000));
      atLeast.recompute();
      expect(atLeast.isCompletedToday(), isTrue,
          reason: 'models.score-list-recompute-numerical-at-most#9');
      atLeast.targetType = NumericalHabitType.atMost;
      atLeast.recompute();
      expect(atLeast.isCompletedToday(), isFalse,
          reason: 'models.score-list-recompute-numerical-at-most#9');
    });
  });

  group('models.score-list-access', () {
    test('#1 get returns the stored score, or a zero score outside the range',
        () {
      checkRange(0, 20);
      recompute();

      expect(scores[today].value, closeTo(0.655747, e),
          reason: 'models.score-list-access#1');
      expect(scores[today].date, today, reason: 'models.score-list-access#1');

      // Before the first entry.
      expect(scores[today.minus(20)], Score(today.minus(20), 0.0),
          reason: 'models.score-list-access#1');
      expect(scores[today.minus(500)], Score(today.minus(500), 0.0),
          reason: 'models.score-list-access#1');
      // After the last computed day (today + 30).
      expect(scores[today.plus(31)], Score(today.plus(31), 0.0),
          reason: 'models.score-list-access#1');
    });

    test('#2 getByInterval yields one score per day, newest first', () {
      checkRange(0, 20);
      recompute();

      final result = scores.getByInterval(today.minus(3), today);
      expect(result.length, 4, reason: 'models.score-list-access#2');
      expect(result.map((s) => s.date).toList(),
          [today, today.minus(1), today.minus(2), today.minus(3)],
          reason: 'models.score-list-access#2');
      expect(result[0].value, closeTo(0.655747, e),
          reason: 'models.score-list-access#2');
      expect(result[3].value, closeTo(0.596033, e),
          reason: 'models.score-list-access#2');

      // A single-day interval still yields one score.
      expect(scores.getByInterval(today, today).length, 1,
          reason: 'models.score-list-access#2');

      // Days outside the recomputed range are still returned, with value 0.
      final wide = scores.getByInterval(today.minus(22), today.minus(19));
      expect(wide.length, 4, reason: 'models.score-list-access#2');
      expect(wide[0].value, closeTo(0.051922, e),
          reason: 'models.score-list-access#2');
      expect(wide[1].value, 0.0, reason: 'models.score-list-access#2');

      // from newer than to gives an empty list.
      expect(scores.getByInterval(today, today.minus(1)), isEmpty,
          reason: 'models.score-list-access#2');
      expect(scores.getByInterval(today.plus(1), today), isEmpty,
          reason: 'models.score-list-access#2');
    });

    test('#3 recompute clears the whole map first', () {
      checkRange(0, 20);
      recompute();
      expect(scores[today].value, closeTo(0.655747, e),
          reason: 'models.score-list-access#3');

      // Recomputing over a range that ends well before today must wipe every
      // previously stored score, including the ones outside the new range.
      scores.recompute(
        frequency: Frequency.daily,
        isNumerical: false,
        numericalHabitType: NumericalHabitType.atLeast,
        targetValue: 2.0,
        computedEntries: entries.getByInterval,
        from: today.minus(19),
        to: today.minus(10),
      );
      expect(scores[today].value, 0.0, reason: 'models.score-list-access#3');
      // The ten days that are still in range keep the values they had, since
      // the range starts at the same day as before.
      expect(scores[today.minus(10)].value, closeTo(0.413270, e),
          reason: 'models.score-list-access#3');
      expect(scores[today.minus(19)].value, closeTo(0.051922, e),
          reason: 'models.score-list-access#3');
    });
  });
}
