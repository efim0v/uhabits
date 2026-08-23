import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/habits_csv_exporter.dart';
import 'package:uhabits_core/src/io/zip.dart';
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
/// Only `onExportCSV` calls it. [dir] is null unless a test sets it, so every
/// other test still fails loudly if it reaches the export path by accident.
class _FakeSystem implements ShowHabitMenuPresenterSystem {
  UserFile? dir;

  int callCount = 0;

  @override
  UserFile getCSVOutputDir() {
    callCount++;
    final d = dir;
    if (d == null) {
      throw UnsupportedError('CSV export is not exercised by this test');
    }
    return d;
  }
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

/// A [UserFile] whose `writeBytes` always fails, so `ExportCSVTask` swallows
/// the exception and reports a null filename — the only way the presenter's
/// COULD_NOT_EXPORT branch can be reached.
class _UnwritableUserFile implements UserFile {
  @override
  String get pathString => '/nonexistent';

  @override
  UserFile resolve(String child) => this;

  @override
  Future<void> writeBytes(List<int> bytes) async {
    throw const FileSystemException('cannot write');
  }

  @override
  Future<void> delete() => throw UnimplementedError();

  @override
  Future<bool> exists() => throw UnimplementedError();

  @override
  Future<List<String>> lines() => throw UnimplementedError();

  @override
  Future<List<UserFile>?> listFiles() => throw UnimplementedError();

  @override
  Future<void> mkdirs() => throw UnimplementedError();

  @override
  Future<Uint8List> readBytes(int limit) => throw UnimplementedError();

  @override
  Future<void> writeString(String content) => throw UnimplementedError();
}

/// Records every task the runner starts, so "runs on the app's TaskRunner" is
/// an observation rather than an inference.
class _RecordingTaskListener implements TaskRunnerListener {
  final List<Task> started = <Task>[];

  @override
  void onTaskStarted(Task task) => started.add(task);

  @override
  void onTaskFinished(Task task) {}
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
  // Export CSV — the single-habit entry point of io.export-csv-entry-points
  // -------------------------------------------------------------------------

  test('onExportCSV exports this one habit into system.getCSVOutputDir()',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('uhabits-show-export-');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final other = fixtures.createEmptyHabit(name: 'Other habit');
    habitList.add(other);
    system.dir = LocalUserFile(tempDir.path);

    menu.onExportCSV();
    await taskRunner.awaitAll();

    expect(system.callCount, 1,
        reason: 'io.export-csv-entry-points#2 — the destination is '
            'system.getCSVOutputDir()');
    final path = '${tempDir.path}/Loop Habits CSV 2015-01-25.zip';
    expect(File(path).existsSync(), isTrue,
        reason: 'io.export-csv-entry-points#2 — the archive lands in the '
            'directory the system handed back');

    final entries = await ZipReader(
            Uint8List.fromList(File(path).readAsBytesSync()))
        .entries();
    final names = entries.map((e) => e.name).toList();
    expect(
      names.where((n) => n.endsWith('Checkmarks.csv') && n.contains('/')),
      hasLength(1),
      reason: 'io.export-csv-entry-points#2 — onExportCSV exports '
          'listOf(habit): exactly ONE per-habit folder, even though the list '
          'holds two habits',
    );
    expect(
      names.singleWhere((n) => n.endsWith('Checkmarks.csv') && n.contains('/')),
      endsWith('Wake up early/Checkmarks.csv'),
      reason: 'io.export-csv-entry-points#2 — and the folder is the habit the '
          'menu was opened on',
    );
    expect(names.where((n) => n.contains('Other habit')), isEmpty,
        reason: 'io.export-csv-entry-points#2 — the other habit gets no '
            'folder of its own');

    final habitsCsv =
        entries.firstWhere((e) => e.name == 'Habits.csv').content;
    expect(habitsCsv, contains('Wake up early'),
        reason: 'io.export-csv-entry-points#2 — Habits.csv is written from '
            'allHabits, not from the selection');
    expect(habitsCsv, contains('Other habit'),
        reason: 'io.export-csv-entry-points#2 — so it still contains EVERY '
            'habit');

    expect(screen.sendFileCalls, <String>[path],
        reason: 'io.export-csv-entry-points#3 — a non-null filename opens the '
            'share-file screen');
    expect(screen.messages, isEmpty,
        reason: 'io.export-csv-entry-points#3 — and shows no message');
  });

  test('onExportCSV shows COULD_NOT_EXPORT when the export produces nothing',
      () async {
    system.dir = _UnwritableUserFile();

    menu.onExportCSV();
    await taskRunner.awaitAll();

    expect(screen.sendFileCalls, isEmpty,
        reason: 'io.export-csv-entry-points#3 — a null filename opens no '
            'share-file screen');
    expect(screen.messages, <ShowHabitMenuPresenterMessage>[
      ShowHabitMenuPresenterMessage.couldNotExport,
    ],
        reason: 'io.export-csv-entry-points#3 — on null the presenter calls '
            'screen.showMessage(COULD_NOT_EXPORT)');
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

  test('show-habit.delete#5 the confirmation is always the singular one', () {
    screen.confirmDelete = true;

    menu.onDeleteHabit();

    // The one call the presenter makes is
    // `screen.showDeleteConfirmationScreen(callback)` — one argument, no
    // count. `ListHabitsSelectionMenuBehavior` passes
    // `quantity = adapter.getSelected().size` to its own screen because a
    // multiple selection can be plural; this screen deletes exactly one habit,
    // so no count crosses the interface and the plural strings are always
    // resolved at quantity 1.
    expect(screen.deleteConfirmationCount, 1,
        reason: 'show-habit.delete#5 — the quantity used for the plural '
            'strings is always 1 on this screen');
    expect(commandRunner.commands.single,
        equals(DeleteHabitsCommand(habitList, <Habit>[habit])),
        reason: 'show-habit.delete#5 — and the command deletes exactly one '
            'habit, which is why 1 is right');
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

  // -------------------------------------------------------------------------
  // show-habit.export-csv — the same entry point read against its own rules
  // -------------------------------------------------------------------------

  test('show-habit.export-csv#1 #3 #7: one ExportCSVTask on the task runner, '
      'one dated archive, this habit only', () async {
    final tempDir = Directory.systemTemp.createTempSync('uhabits-show-export1-');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final other = fixtures.createEmptyHabit(name: 'Other habit');
    habitList.add(other);
    system.dir = LocalUserFile(tempDir.path);
    final tasks = _RecordingTaskListener();
    taskRunner.addListener(tasks);

    menu.onExportCSV();
    await taskRunner.awaitAll();

    expect(tasks.started, hasLength(1),
        reason: 'show-habit.export-csv#1 — selecting Export runs exactly one '
            "task on the app's TaskRunner");
    expect(tasks.started.single, isA<ExportCSVTask>(),
        reason: 'show-habit.export-csv#1 — and that task is ExportCSVTask');
    expect(commandRunner.commands, isEmpty,
        reason: 'show-habit.export-csv#1 — the export dispatches no command');

    final produced = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    expect(produced, hasLength(1),
        reason: 'show-habit.export-csv#7 — exactly one file is produced in the '
            'output directory per export');
    expect(produced.single, 'Loop Habits CSV 2015-01-25.zip',
        reason: 'show-habit.export-csv#3 — the archive is named "Loop Habits '
            'CSV <today>.zip" with a zero-padded YYYY-MM-DD date');
    expect(getToday().toCSVString(), '2015-01-25',
        reason: 'show-habit.export-csv#3 — <today> is '
            'getToday().toCSVString()');

    final names = (await ZipReader(
                Uint8List.fromList(File('${tempDir.path}/${produced.single}')
                    .readAsBytesSync()))
            .entries())
        .map((e) => e.name)
        .toList();
    expect(names.where((n) => n.endsWith('Checkmarks.csv') && n.contains('/')),
        hasLength(1),
        reason: 'show-habit.export-csv#1 — ExportCSVTask is given '
            'listOf(habit), so only the habit currently shown is exported');
    expect(names.where((n) => n.contains('Other habit')), isEmpty,
        reason: 'show-habit.export-csv#1 — the other habits get no folder');
  });

  test('show-habit.export-csv#6: a failing export is swallowed and reported as '
      'COULD_NOT_EXPORT', () async {
    system.dir = _UnwritableUserFile();

    menu.onExportCSV();
    await taskRunner.awaitAll();

    expect(screen.sendFileCalls, isEmpty,
        reason: 'show-habit.export-csv#6 — the exception is swallowed and the '
            'callback receives null, so no share screen opens');
    expect(screen.messages,
        <ShowHabitMenuPresenterMessage>[
          ShowHabitMenuPresenterMessage.couldNotExport,
        ],
        reason: 'show-habit.export-csv#6 — in which case COULD_NOT_EXPORT is '
            'shown');
    expect(ShowHabitMenuPresenterMessage.couldNotExport.index, 0,
        reason: 'show-habit.export-csv#6 — COULD_NOT_EXPORT is the first of '
            'the three menu messages');
  });

  // -------------------------------------------------------------------------
  // show-habit.widget-refresh — the menu half
  // -------------------------------------------------------------------------

  test('show-habit.widget-refresh#3: no menu action touches the widgets', () {
    screen.confirmDelete = true;

    menu.onEditHabit();
    menu.onArchiveHabits();
    menu.onUnarchiveHabits();
    menu.onDeleteHabit();

    expect(log.where((entry) => entry.contains('updateWidgets')), isEmpty,
        reason: 'show-habit.widget-refresh#3 — edit, archive, unarchive and '
            'delete propagate through the CommandRunner, never through '
            'updateWidgets');
    expect(log.where((entry) => entry.startsWith('run:')).toList(), <String>[
      'run:ArchiveHabitsCommand',
      'run:UnarchiveHabitsCommand',
      'run:DeleteHabitsCommand',
    ],
        reason: 'show-habit.widget-refresh#3 — the CommandRunner is the only '
            'thing these actions notify');
  });
}
