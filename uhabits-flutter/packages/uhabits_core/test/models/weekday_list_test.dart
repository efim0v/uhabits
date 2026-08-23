import 'package:test/test.dart';
import 'package:uhabits_core/src/database/habit_repository.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/reminder.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/WeekdayListTest.kt
void main() {
  group('models.weekday-list', () {
    test('#1 wraps exactly 7 booleans, index 0..6', () {
      expect(WeekdayList(0).toArray().length, 7,
          reason: 'models.weekday-list#1');
      expect(WeekdayList(127).toArray().length, 7,
          reason: 'models.weekday-list#1');
      expect(WeekdayList.fromArray([true]).toArray().length, 7,
          reason: 'models.weekday-list#1');
      expect(WeekdayList(0).toArray(), List<bool>.filled(7, false),
          reason: 'models.weekday-list#1');
      expect(WeekdayList(127).toArray(), List<bool>.filled(7, true),
          reason: 'models.weekday-list#1');
    });

    test('#2 int constructor sets bit i, bits above bit 6 ignored', () {
      for (var i = 0; i < 7; i++) {
        final list = WeekdayList(1 << i);
        final expected = List<bool>.filled(7, false);
        expected[i] = true;
        expect(list.toArray(), expected, reason: 'models.weekday-list#2');
      }
      expect(WeekdayList(0).toArray(), List<bool>.filled(7, false),
          reason: 'models.weekday-list#2');
      // Bit 7 and above are ignored.
      expect(WeekdayList(128).toArray(), List<bool>.filled(7, false),
          reason: 'models.weekday-list#2');
      expect(WeekdayList(128).isEmpty, isTrue,
          reason: 'models.weekday-list#2');
      expect(WeekdayList(255).toArray(), List<bool>.filled(7, true),
          reason: 'models.weekday-list#2');
      expect(WeekdayList(1024 + 5).toArray(),
          [true, false, true, false, false, false, false],
          reason: 'models.weekday-list#2');
    });

    test('#3 array constructor copies to exactly length 7', () {
      // Short input is padded with false.
      expect(WeekdayList.fromArray([true, true]).toArray(),
          [true, true, false, false, false, false, false],
          reason: 'models.weekday-list#3');
      expect(WeekdayList.fromArray(const <bool>[]).toArray(),
          List<bool>.filled(7, false),
          reason: 'models.weekday-list#3');
      // Long input is truncated.
      expect(WeekdayList.fromArray(List<bool>.filled(10, true)).toArray(),
          List<bool>.filled(7, true),
          reason: 'models.weekday-list#3');
      expect(
          WeekdayList.fromArray(
              [false, false, true, true, true, true, true, true, true])
              .toInteger(),
          124,
          reason: 'models.weekday-list#3');
      // The source array is copied, not aliased.
      final source = [true, false, false, false, false, false, false];
      final list = WeekdayList.fromArray(source);
      source[1] = true;
      expect(list.toArray(),
          [true, false, false, false, false, false, false],
          reason: 'models.weekday-list#3');
    });

    test('#4 toInteger packs bit i iff weekdays[i], range 0..127', () {
      for (var i = 0; i < 7; i++) {
        final days = List<bool>.filled(7, false);
        days[i] = true;
        expect(WeekdayList.fromArray(days).toInteger(), 1 << i,
            reason: 'models.weekday-list#4');
      }
      expect(WeekdayList.fromArray(List<bool>.filled(7, false)).toInteger(), 0,
          reason: 'models.weekday-list#4');
      expect(WeekdayList.fromArray(List<bool>.filled(7, true)).toInteger(), 127,
          reason: 'models.weekday-list#4');
      for (var packed = 0; packed <= 127; packed++) {
        final roundTripped = WeekdayList(packed).toInteger();
        expect(roundTripped, packed, reason: 'models.weekday-list#4');
        expect(roundTripped >= 0 && roundTripped <= 127, isTrue,
            reason: 'models.weekday-list#4');
      }
      expect(WeekdayList(255).toInteger(), 127,
          reason: 'models.weekday-list#4');
    });

    test('#5 toArray returns a defensive copy of length 7', () {
      final list = WeekdayList(127);
      final first = list.toArray();
      expect(first.length, 7, reason: 'models.weekday-list#5');
      first[0] = false;
      expect(list.toArray(), List<bool>.filled(7, true),
          reason: 'models.weekday-list#5');
      expect(list.toInteger(), 127, reason: 'models.weekday-list#5');
      expect(identical(list.toArray(), list.toArray()), isFalse,
          reason: 'models.weekday-list#5');
    });

    test('#6 isEmpty is true iff every element is false', () {
      expect(WeekdayList(0).isEmpty, isTrue, reason: 'models.weekday-list#6');
      expect(WeekdayList.fromArray(List<bool>.filled(7, false)).isEmpty, isTrue,
          reason: 'models.weekday-list#6');
      expect(WeekdayList.everyDay.isEmpty, isFalse,
          reason: 'models.weekday-list#6');
      for (var i = 0; i < 7; i++) {
        expect(WeekdayList(1 << i).isEmpty, isFalse,
            reason: 'models.weekday-list#6');
      }
      expect(WeekdayList(124).isEmpty, isFalse,
          reason: 'models.weekday-list#6');
    });

    test('#7 EVERY_DAY == WeekdayList(127)', () {
      expect(WeekdayList.everyDay, WeekdayList(127),
          reason: 'models.weekday-list#7');
      expect(WeekdayList.everyDay.toInteger(), 127,
          reason: 'models.weekday-list#7');
      expect(WeekdayList.everyDay.toArray(), List<bool>.filled(7, true),
          reason: 'models.weekday-list#7');
    });

    test('#8 round trip between array and packed integer', () {
      const daysInt = 124;
      const daysArray = [false, false, true, true, true, true, true];
      var list = WeekdayList.fromArray(daysArray);
      expect(list.toArray(), daysArray, reason: 'models.weekday-list#8');
      expect(list.toInteger(), daysInt, reason: 'models.weekday-list#8');
      list = WeekdayList(daysInt);
      expect(list.toArray(), daysArray, reason: 'models.weekday-list#8');
      expect(list.toInteger(), daysInt, reason: 'models.weekday-list#8');
    });

    test('#9 equals compares element-wise, hashCode is the content hash', () {
      expect(WeekdayList(124), WeekdayList(124),
          reason: 'models.weekday-list#9');
      expect(
          WeekdayList(124),
          WeekdayList.fromArray(
              const [false, false, true, true, true, true, true]),
          reason: 'models.weekday-list#9');
      expect(WeekdayList(124) == WeekdayList(125), isFalse,
          reason: 'models.weekday-list#9');
      expect(WeekdayList(124).hashCode,
          WeekdayList.fromArray(
                  const [false, false, true, true, true, true, true])
              .hashCode,
          reason: 'models.weekday-list#9');
      expect(WeekdayList(124).hashCode == WeekdayList(125).hashCode, isFalse,
          reason: 'models.weekday-list#9');
      // Identity and foreign types.
      final list = WeekdayList(3);
      expect(list == list, isTrue, reason: 'models.weekday-list#9');
      // ignore: unrelated_type_equality_checks
      expect(list == 3, isFalse, reason: 'models.weekday-list#9');
      expect({WeekdayList(124), WeekdayList(124)}.length, 1,
          reason: 'models.weekday-list#9');
    });

    test('#10 toString renders a comma-joined list with no spaces', () {
      expect(WeekdayList(0).toString(),
          '{weekdays: [false,false,false,false,false,false,false]}',
          reason: 'models.weekday-list#10');
      expect(
          WeekdayList.fromArray(
              const [false, false, true, true, true, true, true]).toString(),
          '{weekdays: [false,false,true,true,true,true,true]}',
          reason: 'models.weekday-list#10');
      expect(WeekdayList.everyDay.toString(),
          '{weekdays: [true,true,true,true,true,true,true]}',
          reason: 'models.weekday-list#10');
    });

    test('#12 index 0 = Saturday, 1 = Sunday, ... 6 = Friday', () {
      // NotificationTray computes the index as
      // (date.dayOfWeek.daysSinceSunday + 1) % 7.
      int indexOf(DayOfWeek weekday) => (weekday.daysSinceSunday + 1) % 7;

      expect(DayOfWeek.sunday.daysSinceSunday, 0,
          reason: 'models.weekday-list#12');
      expect(DayOfWeek.saturday.daysSinceSunday, 6,
          reason: 'models.weekday-list#12');

      expect(indexOf(DayOfWeek.saturday), 0, reason: 'models.weekday-list#12');
      expect(indexOf(DayOfWeek.sunday), 1, reason: 'models.weekday-list#12');
      expect(indexOf(DayOfWeek.monday), 2, reason: 'models.weekday-list#12');
      expect(indexOf(DayOfWeek.tuesday), 3, reason: 'models.weekday-list#12');
      expect(indexOf(DayOfWeek.wednesday), 4, reason: 'models.weekday-list#12');
      expect(indexOf(DayOfWeek.thursday), 5, reason: 'models.weekday-list#12');
      expect(indexOf(DayOfWeek.friday), 6, reason: 'models.weekday-list#12');

      // A list holding only Saturday is bit 0, and only fires on a Saturday.
      final onlySaturday = WeekdayList(1);
      // 2000-01-01 was a Saturday.
      final saturday = LocalDate.ymd(2000, 1, 1);
      expect(saturday.dayOfWeek, DayOfWeek.saturday,
          reason: 'models.weekday-list#12');
      for (var offset = 0; offset < 7; offset++) {
        final date = saturday.plus(offset);
        final fires =
            onlySaturday.toArray()[(date.dayOfWeek.daysSinceSunday + 1) % 7];
        expect(fires, offset == 0, reason: 'models.weekday-list#12');
      }

      // Weekends only (Saturday = bit 0, Sunday = bit 1) packs to 3.
      final weekend = WeekdayList.fromArray(
          const [true, true, false, false, false, false, false]);
      expect(weekend.toInteger(), 3, reason: 'models.weekday-list#12');
      for (var offset = 0; offset < 7; offset++) {
        final date = saturday.plus(offset);
        final fires =
            weekend.toArray()[(date.dayOfWeek.daysSinceSunday + 1) % 7];
        final isWeekend = date.dayOfWeek == DayOfWeek.saturday ||
            date.dayOfWeek == DayOfWeek.sunday;
        expect(fires, isWeekend, reason: 'models.weekday-list#12');
      }
    });

    test('#11 the bit index is only meaningful through Reminder: index 0 is '
        'the first slot of the reminder_days column', () {
      final factory = MemoryModelFactory();

      for (var i = 0; i <= 6; i++) {
        final habit = factory.buildHabit()
          ..reminder = Reminder(8, 30, WeekdayList(1 << i));
        final row = SQLiteHabitList.copyFrom(habit);
        expect(row.reminderDays, 1 << i, reason: 'models.weekday-list#11');

        final reloaded = factory.buildHabit();
        SQLiteHabitList.copyTo(row, reloaded);
        final days = reloaded.reminder!.days.toArray();
        expect(days[i], isTrue, reason: 'models.weekday-list#11');
        expect(days.where((d) => d).length, 1,
            reason: 'models.weekday-list#11');
      }

      // Index 0 is bit 0, which is the low bit of the stored integer.
      final firstSlot = factory.buildHabit()
        ..reminder = Reminder(8, 30, WeekdayList.fromArray(
            const [true, false, false, false, false, false, false]));
      expect(SQLiteHabitList.copyFrom(firstSlot).reminderDays, 1,
          reason: 'models.weekday-list#11');

      // The mask travels with the Reminder and nowhere else: with no reminder
      // there is no weekday list on the habit at all, whatever the column says.
      final noReminder = factory.buildHabit();
      SQLiteHabitList.copyTo(HabitData(reminderDays: 127), noReminder);
      expect(noReminder.reminder, isNull, reason: 'models.weekday-list#11');
    });

    test('#13 the habit column stores the packed integer, and 0 when there is '
        'no reminder', () {
      final factory = MemoryModelFactory();

      for (final packed in <int>[0, 1, 3, 96, 124, 127]) {
        final habit = factory.buildHabit()
          ..reminder = Reminder(8, 30, WeekdayList(packed));
        expect(SQLiteHabitList.copyFrom(habit).reminderDays, packed,
            reason: 'models.weekday-list#13');
      }

      // toInteger() is exactly what is written.
      final everyDay = factory.buildHabit()
        ..reminder = Reminder(8, 30, WeekdayList.everyDay);
      expect(SQLiteHabitList.copyFrom(everyDay).reminderDays,
          WeekdayList.everyDay.toInteger(),
          reason: 'models.weekday-list#13');
      expect(SQLiteHabitList.copyFrom(everyDay).reminderDays, 127,
          reason: 'models.weekday-list#13');

      // No reminder at all: the column is 0, not NULL and not 127.
      final plain = factory.buildHabit();
      expect(plain.hasReminder(), isFalse, reason: 'models.weekday-list#13');
      expect(SQLiteHabitList.copyFrom(plain).reminderDays, 0,
          reason: 'models.weekday-list#13');

      // A stored 0 loads back as the empty list when the times are present.
      final loaded = factory.buildHabit();
      SQLiteHabitList.copyTo(
          HabitData(reminderHour: 8, reminderMin: 30, reminderDays: 0), loaded);
      expect(loaded.reminder!.days, WeekdayList(0),
          reason: 'models.weekday-list#13');
      expect(loaded.reminder!.days.isEmpty, isTrue,
          reason: 'models.weekday-list#13');
    });
  });
}
