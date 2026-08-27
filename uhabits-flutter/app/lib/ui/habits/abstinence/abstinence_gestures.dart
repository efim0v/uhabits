/// Единственная дверь, которой жест пишет срыв.
library;

import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../state/app_scope.dart';

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
