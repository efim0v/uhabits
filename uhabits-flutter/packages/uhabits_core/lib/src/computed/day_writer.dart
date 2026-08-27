import '../models/entry.dart';
import '../models/habit.dart';
import '../time/local_date.dart';

/// Told that a computed habit's stored days changed.
///
/// A function rather than the application scope: the door needs the
/// announcement, not the app. Core cannot see the app anyway.
typedef ComputedDataChanged = void Function(int habitId);

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
  const DayWriter({ComputedDataChanged? onChanged}) : _onChanged = onChanged;

  /// Null wherever there is nothing to tell — every test of the rules above,
  /// and every read-only use.
  final ComputedDataChanged? _onChanged;

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

  /// Writes a run of days, and — if any of them changed — recomputes the habit
  /// and announces it, once.
  ///
  /// The announcement is here rather than at each kind's sweep because a kind's
  /// sweep is exactly where a rule kept by convention gets dropped: the first
  /// kind called the signal by hand from three places of its own, and the
  /// second kind's three places would have had no reason to know it existed.
  ///
  /// Once, and after the last write, for two reasons that pull the same way.
  /// The signal starts a refresh task per call, and a first sync covering two
  /// years would start seven hundred of them. And a listener redraws from the
  /// habit — on the test dispatcher it redraws on this very stack — so it must
  /// not be told while the run is half written.
  ///
  /// `recompute()` before the announcement, and inside the door rather than at
  /// the caller, for the same reason the writes are here: a kind that forgot it
  /// would announce values nothing had recomputed
  /// (`computed.freshness#2`, `#3`, `#4`).
  bool writeDays(Habit habit, Map<int, int?> valuesByDay) {
    var changed = false;
    for (final MapEntry<int, int?> day in valuesByDay.entries) {
      if (write(habit, day.key, day.value)) changed = true;
    }
    if (!changed) return false;
    habit.recompute();
    _onChanged?.call(habit.id!);
    return true;
  }

  /// Снимает вычисленное значение с [day], возвращая день в молчание.
  ///
  /// Дверь наружу для отмены: `write(habit, day, null)` означает «сказать
  /// нечего» и оставляет запись как была (`computed.day-write#3`), а здесь
  /// сказано именно «того, что было записано, не было». Пишет `Entry.unknown`,
  /// а не удаляет строку: удаления отдельного дня у `EntryList` нет, а
  /// `-1` — то самое значение, которое сам оригинал пишет при выключении
  /// ячейки (`models/entry.dart:66-78`).
  ///
  /// Пропуск не снимает: он есть отметка человека (`computed.day-write#4`).
  ///
  /// Пересчёт и объявление — здесь же и в том же порядке, что у [writeDays]:
  /// отмена меняет балл и счётчик ровно так же, как запись, и звать
  /// объявление снаружи значило бы завести второе место, где живёт одно
  /// правило (`computed.freshness#2`, `#4`).
  bool clear(Habit habit, int day) {
    final LocalDate date = LocalDate(day);
    final Entry existing = habit.originalEntries.get(date);
    if (existing.value == Entry.skip) return false;
    if (existing.value == Entry.unknown) return false;
    habit.originalEntries
        .add(Entry(date, Entry.unknown, notes: existing.notes));
    habit.recompute();
    _onChanged?.call(habit.id!);
    return true;
  }
}
