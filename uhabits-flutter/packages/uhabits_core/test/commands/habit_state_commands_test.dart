import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_observable.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/ArchiveHabitsCommand.kt,
/// .../commands/UnarchiveHabitsCommand.kt, .../commands/ChangeHabitColorCommand.kt
/// and their tests (.../commonTest/.../commands/ArchiveHabitsCommandTest.kt,
/// .../UnarchiveHabitsCommandTest.kt, .../ChangeHabitColorCommandTest.kt).
///
/// Every `expect` carries the parity-ledger rule id it exercises.

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A [MemoryHabitList] that records what `update()` was called with, what the
/// selected habits looked like *at the moment of the call*, and how many times
/// `resort()` ran.
///
/// It is a real MemoryHabitList — every call is forwarded to `super` — so the
/// observable behaviour under test is the production one; the subclass only
/// watches.
class _RecordingHabitList extends MemoryHabitList {
  /// One entry per `update()` call, holding the very list instance passed in.
  final List<List<Habit>> updateCalls = <List<Habit>>[];

  /// `isArchived` of every habit in the argument, sampled inside `update()`,
  /// i.e. after the command's loop and before the list has done anything.
  final List<List<bool>> archivedAtUpdate = <List<bool>>[];

  /// `color` of every habit in the argument, sampled inside `update()`.
  final List<List<PaletteColor>> colorsAtUpdate = <List<PaletteColor>>[];

  int resortCount = 0;

  @override
  void update(List<Habit> habits) {
    updateCalls.add(habits);
    archivedAtUpdate.add(<bool>[for (final h in habits) h.isArchived]);
    colorsAtUpdate.add(<PaletteColor>[for (final h in habits) h.color]);
    super.update(habits);
  }

  @override
  void resort() {
    resortCount++;
    super.resort();
  }

  /// Forgets everything recorded so far, so that a test can ignore the
  /// `resort()` calls that `add()` makes while the fixture is being built.
  void resetRecording() {
    updateCalls.clear();
    archivedAtUpdate.clear();
    colorsAtUpdate.clear();
    resortCount = 0;
  }
}

/// A [Habit] that counts `recompute()` calls, so that "the command does not
/// call recompute()" can be asserted directly rather than inferred.
class _RecomputeCountingHabit extends Habit {
  _RecomputeCountingHabit({
    required super.computedEntries,
    required super.originalEntries,
    required super.scores,
    required super.streaks,
  });

  int recomputeCount = 0;

  @override
  void recompute() {
    recomputeCount++;
    super.recompute();
  }
}

void main() {
  // -------------------------------------------------------------------------
  // BaseUnitTest.setUp, inlined (commands.test-harness).
  //
  // The only deviation is that `habitList` is a _RecordingHabitList rather than
  // `memoryModelFactory.buildHabitList()`: it is still a MemoryHabitList, it
  // just also records the update/resort traffic these rules are about.
  // -------------------------------------------------------------------------
  late MemoryModelFactory memoryModelFactory;
  late _RecordingHabitList habitList;
  late HabitFixtures fixtures;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    memoryModelFactory = MemoryModelFactory();
    habitList = _RecordingHabitList();
    fixtures = HabitFixtures(memoryModelFactory, habitList);
  });

  tearDown(resetToday);

  /// Builds a habit with a distinctive value in every field the state commands
  /// must NOT touch, and with real entries/scores/streaks behind it.
  _RecomputeCountingHabit buildDecoratedHabit() {
    final habit = _RecomputeCountingHabit(
      computedEntries: memoryModelFactory.buildComputedEntries(),
      originalEntries: memoryModelFactory.buildOriginalEntries(),
      scores: memoryModelFactory.buildScoreList(),
      streaks: memoryModelFactory.buildStreakList(),
    );
    habit.name = 'Wake up early';
    habit.question = 'Did you wake up before 6am?';
    habit.description = 'Sleep is important';
    habit.color = const PaletteColor(3);
    habit.position = 7;
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    habit.frequency = Frequency(2, 3);
    var timestamp = getToday();
    for (var i = 0; i < 10; i++) {
      habit.originalEntries.add(
        Entry(timestamp, i.isEven ? Entry.yesManual : Entry.no),
      );
      timestamp = timestamp.minus(1);
    }
    habit.recompute();
    // recomputeCount is deliberately left at 1: the assertions below check
    // that it is still exactly 1 afterwards, which proves both that the
    // counter is live and that the command added nothing to it.
    return habit;
  }

  // ===========================================================================
  // commands.archive-habits
  // ===========================================================================
  group('commands.archive-habits', () {
    test('constructor takes (habitList, selected), in that order', () {
      final habit = fixtures.createShortHabit();
      habitList.add(habit);
      final selected = <Habit>[habit];

      final command = ArchiveHabitsCommand(habitList, selected);

      expect(
        command.habitList,
        same(habitList),
        reason: 'commands.archive-habits#1 — the first constructor component '
            'is habitList',
      );
      expect(
        command.selected,
        same(selected),
        reason: 'commands.archive-habits#1 — the second constructor component '
            'is selected, held by reference and not copied',
      );
      expect(
        command,
        isA<Command>(),
        reason: 'commands.archive-habits#1 — ArchiveHabitsCommand is a Command',
      );
    });

    test('ArchiveHabitsCommandTest.testExecute', () {
      final habit = fixtures.createShortHabit();
      habitList.add(habit);
      final command = ArchiveHabitsCommand(habitList, <Habit>[habit]);

      expect(
        habit.isArchived,
        isFalse,
        reason: 'commands.archive-habits#2 — assertFalse(habit.isArchived) '
            'before run(), as in ArchiveHabitsCommandTest',
      );
      command.run();
      expect(
        habit.isArchived,
        isTrue,
        reason: 'commands.archive-habits#2 — assertTrue(habit.isArchived) '
            'after run(), as in ArchiveHabitsCommandTest',
      );
    });

    test('run() archives every selected habit, then updates exactly once', () {
      final h1 = fixtures.createShortHabit();
      final h2 = fixtures.createShortHabit();
      final other = fixtures.createShortHabit();
      habitList.add(h1);
      habitList.add(h2);
      habitList.add(other);
      final selected = <Habit>[h1, h2];
      habitList.resetRecording();

      ArchiveHabitsCommand(habitList, selected).run();

      expect(
        <bool>[h1.isArchived, h2.isArchived],
        <bool>[true, true],
        reason: 'commands.archive-habits#2 — `for (h in selected) '
            'h.isArchived = true` sets every selected habit',
      );
      expect(
        other.isArchived,
        isFalse,
        reason: 'commands.archive-habits#2 — the loop runs over `selected`, '
            'not over the whole list',
      );
      expect(
        habitList.updateCalls,
        hasLength(1),
        reason: 'commands.archive-habits#2 — ONE call to habitList.update, '
            'not one per habit',
      );
      expect(
        habitList.updateCalls.single,
        same(selected),
        reason: 'commands.archive-habits#2 — update() receives the very '
            '`selected` list the command was built with',
      );
      expect(
        habitList.archivedAtUpdate.single,
        <bool>[true, true],
        reason: 'commands.archive-habits#2 — the loop completes before the '
            'single update() call, so update sees the archived state',
      );
    });

    test('archiving an already-archived habit is idempotent, and still '
        'updates', () {
      final habit = fixtures.createShortHabit();
      habit.isArchived = true;
      habitList.add(habit);
      habitList.resetRecording();
      final command = ArchiveHabitsCommand(habitList, <Habit>[habit]);

      command.run();

      expect(
        habit.isArchived,
        isTrue,
        reason: 'commands.archive-habits#3 — archiving an already-archived '
            'habit leaves isArchived == true',
      );
      expect(
        habitList.updateCalls,
        hasLength(1),
        reason: 'commands.archive-habits#3 — the update/persist still happens, '
            'there is no no-op short circuit',
      );

      command.run();

      expect(
        habit.isArchived,
        isTrue,
        reason: 'commands.archive-habits#3 — running the same command twice is '
            'idempotent',
      );
      expect(
        habitList.updateCalls,
        hasLength(2),
        reason: 'commands.archive-habits#3 — and still performs the update '
            'every time',
      );
    });

    test('run() touches nothing but isArchived, and never recomputes', () {
      final habit = buildDecoratedHabit();
      habitList.add(habit);
      final originalBefore = List<Entry>.from(habit.originalEntries.getKnown());
      final computedBefore = List<Entry>.from(habit.computedEntries.getKnown());
      final scoreBefore = habit.scores[getToday()];
      final streaksBefore = List<Streak>.from(habit.streaks.getBest(10));
      habitList.resetRecording();

      ArchiveHabitsCommand(habitList, <Habit>[habit]).run();

      expect(
        habit.recomputeCount,
        1,
        reason: 'commands.archive-habits#4 — the counter is live (it recorded '
            'the single recompute() the fixture itself made) and the command '
            'added nothing to it: it does not call recompute()',
      );
      expect(
        habit.originalEntries.getKnown(),
        originalBefore,
        reason: 'commands.archive-habits#4 — it does not touch entries',
      );
      expect(
        habit.computedEntries.getKnown(),
        computedBefore,
        reason: 'commands.archive-habits#4 — it does not touch the computed '
            'entries either',
      );
      expect(
        habit.scores[getToday()],
        scoreBefore,
        reason: 'commands.archive-habits#4 — it does not touch scores',
      );
      expect(
        habit.streaks.getBest(10),
        streaksBefore,
        reason: 'commands.archive-habits#4 — it does not touch streaks',
      );
      expect(
        habit.color,
        const PaletteColor(3),
        reason: 'commands.archive-habits#4 — it does not touch colors',
      );
      expect(
        habit.position,
        7,
        reason: 'commands.archive-habits#4 — it does not touch positions',
      );
      expect(
        habit.reminder,
        Reminder(8, 30, WeekdayList.everyDay),
        reason: 'commands.archive-habits#4 — it does not touch reminders',
      );
      expect(
        habit.name,
        'Wake up early',
        reason: 'commands.archive-habits#4 — it does not touch names',
      );
    });

    test('the single update() resorts and notifies the list observable', () {
      final habit = fixtures.createShortHabit();
      habitList.add(habit);
      final active = habitList.getFiltered(const HabitMatcher());
      expect(
        active.size(),
        1,
        reason: 'commands.archive-habits#5 — precondition: before the command '
            'runs, the filtered active list still contains the habit',
      );
      var notifications = 0;
      habitList.observable
          .addListener(ModelObservableListener(() => notifications++));
      habitList.resetRecording();

      ArchiveHabitsCommand(habitList, <Habit>[habit]).run();

      expect(
        habitList.updateCalls,
        hasLength(1),
        reason: 'commands.archive-habits#5 — a single habitList.update(selected)'
            ' call carries every selected habit',
      );
      expect(
        habitList.resortCount,
        1,
        reason: 'commands.archive-habits#5 — that one update triggers a resort',
      );
      expect(
        notifications,
        1,
        reason: 'commands.archive-habits#5 — ... plus list-observable '
            'notifications',
      );
      expect(
        active.size(),
        0,
        reason: 'commands.archive-habits#5 — the notification reaches the '
            'observers: the filtered active list drops the archived habit',
      );
    });

    test('an empty selection still updates, resorts and notifies', () {
      habitList.add(fixtures.createShortHabit());
      var notifications = 0;
      habitList.observable
          .addListener(ModelObservableListener(() => notifications++));
      habitList.resetRecording();
      final selected = <Habit>[];

      ArchiveHabitsCommand(habitList, selected).run();

      expect(
        habitList.updateCalls,
        hasLength(1),
        reason: 'commands.archive-habits#6 — an empty `selected` list still '
            'calls habitList.update(emptyList())',
      );
      expect(
        habitList.updateCalls.single,
        isEmpty,
        reason: 'commands.archive-habits#6 — with the empty list itself',
      );
      expect(
        habitList.resortCount,
        1,
        reason: 'commands.archive-habits#6 — which still resorts',
      );
      expect(
        notifications,
        1,
        reason: 'commands.archive-habits#6 — and still notifies',
      );
    });
  });

  // ===========================================================================
  // commands.unarchive-habits
  // ===========================================================================
  group('commands.unarchive-habits', () {
    test('constructor takes (habitList, selected), in that order', () {
      final habit = fixtures.createShortHabit();
      habitList.add(habit);
      final selected = <Habit>[habit];

      final command = UnarchiveHabitsCommand(habitList, selected);

      expect(
        command.habitList,
        same(habitList),
        reason: 'commands.unarchive-habits#1 — the first constructor component '
            'is habitList',
      );
      expect(
        command.selected,
        same(selected),
        reason: 'commands.unarchive-habits#1 — the second constructor '
            'component is selected, held by reference and not copied',
      );
      expect(
        command,
        isA<Command>(),
        reason: 'commands.unarchive-habits#1 — UnarchiveHabitsCommand is a '
            'Command',
      );
    });

    test('UnarchiveHabitsCommandTest.testExecuteUndoRedo', () {
      final habit = fixtures.createShortHabit();
      habit.isArchived = true;
      habitList.add(habit);
      final command = UnarchiveHabitsCommand(habitList, <Habit>[habit]);

      expect(
        habit.isArchived,
        isTrue,
        reason: 'commands.unarchive-habits#2 — assertTrue(habit.isArchived) '
            'before run(), as in UnarchiveHabitsCommandTest',
      );
      command.run();
      expect(
        habit.isArchived,
        isFalse,
        reason: 'commands.unarchive-habits#2 — assertFalse(habit.isArchived) '
            'after run(), as in UnarchiveHabitsCommandTest',
      );
    });

    test('run() unarchives every selected habit, then updates exactly once',
        () {
      final h1 = fixtures.createShortHabit()..isArchived = true;
      final h2 = fixtures.createShortHabit()..isArchived = true;
      final other = fixtures.createShortHabit()..isArchived = true;
      habitList.add(h1);
      habitList.add(h2);
      habitList.add(other);
      final selected = <Habit>[h1, h2];
      habitList.resetRecording();

      UnarchiveHabitsCommand(habitList, selected).run();

      expect(
        <bool>[h1.isArchived, h2.isArchived],
        <bool>[false, false],
        reason: 'commands.unarchive-habits#2 — `for (h in selected) '
            'h.isArchived = false` clears every selected habit',
      );
      expect(
        other.isArchived,
        isTrue,
        reason: 'commands.unarchive-habits#2 — the loop runs over `selected`, '
            'not over the whole list',
      );
      expect(
        habitList.updateCalls,
        hasLength(1),
        reason: 'commands.unarchive-habits#2 — ONE call to habitList.update, '
            'not one per habit',
      );
      expect(
        habitList.updateCalls.single,
        same(selected),
        reason: 'commands.unarchive-habits#2 — update() receives the very '
            '`selected` list the command was built with',
      );
      expect(
        habitList.archivedAtUpdate.single,
        <bool>[false, false],
        reason: 'commands.unarchive-habits#2 — the loop completes before the '
            'single update() call',
      );
    });

    test('it mirrors ArchiveHabitsCommand but is a plain forward command, not '
        'an undo', () {
      final habit = fixtures.createShortHabit();
      habitList.add(habit);
      final selected = <Habit>[habit];
      final archive = ArchiveHabitsCommand(habitList, selected);
      final unarchive = UnarchiveHabitsCommand(habitList, selected);
      habitList.resetRecording();

      expect(
        <Type>[archive.habitList.runtimeType, unarchive.habitList.runtimeType],
        <Type>[_RecordingHabitList, _RecordingHabitList],
        reason: 'commands.unarchive-habits#3 — the exact structural mirror: '
            'same (habitList, selected) shape',
      );
      expect(
        unarchive.selected,
        same(archive.selected),
        reason: 'commands.unarchive-habits#3 — same `selected` component',
      );

      // Neither command knows anything about the other: each is issued by the
      // user and applies its own boolean, as many times as the user likes.
      final states = <bool>[];
      for (final command in <Command>[archive, unarchive, archive, unarchive]) {
        command.run();
        states.add(habit.isArchived);
      }

      expect(
        states,
        <bool>[true, false, true, false],
        reason: 'commands.unarchive-habits#3 — the only difference is the '
            'boolean written; both are ordinary forward commands, replayable '
            'in any order',
      );
      expect(
        habitList.updateCalls,
        hasLength(4),
        reason: 'commands.unarchive-habits#3 — each run persists again; there '
            'is no undo history that would collapse the pairs',
      );
      expect(
        unarchive,
        isA<Command>(),
        reason: 'commands.unarchive-habits#3 — it implements the same Command '
            'interface, whose only member is run(): there is no undo() to be '
            'wired as',
      );
    });

    test('unarchiving is idempotent and touches nothing else', () {
      final habit = buildDecoratedHabit();
      habitList.add(habit);
      final originalBefore = List<Entry>.from(habit.originalEntries.getKnown());
      final computedBefore = List<Entry>.from(habit.computedEntries.getKnown());
      final scoreBefore = habit.scores[getToday()];
      final streaksBefore = List<Streak>.from(habit.streaks.getBest(10));
      habitList.resetRecording();
      final command = UnarchiveHabitsCommand(habitList, <Habit>[habit]);

      // The habit was never archived to begin with.
      command.run();
      command.run();

      expect(
        habit.isArchived,
        isFalse,
        reason: 'commands.unarchive-habits#4 — unarchiving is idempotent',
      );
      expect(
        habitList.updateCalls,
        hasLength(2),
        reason: 'commands.unarchive-habits#4 — and still persists every time',
      );
      expect(
        habit.recomputeCount,
        1,
        reason: 'commands.unarchive-habits#4 — the counter is live (it '
            'recorded the single recompute() the fixture itself made) and the '
            'command added nothing to it: it does not call recompute()',
      );
      expect(
        habit.originalEntries.getKnown(),
        originalBefore,
        reason: 'commands.unarchive-habits#4 — it touches nothing else on the '
            'habit: entries are untouched',
      );
      expect(
        habit.computedEntries.getKnown(),
        computedBefore,
        reason: 'commands.unarchive-habits#4 — computed entries are untouched',
      );
      expect(
        habit.scores[getToday()],
        scoreBefore,
        reason: 'commands.unarchive-habits#4 — scores are untouched',
      );
      expect(
        habit.streaks.getBest(10),
        streaksBefore,
        reason: 'commands.unarchive-habits#4 — streaks are untouched',
      );
      expect(
        <Object?>[habit.color, habit.position, habit.reminder, habit.name],
        <Object?>[
          const PaletteColor(3),
          7,
          Reminder(8, 30, WeekdayList.everyDay),
          'Wake up early',
        ],
        reason: 'commands.unarchive-habits#4 — colour, position, reminder and '
            'name are untouched',
      );
    });
  });

  // ===========================================================================
  // commands.change-habit-color
  // ===========================================================================
  group('commands.change-habit-color', () {
    test('constructor takes (habitList, selected, newColor), in that order',
        () {
      final habit = fixtures.createShortHabit();
      habitList.add(habit);
      final selected = <Habit>[habit];
      final newColor = PaletteColor(0);

      final command = ChangeHabitColorCommand(habitList, selected, newColor);

      expect(
        command.habitList,
        same(habitList),
        reason: 'commands.change-habit-color#1 — the first constructor '
            'component is habitList',
      );
      expect(
        command.selected,
        same(selected),
        reason: 'commands.change-habit-color#1 — the second constructor '
            'component is selected',
      );
      expect(
        command.newColor,
        same(newColor),
        reason: 'commands.change-habit-color#1 — the third constructor '
            'component is newColor',
      );
      expect(
        command,
        isA<Command>(),
        reason: 'commands.change-habit-color#1 — ChangeHabitColorCommand is a '
            'Command',
      );
    });

    test('run() recolours every selected habit, then updates exactly once', () {
      final h1 = fixtures.createShortHabit();
      final h2 = fixtures.createShortHabit();
      final other = fixtures.createShortHabit();
      habitList.add(h1);
      habitList.add(h2);
      habitList.add(other);
      final selected = <Habit>[h1, h2];
      habitList.resetRecording();

      ChangeHabitColorCommand(habitList, selected, PaletteColor(5)).run();

      expect(
        <PaletteColor>[h1.color, h2.color],
        <PaletteColor>[const PaletteColor(5), const PaletteColor(5)],
        reason: 'commands.change-habit-color#2 — `for (h in selected) '
            'h.color = newColor` recolours every selected habit',
      );
      expect(
        other.color,
        const PaletteColor(8),
        reason: 'commands.change-habit-color#2 — the loop runs over '
            '`selected`, not over the whole list',
      );
      expect(
        habitList.updateCalls,
        hasLength(1),
        reason: 'commands.change-habit-color#2 — ONE call to habitList.update, '
            'not one per habit',
      );
      expect(
        habitList.updateCalls.single,
        same(selected),
        reason: 'commands.change-habit-color#2 — update() receives the very '
            '`selected` list the command was built with',
      );
      expect(
        habitList.colorsAtUpdate.single,
        <PaletteColor>[const PaletteColor(5), const PaletteColor(5)],
        reason: 'commands.change-habit-color#2 — the loop completes before the '
            'single update() call',
      );
    });

    test('ChangeHabitColorCommandTest.testExecute', () {
      final selected = <Habit>[];
      for (var i = 0; i <= 2; i++) {
        final habit = fixtures.createShortHabit();
        habit.color = PaletteColor(i + 1);
        selected.add(habit);
        habitList.add(habit);
      }
      final newColor = PaletteColor(0);
      final command = ChangeHabitColorCommand(habitList, selected, newColor);

      var k = 0;
      for (final habit in selected) {
        expect(
          habit.color,
          PaletteColor(++k),
          reason: 'commands.change-habit-color#3 — checkOriginalColors(): the '
              'three habits start at PaletteColor(1), (2) and (3)',
        );
      }

      command.run();

      for (final habit in selected) {
        expect(
          habit.color,
          const PaletteColor(0),
          reason: 'commands.change-habit-color#3 — checkNewColors(): all three '
              'become PaletteColor(0) regardless of their previous colour',
        );
        expect(
          habit.color,
          same(newColor),
          reason: 'commands.change-habit-color#3 — every selected habit ends '
              'up with the identical PaletteColor instance',
        );
      }
    });

    test('the default colour is PaletteColor(8) and indices well above 8 are '
        'valid', () {
      final habit = memoryModelFactory.buildHabit();
      final fixtureHabit = fixtures.createShortHabit();
      habitList.add(habit);
      habitList.add(fixtureHabit);

      expect(
        habit.color,
        const PaletteColor(8),
        reason: 'commands.change-habit-color#4 — the default habit colour is '
            'PaletteColor(8)',
      );
      expect(
        fixtureHabit.color,
        const PaletteColor(8),
        reason: 'commands.change-habit-color#4 — the fixtures inherit that '
            'same default',
      );

      ChangeHabitColorCommand(habitList, <Habit>[habit], PaletteColor(30))
          .run();

      expect(
        habit.color,
        const PaletteColor(30),
        reason: 'commands.change-habit-color#4 — the picker returns '
            'PaletteColor(30) in the Kotlin tests, proving palette indices '
            'well above 8 are valid',
      );
    });

    test('run() writes only the colour, and never recomputes', () {
      final habit = buildDecoratedHabit();
      habit.isArchived = true;
      habitList.add(habit);
      final originalBefore = List<Entry>.from(habit.originalEntries.getKnown());
      final computedBefore = List<Entry>.from(habit.computedEntries.getKnown());
      final scoreBefore = habit.scores[getToday()];
      final streaksBefore = List<Streak>.from(habit.streaks.getBest(10));
      habitList.resetRecording();

      ChangeHabitColorCommand(habitList, <Habit>[habit], PaletteColor(12))
          .run();

      expect(
        habit.color,
        const PaletteColor(12),
        reason: 'commands.change-habit-color#5 — it writes the `color` column',
      );
      expect(
        habit.recomputeCount,
        1,
        reason: 'commands.change-habit-color#5 — the counter is live (it '
            'recorded the single recompute() the fixture itself made) and the '
            'command added nothing to it: recompute() is not called',
      );
      expect(
        habit.originalEntries.getKnown(),
        originalBefore,
        reason: 'commands.change-habit-color#5 — entries are untouched',
      );
      expect(
        habit.computedEntries.getKnown(),
        computedBefore,
        reason: 'commands.change-habit-color#5 — computed entries are '
            'untouched',
      );
      expect(
        habit.scores[getToday()],
        scoreBefore,
        reason: 'commands.change-habit-color#5 — scores are untouched',
      );
      expect(
        habit.streaks.getBest(10),
        streaksBefore,
        reason: 'commands.change-habit-color#5 — streaks are untouched',
      );
      expect(
        habit.isArchived,
        isTrue,
        reason: 'commands.change-habit-color#5 — archived state is untouched',
      );
    });
  });
}
