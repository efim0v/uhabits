/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/Task.kt,
/// .../tasks/TaskRunner.kt and .../tasks/CoroutineTaskRunner.kt
///
/// Kotlin splits every task across two coroutine dispatchers: the prologue and
/// the epilogue run on the *main* dispatcher, and `doInBackground` runs on the
/// *io* one. Dart has no such thing, so [Dispatcher] stands in for
/// `CoroutineDispatcher`: it decides whether a block of work runs immediately
/// on the caller's stack or is handed to the event loop.
///
/// The distinction matters because the Kotlin unit tests build the runner from
/// two `UnconfinedTestDispatcher`s, which makes the whole pipeline run inline —
/// by the time `commandRunner.run(cmd)` returns, the command has executed and
/// its listeners have been notified. Reproducing that property is what keeps
/// the ported command tests synchronous, and it is why nothing on the fast path
/// below is declared `async`: a single `await` would push the continuation onto
/// the microtask queue and break it.
library;

import 'dart:async';

/// Port of `kotlinx.coroutines.CoroutineDispatcher`, narrowed to the one thing
/// [CoroutineTaskRunner] asks of it.
abstract interface class Dispatcher {
  /// Runs [block] according to this dispatcher's scheduling policy.
  ///
  /// Returns `null` when [block] ran to completion synchronously, and a future
  /// otherwise. Callers must treat both cases, exactly as a Kotlin coroutine
  /// treats a suspension point that happens not to suspend.
  FutureOr<void> dispatch(FutureOr<void> Function() block);
}

/// Port of `kotlinx.coroutines.test.UnconfinedTestDispatcher`.
///
/// Runs the block immediately on the caller's stack, without scheduling. This
/// is the dispatcher `BaseUnitTest` uses for both the main and the io role.
class UnconfinedTestDispatcher implements Dispatcher {
  const UnconfinedTestDispatcher();

  @override
  FutureOr<void> dispatch(FutureOr<void> Function() block) => block();
}

/// Port of `Dispatchers.Main` / `Dispatchers.IO` for the single-threaded Dart
/// event loop: the block never runs on the caller's stack.
///
/// Dart has one isolate per app, so "main" and "io" cannot be different
/// threads; what survives the port is that the work is deferred, which is the
/// property the production code depends on.
class AsyncDispatcher implements Dispatcher {
  const AsyncDispatcher();

  @override
  Future<void> dispatch(FutureOr<void> Function() block) =>
      Future<void>(() => block());
}

/// Port of `Task`.
///
/// Kotlin declares it as a `fun interface` whose only abstract member is
/// `doInBackground`; every other member is defaulted to a no-op. Dart gets the
/// same shape from an abstract class with concrete defaults.
///
/// `doInBackground` is `suspend` in Kotlin. Here it returns `FutureOr<void>` so
/// that a task with nothing to await — such as the one [CommandRunner] builds —
/// can complete synchronously.
abstract class Task {
  /// Asks this task to stop. Defaults to a no-op.
  void cancel() {}

  /// Whether this task has been cancelled. Defaults to `false`.
  bool isCanceled() => false;

  /// The task's work. The only member an implementation must provide.
  FutureOr<void> doInBackground();

  /// Called by the runner, on the caller's stack, before anything is launched.
  void onAttached(TaskRunner runner) {}

  /// Called after [doInBackground], back on the main dispatcher.
  void onPostExecute() {}

  /// Called before [doInBackground], on the main dispatcher.
  void onPreExecute() {}

  /// Called from [TaskRunner.publishProgress].
  void onProgressUpdate(int currentPosition) {}
}

/// Port of `TaskRunner`.
abstract interface class TaskRunner {
  void addListener(TaskRunnerListener listener);

  void removeListener(TaskRunnerListener listener);

  void execute(Task task);

  void publishProgress(Task task, int progress);

  int get activeTaskCount;

  /// Port of `suspend fun await()`.
  ///
  /// Renamed because `await` cannot be used as an identifier inside an `async`
  /// function in Dart, which would make the method uncallable from the very
  /// code that needs it.
  Future<void> awaitAll();
}

/// Port of `TaskRunner.Listener`. Dart has no nested classes, so the Kotlin
/// inner interface becomes a top-level one.
abstract interface class TaskRunnerListener {
  void onTaskStarted(Task task);

  void onTaskFinished(Task task);
}

/// Port of `CoroutineTaskRunner`.
///
/// Kotlin owns a `CoroutineScope(SupervisorJob() + mainDispatcher)`. The
/// `SupervisorJob` means a job that fails does not cancel its siblings or the
/// scope; the Dart equivalent is simply that [execute] keeps no state that a
/// failure could poison, so the next [execute] behaves normally. As in Kotlin,
/// a throwing task is not caught here: the exception escapes into the ambient
/// uncaught-exception path, and `onPostExecute` is not reached.
///
/// The `activeCount` decrement is the one place this port deliberately parts
/// company with Kotlin. Upstream a throw skips it too, but on Android the
/// exception ends the process, so nothing observes the leak. In Dart it becomes
/// an unhandled asynchronous error, the app carries on, and the leaked count
/// keeps `TaskProgressBar` on screen for the rest of the session
/// (`feedback.the-task-progress-bar-never-hides-again#1`). The counter is
/// therefore released on every path.
class CoroutineTaskRunner implements TaskRunner {
  CoroutineTaskRunner({
    required Dispatcher mainDispatcher,
    required Dispatcher ioDispatcher,
  })  : _mainDispatcher = mainDispatcher,
        _ioDispatcher = ioDispatcher;

  /// `CoroutineScope(SupervisorJob() + mainDispatcher)` in Kotlin.
  final Dispatcher _mainDispatcher;

  final Dispatcher _ioDispatcher;

  final List<TaskRunnerListener> _listeners = <TaskRunnerListener>[];

  /// The `jobs` list: every launched job, removed again on completion.
  final List<Future<void>> _jobs = <Future<void>>[];

  int _activeCount = 0;

  @override
  int get activeTaskCount => _activeCount;

  @override
  void addListener(TaskRunnerListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(TaskRunnerListener listener) {
    _listeners.remove(listener);
  }

  @override
  void execute(Task task) {
    task.onAttached(this);
    final FutureOr<void> job = _mainDispatcher.dispatch(() {
      _activeCount++;
      for (final l in _listeners) {
        l.onTaskStarted(task);
      }
      // Whatever the task does, the bookkeeping below runs exactly once, so
      // `activeTaskCount` always comes back down (`feedback.the-task-progress-
      // bar-never-hides-again#1`). The exception itself is not caught: it goes
      // on escaping, as it does in Kotlin.
      var released = false;
      void release() {
        if (released) return;
        released = true;
        _release(task);
      }

      try {
        task.onPreExecute();
        if (task.isCanceled()) {
          _finish(task, release);
          return null;
        }
        return _andThen(
          _ioDispatcher.dispatch(() => task.doInBackground()),
          () => _finish(task, release),
          release,
        );
      } catch (error, stack) {
        release();
        Error.throwWithStackTrace(error, stack);
      }
    });
    if (job is Future<void>) {
      // `job.invokeOnCompletion { jobs.remove(job) }` followed by
      // `jobs.add(job)`.
      late final Future<void> tracked;
      tracked = job.whenComplete(() => _jobs.remove(tracked));
      _jobs.add(tracked);
    }
  }

  /// The success epilogue. `onPostExecute` publishes what the background step
  /// produced, so it belongs to this path only; a task that threw produced
  /// nothing to publish.
  void _finish(Task task, void Function() release) {
    try {
      task.onPostExecute();
    } finally {
      release();
    }
  }

  /// The half of the epilogue every outcome shares: the counter comes back
  /// down and the listeners — `TaskProgressBar` among them — are told.
  void _release(Task task) {
    _activeCount--;
    for (final l in _listeners) {
      l.onTaskFinished(task);
    }
  }

  /// `withContext(ioDispatcher) { ... }` followed by the epilogue.
  ///
  /// When the background step did not actually suspend, Kotlin's
  /// `DispatchedCoroutine` bails out of the round trip (`afterResume` sees that
  /// the caller never suspended) and the epilogue continues on this very stack;
  /// [value] not being a `Future` is the same situation, so [block] is called
  /// directly.
  ///
  /// When it did suspend, `withContext` resumes the outer coroutine by posting
  /// the continuation **to the main dispatcher**, which is the same queue
  /// [publishProgress] posts to — and it posts it *after* every progress
  /// runnable `doInBackground` already queued, because the queue is FIFO. So
  /// the epilogue is handed back to [_mainDispatcher] rather than chained with
  /// a bare `then`: `then` schedules a microtask, Dart drains the microtask
  /// queue before the next event, and the epilogue would overtake the very
  /// progress callbacks it is supposed to follow
  /// (`audit10.task-runner-progress-before-post#1`).
  ///
  /// [onError] runs instead of [block] when the background step fails, and the
  /// failure is then re-thrown untouched. It takes the same route back: in
  /// Kotlin a `withContext` block that throws also resumes the caller on the
  /// main dispatcher.
  FutureOr<void> _andThen(
    FutureOr<void> value,
    void Function() block,
    void Function() onError,
  ) {
    if (value is Future<void>) {
      return value.then(
        (_) => _mainDispatcher.dispatch(block),
        onError: (Object error, StackTrace stack) =>
            _rethrowAfter(_mainDispatcher.dispatch(onError), error, stack),
      );
    }
    block();
    return null;
  }

  /// Re-throws [error] once [resumed] — the failure half of the epilogue, back
  /// on the main dispatcher — has run, so the counter is always released
  /// before the exception escapes.
  static FutureOr<void> _rethrowAfter(
    FutureOr<void> resumed,
    Object error,
    StackTrace stack,
  ) {
    if (resumed is Future<void>) {
      return resumed.then((_) => Error.throwWithStackTrace(error, stack));
    }
    Error.throwWithStackTrace(error, stack);
  }

  @override
  Future<void> awaitAll() async {
    await Future.wait<void>(List<Future<void>>.of(_jobs));
    _jobs.clear();
  }

  @override
  void publishProgress(Task task, int progress) {
    _mainDispatcher.dispatch(() => task.onProgressUpdate(progress));
  }
}
