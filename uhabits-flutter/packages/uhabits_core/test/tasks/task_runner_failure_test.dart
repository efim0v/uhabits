import 'dart:async';

import 'package:test/test.dart';
// ignore: implementation_imports
import 'package:uhabits_core/src/tasks/task_runner.dart';

/// A task that fails the way a real one does: while doing its background work.
class _ThrowingTask extends Task {
  bool postExecuted = false;

  @override
  FutureOr<void> doInBackground() => throw StateError('boom');

  @override
  void onPostExecute() => postExecuted = true;
}

class _AsyncThrowingTask extends Task {
  @override
  Future<void> doInBackground() async => throw StateError('boom');
}

class _InlineTask extends Task {
  _InlineTask(this.body);

  final void Function() body;

  @override
  FutureOr<void> doInBackground() {
    body();
  }
}

class _RecordingListener implements TaskRunnerListener {
  final List<Task> started = <Task>[];
  final List<Task> finished = <Task>[];

  @override
  void onTaskStarted(Task task) => started.add(task);

  @override
  void onTaskFinished(Task task) => finished.add(task);
}

void main() {
  const String rule =
      'feedback.the-task-progress-bar-never-hides-again#1 — a throwing task '
      'must not leak activeTaskCount: the progress bar is visible exactly '
      'while the count is non-zero, so a leak pins it on screen for the rest '
      'of the session.';

  test('a task that throws synchronously still releases the counter', () {
    final runner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    final listener = _RecordingListener();
    runner.addListener(listener);
    final task = _ThrowingTask();

    expect(() => runner.execute(task), throwsStateError,
        reason: '$rule The failure still has to be loud.');

    expect(runner.activeTaskCount, 0, reason: rule);
    expect(listener.finished.single, same(task),
        reason: '$rule The progress bar listens for onTaskFinished.');
    expect(task.postExecuted, isFalse,
        reason: '$rule onPostExecute is the success epilogue; a task that '
            'threw never produced the result it would publish.');
  });

  test('a task that throws asynchronously still releases the counter',
      () async {
    final runner = CoroutineTaskRunner(
      mainDispatcher: const AsyncDispatcher(),
      ioDispatcher: const AsyncDispatcher(),
    );
    final listener = _RecordingListener();
    runner.addListener(listener);
    runner.execute(_AsyncThrowingTask());

    await expectLater(runner.awaitAll(), throwsStateError, reason: rule);

    expect(runner.activeTaskCount, 0, reason: rule);
    expect(listener.finished, hasLength(1), reason: rule);
  });

  test('the next task still runs normally after a failure', () {
    final runner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    expect(() => runner.execute(_ThrowingTask()), throwsStateError);

    var ran = false;
    runner.execute(_InlineTask(() => ran = true));
    expect(ran, isTrue, reason: rule);
    expect(runner.activeTaskCount, 0, reason: rule);
  });
}
