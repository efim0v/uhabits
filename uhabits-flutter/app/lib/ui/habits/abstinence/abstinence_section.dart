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
  // Тот же судья, что у ячейки, у кнопки и у счётчика:
  // `core.isAbstinenceLapse(definition, величина)`. `lapses.lastDay` отвечал
  // бы на другой вопрос — «есть ли запись», а не «был ли срыв», — и при
  // допуске 30 запись в двадцать минут дала бы подпись «последний срыв:
  // сегодня» рядом с кнопкой «отметить срыв» и числом «40» — три ответа на
  // один вопрос на одной карточке (`computed.abstinence-screen#2`). Ранее
  // здесь стоял именно этот второй судья; это и был дефект.
  //
  // Диапазон — от дня обязательства до сегодня, а не весь журнал: строка до
  // обязательства не была срывом обязательства, которого ещё не было тогда, а
  // строка позже сегодня ещё не наступила — последний срыв не может лежать в
  // будущем. Оба края и есть та отдельная развилка, о которой предупреждает
  // ревью: старая проверка `lastLapse < committedFrom` теперь не нужна,
  // потому что диапазон уже не выходит за неё.
  final Map<int, int> journal =
      scope.lapses.range(id, committedFrom, today.daysSince2000);
  int? lastLapse;
  for (final MapEntry<int, int> entry in journal.entries) {
    if (core.isAbstinenceLapse(definition, entry.value)) lastLapse = entry.key;
  }
  final bool lapsedToday =
      isAbstinenceLapseDay(definition, habit.originalEntries.get(today).value);
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
