import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/canvas.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/image.dart';
import 'package:uhabits_core/src/gui/theme.dart';
import 'package:uhabits_core/src/gui/view.dart';
import 'package:uhabits_core/src/ui/views/ring.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Ring.kt
/// and the `View.drawNotesIndicator` extension in
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt.
///
/// Neither has a Kotlin test upstream, so every assertion below comes from the
/// rules in docs/parity/FEATURES.md, checked line by line against the Kotlin.
/// Ring never reads pixels back, so the whole contract is the *call sequence*
/// it makes on the canvas: [_RecordingCanvas] logs each call together with the
/// paint state it was made under, which is what these tests assert.
void main() {
  group('charts-canvas-theming.ring-core', () {
    test('#1 stateless View with the Kotlin constructor parameters', () {
      final theme = LightTheme();
      final ring = Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 3.0,
        radius: 15.0,
        theme: theme,
      );

      expect(ring, isA<View>(),
          reason: 'charts-canvas-theming.ring-core#1: Ring is a View');
      expect(ring.color, Color.RED,
          reason: 'charts-canvas-theming.ring-core#1: color is kept verbatim');
      expect(ring.percentage, 0.5,
          reason: 'charts-canvas-theming.ring-core#1: percentage is a Double');
      expect(ring.thickness, 3.0,
          reason: 'charts-canvas-theming.ring-core#1: thickness is a Double');
      expect(ring.radius, 15.0,
          reason: 'charts-canvas-theming.ring-core#1: radius is a Double');
      expect(ring.theme, same(theme),
          reason: 'charts-canvas-theming.ring-core#1: theme is kept verbatim');
      expect(ring.label, isFalse,
          reason: 'charts-canvas-theming.ring-core#1: label defaults to false');

      // Stateless: draw() reads nothing but its constructor arguments and the
      // canvas size, so drawing the same instance twice replays exactly the
      // same calls, and two instances built alike are indistinguishable.
      final first = _RecordingCanvas(width: 60.0, height: 60.0);
      final second = _RecordingCanvas(width: 60.0, height: 60.0);
      ring.draw(first);
      ring.draw(second);
      expect(second.trace, first.trace,
          reason: 'charts-canvas-theming.ring-core#1: draw() is stateless, so '
              'redrawing produces an identical call sequence');

      final twin = Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 3.0,
        radius: 15.0,
        theme: theme,
      );
      final third = _RecordingCanvas(width: 60.0, height: 60.0);
      twin.draw(third);
      expect(third.trace, first.trace,
          reason: 'charts-canvas-theming.ring-core#1: Ring holds no mutable '
              'state, so an identical instance draws identically');
    });

    test('#2 angle = 360.0 * max(0.0, min(360.0, percentage))', () {
      double swipeFor(double percentage) {
        final canvas = _RecordingCanvas(width: 100.0, height: 100.0);
        Ring(
          color: Color.RED,
          percentage: percentage,
          thickness: 4.0,
          radius: 20.0,
          theme: LightTheme(),
        ).draw(canvas);
        return canvas.opNamed('fillArc').args[4] as double;
      }

      expect(swipeFor(0.0), 0.0,
          reason: 'charts-canvas-theming.ring-core#2: percentage 0 gives '
              'angle 0');
      expect(swipeFor(0.5), -180.0,
          reason: 'charts-canvas-theming.ring-core#2: percentage 0.5 gives '
              'angle 180, swept as -angle');
      expect(swipeFor(1.0), -360.0,
          reason: 'charts-canvas-theming.ring-core#2: percentage 1 gives a '
              'full 360 degree angle');
      expect(swipeFor(0.25), -90.0,
          reason: 'charts-canvas-theming.ring-core#2: percentage 0.25 gives '
              'angle 90');

      // Negative percentages clamp to zero through max(0.0, ...).
      expect(swipeFor(-0.3), 0.0,
          reason: 'charts-canvas-theming.ring-core#2: negative percentages '
              'clamp to angle 0');
      expect(swipeFor(-1000.0), 0.0,
          reason: 'charts-canvas-theming.ring-core#2: max(0.0, ...) clamps '
              'any negative percentage to 0');

      // The min(360.0, ...) clamp is applied to the *fraction*, not to the
      // resulting degrees, so a percentage above 1 is NOT clamped to one turn:
      // 400 becomes 360, and 360 * 360 = 129600 degrees.
      expect(swipeFor(400.0), -129600.0,
          reason: 'charts-canvas-theming.ring-core#2: min(360.0, percentage) '
              'clamps the fraction, not the degrees — 400 sweeps 129600');
      expect(swipeFor(2.0), -720.0,
          reason: 'charts-canvas-theming.ring-core#2: the expression is kept '
              'verbatim, so percentage 2 sweeps two full turns');
    });

    test('#3 exactly the listed primitives, in the listed order', () {
      final theme = LightTheme();
      final canvas = _RecordingCanvas(width: 60.0, height: 40.0);
      Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 3.0,
        radius: 15.0,
        theme: theme,
      ).draw(canvas);

      // Ring.kt draws three primitives without a label and four with one. The
      // rule's prose count ("four (or five with a label)") is off by one
      // against its own enumeration; the enumeration matches the Kotlin.
      expect(canvas.primitives.map((op) => op.name).toList(),
          ['fillCircle', 'fillArc', 'fillCircle'],
          reason: 'charts-canvas-theming.ring-core#3: without a label the view '
              'paints fillCircle, fillArc, fillCircle and nothing else');

      final outer = canvas.primitives[0];
      expect(outer.args, [30.0, 20.0, 15.0],
          reason: 'charts-canvas-theming.ring-core#3: the first primitive is '
              'fillCircle(width/2, height/2, radius)');
      expect(outer.color, theme.lowContrastTextColor,
          reason: 'charts-canvas-theming.ring-core#3: the background circle '
              'uses theme.lowContrastTextColor');

      final arc = canvas.primitives[1];
      expect(arc.args, [30.0, 20.0, 15.0, 90.0, -180.0],
          reason: 'charts-canvas-theming.ring-core#3: the second primitive is '
              'fillArc(width/2, height/2, radius, 90.0, -angle)');
      expect(arc.color, Color.RED,
          reason: 'charts-canvas-theming.ring-core#3: the arc uses the '
              'habit colour passed to the constructor');

      final hole = canvas.primitives[2];
      expect(hole.args, [30.0, 20.0, 12.0],
          reason: 'charts-canvas-theming.ring-core#3: the third primitive is '
              'fillCircle(width/2, height/2, radius - thickness)');
      expect(hole.color, theme.cardBackgroundColor,
          reason: 'charts-canvas-theming.ring-core#3: the hole uses '
              'theme.cardBackgroundColor');

      final labelled = _RecordingCanvas(width: 60.0, height: 40.0);
      Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 3.0,
        radius: 15.0,
        theme: theme,
        label: true,
      ).draw(labelled);
      expect(labelled.primitives.map((op) => op.name).toList(),
          ['fillCircle', 'fillArc', 'fillCircle', 'drawText'],
          reason: 'charts-canvas-theming.ring-core#3: with a label the '
              'percentage text is painted last, after the three fills');
    });

    test('#4 the arc fills clockwise from the 12 o\'clock position', () {
      final canvas = _RecordingCanvas(width: 100.0, height: 100.0);
      Ring(
        color: Color.RED,
        percentage: 0.25,
        thickness: 4.0,
        radius: 20.0,
        theme: LightTheme(),
      ).draw(canvas);

      final arc = canvas.opNamed('fillArc');
      expect(arc.args[3], 90.0,
          reason: 'charts-canvas-theming.ring-core#4: the arc starts at 90 '
              'degrees, which is 12 o\'clock');
      expect(arc.args[4] as double, lessThan(0.0),
          reason: 'charts-canvas-theming.ring-core#4: the sweep is -angle, '
              'i.e. negative, so it runs clockwise');

      // Resolved geometry: the arc opens at the top of the circle and, for a
      // quarter, closes at its right-hand side.
      expect(arc.geom['startX'], closeTo(50.0, 1e-9),
          reason: 'charts-canvas-theming.ring-core#4: the sweep opens at the '
              'top of the ring');
      expect(arc.geom['startY'], closeTo(30.0, 1e-9),
          reason: 'charts-canvas-theming.ring-core#4: the sweep opens at the '
              '12 o\'clock point (centerY - radius)');
      expect(arc.geom['endX'], closeTo(70.0, 1e-9),
          reason: 'charts-canvas-theming.ring-core#4: a quarter sweeps '
              'clockwise, ending at 3 o\'clock');
      expect(arc.geom['endY'], closeTo(50.0, 1e-9),
          reason: 'charts-canvas-theming.ring-core#4: a quarter ends level '
              'with the centre, not above it');
    });

    test('#5 the hole is overpainted, not cleared', () {
      final light = LightTheme();
      final canvas = _RecordingCanvas(width: 60.0, height: 60.0);
      Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 3.0,
        radius: 15.0,
        theme: light,
      ).draw(canvas);

      final hole = canvas.primitives[2];
      expect(hole.name, 'fillCircle',
          reason: 'charts-canvas-theming.ring-core#5: the hole is punched by '
              'a fill, never by a clear');
      expect(hole.color, light.cardBackgroundColor,
          reason: 'charts-canvas-theming.ring-core#5: the fill uses '
              'theme.cardBackgroundColor');
      expect(hole.color.alpha, 1.0,
          reason: 'charts-canvas-theming.ring-core#5: under an opaque theme '
              'the overpaint really does hide the arc');

      // Under WidgetTheme the "hole" is painted in a fully transparent colour,
      // so with normal source-over compositing nothing is punched at all and
      // the widget shows a filled pie instead of a ring.
      final widget = _RecordingCanvas(width: 60.0, height: 60.0);
      final widgetTheme = WidgetTheme();
      Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 3.0,
        radius: 15.0,
        theme: widgetTheme,
      ).draw(widget);
      final widgetHole = widget.primitives[2];
      expect(widgetHole.color, Color.TRANSPARENT,
          reason: 'charts-canvas-theming.ring-core#5: WidgetTheme paints the '
              'hole in a fully transparent colour');
      expect(widgetHole.color.alpha, 0.0,
          reason: 'charts-canvas-theming.ring-core#5: alpha 0 means the hole '
              'is effectively not punched under source-over compositing');
      expect(widget.primitives.map((op) => op.name).toList(),
          ['fillCircle', 'fillArc', 'fillCircle'],
          reason: 'charts-canvas-theming.ring-core#5: the transparent theme '
              'still issues the same three fills — nothing is skipped');
    });

    test('#6 the label is the percentage, in `color`, at radius*0.4', () {
      final canvas = _RecordingCanvas(width: 120.0, height: 120.0);
      Ring(
        color: Color.GREEN,
        percentage: 0.6,
        thickness: 5.0,
        radius: 50.0,
        theme: LightTheme(),
        label: true,
      ).draw(canvas);

      final text = canvas.opNamed('drawText');
      expect(text.args[0], '60%',
          reason: 'charts-canvas-theming.ring-core#6: the label is '
              'format("%.0f%%", percentage * 100), so 0.6 renders as "60%"');
      expect(text.args[1], 60.0,
          reason: 'charts-canvas-theming.ring-core#6: the label is centred '
              'horizontally at width/2');
      expect(text.args[2], 60.0,
          reason: 'charts-canvas-theming.ring-core#6: the label is centred '
              'vertically at height/2');
      expect(text.color, Color.GREEN,
          reason: 'charts-canvas-theming.ring-core#6: the label is drawn in '
              'the habit colour');
      expect(text.fontSize, 20.0,
          reason: 'charts-canvas-theming.ring-core#6: the label font size is '
              'radius * 0.4');

      String labelFor(double percentage) {
        final c = _RecordingCanvas(width: 120.0, height: 120.0);
        Ring(
          color: Color.GREEN,
          percentage: percentage,
          thickness: 5.0,
          radius: 50.0,
          theme: LightTheme(),
          label: true,
        ).draw(c);
        return c.opNamed('drawText').args[0] as String;
      }

      expect(labelFor(0.0), '0%',
          reason: 'charts-canvas-theming.ring-core#6: 0.0 renders as "0%"');
      expect(labelFor(1.0), '100%',
          reason: 'charts-canvas-theming.ring-core#6: 1.0 renders as "100%"');
      expect(labelFor(0.125), '13%',
          reason: 'charts-canvas-theming.ring-core#6: "%.0f" rounds, it does '
              'not truncate');
      // The label formats the raw percentage, not the clamped angle: a
      // negative percentage draws an empty arc but still prints a negative
      // number. Upstream behaviour, kept.
      expect(labelFor(-0.3), '-30%',
          reason: 'charts-canvas-theming.ring-core#6: the label uses the raw '
              'percentage, not the clamped angle');

      // No label means no text and no font size change at all.
      final unlabelled = _RecordingCanvas(width: 120.0, height: 120.0);
      Ring(
        color: Color.GREEN,
        percentage: 0.6,
        thickness: 5.0,
        radius: 50.0,
        theme: LightTheme(),
      ).draw(unlabelled);
      expect(unlabelled.ops.where((op) => op.name == 'drawText'), isEmpty,
          reason: 'charts-canvas-theming.ring-core#6: the label is drawn only '
              'when label is true');
      expect(unlabelled.ops.where((op) => op.name == 'setFontSize'), isEmpty,
          reason: 'charts-canvas-theming.ring-core#6: setFontSize is part of '
              'the label branch');
    });

    test('#7 the view never sets a text alignment', () {
      final canvas = _RecordingCanvas(width: 120.0, height: 120.0);
      Ring(
        color: Color.GREEN,
        percentage: 0.6,
        thickness: 5.0,
        radius: 50.0,
        theme: LightTheme(),
        label: true,
      ).draw(canvas);

      expect(canvas.ops.where((op) => op.name == 'setTextAlign'), isEmpty,
          reason: 'charts-canvas-theming.ring-core#7: Ring never calls '
              'setTextAlign');
      expect(canvas.opNamed('drawText').textAlign, TextAlign.center,
          reason: 'charts-canvas-theming.ring-core#7: the label therefore '
              'relies on the canvas default of CENTER');
    });

    test('#8 always centred on the canvas centre, overflow and all', () {
      // A wide, short canvas: the ring does not shrink to fit, and it is not
      // squared off — it stays centred with the caller-supplied radius.
      final wide = _RecordingCanvas(width: 200.0, height: 60.0);
      Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 4.0,
        radius: 40.0,
        theme: LightTheme(),
      ).draw(wide);

      for (final op in wide.primitives) {
        expect(op.args[0], 100.0,
            reason: 'charts-canvas-theming.ring-core#8: every primitive is '
                'centred at width/2, whatever the aspect ratio');
        expect(op.args[1], 30.0,
            reason: 'charts-canvas-theming.ring-core#8: every primitive is '
                'centred at height/2, whatever the aspect ratio');
      }
      expect(wide.primitives[0].args[2], 40.0,
          reason: 'charts-canvas-theming.ring-core#8: the radius is the one '
              'the caller supplied, never derived from the canvas size');

      // Smaller than 2*radius: the ring simply overflows.
      final tiny = _RecordingCanvas(width: 20.0, height: 20.0);
      Ring(
        color: Color.RED,
        percentage: 0.5,
        thickness: 4.0,
        radius: 30.0,
        theme: LightTheme(),
      ).draw(tiny);
      final circle = tiny.primitives[0];
      expect(circle.args[2], 30.0,
          reason: 'charts-canvas-theming.ring-core#8: the radius is not '
              'clamped to the canvas');
      expect((circle.args[0] as double) - (circle.args[2] as double),
          lessThan(0.0),
          reason: 'charts-canvas-theming.ring-core#8: on a canvas smaller '
              'than 2*radius the ring overflows the left edge');
      expect((circle.args[1] as double) - (circle.args[2] as double),
          lessThan(0.0),
          reason: 'charts-canvas-theming.ring-core#8: on a canvas smaller '
              'than 2*radius the ring overflows the top edge');
    });
  });

  group('charts-canvas-theming.notes-indicator', () {
    test('#1 blank notes draw nothing at all', () {
      for (final notes in ['', ' ', '   ', '\t', '\n', ' \t\n ']) {
        final canvas = _RecordingCanvas(width: 48.0, height: 48.0);
        drawNotesIndicator(canvas, Color.RED, 10.0, notes);
        expect(canvas.ops, isEmpty,
            reason: 'charts-canvas-theming.notes-indicator#1: notes '
                '${notes.codeUnits} is blank, so the helper returns before '
                'touching the canvas');
      }

      final canvas = _RecordingCanvas(width: 48.0, height: 48.0);
      drawNotesIndicator(canvas, Color.RED, 10.0, ' x ');
      expect(canvas.primitives.map((op) => op.name).toList(), ['fillCircle'],
          reason: 'charts-canvas-theming.notes-indicator#1: notes that are '
              'not blank draw exactly one dot');
    });

    test('#2 a radius-8 dot inset 0.8 em from the top-right corner', () {
      final canvas = _RecordingCanvas(width: 48.0, height: 48.0);
      drawNotesIndicator(canvas, Color.RED, 10.0, 'hello');

      final dot = canvas.opNamed('fillCircle');
      expect(dot.args[0], 48.0 - 8.0,
          reason: 'charts-canvas-theming.notes-indicator#2: the centre x is '
              'width - 0.8*size');
      expect(dot.args[1], 8.0,
          reason: 'charts-canvas-theming.notes-indicator#2: the centre y is '
              '0.8*size');
      expect(dot.args[2], 8.0,
          reason: 'charts-canvas-theming.notes-indicator#2: the radius is '
              'exactly 8, a raw constant');
      expect(dot.color, Color.RED,
          reason: 'charts-canvas-theming.notes-indicator#2: the dot is filled '
              'in the colour passed in');

      // The inset tracks the em size, the radius does not.
      final bigger = _RecordingCanvas(width: 100.0, height: 48.0);
      drawNotesIndicator(bigger, Color.GREEN, 20.0, 'hello');
      final bigDot = bigger.opNamed('fillCircle');
      expect(bigDot.args[0], 100.0 - 16.0,
          reason: 'charts-canvas-theming.notes-indicator#2: the inset is '
              '0.8*size, so a larger em pushes the dot further in');
      expect(bigDot.args[1], 16.0,
          reason: 'charts-canvas-theming.notes-indicator#2: the vertical '
              'inset is the same 0.8*size');
      expect(bigDot.args[2], 8.0,
          reason: 'charts-canvas-theming.notes-indicator#2: the radius stays '
              '8 whatever the em size');

      // "NOT dp-scaled": the radius is a bare literal, so it is unaffected by
      // the display density the backend applies to everything else.
      for (final density in [1.0, 2.0, 3.5]) {
        final scaled =
            _RecordingCanvas(width: 48.0, height: 48.0, density: density);
        drawNotesIndicator(scaled, Color.RED, 10.0, 'hello');
        expect(scaled.opNamed('fillCircle').args[2], 8.0,
            reason: 'charts-canvas-theming.notes-indicator#2: the radius is '
                'never multiplied by the density (density $density)');
      }
    });
  });
}

/// A fake [Canvas] backend that records every call plus the paint state it was
/// made under. Mirrors AndroidCanvas/JavaCanvas: logical units in, device
/// pixels out, and a CENTER text alignment until someone says otherwise.
class _RecordingCanvas extends Canvas {
  _RecordingCanvas({
    required this.width,
    required this.height,
    this.density = 2.0,
  });

  final double width;
  final double height;
  final double density;

  final List<_Op> ops = [];

  Color _color = Color.BLACK;
  Font _font = Font.regular;
  double _fontSize = 12.0;
  double _strokeWidth = 1.0;
  TextAlign _textAlign = TextAlign.center;

  static const Set<String> _primitiveNames = {
    'drawLine',
    'drawText',
    'fillRect',
    'fillRoundRect',
    'drawRect',
    'fillArc',
    'fillCircle',
  };

  /// Only the calls that put ink on the canvas, in order.
  List<_Op> get primitives =>
      ops.where((op) => _primitiveNames.contains(op.name)).toList();

  _Op opNamed(String name) => ops.firstWhere((op) => op.name == name);

  /// A comparable rendering of the whole call sequence, paint state included.
  List<String> get trace => ops.map((op) => op.toString()).toList();

  void _record(String name, List<Object?> args,
      [Map<String, double> geom = const {}]) {
    ops.add(_Op(
      name,
      args,
      color: _color,
      font: _font,
      fontSize: _fontSize,
      strokeWidth: _strokeWidth,
      textAlign: _textAlign,
      geom: geom,
    ));
  }

  @override
  void setColor(Color color) {
    _color = color;
    _record('setColor', [color]);
  }

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _record('drawLine', [x1, y1, x2, y2]);

  @override
  void drawText(String text, double x, double y) =>
      _record('drawText', [text, x, y]);

  @override
  void fillRect(double x, double y, double width, double height) =>
      _record('fillRect', [x, y, width, height]);

  @override
  void fillRoundRect(double x, double y, double width, double height,
          double cornerRadius) =>
      _record('fillRoundRect', [x, y, width, height, cornerRadius]);

  @override
  void drawRect(double x, double y, double width, double height) =>
      _record('drawRect', [x, y, width, height]);

  @override
  double getHeight() => height;

  @override
  double getWidth() => width;

  @override
  void setFont(Font font) {
    _font = font;
    _record('setFont', [font]);
  }

  @override
  void setFontSize(double size) {
    _fontSize = size;
    _record('setFontSize', [size]);
  }

  @override
  void setStrokeWidth(double size) {
    _strokeWidth = size;
    _record('setStrokeWidth', [size]);
  }

  @override
  void fillArc(double centerX, double centerY, double radius, double startAngle,
      double swipeAngle) {
    // Same winding as the Canvas contract: 0 is 3 o'clock, 90 is 12 o'clock,
    // and a positive sweep runs counterclockwise.
    double pointX(double angle) => centerX + radius * cos(angle * pi / 180.0);
    double pointY(double angle) => centerY - radius * sin(angle * pi / 180.0);
    _record(
      'fillArc',
      [centerX, centerY, radius, startAngle, swipeAngle],
      {
        'startX': pointX(startAngle),
        'startY': pointY(startAngle),
        'endX': pointX(startAngle + swipeAngle),
        'endY': pointY(startAngle + swipeAngle),
      },
    );
  }

  @override
  void fillCircle(double centerX, double centerY, double radius) =>
      _record('fillCircle', [centerX, centerY, radius]);

  @override
  void setTextAlign(TextAlign align) {
    _textAlign = align;
    _record('setTextAlign', [align]);
  }

  @override
  Image toImage() =>
      RgbaImage((width * density).round(), (height * density).round());

  @override
  double measureText(String text) => text.length * 0.6 * _fontSize;
}

class _Op {
  _Op(
    this.name,
    this.args, {
    required this.color,
    required this.font,
    required this.fontSize,
    required this.strokeWidth,
    required this.textAlign,
    required this.geom,
  });

  final String name;
  final List<Object?> args;
  final Color color;
  final Font font;
  final double fontSize;
  final double strokeWidth;
  final TextAlign textAlign;
  final Map<String, double> geom;

  @override
  String toString() => '$name($args) '
      'color=$color font=$font fontSize=$fontSize '
      'strokeWidth=$strokeWidth textAlign=$textAlign';
}
