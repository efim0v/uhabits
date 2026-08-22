import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/StreakListTest.kt
///
/// The Kotlin test drives StreakList through Habit.recompute() and the
/// `createLongHabit` fixture. Neither Habit nor EntryList is ported yet, so the
/// computed entries are produced here by [FakeComputedEntries], which
/// reproduces EntryList.getByInterval() exactly: one entry per day in
/// [from, to], ordered newest-first, with UNKNOWN for days that hold nothing.
class FakeComputedEntries {
  FakeComputedEntries();

  final Map<int, Entry> _byDate = {};

  /// Records every (from, to) pair getByInterval was called with.
  final List<List<LocalDate>> calls = [];

  void add(Entry entry) => _byDate[entry.date.daysSince2000] = entry;

  void clear() => _byDate.clear();

  /// Line-for-line the same walk as EntryList.getByInterval in Kotlin.
  List<Entry> getByInterval(LocalDate from, LocalDate to) {
    calls.add([from, to]);
    final result = <Entry>[];
    if (from.isNewerThan(to)) return result;
    var current = to;
    while (current >= from) {
      result.add(
        _byDate[current.daysSince2000] ?? Entry(current, Entry.unknown),
      );
      current = current.minus(1);
    }
    return result;
  }
}

/// The offsets of `HabitFixtures.createLongHabit()`, in days before today.
const List<int> longHabitMarks = [
  0, 1, 3, 5, 7, 8, 9, 10, 12, 14, 15, 17, 19, 20, 26, 27, //
  28, 50, 51, 52, 53, 54, 58, 60, 63, 65, 70, 71, 72, 73, 74, 75, 80,
  81, 83, 89, 90, 91, 95, 102, 103, 108, 109, 120,
];

void main() {
  late LocalDate today;
  late FakeComputedEntries entries;
  late StreakList streaks;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
    entries = FakeComputedEntries();
    streaks = StreakList();
  });

  tearDown(resetToday);

  /// Mirrors what Habit.recompute() passes to StreakList.recompute(): the
  /// computed entries, the oldest known day and today + 30.
  void recomputeBoolean({LocalDate? from, LocalDate? to}) {
    streaks.recompute(
      entries.getByInterval,
      from ?? today.minus(200),
      to ?? today.plus(30),
      false,
      0.0,
      NumericalHabitType.atLeast,
    );
  }

  void markLongHabit() {
    for (final mark in longHabitMarks) {
      entries.add(Entry(today.minus(mark), Entry.yesManual));
    }
  }

  group('models.streak-computation', () {
    test('#1 Streak is an immutable pair of dates with a length', () {
      final start = today.minus(5);
      final end = today;
      final streak = Streak(start, end);

      expect(streak.start, start, reason: 'models.streak-computation#1');
      expect(streak.end, end, reason: 'models.streak-computation#1');
      expect(streak.start <= streak.end, isTrue,
          reason: 'models.streak-computation#1');
      expect(streak.length, start.daysUntil(end) + 1,
          reason: 'models.streak-computation#1');
      expect(streak.length, 6, reason: 'models.streak-computation#1');

      // A single day is a streak of length one.
      expect(Streak(today, today).length, 1,
          reason: 'models.streak-computation#1');

      // Value semantics: same endpoints means the same streak.
      expect(Streak(start, end), Streak(today.minus(5), today),
          reason: 'models.streak-computation#1');
      expect(Streak(start, end).hashCode, Streak(today.minus(5), today).hashCode,
          reason: 'models.streak-computation#1');
    });

    test('#2 recompute clears the list and rebuilds it from '
        'getByInterval(from, to)', () {
      entries.add(Entry(today, Entry.yesManual));
      entries.add(Entry(today.minus(1), Entry.yesManual));
      entries.add(Entry(today.minus(10), Entry.yesManual));
      final from = today.minus(30);
      final to = today.plus(30);
      recomputeBoolean(from: from, to: to);

      expect(entries.calls.single[0], from,
          reason: 'models.streak-computation#2');
      expect(entries.calls.single[1], to, reason: 'models.streak-computation#2');
      expect(streaks.getBest(10).length, 2,
          reason: 'models.streak-computation#2');

      // Recomputing over fewer entries must not leave the old streaks behind.
      entries.clear();
      entries.add(Entry(today.minus(3), Entry.yesManual));
      recomputeBoolean(from: from, to: to);

      final best = streaks.getBest(10);
      expect(best.length, 1, reason: 'models.streak-computation#2');
      expect(best[0], Streak(today.minus(3), today.minus(3)),
          reason: 'models.streak-computation#2');

      // Only the requested interval is consulted: a check older than `from`
      // is invisible to the recomputation.
      entries.add(Entry(today.minus(100), Entry.yesManual));
      recomputeBoolean(from: from, to: to);
      expect(streaks.getBest(10).length, 1,
          reason: 'models.streak-computation#2');
    });

    test('#3 for a boolean habit any value greater than zero qualifies', () {
      entries.add(Entry(today, Entry.yesManual));
      entries.add(Entry(today.minus(1), Entry.yesAuto));
      entries.add(Entry(today.minus(2), Entry.skip));
      entries.add(Entry(today.minus(3), Entry.no));
      entries.add(Entry(today.minus(4), Entry.unknown));
      recomputeBoolean();

      final best = streaks.getBest(10);
      expect(best.length, 1, reason: 'models.streak-computation#3');
      expect(best[0], Streak(today.minus(2), today),
          reason: 'models.streak-computation#3');
      expect(best[0].length, 3, reason: 'models.streak-computation#3');
    });

    test('#3 for a numerical AT_LEAST habit the value must reach the target',
        () {
      entries.add(Entry(today, 3000)); // 3.0 >= 2.0
      entries.add(Entry(today.minus(1), 2000)); // 2.0 >= 2.0
      entries.add(Entry(today.minus(2), 1999)); // 1.999 < 2.0
      entries.add(Entry(today.minus(3), 5000));
      streaks.recompute(
        entries.getByInterval,
        today.minus(30),
        today.plus(30),
        true,
        2.0,
        NumericalHabitType.atLeast,
      );

      final best = streaks.getBest(10);
      expect(best.length, 2, reason: 'models.streak-computation#3');
      expect(best[0], Streak(today.minus(1), today),
          reason: 'models.streak-computation#3');
      expect(best[1], Streak(today.minus(3), today.minus(3)),
          reason: 'models.streak-computation#3');
    });

    test('#3 for a numerical AT_MOST habit UNKNOWN never qualifies', () {
      entries.add(Entry(today, 1000)); // 1.0 <= 2.0
      entries.add(Entry(today.minus(1), 2000)); // 2.0 <= 2.0
      entries.add(Entry(today.minus(2), 2001)); // 2.001 > 2.0
      entries.add(Entry(today.minus(3), Entry.no)); // 0.0 <= 2.0
      // today - 4 holds nothing, so getByInterval yields UNKNOWN (-1). Its
      // value divided by 1000 is below the target, but UNKNOWN is excluded
      // explicitly, so the streak must not reach across it.
      entries.add(Entry(today.minus(5), Entry.no));
      streaks.recompute(
        entries.getByInterval,
        today.minus(30),
        today.plus(30),
        true,
        2.0,
        NumericalHabitType.atMost,
      );

      final best = streaks.getBest(10);
      expect(best.length, 3, reason: 'models.streak-computation#3');
      expect(best[0], Streak(today.minus(1), today),
          reason: 'models.streak-computation#3');
      expect(best[1], Streak(today.minus(3), today.minus(3)),
          reason: 'models.streak-computation#3');
      expect(best[2], Streak(today.minus(5), today.minus(5)),
          reason: 'models.streak-computation#3');
    });

    test('#4 when no day qualifies the list stays empty', () {
      entries.add(Entry(today, Entry.no));
      entries.add(Entry(today.minus(1), Entry.unknown));
      recomputeBoolean();

      expect(streaks.getBest(10), isEmpty, reason: 'models.streak-computation#4');
      expect(streaks.getBest(1), isEmpty, reason: 'models.streak-computation#4');
    });

    test('#5 #6 consecutive days extend a streak, gaps close it, and the '
        'final streak is appended', () {
      // Offsets 0,1,2 | 4 | 7,8 — three streaks, the oldest one closed only by
      // the append that follows the loop.
      for (final offset in [0, 1, 2, 4, 7, 8]) {
        entries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      recomputeBoolean();

      final all = streaks.getBest(100);
      expect(all.length, 3, reason: 'models.streak-computation#5');
      // getBest(all) orders by end date descending, which is exactly the order
      // in which recompute() appended them: newest streak first.
      expect(all[0], Streak(today.minus(2), today),
          reason: 'models.streak-computation#5');
      expect(all[1], Streak(today.minus(4), today.minus(4)),
          reason: 'models.streak-computation#5');
      expect(all[2], Streak(today.minus(8), today.minus(7)),
          reason: 'models.streak-computation#5');
      expect(all[2].length, 2, reason: 'models.streak-computation#5');

      expect([all[0].end, all[1].end, all[2].end],
          [today, today.minus(4), today.minus(7)],
          reason: 'models.streak-computation#6');
    });

    test('#7 only a check today and a NO five days ago gives one streak of '
        'length one', () {
      // Ported from StreakListTest.testGetBest_withUnknowns.
      entries.add(Entry(today, Entry.yesManual));
      entries.add(Entry(today.minus(5), Entry.no));
      recomputeBoolean(from: today.minus(5), to: today.plus(30));

      final best = streaks.getBest(5);
      expect(best.length, 1, reason: 'models.streak-computation#7');
      expect(best[0].length, 1, reason: 'models.streak-computation#7');
      expect(best[0], Streak(today, today),
          reason: 'models.streak-computation#7');
    });
  });

  group('models.streak-best', () {
    test('#1 compareLonger compares lengths and falls back to compareNewer',
        () {
      final long = Streak(today.minus(5), today); // length 6
      final short = Streak(today.minus(1), today); // length 2

      expect(long.compareLonger(short), 4, reason: 'models.streak-best#1');
      expect(short.compareLonger(long), -4, reason: 'models.streak-best#1');

      // Same length: the comparison falls through to compareNewer.
      final newer = Streak(today.minus(1), today); // length 2, ends today
      final older = Streak(today.minus(11), today.minus(10)); // length 2
      expect(newer.compareLonger(older), newer.compareNewer(older),
          reason: 'models.streak-best#1');
      expect(newer.compareLonger(older), 10, reason: 'models.streak-best#1');
      expect(newer.compareLonger(newer), 0, reason: 'models.streak-best#1');
    });

    test('#2 compareNewer subtracts the end dates', () {
      final a = Streak(today.minus(30), today);
      final b = Streak(today.minus(11), today.minus(10));

      expect(a.compareNewer(b), 10, reason: 'models.streak-best#2');
      expect(b.compareNewer(a), -10, reason: 'models.streak-best#2');
      expect(a.compareNewer(a), 0, reason: 'models.streak-best#2');
      expect(a.compareNewer(b), a.end.daysSince2000 - b.end.daysSince2000,
          reason: 'models.streak-best#2');
    });

    test('#3 #4 getBest keeps the longest streaks but returns them newest '
        'first', () {
      // Lengths, newest first: 1 (offset 0), 3 (offsets 2-4), 2 (7-8),
      // 4 (11-14), 3 (20-22).
      for (final offset in [0, 2, 3, 4, 7, 8, 11, 12, 13, 14, 20, 21, 22]) {
        entries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      recomputeBoolean();

      final best = streaks.getBest(3);
      expect(best.length, 3, reason: 'models.streak-best#3');
      // The three longest are 4, 3 (ending today-2) and 3 (ending today-20);
      // the length-3 tie is broken in favour of the newer end date, so the
      // length-2 streak is dropped.
      expect(best.map((s) => s.length).toList(), [3, 4, 3],
          reason: 'models.streak-best#3');
      expect(best.map((s) => s.end).toList(),
          [today.minus(2), today.minus(11), today.minus(20)],
          reason: 'models.streak-best#4');

      // The result is immutable.
      expect(() => best.add(Streak(today, today)), throwsUnsupportedError,
          reason: 'models.streak-best#3');
    });

    test('#5 repeated calls keep returning the correct answer', () {
      markLongHabit();
      recomputeBoolean();

      final first = streaks.getBest(4).map((s) => s.length).toList();
      // getBest reorders the internal list as a side effect; the next calls
      // must not be affected by it.
      final smaller = streaks.getBest(2).map((s) => s.length).toList();
      final again = streaks.getBest(4).map((s) => s.length).toList();
      final all = streaks.getBest(1000);

      expect(first, [4, 3, 5, 6], reason: 'models.streak-best#5');
      expect(smaller, [5, 6], reason: 'models.streak-best#5');
      expect(again, first, reason: 'models.streak-best#5');
      expect(all.length, 22, reason: 'models.streak-best#5');
      expect(streaks.getBest(4).map((s) => s.length).toList(), first,
          reason: 'models.streak-best#5');
    });

    test('#6 a limit above the number of streaks returns them all, and an '
        'empty list stays empty', () {
      expect(streaks.getBest(5), isEmpty, reason: 'models.streak-best#6');
      expect(streaks.getBest(0), isEmpty, reason: 'models.streak-best#6');

      for (final offset in [0, 4, 5]) {
        entries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      recomputeBoolean();

      final best = streaks.getBest(50);
      expect(best.length, 2, reason: 'models.streak-best#6');
      expect(best[0], Streak(today, today), reason: 'models.streak-best#6');
      expect(best[1], Streak(today.minus(5), today.minus(4)),
          reason: 'models.streak-best#6');
      expect(streaks.getBest(0), isEmpty, reason: 'models.streak-best#6');
    });

    test('#7 the long habit fixture yields the documented best streaks', () {
      // Ported from StreakListTest.testGetBest.
      markLongHabit();
      recomputeBoolean(from: today.minus(120), to: today.plus(30));

      var best = streaks.getBest(4);
      expect(best.length, 4, reason: 'models.streak-best#7');
      expect(best[0].length, 4, reason: 'models.streak-best#7');
      expect(best[1].length, 3, reason: 'models.streak-best#7');
      expect(best[2].length, 5, reason: 'models.streak-best#7');
      expect(best[3].length, 6, reason: 'models.streak-best#7');
      expect(best.map((s) => s.end).toList(), [
        today.minus(7),
        today.minus(26),
        today.minus(50),
        today.minus(70),
      ], reason: 'models.streak-best#7');

      best = streaks.getBest(2);
      expect(best.length, 2, reason: 'models.streak-best#7');
      expect(best[0].length, 5, reason: 'models.streak-best#7');
      expect(best[1].length, 6, reason: 'models.streak-best#7');
    });
  });
}
