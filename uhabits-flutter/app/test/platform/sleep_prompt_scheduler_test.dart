/// The morning question a sleep habit asks.
///
/// It was first armed through `SystemScheduler.scheduleShowReminder`, which is
/// the habit reminder machinery. That machinery reads `habit.reminder` to work
/// out which weekdays an alarm covers and answers a habit with none by
/// CANCELLING; it files the alarm under the habit's own notification id; and it
/// reads a local wall-clock day out of the slot a UTC instant was being passed
/// in. Every one of those is wrong for a question whose moment comes from a
/// drifting goal. This file pins the replacement.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_alarm_scheduler.dart' show AlarmPlugin;
import 'package:uhabits/platform/flutter_notification_tray.dart'
    show
        NotificationSpec,
        NotificationStrings,
        ReminderNotificationBuilder,
        reminderNotificationId;
import 'package:uhabits/platform/sleep_prompt_scheduler.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart';

class RecordingAlarms implements AlarmPlugin {
  final List<(NotificationSpec, int)> scheduled = <(NotificationSpec, int)>[];
  final List<int> cancelled = <int>[];

  @override
  Future<void> scheduleExact({
    required NotificationSpec spec,
    required int whenMillis,
  }) async =>
      scheduled.add((spec, whenMillis));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<bool> requestExactAlarmsPermission() async => true;
}

const NotificationStrings strings = NotificationStrings(
  yes: 'Yes',
  no: 'No',
  enter: 'Enter',
  snooze: 'Later',
  defaultReminderQuestion: 'Have you completed this habit today?',
  channelName: 'Reminder',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingAlarms alarms;
  late SleepPromptScheduler prompts;

  setUp(() {
    alarms = RecordingAlarms();
    prompts = SleepPromptScheduler(
      alarms: alarms,
      builder: ReminderNotificationBuilder(
        preferences: Preferences(MemoryStorage()),
        strings: () => strings,
      ),
    );
  });

  Habit habitWith({int id = 7, Reminder? reminder}) {
    final Habit habit = MemoryModelFactory().buildHabit()
      ..id = id
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit
      ..reminder = reminder;
    return habit;
  }

  group('the notification id', () {
    test('is not the habit\'s own reminder id', () {
      final Habit habit = habitWith();
      expect(sleepPromptNotificationId(habit),
          isNot(reminderNotificationId(habit)),
          reason: 'sleep.freshness#4');
    });

    test('never collides with another habit\'s reminder id', () {
      // Reminder ids are the habit id itself. Setting the top bit puts every
      // question outside that range for any id the app can produce.
      for (final int id in <int>[1, 2, 7, 1000, 0x3FFFFFFF]) {
        final Habit habit = habitWith(id: id);
        expect(sleepPromptNotificationId(habit),
            greaterThanOrEqualTo(0x40000000),
            reason: 'sleep.freshness#4');
        expect(sleepPromptNotificationId(habit), isNot(id),
            reason: 'sleep.freshness#4');
      }
    });

    test('is stable for a habit and distinct between habits', () {
      expect(sleepPromptNotificationId(habitWith(id: 7)),
          sleepPromptNotificationId(habitWith(id: 7)));
      expect(sleepPromptNotificationId(habitWith(id: 7)),
          isNot(sleepPromptNotificationId(habitWith(id: 8))));
    });

    test('an unsaved habit gets zero rather than throwing', () {
      final Habit habit = MemoryModelFactory().buildHabit();
      expect(sleepPromptNotificationId(habit), 0);
    });
  });

  group('arming it', () {
    test('works for a habit with no reminder of its own', () async {
      // The whole point: the reminder machinery would cancel here.
      final Habit habit = habitWith(reminder: null);
      await prompts.schedule(habit, LocalDate(9000), 1756108800000);

      expect(alarms.scheduled, hasLength(1), reason: 'sleep.freshness#4');
      expect(alarms.cancelled, isEmpty, reason: 'sleep.freshness#4');
      expect(alarms.scheduled.single.$2, 1756108800000);
    });

    test('files it under its own id', () async {
      final Habit habit = habitWith();
      await prompts.schedule(habit, LocalDate(9000), 1756108800000);
      expect(alarms.scheduled.single.$1.id, sleepPromptNotificationId(habit),
          reason: 'sleep.freshness#4');
      expect(alarms.scheduled.single.$1.id, isNot(reminderNotificationId(habit)));
    });

    test('carries the day it was given, not one derived from the instant',
        () async {
      // East of UTC+8 a UTC instant lands on the day before, and the night the
      // person then entered would be filed against yesterday.
      final Habit habit = habitWith();
      await prompts.schedule(habit, LocalDate(9000), 1756108800000);
      final NotificationSpec spec = alarms.scheduled.single.$1;
      expect(spec.payload, contains('${LocalDate(9000).unixTime}'));
    });

    test('arming again replaces rather than adding', () async {
      final Habit habit = habitWith();
      await prompts.schedule(habit, LocalDate(9000), 1756108800000);
      await prompts.schedule(habit, LocalDate(9001), 1756195200000);
      expect(
        alarms.scheduled.map((r) => r.$1.id).toSet(),
        <int>{sleepPromptNotificationId(habit)},
        reason: 'the same id, so the platform replaces the outstanding one',
      );
    });

    test('cancelling names the same id', () async {
      final Habit habit = habitWith();
      await prompts.cancel(habit);
      expect(alarms.cancelled, <int>[sleepPromptNotificationId(habit)]);
    });
  });

  group('what it says', () {
    test('is the habit name and its question', () async {
      final Habit habit = habitWith()..question = 'How did you sleep?';
      final NotificationSpec spec =
          prompts.specFor(habit, LocalDate(9000), 1756108800000);
      expect(spec.title, 'Sleep');
      expect(spec.body, 'How did you sleep?');
    });

    test('falls back to the default question when the habit asks none',
        () async {
      final Habit habit = habitWith()..question = '   ';
      final NotificationSpec spec =
          prompts.specFor(habit, LocalDate(9000), 1756108800000);
      expect(spec.body, isNotEmpty);
      expect(spec.body.trim(), spec.body);
    });
  });
}
