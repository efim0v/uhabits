// The core's platform seams live under `src`, exactly as
// lib/state/app_scope.dart reaches them; the barrel only re-exports the models,
// database, time and drawing layers.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart'
    show Entry, Habit, LocalDate, NumericalHabitType;

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
///  2. **The gates have to run here.** `notifications.show-gating#6` and gate 1
///     (`if (isCompleted && targetType != AT_MOST) return`) both live at fire
///     time upstream. With no fire-time hook, an alarm set for a day the
///     reminder does not cover — or for a day the habit is already done for —
///     would show a notification the Android build suppresses, so
///     [scheduleShowReminder] advances to the next day that survives both
///     gates. See [_advanceToReminderDay].
///  3. **Nothing re-arms itself.** `reminders.on-show-reminder#2` — every
///     firing schedules the next one — has no counterpart. `scheduleAll()` at
///     app start and after every command is what keeps the chain alive.
///  4. **Nothing withdraws an obsolete alarm.** Gates 2 and 3 (`if (!habit
///     .hasReminder()) return` and `if (habit.isArchived) return`) also live
///     at fire time upstream, and the core scheduler reproduces them by
///     *skipping* the habit. Skipping is enough upstream: the stale
///     `AlarmManager` alarm the habit still owns fires into a task that
///     re-reads it and posts nothing. Here the alarm IS the notification, so
///     skipping leaves a phantom reminder armed and the skip has to become a
///     cancel — [withdrawObsoleteAlarms], which [FlutterReminderScheduler]
///     runs after every `scheduleAll()`.
class FlutterAlarmScheduler implements SystemScheduler {
  FlutterAlarmScheduler({
    required AlarmPlugin plugin,
    required ReminderNotificationBuilder builder,
    PendingAlarmQuery? pendingAlarms,
    Logging? logging,
    int Function()? nowMillis,
  })  : _plugin = plugin,
        _builder = builder,
        // The real plugin answers both, so the common case needs no argument.
        _pendingAlarms = pendingAlarms ??
            (plugin is PendingAlarmQuery ? plugin as PendingAlarmQuery : null),
        _logging = logging ?? StandardLogging(),
        _now = nowMillis ??
            (() => DateUtils.applyTimezone(DateUtils.getLocalTime()));

  static const String _loggerName = 'IntentScheduler';

  /// The tag `logReminderScheduled` writes under
  /// (`reminders.exact-alarm-scheduling#7`).
  static const String reminderHelperLoggerName = 'ReminderHelper';

  /// How far [_advanceToReminderDay] looks for a day that survives both gates,
  /// for a habit whose frequency covers [denominator] days.
  ///
  /// Seven days would cover the weekday gate on its own — a reminder set for a
  /// single weekday. Gate 1 can reject a run before that gate gets a second
  /// look, and that run is the newest frequency interval:
  /// `EntryList.buildIntervals` fills `size` days with YES_AUTO, where `size`
  /// is the denominator (the calendar month's length substitutes only for the
  /// 30 and 31 denominators). So the scan is that run, then at most six more
  /// days to the next weekday the reminder covers.
  ///
  /// It is derived from the habit rather than fixed, because the denominator
  /// is not bounded by anything the app enforces: the picker's field takes
  /// three digits and an imported database can carry more. A fixed bound that
  /// the denominator outgrows does not defer the reminder — it cancels it, and
  /// the user is never told (`audit19.a-long-frequency-must-not-cancel-the-
  /// reminder#1`).
  static int _daysToScan(int denominator) => denominator + 7;

  final AlarmPlugin _plugin;

  final ReminderNotificationBuilder _builder;

  /// The alarms the platform still holds, or null on a host that cannot say.
  /// See [withdrawObsoleteAlarms].
  final PendingAlarmQuery? _pendingAlarms;

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

  /// Cancels every alarm the platform still holds whose notification id is not
  /// in [stillWanted].
  ///
  /// Gates 2 and 3 of `NotificationTray.ShowNotificationTask.onPostExecute`,
  /// moved from fire time to schedule time for the reason given in the class
  /// comment:
  ///
  /// ```kotlin
  /// if (!habit.hasReminder()) { log("does not have a reminder. Skipping."); return }
  /// if (habit.isArchived)     { log("is archived. Skipping."); return }
  /// ```
  ///
  /// Upstream both gates run against a *re-read* habit when the alarm fires,
  /// so an alarm armed at 22:00 for a reminder the user switches off at 22:05
  /// still goes off at 08:00 and is dropped in silence. The port's core
  /// scheduler reproduces the gates one level up, by returning early — which
  /// means [scheduleShowReminder] is never reached for those habits, and the
  /// finished notification the OS is already holding is never taken back.
  ///
  /// The pending set is read from the platform rather than remembered, so a
  /// stale alarm armed by a previous run of the process is withdrawn too: an
  /// app that was killed overnight re-arms only future alarms at startup and
  /// would otherwise never see the leftover one. Reading it also bounds the
  /// work to the alarms that really are armed, instead of cancelling an id per
  /// reminderless habit on every command. Every one of them is a reminder —
  /// [scheduleShowReminder] is the only caller of `scheduleExact` in the app.
  void withdrawObsoleteAlarms(Set<int> stillWanted) {
    final PendingAlarmQuery? query = _pendingAlarms;
    if (query == null) return;
    _enqueue(() async {
      final Set<int>? pending;
      try {
        pending = await query.pendingAlarmIds();
      } on Object catch (error) {
        log(_loggerName, 'Could not read the pending alarms: $error');
        return;
      }
      if (pending == null) return;
      for (final int notificationId in pending) {
        if (stillWanted.contains(notificationId)) continue;
        log(_loggerName,
            'Alarm $notificationId has no habit to show. Cancelling.');
        await _plugin.cancel(notificationId);
      }
    });
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

  /// Moves the alarm forward to the first day that survives the two gates a
  /// scheduled notification cannot run for itself, returning null when no day
  /// does.
  ///
  /// Port of `NotificationTray.ShowNotificationTask`'s
  /// `shouldShowReminderToday` (`notifications.show-gating#6`, `#7` and `#8`)
  /// and of its first gate (`#1`, `audit3.a-habit-already-completed-today
  /// -still#1`), both moved from fire time to schedule time for the reason
  /// given in the class comment. The date tested is the one the alarm carries —
  /// the checkmark day the core computed — not today.
  ///
  /// The scan is [_daysToScan] days long, not seven: gate 1 can reject a whole
  /// run of days before the weekday set is even consulted again.
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
    // The instant the habit's own reminder names, which is what every day
    // after the first has to use. It is the same as [reminderTime] on the
    // ordinary path — `ReminderScheduler.schedule` passes exactly this — but
    // not while a snooze is live: there it passes the *snoozed* instant, which
    // belongs to the day it names and to no other. Adding whole days to that
    // would carry the snoozed hour into every later reminder
    // (`audit13.a-snooze-overtaken-by-completion-moves#1`).
    final int ownTime =
        DateUtils.getUpcomingTimeInMillis(reminder.hour, reminder.minute);
    // `getUpcomingTimeInMillis` returns a UTC instant, while
    // `LocalDate.fromUnixTime` is a plain floor-divide that wants local
    // wall-clock millis — which is what the neighbouring
    // `LocalDate.fromUnixTime(timestamp)` is handed, because the core builds
    // `timestamp` with `removeTimezone`. The two agree only at GMT; anywhere
    // the offset carries the reminder across a UTC midnight they differ by a
    // day, and every day the loop steps to would land a day early west of GMT
    // or a day late east of it
    // (`audit14.day-stepping-derives-its-base-day-from-utc#1`).
    final int ownDay =
        LocalDate.fromUnixTime(DateUtils.removeTimezone(ownTime)).daysSince2000;

    var date = LocalDate.fromUnixTime(timestamp);
    var time = reminderTime;
    // The run gate 1 can reject is this habit's own interval; see
    // [_daysToScan].
    final int scan = _daysToScan(habit.frequency.denominator);
    for (var i = 0; i < scan; i++) {
      // notifications.show-gating#7: SUNDAY -> 1, MONDAY -> 2, ..., SATURDAY -> 0.
      final weekday = (date.dayOfWeek.daysSinceSunday + 1) % 7;
      if (days[weekday] && !_isAlreadyCompleted(habit, date)) {
        return _ReminderTarget(time, date);
      }
      date = LocalDate(date.daysSince2000 + 1);
      time = ownTime + (date.daysSince2000 - ownDay) * DateUtils.dayLength;
    }
    return null;
  }

  /// Gate 1 of `NotificationTray.ShowNotificationTask.onPostExecute`:
  ///
  /// ```kotlin
  /// if (isCompleted && habit.targetType != NumericalHabitType.AT_MOST) {
  ///     systemTray.log("Habit ${habit.id} already checked. Skipping.")
  ///     return
  /// }
  /// ```
  ///
  /// `audit3.a-habit-already-completed-today-still#1`: on Android the alarm
  /// still fires and this gate drops the notification, so a habit checked off
  /// in the morning never shows its evening reminder — however many times the
  /// app is opened in between, since every `scheduleAll()` only re-arms the
  /// same alarm the gate will drop again. Here the alarm *is* the notification,
  /// so a day this gate would reject has to be skipped before the alarm is
  /// filed; otherwise the OS posts a reminder Android would have suppressed.
  ///
  /// The day judged is the one the alarm names, whether or not that day is
  /// today. `isCompleted` is `habit.isCompletedToday()`, which reads
  /// `computedEntries.get(getToday())` — and upstream asks the question when
  /// the alarm fires, by which time the alarm's day *is* today. A future day's
  /// computed entry is already known whenever the habit's own frequency has
  /// filled it: `EntryList.buildIntervals` ends the newest interval at
  /// `begin.plus(size - 1)` and `buildEntriesFromInterval` writes YES_AUTO
  /// across all of it, days after today included. So an "Every 3 days" habit
  /// ticked on Monday is YES_AUTO on Tuesday and Wednesday, a "3 times per
  /// week" habit satisfied by Wednesday is YES_AUTO to the end of its week,
  /// and Android posts nothing on any of those days
  /// (`audit18.the-completion-gate-must-judge-the-alarms-own-day#1`).
  ///
  /// Days no interval covers stay UNKNOWN, which is not completed, so a daily
  /// habit ticked today is still armed for tomorrow — the one case where the
  /// answer really is unknowable in advance, and the one where upstream shows
  /// the reminder. Nor can the answer go stale: an alarm already armed is
  /// re-armed by the tray after every entry
  /// (`audit3.recording-a-non-completing-entry-silently`), and every change to
  /// the entries runs `recompute()` first.
  bool _isAlreadyCompleted(Habit habit, LocalDate date) {
    // Redundant on its own — the core's isCompletedToday already answers false
    // for every AT_MOST habit (`notifications.show-gating#11`) — but it is half
    // of the Kotlin condition and states which habits this gate never touches.
    if (habit.targetType == NumericalHabitType.atMost) return false;
    if (!_isCompletedOn(habit, date)) return false;
    log(_loggerName, 'Habit ${habit.id} already checked. Skipping.');
    return true;
  }

  /// `Habit.isCompletedToday()` with the day named instead of assumed.
  ///
  /// ```kotlin
  /// fun isCompletedToday(): Boolean {
  ///     val today = getToday()
  ///     val value = computedEntries.get(today).value
  ///     return if (isNumerical) {
  ///         when (targetType) {
  ///             NumericalHabitType.AT_LEAST -> value / 1000.0 >= targetValue
  ///             NumericalHabitType.AT_MOST -> false
  ///         }
  ///     } else {
  ///         value != Entry.NO && value != Entry.UNKNOWN
  ///     }
  /// }
  /// ```
  ///
  /// SKIP and YES_AUTO both count as completed for a boolean habit
  /// (`models.habit-completed-entered#3`, `notifications.show-gating#10`), and
  /// YES_AUTO is what the frequency fill writes.
  static bool _isCompletedOn(Habit habit, LocalDate date) {
    final int value = habit.computedEntries.get(date).value;
    if (habit.isNumerical) {
      switch (habit.targetType) {
        case NumericalHabitType.atLeast:
          return value / 1000.0 >= habit.targetValue;
        case NumericalHabitType.atMost:
          return false;
      }
    }
    return value != Entry.no && value != Entry.unknown;
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

/// The alarms the platform is still holding.
///
/// `AlarmManager` has no such query, and upstream has no use for one: an
/// Android alarm carries a `PendingIntent` and decides nothing, so a stale one
/// is harmless. Here an alarm carries the finished notification, so the port
/// needs to know which ones are still armed in order to take the obsolete ones
/// back. `flutter_local_notifications` answers with
/// `pendingNotificationRequests()`.
///
/// Kept apart from [AlarmPlugin] the way [ActiveNotificationQuery] is kept
/// apart from [NotificationPresenter]: it is a question about the platform,
/// not one of the calls the scheduler makes.
abstract interface class PendingAlarmQuery {
  /// The notification ids of the alarms still pending, or null when this host
  /// cannot say — which withdraws nothing, the same way [ActiveNotificationQuery]
  /// dismisses nothing when it cannot see the shade.
  Future<Set<int>?> pendingAlarmIds();
}

/// The app's `ReminderScheduler`: the core one, plus the withdrawal pass that
/// replaces the fire-time gates this port cannot run.
///
/// `scheduleAll()` is the one place every path goes through — app start, boot,
/// every command that is not a checkmark or a recolour, and the tray's re-arm
/// after a cancel — so it is also the place to notice that an alarm has
/// outlived the habit it was armed for. The core's own `scheduleAll` skips
/// exactly the two kinds of habit whose alarms have to go: one whose reminder
/// was removed is not in `HabitMatcher.WITH_ALARM` at all, and an archived one
/// is dropped inside `scheduleAtTime`.
///
/// See [FlutterAlarmScheduler.withdrawObsoleteAlarms] for what upstream does
/// instead, and why the port cannot.
class FlutterReminderScheduler extends ReminderScheduler {
  FlutterReminderScheduler({
    required CommandRunner commandRunner,
    required HabitList habitList,
    required FlutterAlarmScheduler alarms,
    required WidgetPreferences widgetPreferences,
  })  : _habitList = habitList,
        _alarms = alarms,
        super(commandRunner, habitList, alarms, widgetPreferences);

  final HabitList _habitList;

  final FlutterAlarmScheduler _alarms;

  @override
  void scheduleAll() {
    super.scheduleAll();
    // Enqueued behind everything the pass above just armed, on the scheduler's
    // own queue, so the pending set is read after the platform has taken them.
    _alarms.withdrawObsoleteAlarms(<int>{
      for (final Habit habit in _habitList.getFiltered(HabitMatcher.withAlarm))
        // The two gates, in the positive: a habit is still wanted when it has
        // a reminder, is not archived, and has an id to file the alarm under
        // (`schedule()` returns early on a null id).
        if (habit.id != null && !habit.isArchived)
          reminderNotificationId(habit),
    });
  }
}

/// [AlarmPlugin] over `flutter_local_notifications`.
///
/// Never exercised by a widget test — the plugin's method channel has no
/// implementation there.
class LocalNotificationsAlarmPlugin implements AlarmPlugin, PendingAlarmQuery {
  LocalNotificationsAlarmPlugin({
    required this.plugin,
    required LocalNotificationsPresenter presenter,
  }) : _presenter = presenter;

  final FlutterLocalNotificationsPlugin plugin;

  final LocalNotificationsPresenter _presenter;

  static bool _timeZonesInitialized = false;

  /// `IntentScheduler.scheduleShowReminder`'s alarm type and delivery mode,
  /// expressed the way this plugin spells it.
  ///
  /// `reminders.exact-alarm-scheduling#4` and `#5`: upstream calls
  /// `AlarmManager.setExactAndAllowWhileIdle(RTC_WAKEUP, ...)`, which wakes a
  /// sleeping device and pierces Doze.
  /// [AndroidScheduleMode.exactAllowWhileIdle] is the plugin's name for
  /// exactly that pair — it forwards to
  /// `AlarmManagerCompat.setExactAndAllowWhileIdle(alarmManager,
  /// AlarmManager.RTC_WAKEUP, ...)`. Every other mode it offers is either
  /// inexact or an alarm clock, and `#3` says explicitly that no inexact
  /// fallback is used.
  static const AndroidScheduleMode reminderScheduleMode =
      AndroidScheduleMode.exactAllowWhileIdle;

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
      // reminders.exact-alarm-scheduling#4 and #5: setExactAndAllowWhileIdle
      // with RTC_WAKEUP.
      androidScheduleMode: reminderScheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: spec.payload,
    );
  }

  @override
  Future<void> cancel(int id) => plugin.cancel(id);

  /// `pendingNotificationRequests()`, which every platform this app runs on
  /// answers — the plugin keeps the scheduled requests itself.
  @override
  Future<Set<int>?> pendingAlarmIds() async {
    final pending = await plugin.pendingNotificationRequests();
    return <int>{for (final request in pending) request.id};
  }

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
