import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/entry_repository.dart';
import 'package:uhabits_core/src/database/habit_repository.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/model_observable.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_entry_list.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../../helpers/test_database.dart';

/// Ported from
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitListTest.kt`,
/// against
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLiteHabitList.kt`
/// and `.../sqlite/SQLModelFactory.kt`.
///
/// The Kotlin test only covers add / size / getById / getByPosition / indexOf /
/// remove / reorder; everything else here pins down the lazy-load cache, the
/// position repair and the row mapping that the feature rules call out.
void main() {
  /// A fragment of `HabitRepository.findAllStmt`, after whitespace collapsing.
  const findAllSql = 'FROM Habits ORDER BY position';

  /// A fragment of `HabitRepository.updateStmt`.
  const updateSql = 'UPDATE Habits SET name=?';

  late _RecordingDatabase db;
  late SQLModelFactory factory;
  late SQLiteHabitList habitList;
  late HabitRepository repository;
  late EntryRepository entryRepository;

  setUp(() {
    setToday(LocalDate.ymd(2020, 1, 25));
    db = _RecordingDatabase(openMigratedDatabase());
    factory = SQLModelFactory(db);
    habitList = SQLiteHabitList(factory);
    repository = factory.habitRepository;
    entryRepository = factory.entryRepository;
  });

  tearDown(() {
    resetToday();
    db.close();
  });

  /// Inserts one row straight into `Habits`, bypassing the habit list.
  int insertRow({
    required String name,
    required int position,
    int? reminderHour,
    int? reminderMin,
    int reminderDays = 0,
    int archived = 0,
    int color = 8,
    int freqNum = 1,
    int freqDen = 1,
    int type = 0,
    int targetType = 0,
    double targetValue = 0.0,
    String unit = '',
    int highlight = 0,
  }) {
    return repository.insert(
      HabitData(
        name: name,
        description: 'desc of $name',
        question: 'question of $name',
        position: position,
        uuid: 'uuid-$name',
        reminderHour: reminderHour,
        reminderMin: reminderMin,
        reminderDays: reminderDays,
        archived: archived,
        color: color,
        freqNum: freqNum,
        freqDen: freqDen,
        type: type,
        targetType: targetType,
        targetValue: targetValue,
        unit: unit,
        highlight: highlight,
      ),
    );
  }

  /// Three rows at contiguous positions 0, 1, 2.
  void insertThreeRows() {
    insertRow(name: 'A', position: 0);
    insertRow(name: 'B', position: 1);
    insertRow(name: 'C', position: 2);
  }

  /// The Kotlin fixture: ten habits named "habit 1".."habit 10", at positions
  /// 0..9 with ids 1..10, four of them archived and four carrying a reminder.
  List<Habit> seedTenHabits() {
    final habits = <Habit>[];
    for (var i = 0; i < 10; i++) {
      final habit = factory.buildHabit();
      habit.name = 'habit ${i + 1}';
      habit.question = 'Did you meditate this morning?';
      habit.color = const PaletteColor(3);
      habitList.add(habit);
      if (i % 3 == 0) habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habits.add(habit);
    }
    habits[0].isArchived = true;
    habits[1].isArchived = true;
    habits[4].isArchived = true;
    habits[7].isArchived = true;
    habitList.update(habits);
    return habits;
  }

  List<int> storedPositions() =>
      repository.findAll().map((r) => r.position).toList();

  Map<int, HabitData> rowsById() => <int, HabitData>{
        for (final r in repository.findAll()) r.id!: r,
      };

  int countRepetitions(int habitId) =>
      db.queryInt('select count(*) from Repetitions where habit = $habitId');

  group('persistence.sqlite-habit-list-cache', () {
    test('#1 delegates to an internal MemoryHabitList and loads exactly once',
        () {
      insertThreeRows();
      final list = SQLiteHabitList(factory);
      db.clearLog();

      expect(list.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#1');
      expect(db.countResets(findAllSql), 1,
          reason: 'persistence.sqlite-habit-list-cache#1');

      // Every later read is served from the in-memory list.
      list.size();
      list.getById(1);
      list.getByPosition(0);
      list.toList();
      expect(db.countResets(findAllSql), 1,
          reason: 'persistence.sqlite-habit-list-cache#1');

      // The in-memory delegate supplies the defaults and the ordering.
      expect(list.primaryOrder, HabitListOrder.byPosition,
          reason: 'persistence.sqlite-habit-list-cache#1');
      expect(list.secondaryOrder, HabitListOrder.byNameAsc,
          reason: 'persistence.sqlite-habit-list-cache#1');
      expect(list.map((h) => h.name).toList(), ['A', 'B', 'C'],
          reason: 'persistence.sqlite-habit-list-cache#1');
    });

    test('#2 loaded is set before the read, so a re-entrant call cannot recurse',
        () {
      insertThreeRows();
      final list = SQLiteHabitList(factory);

      int? reentrantSize;
      var reentrantLoads = 0;
      db.hookOnceBeforeStep(findAllSql, () {
        final before = db.countResets(findAllSql);
        reentrantSize = list.size();
        reentrantLoads = db.countResets(findAllSql) - before;
      });

      expect(list.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#2');
      // The re-entrant call saw loaded == true, returned the (still empty)
      // in-memory list and issued no second query.
      expect(reentrantSize, 0,
          reason: 'persistence.sqlite-habit-list-cache#2');
      expect(reentrantLoads, 0,
          reason: 'persistence.sqlite-habit-list-cache#2');
    });

    test('#3 loadRecords clears the list first, then adds one habit per row',
        () {
      // Inserted out of order; findAll() returns them ordered by position.
      insertRow(name: 'C', position: 2);
      insertRow(name: 'A', position: 0);
      insertRow(name: 'B', position: 1);

      expect(habitList.map((h) => h.name).toList(), ['A', 'B', 'C'],
          reason: 'persistence.sqlite-habit-list-cache#3');

      // Reloading must not append a second copy of every row.
      habitList.reload();
      expect(habitList.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#3');
      expect(habitList.map((h) => h.name).toList(), ['A', 'B', 'C'],
          reason: 'persistence.sqlite-habit-list-cache#3');
    });

    test('#4 each loaded habit gets its entry list habitId assigned', () {
      insertThreeRows();

      for (final habit in habitList) {
        final entries = habit.originalEntries;
        expect(entries, isA<SQLiteEntryList>(),
            reason: 'persistence.sqlite-habit-list-cache#4');
        expect((entries as SQLiteEntryList).habitId, habit.id,
            reason: 'persistence.sqlite-habit-list-cache#4');
      }
      expect(
        habitList.map((h) => (h.originalEntries as SQLiteEntryList).habitId),
        [1, 2, 3],
        reason: 'persistence.sqlite-habit-list-cache#4',
      );
    });

    test('#5 a position that differs from the row index triggers rebuildOrder',
        () {
      insertRow(name: 'A', position: 0);
      insertRow(name: 'B', position: 1);
      insertRow(name: 'C', position: 5);

      expect(habitList.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#5');
      expect(storedPositions(), [0, 1, 2],
          reason: 'persistence.sqlite-habit-list-cache#5');

      // Upstream quirk, reproduced as is: rebuildOrder rewrites the rows but
      // never the already-built in-memory habits, so the model keeps the stale
      // position until the next reload.
      expect(habitList.getByPosition(2).position, 5,
          reason: 'persistence.sqlite-habit-list-cache#5');
    });

    test('#6 rebuildOrder re-reads all rows and writes only the wrong ones', () {
      insertRow(name: 'A', position: 0);
      insertRow(name: 'B', position: 1);
      insertRow(name: 'C', position: 5);
      db.clearLog();

      habitList.size();

      // One findAll() inside loadRecords, one inside rebuildOrder.
      expect(db.countResets(findAllSql), 2,
          reason: 'persistence.sqlite-habit-list-cache#6');
      // Only the third row was out of place, so only it was rewritten.
      expect(db.countSteps(updateSql), 1,
          reason: 'persistence.sqlite-habit-list-cache#6');
      expect(storedPositions(), [0, 1, 2],
          reason: 'persistence.sqlite-habit-list-cache#6');

      // Rows that already match are left alone: a second repair writes nothing.
      db.clearLog();
      habitList.repair();
      expect(db.countSteps(updateSql), 0,
          reason: 'persistence.sqlite-habit-list-cache#6');
    });

    test('#7 every accessor and mutator loads records first', () {
      final habits = seedTenHabits();

      int loadsDuring(void Function() action) {
        db.clearLog();
        action();
        return db.countResets(findAllSql);
      }

      expect(loadsDuring(() => SQLiteHabitList(factory).getById(1)),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).getByUUID(habits[0].uuid)),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).getByPosition(0)),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(
          loadsDuring(() =>
              SQLiteHabitList(factory).getFiltered(const HabitMatcher())),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).indexOf(habits[3])),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).iterator),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).size()),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).update(<Habit>[])),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(
          loadsDuring(
              () => SQLiteHabitList(factory).add(factory.buildHabit())),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(
          loadsDuring(
              () => SQLiteHabitList(factory).reorder(habits[3], habits[2])),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).repair()),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
      expect(loadsDuring(() => SQLiteHabitList(factory).remove(habits[9])),
          greaterThanOrEqualTo(1),
          reason: 'persistence.sqlite-habit-list-cache#7');
    });

    test('#8 removeAll and resort do not load records', () {
      insertThreeRows();

      final forRemoveAll = SQLiteHabitList(factory);
      db.clearLog();
      forRemoveAll.removeAll();
      expect(db.countResets(findAllSql), 0,
          reason: 'persistence.sqlite-habit-list-cache#8');

      final forResort = SQLiteHabitList(factory);
      db.clearLog();
      forResort.resort();
      expect(db.countResets(findAllSql), 0,
          reason: 'persistence.sqlite-habit-list-cache#8');
    });

    test('#9 reload only marks the cache stale, it does not clear the list',
        () {
      seedTenHabits();
      // A filtered child list mirrors the internal in-memory list, so it is
      // the only window onto that list that reload() cannot re-populate.
      final filtered =
          habitList.getFiltered(const HabitMatcher(isArchivedAllowed: true));
      expect(filtered.size(), 10,
          reason: 'persistence.sqlite-habit-list-cache#9');

      habitList.reload();
      expect(filtered.size(), 10,
          reason: 'persistence.sqlite-habit-list-cache#9');

      // The next read goes back to the database.
      db.run('delete from Habits where id = 1');
      expect(habitList.size(), 9,
          reason: 'persistence.sqlite-habit-list-cache#9');
    });

    test('#10 the cache never notices an external write', () {
      insertThreeRows();
      expect(habitList.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#10');

      insertRow(name: 'D', position: 3);
      expect(habitList.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#10');
      expect(habitList.getById(4), isNull,
          reason: 'persistence.sqlite-habit-list-cache#10');

      habitList.reload();
      expect(habitList.size(), 4,
          reason: 'persistence.sqlite-habit-list-cache#10');
    });

    test('#11 the Kotlin monitor: mutations complete before listeners run', () {
      final habits = seedTenHabits();
      final observed = <int>[];
      // A listener re-enters the list. Kotlin's monitor is reentrant and every
      // mutation notifies last, so the callback always sees the final state; in
      // Dart the single-threaded run loop gives the same guarantee.
      final listener = ModelObservableListener(() {
        observed.add(habitList.size());
      });
      habitList.observable.addListener(listener);

      final extra = factory.buildHabit()..name = 'extra';
      habitList.add(extra);
      expect(observed.last, 11,
          reason: 'persistence.sqlite-habit-list-cache#11');

      habitList.remove(habits[0]);
      expect(observed.last, 10,
          reason: 'persistence.sqlite-habit-list-cache#11');

      habitList.removeAll();
      expect(observed.last, 0,
          reason: 'persistence.sqlite-habit-list-cache#11');

      habitList.observable.removeListener(listener);
    });

    test('#12 habits are built through the ModelFactory on first access', () {
      insertThreeRows();
      final counting = _CountingModelFactory(db);
      final list = SQLiteHabitList(counting);

      expect(list.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#12');
      expect(counting.buildHabitCount, 3,
          reason: 'persistence.sqlite-habit-list-cache#12');
      expect(
        list.map((h) => (h.originalEntries as SQLiteEntryList).habitId).toList(),
        [1, 2, 3],
        reason: 'persistence.sqlite-habit-list-cache#12',
      );
    });

    test('#13 out-of-order positions are renumbered to 0..n-1 and written back',
        () {
      insertRow(name: 'A', position: 3);
      insertRow(name: 'B', position: 7);
      insertRow(name: 'C', position: 9);

      expect(habitList.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#13');
      expect(storedPositions(), [0, 1, 2],
          reason: 'persistence.sqlite-habit-list-cache#13');
      expect(rowsById().values.map((r) => r.name).toList(), ['A', 'B', 'C'],
          reason: 'persistence.sqlite-habit-list-cache#13');
    });

    test('#14 add appends at size(), takes the row id and notifies', () {
      seedTenHabits();
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);

      final habit = factory.buildHabit()..name = 'Hello world';
      expect(habit.id, isNull,
          reason: 'persistence.sqlite-habit-list-cache#14');
      habitList.add(habit);

      expect(habit.position, 10,
          reason: 'persistence.sqlite-habit-list-cache#14');
      expect(habit.id, 11, reason: 'persistence.sqlite-habit-list-cache#14');
      expect((habit.originalEntries as SQLiteEntryList).habitId, 11,
          reason: 'persistence.sqlite-habit-list-cache#14');
      expect(habitList.indexOf(habit), 10,
          reason: 'persistence.sqlite-habit-list-cache#14');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-cache#14');
      expect(rowsById()[11]!.name, 'Hello world',
          reason: 'persistence.sqlite-habit-list-cache#14');

      expect(() => habitList.add(habit), throwsA(isA<ArgumentError>()),
          reason: 'persistence.sqlite-habit-list-cache#14');

      habitList.observable.removeListener(listener);
    });

    test('#15 a habit added with an explicit id keeps it', () {
      seedTenHabits();
      final habit = factory.buildHabit()
        ..name = 'Hello world with id'
        ..id = 12300;

      habitList.add(habit);

      expect(habit.id, 12300, reason: 'persistence.sqlite-habit-list-cache#15');
      expect(rowsById()[12300]!.name, 'Hello world with id',
          reason: 'persistence.sqlite-habit-list-cache#15');
      expect((habit.originalEntries as SQLiteEntryList).habitId, 12300,
          reason: 'persistence.sqlite-habit-list-cache#15');
    });

    test('#16 removeAll clears the list and both tables', () {
      seedTenHabits();
      entryRepository
          .insert(EntryData(habitId: 1, timestamp: 1000, value: Entry.yesManual));
      entryRepository
          .insert(EntryData(habitId: 2, timestamp: 2000, value: Entry.yesManual));
      // The habits are deleted before the repetitions that reference them, so
      // the pair only works with foreign key enforcement off — which is the
      // state the app connection runs in on Android. See
      // persistence.sqlite-habit-list-mutations#8 for the ordering hazard.
      db.run('pragma foreign_keys=OFF');
      db.clearLog();

      habitList.removeAll();

      expect(habitList.size(), 0,
          reason: 'persistence.sqlite-habit-list-cache#16');
      expect(repository.findAll(), isEmpty,
          reason: 'persistence.sqlite-habit-list-cache#16');
      expect(db.queryInt('select count(*) from Repetitions'), 0,
          reason: 'persistence.sqlite-habit-list-cache#16');
      expect(db.preparedMatching('delete from habits'), hasLength(1),
          reason: 'persistence.sqlite-habit-list-cache#16');
      expect(db.preparedMatching('delete from repetitions'), hasLength(1),
          reason: 'persistence.sqlite-habit-list-cache#16');
    });

    test('#17 reload forces the next access to re-read everything', () {
      insertThreeRows();
      expect(habitList.size(), 3,
          reason: 'persistence.sqlite-habit-list-cache#17');

      insertRow(name: 'D', position: 3);
      habitList.reload();
      db.clearLog();

      expect(habitList.size(), 4,
          reason: 'persistence.sqlite-habit-list-cache#17');
      expect(db.countResets(findAllSql), 1,
          reason: 'persistence.sqlite-habit-list-cache#17');
      expect(habitList.map((h) => h.name).toList(), ['A', 'B', 'C', 'D'],
          reason: 'persistence.sqlite-habit-list-cache#17');
    });

    test('#18 copyFrom maps the model onto a row', () {
      final habit = factory.buildHabit()
        ..id = 42
        ..name = 'Run'
        ..description = 'every morning'
        ..question = 'How far?'
        ..frequency = Frequency(3, 7)
        ..color = const PaletteColor(11)
        ..position = 4
        ..reminder = Reminder(8, 30, WeekdayList(3))
        ..isArchived = true
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atMost
        ..targetValue = 2.5
        ..unit = 'miles'
        ..uuid = 'deadbeef';

      final data = SQLiteHabitList.copyFrom(habit);

      expect(data.id, 42, reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.name, 'Run',
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.description, 'every morning',
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.question, 'How far?',
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.freqNum, 3, reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.freqDen, 7, reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.color, 11, reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.position, 4,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.reminderHour, 8,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.reminderMin, 30,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.reminderDays, 3,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.highlight, 0,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.archived, 1,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.type, HabitType.numerical.value,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.targetType, NumericalHabitType.atMost.value,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.targetValue, 2.5,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.unit, 'miles',
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(data.uuid, 'deadbeef',
          reason: 'persistence.sqlite-habit-list-cache#18');

      // No reminder: hour and minute are null and the day mask is 0.
      final plain = factory.buildHabit()..isArchived = false;
      final plainData = SQLiteHabitList.copyFrom(plain);
      expect(plainData.reminderHour, isNull,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(plainData.reminderMin, isNull,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(plainData.reminderDays, 0,
          reason: 'persistence.sqlite-habit-list-cache#18');
      expect(plainData.archived, 0,
          reason: 'persistence.sqlite-habit-list-cache#18');
    });

    test('#19 copyTo maps a row onto the model, reminder only when complete',
        () {
      final data = HabitData(
        id: 7,
        name: 'Meditate',
        description: 'in the morning',
        question: 'Did you meditate?',
        freqNum: 2,
        freqDen: 7,
        color: 5,
        position: 3,
        reminderHour: 22,
        reminderMin: 15,
        reminderDays: 96,
        archived: 1,
        type: 1,
        targetType: 1,
        targetValue: 3.5,
        unit: 'pages',
        uuid: 'abc123',
      );
      final habit = factory.buildHabit();
      SQLiteHabitList.copyTo(data, habit);

      expect(habit.id, 7, reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.name, 'Meditate',
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.description, 'in the morning',
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.question, 'Did you meditate?',
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.frequency, Frequency(2, 7),
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.color, const PaletteColor(5),
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.position, 3,
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.isArchived, isTrue,
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.type, HabitType.numerical,
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.targetType, NumericalHabitType.atMost,
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.targetValue, 3.5,
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.unit, 'pages',
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.uuid, 'abc123',
          reason: 'persistence.sqlite-habit-list-cache#19');
      expect(habit.reminder, Reminder(22, 15, WeekdayList(96)),
          reason: 'persistence.sqlite-habit-list-cache#19');

      final noHour = factory.buildHabit();
      SQLiteHabitList.copyTo(
          HabitData(id: 8, reminderMin: 30, reminderDays: 127), noHour);
      expect(noHour.reminder, isNull,
          reason: 'persistence.sqlite-habit-list-cache#19');

      final noMinute = factory.buildHabit();
      SQLiteHabitList.copyTo(
          HabitData(id: 9, reminderHour: 8, reminderDays: 127), noMinute);
      expect(noMinute.reminder, isNull,
          reason: 'persistence.sqlite-habit-list-cache#19');
    });

    test('#20 ordering and filtering are delegated to the in-memory list', () {
      seedTenHabits();

      habitList.primaryOrder = HabitListOrder.byNameDesc;
      expect(habitList.primaryOrder, HabitListOrder.byNameDesc,
          reason: 'persistence.sqlite-habit-list-cache#20');
      expect(habitList.getByPosition(0).name, 'habit 9',
          reason: 'persistence.sqlite-habit-list-cache#20');
      expect(habitList.map((h) => h.name).last, 'habit 1',
          reason: 'persistence.sqlite-habit-list-cache#20');

      habitList.secondaryOrder = HabitListOrder.byColorAsc;
      expect(habitList.secondaryOrder, HabitListOrder.byColorAsc,
          reason: 'persistence.sqlite-habit-list-cache#20');

      habitList.primaryOrder = HabitListOrder.byPosition;
      final active = habitList.getFiltered(const HabitMatcher());
      expect(active, isA<MemoryHabitList>(),
          reason: 'persistence.sqlite-habit-list-cache#20');
      expect(active.size(), 6,
          reason: 'persistence.sqlite-habit-list-cache#20');

      final withReminder = habitList.getFiltered(const HabitMatcher(
        isArchivedAllowed: true,
        isReminderRequired: true,
      ));
      expect(withReminder.size(), 4,
          reason: 'persistence.sqlite-habit-list-cache#20');
      expect(withReminder.map((h) => h.name).toList(),
          ['habit 1', 'habit 4', 'habit 7', 'habit 10'],
          reason: 'persistence.sqlite-habit-list-cache#20');
    });
  });

  group('persistence.sqlite-habit-list-mutations', () {
    test('#1 adding the same habit twice throws', () {
      seedTenHabits();
      final habit = factory.buildHabit();
      habitList.add(habit);

      expect(
        () => habitList.add(habit),
        throwsA(
          isA<ArgumentError>().having((e) => e.message, 'message',
              contains('habit already added')),
        ),
        reason: 'persistence.sqlite-habit-list-mutations#1',
      );
    });

    test('#2 add overwrites the position with the current size()', () {
      seedTenHabits();
      final habit = factory.buildHabit()
        ..name = 'appended'
        ..position = 999;

      habitList.add(habit);

      expect(habit.position, 10,
          reason: 'persistence.sqlite-habit-list-mutations#2');
      expect(rowsById()[habit.id]!.position, 10,
          reason: 'persistence.sqlite-habit-list-mutations#2');
      expect(storedPositions(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          reason: 'persistence.sqlite-habit-list-mutations#2');
    });

    test('#3 add inserts the row, propagates the id and notifies', () {
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);

      final habit = factory.buildHabit()..name = 'Hello world';
      habitList.add(habit);

      expect(habit.id, isNotNull,
          reason: 'persistence.sqlite-habit-list-mutations#3');
      expect(rowsById()[habit.id]!.name, 'Hello world',
          reason: 'persistence.sqlite-habit-list-mutations#3');
      expect((habit.originalEntries as SQLiteEntryList).habitId, habit.id,
          reason: 'persistence.sqlite-habit-list-mutations#3');
      expect(habitList.indexOf(habit), 0,
          reason: 'persistence.sqlite-habit-list-mutations#3');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#3');

      habitList.observable.removeListener(listener);
    });

    test('#4 add with an explicit id inserts and keeps that id', () {
      seedTenHabits();
      final habit = factory.buildHabit()
        ..name = 'Hello world with id'
        ..id = 12300;

      habitList.add(habit);

      expect(habit.id, 12300,
          reason: 'persistence.sqlite-habit-list-mutations#4');
      final record =
          repository.findAll().where((r) => r.id == 12300).single;
      expect(record.name, habit.name,
          reason: 'persistence.sqlite-habit-list-mutations#4');
    });

    test('#5 remove deletes the row, its entries, and renumbers', () {
      seedTenHabits();
      final habit = habitList.getById(2)!;
      // Two entries for the doomed habit and one for a survivor.
      habit.originalEntries.add(Entry(LocalDate.ymd(2020, 1, 20), Entry.yesManual));
      habit.originalEntries.add(Entry(LocalDate.ymd(2020, 1, 21), Entry.yesManual));
      habitList.getById(3)!.originalEntries
          .add(Entry(LocalDate.ymd(2020, 1, 20), Entry.yesManual));
      expect(countRepetitions(2), 2,
          reason: 'persistence.sqlite-habit-list-mutations#5');

      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);

      habitList.remove(habit);

      expect(habitList.indexOf(habit), -1,
          reason: 'persistence.sqlite-habit-list-mutations#5');
      expect(countRepetitions(2), 0,
          reason: 'persistence.sqlite-habit-list-mutations#5');
      expect(countRepetitions(3), 1,
          reason: 'persistence.sqlite-habit-list-mutations#5');
      expect(rowsById().containsKey(2), isFalse,
          reason: 'persistence.sqlite-habit-list-mutations#5');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#5');

      habitList.observable.removeListener(listener);
    });

    test('#6 remove compacts the remaining positions to 0..n-1', () {
      seedTenHabits();
      final habit = habitList.getById(2)!;

      habitList.remove(habit);

      final rows = rowsById();
      expect(rows[2], isNull,
          reason: 'persistence.sqlite-habit-list-mutations#6');
      expect(rows[3]!.position, 1,
          reason: 'persistence.sqlite-habit-list-mutations#6');
      expect(storedPositions(), [0, 1, 2, 3, 4, 5, 6, 7, 8],
          reason: 'persistence.sqlite-habit-list-mutations#6');
    });

    test('#7 remove compacts positions even when sorted by name', () {
      seedTenHabits();
      habitList.primaryOrder = HabitListOrder.byNameDesc;
      final habit = habitList.getById(2)!;

      habitList.remove(habit);

      expect(habitList.indexOf(habit), -1,
          reason: 'persistence.sqlite-habit-list-mutations#7');
      final rows = rowsById();
      expect(rows[2], isNull,
          reason: 'persistence.sqlite-habit-list-mutations#7');
      expect(rows[3]!.position, 1,
          reason: 'persistence.sqlite-habit-list-mutations#7');
      expect(storedPositions(), [0, 1, 2, 3, 4, 5, 6, 7, 8],
          reason: 'persistence.sqlite-habit-list-mutations#7');
    });

    test('#8 removeAll runs both raw deletes and keeps the id sequence', () {
      seedTenHabits();
      entryRepository
          .insert(EntryData(habitId: 1, timestamp: 1000, value: Entry.yesManual));

      // The order is significant, and upstream has it backwards: the parent
      // rows go first, while the Repetitions rows still reference them. The
      // Android app connection keeps foreign key enforcement off, so it goes
      // through there; this connection ran migration 22, which turns it on, so
      // the very first statement raises and the second one never runs.
      expect(() => habitList.removeAll(), throwsA(isA<Exception>()),
          reason: 'persistence.sqlite-habit-list-mutations#8');
      expect(db.queryInt('select count(*) from Repetitions'), 1,
          reason: 'persistence.sqlite-habit-list-mutations#8');
      expect(repository.findAll(), hasLength(10),
          reason: 'persistence.sqlite-habit-list-mutations#8');

      // Match the environment the two statements were written for.
      db.run('pragma foreign_keys=OFF');
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);
      db.clearLog();

      habitList.removeAll();

      final rawDeletes = db.prepared
          .where((sql) => sql.startsWith('delete from'))
          .toList();
      expect(rawDeletes, ['delete from habits', 'delete from repetitions'],
          reason: 'persistence.sqlite-habit-list-mutations#8');
      expect(db.countResets(findAllSql), 0,
          reason: 'persistence.sqlite-habit-list-mutations#8');
      expect(habitList.size(), 0,
          reason: 'persistence.sqlite-habit-list-mutations#8');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#8');

      // AUTOINCREMENT is untouched: the next habit continues at 11.
      final habit = factory.buildHabit()..name = 'after wipe';
      habitList.add(habit);
      expect(habit.id, 11,
          reason: 'persistence.sqlite-habit-list-mutations#8');

      habitList.observable.removeListener(listener);
    });

    test('#9 reorder issues one bulk shift, in both directions', () {
      seedTenHabits();
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);

      // Moving backwards: toPos < fromPos.
      db.clearLog();
      habitList.reorder(habitList.getById(4)!, habitList.getById(3)!);
      expect(
        db.preparedMatching('update habits set position'),
        ['update habits set position = position + 1 '
            'where position >= 2 and position < 3'],
        reason: 'persistence.sqlite-habit-list-mutations#9',
      );
      expect(rowsById()[4]!.position, 2,
          reason: 'persistence.sqlite-habit-list-mutations#9');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#9');

      // Moving forwards: toPos > fromPos. Habit 3 now sits at position 3.
      db.clearLog();
      habitList.reorder(habitList.getById(3)!, habitList.getById(7)!);
      expect(
        db.preparedMatching('update habits set position'),
        ['update habits set position = position - 1 '
            'where position > 3 and position <= 6'],
        reason: 'persistence.sqlite-habit-list-mutations#9',
      );
      expect(rowsById()[3]!.position, 6,
          reason: 'persistence.sqlite-habit-list-mutations#9');
      expect(storedPositions(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'persistence.sqlite-habit-list-mutations#9');

      habitList.observable.removeListener(listener);
    });

    test('#10 the reorder bounds are interpolated, not bound', () {
      seedTenHabits();
      db.clearLog();

      habitList.reorder(habitList.getById(4)!, habitList.getById(3)!);

      final shift = db.preparedMatching('update habits set position').single;
      expect(shift, contains('position >= 2'),
          reason: 'persistence.sqlite-habit-list-mutations#10');
      expect(shift, contains('position < 3'),
          reason: 'persistence.sqlite-habit-list-mutations#10');
      expect(shift, isNot(contains('?')),
          reason: 'persistence.sqlite-habit-list-mutations#10');
    });

    test('#11 reorder(pos3, pos2) swaps the two rows', () {
      seedTenHabits();
      final habit3 = habitList.getById(3)!;
      final habit4 = habitList.getById(4)!;
      expect(habit3.position, 2,
          reason: 'persistence.sqlite-habit-list-mutations#11');
      expect(habit4.position, 3,
          reason: 'persistence.sqlite-habit-list-mutations#11');

      habitList.reorder(habit4, habit3);

      final rows = rowsById();
      expect(rows[3]!.position, 3,
          reason: 'persistence.sqlite-habit-list-mutations#11');
      expect(rows[4]!.position, 2,
          reason: 'persistence.sqlite-habit-list-mutations#11');
      expect(habitList.getByPosition(2).id, 4,
          reason: 'persistence.sqlite-habit-list-mutations#11');
      expect(habitList.getByPosition(3).id, 3,
          reason: 'persistence.sqlite-habit-list-mutations#11');
    });

    test('#12 reorder on an automatically sorted list throws and writes nothing',
        () {
      seedTenHabits();
      habitList.primaryOrder = HabitListOrder.byNameAsc;
      final habit3 = habitList.getById(3)!;
      final habit4 = habitList.getById(4)!;
      db.clearLog();

      expect(
        () => habitList.reorder(habit4, habit3),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            contains('cannot reorder automatically sorted list'))),
        reason: 'persistence.sqlite-habit-list-mutations#12',
      );
      expect(db.preparedMatching('update habits set position'), isEmpty,
          reason: 'persistence.sqlite-habit-list-mutations#12');
      expect(storedPositions(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'persistence.sqlite-habit-list-mutations#12');
    });

    test('#13 repair renumbers positions and touches nothing else', () {
      seedTenHabits();
      entryRepository
          .insert(EntryData(habitId: 1, timestamp: 1000, value: Entry.yesManual));
      db.run('update Habits set position = 40 where id = 1');
      db.run('update Habits set position = 41 where id = 2');
      habitList.reload();
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);

      habitList.repair();

      expect(storedPositions(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'persistence.sqlite-habit-list-mutations#13');
      expect(rowsById()[1]!.position, 8,
          reason: 'persistence.sqlite-habit-list-mutations#13');
      expect(rowsById()[1]!.name, 'habit 1',
          reason: 'persistence.sqlite-habit-list-mutations#13');
      expect(db.queryInt('select count(*) from Repetitions'), 1,
          reason: 'persistence.sqlite-habit-list-mutations#13');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#13');

      habitList.observable.removeListener(listener);
    });

    test('#14 update rewrites every habit passed to it and notifies once', () {
      final habits = seedTenHabits();
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);
      db.clearLog();

      habits[0].name = 'renamed 1';
      habits[1].name = 'renamed 2';
      habitList.update(<Habit>[habits[0], habits[1]]);

      expect(db.countSteps(updateSql), 2,
          reason: 'persistence.sqlite-habit-list-mutations#14');
      expect(rowsById()[1]!.name, 'renamed 1',
          reason: 'persistence.sqlite-habit-list-mutations#14');
      expect(rowsById()[2]!.name, 'renamed 2',
          reason: 'persistence.sqlite-habit-list-mutations#14');
      expect(rowsById()[3]!.name, 'habit 3',
          reason: 'persistence.sqlite-habit-list-mutations#14');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#14');

      habitList.observable.removeListener(listener);
    });

    test('#15 the sort order is in-memory only and never written to SQLite',
        () {
      seedTenHabits();
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);
      db.clearLog();

      habitList.primaryOrder = HabitListOrder.byColorDesc;
      expect(habitList.primaryOrder, HabitListOrder.byColorDesc,
          reason: 'persistence.sqlite-habit-list-mutations#15');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#15');

      habitList.secondaryOrder = HabitListOrder.byNameDesc;
      expect(habitList.secondaryOrder, HabitListOrder.byNameDesc,
          reason: 'persistence.sqlite-habit-list-mutations#15');
      expect(notifications, 2,
          reason: 'persistence.sqlite-habit-list-mutations#15');

      expect(db.steps, isEmpty,
          reason: 'persistence.sqlite-habit-list-mutations#15');
      expect(db.prepared, isEmpty,
          reason: 'persistence.sqlite-habit-list-mutations#15');

      habitList.observable.removeListener(listener);
    });

    test('#16 resort re-sorts in memory, without loading or writing', () {
      seedTenHabits();
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      habitList.observable.addListener(listener);
      db.clearLog();

      // Corrupt the in-memory positions, then let resort() put them back in
      // order without touching the database.
      habitList.getById(1)!.position = 99;
      habitList.resort();

      expect(habitList.getByPosition(9).id, 1,
          reason: 'persistence.sqlite-habit-list-mutations#16');
      expect(notifications, 1,
          reason: 'persistence.sqlite-habit-list-mutations#16');
      expect(db.countResets(findAllSql), 0,
          reason: 'persistence.sqlite-habit-list-mutations#16');
      expect(db.steps, isEmpty,
          reason: 'persistence.sqlite-habit-list-mutations#16');

      habitList.observable.removeListener(listener);
    });
  });

  // -------------------------------------------------------------------------
  // persistence.repair-db-action
  //
  // Rule #1 lives with the presenter (`ListHabitsBehavior.onRepairDB`) and is
  // cited from `test/ui/screens/habits/list/list_habits_behavior_test.dart`;
  // everything below is the model half of the same action.
  // -------------------------------------------------------------------------
  group('persistence.repair-db-action', () {
    test('#2 repair() = loadRecords + rebuildOrder + notifyListeners', () {
      insertThreeRows();
      final list = SQLiteHabitList(factory);
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      list.observable.addListener(listener);
      db.clearLog();

      list.repair();

      // The rows are already contiguous, so nothing is rewritten and the two
      // reads can only be loadRecords() followed by rebuildOrder().
      expect(db.countResets(findAllSql), 2,
          reason: 'persistence.repair-db-action#2 — repair() loads the records '
              'first (this list had never been read) and then rebuilds the '
              'order, so findAll runs exactly twice');
      expect(db.countSteps(updateSql), 0,
          reason: 'persistence.repair-db-action#2 — rebuildOrder writes '
              'nothing when every position already matches its index');
      expect(list.size(), 3,
          reason: 'persistence.repair-db-action#2 — the load really happened: '
              'the list is populated afterwards');
      expect(notifications, 1,
          reason: 'persistence.repair-db-action#2 — repair() ends with one '
              'observable.notifyListeners()');

      list.observable.removeListener(listener);
    });

    test('#3 rebuildOrder renumbers to the 0-based ORDER BY position index',
        () {
      insertRow(name: 'A', position: 10);
      insertRow(name: 'B', position: 20);
      insertRow(name: 'C', position: 30);

      habitList.repair();

      expect(storedPositions(), [0, 1, 2],
          reason: 'persistence.repair-db-action#3 — every position becomes its '
              '0-based index in the ORDER BY position result');
      expect(repository.findAll().map((r) => r.name).toList(),
          ['A', 'B', 'C'],
          reason: 'persistence.repair-db-action#3 — the renumbering preserves '
              'the order the rows already had');
    });

    test('#3 only the rows whose position changed are written', () {
      insertRow(name: 'A', position: 0);
      insertRow(name: 'B', position: 1);
      insertRow(name: 'C', position: 2);
      habitList.size(); // load; positions are contiguous, so nothing is fixed.

      // Move one row behind the list's back, then repair.
      db.run("update Habits set position = 5 where name = 'C'");
      db.clearLog();

      habitList.repair();

      expect(db.countResets(findAllSql), 1,
          reason: 'persistence.repair-db-action#3 — the list is already '
              'loaded, so only rebuildOrder re-reads the rows');
      expect(db.countSteps(updateSql), 1,
          reason: 'persistence.repair-db-action#3 — exactly one UPDATE: the '
              'two rows that already sat at their index are not rewritten');
      expect(storedPositions(), [0, 1, 2],
          reason: 'persistence.repair-db-action#3 — and the stray row lands at '
              'index 2');

      db.clearLog();
      habitList.repair();
      expect(db.countSteps(updateSql), 0,
          reason: 'persistence.repair-db-action#3 — a second repair writes '
              'nothing at all: repair is idempotent');
    });

    test('#4 repair changes nothing but position', () {
      final habits = seedTenHabits();
      entryRepository.insert(
          EntryData(habitId: habits[0].id, timestamp: 1000, value: Entry.yesManual));
      entryRepository.insert(
          EntryData(habitId: habits[1].id, timestamp: 2000, value: Entry.skip));
      db.run('update Habits set position = 40 where id = 1');
      habitList.reload();
      final before = rowsById();

      habitList.repair();

      final after = rowsById();
      expect(after.keys.toSet(), before.keys.toSet(),
          reason: 'persistence.repair-db-action#4 — repair() deletes nothing: '
              'every habit row survives');
      expect(db.queryInt('select count(*) from Repetitions'), 2,
          reason: 'persistence.repair-db-action#4 — repair() never touches the '
              'Repetitions table');
      expect(countRepetitions(habits[0].id!), 1,
          reason: 'persistence.repair-db-action#4 — the entries of the habit '
              'that moved are left alone');
      for (final id in before.keys) {
        final b = before[id]!;
        final a = after[id]!;
        expect(
          <Object?>[
            a.name, a.description, a.question, a.freqNum, a.freqDen, a.color,
            a.reminderHour, a.reminderMin, a.reminderDays, a.highlight,
            a.archived, a.type, a.targetValue, a.targetType, a.unit, a.uuid,
          ],
          <Object?>[
            b.name, b.description, b.question, b.freqNum, b.freqDen, b.color,
            b.reminderHour, b.reminderMin, b.reminderDays, b.highlight,
            b.archived, b.type, b.targetValue, b.targetType, b.unit, b.uuid,
          ],
          reason: 'persistence.repair-db-action#4 — no field other than '
              'position changes, for habit $id',
        );
      }
      expect(storedPositions(), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'persistence.repair-db-action#4 — position is the one field '
              'repair() does change');
    });

    test('#5 the base HabitList repair() is an empty no-op', () {
      final memory = MemoryHabitList();
      final a = factory.buildHabit()..name = 'A';
      final b = factory.buildHabit()..name = 'B';
      memory.add(a);
      memory.add(b);
      a.position = 40;
      var notifications = 0;
      final listener = ModelObservableListener(() => notifications++);
      memory.observable.addListener(listener);
      db.clearLog();

      memory.repair();

      expect(notifications, 0,
          reason: 'persistence.repair-db-action#5 — MemoryHabitList inherits '
              'the empty body, so it notifies nobody');
      expect(a.position, 40,
          reason: 'persistence.repair-db-action#5 — it renumbers nothing');
      expect(memory.toList(), <Habit>[a, b],
          reason: 'persistence.repair-db-action#5 — and reorders nothing');
      expect(db.steps, isEmpty,
          reason: 'persistence.repair-db-action#5 — no SQL is issued: the base '
              'implementation has no body at all');

      memory.observable.removeListener(listener);
    });
  });

  group('persistence.schema-habits', () {
    test('#8 row to model mapping', () {
      insertRow(
        name: 'Run',
        position: 0,
        archived: 2,
        color: 11,
        freqNum: 3,
        freqDen: 7,
        type: 1,
        targetType: 1,
        targetValue: 2.5,
        unit: 'miles',
      );
      insertRow(name: 'Meditate', position: 1);

      final numerical = habitList.getByPosition(0);
      final boolean = habitList.getByPosition(1);

      // archived != 0, not archived == 1.
      expect(numerical.isArchived, isTrue,
          reason: 'persistence.schema-habits#8');
      expect(boolean.isArchived, isFalse,
          reason: 'persistence.schema-habits#8');
      expect(numerical.color, const PaletteColor(11),
          reason: 'persistence.schema-habits#8');
      expect(numerical.color.paletteIndex, 11,
          reason: 'persistence.schema-habits#8');
      expect(numerical.frequency, Frequency(3, 7),
          reason: 'persistence.schema-habits#8');
      expect(boolean.frequency, Frequency(1, 1),
          reason: 'persistence.schema-habits#8');
      expect(numerical.type, HabitType.numerical,
          reason: 'persistence.schema-habits#8');
      expect(boolean.type, HabitType.yesNo,
          reason: 'persistence.schema-habits#8');
      expect(numerical.targetType, NumericalHabitType.atMost,
          reason: 'persistence.schema-habits#8');
      expect(boolean.targetType, NumericalHabitType.atLeast,
          reason: 'persistence.schema-habits#8');
      expect(numerical.targetValue, 2.5,
          reason: 'persistence.schema-habits#8');
      expect(numerical.unit, 'miles',
          reason: 'persistence.schema-habits#8');

      // HabitType.fromInt / NumericalHabitType.fromInt reject anything else.
      db.run('update Habits set type = 9 where id = 1');
      final freshType = SQLiteHabitList(factory);
      expect(() => freshType.size(), throwsA(isA<StateError>()),
          reason: 'persistence.schema-habits#8');

      db.run('update Habits set type = 1, target_type = 9 where id = 1');
      final freshTarget = SQLiteHabitList(factory);
      expect(() => freshTarget.size(), throwsA(isA<StateError>()),
          reason: 'persistence.schema-habits#8');
    });

    test('#9 a Reminder needs both reminder_hour and reminder_min', () {
      insertRow(
          name: 'both',
          position: 0,
          reminderHour: 8,
          reminderMin: 30,
          reminderDays: 127);
      insertRow(
          name: 'no minute', position: 1, reminderHour: 8, reminderDays: 127);
      insertRow(
          name: 'no hour', position: 2, reminderMin: 30, reminderDays: 127);
      insertRow(name: 'neither', position: 3, reminderDays: 127);

      final both = habitList.getByPosition(0);
      expect(both.reminder, isNotNull,
          reason: 'persistence.schema-habits#9');
      expect(both.reminder!.hour, 8, reason: 'persistence.schema-habits#9');
      expect(both.reminder!.minute, 30, reason: 'persistence.schema-habits#9');
      expect(both.reminder!.days, WeekdayList(127),
          reason: 'persistence.schema-habits#9');
      expect(both.reminder!.days.toInteger(), 127,
          reason: 'persistence.schema-habits#9');

      // reminder_days is ignored whenever either endpoint is NULL.
      expect(habitList.getByPosition(1).reminder, isNull,
          reason: 'persistence.schema-habits#9');
      expect(habitList.getByPosition(2).reminder, isNull,
          reason: 'persistence.schema-habits#9');
      expect(habitList.getByPosition(3).reminder, isNull,
          reason: 'persistence.schema-habits#9');
      expect(habitList.getByPosition(1).hasReminder(), isFalse,
          reason: 'persistence.schema-habits#9');
    });

    test('#10 highlight is always written as 0 and never read back', () {
      final id = insertRow(name: 'A', position: 0, highlight: 99);
      expect(db.queryInt('select highlight from Habits where id = $id'), 99,
          reason: 'persistence.schema-habits#10');

      final habit = habitList.getByPosition(0);
      // Nothing in the model carries the value: copyFrom rebuilds the row with
      // highlight = 0 no matter what was stored.
      expect(SQLiteHabitList.copyFrom(habit).highlight, 0,
          reason: 'persistence.schema-habits#10');

      habitList.updateOne(habit);
      expect(db.queryInt('select highlight from Habits where id = $id'), 0,
          reason: 'persistence.schema-habits#10');

      // The column must nonetheless still exist: dropping it would break both
      // the insert and the select.
      expect(
        db.querySingle(
            "select count(*) from pragma_table_info('Habits') "
            "where name = 'highlight'",
            const [],
            (stmt) => stmt.getInt(0)),
        1,
        reason: 'persistence.schema-habits#10',
      );
    });

    test('#11 a habit with no reminder writes NULL, NULL and 0', () {
      final habit = factory.buildHabit()..name = 'no reminder';
      expect(habit.reminder, isNull, reason: 'persistence.schema-habits#11');

      habitList.add(habit);

      final row = rowsById()[habit.id]!;
      expect(row.reminderHour, isNull,
          reason: 'persistence.schema-habits#11');
      expect(row.reminderMin, isNull, reason: 'persistence.schema-habits#11');
      expect(row.reminderDays, 0, reason: 'persistence.schema-habits#11');
      expect(
        db.querySingle('select typeof(reminder_hour) from Habits where id = ?',
            ['${habit.id}'], (stmt) => stmt.getText(0)),
        'null',
        reason: 'persistence.schema-habits#11',
      );
      expect(
        db.querySingle('select typeof(reminder_min) from Habits where id = ?',
            ['${habit.id}'], (stmt) => stmt.getText(0)),
        'null',
        reason: 'persistence.schema-habits#11',
      );

      // And the day mask really is 0, not the 127 default of the column.
      expect(
        db.queryInt('select reminder_days from Habits where id = ${habit.id}'),
        0,
        reason: 'persistence.schema-habits#11',
      );
    });
  });

  // The two reorder rules that are specific to the SQLite list. The in-memory
  // half of models.habit-list-reorder lives in test/models/habit_list_test.dart;
  // these two need a database, so they are asserted here, against the same
  // recording connection the rest of this file uses.
  group('models.habit-list-reorder (SQLite)', () {
    test('#9 reorder shifts the rows in between with one bulk update, then '
        'writes the moved habit', () {
      seedTenHabits();

      // Moving up (toPos < fromPos): everything from toPos up to, but not
      // including, fromPos slides one position later.
      db.clearLog();
      final movedUp = habitList.getById(6)!; // position 5
      final targetUp = habitList.getById(3)!; // position 2
      expect(movedUp.position, 5, reason: 'models.habit-list-reorder#9');
      expect(targetUp.position, 2, reason: 'models.habit-list-reorder#9');

      habitList.reorder(movedUp, targetUp);

      expect(
        db.preparedMatching('update habits set position'),
        <String>[
          'update habits set position = position + 1 '
              'where position >= 2 and position < 5'
        ],
        reason: 'models.habit-list-reorder#9',
      );
      // Then the moved habit's own row is written with the target position.
      final afterUp = rowsById();
      expect(afterUp[6]!.position, 2, reason: 'models.habit-list-reorder#9');
      expect(afterUp[3]!.position, 3, reason: 'models.habit-list-reorder#9');
      expect(afterUp[4]!.position, 4, reason: 'models.habit-list-reorder#9');
      expect(afterUp[5]!.position, 5, reason: 'models.habit-list-reorder#9');
      expect(storedPositions(), <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'models.habit-list-reorder#9');

      // Moving down (toPos > fromPos): everything after fromPos, up to and
      // including toPos, slides one position earlier.
      db.clearLog();
      final movedDown = habitList.getById(1)!;
      final targetDown = habitList.getById(5)!;
      final fromPos = movedDown.position;
      final toPos = targetDown.position;
      expect(fromPos, 0, reason: 'models.habit-list-reorder#9');
      expect(toPos, 5, reason: 'models.habit-list-reorder#9');

      habitList.reorder(movedDown, targetDown);

      expect(
        db.preparedMatching('update habits set position'),
        <String>[
          'update habits set position = position - 1 '
              'where position > $fromPos and position <= $toPos'
        ],
        reason: 'models.habit-list-reorder#9',
      );
      final afterDown = rowsById();
      expect(afterDown[1]!.position, toPos,
          reason: 'models.habit-list-reorder#9');
      expect(afterDown[5]!.position, toPos - 1,
          reason: 'models.habit-list-reorder#9');
      expect(storedPositions(), <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'models.habit-list-reorder#9');
    });

    test('#10 repair and the load path renumber stored positions to 0..n-1, '
        'writing only the rows that do not already match', () {
      seedTenHabits();

      // Corrupt the LAST row only, so findAll()'s order is unchanged and every
      // other row already sits at its own index.
      db.run('update Habits set position = 99 where id = 10');
      habitList.reload();
      db.clearLog();

      // Reading the list is enough: the load path rebuilds the order itself.
      expect(habitList.size(), 10, reason: 'models.habit-list-reorder#10');
      expect(storedPositions(), <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'models.habit-list-reorder#10');
      expect(rowsById()[10]!.position, 9,
          reason: 'models.habit-list-reorder#10');
      // Nine rows already matched their index and were left alone.
      expect(db.countSteps(updateSql), 1,
          reason: 'models.habit-list-reorder#10');

      // repair() does the same thing on demand, and writes nothing at all when
      // every stored position already matches its row index.
      db.clearLog();
      habitList.repair();
      expect(db.countSteps(updateSql), 0,
          reason: 'models.habit-list-reorder#10');
      expect(storedPositions(), <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'models.habit-list-reorder#10');

      // Pushing the FIRST row to the back shifts every index, so all ten rows
      // are rewritten — and the result is still exactly 0..n-1.
      db.run('update Habits set position = 40 where id = 1');
      db.clearLog();
      habitList.repair();
      expect(db.countSteps(updateSql), 10,
          reason: 'models.habit-list-reorder#10');
      expect(storedPositions(), <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
          reason: 'models.habit-list-reorder#10');
      expect(rowsById()[1]!.position, 9,
          reason: 'models.habit-list-reorder#10');
      expect(rowsById()[2]!.position, 0,
          reason: 'models.habit-list-reorder#10');
    });
  });
}

String _collapse(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();

/// A [ModelFactory] that counts the habits it builds, so the lazy load can be
/// observed from the outside.
class _CountingModelFactory extends SQLModelFactory {
  _CountingModelFactory(super.database);

  int buildHabitCount = 0;

  @override
  Habit buildHabit() {
    buildHabitCount++;
    return super.buildHabit();
  }
}

/// A [Database] that logs every statement it prepares, resets and steps, so the
/// tests can count the lazy loads and pin down the raw SQL the habit list
/// issues.
class _RecordingDatabase implements Database {
  _RecordingDatabase(this._inner);

  final Database _inner;

  final List<String> prepared = <String>[];
  final List<String> resets = <String>[];
  final List<String> steps = <String>[];

  String? _hookNeedle;
  void Function()? _hookAction;

  /// Runs [action] just before the first `step()` of a statement whose SQL
  /// contains [needle], then forgets the hook.
  void hookOnceBeforeStep(String needle, void Function() action) {
    _hookNeedle = needle;
    _hookAction = action;
  }

  void clearLog() {
    prepared.clear();
    resets.clear();
    steps.clear();
  }

  int countResets(String needle) =>
      resets.where((sql) => _collapse(sql).contains(needle)).length;

  int countSteps(String needle) =>
      steps.where((sql) => _collapse(sql).contains(needle)).length;

  List<String> preparedMatching(String needle) =>
      prepared.where((sql) => _collapse(sql).contains(needle)).toList();

  void _recordReset(String sql) => resets.add(sql);

  void _recordStep(String sql) {
    final needle = _hookNeedle;
    final action = _hookAction;
    if (needle != null && action != null && _collapse(sql).contains(needle)) {
      _hookNeedle = null;
      _hookAction = null;
      action();
    }
    steps.add(sql);
  }

  @override
  PreparedStatement prepareStatement(String sql) {
    prepared.add(sql);
    return _RecordingStatement(this, sql, _inner.prepareStatement(sql));
  }

  @override
  void close() => _inner.close();
}

class _RecordingStatement implements PreparedStatement {
  _RecordingStatement(this._db, this._sql, this._inner);

  final _RecordingDatabase _db;
  final String _sql;
  final PreparedStatement _inner;

  @override
  StepResult step() {
    _db._recordStep(_sql);
    return _inner.step();
  }

  @override
  void reset() {
    _db._recordReset(_sql);
    _inner.reset();
  }

  @override
  int getInt(int index) => _inner.getInt(index);

  @override
  int getLong(int index) => _inner.getLong(index);

  @override
  double getReal(int index) => _inner.getReal(index);

  @override
  String getText(int index) => _inner.getText(index);

  @override
  int? getIntOrNull(int index) => _inner.getIntOrNull(index);

  @override
  int? getLongOrNull(int index) => _inner.getLongOrNull(index);

  @override
  double? getRealOrNull(int index) => _inner.getRealOrNull(index);

  @override
  String? getTextOrNull(int index) => _inner.getTextOrNull(index);

  @override
  void bindInt(int index, int value) => _inner.bindInt(index, value);

  @override
  void bindLong(int index, int value) => _inner.bindLong(index, value);

  @override
  void bindReal(int index, double value) => _inner.bindReal(index, value);

  @override
  void bindText(int index, String value) => _inner.bindText(index, value);

  @override
  void bindNull(int index) => _inner.bindNull(index);

  @override
  void finalizeStatement() => _inner.finalizeStatement();
}
