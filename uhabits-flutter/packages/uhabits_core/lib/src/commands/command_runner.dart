import 'dart:async';

import '../tasks/task_runner.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CommandRunner.kt
///
/// One instance exists for the whole application (`@AppScope` in Kotlin), built
/// from a single dependency: a [TaskRunner].
///
/// [run] never executes the command on the caller's stack. It wraps it in a
/// [Task] whose `doInBackground` calls `command.run()` and whose
/// `onPostExecute` calls [notifyListeners], then hands that task to the task
/// runner. Nothing is deduplicated, coalesced, batched, queued or serialized:
/// two calls in quick succession are two independent tasks.
///
/// If `command.run()` throws, `onPostExecute` is never reached, so no listener
/// is notified and the UI is left stale — the exception escapes into the
/// scope's uncaught-exception path.
///
/// Everything here is `open` in Kotlin so tests can subclass and stub it; Dart
/// classes are open by default, and [notifyListeners] is deliberately public so
/// a test can simulate a finished command without executing it.
class CommandRunner {
  CommandRunner(this._taskRunner);

  final TaskRunner _taskRunner;

  /// Insertion-ordered. There is no priority, no filtering and no way for a
  /// listener to stop propagation.
  final List<CommandRunnerListener> _listeners = <CommandRunnerListener>[];

  void run(Command command) {
    _taskRunner.execute(_CommandTask(this, command));
  }

  /// Appends without a duplicate check: registering the same listener twice
  /// makes it receive each command twice.
  void addListener(CommandRunnerListener l) {
    _listeners.add(l);
  }

  /// Notifies every listener, front to back, for every command type.
  void notifyListeners(Command command) {
    for (final l in _listeners) {
      l.onCommandFinished(command);
    }
  }

  /// Removes the first matching element. Removing a listener that was never
  /// added is a silent no-op.
  void removeListener(CommandRunnerListener l) {
    _listeners.remove(l);
  }
}

/// Port of `CommandRunner.Listener`. Dart has no nested classes, so the Kotlin
/// inner interface becomes a top-level one. It has exactly one method.
abstract interface class CommandRunnerListener {
  void onCommandFinished(Command command);
}

/// The anonymous `object : Task` that [CommandRunner.run] builds.
class _CommandTask extends Task {
  _CommandTask(this._runner, this._command);

  final CommandRunner _runner;

  final Command _command;

  @override
  FutureOr<void> doInBackground() {
    _command.run();
  }

  @override
  void onPostExecute() {
    _runner.notifyListeners(_command);
  }
}
