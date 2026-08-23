/// `audit.habitfixtures-saveifsqlite-is-permanently-disabled-by`.
///
/// Kotlin's `HabitFixtures.saveIfSQLite(habit)` is
/// `if (habit.originalEntries !is SQLiteEntryList) return; habitList.add(habit)`
/// — which is what lets `SQLiteHabitListTest` build fixtures against
/// `SQLModelFactory` and have them land in the habit list, and therefore in the
/// `Habits` table. The ported predicate was hardcoded to `false` while
/// `SQLiteEntryList` was unported; the SQLite slice has since landed, so the
/// branch has to become a real type test again.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_entry_list.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late SQLModelFactory factory;
  late SQLiteHabitList habitList;
  late HabitFixtures fixtures;

  setUp(() {
    setToday(LocalDate.ymd(2020, 1, 25));
    db = openMigratedDatabase();
    factory = SQLModelFactory(db);
    habitList = factory.buildHabitList();
    fixtures = HabitFixtures(factory, habitList);
  });

  tearDown(() {
    resetToday();
    db.close();
  });

  int countHabits() {
    var count = 0;
    db.query('select count(*) from Habits', const <String>[],
        (stmt) => count = stmt.getInt(0));
    return count;
  }

  int countEntries() {
    var count = 0;
    db.query('select count(*) from Repetitions', const <String>[],
        (stmt) => count = stmt.getInt(0));
    return count;
  }

  group('saveIfSQLite registers database-backed fixtures', () {
    test('createEmptyHabit lands in the habit list and in the Habits table',
        () {
      final habit = fixtures.createEmptyHabit();

      expect(
        habit.originalEntries,
        isA<SQLiteEntryList>(),
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'a fixture built on SQLModelFactory has an SQLiteEntryList, which is '
            'exactly what saveIfSQLite tests for. '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: the '
            'SQLite slice has landed, so the ported predicate must be '
            '`entries is SQLiteEntryList` rather than a hardcoded false.',
      );
      expect(
        habitList.size(),
        1,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'saveIfSQLite calls habitList.add(habit) for database-backed '
            'fixtures. '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: the '
            'port handed the habit back unregistered instead, so fixtures never '
            'persisted.',
      );
      expect(habitList.getByPosition(0), same(habit));
      expect(
        countHabits(),
        1,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'this is what lets SQLiteHabitListTest build fixtures against '
            'SQLModelFactory and have them actually land in the Habits table. '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: with '
            'the stale stub the row was never written.',
      );
      expect(habit.id, isNotNull);
    });

    test('the habit is registered before its entries, so they persist too', () {
      final habit = fixtures.createShortHabit();

      expect(
        habitList.size(),
        1,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'createShortHabit ends its preamble with saveIfSQLite(habit) and '
            'only then adds the entries — the order that gives SQLiteEntryList '
            'its habitId. '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: the '
            'port keeps the same structure, so restoring the predicate is '
            'enough.',
      );
      expect(
        countEntries(),
        10,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'a database-backed entry list writes itself through on every add. '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: '
            'without the add() the entry list has no habitId and nothing '
            'reaches the Repetitions table.',
      );
      expect(habit.originalEntries.getKnown().length, 10);
    });

    test('every fixture builder registers itself', () {
      fixtures.createEmptyHabit(name: 'Meditate');
      fixtures.createEmptyNumericalHabit(NumericalHabitType.atLeast);
      fixtures.createNumericalHabit();
      fixtures.createLongNumericalHabit(LocalDate.ymd(2020, 1, 25));
      fixtures.createShortHabit();

      expect(
        habitList.size(),
        5,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'every fixture builder — createEmptyHabit, '
            'createEmptyNumericalHabit, createNumericalHabit, '
            'createLongNumericalHabit, createShortHabit — ends with '
            'saveIfSQLite(habit). '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: the '
            'hardcoded false disabled all five at once.',
      );
      expect(countHabits(), 5);
    });

    test('createLongHabit rides on createEmptyHabit and is registered once',
        () {
      final habit = fixtures.createLongHabit();

      expect(
        habitList.size(),
        1,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'createLongHabit delegates to createEmptyHabit, which is where the '
            'single saveIfSQLite lives. '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: the '
            'restored predicate must not add the same habit twice.',
      );
      expect(habit.originalEntries.getKnown(), isNotEmpty);
      expect(countEntries(), 44);
    });
  });

  group('in-memory fixtures are still handed back unregistered', () {
    test('a MemoryModelFactory fixture is not added to the list', () {
      final memoryList = MemoryHabitList();
      final memoryFixtures = HabitFixtures(MemoryModelFactory(), memoryList);

      final Habit habit = memoryFixtures.createEmptyHabit();

      expect(
        habit.originalEntries,
        isNot(isA<SQLiteEntryList>()),
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'with a MemoryModelFactory the check is false',
      );
      expect(
        memoryList.size(),
        0,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#1: '
            'with a MemoryModelFactory the fixture is handed back '
            'unregistered. '
            'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: the '
            'fix restores the branch, it does not remove it — the dozens of '
            'in-memory callers must be unaffected.',
      );
    });

    test('an in-memory fixture still carries its entries', () {
      final memoryList = MemoryHabitList();
      final memoryFixtures = HabitFixtures(MemoryModelFactory(), memoryList);

      final Habit habit = memoryFixtures.createShortHabit();

      expect(memoryList.size(), 0);
      expect(habit.originalEntries.getKnown().length, 10);
      expect(
        habit.originalEntries.getKnown().first.value,
        Entry.yesManual,
        reason: 'audit.habitfixtures-saveifsqlite-is-permanently-disabled-by#2: '
            'the fixture data itself is unchanged',
      );
    });
  });
}
