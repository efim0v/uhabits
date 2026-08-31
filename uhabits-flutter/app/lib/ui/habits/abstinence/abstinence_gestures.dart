/// Единственная дверь, которой жест пишет срыв.
library;

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import 'abstinence_amount_dialog.dart';

/// Записывает или снимает срыв за [date]. Отвечает, сдвинулось ли значение
/// дня.
///
/// Одна функция, а не вызов на каждом жесте: путей записи два — кнопка
/// карточки и календарь на экране привычки, — и правило, размазанное по
/// обоим, будет донесено до одного. Ячейка списка сюда больше не попадает:
/// список — только для просмотра для этого вида
/// (`computed.abstinence-cell#9`).
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
  // Ответ свода, а не `true`. Свод знает то, чего не знает жест: `writeDays`
  // не переписывает неизменившееся значение и молчит (`computed.day-write#5`,
  // `computed.freshness#3`), а правдивый ответ — единственный способ
  // вызывающему узнать, сдвинулось ли в дне хоть что-то
  // (`computed.abstinence-cell#5`).
  return scope.abstinence.setLapse(habit, date, lapsed, amount: amount);
}

/// Жест «сорвался» / «не сорвался» целиком: спрашивает величину, когда допуск
/// её требует, пишет и отвечает, записал ли.
///
/// Одна дверь на оба жеста — кнопку карточки и день в календаре, — потому что
/// «спрашивать или не спрашивать» есть правило привычки, а не свойство места,
/// откуда по ней попали. Развести это по двум местам значит завести два
/// правила, которые обязаны совпадать. Ячейка списка сюда не заходит: список
/// — только для просмотра для этого вида, и её тап никуда не пишет
/// (`computed.abstinence-cell#9`).
///
/// Ответ нужен вызывающему, чтобы знать, записала ли дверь хоть что-нибудь:
/// кнопка карточки перерисовывает счётчик, только когда записано, и
/// календарь-редактор перекрашивает сетку — тоже только тогда.
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
  // Величина, которая в дне уже записана. Журнал, а не значение дня: он
  // хранит её целыми единицами, ровно теми, что вводят, а значение дня есть
  // произведение на тысячу, и делить его обратно значило бы завести второй
  // путь к одному числу. Привычка без id в журнал ещё не попадала.
  final int? id = habit.id;
  final int recorded =
      id == null ? 0 : scope.lapses.forDay(id, date.daysSince2000) ?? 0;
  final int? amount = await askLapseAmount(
    context,
    initialAmount: recorded,
    prompt: abstinenceAmountPrompt(L10n.of(context), definition),
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
