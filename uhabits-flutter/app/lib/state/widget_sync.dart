// The core is reached by its `src` path, exactly as lib/state/app_scope.dart
// reaches it.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

import '../platform/home_widget_bridge.dart';

/// Port of `uhabits-android/.../widgets/WidgetUpdater.kt`.
///
/// A `CommandRunner.Listener` that republishes the home-screen widget data
/// after every command, and a `MidnightTimer.MidnightListener` that does the
/// same when the logical day rolls over.
///
/// ## What survived the port and what did not
///
/// `WidgetUpdater` does two things: it decides *which* widgets a finished
/// command touches, and it delivers that decision as an Android broadcast. The
/// first half is portable and is reproduced exactly — the
/// `CreateRepetitionCommand` special case, the habit-id filtering, the fixed
/// order of the six providers, the broadcast that goes out even when the
/// filtered id array is empty. The second half is not: [HomeWidgetBridge]
/// writes JSON into shared storage and pokes the native widget host instead.
///
/// The rollover is the larger substitution. Upstream, `scheduleStartDayWidget
/// Update()` computes `DateUtils.getStartOfTomorrowWithOffset(midnightDelay
/// Hours, 0)` and hands it to `IntentScheduler.scheduleWidgetUpdate`, which
/// sets an `AlarmManager` RTC alarm on a `PendingIntent` broadcasting
/// `ACTION_UPDATE_WIDGETS_VALUE` to `WidgetReceiver`; the receiver then calls
/// `setToday`, `updateWidgets()` and `scheduleStartDayWidgetUpdate()` in that
/// order, so each firing arms the next one. Flutter has no `AlarmManager`, and
/// the port already owns a cross-platform clock for exactly this event: the
/// core's [MidnightTimer], which fires at the same instant
/// (`millisecondsUntilTomorrowWithOffset(midnightDelayHours, 0)`) and whose
/// `_notifyListeners` already performs the receiver's first step —
/// `setToday(computeToday(midnightDelayHours, 0))` — before calling its
/// listeners. [_onMidnight] therefore contains only the remaining two steps, in
/// the same order.
///
/// The timestamp itself is still computed and exposed as
/// [nextStartOfDayUpdate], because it is the one part of the alarm that is
/// observable: it is what the native side would have to be told if a platform
/// ever gains a real rollover alarm, and it is what
/// `widgets.day-rollover#9` pins down (next local 00:00, or 03:00 with the
/// midnight delay enabled).
///
/// [MidnightTimer] must be resumed by whoever owns the app scope; this class
/// only subscribes to it.
class WidgetSync implements CommandRunnerListener {
  WidgetSync({
    required HomeWidgetBridge bridge,
    required CommandRunner commandRunner,
    required TaskRunner taskRunner,
    required MidnightTimer midnightTimer,
    required Preferences preferences,
  })  : _bridge = bridge,
        _commandRunner = commandRunner,
        _taskRunner = taskRunner,
        _midnightTimer = midnightTimer,
        _preferences = preferences {
    midnightListener = MidnightListener.of(_onMidnight);
  }

  final HomeWidgetBridge _bridge;

  final CommandRunner _commandRunner;

  final TaskRunner _taskRunner;

  final MidnightTimer _midnightTimer;

  final Preferences _preferences;

  /// The rollover subscription. Exposed because it is the port's
  /// `PendingIntent`: holding one instance is what makes the rollover
  /// non-stackable.
  late final MidnightListener midnightListener;

  bool _armed = false;

  int? _nextStartOfDayUpdate;

  /// The epoch-millisecond instant the widgets are next due to redraw, or null
  /// before [scheduleStartDayWidgetUpdate] has ever run.
  int? get nextStartOfDayUpdate => _nextStartOfDayUpdate;

  final List<Future<void>> _pending = <Future<void>>[];

  /// `HabitsApplication.onCreate`: subscribe, arm the rollover, then refresh
  /// everything from a task.
  Future<void> start() async {
    startListening();
    scheduleStartDayWidgetUpdate();
    await updateWidgets();
  }

  /// Registers with the [CommandRunner]. Like upstream there is no duplicate
  /// check — `CommandRunner.addListener` appends — so calling this twice makes
  /// every command publish twice.
  void startListening() {
    _commandRunner.addListener(this);
  }

  /// Unregisters from the [CommandRunner] and disarms the rollover.
  ///
  /// `HabitsApplication.onTerminate` only calls `stopListening()`, and the
  /// pending `AlarmManager` alarm outlives the process by design; here there is
  /// no process boundary — the timer is an object in the same isolate — so
  /// dropping the subscription is what "stop" has to mean.
  void stopListening() {
    _commandRunner.removeListener(this);
    _midnightTimer.removeListener(midnightListener);
    _armed = false;
  }

  /// Port of `WidgetUpdater.onCommandFinished`.
  ///
  /// A `CreateRepetitionCommand` refreshes only the widgets bound to its habit;
  /// every other command type refreshes all of them. Note that a
  /// `CreateRepetitionCommand` whose habit has a null id passes null and
  /// therefore also refreshes all of them — unlike `HabitCardListCache`, which
  /// skips entirely in that case.
  @override
  void onCommandFinished(Command command) {
    if (command is CreateRepetitionCommand) {
      updateWidgets(command.habit.id);
    } else {
      updateWidgets();
    }
  }

  /// Port of `WidgetUpdater.updateWidgets(modifiedHabitId)`.
  ///
  /// The work runs on the [TaskRunner], as upstream, and the returned future
  /// completes when the publish has reached the platform.
  Future<void> updateWidgets([int? modifiedHabitId]) {
    final _PublishTask task = _PublishTask(_bridge, modifiedHabitId);
    _taskRunner.execute(task);
    final Future<void> done = task.completed.future;
    _pending.add(done);
    return done;
  }

  /// Port of `WidgetUpdater.scheduleStartDayWidgetUpdate()`.
  ///
  /// Returns the instant the widgets are next due to redraw:
  /// `getStartOfTomorrowWithOffset(preferences.midnightDelayHours, 0)`, which
  /// is the next local 00:00, or the next 03:00 when the midnight delay is
  /// enabled.
  ///
  /// Calling it repeatedly re-arms rather than stacks, which is what
  /// `FLAG_UPDATE_CURRENT` on a request-code-0 `PendingIntent` buys upstream:
  /// only one rollover can ever be pending.
  int scheduleStartDayWidgetUpdate() {
    final int timestamp = DateUtils.getStartOfTomorrowWithOffset(
      _preferences.midnightDelayHours,
      0,
    );
    _nextStartOfDayUpdate = timestamp;
    if (!_armed) {
      _midnightTimer.addListener(midnightListener);
      _armed = true;
    }
    return timestamp;
  }

  /// Awaits every publish issued so far. For tests and for shutdown.
  Future<void> settle() async {
    while (_pending.isNotEmpty) {
      final List<Future<void>> batch = List<Future<void>>.of(_pending);
      _pending.clear();
      await Future.wait<void>(batch);
    }
  }

  /// The `ACTION_UPDATE_WIDGETS_VALUE` branch of `WidgetReceiver`, minus its
  /// first step: [MidnightTimer] has already called
  /// `setToday(computeToday(midnightDelayHours, 0))` by the time this runs.
  ///
  /// Nothing is parsed out of the event — this is the one widget action that
  /// carries neither a habit nor a date — so the refresh is unfiltered.
  void _onMidnight() {
    updateWidgets();
    scheduleStartDayWidgetUpdate();
  }
}

/// The `taskRunner.execute { ... }` block of `WidgetUpdater.updateWidgets`.
class _PublishTask extends Task {
  _PublishTask(this._bridge, this._modifiedHabitId);

  final HomeWidgetBridge _bridge;

  final int? _modifiedHabitId;

  final Completer<void> completed = Completer<void>();

  @override
  Future<void> doInBackground() async {
    try {
      await _bridge.publish(_modifiedHabitId);
    } catch (error, stackTrace) {
      // A throwing task escapes the runner without reaching onPostExecute, so
      // the completer has to be settled here or every caller of `settle()`
      // would hang.
      if (!completed.isCompleted) completed.completeError(error, stackTrace);
      rethrow;
    }
  }

  @override
  void onPostExecute() {
    if (!completed.isCompleted) completed.complete();
  }
}

// ---------------------------------------------------------------------------
// WidgetBehavior
// ---------------------------------------------------------------------------

/// Port of
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/widgets/WidgetBehavior.kt`.
///
/// The core logic behind a widget tap: five entry points that all funnel into
/// [setValue], which runs a `CreateRepetitionCommand` on the [CommandRunner].
/// Because that command type is what `WidgetUpdater` special-cases, a tap
/// refreshes only the widgets bound to the habit it touched — see
/// [WidgetSync.onCommandFinished].
///
/// It lives next to [WidgetSync] rather than in `uhabits_core` because the
/// core has no Dart port of it yet; it belongs in the core the moment one
/// exists, and nothing here depends on Flutter.
///
/// Three details are load-bearing and easy to lose:
///
///  * add and remove cancel the notification *before* running the command,
///    while toggle, increment and decrement cancel *after* it;
///  * add, remove and toggle read `originalEntries` while increment and
///    decrement read `computedEntries`;
///  * only toggle ever reads `Preferences.isSkipEnabled`.
///
/// Increment and decrement take raw thousandths and clamp nothing: the value
/// may go negative, and it may exceed the target.
class WidgetBehavior {
  WidgetBehavior({
    required HabitList habitList,
    required CommandRunner commandRunner,
    required NotificationTray notificationTray,
    required Preferences preferences,
  })  : _habitList = habitList,
        _commandRunner = commandRunner,
        _notificationTray = notificationTray,
        _preferences = preferences;

  final HabitList _habitList;

  final CommandRunner _commandRunner;

  final NotificationTray _notificationTray;

  final Preferences _preferences;

  void onAddRepetition(Habit habit, LocalDate date) {
    _notificationTray.cancel(habit);
    final Entry entry = habit.originalEntries.get(date);
    setValue(habit, date, Entry.yesManual, entry.notes);
  }

  void onRemoveRepetition(Habit habit, LocalDate date) {
    _notificationTray.cancel(habit);
    final Entry entry = habit.originalEntries.get(date);
    setValue(habit, date, Entry.no, entry.notes);
  }

  void onToggleRepetition(Habit habit, LocalDate date) {
    final Entry entry = habit.originalEntries.get(date);
    final int newValue = Entry.nextToggleValue(
      entry.value,
      isSkipEnabled: _preferences.isSkipEnabled,
      areQuestionMarksEnabled: _preferences.areQuestionMarksEnabled,
    );
    setValue(habit, date, newValue, entry.notes);
    _notificationTray.cancel(habit);
  }

  void onIncrement(Habit habit, LocalDate date, int amount) {
    final Entry entry = habit.computedEntries.get(date);
    setValue(habit, date, entry.value + amount, entry.notes);
    _notificationTray.cancel(habit);
  }

  void onDecrement(Habit habit, LocalDate date, int amount) {
    final Entry entry = habit.computedEntries.get(date);
    setValue(habit, date, entry.value - amount, entry.notes);
    _notificationTray.cancel(habit);
  }

  void setValue(Habit habit, LocalDate date, int newValue, String notes) {
    _commandRunner.run(
      CreateRepetitionCommand(_habitList, habit, date, newValue, notes),
    );
  }
}
