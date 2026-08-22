/// SQLite-backed [EntryList].
///
/// Ported line by line from
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteEntryList.kt`.
library;

import '../../database/entry_repository.dart';
import '../../time/local_date.dart';
import '../entry.dart';
import '../entry_list.dart';
import '../frequency.dart';

/// A habit's `originalEntries`: rows of the `Repetitions` table, cached in
/// memory on first read and written through on every [add].
///
/// Only original entries are SQLite-backed. The derived `computedEntries` list
/// — the one that carries YES_AUTO values — is a plain in-memory [EntryList],
/// which is why [recomputeFrom] throws here.
///
/// Kotlin's `IllegalStateException` becomes Dart's [StateError], and
/// `UnsupportedOperationException` becomes [UnsupportedError]; the `habitId!!`
/// in [clear] raises a [TypeError] where Kotlin raises a
/// `NullPointerException`.
class SQLiteEntryList extends EntryList {
  SQLiteEntryList(this.repository);

  /// Shared by every habit: one repository, one `Repetitions` table.
  final EntryRepository repository;

  /// Null until the owning habit has been saved and given an id.
  int? habitId;

  /// Public, as in Kotlin: `SQLModelFactory` and the habit list flip it back
  /// to false when a habit is reloaded from scratch.
  bool isLoaded = false;

  void _loadRecords() {
    if (isLoaded) return;
    final habitId = this.habitId;
    if (habitId == null) throw StateError('habitId must be set');
    final records = repository.findAllByHabitId(habitId);
    for (final rec in records) {
      super.add(
        Entry(
          LocalDate.fromUnixTime(rec.timestamp),
          rec.value,
          notes: rec.notes,
        ),
      );
    }
    isLoaded = true;
  }

  @override
  Entry get(LocalDate date) {
    _loadRecords();
    return super.get(date);
  }

  @override
  List<Entry> getByInterval(LocalDate from, LocalDate to) {
    _loadRecords();
    return super.getByInterval(from, to);
  }

  @override
  void add(Entry entry) {
    _loadRecords();
    final habitId = this.habitId;
    if (habitId == null) throw StateError('habitId must be set');

    repository.deleteByHabitIdAndTimestamp(habitId, entry.date.unixTime);

    final data = EntryData(
      habitId: habitId,
      timestamp: entry.date.unixTime,
      value: entry.value,
      notes: entry.notes,
    );
    repository.insert(data);

    super.add(entry);
  }

  @override
  List<Entry> getKnown() {
    _loadRecords();
    return super.getKnown();
  }

  @override
  void recomputeFrom(
    EntryList originalEntries,
    Frequency frequency, {
    required bool isNumerical,
  }) {
    throw UnsupportedError('');
  }

  @override
  void clear() {
    super.clear();
    repository.deleteByHabitId(habitId!);
  }
}
