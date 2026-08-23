/// `charts-canvas-theming.score-chart#16` — the widget-transparency path.
///
/// The rest of `ScoreChart` is asserted in
/// app/test/ui/habits/show/chart_cards_test.dart, against a recording
/// `core.Canvas`. This one rule cannot be: it is about a construction that lives
/// *below* the shared canvas API — an `ARGB_8888` bitmap of the view's size,
/// erased to `Color.TRANSPARENT` every frame and blitted onto the real canvas at
/// the end, which is what makes the marker's `PorterDuff.CLEAR` punch a true
/// hole rather than smear the wallpaper.
///
/// `Canvas.saveLayer` is that construction in `dart:ui`, so the port declares it
/// as the `TransparencyCanvas` capability on `FlutterCanvas` and probes for it
/// the way the entry buttons probe `TextOutlineCanvas`. Both halves are checked
/// here: that the chart asks for the layer and the two blend modes when
/// transparency is on, and that a backend which cannot offer them makes it draw
/// the opaque marker instead of a wrong one.
library;

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_canvas.dart';
import 'package:uhabits/ui/habits/show/cards/score_card_view.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String rule = 'charts-canvas-theming.score-chart#16';

  final core.Theme theme = core.LightTheme();
  final core.Color habitColor = theme.colorOf(const core.PaletteColor(7));
  final core.LocalDate today = core.LocalDate.ymd(2015, 1, 25);

  ScoreChartView chart({required bool transparent}) => ScoreChartView(
        scores: <core.Score>[
          for (int i = 0; i < 6; i++)
            core.Score(today.minus(i), 0.2 + i * 0.1),
        ],
        color: habitColor,
        theme: transparent ? core.WidgetTheme() : theme,
        dateFormatter: _Formatter(),
        bucketSize: 7,
        isTransparencyEnabled: transparent,
      );

  test('#16 the flag alone does not change the drawing', () {
    expect(chart(transparent: false).isTransparencyEnabled, isFalse,
        reason: '$rule — the show-habit card draws over an opaque cardBgColor '
            'and leaves transparency off');
    expect(chart(transparent: true).isTransparencyEnabled, isTrue,
        reason: '$rule — setIsTransparencyEnabled(true) is the widget case');

    // The offscreen buffer is a capability of the backend, so a canvas that
    // cannot supply one is not asked to.
    final _PlainCanvas plain = _PlainCanvas();
    expect(chart(transparent: true).usesTransparencyOn(plain), isFalse,
        reason: '$rule — a canvas with no layer support falls back to the '
            'opaque path');
    chart(transparent: true).draw(plain);
    expect(plain.fillCircles, isNotEmpty,
        reason: '$rule — and still draws its markers, as two plain filled '
            'circles');
  });

  test('#16 transparency renders into a layer and clears the hole', () {
    // Opaque first: no layer, and the marker hole is overpainted.
    final _Trace opaque = _record(chart(transparent: false));
    expect(opaque.saveLayers, isEmpty,
        reason: '$rule — nothing offscreen when transparency is off');
    expect(opaque.clearCircles, 0,
        reason: '$rule — and no CLEAR: the hole is filled with the card '
            'background');

    final _Trace transparent = _record(chart(transparent: true));

    expect(transparent.saveLayers.length, 1,
        reason: '$rule — one ARGB_8888 buffer for the whole frame, not one '
            'per marker');
    expect(transparent.saveLayers.single,
        const ui.Rect.fromLTWH(0, 0, 300, 200),
        reason: '$rule — of the view size');
    expect(transparent.restores, 1,
        reason: '$rule — blitted onto the real canvas once, at the end');
    expect(transparent.saveLayerFirst, isTrue,
        reason: '$rule — and opened before anything is drawn, so the buffer '
            'really is erased to transparent under every primitive');

    // `setModeOrColor(pGraph, XFERMODE_CLEAR, internalBackgroundColor)` then
    // `setModeOrColor(pGraph, XFERMODE_SRC, primaryColor)`.
    expect(transparent.clearCircles, greaterThan(0),
        reason: '$rule — so that markers can punch true holes with PorterDuff '
            'CLEAR');
    expect(transparent.srcCircles, transparent.clearCircles,
        reason: '$rule — one SRC ring inside each CLEAR hole');
    expect(transparent.blendModes.contains(ui.BlendMode.src), isTrue,
        reason: '$rule — SRC, so the ring writes its own alpha instead of '
            'compositing over the hole it just made');

    // The grid, the line and the footer are ordinary drawing either way; only
    // the marker changes.
    expect(transparent.clearCircles, opaque.plainCircles ~/ 2,
        reason: '$rule — the same number of markers, drawn differently');
    expect(transparent.plainCircles, 0,
        reason: '$rule — and none of them is drawn the opaque way');
  });
}

/// Runs [view] against a real `dart:ui` canvas wrapped in a recorder, so the
/// blend modes and the layer are the ones Flutter would rasterise.
_Trace _record(ScoreChartView view) {
  final _Trace trace = _Trace();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final _RecordingUiCanvas canvas =
      _RecordingUiCanvas(ui.Canvas(recorder), trace);
  view.draw(FlutterCanvas(canvas, const ui.Size(300, 200)));
  recorder.endRecording().dispose();
  return trace;
}

class _Trace {
  final List<ui.Rect> saveLayers = <ui.Rect>[];
  final List<ui.BlendMode> blendModes = <ui.BlendMode>[];
  int restores = 0;
  int clearCircles = 0;
  int srcCircles = 0;
  int plainCircles = 0;
  bool saveLayerFirst = false;
  bool _sawAnything = false;

  void sawDraw() {
    _sawAnything = true;
  }

  void sawSaveLayer(ui.Rect bounds) {
    if (!_sawAnything && saveLayers.isEmpty) saveLayerFirst = true;
    saveLayers.add(bounds);
  }
}

class _RecordingUiCanvas implements ui.Canvas {
  _RecordingUiCanvas(this._target, this._trace);

  final ui.Canvas _target;
  final _Trace _trace;

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    _trace.sawSaveLayer(bounds ?? ui.Rect.zero);
    _target.saveLayer(bounds, paint);
  }

  @override
  void restore() {
    _trace.restores++;
    _target.restore();
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _trace
      ..sawDraw()
      ..blendModes.add(paint.blendMode);
    switch (paint.blendMode) {
      case ui.BlendMode.clear:
        _trace.clearCircles++;
      case ui.BlendMode.src:
        _trace.srcCircles++;
      default:
        _trace.plainCircles++;
    }
    _target.drawCircle(c, radius, paint);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _trace.sawDraw();
    _target.drawLine(p1, p2, paint);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    _trace.sawDraw();
    _target.drawRect(rect, paint);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    _trace.sawDraw();
    _target.drawParagraph(paragraph, offset);
  }

  @override
  noSuchMethod(Invocation invocation) =>
      // ignore: avoid_dynamic_calls
      (_target as dynamic).noSuchMethod(invocation);
}

/// A [core.Canvas] with no [TransparencyCanvas] behind it: the fallback case.
class _PlainCanvas extends core.Canvas {
  final List<List<double>> fillCircles = <List<double>>[];

  @override
  double getWidth() => 300.0;

  @override
  double getHeight() => 200.0;

  @override
  void fillCircle(double cx, double cy, double radius) =>
      fillCircles.add(<double>[cx, cy, radius]);

  @override
  void setColor(core.Color color) {}

  @override
  void setFont(core.Font font) {}

  @override
  void setFontSize(double size) {}

  @override
  void setStrokeWidth(double size) {}

  @override
  void setTextAlign(core.TextAlign align) {}

  @override
  void drawLine(double x1, double y1, double x2, double y2) {}

  @override
  void drawText(String text, double x, double y) {}

  @override
  void fillRect(double x, double y, double w, double h) {}

  @override
  void drawRect(double x, double y, double w, double h) {}

  @override
  void fillRoundRect(double x, double y, double w, double h, double r) {}

  @override
  void fillArc(double cx, double cy, double r, double start, double swipe) {}

  @override
  double measureText(String text) => text.length * 6.0;

  @override
  core.Image toImage() => throw UnimplementedError();
}

class _Formatter implements core.LocalDateFormatter {
  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  String shortMonthName(core.LocalDate date) => _months[date.month - 1];

  @override
  String shortWeekdayName(core.LocalDate date) => 'Sun';

  @override
  String longMonthName(core.LocalDate date) => shortMonthName(date);

  @override
  String shortWeekdayNameOf(core.DayOfWeek weekday) => 'Sun';

  @override
  String longWeekdayNameOf(core.DayOfWeek weekday) => 'Sunday';
}
