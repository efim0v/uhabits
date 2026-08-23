/// Ported from
/// uhabits-core/src/jvmTest/java/org/isoron/uhabits/core/utils/MidnightTimerTest.kt
/// and uhabits-core/src/jvmTest/java/org/isoron/platform/time/DateUtilsTest.kt,
/// plus the rules in docs/parity/FEATURES.md for `time.midnight-timer` and
/// `time.today-and-day-boundary`.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

const int _second = 1000;
const int _minute = 60 * _second;
const int _hour = 60 * _minute;
const int _day = 24 * _hour;

/// Port of `unixTime` from
/// uhabits-core/src/jvmTest/java/org/isoron/platform/time/TestHelpers.kt: a GMT
/// wall clock converted to epoch millis.
int unixTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int milliseconds = 0,
]) =>
    LocalDate.ymd(year, month, day).unixTime +
    hour * _hour +
    minute * _minute +
    milliseconds;

/// Stand-in for the `testExecutor` that MidnightTimerTest injects: it records
/// the schedule instead of running it, so the timing arithmetic is observable
/// without waiting a day.
class _RecordingExecutor implements ScheduledExecutorService {
  final List<void Function()> commands = <void Function()>[];
  int? initialDelayMillis;
  int? periodMillis;
  bool isShutdown = false;

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelay,
    int period,
  ) {
    commands.add(command);
    initialDelayMillis = initialDelay;
    periodMillis = period;
  }

  @override
  List<void Function()> shutdownNow() {
    isShutdown = true;
    final pending = List<void Function()>.of(commands);
    commands.clear();
    return pending;
  }

  /// Runs every scheduled command once, as one tick of the fixed-rate schedule.
  void tick() {
    for (final command in List<void Function()>.of(commands)) {
      command();
    }
  }
}

class _CountingListener implements MidnightListener {
  int count = 0;

  @override
  void atMidnight() => count++;
}

void main() {
  late MemoryStorage storage;
  late Preferences prefs;
  late MidnightTimer timer;
  late _RecordingExecutor executor;
  late StringBuffer log;

  setUp(() {
    storage = MemoryStorage();
    prefs = Preferences(storage);
    log = StringBuffer();
    timer = MidnightTimer(StandardLogging(out: log, err: log), prefs);
    executor = _RecordingExecutor();
    DateUtils.setFixedTimeZone(gmt);
    DateUtils.setFixedLocalTime(null);
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    getDefaultTimeZone = systemDefaultTimeZone;
    resetToday();
  });

  /// Pins `System.currentTimeMillis()` and `TimeZone.getDefault()`, the two
  /// pieces of ambient state `computeToday` reads.
  void pinClock(int nowMillis, {int timeZoneOffsetMillis = 0}) {
    systemCurrentTimeMillis = () => nowMillis;
    getDefaultTimeZone = () => FixedTimeZone(timeZoneOffsetMillis);
  }

  group('time.midnight-timer', () {
    test('#1 onResume schedules notifyListeners at a fixed daily rate', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));

      timer.onResume(DateUtils.secondLength, executor);

      expect(executor.commands, hasLength(1),
          reason: 'time.midnight-timer#1');
      expect(
        executor.initialDelayMillis,
        DateUtils.millisecondsUntilTomorrowWithOffset(
              prefs.midnightDelayHours,
              0,
            ) +
            DateUtils.secondLength,
        reason: 'time.midnight-timer#1',
      );
      expect(executor.initialDelayMillis, 4 * _hour + 1000,
          reason: 'time.midnight-timer#1');
      expect(executor.periodMillis, DateUtils.dayLength,
          reason: 'time.midnight-timer#1');
      expect(DateUtils.dayLength, 86400000,
          reason: 'time.midnight-timer#1');
      expect(DateUtils.secondLength, 1000, reason: 'time.midnight-timer#1');
    });

    test('#1 the initial delay follows the midnight delay preference', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));
      prefs.isMidnightDelayEnabled = true;

      timer.onResume(DateUtils.secondLength, executor);

      expect(prefs.midnightDelayHours, 3, reason: 'time.midnight-timer#1');
      expect(executor.initialDelayMillis, 7 * _hour + 1000,
          reason: 'time.midnight-timer#1');
    });

    test('#1 without a test executor a single-threaded one is created', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));

      timer.onResume();

      // Nothing to observe but the pending task the created executor holds.
      expect(timer.onPause(), hasLength(1), reason: 'time.midnight-timer#1');
    });

    test('#2 the default 1000 ms offset lands strictly after midnight', () {
      DateUtils.setFixedLocalTime(
        unixTime(2017, 1, 1, 23, 59, DateUtils.minuteLength - 1),
      );

      timer.onResume(DateUtils.secondLength, executor);

      final untilMidnight =
          DateUtils.millisecondsUntilTomorrowWithOffset(0, 0);
      expect(untilMidnight, 1, reason: 'time.midnight-timer#2');
      expect(executor.initialDelayMillis, greaterThan(untilMidnight),
          reason: 'time.midnight-timer#2');
      expect(executor.initialDelayMillis, untilMidnight + 1000,
          reason: 'time.midnight-timer#2');
    });

    test('#3 onPause shuts the executor down and returns pending tasks', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));
      timer.onResume(DateUtils.secondLength, executor);

      final pending = timer.onPause();

      expect(executor.isShutdown, isTrue, reason: 'time.midnight-timer#3');
      expect(pending, hasLength(1), reason: 'time.midnight-timer#3');
    });

    test('#3 onPause before any onResume throws, like the lateinit field', () {
      expect(
        () => timer.onPause(),
        throwsA(
          predicate<Object>(
            (e) =>
                e is Error &&
                e.toString().contains('LateInitializationError'),
          ),
        ),
        reason: 'time.midnight-timer#3',
      );
    });

    test('#4 notifyListeners sets today first, then notifies in order', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));
      pinClock(unixTime(2017, 1, 2, 0, 0, 5));
      setToday(LocalDate.ymd(2017, 1, 1));

      final events = <String>[];
      timer.addListener(
        MidnightListener.of(() => events.add('first ${getToday()
            .toCSVString()}')),
      );
      timer.addListener(
        MidnightListener.of(() => events.add('second ${getToday()
            .toCSVString()}')),
      );
      timer.onResume(DateUtils.secondLength, executor);

      executor.tick();

      expect(events, <String>['first 2017-01-02', 'second 2017-01-02'],
          reason: 'time.midnight-timer#4');
    });

    test('#4 the midnight delay preference reaches computeToday', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 2, 1, 0));
      prefs.isMidnightDelayEnabled = true;
      // 01:00 local on Jan 2: with the 3h delay this is still Jan 1.
      pinClock(unixTime(2017, 1, 2, 1, 0));
      setToday(LocalDate.ymd(2016, 12, 31));

      timer.addListener(_CountingListener());
      timer.onResume(DateUtils.secondLength, executor);
      executor.tick();

      expect(getToday(), LocalDate.ymd(2017, 1, 1),
          reason: 'time.midnight-timer#4');
    });

    test('#5 the notify loop is one critical section', () async {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));
      pinClock(unixTime(2017, 1, 2, 0, 0, 5));
      setToday(LocalDate.ymd(2017, 1, 1));

      // Dart has no `synchronized`: the isolate's single thread is the monitor,
      // so no other task can run between two listeners.
      final order = <String>[];
      timer.addListener(MidnightListener.of(() {
        order.add('listener-1');
        scheduleMicrotask(() => order.add('other-task'));
      }));
      timer.addListener(MidnightListener.of(() => order.add('listener-2')));
      timer.onResume(DateUtils.secondLength, executor);

      executor.tick();

      expect(order, <String>['listener-1', 'listener-2'],
          reason: 'time.midnight-timer#5');
      await Future<void>.delayed(Duration.zero);
      expect(order, <String>['listener-1', 'listener-2', 'other-task'],
          reason: 'time.midnight-timer#5');
    });

    test('#5 a reentrant addListener hits the live listener list', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));
      pinClock(unixTime(2017, 1, 2, 0, 0, 5));
      setToday(LocalDate.ymd(2017, 1, 1));

      // Kotlin's monitor is reentrant, so the nested addListener succeeds and
      // the ongoing iteration over the live list then fails. Dart behaves the
      // same way, with ConcurrentModificationError.
      timer.addListener(MidnightListener.of(() {
        timer.addListener(_CountingListener());
      }));
      timer.onResume(DateUtils.secondLength, executor);

      expect(() => executor.tick(),
          throwsA(isA<ConcurrentModificationError>()),
          reason: 'time.midnight-timer#5');
    });

    test('#6 MidnightListener has the single method atMidnight', () {
      var count = 0;
      final lambda = MidnightListener.of(() => count++);
      lambda.atMidnight();
      expect(count, 1, reason: 'time.midnight-timer#6');

      final subclass = _CountingListener();
      subclass.atMidnight();
      expect(subclass.count, 1, reason: 'time.midnight-timer#6');

      timer.addListener(lambda);
      expect(timer.removeListener(lambda), isTrue,
          reason: 'time.midnight-timer#6');
      expect(timer.removeListener(lambda), isFalse,
          reason: 'time.midnight-timer#6');
    });

    test('#7 regression: fires at GMT 2017-01-01 23:59:59.999', () async {
      DateUtils.setFixedTimeZone(gmt);
      DateUtils.setFixedLocalTime(
        unixTime(2017, 1, 1, 23, 59, DateUtils.minuteLength - 1),
      );
      pinClock(unixTime(2017, 1, 2, 0, 0, 1));
      setToday(LocalDate.ymd(2017, 1, 1));

      final fired = Completer<bool>();
      timer.addListener(MidnightListener.of(() {
        if (!fired.isCompleted) fired.complete(true);
      }));

      timer.onResume(1, SingleThreadScheduledExecutor());

      expect(await fired.future.timeout(const Duration(seconds: 5)), isTrue,
          reason: 'time.midnight-timer#7');
      expect(getToday(), LocalDate.ymd(2017, 1, 2),
          reason: 'time.midnight-timer#7');
      timer.onPause();
    });
  });

  group('time.today-and-day-boundary', () {
    test('#1 #10 today is a process-global mutable LocalDate', () {
      resetToday();
      expect(
        () => getToday(),
        throwsA(
          predicate<Object>((e) =>
              e is StateError &&
              e.message == 'getToday() called before setToday()'),
        ),
        reason: 'time.today-and-day-boundary#1',
      );

      setToday(LocalDate.ymd(2015, 1, 25));
      expect(getToday(), LocalDate.ymd(2015, 1, 25),
          reason: 'time.today-and-day-boundary#10');
      setToday(LocalDate.ymd(2017, 1, 2));
      expect(getToday(), LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#10');

      resetToday();
      expect(() => getToday(), throwsStateError,
          reason: 'time.today-and-day-boundary#10');
    });

    test('#2 the day-dependent model reads the global today', () {
      final habit = MemoryModelFactory().buildHabit();
      habit.originalEntries
          .add(Entry(LocalDate.ymd(2015, 1, 25), Entry.yesManual));

      setToday(LocalDate.ymd(2015, 1, 25));
      habit.recompute();
      expect(habit.isCompletedToday(), isTrue,
          reason: 'time.today-and-day-boundary#2');
      expect(habit.isEnteredToday(), isTrue,
          reason: 'time.today-and-day-boundary#2');
      expect(habit.scores[LocalDate.ymd(2015, 1, 25)].value, greaterThan(0.0),
          reason: 'time.today-and-day-boundary#2');
      expect(habit.scores[LocalDate.ymd(2015, 2, 24)].value, greaterThan(0.0),
          reason: 'time.today-and-day-boundary#2');

      // Roll the global forward: the very same habit answers differently.
      setToday(LocalDate.ymd(2015, 1, 26));
      expect(habit.isCompletedToday(), isFalse,
          reason: 'time.today-and-day-boundary#2');
      expect(habit.isEnteredToday(), isFalse,
          reason: 'time.today-and-day-boundary#2');

      // Habit.recompute reads it too: scores now reach today + 30 days.
      expect(habit.scores[LocalDate.ymd(2015, 2, 25)].value, 0.0,
          reason: 'time.today-and-day-boundary#2');
      habit.recompute();
      expect(habit.scores[LocalDate.ymd(2015, 2, 25)].value, greaterThan(0.0),
          reason: 'time.today-and-day-boundary#2');
    });

    test('#3 #8 computeToday folds the timezone offset into the day', () {
      pinClock(unixTime(2017, 1, 1, 23, 0));
      expect(computeToday(0, 0), LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#3');

      // Sydney (UTC+11) is already on Jan 2 at 20:00 UTC on Jan 1.
      pinClock(unixTime(2017, 1, 1, 20, 0), timeZoneOffsetMillis: 11 * _hour);
      expect(computeToday(0, 0), LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#8');

      // ... and Honolulu (UTC-10) is still on Dec 31.
      pinClock(unixTime(2017, 1, 1, 5, 0), timeZoneOffsetMillis: -10 * _hour);
      expect(computeToday(0, 0), LocalDate.ymd(2016, 12, 31),
          reason: 'time.today-and-day-boundary#8');
    });

    test('#3 #8 the offset is subtracted and the division floors', () {
      pinClock(unixTime(2017, 1, 2, 2, 59, 59999));
      expect(computeToday(3, 0), LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#3');
      expect(computeToday(3, 30), LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#3');

      pinClock(unixTime(2017, 1, 2, 3, 0));
      expect(computeToday(3, 0), LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#3');
      expect(computeToday(3, 30), LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#3');
      expect(computeToday(0, 0), LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#3');

      // floorDiv, not truncation: one hour before the 1970 epoch is 1969-12-31.
      pinClock(0);
      expect(computeToday(1, 0), LocalDate.ymd(1969, 12, 31),
          reason: 'time.today-and-day-boundary#8');
      expect(computeToday(0, 0), LocalDate.ymd(1970, 1, 1),
          reason: 'time.today-and-day-boundary#8');
    });

    test('#9 10957 is the day count between 1970-01-01 and 2000-01-01', () {
      expect(LocalDate.ymd(1970, 1, 1).daysSince2000, -10957,
          reason: 'time.today-and-day-boundary#9');
      pinClock(0);
      expect(computeToday(0, 0).daysSince2000, -10957,
          reason: 'time.today-and-day-boundary#9');
      pinClock(LocalDate.ymd(2000, 1, 1).unixTime);
      expect(computeToday(0, 0).daysSince2000, 0,
          reason: 'time.today-and-day-boundary#9');
    });

    test('#4 the midnight delay preference shifts the day boundary', () {
      expect(Preferences.midnightDelayHoursWhenEnabled, 3,
          reason: 'time.today-and-day-boundary#4');
      expect(prefs.midnightDelayHours, 0,
          reason: 'time.today-and-day-boundary#4');
      expect(storage.getString('pref_midnight_delay', ''), '',
          reason: 'time.today-and-day-boundary#4');

      prefs.isMidnightDelayEnabled = true;
      expect(storage.getString('pref_midnight_delay', ''), 'true',
          reason: 'time.today-and-day-boundary#4');
      expect(prefs.midnightDelayHours, 3,
          reason: 'time.today-and-day-boundary#4');

      // 00:00 and 02:59 local still count as the previous day; 03:00 does not.
      pinClock(unixTime(2017, 1, 2, 0, 0));
      expect(computeToday(prefs.midnightDelayHours, 0),
          LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#4');
      pinClock(unixTime(2017, 1, 2, 2, 59));
      expect(computeToday(prefs.midnightDelayHours, 0),
          LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#4');
      pinClock(unixTime(2017, 1, 2, 3, 0));
      expect(computeToday(prefs.midnightDelayHours, 0),
          LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#4');

      prefs.isMidnightDelayEnabled = false;
      expect(prefs.midnightDelayHours, 0,
          reason: 'time.today-and-day-boundary#4');
      pinClock(unixTime(2017, 1, 2, 0, 0));
      expect(computeToday(prefs.midnightDelayHours, 0),
          LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#4');
    });

    test('#5 #11 the timer re-dates the world and then notifies', () {
      DateUtils.setFixedLocalTime(unixTime(2017, 1, 1, 20, 0));
      pinClock(unixTime(2017, 1, 2, 0, 0, 1));
      setToday(LocalDate.ymd(2017, 1, 1));

      final listener = _CountingListener();
      timer.addListener(listener);
      timer.onResume(DateUtils.secondLength, executor);

      expect(
        executor.initialDelayMillis,
        DateUtils.millisecondsUntilTomorrowWithOffset(
              prefs.midnightDelayHours,
              0,
            ) +
            1000,
        reason: 'time.today-and-day-boundary#5',
      );
      expect(executor.periodMillis, 86400000,
          reason: 'time.today-and-day-boundary#5');

      executor.tick();
      expect(getToday(), LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#5');
      expect(listener.count, 1, reason: 'time.today-and-day-boundary#5');

      // Only the MidnightTimer.notifyListeners call site is reachable from the
      // core; HabitsApplication.onCreate and WidgetReceiver are Android.
      expect(getToday(), computeToday(prefs.midnightDelayHours, 0),
          reason: 'time.today-and-day-boundary#11');

      // The second tick re-dates again, one day of fixed rate later.
      pinClock(unixTime(2017, 1, 3, 0, 0, 1));
      executor.tick();
      expect(getToday(), LocalDate.ymd(2017, 1, 3),
          reason: 'time.today-and-day-boundary#5');
      expect(listener.count, 2, reason: 'time.today-and-day-boundary#5');
    });

    test('#6 #7 getStartOfDay and getStartOfDayWithOffset', () {
      final startOfDay = unixTime(2017, 1, 1);
      final laterInDay = unixTime(2017, 1, 1, 20, 0);
      expect(DateUtils.getStartOfDay(laterInDay), startOfDay,
          reason: 'time.today-and-day-boundary#6');
      expect(DateUtils.getStartOfDay(laterInDay), (laterInDay ~/ _day) * _day,
          reason: 'time.today-and-day-boundary#6');

      final timestamp = unixTime(2020, 9, 3);
      expect(
        DateUtils.getStartOfDayWithOffset(timestamp + DateUtils.hourLength, 0,
            0),
        timestamp,
        reason: 'time.today-and-day-boundary#6',
      );
      expect(
        DateUtils.getStartOfDayWithOffset(laterInDay, 3, 30),
        DateUtils.getStartOfDay(laterInDay - 3 * _hour - 30 * _minute),
        reason: 'time.today-and-day-boundary#6',
      );

      // 03:29 on Sep 3 2020 with a 3h30m offset is still Sep 2 2020.
      expect(
        DateUtils.getStartOfDayWithOffset(
          timestamp + 3 * DateUtils.hourLength + 29 * DateUtils.minuteLength,
          3,
          30,
        ),
        timestamp - DateUtils.dayLength,
        reason: 'time.today-and-day-boundary#7',
      );
      expect(
        LocalDate.fromUnixTime(
          DateUtils.getStartOfDayWithOffset(
            timestamp + 3 * _hour + 29 * _minute,
            3,
            30,
          ),
        ),
        LocalDate.ymd(2020, 9, 2),
        reason: 'time.today-and-day-boundary#7',
      );
    });
  });
}
