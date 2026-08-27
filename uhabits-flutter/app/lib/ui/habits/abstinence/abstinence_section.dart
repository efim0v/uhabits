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
  final int id = habit.id!;
  final int committedFrom = definition.committedFrom!;
  final core.LocalDate today = core.getToday();
  // Из журнала берётся только подпись: какое число показать, знает ядро.
  final int? lastLapse = scope.lapses.lastDay(id);
  // Тот же судья, что у ячейки и у оценки. «Есть запись в дне» ответило бы не
  // на тот вопрос: при допуске 30 двадцать минут записаны, а срыва нет, и
  // кнопка предложила бы «Отменить срыв» там, где счётчик показывает
  // сорок дней без срыва.
  final bool lapsedToday =
      isAbstinenceLapseDay(definition, habit.originalEntries.get(today).value);
  final IntlLocalDateFormatter formatter = IntlLocalDateFormatter.of(context);
  final L10n l10n = L10n.of(context);

  return <Widget>[
    AbstinenceCounterCard(
      theme: theme,
      days: core.daysWithoutLapse(habit),
      subtitle: lastLapse == null || lastLapse < committedFrom
          ? l10n.abstinenceSince(
              formatter.longFormat(core.LocalDate(committedFrom)))
          : l10n.abstinenceLastLapse(
              formatter.longFormat(core.LocalDate(lastLapse))),
      lapsedToday: lapsedToday,
      // `onChanged` под условием: перерисовывать экран, когда ничего не
      // записано, незачем, и надпись на кнопке от этого не поменяется.
      onToggleToday: () async {
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
