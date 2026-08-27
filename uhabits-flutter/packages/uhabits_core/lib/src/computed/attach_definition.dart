import '../models/habit.dart';
import 'definition_repository.dart';
import 'lapse_scoring.dart';

/// Прикрепляет к живой привычке её определение.
///
/// Одна дверь, а не строчка в каждом месте загрузки: правило «живая привычка
/// знает, что она вычисляемая» разъедется по местам ровно так же, как разъехались
/// бы правила записи дня, не будь `DayWriter`.
///
/// Не в `SQLiteHabitList`: это портированный класс, чей `_loadRecords`
/// повторяет котлиновский построчно, и знать о боковой таблице ему нечем.
///
/// Незнакомый вид даёт null — [DefinitionRepository.forHabit] отвечает «нечем
/// считать», и привычка считается по паритетному окну. Запись при этом
/// по-прежнему закрыта: её сторожит [DefinitionRepository.isComputed], которому
/// хватает наличия строки (`computed.definition#9`).
void attachDefinition(Habit habit, DefinitionRepository definitions) {
  final int? id = habit.id;
  if (id == null) return;
  habit.definition = definitions.forHabit(id);
  // Арифметика вида — часть определения, а не отдельная память: объект
  // привычки переживает и снятие определения, и восстановление копии, и
  // включатель, вызываемый где-то ещё, был бы вторым местом, где живёт одно
  // правило (`computed.lapse-score#11`).
  applyLapseScoring(habit, habit.definition);
}

/// То же для всего списка.
///
/// Не пересчитывает: зовущий пересчитывает всё равно и сразу, а лишний обход
/// всей истории на старте стоит дороже этой строчки.
void attachDefinitions(
  Iterable<Habit> habits,
  DefinitionRepository definitions,
) {
  for (final Habit habit in habits) {
    attachDefinition(habit, definitions);
  }
}
