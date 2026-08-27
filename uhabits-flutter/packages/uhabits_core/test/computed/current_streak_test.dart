import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
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
}
