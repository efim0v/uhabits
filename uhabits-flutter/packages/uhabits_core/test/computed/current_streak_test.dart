import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/days_without_lapse.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  late LocalDate today;
  late EntryList entries;
  late StreakList streaks;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
    entries = EntryList();
    streaks = StreakList();
  });

  tearDown(resetToday);

  /// Ровно то, что передаёт Habit.recompute: вычисленные записи, нижняя
  /// граница и сегодня + 30. EntryList.getByInterval сам отдаёт UNKNOWN за
  /// дни, которых в нём нет, так что подделывать нечего.
  void recomputeBoolean() {
    streaks.recompute(
      entries.getByInterval,
      today.minus(60),
      today.plus(30),
      false,
      0.0,
      NumericalHabitType.atLeast,
    );
  }

  group('computed.streak', () {
    test('#3 the current streak is the one that covers the day', () {
      for (final int offset in <int>[0, 1, 2, 10, 11]) {
        entries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      recomputeBoolean();

      expect(streaks.getCurrent(today), Streak(today.minus(2), today),
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today.minus(1)), Streak(today.minus(2), today),
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today.minus(11)),
          Streak(today.minus(11), today.minus(10)),
          reason: 'computed.streak#3');
    });

    test('#3 a day between two streaks belongs to neither', () {
      entries.add(Entry(today, Entry.yesManual));
      entries.add(Entry(today.minus(2), Entry.yesManual));
      recomputeBoolean();

      expect(streaks.getCurrent(today.minus(1)), isNull,
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today.minus(30)), isNull,
          reason: 'computed.streak#3');
      expect(StreakList().getCurrent(today), isNull,
          reason: 'computed.streak#3');
    });

    test('#3 the answer survives the reordering getBest leaves behind', () {
      // Длинная старая серия и короткая сегодняшняя: после getBest(1)
      // внутренний список начинается с длинной, то есть НЕ с текущей.
      for (final int offset in <int>[0, 5, 6, 7, 8, 9]) {
        entries.add(Entry(today.minus(offset), Entry.yesManual));
      }
      recomputeBoolean();

      expect(streaks.getBest(1).single, Streak(today.minus(9), today.minus(5)),
          reason: 'computed.streak#3');
      expect(streaks.getCurrent(today), Streak(today, today),
          reason: 'computed.streak#3');
    });
  });

  group('computed.streak silence', () {
    void recomputeAtMost({required bool silenceQualifies}) {
      streaks.recompute(
        entries.getByInterval,
        today.minus(10),
        today.plus(30),
        true,
        0.0,
        NumericalHabitType.atMost,
        silenceQualifies: silenceQualifies,
      );
    }

    test('#1 with silenceQualifies a day holding nothing extends the streak',
        () {
      // Ни одной записи вообще: для воздержания это сорок чистых дней, а не
      // отсутствие истории.
      recomputeAtMost(silenceQualifies: true);

      expect(streaks.getCurrent(today),
          Streak(today.minus(10), today.plus(30)),
          reason: 'computed.streak#1');

      // Срыв четыре дня назад режет её надвое, и молчание по обе стороны
      // остаётся успехом.
      entries.add(Entry(today.minus(4), 1000));
      recomputeAtMost(silenceQualifies: true);

      expect(streaks.getCurrent(today), Streak(today.minus(3), today.plus(30)),
          reason: 'computed.streak#1');
      expect(streaks.getCurrent(today.minus(4)), isNull,
          reason: 'computed.streak#1');
      expect(streaks.getCurrent(today.minus(5)),
          Streak(today.minus(10), today.minus(5)),
          reason: 'computed.streak#1');
    });

    test('#2 by default silence still breaks an at-most streak', () {
      entries.add(Entry(today, Entry.no));
      entries.add(Entry(today.minus(2), Entry.no));
      recomputeAtMost(silenceQualifies: false);

      expect(streaks.getCurrent(today), Streak(today, today),
          reason: 'computed.streak#2');
      expect(streaks.getCurrent(today.minus(1)), isNull,
          reason: 'computed.streak#2');
      expect(streaks.getBest(10).length, 2, reason: 'computed.streak#2');

      // И то же самое, когда параметр не передан вовсе: умолчание есть
      // паритетное поведение (`models.streak-computation#3`).
      streaks.recompute(
        entries.getByInterval,
        today.minus(10),
        today.plus(30),
        true,
        0.0,
        NumericalHabitType.atMost,
      );
      expect(streaks.getBest(10).length, 2, reason: 'computed.streak#2');
    });
  });

  group('computed.streak days without a lapse', () {
    Habit buildAbstinence(int committedFromOffset) =>
        MemoryModelFactory().buildHabit()
          ..name = 'No sugar'
          ..type = HabitType.numerical
          ..targetType = NumericalHabitType.atMost
          ..targetValue = 0.0
          ..definition = HabitDefinition(
            kind: ComputedKind.abstinence,
            committedFrom: today.minus(committedFromOffset).daysSince2000,
          );

    test('#4 counts up to today and ignores the future tail of the window',
        () {
      final Habit habit = buildAbstinence(40);
      habit.recompute();

      // Серия тянется до today + 30, но дней без срыва — сорок.
      expect(habit.streaks.getCurrent(today)?.end, today.plus(30),
          reason: 'computed.streak#4');
      expect(daysWithoutLapse(habit), 40, reason: 'computed.streak#4');
    });

    test('#4 a lapse restarts the count the next day', () {
      final Habit habit = buildAbstinence(40);
      habit.originalEntries.add(Entry(today.minus(10), 1000));
      habit.recompute();

      // Срыв был десять дней назад: серия началась девять дней назад, и
      // прошедшего времени в ней девять дней.
      expect(daysWithoutLapse(habit), 9, reason: 'computed.streak#4');
      expect(daysWithoutLapse(habit, asOf: today.minus(11)), 29,
          reason: 'computed.streak#4');
    });

    test('#4 a commitment made for tomorrow gives zero, not a negative', () {
      // Перенесено из раздела списка вместе с функцией: арифметика счётчика
      // живёт там же, где счётчик, и «обещание в будущем» проверяется тут.
      final Habit habit = MemoryModelFactory().buildHabit()
        ..name = 'No sugar'
        ..type = HabitType.numerical
        ..targetType = NumericalHabitType.atMost
        ..targetValue = 0.0
        ..definition = HabitDefinition(
          kind: ComputedKind.abstinence,
          committedFrom: today.plus(1).daysSince2000,
        );
      habit.recompute();

      expect(daysWithoutLapse(habit), 0, reason: 'computed.streak#4');
    });

    test('#5 a lapse today gives zero', () {
      final Habit habit = buildAbstinence(40);
      habit.originalEntries.add(Entry(today, 1000));
      habit.recompute();

      expect(daysWithoutLapse(habit), 0, reason: 'computed.streak#5');

      // И обычная привычка без единой серии тоже даёт ноль, а не падает.
      expect(daysWithoutLapse(MemoryModelFactory().buildHabit()..recompute()),
          0,
          reason: 'computed.streak#5');
    });
  });
}
