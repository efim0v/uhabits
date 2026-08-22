import 'package:test/test.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Ported from uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/DatesTest.kt
/// and written from the rules in docs/parity/FEATURES.md.
void main() {
  group('time.local-date-core', () {
    test('#1 wraps a single daysSince2000, zero is 2000-01-01', () {
      expect(LocalDate(0).year, 2000, reason: 'time.local-date-core#1');
      expect(LocalDate(0).month, 1, reason: 'time.local-date-core#1');
      expect(LocalDate(0).day, 1, reason: 'time.local-date-core#1');
      expect(LocalDate(5) == LocalDate(5), isTrue,
          reason: 'time.local-date-core#1');
      expect(LocalDate(5).compareTo(LocalDate(6)), lessThan(0),
          reason: 'time.local-date-core#1');
    });

    test('#2 plus, minus and daysUntil are integer arithmetic', () {
      final d = LocalDate(100);
      expect(d.plus(5).daysSince2000, 105, reason: 'time.local-date-core#2');
      expect(d.minus(5).daysSince2000, 95, reason: 'time.local-date-core#2');
      expect(d.daysUntil(LocalDate(120)), 20, reason: 'time.local-date-core#2');
      expect(d.daysUntil(LocalDate(80)), -20, reason: 'time.local-date-core#2');
    });

    test('#3 isOlderThan and isNewerThan compare day numbers', () {
      expect(LocalDate(1).isOlderThan(LocalDate(2)), isTrue,
          reason: 'time.local-date-core#3');
      expect(LocalDate(2).isNewerThan(LocalDate(1)), isTrue,
          reason: 'time.local-date-core#3');
      expect(LocalDate(1).isOlderThan(LocalDate(1)), isFalse,
          reason: 'time.local-date-core#3');
    });

    test('#4 construction from year, month, day', () {
      expect(LocalDate.ymd(2000, 1, 1).daysSince2000, 0,
          reason: 'time.local-date-core#4');
      expect(LocalDate.ymd(2000, 12, 31).daysSince2000, 365,
          reason: 'time.local-date-core#4');
      expect(LocalDate.ymd(2001, 1, 1).daysSince2000, 366,
          reason: 'time.local-date-core#4');
      expect(LocalDate.ymd(2015, 1, 25).daysSince2000, 5503,
          reason: 'time.local-date-core#4');
    });

    test('#5 leap year rule', () {
      expect(LocalDate.ymd(2000, 2, 1).yearLength, 366,
          reason: 'time.local-date-core#5');
      expect(LocalDate.ymd(1900, 2, 1).yearLength, 365,
          reason: 'time.local-date-core#5');
      expect(LocalDate.ymd(2020, 2, 1).yearLength, 366,
          reason: 'time.local-date-core#5');
      expect(LocalDate.ymd(2021, 2, 1).yearLength, 365,
          reason: 'time.local-date-core#5');
    });

    test('#6 decoding walks the 400-year cycle for negative day numbers', () {
      final cycleStart = LocalDate(-146097);
      expect(cycleStart.year, 1600, reason: 'time.local-date-core#6');
      expect(cycleStart.month, 1, reason: 'time.local-date-core#6');
      expect(cycleStart.day, 1, reason: 'time.local-date-core#6');
      final d = LocalDate.ymd(1970, 1, 1);
      expect(d.daysSince2000, -10957, reason: 'time.local-date-core#6');
      expect(LocalDate(-10957).year, 1970, reason: 'time.local-date-core#6');
    });

    test('#7 dates before 2000 decode correctly', () {
      final d = LocalDate(-1);
      expect(d.year, 1999, reason: 'time.local-date-core#7');
      expect(d.month, 12, reason: 'time.local-date-core#7');
      expect(d.day, 31, reason: 'time.local-date-core#7');
    });

    test('#8 month length', () {
      expect(LocalDate.ymd(2021, 4, 1).monthLength, 30,
          reason: 'time.local-date-core#8');
      expect(LocalDate.ymd(2021, 2, 1).monthLength, 28,
          reason: 'time.local-date-core#8');
      expect(LocalDate.ymd(2020, 2, 1).monthLength, 29,
          reason: 'time.local-date-core#8');
      expect(LocalDate.ymd(2021, 1, 1).monthLength, 31,
          reason: 'time.local-date-core#8');
    });

    test('#9 year length', () {
      expect(LocalDate.ymd(2020, 6, 1).yearLength, 366,
          reason: 'time.local-date-core#9');
      expect(LocalDate.ymd(2021, 6, 1).yearLength, 365,
          reason: 'time.local-date-core#9');
    });

    test('#10 toString is unpadded, toCSVString is zero padded', () {
      expect(LocalDate.ymd(2015, 1, 25).toString(), 'LocalDate(2015-1-25)',
          reason: 'time.local-date-core#10');
      expect(LocalDate.ymd(2015, 1, 25).toCSVString(), '2015-01-25',
          reason: 'time.local-date-core#10');
      expect(LocalDate.ymd(2024, 2, 29).toCSVString(), '2024-02-29',
          reason: 'time.local-date-core#10');
      expect(LocalDate.ymd(1999, 12, 31).toCSVString(), '1999-12-31',
          reason: 'time.local-date-core#10');
    });
  });

  group('time.day-of-week', () {
    test('#1 enum order and daysSinceSunday payload', () {
      expect(DayOfWeek.values.map((d) => d.daysSinceSunday).toList(),
          [0, 1, 2, 3, 4, 5, 6],
          reason: 'time.day-of-week#1');
      expect(DayOfWeek.sunday.daysSinceSunday, 0, reason: 'time.day-of-week#1');
      expect(DayOfWeek.saturday.daysSinceSunday, 6,
          reason: 'time.day-of-week#1');
    });

    test('#2 2000-01-01 was a Saturday', () {
      expect(LocalDate(0).dayOfWeek, DayOfWeek.saturday,
          reason: 'time.day-of-week#2');
      expect(LocalDate(1).dayOfWeek, DayOfWeek.sunday,
          reason: 'time.day-of-week#2');
      expect(LocalDate(6).dayOfWeek, DayOfWeek.friday,
          reason: 'time.day-of-week#2');
    });

    test('#3 correct for negative day numbers', () {
      expect(LocalDate.ymd(1999, 12, 31).dayOfWeek, DayOfWeek.friday,
          reason: 'time.day-of-week#3');
      expect(LocalDate.ymd(1999, 12, 30).dayOfWeek, DayOfWeek.thursday,
          reason: 'time.day-of-week#3');
      expect(LocalDate.ymd(1999, 12, 25).dayOfWeek, DayOfWeek.saturday,
          reason: 'time.day-of-week#3');
      expect(LocalDate.ymd(1999, 12, 26).dayOfWeek, DayOfWeek.sunday,
          reason: 'time.day-of-week#3');
    });

    test('#5 histogram index is (daysSinceSunday + 1) % 7', () {
      // A month that starts on a Saturday puts its extra day in slot 0.
      final august2020 = LocalDate.ymd(2020, 8, 1);
      expect(august2020.dayOfWeek, DayOfWeek.saturday,
          reason: 'time.day-of-week#5');
      final freq = countWeekdayOccurrencesInMonth(august2020);
      expect(freq.length, 7, reason: 'time.day-of-week#5');
      expect(freq[(DayOfWeek.saturday.daysSinceSunday + 1) % 7], 5,
          reason: 'time.day-of-week#5');
      expect(freq[(DayOfWeek.wednesday.daysSinceSunday + 1) % 7], 4,
          reason: 'time.day-of-week#5');
    });

    test('#4 weekday sequence wraps from the first weekday', () {
      expect(getWeekdaySequence(DayOfWeek.tuesday), [
        DayOfWeek.tuesday,
        DayOfWeek.wednesday,
        DayOfWeek.thursday,
        DayOfWeek.friday,
        DayOfWeek.saturday,
        DayOfWeek.sunday,
        DayOfWeek.monday,
      ], reason: 'time.day-of-week#4');
    });

    test('#6 weekday occurrences per month, Saturday-first indexing', () {
      expect(countWeekdayOccurrencesInMonth(LocalDate.ymd(2018, 2, 1)),
          [4, 4, 4, 4, 4, 4, 4],
          reason: 'time.day-of-week#6');
      expect(countWeekdayOccurrencesInMonth(LocalDate.ymd(2020, 2, 1)),
          [5, 4, 4, 4, 4, 4, 4],
          reason: 'time.day-of-week#6');
      expect(countWeekdayOccurrencesInMonth(LocalDate.ymd(2020, 4, 1)),
          [4, 4, 4, 4, 5, 5, 4],
          reason: 'time.day-of-week#6');
      expect(countWeekdayOccurrencesInMonth(LocalDate.ymd(2020, 8, 1)),
          [5, 5, 5, 4, 4, 4, 4],
          reason: 'time.day-of-week#6');
    });
  });

  group('time.truncation', () {
    test('#1 TruncateField has exactly five values', () {
      expect(TruncateField.values, [
        TruncateField.day,
        TruncateField.weekNumber,
        TruncateField.month,
        TruncateField.quarter,
        TruncateField.year,
      ], reason: 'time.truncation#1');
    });

    test('#3 startOfWeek for Wednesday 2015-01-28', () {
      final wed = LocalDate.ymd(2015, 1, 28);
      expect(wed.startOfWeek(DayOfWeek.sunday), LocalDate.ymd(2015, 1, 25),
          reason: 'time.truncation#3');
      expect(wed.startOfWeek(DayOfWeek.monday), LocalDate.ymd(2015, 1, 26),
          reason: 'time.truncation#3');
      expect(wed.startOfWeek(DayOfWeek.wednesday), LocalDate.ymd(2015, 1, 28),
          reason: 'time.truncation#3');
      expect(wed.startOfWeek(DayOfWeek.saturday), LocalDate.ymd(2015, 1, 24),
          reason: 'time.truncation#3');
    });

    test('#2 startOfWeek returns itself when already the first weekday', () {
      final sunday = LocalDate.ymd(2015, 1, 25);
      expect(sunday.dayOfWeek, DayOfWeek.sunday, reason: 'time.truncation#2');
      expect(sunday.startOfWeek(DayOfWeek.sunday), sunday,
          reason: 'time.truncation#2');
    });

    test('#7 truncate dispatches on the field', () {
      final d = LocalDate.ymd(2015, 1, 28);
      expect(d.truncate(TruncateField.day, DayOfWeek.sunday), d,
          reason: 'time.truncation#7');
      expect(d.truncate(TruncateField.weekNumber, DayOfWeek.sunday),
          d.startOfWeek(DayOfWeek.sunday),
          reason: 'time.truncation#7');
      expect(d.truncate(TruncateField.month, DayOfWeek.sunday),
          d.startOfMonth(),
          reason: 'time.truncation#7');
      expect(d.truncate(TruncateField.quarter, DayOfWeek.sunday),
          d.startOfQuarter(),
          reason: 'time.truncation#7');
      expect(d.truncate(TruncateField.year, DayOfWeek.sunday), d.startOfYear(),
          reason: 'time.truncation#7');
    });

    test('#4 #5 #6 startOfMonth, startOfQuarter, startOfYear', () {
      expect(LocalDate.ymd(2024, 2, 29).startOfMonth(),
          LocalDate.ymd(2024, 2, 1),
          reason: 'time.truncation#4');
      expect(LocalDate.ymd(2024, 2, 29).startOfQuarter(),
          LocalDate.ymd(2024, 1, 1),
          reason: 'time.truncation#5');
      expect(LocalDate.ymd(2024, 5, 9).startOfQuarter(),
          LocalDate.ymd(2024, 4, 1),
          reason: 'time.truncation#5');
      expect(LocalDate.ymd(2024, 8, 9).startOfQuarter(),
          LocalDate.ymd(2024, 7, 1),
          reason: 'time.truncation#5');
      expect(LocalDate.ymd(2024, 11, 9).startOfQuarter(),
          LocalDate.ymd(2024, 10, 1),
          reason: 'time.truncation#5');
      expect(LocalDate.ymd(2024, 5, 9).startOfYear(), LocalDate.ymd(2024, 1, 1),
          reason: 'time.truncation#6');
    });
  });

  group('time.unix-conversion', () {
    test('#1 epoch constants', () {
      expect(LocalDate.epoch2000Millis, 946684800000,
          reason: 'time.unix-conversion#1');
      expect(LocalDate.millisPerDay, 86400000,
          reason: 'time.unix-conversion#1');
    });

    test('#2 unixTime is UTC midnight of the calendar day', () {
      expect(LocalDate(0).unixTime, 946684800000,
          reason: 'time.unix-conversion#2');
      expect(LocalDate(1).unixTime, 946684800000 + 86400000,
          reason: 'time.unix-conversion#2');
    });

    test('#4 fromUnixTime floors for pre-2000 timestamps', () {
      expect(LocalDate.fromUnixTime(946684800000), LocalDate.ymd(2000, 1, 1),
          reason: 'time.unix-conversion#3');
      expect(LocalDate.fromUnixTime(946684800000 - 1),
          LocalDate.ymd(1999, 12, 31),
          reason: 'time.unix-conversion#4');
      expect(LocalDate.fromUnixTime(946684800000 - 86400000),
          LocalDate.ymd(1999, 12, 31),
          reason: 'time.unix-conversion#4');
      expect(LocalDate.fromUnixTime(946684800000 - 86400000 - 1),
          LocalDate.ymd(1999, 12, 30),
          reason: 'time.unix-conversion#4');
    });
  });

  group('time.today-and-day-boundary', () {
    tearDown(resetToday);

    test('#1 getToday throws before setToday', () {
      resetToday();
      expect(getToday, throwsStateError,
          reason: 'time.today-and-day-boundary#1');
      setToday(LocalDate.ymd(2015, 1, 25));
      expect(getToday(), LocalDate.ymd(2015, 1, 25),
          reason: 'time.today-and-day-boundary#1');
      resetToday();
      expect(getToday, throwsStateError,
          reason: 'time.today-and-day-boundary#10');
    });
  });
}
