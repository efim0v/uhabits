/// `charts-canvas-theming.ring-view-android`.
///
/// The Android `RingView`, ported in app/lib/ui/common/views/ring_view.dart.
/// Goldens upstream: androidTest/assets/views/common/RingView/{render,
/// renderDifferentParams}.png — 100x100dp at percentage 0.6 with the text
/// "60%", palette colour 0, a white background and 3dp of thickness; and
/// 200x200dp at percentage 0.25 with palette colour 5.
///
/// Every drawing case below replays the painter onto a recording `ui.Canvas`
/// and reads the call trace back, so what is asserted is the sequence of
/// primitives a golden would rasterise: which arc, in which colour, in which
/// order, with which blend mode.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/common/views/ring_view.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  const habitColor = Color(0xFFD32F2F);
  const cardBackground = Color(0xFFFAFAFA);
  final inactive = RingView.applyInactiveAlpha(const Color(0xFF424242));

  RingViewPainter painter({
    double percentage = 0.6,
    double precision = RingViewAttributes.defaultPrecision,
    double thickness = 3.0,
    String text = '',
    double textSize = RingViewAttributes.defaultTextSize,
    bool isStrokedTextEnabled = false,
    bool isTransparencyEnabled = false,
    Color color = habitColor,
    Color backgroundColor = cardBackground,
  }) {
    return RingViewPainter(
      percentage: percentage,
      precision: precision,
      color: color,
      backgroundColor: backgroundColor,
      inactiveColor: inactive,
      thickness: thickness,
      text: text,
      textSize: textSize,
      isStrokedTextEnabled: isStrokedTextEnabled,
      isTransparencyEnabled: isTransparencyEnabled,
    );
  }

  group('charts-canvas-theming.ring-view-android', () {
    testWidgets('#1 the view is square, sized by the smaller of the two specs',
        (tester) async {
      const rule = 'charts-canvas-theming.ring-view-android#1';

      expect(RingViewPainter.diameterOf(const Size(200, 100)), 100.0,
          reason: '$rule — diameter = max(1, min(measuredHeight, '
              'measuredWidth))');
      expect(RingViewPainter.diameterOf(const Size(80, 240)), 80.0,
          reason: rule);
      expect(RingViewPainter.diameterOf(Size.zero), 1.0,
          reason: '$rule — the max(1, …) floor, so a zero-sized ring still '
              'has a canvas');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: RingView(
                percentage: 0.6,
                color: habitColor,
                backgroundColor: cardBackground,
                inactiveColor: inactive,
                thickness: 3,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(CustomPaint).last),
          const Size(100, 100),
          reason: '$rule — onMeasure reports (diameter, diameter), so a '
              '200x100 box paints a 100x100 ring');

      // `em = pRing.measureText("M")` at the current text size: a width, not a
      // height, and it scales with the text size.
      final small = painter(textSize: 10).measureEm();
      final large = painter(textSize: 20).measureEm();
      expect(small, greaterThan(0.0),
          reason: '$rule — em is the advance width of "M"');
      expect(large, closeTo(small * 2, 1e-6),
          reason: '$rule — measured at the current text size');
    });

    test('#2 the XML attribute defaults, and what an unparseable one does', () {
      const rule = 'charts-canvas-theming.ring-view-android#2';

      expect(isoronNamespace, 'http://isoron.org/android', reason: rule);

      const defaults = RingViewAttributes();
      expect(defaults.percentage, 0.0, reason: '$rule — percentage=0f');
      expect(defaults.precision, 0.01, reason: '$rule — precision=0.01f');
      expect(defaults.color, const Color(0x00000000),
          reason: '$rule — color=0');
      expect(defaults.backgroundColor, isNull,
          reason: '$rule — backgroundColor=null, which init() resolves to '
              'cardBgColor');
      expect(defaults.inactiveColor, isNull,
          reason: '$rule — inactiveColor=null, which init() resolves to '
              'contrast100');
      expect(defaults.thickness, 0.0,
          reason: '$rule — thickness=0f, interpreted as dp');
      expect(defaults.textSize, 14.0,
          reason: '$rule — textSize = R.dimen.smallTextSize, 14sp');
      expect(defaults.text, '', reason: '$rule — text=""');
      expect(defaults.enableFontAwesome, isFalse,
          reason: '$rule — enableFontAwesome=false');

      // An empty attribute set falls back to every default.
      expect(RingViewAttributes.fromAttributeSet(const <String, String?>{})
          .precision, 0.01, reason: rule);

      // `getFloatAttribute` catches NumberFormatException and returns the
      // default rather than letting the inflater throw.
      final broken = RingViewAttributes.fromAttributeSet(
        const <String, String?>{
          'percentage': 'not-a-number',
          'thickness': '',
          'precision': '0.5',
        },
      );
      expect(broken.percentage, 0.0,
          reason: '$rule — an unparseable float falls back to the default '
              'rather than throwing');
      expect(broken.thickness, 0.0, reason: rule);
      expect(broken.precision, 0.5,
          reason: '$rule — a parseable one still wins');

      // The two colours the layout leaves out are resolved against the theme.
      final resolved = RingView.fromAttributes(
        RingViewAttributes.fromAttributeSet(
          const <String, String?>{'thickness': '2', 'enableFontAwesome': 'true'},
        ),
        theme: core.LightTheme(),
      );
      expect(resolved.backgroundColor, const Color(0xFFFAFAFA),
          reason: '$rule — backgroundColor falls back to ?attr/cardBgColor');
      expect(argb(resolved.inactiveColor) >>> 24, 38,
          reason: '$rule — inactiveColor falls back to ?attr/contrast100, '
              'then to 15% alpha');
      expect(resolved.enableFontAwesome, isTrue, reason: rule);
    });

    test('#3 inactiveColor is forced to 15% alpha at construction', () {
      const rule = 'charts-canvas-theming.ring-view-android#3';

      expect(ringInactiveAlpha, 0.15, reason: rule);
      // `setAlpha` truncates: (0.15f * 255).toInt() == 38, not 38.25 rounded.
      expect(argb(RingView.applyInactiveAlpha(const Color(0xFF424242))) >>> 24,
          38,
          reason: '$rule — ColorUtils.setAlpha truncates the alpha byte');
      expect(argb(RingView.applyInactiveAlpha(const Color(0x80FFFFFF))),
          argb(const Color(0xFFFFFFFF).withValues(alpha: 38 / 255.0)),
          reason: '$rule — whatever alpha the source colour carried');
    });

    test('#4 the angle is quantised by precision', () {
      const rule = 'charts-canvas-theming.ring-view-android#4';

      expect(painter(percentage: 0.6).sweepDegrees, closeTo(216.0, 1e-9),
          reason: '$rule — angle = 360 * round(percentage / precision) * '
              'precision');
      expect(painter(percentage: 0.6049).sweepDegrees, closeTo(216.0, 1e-9),
          reason: '$rule — the default precision snaps to 1% steps');
      expect(painter(percentage: 0.606).sweepDegrees, closeTo(219.6, 1e-9),
          reason: '$rule — which are 3.6 degrees apart');
      expect(painter(percentage: 0.6, precision: 0.25).sweepDegrees,
          closeTo(180.0, 1e-9),
          reason: '$rule — a coarser precision snaps harder: round(2.4) = 2');
    });

    testWidgets('#5 the three arcs, in order', (tester) async {
      const rule = 'charts-canvas-theming.ring-view-android#5';
      final trace = await _record(tester, painter(percentage: 0.6));
      final arcs = trace.arcs;

      expect(arcs.length, 3,
          reason: '$rule — progress, remainder, then the hole');

      expect(arcs[0].startDegrees, closeTo(-90.0, 1e-6),
          reason: '$rule — drawArc(rect, -90f, angle, useCenter=true)');
      expect(arcs[0].sweepDegrees, closeTo(216.0, 1e-6), reason: rule);
      expect(arcs[0].useCenter, isTrue,
          reason: '$rule — a pie sector, not a stroked ring');
      expect(arcs[0].color, argb(habitColor),
          reason: '$rule — the progress arc is the habit colour');
      expect(arcs[0].rect, const Rect.fromLTWH(0, 0, 100, 100), reason: rule);

      expect(arcs[1].startDegrees, closeTo(216.0 - 90.0, 1e-6),
          reason: '$rule — drawArc(rect, angle - 90f, 360 - angle, true)');
      expect(arcs[1].sweepDegrees, closeTo(360.0 - 216.0, 1e-6), reason: rule);
      expect(arcs[1].color, argb(inactive), reason: rule);

      expect(arcs[2].sweepDegrees, closeTo(360.0, 1e-6),
          reason: '$rule — the hole is a full 360-degree arc');
      expect(arcs[2].rect, const Rect.fromLTWH(3, 3, 94, 94),
          reason: '$rule — over the rect inset by thickness on all sides');
      expect(arcs[2].color, argb(cardBackground),
          reason: '$rule — filled with backgroundColor when transparency is '
              'off');

      // `if (thickness > 0)` — with no thickness there is no hole at all.
      final flat = await _record(tester, painter(thickness: 0));
      expect(flat.arcs.length, 2,
          reason: '$rule — the third arc is drawn "only when thickness > 0"');
    });

    testWidgets('#6 the centre label', (tester) async {
      const rule = 'charts-canvas-theming.ring-view-android#6';

      final withText = painter(text: '60%', textSize: 12);
      final trace = await _record(tester, withText);
      expect(trace.paragraphs.length, 1,
          reason: '$rule — one label, drawn inside the thickness branch');

      final em = withText.measureEm();
      final drawn = trace.paragraphs.single;
      // The inset rect is (3, 3, 97, 97): centre (50, 50).
      expect(drawn.center.dx, closeTo(50.0, 0.5),
          reason: '$rule — CENTER-aligned on the inset rect\'s centreX');
      expect(drawn.center.dy, closeTo(50.0 + 0.4 * em, 0.5),
          reason: '$rule — at centreY + 0.4f * em');
      expect(drawn.height, closeTo(12.0, 6.0),
          reason: '$rule — laid out at textSize');

      final flat = await _record(tester, painter(text: '60%', thickness: 0));
      expect(flat.paragraphs, isEmpty,
          reason: '$rule — no thickness, no label: the drawText call lives '
              'inside the same `if (thickness > 0)` block as the hole');
    });

    testWidgets('#7 stroked text and the FontAwesome typeface', (tester) async {
      const rule = 'charts-canvas-theming.ring-view-android#7';

      expect(painter(textSize: 30).strokeTextWidth, 2.0,
          reason: '$rule — strokeWidth = textSize / 15f');

      final stroked = await _record(
        tester,
        painter(text: '60%', textSize: 12, isStrokedTextEnabled: true),
      );
      expect(stroked.paragraphs.length, 1,
          reason: '$rule — the label is still drawn, as an outline');
      expect(stroked.paragraphs.single.width,
          greaterThan(0.0),
          reason: rule);

      // `if (enableFontAwesome) pRing.typeface = getFontAwesome(context)`.
      const glyph = core.FontAwesome.check;
      final awesome = RingViewPainter(
        percentage: 0.6,
        color: habitColor,
        backgroundColor: cardBackground,
        inactiveColor: inactive,
        thickness: 2,
        text: glyph,
        textSize: 16,
        enableFontAwesome: true,
      );
      final plain = RingViewPainter(
        percentage: 0.6,
        color: habitColor,
        backgroundColor: cardBackground,
        inactiveColor: inactive,
        thickness: 2,
        text: glyph,
        textSize: 16,
      );
      expect((await _record(tester, awesome)).paragraphs.length, 1,
          reason: '$rule — a FontAwesome ring still draws its glyph');
      expect((await _record(tester, plain)).paragraphs.length, 1,
          reason: rule);
    });

    testWidgets('#8 transparency draws into an offscreen layer', (tester) async {
      const rule = 'charts-canvas-theming.ring-view-android#8';

      final opaque = await _record(tester, painter());
      expect(opaque.saveLayerCount, 0,
          reason: '$rule — no offscreen buffer when transparency is off');

      final transparent =
          await _record(tester, painter(isTransparencyEnabled: true));
      expect(transparent.saveLayerCount, 1,
          reason: '$rule — an ARGB_8888 bitmap of diameter x diameter, erased '
              'to Color.TRANSPARENT, is a saveLayer here');
      expect(transparent.saveLayerBounds.single,
          const Rect.fromLTWH(0, 0, 100, 100),
          reason: '$rule — sized diameter x diameter');
      expect(transparent.restoreCount, 1,
          reason: '$rule — and blitted onto the real canvas at the end');

      // The point of the buffer: the hole is punched, not overpainted.
      expect(transparent.arcs[2].blendMode, BlendMode.clear,
          reason: '$rule — PorterDuff.CLEAR against the layer');
      expect(opaque.arcs[2].blendMode, BlendMode.srcOver,
          reason: '$rule — where the opaque path just fills with the card '
              'background');
    });

    test('#9 which setters invalidate and which do not', () {
      const rule = 'charts-canvas-theming.ring-view-android#9';
      final base = painter(text: 'a', textSize: 12);

      // The six that call invalidate().
      expect(base.shouldRepaint(painter(text: 'a', textSize: 12, color: const Color(0xFF00897B))),
          isTrue, reason: '$rule — setColor');
      expect(
          base.shouldRepaint(
              painter(text: 'a', textSize: 12, percentage: 0.7)),
          isTrue,
          reason: '$rule — setPercentage');
      expect(
          base.shouldRepaint(
              painter(text: 'a', textSize: 12, precision: 0.5)),
          isTrue,
          reason: '$rule — setPrecision');
      expect(base.shouldRepaint(painter(text: 'b', textSize: 12)), isTrue,
          reason: '$rule — setText');
      expect(
          base.shouldRepaint(
              painter(text: 'a', textSize: 12, thickness: 9)),
          isTrue,
          reason: '$rule — setThickness');
      expect(
          base.shouldRepaint(painter(
              text: 'a',
              textSize: 12,
              backgroundColor: const Color(0xFF303030))),
          isTrue,
          reason: '$rule — setBackgroundColor');

      // The three that do not. Upstream behaviour, kept rather than fixed: a
      // ring whose only change is its text size keeps the old drawing.
      expect(base.shouldRepaint(painter(text: 'a', textSize: 30)), isFalse,
          reason: '$rule — setTextSize does not call invalidate()');
      expect(
          base.shouldRepaint(painter(
              text: 'a', textSize: 12, isStrokedTextEnabled: true)),
          isFalse,
          reason: '$rule — nor does setIsStrokedTextEnabled');
      expect(
          base.shouldRepaint(painter(
              text: 'a', textSize: 12, isTransparencyEnabled: true)),
          isFalse,
          reason: '$rule — nor setIsTransparencyEnabled');
    });

    test('#10 the three concrete usages', () {
      const rule = 'charts-canvas-theming.ring-view-android#10';

      expect(RingViewUsages.overviewSize, 30.0,
          reason: '$rule — the show-habit overview ring is 30dp');
      expect(RingViewUsages.overviewThickness, 5.0,
          reason: '$rule — with thickness 5dp');
      expect(RingViewUsages.overviewTextSize, 12.0,
          reason: '$rule — and textSize 12');

      expect(RingViewUsages.listCardSize, 15.0,
          reason: '$rule — the habit list card ring is 15dp');
      expect(RingViewUsages.listCardThickness, 3.0,
          reason: '$rule — with thickness 3dp');
      expect(RingViewUsages.listCardMargin, 8.0,
          reason: '$rule — and 8dp horizontal margins');

      expect(RingViewUsages.widgetThickness, 2.0,
          reason: '$rule — the checkmark widget ring uses thickness 2dp');
      expect(RingViewUsages.widgetTextSize, 16.0,
          reason: '$rule — textSize 16');
      expect(RingViewUsages.widgetEnableFontAwesome, isTrue,
          reason: '$rule — and enableFontAwesome=true');
    });
  });
}

// ---------------------------------------------------------------------------
// A recording ui.Canvas
// ---------------------------------------------------------------------------

/// A [Color] as the packed ARGB int Android would have used.
int argb(Color color) =>
    ((color.a * 255).round().clamp(0, 255) << 24) |
    ((color.r * 255).round().clamp(0, 255) << 16) |
    ((color.g * 255).round().clamp(0, 255) << 8) |
    (color.b * 255).round().clamp(0, 255);

/// One `drawArc` call plus the paint state it was made under.
class _Arc {
  _Arc(this.rect, this.startDegrees, this.sweepDegrees, this.useCenter,
      this.color, this.blendMode);

  final Rect rect;
  final double startDegrees;
  final double sweepDegrees;
  final bool useCenter;

  /// The packed ARGB int. `Paint` keeps its colour as float32 components, so a
  /// round trip through it is not `==` to the `Color` that went in; the byte
  /// values are.
  final int color;
  final BlendMode blendMode;
}

/// One `drawParagraph` call, reduced to where it landed and how big it was.
class _Paragraph {
  _Paragraph(this.offset, this.width, this.height);

  final Offset offset;
  final double width;
  final double height;

  Offset get center => offset + Offset(width / 2, height / 2);
}

class _Trace {
  final List<_Arc> arcs = <_Arc>[];
  final List<_Paragraph> paragraphs = <_Paragraph>[];
  final List<Rect> saveLayerBounds = <Rect>[];
  int restoreCount = 0;

  int get saveLayerCount => saveLayerBounds.length;
}

/// Paints [painter] onto a 100x100 recording canvas and returns what it drew.
///
/// A real `ui.PictureRecorder` is used rather than a hand-written fake, so the
/// text layout is the one Flutter would actually rasterise; the call trace is
/// recovered by wrapping the canvas.
Future<_Trace> _record(WidgetTester tester, RingViewPainter painter) async {
  final trace = _Trace();
  final recorder = ui.PictureRecorder();
  final canvas = _RecordingCanvas(ui.Canvas(recorder), trace);
  painter.paint(canvas, const Size(100, 100));
  recorder.endRecording().dispose();
  return trace;
}

class _RecordingCanvas implements Canvas {
  _RecordingCanvas(this._target, this._trace);

  final Canvas _target;
  final _Trace _trace;

  @override
  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter,
      Paint paint) {
    _trace.arcs.add(
      _Arc(
        rect,
        startAngle * 180 / 3.141592653589793,
        sweepAngle * 180 / 3.141592653589793,
        useCenter,
        argb(paint.color),
        paint.blendMode,
      ),
    );
    _target.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, Offset offset) {
    _trace.paragraphs.add(
      _Paragraph(offset, paragraph.longestLine, paragraph.height),
    );
    _target.drawParagraph(paragraph, offset);
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) {
    _trace.saveLayerBounds.add(bounds ?? Rect.zero);
    _target.saveLayer(bounds, paint);
  }

  @override
  void restore() {
    _trace.restoreCount++;
    _target.restore();
  }

  @override
  noSuchMethod(Invocation invocation) =>
      // Everything else forwards unrecorded; the painter draws nothing else.
      // ignore: avoid_dynamic_calls
      (_target as dynamic).noSuchMethod(invocation);
}
