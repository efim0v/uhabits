/// «Сколько сегодня?» — величина срыва, когда допуск её требует.
library;

// `Preferences` из бочки ядра не реэкспортирована — ровно тот же путь и та же
// оговорка, что в `number_dialog.dart`.
// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../common/dialogs/current_dialog.dart';
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
///
/// Определение сюда не едет, и это решение, а не упущение. Спросить у него
/// можно было бы ровно одно — допуск, — и класть допуск в поле нельзя:
/// предзаполненные «30» человек подтвердил бы не глядя, и получилась бы
/// величина, которая обещание **держит**, в ответ на «я сорвался». Отсутствие
/// параметра держит это лучше комментария: подставить туда допуск не из чего.
/// Кому нужен допуск — тот в [toggleLapseDay], и он решает не что показать, а
/// спрашивать ли вообще.
Future<int?> askLapseAmount(
  BuildContext context, {
  required core.Preferences preferences,
  required core.Color color,
}) async {
  // Тот же слот, что у портированного попапа числа (`number-dialog.popup#18`,
  // `platform-glue.transient-ui-helpers#4`, `#5`). Без него этот вход был бы
  // единственным в файле, который в слот не встаёт: `EntryPanel.onTap` на
  // время ожидания не заперт, и второй тап положил бы второй диалог поверх
  // первого, а `onPause` экрана оставил бы открытый вопрос висеть.
  final NumberDialogResult? result =
      await dismissCurrentAndShow<NumberDialogResult>(
    context,
    () => showNumberDialog(
      context,
      // Открывается на нуле, как всякая незаполненная запись
      // (`number-dialog.popup#4`).
      value: 0,
      notes: '',
      // Поля заметок здесь нет: в `Lapses` нет столбца под них, а поле,
      // которое принимает текст и молча его теряет, хуже отсутствующего
      // (`audit7.numeric-entry-popup-throws-away-a#1`). Провести заметку
      // насквозь — это миграция схемы, а не аргумент диалога.
      showNotes: false,
      // NumberDialog красит только кнопки булевого ряда, которого здесь нет;
      // цвет передаётся тем же, каким его передаёт портированный попап числа
      // (`number-dialog.popup#1`).
      color: color,
      preferences: preferences,
    ),
  );
  if (result == null) return null;

  // Журнал хранит целые единицы, и меньше одной он не хранит вовсе
  // (`computed.lapses#2`): ноль удовлетворяет «не больше допуска» при любом
  // допуске, то есть означает «ничего не было», а это молчание — отсутствие
  // строки, а не строка с нулём. Ответ «ноль» поэтому равен отказу.
  final int amount = result.value.round();
  return amount < core.LapseRepository.minimumAmount ? null : amount;
}
