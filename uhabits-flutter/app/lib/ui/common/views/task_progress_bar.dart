/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TaskProgressBar.kt.
///
/// An indeterminate horizontal progress bar that shows itself while the
/// [core.TaskRunner] has work in flight and hides itself when it goes quiet.
/// The Android class is a `ProgressBar` that is also a `TaskRunner.Listener`;
/// the two halves map onto a [StatefulWidget] exactly:
///
///  * `init { visibility = GONE; isIndeterminate = true }` is the initial
///    state (`charts-canvas-theming.task-progress-bar#1`);
///  * `onAttachedToWindow` / `onDetachedFromWindow` are [State.initState] and
///    [State.dispose] (`charts-canvas-theming.task-progress-bar#2`);
///  * `onTaskStarted` and `onTaskFinished` both call `update()`
///    (`charts-canvas-theming.task-progress-bar#3`);
///  * `update()` posts its decision 500 ms into the future, which is what
///    keeps a burst of short tasks from flickering the bar
///    (`charts-canvas-theming.task-progress-bar#4`).
///
/// A hidden Android `View` with visibility GONE takes no space, which is what
/// [SizedBox.shrink] does here.
library;

import 'dart:async';

import 'package:flutter/material.dart';
// The task runner is not re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/tasks/task_runner.dart' as core;

/// `TaskProgressBar(context, runner)`.
class TaskProgressBar extends StatefulWidget {
  const TaskProgressBar({required this.runner, super.key});

  /// `postDelayed(callback, 500)`.
  static const Duration updateDelay = Duration(milliseconds: 500);

  /// `android.R.attr.progressBarStyleHorizontal` with `isIndeterminate = true`
  /// is a 4dp-tall indeterminate bar.
  static const double thickness = 4.0;

  final core.TaskRunner runner;

  @override
  State<TaskProgressBar> createState() => TaskProgressBarState();
}

/// Public so a test can drive the lifecycle the way the window would.
class TaskProgressBarState extends State<TaskProgressBar>
    implements core.TaskRunnerListener {
  /// `visibility`, as the two states this view ever takes.
  ///
  /// Starts hidden: `init { visibility = View.GONE }`
  /// (`charts-canvas-theming.task-progress-bar#1`).
  bool isVisible = false;

  /// `isIndeterminate = true`, set once in the initialiser and never changed.
  bool get isIndeterminate => true;

  Timer? _pending;

  @override
  void initState() {
    super.initState();
    // `onAttachedToWindow`: register, then decide straight away.
    widget.runner.addListener(this);
    update();
  }

  @override
  void dispose() {
    // `onDetachedFromWindow`: unregister. The posted callback dies with the
    // view too — a detached Android View's handler no longer runs it.
    widget.runner.removeListener(this);
    _pending?.cancel();
    _pending = null;
    super.dispose();
  }

  /// `override fun onTaskStarted(task: Task) = update()`.
  @override
  void onTaskStarted(core.Task task) => update();

  /// `override fun onTaskFinished(task: Task) = update()`.
  @override
  void onTaskFinished(core.Task task) => update();

  /// ```kotlin
  /// fun update() {
  ///     val callback = {
  ///         val newVisibility = when (runner.activeTaskCount) {
  ///             0 -> GONE
  ///             else -> VISIBLE
  ///         }
  ///         if (visibility != newVisibility) visibility = newVisibility
  ///     }
  ///     postDelayed(callback, 500)
  /// }
  /// ```
  ///
  /// The count is read *when the callback runs*, not when `update` is called,
  /// so a task that starts and finishes inside the delay never shows the bar.
  /// Each call posts its own callback: Kotlin does not cancel the previous
  /// one, and neither does this — a second timer is armed alongside the first.
  void update() {
    _pending = Timer(TaskProgressBar.updateDelay, () {
      final newVisibility = widget.runner.activeTaskCount != 0;
      // `if (visibility != newVisibility)`: the assignment is skipped when
      // nothing changed, so an idle screen never rebuilds.
      if (isVisible == newVisibility) return;
      if (!mounted) return;
      setState(() => isVisible = newVisibility);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    return const SizedBox(
      height: TaskProgressBar.thickness,
      child: LinearProgressIndicator(),
    );
  }
}
