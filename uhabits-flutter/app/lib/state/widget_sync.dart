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
import 'widget_toggle_queue.dart';

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
/// order, so each firing arms the next one.
///
/// ## Two clocks, not one (`audit5.home-screen-widgets-never-roll-over`)
///
/// That alarm is deliberately *not* the app's screen clock, and the difference
/// is the whole feature. [MidnightTimer] belongs to the activity —
/// `ListHabitsActivity.onResume` starts it, `onPause` calls `shutdownNow()` on
/// it — and it refreshes what is on screen. The `AlarmManager` alarm belongs to
/// the OS: pausing the activity does nothing to it, and at the logical midnight
/// it redraws every home-screen widget whether the app is in front, behind, or
/// not running at all.
///
/// This class once had only the first of the two: it registered
/// [midnightListener] and computed the timestamp without ever arming anything.
/// So the moment the user pressed Home the widgets stopped rolling over and
/// went on drawing yesterday until the app was opened again — which is the one
/// situation a home-screen widget exists for. [WidgetUpdateAlarm] is the
/// missing half, and it is a seam for the same reason `IntentScheduler` is one
/// upstream: what it stands for is a platform service, not a Dart object.
///
/// Both clocks are kept, exactly as upstream keeps both. A foreground rollover
/// therefore runs [_onMidnight] and [_onAlarm] within milliseconds of each
/// other, and both are idempotent: `setToday` is a store, and a second publish
/// rewrites the same documents with the same bytes.
///
/// One half of the rule stays out of reach. A Dart timer cannot outlive its
/// isolate, so "starting the app process if it is dead" has no Flutter
/// equivalent — no plugin in this project can wake a killed process to run
/// Dart. What the alarm buys is every case short of that: backgrounded,
/// screen off, activity destroyed while the engine lives.
///
/// The timestamp is exposed as [nextStartOfDayUpdate] because it is the
/// observable part of the alarm, and it is what `widgets.day-rollover#9` pins
/// down (next local 00:00, or 03:00 with the midnight delay enabled).
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
    WidgetToggleQueue? pendingToggles,
    WidgetUpdateAlarm? alarm,
  })  : _bridge = bridge,
        _commandRunner = commandRunner,
        _taskRunner = taskRunner,
        _midnightTimer = midnightTimer,
        _preferences = preferences,
        _pendingToggles = pendingToggles,
        _alarm = alarm ?? TimerWidgetUpdateAlarm() {
    midnightListener = MidnightListener.of(_onMidnight);
  }

  final HomeWidgetBridge _bridge;

  /// The taps an iOS widget performed in place while the app was closed,
  /// applied on the way to a publish.
  ///
  /// Here rather than anywhere else because this is the one thing that runs at
  /// every moment the queue could need draining: startup, every command, every
  /// resume (`ListHabitsActivity.onResume`'s task block) and the day rollover.
  /// Null for a host that never staged anything — every widget test.
  final WidgetToggleQueue? _pendingToggles;

  /// The publisher this updater drives. Exposed because the widget picker
  /// writes through its [WidgetRegistry] — `HabitPickerDialog.confirm()` calls
  /// `widgetPreferences.addWidget` and then `widgetUpdater.updateWidgets()`,
  /// and both halves live behind this one object.
  HomeWidgetBridge get bridge => _bridge;

  final CommandRunner _commandRunner;

  final TaskRunner _taskRunner;

  final MidnightTimer _midnightTimer;

  final Preferences _preferences;

  /// The port's `IntentScheduler`, i.e. `AlarmManager` plus the one
  /// `PendingIntent` this app ever files with it.
  final WidgetUpdateAlarm _alarm;

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

  /// Unregisters from the [CommandRunner] and disarms both rollover clocks.
  ///
  /// `HabitsApplication.onTerminate` only calls `stopListening()`, and the
  /// pending `AlarmManager` alarm outlives the process by design; here there is
  /// no process boundary — both clocks are objects in this isolate — so
  /// dropping them is what "stop" has to mean. It is also the only thing that
  /// disarms [_alarm]: `_ThemedApp._onPause` must not, or the port is back to
  /// widgets that freeze the moment the user presses Home
  /// (`audit5.home-screen-widgets-never-roll-over#1`).
  void stopListening() {
    _commandRunner.removeListener(this);
    _midnightTimer.removeListener(midnightListener);
    _alarm.cancel();
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
    final _PublishTask task =
        _PublishTask(_bridge, modifiedHabitId, _pendingToggles);
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
  /// only one rollover can ever be pending. That holds for both clocks — the
  /// listener is added once, and [WidgetUpdateAlarm.schedule] replaces whatever
  /// it had pending.
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
    // The `intentScheduler.scheduleWidgetUpdate(timestamp)` half. The delay is
    // taken from the same arithmetic `MidnightTimer.onResume` uses rather than
    // from `timestamp - now`, so the two clocks cannot disagree about when the
    // logical day turns.
    _alarm.schedule(
      timestampMillis: timestamp,
      delayMillis: DateUtils.millisecondsUntilTomorrowWithOffset(
        _preferences.midnightDelayHours,
        0,
      ),
      onAlarm: _onAlarm,
    );
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

  /// `WidgetReceiver.onReceive` for `ACTION_UPDATE_WIDGETS_VALUE`, all three
  /// steps, in order.
  ///
  /// Unlike [_onMidnight] this one performs the `setToday` itself: nothing else
  /// has, because the alarm fires in a process where the activity — and
  /// therefore [MidnightTimer] — may well be paused. That is upstream's
  /// arrangement too, and it is why the receiver has the `setToday` line at all
  /// (`audit5.home-screen-widgets-never-roll-over#1`).
  void _onAlarm() {
    setToday(computeToday(_preferences.midnightDelayHours, 0));
    updateWidgets();
    scheduleStartDayWidgetUpdate();
  }
}

// ---------------------------------------------------------------------------
// The rollover alarm
// ---------------------------------------------------------------------------

/// Port of `IntentScheduler.scheduleWidgetUpdate(updateTime)`.
///
/// Upstream this is `AlarmManager.setExactAndAllowWhileIdle(RTC, timestamp,
/// pendingIntent)` on a broadcast `PendingIntent` addressed to the
/// manifest-declared `WidgetReceiver`, with request code 0 and
/// `FLAG_UPDATE_CURRENT` — so arming replaces whatever was pending and at most
/// one rollover exists at a time.
///
/// It is an interface rather than a bare [Timer] for the same reason
/// `IntentScheduler` is a class upstream: what it stands for is a platform
/// service. A host that gains a real OS alarm — an Android `AlarmManager`
/// binding, a `BGTaskScheduler` submission — implements this and nothing else
/// in [WidgetSync] changes, and a test that wants the rollover to happen *now*
/// supplies one that fires on demand.
abstract class WidgetUpdateAlarm {
  /// Arms the rollover, replacing whatever was armed before.
  ///
  /// [timestampMillis] is the instant the alarm stands for —
  /// `getStartOfTomorrowWithOffset(midnightDelayHours, 0)`, an epoch time — and
  /// [delayMillis] is how far away it is. Both are passed because the two are
  /// not interchangeable under a pinned clock, and because an implementation
  /// backed by a real alarm service wants the first while one backed by a timer
  /// wants the second.
  ///
  /// A [delayMillis] in the past is ignored rather than fired: upstream
  /// `IntentScheduler.schedule` logs "Ignoring attempt to schedule intent in
  /// the past" and returns `SchedulerResult.IGNORED`, and firing instead would
  /// re-arm from the same instant forever.
  void schedule({
    required int timestampMillis,
    required int delayMillis,
    required void Function() onAlarm,
  });

  /// Drops the pending alarm, if any. Idempotent.
  void cancel();
}

/// The default [WidgetUpdateAlarm]: one [Timer], armed on the root zone.
///
/// The root zone is the point. This alarm is the port's stand-in for a service
/// outside the app — upstream it survives `onPause`, `onStop` and `onDestroy`,
/// and is cancelled by nothing the app does — so it must not be swept up by
/// whatever zone happens to be current when a rollover is armed. Under
/// `flutter_test` in particular, `Zone.current` is a fake-async zone owned by
/// the widget tester, and a timer created there would be both cancelled with
/// the tree and reported as a leak; upstream's alarm is neither.
///
/// What it cannot do is outlive the isolate. `AlarmManager` starts a dead
/// process to deliver the broadcast; nothing available here can, so a rollover
/// that falls entirely inside a period when the app is not running is still
/// picked up on the next launch, by `WidgetSync.start`.
class TimerWidgetUpdateAlarm implements WidgetUpdateAlarm {
  Timer? _timer;

  @override
  void schedule({
    required int timestampMillis,
    required int delayMillis,
    required void Function() onAlarm,
  }) {
    cancel();
    // `IntentScheduler.schedule`'s first two lines: an alarm whose instant has
    // already passed is refused, not fired. Both forms of "in the past" are
    // checked because the two are computed from different clocks — the
    // timestamp from `System.currentTimeMillis()`, the delay from the local
    // time `MidnightTimer` reads — and either one being negative means there is
    // no next midnight to wait for.
    if (timestampMillis < systemCurrentTimeMillis()) return;
    if (delayMillis < 0) return;
    _timer = Zone.root.createTimer(
      Duration(milliseconds: delayMillis),
      () {
        _timer = null;
        onAlarm();
      },
    );
  }

  @override
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// The `taskRunner.execute { ... }` block of `WidgetUpdater.updateWidgets`.
class _PublishTask extends Task {
  _PublishTask(this._bridge, this._modifiedHabitId, this._pendingToggles);

  final HomeWidgetBridge _bridge;

  final int? _modifiedHabitId;

  final WidgetToggleQueue? _pendingToggles;

  final Completer<void> completed = Completer<void>();

  @override
  Future<void> doInBackground() async {
    try {
      // Before the publish, never after: applying a staged tap runs a command,
      // and the document that goes out has to be the one the command produced.
      // (The command also asks for a publish of its own; that inner pass finds
      // the queue already being drained and does nothing but publish.)
      await _pendingToggles?.drain();
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
