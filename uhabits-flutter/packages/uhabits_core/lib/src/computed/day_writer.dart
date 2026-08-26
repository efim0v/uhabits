import '../models/entry.dart';
import '../models/habit.dart';
import '../time/local_date.dart';

/// The one way a computed habit writes a day.
///
/// Four rules live here rather than at each call site, because there is more
/// than one call site and a rule spread across several of them is a rule that
/// will be carried to some and not the rest:
///
///  * the note belongs to the person and survives;
///  * a day with nothing to say stays absent — a written zero freezes it, and
///    data arriving later can no longer heal it;
///  * a day the person marked skipped is theirs, whatever was measured;
///  * a computed value never lands on 1, 2 or 3, which mean yesAuto,
///    yesManual and skip and would read as something a person did.
class DayWriter {
  const DayWriter();

  /// Writes [storedValue] for [day], and answers whether anything changed.
  ///
  /// A null [storedValue] means there is nothing to say about that day.
  bool write(Habit habit, int day, int? storedValue) {
    if (storedValue == null) return false;
    if (storedValue == Entry.yesAuto ||
        storedValue == Entry.yesManual ||
        storedValue == Entry.skip) {
      throw ArgumentError.value(
        storedValue,
        'storedValue',
        'lands on a sentinel and would read as something a person did',
      );
    }

    final LocalDate date = LocalDate(day);
    final Entry existing = habit.originalEntries.get(date);
    if (existing.value == Entry.skip) return false;
    if (existing.value == storedValue) return false;

    habit.originalEntries
        .add(Entry(date, storedValue, notes: existing.notes));
    return true;
  }
}
