/// Journey: the user sets a reminder, and answers the notification it posts.
///
/// `verify.integration-harness#3`, journey 8 — "receive a reminder response".
///
/// There is no upstream acceptance test for this — on Android the reminder is
/// an `AlarmManager` broadcast and Espresso cannot see the shade — which is
/// precisely why the port lost it: `verify.notifications-never-initialised`,
/// `verify.notification-actions-unrouted` and `verify.snooze-picker-uncalled`
/// were three separate findings of exactly this shape, every class written and
/// tested, nothing wired.
///
/// The journey therefore does the whole loop through the platform:
///
///  1. the user adds a reminder in the habit editor;
///  2. the app files an alarm with the notification plugin — the journey reads
///     the id, the payload and the due instant off the *method call the app
///     made*, so the notification it answers later is literally the one the
///     app scheduled, not one the test invented;
///  3. the alarm comes due: the clock moves to it and the app is opened again,
///     the way a phone opens it when the user touches the reminder;
///  4. the platform delivers the answer as the
///     `didReceiveNotificationResponse` call the Android and Darwin sides
///     send, which reaches Dart at all only if the app registered a callback
///     when it initialised the plugin.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart'
    show ReminderActions, ReminderPayload;
import 'package:uhabits/ui/common/dialogs/snooze_picker_dialog.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart' show Entry, Habit, LocalDate;

import 'journey.dart';

/// One scheduled reminder, as the app described it to the platform.
typedef Alarm = ({int id, String payload, LocalDate date, int dueAt});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_reminder');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

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

  /// Everything the app told the platform about the alarm it filed.
  ///
  /// The day and the due instant are read out of the payload rather than
  /// assumed, because the payload is all a response carries: if the two ever
  /// disagreed, the answer would be written to the wrong day.
  Alarm scheduledReminder() {
    final List<MethodCall> alarms = device.notifications.scheduledAlarms;
    expect(alarms, isNotEmpty,
        reason: 'reminders.exact-alarm-scheduling: a habit with a reminder has '
            'to reach AlarmManager. ReminderScheduler.onCommandFinished runs '
            'scheduleAll() after every command that is not a repetition or a '
            'colour change, and here the alarm IS the notification.');
    final Map<Object?, Object?> arguments =
        alarms.last.arguments as Map<Object?, Object?>;
    final String payload = arguments['payload']! as String;
    final ReminderPayload? decoded = ReminderPayload.decode(payload);
    expect(decoded, isNotNull,
        reason: 'notifications.content: the payload the app schedules has to '
            'be one the app can decode again — it is the only thing a '
            'response carries');
    return (
      id: arguments['id']! as int,
      payload: payload,
      date: decoded!.date,
      dueAt: decoded.reminderTime,
    );
  }

  Habit theHabit() => app.scope.habitList.getByPosition(0);

  /// Launch, create one habit, give it a daily reminder.
  Future<Alarm> launchAndSetReminder(WidgetTester tester, String name) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: name);
    await addDailyReminder(tester, name);
    return scheduledReminder();
  }

  /// The alarm comes due, and the app is opened on that day.
  ///
  /// `reminders.on-show-reminder`: upstream the alarm is a broadcast into the
  /// app's own process. Here the process is simply started again at that
  /// instant, which is what happens when the user touches a reminder for an
  /// app that is no longer running — and it is what makes the day the
  /// notification names be `getToday()`.
  Future<void> reminderComesDue(Alarm alarm) async {
    travelTo(alarm.dueAt);
    await app.restart();
  }

  testWidgets('setting a reminder files an alarm with the platform',
      (WidgetTester tester) async {
    final Alarm alarm = await launchAndSetReminder(tester, 'Wake up early');

    expect(theHabit().reminder?.hour, 8,
        reason: 'edit-habit.reminder-time#3: the picker opens at 08:00 and the '
            'form saves what it answered');
    expect(alarm.payload, isNotEmpty,
        reason: 'notifications.content: every reminder carries the payload '
            'that identifies the habit and the day — without it a response '
            'cannot be routed anywhere');
    expect(device.notifications.lastCallNamed('initialize'), isNotNull,
        reason: 'verify.notifications-never-initialised: the plugin has to '
            'have been initialised at startup, or the alarm above would throw '
            'inside the plugin at fire time');
  });

  testWidgets('a tap on the notification body opens the habit',
      (WidgetTester tester) async {
    final Alarm alarm = await launchAndSetReminder(tester, 'Wake up early');
    await reminderComesDue(alarm);

    // No actionId: the content intent, which upstream is
    // `IntentFactory.startShowHabitActivity`.
    await device.notifications.deliverResponse(
      notificationId: alarm.id,
      payload: alarm.payload,
    );
    await settleIo(tester);

    expect(find.byType(ShowHabitScreen), findsOneWidget,
        reason: 'verify.notification-actions-unrouted#1: the content intent '
            'starts ShowHabitActivity with ListHabitsActivity beneath it. '
            'That hook needs a BuildContext, so it is installed by the app '
            'widget — a journey is the only kind of test that can see it '
            'missing.');
    verifyDisplaysText('Wake up early');
  });

  testWidgets('"Yes" writes the entry without opening anything',
      (WidgetTester tester) async {
    final Alarm alarm = await launchAndSetReminder(tester, 'Wake up early');
    await reminderComesDue(alarm);
    expect(theHabit().computedEntries.get(alarm.date).value, Entry.unknown,
        reason: 'the precondition: nothing recorded for the day the reminder '
            'names');

    await device.notifications.deliverResponse(
      notificationId: alarm.id,
      actionId: ReminderActions.addRepetition,
      payload: alarm.payload,
    );
    await settleIo(tester);

    expect(theHabit().computedEntries.get(alarm.date).value, Entry.yesManual,
        reason: 'verify.notification-actions-unrouted#1: "Yes" broadcasts '
            'ACTION_ADD_REPETITION to WidgetReceiver, which writes the entry '
            'without any UI');
    expect(find.byType(ShowHabitScreen), findsNothing,
        reason: 'and it opens nothing: the button shows no user interface');
    expect(device.notifications.cancelledIds, contains(alarm.id),
        reason: 'notifications.show-gating#3: recording an entry cancels the '
            'reminder, so the notification the user just answered leaves the '
            'shade');
  });

  testWidgets('"No" writes a NO entry', (WidgetTester tester) async {
    final Alarm alarm = await launchAndSetReminder(tester, 'Wake up early');
    await reminderComesDue(alarm);

    await device.notifications.deliverResponse(
      notificationId: alarm.id,
      actionId: ReminderActions.removeRepetition,
      payload: alarm.payload,
    );
    await settleIo(tester);

    expect(theHabit().computedEntries.get(alarm.date).value, Entry.no,
        reason: 'verify.notification-actions-unrouted#1: "No" broadcasts '
            'ACTION_REMOVE_REPETITION');
  });

  testWidgets('"Later" opens the snooze picker', (WidgetTester tester) async {
    final Alarm alarm = await launchAndSetReminder(tester, 'Wake up early');
    await reminderComesDue(alarm);

    await device.notifications.deliverResponse(
      notificationId: alarm.id,
      actionId: ReminderActions.snoozeReminder,
      payload: alarm.payload,
    );
    await settleIo(tester);

    expect(find.byType(SnoozePickerDialog), findsOneWidget,
        reason: 'verify.snooze-picker-uncalled#1: "Later" starts '
            'SnoozeDelayPickerActivity. The picker needs a screen, so — like '
            'the body tap — it is unreachable unless the running app installs '
            'the hook.');
  });

  testWidgets('the answer given to a notification survives a restart',
      (WidgetTester tester) async {
    final Alarm alarm = await launchAndSetReminder(tester, 'Wake up early');
    await reminderComesDue(alarm);

    await device.notifications.deliverResponse(
      notificationId: alarm.id,
      actionId: ReminderActions.addRepetition,
      payload: alarm.payload,
    );
    await settleIo(tester);

    await app.restart();

    expect(theHabit().computedEntries.get(alarm.date).value, Entry.yesManual,
        reason: 'the notification path writes through the same command runner '
            'as the list does, so the entry has to be in the database');
  });
}
