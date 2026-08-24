/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/NotificationTray.kt
///
/// Plus the two `ReminderController` entry points that drive it —
/// `onShowReminder` and `onDismiss` — from
/// uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt.
///
/// What lives here is the platform-independent half: the decision of *whether*
/// a reminder notification is shown, the id it is shown under, and the registry
/// of what is currently on screen. The other half — building the Android
/// `Notification`, its channel, its icon, its content and delete intents — is
/// what [SystemTray] abstracts away, and belongs to the app package.
library;

import '../commands/command.dart';
import '../commands/command_runner.dart';
import '../commands/create_repetition_command.dart';
import '../commands/delete_habits_command.dart';
import '../models/habit.dart';
import '../models/habit_type.dart';
import '../preferences/preferences.dart';
import '../tasks/task_runner.dart';
import '../time/date_utils.dart';
import '../time/local_date.dart';

/// Port of the nested Kotlin interface `NotificationTray.SystemTray`.
///
/// Dart has no nested classes, so it lives here as a top-level interface. The
/// Android implementation is `AndroidNotificationTray`, which owns the
/// notification builder, the "REMINDERS" channel and its own `HashSet<Int>` of
/// posted ids; the Flutter app package will supply the equivalent.
abstract interface class SystemTray {
  void removeNotification(int notificationId);

  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  );

  void log(String msg);
}

/// Port of the Kotlin `internal class NotificationTray.NotificationData`.
///
/// The two values `show()` is given and every later reshow replays: the day the
/// alarm targeted, and the instant it was scheduled for. `reminderTime` is a
/// `Long` of UTC epoch millis in Kotlin.
class NotificationData {
  const NotificationData(this.date, this.reminderTime);

  final LocalDate date;

  final int reminderTime;
}

/// One entry of the `active` registry: the habit whose notification is on
/// screen, and the data it was posted with.
class _ActiveNotification {
  _ActiveNotification(this.habit, this.data);

  final Habit habit;

  final NotificationData data;
}

/// Port of `NotificationTray`.
///
/// Kotlin declares it `@AppScope @Inject open class ... : CommandRunner.Listener,
/// Preferences.Listener`. `Preferences.Listener` is ported as a concrete class
/// with empty defaults, so this class extends it and implements the
/// command-runner interface.
class NotificationTray extends PreferencesListener
    implements CommandRunnerListener {
  NotificationTray(
    this._taskRunner,
    this._commandRunner,
    this._preferences,
    this._systemTray,
  );

  final TaskRunner _taskRunner;

  final CommandRunner _commandRunner;

  final Preferences _preferences;

  final SystemTray _systemTray;

  /// Port of `companion object { const val REMINDERS_CHANNEL_ID = "REMINDERS" }`.
  static const String remindersChannelId = 'REMINDERS';

  /// `Int.MAX_VALUE`, the modulus of [_getNotificationId]. Dart integers are 64
  /// bit, so the constant has to be spelled out.
  static const int _intMaxValue = 2147483647;

  /// Port of `private val active: MutableMap<Habit, NotificationData>`.
  ///
  /// Kotlin keys this map by the `Habit` data class itself, so every lookup
  /// compares all fourteen model fields — and a habit mutated after `show()`
  /// (renamed, archived, recoloured) hashes differently and can no longer be
  /// found. The ledger tells the port to key by habit id instead, which is also
  /// the granularity the system tray works at: `getNotificationId` is derived
  /// from the id alone, so two habits sharing an id already share a
  /// notification. A null id is a key like any other, matching the way every
  /// null-id habit shares notification id 0.
  final Map<int?, _ActiveNotification> _active = <int?, _ActiveNotification>{};

  /// Removes the habit's notification from the system tray and from the
  /// registry. Idempotent: cancelling twice removes the notification twice and
  /// the second `remove` is a no-op.
  void cancel(Habit habit) {
    final notificationId = _getNotificationId(habit);
    _systemTray.removeNotification(notificationId);
    _active.remove(_keyOf(habit));
  }

  /// Two independent `if`s, not an `else if` chain — a command could in
  /// principle be both, and the Kotlin does not exclude it.
  ///
  /// Every other command type is ignored: archiving a habit does NOT dismiss
  /// an already-showing notification.
  @override
  void onCommandFinished(Command command) {
    if (command is CreateRepetitionCommand) {
      cancel(command.habit);
    }
    if (command is DeleteHabitsCommand) {
      for (final habit in command.selected) {
        cancel(habit);
      }
    }
  }

  /// `Preferences.Listener.onNotificationsChanged`: the sticky setting changed,
  /// so everything on screen has to be rebuilt with the new ongoing flag.
  @override
  void onNotificationsChanged() {
    reshowAll();
  }

  /// Records the notification as active and hands the work to the task runner.
  /// Nothing is decided here — every gate lives in the task.
  void show(Habit habit, LocalDate date, int reminderTime) {
    final data = NotificationData(date, reminderTime);
    _active[_keyOf(habit)] = _ActiveNotification(habit, data);
    _taskRunner.execute(_ShowNotificationTask(this, habit, data));
  }

  /// Records a notification the platform posted by itself, writing the
  /// registry and posting nothing.
  ///
  /// Port-only, and the missing fire-time hook is its whole justification.
  /// Upstream an alarm is only a trigger: it fires a `PendingIntent`,
  /// `ReminderReceiver` runs in the app process and calls
  /// `ReminderController.onShowReminder`, and [show] writes `active[habit]`
  /// before it posts anything — so on Android the registry is populated for
  /// every reminder the user ever sees, at the instant it appears.
  ///
  /// A Flutter port has no such hook. `zonedSchedule` hands the OS a finished
  /// notification and the OS posts it with no Dart running, so [show] is never
  /// reached and the registry stays empty for exactly the notifications it is
  /// supposed to hold. The app package catches up at the next foreground and
  /// calls this; going through [show] instead would re-post a notification
  /// that is already on screen, which on Android re-alerts.
  ///
  /// [date] and [reminderTime] are the two values the show-reminder intent
  /// carries upstream, and every later [reshow] replays them.
  void adopt(Habit habit, LocalDate date, int reminderTime) {
    _active[_keyOf(habit)] =
        _ActiveNotification(habit, NotificationData(date, reminderTime));
  }

  void startListening() {
    _commandRunner.addListener(this);
    _preferences.addListener(this);
  }

  void stopListening() {
    _commandRunner.removeListener(this);
    _preferences.removeListener(this);
  }

  /// Port of `private fun getNotificationId(habit: Habit): Int`.
  ///
  /// `(habit.id % Int.MAX_VALUE).toInt()`, or 0 when the id is null. Kotlin's
  /// `%` on a `Long` is a truncated remainder, so a negative id yields a
  /// negative notification id; [int.remainder] reproduces that, while Dart's
  /// `%` would not. The `.toInt()` narrowing is a no-op after the remainder,
  /// whose magnitude is already below `Int.MAX_VALUE`.
  int _getNotificationId(Habit habit) {
    final id = habit.id;
    if (id == null) return 0;
    return id.remainder(_intMaxValue);
  }

  /// The registry key. See [_active].
  int? _keyOf(Habit habit) => habit.id;

  /// Re-runs the task for every active notification, with each one's own
  /// stored data.
  void reshowAll() {
    for (final entry in _active.values.toList()) {
      _taskRunner.execute(
        _ShowNotificationTask(this, entry.habit, entry.data),
      );
    }
  }

  /// Re-runs the task for one habit, if it is currently active; a habit that
  /// was never shown, or was cancelled, is silently ignored.
  ///
  /// The task is built with the habit that was *passed in*, exactly as Kotlin's
  /// `active[habit]?.let { ShowNotificationTask(habit, it) }` does, so the gates
  /// see the caller's instance and its current state.
  void reshow(Habit habit) {
    final entry = _active[_keyOf(habit)];
    if (entry != null) {
      _taskRunner.execute(_ShowNotificationTask(this, habit, entry.data));
    }
  }
}

/// Port of the Kotlin `private inner class ShowNotificationTask`.
///
/// The split between the two halves is the whole point: `doInBackground` runs
/// on the io dispatcher and does nothing but read `habit.isCompletedToday()`,
/// which walks the entry list; every gate, every log line and the call into the
/// system tray then run on the main dispatcher in `onPostExecute`, against the
/// value captured in the background.
class _ShowNotificationTask extends Task {
  _ShowNotificationTask(this._tray, this._habit, NotificationData data)
      : _date = data.date,
        _reminderTime = data.reminderTime;

  final NotificationTray _tray;

  final Habit _habit;

  final LocalDate _date;

  final int _reminderTime;

  bool isCompleted = false;

  @override
  void doInBackground() {
    isCompleted = _habit.isCompletedToday();
  }

  @override
  void onPostExecute() {
    final systemTray = _tray._systemTray;
    systemTray.log('Showing notification for habit=${_habit.id}');
    if (isCompleted && _habit.targetType != NumericalHabitType.atMost) {
      systemTray.log('Habit ${_habit.id} already checked. Skipping.');
      return;
    }
    if (!_habit.hasReminder()) {
      systemTray.log('Habit ${_habit.id} does not have a reminder. Skipping.');
      return;
    }
    if (_habit.isArchived) {
      systemTray.log('Habit ${_habit.id} is archived. Skipping.');
      return;
    }
    if (!_shouldShowReminderToday()) {
      systemTray.log('Habit ${_habit.id} not supposed to run today. Skipping.');
      return;
    }
    systemTray.showNotification(
      _habit,
      _tray._getNotificationId(_habit),
      _date,
      _reminderTime,
    );
  }

  /// The 0 = Saturday convention, spelled out: the index into the reminder's
  /// weekday array is `(dayOfWeek.daysSinceSunday + 1) % 7`, so SUNDAY -> 1,
  /// MONDAY -> 2, ..., FRIDAY -> 6 and SATURDAY -> 0.
  ///
  /// The date tested is the one carried by the notification — the day the alarm
  /// targeted — and not today.
  bool _shouldShowReminderToday() {
    if (!_habit.hasReminder()) return false;
    final reminder = _habit.reminder!;
    final reminderDays = reminder.days.toArray();
    final weekday = (_date.dayOfWeek.daysSinceSunday + 1) % 7;
    return reminderDays[weekday];
  }
}

/// The one `ReminderScheduler` method [ReminderController] calls.
///
/// The full `ReminderScheduler` port (the `reminders.schedule-*` rules, with
/// `scheduleAll`, `schedule`, `scheduleAtTime` and the snooze bookkeeping) is a
/// separate file owned by a separate slice; declaring the narrow interface here
/// keeps this file self-contained, and the real scheduler satisfies it as soon
/// as it lands.
abstract interface class ReminderSchedulerApi {
  /// Reschedules every habit that has a reminder. This is what re-arms the
  /// next alarm — the app never registers repeating alarms — and, because it
  /// re-reads the snooze preference for each habit, it is also where a snooze
  /// that has just expired gets discarded.
  void scheduleAll();

  /// Persists a snooze of [minutes] for [habit] and re-arms its alarm at the
  /// snoozed instant. Because the instant is written to `WidgetPreferences`,
  /// every later [scheduleAll] re-honours it until it expires.
  void snoozeReminder(Habit habit, int minutes);

  /// Arms [habit]'s alarm at an arbitrary instant, writing nothing. Upstream
  /// this is the "snooze until a custom time" path, and the reason a
  /// custom-time snooze is overwritten by the next [scheduleAll].
  void scheduleAtTime(Habit habit, int reminderTime);

  /// Persists a snooze of [habit] until [reminderTime] and re-arms its alarm
  /// there, exactly as [snoozeReminder] does for a delay.
  ///
  /// A deliberate deviation with no upstream counterpart; see
  /// [ReminderController.onSnoozeTimePicked] for why the port needs one.
  void snoozeUntil(Habit habit, int reminderTime);
}

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/receivers/ReminderController.kt.
///
/// Every entry point `ReminderReceiver` and `SnoozeDelayPickerActivity` reach
/// is here except `onSnoozePressed`, whose whole body is the Android intent
/// that starts the translucent picker activity: `context.sendBroadcast(
/// ACTION_CLOSE_SYSTEM_DIALOGS)` followed by `startActivity(...)` with
/// `habit.uriString` as data. That is platform glue with no core meaning, so
/// the app package owns it and hands the answer back through
/// [onSnoozeDelayPicked] / [onSnoozeTimePicked].
class ReminderController {
  ReminderController(
    this._reminderScheduler,
    this._notificationTray,
    this._preferences,
  );

  final ReminderSchedulerApi _reminderScheduler;

  final NotificationTray _notificationTray;

  final Preferences _preferences;

  /// The whole body of `onBootCompleted()`: re-arm everything.
  ///
  /// Nothing else is needed, because snooze times live in preferences and
  /// therefore survive the reboot; `scheduleAll` re-reads each one and keeps
  /// it while it is still in the future.
  void onBootCompleted() {
    _reminderScheduler.scheduleAll();
  }

  /// Show first, re-arm second. The second call is what schedules tomorrow's
  /// alarm.
  void onShowReminder(Habit habit, LocalDate date, int reminderTime) {
    _notificationTray.show(habit, date, reminderTime);
    _reminderScheduler.scheduleAll();
  }

  /// The user picked one of the fixed snooze delays.
  ///
  /// Snooze first, cancel second — the order matters, because
  /// `snoozeReminder` re-schedules the habit and the cancel that follows must
  /// not take the freshly armed alarm down with the notification.
  void onSnoozeDelayPicked(Habit habit, int delayInMinutes) {
    _reminderScheduler.snoozeReminder(habit, delayInMinutes);
    _notificationTray.cancel(habit);
  }

  /// The user picked a custom wall-clock time.
  ///
  /// Kotlin's body is `reminderScheduler.scheduleAtTime(habit!!, time)`
  /// followed by `notificationTray.cancel(habit)`, and nothing is persisted:
  /// on Android the cancel is `NotificationManagerCompat.cancel(id)` and the
  /// alarm is a separate object under an `AlarmManager` `PendingIntent`, so the
  /// one-off alarm outlives the cancel and only a *later* `scheduleAll()`
  /// replaces it (`reminders.snooze-custom-time#2`).
  ///
  /// **Deliberate deviation:** [ReminderSchedulerApi.snoozeUntil] instead of
  /// [ReminderSchedulerApi.scheduleAtTime], so that the picked instant is
  /// recorded. This port files the alarm and the notification under one id and
  /// re-arms every habit whenever a notification is cancelled
  /// (`audit3.recording-a-non-completing-entry-silently#1`), so the cancel
  /// below destroys the alarm the line above just armed and the re-arm behind
  /// it re-files the habit's *ordinary* reminder — a custom-time snooze never
  /// fires at all. Recording it is what survives both.
  /// See `audit11.custom-time-snooze-is-erased-by-the-cancel-rearm#1`.
  ///
  /// Kotlin's parameter is `Habit?` and its body dereferences it with `!!`, so
  /// a null habit throws rather than being ignored; Dart's non-nullable
  /// parameter is the same contract stated in the type.
  void onSnoozeTimePicked(Habit habit, int hour, int minute) {
    final time = DateUtils.getUpcomingTimeInMillis(hour, minute);
    _reminderScheduler.snoozeUntil(habit, time);
    _notificationTray.cancel(habit);
  }

  /// Reached through the notification's delete intent.
  ///
  /// When notifications are sticky the dismissal is undone immediately: on
  /// Android 14+ even an ongoing notification can be swiped away, so the app
  /// re-posts it.
  void onDismiss(Habit habit) {
    if (_preferences.shouldMakeNotificationsSticky()) {
      _notificationTray.reshow(habit);
    } else {
      _notificationTray.cancel(habit);
    }
  }
}
