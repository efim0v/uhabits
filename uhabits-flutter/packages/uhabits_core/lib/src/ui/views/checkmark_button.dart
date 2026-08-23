import '../../gui/canvas.dart';
import '../../gui/color.dart';
import '../../gui/font_awesome.dart';
import '../../gui/theme.dart';
import '../../gui/view.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/CheckmarkButton.kt.
///
/// One cell of the checkmark panel: a single FontAwesome glyph centred on the
/// canvas. The view is stateless — value, colour and theme all arrive through
/// the constructor — and it paints no background, so the caller is responsible
/// for whatever sits behind the glyph.
///
/// [value] is an [Entry] value: 0 = NO, 1 = YES_AUTO, 2 = YES_MANUAL,
/// 3 = SKIP. Only 2 gets the habit colour, and only 0 gets a cross; the richer
/// treatment of skips and unknowns lives in the Android CheckmarkButtonView.
class CheckmarkButton extends View {
  CheckmarkButton(this._value, this._color, this._theme);

  final int _value;
  final Color _color;
  final Theme _theme;

  @override
  void draw(Canvas canvas) {
    canvas.setFont(Font.fontAwesome);
    canvas.setFontSize(_theme.smallTextSize * 1.5);
    canvas.setColor(
      _value == 2 ? _color : _theme.lowContrastTextColor,
    );
    final text = _value == 0 ? FontAwesome.times : FontAwesome.check;
    canvas.drawText(text, canvas.getWidth() / 2.0, canvas.getHeight() / 2.0);
  }
}
