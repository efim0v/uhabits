import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/gui/canvas.dart';
import 'package:uhabits_core/src/gui/color.dart';
import 'package:uhabits_core/src/gui/font_awesome.dart';
import 'package:uhabits_core/src/gui/image.dart';
import 'package:uhabits_core/src/gui/view.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Canvas.kt,
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/View.kt,
/// uhabits-core/src/commonTest/kotlin/org/isoron/platform/gui/CanvasTest.kt and
/// uhabits-android/src/main/java/org/isoron/platform/gui/{AndroidCanvas,
/// AndroidDataView}.kt.
///
/// This slice is the *interface* between the chart code and whichever backend
/// paints the pixels. Rules that only a real backend can honour (text anchoring,
/// arc winding, fill-vs-stroke, sticky paint state) are asserted here against
/// [RecordingCanvas], a fake backend defined at the bottom of this file that
/// logs every call together with the paint state it was made under and the
/// geometry it resolved to. The fake mirrors AndroidCanvas/JavaCanvas: logical
/// coordinates in, device pixels out.
void main() {
  group('charts-canvas-theming.canvas-api', () {
    test('#1 the declared member set, in logical units', () {
      final canvas = RecordingCanvas(widthPx: 1000, heightPx: 800, density: 2.0);

      // Statically checked tear-offs: every member exists with exactly this
      // signature, and every coordinate/size is a double. `RecordingCanvas
      // extends Canvas` and overrides exactly these sixteen members, so the
      // file would not compile if Canvas declared any further abstract member —
      // that is the "exactly these members" half of the rule.
      final void Function(Color) setColor = canvas.setColor;
      final void Function(double, double, double, double) drawLine =
          canvas.drawLine;
      final void Function(String, double, double) drawText = canvas.drawText;
      final void Function(double, double, double, double) fillRect =
          canvas.fillRect;
      final void Function(double, double, double, double, double)
          fillRoundRect = canvas.fillRoundRect;
      final void Function(double, double, double, double) drawRect =
          canvas.drawRect;
      final double Function() getHeight = canvas.getHeight;
      final double Function() getWidth = canvas.getWidth;
      final void Function(Font) setFont = canvas.setFont;
      final void Function(double) setFontSize = canvas.setFontSize;
      final void Function(double) setStrokeWidth = canvas.setStrokeWidth;
      final void Function(double, double, double, double, double) fillArc =
          canvas.fillArc;
      final void Function(double, double, double) fillCircle =
          canvas.fillCircle;
      final void Function(TextAlign) setTextAlign = canvas.setTextAlign;
      final Image Function() toImage = canvas.toImage;
      final double Function(String) measureText = canvas.measureText;

      setColor(Color.RED);
      drawLine(0.0, 0.0, 10.0, 10.0);
      setFont(Font.regular);
      setFontSize(10.0);
      setTextAlign(TextAlign.left);
      setStrokeWidth(3.0);
      drawText('x', 1.0, 2.0);
      fillRect(1.0, 2.0, 3.0, 4.0);
      fillRoundRect(1.0, 2.0, 3.0, 4.0, 5.0);
      drawRect(1.0, 2.0, 3.0, 4.0);
      fillArc(1.0, 2.0, 3.0, 90.0, 45.0);
      fillCircle(1.0, 2.0, 3.0);

      expect(
          canvas.ops.map((o) => o.name).toList(),
          [
            'setColor',
            'drawLine',
            'setFont',
            'setFontSize',
            'setTextAlign',
            'setStrokeWidth',
            'drawText',
            'fillRect',
            'fillRoundRect',
            'drawRect',
            'fillArc',
            'fillCircle',
          ],
          reason: 'charts-canvas-theming.canvas-api#1');
      expect(measureText('x'), isA<double>(),
          reason: 'charts-canvas-theming.canvas-api#1');
      expect(toImage(), isA<Image>(),
          reason: 'charts-canvas-theming.canvas-api#1');

      // Logical (density-independent) units: a 1000x800 px surface at density 2
      // is 500x400 logical, and a rect drawn at logical (1,2,3,4) lands on
      // device pixels (2,4,6,8).
      expect(getWidth(), 500.0, reason: 'charts-canvas-theming.canvas-api#1');
      expect(getHeight(), 400.0, reason: 'charts-canvas-theming.canvas-api#1');
      expect(canvas.opNamed('fillRect').px, [2.0, 4.0, 6.0, 8.0],
          reason: 'charts-canvas-theming.canvas-api#1');
    });

    test('#2 fill() covers the whole canvas with the current color', () {
      final canvas = RecordingCanvas(widthPx: 600, heightPx: 400, density: 2.0);
      canvas.setColor(Color.CYAN);
      canvas.ops.clear();

      canvas.fill();

      expect(canvas.ops.length, 1,
          reason: 'charts-canvas-theming.canvas-api#2');
      final op = canvas.ops.single;
      expect(op.name, 'fillRect', reason: 'charts-canvas-theming.canvas-api#2');
      expect(op.args, [0.0, 0.0, canvas.getWidth(), canvas.getHeight()],
          reason: 'charts-canvas-theming.canvas-api#2');
      expect(op.args, [0.0, 0.0, 300.0, 200.0],
          reason: 'charts-canvas-theming.canvas-api#2');
      expect(op.state.color, Color.CYAN,
          reason: 'charts-canvas-theming.canvas-api#2');
    });

    test('#3 TextAlign has exactly LEFT, CENTER, RIGHT in ordinal order', () {
      expect(TextAlign.values.length, 3,
          reason: 'charts-canvas-theming.canvas-api#3');
      expect(TextAlign.left.index, 0,
          reason: 'charts-canvas-theming.canvas-api#3');
      expect(TextAlign.center.index, 1,
          reason: 'charts-canvas-theming.canvas-api#3');
      expect(TextAlign.right.index, 2,
          reason: 'charts-canvas-theming.canvas-api#3');
      expect(TextAlign.values,
          [TextAlign.left, TextAlign.center, TextAlign.right],
          reason: 'charts-canvas-theming.canvas-api#3');
    });

    test('#4 Font has exactly REGULAR, BOLD, FONT_AWESOME in ordinal order',
        () {
      expect(Font.values.length, 3,
          reason: 'charts-canvas-theming.canvas-api#4');
      expect(Font.regular.index, 0,
          reason: 'charts-canvas-theming.canvas-api#4');
      expect(Font.bold.index, 1, reason: 'charts-canvas-theming.canvas-api#4');
      expect(Font.fontAwesome.index, 2,
          reason: 'charts-canvas-theming.canvas-api#4');
      expect(Font.values, [Font.regular, Font.bold, Font.fontAwesome],
          reason: 'charts-canvas-theming.canvas-api#4');
    });

    test('#5 ScreenLocation is a data class of x then y', () {
      const location = ScreenLocation(12.5, -3.0);
      expect(location.x, 12.5, reason: 'charts-canvas-theming.canvas-api#5');
      expect(location.y, -3.0, reason: 'charts-canvas-theming.canvas-api#5');
      expect(location.x, isA<double>(),
          reason: 'charts-canvas-theming.canvas-api#5');
      expect(location.y, isA<double>(),
          reason: 'charts-canvas-theming.canvas-api#5');
      expect(location, const ScreenLocation(12.5, -3.0),
          reason: 'charts-canvas-theming.canvas-api#5');
      expect(location.hashCode, const ScreenLocation(12.5, -3.0).hashCode,
          reason: 'charts-canvas-theming.canvas-api#5');
      expect(location == const ScreenLocation(-3.0, 12.5), isFalse,
          reason: 'charts-canvas-theming.canvas-api#5');
    });

    test('#6 drawText centres vertically on y and honours the text alignment',
        () {
      final canvas = RecordingCanvas();
      canvas.setFontSize(20.0);
      final width = canvas.measureText('HELLO');

      canvas.setTextAlign(TextAlign.left);
      canvas.drawText('HELLO', 100.0, 50.0);
      canvas.setTextAlign(TextAlign.center);
      canvas.drawText('HELLO', 100.0, 50.0);
      canvas.setTextAlign(TextAlign.right);
      canvas.drawText('HELLO', 100.0, 50.0);

      final texts = canvas.ops.where((o) => o.name == 'drawText').toList();
      expect(texts.length, 3, reason: 'charts-canvas-theming.canvas-api#6');

      // LEFT: x is the left edge.
      expect(texts[0].geom['left'], closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#6');
      expect(texts[0].geom['right'], closeTo(100.0 + width, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#6');
      // CENTER: x is the horizontal centre.
      expect(texts[1].geom['centerX'], closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#6');
      expect(texts[1].geom['left'], closeTo(100.0 - width / 2, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#6');
      // RIGHT: x is the right edge.
      expect(texts[2].geom['right'], closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#6');
      expect(texts[2].geom['left'], closeTo(100.0 - width, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#6');

      for (final op in texts) {
        // y is the vertical visual centre: half the glyph box above, half below.
        expect(op.geom['centerY'], closeTo(50.0, 1e-9),
            reason: 'charts-canvas-theming.canvas-api#6');
        expect(op.geom['top']! + op.geom['bottom']!, closeTo(2 * 50.0, 1e-9),
            reason: 'charts-canvas-theming.canvas-api#6');
        // ... and never the baseline, which sits below the visual centre.
        expect(op.geom['baselineY']! > op.geom['centerY']!, isTrue,
            reason: 'charts-canvas-theming.canvas-api#6');
      }
    });

    test('#7 fillArc sweeps degrees from 12 o\'clock, negative is clockwise',
        () {
      final canvas = RecordingCanvas();
      // A quarter pie from 12 o'clock sweeping clockwise, as drawTestImage does
      // with its negative swipe angle.
      canvas.fillArc(100.0, 100.0, 50.0, 90.0, -90.0);
      final clockwise = canvas.opNamed('fillArc');

      // startAngle 90 is straight up.
      expect(clockwise.geom['startX'], closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(clockwise.geom['startY'], closeTo(50.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#7');
      // A negative swipe lands to the right (3 o'clock), i.e. clockwise.
      expect(clockwise.geom['endX'], closeTo(150.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(clockwise.geom['endY'], closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#7');
      // The covered quadrant is the upper-right one, not the upper-left one.
      expect(clockwise.sectorContains(120.0, 80.0), isTrue,
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(clockwise.sectorContains(80.0, 80.0), isFalse,
          reason: 'charts-canvas-theming.canvas-api#7');
      // useCenter=true: a filled pie sector, so the centre and the interior
      // between the centre and the rim belong to the shape (a stroked ring
      // would cover neither).
      expect(clockwise.useCenter, isTrue,
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(clockwise.sectorContains(100.0, 100.0), isTrue,
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(clockwise.sectorContains(105.0, 95.0), isTrue,
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(clockwise.style, PaintStyle.fill,
          reason: 'charts-canvas-theming.canvas-api#7');

      // A positive swipe from 12 o'clock goes counterclockwise, to 9 o'clock.
      canvas.fillArc(100.0, 100.0, 50.0, 90.0, 90.0);
      final counterclockwise = canvas.ops.last;
      expect(counterclockwise.geom['endX'], closeTo(50.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(counterclockwise.geom['endY'], closeTo(100.0, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(counterclockwise.sectorContains(80.0, 80.0), isTrue,
          reason: 'charts-canvas-theming.canvas-api#7');
      expect(counterclockwise.sectorContains(120.0, 80.0), isFalse,
          reason: 'charts-canvas-theming.canvas-api#7');
    });

    test('#8 fillRect fills, drawRect strokes, and FILL does not leak', () {
      final canvas = RecordingCanvas();
      canvas.setStrokeWidth(7.0);
      canvas.drawRect(0.0, 0.0, 10.0, 10.0);
      canvas.fillRect(0.0, 0.0, 10.0, 10.0);
      canvas.drawRect(0.0, 0.0, 10.0, 10.0);
      canvas.fillRoundRect(0.0, 0.0, 10.0, 10.0, 2.0);
      canvas.fillCircle(5.0, 5.0, 3.0);

      expect(canvas.ops.map((o) => o.style).toList(), [
        null, // setStrokeWidth is not a draw operation
        PaintStyle.stroke,
        PaintStyle.fill,
        PaintStyle.stroke,
        PaintStyle.fill,
        PaintStyle.fill,
      ], reason: 'charts-canvas-theming.canvas-api#8');
      // The stroked rect uses the current stroke width; the filled ones do not
      // add an outline.
      expect(canvas.ops[1].state.strokeWidth, 7.0,
          reason: 'charts-canvas-theming.canvas-api#8');
      expect(canvas.ops[2].style, PaintStyle.fill,
          reason: 'charts-canvas-theming.canvas-api#8');
    });

    test('#9 setColor applies to both shapes and text', () {
      final canvas = RecordingCanvas();
      canvas.setColor(Color.MAGENTA);
      canvas.fillRect(0.0, 0.0, 10.0, 10.0);
      canvas.drawText('hi', 5.0, 5.0);
      canvas.drawLine(0.0, 0.0, 5.0, 5.0);

      expect(canvas.ops.skip(1).map((o) => o.state.color).toList(),
          [Color.MAGENTA, Color.MAGENTA, Color.MAGENTA],
          reason: 'charts-canvas-theming.canvas-api#9');
      // There is no separate text colour setter: the member list asserted by
      // charts-canvas-theming.canvas-api#1 is exhaustive, and setColor is the
      // only colour entry point in it.
      expect(canvas.textColor, Color.MAGENTA,
          reason: 'charts-canvas-theming.canvas-api#9');
      expect(canvas.shapeColor, canvas.textColor,
          reason: 'charts-canvas-theming.canvas-api#9');
    });

    test('#10 measureText returns the advance width in logical units', () {
      final canvas = RecordingCanvas(density: 2.0);
      canvas.setFont(Font.regular);
      canvas.setFontSize(10.0);
      final short = canvas.measureText('AB');
      final long = canvas.measureText('ABCD');
      expect(long, closeTo(2 * short, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#10');

      canvas.setFontSize(20.0);
      expect(canvas.measureText('AB'), closeTo(2 * short, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#10');

      canvas.setFontSize(10.0);
      canvas.setFont(Font.bold);
      expect(canvas.measureText('AB') == short, isFalse,
          reason: 'charts-canvas-theming.canvas-api#10');

      // Logical, not device pixels: the same text under the same font measures
      // the same on a denser screen.
      final dense = RecordingCanvas(density: 3.0);
      dense.setFont(Font.regular);
      dense.setFontSize(10.0);
      expect(dense.measureText('AB'), closeTo(short, 1e-9),
          reason: 'charts-canvas-theming.canvas-api#10');
      expect(canvas.measureText(''), 0.0,
          reason: 'charts-canvas-theming.canvas-api#10');
    });

    test('#11 drawTestImage issues exactly the canary sequence', () {
      final canvas = RecordingCanvas(widthPx: 1000, heightPx: 800, density: 2.0);
      canvas.drawTestImage();

      expect(canvas.ops.map(_format).toList(), [
        // Transparent background.
        'setColor(rgba(0.100,0.100,0.100,0.500))',
        'fillRect(0.0, 0.0, 500.0, 400.0)',
        // Center rectangle.
        'setColor(rgba(0.376,0.376,0.376,1.000))',
        'setStrokeWidth(25.0)',
        'drawRect(100.0, 100.0, 300.0, 200.0)',
        // Squares, circles and arcs.
        'setColor(rgba(1.000,1.000,0.000,1.000))',
        'setStrokeWidth(1.0)',
        'drawRect(0.0, 0.0, 100.0, 100.0)',
        'fillCircle(50.0, 50.0, 30.0)',
        'drawRect(0.0, 100.0, 100.0, 100.0)',
        'fillArc(50.0, 150.0, 30.0, 90.0, 135.0)',
        'drawRect(0.0, 200.0, 100.0, 100.0)',
        'fillArc(50.0, 250.0, 30.0, 90.0, -135.0)',
        'drawRect(0.0, 300.0, 100.0, 100.0)',
        'fillArc(50.0, 350.0, 30.0, 45.0, 90.0)',
        // Two red crossing lines.
        'setColor(rgba(1.000,0.000,0.000,1.000))',
        'setStrokeWidth(2.0)',
        'drawLine(0.0, 0.0, 500.0, 400.0)',
        'drawLine(500.0, 0.0, 0.0, 400.0)',
        // Text.
        'setFont(Font.bold)',
        'setFontSize(50.0)',
        'setColor(rgba(0.000,1.000,0.000,1.000))',
        'setTextAlign(TextAlign.center)',
        'drawText(HELLO, 250.0, 100.0)',
        'setTextAlign(TextAlign.right)',
        'drawText(HELLO, 250.0, 150.0)',
        'setTextAlign(TextAlign.left)',
        'drawText(HELLO, 250.0, 200.0)',
        // FontAwesome icon.
        'setFont(Font.fontAwesome)',
        'drawText(\u{f00c}, 250.0, 300.0)',
      ], reason: 'charts-canvas-theming.canvas-api#11');
      expect(canvas.ops.last.args.first, FontAwesome.check,
          reason: 'charts-canvas-theming.canvas-api#11');
    });

    test('#12 colour, font, size, stroke width and alignment are sticky', () {
      final canvas = RecordingCanvas();
      canvas.setColor(Color.GREEN);
      canvas.setFont(Font.bold);
      canvas.setFontSize(33.0);
      canvas.setStrokeWidth(4.0);
      canvas.setTextAlign(TextAlign.right);

      canvas.fillRect(0.0, 0.0, 1.0, 1.0);
      canvas.drawText('a', 0.0, 0.0);
      canvas.drawRect(0.0, 0.0, 1.0, 1.0);
      canvas.drawLine(0.0, 0.0, 1.0, 1.0);
      canvas.fillCircle(0.0, 0.0, 1.0);

      for (final op in canvas.ops.where((o) => o.style != null)) {
        expect(op.state.color, Color.GREEN,
            reason: 'charts-canvas-theming.canvas-api#12');
        expect(op.state.font, Font.bold,
            reason: 'charts-canvas-theming.canvas-api#12');
        expect(op.state.fontSize, 33.0,
            reason: 'charts-canvas-theming.canvas-api#12');
        expect(op.state.strokeWidth, 4.0,
            reason: 'charts-canvas-theming.canvas-api#12');
        expect(op.state.textAlign, TextAlign.right,
            reason: 'charts-canvas-theming.canvas-api#12');
      }

      // Nothing is reset between operations: drawTestImage relies on this when
      // it sets the font size once and draws four strings with it.
      final testImage =
          RecordingCanvas(widthPx: 1000, heightPx: 800, density: 2.0);
      testImage.drawTestImage();
      final texts = testImage.ops.where((o) => o.name == 'drawText').toList();
      expect(texts.map((o) => o.state.fontSize).toList(),
          [50.0, 50.0, 50.0, 50.0],
          reason: 'charts-canvas-theming.canvas-api#12');
      expect(texts.map((o) => o.state.color).toList(),
          [Color.GREEN, Color.GREEN, Color.GREEN, Color.GREEN],
          reason: 'charts-canvas-theming.canvas-api#12');
      expect(texts.map((o) => o.state.font).toList(),
          [Font.bold, Font.bold, Font.bold, Font.fontAwesome],
          reason: 'charts-canvas-theming.canvas-api#12');
      expect(
          testImage.ops
              .where((o) => o.name == 'drawLine')
              .map((o) => o.state.strokeWidth)
              .toList(),
          [2.0, 2.0],
          reason: 'charts-canvas-theming.canvas-api#12');
    });
  });

  group('charts-canvas-theming.view-interfaces', () {
    test('#1 View declares draw plus no-op onClick and onLongClick', () {
      final view = _MinimalView();
      final void Function(Canvas) draw = view.draw;
      final void Function(double, double) onClick = view.onClick;
      final void Function(double, double) onLongClick = view.onLongClick;

      final canvas = RecordingCanvas();
      draw(canvas);
      expect(view.log, ['draw'],
          reason: 'charts-canvas-theming.view-interfaces#1');

      // Both handlers default to doing nothing. _MinimalView overrides neither,
      // so the file would not compile if they were abstract.
      expect(() => onClick(1.0, 2.0), returnsNormally,
          reason: 'charts-canvas-theming.view-interfaces#1');
      expect(() => onLongClick(3.0, 4.0), returnsNormally,
          reason: 'charts-canvas-theming.view-interfaces#1');
      expect(view.log, ['draw'],
          reason: 'charts-canvas-theming.view-interfaces#1');
    });

    test('#2 DataView is a View with dataOffset and dataColumnWidth', () {
      final view = _ColumnChart(dataColumnWidth: 50.0);
      expect(view, isA<View>(),
          reason: 'charts-canvas-theming.view-interfaces#2');
      expect(view, isA<DataView>(),
          reason: 'charts-canvas-theming.view-interfaces#2');

      final DataView asDataView = view;
      expect(asDataView.dataOffset, 0,
          reason: 'charts-canvas-theming.view-interfaces#2');
      asDataView.dataOffset = 7; // mutable through the interface
      expect(asDataView.dataOffset, 7,
          reason: 'charts-canvas-theming.view-interfaces#2');
      // Read-only (a getter, no setter), and in the same logical units as
      // draw().
      expect(asDataView.dataColumnWidth, 50.0,
          reason: 'charts-canvas-theming.view-interfaces#2');
      expect(asDataView.dataColumnWidth, isA<double>(),
          reason: 'charts-canvas-theming.view-interfaces#2');
      expect(asDataView.dataOffset, isA<int>(),
          reason: 'charts-canvas-theming.view-interfaces#2');
    });

    test('#3 dataOffset 0 pins the newest column to the right edge', () {
      final canvas = RecordingCanvas(widthPx: 400, heightPx: 200, density: 2.0);
      final chart = _ColumnChart(dataColumnWidth: 50.0);

      chart.draw(canvas);
      expect(chart.columns.length, 4,
          reason: 'charts-canvas-theming.view-interfaces#3');
      expect(chart.columns.last.dataIndex, 0,
          reason: 'charts-canvas-theming.view-interfaces#3');
      expect(chart.columns.last.right, canvas.getWidth(),
          reason: 'charts-canvas-theming.view-interfaces#3');

      // Larger values scroll into older data, one whole column at a time.
      chart.dataOffset = 2;
      chart.draw(canvas);
      expect(chart.columns.last.dataIndex, 2,
          reason: 'charts-canvas-theming.view-interfaces#3');
      expect(chart.columns.map((c) => c.dataIndex).toList(), [5, 4, 3, 2],
          reason: 'charts-canvas-theming.view-interfaces#3');
      expect(chart.columns.last.right, canvas.getWidth(),
          reason: 'charts-canvas-theming.view-interfaces#3');

      // The host never hands over a negative offset (AndroidDataView clamps the
      // scroller position with max(0, ...)).
      expect(_hostDataOffset(-500, 50.0, 2.0), 0,
          reason: 'charts-canvas-theming.view-interfaces#3');
      expect(_hostDataOffset(0, 50.0, 2.0), 0,
          reason: 'charts-canvas-theming.view-interfaces#3');
      expect(_hostDataOffset(250, 50.0, 2.0), 2,
          reason: 'charts-canvas-theming.view-interfaces#3');
    });

    test('#4 click coordinates arrive in the same logical units as draw', () {
      final canvas = RecordingCanvas(widthPx: 400, heightPx: 200, density: 2.0);
      final chart = _ColumnChart(dataColumnWidth: 50.0);
      chart.draw(canvas);

      // The host divides the device-pixel touch position by the density before
      // calling in, so 270px on a density-2 screen is logical x = 135, which
      // falls inside the third drawn column [100, 150).
      _hostClick(chart, 270.0, 20.0, 2.0);
      expect(chart.clicked, [1],
          reason: 'charts-canvas-theming.view-interfaces#4');
      final column = chart.columns[2];
      expect(column.left <= 135.0 && 135.0 < column.right, isTrue,
          reason: 'charts-canvas-theming.view-interfaces#4');
      expect(column.dataIndex, 1,
          reason: 'charts-canvas-theming.view-interfaces#4');

      _hostLongClick(chart, 30.0, 20.0, 2.0);
      expect(chart.longClicked, [3],
          reason: 'charts-canvas-theming.view-interfaces#4');
    });

    test('#5 a chart tolerates or reports onClick before draw', () {
      // The plain View default is a no-op, so calling it before draw is safe.
      final minimal = _MinimalView();
      expect(() => minimal.onClick(1.0, 1.0), returnsNormally,
          reason: 'charts-canvas-theming.view-interfaces#5');

      // A chart that caches its width during draw reports the misuse instead of
      // computing on a zero width, exactly as HistoryChart does.
      final chart = _ColumnChart(dataColumnWidth: 50.0);
      expect(
          () => chart.onClick(10.0, 10.0),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              'onClick must be called after draw(canvas)')),
          reason: 'charts-canvas-theming.view-interfaces#5');
      chart.draw(RecordingCanvas(widthPx: 400, heightPx: 200, density: 2.0));
      expect(() => chart.onClick(10.0, 10.0), returnsNormally,
          reason: 'charts-canvas-theming.view-interfaces#5');
    });
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Whether a recorded operation painted a solid shape or an outline, mirroring
/// android.graphics.Paint.Style.
enum PaintStyle { fill, stroke }

/// A snapshot of the sticky paint state at the moment an operation was issued.
class CanvasState {
  const CanvasState({
    required this.color,
    required this.font,
    required this.fontSize,
    required this.strokeWidth,
    required this.textAlign,
  });

  final Color color;
  final Font font;
  final double fontSize;
  final double strokeWidth;
  final TextAlign textAlign;
}

/// One recorded call, with the logical arguments it was given, the device
/// pixels it resolved to, and the geometry the backend derived from it.
class RecordedOp {
  RecordedOp(
    this.name,
    this.args, {
    required this.state,
    this.style,
    this.px = const [],
    this.geom = const {},
    this.useCenter = false,
  });

  final String name;
  final List<Object?> args;
  final CanvasState state;
  final PaintStyle? style;
  final List<double> px;
  final Map<String, double> geom;
  final bool useCenter;

  /// Pie-sector hit test for a recorded fillArc, in logical coordinates.
  bool sectorContains(double x, double y) {
    final centerX = args[0]! as double;
    final centerY = args[1]! as double;
    final radius = args[2]! as double;
    final startAngle = args[3]! as double;
    final swipeAngle = args[4]! as double;
    final dx = x - centerX;
    final dy = centerY - y; // screen y grows downwards, angles grow upwards
    final distance = sqrt(dx * dx + dy * dy);
    if (distance > radius) return false;
    if (distance == 0.0) return useCenter;
    var angle = atan2(dy, dx) * 180.0 / pi;
    final from = min(startAngle, startAngle + swipeAngle);
    final to = max(startAngle, startAngle + swipeAngle);
    while (angle < from) {
      angle += 360.0;
    }
    return angle <= to;
  }
}

/// A backend that paints nothing and records everything. It reproduces the
/// coordinate and paint conventions of AndroidCanvas/JavaCanvas: logical units
/// in, device pixels out; a single colour shared by shapes and text; explicit
/// FILL/STROKE per operation.
class RecordingCanvas extends Canvas {
  RecordingCanvas({
    this.widthPx = 1000,
    this.heightPx = 800,
    this.density = 2.0,
  });

  final int widthPx;
  final int heightPx;
  final double density;

  final List<RecordedOp> ops = [];

  Color _color = Color.BLACK;
  Font _font = Font.regular;
  double _fontSize = 12.0;
  double _strokeWidth = 1.0;
  TextAlign _textAlign = TextAlign.center;

  /// The colour the fake would use for shapes and for text. AndroidCanvas keeps
  /// two Paint objects but assigns both from setColor.
  Color get shapeColor => _color;
  Color get textColor => _color;

  CanvasState get _state => CanvasState(
        color: _color,
        font: _font,
        fontSize: _fontSize,
        strokeWidth: _strokeWidth,
        textAlign: _textAlign,
      );

  RecordedOp opNamed(String name) => ops.firstWhere((o) => o.name == name);

  double _toPx(double x) => x * density;

  void _record(
    String name,
    List<Object?> args, {
    PaintStyle? style,
    List<double> px = const [],
    Map<String, double> geom = const {},
    bool useCenter = false,
  }) {
    ops.add(RecordedOp(name, args,
        state: _state, style: style, px: px, geom: geom, useCenter: useCenter));
  }

  @override
  void setColor(Color color) {
    _color = color;
    _record('setColor', [color]);
  }

  @override
  void drawLine(double x1, double y1, double x2, double y2) {
    _record('drawLine', [x1, y1, x2, y2],
        style: PaintStyle.stroke,
        px: [_toPx(x1), _toPx(y1), _toPx(x2), _toPx(y2)]);
  }

  @override
  void drawText(String text, double x, double y) {
    final width = measureText(text);
    final ascent = 0.8 * _fontSize;
    final descent = 0.2 * _fontSize;
    final height = ascent + descent;
    final left = switch (_textAlign) {
      TextAlign.left => x,
      TextAlign.center => x - width / 2,
      TextAlign.right => x - width,
    };
    final top = y - height / 2;
    _record('drawText', [text, x, y], style: PaintStyle.fill, geom: {
      'left': left,
      'right': left + width,
      'centerX': left + width / 2,
      'top': top,
      'bottom': top + height,
      'centerY': y,
      'baselineY': top + ascent,
      'width': width,
    });
  }

  @override
  void fillRect(double x, double y, double width, double height) {
    _record('fillRect', [x, y, width, height],
        style: PaintStyle.fill,
        px: [_toPx(x), _toPx(y), _toPx(width), _toPx(height)]);
  }

  @override
  void fillRoundRect(
      double x, double y, double width, double height, double cornerRadius) {
    _record('fillRoundRect', [x, y, width, height, cornerRadius],
        style: PaintStyle.fill,
        px: [_toPx(x), _toPx(y), _toPx(width), _toPx(height)]);
  }

  @override
  void drawRect(double x, double y, double width, double height) {
    _record('drawRect', [x, y, width, height],
        style: PaintStyle.stroke,
        px: [_toPx(x), _toPx(y), _toPx(width), _toPx(height)]);
  }

  @override
  double getHeight() => heightPx / density;

  @override
  double getWidth() => widthPx / density;

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
  void fillArc(double centerX, double centerY, double radius,
      double startAngle, double swipeAngle) {
    double pointX(double angle) => centerX + radius * cos(angle * pi / 180.0);
    double pointY(double angle) => centerY - radius * sin(angle * pi / 180.0);
    _record('fillArc', [centerX, centerY, radius, startAngle, swipeAngle],
        style: PaintStyle.fill,
        useCenter: true,
        geom: {
          'startX': pointX(startAngle),
          'startY': pointY(startAngle),
          'endX': pointX(startAngle + swipeAngle),
          'endY': pointY(startAngle + swipeAngle),
        });
  }

  @override
  void fillCircle(double centerX, double centerY, double radius) {
    _record('fillCircle', [centerX, centerY, radius],
        style: PaintStyle.fill,
        px: [_toPx(centerX), _toPx(centerY), _toPx(radius)]);
  }

  @override
  void setTextAlign(TextAlign align) {
    _textAlign = align;
    _record('setTextAlign', [align]);
  }

  @override
  Image toImage() => _FakeImage(widthPx, heightPx);

  @override
  double measureText(String text) =>
      text.length * 0.6 * _fontSize * (_font == Font.bold ? 1.1 : 1.0);
}

class _FakeImage extends Image {
  _FakeImage(this.width, this.height);

  @override
  final int width;

  @override
  final int height;

  @override
  PixelColor getPixel(int x, int y) => const PixelColor(0.0, 0.0, 0.0, 1.0);

  @override
  void setPixel(int x, int y, PixelColor color) {}

  @override
  Future<void> export(String path) async {}
}

String _format(RecordedOp op) {
  final args = op.args.map((a) {
    if (a is double) return a.toStringAsFixed(1);
    if (a is Color) {
      return 'rgba(${a.red.toStringAsFixed(3)},${a.green.toStringAsFixed(3)},'
          '${a.blue.toStringAsFixed(3)},${a.alpha.toStringAsFixed(3)})';
    }
    return '$a';
  }).join(', ');
  return '${op.name}($args)';
}

class _MinimalView extends View {
  final List<String> log = [];

  @override
  void draw(Canvas canvas) {
    log.add('draw');
  }
}

class _Column {
  const _Column(this.dataIndex, this.left, this.right);

  final int dataIndex;
  final double left;
  final double right;
}

/// A stand-in for BarChart/HistoryChart: it lays out whole data columns from the
/// right edge of the canvas and maps clicks back to the data index under the
/// finger, the way the real charts do.
class _ColumnChart extends DataView {
  _ColumnChart({required this.dataColumnWidth});

  @override
  final double dataColumnWidth;

  @override
  int dataOffset = 0;

  double _width = 0.0;
  final List<_Column> columns = [];
  final List<int> clicked = [];
  final List<int> longClicked = [];

  @override
  void draw(Canvas canvas) {
    _width = canvas.getWidth();
    columns.clear();
    final nColumns = (_width / dataColumnWidth).floor();
    for (var c = 0; c < nColumns; c++) {
      final left = _width - (nColumns - c) * dataColumnWidth;
      columns.add(_Column(
          nColumns - c - 1 + dataOffset, left, left + dataColumnWidth));
    }
  }

  int _dataIndexAt(double x) {
    if (_width <= 0.0) {
      throw StateError('onClick must be called after draw(canvas)');
    }
    final nColumns = (_width / dataColumnWidth).floor();
    final c = (x / dataColumnWidth).floor();
    return nColumns - c - 1 + dataOffset;
  }

  @override
  void onClick(double x, double y) {
    clicked.add(_dataIndexAt(x));
  }

  @override
  void onLongClick(double x, double y) {
    longClicked.add(_dataIndexAt(x));
  }
}

/// AndroidView.handleClick: device pixels divided by the display density.
void _hostClick(View view, double xPx, double yPx, double density) {
  view.onClick(xPx / density, yPx / density);
}

void _hostLongClick(View view, double xPx, double yPx, double density) {
  view.onLongClick(xPx / density, yPx / density);
}

/// AndroidDataView.updateDataOffset: whole columns of scroll, clamped at zero.
int _hostDataOffset(int scrollXPx, double dataColumnWidth, double density) =>
    max(0, scrollXPx ~/ (dataColumnWidth * density).toInt());
