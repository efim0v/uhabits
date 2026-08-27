/// Как календарь рисует дни привычки-воздержания.
///
/// Портированный `HistoryCardPresenter.buildState` красит числовой день двумя
/// ветками — «уложился в цель» и «не уложился», — и для воздержания это
/// четвёртый ответ на вопрос «удался ли день». Молчание он читает как
/// `Entry.unknown` → `Square.off`, самый бледный оттенок сетки: держащий
/// обещание сорок дней видел пустоту, единственными заметными квадратами были
/// провалы, а при допуске 30 день с двадцатью минутами выходил ярче дня полной
/// трезвости.
///
/// Своего судьи здесь нет. День классифицирует та же `abstinenceCellOf`, что
/// рисует ячейку списка, и весь этот файл — перевод её четырёх ответов в
/// словарь сетки (`computed.abstinence-screen#10`).
library;

// Путь `src` — ровно как в abstinence_button_view.dart и в history_card_view.dart:
// корневая библиотека ядра `Square` не отдаёт.
// ignore_for_file: implementation_imports

import 'package:uhabits_core/src/ui/views/history_chart.dart' show Square;
import 'package:uhabits_core/uhabits_core.dart' as core;

import 'abstinence_button_view.dart' show AbstinenceCell, abstinenceCellOf;

/// Определение воздержания, по которому красится день, или null для всякой
/// другой привычки.
///
/// Спрашивается у самой привычки, а не у репозитория, и это не сокращение:
/// `Habit.recompute()` судит по этому же полю — им включается
/// `silenceQualifies` и им двигается нижняя граница окна, — так что календарь,
/// заглянувший во второй источник, разошёлся бы с серией и баллом на одном
/// экране. Поле ставит одна дверь, `attachDefinition`, при открытии приложения
/// и при каждом сохранении (`computed.commitment#5`, `#7`).
///
/// Признак — тот же, что у ячейки списка: вид `abstinence` **с непустым** днём
/// обещания. Неполное определение воздержанием не делает
/// (`computed.abstinence-cell#7`).
core.HabitDefinition? abstinenceCommitmentOf(core.Habit habit) {
  final core.HabitDefinition? definition = habit.definition;
  if (definition == null) return null;
  if (definition.kind != core.ComputedKind.abstinence) return null;
  if (definition.committedFrom == null) return null;
  return definition;
}

/// Классификатор дня для сетки, или null — красить дословно как порт.
///
/// Словарь сетки повторяет словарь ячейки: чистый день есть цвет привычки
/// (`Square.on`), срыв — contrast60 (`Square.grey`), пропуск — штриховка,
/// день до обещания — пустая клетка, ровно как ячейка списка не рисует в нём
/// ничего (`computed.abstinence-cell#3`).
Square Function(core.Entry)? abstinenceSquareOf(core.Habit habit) {
  final core.HabitDefinition? definition = abstinenceCommitmentOf(habit);
  if (definition == null) return null;
  return (core.Entry entry) {
    switch (abstinenceCellOf(
      definition: definition,
      storedValue: entry.value,
      day: entry.date.daysSince2000,
    )) {
      case AbstinenceCell.beforeCommitment:
        return Square.off;
      case AbstinenceCell.clean:
        return Square.on;
      case AbstinenceCell.lapse:
        return Square.grey;
      case AbstinenceCell.skipped:
        return Square.hatched;
    }
  };
}

/// Первый день сетки воздержания, или null — начинать со старейшей записи.
///
/// Привычка, которая ничего не пишет, пока её держат, старейшей записи не
/// имеет вовсе, и сетка сорока безупречных дней была бы шириной в один
/// сегодняшний квадрат. Тот же довод, по которому день обещания двигает окно
/// пересчёта (`computed.commitment#1`), двигает и начало сетки.
core.LocalDate? abstinenceOldestDay(core.Habit habit) {
  final core.HabitDefinition? definition = abstinenceCommitmentOf(habit);
  if (definition == null) return null;
  return core.LocalDate(definition.committedFrom!);
}
