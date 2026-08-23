import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_observable.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/HabitListTest.kt
///
/// The Kotlin `setUp` lives in BaseUnitTest; the parts this file needs (a fixed
/// `today`, a MemoryModelFactory, a habit list and HabitFixtures) are inlined
/// into the [setUp] below.
///
/// Every `expect` carries the parity-ledger rule id it exercises.
void main() {
  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late List<Habit> habitsArray;
  late HabitList activeHabits;
  late HabitList reminderHabits;

  /// A boolean habit with [marks] consecutive YES_MANUAL entries ending today.
  Habit buildScoredHabit(String name, int marks) {
    final habit = fixtures.createEmptyHabit(name: name);
    final today = getToday();
    for (var i = 0; i < marks; i++) {
      habit.originalEntries.add(Entry(today.minus(i), Entry.yesManual));
    }
    habit.recompute();
    return habit;
  }

  /// A numerical habit (target: at least 2.0) holding [todayValue] for today.
  Habit buildNumericalHabit(String name, int todayValue) {
    final habit =
        fixtures.createEmptyNumericalHabit(NumericalHabitType.atLeast);
    habit.name = name;
    habit.originalEntries.add(Entry(getToday(), todayValue));
    habit.recompute();
    return habit;
  }

  /// A boolean habit that either is or is not checked off today.
  Habit buildBooleanHabit(String name, {required bool done}) {
    final habit = fixtures.createEmptyHabit(name: name);
    if (done) {
      habit.originalEntries.add(Entry(getToday(), Entry.yesManual));
    }
    habit.recompute();
    return habit;
  }

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    modelFactory = MemoryModelFactory();
    habitList = modelFactory.buildHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    habitsArray = <Habit>[];
    for (var i = 0; i <= 9; i++) {
      final habit = fixtures.createEmptyHabit();
      habitList.add(habit);
      habitsArray.add(habit);
      if (i % 3 == 0) habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    }
    habitsArray[0].isArchived = true;
    habitsArray[1].isArchived = true;
    habitsArray[4].isArchived = true;
    habitsArray[7].isArchived = true;
    activeHabits = habitList.getFiltered(const HabitMatcher());
    reminderHabits = habitList.getFiltered(
      const HabitMatcher(isArchivedAllowed: true, isReminderRequired: true),
    );
  });

  tearDown(resetToday);

  group('models.habit-list-crud', () {
    test('HabitList is an ordered Iterable<Habit> with the CRUD surface', () {
      expect(habitList, isA<Iterable<Habit>>(),
          reason: 'models.habit-list-crud#1');

      final list = MemoryHabitList();
      expect(list, isA<HabitList>(), reason: 'models.habit-list-crud#1');

      final a = fixtures.createEmptyHabit(name: 'A');
      final b = fixtures.createEmptyHabit(name: 'B');
      list.add(a);
      list.add(b);
      expect(list.size(), 2, reason: 'models.habit-list-crud#1');
      expect(list.getById(a.id!), same(a), reason: 'models.habit-list-crud#1');
      expect(list.getByUUID(b.uuid), same(b),
          reason: 'models.habit-list-crud#1');
      expect(list.getByPosition(0), same(a),
          reason: 'models.habit-list-crud#1');
      expect(list.indexOf(b), 1, reason: 'models.habit-list-crud#1');
      expect(list.getFiltered(const HabitMatcher()), isA<HabitList>(),
          reason: 'models.habit-list-crud#1');

      list.reorder(b, a);
      expect(list.toList().map((h) => h.name).toList(), <String>['B', 'A'],
          reason: 'models.habit-list-crud#1');

      list.update(<Habit>[a, b]);
      list.resort();
      expect(list.size(), 2, reason: 'models.habit-list-crud#1');

      list.remove(a);
      expect(list.size(), 1, reason: 'models.habit-list-crud#1');
      expect(list.indexOf(a), -1, reason: 'models.habit-list-crud#1');
    });

    test('add rejects a habit that is already on the list', () {
      final list = MemoryHabitList();
      final habit = fixtures.createEmptyHabit(name: 'A');
      list.add(habit);
      expect(
        () => list.add(habit),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'habit already added')),
        reason: 'models.habit-list-crud#2',
      );
    });

    test('add assigns ids, rejects duplicate ids and resorts', () {
      final list = MemoryHabitList();
      var notifications = 0;
      list.observable
          .addListener(ModelObservableListener(() => notifications++));

      final a = fixtures.createEmptyHabit(name: 'A');
      expect(a.id, isNull, reason: 'models.habit-list-crud#3');
      list.add(a);
      expect(a.id, 0, reason: 'models.habit-list-crud#3');
      expect(notifications, 1, reason: 'models.habit-list-crud#3');

      final b = fixtures.createEmptyHabit(name: 'B');
      list.add(b);
      expect(b.id, 1, reason: 'models.habit-list-crud#3');
      expect(notifications, 2, reason: 'models.habit-list-crud#3');

      // A non-null id that is not taken yet is kept as is.
      final c = fixtures.createEmptyHabit(name: 'C')..id = 17;
      list.add(c);
      expect(c.id, 17, reason: 'models.habit-list-crud#3');

      final duplicate = fixtures.createEmptyHabit(name: 'D')..id = 1;
      expect(
        () => list.add(duplicate),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'toString', contains('duplicate id'))),
        reason: 'models.habit-list-crud#3',
      );
    });

    test('getById returns the habit or null, never throws', () {
      final habit = habitsArray[0];
      expect(habitList.getById(habit.id!), same(habit),
          reason: 'models.habit-list-crud#4');
      expect(habitList.getById(100), isNull,
          reason: 'models.habit-list-crud#4');
    });

    test('getByUUID returns the habit or null', () {
      final habit = habitsArray[3];
      expect(habit.uuid, isNotNull, reason: 'models.habit-list-crud#5');
      expect(habitList.getByUUID(habit.uuid), same(habit),
          reason: 'models.habit-list-crud#5');
      expect(habitList.getByUUID('not-a-uuid-of-any-habit'), isNull,
          reason: 'models.habit-list-crud#5');
    });

    test('getByPosition indexes the sorted list and range-checks', () {
      expect(habitList.getByPosition(0), same(habitsArray[0]),
          reason: 'models.habit-list-crud#6');
      expect(habitList.getByPosition(3), same(habitsArray[3]),
          reason: 'models.habit-list-crud#6');
      expect(habitList.getByPosition(9), same(habitsArray[9]),
          reason: 'models.habit-list-crud#6');
      expect(activeHabits.getByPosition(0), same(habitsArray[2]),
          reason: 'models.habit-list-crud#6');
      expect(reminderHabits.getByPosition(1), same(habitsArray[3]),
          reason: 'models.habit-list-crud#6');

      expect(() => habitList.getByPosition(10), throwsRangeError,
          reason: 'models.habit-list-crud#6');
      expect(() => habitList.getByPosition(-1), throwsRangeError,
          reason: 'models.habit-list-crud#6');

      // The argument is the list INDEX, not habit.position: under a sorted
      // order the two come apart.
      final list = MemoryHabitList();
      final a = fixtures.createEmptyHabit(name: 'A', position: 5);
      final b = fixtures.createEmptyHabit(name: 'B', position: 9);
      list.add(a);
      list.add(b);
      list.primaryOrder = HabitListOrder.byNameDesc;
      expect(list.getByPosition(0), same(b), reason: 'models.habit-list-crud#6');
      expect(list.getByPosition(0).position, 9,
          reason: 'models.habit-list-crud#6');
    });

    test('indexOf returns the index in the sorted list, or -1', () {
      expect(habitList.indexOf(habitsArray[4]), 4,
          reason: 'models.habit-list-crud#7');
      expect(habitList.indexOf(fixtures.createEmptyHabit(name: 'Absent')), -1,
          reason: 'models.habit-list-crud#7');

      final h1 = fixtures.createEmptyHabit();
      expect(h1.isArchived, isFalse, reason: 'models.habit-list-crud#7');
      expect(h1.id, isNull, reason: 'models.habit-list-crud#7');
      expect(habitList.indexOf(h1), -1, reason: 'models.habit-list-crud#7');
      habitList.add(h1);
      expect(habitList.indexOf(h1), isNot(-1),
          reason: 'models.habit-list-crud#7');
      expect(activeHabits.indexOf(h1), isNot(-1),
          reason: 'models.habit-list-crud#7');
    });

    test('isEmpty is size() == 0', () {
      final list = MemoryHabitList();
      expect(list.size(), 0, reason: 'models.habit-list-crud#8');
      expect(list.isEmpty, isTrue, reason: 'models.habit-list-crud#8');
      list.add(fixtures.createEmptyHabit(name: 'A'));
      expect(list.size(), 1, reason: 'models.habit-list-crud#8');
      expect(list.isEmpty, isFalse, reason: 'models.habit-list-crud#8');

      expect(habitList.size(), 10, reason: 'models.habit-list-crud#8');
      expect(activeHabits.size(), 6, reason: 'models.habit-list-crud#8');
      expect(reminderHabits.size(), 4, reason: 'models.habit-list-crud#8');
    });

    test('remove drops the habit, ignores absentees and notifies', () {
      final list = MemoryHabitList();
      var notifications = 0;
      final a = fixtures.createEmptyHabit(name: 'A');
      final b = fixtures.createEmptyHabit(name: 'B');
      list.add(a);
      list.add(b);
      list.observable
          .addListener(ModelObservableListener(() => notifications++));

      list.remove(a);
      expect(list.size(), 1, reason: 'models.habit-list-crud#9');
      expect(list.indexOf(a), -1, reason: 'models.habit-list-crud#9');
      expect(notifications, 1, reason: 'models.habit-list-crud#9');

      // No-op for a habit that is not in the list, but still notifies.
      list.remove(fixtures.createEmptyHabit(name: 'Absent'));
      expect(list.size(), 1, reason: 'models.habit-list-crud#9');
      expect(notifications, 2, reason: 'models.habit-list-crud#9');
    });

    test('removeAll removes one by one and then notifies once more', () {
      final list = MemoryHabitList();
      for (final name in <String>['A', 'B', 'C']) {
        list.add(fixtures.createEmptyHabit(name: name));
      }
      var notifications = 0;
      list.observable
          .addListener(ModelObservableListener(() => notifications++));
      list.removeAll();
      expect(list.size(), 0, reason: 'models.habit-list-crud#10');
      expect(notifications, 4, reason: 'models.habit-list-crud#10');
    });

    test('update(habit) delegates to update(list) and only re-sorts', () {
      final list = _RecordingHabitList();
      final a = fixtures.createEmptyHabit(name: 'A');
      final b = fixtures.createEmptyHabit(name: 'B');
      list.add(a);
      list.add(b);
      list.primaryOrder = HabitListOrder.byNameAsc;
      list.updates.clear();

      list.updateOne(a);
      expect(list.updates.length, 1, reason: 'models.habit-list-crud#11');
      expect(list.updates.single, <Habit>[a],
          reason: 'models.habit-list-crud#11');

      // MemoryHabitList.update only re-sorts.
      a.name = 'Z';
      var notifications = 0;
      list.observable
          .addListener(ModelObservableListener(() => notifications++));
      list.update(<Habit>[a]);
      expect(list.map((h) => h.name).toList(), <String>['B', 'Z'],
          reason: 'models.habit-list-crud#11');
      expect(notifications, 1, reason: 'models.habit-list-crud#11');
    });

    test('iterator walks a snapshot, so the list can be modified meanwhile',
        () {
      final seen = <Habit>[];
      for (final habit in habitList) {
        seen.add(habit);
        habitList.remove(habit);
      }
      expect(seen.length, 10, reason: 'models.habit-list-crud#12');
      expect(habitList.size(), 0, reason: 'models.habit-list-crud#12');
    });
  });

  group('models.habit-list-ordering', () {
    test('Order has exactly nine values, in the Kotlin declaration order', () {
      expect(
        HabitListOrder.values.map((o) => o.name).toList(),
        <String>[
          'byNameAsc',
          'byNameDesc',
          'byColorAsc',
          'byColorDesc',
          'byScoreAsc',
          'byScoreDesc',
          'byStatusAsc',
          'byStatusDesc',
          'byPosition',
        ],
        reason: 'models.habit-list-ordering#1',
      );
      expect(HabitListOrder.values.length, 9,
          reason: 'models.habit-list-ordering#1');
    });

    test('defaults are BY_POSITION and BY_NAME_ASC', () {
      final list = MemoryHabitList();
      expect(list.primaryOrder, HabitListOrder.byPosition,
          reason: 'models.habit-list-ordering#2');
      expect(list.secondaryOrder, HabitListOrder.byNameAsc,
          reason: 'models.habit-list-ordering#2');
    });

    test('the secondary comparator only runs when the primary ties', () {
      final list = MemoryHabitList();
      final b2 = fixtures.createEmptyHabit(
          name: 'B', color: const PaletteColor(2));
      final a2 = fixtures.createEmptyHabit(
          name: 'A', color: const PaletteColor(2));
      final z1 = fixtures.createEmptyHabit(
          name: 'Z', color: const PaletteColor(1));
      list.add(b2);
      list.add(a2);
      list.add(z1);
      list.primaryOrder = HabitListOrder.byColorAsc;
      list.secondaryOrder = HabitListOrder.byNameAsc;
      // Z wins on color even though its name sorts last; A and B tie on color
      // and are separated by the secondary comparator.
      expect(list.map((h) => h.name).toList(), <String>['Z', 'A', 'B'],
          reason: 'models.habit-list-ordering#3');
    });

    test('setting either order re-sorts immediately and notifies', () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(
          name: 'A', color: const PaletteColor(1)));
      list.add(fixtures.createEmptyHabit(
          name: 'B', color: const PaletteColor(0)));
      var notifications = 0;
      list.observable
          .addListener(ModelObservableListener(() => notifications++));

      list.primaryOrder = HabitListOrder.byNameDesc;
      expect(list.map((h) => h.name).toList(), <String>['B', 'A'],
          reason: 'models.habit-list-ordering#4');
      expect(notifications, 1, reason: 'models.habit-list-ordering#4');

      list.primaryOrder = HabitListOrder.byPosition;
      list.secondaryOrder = HabitListOrder.byColorAsc;
      expect(list.map((h) => h.name).toList(), <String>['B', 'A'],
          reason: 'models.habit-list-ordering#4');
      expect(notifications, 3, reason: 'models.habit-list-ordering#4');
    });

    test('BY_POSITION compares habit.position ascending', () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'A', position: 2));
      list.add(fixtures.createEmptyHabit(name: 'B', position: 0));
      list.add(fixtures.createEmptyHabit(name: 'C', position: 1));
      list.primaryOrder = HabitListOrder.byPosition;
      expect(list.map((h) => h.name).toList(), <String>['B', 'C', 'A'],
          reason: 'models.habit-list-ordering#5');
    });

    test('BY_NAME_ASC is plain, case-sensitive String.compareTo', () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'apple'));
      list.add(fixtures.createEmptyHabit(name: 'Zebra'));
      list.add(fixtures.createEmptyHabit(name: 'Apple'));
      list.primaryOrder = HabitListOrder.byNameAsc;
      // Code-unit order: 'A' (65) < 'Z' (90) < 'a' (97). A locale-aware
      // collation would have produced Apple, apple, Zebra.
      expect(list.map((h) => h.name).toList(),
          <String>['Apple', 'Zebra', 'apple'],
          reason: 'models.habit-list-ordering#6');
      list.primaryOrder = HabitListOrder.byNameDesc;
      expect(list.map((h) => h.name).toList(),
          <String>['apple', 'Zebra', 'Apple'],
          reason: 'models.habit-list-ordering#6');
    });

    test('BY_COLOR_ASC compares paletteIndex ascending, DESC is its reverse',
        () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(
          name: 'A', color: const PaletteColor(2)));
      list.add(fixtures.createEmptyHabit(
          name: 'B', color: const PaletteColor(0)));
      list.add(fixtures.createEmptyHabit(
          name: 'C', color: const PaletteColor(1)));
      list.primaryOrder = HabitListOrder.byColorAsc;
      expect(list.map((h) => h.color.paletteIndex).toList(), <int>[0, 1, 2],
          reason: 'models.habit-list-ordering#7');
      list.primaryOrder = HabitListOrder.byColorDesc;
      expect(list.map((h) => h.color.paletteIndex).toList(), <int>[2, 1, 0],
          reason: 'models.habit-list-ordering#7');
    });

    test('BY_SCORE_DESC puts the LOWEST score first (upstream inversion)', () {
      final list = MemoryHabitList();
      final low = buildScoredHabit('Low', 0);
      final high = buildScoredHabit('High', 60);
      list.add(high);
      list.add(low);
      final today = getToday();
      expect(high.scores[today].value, greaterThan(low.scores[today].value),
          reason: 'models.habit-list-ordering#8');

      list.primaryOrder = HabitListOrder.byScoreDesc;
      expect(list.map((h) => h.name).toList(), <String>['Low', 'High'],
          reason: 'models.habit-list-ordering#8');
      list.primaryOrder = HabitListOrder.byScoreAsc;
      expect(list.map((h) => h.name).toList(), <String>['High', 'Low'],
          reason: 'models.habit-list-ordering#8');
    });

    test('BY_STATUS_DESC: completed, then numerical, then value descending',
        () {
      final list = MemoryHabitList();
      final nHigh = buildNumericalHabit('n-high', 5000); // done, value 5000
      final nLow = buildNumericalHabit('n-low', 3000); // done, value 3000
      final bDone = buildBooleanHabit('b-done', done: true);
      final nMiss = buildNumericalHabit('n-miss', 1000); // 1.0 < target 2.0
      final bMiss = buildBooleanHabit('b-miss', done: false);
      for (final habit in <Habit>[bMiss, nLow, bDone, nHigh, nMiss]) {
        list.add(habit);
      }
      expect(nHigh.isCompletedToday(), isTrue,
          reason: 'models.habit-list-ordering#9');
      expect(nMiss.isCompletedToday(), isFalse,
          reason: 'models.habit-list-ordering#9');

      list.primaryOrder = HabitListOrder.byStatusDesc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['n-high', 'n-low', 'b-done', 'n-miss', 'b-miss'],
        reason: 'models.habit-list-ordering#9',
      );
      list.primaryOrder = HabitListOrder.byStatusAsc;
      expect(
        list.map((h) => h.name).toList(),
        <String>['b-miss', 'n-miss', 'b-done', 'n-low', 'n-high'],
        reason: 'models.habit-list-ordering#9',
      );
    });

    test('resort re-sorts with the current comparator and notifies', () {
      final list = MemoryHabitList();
      final a = fixtures.createEmptyHabit(name: 'A');
      list.add(a);
      list.add(fixtures.createEmptyHabit(name: 'B'));
      list.primaryOrder = HabitListOrder.byNameAsc;
      var notifications = 0;
      list.observable
          .addListener(ModelObservableListener(() => notifications++));

      // A direct mutation does not re-sort by itself.
      a.name = 'Z';
      expect(list.map((h) => h.name).toList(), <String>['Z', 'B'],
          reason: 'models.habit-list-ordering#10');
      list.resort();
      expect(list.map((h) => h.name).toList(), <String>['B', 'Z'],
          reason: 'models.habit-list-ordering#10');
      expect(notifications, 1, reason: 'models.habit-list-ordering#10');
    });

    test('concrete four-habit ordering scenario', () {
      final h1 =
          fixtures.createEmptyHabit(name: 'A Habit', color: const PaletteColor(2), position: 1);
      final h2 =
          fixtures.createEmptyHabit(name: 'B Habit', color: const PaletteColor(2), position: 3);
      final h3 =
          fixtures.createEmptyHabit(name: 'C Habit', color: const PaletteColor(0), position: 0);
      final h4 =
          fixtures.createEmptyHabit(name: 'D Habit', color: const PaletteColor(1), position: 2);

      final list = modelFactory.buildHabitList()
        ..add(h3)
        ..add(h1)
        ..add(h4)
        ..add(h2);

      list.primaryOrder = HabitListOrder.byPosition;
      expect(list.getByPosition(0), same(h3),
          reason: 'models.habit-list-ordering#11');
      expect(list.getByPosition(1), same(h1),
          reason: 'models.habit-list-ordering#11');
      expect(list.getByPosition(2), same(h4),
          reason: 'models.habit-list-ordering#11');
      expect(list.getByPosition(3), same(h2),
          reason: 'models.habit-list-ordering#11');

      list.primaryOrder = HabitListOrder.byNameDesc;
      expect(list.map((h) => h.name).toList(),
          <String>['D Habit', 'C Habit', 'B Habit', 'A Habit'],
          reason: 'models.habit-list-ordering#11');

      list.primaryOrder = HabitListOrder.byNameAsc;
      expect(list.map((h) => h.name).toList(),
          <String>['A Habit', 'B Habit', 'C Habit', 'D Habit'],
          reason: 'models.habit-list-ordering#11');

      list.primaryOrder = HabitListOrder.byNameAsc;
      list.remove(h1);
      list.add(h1);
      expect(list.getByPosition(0), same(h1),
          reason: 'models.habit-list-ordering#11');

      list.primaryOrder = HabitListOrder.byColorAsc;
      list.secondaryOrder = HabitListOrder.byNameAsc;
      expect(list.map((h) => h.name).toList(),
          <String>['C Habit', 'D Habit', 'A Habit', 'B Habit'],
          reason: 'models.habit-list-ordering#11');

      list.primaryOrder = HabitListOrder.byColorDesc;
      list.secondaryOrder = HabitListOrder.byNameAsc;
      expect(list.map((h) => h.name).toList(),
          <String>['A Habit', 'B Habit', 'D Habit', 'C Habit'],
          reason: 'models.habit-list-ordering#11');

      list.primaryOrder = HabitListOrder.byPosition;
      expect(list.map((h) => h.name).toList(),
          <String>['C Habit', 'A Habit', 'D Habit', 'B Habit'],
          reason: 'models.habit-list-ordering#11');
    });
  });

  group('models.habit-list-reorder', () {
    test('reorder moves `from` to the index currently held by `to`', () {
      habitList.reorder(habitsArray[5], habitsArray[2]);
      expect(habitList.indexOf(habitsArray[5]), 2,
          reason: 'models.habit-list-reorder#1');
      expect(habitList.map((h) => h.id).toList(),
          <int>[0, 1, 5, 2, 3, 4, 6, 7, 8, 9],
          reason: 'models.habit-list-reorder#1');
    });

    test('reorder rejects an automatically sorted list', () {
      habitList.primaryOrder = HabitListOrder.byScoreDesc;
      expect(
        () => habitList.reorder(habitsArray[1], habitsArray[2]),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            'cannot reorder automatically sorted list')),
        reason: 'models.habit-list-reorder#2',
      );
    });

    test('reorder rejects a filtered (child) list', () {
      expect(
        () => activeHabits.reorder(
            fixtures.createEmptyHabit(), fixtures.createEmptyHabit()),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          'Filtered lists cannot be modified directly. '
              'You should modify the parent list instead.',
        )),
        reason: 'models.habit-list-reorder#3',
      );
    });

    test('reorder rejects habits that are not in the list', () {
      final absent = fixtures.createEmptyHabit(name: 'Absent');
      expect(
        () => habitList.reorder(absent, habitsArray[0]),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            'list does not contain (from) habit')),
        reason: 'models.habit-list-reorder#4',
      );
      expect(
        () => habitList.reorder(habitsArray[0], absent),
        throwsA(isA<ArgumentError>().having(
            (e) => e.message, 'message', 'list does not contain (to) habit')),
        reason: 'models.habit-list-reorder#4',
      );
    });

    test('the target index is captured before the removal', () {
      // Moving down: `from` lands AFTER the habit it targeted, because toPos
      // was read before the shorter list shifted everything left.
      habitList.reorder(habitsArray[2], habitsArray[5]);
      expect(habitList.map((h) => h.id).toList(),
          <int>[0, 1, 3, 4, 5, 2, 6, 7, 8, 9],
          reason: 'models.habit-list-reorder#5');
      expect(habitList.indexOf(habitsArray[2]), 5,
          reason: 'models.habit-list-reorder#5');
      expect(habitList.indexOf(habitsArray[5]), 4,
          reason: 'models.habit-list-reorder#5');
    });

    test('reorder renumbers positions, notifies once and does not resort', () {
      var notifications = 0;
      habitList.observable
          .addListener(ModelObservableListener(() => notifications++));
      habitList.reorder(habitsArray[5], habitsArray[2]);

      for (var i = 0; i < 10; i++) {
        expect(habitList.getByPosition(i).position, i,
            reason: 'models.habit-list-reorder#6');
      }
      // resort() would have notified a second time.
      expect(notifications, 1, reason: 'models.habit-list-reorder#6');
    });

    test('concrete reorder sequence over ten habits', () {
      const operations = <List<int>>[
        <int>[5, 2],
        <int>[3, 7],
        <int>[4, 4],
        <int>[8, 3],
      ];
      const expectedSequence = <List<int>>[
        <int>[0, 1, 5, 2, 3, 4, 6, 7, 8, 9],
        <int>[0, 1, 5, 2, 4, 6, 7, 3, 8, 9],
        <int>[0, 1, 5, 2, 4, 6, 7, 3, 8, 9],
        <int>[0, 1, 5, 2, 4, 6, 7, 8, 3, 9],
      ];
      for (var i = 0; i < operations.length; i++) {
        habitList.reorder(
            habitsArray[operations[i][0]], habitsArray[operations[i][1]]);
        final actualSequence = <int>[];
        for (var j = 0; j <= 9; j++) {
          final habit = habitList.getByPosition(j);
          expect(habit.position, j, reason: 'models.habit-list-reorder#7');
          actualSequence.add(habit.id!);
        }
        expect(actualSequence, expectedSequence[i],
            reason: 'models.habit-list-reorder#7');
      }
      expect(activeHabits.indexOf(habitsArray[5]), 0,
          reason: 'models.habit-list-reorder#7');
      expect(activeHabits.indexOf(habitsArray[2]), 1,
          reason: 'models.habit-list-reorder#7');
    });

    test('filtered child lists follow the parent order after a reorder', () {
      habitList.reorder(habitsArray[5], habitsArray[2]);
      expect(activeHabits.indexOf(habitsArray[5]), 0,
          reason: 'models.habit-list-reorder#8');
      expect(activeHabits.indexOf(habitsArray[2]), 1,
          reason: 'models.habit-list-reorder#8');
      expect(activeHabits.map((h) => h.id).toList(), <int>[5, 2, 3, 6, 8, 9],
          reason: 'models.habit-list-reorder#8');
    });
  });

  group('models.habit-list-filtering', () {
    test('a top-level list filters with isArchivedAllowed = true', () {
      final list = MemoryHabitList();
      expect(list.filter, const HabitMatcher(isArchivedAllowed: true),
          reason: 'models.habit-list-filtering#1');
      expect(habitList.filter.isArchivedAllowed, isTrue,
          reason: 'models.habit-list-filtering#1');
      // Four of the ten habits are archived and all ten are still listed.
      expect(habitList.size(), 10,
          reason: 'models.habit-list-filtering#1');
      expect(habitList.where((h) => h.isArchived).length, 4,
          reason: 'models.habit-list-filtering#1');
    });

    test('getFiltered builds a fresh child bound to the parent', () {
      const matcher = HabitMatcher();
      final child = habitList.getFiltered(matcher);
      expect(child, isA<MemoryHabitList>(),
          reason: 'models.habit-list-filtering#2');
      expect(identical(child, habitList), isFalse,
          reason: 'models.habit-list-filtering#2');
      expect(child.filter, same(matcher),
          reason: 'models.habit-list-filtering#2');
      // Loaded immediately, without waiting for a parent notification.
      expect(child.size(), 6, reason: 'models.habit-list-filtering#2');
      // A listener was registered on the parent's observable.
      habitList.add(fixtures.createEmptyHabit(name: 'New'));
      expect(child.size(), 7, reason: 'models.habit-list-filtering#2');
    });

    test('a child overwrites the comparator it was handed', () {
      final list = MemoryHabitList();
      for (final name in <String>['A', 'B', 'C']) {
        list.add(fixtures.createEmptyHabit(name: name));
      }
      list.primaryOrder = HabitListOrder.byNameDesc;
      final child = MemoryHabitList.filtered(
        const HabitMatcher(isArchivedAllowed: true),
        // Would sort by insertion id, i.e. A, B, C.
        (h1, h2) => h1.id!.compareTo(h2.id!),
        list,
      );
      expect(child.primaryOrder, HabitListOrder.byNameDesc,
          reason: 'models.habit-list-filtering#3');
      expect(child.secondaryOrder, HabitListOrder.byNameAsc,
          reason: 'models.habit-list-filtering#3');
      expect(child.map((h) => h.name).toList(), <String>['C', 'B', 'A'],
          reason: 'models.habit-list-filtering#3');
    });

    test('every parent notification reloads and re-notifies the child', () {
      var childNotifications = 0;
      activeHabits.observable
          .addListener(ModelObservableListener(() => childNotifications++));

      expect(activeHabits.size(), 6,
          reason: 'models.habit-list-filtering#4');
      habitsArray[2].isArchived = true;
      habitList.update(<Habit>[habitsArray[2]]);
      expect(activeHabits.size(), 5,
          reason: 'models.habit-list-filtering#4');
      expect(activeHabits.indexOf(habitsArray[2]), -1,
          reason: 'models.habit-list-filtering#4');
      expect(childNotifications, greaterThanOrEqualTo(1),
          reason: 'models.habit-list-filtering#4');

      habitsArray[2].isArchived = false;
      habitList.update(<Habit>[habitsArray[2]]);
      expect(activeHabits.size(), 6,
          reason: 'models.habit-list-filtering#4');
    });

    test('add, remove and reorder all throw on a filtered list', () {
      const message = 'Filtered lists cannot be modified directly. '
          'You should modify the parent list instead.';
      expect(
        () => activeHabits.add(fixtures.createEmptyHabit()),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', message)),
        reason: 'models.habit-list-filtering#5',
      );
      expect(
        () => activeHabits.remove(fixtures.createEmptyHabit()),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', message)),
        reason: 'models.habit-list-filtering#5',
      );
      expect(
        () => activeHabits.reorder(
            fixtures.createEmptyHabit(), fixtures.createEmptyHabit()),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', message)),
        reason: 'models.habit-list-filtering#5',
      );
    });

    test('a child inherits the order the parent had at construction time', () {
      habitList.primaryOrder = HabitListOrder.byColorAsc;
      final filteredList = habitList.getFiltered(
        const HabitMatcher(isArchivedAllowed: false, isCompletedAllowed: false),
      );
      expect(filteredList.primaryOrder, HabitListOrder.byColorAsc,
          reason: 'models.habit-list-filtering#6');
    });

    test('children share the parent habit instances', () {
      final fromChild = activeHabits.getByPosition(0);
      expect(identical(fromChild, habitsArray[2]), isTrue,
          reason: 'models.habit-list-filtering#7');
      fromChild.name = 'Renamed through the child';
      expect(habitsArray[2].name, 'Renamed through the child',
          reason: 'models.habit-list-filtering#7');
      expect(identical(habitList.getByPosition(2), fromChild), isTrue,
          reason: 'models.habit-list-filtering#7');
    });
  });

  group('models.habit-list-csv', () {
    test('a header line, then one line per habit in iteration order', () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'A'));
      list.add(fixtures.createEmptyHabit(name: 'B'));
      list.add(fixtures.createEmptyHabit(name: 'C'));

      var lines = list.writeCSV().split('\n');
      expect(lines.length, 5, reason: 'models.habit-list-csv#1');
      expect(lines.last, '', reason: 'models.habit-list-csv#1');
      expect(lines.sublist(1, 4).map((l) => l.split(',')[1]).toList(),
          <String>['A', 'B', 'C'],
          reason: 'models.habit-list-csv#1');

      list.primaryOrder = HabitListOrder.byNameDesc;
      lines = list.writeCSV().split('\n');
      expect(lines.sublist(1, 4).map((l) => l.split(',')[1]).toList(),
          <String>['C', 'B', 'A'],
          reason: 'models.habit-list-csv#1');
    });

    test('the header is exactly the twelve upstream column names', () {
      expect(
        MemoryHabitList().writeCSV(),
        'Position,Name,Type,Question,Description,FrequencyNumerator,'
            'FrequencyDenominator,Color,Unit,Target Type,Target Value,'
            'Archived?\n',
        reason: 'models.habit-list-csv#2',
      );
    });

    test('Position is the 1-based index, zero padded to three digits', () {
      final list = MemoryHabitList();
      for (final name in <String>['A', 'B', 'C']) {
        list.add(fixtures.createEmptyHabit(name: name));
      }
      final lines = list.writeCSV().split('\n');
      expect(lines.sublist(1, 4).map((l) => l.split(',')[0]).toList(),
          <String>['001', '002', '003'],
          reason: 'models.habit-list-csv#3');
    });

    test('Type is the Kotlin enum name and Color is the CSV color', () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(
          name: 'A', color: const PaletteColor(3)));
      list.add(fixtures.createNumericalHabit());
      final rows = list
          .writeCSV()
          .split('\n')
          .sublist(1, 3)
          .map((l) => l.split(','))
          .toList();
      expect(rows[0][2], 'YES_NO', reason: 'models.habit-list-csv#4');
      expect(rows[0][7], '#FF8F00', reason: 'models.habit-list-csv#4');
      expect(rows[1][2], 'NUMERICAL', reason: 'models.habit-list-csv#4');
      expect(rows[1][7], '#E64A19', reason: 'models.habit-list-csv#4');
    });

    test('Unit, Target Type and Target Value are numerical-only', () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'A'));
      final numerical = fixtures.createNumericalHabit();
      list.add(numerical);
      final rows = list
          .writeCSV()
          .split('\n')
          .sublist(1, 3)
          .map((l) => l.split(','))
          .toList();
      expect(rows[0].sublist(8, 11), <String>['', '', ''],
          reason: 'models.habit-list-csv#5');
      expect(rows[1].sublist(8, 11), <String>['miles', 'AT_LEAST', '2.0'],
          reason: 'models.habit-list-csv#5');

      numerical.targetValue = 12.75;
      numerical.targetType = NumericalHabitType.atMost;
      final updated = list.writeCSV().split('\n')[2].split(',');
      expect(updated.sublist(8, 11), <String>['miles', 'AT_MOST', '12.8'],
          reason: 'models.habit-list-csv#5');
    });

    test('Target Value rounds the way String.format does', () {
      // `format("%.1f", habit.targetValue)` on the JVM goes through
      // java.util.Formatter, which rounds the *shortest decimal that
      // round-trips the double* — what Double.toString prints — HALF_UP.
      // `toStringAsFixed` rounds the exact binary value instead, and 0.15 is
      // stored as 0.1499999999999999944…, so the two disagree on roughly half
      // of all x.x5 targets. The port has its own Java-compatible `format()`
      // for exactly this reason; this column is the one place that skipped it
      // (`feedback.csv-target-value-rounds-unlike-java#1`).
      const cases = <(double, String)>[
        (0.15, '0.2'),
        (0.35, '0.4'),
        (0.85, '0.9'),
        (0.95, '1.0'),
        (1.15, '1.2'),
        (4.35, '4.4'),
        (8.35, '8.4'),
        // Exactly representable, so both rounders already agreed here — which
        // is why the existing coverage never caught the difference.
        (12.75, '12.8'),
        (2.0, '2.0'),
      ];
      for (final (value, expected) in cases) {
        final list = MemoryHabitList();
        list.add(fixtures.createNumericalHabit()..targetValue = value);
        final row = list.writeCSV().split('\n')[1].split(',');
        expect(row[10], expected,
            reason: 'feedback.csv-target-value-rounds-unlike-java#1 — '
                'String.format("%.1f", $value) is "$expected" on the JVM; '
                'users diff these files against spreadsheets.');
      }
    });

    test('Archived? renders the boolean', () {
      final list = MemoryHabitList();
      final a = fixtures.createEmptyHabit(name: 'A');
      final b = fixtures.createEmptyHabit(name: 'B')..isArchived = true;
      list.add(a);
      list.add(b);
      final rows = list
          .writeCSV()
          .split('\n')
          .sublist(1, 3)
          .map((l) => l.split(','))
          .toList();
      expect(rows[0][11], 'false', reason: 'models.habit-list-csv#6');
      expect(rows[1][11], 'true', reason: 'models.habit-list-csv#6');
    });

    test('fields holding a comma, quote, CR or LF are quoted', () {
      final list = MemoryHabitList();
      final habit = fixtures.createEmptyHabit(name: 'Read, daily');
      habit.question = 'Did you say "hi"?';
      habit.description = 'line1\nline2';
      habit.color = const PaletteColor(3);
      list.add(habit);
      expect(
        list.writeCSV(),
        'Position,Name,Type,Question,Description,FrequencyNumerator,'
            'FrequencyDenominator,Color,Unit,Target Type,Target Value,'
            'Archived?\n'
            '001,"Read, daily",YES_NO,"Did you say ""hi""?",'
            '"line1\nline2",1,1,#FF8F00,,,,false\n',
        reason: 'models.habit-list-csv#7',
      );

      habit.description = 'carriage\rreturn';
      expect(list.writeCSV().contains('"carriage\rreturn"'), isTrue,
          reason: 'models.habit-list-csv#7');
      // A plain field is emitted verbatim, never quoted.
      habit.name = 'Plain';
      habit.question = '';
      habit.description = '';
      expect(list.writeCSV().contains('001,Plain,YES_NO,,,1,1,#FF8F00,,,,false'),
          isTrue,
          reason: 'models.habit-list-csv#7');
    });

    test('concrete three-habit CSV export', () {
      final list = modelFactory.buildHabitList();
      final h1 = fixtures.createEmptyHabit();
      h1.name = 'Meditate';
      h1.question = 'Did you meditate this morning?';
      h1.description = 'this is a test description';
      h1.frequency = Frequency.daily;
      h1.color = const PaletteColor(3);
      final h2 = fixtures.createEmptyHabit();
      h2.name = 'Wake up early';
      h2.question = 'Did you wake up before 6am?';
      h2.description = '';
      h2.frequency = Frequency(2, 3);
      h2.color = const PaletteColor(5);
      final h3 = fixtures.createNumericalHabit();
      list.add(h1);
      list.add(h2);
      list.add(h3);

      const expectedCSV =
          'Position,Name,Type,Question,Description,FrequencyNumerator,'
          'FrequencyDenominator,Color,Unit,Target Type,Target Value,Archived?\n'
          '001,Meditate,YES_NO,Did you meditate this morning?,'
          'this is a test description,1,1,#FF8F00,,,,false\n'
          '002,Run,NUMERICAL,How many miles did you run today?,,1,1,#E64A19,'
          'miles,AT_LEAST,2.0,false\n'
          '003,Wake up early,YES_NO,Did you wake up before 6am?,,2,3,#AFB42B,'
          ',,,false\n';
      expect(list.writeCSV(), expectedCSV,
          reason: 'models.habit-list-csv#8');
    });
  });

  // =======================================================================
  // audit5.habit-list-re-sort-is-unstable
  //
  // `MutableList.sortWith` is `java.util.List.sort`, i.e. TimSort, which is
  // contractually stable: two habits the composed comparator calls equal keep
  // the relative order they already had in the backing list. `List<E>.sort`
  // in Dart is an introsort — insertion sort below 32 elements, dual-pivot
  // quicksort above it — and is stable at neither size by contract.
  // `resort()` runs on every add, every update, every CreateRepetitionCommand
  // and every filter or order change, so an unstable comparison makes a tied
  // pair jump around for the whole session.
  // =======================================================================

  group('audit5.habit-list-re-sort-is-unstable', () {
    /// Enough habits to take Dart's `List.sort` past its 32-element insertion
    /// sort threshold and into the dual-pivot quicksort, which reorders ties.
    const int tiedHabitCount = 40;

    List<String> namesOf(HabitList list) =>
        <String>[for (final h in list) h.name];

    MemoryHabitList buildTiedList() {
      final list = modelFactory.buildHabitList();
      final tiedFixtures = HabitFixtures(modelFactory, list);
      for (var i = 0; i < tiedHabitCount; i++) {
        // Same position and same color for every habit, so both halves of the
        // composed comparator below return 0 for every pair.
        list.add(
          tiedFixtures.createEmptyHabit(
            name: 'Habit ${i.toString().padLeft(2, '0')}',
            color: const PaletteColor(7),
          ),
        );
      }
      return list;
    }

    test('#1 a resort keeps the previous relative order of habits that tie on '
        'both comparators', () {
      final list = buildTiedList();
      // The habits were added under the default BY_POSITION / BY_NAME_ASC
      // pair, whose tie-break is the name, so the list starts in name order.
      final before = namesOf(list);
      expect(before, List<String>.from(before)..sort(),
          reason: 'audit5.habit-list-re-sort-is-unstable#1 — the fixture '
              'starts in a known order');

      // Now every comparison is a tie: BY_COLOR_ASC over one single color,
      // twice.
      list.primaryOrder = HabitListOrder.byColorAsc;
      list.secondaryOrder = HabitListOrder.byColorAsc;

      expect(namesOf(list), before,
          reason: 'audit5.habit-list-re-sort-is-unstable#1 — sortWith is '
              'TimSort and is contractually stable, so a comparator that '
              'returns 0 leaves the two habits exactly where they were');

      // …and it stays put across the repeated resorts that add / update /
      // CreateRepetitionCommand trigger.
      for (var i = 0; i < 5; i++) {
        list.resort();
        expect(namesOf(list), before,
            reason: 'audit5.habit-list-re-sort-is-unstable#1 — a tied pair '
                'keeps a fixed, non-jumping position for the whole session');
      }
    });

    test('#1 a filtered view resorts its tied habits just as stably', () {
      final list = buildTiedList();
      list.primaryOrder = HabitListOrder.byColorAsc;
      list.secondaryOrder = HabitListOrder.byColorAsc;
      final before = namesOf(list);

      final filtered = list.getFiltered(const HabitMatcher());
      expect(namesOf(filtered), before,
          reason: 'audit5.habit-list-re-sort-is-unstable#1 — the child list '
              'loads from the parent and resorts, and the tie order survives');

      filtered.resort();
      expect(namesOf(filtered), before,
          reason: 'audit5.habit-list-re-sort-is-unstable#1');
    });
  });
}

/// Records every `update(List<Habit>)` call so the single-habit overload can be
/// shown to delegate to it.
class _RecordingHabitList extends MemoryHabitList {
  final List<List<Habit>> updates = <List<Habit>>[];

  @override
  void update(List<Habit> habits) {
    updates.add(habits);
    super.update(habits);
  }
}
