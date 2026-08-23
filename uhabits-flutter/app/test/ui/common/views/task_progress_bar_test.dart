/// Widget tests for the background-work indicator.
///
/// Ported from
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TaskProgressBar.kt,
/// which has no Kotlin test; every assertion below cites the rule in
/// docs/parity/FEATURES.md it comes from.
library;

// The task runner is not re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/common/views/task_progress_bar.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';

void main() {
  late _FakeTaskRunner runner;

  setUp(() => runner = _FakeTaskRunner());

  Widget wrap() => MaterialApp(
        home: Scaffold(body: TaskProgressBar(runner: runner)),
      );

  TaskProgressBarState stateOf(WidgetTester tester) =>
      tester.state<TaskProgressBarState>(find.byType(TaskProgressBar));

  testWidgets('#1 it starts hidden and indeterminate', (tester) async {
    await tester.pumpWidget(wrap());

    final state = stateOf(tester);
    expect(state.isVisible, isFalse,
        reason: 'charts-canvas-theming.task-progress-bar#1 — '
            'init { visibility = View.GONE }');
    expect(state.isIndeterminate, isTrue,
        reason: 'charts-canvas-theming.task-progress-bar#1 — '
            'isIndeterminate = true');
    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'charts-canvas-theming.task-progress-bar#1 — a GONE view '
            'takes no space');

    // Nothing has started, so even after the delay it stays hidden.
    await tester.pump(TaskProgressBar.updateDelay);
    expect(stateOf(tester).isVisible, isFalse,
        reason: 'charts-canvas-theming.task-progress-bar#1');
  });

  testWidgets('#2 it listens only while attached, and updates on attach',
      (tester) async {
    expect(runner.listeners, isEmpty);

    await tester.pumpWidget(wrap());
    expect(runner.listeners, hasLength(1),
        reason: 'charts-canvas-theming.task-progress-bar#2 — '
            'onAttachedToWindow registers the listener');

    // `onAttachedToWindow` also calls update() immediately, so a runner that
    // was already busy before the bar existed still shows it.
    runner.activeTaskCount = 2;
    await tester.pumpWidget(wrap());
    await tester.pump(TaskProgressBar.updateDelay);
    expect(stateOf(tester).isVisible, isTrue,
        reason: 'charts-canvas-theming.task-progress-bar#2 — and calls '
            'update() straight away');

    await tester.pumpWidget(const SizedBox.shrink());
    expect(runner.listeners, isEmpty,
        reason: 'charts-canvas-theming.task-progress-bar#2 — '
            'onDetachedFromWindow unregisters it');
  });

  testWidgets('#3 both task callbacks go through update()', (tester) async {
    await tester.pumpWidget(wrap());

    runner.activeTaskCount = 1;
    runner.notifyStarted();
    await tester.pump(TaskProgressBar.updateDelay);
    expect(stateOf(tester).isVisible, isTrue,
        reason: 'charts-canvas-theming.task-progress-bar#3 — onTaskStarted '
            'calls update()');

    runner.activeTaskCount = 0;
    runner.notifyFinished();
    await tester.pump(TaskProgressBar.updateDelay);
    expect(stateOf(tester).isVisible, isFalse,
        reason: 'charts-canvas-theming.task-progress-bar#3 — and so does '
            'onTaskFinished');
  });

  testWidgets('#4 the decision is 500 ms late, which is what hides short '
      'tasks', (tester) async {
    await tester.pumpWidget(wrap());

    expect(TaskProgressBar.updateDelay, const Duration(milliseconds: 500),
        reason: 'charts-canvas-theming.task-progress-bar#4 — '
            'postDelayed(callback, 500)');

    // A task that starts and finishes inside the delay never shows the bar:
    // the callback reads activeTaskCount when it runs, not when it is posted.
    runner.activeTaskCount = 1;
    runner.notifyStarted();
    await tester.pump(const Duration(milliseconds: 300));
    expect(stateOf(tester).isVisible, isFalse,
        reason: 'charts-canvas-theming.task-progress-bar#4 — nothing happens '
            'before the delay elapses');
    runner.activeTaskCount = 0;
    runner.notifyFinished();
    await tester.pump(const Duration(milliseconds: 500));
    expect(stateOf(tester).isVisible, isFalse,
        reason: 'charts-canvas-theming.task-progress-bar#4 — the 500 ms delay '
            'is what prevents flicker for short tasks');

    // A task that outlives the delay does show it.
    runner.activeTaskCount = 1;
    runner.notifyStarted();
    await tester.pump(TaskProgressBar.updateDelay);
    expect(stateOf(tester).isVisible, isTrue,
        reason: 'charts-canvas-theming.task-progress-bar#4 — VISIBLE when '
            'activeTaskCount is not 0');
    expect(find.byType(LinearProgressIndicator), findsOneWidget,
        reason: 'charts-canvas-theming.task-progress-bar#4');

    // The assignment is skipped when nothing changed, so a second update that
    // agrees with the current state rebuilds nothing.
    final rebuildsBefore = tester.state<TaskProgressBarState>(
      find.byType(TaskProgressBar),
    );
    runner.notifyStarted();
    await tester.pump(TaskProgressBar.updateDelay);
    expect(identical(stateOf(tester), rebuildsBefore), isTrue,
        reason: 'charts-canvas-theming.task-progress-bar#4 — '
            'if (visibility != newVisibility)');
    expect(stateOf(tester).isVisible, isTrue,
        reason: 'charts-canvas-theming.task-progress-bar#4');

    runner.activeTaskCount = 0;
    runner.notifyFinished();
    await tester.pump(TaskProgressBar.updateDelay);
    expect(stateOf(tester).isVisible, isFalse,
        reason: 'charts-canvas-theming.task-progress-bar#4 — GONE when the '
            'count is back to 0');
  });
}

/// A [TaskRunner] whose active count the test sets by hand.
class _FakeTaskRunner implements TaskRunner {
  final List<TaskRunnerListener> listeners = <TaskRunnerListener>[];

  @override
  int activeTaskCount = 0;

  @override
  void addListener(TaskRunnerListener listener) => listeners.add(listener);

  @override
  void removeListener(TaskRunnerListener listener) =>
      listeners.remove(listener);

  @override
  void execute(Task task) => throw UnimplementedError();

  @override
  void publishProgress(Task task, int progress) =>
      throw UnimplementedError();

  @override
  Future<void> awaitAll() => throw UnimplementedError();

  void notifyStarted() {
    for (final listener in List<TaskRunnerListener>.of(listeners)) {
      listener.onTaskStarted(_NoopTask());
    }
  }

  void notifyFinished() {
    for (final listener in List<TaskRunnerListener>.of(listeners)) {
      listener.onTaskFinished(_NoopTask());
    }
  }
}

class _NoopTask extends Task {
  @override
  void doInBackground() {}
}
