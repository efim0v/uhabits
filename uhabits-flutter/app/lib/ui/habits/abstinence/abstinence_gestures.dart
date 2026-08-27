/// Единственная дверь, которой жест пишет срыв.
library;

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../state/app_scope.dart';
import 'abstinence_amount_dialog.dart';

/// Записывает или снимает срыв за [date]. Отвечает, записала ли.
///
/// Одна функция, а не вызов на каждом жесте: путей записи два — ячейка списка
/// и календарь на экране привычки, — и правило, размазанное по обоим, будет
/// донесено до одного.
///
/// [amount] — измеренная величина дня в единице привычки. `null` значит «одна
/// единица»: при допуске ноль тап и есть весь факт, спрашивать нечего
/// (`computed.lapses#2`). Когда допуск больше нуля, величину спрашивают —
/// но спрашивают выше, в [toggleLapseDay]; эта дверь только пишет.
///
/// Об изменении **не объявляет**: это делает `DayWriter`, которым собран
/// `AbstinenceSync` в `AppScope.open` (Задача 24). Второй вызов
/// `onComputedDataChanged` отсюда дал бы два объявления на один тап — и, что
/// хуже, снял бы вопрос «а пересчитана ли привычка до объявления»
/// (`computed.freshness#2`, `#4`).
bool setLapseDay(
  AppScope scope, {
  required core.Habit habit,
  required core.LocalDate date,
  required bool lapsed,
  int? amount,
}) {
  final int? id = habit.id;
  if (id == null) return false;
  scope.abstinence.setLapse(habit, date, lapsed, amount: amount);
  return true;
}

/// Жест «сорвался» / «не сорвался» целиком: спрашивает величину, когда допуск
/// её требует, пишет и отвечает, записал ли.
///
/// Одна дверь на все три жеста — ячейку списка, кнопку карточки и день в
/// календаре, — потому что «спрашивать или не спрашивать» есть правило
/// привычки, а не свойство места, откуда по ней попали. Развести это по трём
/// местам значит завести три правила, из которых совпадать будут два.
///
/// Ответ нужен вызывающему: панель красит ячейку до записи, и «ничего не
/// записано» она обязана уметь отменить.
Future<bool> toggleLapseDay(
  BuildContext context,
  AppScope scope, {
  required core.Habit habit,
  required core.HabitDefinition definition,
  required core.LocalDate date,
  required bool lapsed,
  required core.Theme theme,
}) async {
  // Снятие величины не имеет: «этого не было» — не количество.
  if (!lapsed) {
    return setLapseDay(scope, habit: habit, date: date, lapsed: false);
  }
  // Допуск ноль — умолчание: тап и есть весь факт, и одна единица есть всё,
  // что он может значить (`computed.lapses#2`).
  if (core.abstinenceAllowanceOf(definition) <= 0) {
    return setLapseDay(scope, habit: habit, date: date, lapsed: true);
  }
  final int? amount = await askLapseAmount(
    context,
    definition: definition,
    preferences: scope.preferences,
    color: theme.colorOf(const core.PaletteColor(0)),
  );
  if (amount == null) return false;
  return setLapseDay(
    scope,
    habit: habit,
    date: date,
    lapsed: true,
    amount: amount,
  );
}
