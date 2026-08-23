import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/score.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Rules ported from docs/parity/FEATURES.md -> models.frequency
/// Source: uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Frequency.kt
/// (Frequency.kt has no dedicated Kotlin test; cases are written from the rules.)
void main() {
  /// One YES_MANUAL entry per offset in [manualOffsets] (days before [today]),
  /// UNKNOWN everywhere else — the shape `EntryList.getByInterval` hands to
  /// `ScoreList.recompute`: one entry per day in [from, to], newest first.
  List<Entry> Function(LocalDate, LocalDate) checkmarksAt(
    LocalDate today,
    Set<int> manualOffsets,
  ) {
    return (LocalDate from, LocalDate to) {
      final result = <Entry>[];
      if (from.isNewerThan(to)) return result;
      var current = to;
      while (!current.isOlderThan(from)) {
        final offset = current.daysUntil(today);
        result.add(Entry(
          current,
          manualOffsets.contains(offset) ? Entry.yesManual : Entry.unknown,
        ));
        current = current.minus(1);
      }
      return result;
    };
  }

  /// The boolean branch of `ScoreList.recompute`, spelled out independently so
  /// the rolling-sum window and the numerator can be varied by hand.
  /// [valuesNewestFirst] is the vector `computedEntries(from, to)` produces.
  double booleanScoreOfLastDay(
    List<int> valuesNewestFirst,
    int numerator,
    int denominator,
    double freq,
  ) {
    var rollingSum = 0.0;
    var previous = 0.0;
    for (var i = 0; i < valuesNewestFirst.length; i++) {
      final offset = valuesNewestFirst.length - i - 1;
      if (valuesNewestFirst[offset] == Entry.yesManual) rollingSum += 1.0;
      if (offset + denominator < valuesNewestFirst.length &&
          valuesNewestFirst[offset + denominator] == Entry.yesManual) {
        rollingSum -= 1.0;
      }
      if (valuesNewestFirst[offset] != Entry.skip) {
        previous =
            Score.compute(freq, previous, min(1.0, rollingSum / numerator));
      }
    }
    return previous;
  }

  group('models.frequency', () {
    test('#1/#9 value object of numerator and denominator (both int)', () {
      final f = Frequency(3, 7);
      expect(f.numerator, 3, reason: 'models.frequency#1');
      expect(f.denominator, 7, reason: 'models.frequency#9');
      expect(f.numerator, isA<int>(), reason: 'models.frequency#1');
      expect(f.denominator, isA<int>(), reason: 'models.frequency#9');
      expect(f.toString(), 'Frequency(numerator=3, denominator=7)',
          reason: 'models.frequency#9');
    });

    test('#2/#10 numerator == denominator normalises to exactly 1/1', () {
      final two = Frequency(2, 2);
      expect(two.numerator, 1, reason: 'models.frequency#2');
      expect(two.denominator, 1, reason: 'models.frequency#2');

      final seven = Frequency(7, 7);
      expect(seven.numerator, 1, reason: 'models.frequency#10');
      expect(seven.denominator, 1, reason: 'models.frequency#10');
      expect(seven, Frequency(1, 1), reason: 'models.frequency#10');

      final thirty = Frequency(30, 30);
      expect(thirty, Frequency(1, 1), reason: 'models.frequency#10');

      final zero = Frequency(0, 0);
      expect(zero.numerator, 1, reason: 'models.frequency#2');
      expect(zero.denominator, 1, reason: 'models.frequency#2');

      // Non-equal pairs are left exactly as given, never reduced.
      final threeSevenths = Frequency(3, 7);
      expect(threeSevenths.numerator, 3, reason: 'models.frequency#2');
      expect(threeSevenths.denominator, 7, reason: 'models.frequency#2');
      final twoFourths = Frequency(2, 4);
      expect(twoFourths.numerator, 2, reason: 'models.frequency#2');
      expect(twoFourths.denominator, 4, reason: 'models.frequency#2');
      expect(twoFourths == Frequency(1, 2), isFalse,
          reason: 'models.frequency#2');
    });

    test('#3/#11 toDouble() is numerator / denominator as a double', () {
      expect(Frequency(1, 1).toDouble(), 1.0, reason: 'models.frequency#3');
      expect(Frequency(1, 2).toDouble(), 0.5, reason: 'models.frequency#3');
      expect(Frequency(3, 7).toDouble(), closeTo(0.42857142857142855, 1e-15),
          reason: 'models.frequency#11');
      expect(Frequency(3, 7).toDouble(), 3 / 7, reason: 'models.frequency#11');
      expect(Frequency(1, 7).toDouble(), 1 / 7, reason: 'models.frequency#11');
      expect(Frequency(2, 7).toDouble(), 2 / 7, reason: 'models.frequency#11');
      // Normalisation happens first: 7/7 is 1/1, so toDouble() is 1.0.
      expect(Frequency(7, 7).toDouble(), 1.0, reason: 'models.frequency#3');
      // Integer division must not be used: 1/30 is not 0.
      expect(Frequency(1, 30).toDouble(), 1 / 30, reason: 'models.frequency#11');
    });

    test('#4/#12 the four named constants', () {
      expect(Frequency.daily.numerator, 1, reason: 'models.frequency#4');
      expect(Frequency.daily.denominator, 1, reason: 'models.frequency#4');
      expect(Frequency.threeTimesPerWeek.numerator, 3,
          reason: 'models.frequency#4');
      expect(Frequency.threeTimesPerWeek.denominator, 7,
          reason: 'models.frequency#4');
      expect(Frequency.twoTimesPerWeek.numerator, 2,
          reason: 'models.frequency#12');
      expect(Frequency.twoTimesPerWeek.denominator, 7,
          reason: 'models.frequency#12');
      expect(Frequency.weekly.numerator, 1, reason: 'models.frequency#12');
      expect(Frequency.weekly.denominator, 7, reason: 'models.frequency#12');

      expect(Frequency.daily, Frequency(1, 1), reason: 'models.frequency#4');
      expect(Frequency.threeTimesPerWeek, Frequency(3, 7),
          reason: 'models.frequency#4');
      expect(Frequency.twoTimesPerWeek, Frequency(2, 7),
          reason: 'models.frequency#12');
      expect(Frequency.weekly, Frequency(1, 7), reason: 'models.frequency#12');
    });

    test('#5 constants are immutable, so sharing them cannot alias', () {
      // Kotlin's Frequency has `var` fields, so `habit.frequency =
      // Frequency.DAILY` hands out the one shared instance and a later
      // mutation would corrupt the constant. The Dart port is immutable
      // instead: there is no setter to call, and the constant survives being
      // handed around.
      final a = Frequency.daily;
      final b = Frequency.daily;
      expect(identical(a, b), isTrue, reason: 'models.frequency#5');

      // Re-reading a constant after other frequencies have been built still
      // yields the original values.
      Frequency(5, 9);
      Frequency(2, 2);
      expect(Frequency.daily.numerator, 1, reason: 'models.frequency#5');
      expect(Frequency.daily.denominator, 1, reason: 'models.frequency#5');
      expect(Frequency.weekly.numerator, 1, reason: 'models.frequency#5');
      expect(Frequency.weekly.denominator, 7, reason: 'models.frequency#5');

      // A freshly built equal frequency is a distinct object, so callers that
      // build their own never share storage with the constant.
      final fresh = Frequency(1, 7);
      expect(identical(fresh, Frequency.weekly), isFalse,
          reason: 'models.frequency#5');
      expect(fresh, Frequency.weekly, reason: 'models.frequency#5');
    });

    test('#6 equality is structural on (numerator, denominator)', () {
      expect(Frequency(3, 7) == Frequency(3, 7), isTrue,
          reason: 'models.frequency#6');
      expect(Frequency(3, 7).hashCode, Frequency(3, 7).hashCode,
          reason: 'models.frequency#6');
      expect(Frequency(3, 7) == Frequency(2, 7), isFalse,
          reason: 'models.frequency#6');
      expect(Frequency(1, 7) == Frequency(1, 30), isFalse,
          reason: 'models.frequency#6');

      // After normalisation, every n/n is equal to 1/1 and hashes alike.
      expect(Frequency(7, 7) == Frequency(1, 1), isTrue,
          reason: 'models.frequency#6');
      expect(Frequency(7, 7).hashCode, Frequency(1, 1).hashCode,
          reason: 'models.frequency#6');
      expect(Frequency(0, 0) == Frequency.daily, isTrue,
          reason: 'models.frequency#6');

      // Usable as a set/map key.
      final set = {Frequency(3, 7), Frequency(3, 7), Frequency(7, 7)};
      expect(set.length, 2, reason: 'models.frequency#6');
      expect(set.contains(Frequency.daily), isTrue,
          reason: 'models.frequency#6');
      expect(set.contains(Frequency.threeTimesPerWeek), isTrue,
          reason: 'models.frequency#6');
    });

    test('#7 denominators 30 and 31 mean calendar months; every other '
        'denominator is used literally', () {
      Entry check(int year, int month, int day) =>
          Entry(LocalDate.ymd(year, month, day), Entry.yesManual);

      // January has 31 days, so both 'monthly' denominators produce the same
      // 31-day interval when it starts on the 1st.
      for (final den in <int>[30, 31]) {
        final interval =
            EntryList.buildIntervals(Frequency(1, den), [check(2015, 1, 1)])
                .single;
        expect(interval.end, LocalDate.ymd(2015, 1, 31),
            reason: 'models.frequency#7');
        expect(interval.length, 31, reason: 'models.frequency#7');
      }

      // February 2015 has 28: the very same 1/30 frequency spans 28 days there,
      // which is what makes this a calendar month rather than a literal 30.
      final february =
          EntryList.buildIntervals(Frequency(1, 30), [check(2015, 2, 1)])
              .single;
      expect(february.end, LocalDate.ymd(2015, 2, 28),
          reason: 'models.frequency#7');
      expect(february.length, 28, reason: 'models.frequency#7');

      // An interval that begins on the last day of a month takes the length of
      // the NEXT month.
      final lastDay =
          EntryList.buildIntervals(Frequency(1, 30), [check(2015, 1, 31)])
              .single;
      expect(lastDay.end, LocalDate.ymd(2015, 2, 27),
          reason: 'models.frequency#7');
      expect(lastDay.length, 28, reason: 'models.frequency#7');

      // 29, 28, 7 and 32 are all literal: the month length never enters.
      final literals = <int, LocalDate>{
        7: LocalDate.ymd(2015, 1, 7),
        28: LocalDate.ymd(2015, 1, 28),
        29: LocalDate.ymd(2015, 1, 29),
        32: LocalDate.ymd(2015, 2, 1),
      };
      literals.forEach((den, end) {
        final interval =
            EntryList.buildIntervals(Frequency(1, den), [check(2015, 1, 1)])
                .single;
        expect(interval.end, end, reason: 'models.frequency#7');
        expect(interval.length, den, reason: 'models.frequency#7');
      });
    });

    test('#8 the frequency drives interval construction, the score decay '
        'multiplier and the rolling-sum window', () {
      final today = LocalDate.ymd(2015, 1, 25);

      // (1) Interval construction for the YES_AUTO fill-in. The same three
      // checkmarks become three one-day intervals under DAILY and a single
      // seven-day interval under 3/7 — and only the latter produces YES_AUTO.
      final marks = <Entry>[
        Entry(today, Entry.yesManual),
        Entry(today.minus(2), Entry.yesManual),
        Entry(today.minus(4), Entry.yesManual),
      ];
      final daily = EntryList.buildIntervals(Frequency.daily, marks);
      expect(daily.length, 3, reason: 'models.frequency#8');
      expect(daily.map((i) => i.length).toList(), <int>[1, 1, 1],
          reason: 'models.frequency#8');
      final threeSevenths = EntryList.buildIntervals(Frequency(3, 7), marks);
      expect(threeSevenths.length, 1, reason: 'models.frequency#8');
      expect(threeSevenths.single.length, 7, reason: 'models.frequency#8');

      final original = EntryList();
      for (final mark in marks) {
        original.add(mark);
      }
      final computedDaily = EntryList()
        ..recomputeFrom(original, Frequency.daily, isNumerical: false);
      final computedWeekly = EntryList()
        ..recomputeFrom(original, Frequency(3, 7), isNumerical: false);
      expect(
        computedDaily.getKnown().where((e) => e.value == Entry.yesAuto),
        isEmpty,
        reason: 'models.frequency#8',
      );
      expect(
        computedWeekly.getKnown().where((e) => e.value == Entry.yesAuto),
        isNotEmpty,
        reason: 'models.frequency#8',
      );

      // (2) The score decay multiplier is Score.compute(frequency.toDouble(),
      // ...). Two numerical habits with the same denominator (so the same
      // rolling window) but different numerators score differently, and each
      // one matches Score.compute fed with its own toDouble().
      double firstScoreOf(Frequency frequency) {
        final scores = ScoreList();
        final from = today.minus(10);
        scores.recompute(
          frequency: frequency,
          isNumerical: true,
          numericalHabitType: NumericalHabitType.atLeast,
          targetValue: 1.0,
          computedEntries: (LocalDate f, LocalDate t) {
            final result = <Entry>[];
            var current = t;
            while (!current.isOlderThan(f)) {
              result.add(Entry(current, current == from ? 1000 : Entry.unknown));
              current = current.minus(1);
            }
            return result;
          },
          from: from,
          to: today,
        );
        return scores[from].value;
      }

      expect(firstScoreOf(Frequency(1, 7)),
          Score.compute(Frequency(1, 7).toDouble(), 0.0, 1.0),
          reason: 'models.frequency#8');
      expect(firstScoreOf(Frequency(3, 7)),
          Score.compute(Frequency(3, 7).toDouble(), 0.0, 1.0),
          reason: 'models.frequency#8');
      expect(firstScoreOf(Frequency(1, 7)), isNot(firstScoreOf(Frequency(3, 7))),
          reason: 'models.frequency#8');

      // (3) The rolling-sum window is the denominator, doubled (together with
      // the numerator) for non-daily BOOLEAN habits. One checkmark 13 days ago
      // is still inside the doubled 14-day window; a literal 7-day window would
      // already have subtracted it.
      final from = today.minus(20);
      final entriesFn = checkmarksAt(today, <int>{13});
      final values = entriesFn(from, today).map((e) => e.value).toList();
      final scores = ScoreList();
      scores.recompute(
        frequency: Frequency(1, 7),
        isNumerical: false,
        numericalHabitType: NumericalHabitType.atLeast,
        targetValue: 0.0,
        computedEntries: entriesFn,
        from: from,
        to: today,
      );
      final doubled =
          booleanScoreOfLastDay(values, 2, 14, Frequency(1, 7).toDouble());
      final literal =
          booleanScoreOfLastDay(values, 1, 7, Frequency(1, 7).toDouble());
      expect(scores[today].value, closeTo(doubled, 1e-12),
          reason: 'models.frequency#8');
      expect(doubled, isNot(closeTo(literal, 1e-12)),
          reason: 'models.frequency#8');

      // A DAILY boolean habit has freq == 1.0, so nothing is doubled.
      final dailyScores = ScoreList();
      final dailyEntries = checkmarksAt(today, <int>{13});
      dailyScores.recompute(
        frequency: Frequency.daily,
        isNumerical: false,
        numericalHabitType: NumericalHabitType.atLeast,
        targetValue: 0.0,
        computedEntries: dailyEntries,
        from: from,
        to: today,
      );
      expect(
        dailyScores[today].value,
        closeTo(booleanScoreOfLastDay(values, 1, 1, 1.0), 1e-12),
        reason: 'models.frequency#8',
      );
    });

    test('#13 Habit.frequency defaults to Frequency.DAILY', () {
      final habit = MemoryModelFactory().buildHabit();
      expect(habit.frequency, Frequency.daily, reason: 'models.frequency#13');
      expect(habit.frequency.numerator, 1, reason: 'models.frequency#13');
      expect(habit.frequency.denominator, 1, reason: 'models.frequency#13');
      // The default is the shared constant itself, which is only safe because
      // Frequency is immutable here (see #5).
      expect(identical(habit.frequency, Frequency.daily), isTrue,
          reason: 'models.frequency#13');

      final second = MemoryModelFactory().buildHabit();
      expect(second.frequency, Frequency.daily, reason: 'models.frequency#13');
    });
  });
}
