/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateRepetitionCommand.kt
/// (plus .../models/Entry.kt, .../models/EntryList.kt,
/// .../models/sqlite/SQLiteEntryList.kt, .../models/HabitList.kt,
/// .../models/memory/MemoryHabitList.kt) and their Kotlin tests
/// (.../commonTest/.../commands/CreateRepetitionCommandTest.kt,
/// .../commonTest/.../ui/widgets/WidgetBehaviorTest.kt,
/// .../commonTest/.../ui/screens/habits/list/HabitCardListCacheTest.kt).
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/entry_repository.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_observable.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_entry_list.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';

import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// An [EntryList] that appends every mutation it receives to a shared log.
///
/// `recomputeFrom` calls `clear()` and `add()` on itself, and those calls
/// dispatch back through these overrides, so the log also shows what
/// `Habit.recompute()` did to the derived list.
class _LoggingEntryList extends EntryList {
  _LoggingEntryList(this.log, this.label);

  final List<String> log;
  final String label;

  @override
  void add(Entry entry) {
    log.add('$label.add');
    super.add(entry);
  }

  @override
  void clear() {
    log.add('$label.clear');
    super.clear();
  }

  @override
  void recomputeFrom(
    EntryList originalEntries,
    Frequency frequency, {
    required bool isNumerical,
  }) {
    log.add('$label.recomputeFrom');
    super.recomputeFrom(originalEntries, frequency, isNumerical: isNumerical);
  }
}

/// A [Habit] that records each `recompute()` call.
class _LoggingHabit extends Habit {
  _LoggingHabit(
    this.log, {
    required super.computedEntries,
    required super.originalEntries,
    required super.scores,
    required super.streaks,
    super.name,
  });

  final List<String> log;
  int recomputeCount = 0;

  @override
  void recompute() {
    recomputeCount++;
    log.add('habit.recompute');
    super.recompute();
  }
}

/// A [MemoryHabitList] that records `resort`, `update` and `updateOne`.
class _LoggingHabitList extends MemoryHabitList {
  _LoggingHabitList(this.log);

  final List<String> log;
  int resortCount = 0;
  int updateCount = 0;
  int updateOneCount = 0;
  final List<List<Habit>> updateArgs = <List<Habit>>[];

  @override
  void resort() {
    resortCount++;
    log.add('habitList.resort');
    super.resort();
  }

  @override
  void update(List<Habit> habits) {
    updateCount++;
    updateArgs.add(habits);
    log.add('habitList.update');
    super.update(habits);
  }

  @override
  void updateOne(Habit habit) {
    updateOneCount++;
    log.add('habitList.updateOne');
    super.updateOne(habit);
  }
}

/// Records the exact order in which [SQLiteEntryList] drives the repository.
class _SpyEntryRepository extends EntryRepository {
  _SpyEntryRepository(super.db);

  final List<String> log = <String>[];

  @override
  void deleteByHabitIdAndTimestamp(int habitId, int timestamp) {
    log.add('deleteByHabitIdAndTimestamp($habitId, $timestamp)');
    super.deleteByHabitIdAndTimestamp(habitId, timestamp);
  }

  @override
  int insert(EntryData data) {
    log.add('insert(${data.habitId}, ${data.timestamp}, '
        '${data.value}, ${data.notes})');
    return super.insert(data);
  }
}

/// Stands in for the commands that mutate the list itself (CreateHabitCommand
/// and DeleteHabitsCommand call `habitList.add` / `habitList.remove`). Those
/// live in other slices, so the shape is reproduced locally rather than
/// stubbed.
class _ListMutatingCommand implements Command {
  _ListMutatingCommand(this.habitList, this.habit);

  final HabitList habitList;
  final Habit habit;

  @override
  void run() {
    habitList.add(habit);
  }
}

/// Inserts a bare Habits row so the `habit` foreign key of Repetitions
/// resolves (migration 22 turns `pragma foreign_keys` ON).
int _insertTestHabit(Database db, {String name = 'Test'}) {
  db.run(
    'insert into Habits(name, freq_num, freq_den, color, position, archived, '
    "type) values ('$name', 1, 1, 0, 0, 0, 0)",
  );
  return db.queryLong('select last_insert_rowid()');
}

void main() {
  // -------------------------------------------------------------------------
  // BaseUnitTest.setUp, inlined (commands.test-harness), followed by
  // CreateRepetitionCommandTest.setUp.
  // -------------------------------------------------------------------------
  late MemoryModelFactory memoryModelFactory;
  late HabitList habitList;
  late HabitFixtures fixtures;
  late TaskRunner taskRunner;
  late CommandRunner commandRunner;
  late List<String> log;

  late Habit habit;
  late LocalDate today;
  late CreateRepetitionCommand command;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    memoryModelFactory = MemoryModelFactory();
    habitList = memoryModelFactory.buildHabitList();
    fixtures = HabitFixtures(memoryModelFactory, habitList);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = CommandRunner(taskRunner);
    log = <String>[];

    habit = fixtures.createShortHabit();
    habitList.add(habit);
    today = getToday();
    command = CreateRepetitionCommand(habitList, habit, today, 100, '');
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // commands.create-repetition
  // -------------------------------------------------------------------------
  group('commands.create-repetition', () {
    test('constructor takes habitList, habit, date, value, notes in order', () {
      final cmd = CreateRepetitionCommand(habitList, habit, today, 100, 'note');

      expect(
        cmd.habitList,
        same(habitList),
        reason: 'commands.create-repetition#1 — component1 is habitList',
      );
      expect(
        cmd.habit,
        same(habit),
        reason: 'commands.create-repetition#1 — component2 is habit; listeners '
            'read command.habit for a targeted refresh',
      );
      expect(
        cmd.date,
        today,
        reason: 'commands.create-repetition#1 — component3 is date',
      );
      expect(
        cmd.value,
        100,
        reason: 'commands.create-repetition#1 — component4 is value',
      );
      expect(
        cmd.notes,
        'note',
        reason: 'commands.create-repetition#1 — component5 is notes',
      );
      expect(
        cmd,
        isA<Command>(),
        reason: 'commands.create-repetition#1 — it is a Command',
      );
    });

    test('run does exactly add, recompute, resort, in that order', () {
      final ordered = <String>[];
      final original = _LoggingEntryList(ordered, 'originalEntries');
      final computed = _LoggingEntryList(ordered, 'computedEntries');
      final h = _LoggingHabit(
        ordered,
        computedEntries: computed,
        originalEntries: original,
        scores: ScoreList(),
        streaks: StreakList(),
        name: 'Meditate',
      );
      final list = _LoggingHabitList(ordered);
      list.add(h);
      // MemoryHabitList.add resorts; only what the command itself does counts.
      list.resortCount = 0;
      ordered.clear();

      CreateRepetitionCommand(list, h, today, Entry.yesManual, '').run();

      expect(
        ordered
            .where((e) => <String>[
                  'originalEntries.add',
                  'habit.recompute',
                  'habitList.resort',
                ].contains(e))
            .toList(),
        <String>[
          'originalEntries.add',
          'habit.recompute',
          'habitList.resort',
        ],
        reason: 'commands.create-repetition#2 — run() performs exactly three '
            'steps in order: originalEntries.add(Entry(date, value, notes)), '
            'habit.recompute(), habitList.resort()',
      );
      expect(
        h.recomputeCount,
        1,
        reason: 'commands.create-repetition#2 — recompute() runs exactly once',
      );
      expect(
        list.resortCount,
        1,
        reason: 'commands.create-repetition#2 — resort() runs exactly once',
      );
      expect(
        original.get(today),
        Entry(today, Entry.yesManual),
        reason: 'commands.create-repetition#2 — step (1) adds exactly '
            'Entry(date, value, notes)',
      );
    });

    test('run upserts: an existing entry for the same date is replaced', () {
      // Kotlin CreateRepetitionCommandTest.testExecute, line for line.
      final entries = habit.originalEntries;
      var entry = entries.get(today);
      expect(
        entry.value,
        Entry.yesManual,
        reason: 'commands.create-repetition#3 — the short-habit fixture starts '
            'from Entry.YES_MANUAL on today',
      );

      command.run();

      entry = entries.get(today);
      expect(
        entry.value,
        100,
        reason: 'commands.create-repetition#3 — after running with value=100 '
            'the value becomes 100',
      );
      expect(
        entries.getKnown().where((e) => e.date == today).length,
        1,
        reason: 'commands.create-repetition#3 — EntryList.add stores by date in '
            'a HashMap, so the old entry is replaced, not appended',
      );

      CreateRepetitionCommand(habitList, habit, today, Entry.no, 'replaced')
          .run();
      expect(
        entries.get(today).notes,
        'replaced',
        reason: 'commands.create-repetition#3 — notes are overwritten too',
      );
      expect(
        entries.get(today).value,
        Entry.no,
        reason: 'commands.create-repetition#3 — value is overwritten too',
      );

      CreateRepetitionCommand(habitList, habit, today, Entry.no, '').run();
      expect(
        entries.get(today).notes,
        '',
        reason: 'commands.create-repetition#3 — replacing with empty notes '
            'clears the previous notes; the whole Entry is replaced',
      );
    });

    test('an entry is removed by writing NO or UNKNOWN', () {
      CreateRepetitionCommand(habitList, habit, today, Entry.no, '').run();
      expect(
        habit.originalEntries.get(today).value,
        Entry.no,
        reason: 'commands.create-repetition#4 — there is no delete-repetition '
            'command; writing Entry.NO (0) is how a repetition is removed',
      );
      expect(
        habit.computedEntries.get(today).value,
        Entry.no,
        reason: 'commands.create-repetition#4 — the checkmark is gone after '
            'writing Entry.NO',
      );

      CreateRepetitionCommand(habitList, habit, today, Entry.unknown, '').run();
      expect(
        habit.originalEntries.get(today).value,
        Entry.unknown,
        reason: 'commands.create-repetition#4 — writing Entry.UNKNOWN (-1) is '
            'the other way to remove a repetition',
      );
      expect(
        habit.computedEntries.get(today).value,
        Entry.unknown,
        reason: 'commands.create-repetition#4 — an UNKNOWN original entry with '
            'empty notes drops out of computedEntries entirely',
      );
    });

    test('value is an Entry constant, or thousandths for numerical habits', () {
      expect(
        <int>[
          Entry.unknown,
          Entry.no,
          Entry.yesAuto,
          Entry.yesManual,
          Entry.skip,
        ],
        <int>[-1, 0, 1, 2, 3],
        reason: 'commands.create-repetition#5 — UNKNOWN = -1, NO = 0, '
            'YES_AUTO = 1, YES_MANUAL = 2, SKIP = 3',
      );

      for (final v in <int>[
        Entry.unknown,
        Entry.no,
        Entry.yesAuto,
        Entry.yesManual,
        Entry.skip,
      ]) {
        CreateRepetitionCommand(habitList, habit, today, v, '').run();
        expect(
          habit.originalEntries.get(today).value,
          v,
          reason: 'commands.create-repetition#5 — a YES_NO habit stores the '
              'Entry constant verbatim',
        );
      }

      // ListHabitsBehavior.onEdit / HistoryCard.showNumberPopup:
      // `val value = (newValue * 1000).roundToInt()`.
      final numerical = fixtures.createNumericalHabit();
      habitList.add(numerical);
      const userValue = 2.5;
      final thousands = (userValue * 1000).round();
      expect(
        thousands,
        2500,
        reason: 'commands.create-repetition#5 — for NUMERICAL habits the value '
            'is the user value in thousandths, (userValue * 1000).roundToInt()',
      );

      CreateRepetitionCommand(habitList, numerical, today, thousands, '').run();
      expect(
        numerical.originalEntries.get(today).value,
        2500,
        reason: 'commands.create-repetition#5 — the thousandths value is stored '
            'verbatim for a NUMERICAL habit',
      );
      expect(
        numerical.computedEntries.get(today).value / 1000.0,
        2.5,
        reason: 'commands.create-repetition#5 — reading it back divides by 1000',
      );
    });

    test('writes originalEntries only; recompute rebuilds the rest', () {
      final ordered = <String>[];
      final original = _LoggingEntryList(ordered, 'originalEntries');
      final computed = _LoggingEntryList(ordered, 'computedEntries');
      final h = _LoggingHabit(
        ordered,
        computedEntries: computed,
        originalEntries: original,
        scores: ScoreList(),
        streaks: StreakList(),
        name: 'Meditate',
      );
      final list = MemoryHabitList()..add(h);
      for (var i = 1; i <= 5; i++) {
        original.add(Entry(today.minus(i), Entry.yesManual));
      }
      h.recompute();
      final scoreBefore = h.scores[today].value;
      final bestBefore = h.streaks.getBest(1).first.length;
      ordered.clear();

      CreateRepetitionCommand(list, h, today, Entry.yesManual, '').run();

      expect(
        ordered.first,
        'originalEntries.add',
        reason: 'commands.create-repetition#6 — the command writes to '
            'originalEntries, and that write is its first action',
      );
      expect(
        ordered.where((e) => e.startsWith('computedEntries')).first,
        'computedEntries.recomputeFrom',
        reason: 'commands.create-repetition#6 — computedEntries is never '
            'written by the command; it is only touched via recomputeFrom',
      );
      expect(
        h.computedEntries.get(today).value,
        Entry.yesManual,
        reason: 'commands.create-repetition#6 — computedEntries is regenerated '
            'by step (2) recompute()',
      );
      expect(
        h.scores[today].value,
        greaterThan(scoreBefore),
        reason: 'commands.create-repetition#6 — recompute() also recomputes '
            'scores',
      );
      expect(
        h.streaks.getBest(1).first.length,
        bestBefore + 1,
        reason: 'commands.create-repetition#6 — recompute() also recomputes '
            'streaks',
      );
    });

    test('SQLite persistence deletes then inserts, one row per habit/date', () {
      final db = openMigratedDatabase();
      addTearDown(db.close);
      final repo = _SpyEntryRepository(db);
      final habitId = _insertTestHabit(db);
      final entries = SQLiteEntryList(repo)..habitId = habitId;
      final h = Habit(
        computedEntries: EntryList(),
        originalEntries: entries,
        scores: ScoreList(),
        streaks: StreakList(),
        id: habitId,
        name: 'Wake up early',
      );
      final list = MemoryHabitList()..add(h);

      CreateRepetitionCommand(list, h, today, Entry.yesManual, 'first').run();
      CreateRepetitionCommand(list, h, today, Entry.no, 'second').run();

      expect(
        repo.log,
        <String>[
          'deleteByHabitIdAndTimestamp($habitId, ${today.unixTime})',
          'insert($habitId, ${today.unixTime}, ${Entry.yesManual}, first)',
          'deleteByHabitIdAndTimestamp($habitId, ${today.unixTime})',
          'insert($habitId, ${today.unixTime}, ${Entry.no}, second)',
        ],
        reason: 'commands.create-repetition#7 — SQLiteEntryList.add persists by '
            'first deleteByHabitIdAndTimestamp(habitId, date.unixTime) and then '
            'inserting EntryData(habitId, timestamp, value, notes)',
      );
      expect(
        db.queryInt('select count(*) from Repetitions where habit = $habitId'),
        1,
        reason: 'commands.create-repetition#7 — at most one repetition row per '
            '(habit, date) can exist',
      );
      expect(
        db.queryInt(
          'select value from Repetitions where habit = $habitId '
          'and timestamp = ${today.unixTime}',
        ),
        Entry.no,
        reason: 'commands.create-repetition#7 — the surviving row carries the '
            'newest value',
      );
    });

    test('does not call habitList.update, only habitList.resort', () {
      final list = _LoggingHabitList(log);
      list.add(habit);
      log.clear();

      CreateRepetitionCommand(list, habit, today, 100, '').run();

      expect(
        list.updateCount,
        0,
        reason: 'commands.create-repetition#8 — the command does NOT call '
            'habitList.update(...), so no habit row is written',
      );
      expect(
        list.updateOneCount,
        0,
        reason: 'commands.create-repetition#8 — nor the single-habit overload',
      );
      expect(
        log,
        <String>['habitList.resort'],
        reason: 'commands.create-repetition#8 — only the repetitions table '
            'changes; the list is merely resorted',
      );
    });

    test('resort matters because BY_SCORE and BY_STATUS read today', () {
      final statusList = MemoryHabitList();
      final a1 = fixtures.createEmptyHabit(name: 'A', position: 0);
      final b1 = fixtures.createEmptyHabit(name: 'B', position: 1);
      statusList
        ..add(a1)
        ..add(b1)
        ..primaryOrder = HabitListOrder.byStatusDesc;
      expect(
        statusList.map((h) => h.name).toList(),
        <String>['A', 'B'],
        reason: 'commands.create-repetition#9 — baseline: neither habit is '
            'completed today, so the secondary BY_NAME_ASC order applies',
      );

      CreateRepetitionCommand(statusList, b1, today, Entry.yesManual, '').run();
      expect(
        statusList.map((h) => h.name).toList(),
        <String>['B', 'A'],
        reason: 'commands.create-repetition#9 — habitList.resort() is called '
            'even though no habit field changed, because BY_STATUS depends on '
            "today's entry value",
      );

      final scoreList = MemoryHabitList();
      final a2 = fixtures.createEmptyHabit(name: 'A', position: 0);
      final b2 = fixtures.createEmptyHabit(name: 'B', position: 1);
      scoreList
        ..add(a2)
        ..add(b2)
        ..primaryOrder = HabitListOrder.byScoreAsc;
      expect(
        scoreList.map((h) => h.name).toList(),
        <String>['A', 'B'],
        reason: 'commands.create-repetition#9 — baseline: both scores are 0',
      );

      CreateRepetitionCommand(scoreList, b2, today, Entry.yesManual, '').run();
      expect(
        scoreList.map((h) => h.name).toList(),
        <String>['B', 'A'],
        reason: 'commands.create-repetition#9 — BY_SCORE likewise depends on '
            "today's entry value, so the resort is not a no-op",
      );
    });

    test('notes are stored verbatim and preserved by value-only callers', () {
      const weird = '  spaced, "quoted"\n note ';
      CreateRepetitionCommand(habitList, habit, today, Entry.yesManual, weird)
          .run();
      expect(
        habit.originalEntries.get(today).notes,
        weird,
        reason: 'commands.create-repetition#10 — notes are stored verbatim',
      );

      CreateRepetitionCommand(habitList, habit, today, Entry.yesManual, '')
          .run();
      expect(
        habit.originalEntries.get(today).notes,
        '',
        reason: 'commands.create-repetition#10 — notes may be the empty string',
      );

      // WidgetBehavior.toggle / ListHabitsBehavior.onToggle: a caller that only
      // changes the value passes the existing entry.notes straight through.
      CreateRepetitionCommand(habitList, habit, today, Entry.yesManual, 'keep')
          .run();
      final entry = habit.computedEntries.get(today);
      final nextValue = Entry.nextToggleValue(
        entry.value,
        isSkipEnabled: false,
        areQuestionMarksEnabled: false,
      );
      CreateRepetitionCommand(habitList, habit, today, nextValue, entry.notes)
          .run();
      expect(
        habit.originalEntries.get(today).notes,
        'keep',
        reason: 'commands.create-repetition#10 — callers that only change the '
            'value pass through the existing entry.notes, so notes survive',
      );
      expect(
        habit.originalEntries.get(today).value,
        Entry.no,
        reason: 'commands.create-repetition#10 — while the value does change',
      );
    });

    test('the runner path notifies listeners with this very command', () {
      final seen = <Command>[];
      commandRunner.addListener(_RecordingListener(seen));

      commandRunner.run(command);

      expect(
        habit.originalEntries.get(today).value,
        100,
        reason: 'commands.create-repetition#2 — the same three steps run when '
            'the command is dispatched through the CommandRunner',
      );
      expect(
        seen.single,
        same(command),
        reason: 'commands.create-repetition#1 — listeners receive the command '
            'instance itself, which is how they reach component2 (habit)',
      );
    });

    test('it is the only command listeners special-case for a targeted '
        'refresh', () {
      final other = fixtures.createShortHabit();
      other.name = 'Other';
      habitList.add(other);
      final cache = HabitCardListCache(
        habitList,
        commandRunner,
        taskRunner,
        StandardLogging(out: StringBuffer(), err: StringBuffer()),
      );
      cache.onAttached();
      final cachedOther = cache.getScore(other.id!);

      // Both habits change behind the cache's back, so a full refresh and a
      // targeted one are told apart by what the cache picks up.
      habit.originalEntries.add(Entry(today.minus(1), Entry.yesManual));
      habit.recompute();
      other.originalEntries.add(Entry(today.minus(1), Entry.yesManual));
      other.recompute();

      commandRunner
          .run(CreateRepetitionCommand(habitList, habit, today, 100, ''));

      expect(
        cache.getScore(habit.id!),
        habit.scores[today].value,
        reason: 'commands.create-repetition#11 — listeners special-case this '
            "command and refresh only command.habit — the cache's entry for it "
            'is up to date',
      );
      expect(
        cache.getScore(other.id!),
        cachedOther,
        reason: 'commands.create-repetition#11 — the refresh is targeted at a '
            'single habit, so every other habit keeps its stale cached data',
      );

      commandRunner.run(_NoOpCommand());

      expect(
        cache.getScore(other.id!),
        other.scores[today].value,
        reason: 'commands.create-repetition#11 — every OTHER command falls '
            'through to a full refresh, which does pick the other habit up',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.list-mutations-triggered
  // -------------------------------------------------------------------------
  group('commands.list-mutations-triggered', () {
    test('update(habit) delegates to update(listOf(habit))', () {
      final list = _LoggingHabitList(log);
      list.add(habit);
      list.updateArgs.clear();

      list.updateOne(habit);

      expect(
        list.updateCount,
        1,
        reason: 'commands.list-mutations-triggered#1 — HabitList.update(habit) '
            'is a convenience that delegates to update(listOf(habit))',
      );
      expect(
        list.updateArgs.single.length,
        1,
        reason: 'commands.list-mutations-triggered#1 — the delegate receives a '
            'single-element list',
      );
      expect(
        list.updateArgs.single.single,
        same(habit),
        reason: 'commands.list-mutations-triggered#1 — holding exactly the '
            'habit it was given',
      );
    });

    test('MemoryHabitList.update ignores its argument and resorts', () {
      final list = MemoryHabitList();
      final a = fixtures.createEmptyHabit(name: 'A', position: 0);
      final b = fixtures.createEmptyHabit(name: 'B', position: 1);
      final stranger = fixtures.createEmptyHabit(name: 'Z', position: 9);
      list
        ..add(a)
        ..add(b)
        ..primaryOrder = HabitListOrder.byNameAsc;
      // Make the list stale without telling it.
      a.name = 'Zzz';
      var notifications = 0;
      list.observable.addListener(ModelObservableListener(() => notifications++));

      list.update(<Habit>[stranger]);

      expect(
        list.map((h) => h.name).toList(),
        <String>['B', 'Zzz'],
        reason: 'commands.list-mutations-triggered#2 — '
            'MemoryHabitList.update(habits) just calls resort(), which sorts '
            'with the current comparator',
      );
      expect(
        list.size(),
        2,
        reason: 'commands.list-mutations-triggered#2 — the argument is ignored '
            'entirely; the stranger habit is not added',
      );
      expect(
        notifications,
        1,
        reason: 'commands.list-mutations-triggered#2 — resort() fires the list '
            'observable exactly once',
      );
    });

    test('resort sorts in place with the composed comparator and notifies', () {
      final list = MemoryHabitList();
      final a = fixtures.createEmptyHabit(name: 'A', position: 0);
      final b = fixtures.createEmptyHabit(name: 'B', position: 1);
      list
        ..add(a)
        ..add(b)
        ..primaryOrder = HabitListOrder.byNameAsc;
      a.name = 'Zzz';
      var notifications = 0;
      list.observable.addListener(ModelObservableListener(() => notifications++));

      list.resort();

      expect(
        list.map((h) => h.name).toList(),
        <String>['B', 'Zzz'],
        reason: 'commands.list-mutations-triggered#4 — resort() on '
            'MemoryHabitList sorts in place with the composed comparator',
      );
      expect(
        identical(list.getByPosition(0), b),
        isTrue,
        reason: 'commands.list-mutations-triggered#4 — in place: the same Habit '
            'instances are reordered, not copies',
      );
      expect(
        notifications,
        1,
        reason: 'commands.list-mutations-triggered#4 — and fires the observable',
      );
    });

    test('the comparator is primaryOrder then secondaryOrder', () {
      final list = MemoryHabitList();
      expect(
        list.primaryOrder,
        HabitListOrder.byPosition,
        reason: 'commands.list-mutations-triggered#5 — default primaryOrder is '
            'BY_POSITION',
      );
      expect(
        list.secondaryOrder,
        HabitListOrder.byNameAsc,
        reason: 'commands.list-mutations-triggered#5 — default secondaryOrder '
            'is BY_NAME_ASC',
      );

      final zebra = fixtures.createEmptyHabit(name: 'Zebra', position: 0);
      final apple = fixtures.createEmptyHabit(name: 'Apple', position: 0);
      list
        ..add(zebra)
        ..add(apple);
      expect(
        list.map((h) => h.name).toList(),
        <String>['Apple', 'Zebra'],
        reason: 'commands.list-mutations-triggered#5 — when the primary '
            'comparison returns 0 the secondary comparator breaks the tie',
      );

      zebra.position = -1;
      list.resort();
      expect(
        list.map((h) => h.name).toList(),
        <String>['Zebra', 'Apple'],
        reason: 'commands.list-mutations-triggered#5 — a non-zero primary '
            'comparison wins and the secondary order is never consulted',
      );
    });

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
        reason: 'commands.list-mutations-triggered#6 — Order enum values are '
            'exactly BY_NAME_ASC, BY_NAME_DESC, BY_COLOR_ASC, BY_COLOR_DESC, '
            'BY_SCORE_ASC, BY_SCORE_DESC, BY_STATUS_ASC, BY_STATUS_DESC, '
            'BY_POSITION',
      );
    });

    test('filtered sublists throw from add, remove and reorder', () {
      final root = MemoryHabitList();
      final a = fixtures.createEmptyHabit(name: 'A', position: 0);
      final b = fixtures.createEmptyHabit(name: 'B', position: 1);
      final c = fixtures.createEmptyHabit(name: 'C', position: 2);
      root
        ..add(a)
        ..add(b);
      final filtered =
          root.getFiltered(const HabitMatcher(isArchivedAllowed: true));

      expect(
        () => filtered.add(c),
        throwsA(isA<StateError>()),
        reason: 'commands.list-mutations-triggered#7 — filtered sublists throw '
            'IllegalStateException from add',
      );
      expect(
        () => filtered.remove(a),
        throwsA(isA<StateError>()),
        reason: 'commands.list-mutations-triggered#7 — and from remove',
      );
      expect(
        () => filtered.reorder(a, b),
        throwsA(isA<StateError>()),
        reason: 'commands.list-mutations-triggered#7 — and from reorder',
      );
    });

    test('a list-mutating command throws when given a filtered list', () {
      final root = MemoryHabitList();
      final a = fixtures.createEmptyHabit(name: 'A', position: 0);
      final c = fixtures.createEmptyHabit(name: 'C', position: 2);
      root.add(a);
      final filtered =
          root.getFiltered(const HabitMatcher(isArchivedAllowed: true));

      expect(
        () => _ListMutatingCommand(filtered, c).run(),
        throwsA(isA<StateError>()),
        reason: 'commands.list-mutations-triggered#8 — because commands hold '
            'the HabitList reference directly, running one on a filtered list '
            'throws; all call sites inject the root list',
      );
      expect(
        root.size(),
        1,
        reason: 'commands.list-mutations-triggered#8 — and nothing reaches the '
            'root list either',
      );
      expect(
        () =>
            CreateRepetitionCommand(filtered, a, today, Entry.yesManual, '').run(),
        returnsNormally,
        reason: 'commands.list-mutations-triggered#8 — the exception comes from '
            'add/remove/reorder only: CreateRepetitionCommand touches the list '
            'through resort(), which filtered sublists do allow',
      );
    });

    test('SQLiteHabitList.update notifies the inner list, then writes, then '
        'notifies the outer one', () {
      final db = openMigratedDatabase();
      addTearDown(db.close);
      final factory = SQLModelFactory(db);
      final SQLiteHabitList list = factory.buildHabitList();
      final a = factory.buildHabit()..name = 'A';
      final b = factory.buildHabit()..name = 'B';
      list
        ..add(a)
        ..add(b);
      // Filtered sublists are exactly what listens to the INNER observable.
      final sublist =
          list.getFiltered(const HabitMatcher(isArchivedAllowed: true));

      String storedNames() => factory.habitRepository
          .findAll()
          .map((r) => r.name)
          .join(',');

      final events = <String>[];
      sublist.observable.addListener(
        ModelObservableListener(() => events.add('inner(${storedNames()})')),
      );
      list.observable.addListener(
        ModelObservableListener(() => events.add('outer(${storedNames()})')),
      );

      a.name = 'A2';
      b.name = 'B2';
      list.update(<Habit>[a, b]);

      expect(
        events,
        <String>['inner(A,B)', 'outer(A2,B2)'],
        reason: 'commands.list-mutations-triggered#3 — SQLiteHabitList.update '
            'first runs list.update(habits) on the inner MemoryHabitList, '
            'which resorts and fires the INNER observable that filtered '
            'sublists listen to (the rows are still the old ones then); only '
            'afterwards does it issue one repository.update(copyFrom(h)) per '
            'habit and fire the OUTER observable',
      );
      expect(
        events.length,
        2,
        reason: 'commands.list-mutations-triggered#3 — so one '
            'Archive/Unarchive/ChangeColor command produces multiple '
            'observable notifications, not one',
      );
      expect(
        sublist.map((h) => h.name).toList(),
        <String>['A2', 'B2'],
        reason: 'commands.list-mutations-triggered#3 — the inner list holds '
            'the very same Habit instances, so the sublist sees the edit',
      );
    });
  });
}

/// A command that does nothing at all, used to show what listeners do with
/// anything that is not a CreateRepetitionCommand.
class _NoOpCommand implements Command {
  @override
  void run() {}
}

/// Minimal [CommandRunnerListener] used by the dispatch test.
class _RecordingListener implements CommandRunnerListener {
  _RecordingListener(this.seen);

  final List<Command> seen;

  @override
  void onCommandFinished(Command command) {
    seen.add(command);
  }
}
