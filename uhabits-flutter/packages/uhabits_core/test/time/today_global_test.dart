/// `time.today-and-day-boundary#12` — 'today' is a process-global *cache*, not
/// a function of the clock.
///
/// The consequence the rule names is about a cold-started process: an alarm
/// that wakes the app hours after launch reads whatever `setToday()` stamped
/// during `HabitsApplication.onCreate`, not whatever the wall clock says at
/// the moment the alarm fires. That is observable entirely from the core: pin
/// the clock, stamp today, move the clock across midnight, and read again.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

int _unixTime(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    LocalDate.ymd(year, month, day).unixTime + hour * 3600000 + minute * 60000;

void main() {
  final int Function() realClock = systemCurrentTimeMillis;
  final TimeZone Function() realZone = getDefaultTimeZone;

  setUp(resetToday);

  tearDown(() {
    systemCurrentTimeMillis = realClock;
    getDefaultTimeZone = realZone;
    resetToday();
  });

  void pinClock(int nowMillis) {
    systemCurrentTimeMillis = () => nowMillis;
    getDefaultTimeZone = () => const FixedTimeZone(0);
  }

  group('time.today-and-day-boundary', () {
    test('#12 an alarm firing later in the process reads the value stamped at '
        'startup, not the current clock', () {
      // A cold-started process: nothing has stamped a day yet.
      expect(getToday, throwsStateError,
          reason: 'time.today-and-day-boundary#12 — before onCreate runs there '
              'is no cached today at all, so every reader would throw');

      // HabitsApplication.onCreate: setToday(computeToday(delay, 0)).
      pinClock(_unixTime(2017, 1, 1, 20, 0));
      setToday(computeToday(0, 0));
      expect(getToday(), LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#12 — onCreate is what puts a '
              'value in the process-global cache');

      // Nine hours pass and an alarm fires; the wall clock is now the 2nd.
      pinClock(_unixTime(2017, 1, 2, 5, 0));
      expect(computeToday(0, 0), LocalDate.ymd(2017, 1, 2),
          reason: 'time.today-and-day-boundary#12 — recomputing from the clock '
              'would give the new day');
      expect(getToday(), LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#12 — but getToday() is a cached '
              'global, so the alarm still sees the day onCreate stamped');
    });

    test('#12 the cached value only changes when something calls setToday', () {
      pinClock(_unixTime(2017, 1, 1, 20, 0));
      setToday(computeToday(0, 0));

      pinClock(_unixTime(2017, 3, 15, 12, 0));
      expect(getToday(), LocalDate.ymd(2017, 1, 1),
          reason: 'time.today-and-day-boundary#12 — arbitrarily large clock '
              'movement does not invalidate the cache');

      // MidnightTimer.notifyListeners / a fresh onCreate is what refreshes it.
      setToday(computeToday(0, 0));
      expect(getToday(), LocalDate.ymd(2017, 3, 15),
          reason: 'time.today-and-day-boundary#12 — the only way the cached '
              'day advances is an explicit setToday()');
    });
  });
}
