import '../time/local_date.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Streak.kt
///
/// An uninterrupted run of days on which the habit was performed. [start] is
/// the oldest day of the run and [end] the newest, so [start] is never newer
/// than [end].
class Streak {
  const Streak(this.start, this.end);

  final LocalDate start;
  final LocalDate end;

  /// Positive when this streak is longer than [other]. Streaks of equal length
  /// are compared by end date instead, so the comparison is a total order.
  int compareLonger(Streak other) {
    if (length != other.length) {
      return length - other.length;
    } else {
      return compareNewer(other);
    }
  }

  /// Positive when this streak ends later than [other].
  int compareNewer(Streak other) => end.daysSince2000 - other.end.daysSince2000;

  int get length => start.daysUntil(end) + 1;

  @override
  bool operator ==(Object other) =>
      other is Streak && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Streak(start=$start, end=$end)';
}
