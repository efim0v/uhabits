/// «Сколько сегодня?» — величина срыва, когда допуск её требует.
library;

// `Preferences` из бочки ядра не реэкспортирована — ровно тот же путь и та же
// оговорка, что в `number_dialog.dart`.
// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../common/dialogs/number_dialog.dart';

/// Спрашивает величину дня и отдаёт её в целых единицах привычки, или null,
/// когда ответа не было.
///
/// Свой маршрут, а не общая дверь числа. `showNumberPopup` — и в списке, и на
/// экране привычки — закрыт охраной вычисляемых привычек
/// (`computed.write-paths#3`), и открывать его ради воздержания значило бы
/// снять запрет со всех: человек начал бы писать вычисленное значение дня
/// руками, а следующий пересчёт молча его затирал бы. Здесь пишется не
/// значение дня, а величина в журнал; значение дня из неё считает приложение
/// (`computed.lapse-score#2`).
///
/// Виджет тот же самый — портированный [NumberDialog], со своими надписями и
/// своей клавиатурой. Новых строк локализации ввод не приносит.
Future<int?> askLapseAmount(
  BuildContext context, {
  required core.HabitDefinition definition,
  required core.Preferences preferences,
  required core.Color color,
}) async {
  final NumberDialogResult? result = await showNumberDialog(
    context,
    // Открывается на нуле, как всякая незаполненная запись
    // (`number-dialog.popup#4`), а не на допуске: предзаполненные «30» человек
    // подтвердил бы не глядя, и получилась бы величина, которая обещание
    // держит, в ответ на «я сорвался».
    value: 0,
    notes: '',
    // NumberDialog красит только кнопки булевого ряда, которого здесь нет;
    // цвет передаётся тем же, каким его передаёт портированный попап числа
    // (`number-dialog.popup#1`).
    color: color,
    preferences: preferences,
  );
  if (result == null) return null;

  // Журнал хранит целые единицы, и меньше одной он не хранит вовсе
  // (`computed.lapses#2`): ноль удовлетворяет «не больше допуска» при любом
  // допуске, то есть означает «ничего не было», а это молчание — отсутствие
  // строки, а не строка с нулём. Ответ «ноль» поэтому равен отказу.
  final int amount = result.value.round();
  return amount < core.LapseRepository.minimumAmount ? null : amount;
}
