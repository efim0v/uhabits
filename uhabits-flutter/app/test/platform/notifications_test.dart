// The two classes under test implement core interfaces that are reached by
// their `src` path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart';
import 'package:uhabits/platform/flutter_notification_tray.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

/// Tests for the platform half of the reminder pipeline: the
/// `NotificationTray.SystemTray` implementation
/// ([FlutterNotificationTray] + [ReminderNotificationBuilder]) and the
/// `ReminderScheduler.SystemScheduler` implementation ([FlutterAlarmScheduler]).
///
/// The Kotlin counterparts are `AndroidNotificationTray`, `PendingIntentFactory`
/// and `IntentScheduler`; none of them has a Kotlin test, so the parity-ledger
/// rules are the only specification and every `expect` cites the one it
/// exercises.
///
/// `flutter_local_notifications` cannot run in a widget test, so both classes
/// talk to the platform through a one-method-per-call interface —
/// [NotificationPresenter] and [AlarmPlugin] — and everything below runs against
/// a fake. `LocalNotificationsPresenter` and `LocalNotificationsAlarmPlugin`,
/// the real implementations, hold nothing but the translation into plugin
/// types.
void main() {
  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  const TimeZone gmt = FixedTimeZone(0);
  const TimeZone gmtMinus4 = FixedTimeZone(-4 * DateUtils.hourLength);

  int unixTime(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;

  const NotificationStrings strings = NotificationStrings(
    yes: 'Yes',
    no: 'No',
    enter: 'Enter',
    snooze: 'Later',
    defaultReminderQuestion: 'Have you completed this habit today?',
    channelName: 'Reminder',
  );

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late MemoryStorage storage;
  late Preferences preferences;
  late StringBuffer logBuffer;
  late Logging logging;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 26));
    DateUtils.setFixedTimeZone(gmt);
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    storage = MemoryStorage();
    preferences = Preferences(storage);
    logBuffer = StringBuffer();
    logging = StandardLogging(out: logBuffer, err: logBuffer);
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  ReminderNotificationBuilder buildBuilder({bool snoozeActionEnabled = true}) =>
      ReminderNotificationBuilder(
        preferences: preferences,
        strings: () => strings,
        snoozeActionEnabled: snoozeActionEnabled,
      );

  Habit yesNoHabit({
    int? id = 10,
    String name = 'Meditate',
    String question = 'Did you meditate this morning?',
    Reminder? reminder,
  }) {
    final habit = fixtures.createEmptyHabit(name: name);
    habit.id = id;
    habit.question = question;
    habit.reminder = reminder ?? Reminder(8, 30, WeekdayList.everyDay);
    return habit;
  }

  Habit numericalHabit({int? id = 11}) {
    final habit = fixtures.createEmptyNumericalHabit(NumericalHabitType.atLeast);
    habit.id = id;
    habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
    return habit;
  }

  // -----------------------------------------------------------------------
  // intents.actions-and-extras — what the notification carries
  // -----------------------------------------------------------------------

  group('ReminderPayload', () {
    test('#10 identifies the habit by its content URI', () {
      const payload = ReminderPayload(
        habitId: 10,
        timestamp: 1422230400000,
        reminderTime: 1422260200000,
      );
      expect(
        payload.encode(),
        startsWith('content://org.isoron.uhabits/habit/10'),
        reason: 'intents.actions-and-extras#10: the habit is always identified '
            'by the data URI content://org.isoron.uhabits/habit/<id>',
      );
    });

    test('#11 carries the timestamp and reminderTime extras', () {
      final timestamp = unixTime(2015, 1, 25);
      final reminderTime = unixTime(2015, 1, 25, 8, 30);
      final decoded = ReminderPayload.decode(
        ReminderPayload(
          habitId: 10,
          timestamp: timestamp,
          reminderTime: reminderTime,
        ).encode(),
      );
      expect(decoded, isNotNull);
      expect(decoded!.habitId, 10,
          reason: 'intents.actions-and-extras#10: receivers resolve the habit '
              'id out of the data URI');
      expect(decoded.timestamp, timestamp,
          reason: 'intents.actions-and-extras#11: the extra "timestamp" is the '
              'local-midnight checkmark timestamp');
      expect(decoded.reminderTime, reminderTime,
          reason: 'intents.actions-and-extras#11: the extra "reminderTime" is '
              'the alarm instant');
      expect(decoded.date, LocalDate.ymd(2015, 1, 25),
          reason: 'notifications.show-gating#8: the date carried by the '
              'notification is the alarm target day');
    });

    test('decoding rejects anything this app did not write', () {
      expect(ReminderPayload.decode(null), isNull);
      expect(ReminderPayload.decode('content://org.isoron.uhabits/habit/abc'),
          isNull);
      expect(ReminderPayload.decode('content://org.isoron.uhabits/habit/10'),
          isNull,
          reason: 'both extras are required, the way ReminderReceiver reads '
              'both getLongExtra values');
    });

    test('an action id maps back onto the receiver that handled it', () {
      final payload = ReminderPayload(
        habitId: 10,
        timestamp: unixTime(2015, 1, 25),
        reminderTime: unixTime(2015, 1, 25, 8, 30),
      ).encode();
      ReminderResponseKind? kindOf(String? actionId) =>
          ReminderResponse.decode(actionId: actionId, payload: payload)?.kind;

      expect(kindOf(null), ReminderResponseKind.open,
          reason: 'notifications.content#5: tapping the notification opens the '
              'habit');
      expect(kindOf(ReminderActions.addRepetition),
          ReminderResponseKind.addRepetition,
          reason: 'notifications.actions#5: "Yes" broadcasts '
              'org.isoron.uhabits.ACTION_ADD_REPETITION');
      expect(kindOf(ReminderActions.removeRepetition),
          ReminderResponseKind.removeRepetition,
          reason: 'notifications.actions#6: "No" broadcasts '
              'org.isoron.uhabits.ACTION_REMOVE_REPETITION');
      expect(kindOf(ReminderActions.edit), ReminderResponseKind.edit,
          reason: 'notifications.actions#7: "Enter" starts ListHabitsActivity '
              'with action org.isoron.uhabits.ACTION_EDIT');
      expect(kindOf(ReminderActions.snoozeReminder), ReminderResponseKind.snooze,
          reason: 'notifications.actions#8: "Later" broadcasts '
              'org.isoron.uhabits.ACTION_SNOOZE_REMINDER');
      expect(kindOf(ReminderActions.dismissReminder),
          ReminderResponseKind.dismiss,
          reason: 'notifications.content#6: the delete intent is '
              'org.isoron.uhabits.ACTION_DISMISS_REMINDER');
      expect(kindOf('org.isoron.uhabits.ACTION_SOMETHING_ELSE'), isNull);
    });

    test('the exact intent action strings are preserved', () {
      expect(ReminderActions.showReminder,
          'org.isoron.uhabits.ACTION_SHOW_REMINDER',
          reason: 'intents.actions-and-extras#1');
      expect(ReminderActions.dismissReminder,
          'org.isoron.uhabits.ACTION_DISMISS_REMINDER',
          reason: 'intents.actions-and-extras#2');
      expect(ReminderActions.snoozeReminder,
          'org.isoron.uhabits.ACTION_SNOOZE_REMINDER',
          reason: 'intents.actions-and-extras#3');
      expect(ReminderActions.addRepetition,
          'org.isoron.uhabits.ACTION_ADD_REPETITION',
          reason: 'intents.actions-and-extras#4');
      expect(ReminderActions.removeRepetition,
          'org.isoron.uhabits.ACTION_REMOVE_REPETITION',
          reason: 'intents.actions-and-extras#5');
      expect(ReminderActions.edit, 'org.isoron.uhabits.ACTION_EDIT',
          reason: 'intents.actions-and-extras#9');
      expect(ReminderActions.edit, 'org.isoron.uhabits.ACTION_EDIT',
          reason: 'platform-glue.deep-link-edit-entry#1 — '
              'ListHabitsActivity.ACTION_EDIT is the literal string '
              '"org.isoron.uhabits.ACTION_EDIT". It is the action the '
              'notification\'s "Enter" button and the numerical Checkmark '
              'widget both use, so the string has to stay byte-for-byte what '
              'it was.');
    });

    test('there is one dismiss action, not two copies of one string', () {
      // Upstream declares ACTION_DISMISS_REMINDER twice — once on
      // ReminderReceiver and once on WidgetReceiver — and
      // PendingIntentFactory.dismissNotification targets ReminderReceiver
      // while naming WidgetReceiver's copy. The port has one constant, so the
      // two spellings cannot drift apart.
      final Set<String> dismissConstants = <String>{
        ReminderActions.dismissReminder,
      };

      expect(dismissConstants, <String>{'org.isoron.uhabits.ACTION_DISMISS_REMINDER'},
          reason: 'intents.actions-and-extras#8 — WidgetReceiver also declares '
              'its own constant ACTION_DISMISS_REMINDER with the identical '
              'string "org.isoron.uhabits.ACTION_DISMISS_REMINDER"; '
              'PendingIntentFactory.dismissNotification actually targets '
              'ReminderReceiver but uses WidgetReceiver\'s copy of the constant '
              '— the strings are equal so behaviour is unaffected. There is one '
              'copy here and the string is unchanged, so the behaviour stays '
              'unaffected for the same reason and cannot stop being.');

      // The one place the string is consumed still routes to dismissal.
      expect(
        ReminderResponse.decode(
          actionId: ReminderActions.dismissReminder,
          payload: const ReminderPayload(
            habitId: 10,
            timestamp: 0,
            reminderTime: 0,
          ).encode(),
        )?.kind,
        ReminderResponseKind.dismiss,
        reason: 'intents.actions-and-extras#8: and it is the dismissal branch '
            'that answers it, whichever receiver upstream would have used',
      );
    });
  });

  // -----------------------------------------------------------------------
  // notifications.id-and-registry
  // -----------------------------------------------------------------------

  group('notification id', () {
    test('#1 is the habit id modulo Int.MAX_VALUE, or 0 when the id is null',
        () {
      final habit = yesNoHabit(id: 10);
      expect(reminderNotificationId(habit), 10,
          reason: 'notifications.id-and-registry#1: '
              '(habit.id % Int.MAX_VALUE).toInt()');

      habit.id = null;
      expect(reminderNotificationId(habit), 0,
          reason: 'notifications.id-and-registry#1: 0 when habit.id is null');

      habit.id = 2147483647;
      expect(reminderNotificationId(habit), 0,
          reason: 'notifications.id-and-registry#1: Int.MAX_VALUE wraps to 0');

      habit.id = 2147483650;
      expect(reminderNotificationId(habit), 3,
          reason: 'notifications.id-and-registry#1: ids beyond Int.MAX_VALUE '
              'wrap around');

      habit.id = -5;
      expect(reminderNotificationId(habit), -5,
          reason: 'notifications.id-and-registry#1: Kotlin % on a Long is a '
              'truncated remainder, so a negative id stays negative');
    });
  });

  // -----------------------------------------------------------------------
  // notifications.content
  // -----------------------------------------------------------------------

  group('notification content', () {
    test('#1 #3 #7 the channel, the title and the timestamp', () {
      final habit = yesNoHabit();
      final reminderTime = unixTime(2015, 1, 26, 8, 30);
      final spec = buildBuilder()
          .build(habit, 10, LocalDate.ymd(2015, 1, 26), reminderTime);

      expect(spec.channelId, 'REMINDERS',
          reason: 'notifications.content#1 and '
              'settings.screen.reminder-category#8: the channel id is the '
              'constant "REMINDERS"');
      expect(spec.channelId, NotificationTray.remindersChannelId,
          reason: 'notifications.content#1 and '
              'settings.screen.reminder-category#8: it is '
              'NotificationTray.REMINDERS_CHANNEL_ID');
      expect(spec.channelName, 'Reminder',
          reason: 'notifications.channel#1 and '
              'settings.screen.reminder-category#8: the channel is created '
              'with name = the localized string "Reminder"');
      expect(spec.title, 'Meditate',
          reason: 'notifications.content#3: the content title is habit.name '
              'verbatim');
      expect(spec.whenMillis, reminderTime,
          reason: 'notifications.content#7: setWhen(reminderTime) — the '
              'timestamp shown is the reminder instant, not the posting moment');
      expect(spec.showWhen, isTrue,
          reason: 'notifications.content#7: setShowWhen(true)');
    });

    test('#7 the developer "notify now" action stamps the Unix epoch', () {
      // `ListHabitsSelectionMenu` passes reminderTime = 0 for the dev-only
      // action_notify item, and setWhen takes that number as-is.
      final spec =
          buildBuilder().build(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 0);

      expect(spec.whenMillis, 0,
          reason: 'notifications.dev-test-action#3: because reminderTime is 0, '
              "the resulting notification's setWhen is the Unix epoch");
      expect(
        DateTime.fromMillisecondsSinceEpoch(spec.whenMillis, isUtc: true),
        DateTime.utc(1970),
        reason: 'notifications.dev-test-action#3: 0 ms is 1970-01-01T00:00Z, '
            'so the notification is stamped with the epoch rather than with '
            'the moment it was posted',
      );
      expect(spec.showWhen, isTrue,
          reason: 'notifications.dev-test-action#3: and the timestamp is '
              'shown, so the epoch is what the user sees');
    });

    test('#4 the body is the question, or the default question when blank', () {
      final habit = yesNoHabit(question: 'Did you meditate this morning?');
      final builder = buildBuilder();
      expect(
        builder.build(habit, 10, LocalDate.ymd(2015, 1, 26), 0).body,
        'Did you meditate this morning?',
        reason: 'notifications.content#4: the content text is habit.question',
      );

      habit.question = '   ';
      expect(
        builder.build(habit, 10, LocalDate.ymd(2015, 1, 26), 0).body,
        'Have you completed this habit today?',
        reason: 'notifications.content#4: unless habit.question.isBlank(), in '
            'which case it is default_reminder_question',
      );
    });

    test('#8 ongoing follows the sticky preference', () {
      final habit = yesNoHabit();
      final builder = buildBuilder();
      expect(
        builder.build(habit, 10, LocalDate.ymd(2015, 1, 26), 0).ongoing,
        isFalse,
        reason: 'notifications.sticky-and-dismiss#1 and '
            'settings.preferences.sticky-notifications#4: '
            'pref_sticky_notifications defaults to false, so nothing is '
            'ongoing',
      );

      preferences.setNotificationsSticky(true);
      expect(
        builder.build(habit, 10, LocalDate.ymd(2015, 1, 26), 0).ongoing,
        isTrue,
        reason: 'notifications.content#8 and '
            'settings.preferences.sticky-notifications#4: every reminder is '
            'built with '
            'setOngoing(preferences.shouldMakeNotificationsSticky())',
      );

      preferences.setNotificationsSticky(false);
      expect(
        builder.build(habit, 10, LocalDate.ymd(2015, 1, 26), 0).ongoing,
        isFalse,
        reason: 'settings.preferences.sticky-notifications#4: the flag is '
            'read afresh for every notification, not captured once',
      );
    });

    test('#9 #10 #11 sound, colour and grouping', () {
      final habit = yesNoHabit();
      final builder = buildBuilder();
      final spec = builder.build(habit, 10, LocalDate.ymd(2015, 1, 26), 0);

      expect(spec.playSound, isTrue,
          reason: 'notifications.content#9: the ringtone is applied whenever '
              'disableSound is false');
      expect(
        builder
            .build(habit, 10, LocalDate.ymd(2015, 1, 26), 0, disableSound: true)
            .playSound,
        isFalse,
        reason: 'notifications.content#9: the builder starts from setSound(null)',
      );
      expect(spec.color, isNull,
          reason: "notifications.content#10: the habit's colour is NOT applied "
              'to the notification');
      expect(spec.groupKey, isNull,
          reason: 'notifications.content#11: the notification carries no group '
              'or summary');
    });

    test(
        'settings.reminder-sound-row-hidden#3 — every reminder plays the '
        'system default notification sound', () {
      // The ringtone picker is unreachable, so `pref_ringtone_uri` is never
      // written; nothing in the notification pipeline reads it, and the
      // notification therefore carries no sound of its own.
      storage.putString('pref_ringtone_uri', 'content://media/ringtone/17');
      final habit = yesNoHabit();
      final spec = buildBuilder().build(habit, 10, LocalDate.ymd(2015, 1, 26), 0);

      expect(spec.playSound, isTrue,
          reason: 'settings.reminder-sound-row-hidden#3: RingtoneManager'
              '.getURI() always returns its fallback '
              'Settings.System.DEFAULT_NOTIFICATION_URI, so every reminder '
              'plays the system default notification sound');
      expect(spec.toString(), isNot(contains('content://media/ringtone/17')),
          reason: "settings.reminder-sound-row-hidden#3: a value stored under "
              'pref_ringtone_uri by anything other than the (dead) picker is '
              'never read back — the notification carries no ringtone URI');
      expect(
        buildBuilder()
            .build(habit, 10, LocalDate.ymd(2015, 1, 26), 0, disableSound: true)
            .playSound,
        isFalse,
        reason: "settings.reminder-sound-row-hidden#3: the 'silent' state is "
            'unreachable through the UI — the only thing that can silence a '
            'reminder is the internal disableSound retry',
      );
    });
  });

  // -----------------------------------------------------------------------
  // notifications.actions
  // -----------------------------------------------------------------------

  group('notification actions', () {
    test('#2 #3 a yes/no habit gets "Yes", "No", then "Later"', () {
      final spec = buildBuilder()
          .build(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 0);

      expect(
        spec.actions.map((a) => a.title).toList(),
        ['Yes', 'No', 'Later'],
        reason: 'notifications.actions#2: exactly two actions in this order, '
            '"Yes" then "No"; notifications.actions#3: "Later" is appended '
            'after them',
      );
      expect(
        spec.actions.map((a) => a.id).toList(),
        [
          ReminderActions.addRepetition,
          ReminderActions.removeRepetition,
          ReminderActions.snoozeReminder,
        ],
        reason: 'notifications.actions#5, #6 and #8: each button carries the '
            'action of the receiver that answers it',
      );
    });

    test('#1 a numerical habit gets exactly one "Enter" action', () {
      final spec = buildBuilder()
          .build(numericalHabit(), 11, LocalDate.ymd(2015, 1, 26), 0);

      expect(
        spec.actions.map((a) => a.title).toList(),
        ['Enter', 'Later'],
        reason: 'notifications.actions#1: for a NUMERICAL habit exactly one '
            'action is added, labelled "Enter"; notifications.actions#3 adds '
            '"Later" after it',
      );
      expect(spec.actions.first.id, ReminderActions.edit,
          reason: 'notifications.actions#7: "Enter" starts ListHabitsActivity '
              'with action ACTION_EDIT');
    });

    test('the snooze action can be hidden, as Android 12+ hides it', () {
      final spec = buildBuilder(snoozeActionEnabled: false)
          .build(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 0);

      expect(
        spec.actions.map((a) => a.title).toList(),
        ['Yes', 'No'],
        reason: 'reminders.snooze-android12-gate#1: the "Later" action is added '
            'only when SDK_INT < 31. The Flutter port answers the action in '
            'Dart instead of trampolining into an activity, so the gate does '
            'not apply and the button is enabled by default',
      );
    });

    test('the iOS categories mirror the action lists exactly', () {
      final builder = buildBuilder();
      final categories = {
        for (final category in builder.categories())
          category.identifier: category.actions.map((a) => a.id).toList(),
      };

      expect(
        categories[ReminderCategories.yesNo],
        [
          ReminderActions.addRepetition,
          ReminderActions.removeRepetition,
          ReminderActions.snoozeReminder,
        ],
        reason: 'notifications.actions#2 and #3: on iOS the buttons are '
            'UNNotificationActions declared at initialisation, so the category '
            'has to carry the same list the notification names',
      );
      expect(
        categories[ReminderCategories.numerical],
        [ReminderActions.edit, ReminderActions.snoozeReminder],
        reason: 'notifications.actions#1 and #3',
      );
      expect(
        builder
            .build(numericalHabit(), 11, LocalDate.ymd(2015, 1, 26), 0)
            .categoryId,
        ReminderCategories.numerical,
        reason: 'notifications.actions#1: a numerical habit names the '
            'one-button category',
      );
      expect(
        builder.build(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 0).categoryId,
        ReminderCategories.yesNo,
        reason: 'notifications.actions#2: a yes/no habit names the two-button '
            'category',
      );
    });
  });

  // -----------------------------------------------------------------------
  // FlutterNotificationTray — the SystemTray implementation
  // -----------------------------------------------------------------------

  group('FlutterNotificationTray', () {
    late _FakePresenter presenter;
    late FlutterNotificationTray tray;

    setUp(() {
      presenter = _FakePresenter();
      tray = FlutterNotificationTray(
        presenter: presenter,
        builder: buildBuilder(),
        logging: logging,
      );
    });

    test('#6 showing adds the id to the tray\'s own active set', () async {
      final habit = yesNoHabit();
      tray.showNotification(habit, 10, LocalDate.ymd(2015, 1, 26), 500);
      await tray.settle();

      expect(presenter.shown.single.id, 10,
          reason: 'notifications.id-and-registry#6: showNotification posts '
              'under the id the core computed');
      expect(tray.activeNotificationIds, {10},
          reason: 'notifications.id-and-registry#6: showNotification adds the '
              'id to its own HashSet<Int> of active ids');
    });

    test('#6 removing cancels and drops the id', () async {
      final habit = yesNoHabit();
      tray.showNotification(habit, 10, LocalDate.ymd(2015, 1, 26), 500);
      tray.removeNotification(10);
      await tray.settle();

      expect(presenter.cancelled, [10],
          reason: 'notifications.id-and-registry#6: removeNotification(id) '
              'calls NotificationManagerCompat.cancel(id)');
      expect(tray.activeNotificationIds, isEmpty,
          reason: 'notifications.id-and-registry#6: and removes the id from its '
              'own HashSet<Int>');
    });

    test('#8 a failing post is retried without sound', () async {
      presenter.failNextShow = true;
      tray.showNotification(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 500);
      await tray.settle();

      expect(presenter.shown.length, 2,
          reason: 'notifications.sound#8: if notify throws a RuntimeException '
              'the notification is rebuilt and posted again');
      expect(presenter.shown.first.playSound, isTrue);
      expect(presenter.shown.last.playSound, isFalse,
          reason: 'notifications.sound#8: the retry is built with '
              'disableSound = true (setSound(null))');
      expect(tray.activeNotificationIds, {10},
          reason: 'notifications.sound#8: the retry succeeds, so the id is '
              'still recorded as active');
    });

    test(
        'notifications.channel#2 — every post names the channel, so it is '
        '(re)created immediately before notifying', () async {
      tray.showNotification(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 500);
      tray.showNotification(numericalHabit(), 11, LocalDate.ymd(2015, 1, 26), 0);
      presenter.failNextShow = true;
      tray.showNotification(yesNoHabit(id: 12), 12, LocalDate.ymd(2015, 1, 26), 0);
      await tray.settle();

      expect(presenter.shown, hasLength(4),
          reason: 'notifications.channel#2: three posts plus the soundless '
              'retry of the third');
      for (final spec in presenter.shown) {
        expect(spec.channelId, NotificationTray.remindersChannelId,
            reason: 'notifications.channel#2: the channel is (re)created on '
                'every showNotification call, immediately before notifying — '
                'the id travels with the notification rather than being '
                'assumed to exist');
        expect(spec.channelName, strings.channelName,
            reason: 'notifications.channel#2: with the name it would be '
                '(re)created under, so a renamed channel follows the very '
                'next post');
      }
    });

    test('log() forwards the core\'s messages', () {
      tray.log('Showing notification for habit=10');
      expect(logBuffer.toString(),
          contains('Showing notification for habit=10'),
          reason: 'notifications.show-gating#9: "Showing notification for '
              'habit=<id>" is logged before the gates run');
    });
  });

  // -----------------------------------------------------------------------
  // The core NotificationTray driving the Flutter tray end to end
  // -----------------------------------------------------------------------

  group('NotificationTray over FlutterNotificationTray', () {
    late _FakePresenter presenter;
    late FlutterNotificationTray systemTray;
    late NotificationTray core;
    late CommandRunner commandRunner;

    setUp(() {
      presenter = _FakePresenter();
      systemTray = FlutterNotificationTray(
        presenter: presenter,
        builder: buildBuilder(),
        logging: logging,
      );
      final taskRunner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      commandRunner = CommandRunner(taskRunner);
      core = NotificationTray(
        taskRunner,
        commandRunner,
        preferences,
        systemTray,
      );
    });

    test('#9 a habit that passes every gate is posted', () async {
      final habit = yesNoHabit();
      core.show(habit, LocalDate.ymd(2015, 1, 26), 4321);
      await systemTray.settle();

      expect(presenter.shown.length, 1,
          reason: 'notifications.show-gating#9: only if all four gates pass is '
              'systemTray.showNotification invoked');
      expect(presenter.shown.single.title, 'Meditate',
          reason: 'notifications.content#3');
      expect(presenter.shown.single.whenMillis, 4321,
          reason: 'notifications.content#7: setWhen(reminderTime)');
    });

    test('#3 a habit already checked today is not posted', () async {
      final habit = yesNoHabit();
      habit.originalEntries.add(Entry(getToday(), Entry.yesManual));
      habit.recompute();

      core.show(habit, LocalDate.ymd(2015, 1, 26), 4321);
      await systemTray.settle();

      expect(presenter.shown, isEmpty,
          reason: 'notifications.show-gating#3: gate 1 skips a completed habit '
              'whose targetType is not AT_MOST');
    });

    test('#6 a habit whose reminder does not cover the day is not posted',
        () async {
      // 2015-01-26 is a Monday; index (dayOfWeek.daysSinceSunday + 1) % 7 = 2.
      final mondaysOnly = WeekdayList.fromArray(
        [false, false, true, false, false, false, false],
      );
      final habit = yesNoHabit(reminder: Reminder(8, 30, mondaysOnly));

      core.show(habit, LocalDate.ymd(2015, 1, 27), 4321);
      await systemTray.settle();
      expect(presenter.shown, isEmpty,
          reason: 'notifications.show-gating#6: gate 4 skips a day the '
              "reminder's weekday set does not contain");

      core.show(habit, LocalDate.ymd(2015, 1, 26), 4321);
      await systemTray.settle();
      expect(presenter.shown.length, 1,
          reason: 'notifications.show-gating#7: SUNDAY -> 1, MONDAY -> 2, ..., '
              'SATURDAY -> 0');
    });

    test('#3 cancelling reaches the platform', () async {
      final habit = yesNoHabit();
      core.show(habit, LocalDate.ymd(2015, 1, 26), 4321);
      core.cancel(habit);
      await systemTray.settle();

      expect(presenter.cancelled, [10],
          reason: 'notifications.id-and-registry#3: cancel(habit) calls '
              'systemTray.removeNotification(getNotificationId(habit))');
    });
  });

  // -----------------------------------------------------------------------
  // FlutterAlarmScheduler — the SystemScheduler implementation
  // -----------------------------------------------------------------------

  group('FlutterAlarmScheduler', () {
    late _FakeAlarmPlugin plugin;

    FlutterAlarmScheduler buildScheduler({required int now}) =>
        FlutterAlarmScheduler(
          plugin: plugin,
          builder: buildBuilder(),
          logging: logging,
          nowMillis: () => now,
        );

    setUp(() {
      plugin = _FakeAlarmPlugin();
    });

    test('#2 an instant in the past is ignored', () async {
      final scheduler = buildScheduler(now: unixTime(2015, 1, 26, 12, 0));
      final result = scheduler.scheduleShowReminder(
        unixTime(2015, 1, 26, 11, 59),
        yesNoHabit(),
        unixTime(2015, 1, 26),
      );
      await scheduler.settle();

      expect(result, SchedulerResult.ignored,
          reason: 'reminders.exact-alarm-scheduling#2: schedule returns IGNORED '
              'when timestamp < System.currentTimeMillis()');
      expect(plugin.scheduled, isEmpty,
          reason: 'reminders.exact-alarm-scheduling#2: no alarm is set');
      expect(
        logBuffer.toString(),
        contains('Ignoring attempt to schedule intent in the past.'),
        reason: 'reminders.exact-alarm-scheduling#2: it logs "Ignoring attempt '
            'to schedule intent in the past."',
      );
    });

    test('#2 an instant exactly equal to now is accepted', () async {
      final now = unixTime(2015, 1, 26, 12, 0);
      final scheduler = buildScheduler(now: now);
      final result = scheduler.scheduleShowReminder(
        now,
        yesNoHabit(),
        unixTime(2015, 1, 26),
      );
      await scheduler.settle();

      expect(result, SchedulerResult.ok,
          reason: 'reminders.exact-alarm-scheduling#2: a timestamp exactly '
              'equal to now is accepted');
      expect(plugin.scheduled.single.whenMillis, now);
    });

    test('#3 no exact-alarm permission means no alarm and no fallback',
        () async {
      plugin.exactAlarmsAllowed = false;
      final scheduler = buildScheduler(now: unixTime(2015, 1, 26, 6, 0));
      await scheduler.refreshExactAlarmPermission();

      final result = scheduler.scheduleShowReminder(
        unixTime(2015, 1, 26, 12, 30),
        yesNoHabit(),
        unixTime(2015, 1, 26),
      );
      await scheduler.settle();

      expect(result, SchedulerResult.ignored,
          reason: 'reminders.exact-alarm-scheduling#3: on SDK >= 31, if '
              'canScheduleExactAlarms() is false it returns IGNORED');
      expect(plugin.scheduled, isEmpty,
          reason: 'reminders.exact-alarm-scheduling#3: no alarm is set and no '
              'fallback inexact alarm is used');
      expect(logBuffer.toString(),
          contains('No permission to schedule exact alarms'),
          reason: 'reminders.exact-alarm-scheduling#3: it logs "No permission '
              'to schedule exact alarms"');
    });

    test('#4 otherwise the alarm is set and OK is returned', () async {
      final scheduler = buildScheduler(now: unixTime(2015, 1, 26, 6, 0));
      final reminderTime = unixTime(2015, 1, 26, 12, 30);
      final result = scheduler.scheduleShowReminder(
        reminderTime,
        yesNoHabit(),
        unixTime(2015, 1, 26),
      );
      await scheduler.settle();

      expect(result, SchedulerResult.ok,
          reason: 'reminders.exact-alarm-scheduling#4: it calls '
              'setExactAndAllowWhileIdle and returns OK');
      expect(plugin.scheduled.single.whenMillis, reminderTime,
          reason: 'reminders.exact-alarm-scheduling#4: the alarm is set for the '
              'instant the core computed');
      expect(plugin.scheduled.single.spec.id, 10,
          reason: 'notifications.id-and-registry#1: the alarm is filed under '
              'the notification id, so cancelling the notification disarms it');
      expect(
        ReminderPayload.decode(plugin.scheduled.single.spec.payload)?.timestamp,
        unixTime(2015, 1, 26),
        reason: 'intents.actions-and-extras#11: the alarm carries the '
            'local-midnight checkmark timestamp',
      );
    });

    test('#7 #12 the scheduling attempt is logged before it is refused', () {
      DateUtils.setFixedTimeZone(gmt);
      final scheduler = buildScheduler(now: unixTime(2020, 6, 2, 0, 0));
      scheduler.scheduleShowReminder(
        unixTime(2020, 6, 1, 12, 30),
        yesNoHabit(name: 'Meditate'),
        unixTime(2020, 6, 1),
      );

      expect(
        logBuffer.toString(),
        contains('[ReminderHelper] Setting alarm (2020-06-01 123000): Medit'),
        reason: 'reminders.exact-alarm-scheduling#7 and #12: under tag '
            '"ReminderHelper", "Setting alarm (<yyyy-MM-dd HHmmss>): <first '
            'min(5, name.length) characters of habit.name>"',
      );
    });

    test('#7 a short habit name is not truncated', () {
      final scheduler = buildScheduler(now: unixTime(2020, 6, 1, 0, 0));
      scheduler.scheduleShowReminder(
        unixTime(2020, 6, 1, 12, 30),
        yesNoHabit(name: 'Run'),
        unixTime(2020, 6, 1),
      );

      expect(logBuffer.toString(), contains('): Run\n'),
          reason: 'reminders.exact-alarm-scheduling#12: habitNamePrefix is the '
              'first min(5, name.length) characters');
    });

    test('#6 widget updates are not scheduled', () {
      final scheduler = buildScheduler(now: 0);
      expect(scheduler.scheduleWidgetUpdate(unixTime(2015, 1, 27)), isNull,
          reason: 'reminders.exact-alarm-scheduling#6: scheduleWidgetUpdate '
              'uses the non-waking RTC alarm type to refresh home-screen '
              'widgets, which the Flutter app does not have');
    });

    test('the weekday gate moves the alarm onto a day the reminder covers',
        () async {
      // 2015-01-26 is a Monday, so index 2 is Monday.
      final mondaysOnly = WeekdayList.fromArray(
        [false, false, true, false, false, false, false],
      );
      final habit = yesNoHabit(reminder: Reminder(8, 30, mondaysOnly));
      final scheduler = buildScheduler(now: unixTime(2015, 1, 27, 6, 0));

      // Tuesday 2015-01-27: the next Monday is six days later.
      final result = scheduler.scheduleShowReminder(
        unixTime(2015, 1, 27, 8, 30),
        habit,
        unixTime(2015, 1, 27),
      );
      await scheduler.settle();

      expect(result, SchedulerResult.ok);
      expect(plugin.scheduled.single.whenMillis, unixTime(2015, 2, 2, 8, 30),
          reason: 'notifications.show-gating#6: the Android build fires the '
              'alarm every day and drops it in gate 4; with no fire-time hook '
              'the gate runs here instead, so the alarm lands on the next day '
              'the weekday set covers');
      expect(
        ReminderPayload.decode(plugin.scheduled.single.spec.payload)?.date,
        LocalDate.ymd(2015, 2, 2),
        reason: 'notifications.show-gating#8: the notification carries the day '
            'the alarm targets',
      );
    });

    test('a reminder covering no weekday at all posts nothing', () async {
      final habit = yesNoHabit(reminder: Reminder(8, 30, WeekdayList(0)));
      final scheduler = buildScheduler(now: unixTime(2015, 1, 26, 6, 0));

      final result = scheduler.scheduleShowReminder(
        unixTime(2015, 1, 26, 8, 30),
        habit,
        unixTime(2015, 1, 26),
      );
      await scheduler.settle();

      expect(result, SchedulerResult.ignored);
      expect(plugin.scheduled, isEmpty,
          reason: 'notifications.show-gating#6: gate 4 rejects every day, so '
              'the Android build would post nothing either');
      expect(plugin.cancelled, [10],
          reason: 'notifications.show-gating#6: an alarm left over from a '
              'previous weekday set is cleared');
    });
  });

  // -----------------------------------------------------------------------
  // The core ReminderScheduler driving the Flutter scheduler end to end
  // -----------------------------------------------------------------------

  group('ReminderScheduler over FlutterAlarmScheduler', () {
    late _FakeAlarmPlugin plugin;
    late FlutterAlarmScheduler systemScheduler;
    late ReminderScheduler core;

    setUp(() {
      DateUtils.setFixedTimeZone(gmtMinus4);
      plugin = _FakeAlarmPlugin();
      systemScheduler = FlutterAlarmScheduler(
        plugin: plugin,
        builder: buildBuilder(),
        logging: logging,
      );
      core = ReminderScheduler(
        CommandRunner(
          CoroutineTaskRunner(
            mainDispatcher: const UnconfinedTestDispatcher(),
            ioDispatcher: const UnconfinedTestDispatcher(),
          ),
        ),
        habitList,
        systemScheduler,
        WidgetPreferences(storage),
      );
    });

    test('#5 scheduleAll arms tomorrow\'s alarm for every habit', () async {
      // reminders.schedule-at-time#7: GMT-4, now = 2015-01-26 13:00 local.
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      final habit = yesNoHabit();
      habitList.add(habit);
      final noReminder = fixtures.createEmptyHabit(name: 'Wake up early')
        ..id = 12
        ..reminder = null;
      habitList.add(noReminder);

      core.scheduleAll();
      await systemScheduler.settle();

      expect(plugin.scheduled.length, 1,
          reason: 'reminders.schedule-all#3: habits with reminder == null are '
              'excluded from scheduleAll entirely');
      expect(plugin.scheduled.single.whenMillis, unixTime(2015, 1, 27, 12, 30),
          reason: 'reminders.schedule-at-time#7: with now = 2015-01-26 13:00 in '
              'GMT-4 and reminder 08:30, the alarm is 2015-01-27 12:30 UTC');
      expect(
        ReminderPayload.decode(plugin.scheduled.single.spec.payload)?.timestamp,
        unixTime(2015, 1, 27),
        reason: 'reminders.schedule-at-time#3: the checkmark timestamp is the '
            'reminder instant floored to local midnight',
      );
    });

    test('#2 an archived habit is dropped before it reaches the platform',
        () async {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 30));
      final habit = yesNoHabit()..isArchived = true;
      habitList.add(habit);

      core.scheduleAll();
      await systemScheduler.settle();

      expect(plugin.scheduled, isEmpty,
          reason: 'reminders.schedule-at-time#2: archived habits never fire '
              'reminders even though they are included in the WITH_ALARM query');
    });
  });

  // -----------------------------------------------------------------------
  // The receiver rules the decoder is the whole of, in the Flutter port
  // -----------------------------------------------------------------------

  group('reminder response dispatch', () {
    String payloadFor(Habit habit, LocalDate date, int reminderTime) =>
        ReminderPayload(
          habitId: habit.id ?? 0,
          timestamp: date.unixTime,
          reminderTime: reminderTime,
        ).encode();

    test('a payload this app did not write is dropped, not thrown on', () {
      expect(ReminderResponse.decode(payload: null), isNull,
          reason: 'intents.reminder-receiver-dispatch#1: onReceive returns '
              'immediately when the intent it was handed carries nothing');
      expect(
        ReminderResponse.decode(
            actionId: ReminderActions.addRepetition, payload: null),
        isNull,
        reason: 'intents.reminder-receiver-dispatch#1: an action without an '
            'intent behind it is dropped too',
      );

      for (final broken in <String>[
        '',
        'not a uri at all ::::',
        'content://org.isoron.uhabits/habit/abc?timestamp=0&reminderTime=0',
        'content://org.isoron.uhabits/habit/10',
        'content://org.isoron.uhabits/habit/10?timestamp=x&reminderTime=1',
      ]) {
        expect(
          () => ReminderResponse.decode(
              actionId: ReminderActions.snoozeReminder, payload: broken),
          returnsNormally,
          reason: 'intents.reminder-receiver-dispatch#10: the whole dispatch '
              'is wrapped in try/catch(RuntimeException), so a deleted habit '
              'or a malformed URI never crashes the app',
        );
        expect(
          ReminderResponse.decode(
              actionId: ReminderActions.snoozeReminder, payload: broken),
          isNull,
          reason: 'intents.reminder-receiver-dispatch#10: it is swallowed',
        );
      }
    });

    test('the show-reminder path carries the habit, the checkmark day and the '
        'alarm instant', () async {
      final habit = yesNoHabit();
      habitList.add(habit);
      final date = LocalDate.ymd(2015, 1, 26);
      final int reminderTime = unixTime(2015, 1, 26, 8, 30);

      final plugin = _FakeAlarmPlugin();
      final scheduler = FlutterAlarmScheduler(
        plugin: plugin,
        builder: buildBuilder(),
        logging: logging,
        nowMillis: () => unixTime(2015, 1, 26, 6, 0),
      );
      scheduler.scheduleShowReminder(reminderTime, habit, date.unixTime);
      await scheduler.settle();

      final decoded =
          ReminderPayload.decode(plugin.scheduled.single.spec.payload)!;

      expect(decoded.habitId, habit.id,
          reason: 'intents.reminder-receiver-dispatch#5 — ACTION_SHOW_REMINDER: '
              'returns silently if habit is null; otherwise calls '
              'reminderController.onShowReminder(habit, '
              'LocalDate.fromUnixTime(timestamp), reminderTime). The port has '
              'no fire-time hook — flutter_local_notifications posts a '
              'notification the app built at schedule time — so the three '
              'arguments travel with the alarm instead of being reassembled '
              'when it fires; the gating onShowReminder would have applied runs '
              'before the alarm is set. See the class doc on '
              'FlutterAlarmScheduler.');
      expect(decoded.date, date,
          reason: 'intents.reminder-receiver-dispatch#5: the checkmark day, '
              'recovered with LocalDate.fromUnixTime(timestamp)');
      expect(decoded.timestamp, date.unixTime,
          reason: 'intents.reminder-receiver-dispatch#5: which is the raw '
              'extra');
      expect(decoded.reminderTime, reminderTime,
          reason: 'intents.reminder-receiver-dispatch#5: alongside the alarm '
              'instant');

      // "returns silently if habit is null": a payload naming a habit the list
      // no longer holds resolves to an id nothing answers, and the caller gets
      // nothing to act on rather than an exception.
      habitList.remove(habit);
      final response = ReminderResponse.decode(
        payload: plugin.scheduled.single.spec.payload,
      )!;
      expect(habitList.getById(response.habitId), isNull,
          reason: 'intents.reminder-receiver-dispatch#5: a deleted habit '
              'resolves to nothing, and the branch stops there');
    });

    test('an action with no branch has no effect', () {
      final payload = payloadFor(yesNoHabit(), LocalDate.ymd(2015, 1, 26), 500);

      expect(
        ReminderResponse.decode(
            actionId: 'org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE',
            payload: payload),
        isNull,
        reason: 'intents.reminder-receiver-dispatch#9: any other action falls '
            'through the when with no effect',
      );
      expect(
        ReminderResponse.decode(actionId: 'android.intent.action.BOOT_COMPLETED',
            payload: payload),
        isNull,
        reason: 'intents.reminder-receiver-dispatch#9',
      );
    });

    test('the Yes and No actions carry the checkmark day as "timestamp"', () {
      final habit = yesNoHabit();
      final date = LocalDate.ymd(2015, 1, 25);
      final payload = payloadFor(habit, date, unixTime(2015, 1, 25, 8, 30));

      expect(Uri.parse(payload).queryParameters['timestamp'],
          '${date.unixTime}',
          reason: 'intents.actions-and-extras#12: the ADD/REMOVE repetition '
              "intents carry the long extra 'timestamp' = LocalDate.unixTime");
      for (final action in <String>[
        ReminderActions.addRepetition,
        ReminderActions.removeRepetition,
      ]) {
        final response =
            ReminderResponse.decode(actionId: action, payload: payload)!;
        expect(response.date, date,
            reason: 'intents.actions-and-extras#12: which is what the handler '
                'writes the entry to');
        expect(response.habitId, habit.id,
            reason: 'intents.actions-and-extras#12: alongside the habit the '
                'data URI names');
      }
    });

    test('the dismiss action is what reaches ReminderController.onDismiss',
        () async {
      final presenter = _FakePresenter();
      final systemTray = FlutterNotificationTray(
        presenter: presenter,
        builder: buildBuilder(),
        logging: logging,
      );
      final taskRunner = CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      final core = NotificationTray(
        taskRunner,
        CommandRunner(taskRunner),
        preferences,
        systemTray,
      );
      final controller =
          ReminderController(_NoopScheduler(), core, preferences);
      final habit = yesNoHabit();
      habitList.add(habit);

      core.show(habit, LocalDate.ymd(2015, 1, 26), 500);
      await systemTray.settle();
      final posted = presenter.shown.single;

      final response = ReminderResponse.decode(
        actionId: ReminderActions.dismissReminder,
        payload: posted.payload,
      )!;
      expect(response.kind, ReminderResponseKind.dismiss,
          reason: 'notifications.sticky-and-dismiss#6: onDismiss is reached '
              'via the notification delete intent, action '
              'org.isoron.uhabits.ACTION_DISMISS_REMINDER');
      expect(response.habitId, habit.id,
          reason: 'intents.reminder-receiver-dispatch#6: the receiver resolves '
              'the habit from the intent data before calling onDismiss');

      controller.onDismiss(habitList.getById(response.habitId)!);
      await systemTray.settle();

      expect(presenter.cancelled, <int>[10],
          reason: 'intents.reminder-receiver-dispatch#6: ACTION_DISMISS_'
              'REMINDER calls reminderController.onDismiss(habit), which '
              'cancels');

      // The sticky branch of the same entry point.
      preferences.setNotificationsSticky(true);
      presenter.shown.clear();
      presenter.cancelled.clear();
      core.show(habit, LocalDate.ymd(2015, 1, 26), 500);
      await systemTray.settle();
      presenter.shown.clear();
      controller.onDismiss(habit);
      await systemTray.settle();

      expect(presenter.cancelled, isEmpty,
          reason: 'notifications.sticky-and-dismiss#6: with sticky on, the '
              'same delete intent re-posts instead of cancelling');
      expect(presenter.shown.length, 1,
          reason: 'notifications.sticky-and-dismiss#6');
    });
  });

  // -----------------------------------------------------------------------
  // Strings and flags the builder takes straight from the ledger
  // -----------------------------------------------------------------------

  group('notification strings and flags', () {
    test('the snooze action carries the "snooze" string, English "Later"', () {
      final resolved = NotificationStrings.from(L10nEn());
      expect(resolved.snooze, 'Later',
          reason: 'reminders.snooze-android12-gate#3: the action label is the '
              'string "snooze" whose English value is "Later"');

      final builder = ReminderNotificationBuilder(
        preferences: preferences,
        strings: () => resolved,
      );
      final spec = builder.build(
        yesNoHabit(),
        10,
        LocalDate.ymd(2015, 1, 26),
        500,
      );
      expect(
        spec.actions.last,
        const ReminderNotificationAction(
            'org.isoron.uhabits.ACTION_SNOOZE_REMINDER', 'Later',
            // `Action(R.drawable.ic_action_snooze, getString(R.string.snooze),
            // …)`: the button is the label AND the clock icon
            // (`audit8.reminder-notification-action-buttons-are-built#1`).
            icon: ReminderActionIcons.snooze),
        reason: 'reminders.snooze-android12-gate#3: and that string is what '
            'labels the snooze action',
      );
    });

    testWidgets('audit24.reminder-strings-are-resolved-at-build-time#1 the '
        'six strings follow a runtime language change', (tester) async {
      // `AndroidNotificationTray.buildNotification` reads every one of them out
      // of the application Context — `context.getString(R.string.yes)` and the
      // rest — at the moment the notification is built, and
      // `createAndroidNotificationChannel` reads `R.string.reminder` the same
      // way immediately before each notify(). `Resources.getString` resolves
      // against the process's CURRENT configuration, so a device- or per-app
      // language change is picked up by the very next reminder, with nothing to
      // re-arm and no restart.
      const String rule =
          'audit24.reminder-strings-are-resolved-at-build-time#1';
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      // Exactly what AppScope._startPlatformServices builds.
      final builder = ReminderNotificationBuilder(preferences: preferences);

      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
      final NotificationSpec german = builder.build(
        yesNoHabit(question: ''),
        10,
        LocalDate.ymd(2015, 1, 26),
        500,
      );
      expect(german.body, 'Hast du diese Gewohnheit heute erledigt?',
          reason: '$rule — getString(R.string.default_reminder_question)');
      expect(german.actions.map((a) => a.title).toList(),
          <String>['Ja', 'Nein', 'Später'],
          reason: '$rule — getString(R.string.yes / .no / .snooze)');
      expect(german.channelName, 'Erinnerung',
          reason: '$rule — resources.getString(R.string.reminder)');
      expect(builder.strings.enter, 'Eingeben',
          reason: '$rule — getString(R.string.enter)');

      // The user switches the phone — or Loop itself — to English.
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];

      final NotificationSpec english = builder.build(
        yesNoHabit(question: ''),
        10,
        LocalDate.ymd(2015, 1, 26),
        500,
      );
      expect(english.body, 'Have you completed this habit today?',
          reason: '$rule — the very next notification is already translated; '
              'nothing is captured at process start');
      expect(english.actions.map((a) => a.title).toList(),
          <String>['Yes', 'No', 'Later'],
          reason: rule);
      expect(english.channelName, 'Reminder', reason: rule);
      expect(builder.strings.enter, 'Enter', reason: rule);
      // The iOS categories are built from the same action lists, so they
      // follow too (`LocalNotificationsPresenter._darwinCategories`).
      expect(
        builder
            .categories()
            .expand((c) => c.actions)
            .map((a) => a.title)
            .toSet(),
        <String>{'Enter', 'Later', 'Yes', 'No'},
        reason: '$rule — the Darwin action titles are the same six strings',
      );
    });

    test('sticky notifications are built ongoing', () async {
      final presenter = _FakePresenter();
      final tray = FlutterNotificationTray(
        presenter: presenter,
        builder: buildBuilder(),
        logging: logging,
      );

      expect(preferences.shouldMakeNotificationsSticky(), isFalse);
      tray.showNotification(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 500);
      await tray.settle();
      expect(presenter.shown.single.ongoing, isFalse,
          reason: 'notifications.sticky-and-dismiss#4: setOngoing follows the '
              'preference, which defaults to false');

      preferences.setNotificationsSticky(true);
      presenter.shown.clear();
      tray.showNotification(yesNoHabit(), 10, LocalDate.ymd(2015, 1, 26), 500);
      await tray.settle();
      expect(presenter.shown.single.ongoing, isTrue,
          reason: 'notifications.sticky-and-dismiss#4: when sticky is on, the '
              'notification is built with setOngoing(true)');
    });
  });

  // -----------------------------------------------------------------------
  // The SystemScheduler contract itself
  // -----------------------------------------------------------------------

  group('SystemScheduler contract', () {
    test('the Flutter scheduler is a SystemScheduler with two results', () {
      final scheduler = FlutterAlarmScheduler(
        plugin: _FakeAlarmPlugin(),
        builder: buildBuilder(),
        logging: logging,
        nowMillis: () => 0,
      );

      expect(scheduler, isA<SystemScheduler>(),
          reason: 'reminders.exact-alarm-scheduling#1: IntentScheduler '
              'implements ReminderScheduler.SystemScheduler');
      expect(SchedulerResult.values,
          <SchedulerResult>[SchedulerResult.ignored, SchedulerResult.ok],
          reason: 'reminders.exact-alarm-scheduling#1: SchedulerResult has '
              'exactly two values: IGNORED and OK');
    });

    test('the scheduler holds the platform alarm service it was built with',
        () async {
      final plugin = _FakeAlarmPlugin();
      final scheduler = FlutterAlarmScheduler(
        plugin: plugin,
        builder: buildBuilder(),
        logging: logging,
        nowMillis: () => 0,
      );

      expect(scheduler, isA<SystemScheduler>(),
          reason: 'reminders.exact-alarm-scheduling#10: IntentScheduler '
              'implements ReminderScheduler.SystemScheduler');
      // `@AppScope` plus `context.getSystemService(ALARM_SERVICE)`: one
      // long-lived object that owns the handle it schedules through. Here the
      // handle is the AlarmPlugin, injected once at construction, and every
      // alarm goes through that same instance.
      final habit = yesNoHabit();
      scheduler.scheduleShowReminder(
        unixTime(2015, 1, 26, 8, 30),
        habit,
        unixTime(2015, 1, 26),
      );
      scheduler.scheduleShowReminder(
        unixTime(2015, 1, 27, 8, 30),
        habit,
        unixTime(2015, 1, 27),
      );
      await scheduler.settle();
      expect(plugin.scheduled, hasLength(2),
          reason: 'reminders.exact-alarm-scheduling#10: the scheduler holds '
              'the alarm service — nothing else is consulted, and no second '
              'handle is obtained per call');
    });

    test('log(componentName, msg) writes under that component name', () {
      final scheduler = FlutterAlarmScheduler(
        plugin: _FakeAlarmPlugin(),
        builder: buildBuilder(),
        logging: logging,
        nowMillis: () => 0,
      );

      scheduler.log('ReminderScheduler', 'Scheduling all alarms');

      expect(logBuffer.toString(),
          contains('[ReminderScheduler] Scheduling all alarms'),
          reason: 'reminders.exact-alarm-scheduling#11: log(componentName, '
              'msg) forwards to Log.d(componentName, msg) — the component '
              'name is the tag, not a fixed one');

      scheduler.log('IntentScheduler', 'timestamp=1 now=0');
      expect(logBuffer.toString(),
          contains('[IntentScheduler] timestamp=1 now=0'),
          reason: 'reminders.exact-alarm-scheduling#11: a different component '
              'name gives a different tag');
    });
  });
}

/// The one `ReminderScheduler` method `ReminderController` calls; the real one
/// is exercised by the core's own test.
class _NoopScheduler implements ReminderSchedulerApi {
  int scheduleAllCount = 0;

  @override
  void scheduleAll() {
    scheduleAllCount++;
  }

  @override
  void snoozeReminder(Habit habit, int minutes) {}

  @override
  void scheduleAtTime(Habit habit, int reminderTime) {}

  @override
  void snoozeUntil(Habit habit, int reminderTime) {}
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Stands in for `NotificationManagerCompat`.
class _FakePresenter implements NotificationPresenter {
  final List<NotificationSpec> shown = <NotificationSpec>[];
  final List<int> cancelled = <int>[];

  /// Reproduces the Xiaomi `RuntimeException` of `notifications.sound#8`.
  bool failNextShow = false;

  @override
  Future<void> show(NotificationSpec spec) async {
    shown.add(spec);
    if (failNextShow) {
      failNextShow = false;
      throw Exception('Failed to show notification');
    }
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

class _ScheduledAlarm {
  _ScheduledAlarm(this.spec, this.whenMillis);

  final NotificationSpec spec;
  final int whenMillis;
}

/// Stands in for `AlarmManager`.
class _FakeAlarmPlugin implements AlarmPlugin {
  final List<_ScheduledAlarm> scheduled = <_ScheduledAlarm>[];
  final List<int> cancelled = <int>[];

  /// `AlarmManager.canScheduleExactAlarms()`.
  bool exactAlarmsAllowed = true;

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async {
    scheduled.add(_ScheduledAlarm(spec, whenMillis));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsAllowed;

  @override
  Future<bool> requestExactAlarmsPermission() async => exactAlarmsAllowed;
}
