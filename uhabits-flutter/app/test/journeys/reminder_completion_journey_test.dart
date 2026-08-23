/// Journey: what an entry recorded during the day does to that day's reminder.
///
/// Two audit findings, one mechanism. On Android the alarm and the
/// notification are separate objects, so recording an entry touches only the
/// second one and the day's *alarm* survives until it fires — at which point
/// `NotificationTray.ShowNotificationTask` runs gate 1 and decides whether
/// anything is posted:
///
/// ```kotlin
/// if (isCompleted && habit.targetType != NumericalHabitType.AT_MOST) return
/// ```
///
/// In this port the alarm *is* the finished notification, filed under the same
/// id, so the two halves of that sentence collapsed into one bug each:
///
///  * `audit3.a-habit-already-completed-today-still` — nothing runs gate 1,
///    so every `scheduleAll()` (app start, resume, any command) happily re-arms
///    today's alarm for a habit the user already checked off this morning;
///  * `audit3.recording-a-non-completing-entry-silently` — cancelling the
///    notification cancels the alarm with it, so an entry that does *not*
///    complete the habit destroys a reminder the Android build would still
///    have shown.
///
/// They are tested together because the fix is one decision made in two
/// places: the tray re-arms the day's alarm after every cancel, and the alarm
/// scheduler applies gate 1 when it chooses the day that alarm lands on.
///
/// Everything below is driven from `main()`, through the widgets the user
/// touches and the method calls the app really sent the notification plugin —
/// see the header of journey.dart for why.
library;

// `DateUtils.dayLength` is reached by its `src` path, exactly as
// lib/state/app_scope.dart reaches the core's platform seams.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart'
    show ReminderPayload;
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart'
    show Entry, Habit, LocalDate, getToday;

import 'journey.dart';

/// One scheduled reminder, as the app described it to the platform.
typedef Alarm = ({int id, LocalDate date, int dueAt});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_completion');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// The hour the editor's time picker opens on, and therefore the hour every
  /// reminder in this file is due at.
  const int reminderHour = 8;

  /// The morning the journey happens on: 05:00 local, three hours before the
  /// reminder, on a day a month out.
  ///
  /// Pinning the clock is what makes "the alarm the app filed is for *today*"
  /// a fact rather than a coin toss — `getUpcomingTimeInMillis(8, 0)` answers
  /// tomorrow whenever the suite happens to run after breakfast. It has to be
  /// pinned *forward*, because the notification plugin validates every
  /// `zonedSchedule` against the host's real clock and rejects an alarm in its
  /// own past, which no test hook reaches.
  final DateTime day = DateTime.now().add(const Duration(days: 30));

  /// The UTC instant at which the device's own wall clock reads [hour] on the
  /// journey's day. The core reads the host zone through
  /// `DateTime.timeZoneOffset`, so a plain local [DateTime] is the same
  /// instant it computes with.
  int atHour(int hour) =>
      DateTime(day.year, day.month, day.day, hour).millisecondsSinceEpoch;

  Habit theHabit() => app.scope.habitList.getByPosition(0);

  /// The reminder row of the habit editor, answered with the picker's default.
  ///
  /// `edit-habit.reminder-time#3`: an unset reminder seeds the radial picker at
  /// 08:00, so accepting it is a reminder at 08:00, every day.
  Future<void> addDailyReminder(WidgetTester tester, String habit) async {
    await longPressHabit(tester, habit);
    await tapSelectionMenuItem(tester, ListHabitsSelectionMenuItems.edit);
    await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget,
        reason: 'reminders.edit-ui#4: the reminder row opens the radial time '
            'picker');
    await tester.tap(find.text(
      MaterialLocalizations.of(tester.element(find.byType(TimePickerDialog)))
          .okButtonLabel,
    ));
    await tester.pumpAndSettle();
    await saveHabit(tester);
  }

  /// The notification id a plugin call carries, whichever shape it uses.
  int? idOf(MethodCall call) {
    final Object? arguments = call.arguments;
    if (arguments is Map) return arguments['id'] as int?;
    if (arguments is int) return arguments;
    return null;
  }

  /// One `zonedSchedule` call, read back as the alarm it filed.
  Alarm alarmOf(MethodCall call) {
    final Map<Object?, Object?> arguments =
        call.arguments as Map<Object?, Object?>;
    final ReminderPayload? decoded =
        ReminderPayload.decode(arguments['payload'] as String?);
    expect(decoded, isNotNull,
        reason: 'notifications.content: the payload the app schedules has to '
            'be one the app can decode again');
    return (
      id: arguments['id']! as int,
      date: decoded!.date,
      dueAt: decoded.reminderTime,
    );
  }

  /// The alarm the app most recently filed.
  Alarm scheduledReminder() {
    final List<MethodCall> alarms = device.notifications.scheduledAlarms;
    expect(alarms, isNotEmpty,
        reason: 'reminders.exact-alarm-scheduling: a habit with a reminder has '
            'to reach AlarmManager at all');
    return alarmOf(alarms.last);
  }

  /// Every alarm filed for [id] *after* the last time [id] was cancelled.
  ///
  /// The order is the whole assertion: an alarm filed before the cancel is an
  /// alarm the cancel took down with the notification, which is exactly the
  /// defect. Both halves are read off the calls the app made to the plugin.
  List<MethodCall> alarmsFiledAfterTheCancel(int id) {
    final List<MethodCall> calls = device.notifications.calls;
    final int lastCancel = calls.lastIndexWhere(
      (MethodCall call) => call.method == 'cancel' && idOf(call) == id,
    );
    expect(lastCancel, isNot(-1),
        reason: 'notifications.show-gating#3: recording an entry cancels the '
            'habit\'s notification — that much the port already does');
    return calls
        .sublist(lastCancel + 1)
        .where((MethodCall call) =>
            call.method == 'zonedSchedule' && idOf(call) == id)
        .toList();
  }

  /// Launch on the pinned morning, create one habit, give it a daily reminder.
  Future<Alarm> launchAndSetReminder(
    WidgetTester tester, {
    required String name,
    bool measurable = false,
    String target = '10',
  }) async {
    travelTo(atHour(5));
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(
      tester,
      name: name,
      measurable: measurable,
      target: target,
      unit: 'km',
    );
    await addDailyReminder(tester, name);
    final Alarm alarm = scheduledReminder();
    expect(alarm.date, getToday(),
        reason: 'the precondition of both rules: the alarm the app just filed '
            'is the one due later TODAY — 05:00 now, 08:00 then');
    expect(alarm.dueAt, atHour(reminderHour),
        reason: 'reminders.schedule-at-time: 08:00 on the device\'s own wall '
            'clock');
    return alarm;
  }

  // -------------------------------------------------------------------------
  // audit3.a-habit-already-completed-today-still
  // -------------------------------------------------------------------------

  testWidgets(
      'a habit checked off in the morning does not get today\'s reminder back '
      'when the app is reopened', (WidgetTester tester) async {
    await launchAndSetReminder(tester, name: 'Meditate');
    final LocalDate today = getToday();

    await toggleCheckmark(tester, 'Meditate', today);
    expect(theHabit().computedEntries.get(today).value, Entry.yesManual,
        reason: 'the precondition: the user checked the habit off');
    expect(theHabit().isCompletedToday(), isTrue,
        reason: 'the precondition: a yes/no habit with a YES entry is '
            'completed for the day');

    // "no matter how many times the app is opened in between": every launch
    // runs reminderScheduler.scheduleAll(), and so does every resume.
    await app.restart();

    final Alarm armed = scheduledReminder();
    expect(armed.date, LocalDate(today.daysSince2000 + 1),
        reason: 'audit3.a-habit-already-completed-today-still#1: on Android '
            'the alarm only fires a broadcast. At fire time NotificationTray '
            'runs four gates before anything is posted; gate 1 computes '
            'habit.isCompletedToday() and drops the notification when the '
            'habit is done for the day (unless targetType is AT_MOST). Check a '
            'habit off in the morning and its evening reminder never appears, '
            'no matter how many times the app is opened in between. This port '
            'has no fire-time hook — the alarm IS the notification — so gate 1 '
            'has to run where the alarm is armed, and the next alarm is '
            'tomorrow\'s.');
    expect(armed.dueAt, atHour(reminderHour) + core_time.DateUtils.dayLength,
        reason: 'audit3.a-habit-already-completed-today-still#1: and it is the '
            'habit\'s own reminder on that day, not today\'s alarm re-filed. '
            'One day is one DateUtils.dayLength here, exactly as the weekday '
            'gate already advances — across a DST boundary the alarm lands an '
            'hour off the wall clock and the next scheduleAll corrects it.');
  });

  // -------------------------------------------------------------------------
  // audit3.recording-a-non-completing-entry-silently
  // -------------------------------------------------------------------------

  testWidgets(
      'recording a value below the target leaves the day\'s reminder armed',
      (WidgetTester tester) async {
    final Alarm morning = await launchAndSetReminder(
      tester,
      name: 'Run',
      measurable: true,
      target: '10',
    );
    final LocalDate today = getToday();

    // The user logs 3 km at 05:00. The habit wants 10.
    await tester.tap(find.descendant(
      of: habitRow('Run'),
      matching: find.byKey(entryButtonKey(today)),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('number_value')),
      '3',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleIo(tester);

    expect(theHabit().computedEntries.get(today).value, 3000,
        reason: 'the precondition: round(3.0 * 1000) was recorded for today');
    expect(theHabit().isCompletedToday(), isFalse,
        reason: 'the precondition: 3 km is below the 10 km AT_LEAST target, so '
            'gate 1 would let this reminder through');

    final List<MethodCall> refiled = alarmsFiledAfterTheCancel(morning.id);
    expect(refiled, isNotEmpty,
        reason: 'audit3.recording-a-non-completing-entry-silently#1: entering '
            'a value cancels the notification currently in the shade and '
            'nothing else. If the entry does not complete the habit — a '
            'numeric value below an AT_LEAST target — the alarm still fires '
            'later that day and the reminder is still shown. In this port the '
            'alarm is filed under the notification id, so the cancel takes it '
            'down; the day\'s alarm has to be re-armed behind it.');

    final Alarm armed = alarmOf(refiled.last);
    expect(armed.dueAt, morning.dueAt,
        reason: 'audit3.recording-a-non-completing-entry-silently#1: the same '
            'instant the reminder was already due at — 08:00 today');
    expect(armed.date, today,
        reason: 'audit3.recording-a-non-completing-entry-silently#1: for the '
            'same day, so the checkmark the reminder writes is today\'s');
  });
}
