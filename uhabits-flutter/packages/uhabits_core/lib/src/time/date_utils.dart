/// Port of uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt
/// and uhabits-core/src/jvmMain/java/org/isoron/platform/time/JvmDates.kt.
///
/// Everything here works in epoch milliseconds, which is the one place in the
/// core where wall-clock time and timezones matter: the model itself keys on
/// [LocalDate] day numbers. Two pieces of ambient state are read — the system
/// clock and the default timezone — and both are injectable so that tests can
/// pin them the way the Kotlin tests use `DateUtils.setFixedLocalTime` and
/// `DateUtils.setFixedTimeZone`.
library;

import 'local_date.dart';

/// Port of `java.util.TimeZone`, narrowed to the single method the core calls.
abstract class TimeZone {
  const TimeZone();

  /// `TimeZone.getOffset(millis)`: the offset from UTC, in milliseconds, that
  /// applies at the given UTC instant (so DST is already folded in).
  int getOffset(int utcMillis);
}

/// A zone with no DST, i.e. what `TimeZone.getTimeZone("GMT")` and the
/// `GMT+HH:MM` ids give you.
class FixedTimeZone extends TimeZone {
  const FixedTimeZone(this.offsetMillis, [this.id = 'GMT']);

  final int offsetMillis;
  final String id;

  @override
  int getOffset(int utcMillis) => offsetMillis;

  @override
  bool operator ==(Object other) =>
      other is FixedTimeZone &&
      other.offsetMillis == offsetMillis &&
      other.id == id;

  @override
  int get hashCode => Object.hash(offsetMillis, id);

  @override
  String toString() => 'TimeZone($id)';
}

/// `TimeZone.getTimeZone("GMT")`.
const TimeZone gmt = FixedTimeZone(0);

/// The host's zone, read through Dart's own tz database. This is the
/// equivalent of `TimeZone.getDefault()`: `DateTime.timeZoneOffset` is
/// evaluated for the given instant, so historical offsets and DST transitions
/// resolve exactly like `TimeZone.getOffset`.
class SystemTimeZone extends TimeZone {
  const SystemTimeZone();

  @override
  int getOffset(int utcMillis) =>
      DateTime.fromMillisecondsSinceEpoch(utcMillis)
          .timeZoneOffset
          .inMilliseconds;

  @override
  String toString() => 'TimeZone(default)';
}

/// `System.currentTimeMillis()`.
int defaultCurrentTimeMillis() => DateTime.now().millisecondsSinceEpoch;

/// `TimeZone.getDefault()`.
TimeZone systemDefaultTimeZone() => const SystemTimeZone();

/// The clock the core reads. Kotlin calls `System.currentTimeMillis()` and
/// `Date().time` inline; in Dart the call is routed through this variable so
/// that tests — and, later, the app's own fake clocks — can pin it without
/// reaching for `DateTime.now()` inside the core.
int Function() systemCurrentTimeMillis = defaultCurrentTimeMillis;

/// The default timezone the core reads, for the same reason.
TimeZone Function() getDefaultTimeZone = systemDefaultTimeZone;

/// Port of `Math.floorDiv`. Dart's `~/` truncates towards zero, which would
/// put the instants just before an epoch on the wrong day.
int _floorDiv(int x, int y) {
  var result = x ~/ y;
  if ((x % y != 0) && ((x < 0) != (y < 0))) result--;
  return result;
}

/// Port of `actual fun computeToday(hourOffset, minuteOffset)` from JvmDates.kt.
///
/// The number 10957 is the count of days between 1970-01-01 and 2000-01-01,
/// which is what turns a Unix day number into a [LocalDate].
///
/// Note that the two `DateUtils` test hooks do NOT reach this function, exactly
/// as on the JVM: `setFixedLocalTime` leaves `System.currentTimeMillis()`
/// alone, so pinning it does not pin `computeToday`.
LocalDate computeToday([int hourOffset = 0, int minuteOffset = 0]) {
  final nowMillis = systemCurrentTimeMillis();
  final tz = getDefaultTimeZone();
  final localMillis = nowMillis + tz.getOffset(nowMillis);
  final offsetMillis = hourOffset * 3600000 + minuteOffset * 60000;
  final adjustedMillis = localMillis - offsetMillis;
  final daysSinceEpoch = _floorDiv(adjustedMillis, 86400000);
  final daysSince2000 = daysSinceEpoch - 10957;
  return LocalDate(daysSince2000);
}

/// Port of the Kotlin `object DateUtils`.
///
/// The names are the Kotlin ones with Dart casing: `DAY_LENGTH` becomes
/// [dayLength], and the `@JvmStatic var fixedTimeZone` with its private setter
/// becomes a getter plus [setFixedTimeZone].
class DateUtils {
  DateUtils._();

  static const int secondLength = 1000;
  static const int minuteLength = 60 * secondLength;
  static const int hourLength = 60 * minuteLength;
  static const int dayLength = 24 * hourLength;

  static int? _fixedLocalTime;

  /// Test hook: pins the value [getLocalTime] returns, ignoring both the clock
  /// and the timezone. Pass null to release it.
  static void setFixedLocalTime(int? value) {
    _fixedLocalTime = value;
  }

  static int? get fixedLocalTime => _fixedLocalTime;

  static TimeZone? _fixedTimeZone;

  static TimeZone? get fixedTimeZone => _fixedTimeZone;

  /// Test hook: pins the zone every method here defaults to. Pass null to
  /// release it.
  static void setFixedTimeZone(TimeZone? value) {
    _fixedTimeZone = value;
  }

  static TimeZone get _defaultTimeZone => _fixedTimeZone ?? getDefaultTimeZone();

  /// The zone in force: the pinned one when a test set it, the host's
  /// otherwise.
  ///
  /// Exposed so that callers outside this class resolve the zone the same way
  /// it does. Reaching for [getDefaultTimeZone] directly skips
  /// [setFixedTimeZone], which is the hook every test in the port uses.
  static TimeZone get currentTimeZone => _defaultTimeZone;

  /// Local wall-clock millis back to a UTC instant. The offset is looked up
  /// twice on purpose, so that the DST boundaries resolve correctly.
  static int applyTimezone(int localTimestamp, [TimeZone? timeZone]) {
    final tz = timeZone ?? _defaultTimeZone;
    return localTimestamp - tz.getOffset(localTimestamp - tz.getOffset(localTimestamp));
  }

  /// A UTC instant to local wall-clock millis.
  static int removeTimezone(int timestamp, [TimeZone? timeZone]) {
    final tz = timeZone ?? _defaultTimeZone;
    return timestamp + tz.getOffset(timestamp);
  }

  /// Now, shifted into local wall-clock millis — or the pinned
  /// [fixedLocalTime], which wins over both arguments.
  static int getLocalTime({TimeZone? timeZone, int? utcTimeInMillis}) {
    final fixed = _fixedLocalTime;
    if (fixed != null) return fixed;
    final tz = timeZone ?? _defaultTimeZone;
    final now = utcTimeInMillis ?? systemCurrentTimeMillis();
    return now + tz.getOffset(now);
  }

  /// Truncating division, exactly as in Kotlin: this assumes `timestamp >= 0`
  /// and gives the wrong answer for negative timestamps. Upstream behaviour,
  /// reproduced deliberately.
  static int getStartOfDay(int timestamp) => (timestamp ~/ dayLength) * dayLength;

  static int getStartOfDayWithOffset(
    int timestamp,
    int hourOffset,
    int minuteOffset,
  ) {
    final offset = hourOffset * hourLength + minuteOffset * minuteLength;
    return getStartOfDay(timestamp - offset);
  }

  static int getStartOfTomorrowWithOffset(
    int hourOffset,
    int minuteOffset, [
    TimeZone? timeZone,
  ]) =>
      getUpcomingTimeInMillis(hourOffset, minuteOffset, timeZone);

  static int millisecondsUntilTomorrowWithOffset(
    int hourOffset,
    int minuteOffset, [
    TimeZone? timeZone,
  ]) {
    final tz = timeZone ?? _defaultTimeZone;
    return getStartOfTomorrowWithOffset(hourOffset, minuteOffset, tz) -
        applyTimezone(getLocalTime(timeZone: tz), tz);
  }

  /// The next UTC instant at which the local wall clock reads [hour]:[minute].
  ///
  /// Kotlin builds a GMT `GregorianCalendar` on the start of the local day and
  /// sets HOUR_OF_DAY, MINUTE and SECOND. Since the start of a day is always a
  /// whole multiple of [dayLength], that is plain arithmetic.
  static int getUpcomingTimeInMillis(
    int hour,
    int minute, [
    TimeZone? timeZone,
  ]) {
    final tz = timeZone ?? _defaultTimeZone;
    final localTime = getLocalTime(timeZone: tz);
    final startOfToday = getStartOfDay(localTime);
    var time = startOfToday + hour * hourLength + minute * minuteLength;
    if (localTime > time) {
      time += dayLength;
    }
    return applyTimezone(time, tz);
  }
}
