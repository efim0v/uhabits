import '../commands/change_habit_color_command.dart';
import '../commands/command.dart';
import '../commands/command_runner.dart';
import '../commands/create_repetition_command.dart';
import '../models/habit.dart';
import '../models/habit_list.dart';
import '../models/habit_matcher.dart';
import '../preferences/widget_preferences.dart';
import 'date_utils.dart';

/// Port of
/// uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt
///
/// Decides *when* a reminder should fire and hands that instant to the
/// platform through [SystemScheduler]; it never posts a notification itself and
/// keeps no state of its own — the only thing it remembers is the snooze time,
/// and that lives in [WidgetPreferences].
///
/// Two timestamps travel together on every scheduled reminder:
///
///   * `reminderTime`, a UTC instant, is when the alarm goes off;
///   * `timestamp`, the local midnight of the day the reminder belongs to, is
///     the day a checkmark would be written to if the user acts on the
///     notification.
///
/// Every method is `@Synchronized` upstream. A Dart isolate has a single
/// thread and none of these methods suspends, so each one already runs to
/// completion before another can start; there is no lock to port.
class ReminderScheduler implements CommandRunnerListener {
  ReminderScheduler(
    this._commandRunner,
    this._habitList,
    this._sys,
    this._widgetPreferences,
  );

  final CommandRunner _commandRunner;

  final HabitList _habitList;

  final SystemScheduler _sys;

  final WidgetPreferences _widgetPreferences;

  /// Re-arms every alarm after any command that could have changed one.
  ///
  /// Checking off a habit and recolouring it are the two exceptions: neither
  /// can move a reminder, and both happen often enough that rescheduling every
  /// alarm on each one would be pure waste.
  @override
  void onCommandFinished(Command command) {
    if (command is CreateRepetitionCommand) return;
    if (command is ChangeHabitColorCommand) return;
    scheduleAll();
  }

  /// Schedules [habit]'s next reminder, honouring a live snooze.
  void schedule(Habit habit) {
    final id = habit.id;
    if (id == null) {
      _sys.log('ReminderScheduler', 'Habit has null id. Returning.');
      return;
    }
    if (!habit.hasReminder()) {
      _sys.log('ReminderScheduler', 'habit=$id has no reminder. Skipping.');
      return;
    }
    var reminderTime = DateUtils.getUpcomingTimeInMillis(
      habit.reminder!.hour,
      habit.reminder!.minute,
    );
    final snoozeReminderTime = _widgetPreferences.getSnoozeTime(id);
    if (snoozeReminderTime != 0) {
      final now = DateUtils.applyTimezone(DateUtils.getLocalTime());
      _sys.log('ReminderScheduler',
          'Habit $id has been snoozed until $snoozeReminderTime');
      if (snoozeReminderTime > now) {
        _sys.log('ReminderScheduler', 'Snooze time is in the future. Accepting.');
        reminderTime = snoozeReminderTime;
      } else {
        _sys.log('ReminderScheduler', 'Snooze time is in the past. Discarding.');
        _widgetPreferences.removeSnoozeTime(id);
      }
    }
    scheduleAtTime(habit, reminderTime);
  }

  /// Schedules [habit] at an arbitrary instant — used both by [schedule] and by
  /// the "snooze until a custom time" flow, which does not persist anything.
  ///
  /// The checkmark day is derived with hard-coded zero offsets, so the user's
  /// midnight-delay preference is deliberately not applied here.
  void scheduleAtTime(Habit habit, int reminderTime) {
    _sys.log('ReminderScheduler', 'Scheduling alarm for habit=${habit.id}');
    if (!habit.hasReminder()) {
      _sys.log(
          'ReminderScheduler', 'habit=${habit.id} has no reminder. Skipping.');
      return;
    }
    if (habit.isArchived) {
      _sys.log('ReminderScheduler', 'habit=${habit.id} is archived. Skipping.');
      return;
    }
    final timestamp = DateUtils.getStartOfDayWithOffset(
      DateUtils.removeTimezone(reminderTime),
      0,
      0,
    );
    _sys.log(
      'ReminderScheduler',
      'reminderTime=$reminderTime '
          'removeTimezone=${DateUtils.removeTimezone(reminderTime)} '
          'timestamp=$timestamp',
    );
    _sys.scheduleShowReminder(reminderTime, habit, timestamp);
  }

  /// Re-arms every habit that carries a reminder, archived ones included — they
  /// are dropped one level down, inside [scheduleAtTime]. Nothing is cancelled
  /// first; an alarm is simply replaced by the next one for the same habit.
  void scheduleAll() {
    _sys.log('ReminderScheduler', 'Scheduling all alarms');
    final reminderHabits = _habitList.getFiltered(HabitMatcher.withAlarm);
    for (final habit in reminderHabits) {
      schedule(habit);
    }
  }

  bool hasHabitsWithReminders() =>
      !_habitList.getFiltered(HabitMatcher.withAlarm).isEmpty;

  void startListening() {
    _commandRunner.addListener(this);
  }

  void stopListening() {
    _commandRunner.removeListener(this);
  }

  /// Snoozes [habit] by [minutes], persisting the new instant so that any
  /// later [scheduleAll] — after a reboot, an edit, or an app restart —
  /// re-honours it until it expires.
  void snoozeReminder(Habit habit, int minutes) {
    final now = DateUtils.applyTimezone(DateUtils.getLocalTime());
    final snoozedUntil = now + minutes * 60 * 1000;
    _widgetPreferences.setSnoozeTime(habit.id!, snoozedUntil);
    schedule(habit);
  }
}

/// Port of `ReminderScheduler.SystemScheduler`. Dart has no nested classes, so
/// the Kotlin inner interface becomes a top-level one, as
/// `CommandRunner.Listener` did.
///
/// This is the whole platform surface the scheduler needs: on Android it is
/// backed by `AlarmManager` and `PendingIntent`, and a Flutter app implements
/// it with whatever local-notification plugin it uses. Keeping it an interface
/// is what allows the time arithmetic above to live in pure Dart.
abstract interface class SystemScheduler {
  /// Asks the platform to fire a reminder for [habit] at [reminderTime] (a UTC
  /// instant), for the checkmark day [timestamp].
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  );

  SchedulerResult? scheduleWidgetUpdate(int updateTime);

  void log(String componentName, String msg);
}

/// Port of `ReminderScheduler.SchedulerResult`. Android returns [ignored] when
/// it refuses to set an exact alarm.
enum SchedulerResult { ignored, ok }
