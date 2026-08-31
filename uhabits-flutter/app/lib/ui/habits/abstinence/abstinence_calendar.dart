/// Чем воздержание отвечает портированным карточкам экрана: чем красить дни
/// в сетке календаря и что считать в «Всего» на кольце Overview.
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
/// словарь той карточки, которая спрашивает (`computed.abstinence-screen#10`,
/// `#4`).
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

/// Яркость дня в сетке, или null — красить как порт.
///
/// Яркость дня есть оценка в этот день: кольцо, сетка и уровень — одна кривая,
/// показанная тремя способами (`computed.abstinence-screen#13`). У дня срыва
/// яркости нет вовсе — не ноль, а `null`: `Square.grey` там уже есть
/// contrast60 (`computed.abstinence-screen#10`), а смешивание к цвету
/// привычки читалось бы как «наполовину сорвался». Судья тот же
/// `abstinenceCellOf`, что красит день срыва серым, второго не заводится
/// (`computed.abstinence-cell#2`).
double? Function(core.Entry)? abstinenceIntensityOf(core.Habit habit) {
  final core.HabitDefinition? definition = abstinenceCommitmentOf(habit);
  if (definition == null) return null;
  return (core.Entry entry) {
    final AbstinenceCell cell = abstinenceCellOf(
      definition: definition,
      storedValue: entry.value,
      day: entry.date.daysSince2000,
    );
    if (cell == AbstinenceCell.lapse) return null;
    return habit.scores[entry.date].value;
  };
}

/// Сколько дней показывать за серию, или null — считать как порт.
///
/// Воздержание измеряет выдержанное время, и сегодняшний день ещё идёт
/// (`computed.streak#8`).
int Function(core.Streak)? abstinenceStreakLengthOf(core.Habit habit) {
  if (abstinenceCommitmentOf(habit) == null) return null;
  return (core.Streak streak) => core.elapsedDaysOf(streak);
}

/// Что идёт в счёт «Всего» на кольце Overview, или null — считать как порт.
///
/// Портированный счёт складывает дни, равные `Entry.yesManual`: отметки,
/// сделанные рукой. Воздержание не пишет их никогда — оно вообще ничего не
/// пишет, пока его держат, — и «Всего» читало ноль вечно, рядом с кольцом,
/// счётчиком и календарём, у каждого из которых было что показать.
///
/// Считаются срывы: единственное, что эта привычка записывает, и ровно те
/// дни, которые сетка красит крестом. Судья тот же — `abstinenceCellOf`, — и
/// день до обещания в счёт не идёт по той же причине, по которой он не
/// красится (`computed.abstinence-cell#3`).
bool Function(core.Entry)? abstinenceCountsTowardsTotal(core.Habit habit) {
  final Square Function(core.Entry)? square = abstinenceSquareOf(habit);
  if (square == null) return null;
  return (core.Entry entry) => square(entry) == Square.grey;
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
