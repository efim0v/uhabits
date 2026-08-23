import '../../gui/canvas.dart';
import '../../gui/theme.dart';
import '../../gui/view.dart';
import '../../time/local_date.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/HabitListHeader.kt.
///
/// The weekday / day-number strip that sits above the habit list: a filled
/// background, a hairline along the bottom edge, and one two-line column per
/// checkmark button, laid out right to left.
///
/// Note the direction: index 0 is the *rightmost* column and holds the oldest
/// date, so today ends up leftmost. The Android HeaderView, which is what the
/// shipping list screen actually uses, numbers its columns the other way
/// around (and supports scrolling, RTL and a reversed checkmark order).
class HabitListHeader extends View {
  HabitListHeader(this._today, this._nButtons, this._theme, this._fmt);

  final LocalDate _today;
  final int _nButtons;
  final Theme _theme;
  final LocalDateFormatter _fmt;

  @override
  void draw(Canvas canvas) {
    final width = canvas.getWidth();
    final height = canvas.getHeight();
    final buttonSize = _theme.checkmarkButtonSize;
    canvas.setColor(_theme.headerBackgroundColor);
    canvas.fillRect(0.0, 0.0, width, height);

    canvas.setColor(_theme.headerBorderColor);
    canvas.setStrokeWidth(0.5);
    canvas.drawLine(0.0, height - 0.5, width, height - 0.5);

    canvas.setColor(_theme.headerTextColor);
    canvas.setFont(Font.bold);
    canvas.setFontSize(_theme.smallTextSize);

    for (var index = 0; index < _nButtons; index++) {
      final date = _today.minus(_nButtons - index - 1);
      final name = _fmt.shortWeekdayName(date).toUpperCase();
      final number = date.day.toString();

      final x = width - (index + 1) * buttonSize + buttonSize / 2;
      final y = height / 2;
      canvas.drawText(name, x, y - _theme.smallTextSize * 0.6);
      canvas.drawText(number, x, y + _theme.smallTextSize * 0.6);
    }
  }
}
