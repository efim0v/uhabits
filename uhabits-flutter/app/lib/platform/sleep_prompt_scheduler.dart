import 'package:uhabits_core/uhabits_core.dart';

import 'flutter_alarm_scheduler.dart' show AlarmPlugin;
import 'flutter_notification_tray.dart'
    show NotificationSpec, ReminderNotificationBuilder, reminderNotificationId;

/// The notification id a sleep habit's morning question is filed under.
///
/// A namespace of its own, set apart from [reminderNotificationId] by the top
/// bit. Filing the question under the habit's ordinary reminder id looked
/// harmless and was not: the next `scheduleAll` would overwrite it, and a habit
/// with no reminder of its own would have the question withdrawn rather than
/// posted.
int sleepPromptNotificationId(Habit habit) {
  final int? id = habit.id;
  if (id == null) return 0;
  return 0x40000000 | (id & 0x3FFFFFFF);
}

/// Arms the question a sleep habit asks in the morning.
///
/// Deliberately not `SystemScheduler.scheduleShowReminder`. That is the habit
/// reminder machinery: it reads `habit.reminder` to work out which weekdays the
/// alarm covers, and answers a habit that has none by cancelling rather than
/// scheduling. A sleep habit has no reminder of its own — its moment comes from
/// the goal, and moves as the goal adapts to a new timezone.
///
/// The notification itself is built by the same builder every reminder uses, so
/// its copy, its actions and its payload cannot drift from the rest of the app.
/// Only the id differs, and the day is given rather than derived.
class SleepPromptScheduler {
  const SleepPromptScheduler({
    required AlarmPlugin alarms,
    required ReminderNotificationBuilder builder,
  })  : _alarms = alarms,
        _builder = builder;

  final AlarmPlugin _alarms;
  final ReminderNotificationBuilder _builder;

  /// Posts the question for [habit] at [atMillis], a UTC instant, about [day].
  ///
  /// [day] is passed rather than derived from the instant: the reminder
  /// machinery reads a local wall-clock day out of that slot, and east of UTC+8
  /// a UTC instant lands on the day before — so the night the person then
  /// entered would be filed against yesterday.
  ///
  /// Replaces whatever was armed for the habit: the moment moves whenever the
  /// goal drifts, so there is never more than one outstanding question.
  Future<void> schedule(Habit habit, LocalDate day, int atMillis) async {
    await _alarms.scheduleExact(
      spec: specFor(habit, day, atMillis),
      whenMillis: atMillis,
    );
  }

  Future<void> cancel(Habit habit) =>
      _alarms.cancel(sleepPromptNotificationId(habit));

  /// What would be posted. Exposed so a test can read it without a platform.
  NotificationSpec specFor(Habit habit, LocalDate day, int atMillis) =>
      _builder.build(
        habit,
        sleepPromptNotificationId(habit),
        day,
        atMillis,
      );
}
