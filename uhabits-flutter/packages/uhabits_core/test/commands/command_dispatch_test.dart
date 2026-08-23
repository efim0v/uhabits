/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt
/// and its test
/// .../commonTest/.../ui/screens/habits/show/ShowHabitMenuPresenterTest.kt.
///
/// The habit detail menu is the second dispatch site of the command layer (the
/// first, `ListHabitsSelectionMenuBehavior`, is covered from
/// habit_lifecycle_commands_test.dart and habit_state_commands_test.dart). The
/// rules here are about *how* it dispatches: always a fresh one-element list,
/// always a message shown synchronously at dispatch time rather than when the
/// command finishes, and — for Randomize — no command at all.
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'dart:async';
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
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit_menu_presenter.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Records every call the presenter makes back into the UI, in order.
class _RecordingScreen implements ShowHabitMenuPresenterScreen {
  _RecordingScreen(this.log);

  final List<String> log;

  final List<ShowHabitMenuPresenterMessage?> messages =
      <ShowHabitMenuPresenterMessage?>[];

  final List<String> sendFileCalls = <String>[];

  /// Whether the delete confirmation answers "Yes".
  bool confirmDelete = true;

  @override
  void close() => log.add('close');

  @override
  void refresh() => log.add('refresh');

  @override
  void showDeleteConfirmationScreen(void Function() callback) {
    log.add('showDeleteConfirmationScreen');
    if (confirmDelete) callback();
  }

  @override
  void showEditHabitScreen(Habit habit) => log.add('showEditHabitScreen');

  @override
  void showMessage(ShowHabitMenuPresenterMessage? m) {
    messages.add(m);
    log.add('showMessage(${m?.name})');
  }

  @override
  void showSendFileScreen(String filename) {
    sendFileCalls.add(filename);
    log.add('showSendFileScreen');
  }
}

/// `getCSVOutputDir()` throws unless a test opts into the export path.
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

/// A [TaskRunner] that only queues; [drain] runs the pipeline synchronously.
///
/// It is what makes "the message is shown at dispatch time, not when the
/// command finishes" observable: nothing a command does has happened yet by the
/// time `CommandRunner.run` returns.
class _DeferredTaskRunner implements TaskRunner {
  final List<Task> pending = <Task>[];

  @override
  void execute(Task task) {
    task.onAttached(this);
    pending.add(task);
  }

  void drain() {
    while (pending.isNotEmpty) {
      final task = pending.removeAt(0);
      task.onPreExecute();
      if (!task.isCanceled()) {
        final FutureOr<void> result = task.doInBackground();
        if (result is Future<void>) {
          throw StateError('a command task must not suspend');
        }
      }
      task.onPostExecute();
    }
  }

  @override
  void publishProgress(Task task, int progress) =>
      task.onProgressUpdate(progress);

  @override
  void addListener(TaskRunnerListener listener) {}

  @override
  void removeListener(TaskRunnerListener listener) {}

  @override
  int get activeTaskCount => pending.length;

  @override
  Future<void> awaitAll() async => drain();
}

class _RecordingCommandListener implements CommandRunnerListener {
  _RecordingCommandListener(this.log);

  final List<String> log;

  final List<Command> finished = <Command>[];

  @override
  void onCommandFinished(Command command) {
    finished.add(command);
    log.add('onCommandFinished(${command.runtimeType})');
  }
}

/// A [math.Random] whose draws are fixed, so `onRandomize` becomes exactly
/// reproducible: `nextInt` never beats `strength`, so no day is skipped, and
/// every Gaussian sample is the same.
class _ScriptedRandom implements math.Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => 0;
}

/// A [UserFile] whose `writeBytes` always fails, so `ExportCSVTask` swallows
/// the exception and reports a null filename.
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
  Future<void> mkdirs() async {}

  @override
  Future<Uint8List> readBytes(int limit) => throw UnimplementedError();

  @override
  Future<void> writeString(String content) => throw UnimplementedError();
}

void main() {
  // -------------------------------------------------------------------------
  // BaseUnitTest.setUp, inlined (commands.test-harness)
  // -------------------------------------------------------------------------
  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late CoroutineTaskRunner taskRunner;
  late _DeferredTaskRunner deferred;
  late CommandRunner commandRunner;
  late CommandRunner deferredCommandRunner;
  late _RecordingScreen screen;
  late _FakeSystem system;
  late _RecordingCommandListener listener;
  late List<String> log;
  late Habit habit;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    modelFactory = MemoryModelFactory();
    habitList = modelFactory.buildHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    deferred = _DeferredTaskRunner();
    commandRunner = CommandRunner(taskRunner);
    deferredCommandRunner = CommandRunner(deferred);
    log = <String>[];
    screen = _RecordingScreen(log);
    system = _FakeSystem();
    listener = _RecordingCommandListener(log);
    commandRunner.addListener(listener);
    deferredCommandRunner.addListener(listener);

    habit = fixtures.createEmptyHabit(name: 'Wake up early');
    habitList.add(habit);
  });

  tearDown(resetToday);

  ShowHabitMenuPresenter buildMenu({
    CommandRunner? runner,
    Habit? target,
    math.Random? random,
  }) =>
      ShowHabitMenuPresenter(
        commandRunner: runner ?? commandRunner,
        habit: target ?? habit,
        habitList: habitList,
        screen: screen,
        system: system,
        taskRunner: taskRunner,
        random: random,
      );

  // -------------------------------------------------------------------------
  // commands.dispatch-show-habit-menu
  // -------------------------------------------------------------------------
  group('commands.dispatch-show-habit-menu', () {
    test('every command is built from a fresh listOf(habit)', () {
      final other = fixtures.createEmptyHabit(name: 'Other', position: 1);
      habitList.add(other);
      final menu = buildMenu();

      menu.onArchiveHabits();
      menu.onUnarchiveHabits();
      menu.onDeleteHabit();

      final selections = <List<Habit>>[
        (listener.finished[0] as ArchiveHabitsCommand).selected,
        (listener.finished[1] as UnarchiveHabitsCommand).selected,
        (listener.finished[2] as DeleteHabitsCommand).selected,
      ];
      for (final selected in selections) {
        expect(
          selected,
          <Habit>[habit],
          reason: 'commands.dispatch-show-habit-menu#1 — ShowHabitMenuPresenter '
              'always wraps the single habit in listOf(habit)',
        );
        expect(
          selected.single,
          same(habit),
          reason: 'commands.dispatch-show-habit-menu#1 — holding the live '
              'instance the presenter was constructed with, never the other '
              'habits of the list',
        );
      }
      expect(
        identical(selections[0], selections[1]) ||
            identical(selections[1], selections[2]),
        isFalse,
        reason: 'commands.dispatch-show-habit-menu#1 — a *fresh* one-element '
            'list per dispatch; nothing is shared between commands',
      );
      for (final command in listener.finished) {
        expect(
          (command as dynamic).habitList,
          same(habitList),
          reason: 'commands.dispatch-show-habit-menu#1 — the presenter is '
              'constructed with (commandRunner, habit, habitList, screen, '
              'system, taskRunner) and hands that habitList to every command',
        );
      }
    });

    test('onArchiveHabits runs the command and shows HABIT_ARCHIVED at '
        'dispatch time', () {
      buildMenu(runner: deferredCommandRunner).onArchiveHabits();

      expect(
        log,
        <String>['showMessage(habitArchived)'],
        reason: 'commands.dispatch-show-habit-menu#2 — the message is shown '
            'synchronously at dispatch time, not when the command finishes',
      );
      expect(
        habit.isArchived,
        isFalse,
        reason: 'commands.dispatch-show-habit-menu#2 — the command has not '
            'even run yet when the message appears',
      );

      deferred.drain();

      expect(
        listener.finished.single,
        isA<ArchiveHabitsCommand>()
            .having((c) => c.selected, 'selected', <Habit>[habit]),
        reason: 'commands.dispatch-show-habit-menu#2 — onArchiveHabits() runs '
            'ArchiveHabitsCommand(habitList, listOf(habit))',
      );
      expect(
        habit.isArchived,
        isTrue,
        reason: 'commands.dispatch-show-habit-menu#2 — and it really archives '
            'the habit once it runs',
      );
      expect(
        log,
        <String>[
          'showMessage(habitArchived)',
          'onCommandFinished(ArchiveHabitsCommand)',
        ],
        reason: 'commands.dispatch-show-habit-menu#2 — the message precedes '
            'the command listeners rather than following them',
      );
    });

    test('onUnarchiveHabits runs the command and shows HABIT_UNARCHIVED', () {
      habit.isArchived = true;

      buildMenu(runner: deferredCommandRunner).onUnarchiveHabits();

      expect(
        log,
        <String>['showMessage(habitUnarchived)'],
        reason: 'commands.dispatch-show-habit-menu#3 — onUnarchiveHabits() '
            'shows Message.HABIT_UNARCHIVED, synchronously, right after '
            'handing the command to the runner',
      );

      deferred.drain();

      expect(
        listener.finished.single,
        isA<UnarchiveHabitsCommand>()
            .having((c) => c.selected, 'selected', <Habit>[habit]),
        reason: 'commands.dispatch-show-habit-menu#3 — it runs '
            'UnarchiveHabitsCommand(habitList, listOf(habit))',
      );
      expect(
        habit.isArchived,
        isFalse,
        reason: 'commands.dispatch-show-habit-menu#3 — which unarchives it',
      );
    });

    test('onDeleteHabit asks first, then deletes and closes without waiting',
        () {
      final menu = buildMenu(runner: deferredCommandRunner);
      screen.confirmDelete = false;

      menu.onDeleteHabit();

      expect(
        log,
        <String>['showDeleteConfirmationScreen'],
        reason: 'commands.dispatch-show-habit-menu#4 — onDeleteHabit() calls '
            'screen.showDeleteConfirmationScreen { ... } and nothing else',
      );
      expect(
        deferred.pending,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#4 — only on confirmation is '
            'anything dispatched',
      );
      expect(
        habitList.size(),
        1,
        reason: 'commands.dispatch-show-habit-menu#4 — an unconfirmed delete '
            'leaves the habit alone',
      );

      log.clear();
      screen.confirmDelete = true;

      menu.onDeleteHabit();

      expect(
        log,
        <String>['showDeleteConfirmationScreen', 'close'],
        reason: 'commands.dispatch-show-habit-menu#4 — on confirmation it runs '
            'DeleteHabitsCommand(habitList, listOf(habit)) and then '
            'screen.close() without waiting for completion',
      );
      expect(
        habitList.size(),
        1,
        reason: 'commands.dispatch-show-habit-menu#4 — the screen is already '
            'closed while the command is still pending',
      );

      deferred.drain();

      expect(
        habitList.size(),
        0,
        reason: 'commands.dispatch-show-habit-menu#4 — the deletion lands '
            'afterwards',
      );
      expect(
        listener.finished.single,
        isA<DeleteHabitsCommand>()
            .having((c) => c.selected, 'selected', <Habit>[habit]),
        reason: 'commands.dispatch-show-habit-menu#4 — with the habit wrapped '
            'in listOf(habit)',
      );
    });

    test('onEditHabit dispatches no command', () {
      buildMenu(runner: deferredCommandRunner).onEditHabit();

      expect(
        log,
        <String>['showEditHabitScreen'],
        reason: 'commands.dispatch-show-habit-menu#5 — onEditHabit() opens the '
            'editor via screen.showEditHabitScreen(habit)',
      );
      expect(
        deferred.pending,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#5 — and dispatches no '
            'command at all',
      );
      expect(
        listener.finished,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#5 — so no command listener '
            'ever hears about it',
      );
    });

    test('onExportCSV dispatches no command and reports the filename',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('uhabits-dispatch-');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      system.dir = LocalUserFile(tempDir.path);

      buildMenu().onExportCSV();
      await taskRunner.awaitAll();

      expect(
        listener.finished,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#6 — onExportCSV() '
            'dispatches no command; it runs an ExportCSVTask directly on the '
            'TaskRunner',
      );
      expect(
        system.callCount,
        1,
        reason: 'commands.dispatch-show-habit-menu#6 — the destination comes '
            'from system.getCSVOutputDir()',
      );
      expect(
        screen.sendFileCalls,
        hasLength(1),
        reason: 'commands.dispatch-show-habit-menu#6 — and it reports '
            'screen.showSendFileScreen(filename)',
      );
      expect(
        File(screen.sendFileCalls.single).existsSync(),
        isTrue,
        reason: 'commands.dispatch-show-habit-menu#6 — the archive really '
            'exists at the reported path',
      );
      expect(
        screen.messages,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#6 — a successful export '
            'shows no message',
      );

      log.clear();
      screen.sendFileCalls.clear();
      system.dir = _UnwritableUserFile();

      buildMenu().onExportCSV();
      await taskRunner.awaitAll();

      expect(
        screen.sendFileCalls,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#6 — a failed export opens '
            'no share-file screen',
      );
      expect(
        screen.messages,
        <ShowHabitMenuPresenterMessage>[
          ShowHabitMenuPresenterMessage.couldNotExport,
        ],
        reason: 'commands.dispatch-show-habit-menu#6 — it reports '
            'Message.COULD_NOT_EXPORT instead',
      );
      expect(
        listener.finished,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#6 — either way no command '
            'is dispatched',
      );
    });

    test('onRandomize bypasses the command layer entirely', () {
      final today = getToday();
      habit.originalEntries.add(Entry(today.minus(4000), Entry.yesManual));

      buildMenu(runner: deferredCommandRunner, random: _ScriptedRandom())
          .onRandomize();

      final known = habit.originalEntries.getKnown();
      expect(
        known.any((e) => e.date == today.minus(4000)),
        isFalse,
        reason: 'commands.dispatch-show-habit-menu#7 — onRandomize() clears '
            'habit.originalEntries first',
      );
      expect(
        known.length,
        1825,
        reason: 'commands.dispatch-show-habit-menu#7 — it generates 365*5 = '
            '1825 days of entries (this scripted Random never skips a day)',
      );
      expect(
        <LocalDate>[known.first.date, known.last.date],
        <LocalDate>[today, today.minus(1824)],
        reason: 'commands.dispatch-show-habit-menu#7 — walking backwards from '
            'today',
      );
      expect(
        known.map((e) => e.value).toSet(),
        <int>{Entry.yesManual},
        reason: 'commands.dispatch-show-habit-menu#7 — YES_MANUAL is used for '
            'boolean habits',
      );
      expect(
        log,
        <String>['refresh'],
        reason: 'commands.dispatch-show-habit-menu#7 — it calls '
            'habit.recompute() and screen.refresh(), and nothing else',
      );
      expect(
        deferred.pending,
        isEmpty,
        reason: 'commands.dispatch-show-habit-menu#7 — no command is '
            'dispatched, so no CommandRunner listener is ever notified and '
            'widgets, reminders and the list cache do not update',
      );
      expect(
        habit.computedEntries.get(today).value,
        Entry.yesManual,
        reason: 'commands.dispatch-show-habit-menu#7 — habit.recompute() ran, '
            'so the derived entries are up to date',
      );

      final numerical = fixtures.createNumericalHabit();
      habitList.add(numerical);
      buildMenu(
        runner: deferredCommandRunner,
        target: numerical,
        random: _ScriptedRandom(),
      ).onRandomize();

      expect(
        numerical.originalEntries.getKnown().every((e) => e.value % 1000 == 0),
        isTrue,
        reason: 'commands.dispatch-show-habit-menu#7 — numerical habits get '
            '((1000 + 250*gaussian*strength/100).toInt() * 1000)',
      );
    });

    test('Message has exactly three values, in the Kotlin order', () {
      expect(
        ShowHabitMenuPresenterMessage.values,
        <ShowHabitMenuPresenterMessage>[
          ShowHabitMenuPresenterMessage.couldNotExport,
          ShowHabitMenuPresenterMessage.habitArchived,
          ShowHabitMenuPresenterMessage.habitUnarchived,
        ],
        reason: 'commands.dispatch-show-habit-menu#8 — '
            'ShowHabitMenuPresenter.Message has exactly three values: '
            'COULD_NOT_EXPORT, HABIT_ARCHIVED, HABIT_UNARCHIVED',
      );
      expect(
        ShowHabitMenuPresenterMessage.values,
        hasLength(3),
        reason: 'commands.dispatch-show-habit-menu#8 — and no others',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.listener-list-habits-toasts
  // -------------------------------------------------------------------------
  group('commands.listener-list-habits-toasts', () {
    test('the detail screen emits its own messages, from the presenter rather '
        'than from a command listener', () {
      final menu = buildMenu(runner: deferredCommandRunner);

      menu.onArchiveHabits();
      menu.onUnarchiveHabits();

      expect(
        screen.messages,
        <ShowHabitMenuPresenterMessage>[
          ShowHabitMenuPresenterMessage.habitArchived,
          ShowHabitMenuPresenterMessage.habitUnarchived,
        ],
        reason: 'commands.listener-list-habits-toasts#6 — the habit detail '
            'screen shows its own messages, via '
            'ShowHabitMenuPresenter.Message.HABIT_ARCHIVED and '
            'HABIT_UNARCHIVED',
      );
      expect(
        listener.finished,
        isEmpty,
        reason: 'commands.listener-list-habits-toasts#6 — they are emitted '
            'synchronously by the presenter, before any command has even run, '
            'rather than from the command listener',
      );

      deferred.drain();

      expect(
        screen.messages,
        <ShowHabitMenuPresenterMessage>[
          ShowHabitMenuPresenterMessage.habitArchived,
          ShowHabitMenuPresenterMessage.habitUnarchived,
        ],
        reason: 'commands.listener-list-habits-toasts#6 — finishing the '
            'commands adds no further message: nothing on this screen reacts '
            'to onCommandFinished by showing one',
      );
      expect(
        listener.finished.map((c) => c.runtimeType.toString()).toList(),
        <String>['ArchiveHabitsCommand', 'UnarchiveHabitsCommand'],
        reason: 'commands.listener-list-habits-toasts#6 — the commands did run '
            'and the listeners did fire; the messages simply did not come from '
            'them',
      );
    });
  });
}
