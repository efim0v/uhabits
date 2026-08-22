import 'dart:async';

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/gui/font_awesome.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_factory.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/Command.kt,
/// .../commands/CommandRunner.kt, .../tasks/Task.kt, .../tasks/TaskRunner.kt,
/// .../tasks/CoroutineTaskRunner.kt and their tests
/// (.../commonTest/.../tasks/CoroutineTaskRunnerTest.kt,
/// .../commonTest/.../BaseUnitTest.kt).
///
/// Every `expect` carries the parity-ledger rule id it exercises.

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A complete `Command` implementation.
///
/// The fact that this class compiles while declaring nothing but `run()` is the
/// compile-time half of the proof that `run()` is the interface's only member.
class _MinimalCommand implements Command {
  bool didRun = false;

  @override
  void run() {
    didRun = true;
  }
}

/// A command that appends to a shared log, so that the observable order of a
/// dispatch can be asserted.
class _LoggingCommand implements Command {
  _LoggingCommand(this.log, [this.label = 'command']);

  final List<String> log;
  final String label;
  int runCount = 0;

  @override
  void run() {
    runCount++;
    log.add('$label.run');
  }
}

/// A second, unrelated `Command` implementation, used to show that the runner
/// notifies every listener for every command type.
class _OtherCommand implements Command {
  _OtherCommand(this.log);

  final List<String> log;
  int runCount = 0;

  @override
  void run() {
    runCount++;
    log.add('other.run');
  }
}

/// `run()` reports failure the only way it can: by throwing.
class _ThrowingCommand implements Command {
  int runCount = 0;

  @override
  void run() {
    runCount++;
    throw StateError('boom');
  }
}

/// A complete `CommandRunner.Listener`: it declares `onCommandFinished` and
/// nothing else.
class _MinimalCommandListener implements CommandRunnerListener {
  final List<Command> received = <Command>[];

  @override
  void onCommandFinished(Command command) {
    received.add(command);
  }
}

class _LoggingCommandListener implements CommandRunnerListener {
  _LoggingCommandListener(this.log, this.label);

  final List<String> log;
  final String label;
  final List<Command> received = <Command>[];

  @override
  void onCommandFinished(Command command) {
    received.add(command);
    log.add('$label.onCommandFinished');
  }
}

class _LoggingTaskRunnerListener implements TaskRunnerListener {
  _LoggingTaskRunnerListener(this.log);

  final List<String> log;
  final String label = 'runnerListener';
  final List<Task> started = <Task>[];
  final List<Task> finished = <Task>[];

  @override
  void onTaskStarted(Task task) {
    started.add(task);
    log.add('$label.onTaskStarted');
  }

  @override
  void onTaskFinished(Task task) {
    finished.add(task);
    log.add('$label.onTaskFinished');
  }
}

/// A `Task` that overrides nothing but `doInBackground`, so that the defaults
/// declared by `Task` can be probed.
class _BareTask extends Task {
  int runCount = 0;

  @override
  FutureOr<void> doInBackground() {
    runCount++;
  }
}

class _LoggingTask extends Task {
  _LoggingTask(this.log, {this.canceled = false, this.onBackground});

  final List<String> log;
  final bool canceled;
  final void Function()? onBackground;
  TaskRunner? attachedRunner;
  int progress = -1;

  @override
  bool isCanceled() => canceled;

  @override
  void onAttached(TaskRunner runner) {
    attachedRunner = runner;
    log.add('task.onAttached');
  }

  @override
  void onPreExecute() => log.add('task.onPreExecute');

  @override
  FutureOr<void> doInBackground() {
    log.add('task.doInBackground');
    onBackground?.call();
  }

  @override
  void onPostExecute() => log.add('task.onPostExecute');

  @override
  void onProgressUpdate(int currentPosition) {
    progress = currentPosition;
    log.add('task.onProgressUpdate');
  }
}

/// Wraps the `Task` that `CommandRunner` builds internally so that its
/// callbacks can be observed in order.
class _SpyTask extends Task {
  _SpyTask(this.inner, this.log);

  final Task inner;
  final List<String> log;
  TaskRunner? attachedRunner;
  int postExecuteCount = 0;

  @override
  void cancel() => inner.cancel();

  @override
  bool isCanceled() => inner.isCanceled();

  @override
  void onAttached(TaskRunner runner) {
    attachedRunner = runner;
    log.add('task.onAttached');
    inner.onAttached(runner);
  }

  @override
  void onPreExecute() {
    log.add('task.onPreExecute');
    inner.onPreExecute();
  }

  @override
  FutureOr<void> doInBackground() {
    log.add('task.doInBackground');
    return inner.doInBackground();
  }

  @override
  void onPostExecute() {
    postExecuteCount++;
    log.add('task.onPostExecute');
    inner.onPostExecute();
  }

  @override
  void onProgressUpdate(int currentPosition) =>
      inner.onProgressUpdate(currentPosition);
}

/// A `TaskRunner` that records the tasks handed to it and never runs them.
class _CapturingTaskRunner implements TaskRunner {
  final List<Task> executed = <Task>[];

  @override
  void addListener(TaskRunnerListener listener) {}

  @override
  void removeListener(TaskRunnerListener listener) {}

  @override
  void execute(Task task) => executed.add(task);

  @override
  void publishProgress(Task task, int progress) {}

  @override
  int get activeTaskCount => 0;

  @override
  Future<void> awaitAll() async {}
}

/// Delegates to [inner] but wraps every task in a [_SpyTask] first.
class _SpyingTaskRunner implements TaskRunner {
  _SpyingTaskRunner(this.inner, this.log);

  final TaskRunner inner;
  final List<String> log;
  final List<_SpyTask> spies = <_SpyTask>[];

  @override
  void addListener(TaskRunnerListener listener) => inner.addListener(listener);

  @override
  void removeListener(TaskRunnerListener listener) =>
      inner.removeListener(listener);

  @override
  void execute(Task task) {
    final spy = _SpyTask(task, log);
    spies.add(spy);
    inner.execute(spy);
  }

  @override
  void publishProgress(Task task, int progress) =>
      inner.publishProgress(task, progress);

  @override
  int get activeTaskCount => inner.activeTaskCount;

  @override
  Future<void> awaitAll() => inner.awaitAll();
}

/// `CommandRunner` is `open` in Kotlin: tests subclass it and stub `run`.
class _StubCommandRunner extends CommandRunner {
  _StubCommandRunner(super.taskRunner);

  final List<Command> seen = <Command>[];

  @override
  void run(Command command) {
    seen.add(command);
  }
}

void main() {
  // -------------------------------------------------------------------------
  // BaseUnitTest.setUp, inlined (commands.test-harness)
  // -------------------------------------------------------------------------
  late MemoryModelFactory memoryModelFactory;
  late HabitList habitList;
  late HabitFixtures fixtures;
  late ModelFactory modelFactory;
  late TaskRunner taskRunner;
  late CommandRunner commandRunner;
  late List<String> log;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    memoryModelFactory = MemoryModelFactory();
    habitList = memoryModelFactory.buildHabitList();
    fixtures = HabitFixtures(memoryModelFactory, habitList);
    modelFactory = memoryModelFactory;
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = CommandRunner(taskRunner);
    log = <String>[];
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // commands.command-interface
  // -------------------------------------------------------------------------
  group('commands.command-interface', () {
    test('Command declares exactly one member, run()', () {
      final command = _MinimalCommand();

      // The compile-time half: _MinimalCommand satisfies Command while
      // declaring nothing but run().
      expect(
        command,
        isA<Command>(),
        reason: 'commands.command-interface#1 — a class declaring only run() '
            'is a complete Command implementation',
      );

      final dynamic probe = command;
      for (final member in <void Function()>[
        () => probe.undo(),
        () => probe.redo(),
        () => probe.id,
        () => probe.name,
        () => probe.description,
        () => probe.isUndoable,
      ]) {
        expect(
          member,
          throwsA(isA<NoSuchMethodError>()),
          reason: 'commands.command-interface#1 — Command has no undo(), no '
              'redo(), no id, no name, no description and no isUndoable',
        );
      }
    });

    test('run() is synchronous, returns nothing and fails by throwing', () {
      final command = _MinimalCommand();
      final dynamic probe = command;

      final Object? result = probe.run();
      expect(
        command.didRun,
        isTrue,
        reason: 'commands.command-interface#2 — run() is synchronous: its '
            'effect is visible as soon as the call returns',
      );
      expect(
        result,
        isNull,
        reason: 'commands.command-interface#2 — run() returns Unit; there is '
            'no result and no future to await',
      );

      final throwing = _ThrowingCommand();
      expect(
        throwing.run,
        throwsA(isA<StateError>()),
        reason: 'commands.command-interface#2 — run() reports failure only by '
            'throwing',
      );
    });

    test('commands are never serialized, persisted or kept in a history', () {
      final command = _MinimalCommand();
      final dynamic commandProbe = command;
      for (final member in <void Function()>[
        () => commandProbe.toJson(),
        () => commandProbe.serialize(),
        () => commandProbe.toRecord(),
      ]) {
        expect(
          member,
          throwsA(isA<NoSuchMethodError>()),
          reason: 'commands.command-interface#6 — commands are never '
              'serialized and never persisted',
        );
      }

      commandRunner.run(command);
      final dynamic runnerProbe = commandRunner;
      for (final member in <void Function()>[
        () => runnerProbe.history,
        () => runnerProbe.commands,
        () => runnerProbe.executed,
      ]) {
        expect(
          member,
          throwsA(isA<NoSuchMethodError>()),
          reason: 'commands.command-interface#6 — a command that has run is '
              'not stored in any history list',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // commands.no-undo-redo
  // -------------------------------------------------------------------------
  group('commands.no-undo-redo', () {
    test('there is no undo stack, no redo stack and no history limit', () {
      final dynamic runnerProbe = commandRunner;
      for (final member in <void Function()>[
        () => runnerProbe.undo(),
        () => runnerProbe.redo(),
        () => runnerProbe.undoStack,
        () => runnerProbe.redoStack,
        () => runnerProbe.historySize,
        () => runnerProbe.maxHistorySize,
        () => runnerProbe.canUndo,
        () => runnerProbe.canRedo,
      ]) {
        expect(
          member,
          throwsA(isA<NoSuchMethodError>()),
          reason: 'commands.no-undo-redo#1 — there is no undo stack, no redo '
              'stack and no history size limit anywhere in the app',
        );
      }
    });

    test('no command can be reverted programmatically', () {
      final command = _MinimalCommand();
      command.run();

      final dynamic probe = command;
      expect(
        () => probe.undo(),
        throwsA(isA<NoSuchMethodError>()),
        reason: 'commands.no-undo-redo#2 — because Command has only run(), no '
            'command can be reverted programmatically',
      );
      expect(
        command.didRun,
        isTrue,
        reason: 'commands.no-undo-redo#2 — the only way to reverse an action '
            'is to issue the inverse action; the forward effect stands',
      );
    });

    test('the fa_undo glyph is absent from the ported resource table', () {
      expect(
        FontAwesome.androidGlyphs.containsKey('fa_undo'),
        isFalse,
        reason: 'commands.no-undo-redo#4 — the fa_undo glyph is commented out '
            'in fontawesome.xml, so it is unused',
      );
      expect(
        FontAwesome.androidGlyphs.values.contains('\u{f0e2}'),
        isFalse,
        reason: 'commands.no-undo-redo#4 — U+F0E2 (fa_undo) is not part of the '
            'glyph vocabulary',
      );
      expect(
        FontAwesome.coreGlyphs.containsKey('UNDO'),
        isFalse,
        reason: 'commands.no-undo-redo#4 — the shared core declares no undo '
            'glyph either',
      );
    });

    test('testExecuteUndoRedo asserts only the forward effect', () {
      // The Kotlin test method is named UnarchiveHabitsCommandTest
      // .testExecuteUndoRedo, but it only calls command.run() and checks the
      // forward effect. Porting the *name* must not introduce an undo.
      final command = _MinimalCommand();
      command.run();

      expect(
        command.didRun,
        isTrue,
        reason: 'commands.no-undo-redo#5 — the test only calls run() and '
            'asserts the forward effect',
      );
      final dynamic probe = command;
      for (final member in <void Function()>[
        () => probe.undo(),
        () => probe.redo(),
      ]) {
        expect(
          member,
          throwsA(isA<NoSuchMethodError>()),
          reason: 'commands.no-undo-redo#5 — the leftover method name must NOT '
              'make the port introduce undo',
        );
      }
    });

    test('commands are fire-and-forget mutations', () {
      final command = _LoggingCommand(log);
      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);

      final dynamic probe = commandRunner;
      final Object? result = probe.run(command);

      expect(
        result,
        isNull,
        reason: 'commands.no-undo-redo#6 — commands are fire-and-forget: run() '
            'hands back no handle that could later be undone',
      );
      expect(
        command.runCount,
        1,
        reason: 'commands.no-undo-redo#6 — the mutation happens once and is '
            'not recorded for reversal',
      );
      expect(
        listener.received.single,
        same(command),
        reason: 'commands.no-undo-redo#6 — the only feedback channel is the '
            'listener callback',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.command-runner-run
  // -------------------------------------------------------------------------
  group('commands.command-runner-run', () {
    test('CommandRunner takes a single dependency: a TaskRunner', () {
      final capturing = _CapturingTaskRunner();
      final runner = CommandRunner(capturing);
      final command = _MinimalCommand();

      runner.run(command);

      expect(
        capturing.executed.length,
        1,
        reason: 'commands.command-runner-run#1 — CommandRunner is constructed '
            'with a single dependency, a TaskRunner, and dispatches through it',
      );
    });

    test('run() builds a Task instead of calling command.run() inline', () {
      final capturing = _CapturingTaskRunner();
      final runner = CommandRunner(capturing);
      final listener = _MinimalCommandListener();
      runner.addListener(listener);
      final command = _LoggingCommand(log);

      runner.run(command);

      expect(
        command.runCount,
        0,
        reason: 'commands.command-runner-run#2 — run(command) never calls '
            "command.run() directly on the caller's thread",
      );
      final task = capturing.executed.single;
      task.doInBackground();
      expect(
        command.runCount,
        1,
        reason: 'commands.command-runner-run#2 — the task doInBackground() '
            'calls command.run()',
      );
      expect(
        listener.received,
        isEmpty,
        reason: 'commands.command-runner-run#2 — listeners are notified from '
            'onPostExecute(), not from doInBackground()',
      );
      task.onPostExecute();
      expect(
        listener.received.single,
        same(command),
        reason: 'commands.command-runner-run#2 — the task onPostExecute() '
            'calls notifyListeners(command)',
      );
    });

    test('the observable order of a single run(command)', () {
      final inner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final runnerListener = _LoggingTaskRunnerListener(log);
      inner.addListener(runnerListener);
      final spying = _SpyingTaskRunner(inner, log);
      final runner = CommandRunner(spying);
      runner.addListener(_LoggingCommandListener(log, 'commandListener'));
      final command = _LoggingCommand(log);

      runner.run(command);

      expect(
        log,
        <String>[
          'task.onAttached',
          'runnerListener.onTaskStarted',
          'task.onPreExecute',
          'task.doInBackground',
          'command.run',
          'task.onPostExecute',
          'commandListener.onCommandFinished',
          'runnerListener.onTaskFinished',
        ],
        reason: 'commands.command-runner-run#3 — the observable order is '
            'onAttached -> onTaskStarted -> onPreExecute -> command.run -> '
            'notifyListeners -> onTaskFinished',
      );
      expect(
        spying.spies.single.attachedRunner,
        same(inner),
        reason: 'commands.command-runner-run#3 — onAttached receives the '
            'TaskRunner that will execute the task',
      );
    });

    test('run() returns immediately, with no future and no result', () async {
      final asyncRunner = CoroutineTaskRunner(
        mainDispatcher: const AsyncDispatcher(),
        ioDispatcher: const AsyncDispatcher(),
      );
      final runner = CommandRunner(asyncRunner);
      final listener = _MinimalCommandListener();
      runner.addListener(listener);
      final command = _LoggingCommand(log);

      final dynamic probe = runner;
      final Object? result = probe.run(command);

      expect(
        result,
        isNull,
        reason: 'commands.command-runner-run#4 — run() returns void: no '
            'completion callback, no future, no result',
      );
      expect(
        command.runCount,
        0,
        reason: 'commands.command-runner-run#4 — run() returns immediately, '
            'before the command has executed',
      );

      await asyncRunner.awaitAll();

      expect(
        listener.received.single,
        same(command),
        reason: 'commands.command-runner-run#4 — UI code that must react has '
            'to register a CommandRunner.Listener',
      );
    });

    test('listeners receive the very instance passed to run()', () {
      final first = _MinimalCommandListener();
      final second = _MinimalCommandListener();
      commandRunner.addListener(first);
      commandRunner.addListener(second);
      final command = _LoggingCommand(log);

      commandRunner.run(command);

      expect(
        first.received.single,
        same(command),
        reason: 'commands.command-runner-run#5 — the exact same command '
            'instance is handed to every listener',
      );
      expect(
        second.received.single,
        same(command),
        reason: 'commands.command-runner-run#5 — every listener gets the same '
            'instance, not a copy',
      );
    });

    test('a throwing command notifies no listener', () {
      final inner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final spying = _SpyingTaskRunner(inner, log);
      final runner = CommandRunner(spying);
      final listener = _MinimalCommandListener();
      runner.addListener(listener);
      final command = _ThrowingCommand();

      // With the inline dispatcher the "uncaught exception path" is the
      // caller's own stack; on Kotlin/Android it is the scope's uncaught
      // handler. Either way it escapes CommandRunner untouched.
      expect(
        () => runner.run(command),
        throwsA(isA<StateError>()),
        reason: 'commands.command-runner-run#6 — the exception escapes into '
            "the scope's uncaught-exception path",
      );
      expect(
        spying.spies.single.postExecuteCount,
        0,
        reason: 'commands.command-runner-run#6 — onPostExecute() is never '
            'reached when command.run() throws',
      );
      expect(
        listener.received,
        isEmpty,
        reason: 'commands.command-runner-run#6 — NO listener is notified and '
            'the UI is left stale',
      );
    });

    test('two run() calls are two independent tasks', () async {
      final capturing = _CapturingTaskRunner();
      final capturingRunner = CommandRunner(capturing);
      final command = _LoggingCommand(log);

      capturingRunner.run(command);
      capturingRunner.run(command);

      expect(
        capturing.executed.length,
        2,
        reason: 'commands.command-runner-run#7 — CommandRunner does not '
            'deduplicate or coalesce commands',
      );
      expect(
        identical(capturing.executed[0], capturing.executed[1]),
        isFalse,
        reason: 'commands.command-runner-run#7 — each run() builds its own '
            'task; nothing is batched or queued',
      );

      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      final a = _LoggingCommand(log, 'a');
      final b = _LoggingCommand(log, 'b');
      commandRunner.run(a);
      commandRunner.run(b);

      expect(
        log,
        <String>['a.run', 'b.run'],
        reason: 'commands.command-runner-run#7 — commands are not serialized '
            'into a queue; each dispatch runs on its own',
      );
      expect(
        listener.received,
        <Object>[a, b],
        reason: 'commands.command-runner-run#7 — two independent tasks produce '
            'two independent notifications',
      );
    });

    test('CommandRunner is open and notifyListeners is public', () {
      final stub = _StubCommandRunner(taskRunner);
      final command = _LoggingCommand(log);

      stub.run(command);

      expect(
        stub.seen.single,
        same(command),
        reason: 'commands.command-runner-run#8 — CommandRunner and run() are '
            'open, so tests may subclass and stub them',
      );
      expect(
        command.runCount,
        0,
        reason: 'commands.command-runner-run#8 — the stubbed run() replaces '
            'the dispatch entirely',
      );

      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      final direct = _LoggingCommand(log, 'direct');
      commandRunner.notifyListeners(direct);

      expect(
        listener.received.single,
        same(direct),
        reason: 'commands.command-runner-run#8 — notifyListeners(command) is '
            'public and can be invoked directly',
      );
      expect(
        direct.runCount,
        0,
        reason: 'commands.command-runner-run#8 — notifyListeners simulates a '
            'finished command without executing it',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.command-runner-listeners
  // -------------------------------------------------------------------------
  group('commands.command-runner-listeners', () {
    test('listeners are notified front-to-back in insertion order', () {
      commandRunner.addListener(_LoggingCommandListener(log, 'first'));
      commandRunner.addListener(_LoggingCommandListener(log, 'second'));
      commandRunner.addListener(_LoggingCommandListener(log, 'third'));

      commandRunner.notifyListeners(_MinimalCommand());

      expect(
        log,
        <String>[
          'first.onCommandFinished',
          'second.onCommandFinished',
          'third.onCommandFinished',
        ],
        reason: 'commands.command-runner-listeners#1 — the insertion-ordered '
            'list is iterated front-to-back, with no priority and no way to '
            'stop propagation',
      );
    });

    test('every listener is notified for every command type', () {
      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      final minimal = _MinimalCommand();
      final other = _OtherCommand(log);

      commandRunner.run(minimal);
      commandRunner.run(other);

      expect(
        listener.received,
        <Object>[minimal, other],
        reason: 'commands.command-runner-listeners#2 — every listener is '
            'notified for EVERY command type; filtering happens inside the '
            'listener, not in the runner',
      );
    });

    test('addListener appends without a duplicate check', () {
      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      commandRunner.addListener(listener);
      final command = _MinimalCommand();

      commandRunner.run(command);

      expect(
        listener.received,
        <Object>[command, command],
        reason: 'commands.command-runner-listeners#3 — registering the same '
            'listener twice makes it receive each command twice',
      );
    });

    test('removeListener removes the first match and never throws', () {
      final listener = _MinimalCommandListener();
      final never = _MinimalCommandListener();

      expect(
        () => commandRunner.removeListener(never),
        returnsNormally,
        reason: 'commands.command-runner-listeners#4 — removing a listener '
            'that was never added is a silent no-op',
      );

      commandRunner.addListener(listener);
      commandRunner.addListener(listener);
      commandRunner.removeListener(listener);
      commandRunner.run(_MinimalCommand());

      expect(
        listener.received.length,
        1,
        reason: 'commands.command-runner-listeners#4 — removeListener removes '
            'only the first matching element',
      );
    });

    test('CommandRunner.Listener has exactly one method', () {
      final listener = _MinimalCommandListener();

      expect(
        listener,
        isA<CommandRunnerListener>(),
        reason: 'commands.command-runner-listeners#5 — a class declaring only '
            'onCommandFinished is a complete Listener',
      );

      final dynamic probe = listener;
      for (final member in <void Function()>[
        () => probe.onCommandStarted(_MinimalCommand()),
        () => probe.onCommandFailed(_MinimalCommand()),
        () => probe.onCommandUndone(_MinimalCommand()),
      ]) {
        expect(
          member,
          throwsA(isA<NoSuchMethodError>()),
          reason: 'commands.command-runner-listeners#5 — the interface has '
              'exactly one method, onCommandFinished(command)',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // commands.task-runner-contract
  // -------------------------------------------------------------------------
  group('commands.task-runner-contract', () {
    test('TaskRunner exposes exactly the documented members', () async {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final listener = _LoggingTaskRunnerListener(log);
      final task = _LoggingTask(log);

      expect(
        runner,
        isA<TaskRunner>(),
        reason: 'commands.task-runner-contract#1 — CoroutineTaskRunner '
            'implements the TaskRunner interface',
      );
      expect(
        runner.activeTaskCount,
        0,
        reason: 'commands.task-runner-contract#1 — TaskRunner exposes '
            'activeTaskCount',
      );

      runner.addListener(listener);
      runner.execute(task);
      expect(
        listener.started.single,
        same(task),
        reason: 'commands.task-runner-contract#1 — TaskRunner exposes '
            'addListener(Listener) and execute(Task)',
      );

      runner.publishProgress(task, 42);
      expect(
        task.progress,
        42,
        reason: 'commands.task-runner-contract#1 — TaskRunner exposes '
            'publishProgress(Task, Int)',
      );

      runner.removeListener(listener);
      runner.execute(_LoggingTask(log));
      expect(
        listener.started.length,
        1,
        reason: 'commands.task-runner-contract#1 — TaskRunner exposes '
            'removeListener(Listener)',
      );

      await runner.awaitAll();
      expect(
        runner.activeTaskCount,
        0,
        reason: 'commands.task-runner-contract#1 — TaskRunner exposes await(), '
            'ported as awaitAll()',
      );
    });

    test('Task defaults every member except doInBackground', () {
      final task = _BareTask();
      final runner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );

      expect(
        task.isCanceled(),
        isFalse,
        reason: 'commands.task-runner-contract#2 — isCanceled() defaults to '
            'false',
      );
      task.cancel();
      expect(
        task.isCanceled(),
        isFalse,
        reason: 'commands.task-runner-contract#2 — cancel() defaults to a '
            'no-op, so it does not flip isCanceled()',
      );
      for (final member in <void Function()>[
        () => task.onAttached(runner),
        () => task.onPostExecute(),
        () => task.onPreExecute(),
        () => task.onProgressUpdate(7),
      ]) {
        expect(
          member,
          returnsNormally,
          reason: 'commands.task-runner-contract#2 — onAttached, '
              'onPostExecute, onPreExecute and onProgressUpdate all default to '
              'no-ops',
        );
      }
      task.doInBackground();
      expect(
        task.runCount,
        1,
        reason: 'commands.task-runner-contract#2 — doInBackground() is the '
            'only abstract member',
      );
    });

    test('CoroutineTaskRunner uses its main and io dispatchers', () async {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const AsyncDispatcher(),
      );
      final task = _LoggingTask(log);

      runner.execute(task);

      expect(
        log,
        <String>['task.onAttached', 'task.onPreExecute'],
        reason: 'commands.task-runner-contract#3 — the runner is created with '
            'a mainDispatcher and an ioDispatcher; the prologue runs on the '
            'main one and the background step on the io one',
      );

      await runner.awaitAll();

      expect(
        log,
        <String>[
          'task.onAttached',
          'task.onPreExecute',
          'task.doInBackground',
          'task.onPostExecute',
        ],
        reason: 'commands.task-runner-contract#3 — the io dispatcher carries '
            'doInBackground, after which the epilogue resumes',
      );
    });

    test('a failing task does not tear down the scope', () {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final failing = _LoggingTask(
        log,
        onBackground: () => throw StateError('boom'),
      );

      expect(
        () => runner.execute(failing),
        throwsA(isA<StateError>()),
        reason: 'commands.task-runner-contract#3 — the runner does not catch a '
            'failing task; the exception leaves the scope',
      );

      final survivor = _LoggingTask(log);
      runner.execute(survivor);

      expect(
        log.where((e) => e == 'task.onPostExecute').length,
        1,
        reason: 'commands.task-runner-contract#3 — the scope is built on a '
            'SupervisorJob, so a failed job does not cancel the runner',
      );
    });

    test('execute runs its phases in order', () {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final listener = _LoggingTaskRunnerListener(log);
      runner.addListener(listener);
      var activeDuringBackground = -1;
      final task = _LoggingTask(
        log,
        onBackground: () => activeDuringBackground = runner.activeTaskCount,
      );

      runner.execute(task);

      expect(
        log,
        <String>[
          'task.onAttached',
          'runnerListener.onTaskStarted',
          'task.onPreExecute',
          'task.doInBackground',
          'task.onPostExecute',
          'runnerListener.onTaskFinished',
        ],
        reason: 'commands.task-runner-contract#4 — execute(task) runs '
            'onAttached, then onTaskStarted, onPreExecute, doInBackground, '
            'onPostExecute and onTaskFinished in that order',
      );
      expect(
        task.attachedRunner,
        same(runner),
        reason: 'commands.task-runner-contract#4 — task.onAttached(this) is '
            'called with the runner itself, before anything is launched',
      );
      expect(
        activeDuringBackground,
        1,
        reason: 'commands.task-runner-contract#4 — activeCount is incremented '
            'before the listeners are told the task started',
      );
      expect(
        runner.activeTaskCount,
        0,
        reason: 'commands.task-runner-contract#4 — activeCount is decremented '
            'after onPostExecute and before onTaskFinished',
      );
      expect(
        listener.finished.single,
        same(task),
        reason: 'commands.task-runner-contract#4 — onTaskFinished closes the '
            'sequence',
      );
    });

    test('a cancelled task skips doInBackground but still posts', () {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final listener = _LoggingTaskRunnerListener(log);
      runner.addListener(listener);
      final task = _LoggingTask(log, canceled: true);

      runner.execute(task);

      expect(
        log,
        <String>[
          'task.onAttached',
          'runnerListener.onTaskStarted',
          'task.onPreExecute',
          'task.onPostExecute',
          'runnerListener.onTaskFinished',
        ],
        reason: 'commands.task-runner-contract#5 — when isCanceled() is true '
            'doInBackground is skipped but onPostExecute is STILL called',
      );
    });

    test('await joins the outstanding jobs and clears the list', () async {
      final runner = CoroutineTaskRunner(
        mainDispatcher: const AsyncDispatcher(),
        ioDispatcher: const AsyncDispatcher(),
      );
      final first = _LoggingTask(log);
      final second = _LoggingTask(log);

      runner.execute(first);
      runner.execute(second);

      expect(
        log,
        <String>['task.onAttached', 'task.onAttached'],
        reason: 'commands.task-runner-contract#6 — each launched job is added '
            'to the internal jobs list and only runs once scheduled',
      );

      await runner.awaitAll();

      expect(
        log.where((e) => e == 'task.onPostExecute').length,
        2,
        reason: 'commands.task-runner-contract#6 — await() joins all '
            'outstanding jobs',
      );
      expect(
        runner.activeTaskCount,
        0,
        reason: 'commands.task-runner-contract#6 — every job is removed on '
            'completion',
      );

      await runner.awaitAll();

      expect(
        log.where((e) => e == 'task.onPostExecute').length,
        2,
        reason: 'commands.task-runner-contract#6 — await() clears the list, so '
            'a second await joins nothing',
      );
    });

    test('unconfined dispatchers make run() synchronous', () {
      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      final command = _LoggingCommand(log);

      commandRunner.run(command);

      expect(
        command.runCount,
        1,
        reason: 'commands.task-runner-contract#7 — with unconfined test '
            'dispatchers the command has executed by the time run() returns',
      );
      expect(
        listener.received.single,
        same(command),
        reason: 'commands.task-runner-contract#7 — listeners have been '
            'notified by the time run() returns',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.direct-run-bypass
  // -------------------------------------------------------------------------
  group('commands.direct-run-bypass', () {
    test('a directly executed command notifies no listener', () {
      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      final command = _LoggingCommand(log);

      command.run();

      expect(
        command.runCount,
        1,
        reason: 'commands.direct-run-bypass#1 — Command.run() can be called '
            'directly, bypassing CommandRunner entirely',
      );
      expect(
        listener.received,
        isEmpty,
        reason: 'commands.direct-run-bypass#1 — when a command is run directly '
            'NO listener is notified',
      );
      expect(
        log,
        <String>['command.run'],
        reason: 'commands.direct-run-bypass#1 — no widget refresh, no reminder '
            'rescheduling, no toast, no list-cache refresh',
      );
    });
  });

  // -------------------------------------------------------------------------
  // commands.test-harness
  // -------------------------------------------------------------------------
  group('commands.test-harness', () {
    test('setUp pins today to 2015-01-25', () {
      expect(
        getToday(),
        LocalDate.ymd(2015, 1, 25),
        reason: 'commands.test-harness#1 — setUp pins today to '
            'LocalDate(2015, 1, 25) before building anything',
      );
      expect(
        <int>[getToday().year, getToday().month, getToday().day],
        <int>[2015, 1, 25],
        reason: 'commands.test-harness#1 — command tests are deterministic '
            'because today never moves',
      );
    });

    test('setUp builds the same collaborators as BaseUnitTest', () {
      expect(
        memoryModelFactory,
        isA<MemoryModelFactory>(),
        reason: 'commands.test-harness#2 — the harness builds a '
            'MemoryModelFactory',
      );
      expect(
        habitList,
        isA<MemoryHabitList>(),
        reason: 'commands.test-harness#2 — habitList = '
            'memoryModelFactory.buildHabitList(), a MemoryHabitList',
      );
      expect(
        modelFactory,
        same(memoryModelFactory),
        reason: 'commands.test-harness#2 — modelFactory = memoryModelFactory',
      );
      expect(
        taskRunner,
        isA<CoroutineTaskRunner>(),
        reason: 'commands.test-harness#2 — taskRunner = '
            'CoroutineTaskRunner(UnconfinedTestDispatcher(), '
            'UnconfinedTestDispatcher())',
      );
      expect(
        commandRunner,
        isA<CommandRunner>(),
        reason: 'commands.test-harness#2 — commandRunner = '
            'CommandRunner(taskRunner)',
      );

      final habit = fixtures.createEmptyHabit();
      habitList.add(habit);
      expect(
        habitList.toList(),
        <Object>[habit],
        reason: 'commands.test-harness#2 — fixtures = '
            'HabitFixtures(memoryModelFactory, habitList) writes into that '
            'same list',
      );
    });

    test('run(cmd) completes before it returns', () {
      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      final command = _LoggingCommand(log);

      commandRunner.run(command);

      expect(
        log,
        <String>['command.run'],
        reason: 'commands.test-harness#3 — because both dispatchers are '
            'unconfined, run(cmd) completes before it returns',
      );
      expect(
        listener.received.single,
        same(command),
        reason: 'commands.test-harness#3 — listeners are notified before '
            'run(cmd) returns, letting tests assert immediately after the call',
      );
    });

    test('the direct path and the runner path are both supported', () {
      final listener = _MinimalCommandListener();
      commandRunner.addListener(listener);
      final direct = _LoggingCommand(log, 'direct');
      final dispatched = _LoggingCommand(log, 'dispatched');

      direct.run();
      commandRunner.run(dispatched);

      expect(
        log,
        <String>['direct.run', 'dispatched.run'],
        reason: 'commands.test-harness#4 — command tests call command.run() '
            'directly, while listener tests go through commandRunner.run(...)',
      );
      expect(
        listener.received,
        <Object>[dispatched],
        reason: 'commands.test-harness#4 — only the dispatched command reaches '
            'the listeners',
      );
    });

    test('the port provides a fixed today and an inline task runner', () {
      expect(
        getToday(),
        LocalDate.ymd(2015, 1, 25),
        reason: 'commands.test-harness#5 — knob one: a fixed today, set with '
            'setToday and cleared with resetToday',
      );

      final inline = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final task = _LoggingTask(log);
      inline.execute(task);

      expect(
        log,
        <String>[
          'task.onAttached',
          'task.onPreExecute',
          'task.doInBackground',
          'task.onPostExecute',
        ],
        reason: 'commands.test-harness#5 — knob two: an inline/synchronous '
            'task runner, built from two unconfined dispatchers',
      );
    });
  });
}
