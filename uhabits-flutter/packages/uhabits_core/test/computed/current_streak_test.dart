import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/days_without_lapse.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/streak.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/streak_card.dart';
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

      expect(streaks.getCurrent(today), Streak(today.minus(10), today),
          reason: 'computed.streak#1');

      // Срыв четыре дня назад режет её надвое, и молчание по обе стороны
      // остаётся успехом.
      entries.add(Entry(today.minus(4), 1000));
      recomputeAtMost(silenceQualifies: true);

      expect(streaks.getCurrent(today), Streak(today.minus(3), today),
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

    test('#7 a skip does not break a streak where silence is success', () {
      // Пропуск защищён в четырёх местах — оценкой, сводом, дверью записи,
      // ячейкой — и был уронен в пятом: `Entry.skip` есть 3, то есть 0.003,
      // и при допуске ноль числовое сравнение выбрасывало его из серии.
      entries.add(Entry(today.minus(3), Entry.skip));
      recomputeAtMost(silenceQualifies: true);

      expect(streaks.getCurrent(today), Streak(today.minus(10), today),
          reason: 'computed.streak#7 — «сегодня меня тут нет» не есть срыв');

      // И портированное сравнение не сдвинулось: при выключенном признаке
      // пропуск судится как 0.003 — при цели 5 он в неё укладывается, и
      // серия из него одного существует (`models.streak-computation#3`).
      streaks.recompute(
        entries.getByInterval,
        today.minus(10),
        today.plus(30),
        true,
        5.0,
        NumericalHabitType.atMost,
      );
      expect(streaks.getCurrent(today.minus(3)),
          Streak(today.minus(3), today.minus(3)),
          reason: 'computed.streak#2 — умолчание есть паритетное поведение');
    });

    test('#2 a ported habit keeps the future tail of its window', () {
      // Обрезка хвоста стоит под тем же признаком, что и впуск молчания, и
      // это обязательное условие, а не осторожность. Хвост есть и у привычки
      // оригинала: `EntryList.recomputeFrom` заполняет интервал шириной в
      // знаменатель, то есть при частоте 1/7 отметка сегодня даёт YES_AUTO на
      // шесть дней вперёд, и котлиновская `StreakList` кладёт их в серию.
      // Безусловная обрезка сделала бы из семи дней один на карточке всякой
      // непоследовательной привычки оригинала.
      final Habit habit = MemoryModelFactory().buildHabit()
        ..name = 'Weekly'
        ..type = HabitType.yesNo
        ..frequency = Frequency(1, 7);
      habit.originalEntries.add(Entry(today, Entry.yesManual));
      habit.recompute();

      expect(habit.streaks.getBest(1).single, Streak(today, today.plus(6)),
          reason: 'computed.streak#2 — умолчание есть паритетное поведение, '
              'вместе с хвостом (`models.streak-computation#3`)');
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

    test('#4 counts elapsed time from the start of the streak', () {
      final Habit habit = buildAbstinence(40);
      habit.recompute();

      expect(habit.streaks.getCurrent(today)?.start, today.minus(40),
          reason: 'computed.streak#4');
      expect(daysWithoutLapse(habit), 40, reason: 'computed.streak#4');
    });

    test('#6 the streak card and the counter agree, and the date has '
        'happened', () {
      // Ревью нашло это на экране: счётчик говорил «10 дней без срыва», а
      // карточка серий под ним — «41 день, до 19 сентября», даты, которой
      // ещё не было. Одна и та же `StreakList` отвечала двоим по-разному,
      // потому что хвост окна в тридцать дней вперёд входил в серию целиком.
      final Habit habit = buildAbstinence(10);
      habit.recompute();

      final StreakCardState card =
          StreakCartPresenter.buildState(habit, LightTheme());
      final Streak shown = card.bestStreaks.first;

      expect(shown.end, today,
          reason: 'computed.streak#6 — карточка не вправе показывать дату, '
              'которой ещё не было');
      expect(shown.length, 11,
          reason: 'computed.streak#6 — одиннадцать прожитых дней, а не сорок '
              'один; тридцать из них ещё не наступили');
      expect(daysWithoutLapse(habit), 10,
          reason: 'computed.streak#4 — счётчик считает прошедшее время от '
              'начала той же серии');
    });

    test('#6 a lapse still cuts the streak where it happened', () {
      // Обрезка хвоста ничего не делает с прошлым: срыв четыре дня назад
      // по-прежнему начинает новую серию на следующий день.
      final Habit habit = buildAbstinence(40);
      habit.originalEntries.add(Entry(today.minus(4), 1000));
      habit.recompute();

      final Streak? current = habit.streaks.getCurrent(today);
      expect(current, Streak(today.minus(3), today),
          reason: 'computed.streak#6');
      expect(habit.streaks.getCurrent(today.minus(5)),
          Streak(today.minus(40), today.minus(5)),
          reason: 'computed.streak#6');
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
