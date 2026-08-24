/// `audit.reminder-notifications-are-auto-cancelled-when`.
///
/// `AndroidNotificationTray.buildNotification()` never calls
/// `setAutoCancel(...)`, so the reminder is posted without FLAG_AUTO_CANCEL:
/// tapping it opens ShowHabitActivity and the reminder STAYS in the shade. It
/// leaves only when the entry is recorded, when it is swiped away (the delete
/// intent) or when it is snoozed — which is what makes "Make notifications
/// sticky" (`setOngoing(true)`) coherent.
///
/// flutter_local_notifications defaults `autoCancel` to `true`, so the port has
/// to pass it explicitly.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const NotificationStrings strings = NotificationStrings(
    yes: 'Yes',
    no: 'No',
    enter: 'Enter',
    snooze: 'Later',
    defaultReminderQuestion: 'Have you completed this habit today?',
    channelName: 'Reminder',
  );

  late Preferences preferences;
  late LocalNotificationsPresenter presenter;

  setUp(() {
    preferences = Preferences(MemoryStorage());
    presenter = LocalNotificationsPresenter(
      plugin: FlutterLocalNotificationsPlugin(),
      builder: ReminderNotificationBuilder(
        preferences: preferences,
        strings: () => strings,
      ),
    );
  });

  NotificationSpec spec({bool ongoing = false}) => NotificationSpec(
        id: 7,
        channelId: NotificationTray.remindersChannelId,
        channelName: strings.channelName,
        categoryId: ReminderCategories.yesNo,
        title: 'Meditate',
        body: 'Did you meditate this morning?',
        whenMillis: 1590000000000,
        ongoing: ongoing,
        playSound: true,
        actions: const <ReminderNotificationAction>[],
        payload: 'payload',
      );

  group('the reminder notification is never auto-cancelled', () {
    test('a plain reminder does not carry FLAG_AUTO_CANCEL', () {
      final details = presenter.detailsFor(spec());

      expect(
        details.android!.autoCancel,
        isFalse,
        reason: 'audit.reminder-notifications-are-auto-cancelled-when#1: the '
            'NotificationCompat.Builder chain in buildNotification() sets '
            'smallIcon/title/text/contentIntent/deleteIntent/sound/when/showWhen/'
            'ongoing and the actions, and never calls setAutoCancel(...), so '
            'tapping the body opens ShowHabitActivity and the reminder stays in '
            'the shade. '
            'audit.reminder-notifications-are-auto-cancelled-when#2: the port '
            'must do the same, but AndroidNotificationDetails defaults '
            'autoCancel to true, so a tap removed a reminder no entry had '
            'answered.',
      );
    });

    test('a sticky reminder is not defeated by a single tap', () {
      final details = presenter.detailsFor(spec(ongoing: true));

      expect(
        details.android!.ongoing,
        isTrue,
        reason: 'audit.reminder-notifications-are-auto-cancelled-when#1: '
            'setOngoing(preferences.shouldMakeNotificationsSticky())',
      );
      expect(
        details.android!.autoCancel,
        isFalse,
        reason: 'audit.reminder-notifications-are-auto-cancelled-when#1: not '
            'calling setAutoCancel is what makes "Make notifications sticky" '
            'coherent — the reminder cannot be got rid of without answering it. '
            'audit.reminder-notifications-are-auto-cancelled-when#2: with the '
            'plugin default the sticky switch was defeated by one tap, and a '
            'later reshowAll() resurrected a notification the user had made '
            'disappear.',
      );
    });

    test('the action buttons still leave the notification alone', () {
      final habit = MemoryModelFactory().buildHabit()
        ..name = 'Meditate'
        ..question = 'Did you meditate this morning?';
      final built = ReminderNotificationBuilder(
        preferences: preferences,
        strings: () => strings,
      ).build(habit, 7, LocalDate.ymd(2020, 5, 20), 1590000000000);

      final details = presenter.detailsFor(built);

      expect(
        details.android!.autoCancel,
        isFalse,
        reason: 'audit.reminder-notifications-are-auto-cancelled-when#1: the '
            'reminder is removed only by the entry being recorded, by the swipe '
            'delete intent, or by a snooze. '
            'audit.reminder-notifications-are-auto-cancelled-when#2: a spec that '
            'came from the real builder must be posted the same way.',
      );
      for (final action in details.android!.actions!) {
        expect(
          action.cancelNotification,
          isFalse,
          reason: 'audit.reminder-notifications-are-auto-cancelled-when#1: the '
              'tray, not the tap, decides when a reminder goes away. '
              'audit.reminder-notifications-are-auto-cancelled-when#2: the '
              'actions already pass cancelNotification: false; the body had to '
              'do the same.',
        );
      }
    });
  });
}
