/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt
///
/// The whole model keys on an integer day number rather than a wall-clock
/// timestamp, which is what keeps it free of DST and timezone drift. Do not
/// substitute Dart's [DateTime] here.
library;

LocalDate? _currentToday;

/// The process-global "today". Throws until [setToday] has been called.
LocalDate getToday() {
  final today = _currentToday;
  if (today == null) {
    throw StateError('getToday() called before setToday()');
  }
  return today;
}

void setToday(LocalDate date) => _currentToday = date;

void resetToday() => _currentToday = null;

enum DayOfWeek {
  sunday(0),
  monday(1),
  tuesday(2),
  wednesday(3),
  thursday(4),
  friday(5),
  saturday(6);

  const DayOfWeek(this.daysSinceSunday);

  final int daysSinceSunday;
}

enum TruncateField { day, weekNumber, month, quarter, year }

const List<int> leapOffset = [
  0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366, //
];

const List<int> nonLeapOffset = [
  0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365, //
];

bool _isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

int _daysSince2000(int year, int month, int day) {
  var result = 365 * (year - 2000);
  result += ((year - 2000) / 4.0).ceil();
  result -= ((year - 2000) / 100.0).ceil();
  result += ((year - 2000) / 400.0).ceil();
  result += _isLeapYear(year) ? leapOffset[month - 1] : nonLeapOffset[month - 1];
  result += day - 1;
  return result;
}

class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.daysSince2000);

  LocalDate.ymd(int year, int month, int day)
      : daysSince2000 = _daysSince2000(year, month, day);

  factory LocalDate.fromUnixTime(int millis) {
    final diff = millis - epoch2000Millis;
    final days = diff >= 0
        ? diff ~/ millisPerDay
        : (diff - millisPerDay + 1) ~/ millisPerDay;
    return LocalDate(days);
  }

  static const int epoch2000Millis = 946684800000;
  static const int millisPerDay = 86400000;

  final int daysSince2000;

  int _yearCache = -1;
  int _monthCache = -1;
  int _dayCache = -1;

  @override
  int compareTo(LocalDate other) => daysSince2000.compareTo(other.daysSince2000);

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.daysSince2000 == daysSince2000;

  @override
  int get hashCode => daysSince2000.hashCode;

  bool operator <(LocalDate other) => daysSince2000 < other.daysSince2000;
  bool operator <=(LocalDate other) => daysSince2000 <= other.daysSince2000;
  bool operator >(LocalDate other) => daysSince2000 > other.daysSince2000;
  bool operator >=(LocalDate other) => daysSince2000 >= other.daysSince2000;

  DayOfWeek get dayOfWeek {
    final rem = daysSince2000 % 7;
    final mod = rem < 0 ? rem + 7 : rem;
    switch (mod) {
      case 0:
        return DayOfWeek.saturday;
      case 1:
        return DayOfWeek.sunday;
      case 2:
        return DayOfWeek.monday;
      case 3:
        return DayOfWeek.tuesday;
      case 4:
        return DayOfWeek.wednesday;
      case 5:
        return DayOfWeek.thursday;
      default:
        return DayOfWeek.friday;
    }
  }

  int get year {
    if (_yearCache < 0) _updateYearMonthDayCache();
    return _yearCache;
  }

  int get month {
    if (_monthCache < 0) _updateYearMonthDayCache();
    return _monthCache;
  }

  int get day {
    if (_dayCache < 0) _updateYearMonthDayCache();
    return _dayCache;
  }

  int get monthLength {
    switch (month) {
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      case 2:
        return _isLeapYear(year) ? 29 : 28;
      default:
        return 31;
    }
  }

  int get yearLength => _isLeapYear(year) ? 366 : 365;

  void _updateYearMonthDayCache() {
    var currYear = 2000;
    var currDay = 0;
    if (daysSince2000 < 0) {
      currYear -= 400;
      currDay -= 146097;
    }
    while (true) {
      final currYearLength = _isLeapYear(currYear) ? 366 : 365;
      if (daysSince2000 < currDay + currYearLength) {
        _yearCache = currYear;
        break;
      }
      currYear++;
      currDay += currYearLength;
    }
    var currMonth = 1;
    final monthOffset = _isLeapYear(currYear) ? leapOffset : nonLeapOffset;
    while (true) {
      if (daysSince2000 < currDay + monthOffset[currMonth]) {
        _monthCache = currMonth;
        break;
      }
      currMonth++;
    }
    currDay += monthOffset[currMonth - 1];
    _dayCache = daysSince2000 - currDay + 1;
  }

  bool isOlderThan(LocalDate other) => daysSince2000 < other.daysSince2000;

  bool isNewerThan(LocalDate other) => daysSince2000 > other.daysSince2000;

  LocalDate plus(int days) => LocalDate(daysSince2000 + days);

  LocalDate minus(int days) => LocalDate(daysSince2000 - days);

  int daysUntil(LocalDate other) => other.daysSince2000 - daysSince2000;

  int get unixTime => epoch2000Millis + daysSince2000 * millisPerDay;

  LocalDate startOfWeek(DayOfWeek firstWeekday) {
    var delta = dayOfWeek.daysSinceSunday - firstWeekday.daysSinceSunday;
    if (delta < 0) delta += 7;
    return minus(delta);
  }

  LocalDate startOfMonth() => LocalDate.ymd(year, month, 1);

  LocalDate startOfQuarter() =>
      LocalDate.ymd(year, ((month - 1) ~/ 3) * 3 + 1, 1);

  LocalDate startOfYear() => LocalDate.ymd(year, 1, 1);

  LocalDate truncate(TruncateField field, DayOfWeek firstWeekday) {
    switch (field) {
      case TruncateField.day:
        return this;
      case TruncateField.weekNumber:
        return startOfWeek(firstWeekday);
      case TruncateField.month:
        return startOfMonth();
      case TruncateField.quarter:
        return startOfQuarter();
      case TruncateField.year:
        return startOfYear();
    }
  }

  String toCSVString() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  String toString() => 'LocalDate($year-$month-$day)';
}

List<DayOfWeek> getWeekdaySequence(DayOfWeek firstWeekday) {
  final allDays = DayOfWeek.values;
  return List.generate(
      7, (offset) => allDays[(firstWeekday.daysSinceSunday + offset) % 7]);
}

/// Returns a 7-element histogram indexed Saturday-first:
/// 0 = Saturday, 1 = Sunday, 2 = Monday ... 6 = Friday.
List<int> countWeekdayOccurrencesInMonth(LocalDate startOfMonth) {
  final weekday = (startOfMonth.dayOfWeek.daysSinceSunday + 1) % 7;
  final freq = List.filled(7, 0);
  for (var day = weekday; day < weekday + startOfMonth.monthLength; day++) {
    freq[day % 7] += 1;
  }
  return freq;
}

abstract class LocalDateFormatter {
  String shortWeekdayNameOf(DayOfWeek weekday);
  String shortWeekdayName(LocalDate date);
  String shortMonthName(LocalDate date);
  String longWeekdayNameOf(DayOfWeek weekday);
  String longMonthName(LocalDate date);
}
