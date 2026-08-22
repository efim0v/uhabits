/// Implementation of a [HabitList] that is backed by SQLite.
///
/// Ported line by line from
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`.
library;

import '../../database/habit_repository.dart';
import '../frequency.dart';
import '../habit.dart';
import '../habit_list.dart';
import '../habit_matcher.dart';
import '../habit_type.dart';
import '../memory/memory_habit_list.dart';
import '../model_factory.dart';
import '../palette_color.dart';
import '../reminder.dart';
import '../weekday_list.dart';
import 'sql_model_factory.dart';
import 'sqlite_entry_list.dart';

/// A [HabitList] whose rows live in the `Habits` table.
///
/// Every in-memory behavior — ordering, filtering, lookup — is delegated to an
/// internal [MemoryHabitList]. This class only adds two things: a lazy load
/// that fills that list from SQLite exactly once, and a write-through on every
/// mutation.
///
/// The cache is never invalidated: the app is assumed to be the only writer of
/// the database file, so a row changed behind this object's back stays
/// invisible until [reload] is called.
///
/// Kotlin annotates every public member `@Synchronized` (and the order setters
/// `@set:Synchronized`), so the whole list is guarded by one monitor. A Dart
/// isolate is single threaded and every method here is synchronous, so there is
/// no lock to port: a method always runs to completion before anything else
/// observes the list, and the re-entrant calls a listener makes see the final
/// state, exactly as a reentrant JVM monitor would give them.
class SQLiteHabitList extends HabitList {
  SQLiteHabitList(this.modelFactory)
      : repository = (modelFactory as SQLModelFactory).habitRepository;

  /// Kotlin declares this as `ModelFactory` and immediately casts it to
  /// `SQLModelFactory` to reach the repository, so passing any other
  /// implementation throws — `ClassCastException` there, [TypeError] here.
  final ModelFactory modelFactory;

  final HabitRepository repository;

  final MemoryHabitList _list = MemoryHabitList();

  bool _loaded = false;

  /// Fills the in-memory list from the database, at most once.
  ///
  /// `loaded` is set BEFORE the read, so a re-entrant call made while the rows
  /// are being fetched returns the partially built list instead of recursing.
  void _loadRecords() {
    if (_loaded) return;
    _loaded = true;
    _list.removeAll();
    final records = repository.findAll();
    var shouldRebuildOrder = false;
    for (var expectedPosition = 0;
        expectedPosition < records.length;
        expectedPosition++) {
      final rec = records[expectedPosition];
      if (rec.position != expectedPosition) shouldRebuildOrder = true;
      final h = modelFactory.buildHabit();
      copyTo(rec, h);
      (h.originalEntries as SQLiteEntryList).habitId = h.id;
      _list.add(h);
    }
    if (shouldRebuildOrder) _rebuildOrder();
  }

  /// Renumbers the stored positions to 0..n-1, in the order `findAll()`
  /// returns them. Rows that already sit at the right position are not
  /// rewritten. The in-memory habits are deliberately left alone, exactly as
  /// upstream: they keep the stale position until the next load.
  void _rebuildOrder() {
    final records = repository.findAll();
    for (var pos = 0; pos < records.length; pos++) {
      final r = records[pos];
      if (r.position != pos) {
        r.position = pos;
        repository.update(r);
      }
    }
  }

  @override
  void add(Habit habit) {
    _loadRecords();
    // Kotlin: `require(list.indexOf(habit) < 0) { "habit already added" }`.
    final existing = _list.indexOf(habit);
    if (existing >= 0) throw ArgumentError('habit already added');
    habit.position = size();
    final data = copyFrom(habit);
    final id = repository.insert(data);
    habit.id = id;
    (habit.originalEntries as SQLiteEntryList).habitId = id;
    _list.add(habit);
    observable.notifyListeners();
  }

  @override
  Habit? getById(int id) {
    _loadRecords();
    return _list.getById(id);
  }

  @override
  Habit? getByUUID(String? uuid) {
    _loadRecords();
    return _list.getByUUID(uuid);
  }

  @override
  Habit getByPosition(int position) {
    _loadRecords();
    return _list.getByPosition(position);
  }

  @override
  HabitList getFiltered(HabitMatcher? matcher) {
    _loadRecords();
    return _list.getFiltered(matcher);
  }

  @override
  HabitListOrder get primaryOrder => _list.primaryOrder;

  @override
  set primaryOrder(HabitListOrder order) {
    _list.primaryOrder = order;
    observable.notifyListeners();
  }

  @override
  HabitListOrder get secondaryOrder => _list.secondaryOrder;

  @override
  set secondaryOrder(HabitListOrder order) {
    _list.secondaryOrder = order;
    observable.notifyListeners();
  }

  @override
  int indexOf(Habit h) {
    _loadRecords();
    return _list.indexOf(h);
  }

  @override
  Iterator<Habit> get iterator {
    _loadRecords();
    return _list.iterator;
  }

  @override
  void remove(Habit h) {
    _loadRecords();
    _list.remove(h);
    h.originalEntries.clear();
    repository.delete(h.id!);
    _rebuildOrder();
    observable.notifyListeners();
  }

  /// Wipes both tables. Unlike every other member, it does not load first: the
  /// in-memory list is simply emptied and the rows are deleted in bulk. The
  /// `sqlite_sequence` row is left alone, so ids keep climbing.
  ///
  /// The two statements are issued parent-first, which only works while foreign
  /// key enforcement is off: `Repetitions.habit references habits(id)`, so with
  /// `pragma foreign_keys=ON` — the state migration 22 leaves a connection in —
  /// `delete from habits` raises as soon as any repetition exists, and the
  /// second statement never runs. Ported as is; upstream survives it because
  /// the Android app connection keeps enforcement off.
  @override
  void removeAll() {
    _list.removeAll();
    repository.execSQL('delete from habits');
    repository.execSQL('delete from repetitions');
    observable.notifyListeners();
  }

  @override
  void reorder(Habit from, Habit to) {
    _loadRecords();
    final fromPos = from.position;
    final toPos = to.position;
    _list.reorder(from, to);
    if (toPos < fromPos) {
      repository.execSQL('update habits set position = position + 1 '
          'where position >= $toPos and position < $fromPos');
    } else {
      repository.execSQL('update habits set position = position - 1 '
          'where position > $fromPos and position <= $toPos');
    }
    final data = copyFrom(from);
    data.position = toPos;
    repository.update(data);
    observable.notifyListeners();
  }

  @override
  void repair() {
    _loadRecords();
    _rebuildOrder();
    observable.notifyListeners();
  }

  @override
  int size() {
    _loadRecords();
    return _list.size();
  }

  @override
  void update(List<Habit> habits) {
    _loadRecords();
    _list.update(habits);
    for (final h in habits) {
      final data = copyFrom(h);
      repository.update(data);
    }
    observable.notifyListeners();
  }

  @override
  void resort() {
    _list.resort();
    observable.notifyListeners();
  }

  /// Marks the cache stale. The in-memory list is left as it is; the next read
  /// re-queries the database and rebuilds it from scratch.
  ///
  /// Nothing in the app calls this — it exists for tooling that writes to the
  /// database behind the list's back.
  void reload() {
    _loaded = false;
  }

  /// Maps a habit onto the row that stores it.
  ///
  /// `highlight` is always written as 0: the column survives from an old
  /// version of the app and is never read back into the model. A habit with no
  /// reminder stores NULL hour, NULL minute and a day mask of 0.
  static HabitData copyFrom(Habit habit) {
    final numerator = habit.frequency.numerator;
    final denominator = habit.frequency.denominator;
    return HabitData(
      id: habit.id,
      name: habit.name,
      description: habit.description,
      question: habit.question,
      freqNum: numerator,
      freqDen: denominator,
      color: habit.color.paletteIndex,
      position: habit.position,
      reminderHour: habit.reminder?.hour,
      reminderMin: habit.reminder?.minute,
      reminderDays: habit.reminder?.days.toInteger() ?? 0,
      highlight: 0,
      archived: habit.isArchived ? 1 : 0,
      type: habit.type.value,
      targetValue: habit.targetValue,
      targetType: habit.targetType.value,
      unit: habit.unit,
      uuid: habit.uuid,
    );
  }

  /// Maps a row onto the habit that reads it.
  ///
  /// A [Reminder] is created only when BOTH `reminder_hour` and `reminder_min`
  /// are non-NULL; when either is missing the habit keeps whatever reminder it
  /// already had (none, for a freshly built habit) and `reminder_days` is
  /// ignored.
  static void copyTo(HabitData data, Habit habit) {
    habit.id = data.id;
    habit.name = data.name;
    habit.description = data.description;
    habit.question = data.question;
    habit.frequency = Frequency(data.freqNum, data.freqDen);
    habit.color = PaletteColor(data.color);
    habit.isArchived = data.archived != 0;
    habit.type = HabitType.fromInt(data.type);
    habit.targetType = NumericalHabitType.fromInt(data.targetType);
    habit.targetValue = data.targetValue;
    habit.unit = data.unit;
    habit.position = data.position;
    habit.uuid = data.uuid;
    if (data.reminderHour != null && data.reminderMin != null) {
      habit.reminder = Reminder(
        data.reminderHour!,
        data.reminderMin!,
        WeekdayList(data.reminderDays),
      );
    }
  }
}
