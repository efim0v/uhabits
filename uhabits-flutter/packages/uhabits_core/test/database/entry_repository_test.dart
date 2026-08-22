/// Port of
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/EntryRepositoryTest.kt`,
/// extended to cover every rule of `persistence.entry-repository`.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/entry_repository.dart';
import 'package:uhabits_core/src/models/entry.dart';

import '../helpers/test_database.dart';

/// Kotlin: `EntryRepositoryTest.insertTestHabit`.
int insertTestHabit(Database db, {String name = 'Test'}) {
  db.run(
    "insert into Habits(name, freq_num, freq_den, color, position, archived, type) "
    "values ('$name', 1, 1, 0, 0, 0, 0)",
  );
  return db.queryLong('select last_insert_rowid()');
}

void main() {
  late Database db;
  late EntryRepository repo;

  setUp(() {
    // Kotlin: TestDatabaseHelper.createEmptyDatabase().
    db = openMigratedDatabase();
    repo = EntryRepository(db);
  });

  tearDown(() {
    db.close();
  });

  test('EntryData default values', () {
    final data = EntryData();
    expect(data.id, isNull,
        reason: 'persistence.entry-repository#1 — EntryData.id defaults to '
            'null');
    expect(data.habitId, isNull,
        reason: 'persistence.entry-repository#1 — EntryData.habitId defaults '
            'to null');
    expect(data.timestamp, 0,
        reason: 'persistence.entry-repository#1 — EntryData.timestamp '
            'defaults to 0L');
    expect(data.value, 0,
        reason: 'persistence.entry-repository#1 — EntryData.value defaults '
            'to 0');
    expect(data.notes, '',
        reason: 'persistence.entry-repository#1 — EntryData.notes defaults to '
            'the empty string');
  });

  test('findAllByHabitId returns newest first, with every column mapped', () {
    final habitId = insertTestHabit(db);

    expect(repo.findAllByHabitId(habitId), isEmpty,
        reason: 'persistence.entry-repository#4 — a habit with no rows yields '
            'an empty list');

    // Inserted out of chronological order, so row id order differs from
    // timestamp order and only ORDER BY timestamp DESC can produce the
    // expected sequence.
    final idMiddle =
        repo.insert(EntryData(habitId: habitId, timestamp: 1700100000000, value: 2, notes: 'good'));
    final idNewest =
        repo.insert(EntryData(habitId: habitId, timestamp: 1700200000000, value: 1));
    final idOldest =
        repo.insert(EntryData(habitId: habitId, timestamp: 1700000000000, value: 2));

    final all = repo.findAllByHabitId(habitId);
    expect(all.length, 3,
        reason: 'persistence.entry-repository#2 — every row of the habit is '
            'returned');
    expect([all[0].timestamp, all[1].timestamp, all[2].timestamp],
        [1700200000000, 1700100000000, 1700000000000],
        reason: 'persistence.entry-repository#2 — ORDER BY timestamp DESC: '
            'the newest entry is element 0 and the oldest is last');
    expect([all[0].id, all[1].id, all[2].id], [idNewest, idMiddle, idOldest],
        reason: 'persistence.entry-repository#2 — the order is by timestamp, '
            'not by id: the SELECT reads column 0 as id');
    expect(all.map((e) => e.habitId).toList(), [habitId, habitId, habitId],
        reason: 'persistence.entry-repository#2 — column 1 (habit) is read '
            'into habitId');
    expect([all[0].value, all[1].value, all[2].value], [1, 2, 2],
        reason: 'persistence.entry-repository#2 — column 3 (value) is read '
            'into value');
    expect([all[0].notes, all[1].notes, all[2].notes], ['', 'good', ''],
        reason: 'persistence.entry-repository#2 — column 4 (notes) is read '
            'into notes');
  });

  test('findAllByHabitId reads a NULL notes column as the empty string', () {
    final habitId = insertTestHabit(db);

    // Rows written without the notes column, the way every database migrated
    // from schema 24 looks (migration 25 adds `notes text`, filling NULL).
    repo.execSQL(
      'insert into Repetitions(habit, timestamp, value) '
      'values ($habitId, 1000, 2)',
    );
    repo.execSQL(
      'insert into Repetitions(habit, timestamp, value, notes) '
      'values ($habitId, 2000, 2, null)',
    );

    final all = repo.findAllByHabitId(habitId);
    expect(all.length, 2,
        reason: 'persistence.entry-repository#3 — rows with NULL notes are '
            'returned like any other');
    expect(all[0].notes, '',
        reason: 'persistence.entry-repository#3 — an explicit NULL notes '
            'column reads back as the empty string');
    expect(all[1].notes, '',
        reason: 'persistence.entry-repository#3 — a notes column left unset '
            'reads back as the empty string');
  });

  test('findAllByHabitId returns an empty list for habits with no rows', () {
    final habitA = insertTestHabit(db, name: 'A');
    final habitB = insertTestHabit(db, name: 'B');
    repo.insert(EntryData(habitId: habitA, timestamp: 1000, value: 2));

    expect(repo.findAllByHabitId(habitB), isEmpty,
        reason: 'persistence.entry-repository#4 — an existing habit with no '
            'rows returns an empty list without error');
    expect(repo.findAllByHabitId(9999), isEmpty,
        reason: 'persistence.entry-repository#4 — a non-existent habit id '
            'such as 9999 returns an empty list without error');
    expect(repo.findAllByHabitId(habitA).length, 1,
        reason: 'persistence.entry-repository#4 — the empty queries did not '
            'disturb the habit that does have rows');
  });

  test('insert generates the id, ignoring data.id, and requires habitId', () {
    final habitId = insertTestHabit(db);

    final id1 = repo.insert(
        EntryData(habitId: habitId, timestamp: 1000, value: 2, notes: 'a'));
    expect(id1, db.queryLong('select last_insert_rowid()'),
        reason: 'persistence.entry-repository#5 — insert returns '
            '`SELECT last_insert_rowid()`');
    expect(id1 > 0, isTrue,
        reason: 'persistence.entry-repository#5 — the generated id is a real '
            'rowid');

    final id2 = repo.insert(EntryData(habitId: habitId, timestamp: 2000, value: 2));
    expect(id2 > id1, isTrue,
        reason: 'persistence.entry-repository#5 — successive inserts return '
            'strictly increasing last_insert_rowid() values');

    // data.id is never bound: the INSERT lists only habit, timestamp, value
    // and notes.
    final withExplicitId =
        EntryData(id: 999, habitId: habitId, timestamp: 3000, value: 2);
    final id3 = repo.insert(withExplicitId);
    expect(id3, isNot(999),
        reason: 'persistence.entry-repository#5 — data.id is ignored; the id '
            'is always generated');
    expect(withExplicitId.id, 999,
        reason: 'persistence.entry-repository#5 — insert does not write the '
            'generated id back into data');
    final stored =
        repo.findAllByHabitId(habitId).firstWhere((e) => e.timestamp == 3000);
    expect(stored.id, id3,
        reason: 'persistence.entry-repository#5 — the stored row carries the '
            'generated id, not data.id');
    expect(stored.notes, '',
        reason: 'persistence.entry-repository#5 — the four bound columns are '
            'habit, timestamp, value and notes');
    expect(stored.value, 2,
        reason: 'persistence.entry-repository#5 — value is bound at '
            'parameter 3');
    expect(stored.habitId, habitId,
        reason: 'persistence.entry-repository#5 — habit is bound at '
            'parameter 1');

    expect(() => repo.insert(EntryData(timestamp: 4000, value: 2)),
        throwsA(isA<TypeError>()),
        reason: 'persistence.entry-repository#5 — data.habitId must be '
            'non-null or an NPE (Dart: null-check TypeError) is thrown');
  });

  test('deleteByHabitIdAndTimestamp removes only the matching row', () {
    final habitA = insertTestHabit(db, name: 'A');
    final habitB = insertTestHabit(db, name: 'B');

    repo.insert(EntryData(habitId: habitA, timestamp: 1000, value: 2));
    repo.insert(EntryData(habitId: habitA, timestamp: 2000, value: 2));
    repo.insert(EntryData(habitId: habitA, timestamp: 3000, value: 2));
    repo.insert(EntryData(habitId: habitB, timestamp: 2000, value: 2));

    repo.deleteByHabitIdAndTimestamp(habitA, 2000);

    final remaining = repo.findAllByHabitId(habitA);
    expect(remaining.length, 2,
        reason: 'persistence.entry-repository#6 — exactly one row is deleted');
    expect(remaining.any((e) => e.timestamp == 2000), isFalse,
        reason: 'persistence.entry-repository#6 — the row matching both habit '
            'and timestamp is gone');
    expect(repo.findAllByHabitId(habitB).single.timestamp, 2000,
        reason: 'persistence.entry-repository#6 — another habit sharing the '
            'timestamp is untouched, because habit = ? is part of the WHERE');

    repo.deleteByHabitIdAndTimestamp(habitA, 12345);
    expect(repo.findAllByHabitId(habitA).length, 2,
        reason: 'persistence.entry-repository#6 — deleting a timestamp that '
            'does not exist removes nothing and does not error');
  });

  test('deleteByHabitId leaves other habits untouched', () {
    final habitA = insertTestHabit(db, name: 'A');
    final habitB = insertTestHabit(db, name: 'B');

    repo.insert(EntryData(habitId: habitA, timestamp: 1000, value: 2));
    repo.insert(EntryData(habitId: habitA, timestamp: 2000, value: 2));
    repo.insert(EntryData(habitId: habitB, timestamp: 3000, value: 2));

    repo.deleteByHabitId(habitA);

    expect(repo.findAllByHabitId(habitA), isEmpty,
        reason: 'persistence.entry-repository#7 — every row of the habit is '
            'deleted');
    expect(repo.findAllByHabitId(habitB).length, 1,
        reason: "persistence.entry-repository#7 — another habit's entries are "
            'left untouched');

    repo.deleteByHabitId(9999);
    expect(repo.findAllByHabitId(habitB).length, 1,
        reason: 'persistence.entry-repository#7 — deleting a habit with no '
            'rows removes nothing and does not error');
  });

  test('entries are never filtered by value', () {
    final habitId = insertTestHabit(db);

    repo.insert(
        EntryData(habitId: habitId, timestamp: 1000, value: Entry.unknown));
    repo.insert(EntryData(habitId: habitId, timestamp: 2000, value: Entry.no));
    repo.insert(
        EntryData(habitId: habitId, timestamp: 3000, value: Entry.yesAuto));
    repo.insert(
        EntryData(habitId: habitId, timestamp: 4000, value: Entry.yesManual));
    repo.insert(
        EntryData(habitId: habitId, timestamp: 5000, value: Entry.skip));

    final all = repo.findAllByHabitId(habitId);
    expect(all.length, 5,
        reason: 'persistence.entry-repository#8 — the repository never '
            'filters by value');
    expect(all.map((e) => e.value).toList(),
        [Entry.skip, Entry.yesManual, Entry.yesAuto, Entry.no, Entry.unknown],
        reason: 'persistence.entry-repository#8 — UNKNOWN(-1) and NO(0) are '
            'stored and returned like any other value');

    repo.deleteByHabitIdAndTimestamp(habitId, 1000);
    expect(repo.findAllByHabitId(habitId).length, 4,
        reason: 'persistence.entry-repository#8 — an UNKNOWN(-1) row is '
            'deletable like any other row');
  });

  test('cached statements are reset before each use', () {
    final habitA = insertTestHabit(db, name: 'A');
    final habitB = insertTestHabit(db, name: 'B');

    // findAllByHabit: same statement, re-executed against current data.
    expect(repo.findAllByHabitId(habitA), isEmpty,
        reason: 'persistence.entry-repository#9 — the first call to the '
            'cached findAllByHabit statement sees no rows');
    repo.insert(EntryData(habitId: habitA, timestamp: 1000, value: 2));
    expect(repo.findAllByHabitId(habitA).length, 1,
        reason: 'persistence.entry-repository#9 — reset() before stepping '
            'makes a repeated call observe the row inserted in between');

    // insert: same statement, re-bound each time.
    repo.insert(EntryData(habitId: habitA, timestamp: 2000, value: 2, notes: 'x'));
    repo.insert(EntryData(habitId: habitB, timestamp: 3000, value: 1));
    expect(repo.findAllByHabitId(habitA).length, 2,
        reason: 'persistence.entry-repository#9 — the cached insert statement '
            'is re-bound on every call');
    expect(repo.findAllByHabitId(habitB).single.value, 1,
        reason: 'persistence.entry-repository#9 — the cached findAllByHabit '
            'statement is re-bound with the new habit id');

    // deleteByHabitAndTimestamp: same statement, twice.
    repo.deleteByHabitIdAndTimestamp(habitA, 1000);
    repo.deleteByHabitIdAndTimestamp(habitA, 2000);
    expect(repo.findAllByHabitId(habitA), isEmpty,
        reason: 'persistence.entry-repository#9 — repeated calls to the '
            'cached delete-by-habit-and-timestamp statement each execute');

    // deleteByHabit: same statement, twice.
    repo.insert(EntryData(habitId: habitA, timestamp: 4000, value: 2));
    repo.deleteByHabitId(habitA);
    repo.deleteByHabitId(habitB);
    expect(repo.findAllByHabitId(habitA), isEmpty,
        reason: 'persistence.entry-repository#9 — the cached delete-by-habit '
            'statement executes on its first call');
    expect(repo.findAllByHabitId(habitB), isEmpty,
        reason: 'persistence.entry-repository#9 — and again, re-bound, on its '
            'second call');
  });

  test('all fields survive a round trip', () {
    final habitId = insertTestHabit(db);

    final original = EntryData(
      habitId: habitId,
      timestamp: 1700000000000,
      value: 2,
      notes: 'Felt great today',
    );
    original.id = repo.insert(original);

    final loaded = repo.findAllByHabitId(habitId).single;
    expect(loaded.id, original.id,
        reason: 'persistence.entry-repository#2 — id round trips');
    expect(loaded.habitId, original.habitId,
        reason: 'persistence.entry-repository#2 — habitId round trips');
    expect(loaded.timestamp, original.timestamp,
        reason: 'persistence.entry-repository#2 — a millisecond timestamp '
            'round trips as a 64-bit integer');
    expect(loaded.value, original.value,
        reason: 'persistence.entry-repository#2 — value round trips');
    expect(loaded.notes, original.notes,
        reason: 'persistence.entry-repository#3 — a non-empty notes string '
            'round trips unchanged');
  });
}
