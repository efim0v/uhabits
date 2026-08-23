// The core's platform seams live under `src`, exactly as
// lib/state/app_scope.dart reaches them; the barrel only re-exports the models,
// database, time and drawing layers.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart' show Habit, LocalDate;

import 'flutter_notification_tray.dart';

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentScheduler.kt,
/// the `ReminderScheduler.SystemScheduler` half of the reminder pipeline.
///
/// ## What Android does, and what Flutter can do
///
/// On Android the alarm and the notification are two separate things: an
/// `AlarmManager` alarm fires a `PendingIntent`, `ReminderReceiver` receives it
/// and calls `ReminderController.onShowReminder`, which runs the core's four
/// gates (already checked / no reminder / archived / wrong weekday) and only
/// then posts the notification — and re-arms tomorrow's alarm.
///
/// `flutter_local_notifications` has no such hook: `zonedSchedule` hands a
/// finished notification to the OS and no Dart code runs when it fires. Three
/// consequences, all of them deliberate and all of them visible here:
///
///  1. **The notification is built at schedule time.** [scheduleShowReminder]
///     builds it with the same [ReminderNotificationBuilder] the tray uses and
///     files it under the same [reminderNotificationId], so the core cancelling
///     a notification also cancels the alarm that would have posted it. That is
///     what reproduces `notifications.show-gating#3`: checking a habit off runs
///     `CreateRepetitionCommand`, the core tray cancels, and the pending alarm
///     disappears with it.
///  2. **The weekday gate has to run here.** `notifications.show-gating#6`
///     lives at fire time upstream. With no fire-time hook, an alarm set for a
///     day the reminder does not cover would show a notification the Android
///     build suppresses, so [scheduleShowReminder] advances to the next day the
///     weekday set does cover — see [_advanceToReminderDay].
///  3. **Nothing re-arms itself.** `reminders.on-show-reminder#2` — every
///     firing schedules the next one — has no counterpart. `scheduleAll()` at
///     app start and after every command is what keeps the chain alive.
class FlutterAlarmScheduler implements SystemScheduler {
  FlutterAlarmScheduler({
    required AlarmPlugin plugin,
    required ReminderNotificationBuilder builder,
    Logging? logging,
    int Function()? nowMillis,
  })  : _plugin = plugin,
        _builder = builder,
        _logging = logging ?? StandardLogging(),
        _now = nowMillis ??
            (() => DateUtils.applyTimezone(DateUtils.getLocalTime()));

  static const String _loggerName = 'IntentScheduler';

  /// The tag `logReminderScheduled` writes under
  /// (`reminders.exact-alarm-scheduling#7`).
  static const String reminderHelperLoggerName = 'ReminderHelper';

  final AlarmPlugin _plugin;

  final ReminderNotificationBuilder _builder;

  final Logging _logging;

  /// `System.currentTimeMillis()`, expressed through the core's injectable
  /// clock so `DateUtils.setFixedLocalTime` reaches it in tests.
  final int Function() _now;

  /// `AlarmManager.canScheduleExactAlarms()`, cached.
  ///
  /// [SystemScheduler.scheduleShowReminder] is synchronous and the plugin's
  /// query is not, so the answer has to be known before the first alarm is set.
  /// Optimistic until [refreshExactAlarmPermission] says otherwise, which is
  /// also what every platform other than Android 12+ reports.
  bool _exactAlarmsAllowed = true;

  bool get exactAlarmsAllowed => _exactAlarmsAllowed;

  /// Every platform call, in order — see [FlutterNotificationTray.settle].
  Future<void> _pending = Future<void>.value();

  /// Awaits every platform call issued so far. For tests and for shutdown.
  Future<void> settle() => _pending;

  void _enqueue(Future<void> Function() operation) {
    _pending = _pending.then((_) => operation()).catchError((Object error) {
      _logging.getLogger(_loggerName).error('Could not schedule alarm: $error');
    });
  }

  /// Re-reads `AlarmManager.canScheduleExactAlarms()`.
  ///
  /// Call it at app start and whenever the app returns to the foreground: the
  /// user can revoke the permission from system settings at any time, and
  /// Android kills the app when they do — but not when they grant it.
  Future<bool> refreshExactAlarmPermission() async {
    _exactAlarmsAllowed = await _plugin.canScheduleExactAlarms();
    return _exactAlarmsAllowed;
  }

  /// Opens the system's "Alarms & reminders" screen on Android 12+. A no-op
  /// everywhere else, where the permission does not exist.
  Future<bool> requestExactAlarmPermission() async {
    final granted = await _plugin.requestExactAlarmsPermission();
    _exactAlarmsAllowed = granted;
    return granted;
  }

  @override
  void log(String componentName, String msg) {
    // reminders.exact-alarm-scheduling#11: log(componentName, msg) forwards to
    // Log.d(componentName, msg).
    _logging.getLogger(componentName).debug(msg);
  }

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) {
    // The log happens before the scheduling attempt, so it is written even when
    // the alarm is refused.
    _logReminderScheduled(habit, reminderTime);

    final notificationId = reminderNotificationId(habit);
    final target = _advanceToReminderDay(habit, reminderTime, timestamp);
    if (target == null) {
      // The reminder covers no weekday at all, so the Android build would fire
      // the alarm and drop it in `NotificationTray`'s fourth gate
      // (`notifications.show-gating#6`). Nothing is posted here either; any
      // alarm left over from a previous weekday set is cleared.
      log(_loggerName,
          'Habit ${habit.id} not supposed to run on any day. Skipping.');
      _enqueue(() => _plugin.cancel(notificationId));
      return SchedulerResult.ignored;
    }

    final spec = _builder.build(
      habit,
      notificationId,
      target.date,
      target.reminderTime,
    );
    return _schedule(target.reminderTime, spec);
  }

  /// `reminders.exact-alarm-scheduling#6`: widget updates use the non-waking
  /// `RTC` alarm type.
  ///
  /// Home-screen widgets are not part of the Flutter app — they are native on
  /// both platforms and have no Dart entry point — so there is nothing to wake
  /// up. Returning null, which the core's signature allows, keeps the call
  /// harmless.
  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) {
    log(_loggerName,
        'Ignoring widget update at $updateTime: no home-screen widgets.');
    return null;
  }

  /// Port of `IntentScheduler.schedule(timestamp, intent, alarmType)`.
  SchedulerResult _schedule(int timestamp, NotificationSpec spec) {
    final now = _now();
    log(_loggerName, 'timestamp=$timestamp now=$now');
    if (timestamp < now) {
      // reminders.exact-alarm-scheduling#2. Strictly less-than: an instant
      // exactly equal to now is accepted.
      log(_loggerName, 'Ignoring attempt to schedule intent in the past.');
      return SchedulerResult.ignored;
    }
    if (!_exactAlarmsAllowed) {
      // reminders.exact-alarm-scheduling#3: no alarm and no inexact fallback.
      log(_loggerName, 'No permission to schedule exact alarms');
      return SchedulerResult.ignored;
    }
    // reminders.exact-alarm-scheduling#4/#5: setExactAndAllowWhileIdle with
    // RTC_WAKEUP.
    _enqueue(() => _plugin.scheduleExact(spec: spec, whenMillis: timestamp));
    return SchedulerResult.ok;
  }

  /// Port of `IntentScheduler.logReminderScheduled`
  /// (`reminders.exact-alarm-scheduling#7` and `#12`).
  void _logReminderScheduled(Habit habit, int reminderTime) {
    final length = habit.name.length < 5 ? habit.name.length : 5;
    final name = habit.name.substring(0, length);
    final time = _formatBackupDate(reminderTime);
    _logging
        .getLogger(reminderHelperLoggerName)
        .info('Setting alarm ($time): $name');
  }

  /// `DateFormats.getBackupDateFormat()`: the pattern "yyyy-MM-dd HHmmss" in
  /// `Locale.US`, rendered in the device's wall-clock time.
  ///
  /// The wall clock is reached through [DateUtils.removeTimezone] rather than
  /// `DateTime.toLocal()`, so the fixed timezone a test installs applies here
  /// too, exactly as it does in every core computation.
  static String _formatBackupDate(int utcMillis) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      DateUtils.removeTimezone(utcMillis),
      isUtc: true,
    );
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-'
        '${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}${two(local.minute)}${two(local.second)}';
  }

  /// Moves the alarm forward to the first day the reminder's weekday set
  /// covers, returning null when it covers none.
  ///
  /// Port of `NotificationTray.ShowNotificationTask.shouldShowReminderToday`
  /// (`notifications.show-gating#6`, `#7` and `#8`) moved from fire time to
  /// schedule time, for the reason given in the class comment. The date tested
  /// is the one the alarm carries — the checkmark day the core computed — not
  /// today.
  ///
  /// One day is one [DateUtils.dayLength] here; across a DST boundary the alarm
  /// therefore lands an hour off the habit's wall-clock reminder, which the
  /// Android build would have corrected on its next `scheduleAll()`. So does
  /// this one.
  _ReminderTarget? _advanceToReminderDay(
    Habit habit,
    int reminderTime,
    int timestamp,
  ) {
    final reminder = habit.reminder;
    if (reminder == null) return null;
    final days = reminder.days.toArray();
    var date = LocalDate.fromUnixTime(timestamp);
    var time = reminderTime;
    for (var i = 0; i < 7; i++) {
      // notifications.show-gating#7: SUNDAY -> 1, MONDAY -> 2, ..., SATURDAY -> 0.
      final weekday = (date.dayOfWeek.daysSinceSunday + 1) % 7;
      if (days[weekday]) return _ReminderTarget(time, date);
      date = LocalDate(date.daysSince2000 + 1);
      time += DateUtils.dayLength;
    }
    return null;
  }
}

class _ReminderTarget {
  const _ReminderTarget(this.reminderTime, this.date);

  final int reminderTime;

  final LocalDate date;
}

// ---------------------------------------------------------------------------
// The platform seam
// ---------------------------------------------------------------------------

/// What [FlutterAlarmScheduler] needs from the platform: set one exact alarm,
/// cancel one, and answer whether exact alarms are allowed at all.
///
/// A plugin cannot run in a widget test, so this is where the port stops and
/// the fake takes over.
abstract interface class AlarmPlugin {
  /// `AlarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, whenMillis, intent)`,
  /// carrying the notification that alarm will post.
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  });

  /// Drops a pending alarm. Cancelling by the notification id is what makes the
  /// core's `NotificationTray.cancel` disarm the alarm as well.
  Future<void> cancel(int id);

  /// `AlarmManager.canScheduleExactAlarms()`. True on every platform that has
  /// no such permission.
  Future<bool> canScheduleExactAlarms();

  /// Sends the user to the system's "Alarms & reminders" screen.
  Future<bool> requestExactAlarmsPermission();
}

/// [AlarmPlugin] over `flutter_local_notifications`.
///
/// Never exercised by a widget test — the plugin's method channel has no
/// implementation there.
class LocalNotificationsAlarmPlugin implements AlarmPlugin {
  LocalNotificationsAlarmPlugin({
    required this.plugin,
    required LocalNotificationsPresenter presenter,
  }) : _presenter = presenter;

  final FlutterLocalNotificationsPlugin plugin;

  final LocalNotificationsPresenter _presenter;

  static bool _timeZonesInitialized = false;

  /// Loads the IANA database `zonedSchedule` needs.
  ///
  /// Every instant this class is handed is an absolute UTC epoch value computed
  /// by `ReminderScheduler`, so the alarm is expressed in [tz.UTC]: the plugin
  /// serialises the zoned date-time together with its zone name and the
  /// platform reconstructs the same instant from it. Nothing here needs the
  /// device's own IANA zone — which is exactly as well, since reading it needs
  /// a plugin this app does not depend on — and a DST transition between now
  /// and the alarm cannot move an absolute instant.
  static Future<void> ensureTimeZones() async {
    if (_timeZonesInitialized) return;
    tz_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async {
    await ensureTimeZones();
    final when = tz.TZDateTime.from(
      DateTime.fromMillisecondsSinceEpoch(whenMillis, isUtc: true),
      tz.UTC,
    );
    await plugin.zonedSchedule(
      spec.id,
      spec.title,
      spec.body,
      when,
      _presenter.detailsFor(spec),
      // reminders.exact-alarm-scheduling#4: setExactAndAllowWhileIdle.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: spec.payload,
    );
  }

  @override
  Future<void> cancel(int id) => plugin.cancel(id);

  @override
  Future<bool> canScheduleExactAlarms() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<bool> requestExactAlarmsPermission() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestExactAlarmsPermission() ?? false;
  }
}
