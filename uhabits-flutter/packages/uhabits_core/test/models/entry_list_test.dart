import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryListTest.kt
///
/// The Kotlin test's `day(offset)` helper counts BACKWARDS from a fixed
/// reference, so `day(0)` is the newest date and `day(23)` is the oldest. Keep
/// that in mind when reading interval literals: `Interval(day(8), day(8),
/// day(2))` has its `begin` in the past and its `end` in the future.
LocalDate day(int offset) => LocalDate.ymd(2015, 1, 25).minus(offset);

void main() {
  group('models.entry-list-storage', () {
    test('#1 #2 #3 at most one entry per date; get() never returns null', () {
      final entries = EntryList();
      final today = LocalDate.ymd(2015, 1, 25);

      // Nothing stored yet: get() synthesises an UNKNOWN entry.
      expect(entries.get(today.minus(0)), Entry(today.minus(0), Entry.unknown),
          reason: 'models.entry-list-storage#2');
      expect(entries.get(today.minus(2)), Entry(today.minus(2), Entry.unknown),
          reason: 'models.entry-list-storage#2');
      expect(entries.get(today.minus(5)), Entry(today.minus(5), Entry.unknown),
          reason: 'models.entry-list-storage#2');
      expect(entries.get(today.minus(5)), isNotNull,
          reason: 'models.entry-list-storage#2');

      entries.add(Entry(today.minus(0), 10));
      entries.add(Entry(today.minus(0), 15)); // replaces the previous one
      entries.add(Entry(today.minus(5), 20));
      entries.add(Entry(today.minus(8), 30));

      expect(entries.get(today.minus(0)), Entry(today.minus(0), 15),
          reason: 'models.entry-list-storage#3');
      expect(entries.get(today.minus(5)), Entry(today.minus(5), 20),
          reason: 'models.entry-list-storage#1');
      expect(entries.get(today.minus(8)), Entry(today.minus(8), 30),
          reason: 'models.entry-list-storage#1');

      // Only three dates were touched, so only three entries exist.
      expect(entries.getKnown().length, 3,
          reason: 'models.entry-list-storage#1');

      // Replacing also replaces the notes.
      entries.add(Entry(today.minus(5), 20, notes: 'first'));
      expect(entries.get(today.minus(5)).notes, 'first',
          reason: 'models.entry-list-storage#3');
      entries.add(Entry(today.minus(5), 21));
      expect(entries.get(today.minus(5)), Entry(today.minus(5), 21),
          reason: 'models.entry-list-storage#3');
      expect(entries.get(today.minus(5)).notes, '',
          reason: 'models.entry-list-storage#3');
      expect(entries.getKnown().length, 3,
          reason: 'models.entry-list-storage#1');
    });

    test('#4 getKnown() is sorted newest-first and keeps stored UNKNOWNs', () {
      final entries = EntryList();
      final today = LocalDate.ymd(2015, 1, 25);

      // Inserted out of order on purpose.
      entries.add(Entry(today.minus(8), 30));
      entries.add(Entry(today.minus(0), 15));
      entries.add(Entry(today.minus(5), 20));

      final known = entries.getKnown();
      expect(known.length, 3, reason: 'models.entry-list-storage#4');
      expect(known[0], Entry(today.minus(0), 15),
          reason: 'models.entry-list-storage#4');
      expect(known[1], Entry(today.minus(5), 20),
          reason: 'models.entry-list-storage#4');
      expect(known[2], Entry(today.minus(8), 30),
          reason: 'models.entry-list-storage#4');

      // An explicitly stored UNKNOWN is still "known".
      entries.add(Entry(today.minus(3), Entry.unknown, notes: 'kept'));
      final known2 = entries.getKnown();
      expect(known2.length, 4, reason: 'models.entry-list-storage#4');
      expect(known2[1], Entry(today.minus(3), Entry.unknown, notes: 'kept'),
          reason: 'models.entry-list-storage#4');
    });

    test('#5 getByInterval() yields one entry per day, newest-first', () {
      final entries = EntryList();
      final today = LocalDate.ymd(2015, 1, 25);
      entries.add(Entry(today.minus(0), 15));
      entries.add(Entry(today.minus(5), 20));
      entries.add(Entry(today.minus(8), 30));

      final actual = entries.getByInterval(today.minus(5), today);
      expect(actual.length, 6, reason: 'models.entry-list-storage#5');
      expect(actual[0], Entry(today.minus(0), 15),
          reason: 'models.entry-list-storage#5');
      expect(actual[1], Entry(today.minus(1), Entry.unknown),
          reason: 'models.entry-list-storage#5');
      expect(actual[2], Entry(today.minus(2), Entry.unknown),
          reason: 'models.entry-list-storage#5');
      expect(actual[3], Entry(today.minus(3), Entry.unknown),
          reason: 'models.entry-list-storage#5');
      expect(actual[4], Entry(today.minus(4), Entry.unknown),
          reason: 'models.entry-list-storage#5');
      expect(actual[5], Entry(today.minus(5), 20),
          reason: 'models.entry-list-storage#5');

      // Single day interval.
      expect(entries.getByInterval(today, today).length, 1,
          reason: 'models.entry-list-storage#5');

      // from newer than to => empty.
      expect(entries.getByInterval(today, today.minus(5)), isEmpty,
          reason: 'models.entry-list-storage#5');
    });

    test('#6 clear() removes every stored entry', () {
      final entries = EntryList();
      final today = LocalDate.ymd(2015, 1, 25);
      entries.add(Entry(today, 15));
      entries.add(Entry(today.minus(5), 20));

      entries.clear();

      expect(entries.getKnown(), isEmpty,
          reason: 'models.entry-list-storage#6');
      expect(entries.get(today), Entry(today, Entry.unknown),
          reason: 'models.entry-list-storage#6');
    });

    test('#7 readers hand out snapshots, so iteration survives mutation', () {
      final entries = EntryList();
      final today = LocalDate.ymd(2015, 1, 25);
      entries.add(Entry(today, 15));
      entries.add(Entry(today.minus(1), 20));

      // Kotlin marks every accessor @Synchronized; in Dart the guarantee we
      // need is simply that a returned list is not a live view of the map, so
      // mutating while iterating cannot throw.
      final known = entries.getKnown();
      var seen = 0;
      for (final e in known) {
        entries.add(Entry(e.date.minus(10), 99));
        seen++;
      }
      expect(seen, 2, reason: 'models.entry-list-storage#7');
      expect(known.length, 2, reason: 'models.entry-list-storage#7');
      expect(entries.getKnown().length, 4,
          reason: 'models.entry-list-storage#7');

      final interval = entries.getByInterval(today.minus(1), today);
      var seen2 = 0;
      for (final _ in interval) {
        entries.add(Entry(today.minus(50 + seen2), 1));
        seen2++;
      }
      expect(seen2, 2, reason: 'models.entry-list-storage#7');
    });
  });

  group('models.entry-list-build-intervals', () {
    test('#1 only YES_MANUAL entries take part', () {
      final entries = [
        Entry(day(1), Entry.yesAuto),
        Entry(day(2), Entry.no),
        Entry(day(3), Entry.skip),
        Entry(day(4), Entry.unknown),
        Entry(day(5), 500),
      ];
      expect(EntryList.buildIntervals(Frequency.daily, entries), isEmpty,
          reason: 'models.entry-list-build-intervals#1');

      final mixed = [
        Entry(day(1), Entry.yesAuto),
        Entry(day(2), Entry.yesManual),
        Entry(day(3), Entry.no),
      ];
      expect(
        EntryList.buildIntervals(Frequency.daily, mixed),
        [Interval(day(2), day(2), day(2))],
        reason: 'models.entry-list-build-intervals#1',
      );
    });

    test('#2 #5 begin is the older endpoint, center the num-th checkmark back',
        () {
      // Newest-first: index 0 == day(6) == the newest.
      final entries = [
        Entry(day(6), Entry.yesManual),
        Entry(day(9), Entry.yesManual),
        Entry(day(11), Entry.yesManual),
      ];
      final actual =
          EntryList.buildIntervals(Frequency.twoTimesPerWeek, entries);

      // num == 2, so i starts at 1.
      // i == 1: begin = filtered[1] = day(9), center = filtered[0] = day(6).
      // i == 2: begin = filtered[2] = day(11), center = filtered[1] = day(9).
      expect(actual.length, 2,
          reason: 'models.entry-list-build-intervals#2');
      expect(actual[0], Interval(day(9), day(6), day(3)),
          reason: 'models.entry-list-build-intervals#2');
      expect(actual[0].begin, day(9),
          reason: 'models.entry-list-build-intervals#2');
      expect(actual[0].center, day(6),
          reason: 'models.entry-list-build-intervals#2');
      expect(actual[1], Interval(day(11), day(9), day(5)),
          reason: 'models.entry-list-build-intervals#2');
      expect(actual[1].begin, day(11),
          reason: 'models.entry-list-build-intervals#2');
      expect(actual[1].center, day(9),
          reason: 'models.entry-list-build-intervals#2');

      // The output order mirrors `filtered`, i.e. newest interval first.
      expect(actual[0].begin.isNewerThan(actual[1].begin), isTrue,
          reason: 'models.entry-list-build-intervals#5');
    });

    test('#3 monthly denominators use real calendar month lengths', () {
      // Newest-first.
      final entries = [
        Entry(LocalDate.ymd(2015, 1, 31), Entry.yesManual),
        Entry(LocalDate.ymd(2015, 1, 15), Entry.yesManual),
      ];

      final byThirty = EntryList.buildIntervals(Frequency(1, 30), entries);
      // begin == Jan 31 is the last day of its month, so size is FEBRUARY's
      // length (28), not January's.
      expect(byThirty[0].begin, LocalDate.ymd(2015, 1, 31),
          reason: 'models.entry-list-build-intervals#3');
      expect(byThirty[0].end, LocalDate.ymd(2015, 2, 27),
          reason: 'models.entry-list-build-intervals#3');
      // begin == Jan 15 is not the last day, so size is January's length (31).
      expect(byThirty[1].begin, LocalDate.ymd(2015, 1, 15),
          reason: 'models.entry-list-build-intervals#3');
      expect(byThirty[1].end, LocalDate.ymd(2015, 2, 14),
          reason: 'models.entry-list-build-intervals#3');

      // den == 31 takes the same branch as den == 30.
      final byThirtyOne = EntryList.buildIntervals(Frequency(1, 31), entries);
      expect(byThirtyOne[0].end, LocalDate.ymd(2015, 2, 27),
          reason: 'models.entry-list-build-intervals#3');
      expect(byThirtyOne[1].end, LocalDate.ymd(2015, 2, 14),
          reason: 'models.entry-list-build-intervals#3');

      // A short month: February 2015 has 28 days.
      final feb = [Entry(LocalDate.ymd(2015, 2, 10), Entry.yesManual)];
      expect(
        EntryList.buildIntervals(Frequency(1, 30), feb).single.end,
        LocalDate.ymd(2015, 3, 9),
        reason: 'models.entry-list-build-intervals#3',
      );

      // Any other denominator is used verbatim: size == den.
      final weekly = EntryList.buildIntervals(
        Frequency.weekly,
        [Entry(LocalDate.ymd(2015, 1, 31), Entry.yesManual)],
      );
      expect(weekly.single.end, LocalDate.ymd(2015, 2, 6),
          reason: 'models.entry-list-build-intervals#3');
    });

    test('#4 nothing is emitted when the checkmarks are too far apart', () {
      // Two checkmarks 10 days apart, but the window is only 7 days long.
      final entries = [
        Entry(day(0), Entry.yesManual),
        Entry(day(10), Entry.yesManual),
      ];
      expect(
        EntryList.buildIntervals(Frequency.twoTimesPerWeek, entries),
        isEmpty,
        reason: 'models.entry-list-build-intervals#4',
      );

      // Exactly 6 days apart: 6 < 7, so it is emitted as
      // Interval(begin, center, begin.plus(size - 1)).
      final close = [
        Entry(day(0), Entry.yesManual),
        Entry(day(6), Entry.yesManual),
      ];
      expect(
        EntryList.buildIntervals(Frequency.twoTimesPerWeek, close),
        [Interval(day(6), day(0), day(0))],
        reason: 'models.entry-list-build-intervals#4',
      );

      // Exactly 7 days apart: 7 is not < 7, so nothing is emitted.
      final onTheEdge = [
        Entry(day(0), Entry.yesManual),
        Entry(day(7), Entry.yesManual),
      ];
      expect(
        EntryList.buildIntervals(Frequency.twoTimesPerWeek, onTheEdge),
        isEmpty,
        reason: 'models.entry-list-build-intervals#4',
      );
    });

    test('#6 Interval.length is begin.daysUntil(end) + 1', () {
      expect(Interval(day(8), day(8), day(2)).length, 7,
          reason: 'models.entry-list-build-intervals#6');
      expect(Interval(day(8), day(8), day(8)).length, 1,
          reason: 'models.entry-list-build-intervals#6');
      expect(
        EntryList.buildIntervals(
          Frequency.weekly,
          [Entry(day(8), Entry.yesManual)],
        ).single.length,
        7,
        reason: 'models.entry-list-build-intervals#6',
      );
    });

    test('#7 WEEKLY over checkmarks at offsets 8, 18, 23', () {
      final entries = [
        Entry(day(8), Entry.yesManual),
        Entry(day(18), Entry.yesManual),
        Entry(day(23), Entry.yesManual),
      ];
      final expected = [
        Interval(day(8), day(8), day(2)),
        Interval(day(18), day(18), day(12)),
        Interval(day(23), day(23), day(17)),
      ];
      expect(EntryList.buildIntervals(Frequency.weekly, entries), expected,
          reason: 'models.entry-list-build-intervals#7');
    });

    test('#8 DAILY over the same checkmarks yields single-day intervals', () {
      final entries = [
        Entry(day(8), Entry.yesManual),
        Entry(day(18), Entry.yesManual),
        Entry(day(23), Entry.yesManual),
      ];
      final expected = [
        Interval(day(8), day(8), day(8)),
        Interval(day(18), day(18), day(18)),
        Interval(day(23), day(23), day(23)),
      ];
      expect(EntryList.buildIntervals(Frequency.daily, entries), expected,
          reason: 'models.entry-list-build-intervals#8');
    });

    test('#9 TWO_TIMES_PER_WEEK skips i = 0 because num - 1 == 1', () {
      final entries = [
        Entry(day(8), Entry.yesManual),
        Entry(day(15), Entry.yesManual),
        Entry(day(18), Entry.yesManual),
        Entry(day(22), Entry.yesManual),
        Entry(day(23), Entry.yesManual),
      ];
      final expected = [
        Interval(day(18), day(15), day(12)),
        Interval(day(22), day(18), day(16)),
        Interval(day(23), day(22), day(17)),
      ];
      expect(
        EntryList.buildIntervals(Frequency.twoTimesPerWeek, entries),
        expected,
        reason: 'models.entry-list-build-intervals#9',
      );
    });

    test('#10 a SKIP between two checkmarks is ignored entirely', () {
      final entries = [
        Entry(day(10), Entry.yesManual),
        Entry(day(20), Entry.skip),
        Entry(day(30), Entry.yesManual),
      ];
      final expected = [
        Interval(day(10), day(10), day(8)),
        Interval(day(30), day(30), day(28)),
      ];
      expect(EntryList.buildIntervals(Frequency(1, 3), entries), expected,
          reason: 'models.entry-list-build-intervals#10');
    });
  });

  group('models.entry-list-snap-intervals', () {
    test('#1 the list is mutated in place', () {
      final original = [
        Interval(day(2), day(2), day(0)),
        Interval(day(4), day(4), day(2)),
      ];
      final same = original;

      EntryList.snapIntervalsTogether(original);

      expect(identical(same, original), isTrue,
          reason: 'models.entry-list-snap-intervals#1');
      expect(original[1], Interval(day(5), day(4), day(3)),
          reason: 'models.entry-list-snap-intervals#1');
    });

    test('#2 #3 touching intervals slide backwards by min(centerGap, gap + 1)',
        () {
      // next.begin == day(2), curr.end == day(2) => gapNextToCurrent == 0.
      // curr.center == day(4), curr.end == day(2) => gapCenterToEnd == 2.
      // shift == min(2, 0 + 1) == 1.
      final intervals = [
        Interval(day(2), day(2), day(0)),
        Interval(day(4), day(4), day(2)),
      ];
      EntryList.snapIntervalsTogether(intervals);
      expect(intervals[0], Interval(day(2), day(2), day(0)),
          reason: 'models.entry-list-snap-intervals#2');
      expect(intervals[1], Interval(day(5), day(4), day(3)),
          reason: 'models.entry-list-snap-intervals#3');

      // Now let gapCenterToEnd be the smaller of the two: the center pins the
      // slide, so the interval never slides past its own checkmark.
      // next = (day(10), day(10), day(4)), curr = (day(14), day(9), day(8)).
      // gapNextToCurrent = day(10).daysUntil(day(8)) == 2
      // gapCenterToEnd   = day(9).daysUntil(day(8))  == 1
      // shift = min(1, 3) == 1
      final overlapping = [
        Interval(day(10), day(10), day(4)),
        Interval(day(14), day(9), day(8)),
      ];
      EntryList.snapIntervalsTogether(overlapping);
      expect(overlapping[1], Interval(day(15), day(9), day(9)),
          reason: 'models.entry-list-snap-intervals#3');
      expect(overlapping[1].center, day(9),
          reason: 'models.entry-list-snap-intervals#3');
    });

    test('#4 a negative gap leaves the interval untouched', () {
      // next.begin == day(2), curr.end == day(3) =>
      // gapNextToCurrent == day(2).daysUntil(day(3)) == -1 < 0.
      final intervals = [
        Interval(day(2), day(2), day(0)),
        Interval(day(5), day(5), day(3)),
      ];
      EntryList.snapIntervalsTogether(intervals);
      expect(intervals[0], Interval(day(2), day(2), day(0)),
          reason: 'models.entry-list-snap-intervals#4');
      expect(intervals[1], Interval(day(5), day(5), day(3)),
          reason: 'models.entry-list-snap-intervals#4');
    });

    test('#5 shifts accumulate because each step reads the shifted neighbour',
        () {
      // If intervals[i - 1] were read from the ORIGINAL list, the third
      // interval below would not move at all.
      final intervals = [
        Interval(day(8), day(8), day(2)),
        Interval(day(12), day(12), day(6)),
        Interval(day(20), day(20), day(14)),
      ];
      EntryList.snapIntervalsTogether(intervals);
      expect(intervals[1], Interval(day(15), day(12), day(9)),
          reason: 'models.entry-list-snap-intervals#5');
      // The third step reads the ALREADY-SHIFTED intervals[1] (begin day(15)),
      // so gapNextToCurrent == day(15).daysUntil(day(14)) == 1 and the shift
      // is min(6, 2) == 2. Against the unshifted day(12) it would have been
      // min(6, -1 + 1) == 0, leaving the interval where it was.
      expect(intervals[2], Interval(day(22), day(20), day(16)),
          reason: 'models.entry-list-snap-intervals#5');
    });

    test('#6 four weekly intervals snap into a contiguous streak', () {
      final original = [
        Interval(day(8), day(8), day(2)),
        Interval(day(12), day(12), day(6)),
        Interval(day(20), day(20), day(14)),
        Interval(day(27), day(27), day(21)),
      ];
      final expected = [
        Interval(day(8), day(8), day(2)),
        Interval(day(15), day(12), day(9)),
        Interval(day(22), day(20), day(16)),
        Interval(day(29), day(27), day(23)),
      ];
      EntryList.snapIntervalsTogether(original);
      expect(original, expected,
          reason: 'models.entry-list-snap-intervals#6');
    });

    test('#7 two intervals with off-center checkmarks', () {
      final original = [
        Interval(day(6), day(4), day(0)),
        Interval(day(11), day(8), day(5)),
      ];
      final expected = [
        Interval(day(6), day(4), day(0)),
        Interval(day(13), day(8), day(7)),
      ];
      EntryList.snapIntervalsTogether(original);
      expect(original, expected,
          reason: 'models.entry-list-snap-intervals#7');
    });
  });

  group('models.entry-list-build-entries-from-interval', () {
    test('#1 an empty original yields an empty result', () {
      expect(
        EntryList.buildEntriesFromInterval(
          [],
          [Interval(day(5), day(5), day(1))],
        ),
        isEmpty,
        reason: 'models.entry-list-build-entries-from-interval#1',
      );
      expect(EntryList.buildEntriesFromInterval([], []), isEmpty,
          reason: 'models.entry-list-build-entries-from-interval#1');
    });

    test('#2 the range spans both the entries and the interval endpoints', () {
      // The single entry sits inside an interval that extends past it in both
      // directions, so from/to come from the interval, not the entry.
      final actual = EntryList.buildEntriesFromInterval(
        [Entry(day(5), Entry.yesManual)],
        [Interval(day(8), day(8), day(2))],
      );
      expect(actual.length, 7,
          reason: 'models.entry-list-build-entries-from-interval#2');
      expect(actual.first.date, day(2),
          reason: 'models.entry-list-build-entries-from-interval#2');
      expect(actual.last.date, day(8),
          reason: 'models.entry-list-build-entries-from-interval#2');
      expect(
        actual,
        [
          Entry(day(2), Entry.yesAuto),
          Entry(day(3), Entry.yesAuto),
          Entry(day(4), Entry.yesAuto),
          Entry(day(5), Entry.yesManual),
          Entry(day(6), Entry.yesAuto),
          Entry(day(7), Entry.yesAuto),
          Entry(day(8), Entry.yesAuto),
        ],
        reason: 'models.entry-list-build-entries-from-interval#2',
      );
    });

    test('#3 #8 one entry per day, UNKNOWN by default, newest at index 0', () {
      final actual = EntryList.buildEntriesFromInterval(
        [Entry(day(0), Entry.no), Entry(day(3), Entry.no)],
        [],
      );
      expect(actual.length, 4,
          reason: 'models.entry-list-build-entries-from-interval#3');
      expect(actual[0], Entry(day(0), Entry.no),
          reason: 'models.entry-list-build-entries-from-interval#8');
      expect(actual[1], Entry(day(1), Entry.unknown),
          reason: 'models.entry-list-build-entries-from-interval#3');
      expect(actual[2], Entry(day(2), Entry.unknown),
          reason: 'models.entry-list-build-entries-from-interval#3');
      expect(actual[3], Entry(day(3), Entry.no),
          reason: 'models.entry-list-build-entries-from-interval#3');
      // Default notes are empty.
      expect(actual[1].notes, '',
          reason: 'models.entry-list-build-entries-from-interval#3');
      // Index of a date d is d.daysUntil(to), with to == day(0).
      expect(actual[day(2).daysUntil(day(0))].date, day(2),
          reason: 'models.entry-list-build-entries-from-interval#3');
      // Newest first.
      expect(actual.first.date.isNewerThan(actual.last.date), isTrue,
          reason: 'models.entry-list-build-entries-from-interval#8');
    });

    test('#4 every day inside an interval becomes YES_AUTO with no notes', () {
      final actual = EntryList.buildEntriesFromInterval(
        [Entry(day(4), Entry.yesManual), Entry(day(0), Entry.unknown)],
        [Interval(day(3), day(3), day(1))],
      );
      expect(
        actual,
        [
          Entry(day(0), Entry.unknown),
          Entry(day(1), Entry.yesAuto),
          Entry(day(2), Entry.yesAuto),
          Entry(day(3), Entry.yesAuto),
          Entry(day(4), Entry.yesManual),
        ],
        reason: 'models.entry-list-build-entries-from-interval#4',
      );
      expect(actual[2].notes, '',
          reason: 'models.entry-list-build-entries-from-interval#4');
    });

    test('#5 #6 original entries are merged over the computed slots', () {
      // Slot UNKNOWN: the original value wins, whatever it is.
      expect(
        EntryList.buildEntriesFromInterval(
          [Entry(day(2), Entry.no, notes: 'x')],
          [],
        ),
        [Entry(day(2), Entry.no, notes: 'x')],
        reason: 'models.entry-list-build-entries-from-interval#5',
      );

      // Slot YES_AUTO, original SKIP: SKIP wins.
      expect(
        EntryList.buildEntriesFromInterval(
          [Entry(day(2), Entry.skip, notes: 's')],
          [Interval(day(3), day(3), day(1))],
        )[1],
        Entry(day(2), Entry.skip, notes: 's'),
        reason: 'models.entry-list-build-entries-from-interval#5',
      );

      // Slot YES_AUTO, original YES_MANUAL: YES_MANUAL wins.
      expect(
        EntryList.buildEntriesFromInterval(
          [Entry(day(2), Entry.yesManual, notes: 'm')],
          [Interval(day(3), day(3), day(1))],
        )[1],
        Entry(day(2), Entry.yesManual, notes: 'm'),
        reason: 'models.entry-list-build-entries-from-interval#5',
      );

      // Slot YES_AUTO, original NO: YES_AUTO wins, notes survive.
      final overridden = EntryList.buildEntriesFromInterval(
        [Entry(day(2), Entry.no, notes: 'kept')],
        [Interval(day(3), day(3), day(1))],
      );
      expect(overridden[1], Entry(day(2), Entry.yesAuto, notes: 'kept'),
          reason: 'models.entry-list-build-entries-from-interval#6');

      // Slot YES_AUTO, original UNKNOWN: YES_AUTO wins, notes survive.
      expect(
        EntryList.buildEntriesFromInterval(
          [Entry(day(2), Entry.unknown, notes: 'u')],
          [Interval(day(3), day(3), day(1))],
        )[1],
        Entry(day(2), Entry.yesAuto, notes: 'u'),
        reason: 'models.entry-list-build-entries-from-interval#5',
      );

      // A NO entry outside every interval stays NO.
      final outside = EntryList.buildEntriesFromInterval(
        [Entry(day(0), Entry.no, notes: 'out'), Entry(day(2), Entry.no)],
        [Interval(day(3), day(3), day(2))],
      );
      expect(outside[0], Entry(day(0), Entry.no, notes: 'out'),
          reason: 'models.entry-list-build-entries-from-interval#6');
      expect(outside[2], Entry(day(2), Entry.yesAuto),
          reason: 'models.entry-list-build-entries-from-interval#6');
    });

    test('#7 the full worked example', () {
      final entries = [
        Entry(day(1), Entry.yesManual),
        Entry(day(2), Entry.no, notes: 'Test'),
        Entry(day(4), Entry.no),
        Entry(day(5), Entry.yesManual),
        Entry(day(10), Entry.yesManual),
        Entry(day(11), Entry.no),
      ];
      final intervals = [
        Interval(day(2), day(2), day(1)),
        Interval(day(6), day(5), day(4)),
        Interval(day(10), day(8), day(8)),
      ];
      final expected = [
        Entry(day(1), Entry.yesManual),
        Entry(day(2), Entry.yesAuto, notes: 'Test'),
        Entry(day(3), Entry.unknown),
        Entry(day(4), Entry.yesAuto),
        Entry(day(5), Entry.yesManual),
        Entry(day(6), Entry.yesAuto),
        Entry(day(7), Entry.unknown),
        Entry(day(8), Entry.yesAuto),
        Entry(day(9), Entry.yesAuto),
        Entry(day(10), Entry.yesManual),
        Entry(day(11), Entry.no),
      ];
      expect(EntryList.buildEntriesFromInterval(entries, intervals), expected,
          reason: 'models.entry-list-build-entries-from-interval#7');
    });
  });

  group('models.entry-list-recompute', () {
    test('#1 the receiver is cleared before being repopulated', () {
      final today = LocalDate.ymd(2015, 1, 25);
      final original = EntryList();
      original.add(Entry(today.minus(4), 100));

      final computed = EntryList();
      computed.add(Entry(today.minus(100), 999));
      computed.add(Entry(today.minus(101), 998));

      computed.recomputeFrom(original, Frequency.daily, isNumerical: true);

      expect(computed.getKnown(), [Entry(today.minus(4), 100)],
          reason: 'models.entry-list-recompute#1');
      expect(computed.get(today.minus(100)),
          Entry(today.minus(100), Entry.unknown),
          reason: 'models.entry-list-recompute#1');
    });

    test('#2 numerical habits copy every known entry verbatim', () {
      final today = LocalDate.ymd(2015, 1, 25);
      final original = EntryList();
      original.add(Entry(today.minus(4), 100, notes: 'a'));
      original.add(Entry(today.minus(9), 200));
      original.add(Entry(today.minus(10), Entry.skip, notes: 'b'));

      final computed = EntryList();
      computed.recomputeFrom(original, Frequency(1, 3), isNumerical: true);

      expect(
        computed.getKnown(),
        [
          Entry(today.minus(4), 100, notes: 'a'),
          Entry(today.minus(9), 200),
          Entry(today.minus(10), Entry.skip, notes: 'b'),
        ],
        reason: 'models.entry-list-recompute#2',
      );
      // No YES_AUTO was invented anywhere.
      expect(
        computed.getKnown().where((e) => e.value == Entry.yesAuto),
        isEmpty,
        reason: 'models.entry-list-recompute#2',
      );
    });

    test('#3 boolean habits store computed entries, dropping bare UNKNOWNs',
        () {
      final today = LocalDate.ymd(2015, 1, 25);
      final original = EntryList();
      original.add(Entry(today.minus(0), Entry.yesManual));
      original.add(Entry(today.minus(5), Entry.unknown, notes: 'note'));
      original.add(Entry(today.minus(10), Entry.yesManual));

      final computed = EntryList();
      computed.recomputeFrom(original, Frequency.daily, isNumerical: false);

      expect(
        computed.getKnown(),
        [
          Entry(today.minus(0), Entry.yesManual),
          Entry(today.minus(5), Entry.unknown, notes: 'note'),
          Entry(today.minus(10), Entry.yesManual),
        ],
        reason: 'models.entry-list-recompute#3',
      );
      // The UNKNOWN days without notes were dropped entirely.
      expect(computed.get(today.minus(4)),
          Entry(today.minus(4), Entry.unknown),
          reason: 'models.entry-list-recompute#3');
      expect(computed.getKnown().length, 3,
          reason: 'models.entry-list-recompute#3');
    });

    test('#4 a second call fully replaces the previous contents', () {
      final today = LocalDate.ymd(2015, 1, 25);
      final original = EntryList();
      original.add(Entry(today.minus(4), Entry.yesManual));

      final computed = EntryList();
      computed.recomputeFrom(original, Frequency(1, 3), isNumerical: false);
      expect(computed.getKnown(), isNotEmpty,
          reason: 'models.entry-list-recompute#4');

      computed.recomputeFrom(EntryList(), Frequency(1, 3), isNumerical: false);
      expect(computed.getKnown(), isEmpty,
          reason: 'models.entry-list-recompute#4');
    });

    test('#5 the worked boolean example with Frequency(1, 3)', () {
      final today = LocalDate.ymd(2015, 1, 25);

      final original = EntryList();
      original.add(Entry(today.minus(4), Entry.yesManual));
      original.add(Entry(today.minus(9), Entry.yesManual));
      original.add(Entry(today.minus(10), Entry.yesManual));

      final computed = EntryList();
      computed.recomputeFrom(original, Frequency(1, 3), isNumerical: false);

      final expected = [
        Entry(today.minus(2), Entry.yesAuto),
        Entry(today.minus(3), Entry.yesAuto),
        Entry(today.minus(4), Entry.yesManual),
        Entry(today.minus(7), Entry.yesAuto),
        Entry(today.minus(8), Entry.yesAuto),
        Entry(today.minus(9), Entry.yesManual),
        Entry(today.minus(10), Entry.yesManual),
        Entry(today.minus(11), Entry.yesAuto),
        Entry(today.minus(12), Entry.yesAuto),
      ];
      expect(computed.getKnown(), expected,
          reason: 'models.entry-list-recompute#5');
    });

    test('#6 the worked numerical example', () {
      final today = LocalDate.ymd(2015, 1, 25);

      final original = EntryList();
      original.add(Entry(today.minus(4), 100));
      original.add(Entry(today.minus(9), 200));
      original.add(Entry(today.minus(10), 300));

      final computed = EntryList();
      computed.recomputeFrom(original, Frequency.daily, isNumerical: true);

      expect(
        computed.getKnown(),
        [
          Entry(today.minus(4), 100),
          Entry(today.minus(9), 200),
          Entry(today.minus(10), 300),
        ],
        reason: 'models.entry-list-recompute#6',
      );
    });
  });

  group('models.entry-grouped-sum', () {
    test('#1 #4 entries are mapped, grouped by truncated date, then summed',
        () {
      final entries = [
        Entry(LocalDate.ymd(2015, 3, 14), 5),
        Entry(LocalDate.ymd(2015, 3, 14), 7),
        Entry(LocalDate.ymd(2015, 3, 13), 11),
      ];
      expect(
        entries.groupedSum(
            truncateField: TruncateField.day, isNumerical: true),
        [
          Entry(LocalDate.ymd(2015, 3, 14), 12),
          Entry(LocalDate.ymd(2015, 3, 13), 11),
        ],
        reason: 'models.entry-grouped-sum#1',
      );

      // Truncation targets, one per field.
      final march14 = [Entry(LocalDate.ymd(2015, 3, 14), 5)];
      expect(
        march14
            .groupedSum(truncateField: TruncateField.day, isNumerical: true)
            .single
            .date,
        LocalDate.ymd(2015, 3, 14),
        reason: 'models.entry-grouped-sum#4',
      );
      expect(
        march14
            .groupedSum(
                truncateField: TruncateField.weekNumber, isNumerical: true)
            .single
            .date,
        LocalDate.ymd(2015, 3, 14).startOfWeek(DayOfWeek.saturday),
        reason: 'models.entry-grouped-sum#4',
      );
      expect(
        march14
            .groupedSum(truncateField: TruncateField.month, isNumerical: true)
            .single
            .date,
        LocalDate.ymd(2015, 3, 1),
        reason: 'models.entry-grouped-sum#4',
      );
      expect(
        march14
            .groupedSum(
                truncateField: TruncateField.quarter, isNumerical: true)
            .single
            .date,
        LocalDate.ymd(2015, 1, 1),
        reason: 'models.entry-grouped-sum#4',
      );
      expect(
        march14
            .groupedSum(truncateField: TruncateField.year, isNumerical: true)
            .single
            .date,
        LocalDate.ymd(2015, 1, 1),
        reason: 'models.entry-grouped-sum#4',
      );
    });

    test('#2 numerical mapping: SKIP is zero, negatives clamp to zero', () {
      final date = LocalDate.ymd(2015, 3, 14);
      final entries = [
        Entry(date, Entry.skip),
        Entry(date, Entry.unknown),
        Entry(date, Entry.no),
        Entry(date, 500),
      ];
      expect(
        entries
            .groupedSum(truncateField: TruncateField.day, isNumerical: true)
            .single,
        Entry(date, 500),
        reason: 'models.entry-grouped-sum#2',
      );
      expect(
        [Entry(date, Entry.skip)]
            .groupedSum(truncateField: TruncateField.day, isNumerical: true)
            .single
            .value,
        0,
        reason: 'models.entry-grouped-sum#2',
      );
      expect(
        [Entry(date, Entry.unknown)]
            .groupedSum(truncateField: TruncateField.day, isNumerical: true)
            .single
            .value,
        0,
        reason: 'models.entry-grouped-sum#2',
      );
      // YES_MANUAL (2) is not special for numerical habits: it counts as 2.
      expect(
        [Entry(date, Entry.yesManual)]
            .groupedSum(truncateField: TruncateField.day, isNumerical: true)
            .single
            .value,
        2,
        reason: 'models.entry-grouped-sum#2',
      );
    });

    test('#3 boolean mapping: YES_MANUAL is 1000, everything else is 0', () {
      final date = LocalDate.ymd(2015, 3, 14);
      for (final value in [
        Entry.yesAuto,
        Entry.skip,
        Entry.no,
        Entry.unknown,
        500,
      ]) {
        expect(
          [Entry(date, value)]
              .groupedSum(truncateField: TruncateField.day, isNumerical: false)
              .single
              .value,
          0,
          reason: 'models.entry-grouped-sum#3',
        );
      }
      expect(
        [Entry(date, Entry.yesManual), Entry(date, Entry.yesManual)]
            .groupedSum(truncateField: TruncateField.day, isNumerical: false)
            .single
            .value,
        2000,
        reason: 'models.entry-grouped-sum#3',
      );
    });

    test('#5 firstWeekday is a 1-based DayOfWeek index, defaulting to 7', () {
      // 2015-01-25 is a Sunday, 2015-01-26 a Monday.
      final entries = [
        Entry(LocalDate.ymd(2015, 1, 26), Entry.yesManual),
        Entry(LocalDate.ymd(2015, 1, 25), Entry.yesManual),
      ];

      // firstWeekday 1 == SUNDAY: both days fall in the week of Jan 25.
      expect(
        entries.groupedSum(
          truncateField: TruncateField.weekNumber,
          firstWeekday: 1,
          isNumerical: false,
        ),
        [Entry(LocalDate.ymd(2015, 1, 25), 2000)],
        reason: 'models.entry-grouped-sum#5',
      );

      // firstWeekday 2 == MONDAY: the Sunday belongs to the previous week.
      expect(
        entries.groupedSum(
          truncateField: TruncateField.weekNumber,
          firstWeekday: 2,
          isNumerical: false,
        ),
        [
          Entry(LocalDate.ymd(2015, 1, 26), 1000),
          Entry(LocalDate.ymd(2015, 1, 19), 1000),
        ],
        reason: 'models.entry-grouped-sum#5',
      );

      // The default is 7 == SATURDAY: the week starts on Jan 24.
      expect(
        entries.groupedSum(
          truncateField: TruncateField.weekNumber,
          isNumerical: false,
        ),
        [Entry(LocalDate.ymd(2015, 1, 24), 2000)],
        reason: 'models.entry-grouped-sum#5',
      );

      // firstWeekday is ignored for every other field.
      expect(
        entries.groupedSum(
          truncateField: TruncateField.month,
          firstWeekday: 2,
          isNumerical: false,
        ),
        [Entry(LocalDate.ymd(2015, 1, 1), 2000)],
        reason: 'models.entry-grouped-sum#5',
      );
    });

    test('#6 buckets are newest-first and gaps are preserved', () {
      final entries = [
        Entry(LocalDate.ymd(2015, 3, 14), 5),
        Entry(LocalDate.ymd(2015, 1, 14), 7),
      ];
      final byMonth = entries.groupedSum(
          truncateField: TruncateField.month, isNumerical: true);
      expect(byMonth.length, 2, reason: 'models.entry-grouped-sum#6');
      expect(byMonth[0], Entry(LocalDate.ymd(2015, 3, 1), 5),
          reason: 'models.entry-grouped-sum#6');
      expect(byMonth[1], Entry(LocalDate.ymd(2015, 1, 1), 7),
          reason: 'models.entry-grouped-sum#6');
      // February produced no bucket at all.
      expect(
        byMonth.where((e) => e.date == LocalDate.ymd(2015, 2, 1)),
        isEmpty,
        reason: 'models.entry-grouped-sum#6',
      );

      // Insertion order of the source list does not matter.
      final reversed = entries.reversed
          .toList()
          .groupedSum(truncateField: TruncateField.month, isNumerical: true);
      expect(reversed, byMonth, reason: 'models.entry-grouped-sum#6');
    });

    test('#7 the worked example over 100 checkmarks', () {
      final offsets = <int>[
        0, 5, 9, 15, 17, 21, 23, 27, 28, 35, 41, 45, 47, 53, 56, 62, 70, 73, 78,
        83, 86, 94, 101, 106, 113, 114, 120, 126, 130, 133, 141, 143, 148, 151,
        157, 164, 166, 171, 173, 176, 179, 183, 191, 259, 264, 268, 270, 275,
        282, 284, 289, 295, 302, 306, 310, 315, 323, 325, 328, 335, 343, 349,
        351, 353, 357, 359, 360, 367, 372, 376, 380, 385, 393, 400, 404, 412,
        415, 418, 422, 425, 433, 437, 444, 449, 455, 460, 462, 465, 470, 471,
        479, 481, 485, 489, 494, 495, 500, 501, 503, 507,
      ];

      final reference = LocalDate.ymd(2014, 6, 1);
      final entries = EntryList();
      for (final offset in offsets) {
        entries.add(Entry(reference.minus(offset), Entry.yesManual));
      }

      final byMonth = entries
          .getKnown()
          .groupedSum(truncateField: TruncateField.month, isNumerical: false);
      expect(byMonth.length, 17, reason: 'models.entry-grouped-sum#7');
      expect(byMonth[0], Entry(LocalDate.ymd(2014, 6, 1), 1000),
          reason: 'models.entry-grouped-sum#7');
      expect(byMonth[6], Entry(LocalDate.ymd(2013, 12, 1), 7000),
          reason: 'models.entry-grouped-sum#7');
      expect(byMonth[12], Entry(LocalDate.ymd(2013, 5, 1), 6000),
          reason: 'models.entry-grouped-sum#7');

      final byQuarter = entries
          .getKnown()
          .groupedSum(truncateField: TruncateField.quarter, isNumerical: false);
      expect(byQuarter.length, 6, reason: 'models.entry-grouped-sum#7');
      expect(byQuarter[0], Entry(LocalDate.ymd(2014, 4, 1), 15000),
          reason: 'models.entry-grouped-sum#7');
      expect(byQuarter[3], Entry(LocalDate.ymd(2013, 7, 1), 17000),
          reason: 'models.entry-grouped-sum#7');
      expect(byQuarter[5], Entry(LocalDate.ymd(2013, 1, 1), 20000),
          reason: 'models.entry-grouped-sum#7');

      final byYear = entries
          .getKnown()
          .groupedSum(truncateField: TruncateField.year, isNumerical: false);
      expect(byYear.length, 2, reason: 'models.entry-grouped-sum#7');
      expect(byYear[0], Entry(LocalDate.ymd(2014, 1, 1), 34000),
          reason: 'models.entry-grouped-sum#7');
      expect(byYear[1], Entry(LocalDate.ymd(2013, 1, 1), 66000),
          reason: 'models.entry-grouped-sum#7');
    });

    test('#7 the same example with numerical values', () {
      final offsets = <int>[
        0, 5, 9, 15, 17, 21, 23, 27, 28, 35, 41, 45, 47, 53, 56, 62, 70, 73, 78,
        83, 86, 94, 101, 106, 113, 114, 120, 126, 130, 133, 141, 143, 148, 151,
        157, 164, 166, 171, 173, 176, 179, 183, 191, 259, 264, 268, 270, 275,
        282, 284, 289, 295, 302, 306, 310, 315, 323, 325, 328, 335, 343, 349,
        351, 353, 357, 359, 360, 367, 372, 376, 380, 385, 393, 400, 404, 412,
        415, 418, 422, 425, 433, 437, 444, 449, 455, 460, 462, 465, 470, 471,
        479, 481, 485, 489, 494, 495, 500, 501, 503, 507,
      ];
      final values = <int>[
        230, 306, 148, 281, 134, 285, 104, 158, 325, 236, 303, 210, 118, 124,
        301, 201, 156, 376, 347, 367, 396, 134, 160, 381, 155, 354, 231, 134,
        164, 354, 236, 398, 199, 221, 208, 397, 253, 276, 214, 341, 299, 221,
        353, 250, 341, 168, 374, 205, 182, 217, 297, 321, 104, 237, 294, 110,
        136, 229, 102, 271, 250, 294, 158, 319, 379, 126, 282, 155, 288, 159,
        215, 247, 207, 226, 244, 158, 371, 219, 272, 228, 350, 153, 356, 279,
        394, 202, 213, 214, 112, 248, 139, 245, 165, 256, 370, 187, 208, 231,
        341, 312,
      ];

      final reference = LocalDate.ymd(2014, 6, 1);
      final entries = EntryList();
      for (var i = 0; i < offsets.length; i++) {
        entries.add(Entry(reference.minus(offsets[i]), values[i]));
      }

      final byMonth = entries
          .getKnown()
          .groupedSum(truncateField: TruncateField.month, isNumerical: true);
      expect(byMonth.length, 17, reason: 'models.entry-grouped-sum#2');
      expect(byMonth[0], Entry(LocalDate.ymd(2014, 6, 1), 230),
          reason: 'models.entry-grouped-sum#2');
      expect(byMonth[6], Entry(LocalDate.ymd(2013, 12, 1), 1988),
          reason: 'models.entry-grouped-sum#2');
      expect(byMonth[12], Entry(LocalDate.ymd(2013, 5, 1), 1271),
          reason: 'models.entry-grouped-sum#2');

      final byQuarter = entries
          .getKnown()
          .groupedSum(truncateField: TruncateField.quarter, isNumerical: true);
      expect(byQuarter.length, 6, reason: 'models.entry-grouped-sum#4');
      expect(byQuarter[0], Entry(LocalDate.ymd(2014, 4, 1), 3263),
          reason: 'models.entry-grouped-sum#4');
      expect(byQuarter[3], Entry(LocalDate.ymd(2013, 7, 1), 3838),
          reason: 'models.entry-grouped-sum#4');
      expect(byQuarter[5], Entry(LocalDate.ymd(2013, 1, 1), 4975),
          reason: 'models.entry-grouped-sum#4');

      final byYear = entries
          .getKnown()
          .groupedSum(truncateField: TruncateField.year, isNumerical: true);
      expect(byYear.length, 2, reason: 'models.entry-grouped-sum#4');
      expect(byYear[0], Entry(LocalDate.ymd(2014, 1, 1), 8227),
          reason: 'models.entry-grouped-sum#4');
      expect(byYear[1], Entry(LocalDate.ymd(2013, 1, 1), 16172),
          reason: 'models.entry-grouped-sum#4');
    });

    test('#8 the first bucket is the current period; empty input has none', () {
      // TargetCard reads `.firstOrNull()?.value ?: 0`, so an empty result must
      // mean zero and a non-empty one must start at the newest bucket.
      final empty = <Entry>[]
          .groupedSum(truncateField: TruncateField.day, isNumerical: true);
      expect(empty, isEmpty, reason: 'models.entry-grouped-sum#8');
      expect(empty.isEmpty ? 0 : empty.first.value, 0,
          reason: 'models.entry-grouped-sum#8');

      final entries = [
        Entry(LocalDate.ymd(2015, 3, 14), 5),
        Entry(LocalDate.ymd(2015, 3, 10), 7),
      ];
      final byDay = entries.groupedSum(
          truncateField: TruncateField.day, isNumerical: true);
      expect(byDay.first, Entry(LocalDate.ymd(2015, 3, 14), 5),
          reason: 'models.entry-grouped-sum#8');
    });
  });

  group('models.entry-count-skipped-days', () {
    test('#1 #2 SKIP counts as one, everything else as zero', () {
      final entries = [
        Entry(LocalDate.ymd(2015, 3, 14), Entry.skip),
        Entry(LocalDate.ymd(2015, 3, 12), Entry.skip),
        Entry(LocalDate.ymd(2015, 3, 11), Entry.yesManual),
        Entry(LocalDate.ymd(2015, 3, 10), Entry.no),
        Entry(LocalDate.ymd(2015, 3, 9), Entry.unknown),
        Entry(LocalDate.ymd(2015, 3, 8), Entry.yesAuto),
        Entry(LocalDate.ymd(2015, 2, 14), Entry.skip),
      ];

      final byMonth =
          entries.countSkippedDays(truncateField: TruncateField.month);
      expect(byMonth.length, 2,
          reason: 'models.entry-count-skipped-days#2');
      expect(byMonth[0], Entry(LocalDate.ymd(2015, 3, 1), 2),
          reason: 'models.entry-count-skipped-days#1');
      expect(byMonth[1], Entry(LocalDate.ymd(2015, 2, 1), 1),
          reason: 'models.entry-count-skipped-days#2');

      // Same truncation rules as groupedSum, including the firstWeekday index.
      final sunday = [Entry(LocalDate.ymd(2015, 1, 25), Entry.skip)];
      expect(
        sunday
            .countSkippedDays(
                truncateField: TruncateField.weekNumber, firstWeekday: 2)
            .single,
        Entry(LocalDate.ymd(2015, 1, 19), 1),
        reason: 'models.entry-count-skipped-days#1',
      );
      expect(
        sunday.countSkippedDays(truncateField: TruncateField.weekNumber).single,
        Entry(LocalDate.ymd(2015, 1, 24), 1),
        reason: 'models.entry-count-skipped-days#1',
      );
      expect(
        sunday.countSkippedDays(truncateField: TruncateField.day).single,
        Entry(LocalDate.ymd(2015, 1, 25), 1),
        reason: 'models.entry-count-skipped-days#1',
      );
      expect(
        sunday.countSkippedDays(truncateField: TruncateField.quarter).single,
        Entry(LocalDate.ymd(2015, 1, 1), 1),
        reason: 'models.entry-count-skipped-days#1',
      );
      expect(
        sunday.countSkippedDays(truncateField: TruncateField.year).single,
        Entry(LocalDate.ymd(2015, 1, 1), 1),
        reason: 'models.entry-count-skipped-days#1',
      );
    });

    test('#3 SKIP is detected identically for boolean and numerical habits',
        () {
      final date = LocalDate.ymd(2015, 3, 14);

      // A numerical-looking list: large values, one SKIP.
      final numerical = [
        Entry(date, 500),
        Entry(date, Entry.skip),
        Entry(date, 1200),
      ];
      // A boolean-looking list: the same SKIP among checkmarks.
      final boolean = [
        Entry(date, Entry.yesManual),
        Entry(date, Entry.skip),
        Entry(date, Entry.yesAuto),
      ];

      expect(
        numerical.countSkippedDays(truncateField: TruncateField.day).single,
        Entry(date, 1),
        reason: 'models.entry-count-skipped-days#3',
      );
      expect(
        boolean.countSkippedDays(truncateField: TruncateField.day).single,
        Entry(date, 1),
        reason: 'models.entry-count-skipped-days#3',
      );
      expect(
        numerical.countSkippedDays(truncateField: TruncateField.day),
        boolean.countSkippedDays(truncateField: TruncateField.day),
        reason: 'models.entry-count-skipped-days#3',
      );
    });
  });

  group('models.entry-weekday-frequency', () {
    test('#1 #2 #3 #4 #5 boolean histogram keyed by the first of the month',
        () {
      final entries = EntryList();
      // 2015-01-01 is a Thursday, so its bucket index is (4 + 1) % 7 == 5.
      entries.add(Entry(LocalDate.ymd(2015, 1, 1), Entry.yesManual)); // Thu
      entries.add(Entry(LocalDate.ymd(2015, 1, 2), Entry.yesManual)); // Fri
      entries.add(Entry(LocalDate.ymd(2015, 1, 3), Entry.no)); // Sat
      entries.add(Entry(LocalDate.ymd(2015, 1, 8), Entry.yesManual)); // Thu
      // February has entries but no checkmarks at all.
      entries.add(Entry(LocalDate.ymd(2015, 2, 1), Entry.no)); // Sun
      // March is left completely empty.

      final freq = entries.computeWeekdayFrequency(isNumerical: false);

      final january = freq[LocalDate.ymd(2015, 1, 1)];
      expect(january, isNotNull, reason: 'models.entry-weekday-frequency#1');
      expect(january!.length, 7, reason: 'models.entry-weekday-frequency#1');
      expect(january, [0, 0, 0, 0, 0, 2, 1],
          reason: 'models.entry-weekday-frequency#3');

      // Index 0 is Saturday, 1 Sunday, 2 Monday ... 6 Friday.
      expect(january[5], 2, reason: 'models.entry-weekday-frequency#2');
      expect(january[6], 1, reason: 'models.entry-weekday-frequency#2');
      expect(january[0], 0, reason: 'models.entry-weekday-frequency#2');

      // The map is keyed by startOfMonth, never by the entry date itself.
      expect(freq[LocalDate.ymd(2015, 1, 8)], isNull,
          reason: 'models.entry-weekday-frequency#1');

      // A month with entries but zero YES_MANUAL is an all-zero array.
      expect(freq[LocalDate.ymd(2015, 2, 1)], [0, 0, 0, 0, 0, 0, 0],
          reason: 'models.entry-weekday-frequency#5');

      // A month with no entries at all has no key.
      expect(freq.containsKey(LocalDate.ymd(2015, 3, 1)), isFalse,
          reason: 'models.entry-weekday-frequency#4');
      expect(freq[LocalDate.ymd(2015, 3, 1)], isNull,
          reason: 'models.entry-weekday-frequency#4');

      expect(freq.length, 2, reason: 'models.entry-weekday-frequency#4');
    });

    test('#2 every weekday lands in its Saturday-first slot', () {
      final entries = EntryList();
      // 2015-01-04 is a Sunday; the following week covers all seven weekdays.
      for (var i = 0; i < 7; i++) {
        entries.add(
            Entry(LocalDate.ymd(2015, 1, 4).plus(i), Entry.yesManual));
      }
      final freq =
          entries.computeWeekdayFrequency(isNumerical: false)[
              LocalDate.ymd(2015, 1, 1)]!;
      expect(freq, [1, 1, 1, 1, 1, 1, 1],
          reason: 'models.entry-weekday-frequency#2');

      final one = EntryList();
      one.add(Entry(LocalDate.ymd(2015, 1, 3), Entry.yesManual)); // Saturday
      expect(
        one.computeWeekdayFrequency(isNumerical: false)[
            LocalDate.ymd(2015, 1, 1)],
        [1, 0, 0, 0, 0, 0, 0],
        reason: 'models.entry-weekday-frequency#2',
      );

      final two = EntryList();
      two.add(Entry(LocalDate.ymd(2015, 1, 4), Entry.yesManual)); // Sunday
      expect(
        two.computeWeekdayFrequency(isNumerical: false)[
            LocalDate.ymd(2015, 1, 1)],
        [0, 1, 0, 0, 0, 0, 0],
        reason: 'models.entry-weekday-frequency#2',
      );

      final three = EntryList();
      three.add(Entry(LocalDate.ymd(2015, 1, 5), Entry.yesManual)); // Monday
      expect(
        three.computeWeekdayFrequency(isNumerical: false)[
            LocalDate.ymd(2015, 1, 1)],
        [0, 0, 1, 0, 0, 0, 0],
        reason: 'models.entry-weekday-frequency#2',
      );
    });

    test('#3 numerical mode sums the raw stored values, warts and all', () {
      final entries = EntryList();
      entries.add(Entry(LocalDate.ymd(2015, 1, 1), 100)); // Thu -> index 5
      entries.add(Entry(LocalDate.ymd(2015, 1, 2), Entry.skip)); // Fri -> 6
      entries.add(Entry(LocalDate.ymd(2015, 1, 3), Entry.unknown)); // Sat -> 0
      entries.add(Entry(LocalDate.ymd(2015, 1, 8), 50)); // Thu -> index 5

      expect(
        entries.computeWeekdayFrequency(isNumerical: true)[
            LocalDate.ymd(2015, 1, 1)],
        [-1, 0, 0, 0, 0, 150, 3],
        reason: 'models.entry-weekday-frequency#3',
      );

      // The same list read as boolean counts only YES_MANUAL, which is none.
      expect(
        entries.computeWeekdayFrequency(isNumerical: false)[
            LocalDate.ymd(2015, 1, 1)],
        [0, 0, 0, 0, 0, 0, 0],
        reason: 'models.entry-weekday-frequency#3',
      );
    });
  });
}
