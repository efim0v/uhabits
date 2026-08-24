/// The intent plumbing: what a widget tap, a notification button and a deep
/// link actually reach.
///
/// Three Android components are under test here, all of them ported into
/// `lib/state/intent_router.dart` and wired up by `lib/state/widget_link.dart`:
///
///  * `receivers/WidgetReceiver.kt` — [WidgetIntentReceiver];
///  * `receivers/ReminderReceiver.kt` — [ReminderIntentReceiver];
///  * `ListHabitsActivity.parseIntents()` — already `HabitListModel`'s, driven
///    from the end of this file through the whole deep-link path.
///
/// The receivers are exercised as objects rather than through the platform,
/// which is the only way they can be: a `BroadcastReceiver` runs in the
/// launcher's process and a `flutter test` has no platform at all. What that
/// costs is the delivery — whether Android really routes the broadcast — and
/// what it buys is every branch, every default and every swallowed failure.
library;

// The core's models, presenters and logging are reached by their `src` path,
// exactly as lib/state does.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart' hide DateUtils, Intent;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/home_widget_bridge.dart' show WidgetRegistry;
import 'package:uhabits/platform/flutter_notification_tray.dart'
    show ReminderActions;
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart' show HabitListModel;
import 'package:uhabits/state/intent_router.dart';
import 'package:uhabits/state/widget_link.dart';
import 'package:uhabits/state/widget_sync.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

void main() {
  // -----------------------------------------------------------------------
  // Fixtures for the two receivers
  // -----------------------------------------------------------------------

  const TimeZone gmt = FixedTimeZone(0);
  final int Function() realClock = systemCurrentTimeMillis;
  final TimeZone Function() realZone = getDefaultTimeZone;

  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late Preferences preferences;
  late RecordingCommandRunner commandRunner;
  late RecordingNotificationTray tray;
  late WidgetBehavior behavior;
  late StringBuffer logOut;
  late StringBuffer logErr;
  late Logging logging;
  late List<String> updaterCalls;
  late LocalDate today;

  setUp(() {
    DateUtils.setFixedTimeZone(gmt);
    DateUtils.setFixedLocalTime(null);
    getDefaultTimeZone = () => gmt;
    setToday(LocalDate.ymd(2015, 1, 26));
    today = getToday();
    modelFactory = MemoryModelFactory();
    habitList = MemoryHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    preferences = Preferences(MemoryStorage());
    final TaskRunner taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = RecordingCommandRunner(taskRunner);
    tray = RecordingNotificationTray(taskRunner, commandRunner, preferences);
    behavior = WidgetBehavior(
      habitList: habitList,
      commandRunner: commandRunner,
      notificationTray: tray,
      preferences: preferences,
    );
    logOut = StringBuffer();
    logErr = StringBuffer();
    logging = StandardLogging(out: logOut, err: logErr);
    updaterCalls = <String>[];
    WidgetIntentReceiver.clearLastReceivedIntent();
    ReminderIntentReceiver.clearLastReceivedIntent();
  });

  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    systemCurrentTimeMillis = realClock;
    getDefaultTimeZone = realZone;
    WidgetIntentReceiver.clearLastReceivedIntent();
    ReminderIntentReceiver.clearLastReceivedIntent();
  });

  Habit addHabit({
    String name = 'Meditate',
    HabitType type = HabitType.yesNo,
  }) {
    final Habit habit = type == HabitType.yesNo
        ? fixtures.createEmptyHabit(name: name)
        : fixtures.createNumericalHabit();
    if (!habitList.toList().contains(habit)) habitList.add(habit);
    return habit;
  }

  WidgetIntentReceiver buildWidgetReceiver() => WidgetIntentReceiver(
        parser: IntentParser(habitList),
        controller: behavior,
        preferences: preferences,
        updateWidgets: () async => updaterCalls.add('updateWidgets'),
        scheduleStartDayWidgetUpdate: () =>
            updaterCalls.add('scheduleStartDayWidgetUpdate'),
        logging: logging,
      );

  int lastValue() =>
      (commandRunner.commands.last as CreateRepetitionCommand).value;

  // =======================================================================
  // intents.actions-and-extras — the constants the receivers switch on
  // =======================================================================

  group('intents.actions-and-extras', () {
    test('#6/#7 the two WidgetReceiver constants that had no home', () {
      expect(
        WidgetActions.toggleRepetition,
        'org.isoron.uhabits.ACTION_TOGGLE_REPETITION',
        reason: 'intents.actions-and-extras#6 — '
            'WidgetReceiver.ACTION_TOGGLE_REPETITION = '
            '"org.isoron.uhabits.ACTION_TOGGLE_REPETITION". It is the action a '
            'boolean Checkmark widget broadcasts, and a home screen placed '
            'before this port still holds PendingIntents addressed with it.',
      );
      expect(
        WidgetActions.updateWidgetsValue,
        'org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE',
        reason: 'intents.actions-and-extras#7 — '
            'WidgetReceiver.ACTION_UPDATE_WIDGETS_VALUE = '
            '"org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE", the day-rollover '
            'alarm.',
      );
    });

    test('#8 WidgetReceiver\'s copy of ACTION_DISMISS_REMINDER really is the '
        "same string as ReminderReceiver's", () {
      expect(WidgetActions.dismissReminder,
          ReminderIntentActions.dismissReminder,
          reason: 'intents.actions-and-extras#8 — WidgetReceiver also declares '
              'its own constant ACTION_DISMISS_REMINDER with the identical '
              'string; PendingIntentFactory.dismissNotification actually '
              'targets ReminderReceiver but uses WidgetReceiver\'s copy — the '
              'strings are equal so behaviour is unaffected.');
      expect(WidgetActions.dismissReminder, ReminderActions.dismissReminder,
          reason: 'intents.actions-and-extras#8: and the notification layer '
              'answers with the same identifier');
    });

    test('#4/#5 the Yes and No actions are the ones the notification uses', () {
      expect(WidgetActions.addRepetition, ReminderActions.addRepetition,
          reason: 'intents.actions-and-extras#4 — '
              'WidgetReceiver.ACTION_ADD_REPETITION = '
              '"org.isoron.uhabits.ACTION_ADD_REPETITION"');
      expect(WidgetActions.removeRepetition, ReminderActions.removeRepetition,
          reason: 'intents.actions-and-extras#5 — '
              'WidgetReceiver.ACTION_REMOVE_REPETITION = '
              '"org.isoron.uhabits.ACTION_REMOVE_REPETITION"');
    });

    test('#13 ACTION_EDIT carries "habit" and "timestamp", never "habitId"',
        () {
      final Habit habit = addHabit(type: HabitType.numerical);
      final LocalDate date = today.minus(2);
      final Intent? intent = widgetLinkIntent(
        WidgetLink(
          action: WidgetLink.actionEdit,
          widgetId: 7,
          habitId: habit.id,
          date: '${date.year}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}',
        ),
        today: today,
      );

      expect(intent!.action, actionEdit,
          reason: 'platform-glue.deep-link-edit-entry#1 — '
              'ListHabitsActivity.ACTION_EDIT is the literal string '
              '"org.isoron.uhabits.ACTION_EDIT".');
      expect(intent.extras.keys.toSet(), <String>{'habit', 'timestamp'},
          reason: 'intents.actions-and-extras#13 — ACTION_EDIT carries long '
              'extras "habit" (habit id) and "timestamp" (LocalDate.unixTime) '
              '— note the key is "habit", not "habitId".');
      expect(intent.getLongExtra('habit', -1), habit.id,
          reason: 'intents.actions-and-extras#13');
      expect(intent.getLongExtra('timestamp', -1), date.unixTime,
          reason: 'intents.actions-and-extras#13: LocalDate.unixTime');
    });
  });

  // =======================================================================
  // intents.widget-receiver-dispatch
  // =======================================================================

  group('intents.widget-receiver-dispatch', () {
    test('#1/#11 the received intent is parked in a static field until '
        'clearLastReceivedIntent()', () {
      final Habit habit = addHabit();
      final WidgetIntentReceiver receiver = buildWidgetReceiver();

      expect(WidgetIntentReceiver.lastReceivedIntent, isNull,
          reason: 'intents.widget-receiver-dispatch#11 — The receiver stores '
              'the last received Intent in a static field '
              '(WidgetReceiver.lastReceivedIntent) used by instrumentation '
              'tests, with clearLastReceivedIntent() to reset it.');

      final Intent first = Intent(
        action: WidgetActions.addRepetition,
        data: habitUri(habit.id!),
      );
      receiver.onReceive(first);
      expect(WidgetIntentReceiver.lastReceivedIntent, same(first),
          reason: 'intents.widget-receiver-dispatch#1 — WidgetReceiver stores '
              'the received intent in the static '
              'WidgetReceiver.lastReceivedIntent, cleared only by '
              'clearLastReceivedIntent().');

      // A broadcast that fails still counts as received: the field is written
      // before the try block, exactly as upstream.
      final Intent broken = Intent(action: WidgetActions.addRepetition);
      receiver.onReceive(broken);
      expect(WidgetIntentReceiver.lastReceivedIntent, same(broken),
          reason: 'intents.widget-receiver-dispatch#1: the newest receipt '
              'replaces the previous one, even when the dispatch throws');

      WidgetIntentReceiver.clearLastReceivedIntent();
      expect(WidgetIntentReceiver.lastReceivedIntent, isNull,
          reason: 'intents.widget-receiver-dispatch#11: and only '
              'clearLastReceivedIntent() nulls it');
    });

    test('#2 the update-widgets action is compared by reference, so an equal '
        'copy is sent through the parser instead', () {
      final WidgetIntentReceiver receiver = buildWidgetReceiver();
      const String rule =
          'intents.widget-receiver-dispatch#2 — For every action except '
          'ACTION_UPDATE_WIDGETS_VALUE it first parses the intent through '
          'IntentParser.parseCheckmarkIntent; the comparison used is '
          'referential (intent.action !== ACTION_UPDATE_WIDGETS_VALUE). Dart '
          'spells that `identical`, and the port keeps it rather than '
          'correcting it, because the difference is observable.';

      // The constant itself: no parse, so the missing data uri is harmless and
      // the rollover runs.
      receiver.onReceive(Intent(action: WidgetActions.updateWidgetsValue));
      expect(updaterCalls,
          <String>['updateWidgets', 'scheduleStartDayWidgetUpdate'],
          reason: rule);

      // An equal but distinct string — what a Parcel round trip can produce.
      // `parseCheckmarkIntent` runs, throws on the null data uri, and the
      // rollover silently does not happen.
      updaterCalls.clear();
      final String copy = String.fromCharCodes(
        WidgetActions.updateWidgetsValue.codeUnits,
      );
      expect(copy, WidgetActions.updateWidgetsValue, reason: rule);
      expect(identical(copy, WidgetActions.updateWidgetsValue), isFalse,
          reason: '$rule The copy is equal and not identical.');

      receiver.onReceive(Intent(action: copy));
      expect(updaterCalls, isEmpty,
          reason: '$rule The parser ran first and threw, so the rollover was '
              'skipped — upstream behaviour, reproduced rather than fixed.');
    });

    test('#7 a stale or malformed intent is logged and swallowed', () {
      final Habit habit = addHabit();
      final WidgetIntentReceiver receiver = buildWidgetReceiver();
      const String rule =
          'intents.widget-receiver-dispatch#7 — The whole dispatch is wrapped '
          'in try/catch(RuntimeException) logging "could not process intent", '
          'so an invalid or stale intent never crashes.';

      // No data uri at all: `parseCheckmarkIntent` throws "uri is null".
      receiver.onReceive(Intent(action: WidgetActions.toggleRepetition));
      expect(commandRunner.commands, isEmpty, reason: rule);

      // A habit that was deleted after the widget last drew itself.
      receiver.onReceive(Intent(
        action: WidgetActions.toggleRepetition,
        data: habitUri(habit.id! + 4242),
      ));
      expect(commandRunner.commands, isEmpty, reason: rule);

      // Tomorrow: rejected by `IntentParser` as "timestamp is not valid".
      receiver.onReceive(Intent(
        action: WidgetActions.toggleRepetition,
        data: habitUri(habit.id!),
        extras: <String, Object?>{'timestamp': today.plus(1).unixTime},
      ));
      expect(commandRunner.commands, isEmpty, reason: rule);

      expect('$logOut'.split('could not process intent').length - 1, 3,
          reason: '$rule Each failure is logged once.');

      // And the receiver still works afterwards.
      receiver.onReceive(Intent(
        action: WidgetActions.toggleRepetition,
        data: habitUri(habit.id!),
      ));
      expect(commandRunner.commands, hasLength(1), reason: rule);
    });

    test('#8 exactly four actions have a branch, all namespaced '
        'org.isoron.uhabits.', () {
      expect(
        WidgetActions.dispatched,
        <String>[
          'org.isoron.uhabits.ACTION_ADD_REPETITION',
          'org.isoron.uhabits.ACTION_TOGGLE_REPETITION',
          'org.isoron.uhabits.ACTION_REMOVE_REPETITION',
          'org.isoron.uhabits.ACTION_UPDATE_WIDGETS_VALUE',
        ],
        reason: 'intents.widget-receiver-dispatch#8 — WidgetReceiver handles '
            "four actions, all namespaced 'org.isoron.uhabits.': "
            'ACTION_ADD_REPETITION, ACTION_REMOVE_REPETITION, '
            'ACTION_TOGGLE_REPETITION and ACTION_UPDATE_WIDGETS_VALUE '
            '(ACTION_DISMISS_REMINDER is defined here too but consumed by '
            'ReminderReceiver).',
      );
      expect(
        WidgetActions.dispatched.contains(WidgetActions.dismissReminder),
        isFalse,
        reason: 'intents.widget-receiver-dispatch#8: and dismissal is not one '
            'of them',
      );
    });

    test('#13 every receipt is logged at INFO, action and data included', () {
      final Habit habit = addHabit();
      final WidgetIntentReceiver receiver = buildWidgetReceiver();
      const String rule = 'intents.widget-receiver-dispatch#13 — Every receipt '
          'logs at INFO: String.format("Received intent: %s", '
          'intent.toString()). The core Intent has no Android toString, so '
          '`describeIntent` renders the same three fields Android renders.';

      receiver.onReceive(Intent(
        action: WidgetActions.toggleRepetition,
        data: habitUri(habit.id!),
      ));

      expect('$logOut', contains('[WidgetReceiver] Received intent:'),
          reason: rule);
      expect('$logOut', contains('act=${WidgetActions.toggleRepetition}'),
          reason: '$rule The action is in the line.');
      expect('$logOut', contains('dat=content://org.isoron.uhabits/habit/'
          '${habit.id}'), reason: '$rule And so is the habit uri.');

      // Even an action with no branch is logged: the statement is the first
      // one in `onReceive`, before the `when`.
      logOut.clear();
      receiver.onReceive(Intent(
        action: WidgetActions.setNumericalValue,
        data: habitUri(habit.id!),
      ));
      expect('$logOut', contains('Received intent:'), reason: rule);
    });

    test('#14 ACTION_DISMISS_REMINDER does nothing here and everything on the '
        'reminder receiver', () {
      final Habit habit = addHabit();
      final WidgetIntentReceiver widgetReceiver = buildWidgetReceiver();
      const String rule = 'intents.widget-receiver-dispatch#14 — '
          'ACTION_DISMISS_REMINDER is declared on WidgetReceiver but has no '
          'branch in its when-block; dismissal is actually routed to '
          'ReminderReceiver.';

      widgetReceiver.onReceive(Intent(
        action: WidgetActions.dismissReminder,
        data: habitUri(habit.id!),
      ));
      expect(commandRunner.commands, isEmpty, reason: rule);
      expect(tray.log, isEmpty,
          reason: '$rule Not even the notification is touched.');

      final RecordingScheduler scheduler = RecordingScheduler();
      ReminderIntentReceiver(
        habits: habitList,
        controller: ReminderController(scheduler, tray, preferences),
        logging: logging,
      ).onReceive(Intent(
        action: ReminderIntentActions.dismissReminder,
        data: habitUri(habit.id!),
      ));
      expect(tray.log, <String>['cancel'],
          reason: '$rule The very same string, delivered to the other '
              'receiver, cancels.');
    });

    test('#3/#4/#5 the three entry-writing actions still write what they wrote',
        () {
      final Habit habit = addHabit();
      final WidgetIntentReceiver receiver = buildWidgetReceiver();
      habit.originalEntries.add(Entry(today, Entry.no, notes: 'kept'));

      receiver.onReceive(Intent(
        action: WidgetActions.addRepetition,
        data: habitUri(habit.id!),
      ));
      expect(lastValue(), Entry.yesManual,
          reason: 'intents.widget-receiver-dispatch#3 — ACTION_ADD_REPETITION '
              '-> WidgetBehavior.onAddRepetition(habit, date), reached here '
              'through the receiver rather than by calling the behavior '
              'directly.');

      receiver.onReceive(Intent(
        action: WidgetActions.removeRepetition,
        data: habitUri(habit.id!),
      ));
      expect(lastValue(), Entry.no,
          reason: 'intents.widget-receiver-dispatch#4 — '
              'ACTION_REMOVE_REPETITION -> WidgetBehavior.onRemoveRepetition');

      habit.originalEntries.add(Entry(today, Entry.no));
      receiver.onReceive(Intent(
        action: WidgetActions.toggleRepetition,
        data: habitUri(habit.id!),
      ));
      expect(lastValue(), Entry.yesManual,
          reason: 'intents.widget-receiver-dispatch#5 — '
              'ACTION_TOGGLE_REPETITION -> WidgetBehavior.onToggleRepetition');
    });

    test('#6 the rollover action sets today, refreshes and re-arms, in order',
        () {
      final WidgetIntentReceiver receiver = buildWidgetReceiver();
      // A day the global today is not: the branch's first statement is what
      // moves it.
      setToday(LocalDate.ymd(1999, 1, 1));
      systemCurrentTimeMillis = () => LocalDate.ymd(2015, 1, 26).unixTime;

      receiver.onReceive(Intent(action: WidgetActions.updateWidgetsValue));

      expect(getToday(), LocalDate.ymd(2015, 1, 26),
          reason: 'intents.widget-receiver-dispatch#6 — '
              'ACTION_UPDATE_WIDGETS_VALUE -> setToday(computeToday('
              'preferences.midnightDelayHours, 0)); '
              'widgetUpdater.updateWidgets(); '
              'widgetUpdater.scheduleStartDayWidgetUpdate().');
      expect(updaterCalls,
          <String>['updateWidgets', 'scheduleStartDayWidgetUpdate'],
          reason: 'intents.widget-receiver-dispatch#6: in that order');
    });
  });

  // =======================================================================
  // intents.reminder-receiver-dispatch
  // =======================================================================

  group('intents.reminder-receiver-dispatch', () {
    late RecordingScheduler scheduler;
    late ReminderController controller;
    late List<Habit> snoozed;

    ReminderIntentReceiver buildReminderReceiver() => ReminderIntentReceiver(
          habits: habitList,
          controller: controller,
          logging: logging,
          onSnoozePressed: snoozed.add,
        );

    setUp(() {
      scheduler = RecordingScheduler();
      controller = ReminderController(scheduler, tray, preferences);
      snoozed = <Habit>[];
    });

    test('#2 the received intent is parked in its own static field', () {
      final Habit habit = addHabit();
      final ReminderIntentReceiver receiver = buildReminderReceiver();
      const String rule = 'intents.reminder-receiver-dispatch#2 — The received '
          'intent is stored in the static ReminderReceiver.lastReceivedIntent '
          '(readable, cleared only by clearLastReceivedIntent()) — used by '
          'instrumentation tests.';

      final Intent intent = Intent(
        action: ReminderIntentActions.showReminder,
        data: habitUri(habit.id!),
      );
      receiver.onReceive(intent);
      expect(ReminderIntentReceiver.lastReceivedIntent, same(intent),
          reason: rule);
      expect(WidgetIntentReceiver.lastReceivedIntent, isNull,
          reason: '$rule It is ReminderReceiver\'s own field, not a shared '
              'one.');

      // The two early returns happen before the field is written, so an intent
      // with no action leaves the previous one standing.
      receiver.onReceive(Intent(data: habitUri(habit.id!)));
      expect(ReminderIntentReceiver.lastReceivedIntent, same(intent),
          reason: 'intents.reminder-receiver-dispatch#1 — onReceive returns '
              'immediately if context is null, intent is null, or intent.action '
              'is null, which is before lastReceivedIntent is written.');
      receiver.onReceive(null);
      expect(ReminderIntentReceiver.lastReceivedIntent, same(intent),
          reason: 'intents.reminder-receiver-dispatch#1');

      ReminderIntentReceiver.clearLastReceivedIntent();
      expect(ReminderIntentReceiver.lastReceivedIntent, isNull, reason: rule);
    });

    test('#4 timestamp and reminderTime both default to today\'s midnight', () {
      final Habit habit = addHabit();
      final ReminderIntentReceiver receiver = buildReminderReceiver();
      const String rule = 'intents.reminder-receiver-dispatch#4 — timestamp = '
          'intent.getLongExtra("timestamp", getToday().unixTime); reminderTime '
          '= intent.getLongExtra("reminderTime", getToday().unixTime). Both '
          'default to today\'s midnight in unix millis.';

      receiver.onReceive(Intent(
        action: ReminderIntentActions.showReminder,
        data: habitUri(habit.id!),
      ));
      expect(tray.shownDates, <LocalDate>[today], reason: rule);
      expect(tray.shownReminderTimes, <int>[today.unixTime],
          reason: '$rule Both defaults are the same number, and it is local '
              'midnight — not the epoch and not "now".');

      // Present extras win, and they are read independently of each other.
      tray.reset();
      final LocalDate yesterday = today.minus(1);
      receiver.onReceive(Intent(
        action: ReminderIntentActions.showReminder,
        data: habitUri(habit.id!),
        extras: <String, Object?>{
          'timestamp': yesterday.unixTime,
          'reminderTime': yesterday.unixTime + 8 * 3600000,
        },
      ));
      expect(tray.shownDates, <LocalDate>[yesterday], reason: rule);
      expect(tray.shownReminderTimes,
          <int>[yesterday.unixTime + 8 * 3600000], reason: rule);

      // One missing, one present: the missing one alone falls back.
      tray.reset();
      receiver.onReceive(Intent(
        action: ReminderIntentActions.showReminder,
        data: habitUri(habit.id!),
        extras: <String, Object?>{'timestamp': yesterday.unixTime},
      ));
      expect(tray.shownDates, <LocalDate>[yesterday], reason: rule);
      expect(tray.shownReminderTimes, <int>[today.unixTime],
          reason: '$rule The two extras are read separately.');
    });

    test('#7 the snooze branch resolves the habit and then opens the picker on '
        'every version', () {
      final Habit habit = addHabit();
      final ReminderIntentReceiver receiver = buildReminderReceiver();
      const String rule = 'intents.reminder-receiver-dispatch#7 — '
          'ACTION_SNOOZE_REMINDER: returns silently if habit is null; on SDK < '
          '31 calls reminderController.onSnoozePressed(habit, context); on SDK '
          '>= 31 only logs a warning. The port keeps the first clause and drops '
          'the version gate: the gate exists because from Android 12 a '
          'notification action may not start an activity, and there is no '
          'activity to start here — the response is handled in Dart and the '
          'picker is a dialog inside the running app. DEVIATIONS.md records the '
          'same decision for reminders.snooze-android12-gate.';

      // No data uri, so no habit: silent.
      receiver.onReceive(Intent(action: ReminderIntentActions.snoozeReminder));
      expect(snoozed, isEmpty, reason: rule);

      // A habit that no longer exists: also silent.
      receiver.onReceive(Intent(
        action: ReminderIntentActions.snoozeReminder,
        data: habitUri(habit.id! + 4242),
      ));
      expect(snoozed, isEmpty, reason: rule);

      receiver.onReceive(Intent(
        action: ReminderIntentActions.snoozeReminder,
        data: habitUri(habit.id!),
      ));
      expect(snoozed, <Habit>[habit], reason: rule);
      expect(scheduler.calls, isEmpty,
          reason: '$rule The receiver only opens the picker; the delay the '
              'user picks is what reaches the scheduler.');
    });

    test('#5/#6/#8/#9/#10 the remaining branches, through the same object', () {
      final Habit habit = addHabit();
      final ReminderIntentReceiver receiver = buildReminderReceiver();

      receiver.onReceive(Intent(
        action: ReminderIntentActions.bootCompleted,
        // "habit is irrelevant": no data uri at all.
      ));
      expect(scheduler.calls, <String>['scheduleAll'],
          reason: 'intents.reminder-receiver-dispatch#8 — '
              'Intent.ACTION_BOOT_COMPLETED: calls '
              'reminderController.onBootCompleted() (habit is irrelevant).');

      scheduler.calls.clear();
      receiver.onReceive(Intent(action: 'android.intent.action.MAIN'));
      expect(scheduler.calls, isEmpty,
          reason: 'intents.reminder-receiver-dispatch#9 — Any other action '
              'falls through the when with no effect.');
      expect(tray.log, isEmpty,
          reason: 'intents.reminder-receiver-dispatch#9');

      // A show for a habit that is gone returns before the tray is touched.
      receiver.onReceive(Intent(
        action: ReminderIntentActions.showReminder,
        data: habitUri(habit.id! + 4242),
      ));
      expect(tray.log, isEmpty,
          reason: 'intents.reminder-receiver-dispatch#5 — ACTION_SHOW_REMINDER: '
              'returns silently if habit is null.');

      receiver.onReceive(Intent(
        action: ReminderIntentActions.dismissReminder,
        data: habitUri(habit.id!),
      ));
      expect(tray.log, <String>['cancel'],
          reason: 'intents.reminder-receiver-dispatch#6 — '
              'ACTION_DISMISS_REMINDER: calls reminderController.onDismiss.');

      // A tray that fails mid-dispatch: the catch logs and swallows it.
      tray.reset();
      tray.throwOnCancel = true;
      receiver.onReceive(Intent(
        action: ReminderIntentActions.dismissReminder,
        data: habitUri(habit.id!),
      ));
      expect('$logOut', contains('could not process intent'),
          reason: 'intents.reminder-receiver-dispatch#10 — The whole dispatch '
              'is wrapped in try/catch(RuntimeException) which logs "could not '
              'process intent" and swallows the error — a deleted habit or '
              'malformed URI never crashes the app.');
      tray.throwOnCancel = false;

      // The reach of that catch is exactly the `when`, and no more. The habit
      // lookup sits above the try in the Kotlin, so a uri whose last segment is
      // not a number still escapes `onReceive` — kept rather than tidied,
      // because moving the lookup inside the try would change which failures
      // the app survives.
      expect(
        () => receiver.onReceive(Intent(
          action: ReminderIntentActions.dismissReminder,
          data: Uri.parse('content://org.isoron.uhabits/habit/not-a-number'),
        )),
        throwsA(isA<FormatException>()),
        reason: 'intents.reminder-receiver-dispatch#10: the catch begins after '
            'ContentUris.parseId has already run — "a deleted habit" is '
            'covered by the null check above it, not by the catch.',
      );
    });
  });

  // =======================================================================
  // platform-glue.habit-content-uri
  // =======================================================================

  group('platform-glue.habit-content-uri', () {
    test('#5 ACTION_SET_NUMERICAL_VALUE parses the intent and then drops it',
        () {
      final Habit habit = addHabit(type: HabitType.numerical);
      final WidgetIntentReceiver receiver = buildWidgetReceiver();
      const String rule = 'platform-glue.habit-content-uri#5 — Note the '
          'manifest advertises org.isoron.uhabits.ACTION_SET_NUMERICAL_VALUE '
          'but WidgetReceiver has no branch for it, so such a broadcast parses '
          'the checkmark data and then does nothing.';

      // A well-formed broadcast: the parse succeeds, so nothing is logged as a
      // failure — and nothing is written either.
      receiver.onReceive(Intent(
        action: WidgetActions.setNumericalValue,
        data: habitUri(habit.id!),
      ));
      expect(commandRunner.commands, isEmpty, reason: rule);
      expect('$logOut', isNot(contains('could not process intent')),
          reason: '$rule The parse itself succeeded — the intent was well '
              'formed; it is the missing branch that drops it.');

      // A malformed one still goes through the parser first, and therefore
      // still fails there.
      receiver.onReceive(Intent(action: WidgetActions.setNumericalValue));
      expect('$logOut', contains('could not process intent'),
          reason: '$rule The parse is unconditional for every action but the '
              'rollover.');
    });

    test('#6 the show link carries the habit uri, and an id that no longer '
        'resolves throws', () {
      final Habit habit = addHabit();
      const String rule = 'platform-glue.habit-content-uri#6 — '
          'ShowHabitActivity.onCreate resolves its habit with habitList.getById'
          '(ContentUris.parseId(intent.data!!))!! and will crash with NPE if '
          'the data is missing or the habit was deleted.';

      final Intent intent = widgetLinkIntent(
        WidgetLink(
          action: WidgetLink.actionShow,
          widgetId: 3,
          habitId: habit.id,
        ),
        today: today,
      )!;
      expect(intent.action, isNull,
          reason: '$rule IntentFactory.startShowHabitActivity sets only the '
              'data — the component is the target.');
      expect('${intent.data}', habit.uriString, reason: rule);
      expect(ShowHabitScreen.habitFromUri(habitList, intent.data!), same(habit),
          reason: rule);

      final Uri gone = habitUri(habit.id! + 4242);
      expect(() => ShowHabitScreen.habitFromUri(habitList, gone),
          throwsA(isA<TypeError>()),
          reason: '$rule A habit deleted since the widget last drew itself.');
      // "if the data is missing": the `!!` on `intent.data` itself.
      final Intent noData = Intent();
      expect(() => ShowHabitScreen.habitFromUri(habitList, noData.data!),
          throwsA(isA<TypeError>()),
          reason: '$rule And an intent with no data at all.');
    });
  });

  // =======================================================================
  // platform-glue.deep-link-edit-entry — the whole path, end to end
  // =======================================================================

  group('platform-glue.deep-link-edit-entry', () {
    late Directory tempDir;
    final List<AppScope> scopes = <AppScope>[];

    setUp(() {
      resetToday();
      tempDir = Directory.systemTemp.createTempSync('uhabits_deep_link');
    });

    tearDown(() {
      for (final AppScope scope in scopes) {
        scope.close();
      }
      scopes.clear();
      tempDir.deleteSync(recursive: true);
    });

    AppScope openScope() {
      final AppScope scope = AppScope.open(
        AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
      );
      // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
      // empty preference store IS a first run, and a first run now opens the intro
      // on top of the habit list (`verify.intro-never-shown`) — which is
      // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
      scope.preferences.isFirstRun = false;
      scopes.add(scope);
      return scope;
    }

    Habit addDbHabit(AppScope scope, {HabitType type = HabitType.yesNo}) {
      final Habit habit = scope.modelFactory.buildHabit()
        ..name = 'Meditate'
        ..type = type;
      if (type == HabitType.numerical) {
        habit
          ..targetValue = 200
          ..unit = 'steps';
      }
      scope.habitList.add(habit);
      habit.recompute();
      return habit;
    }

    /// One router with no plugin behind it, so `start()` is never needed.
    WidgetLinkRouter routerFor(
      AppScope scope, {
      void Function(Habit habit)? showHabit,
    }) =>
        WidgetLinkRouter(
          habitList: scope.habitList,
          registry: WidgetRegistry(MemoryStorage()),
          publish: () async {},
          navigator: GlobalKey<NavigatorState>(),
          launches: const _NoLaunches(),
          showHabit: showHabit,
        );

    Widget wrap(AppScope scope, WidgetLinkRouter router) => MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: HabitListScreen(widgetLinks: router),
          ),
        );

    HabitListModel modelOf(WidgetTester tester) =>
        Provider.of<HabitListModel>(
          tester.element(find.byType(Scaffold)),
          listen: false,
        );

    String iso(LocalDate date) => '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    testWidgets('#2/#3 an edit link opens that day\'s popup through '
        'parseIntents', (WidgetTester tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope, type: HabitType.numerical);
      final WidgetLinkRouter router = routerFor(scope);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      final LocalDate date = getToday().minus(2);
      await router.handle(Uri.parse('uhabits://widget/edit?habit=${habit.id}'
          '&widgetId=7&date=${iso(date)}'));
      await tester.pumpAndSettle();

      expect(find.byType(NumberDialog), findsOneWidget,
          reason: 'platform-glue.deep-link-edit-entry#3 — If intent.action == '
              'ACTION_EDIT and both long extras "habit" and "timestamp" are '
              'present, the activity resolves the habit with '
              'habitList.getById(habitId)!! and calls '
              'listHabitsBehavior.onEdit(habit, '
              'LocalDate.fromUnixTime(timestampMillis), 0f, 0f) — the 0f,0f '
              'coordinates suppress the confetti animation.');

      // The value really lands on the day the link named.
      await tester.enterText(
          find.byKey(const ValueKey<String>('number_value')), '5');
      await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
      await tester.pumpAndSettle();
      expect(habit.computedEntries.get(date).value, 5000,
          reason: 'platform-glue.deep-link-edit-entry#3: for the day the link '
              'named, not for today');
    });

    testWidgets('#2 the link is acted on by the screen\'s resume, not by the '
        'router', (WidgetTester tester) async {
      const String rule = 'platform-glue.deep-link-edit-entry#2 — '
          'parseIntents() runs at the end of every onResume, before '
          'super.onResume(). The port keeps the two halves where upstream had '
          'them: the delivery sets pendingIntent (onNewIntent -> setIntent) '
          'and HabitListModel.attach() — the resume — is what parses it.';

      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope);
      final WidgetLinkRouter router = routerFor(scope);

      // The link arrives before any screen exists, which is what a cold launch
      // from a widget tap looks like. Upstream the system hands the intent to
      // an activity that has not been created yet and `onResume` finds it
      // waiting; here the router holds it until the screen registers.
      await router.handle(Uri.parse(
          'uhabits://widget/edit?habit=${habit.id}&widgetId=7'));

      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: '$rule Nothing is lost by arriving early.');

      await tester
          .tap(find.byKey(const ValueKey<String>('checkmark_no_button')));
      await tester.pumpAndSettle();

      // And the resume really is the trigger: an intent parked on the model
      // does nothing until `attach()` runs.
      final HabitListModel model = modelOf(tester);
      model
        ..detach()
        ..pendingIntent = Intent(
          action: actionEdit,
          extras: <String, Object?>{
            'habit': habit.id,
            'timestamp': getToday().unixTime,
          },
        );
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsNothing, reason: rule);

      model.attach();
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: '$rule The resume is what opens it.');
    });

    testWidgets('#4 the intent is cleared, so a second resume handles nothing',
        (WidgetTester tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope);
      final WidgetLinkRouter router = routerFor(scope);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      await router.handle(Uri.parse(
          'uhabits://widget/edit?habit=${habit.id}&widgetId=7'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: 'platform-glue.deep-link-edit-entry#4');

      await tester.tap(find.byKey(const ValueKey<String>('checkmark_no_button')));
      await tester.pumpAndSettle();

      final HabitListModel model = modelOf(tester);
      expect(model.pendingIntent, isNull,
          reason: 'platform-glue.deep-link-edit-entry#4 — After parsing, '
              '`intent` is set to null so the same deep link is never handled '
              'twice on a subsequent resume.');
      model
        ..detach()
        ..attach();
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsNothing,
          reason: 'platform-glue.deep-link-edit-entry#4');
    });

    testWidgets('#5 a second tap reuses the one screen that is already there',
        (WidgetTester tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope);
      final WidgetLinkRouter router = routerFor(scope);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      const String rule = 'platform-glue.deep-link-edit-entry#5 — onNewIntent '
          'stores the new intent via setIntent(intent); because launchMode is '
          'singleTop, a second widget tap reuses the existing activity '
          'instance. A Flutter app has exactly one activity, so "reuse" is '
          'structural: the same HabitListModel answers both taps.';

      final HabitListModel first = modelOf(tester);
      await router.handle(Uri.parse(
          'uhabits://widget/edit?habit=${habit.id}&widgetId=7'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('checkmark_no_button')));
      await tester.pumpAndSettle();

      await router.handle(Uri.parse(
          'uhabits://widget/edit?habit=${habit.id}&widgetId=7'));
      await tester.pumpAndSettle();
      expect(modelOf(tester), same(first), reason: rule);
      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: '$rule And the second tap is answered, not dropped.');
    });

    testWidgets('#6 an id that does not resolve throws, uncaught',
        (WidgetTester tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope);
      final WidgetLinkRouter router = routerFor(scope);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      final HabitListModel model = modelOf(tester);
      model
        ..detach()
        ..pendingIntent = Intent(
          action: actionEdit,
          extras: <String, Object?>{
            'habit': habit.id! + 4242,
            'timestamp': getToday().unixTime,
          },
        );

      expect(model.parseIntents, throwsA(isA<TypeError>()),
          reason: 'platform-glue.deep-link-edit-entry#6 — If the habit id does '
              'not resolve, the non-null assertion throws (uncaught) — there '
              'is no graceful "habit not found" path on this route.');
    });

    testWidgets('a screen that goes away stops receiving, and the link that '
        'arrives meanwhile waits for the next one',
        (WidgetTester tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope);
      final WidgetLinkRouter router = routerFor(scope);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      // The screen is torn down — a configuration change, or the app being
      // rebuilt around a theme switch.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      const String rule = 'platform-glue.deep-link-edit-entry#5 — onNewIntent '
          'stores the new intent via setIntent(intent). An activity that no '
          'longer exists cannot be the one that stores it, so the router holds '
          'the intent until a screen registers again — which is what Android '
          'does with an Intent handed to a process whose activity has been '
          'destroyed.';

      await router.handle(Uri.parse(
          'uhabits://widget/edit?habit=${habit.id}&widgetId=7'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsOneWidget, reason: rule);
    });

    testWidgets('a show link opens the habit screen; a toggle link writes',
        (WidgetTester tester) async {
      final AppScope scope = openScope();
      final Habit habit = addDbHabit(scope);
      final List<Habit> shown = <Habit>[];
      final WidgetLinkRouter router = routerFor(scope, showHabit: shown.add);
      await tester.pumpWidget(wrap(scope, router));
      await tester.pumpAndSettle();

      await router
          .handle(Uri.parse('uhabits://widget/show?habit=${habit.id}&widgetId=1'));
      expect(shown, <Habit>[habit],
          reason: 'platform-glue.habit-content-uri#6: the five graph widgets '
              'open the habit detail screen, addressed by the same content '
              'uri.');

      // A habit deleted between the widget's last redraw and the tap is
      // dropped rather than crashing the running app.
      shown.clear();
      await router.handle(Uri.parse(
          'uhabits://widget/show?habit=${habit.id! + 4242}&widgetId=1'));
      expect(shown, isEmpty,
          reason: 'platform-glue.habit-content-uri#6');
    });
  });

  // =======================================================================
  // The link-to-intent translation itself
  // =======================================================================

  group('widgetLinkIntent', () {
    test('a toggle link becomes the broadcast WidgetReceiver expects', () {
      final Habit habit = addHabit();
      final Intent intent = widgetLinkIntent(
        WidgetLink(
          action: WidgetLink.actionToggle,
          widgetId: 4,
          habitId: habit.id,
        ),
        today: today,
      )!;

      expect(intent.action, WidgetActions.toggleRepetition,
          reason: 'intents.actions-and-extras#6');
      expect('${intent.data}', habit.uriString,
          reason: 'intents.actions-and-extras#10: the habit is always '
              'identified by the intent\'s data URI '
              '"content://org.isoron.uhabits/habit/<id>".');
      expect(intent.getLongExtra('timestamp', -1), today.unixTime,
          reason: 'intents.actions-and-extras#12 — the ADD/REMOVE/TOGGLE '
              'repetition intents carry the long extra "timestamp" = '
              'LocalDate.unixTime; a link with no date means today.');
    });

    test('a configure link has no intent behind it, and neither does a link '
        'without a habit', () {
      expect(
        widgetLinkIntent(
          const WidgetLink(action: WidgetLink.actionConfigure, widgetId: 4),
          today: today,
        ),
        isNull,
        reason: 'intents.widget-receiver-dispatch#8: configure is not one of '
            'the receiver\'s four actions — it is answered by the picker '
            'dialog.',
      );
      expect(
        widgetLinkIntent(
          const WidgetLink(action: WidgetLink.actionToggle, widgetId: 4),
          today: today,
        ),
        isNull,
        reason: 'intents.widget-receiver-dispatch#9: a link with no habit '
            'cannot become an intent with a data uri.',
      );
    });

    test('a malformed date falls back to today rather than throwing', () {
      final Habit habit = addHabit();
      for (final String bad in <String>['', 'today', '2015-13-01',
        '2015-02-30', '15-01-26']) {
        final Intent intent = widgetLinkIntent(
          WidgetLink(
            action: WidgetLink.actionToggle,
            widgetId: 4,
            habitId: habit.id,
            date: bad,
          ),
          today: today,
        )!;
        expect(intent.getLongExtra('timestamp', -1), today.unixTime,
            reason: 'intents.widget-receiver-dispatch#7: nothing that arrives '
                'from another process is trusted ("$bad")');
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// A [WidgetLaunchSource] with no plugin behind it: the router is driven by
/// calling [WidgetLinkRouter.handle] directly.
class _NoLaunches implements WidgetLaunchSource {
  const _NoLaunches();

  @override
  Future<Uri?> initialLaunchUri() async => null;

  @override
  Stream<Uri?> get launchUris => const Stream<Uri?>.empty();
}

class RecordingCommandRunner extends CommandRunner {
  RecordingCommandRunner(super.taskRunner);

  final List<Command> commands = <Command>[];

  @override
  void run(Command command) {
    commands.add(command);
    super.run(command);
  }
}

/// The tray, recording what `ReminderController` and `WidgetBehavior` ask of
/// it. `show` is the only method whose arguments matter here.
class RecordingNotificationTray extends NotificationTray {
  RecordingNotificationTray(
    TaskRunner taskRunner,
    CommandRunner commandRunner,
    Preferences preferences,
  ) : super(taskRunner, commandRunner, preferences, _NullSystemTray());

  final List<String> log = <String>[];
  final List<LocalDate> shownDates = <LocalDate>[];
  final List<int> shownReminderTimes = <int>[];

  /// Makes the dispatch fail from inside the `when`, which is the only place
  /// the receiver's catch can reach.
  bool throwOnCancel = false;

  void reset() {
    log.clear();
    shownDates.clear();
    shownReminderTimes.clear();
  }

  @override
  void cancel(Habit habit) {
    log.add('cancel');
    if (throwOnCancel) throw StateError('tray unavailable');
  }

  @override
  void reshow(Habit habit) => log.add('reshow');

  @override
  void show(Habit habit, LocalDate date, int reminderTime) {
    log.add('show');
    shownDates.add(date);
    shownReminderTimes.add(reminderTime);
  }
}

class _NullSystemTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}

class RecordingScheduler implements ReminderSchedulerApi {
  final List<String> calls = <String>[];

  @override
  void scheduleAll() => calls.add('scheduleAll');

  @override
  void scheduleAtTime(Habit habit, int reminderTime) =>
      calls.add('scheduleAtTime');

  @override
  void snoozeReminder(Habit habit, int minutes) => calls.add('snoozeReminder');

  @override
  void snoozeUntil(Habit habit, int reminderTime) => calls.add('snoozeUntil');
}
