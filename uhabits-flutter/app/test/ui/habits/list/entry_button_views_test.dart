/// Tests for the two Android entry-cell drawings.
///
/// Port target:
/// uhabits-android/.../habits/list/views/CheckmarkButtonView.kt and
/// .../NumberButtonView.kt (goldens under
/// androidTest/assets/views/habits/list/{CheckmarkButtonView,NumberButtonView}/,
/// all 96x96 px = 48x48 dp at density 2), plus `View.drawNotesIndicator`.
///
/// Both views are `core.View`s, so every pixel is a function of their
/// constructor arguments and the canvas size. They are driven here against
/// [_RecordingCanvas], which logs each drawing call together with the sticky
/// paint state it was made under — colour, font, font size and stroke width —
/// which is exactly what a golden would show.
///
/// One deliberate departure, documented on `entry_button_views.dart`: Android
/// anchors `Canvas.drawText` on the text *baseline* and converts a rect centre
/// into one by nudging the rect down (0.4 em for the checkmark, 0.5 em for a
/// unitless number), while `core.Canvas.drawText` anchors on the glyph's
/// visual centre (`charts-canvas-theming.canvas-api#6`) — which is what that
/// nudge computes. The port therefore draws at the plain centre; every
/// *relative* offset (the 1.3 em between a number and its unit, the 0.8 em
/// inset of the notes dot) is kept literally.
library;

// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_canvas.dart' show TextOutlineCanvas;
import 'package:uhabits/ui/habits/list/entry_button_views.dart';
import 'package:uhabits_core/src/ui/views/number_button.dart' as core_views;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  final theme = core.LightTheme();
  final habitColor = theme.colorOf(const core.PaletteColor(7));

  _RecordingCanvas draw(core.View view, {double width = 48, double height = 48}) {
    final canvas = _RecordingCanvas(width: width, height: height);
    view.draw(canvas);
    return canvas;
  }

  CheckmarkButtonView checkmark(
    int value, {
    String notes = '',
    bool areQuestionMarksEnabled = false,
  }) =>
      CheckmarkButtonView(
        value: value,
        color: habitColor,
        theme: theme,
        notes: notes,
        areQuestionMarksEnabled: areQuestionMarksEnabled,
      );

  NumberButtonView number({
    double value = 0.0,
    double threshold = 100.0,
    String units = '',
    core.NumericalHabitType targetType = core.NumericalHabitType.atLeast,
    String notes = '',
    bool areQuestionMarksEnabled = false,
  }) =>
      NumberButtonView(
        color: habitColor,
        value: value,
        threshold: threshold,
        units: units,
        theme: theme,
        targetType: targetType,
        notes: notes,
        areQuestionMarksEnabled: areQuestionMarksEnabled,
      );

  group('list-habits.checkmark-button-rendering', () {
    test('#2 the glyph colour of every entry value', () {
      // YES_MANUAL, YES_AUTO and SKIP all take the habit colour.
      for (final value in <int>[
        core.Entry.yesManual,
        core.Entry.yesAuto,
        core.Entry.skip,
      ]) {
        expect(checkmark(value).glyphColor, habitColor,
            reason: 'list-habits.checkmark-button-rendering#2 — value $value');
      }

      // NO: contrast60 with question marks on, contrast40 otherwise.
      expect(checkmark(core.Entry.no).glyphColor, theme.lowContrastTextColor,
          reason: 'list-habits.checkmark-button-rendering#2');
      expect(
        checkmark(core.Entry.no, areQuestionMarksEnabled: true).glyphColor,
        theme.mediumContrastTextColor,
        reason: 'list-habits.checkmark-button-rendering#2',
      );
      expect(theme.mediumContrastTextColor, isNot(theme.lowContrastTextColor),
          reason: 'list-habits.checkmark-button-rendering#2');

      // UNKNOWN, and anything else, is contrast40 either way.
      for (final enabled in <bool>[false, true]) {
        expect(
          checkmark(core.Entry.unknown, areQuestionMarksEnabled: enabled)
              .glyphColor,
          theme.lowContrastTextColor,
          reason: 'list-habits.checkmark-button-rendering#2',
        );
        expect(
          checkmark(99, areQuestionMarksEnabled: enabled).glyphColor,
          theme.lowContrastTextColor,
          reason: 'list-habits.checkmark-button-rendering#2 — the else branch',
        );
      }

      // …and the colour really reaches the canvas.
      final ops = draw(checkmark(core.Entry.skip)).opsNamed('drawText');
      expect(ops.single.color, habitColor,
          reason: 'list-habits.checkmark-button-rendering#2');
    });

    test('#3 the glyph of every entry value', () {
      expect(draw(checkmark(core.Entry.skip)).texts,
          <String>[core.FontAwesome.skipped],
          reason: 'list-habits.checkmark-button-rendering#3');
      expect(draw(checkmark(core.Entry.no)).texts,
          <String>[core.FontAwesome.times],
          reason: 'list-habits.checkmark-button-rendering#3');
      expect(draw(checkmark(core.Entry.unknown)).texts,
          <String>[core.FontAwesome.times],
          reason: 'list-habits.checkmark-button-rendering#3 — fa_times while '
              'question marks are off');
      expect(
        draw(checkmark(core.Entry.unknown, areQuestionMarksEnabled: true))
            .texts,
        <String>[core.FontAwesome.question],
        reason: 'list-habits.checkmark-button-rendering#3',
      );
      expect(draw(checkmark(core.Entry.yesManual)).texts,
          <String>[core.FontAwesome.check],
          reason: 'list-habits.checkmark-button-rendering#3');
      // YES_AUTO draws the check twice — see #5.
      expect(draw(checkmark(core.Entry.yesAuto)).texts,
          <String>[core.FontAwesome.check, core.FontAwesome.check],
          reason: 'list-habits.checkmark-button-rendering#3');
      // The glyphs are the FontAwesome ones, drawn in the icon face.
      expect(
        draw(checkmark(core.Entry.skip)).opsNamed('drawText').single.font,
        core.Font.fontAwesome,
        reason: 'list-habits.checkmark-button-rendering#3',
      );
    });

    test('#4 12sp for the question mark, 13sp for YES_AUTO, 14sp otherwise',
        () {
      expect(
        draw(checkmark(core.Entry.unknown, areQuestionMarksEnabled: true))
            .opsNamed('drawText')
            .single
            .fontSize,
        12.0,
        reason: 'list-habits.checkmark-button-rendering#4',
      );
      expect(draw(checkmark(core.Entry.yesAuto)).ops.first.fontSize, 13.0,
          reason: 'list-habits.checkmark-button-rendering#4');
      for (final value in <int>[
        core.Entry.skip,
        core.Entry.no,
        core.Entry.yesManual,
        core.Entry.unknown,
      ]) {
        expect(
          draw(checkmark(value)).opsNamed('drawText').single.fontSize,
          14.0,
          reason: 'list-habits.checkmark-button-rendering#4 — value $value',
        );
      }
    });

    test('#5 YES_AUTO is stroked in the habit colour then filled in the card '
        'background', () {
      final canvas = draw(checkmark(core.Entry.yesAuto));
      expect(canvas.drawOps, hasLength(2),
          reason: 'list-habits.checkmark-button-rendering#5');

      final outline = canvas.drawOps[0];
      expect(outline.name, 'drawTextOutline',
          reason: 'list-habits.checkmark-button-rendering#5 — '
              'Paint.Style.STROKE');
      expect(outline.strokeWidth, 5.0,
          reason: 'list-habits.checkmark-button-rendering#5');
      expect(outline.color, habitColor,
          reason: 'list-habits.checkmark-button-rendering#5');

      final fill = canvas.drawOps[1];
      expect(fill.name, 'drawText',
          reason: 'list-habits.checkmark-button-rendering#5 — re-drawn filled '
              'on top');
      expect(fill.color, theme.cardBackgroundColor,
          reason: 'list-habits.checkmark-button-rendering#5');
      expect(fill.strokeWidth, 0.0,
          reason: 'list-habits.checkmark-button-rendering#5');
      // Both passes are the same glyph in the same place.
      expect(fill.args, outline.args,
          reason: 'list-habits.checkmark-button-rendering#5');
      expect(fill.text, outline.text,
          reason: 'list-habits.checkmark-button-rendering#5');
    });

    test('#6 every other value is a single filled glyph at strokeWidth 0', () {
      for (final value in <int>[
        core.Entry.skip,
        core.Entry.no,
        core.Entry.yesManual,
        core.Entry.unknown,
      ]) {
        final canvas = draw(checkmark(value));
        expect(canvas.drawOps, hasLength(1),
            reason: 'list-habits.checkmark-button-rendering#6 — value $value');
        expect(canvas.drawOps.single.name, 'drawText',
            reason: 'list-habits.checkmark-button-rendering#6 — no outline '
                'pass for value $value');
        expect(canvas.drawOps.single.strokeWidth, 0.0,
            reason: 'list-habits.checkmark-button-rendering#6');
      }
    });

    test('#7 the glyph is centred on the button, with em = measureText("m")',
        () {
      final canvas = draw(checkmark(core.Entry.yesManual));
      final op = canvas.opsNamed('drawText').single;
      // `rect.set(0, 0, width, height)` then `drawText(label, rect.centerX(),
      // rect.centerY())`. The 0.4 em the Kotlin rect is offset by converts the
      // centre into a baseline, which this canvas does for itself.
      expect(op.args, <double>[24.0, 24.0],
          reason: 'list-habits.checkmark-button-rendering#7');
      // A non-square canvas still lands on its own centre.
      final wide = draw(checkmark(core.Entry.yesManual), width: 80, height: 40);
      expect(wide.opsNamed('drawText').single.args, <double>[40.0, 20.0],
          reason: 'list-habits.checkmark-button-rendering#7');

      // em is measured under the glyph paint, and is what places the notes
      // dot: 14sp for a check, 12sp for a question mark, so the two dots do
      // not land in the same place.
      final checkDot = draw(checkmark(core.Entry.yesManual, notes: 'x'))
          .opsNamed('fillCircle')
          .single;
      final questionDot = draw(
        checkmark(core.Entry.unknown,
            notes: 'x', areQuestionMarksEnabled: true),
      ).opsNamed('fillCircle').single;
      expect(checkDot.args[1], isNot(questionDot.args[1]),
          reason: 'list-habits.checkmark-button-rendering#7 — em follows the '
              'paint the glyph is drawn with');
      expect(checkDot.args[1], closeTo(0.8 * _em(14.0), 1e-9),
          reason: 'list-habits.checkmark-button-rendering#7');
    });

    test('#8 the notes dot: radius 8 at (width - 0.8em, 0.8em), and nothing '
        'when the notes are blank', () {
      expect(draw(checkmark(core.Entry.yesManual)).opsNamed('fillCircle'),
          isEmpty,
          reason: 'list-habits.checkmark-button-rendering#8');
      expect(
        draw(checkmark(core.Entry.yesManual, notes: '   '))
            .opsNamed('fillCircle'),
        isEmpty,
        reason: 'list-habits.checkmark-button-rendering#8 — isBlank(), not '
            'isEmpty()',
      );

      final canvas = draw(checkmark(core.Entry.yesManual, notes: 'ran 5k'));
      final dot = canvas.opsNamed('fillCircle').single;
      final em = _em(14.0);
      expect(dot.args[0], closeTo(48.0 - 0.8 * em, 1e-9),
          reason: 'list-habits.checkmark-button-rendering#8');
      expect(dot.args[1], closeTo(0.8 * em, 1e-9),
          reason: 'list-habits.checkmark-button-rendering#8');
      expect(dot.args[2], 8.0,
          reason: 'list-habits.checkmark-button-rendering#8 — a bare 8f, not '
              'dp-scaled');
      expect(dot.color, habitColor,
          reason: 'list-habits.checkmark-button-rendering#8 — the habit '
              'colour, even for a NO cell');
      // …including on a cell whose glyph is not in the habit colour.
      expect(
        draw(checkmark(core.Entry.no, notes: 'x'))
            .opsNamed('fillCircle')
            .single
            .color,
        habitColor,
        reason: 'list-habits.checkmark-button-rendering#8',
      );
    });
  });

  group('list-habits.number-button', () {
    test('#3 the active colour', () {
      // A negative value is contrast40 whatever the target says.
      for (final type in core.NumericalHabitType.values) {
        expect(
          number(value: -0.001, targetType: type).activeColor,
          theme.lowContrastTextColor,
          reason: 'list-habits.number-button#3',
        );
      }

      // AT_LEAST: the habit colour once the threshold is reached.
      expect(number(value: 100.0).activeColor, habitColor,
          reason: 'list-habits.number-button#3');
      expect(number(value: 150.0).activeColor, habitColor,
          reason: 'list-habits.number-button#3');
      expect(number(value: 99.0).activeColor, theme.mediumContrastTextColor,
          reason: 'list-habits.number-button#3');

      // AT_MOST: the other way round.
      const atMost = core.NumericalHabitType.atMost;
      expect(number(value: 50.0, targetType: atMost).activeColor, habitColor,
          reason: 'list-habits.number-button#3');
      expect(number(value: 100.0, targetType: atMost).activeColor, habitColor,
          reason: 'list-habits.number-button#3');
      expect(
        number(value: 101.0, targetType: atMost).activeColor,
        theme.mediumContrastTextColor,
        reason: 'list-habits.number-button#3',
      );

      // Zero is not negative, so an at-least habit with a positive target
      // still reads as "below target", not "unset".
      expect(number(value: 0.0).activeColor, theme.mediumContrastTextColor,
          reason: 'list-habits.number-button#3');
      expect(draw(number(value: 150.0)).opsNamed('drawText').single.color,
          habitColor,
          reason: 'list-habits.number-button#3');
    });

    test('#4 the four label branches, in order', () {
      // Entry.SKIP / 1000 == 0.003, drawn as the fa_skipped glyph at 14sp.
      expect(NumberButtonView.skipValue, 0.003,
          reason: 'list-habits.number-button#4');
      final skip = draw(number(value: 0.003)).opsNamed('drawText').single;
      expect(skip.text, core.FontAwesome.skipped,
          reason: 'list-habits.number-button#4');
      expect(skip.font, core.Font.fontAwesome,
          reason: 'list-habits.number-button#4');
      expect(skip.fontSize, 14.0, reason: 'list-habits.number-button#4');

      // value >= 0: the short string, bold, 14sp.
      final positive = draw(number(value: 12.34)).opsNamed('drawText').single;
      expect(positive.text, 12.34.toShortStringAndroid(),
          reason: 'list-habits.number-button#4');
      expect(positive.text, '12.3', reason: 'list-habits.number-button#4');
      expect(positive.font, core.Font.bold,
          reason: 'list-habits.number-button#4');
      expect(positive.fontSize, 14.0, reason: 'list-habits.number-button#4');
      // Zero is still a number, not the unset branch.
      expect(draw(number()).opsNamed('drawText').single.text, '0',
          reason: 'list-habits.number-button#4');

      // Negative with question marks on: the fa_question glyph at 12sp.
      final unknown =
          draw(number(value: -0.001, areQuestionMarksEnabled: true))
              .opsNamed('drawText')
              .single;
      expect(unknown.text, core.FontAwesome.question,
          reason: 'list-habits.number-button#4');
      expect(unknown.font, core.Font.fontAwesome,
          reason: 'list-habits.number-button#4');
      expect(unknown.fontSize, 12.0, reason: 'list-habits.number-button#4');

      // …and with them off, the literal string "0" in bold at 14sp.
      final zero = draw(number(value: -0.001)).opsNamed('drawText').single;
      expect(zero.text, '0', reason: 'list-habits.number-button#4');
      expect(zero.font, core.Font.bold, reason: 'list-habits.number-button#4');
      expect(zero.fontSize, 14.0, reason: 'list-habits.number-button#4');
    });

    test('#7 a blank unit draws the number alone, centred', () {
      for (final units in <String>['', '   ']) {
        final canvas = draw(number(value: 12.0, units: units));
        expect(canvas.opsNamed('drawText'), hasLength(1),
            reason: 'list-habits.number-button#7 — no unit line at all');
        expect(canvas.opsNamed('drawText').single.args, <double>[24.0, 24.0],
            reason: 'list-habits.number-button#7');
      }
      // A non-square button still centres it.
      expect(
        draw(number(value: 12.0), width: 80, height: 40)
            .opsNamed('drawText')
            .single
            .args,
        <double>[40.0, 20.0],
        reason: 'list-habits.number-button#7',
      );
    });

    test('#8 #12 a unit is drawn 1.3 em below the number, at 12sp in the '
        'normal condensed face and the same colour', () {
      final canvas = draw(number(value: 150.0, units: 'km'));
      final ops = canvas.opsNamed('drawText');
      expect(ops, hasLength(2), reason: 'list-habits.number-button#8');

      final numberOp = ops[0];
      final unitOp = ops[1];
      expect(numberOp.args, <double>[24.0, 24.0],
          reason: 'list-habits.number-button#8 — the number keeps the centre');
      expect(unitOp.text, 'km', reason: 'list-habits.number-button#8');
      expect(unitOp.args[0], 24.0, reason: 'list-habits.number-button#8');
      // em is measured with the *number* paint (bold, 14sp), not the unit's.
      expect(unitOp.args[1], closeTo(24.0 + 1.3 * _em(14.0), 1e-9),
          reason: 'list-habits.number-button#8');
      expect(unitOp.fontSize, 12.0,
          reason: 'list-habits.number-button#8 — smallerTextSize');
      expect(unitOp.color, numberOp.color,
          reason: 'list-habits.number-button#8 — pUnit.color = activeColor');

      // `Typeface.create("sans-serif-condensed", BOLD)` for the value and
      // `NORMAL` for the unit.
      expect(numberOp.font, core.Font.bold,
          reason: 'list-habits.number-button#12');
      expect(unitOp.font, core.Font.regular,
          reason: 'list-habits.number-button#12');
    });

    test('#9 a unit too wide for the button is trimmed two characters at a '
        'time and ellipsized', () {
      // The loop is pure arithmetic over the unit paint's measureText, so it
      // is exercised directly as well as through a drawing.
      double measure(String text) => text.length * 0.6 * 12.0;
      const maxWidth = 48.0 * 0.9;

      expect(NumberButtonView.trimUnits('km', maxWidth, measure), 'km',
          reason: 'list-habits.number-button#9 — it already fits');
      // 'kilometres' is 10 chars = 72 > 43.2: drop two, append the ellipsis,
      // and keep going until it fits.
      final trimmed =
          NumberButtonView.trimUnits('kilometres', maxWidth, measure);
      expect(trimmed.endsWith('…'), isTrue,
          reason: 'list-habits.number-button#9');
      expect(measure(trimmed), lessThanOrEqualTo(maxWidth),
          reason: 'list-habits.number-button#9');
      expect(trimmed, 'kilom…', reason: 'list-habits.number-button#9');

      // The loop stops at two characters even when they still do not fit.
      expect(NumberButtonView.trimUnits('ab', 1.0, measure), 'ab',
          reason: 'list-habits.number-button#9 — `length > 2` guards it');

      // …and the drawing uses the trimmed string.
      final canvas = draw(number(value: 150.0, units: 'kilometres'));
      expect(canvas.opsNamed('drawText')[1].text, 'kilom…',
          reason: 'list-habits.number-button#9');
    });

    test('#10 the notes dot uses the number paint em', () {
      expect(draw(number(value: 150.0, units: 'km')).opsNamed('fillCircle'),
          isEmpty,
          reason: 'list-habits.number-button#10');
      expect(
        draw(number(value: 150.0, units: 'km', notes: ' '))
            .opsNamed('fillCircle'),
        isEmpty,
        reason: 'list-habits.number-button#10',
      );

      final dot = draw(number(value: 150.0, units: 'km', notes: 'hilly'))
          .opsNamed('fillCircle')
          .single;
      final em = _em(14.0);
      expect(dot.args[0], closeTo(48.0 - 0.8 * em, 1e-9),
          reason: 'list-habits.number-button#10');
      expect(dot.args[1], closeTo(0.8 * em, 1e-9),
          reason: 'list-habits.number-button#10');
      expect(dot.args[2], 8.0, reason: 'list-habits.number-button#10');
      expect(dot.color, habitColor, reason: 'list-habits.number-button#10');

      // The question-mark label is drawn at 12sp, but the dot still sits where
      // the 14sp number paint puts it.
      final unknownDot = draw(
        number(value: -0.001, areQuestionMarksEnabled: true, notes: 'x'),
      ).opsNamed('fillCircle').single;
      expect(unknownDot.args[1], closeTo(0.8 * em, 1e-9),
          reason: 'list-habits.number-button#10 — em comes from pNumber, not '
              'from the label paint');
    });

    test('#12 the cell is still a NumberButton to everything that inspects one',
        () {
      final view = number(value: 150.0, units: 'km');
      expect(view, isA<core_views.NumberButton>(),
          reason: 'list-habits.number-button#12');
      expect(view.value, 150.0, reason: 'list-habits.number-button#12');
      expect(view.units, 'km', reason: 'list-habits.number-button#12');
      expect(view.threshold, 100.0, reason: 'list-habits.number-button#12');
      expect(view.color, habitColor, reason: 'list-habits.number-button#12');
    });
  });
}

/// The stub advance width [_RecordingCanvas.measureText] returns for "m".
double _em(double fontSize) => 0.6 * fontSize;

class _Op {
  _Op(
    this.name,
    this.args, {
    this.text,
    required this.color,
    required this.font,
    required this.fontSize,
    required this.strokeWidth,
  });

  final String name;
  final List<double> args;
  final String? text;
  final core.Color color;
  final core.Font font;
  final double fontSize;
  final double strokeWidth;

  @override
  String toString() =>
      '$name(${text == null ? '' : '"$text", '}$args) {color=$color '
      'font=$font fontSize=$fontSize strokeWidth=$strokeWidth}';
}

/// A [core.Canvas] that paints nothing and remembers everything, including the
/// [core.Canvas.drawTextOutline] pass the default implementation would have
/// collapsed into a plain fill.
class _RecordingCanvas extends core.Canvas implements TextOutlineCanvas {
  _RecordingCanvas({required this.width, required this.height});

  final double width;
  final double height;
  final List<_Op> ops = <_Op>[];

  core.Color _color = core.Color.BLACK;
  core.Font _font = core.Font.regular;
  double _fontSize = 12.0;
  double _strokeWidth = 1.0;

  List<_Op> opsNamed(String name) =>
      ops.where((op) => op.name == name).toList();

  /// Every call that puts ink on the surface, in order.
  List<_Op> get drawOps => ops.toList();

  List<String> get texts =>
      ops.where((op) => op.text != null).map((op) => op.text!).toList();

  void _record(String name, List<double> args, {String? text}) {
    ops.add(
      _Op(
        name,
        args,
        text: text,
        color: _color,
        font: _font,
        fontSize: _fontSize,
        strokeWidth: _strokeWidth,
      ),
    );
  }

  @override
  double getWidth() => width;

  @override
  double getHeight() => height;

  @override
  void setColor(core.Color color) => _color = color;

  @override
  void setFont(core.Font font) => _font = font;

  @override
  void setFontSize(double size) => _fontSize = size;

  @override
  void setStrokeWidth(double size) => _strokeWidth = size;

  @override
  void setTextAlign(core.TextAlign align) {}

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _record('drawLine', <double>[x1, y1, x2, y2]);

  @override
  void drawText(String text, double x, double y) =>
      _record('drawText', <double>[x, y], text: text);

  @override
  void drawTextOutline(String text, double x, double y) =>
      _record('drawTextOutline', <double>[x, y], text: text);

  @override
  void fillRect(double x, double y, double w, double h) =>
      _record('fillRect', <double>[x, y, w, h]);

  @override
  void drawRect(double x, double y, double w, double h) =>
      _record('drawRect', <double>[x, y, w, h]);

  @override
  void fillRoundRect(double x, double y, double w, double h, double radius) =>
      _record('fillRoundRect', <double>[x, y, w, h, radius]);

  @override
  void fillCircle(double cx, double cy, double radius) =>
      _record('fillCircle', <double>[cx, cy, radius]);

  @override
  void fillArc(
    double cx,
    double cy,
    double radius,
    double startAngle,
    double swipeAngle,
  ) =>
      _record('fillArc', <double>[cx, cy, radius, startAngle, swipeAngle]);

  @override
  double measureText(String text) => text.length * 0.6 * _fontSize;

  @override
  core.Image toImage() => throw UnsupportedError('not recorded');
}
