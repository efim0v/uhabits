import '../models/habit.dart';
import '../time/local_date.dart';
import 'day_writer.dart';
import 'habit_definition.dart';
import 'lapse_day_value.dart';
import 'lapse_repository.dart';

/// Свод воздержания: журнал срывов → значения дней.
///
/// Ровно та же четвёрка ролей, что у сна («Конвейер» спецификации): источник —
/// палец человека, хранилище — [LapseRepository], определение —
/// [lapseDayValue] с допуском из [HabitDefinition], свод — этот класс.
/// Считает по диапазону, а не по дню: у «дней без срыва» балл дня зависит от
/// прошлого ровно так же, как у свёртки часового пояса во сне.
class AbstinenceSync {
  AbstinenceSync({required this.lapses, required this.writer});

  final LapseRepository lapses;

  /// Единственная дверь записи. Она же — та, что пересчитывает привычку и один
  /// раз объявляет об изменении: в приложении сюда приходит `DayWriter`,
  /// собранный с тем же `onChanged`, что и у сна (`computed.freshness#2`).
  ///
  /// Обязательный параметр без значения по умолчанию — намеренно, той же
  /// причины ради, что и у `SleepSync.writer`: `const DayWriter()` по
  /// умолчанию дал бы собрать свод с молчащей дверью, и он бы скомпилировался,
  /// позеленел в тестах и клал бы дни на диск, пока список показывает
  /// прежнее. Кому нужна тишина — всякому здешнему тесту ядра — тот пишет
  /// `const DayWriter()` сам, и это видно.
  final DayWriter writer;

  /// Записывает или снимает срыв за [date] и пересчитывает день.
  ///
  /// Идемпотентно: повторный `setLapse(h, d, true)` даёт один срыв — журнал
  /// заменяет строку (`computed.lapses#3`), а [DayWriter] не переписывает
  /// неизменившееся значение (`computed.day-write#5`).
  ///
  /// Снятие идёт не через запись null: `writeDays` на null означает «сказать
  /// нечего» и оставляет запись как была (`computed.day-write#3`). Здесь
  /// сказано другое — «того, что было записано, не было», — и это
  /// [DayWriter.clear] (`computed.day-write#8`).
  void setLapse(Habit habit, LocalDate date, bool lapsed, {int? amount}) {
    final int id = habit.id!;
    final int day = date.daysSince2000;
    if (lapsed) {
      lapses.save(id, day, amount: amount ?? LapseRepository.minimumAmount);
      recomputeDays(habit, day, day);
    } else {
      lapses.remove(id, day);
      writer.clear(habit, day);
    }
  }

  /// Пересчитывает дни `[fromDay, toDay]` из журнала.
  ///
  /// Зовётся и при смене допуска: понижение с 30 до 10 обязано переоценить уже
  /// записанные дни (`computed.allowance#1`), а значение дня есть величина, и
  /// от допуска не зависит — зависит от него ветвь деления пополам, поэтому
  /// пересчёт нужен весь.
  bool recomputeDays(Habit habit, int fromDay, int toDay) {
    final int id = habit.id!;
    final Map<int, int> journal = lapses.range(id, fromDay, toDay);
    final Map<int, int?> values = <int, int?>{};
    for (int day = fromDay; day <= toDay; day++) {
      values[day] = lapseDayValue(journal[day] ?? 0);
    }
    return writer.writeDays(habit, values);
  }

  /// Весь диапазон обязательства — от `committedFrom` до сегодня.
  ///
  /// Нет дня обязательства — нет и обязательства, которое можно переоценить:
  /// подставленный вместо него ноль накрыл бы двадцать шесть лет до эпохи
  /// (`computed.commitment#6`).
  bool recomputeAll(Habit habit, HabitDefinition definition) {
    final int? from = definition.committedFrom;
    if (from == null) return false;
    return recomputeDays(habit, from, getToday().daysSince2000);
  }
}
