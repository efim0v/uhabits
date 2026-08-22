import 'package:test/test.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Written from the parity rules for `models.reminder` (no Kotlin test file
/// covers Reminder directly; WeekdayListTest.kt cases are reproduced here).
void main() {
  group('models.reminder', () {
    test('#1 immutable value with hour, minute and days', () {
      final reminder = Reminder(8, 30, WeekdayList(1));
      expect(reminder.hour, 8, reason: 'models.reminder#1');
      expect(reminder.minute, 30, reason: 'models.reminder#1');
      expect(reminder.days, WeekdayList(1), reason: 'models.reminder#1');

      // The documented ranges are 0..23 for hour and 0..59 for minute; the
      // Kotlin data class stores them verbatim without validating.
      expect(Reminder(0, 0, WeekdayList(0)).hour, 0,
          reason: 'models.reminder#1');
      expect(Reminder(0, 0, WeekdayList(0)).minute, 0,
          reason: 'models.reminder#1');
      expect(Reminder(23, 59, WeekdayList.everyDay).hour, 23,
          reason: 'models.reminder#1');
      expect(Reminder(23, 59, WeekdayList.everyDay).minute, 59,
          reason: 'models.reminder#1');
    });

    test('#2 #5 equality is structural over all three fields', () {
      final a = Reminder(8, 30, WeekdayList(1));
      final b = Reminder(8, 30, WeekdayList(1));
      expect(a, b, reason: 'models.reminder#2');
      expect(a.hashCode, b.hashCode, reason: 'models.reminder#2');

      expect(a == Reminder(9, 30, WeekdayList(1)), isFalse,
          reason: 'models.reminder#5');
      expect(a == Reminder(8, 31, WeekdayList(1)), isFalse,
          reason: 'models.reminder#5');
      expect(a == Reminder(8, 30, WeekdayList(2)), isFalse,
          reason: 'models.reminder#5');
      expect(Reminder(8, 30, WeekdayList.everyDay),
          Reminder(8, 30, WeekdayList(127)),
          reason: 'models.reminder#5');
    });

    test('#7 the packed-int constructor sets bit i for weekday i', () {
      expect(WeekdayList(0).toArray(), List.filled(7, false),
          reason: 'models.reminder#7');
      expect(WeekdayList(124).toArray(),
          [false, false, true, true, true, true, true],
          reason: 'models.reminder#7');
      for (var i = 0; i < 7; i++) {
        final only = WeekdayList(1 << i).toArray();
        expect(only[i], isTrue, reason: 'models.reminder#7');
        expect(only.where((d) => d).length, 1, reason: 'models.reminder#7');
      }
      // Bits above bit 6 are ignored.
      expect(WeekdayList(128).toArray(), List.filled(7, false),
          reason: 'models.reminder#7');
    });

    test('#8 toInteger packs the weekdays back into an int', () {
      expect(WeekdayList(127).toInteger(), 127, reason: 'models.reminder#8');
      expect(WeekdayList(124).toInteger(), 124, reason: 'models.reminder#8');
      expect(WeekdayList(0).toInteger(), 0, reason: 'models.reminder#8');
      expect(
          WeekdayList.fromArray(
                  [false, false, true, true, true, true, true]).toInteger(),
          124,
          reason: 'models.reminder#8');
      for (var i = 0; i < 7; i++) {
        expect(WeekdayList(1 << i).toInteger(), 1 << i,
            reason: 'models.reminder#8');
      }
    });

    test('#9 EVERY_DAY is WeekdayList(127)', () {
      expect(WeekdayList.everyDay, WeekdayList(127),
          reason: 'models.reminder#9');
      expect(WeekdayList.everyDay.toArray(), List.filled(7, true),
          reason: 'models.reminder#9');
      expect(WeekdayList.everyDay.toInteger(), 127,
          reason: 'models.reminder#9');
    });

    test('#10 isEmpty is true only when no day is set', () {
      expect(WeekdayList(0).isEmpty, isTrue, reason: 'models.reminder#10');
      expect(WeekdayList.everyDay.isEmpty, isFalse,
          reason: 'models.reminder#10');
      for (var i = 0; i < 7; i++) {
        expect(WeekdayList(1 << i).isEmpty, isFalse,
            reason: 'models.reminder#10');
      }
    });

    test('#11 toArray returns a defensive copy of length 7', () {
      final list = WeekdayList(0);
      final array = list.toArray();
      expect(array.length, 7, reason: 'models.reminder#11');
      array[3] = true;
      expect(list.toArray()[3], isFalse, reason: 'models.reminder#11');
      expect(list.toInteger(), 0, reason: 'models.reminder#11');
      expect(identical(list.toArray(), list.toArray()), isFalse,
          reason: 'models.reminder#11');
    });

    test('#12 the array constructor copies to exactly length 7', () {
      final short = [true, true];
      final list = WeekdayList.fromArray(short);
      expect(list.toArray(), [true, true, false, false, false, false, false],
          reason: 'models.reminder#12');
      expect(list.toInteger(), 3, reason: 'models.reminder#12');

      final long = List.filled(10, true);
      expect(WeekdayList.fromArray(long).toArray(), List.filled(7, true),
          reason: 'models.reminder#12');
      expect(WeekdayList.fromArray(long).toInteger(), 127,
          reason: 'models.reminder#12');

      // The source array is copied, not aliased.
      final source = List.filled(7, false);
      final copied = WeekdayList.fromArray(source);
      source[0] = true;
      expect(copied.toArray()[0], isFalse, reason: 'models.reminder#12');
    });

    test('#13 toString renders the seven booleans joined by commas', () {
      expect(WeekdayList(0).toString(),
          '{weekdays: [false,false,false,false,false,false,false]}',
          reason: 'models.reminder#13');
      expect(
          WeekdayList.fromArray([false, false, true, true, true, true, true])
              .toString(),
          '{weekdays: [false,false,true,true,true,true,true]}',
          reason: 'models.reminder#13');
      expect(WeekdayList.everyDay.toString(),
          '{weekdays: [true,true,true,true,true,true,true]}',
          reason: 'models.reminder#13');
    });

    test('#14 index 0 is Saturday, 1 Sunday, ... 6 Friday', () {
      // NotificationTray looks the reminder day up with this expression.
      int reminderIndexOf(DayOfWeek day) => (day.daysSinceSunday + 1) % 7;

      expect(reminderIndexOf(DayOfWeek.saturday), 0,
          reason: 'models.reminder#14');
      expect(reminderIndexOf(DayOfWeek.sunday), 1,
          reason: 'models.reminder#14');
      expect(reminderIndexOf(DayOfWeek.monday), 2,
          reason: 'models.reminder#14');
      expect(reminderIndexOf(DayOfWeek.tuesday), 3,
          reason: 'models.reminder#14');
      expect(reminderIndexOf(DayOfWeek.wednesday), 4,
          reason: 'models.reminder#14');
      expect(reminderIndexOf(DayOfWeek.thursday), 5,
          reason: 'models.reminder#14');
      expect(reminderIndexOf(DayOfWeek.friday), 6,
          reason: 'models.reminder#14');

      // A reminder that only fires on Saturdays is the packed value 1.
      final saturdayOnly = Reminder(8, 30, WeekdayList(1));
      expect(saturdayOnly.days.toArray()[reminderIndexOf(DayOfWeek.saturday)],
          isTrue,
          reason: 'models.reminder#14');
      for (final day in DayOfWeek.values) {
        if (day == DayOfWeek.saturday) continue;
        expect(saturdayOnly.days.toArray()[reminderIndexOf(day)], isFalse,
            reason: 'models.reminder#14');
      }

      // Weekdays only (Monday..Friday) is 0b1111100 == 124.
      final weekdaysOnly = WeekdayList(124).toArray();
      for (final day in [
        DayOfWeek.monday,
        DayOfWeek.tuesday,
        DayOfWeek.wednesday,
        DayOfWeek.thursday,
        DayOfWeek.friday,
      ]) {
        expect(weekdaysOnly[reminderIndexOf(day)], isTrue,
            reason: 'models.reminder#14');
      }
      expect(weekdaysOnly[reminderIndexOf(DayOfWeek.saturday)], isFalse,
          reason: 'models.reminder#14');
      expect(weekdaysOnly[reminderIndexOf(DayOfWeek.sunday)], isFalse,
          reason: 'models.reminder#14');
    });

    test('#15 WeekdayList equality and hashCode are content-based', () {
      expect(
          WeekdayList(124),
          WeekdayList.fromArray([false, false, true, true, true, true, true]),
          reason: 'models.reminder#15');
      expect(WeekdayList(124).hashCode,
          WeekdayList.fromArray([false, false, true, true, true, true, true])
              .hashCode,
          reason: 'models.reminder#15');
      expect(WeekdayList(124) == WeekdayList(125), isFalse,
          reason: 'models.reminder#15');
      expect(WeekdayList(0), WeekdayList.fromArray(List.filled(7, false)),
          reason: 'models.reminder#15');
    });
  });
}
