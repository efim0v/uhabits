import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/edit_habit_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/reminders/ReminderScheduler.kt
/// and uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt, with
/// the scenarios of
/// uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/reminders/ReminderSchedulerTest.kt
/// and uhabits-core/src/jvmTest/java/org/isoron/platform/time/DateUtilsTest.kt.
///
/// The Kotlin test helper `unixTime` takes a 0-based `java.util.Calendar`
/// month, so `unixTime(2015, 1, 26)` there is February 26. The rules in
/// docs/parity/FEATURES.md spell those same scenarios with 1-based months
/// (2015-01-26); since every assertion here is pure day/hour arithmetic the
/// month is irrelevant, and the helper below takes the 1-based month so the
/// dates read exactly as the rules state them.
int unixTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int milliseconds = 0,
]) =>
    DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch +
    milliseconds;

const TimeZone gmt = FixedTimeZone(0);
const TimeZone gmtMinus4 = FixedTimeZone(-4 * DateUtils.hourLength);

/// A zone with a real DST discontinuity, mirroring Australia/Sydney around the
/// 2017 spring-forward: AEST (+10) before 2017-10-01 02:00 local, AEDT (+11)
/// after. `java.util.TimeZone.getOffset(long)` takes a UTC instant, so the
/// switch is expressed in UTC too. This is what makes the double-offset lookup
/// in applyTimezone observable.
class SydneyLikeTimeZone implements TimeZone {
  const SydneyLikeTimeZone();

  /// 2017-10-01 02:00 AEST == 2017-09-30 16:00 UTC.
  static final int dstStart = DateTime.utc(2017, 9, 30, 16).millisecondsSinceEpoch;

  /// 2018-04-01 03:00 AEDT == 2018-03-31 16:00 UTC.
  static final int dstEnd = DateTime.utc(2018, 3, 31, 16).millisecondsSinceEpoch;

  @override
  int getOffset(int timestamp) =>
      (timestamp >= dstStart && timestamp < dstEnd) ? 11 * 3600000 : 10 * 3600000;
}

class ScheduledReminder {
  ScheduledReminder(this.reminderTime, this.habit, this.timestamp);

  final int reminderTime;
  final Habit habit;
  final int timestamp;
}

/// Records everything the scheduler asks of the platform.
class SpySystemScheduler implements SystemScheduler {
  final List<ScheduledReminder> scheduled = <ScheduledReminder>[];
  final List<int> widgetUpdates = <int>[];
  final List<String> logs = <String>[];

  /// Every platform call in order, so non-interleaving can be asserted.
  final List<String> calls = <String>[];

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) {
    scheduled.add(ScheduledReminder(reminderTime, habit, timestamp));
    calls.add('show:${habit.name}:$reminderTime:$timestamp');
    return SchedulerResult.ok;
  }

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) {
    widgetUpdates.add(updateTime);
    calls.add('widget:$updateTime');
    return SchedulerResult.ok;
  }

  @override
  void log(String componentName, String msg) {
    logs.add(msg);
    calls.add('log:$msg');
  }

  void clear() {
    scheduled.clear();
    widgetUpdates.clear();
    logs.clear();
    calls.clear();
  }
}

/// Notes every key the preference layer touches, so the snooze key format and
/// the "write 0, do not delete" contract can be asserted directly.
class RecordingStorage extends MemoryStorage {
  final List<String> writtenKeys = <String>[];
  final List<int> writtenLongs = <int>[];
  final List<String> readKeys = <String>[];
  final List<String> removedKeys = <String>[];

  @override
  int getLong(String key, int defValue) {
    readKeys.add(key);
    return super.getLong(key, defValue);
  }

  @override
  void putLong(String key, int value) {
    writtenKeys.add(key);
    writtenLongs.add(value);
    super.putLong(key, value);
  }

  @override
  void remove(String key) {
    removedKeys.add(key);
    super.remove(key);
  }
}

/// Remembers the matcher handed to getFiltered, which is how the WITH_ALARM
/// query itself becomes observable.
class RecordingHabitList extends MemoryHabitList {
  RecordingHabitList() : super();

  final List<HabitMatcher?> filterRequests = <HabitMatcher?>[];

  @override
  MemoryHabitList getFiltered(HabitMatcher? matcher) {
    filterRequests.add(matcher);
    return super.getFiltered(matcher) as MemoryHabitList;
  }
}

void main() {
  const int habitId = 10;

  late RecordingHabitList habitList;
  late HabitFixtures fixtures;
  late SpySystemScheduler sys;
  late RecordingStorage storage;
  late WidgetPreferences widgetPreferences;
  late CommandRunner commandRunner;
  late ReminderScheduler reminderScheduler;
  late Habit habit;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 26));
    habitList = RecordingHabitList();
    fixtures = HabitFixtures(MemoryModelFactory(), habitList);
    sys = SpySystemScheduler();
    storage = RecordingStorage();
    widgetPreferences = WidgetPreferences(storage);
    commandRunner = CommandRunner(
      CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      ),
    );
    reminderScheduler = ReminderScheduler(
      commandRunner,
      habitList,
      sys,
      widgetPreferences,
    );
    habit = fixtures.createEmptyHabit();
    habit.id = habitId;
    DateUtils.setFixedTimeZone(gmtMinus4);
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  // -----------------------------------------------------------------------
  // reminders.upcoming-time
  // -----------------------------------------------------------------------

  group('DateUtils', () {
    test('constants', () {
      expect(DateUtils.secondLength, 1000,
          reason: 'reminders.upcoming-time#8: SECOND_LENGTH=1000');
      expect(DateUtils.minuteLength, 60000,
          reason: 'reminders.upcoming-time#8: MINUTE_LENGTH=60000');
      expect(DateUtils.hourLength, 3600000,
          reason: 'reminders.upcoming-time#8: HOUR_LENGTH=3600000');
      expect(DateUtils.dayLength, 86400000,
          reason: 'reminders.upcoming-time#8: DAY_LENGTH=86400000');
    });

    test('getStartOfDay floors to the day', () {
      final startOfDay = unixTime(2017, 1, 1);
      final laterInDay = unixTime(2017, 1, 1, 20, 0);
      expect(DateUtils.getStartOfDay(laterInDay), startOfDay,
          reason: 'reminders.upcoming-time#9: '
              'getStartOfDay(t) = (t / 86400000) * 86400000');
      expect(DateUtils.getStartOfDay(startOfDay), startOfDay,
          reason: 'reminders.upcoming-time#9: a day boundary is its own start');
    });

    test('getStartOfDayWithOffset', () {
      final timestamp = unixTime(2020, 9, 3);
      expect(
        DateUtils.getStartOfDayWithOffset(
            timestamp + DateUtils.hourLength, 0, 0),
        timestamp,
        reason: 'reminders.upcoming-time#10: '
            'getStartOfDayWithOffset(t, 0, 0) = getStartOfDay(t)',
      );
      expect(
        DateUtils.getStartOfDayWithOffset(
          timestamp + 3 * DateUtils.hourLength + 29 * DateUtils.minuteLength,
          3,
          30,
        ),
        timestamp - DateUtils.dayLength,
        reason: 'reminders.upcoming-time#10: Sep 3 03:29 with offset (3, 30) '
            'floors to Sep 2 00:00',
      );
    });

    test('getLocalTime shifts by the zone offset', () {
      DateUtils.setFixedLocalTime(null);
      DateUtils.setFixedTimeZone(const FixedTimeZone(11 * 3600000));
      final utcTime = unixTime(2015, 1, 11);
      expect(
        DateUtils.getLocalTime(utcTimeInMillis: utcTime),
        utcTime + 11 * 3600000,
        reason: 'reminders.upcoming-time#7: '
            'getLocalTime(tz) = now + tz.getOffset(now)',
      );
      DateUtils.setFixedLocalTime(12345);
      expect(
        DateUtils.getLocalTime(utcTimeInMillis: utcTime),
        12345,
        reason: 'reminders.upcoming-time#7: an injected fixed local time wins '
            'over the clock',
      );
    });

    test('applyTimezone uses a double offset lookup', () {
      DateUtils.setFixedTimeZone(const SydneyLikeTimeZone());
      expect(
        DateUtils.applyTimezone(unixTime(2017, 10, 1, 1, 59)),
        unixTime(2017, 9, 30, 15, 59),
        reason: 'reminders.upcoming-time#5: applyTimezone(l) = '
            'l - tz.getOffset(l - tz.getOffset(l)); just before the DST jump '
            'the second lookup still returns +10',
      );
      expect(
        DateUtils.applyTimezone(unixTime(2017, 10, 1, 3, 0)),
        unixTime(2017, 9, 30, 16, 0),
        reason: 'reminders.upcoming-time#5: right after the DST jump the '
            'second lookup returns +11',
      );
      expect(
        DateUtils.applyTimezone(unixTime(2017, 7, 30, 18, 0)),
        unixTime(2017, 7, 30, 8, 0),
        reason: 'reminders.upcoming-time#5: outside DST the double lookup is '
            'the plain offset',
      );
      DateUtils.setFixedTimeZone(gmtMinus4);
      expect(
        DateUtils.applyTimezone(unixTime(2015, 1, 2, 8, 30)),
        unixTime(2015, 1, 2, 12, 30),
        reason: 'reminders.upcoming-time#5: in GMT-4 a local timestamp is '
            'four hours behind UTC',
      );
    });

    test('removeTimezone adds the offset at that instant', () {
      DateUtils.setFixedTimeZone(const SydneyLikeTimeZone());
      expect(
        DateUtils.removeTimezone(unixTime(2017, 9, 30, 15, 59)),
        unixTime(2017, 10, 1, 1, 59),
        reason: 'reminders.upcoming-time#6: '
            'removeTimezone(t) = t + tz.getOffset(t)',
      );
      expect(
        DateUtils.removeTimezone(unixTime(2017, 9, 30, 16, 0)),
        unixTime(2017, 10, 1, 3, 0),
        reason: 'reminders.upcoming-time#6: the offset is read at the UTC '
            'instant, so the DST jump is visible',
      );
      DateUtils.setFixedTimeZone(gmtMinus4);
      expect(
        DateUtils.removeTimezone(unixTime(2015, 1, 30, 11, 30)),
        unixTime(2015, 1, 30, 7, 30),
        reason: 'reminders.upcoming-time#6: GMT-4 subtracts four hours',
      );
    });

    test('getUpcomingTimeInMillis at a fixed GMT time', () {
      DateUtils.setFixedTimeZone(gmt);
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 25, 8, 0));
      expect(
        DateUtils.getUpcomingTimeInMillis(10, 1),
        unixTime(2015, 1, 25, 10, 1),
        reason: 'reminders.upcoming-time#4: fixed GMT time 2015-01-25 08:00, '
            'getUpcomingTimeInMillis(10, 1) == 2015-01-25 10:01 UTC',
      );
      expect(
        DateUtils.getUpcomingTimeInMillis(7, 0),
        unixTime(2015, 1, 26, 7, 0),
        reason: 'reminders.upcoming-time#2: when the wall-clock time has '
            'already passed today, one DAY_LENGTH is added',
      );
    });

    test('getUpcomingTimeInMillis returns a UTC instant', () {
      DateUtils.setFixedTimeZone(gmtMinus4);
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 30));
      expect(
        DateUtils.getUpcomingTimeInMillis(8, 30),
        unixTime(2015, 1, 26, 12, 30),
        reason: 'reminders.upcoming-time#1: the next occurrence of local '
            '08:30 in GMT-4 is 12:30 UTC',
      );
      expect(
        DateUtils.getUpcomingTimeInMillis(8, 30),
        DateUtils.applyTimezone(unixTime(2015, 1, 26, 8, 30)),
        reason: 'reminders.upcoming-time#2: the result is '
            'applyTimezone(startOfToday + hour:minute)',
      );
    });

    test('getUpcomingTimeInMillis is strictly greater-than', () {
      DateUtils.setFixedTimeZone(gmt);
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 25, 10, 1));
      expect(
        DateUtils.getUpcomingTimeInMillis(10, 1),
        unixTime(2015, 1, 25, 10, 1),
        reason: 'reminders.upcoming-time#3: local time equal to the reminder '
            'time schedules for today, not tomorrow',
      );
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 25, 10, 1, 1));
      expect(
        DateUtils.getUpcomingTimeInMillis(10, 1),
        unixTime(2015, 1, 26, 10, 1),
        reason: 'reminders.upcoming-time#3: one millisecond later it rolls to '
            'tomorrow',
      );
    });

    test('getStartOfTomorrowWithOffset is getUpcomingTimeInMillis', () {
      DateUtils.setFixedTimeZone(gmt);
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 2, 0));
      expect(
        DateUtils.getStartOfTomorrowWithOffset(3, 0),
        DateUtils.getUpcomingTimeInMillis(3, 0),
        reason: 'reminders.upcoming-time#11: getStartOfTomorrowWithOffset is '
            'defined as exactly getUpcomingTimeInMillis',
      );
      expect(
        DateUtils.getStartOfTomorrowWithOffset(3, 0),
        unixTime(2017, 1, 1, 3, 0),
        reason: 'reminders.upcoming-time#11: prior to the offset, "tomorrow" '
            'starts later today',
      );
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 4, 0));
      expect(
        DateUtils.getStartOfTomorrowWithOffset(3, 0),
        unixTime(2017, 1, 2, 3, 0),
        reason: 'reminders.upcoming-time#11: after the offset it is the next '
            'calendar day',
      );
    });

    test('millisecondsUntilTomorrowWithOffset', () {
      DateUtils.setFixedTimeZone(gmt);
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 23, 59));
      expect(
        DateUtils.millisecondsUntilTomorrowWithOffset(0, 0),
        DateUtils.minuteLength,
        reason: 'reminders.upcoming-time#12: at GMT 2017-01-01 23:59 with '
            'offset (0,0) it is 60000',
      );
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));
      expect(
        DateUtils.millisecondsUntilTomorrowWithOffset(0, 0),
        4 * DateUtils.hourLength,
        reason: 'reminders.upcoming-time#12: at 20:00 it is 14400000',
      );
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 23, 59));
      expect(
        DateUtils.millisecondsUntilTomorrowWithOffset(3, 30),
        3 * DateUtils.hourLength + 31 * DateUtils.minuteLength,
        reason: 'reminders.upcoming-time#12: at 23:59 with offset (3,30) it '
            'is 3h31m',
      );
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 2, 1, 0));
      expect(
        DateUtils.millisecondsUntilTomorrowWithOffset(3, 30),
        2 * DateUtils.hourLength + 30 * DateUtils.minuteLength,
        reason: 'reminders.upcoming-time#12: at 2017-01-02 01:00 with offset '
            '(3,30) it is 2h30m',
      );
      expect(
        DateUtils.millisecondsUntilTomorrowWithOffset(3, 30),
        DateUtils.getStartOfTomorrowWithOffset(3, 30) -
            DateUtils.applyTimezone(DateUtils.getLocalTime()),
        reason: 'reminders.upcoming-time#12: it is defined as '
            'getStartOfTomorrowWithOffset - applyTimezone(getLocalTime())',
      );
    });
  });

  // -----------------------------------------------------------------------
  // reminders.schedule-one-habit and reminders.schedule-at-time
  // -----------------------------------------------------------------------

  group('schedule', () {
    test('habit with null id is skipped', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.id = null;
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      reminderScheduler.schedule(habit);
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.schedule-one-habit#1: schedule() returns '
              'immediately when habit.id == null');
      expect(sys.logs, contains('Habit has null id. Returning.'),
          reason: 'reminders.schedule-one-habit#1: it logs '
              '"Habit has null id. Returning."');
    });

    test('habit without reminder is skipped', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      expect(habit.hasReminder(), isFalse,
          reason: 'reminders.schedule-one-habit#2: the fixture has no '
              'reminder');
      reminderScheduler.schedule(habit);
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.schedule-one-habit#2: nothing is scheduled for a '
              'habit without a reminder');
      expect(sys.logs, contains('habit=10 has no reminder. Skipping.'),
          reason: 'reminders.schedule-one-habit#2: it logs '
              '"habit=<id> has no reminder. Skipping."');
      expect(storage.readKeys, isEmpty,
          reason: 'reminders.schedule-one-habit#2: it returns before reading '
              'the snooze time');
    });

    test('without a snooze the reminder is the next occurrence', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 30));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      reminderScheduler.schedule(habit);
      expect(sys.scheduled.single.reminderTime,
          DateUtils.getUpcomingTimeInMillis(8, 30),
          reason: 'reminders.schedule-one-habit#3: reminderTime = '
              'getUpcomingTimeInMillis(reminder.hour, reminder.minute)');
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 26, 12, 30),
          reason: 'reminders.schedule-at-time#6: now = 2015-01-26 06:30 in '
              'GMT-4 with reminder 08:30 gives 2015-01-26 12:30 UTC');
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 26, 0, 0),
          reason: 'reminders.schedule-at-time#6: the checkmark timestamp is '
              '2015-01-26 00:00');
      expect(sys.scheduled.single.habit, same(habit),
          reason: 'reminders.schedule-one-habit#7: scheduleAtTime(habit, '
              'reminderTime) is called with the same habit');
    });

    test('a stored snooze of zero is not a snooze', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 6, 30));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.schedule-one-habit#4: the "no snooze" sentinel '
              'is 0');
      storage.writtenKeys.clear();
      reminderScheduler.schedule(habit);
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 26, 12, 30),
          reason: 'reminders.schedule-one-habit#4: with a snooze time of 0 '
              'the regular reminder time is used');
      expect(storage.writtenKeys, isEmpty,
          reason: 'reminders.schedule-one-habit#4: a snooze time of exactly 0 '
              'is not even discarded — nothing is written');
    });

    test('a snooze in the future replaces the reminder time', () {
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 1, 15, 0)));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      final snoozeTimeInFuture = unixTime(2015, 1, 1, 21, 0);
      widgetPreferences.setSnoozeTime(habitId, snoozeTimeInFuture);
      reminderScheduler.schedule(habit);
      expect(sys.scheduled.single.reminderTime, snoozeTimeInFuture,
          reason: 'reminders.schedule-one-habit#5: a snooze time greater than '
              'now replaces reminderTime');
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 1, 0, 0),
          reason: 'reminders.schedule-one-habit#8: the snoozed reminder of '
              '2015-01-01 21:00 carries checkmark timestamp 2015-01-01 00:00');
      expect(widgetPreferences.getSnoozeTime(habitId), snoozeTimeInFuture,
          reason: 'reminders.schedule-one-habit#5: an accepted snooze is kept');
    });

    test('a snooze in the past is discarded', () {
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 1, 15, 0)));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      final snoozeTimeInPast = unixTime(2015, 1, 1, 7, 0);
      widgetPreferences.setSnoozeTime(habitId, snoozeTimeInPast);
      reminderScheduler.schedule(habit);
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.schedule-one-habit#6: a snooze time at or before '
              'now is removed via removeSnoozeTime');
      expect(sys.scheduled.single.reminderTime,
          DateUtils.applyTimezone(unixTime(2015, 1, 2, 8, 30)),
          reason: 'reminders.schedule-one-habit#8: the regular reminder time '
              'is applyTimezone(2015-01-02 08:30)');
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 2, 0, 0),
          reason: 'reminders.schedule-one-habit#8: with the snooze dropped '
              'the checkmark timestamp is 2015-01-02 00:00');
    });

    test('a snooze exactly at now is discarded', () {
      final now = unixTime(2015, 1, 1, 15, 0);
      DateUtils.setFixedLocalTime(DateUtils.removeTimezone(now));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      widgetPreferences.setSnoozeTime(habitId, now);
      reminderScheduler.schedule(habit);
      expect(sys.scheduled.single.reminderTime, isNot(now),
          reason: 'reminders.schedule-one-habit#6: the comparison is strictly '
              'greater-than, so a snooze equal to now is discarded');
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.schedule-one-habit#6: the stored snooze is '
              'cleared');
    });

    test('concurrent schedule calls do not interleave', () async {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      final other = fixtures.createEmptyHabit(name: 'Read');
      other.id = 11;
      other.reminder = Reminder(18, 30, WeekdayList.everyDay);
      await Future.wait(<Future<void>>[
        Future<void>(() => reminderScheduler.schedule(habit)),
        Future<void>(() => reminderScheduler.schedule(other)),
      ]);
      final firstEnd = sys.calls.indexWhere((c) => c.startsWith('show:Meditate'));
      final secondStart =
          sys.calls.indexWhere((c) => c.contains('habit=11'));
      expect(firstEnd, lessThan(secondStart),
          reason: 'reminders.schedule-one-habit#9: schedule() is synchronized, '
              'so the first call finishes scheduling before the second starts');
      expect(sys.scheduled.length, 2,
          reason: 'reminders.schedule-one-habit#9: both calls complete');
    });
  });

  group('scheduleAtTime', () {
    test('skips a habit without a reminder', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      reminderScheduler.scheduleAtTime(habit, unixTime(2015, 1, 30, 11, 30));
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.schedule-at-time#1: scheduleAtTime skips a habit '
              'with no reminder');
      expect(sys.logs, contains('habit=10 has no reminder. Skipping.'),
          reason: 'reminders.schedule-at-time#1: it logs '
              '"has no reminder. Skipping."');
    });

    test('skips an archived habit', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habit.isArchived = true;
      reminderScheduler.scheduleAtTime(habit, unixTime(2015, 1, 30, 11, 30));
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.schedule-at-time#2: archived habits never fire '
              'reminders');
      expect(sys.logs, contains('habit=10 is archived. Skipping.'),
          reason: 'reminders.schedule-at-time#2: it logs '
              '"is archived. Skipping."');
    });

    test('derives the checkmark timestamp from the reminder instant', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      final atTime = unixTime(2015, 1, 30, 11, 30);
      reminderScheduler.scheduleAtTime(habit, atTime);
      expect(
        sys.scheduled.single.timestamp,
        DateUtils.getStartOfDayWithOffset(DateUtils.removeTimezone(atTime), 0, 0),
        reason: 'reminders.schedule-at-time#3: timestamp = '
            'getStartOfDayWithOffset(removeTimezone(reminderTime), 0, 0)',
      );
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 30, 0, 0),
          reason: 'reminders.schedule-at-time#5: in GMT-4, 2015-01-30 11:30 '
              'UTC belongs to checkmark day 2015-01-30 00:00');
      expect(sys.scheduled.single.reminderTime, atTime,
          reason: 'reminders.schedule-at-time#4: sys.scheduleShowReminder is '
              'called with the reminder instant unchanged');
      expect(sys.scheduled.single.habit, same(habit),
          reason: 'reminders.schedule-at-time#4: and with the habit');
      // 2015-01-30 01:00 UTC is 2015-01-29 21:00 in GMT-4: the checkmark day
      // follows the local calendar, not the UTC one.
      sys.clear();
      reminderScheduler.scheduleAtTime(habit, unixTime(2015, 1, 30, 1, 0));
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 29, 0, 0),
          reason: 'reminders.schedule-at-time#3: the reminder instant is '
              'converted to local-shifted millis with removeTimezone before '
              'being floored to midnight');
    });

    test('the midnight-delay preference is not applied', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(3, 0, WeekdayList.everyDay);
      // 2015-01-30 07:00 UTC is 03:00 local in GMT-4: before a 3:30 midnight
      // delay, yet the reminder still belongs to Jan 30.
      reminderScheduler.scheduleAtTime(habit, unixTime(2015, 1, 30, 7, 0));
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 30, 0, 0),
          reason: 'reminders.schedule-at-time#3 and '
              'settings.preferences.midnight-delay#12: the hour/minute offsets '
              'are hard-coded 0, so the midnight-delay preference is '
              'deliberately not applied by scheduleAtTime');
      // 2015-01-30 06:00 UTC is 02:00 local: strictly inside the 3-hour
      // window, so the two offsets disagree about which day it is.
      sys.clear();
      final insideTheDelay = unixTime(2015, 1, 30, 6, 0);
      reminderScheduler.scheduleAtTime(habit, insideTheDelay);
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 30, 0, 0),
          reason: 'settings.preferences.midnight-delay#12: scheduleAtTime '
              'still says Jan 30');
      expect(
        DateUtils.getStartOfDayWithOffset(
          DateUtils.removeTimezone(insideTheDelay),
          Preferences.midnightDelayHoursWhenEnabled,
          0,
        ),
        unixTime(2015, 1, 29, 0, 0),
        reason: 'settings.preferences.midnight-delay#12: had the 3-hour '
            'offset been passed through, the checkmark day would have been '
            'Jan 29 instead',
      );
    });

    test('tomorrow when the reminder time has passed', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      reminderScheduler.schedule(habit);
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 27, 12, 30),
          reason: 'reminders.schedule-at-time#7: now = 2015-01-26 13:00 in '
              'GMT-4 with reminder 08:30 gives 2015-01-27 12:30 UTC');
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 27, 0, 0),
          reason: 'reminders.schedule-at-time#7: with checkmark timestamp '
              '2015-01-27 00:00');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.schedule-all
  // -----------------------------------------------------------------------

  group('scheduleAll', () {
    test('WITH_ALARM is the matcher used', () {
      expect(
        HabitMatcher.withAlarm,
        const HabitMatcher(
          isArchivedAllowed: true,
          isReminderRequired: true,
          isCompletedAllowed: true,
          isEnteredAllowed: true,
          searchQuery: '',
        ),
        reason: 'reminders.schedule-all#2: HabitMatcher.WITH_ALARM allows '
            'archived, completed and entered habits and requires a reminder',
      );
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      reminderScheduler.scheduleAll();
      expect(habitList.filterRequests, contains(HabitMatcher.withAlarm),
          reason: 'reminders.schedule-all#1: scheduleAll() calls '
              'habitList.getFiltered(HabitMatcher.WITH_ALARM)');
      expect(sys.logs, contains('Scheduling all alarms'),
          reason: 'reminders.schedule-all#1: it logs "Scheduling all alarms"');
    });

    test('schedules every habit with a reminder', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      final h1 = fixtures.createEmptyHabit(name: 'h1');
      final h2 = fixtures.createEmptyHabit(name: 'h2');
      final h3 = fixtures.createEmptyHabit(name: 'h3');
      h1.reminder = Reminder(8, 30, WeekdayList.everyDay);
      h2.reminder = Reminder(18, 30, WeekdayList.everyDay);
      h3.reminder = null;
      habitList.add(h1);
      habitList.add(h2);
      habitList.add(h3);
      reminderScheduler.scheduleAll();
      expect(
        sys.scheduled
            .firstWhere((s) => identical(s.habit, h1))
            .reminderTime,
        unixTime(2015, 1, 27, 12, 30),
        reason: 'reminders.schedule-all#5: h1 (08:30) is scheduled at '
            '2015-01-27 12:30 UTC',
      );
      expect(
        sys.scheduled
            .firstWhere((s) => identical(s.habit, h2))
            .reminderTime,
        unixTime(2015, 1, 26, 22, 30),
        reason: 'reminders.schedule-all#5: h2 (18:30) is scheduled at '
            '2015-01-26 22:30 UTC',
      );
      expect(sys.scheduled.where((s) => identical(s.habit, h3)), isEmpty,
          reason: 'reminders.schedule-all#5: nothing is scheduled for h3',);
      expect(sys.scheduled.length, 2,
          reason: 'reminders.schedule-all#3: habits with reminder == null are '
              'excluded from scheduleAll entirely');
      expect(sys.logs.where((l) => l.contains('h3')), isEmpty,
          reason: 'reminders.schedule-all#3: h3 never even reaches schedule()');
    });

    test('archived habits pass the filter but are dropped', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      final archived = fixtures.createEmptyHabit(name: 'archived');
      archived.reminder = Reminder(8, 30, WeekdayList.everyDay);
      archived.isArchived = true;
      habitList.add(archived);
      reminderScheduler.scheduleAll();
      expect(habitList.getFiltered(HabitMatcher.withAlarm).toList(),
          contains(archived),
          reason: 'reminders.schedule-all#2: archived habits pass the '
              'WITH_ALARM filter');
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.schedule-all#2: and are dropped later inside '
              'scheduleAtTime');
    });

    test('hasHabitsWithReminders', () {
      expect(reminderScheduler.hasHabitsWithReminders(), isFalse,
          reason: 'reminders.schedule-all#4: false when no habit carries a '
              'reminder');
      final withReminder = fixtures.createEmptyHabit(name: 'with');
      withReminder.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(withReminder);
      expect(reminderScheduler.hasHabitsWithReminders(), isTrue,
          reason: 'reminders.schedule-all#4: true iff '
              'getFiltered(WITH_ALARM) is non-empty');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.reschedule-on-command
  // -----------------------------------------------------------------------

  group('onCommandFinished', () {
    late Habit scheduled;

    setUp(() {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      scheduled = fixtures.createEmptyHabit(name: 'scheduled');
      scheduled.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(scheduled);
      sys.clear();
    });

    test('CreateRepetitionCommand and ChangeHabitColorCommand are ignored', () {
      reminderScheduler.onCommandFinished(CreateRepetitionCommand(
          habitList, scheduled, LocalDate.ymd(2015, 1, 26), 1000, ''));
      expect(sys.calls, isEmpty,
          reason: 'reminders.reschedule-on-command#1: onCommandFinished '
              'returns without doing anything for CreateRepetitionCommand');
      reminderScheduler.onCommandFinished(ChangeHabitColorCommand(
          habitList, <Habit>[scheduled], const PaletteColor(5)));
      expect(sys.calls, isEmpty,
          reason: 'reminders.reschedule-on-command#1: and for '
              'ChangeHabitColorCommand');
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.reschedule-on-command#3: checking off a habit or '
              'changing its color does not re-arm any alarm');
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.reschedule-on-command#6: ticking a checkmark and '
              'recolouring cannot change any reminder');
    });

    test('every other command reschedules everything', () {
      final commands = <Command>[
        CreateHabitCommand(MemoryModelFactory(), habitList, scheduled),
        EditHabitCommand(habitList, scheduled.id!, scheduled),
        DeleteHabitsCommand(habitList, <Habit>[]),
        ArchiveHabitsCommand(habitList, <Habit>[]),
        UnarchiveHabitsCommand(habitList, <Habit>[]),
      ];
      for (final command in commands) {
        sys.clear();
        reminderScheduler.onCommandFinished(command);
        expect(sys.logs, contains('Scheduling all alarms'),
            reason: 'reminders.reschedule-on-command#1: onCommandFinished '
                'calls scheduleAll() for ${command.runtimeType}');
        expect(sys.scheduled.length, 1,
            reason: 'reminders.reschedule-on-command#3: creating, editing, '
                'deleting, archiving or unarchiving re-arms every alarm '
                '(${command.runtimeType})');
      }
      expect(commands.length, 5,
          reason: 'reminders.reschedule-on-command#6: creating, editing, '
              'deleting, archiving and unarchiving all can change a reminder');
    });

    test('startListening and stopListening', () {
      reminderScheduler.startListening();
      commandRunner.notifyListeners(DeleteHabitsCommand(habitList, <Habit>[]));
      expect(sys.logs, contains('Scheduling all alarms'),
          reason: 'reminders.reschedule-on-command#2: startListening() '
              'registers the scheduler with the CommandRunner');
      sys.clear();
      reminderScheduler.stopListening();
      commandRunner.notifyListeners(DeleteHabitsCommand(habitList, <Habit>[]));
      expect(sys.calls, isEmpty,
          reason: 'reminders.reschedule-on-command#2: stopListening() '
              'unregisters it');
    });

    test('scheduleAll re-schedules without cancelling', () {
      reminderScheduler.scheduleAll();
      reminderScheduler.scheduleAll();
      expect(sys.scheduled.length, 2,
          reason: 'reminders.reschedule-on-command#7: scheduleAll() iterates '
              'the filtered list and calls schedule(habit) on each; it does '
              'not cancel previously scheduled alarms explicitly');
      expect(sys.widgetUpdates, isEmpty,
          reason: 'reminders.reschedule-on-command#7: nothing else is asked '
              'of the platform scheduler');
    });

    test('schedule skips null ids and honours a live snooze', () {
      final orphan = fixtures.createEmptyHabit(name: 'orphan');
      orphan.reminder = Reminder(8, 30, WeekdayList.everyDay);
      orphan.id = null;
      reminderScheduler.schedule(orphan);
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.reschedule-on-command#8: schedule(habit) skips '
              'habits with a null id');
      final noReminder = fixtures.createEmptyHabit(name: 'no reminder');
      noReminder.id = 77;
      reminderScheduler.schedule(noReminder);
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.reschedule-on-command#8: and habits without a '
              'reminder');
      final snoozed = unixTime(2015, 1, 26, 23, 0);
      widgetPreferences.setSnoozeTime(scheduled.id!, snoozed);
      reminderScheduler.schedule(scheduled);
      expect(sys.scheduled.single.reminderTime, snoozed,
          reason: 'reminders.reschedule-on-command#8: a non-zero snooze time '
              'still in the future is used');
      sys.clear();
      widgetPreferences.setSnoozeTime(scheduled.id!, unixTime(2015, 1, 26, 1, 0));
      reminderScheduler.schedule(scheduled);
      expect(widgetPreferences.getSnoozeTime(scheduled.id!), 0,
          reason: 'reminders.reschedule-on-command#8: otherwise the stored '
              'snooze time is cleared');
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 27, 12, 30),
          reason: 'reminders.reschedule-on-command#8: and the reminder time '
              'is the next occurrence of reminder.hour:reminder.minute');
    });

    test('archiving removes a habit on the next scheduleAll pass', () {
      reminderScheduler.scheduleAll();
      expect(sys.scheduled.length, 1,
          reason: 'reminders.reschedule-on-command#9: the habit is scheduled '
              'while active');
      scheduled.isArchived = true;
      sys.clear();
      reminderScheduler.scheduleAll();
      expect(sys.scheduled, isEmpty,
          reason: 'reminders.reschedule-on-command#9: scheduleAtTime skips '
              'archived habits, so archiving removes it from future '
              'scheduling on the next scheduleAll pass');
    });

    test('the scheduler methods run to completion without suspending',
        () async {
      final second = fixtures.createEmptyHabit(name: 'second');
      second.reminder = Reminder(18, 30, WeekdayList.everyDay);
      habitList.add(second);
      sys.clear();
      await Future.wait(<Future<void>>[
        Future<void>(() => reminderScheduler.scheduleAll()),
        Future<void>(() => reminderScheduler.scheduleAll()),
      ]);
      final firstRun = sys.calls.indexOf('log:Scheduling all alarms');
      final secondRun = sys.calls.lastIndexOf('log:Scheduling all alarms');
      final between = sys.calls.sublist(firstRun, secondRun);
      expect(between.where((c) => c.startsWith('show:')).length, 2,
          reason: 'reminders.reschedule-on-command#10: every method is '
              '@Synchronized, so one scheduleAll() finishes before the next '
              'one starts');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.snooze-storage
  // -----------------------------------------------------------------------

  group('snooze storage', () {
    test('key format, default and sentinel', () {
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.snooze-storage#2: getSnoozeTime returns '
              'storage.getLong(key, 0); the default and the "no snooze" '
              'sentinel are both 0');
      expect(storage.readKeys, contains('snooze-000010'),
          reason: 'reminders.snooze-storage#1: the key is '
              'format("snooze-%06d", habitId.toInt()) — habit 10 gives '
              '"snooze-000010"');
      widgetPreferences.setSnoozeTime(habitId, 1420070400000);
      expect(storage.writtenKeys, contains('snooze-000010'),
          reason: 'reminders.snooze-storage#1: the same key is written');
      expect(widgetPreferences.getSnoozeTime(habitId), 1420070400000,
          reason: 'reminders.snooze-storage#4: setSnoozeTime writes the '
              'absolute UTC epoch-millis instant');
    });

    test('removeSnoozeTime writes 0 rather than deleting', () {
      widgetPreferences.setSnoozeTime(habitId, 1420070400000);
      widgetPreferences.removeSnoozeTime(habitId);
      expect(storage.writtenLongs.last, 0,
          reason: 'reminders.snooze-storage#3: removeSnoozeTime writes 0 to '
              'the key');
      expect(storage.removedKeys, isEmpty,
          reason: 'reminders.snooze-storage#3: it does not delete the key');
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.snooze-storage#3: reading it back gives the '
              'sentinel');
    });

    test('snooze state survives a restart', () {
      widgetPreferences.setSnoozeTime(habitId, 1420070400000);
      final afterRestart = WidgetPreferences(storage);
      expect(afterRestart.getSnoozeTime(habitId), 1420070400000,
          reason: 'reminders.snooze-storage#5: snooze state lives in '
              'preferences, not in memory, so it survives restarts and '
              'reboots');
    });

    test('the habit id is narrowed to Int before formatting', () {
      const int beyondInt = 4294967296 + 10; // 2^32 + 10
      widgetPreferences.setSnoozeTime(beyondInt, 999);
      expect(storage.writtenKeys.last, 'snooze-000010',
          reason: 'reminders.snooze-storage#6: the Long habit id is narrowed '
              'to Int before formatting');
      expect(widgetPreferences.getSnoozeTime(habitId), 999,
          reason: 'reminders.snooze-storage#6: so ids beyond Int range '
              'collide with small ids');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.snooze-by-delay
  // -----------------------------------------------------------------------

  group('snoozeReminder', () {
    test('stores now + minutes and reschedules', () {
      final localNow = DateUtils.removeTimezone(unixTime(2015, 1, 26, 13, 0));
      DateUtils.setFixedLocalTime(localNow);
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(habit);
      reminderScheduler.snoozeReminder(habit, 30);
      final expected = unixTime(2015, 1, 26, 13, 30);
      expect(widgetPreferences.getSnoozeTime(habitId), expected,
          reason: 'reminders.snooze-by-delay#1: snoozeReminder stores '
              'applyTimezone(getLocalTime()) + minutes * 60 * 1000');
      expect(sys.scheduled.single.reminderTime, expected,
          reason: 'reminders.snooze-by-delay#1: and then calls '
              'schedule(habit), which picks the snooze up');
      expect(sys.scheduled.single.timestamp, unixTime(2015, 1, 26, 0, 0),
          reason: 'reminders.snooze-by-delay#1: the checkmark timestamp still '
              'comes from the reminder instant');
    });

    test('a later scheduleAll re-honours the stored snooze', () {
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 26, 13, 0)));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(habit);
      reminderScheduler.snoozeReminder(habit, 120);
      final snoozedUntil = unixTime(2015, 1, 26, 15, 0);
      sys.clear();
      reminderScheduler.scheduleAll();
      expect(sys.scheduled.single.reminderTime, snoozedUntil,
          reason: 'reminders.snooze-by-delay#2: because the value is '
              'persisted, a later scheduleAll() re-honours the snooze');
      // Two hours later the snooze has expired.
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 26, 15, 0)));
      sys.clear();
      reminderScheduler.scheduleAll();
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 27, 12, 30),
          reason: 'reminders.snooze-by-delay#2: until it expires — then the '
              'regular reminder time comes back');
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.snooze-by-delay#2: and the expired value is '
              'cleared');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.boot-reschedule
  // -----------------------------------------------------------------------

  group('reminders.boot-reschedule', () {
    /// Everything the process owned is rebuilt; only the preference store —
    /// the one thing that survives a reboot — is carried over.
    ReminderScheduler reboot() => ReminderScheduler(
          CommandRunner(
            CoroutineTaskRunner(
              mainDispatcher: const UnconfinedTestDispatcher(),
              ioDispatcher: const UnconfinedTestDispatcher(),
            ),
          ),
          habitList,
          sys,
          WidgetPreferences(storage),
        );

    test('#4 a snooze outlives the reboot while it is still in the future', () {
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 26, 13, 0)));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(habit);
      reminderScheduler.snoozeReminder(habit, 120);
      final int snoozedUntil = unixTime(2015, 1, 26, 15, 0);
      sys.clear();

      // ReminderController.onBootCompleted() does exactly one thing:
      // reminderScheduler.scheduleAll().
      reboot().scheduleAll();

      expect(sys.scheduled.single.reminderTime, snoozedUntil,
          reason: 'reminders.boot-reschedule#4: because snooze times are '
              'persisted, a habit snoozed before the reboot keeps its snooze '
              'after the reboot as long as the snoozed-until instant is still '
              'in the future');
      expect(widgetPreferences.getSnoozeTime(habitId), snoozedUntil,
          reason: 'reminders.boot-reschedule#4: the stored instant is what '
              'carries the snooze across the process boundary');
    });

    test('#4 a snooze whose instant has passed does not', () {
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 26, 13, 0)));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(habit);
      reminderScheduler.snoozeReminder(habit, 120);
      sys.clear();

      // The reboot happens after the snooze has expired.
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 26, 16, 0)));
      reboot().scheduleAll();

      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 27, 12, 30),
          reason: 'reminders.boot-reschedule#4: the snooze is kept only "as '
              'long as the snoozed-until instant is still in the future" — '
              'otherwise the regular reminder time comes back');
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.boot-reschedule#4: and the expired value is '
              'discarded by the same scheduleAll that read it');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.snooze-custom-time
  // -----------------------------------------------------------------------

  group('custom-time snooze', () {
    test('scheduleAtTime with the upcoming wall-clock time', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      final time = DateUtils.getUpcomingTimeInMillis(20, 15);
      reminderScheduler.scheduleAtTime(habit, time);
      expect(sys.scheduled.single.reminderTime, time,
          reason: 'reminders.snooze-custom-time#1: the picked hour:minute is '
              'turned into an instant with getUpcomingTimeInMillis and handed '
              'to scheduleAtTime');
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 27, 0, 15),
          reason: 'reminders.snooze-custom-time#3: 20:15 local in GMT-4 is '
              '00:15 UTC the next day');
    });

    test('a custom time still ahead today lands today', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      reminderScheduler.scheduleAtTime(
          habit, DateUtils.getUpcomingTimeInMillis(14, 0));
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 26, 18, 0),
          reason: 'reminders.snooze-custom-time#3: 14:00 is still ahead of '
              '13:00, so the alarm lands today');
      sys.clear();
      reminderScheduler.scheduleAtTime(
          habit, DateUtils.getUpcomingTimeInMillis(12, 0));
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 27, 16, 0),
          reason: 'reminders.snooze-custom-time#3: 12:00 has passed, so it '
              'lands tomorrow');
    });

    test('nothing is written to the preferences', () {
      DateUtils.setFixedLocalTime(unixTime(2015, 1, 26, 13, 0));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(habit);
      storage.writtenKeys.clear();
      reminderScheduler.scheduleAtTime(
          habit, DateUtils.getUpcomingTimeInMillis(20, 15));
      expect(storage.writtenKeys, isEmpty,
          reason: 'reminders.snooze-custom-time#2: custom-time snooze does '
              'NOT write anything to WidgetPreferences');
      expect(widgetPreferences.getSnoozeTime(habitId), 0,
          reason: 'reminders.snooze-custom-time#2: no snooze time is stored');
      sys.clear();
      reminderScheduler.scheduleAll();
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 27, 12, 30),
          reason: 'reminders.snooze-custom-time#2: therefore a later '
              'scheduleAll() overwrites the one-off alarm with the habit\'s '
              'regular reminder time');
    });
  });

  // -----------------------------------------------------------------------
  // reminders.dependency-wiring / reminders.app-start-and-permission
  // -----------------------------------------------------------------------

  group('object graph', () {
    test('ReminderScheduler is built from commandRunner, habitList, the '
        'system scheduler and the widget preferences', () {
      final scheduler = ReminderScheduler(
        commandRunner,
        habitList,
        sys,
        widgetPreferences,
      );

      expect(scheduler, isA<CommandRunnerListener>(),
          reason: 'reminders.dependency-wiring#1: ReminderScheduler is '
              'constructed as ReminderScheduler(commandRunner, habitList, '
              'sys = IntentScheduler, widgetPreferences), and the command '
              'runner argument is there because it registers itself as a '
              'listener');

      // Each of the four arguments is actually used, which is the only way to
      // tell them apart from the outside.
      DateUtils.setFixedLocalTime(
          DateUtils.removeTimezone(unixTime(2015, 1, 26, 13, 0)));
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.add(habit);
      widgetPreferences.setSnoozeTime(habitId, unixTime(2015, 1, 26, 15, 0));
      sys.clear();

      scheduler.startListening();
      commandRunner.run(EditHabitCommand(habitList, habitId, habit));

      expect(sys.scheduled.single.habit, same(habit),
          reason: 'reminders.dependency-wiring#1: the habitList argument is '
              'what scheduleAll() iterates and the sys argument is what '
              'receives the alarm');
      expect(sys.scheduled.single.reminderTime, unixTime(2015, 1, 26, 15, 0),
          reason: 'reminders.dependency-wiring#1: the widgetPreferences '
              'argument is where the snooze time comes from');
      scheduler.stopListening();
    });

    test('no habit with a reminder means nothing to ask permission for', () {
      expect(reminderScheduler.hasHabitsWithReminders(), isFalse,
          reason: 'reminders.app-start-and-permission#6: if the user has zero '
              'habits with reminders, no permission is ever requested');

      final withoutReminder = fixtures.createEmptyHabit(name: 'no reminder');
      habitList.add(withoutReminder);
      expect(reminderScheduler.hasHabitsWithReminders(), isFalse,
          reason: 'reminders.app-start-and-permission#6: a habit without a '
              'reminder does not open the permission gate either');

      final archived = fixtures.createEmptyHabit(name: 'archived');
      archived.reminder = Reminder(8, 30, WeekdayList.everyDay);
      archived.isArchived = true;
      habitList.add(archived);
      expect(reminderScheduler.hasHabitsWithReminders(), isTrue,
          reason: 'reminders.app-start-and-permission#6: the gate is '
              'getFiltered(WITH_ALARM), which does include archived habits');

      expect(reminderScheduler.hasHabitsWithReminders(), isTrue,
          reason: 'platform-glue.permissions#6 — If there are no habits with '
              'reminders, the permission is never requested at all. '
              'hasHabitsWithReminders() is that gate, and it is the whole of '
              'the rule that is portable: the once-per-activity guard and the '
              'SDK_INT check around it are Activity lifecycle and have no '
              'counterpart here.');
    });

    test('the permission gate opens only once a reminder exists', () {
      // The gate, walked from empty to armed, because "never requested at all"
      // is a statement about the false case rather than the true one.
      expect(reminderScheduler.hasHabitsWithReminders(), isFalse,
          reason: 'platform-glue.permissions#6: an empty list asks for '
              'nothing');

      final plain = fixtures.createEmptyHabit(name: 'plain');
      habitList.add(plain);
      expect(reminderScheduler.hasHabitsWithReminders(), isFalse,
          reason: 'platform-glue.permissions#6: nor does a habit that would '
              'never post a notification');

      plain.reminder = Reminder(8, 30, WeekdayList.everyDay);
      habitList.update(<Habit>[plain]);
      expect(reminderScheduler.hasHabitsWithReminders(), isTrue,
          reason: 'platform-glue.permissions#6: giving it a reminder is what '
              'opens the gate');

      plain.reminder = null;
      habitList.update(<Habit>[plain]);
      expect(reminderScheduler.hasHabitsWithReminders(), isFalse,
          reason: 'platform-glue.permissions#6: and taking it away closes it '
              'again');
    });
  });
}
