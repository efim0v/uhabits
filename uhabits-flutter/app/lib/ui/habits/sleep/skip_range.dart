import 'package:uhabits_core/uhabits_core.dart' as core;

/// Marks a stretch of days as not applicable.
///
/// A range rather than a day at a time because the thing being marked is a
/// trip, not a night. There is no trip entity to go with it: a range is
/// expressed entirely by the entries it writes, and inventing a table for
/// something already representable would leave two records of the same fact to
/// fall out of step.
///
/// Marking is unrestricted, including in the past. The check on that is not a
/// rule but a number: the habit screen always shows how many days were set
/// aside, so a person cannot skip their way out of a bad fortnight without
/// seeing what they did.
class SkipRange {
  const SkipRange(this.fromDay, this.toDay);

  /// Both ends are `daysSince2000` and both are included.
  final int fromDay;
  final int toDay;

  /// The days this range covers, in order.
  Iterable<int> get days sync* {
    if (toDay < fromDay) return;
    for (var day = fromDay; day <= toDay; day++) {
      yield day;
    }
  }

  int get length => toDay < fromDay ? 0 : toDay - fromDay + 1;

  /// Writes a skip on every day of the range.
  ///
  /// A skip is the port's existing `Entry.skip`: the day is neither a success
  /// nor a failure, the score carries over and the streak survives.
  void applyTo(core.Habit habit) {
    for (final int day in days) {
      habit.originalEntries.add(core.Entry(core.LocalDate(day), core.Entry.skip));
    }
    if (length > 0) habit.recompute();
  }

  /// Removes the skips again, leaving the days with no entry at all.
  ///
  /// Not "writes a zero": an absent entry is what a day with no data is, and
  /// putting a zero there would stop later data from healing it.
  void clearFrom(core.Habit habit) {
    for (final int day in days) {
      final core.LocalDate date = core.LocalDate(day);
      if (habit.originalEntries.get(date).value != core.Entry.skip) continue;
      habit.originalEntries.add(core.Entry(date, core.Entry.unknown));
    }
    if (length > 0) habit.recompute();
  }

  @override
  bool operator ==(Object other) =>
      other is SkipRange && other.fromDay == fromDay && other.toDay == toDay;

  @override
  int get hashCode => Object.hash(fromDay, toDay);

  @override
  String toString() => 'SkipRange($fromDay..$toDay)';
}

/// Whether [day] is marked as not counting.
///
/// One place, because the question is asked from the sheet that sets it, the
/// strip that draws it, and the section that reads it — and three answers to
/// one question is how they come to disagree.
bool isDaySkipped(core.Habit habit, int day) =>
    habit.originalEntries.get(core.LocalDate(day)).value == core.Entry.skip;
