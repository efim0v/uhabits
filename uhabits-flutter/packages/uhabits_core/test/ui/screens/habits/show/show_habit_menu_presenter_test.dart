import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit_menu_presenter.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt
/// and its test
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenterTest.kt
///
/// The Kotlin test only covers `onEditHabit` and `onExportCSV`; everything
/// else here is derived from the parity ledger, and every `expect` carries the
/// rule id it exercises.
///
/// Kotlin mocks the two nested interfaces with mokkery. Dart has no such thing
/// here, so they are implemented by hand-rolled fakes that also record the
/// *order* of the calls, which is what several of the rules are about.
///
/// `onRandomize` reads a [math.Random]. Kotlin reaches for the global
/// `kotlin.random.Random`, which no test can steer; the Dart port takes the
/// generator as an optional constructor argument so the sequence of
/// `nextDouble`/`nextInt` values can be scripted and the generated entries
/// checked exactly.

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Stands in for `mock<ShowHabitMenuPresenter.Screen>()`.
class _FakeScreen implements ShowHabitMenuPresenterScreen {
  _FakeScreen(this._log);

  final List<String> _log;

  /// One entry per `showEditHabitScreen` call, holding the argument instance.
  final List<Habit> editScreenCalls = <Habit>[];

  final List<ShowHabitMenuPresenterMessage?> messages =
      <ShowHabitMenuPresenterMessage?>[];

  final List<String> sendFileCalls = <String>[];

  int deleteConfirmationCount = 0;

  /// `true` taps Yes immediately; `false` leaves the dialog unanswered, which
  /// is what both "No" and a dismissal do.
  bool confirmDelete = false;

  void Function()? pendingDeleteCallback;

  int closeCount = 0;

  int refreshCount = 0;

  /// The habit whose recomputed state is sampled when [refresh] is called, so
  /// that "recompute() happens before refresh()" can be asserted.
  Habit? watched;

  /// `watched.computedEntries.get(probeDate).value` as of the last [refresh].
  int? computedValueAtRefresh;

  LocalDate? probeDate;

  @override
  void showEditHabitScreen(Habit habit) {
    editScreenCalls.add(habit);
    _log.add('showEditHabitScreen');
  }

  @override
  void showMessage(ShowHabitMenuPresenterMessage? m) {
    messages.add(m);
    _log.add('showMessage:$m');
  }

  @override
  void showSendFileScreen(String filename) {
    sendFileCalls.add(filename);
    _log.add('showSendFileScreen');
  }

  @override
  void showDeleteConfirmationScreen(void Function() callback) {
    deleteConfirmationCount++;
    pendingDeleteCallback = callback;
    _log.add('showDeleteConfirmationScreen');
    if (confirmDelete) callback();
  }

  @override
  void close() {
    closeCount++;
    _log.add('close');
  }

  @override
  void refresh() {
    refreshCount++;
    _log.add('refresh');
    final habit = watched;
    final date = probeDate;
    if (habit != null && date != null) {
      computedValueAtRefresh = habit.computedEntries.get(date).value;
    }
  }
}

/// Stands in for `mock<ShowHabitMenuPresenter.System>()`.
///
/// Only `onExportCSV` ever calls it, and the CSV export rules belong to
/// another slice, so nothing in this file drives it.
class _FakeSystem implements ShowHabitMenuPresenterSystem {
  @override
  UserFile getCSVOutputDir() =>
      throw UnsupportedError('CSV export is not exercised by this test');
}

/// A real [CommandRunner] — the commands genuinely run, as they do in
/// `BaseUnitTest` with its unconfined dispatchers — that also records what it
/// was asked to dispatch and when.
class _RecordingCommandRunner extends CommandRunner {
  _RecordingCommandRunner(super.taskRunner, this._log);

  final List<String> _log;

  final List<Command> commands = <Command>[];

  @override
  void run(Command command) {
    commands.add(command);
    _log.add('run:${command.runtimeType}');
    super.run(command);
  }
}

/// Records `update()` so that "…and persists them" can be asserted directly.
class _RecordingHabitList extends MemoryHabitList {
  final List<List<Habit>> updateCalls = <List<Habit>>[];

  @override
  void update(List<Habit> habits) {
    updateCalls.add(habits);
    super.update(habits);
  }
}

/// Records every command the runner announces as finished.
class _RecordingListener implements CommandRunnerListener {
  final List<Command> finished = <Command>[];

  @override
  void onCommandFinished(Command command) {
    finished.add(command);
  }
}

/// A [math.Random] whose output is a script: the first doubles come from
/// [doubles], everything after that is [fallbackDouble], and every `nextInt`
/// returns the constant [roll].
///
/// The two are scripted separately because the presenter interleaves them: two
/// doubles per Box-Muller sample, one int per day.
class _ScriptedRandom implements math.Random {
  _ScriptedRandom({
    this.doubles = const <double>[],
    this.fallbackDouble = 0.5,
    this.roll = 0,
  });

  final List<double> doubles;

  final double fallbackDouble;

  /// What every `nextInt(100)` returns, i.e. the daily roll of
  /// `Random.nextInt(100) > strength`.
  final int roll;

  int doubleCalls = 0;

  /// The `max` argument of every `nextInt` call.
  final List<int> intBounds = <int>[];

  @override
  double nextDouble() {
    final i = doubleCalls++;
    return i < doubles.length ? doubles[i] : fallbackDouble;
  }

  @override
  int nextInt(int max) {
    intBounds.add(max);
    return roll;
  }

  @override
  bool nextBool() =>
      throw UnsupportedError('ShowHabitMenuPresenter never calls nextBool');
}

void main() {
  // -------------------------------------------------------------------------
  // BaseUnitTest.setUp plus ShowHabitMenuPresenterTest.setUp, inlined
  // -------------------------------------------------------------------------
  late _RecordingHabitList habitList;
  late HabitFixtures fixtures;
  late TaskRunner taskRunner;
  late _RecordingCommandRunner commandRunner;
  late _RecordingListener listener;
  late List<String> log;
  late _FakeScreen screen;
  late _FakeSystem system;
  late Habit habit;
  late ShowHabitMenuPresenter menu;
  late LocalDate today;

  /// Builds a presenter for [h], optionally with a scripted generator.
  ShowHabitMenuPresenter presenterFor(Habit h, {math.Random? random}) =>
      ShowHabitMenuPresenter(
        commandRunner: commandRunner,
        habit: h,
        habitList: habitList,
        screen: screen,
        system: system,
        taskRunner: taskRunner,
        random: random,
      );

  setUp(() {
    today = LocalDate.ymd(2015, 1, 25);
    setToday(today);
    final modelFactory = MemoryModelFactory();
    habitList = _RecordingHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    log = <String>[];
    commandRunner = _RecordingCommandRunner(taskRunner, log);
    listener = _RecordingListener();
    commandRunner.addListener(listener);
    screen = _FakeScreen(log);
    system = _FakeSystem();
    habit = fixtures.createShortHabit();
    habitList.add(habit);
    menu = presenterFor(habit);
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // Menu item visibility
  // -------------------------------------------------------------------------

  test('canArchive is the negation of isArchived', () {
    habit.isArchived = false;
    expect(menu.canArchive(), isTrue,
        reason: 'show-habit.menu#3 — the Archive item is visible only when '
            'the habit is NOT archived (canArchive() == !habit.isArchived)');
    habit.isArchived = true;
    expect(menu.canArchive(), isFalse,
        reason: 'show-habit.menu#3 — the Archive item is visible only when '
            'the habit is NOT archived (canArchive() == !habit.isArchived)');
  });

  test('canUnarchive mirrors isArchived', () {
    habit.isArchived = false;
    expect(menu.canUnarchive(), isFalse,
        reason: 'show-habit.menu#4 — the Unarchive item is visible only when '
            'the habit IS archived (canUnarchive() == habit.isArchived)');
    habit.isArchived = true;
    expect(menu.canUnarchive(), isTrue,
        reason: 'show-habit.menu#4 — the Unarchive item is visible only when '
            'the habit IS archived (canUnarchive() == habit.isArchived)');
  });

  // -------------------------------------------------------------------------
  // Edit
  // -------------------------------------------------------------------------

  test('onEditHabit opens the editor and does nothing else', () {
    menu.onEditHabit();

    expect(screen.editScreenCalls, hasLength(1),
        reason: 'show-habit.edit-action#1 — selecting Edit calls '
            'ShowHabitMenuPresenter.onEditHabit(), which calls '
            'screen.showEditHabitScreen(habit)');
    expect(identical(screen.editScreenCalls.single, habit), isTrue,
        reason: 'show-habit.edit-action#1 — screen.showEditHabitScreen is '
            'handed the presenter\'s own habit instance');
    expect(commandRunner.commands, isEmpty,
        reason: 'show-habit.edit-action#1 — onEditHabit calls '
            'showEditHabitScreen and nothing else (no command)');
    expect(log, <String>['showEditHabitScreen'],
        reason: 'show-habit.edit-action#1 — onEditHabit calls '
            'showEditHabitScreen and nothing else (no state change)');
    expect(screen.closeCount, 0,
        reason: 'show-habit.edit-action#3 — the show screen is NOT finished '
            'when the editor is opened (the presenter never calls close)');
  });

  // -------------------------------------------------------------------------
  // Archive / unarchive
  // -------------------------------------------------------------------------

  test('onArchiveHabits archives the habit and reports it', () {
    habit.isArchived = false;

    menu.onArchiveHabits();

    expect(commandRunner.commands, hasLength(1),
        reason: 'show-habit.archive-unarchive#1 — Archive runs '
            'ArchiveHabitsCommand(habitList, listOf(habit))');
    final command = commandRunner.commands.single;
    expect(command, isA<ArchiveHabitsCommand>(),
        reason: 'show-habit.archive-unarchive#1 — Archive runs '
            'ArchiveHabitsCommand(habitList, listOf(habit))');
    expect(
        command,
        equals(ArchiveHabitsCommand(habitList, <Habit>[habit])),
        reason: 'show-habit.archive-unarchive#1 — the command is built with '
            'this habitList and the single habit wrapped in a list');
    expect(habit.isArchived, isTrue,
        reason: 'show-habit.archive-unarchive#1 — the command sets '
            'habit.isArchived = true');
    expect(habitList.updateCalls, hasLength(1),
        reason: 'show-habit.archive-unarchive#1 — the command calls '
            'habitList.update(list)');
    expect(habitList.updateCalls.single, <Habit>[habit],
        reason: 'show-habit.archive-unarchive#1 — habitList.update is called '
            'with the same one-element list');
    expect(screen.messages, <ShowHabitMenuPresenterMessage>[
      ShowHabitMenuPresenterMessage.habitArchived
    ],
        reason: 'show-habit.archive-unarchive#1 — then shows the message '
            'HABIT_ARCHIVED');
    expect(log, <String>[
      'run:ArchiveHabitsCommand',
      'showMessage:${ShowHabitMenuPresenterMessage.habitArchived}',
    ],
        reason: 'show-habit.archive-unarchive#1 — the command is dispatched '
            'first and the message shown after');
    expect(screen.closeCount, 0,
        reason: 'show-habit.archive-unarchive#4 — archiving does not close '
            'the screen');
    expect(screen.refreshCount, 0,
        reason: 'show-habit.archive-unarchive#4 — the presenter itself never '
            'refreshes; the refresh comes from the finished command');
  });

  test('onUnarchiveHabits unarchives the habit and reports it', () {
    habit.isArchived = true;

    menu.onUnarchiveHabits();

    expect(commandRunner.commands, hasLength(1),
        reason: 'show-habit.archive-unarchive#2 — Unarchive runs '
            'UnarchiveHabitsCommand(habitList, listOf(habit))');
    final command = commandRunner.commands.single;
    expect(command, isA<UnarchiveHabitsCommand>(),
        reason: 'show-habit.archive-unarchive#2 — Unarchive runs '
            'UnarchiveHabitsCommand(habitList, listOf(habit))');
    expect(
        command,
        equals(UnarchiveHabitsCommand(habitList, <Habit>[habit])),
        reason: 'show-habit.archive-unarchive#2 — the command is built with '
            'this habitList and the single habit wrapped in a list');
    expect(habit.isArchived, isFalse,
        reason: 'show-habit.archive-unarchive#2 — the command sets '
            'habit.isArchived = false');
    expect(habitList.updateCalls, hasLength(1),
        reason: 'show-habit.archive-unarchive#2 — the command calls '
            'habitList.update(list)');
    expect(habitList.updateCalls.single, <Habit>[habit],
        reason: 'show-habit.archive-unarchive#2 — habitList.update is called '
            'with the same one-element list');
    expect(screen.messages, <ShowHabitMenuPresenterMessage>[
      ShowHabitMenuPresenterMessage.habitUnarchived
    ],
        reason: 'show-habit.archive-unarchive#2 — then shows the message '
            'HABIT_UNARCHIVED');
    expect(log, <String>[
      'run:UnarchiveHabitsCommand',
      'showMessage:${ShowHabitMenuPresenterMessage.habitUnarchived}',
    ],
        reason: 'show-habit.archive-unarchive#2 — the command is dispatched '
            'first and the message shown after');
    expect(screen.closeCount, 0,
        reason: 'show-habit.archive-unarchive#4 — unarchiving does not close '
            'the screen');
  });

  test('the three menu messages are exactly the ported enum', () {
    expect(ShowHabitMenuPresenterMessage.values, <ShowHabitMenuPresenterMessage>[
      ShowHabitMenuPresenterMessage.couldNotExport,
      ShowHabitMenuPresenterMessage.habitArchived,
      ShowHabitMenuPresenterMessage.habitUnarchived,
    ],
        reason: 'show-habit.archive-unarchive#1 and '
            'show-habit.archive-unarchive#2 — HABIT_ARCHIVED and '
            'HABIT_UNARCHIVED are the two messages these actions can show');
  });

  // -------------------------------------------------------------------------
  // Delete
  // -------------------------------------------------------------------------

  test('onDeleteHabit asks for confirmation before anything else', () {
    screen.confirmDelete = false;

    menu.onDeleteHabit();

    expect(screen.deleteConfirmationCount, 1,
        reason: 'show-habit.delete#1 — selecting Delete first opens a '
            'confirmation dialog');
    expect(log, <String>['showDeleteConfirmationScreen'],
        reason: 'show-habit.delete#1 — the confirmation is the only thing '
            'that happens at selection time');
    expect(commandRunner.commands, isEmpty,
        reason: 'show-habit.delete#2 — pressing "No" (or dismissing) does '
            'nothing at all: no command is run');
    expect(screen.closeCount, 0,
        reason: 'show-habit.delete#2 — pressing "No" (or dismissing) leaves '
            'the screen open');
    expect(habitList.contains(habit), isTrue,
        reason: 'show-habit.delete#2 — the habit survives an unconfirmed '
            'delete');
  });

  test('onDeleteHabit deletes and closes once confirmed', () {
    screen.confirmDelete = true;

    menu.onDeleteHabit();

    expect(commandRunner.commands, hasLength(1),
        reason: 'show-habit.delete#3 — pressing "Yes" runs '
            'DeleteHabitsCommand(habitList, listOf(habit))');
    expect(
        commandRunner.commands.single,
        equals(DeleteHabitsCommand(habitList, <Habit>[habit])),
        reason: 'show-habit.delete#3 — pressing "Yes" runs '
            'DeleteHabitsCommand(habitList, listOf(habit))');
    expect(habitList.contains(habit), isFalse,
        reason: 'show-habit.delete#3 — the command calls habitList.remove '
            'for the habit');
    expect(screen.closeCount, 1,
        reason: 'show-habit.delete#3 — and then immediately closes the show '
            'screen');
    expect(log, <String>[
      'showDeleteConfirmationScreen',
      'run:DeleteHabitsCommand',
      'close',
    ],
        reason: 'show-habit.delete#3 — the confirmation comes first, then '
            'the command, then the close');
  });

  // -------------------------------------------------------------------------
  // Randomize
  // -------------------------------------------------------------------------

  test('onRandomize replaces the entries with five years of days', () {
    // A distinctive entry outside the generated window, to prove the clear.
    habit.originalEntries.add(Entry(today.minus(3000), Entry.yesManual));
    // gaussian == -1.1774100225154747 on every draw, so `strength` walks
    // 50 -> 38.22 -> 26.45 -> 14.67 -> 2.90 -> 0.0 and stays there; nextInt
    // always returns 0, so `0 > strength` is never true.
    final random = _ScriptedRandom(fallbackDouble: 0.5, roll: 0);
    menu = presenterFor(habit, random: random);

    menu.onRandomize();

    final entries = habit.originalEntries.getKnown();
    expect(entries, hasLength(1825),
        reason: 'show-habit.randomize#2 — the loop runs i from 0 to '
            '365 * 5 - 1 = 1824, five years of days ending today');
    expect(habit.originalEntries.get(today.minus(3000)).value, Entry.unknown,
        reason: 'show-habit.randomize#2 — onRandomize clears '
            'habit.originalEntries entirely before generating');
    expect(entries.first.date, today,
        reason: 'show-habit.randomize#6 — the entry is added at '
            'getToday().minus(i), so i = 0 lands on today');
    expect(entries.last.date, today.minus(1824),
        reason: 'show-habit.randomize#6 — the entry is added at '
            'getToday().minus(i), so i = 1824 lands 1824 days back');
    expect(entries.map((e) => e.value).toSet(), <int>{Entry.yesManual},
        reason: 'show-habit.randomize#5 — the value is 2 (YES_MANUAL) for '
            'boolean habits');
    expect(habit.originalEntries.get(today.minus(1824)).value, Entry.yesManual,
        reason: 'show-habit.randomize#3 — strength is clamped by '
            'max(0.0, ...), so once the walk goes negative it sits at 0.0 and '
            '`0 > 0` never skips a day (an unclamped negative strength would '
            'have skipped every remaining day)');
    expect(random.intBounds.toSet(), <int>{100},
        reason: 'show-habit.randomize#4 — the roll is Random.nextInt(100)');
    expect(random.intBounds, hasLength(1825),
        reason: 'show-habit.randomize#4 — one roll per day of the loop');
  });

  test('onRandomize skips the days whose roll beats the strength', () {
    // gaussian == -1.1774100225154747 on every draw, so `strength` is
    // 38.2258... for i in 0..6, 26.4517... for i in 7..13, and lower after
    // that; every roll returns 30.
    final random = _ScriptedRandom(fallbackDouble: 0.5, roll: 30);
    menu = presenterFor(habit, random: random);

    menu.onRandomize();

    final entries = habit.originalEntries.getKnown();
    expect(entries, hasLength(7),
        reason: 'show-habit.randomize#4 — if Random.nextInt(100) > strength '
            'the day is skipped: 30 clears the 38.22 of the first week only');
    expect(entries.map((e) => e.date).toList(),
        List<LocalDate>.generate(7, (i) => today.minus(i)),
        reason: 'show-habit.randomize#6 — the surviving entries are at '
            'getToday().minus(i) for i = 0..6');
    expect(habit.originalEntries.get(today.minus(7)).value, Entry.unknown,
        reason: 'show-habit.randomize#3 — strength starts at 50.0 and is '
            're-rolled every time i % 7 == 0 as '
            'max(0, min(100, strength + 10 * gaussian)), so the second week '
            'drops to 26.45 and is skipped wholesale');
  });

  test('onRandomize computes numerical values from the strength', () {
    final numerical = fixtures.createNumericalHabit();
    // The first Box-Muller sample draws u1 = u2 = 0, giving an infinite
    // gaussian: min(100.0, ...) is what keeps `strength` finite. Every later
    // draw is 0.5, giving gaussian == -1.1774100225154747.
    final random = _ScriptedRandom(
      doubles: <double>[0.0, 0.0, 0.5, 0.5],
      fallbackDouble: 0.5,
      roll: 0,
    );
    menu = presenterFor(numerical, random: random);

    menu.onRandomize();

    expect(numerical.originalEntries.get(today).value, 705000,
        reason: 'show-habit.randomize#5 — for numerical habits the value is '
            '(1000 + 250 * gaussian * strength / 100).toInt() * 1000');
    expect(numerical.originalEntries.get(today.minus(6)).value, 705000,
        reason: 'show-habit.randomize#5 — the same strength is reused for '
            'the whole week');
    expect(numerical.originalEntries.get(today).value, isNot(equals(0)),
        reason: 'show-habit.randomize#3 — strength is clamped by '
            'min(100.0, ...): without it the infinite gaussian would make '
            'strength infinite and the value unrepresentable');
    expect(numerical.originalEntries.get(today.minus(7)).value, 740000,
        reason: 'show-habit.randomize#3 — the strength is re-rolled at '
            'i = 7, dropping from 100.0 to 88.2258..., which lifts the value '
            'accordingly');
  });

  test('onRandomize recomputes and refreshes without a command', () {
    final probe = today.minus(1000);
    screen.watched = habit;
    screen.probeDate = probe;
    expect(habit.computedEntries.get(probe).value, Entry.unknown,
        reason: 'show-habit.randomize#7 — precondition: the probe date is '
            'outside the fixture, so it is only known once recompute() ran');
    final random = _ScriptedRandom(fallbackDouble: 0.5, roll: 0);
    menu = presenterFor(habit, random: random);

    menu.onRandomize();

    expect(screen.refreshCount, 1,
        reason: 'show-habit.randomize#7 — after the loop habit.recompute() is '
            'called and then screen.refresh()');
    expect(screen.computedValueAtRefresh, Entry.yesManual,
        reason: 'show-habit.randomize#7 — recompute() runs BEFORE '
            'screen.refresh(), so the cards redraw with the generated data');
    expect(commandRunner.commands, isEmpty,
        reason: 'show-habit.randomize#8 — no command is run, so the change is '
            'not undoable');
    expect(listener.finished, isEmpty,
        reason: 'show-habit.randomize#8 — no CommandRunner listener is ever '
            'notified');
    expect(log, <String>['refresh'],
        reason: 'show-habit.randomize#8 — refresh is the only call the '
            'presenter makes; nothing else is notified');
  });
}
