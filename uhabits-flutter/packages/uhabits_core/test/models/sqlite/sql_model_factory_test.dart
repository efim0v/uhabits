/// Covers `persistence.model-factory` against
/// `lib/src/models/sqlite/sql_model_factory.dart`, the port of
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLModelFactory.kt`.
///
/// The Kotlin side has no dedicated test for the factory — `SQLiteEntryListTest`
/// builds its list through it — so every assertion here comes from the ledger.
///
/// `persistence.model-factory#7` describes the Dagger graph in
/// `uhabits-android/.../inject/HabitsApplicationComponent.kt`; there is no DI
/// container in this package, so it stays uncited.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/entry_repository.dart';
import 'package:uhabits_core/src/database/habit_repository.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_entry_list.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../../helpers/test_database.dart';

void main() {
  late Database db;
  late SQLModelFactory factory;

  setUp(() {
    db = openMigratedDatabase();
    factory = SQLModelFactory(db);
  });

  tearDown(() => db.close());

  group('persistence.model-factory', () {
    test('#1 one database, one habit repository, one entry repository', () {
      expect(factory.database, same(db),
          reason: 'persistence.model-factory#1 — SQLModelFactory takes exactly '
              'one Database');
      expect(factory.habitRepository, isA<HabitRepository>(),
          reason: 'persistence.model-factory#1 — it constructs one '
              'HabitRepository');
      expect(factory.entryRepository, isA<EntryRepository>(),
          reason: 'persistence.model-factory#1 — it constructs one '
              'EntryRepository');
      expect(factory.habitRepository.db, same(db),
          reason: 'persistence.model-factory#1 — the habit repository is built '
              'over the factory database');
      expect(factory.entryRepository.db, same(db),
          reason: 'persistence.model-factory#1 — the entry repository is built '
              'over the same Database');

      // Both fields are `final` and initialized in the constructor, so reading
      // them twice can never produce a second repository.
      expect(factory.habitRepository, same(factory.habitRepository),
          reason: 'persistence.model-factory#1 — habitRepository is the same '
              'instance on every read');
      expect(factory.entryRepository, same(factory.entryRepository),
          reason: 'persistence.model-factory#1 — entryRepository is the same '
              'instance on every read');

      // "both shared by everything it builds": two independently built entry
      // lists and a habit list all reach the very same pair.
      final entriesA = factory.buildOriginalEntries() as SQLiteEntryList;
      final entriesB = factory.buildOriginalEntries() as SQLiteEntryList;
      expect(entriesA.repository, same(factory.entryRepository),
          reason: 'persistence.model-factory#1 — every SQLiteEntryList shares '
              'the one EntryRepository');
      expect(entriesB.repository, same(entriesA.repository),
          reason: 'persistence.model-factory#1 — and so does the next one');
      expect(factory.buildHabitList().repository, same(factory.habitRepository),
          reason: 'persistence.model-factory#1 — every SQLiteHabitList shares '
              'the one HabitRepository');
      expect(factory.buildHabit().originalEntries,
          isA<SQLiteEntryList>().having(
              (l) => l.repository, 'repository', same(factory.entryRepository)),
          reason: 'persistence.model-factory#1 — the entries of a habit built '
              'by the factory write through the shared repository');

      // One repository over one database really is one table: a row written
      // through a habit built by the factory is read back by an unrelated
      // entry list of the same factory.
      final habitId = factory.habitRepository.insert(HabitData(name: 'Run'));
      entriesA.habitId = habitId;
      entriesA.add(Entry(LocalDate.ymd(2020, 1, 1), Entry.yesManual));
      entriesB.habitId = habitId;
      expect(entriesB.get(LocalDate.ymd(2020, 1, 1)).value, Entry.yesManual,
          reason: 'persistence.model-factory#1 — the two lists see the same '
              'Repetitions table because they share the repository');
    });

    test('#2 buildOriginalEntries returns a fresh SQLiteEntryList, habitId null',
        () {
      final entries = factory.buildOriginalEntries();
      expect(entries, isA<SQLiteEntryList>(),
          reason: 'persistence.model-factory#2 — buildOriginalEntries returns '
              'a SQLiteEntryList');
      expect((entries as SQLiteEntryList).repository,
          same(factory.entryRepository),
          reason: 'persistence.model-factory#2 — it is constructed with the '
              'factory entryRepository');
      expect(entries.habitId, isNull,
          reason: 'persistence.model-factory#2 — habitId is still null: the '
              'habit list sets it once the row has an id');
      expect(entries.isLoaded, isFalse,
          reason: 'persistence.model-factory#2 — a brand new list has not '
              'loaded anything yet');
      expect(factory.buildOriginalEntries(), isNot(same(entries)),
          reason: 'persistence.model-factory#2 — a NEW list on every call');
    });

    test('#3 buildComputedEntries returns a plain in-memory EntryList', () {
      final computed = factory.buildComputedEntries();
      expect(computed, isA<EntryList>(),
          reason: 'persistence.model-factory#3 — buildComputedEntries returns '
              'an EntryList');
      expect(computed, isNot(isA<SQLiteEntryList>()),
          reason: 'persistence.model-factory#3 — it is NOT SQLite-backed: '
              'computed entries are never persisted');
      expect(computed.runtimeType, EntryList,
          reason: 'persistence.model-factory#3 — a plain EntryList, not a '
              'subclass');
      expect(factory.buildComputedEntries(), isNot(same(computed)),
          reason: 'persistence.model-factory#3 — a new list on every call');

      // A computed entry stays in memory: nothing reaches Repetitions.
      computed.add(Entry(LocalDate.ymd(2020, 1, 1), Entry.yesAuto));
      expect(db.queryInt('select count(*) from Repetitions'), 0,
          reason: 'persistence.model-factory#3 — writing a computed entry '
              'touches no table');
    });

    test('#4 buildHabitList returns SQLiteHabitList(this)', () {
      final list = factory.buildHabitList();
      expect(list, isA<SQLiteHabitList>(),
          reason: 'persistence.model-factory#4 — buildHabitList returns a '
              'SQLiteHabitList');
      expect(list.modelFactory, same(factory),
          reason: 'persistence.model-factory#4 — it is handed `this`, so the '
              'list builds its habits with the same factory');
      expect(factory.buildHabitList(), isNot(same(list)),
          reason: 'persistence.model-factory#4 — a new list on every call; the '
              'singleton lives in the DI graph, not here');
    });

    test('#5 scores and streaks are plain in-memory lists', () {
      final scores = factory.buildScoreList();
      final streaks = factory.buildStreakList();
      expect(scores.runtimeType, ScoreList,
          reason: 'persistence.model-factory#5 — buildScoreList returns a '
              'plain ScoreList');
      expect(streaks.runtimeType, StreakList,
          reason: 'persistence.model-factory#5 — buildStreakList returns a '
              'plain StreakList');
      expect(factory.buildScoreList(), isNot(same(scores)),
          reason: 'persistence.model-factory#5 — a new list on every call');
      expect(factory.buildStreakList(), isNot(same(streaks)),
          reason: 'persistence.model-factory#5 — a new list on every call');

      // Nothing in the schema could hold them even if the factory wanted to:
      // migration 20 dropped the Score and Streak tables.
      final tables = <String>[];
      db.query(
        "select name from sqlite_master where type = 'table'",
        const <String>[],
        (stmt) => tables.add(stmt.getText(0).toLowerCase()),
      );
      expect(tables, isNot(contains('score')),
          reason: 'persistence.model-factory#5 — scores are never persisted: '
              'there is no Score table at version 25');
      expect(tables, isNot(contains('streak')),
          reason: 'persistence.model-factory#5 — streaks are never persisted: '
              'there is no Streak table at version 25');
    });

    test('#6 SQLiteHabitList requires an SQLModelFactory', () {
      expect(SQLiteHabitList(factory).repository, same(factory.habitRepository),
          reason: 'persistence.model-factory#6 — the injected ModelFactory is '
              'cast to SQLModelFactory to reach habitRepository');
      expect(
        () => SQLiteHabitList(MemoryModelFactory()),
        throwsA(isA<TypeError>()),
        reason: 'persistence.model-factory#6 — any other ModelFactory '
            'implementation throws (ClassCastException in Kotlin, TypeError '
            'here)',
      );
    });
  });
}
