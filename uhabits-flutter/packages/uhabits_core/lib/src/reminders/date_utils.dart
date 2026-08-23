/// Port of uhabits-core/src/jvmMain/java/org/isoron/platform/time/DateUtils.kt
///
/// This is the wall-clock half of the time layer, and it is deliberately kept
/// apart from [LocalDate] (src/time/local_date.dart), which is the day-number
/// half. Everything here works on two different kinds of `int`:
///
///   * a **UTC timestamp** — plain epoch milliseconds, what the platform
///     scheduler and the database store;
///   * a **local-shifted timestamp** — epoch milliseconds moved forward by the
///     zone offset, so that dividing by [DateUtils.dayLength] yields the local
///     calendar day. Upstream calls this "local time"; it is not a valid
///     instant, only an arithmetic convenience.
///
/// [DateUtils.removeTimezone] converts the first into the second and
/// [DateUtils.applyTimezone] converts back. The round trip is not a plain
/// addition and subtraction: `applyTimezone` looks the offset up twice, which
/// is what makes a local timestamp that falls on the far side of a DST
/// transition resolve to the right instant. Ported verbatim, double lookup
/// included.
///
/// Kotlin declares this as an `object` with mutable test hooks
/// (`setFixedLocalTime`, `setFixedTimeZone`); the Dart port keeps the same
/// process-global state, exactly as `getToday`/`setToday` do.
library;

/// Port of the single method `java.util.TimeZone` is used for here.
///
/// Upstream passes real `TimeZone` instances around (`TimeZone.getDefault()`,
/// `TimeZone.getTimeZone("GMT-4")`). Dart's core library has no zone database,
/// so this narrow interface is what the core depends on: the app supplies an
/// implementation backed by whatever zone data it has, and the tests supply
/// fixed or synthetic ones.
abstract interface class TimeZone {
  /// The offset, in milliseconds, to add to the UTC instant [timestamp] to
  /// obtain local wall-clock time — the contract of
  /// `java.util.TimeZone.getOffset(long date)`, DST included.
  int getOffset(int timestamp);
}

/// A zone with no DST, equivalent to `TimeZone.getTimeZone("GMT-4")`.
class FixedTimeZone implements TimeZone {
  const FixedTimeZone(this.offset, [this.id = '']);

  final int offset;

  final String id;

  @override
  int getOffset(int timestamp) => offset;

  @override
  String toString() => 'FixedTimeZone($id, $offset)';
}

/// `TimeZone.getDefault()`: the host's own zone, DST included.
///
/// Dart resolves the offset of an instant through [DateTime], which is the only
/// zone data available without a package.
class SystemTimeZone implements TimeZone {
  const SystemTimeZone();

  @override
  int getOffset(int timestamp) =>
      DateTime.fromMillisecondsSinceEpoch(timestamp)
          .timeZoneOffset
          .inMilliseconds;

  @override
  String toString() => 'SystemTimeZone()';
}

/// Port of the Kotlin `object DateUtils`. Dart has no objects-as-singletons, so
/// this is an uninstantiable class of static members with static state.
class DateUtils {
  DateUtils._();

  static const int secondLength = 1000;
  static const int minuteLength = 60 * secondLength;
  static const int hourLength = 60 * minuteLength;
  static const int dayLength = 24 * hourLength;

  static int? _fixedLocalTime;
  static TimeZone? _fixedTimeZone;

  /// Freezes the clock. `null` restores the real one.
  static void setFixedLocalTime(int? value) {
    _fixedLocalTime = value;
  }

  static TimeZone? get fixedTimeZone => _fixedTimeZone;

  /// Freezes the zone. `null` restores the host's.
  static void setFixedTimeZone(TimeZone? value) {
    _fixedTimeZone = value;
  }

  static TimeZone get _defaultTimeZone =>
      _fixedTimeZone ?? const SystemTimeZone();

  /// Local-shifted millis to UTC millis.
  ///
  /// The offset is looked up twice on purpose: the first lookup gives a rough
  /// instant, the second corrects it when the rough instant lands on the other
  /// side of a DST transition.
  static int applyTimezone(int localTimestamp, [TimeZone? tz]) {
    final zone = tz ?? _defaultTimeZone;
    return localTimestamp -
        zone.getOffset(localTimestamp - zone.getOffset(localTimestamp));
  }

  /// UTC millis to local-shifted millis.
  static int removeTimezone(int timestamp, [TimeZone? tz]) {
    final zone = tz ?? _defaultTimeZone;
    return timestamp + zone.getOffset(timestamp);
  }

  /// The current local-shifted time, or whatever [setFixedLocalTime] injected.
  ///
  /// The injected value wins before the zone is even consulted, so a frozen
  /// local time is not shifted a second time.
  static int getLocalTime({TimeZone? tz, int? utcTimeInMillis}) {
    final fixed = _fixedLocalTime;
    if (fixed != null) return fixed;
    final zone = tz ?? _defaultTimeZone;
    final now = utcTimeInMillis ?? DateTime.now().millisecondsSinceEpoch;
    return now + zone.getOffset(now);
  }

  /// Floors to a day boundary by integer division, so it assumes a
  /// non-negative timestamp — dates before 1970 round the wrong way upstream
  /// too.
  static int getStartOfDay(int timestamp) => (timestamp ~/ dayLength) * dayLength;

  static int getStartOfDayWithOffset(
    int timestamp,
    int hourOffset,
    int minuteOffset,
  ) {
    final offset = hourOffset * hourLength + minuteOffset * minuteLength;
    return getStartOfDay(timestamp - offset);
  }

  /// The start of the user's next "day", which is simply the next occurrence
  /// of the midnight-delay wall-clock time.
  static int getStartOfTomorrowWithOffset(
    int hourOffset,
    int minuteOffset, [
    TimeZone? tz,
  ]) =>
      getUpcomingTimeInMillis(hourOffset, minuteOffset, tz);

  static int millisecondsUntilTomorrowWithOffset(
    int hourOffset,
    int minuteOffset, [
    TimeZone? tz,
  ]) {
    final zone = tz ?? _defaultTimeZone;
    return getStartOfTomorrowWithOffset(hourOffset, minuteOffset, zone) -
        applyTimezone(getLocalTime(tz: zone), zone);
  }

  /// The UTC instant of the next occurrence of local wall-clock
  /// [hour]:[minute].
  ///
  /// Kotlin builds a GMT `GregorianCalendar` at the start of the local day and
  /// sets HOUR_OF_DAY, MINUTE and SECOND on it; since the start of a day has
  /// zero minutes, seconds and milliseconds, that is the plain addition below.
  ///
  /// The comparison is strictly greater-than: a local time equal to the
  /// reminder time schedules for today, at that very instant.
  static int getUpcomingTimeInMillis(int hour, int minute, [TimeZone? tz]) {
    final zone = tz ?? _defaultTimeZone;
    final localTime = getLocalTime(tz: zone);
    final startOfToday = getStartOfDay(localTime);
    var time = startOfToday + hour * hourLength + minute * minuteLength;
    if (localTime > time) {
      time += dayLength;
    }
    return applyTimezone(time, zone);
  }
}
