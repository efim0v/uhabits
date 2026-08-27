/// Блоки, которые получает привычка-воздержание и не получает никакая другая.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../list/list_header.dart' show IntlLocalDateFormatter;
import 'abstinence_button_view.dart' show isAbstinenceLapseDay;
import 'abstinence_counter.dart';
import 'abstinence_gestures.dart';

/// Функция, а не виджет: она отдаёт те же карточки, что и портированная
/// колонка, и обёртка вокруг них поставила бы шов посреди одного экрана.
/// Ровно как `buildSleepSection`.
List<Widget> buildAbstinenceSection(
  BuildContext context, {
  required AppScope scope,
  required core.Habit habit,
  required core.HabitDefinition definition,
  required core.Theme theme,
  required VoidCallback onChanged,
}) {
  final int committedFrom = definition.committedFrom!;
  final core.LocalDate today = core.getToday();
  // Один судья и один вход. Судья — `isAbstinenceLapseDay(definition,
  // хранимое значение дня)`, тот же, которым судят ячейка списка, сетка
  // календаря, «Всего» на кольце и кнопка ниже. Вход — `habit.computedEntries`,
  // тот самый список, который читают они же.
  //
  // Одного судьи мало: журнал и значения дней расходятся. `DayWriter` не
  // переписывает пропуск (`computed.day-write#4`), и строка журнала, поданная
  // на пропущенный день, остаётся строкой без дня. Подпись, читавшая журнал,
  // объявляла тогда «Последний срыв: 28 августа» рядом с числом «40 дней без
  // срыва», пока ячейка и календарь показывали пропуск, а «Всего» — ноль:
  // четыре поверхности, один судья, два входа, два ответа. Снять этот срыв
  // человеку было нечем — обе двери записи пропуск охраняют.
  //
  // Диапазон — от дня обязательства до сегодня, а не весь список: день до
  // обязательства не был срывом обязательства, которого ещё не было тогда, а
  // день позже сегодня ещё не наступил — последний срыв не может лежать в
  // будущем. `getByInterval` отдаёт дни от новых к старым, поэтому первое
  // совпадение и есть последний срыв.
  final List<core.Entry> days = habit.computedEntries
      .getByInterval(core.LocalDate(committedFrom), today);
  int? lastLapse;
  for (final core.Entry entry in days) {
    if (isAbstinenceLapseDay(definition, entry.value)) {
      lastLapse = entry.date.daysSince2000;
      break;
    }
  }
  final int todayValue = habit.computedEntries.get(today).value;
  final bool lapsedToday = isAbstinenceLapseDay(definition, todayValue);
  // Пропуск — отметка человека, и кнопка её не переписывает: `DayWriter` всё
  // равно откажет (`computed.day-write#4`), а нажатие, которое пишет строку
  // журнала и не двигает день, оставляет ровно тот призрак, ради которого
  // подпись выше переехала на значения дней. Тот же охранник стоит у ячейки
  // списка (`entry_panel.dart`) и у клетки календаря
  // (`show_habit_screen.dart`).
  final bool skippedToday = todayValue == core.Entry.skip;
  final IntlLocalDateFormatter formatter = IntlLocalDateFormatter.of(context);
  final L10n l10n = L10n.of(context);

  return <Widget>[
    AbstinenceCounterCard(
      theme: theme,
      days: core.daysWithoutLapse(habit),
      subtitle: lastLapse == null
          ? l10n.abstinenceSince(
              formatter.longFormat(core.LocalDate(committedFrom)))
          : l10n.abstinenceLastLapse(
              formatter.longFormat(core.LocalDate(lastLapse))),
      lapsedToday: lapsedToday,
      // `onChanged` под условием: перерисовывать экран, когда ничего не
      // записано, незачем, и надпись на кнопке от этого не поменяется.
      onToggleToday: skippedToday
          ? null
          : () async {
              final bool written = await toggleLapseDay(
                context,
                scope,
                habit: habit,
                definition: definition,
                date: today,
                lapsed: !lapsedToday,
                theme: theme,
              );
              if (written) onChanged();
            },
    ),
  ];
}
