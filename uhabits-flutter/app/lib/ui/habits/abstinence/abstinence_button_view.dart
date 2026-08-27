/// Ячейка списка для привычки-воздержания.
///
/// Воздержание — числовая привычка, и числовая панель нарисовала бы ей «0» в
/// каждый день: величина, которой человек не вводил, в цвете «мимо цели». Тут
/// рисуется другое: день без записи выглядит удачным, потому что он удачный —
/// молчание и есть успех.
///
/// Словарь взят у порта, а не выдуман: чистый день есть полая галочка, то
/// самое начертание, которым `CheckmarkButtonView` рисует `YES_AUTO` — «зачло
/// приложение, человек ничего не подтверждал». Срыв есть крест в contrast60,
/// как порт рисует `NO` при включённых вопросах. Пропуск — свой глиф порта.
library;

// Пути `src` — ровно как в entry_button_views.dart.
// ignore_for_file: implementation_imports

import 'package:flutter/painting.dart' show TextScaler;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../platform/flutter_canvas.dart' show TextOutlineCanvas;
import '../list/entry_button_views.dart'
    show drawNotesIndicator, smallTextSize, yesAutoStrokeWidth, yesAutoTextSize;

/// Что ячейка говорит про день.
enum AbstinenceCell { beforeCommitment, clean, lapse, skipped }

/// Был ли в этот день срыв — по тому же судье, что и у оценки.
///
/// Судья один на всю привычку: `isAbstinenceLapse(definition, величина)` из
/// `computed/abstinence_payload.dart`. Оценка сравнивает
/// `normalizedRollingSum > targetValue`, а `targetValue` есть зеркало допуска
/// (`computed.allowance#1`), то есть это буквально одно сравнение, записанное
/// дважды (`computed.lapse-score#5`). Своего порога у интерфейса нет: «не более
/// 30 минут» на ячейке и «не более 30 минут» в балле обязаны означать одно.
///
/// Всё, что добавляет эта функция, — перевод шкалы. Предикат берёт величину, а
/// сюда приходит хранимое значение дня, то есть величина × 1000
/// (`computed.lapse-score#2`).
///
/// Ступеньки 1, 2 и 3 заняты `yesAuto`, `yesManual` и `skip`, а тишина есть -1.
/// Ни одна из них не величина, и делить их на тысячу бессмысленно: при допуске
/// ноль `yesAuto` дал бы 0.001 и стал бы «срывом» — отметка человека,
/// прочитанная как замер. Поэтому они отсеиваются до сравнения, а не им.
bool isAbstinenceLapseDay(core.HabitDefinition definition, int storedValue) {
  if (storedValue == core.Entry.unknown ||
      storedValue == core.Entry.skip ||
      storedValue == core.Entry.yesAuto ||
      storedValue == core.Entry.yesManual) {
    return false;
  }
  return core.isAbstinenceLapse(definition, storedValue / 1000.0);
}

/// Состояние дня по определению привычки и хранимому значению.
///
/// День обязательства спрашивается у определения, а не приезжает отдельным
/// числом: определение и так здесь, а два источника одного факта расходятся.
/// Пустой `committedFrom` — неполное обязательство, судить по нему нечего, и
/// ячейка ведёт себя как до обещания (`computed.abstinence-cell#7`).
AbstinenceCell abstinenceCellOf({
  required core.HabitDefinition definition,
  required int storedValue,
  required int day,
}) {
  final int? committedFrom = definition.committedFrom;
  if (committedFrom == null || day < committedFrom) {
    return AbstinenceCell.beforeCommitment;
  }
  if (storedValue == core.Entry.skip) return AbstinenceCell.skipped;
  return isAbstinenceLapseDay(definition, storedValue)
      ? AbstinenceCell.lapse
      : AbstinenceCell.clean;
}

class AbstinenceButtonView extends core.View {
  AbstinenceButtonView({
    required this.cell,
    required this.color,
    required this.theme,
    this.notes = '',
    this.textScaler = TextScaler.noScaling,
  });

  final AbstinenceCell cell;
  final core.Color color;
  final core.Theme theme;
  final String notes;

  /// Системный масштаб шрифта: глифы порта — sp, и этот тоже
  /// (`audit4.check-mark-cell-glyphs-no-longer#1`).
  final TextScaler textScaler;

  /// Глиф дня, или null — рисовать нечего.
  String? get glyph {
    switch (cell) {
      case AbstinenceCell.beforeCommitment:
        return null;
      case AbstinenceCell.clean:
        return core.FontAwesome.check;
      case AbstinenceCell.lapse:
        return core.FontAwesome.times;
      case AbstinenceCell.skipped:
        return core.FontAwesome.skipped;
    }
  }

  core.Color get glyphColor =>
      cell == AbstinenceCell.lapse ? theme.contrast60 : color;

  /// Полая галочка — то же начертание, каким порт рисует `YES_AUTO`.
  bool get isHollow => cell == AbstinenceCell.clean;

  double get fontSize =>
      textScaler.scale(isHollow ? yesAutoTextSize : smallTextSize);

  @override
  void draw(core.Canvas canvas) {
    final String? label = glyph;
    if (label == null) return;
    canvas.setFont(core.Font.fontAwesome);
    canvas.setFontSize(fontSize);
    canvas.setColor(glyphColor);

    final double em = canvas.measureText('m');
    final double x = canvas.getWidth() / 2.0;
    final double y = canvas.getHeight() / 2.0;

    if (isHollow) {
      // `paint.style = STROKE` порта, поверх — тот же глиф цветом карточки.
      canvas.setStrokeWidth(yesAutoStrokeWidth);
      if (canvas is TextOutlineCanvas) {
        (canvas as TextOutlineCanvas).drawTextOutline(label, x, y);
      } else {
        canvas.drawText(label, x, y);
      }
      canvas.setColor(theme.cardBackgroundColor);
      canvas.setStrokeWidth(0.0);
      canvas.drawText(label, x, y);
    } else {
      canvas.setStrokeWidth(0.0);
      canvas.drawText(label, x, y);
    }

    drawNotesIndicator(canvas, color: color, size: em, notes: notes);
  }
}
