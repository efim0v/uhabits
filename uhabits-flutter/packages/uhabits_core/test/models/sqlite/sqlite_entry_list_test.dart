/// Port of
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteEntryListTest.kt`,
/// extended to cover every rule of `persistence.sqlite-entry-list`, plus the
/// two rules of neighbouring features that describe this class:
/// `persistence.schema-repetitions#8` and `models.entry-list-recompute#7`.
///
/// The Kotlin test builds the list through `SQLModelFactory`; here the list is
/// wired by hand (repository + habitId) so the slice stays independent of the
/// factory.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/entry_repository.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_entry_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../../helpers/test_database.dart';

/// Inserts a bare Habits row so that the `habit` foreign key of Repetitions
/// resolves (migration 22 turns `pragma foreign_keys` ON).
int insertTestHabit(Database db, {String name = 'Test'}) {
  db.run(
    "insert into Habits(name, freq_num, freq_den, color, position, archived, type) "
    "values ('$name', 1, 1, 0, 0, 0, 0)",
  );
  return db.queryLong('select last_insert_rowid()');
}

/// Counts every row belonging to [habitId].
int countRows(Database db, int habitId) =>
    db.queryInt('select count(*) from Repetitions where habit = $habitId');

/// An [EntryRepository] that records how often — and in which state — the list
/// asks it to load.
class SpyEntryRepository extends EntryRepository {
  SpyEntryRepository(super.db);

  /// The list under observation; read back during [findAllByHabitId].
  SQLiteEntryList? watched;

  int findCount = 0;
  final List<bool> isLoadedDuringFind = <bool>[];

  @override
  List<EntryData> findAllByHabitId(int habitId) {
    findCount++;
    isLoadedDuringFind.add(watched!.isLoaded);
    return super.findAllByHabitId(habitId);
  }
}

Matcher throwsHabitIdMustBeSet() => throwsA(
      isA<StateError>()
          .having((e) => e.message, 'message', 'habitId must be set'),
    );

void main() {
  late Database db;
  late EntryRepository repo;
  late int habitId;
  late SQLiteEntryList entries;

  // Kotlin: `private val today = LocalDate(2015, 1, 25)`.
  final today = LocalDate.ymd(2015, 1, 25);

  setUp(() {
    db = openMigratedDatabase();
    repo = EntryRepository(db);
    habitId = insertTestHabit(db);
    entries = SQLiteEntryList(repo)..habitId = habitId;
  });

  tearDown(() {
    db.close();
  });

  test('extends EntryList, exposes habitId / isLoaded, shares one repository',
      () {
    final fresh = SQLiteEntryList(repo);

    expect(fresh, isA<EntryList>(),
        reason: 'persistence.sqlite-entry-list#1 — SQLiteEntryList extends '
            'EntryList');
    expect(fresh.habitId, isNull,
        reason: 'persistence.sqlite-entry-list#1 — habitId is nullable and '
            'starts out null');
    expect(fresh.isLoaded, isFalse,
        reason: 'persistence.sqlite-entry-list#1 — isLoaded is a public flag '
            'that starts out false');
    expect(identical(fresh.repository, repo), isTrue,
        reason: 'persistence.sqlite-entry-list#1 — the list wraps the '
            'EntryRepository it was given');

    // A single repository is shared across all habits: two lists built on the
    // same repository each see only their own habit's rows.
    final otherHabitId = insertTestHabit(db, name: 'Other');
    final other = SQLiteEntryList(repo)..habitId = otherHabitId;
    expect(identical(other.repository, entries.repository), isTrue,
        reason: 'persistence.sqlite-entry-list#1 — a single EntryRepository is '
            'shared across all habits');

    entries.add(Entry(today, Entry.yesManual));
    other.add(Entry(today, Entry.skip));

    expect(entries.get(today).value, Entry.yesManual,
        reason: 'persistence.sqlite-entry-list#1 — each list reads only the '
            'rows of its own habitId');
    expect(other.get(today).value, Entry.skip,
        reason: 'persistence.sqlite-entry-list#1 — each list reads only the '
            'rows of its own habitId');
  });

  test('every operation throws IllegalStateException while habitId is null',
      () {
    SQLiteEntryList orphan() => SQLiteEntryList(repo);

    expect(() => orphan().get(today), throwsHabitIdMustBeSet(),
        reason: 'persistence.sqlite-entry-list#2 — get() while habitId is null '
            'throws IllegalStateException("habitId must be set")');
    expect(() => orphan().getByInterval(today.minus(5), today),
        throwsHabitIdMustBeSet(),
        reason: 'persistence.sqlite-entry-list#2 — getByInterval() while '
            'habitId is null throws IllegalStateException("habitId must be '
            'set")');
    expect(() => orphan().getKnown(), throwsHabitIdMustBeSet(),
        reason: 'persistence.sqlite-entry-list#2 — getKnown() while habitId is '
            'null throws IllegalStateException("habitId must be set")');
    expect(() => orphan().add(Entry(today, Entry.yesManual)),
        throwsHabitIdMustBeSet(),
        reason: 'persistence.sqlite-entry-list#2 — add() while habitId is null '
            'throws IllegalStateException("habitId must be set")');
    expect(() => orphan().add(Entry(today, Entry.yesManual)),
        throwsHabitIdMustBeSet(),
        reason: 'persistence.sqlite-entry-list#12 — loadRecords throws '
            'IllegalStateException("habitId must be set") when habitId is '
            'null');
  });

  test('loadRecords runs at most once and flips isLoaded after the loop', () {
    final spy = SpyEntryRepository(db);
    final list = SQLiteEntryList(spy)..habitId = habitId;
    spy.watched = list;

    repo.insert(
      EntryData(habitId: habitId, timestamp: today.unixTime, value: 500),
    );
    repo.insert(
      EntryData(
        habitId: habitId,
        timestamp: today.minus(5).unixTime,
        value: 300,
      ),
    );

    expect(list.isLoaded, isFalse,
        reason: 'persistence.sqlite-entry-list#3 — isLoaded is false until the '
            'first operation loads the records');

    expect(list.get(today).value, 500,
        reason: 'persistence.sqlite-entry-list#3 — loadRecords() calls '
            'repository.findAllByHabitId(habitId) and adds each record');
    expect(spy.findCount, 1,
        reason: 'persistence.sqlite-entry-list#3 — loadRecords() queries the '
            'repository once');
    expect(spy.isLoadedDuringFind, [false],
        reason: 'persistence.sqlite-entry-list#3 — isLoaded is set AFTER the '
            'loop, so it is still false while the records are being read '
            '(unlike SQLiteHabitList, which sets its flag before loading)');
    expect(list.isLoaded, isTrue,
        reason: 'persistence.sqlite-entry-list#3 — isLoaded is true once '
            'loadRecords() has finished');

    // A row inserted behind the list's back is never picked up: loadRecords
    // runs at most once.
    repo.insert(
      EntryData(
        habitId: habitId,
        timestamp: today.minus(9).unixTime,
        value: 700,
      ),
    );
    list.get(today);
    list.getByInterval(today.minus(20), today);
    list.getKnown();
    list.add(Entry(today.minus(2), Entry.yesManual));

    expect(spy.findCount, 1,
        reason: 'persistence.sqlite-entry-list#12 — isLoaded guards re-entry: '
            'every row is loaded exactly once');
    expect(list.get(today.minus(9)).value, Entry.unknown,
        reason: 'persistence.sqlite-entry-list#3 — loadRecords() runs at most '
            'once, so later rows are not reloaded');
  });

  test('get / getByInterval / getKnown / add each call loadRecords first', () {
    repo.insert(
      EntryData(habitId: habitId, timestamp: today.unixTime, value: 500),
    );

    final byGet = SQLiteEntryList(repo)..habitId = habitId;
    expect(byGet.get(today).value, 500,
        reason: 'persistence.sqlite-entry-list#4 — get(date) calls '
            'loadRecords() first');
    expect(byGet.isLoaded, isTrue,
        reason: 'persistence.sqlite-entry-list#4 — get(date) calls '
            'loadRecords() first');

    final byInterval = SQLiteEntryList(repo)..habitId = habitId;
    expect(byInterval.getByInterval(today, today).single.value, 500,
        reason: 'persistence.sqlite-entry-list#4 — getByInterval(from, to) '
            'calls loadRecords() first');
    expect(byInterval.isLoaded, isTrue,
        reason: 'persistence.sqlite-entry-list#4 — getByInterval(from, to) '
            'calls loadRecords() first');

    final byKnown = SQLiteEntryList(repo)..habitId = habitId;
    expect(byKnown.getKnown().single.value, 500,
        reason: 'persistence.sqlite-entry-list#4 — getKnown() calls '
            'loadRecords() first');
    expect(byKnown.isLoaded, isTrue,
        reason: 'persistence.sqlite-entry-list#4 — getKnown() calls '
            'loadRecords() first');

    final byAdd = SQLiteEntryList(repo)..habitId = habitId;
    byAdd.add(Entry(today.minus(3), Entry.yesManual));
    expect(byAdd.isLoaded, isTrue,
        reason: 'persistence.sqlite-entry-list#4 — add(entry) calls '
            'loadRecords() first');
    expect(byAdd.get(today).value, 500,
        reason: 'persistence.sqlite-entry-list#4 — add(entry) loads the '
            'pre-existing rows before writing');
    expect(byAdd.getKnown().length, 2,
        reason: 'persistence.sqlite-entry-list#12 — any of get / getByInterval '
            '/ add / getKnown triggers loadRecords() first');
  });

  test('testLoad: stored rows are visible, missing dates read UNKNOWN', () {
    // Kotlin: SQLiteEntryListTest.testLoad.
    repo.insert(
      EntryData(habitId: habitId, timestamp: today.unixTime, value: 500),
    );
    repo.insert(
      EntryData(
        habitId: habitId,
        timestamp: today.minus(5).unixTime,
        value: 300,
      ),
    );

    expect(entries.get(today), Entry(today, 500),
        reason: 'persistence.sqlite-entry-list#13 — each DB row becomes '
            'Entry(LocalDate.fromUnixTime(rec.timestamp), rec.value, '
            'rec.notes)');
    expect(entries.get(today.minus(1)), Entry(today.minus(1), Entry.unknown),
        reason: 'persistence.sqlite-entry-list#5 — get(date) for a date with '
            'no stored row returns Entry(date, UNKNOWN = -1, notes = "")');
    expect(entries.get(today.minus(1)).notes, '',
        reason: 'persistence.sqlite-entry-list#5 — the synthesized entry '
            'carries empty notes');
    expect(entries.get(today.minus(5)), Entry(today.minus(5), 300),
        reason: 'persistence.sqlite-entry-list#13 — each DB row becomes '
            'Entry(LocalDate.fromUnixTime(rec.timestamp), rec.value, '
            'rec.notes)');
  });

  test('rows map to Entry(fromUnixTime(timestamp), value, notes)', () {
    // A pre-2000 date exercises the flooring branch of fromUnixTime, and a
    // NULL notes column (every row written before schema 25) reads back as "".
    final old = LocalDate.ymd(1999, 12, 25);
    repo.insert(
      EntryData(
        habitId: habitId,
        timestamp: old.unixTime,
        value: Entry.yesManual,
        notes: 'hello',
      ),
    );
    db.run(
      'insert into Repetitions(habit, timestamp, value) '
      'values ($habitId, ${today.unixTime}, ${Entry.skip})',
    );

    expect(entries.get(old), Entry(old, Entry.yesManual, notes: 'hello'),
        reason: 'persistence.sqlite-entry-list#13 — Entry('
            'LocalDate.fromUnixTime(rec.timestamp), rec.value, rec.notes)');
    expect(entries.get(today), Entry(today, Entry.skip),
        reason: 'persistence.sqlite-entry-list#13 — a NULL notes column maps '
            'to the empty string');
  });

  test('add performs delete-then-insert, keeping one row per date', () {
    entries.add(Entry(today, Entry.yesManual, notes: 'first'));

    expect(countRows(db, habitId), 1,
        reason: 'persistence.sqlite-entry-list#6 — add(entry) inserts '
            'EntryData(habitId, entry.date.unixTime, entry.value, '
            'entry.notes)');

    entries.add(Entry(today, Entry.skip, notes: 'second'));

    expect(countRows(db, habitId), 1,
        reason: 'persistence.sqlite-entry-list#6 — add() first calls '
            'repository.deleteByHabitIdAndTimestamp, so a second entry for '
            'the same date leaves exactly one row');

    final stored = repo.findAllByHabitId(habitId).single;
    expect(stored.value, Entry.skip,
        reason: 'persistence.sqlite-entry-list#6 — the surviving row holds the '
            'newest value');
    expect(stored.notes, 'second',
        reason: 'persistence.sqlite-entry-list#6 — the surviving row holds the '
            'newest notes');
    expect(stored.habitId, habitId,
        reason: 'persistence.sqlite-entry-list#6 — the row is written with the '
            "list's habitId");
    expect(stored.timestamp, today.unixTime,
        reason: 'persistence.sqlite-entry-list#6 — the row is written with '
            'entry.date.unixTime');
    expect(entries.get(today), Entry(today, Entry.skip, notes: 'second'),
        reason: 'persistence.sqlite-entry-list#6 — add() also calls super.add, '
            'so the in-memory map is updated');

    // Other dates are untouched by the delete-then-insert.
    entries.add(Entry(today.minus(1), Entry.yesManual));
    expect(countRows(db, habitId), 2,
        reason: 'persistence.sqlite-entry-list#6 — only the row with the same '
            'timestamp is deleted before inserting');
  });

  test('testAdd: 150 then 90 leaves exactly one row with value 90', () {
    // Kotlin: SQLiteEntryListTest.testAdd.
    expect(repo.findAllByHabitId(habitId), isEmpty,
        reason: 'persistence.sqlite-entry-list#7 — no rows before the first '
            'add');

    entries.add(Entry(today, 150));

    final all = repo.findAllByHabitId(habitId);
    expect(all.length, 1,
        reason: 'persistence.sqlite-entry-list#7 — add(Entry(date, 150)) '
            'writes one row');
    expect(all[0].value, 150,
        reason: 'persistence.sqlite-entry-list#7 — the row holds value 150');
    expect(all[0].timestamp, today.unixTime,
        reason: 'persistence.sqlite-entry-list#7 — the row holds '
            'date.unixTime');

    entries.add(Entry(today, 90));

    final all2 = repo.findAllByHabitId(habitId);
    expect(all2.length, 1,
        reason: 'persistence.sqlite-entry-list#7 — add(Entry(date, 90)) leaves '
            'exactly 1 row for that habit');
    expect(all2[0].value, 90,
        reason: 'persistence.sqlite-entry-list#7 — the surviving row has '
            'value 90');
  });

  test('clear empties the in-memory map and deletes every row', () {
    entries.add(Entry(today, Entry.yesManual));
    entries.add(Entry(today.minus(1), Entry.yesManual));
    final otherHabitId = insertTestHabit(db, name: 'Other');
    final other = SQLiteEntryList(repo)..habitId = otherHabitId;
    other.add(Entry(today, Entry.yesManual));

    entries.clear();

    expect(countRows(db, habitId), 0,
        reason: 'persistence.sqlite-entry-list#8 — clear() calls '
            'repository.deleteByHabitId(habitId!!)');
    expect(countRows(db, otherHabitId), 1,
        reason: 'persistence.sqlite-entry-list#8 — clear() only deletes rows '
            "of this list's habit");
    expect(entries.get(today), Entry(today, Entry.unknown),
        reason: 'persistence.sqlite-entry-list#8 — clear() calls super.clear(), '
            'emptying the in-memory map');
    expect(entries.isLoaded, isTrue,
        reason: 'persistence.sqlite-entry-list#8 — clear() does NOT reset '
            'isLoaded');

    // Because isLoaded stays true, a row inserted afterwards is never loaded.
    repo.insert(
      EntryData(habitId: habitId, timestamp: today.unixTime, value: 300),
    );
    expect(entries.getKnown(), isEmpty,
        reason: 'persistence.sqlite-entry-list#8 — isLoaded is not reset, so '
            'the list never reloads after clear()');
  });

  test('clear throws when habitId is null', () {
    // Kotlin: `repository.deleteByHabitId(habitId!!)` raises a
    // NullPointerException; Dart's `!` raises a TypeError.
    expect(() => SQLiteEntryList(repo).clear(), throwsA(isA<TypeError>()),
        reason: 'persistence.sqlite-entry-list#8 — clear() throws NPE if '
            'habitId is null');
  });

  test('recomputeFrom always throws UnsupportedOperationException', () {
    final original = EntryList()..add(Entry(today, Entry.yesManual));

    expect(
      () => entries.recomputeFrom(original, Frequency(1, 3),
          isNumerical: false),
      throwsA(isA<UnsupportedError>()),
      reason: 'persistence.sqlite-entry-list#9 — recomputeFrom always throws '
          'UnsupportedOperationException',
    );
    expect(
      () => entries.recomputeFrom(original, Frequency.daily,
          isNumerical: true),
      throwsA(isA<UnsupportedError>()),
      reason: 'models.entry-list-recompute#7 — SQLiteEntryList.recomputeFrom '
          'throws UnsupportedOperationException',
    );
    expect(
      () => entries.recomputeFrom(EntryList(), Frequency(1, 3),
          isNumerical: false),
      throwsA(isA<UnsupportedError>()),
      reason: 'models.entry-list-recompute#7 — only the in-memory '
          'computedEntries list is ever recomputed',
    );

    // Nothing is written or cleared on the way to the exception.
    entries.add(Entry(today, Entry.yesManual));
    expect(
      () => entries.recomputeFrom(original, Frequency(1, 3),
          isNumerical: false),
      throwsA(isA<UnsupportedError>()),
      reason: 'persistence.sqlite-entry-list#9 — recomputeFrom throws even '
          'once the list is loaded',
    );
    expect(countRows(db, habitId), 1,
        reason: 'persistence.sqlite-entry-list#9 — recomputeFrom leaves the '
            'database untouched');
    expect(entries.get(today).value, Entry.yesManual,
        reason: 'persistence.sqlite-entry-list#9 — recomputeFrom leaves the '
            'in-memory map untouched');
  });

  test('only originalEntries are persisted; computedEntries stay in memory',
      () {
    // The habit is checked on three days; with Frequency(1, 3) the computed
    // list gains YES_AUTO days around them. None of those derived days may
    // reach the Repetitions table.
    for (final offset in [4, 9, 10]) {
      entries.add(Entry(today.minus(offset), Entry.yesManual));
    }

    final computed = EntryList()
      ..recomputeFrom(entries, Frequency(1, 3), isNumerical: false);

    expect(
      computed.getKnown().where((e) => e.value == Entry.yesAuto).length,
      greaterThan(0),
      reason: 'persistence.schema-repetitions#8 — computedEntries carry the '
          'derived YES_AUTO values',
    );
    expect(countRows(db, habitId), 3,
        reason: 'persistence.schema-repetitions#8 — only the habit\'s '
            'originalEntries are persisted');
    expect(
      db.queryInt(
        'select count(*) from Repetitions '
        'where habit = $habitId and value = ${Entry.yesAuto}',
      ),
      0,
      reason: 'persistence.schema-repetitions#8 — computedEntries live in '
          'memory only and are never written to Repetitions',
    );
    expect(
      repo.findAllByHabitId(habitId).map((r) => r.value).toSet(),
      {Entry.yesManual},
      reason: 'persistence.schema-repetitions#8 — the stored rows are exactly '
          'the manual checkmarks',
    );
  });

  test('the persisted timestamp is UTC midnight, time-zone independent', () {
    final date = LocalDate.ymd(2015, 1, 25);
    entries.add(Entry(date, Entry.yesManual));

    final expected =
        946684800000 + date.daysSince2000 * 86400000;
    expect(
      db.queryLong('select timestamp from Repetitions where habit = $habitId'),
      expected,
      reason: 'persistence.sqlite-entry-list#10 — the timestamp written is '
          'LocalDate.unixTime = 946684800000 + daysSince2000 * 86400000',
    );
    expect(expected % 86400000, 0,
        reason: 'persistence.sqlite-entry-list#10 — the timestamp is UTC '
            'midnight, independent of the device time zone');

    // Round-trips through a fresh list unchanged.
    final reloaded = SQLiteEntryList(repo)..habitId = habitId;
    expect(reloaded.get(date).value, Entry.yesManual,
        reason: 'persistence.sqlite-entry-list#10 — the UTC-midnight timestamp '
            'maps back to the same date');
  });

  test('getKnown returns every loaded entry, newest first', () {
    for (final offset in [0, 5, 1, 9]) {
      repo.insert(
        EntryData(
          habitId: habitId,
          timestamp: today.minus(offset).unixTime,
          value: 100 + offset,
        ),
      );
    }
    entries.add(Entry(today.minus(3), Entry.yesManual));

    expect(
      entries.getKnown().map((e) => e.date).toList(),
      [
        today,
        today.minus(1),
        today.minus(3),
        today.minus(5),
        today.minus(9),
      ],
      reason: 'persistence.sqlite-entry-list#11 — getKnown() returns all '
          'loaded entries sorted newest-first (inherited EntryList behavior)',
    );
    expect(entries.getKnown().length, 5,
        reason: 'persistence.sqlite-entry-list#11 — getKnown() returns all '
            'loaded entries');
  });
}
