/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/CoroutineTaskRunner.kt
///
/// `execute` launches the task coroutine on the *main* dispatcher and
/// `publishProgress` does `scope.launch { task.onProgressUpdate(progress) }` on
/// that very same dispatcher, so every progress runnable is posted to the main
/// queue while `doInBackground` is still on the io dispatcher — strictly before
/// `withContext(ioDispatcher)` posts its own continuation back. The main queue
/// is FIFO, so `onPostExecute` always lands last.
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'dart:async';

import 'package:test/test.dart';
// ignore: implementation_imports
import 'package:uhabits_core/src/tasks/task_runner.dart';

/// A task shaped like `HabitCardListCache.RefreshTask`: it publishes progress
/// from inside `doInBackground` and does its user-visible work in
/// `onPostExecute`.
class _ProgressTask extends Task {
  _ProgressTask(this.log, {this.steps = 2});

  final List<String> log;
  final int steps;
  TaskRunner? runner;

  @override
  void onAttached(TaskRunner runner) => this.runner = runner;

  @override
  void onPreExecute() => log.add('pre');

  @override
  FutureOr<void> doInBackground() {
    log.add('bg-start');
    runner!.publishProgress(this, -1);
    for (var i = 0; i < steps; i++) {
      runner!.publishProgress(this, i);
    }
    log.add('bg-end');
    return null;
  }

  @override
  void onProgressUpdate(int currentPosition) =>
      log.add('progress($currentPosition)');

  @override
  void onPostExecute() => log.add('post');
}

class _RecordingListener implements TaskRunnerListener {
  _RecordingListener(this.log);

  final List<String> log;

  @override
  void onTaskStarted(Task task) => log.add('started');

  @override
  void onTaskFinished(Task task) => log.add('finished');
}

void main() {
  const String rule =
      'audit10.task-runner-progress-before-post#1 — publishProgress and the '
      'post-background continuation are both posted to the main dispatcher, '
      'which is FIFO, so every progress callback queued by doInBackground runs '
      'before onPostExecute.';

  test('onPostExecute runs after the progress callbacks doInBackground queued',
      () async {
    final log = <String>[];
    final runner = CoroutineTaskRunner(
      mainDispatcher: const AsyncDispatcher(),
      ioDispatcher: const AsyncDispatcher(),
    );
    runner.execute(_ProgressTask(log));
    await runner.awaitAll();
    // Anything still sitting on the event queue gets its turn.
    await Future<void>.delayed(Duration.zero);

    expect(
      log,
      <String>[
        'pre',
        'bg-start',
        'bg-end',
        'progress(-1)',
        'progress(0)',
        'progress(1)',
        'post',
      ],
      reason: rule,
    );
  });

  test('onTaskFinished also lands after the queued progress callbacks',
      () async {
    final log = <String>[];
    final runner = CoroutineTaskRunner(
      mainDispatcher: const AsyncDispatcher(),
      ioDispatcher: const AsyncDispatcher(),
    );
    runner.addListener(_RecordingListener(log));
    runner.execute(_ProgressTask(log, steps: 1));
    await runner.awaitAll();
    await Future<void>.delayed(Duration.zero);

    expect(
      log,
      <String>[
        'started',
        'pre',
        'bg-start',
        'bg-end',
        'progress(-1)',
        'progress(0)',
        'post',
        'finished',
      ],
      reason: '$rule activeCount-- and the listener notification are the tail '
          'of the same resumed coroutine as onPostExecute.',
    );
  });

  test('an inline runner keeps running the whole pipeline on one stack', () {
    final log = <String>[];
    final runner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    runner.execute(_ProgressTask(log, steps: 1));

    expect(
      log,
      <String>[
        'pre',
        'bg-start',
        'progress(-1)',
        'progress(0)',
        'bg-end',
        'post',
      ],
      reason: '$rule With two UnconfinedTestDispatchers — the wiring '
          'BaseUnitTest uses — nothing is ever queued, so the ordering fix '
          'must not push any of it onto the event loop.',
    );
  });
}
