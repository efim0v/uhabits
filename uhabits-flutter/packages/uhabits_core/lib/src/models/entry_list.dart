import 'dart:math' as math;

import '../time/local_date.dart';
import 'entry.dart';
import 'frequency.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/EntryList.kt
///
/// Kotlin nests this as `EntryList.Interval`; Dart has no nested classes, so it
/// lives here as a top-level type with the same three fields.
///
/// [begin] is the OLDER endpoint and [end] the NEWER one, so `begin <= center
/// <= end` for every interval the algorithm produces.
class Interval {
  const Interval(this.begin, this.center, this.end);

  final LocalDate begin;

  final LocalDate center;

  final LocalDate end;

  int get length => begin.daysUntil(end) + 1;

  @override
  bool operator ==(Object other) =>
      other is Interval &&
      other.begin == begin &&
      other.center == center &&
      other.end == end;

  @override
  int get hashCode => Object.hash(begin, center, end);

  @override
  String toString() => 'Interval(begin=$begin, center=$center, end=$end)';
}

/// A sparse map from date to [Entry], plus the algorithm that turns a habit's
/// manual checkmarks into the YES_AUTO values every chart displays.
///
/// Kotlin annotates every accessor `@Synchronized`. Dart isolates are
/// single-threaded, so that is a no-op here; what carries over is that
/// [getKnown] and [getByInterval] hand back fresh lists rather than live views
/// of the backing map.
class EntryList {
  final Map<LocalDate, Entry> _entriesByDate = <LocalDate, Entry>{};

  /// Returns the entry corresponding to the given date. If no entry with such
  /// date has been previously added, returns Entry(date, UNKNOWN).
  Entry get(LocalDate date) =>
      _entriesByDate[date] ?? Entry(date, Entry.unknown);

  /// Returns one entry for each day in the given interval. The first element
  /// corresponds to the newest entry, and the last element corresponds to the
  /// oldest. The interval endpoints are included.
  List<Entry> getByInterval(LocalDate from, LocalDate to) {
    final result = <Entry>[];
    if (from.isNewerThan(to)) return result;
    var current = to;
    while (current >= from) {
      result.add(get(current));
      current = current.minus(1);
    }
    return result;
  }

  /// Adds the given entry to the list. If another entry with the same date
  /// already exists, replaces it.
  void add(Entry entry) {
    _entriesByDate[entry.date] = entry;
  }

  /// Returns all entries whose values are known, sorted by date. The first
  /// element corresponds to the newest entry, and the last element corresponds
  /// to the oldest.
  List<Entry> getKnown() {
    final sorted = _entriesByDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted.reversed.toList();
  }

  /// Replaces all entries in this list by entries computed automatically from
  /// another list.
  ///
  /// For boolean habits, this function creates additional entries (with value
  /// YES_AUTO) according to the frequency of the habit. For numerical habits,
  /// this function simply copies all entries.
  void recomputeFrom(
    EntryList originalEntries,
    Frequency frequency, {
    required bool isNumerical,
  }) {
    clear();
    final original = originalEntries.getKnown();
    if (isNumerical) {
      for (final entry in original) {
        add(entry);
      }
    } else {
      final intervals = buildIntervals(frequency, original);
      snapIntervalsTogether(intervals);
      final computed = buildEntriesFromInterval(original, intervals);
      for (final entry in computed) {
        if (entry.value != Entry.unknown || entry.notes.isNotEmpty) {
          add(entry);
        }
      }
    }
  }

  /// Removes all known entries.
  void clear() {
    _entriesByDate.clear();
  }

  /// Returns the total number of successful entries for each month, grouped by
  /// day of week.
  ///
  /// The key is the first day of the month. The value is a 7-element list whose
  /// first entry counts the checkmarks that fell on a Saturday, the second on a
  /// Sunday, and so on. Months without any stored entry get no key at all, so
  /// callers must treat a missing bucket as 'no data'.
  Map<LocalDate, List<int>> computeWeekdayFrequency({
    required bool isNumerical,
  }) {
    final entries = getKnown();
    final map = <LocalDate, List<int>>{};
    for (final entry in entries) {
      final weekday = (entry.date.dayOfWeek.daysSinceSunday + 1) % 7;
      final monthStart = entry.date.startOfMonth();

      var list = map[monthStart];
      if (list == null) {
        list = <int>[0, 0, 0, 0, 0, 0, 0];
        map[monthStart] = list;
      }

      if (isNumerical) {
        list[weekday] += entry.value;
      } else if (entry.value == Entry.yesManual) {
        list[weekday] += 1;
      }
    }
    return map;
  }

  /// Converts a list of intervals into a list of entries. Entries that fall
  /// outside of any interval receive value UNKNOWN. Entries that fall within an
  /// interval but do not appear in [original] receive value YES_AUTO. Entries
  /// provided in [original] are copied over.
  ///
  /// The intervals should be sorted by date. The first element in the list
  /// should correspond to the newest interval.
  static List<Entry> buildEntriesFromInterval(
    List<Entry> original,
    List<Interval> intervals,
  ) {
    final result = <Entry>[];
    if (original.isEmpty) return result;

    var from = original[0].date;
    var to = original[0].date;

    for (final e in original) {
      if (e.date < from) from = e.date;
      if (e.date > to) to = e.date;
    }
    for (final interval in intervals) {
      if (interval.begin < from) from = interval.begin;
      if (interval.end > to) to = interval.end;
    }

    // Create unknown entries
    var current = to;
    while (current >= from) {
      result.add(Entry(current, Entry.unknown));
      current = current.minus(1);
    }

    // Create YES_AUTO entries
    for (final interval in intervals) {
      current = interval.end;
      while (current >= interval.begin) {
        final offset = current.daysUntil(to);
        result[offset] = Entry(current, Entry.yesAuto);
        current = current.minus(1);
      }
    }

    // Copy original entries
    for (final entry in original) {
      final offset = entry.date.daysUntil(to);
      final int value;
      if (result[offset].value == Entry.unknown ||
          entry.value == Entry.skip ||
          entry.value == Entry.yesManual) {
        value = entry.value;
      } else {
        value = Entry.yesAuto;
      }
      result[offset] = Entry(entry.date, value, notes: entry.notes);
    }

    return result;
  }

  /// Starting from the second newest interval, this function tries to slide the
  /// intervals backwards into the past, so that gaps are eliminated and streaks
  /// are maximized.
  ///
  /// The intervals should be sorted by date. The first element in the list
  /// should correspond to the newest interval. The list is mutated in place,
  /// and each step reads the already-shifted neighbour, so shifts accumulate.
  static void snapIntervalsTogether(List<Interval> intervals) {
    for (var i = 1; i < intervals.length; i++) {
      final curr = intervals[i];
      final next = intervals[i - 1];
      final gapNextToCurrent = next.begin.daysUntil(curr.end);
      final gapCenterToEnd = curr.center.daysUntil(curr.end);
      if (gapNextToCurrent >= 0) {
        final shift = math.min(gapCenterToEnd, gapNextToCurrent + 1);
        intervals[i] = Interval(
          curr.begin.minus(shift),
          curr.center,
          curr.end.minus(shift),
        );
      }
    }
  }

  /// Builds one interval per group of [Frequency.numerator] manual checkmarks
  /// that fit inside a single window. [entries] must be ordered newest-first;
  /// the result follows the same order.
  static List<Interval> buildIntervals(
    Frequency freq,
    List<Entry> entries,
  ) {
    final filtered =
        entries.where((it) => it.value == Entry.yesManual).toList();
    final num = freq.numerator;
    final den = freq.denominator;
    final intervals = <Interval>[];
    for (var i = num - 1; i < filtered.length; i++) {
      final begin = filtered[i].date;
      final center = filtered[i - num + 1].date;
      var size = den;
      if (den == 30 || den == 31) {
        size = begin.day == begin.monthLength
            ? begin.plus(1).monthLength
            : begin.monthLength;
      }
      if (begin.daysUntil(center) < size) {
        final end = begin.plus(size - 1);
        intervals.add(Interval(begin, center, end));
      }
    }
    return intervals;
  }
}

LocalDate _truncateDate(
  LocalDate date,
  TruncateField field,
  DayOfWeek firstWeekday,
) {
  switch (field) {
    case TruncateField.day:
      return date;
    case TruncateField.weekNumber:
      return date.startOfWeek(firstWeekday);
    case TruncateField.month:
      return date.startOfMonth();
    case TruncateField.quarter:
      return date.startOfQuarter();
    case TruncateField.year:
      return date.startOfYear();
  }
}

/// The two Kotlin extension functions on `List<Entry>`, kept as an extension so
/// the call sites read the same: `entries.groupedSum(...)`.
extension EntryListAggregates on List<Entry> {
  /// Truncates the date of each entry (according to the field given), groups
  /// the entries by this truncated date, then creates a new entry (d, v) for
  /// each group, where d is the truncated date and v is the sum of the values
  /// of all entries in the group.
  ///
  /// For numerical habits, non-positive entry values are converted to zero. For
  /// boolean habits, each YES_MANUAL value is converted to 1000 and all other
  /// values are converted to zero.
  ///
  /// SKIP values are converted to zero (if they weren't, each SKIP day would
  /// count as 0.003).
  ///
  /// The returned list is sorted by date, newest first. Gaps in the source list
  /// stay gaps: a period with no entries produces no bucket.
  ///
  /// [firstWeekday] is a 1-based index into [DayOfWeek] (1 == sunday,
  /// 7 == saturday) and is only relevant when truncating by week.
  List<Entry> groupedSum({
    required TruncateField truncateField,
    int firstWeekday = 7,
    required bool isNumerical,
  }) {
    final firstWeekdayEnum = DayOfWeek.values[firstWeekday - 1];
    final mapped = map((entry) {
      final date = entry.date;
      final value = entry.value;
      if (isNumerical) {
        if (value == Entry.skip) {
          return Entry(date, 0);
        } else {
          return Entry(date, math.max(0, value));
        }
      } else {
        return Entry(date, value == Entry.yesManual ? 1000 : 0);
      }
    });
    return _sumByTruncatedDate(mapped, truncateField, firstWeekdayEnum);
  }

  /// Counts the number of days with value SKIP in each period.
  ///
  /// There is no isNumerical parameter: SKIP is detected identically for
  /// boolean and numerical habits.
  List<Entry> countSkippedDays({
    required TruncateField truncateField,
    int firstWeekday = 7,
  }) {
    final firstWeekdayEnum = DayOfWeek.values[firstWeekday - 1];
    final mapped = map((entry) {
      if (entry.value == Entry.skip) {
        return Entry(entry.date, 1);
      } else {
        return Entry(entry.date, 0);
      }
    });
    return _sumByTruncatedDate(mapped, truncateField, firstWeekdayEnum);
  }
}

/// Kotlin's `groupBy { … }.entries.map { … }.sortedBy { -daysSince2000 }`.
List<Entry> _sumByTruncatedDate(
  Iterable<Entry> mapped,
  TruncateField truncateField,
  DayOfWeek firstWeekday,
) {
  final groups = <LocalDate, List<Entry>>{};
  for (final entry in mapped) {
    final key = _truncateDate(entry.date, truncateField, firstWeekday);
    (groups[key] ??= <Entry>[]).add(entry);
  }
  final result = groups.entries
      .map((e) => Entry(e.key, e.value.fold(0, (sum, it) => sum + it.value)))
      .toList();
  result.sort((a, b) => (-a.date.daysSince2000) - (-b.date.daysSince2000));
  return result;
}
