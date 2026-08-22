import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' as painting;
import 'package:uhabits_core/uhabits_core.dart' as core;

/// Draws the core's charts onto a Flutter canvas.
///
/// Every chart in `uhabits_core` is written against [core.Canvas] and knows
/// nothing about any platform, which is the whole reason the chart code could
/// be ported line by line. This class is the one place that translates that
/// vocabulary into `dart:ui`.
///
/// Flutter's logical pixels are already density-independent, so unlike
/// AndroidCanvas and JavaCanvas this backend needs no density conversion.
class FlutterCanvas extends core.Canvas {
  FlutterCanvas(this._canvas, this._size);

  final ui.Canvas _canvas;
  final ui.Size _size;

  ui.Color _color = const ui.Color(0xFF000000);
  core.Font _font = core.Font.regular;
  double _fontSize = 12;
  double _strokeWidth = 1;
  core.TextAlign _textAlign = core.TextAlign.center;

  ui.Paint get _fillPaint => ui.Paint()
    ..color = _color
    ..style = ui.PaintingStyle.fill
    ..isAntiAlias = true;

  ui.Paint get _strokePaint => ui.Paint()
    ..color = _color
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = _strokeWidth
    ..isAntiAlias = true;

  @override
  void setColor(core.Color color) {
    _color = ui.Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
  }

  @override
  void setFont(core.Font font) => _font = font;

  @override
  void setFontSize(double size) => _fontSize = size;

  @override
  void setStrokeWidth(double size) => _strokeWidth = size;

  @override
  void setTextAlign(core.TextAlign align) => _textAlign = align;

  @override
  double getWidth() => _size.width;

  @override
  double getHeight() => _size.height;

  @override
  void drawLine(double x1, double y1, double x2, double y2) {
    _canvas.drawLine(ui.Offset(x1, y1), ui.Offset(x2, y2), _strokePaint);
  }

  @override
  void fillRect(double x, double y, double width, double height) {
    _canvas.drawRect(ui.Rect.fromLTWH(x, y, width, height), _fillPaint);
  }

  @override
  void drawRect(double x, double y, double width, double height) {
    _canvas.drawRect(ui.Rect.fromLTWH(x, y, width, height), _strokePaint);
  }

  @override
  void fillRoundRect(
    double x,
    double y,
    double width,
    double height,
    double cornerRadius,
  ) {
    _canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(x, y, width, height),
        ui.Radius.circular(cornerRadius),
      ),
      _fillPaint,
    );
  }

  @override
  void fillCircle(double centerX, double centerY, double radius) {
    _canvas.drawCircle(ui.Offset(centerX, centerY), radius, _fillPaint);
  }

  @override
  void fillArc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double swipeAngle,
  ) {
    // The core speaks java.awt.Graphics2D.fillArc: zero degrees points at three
    // o'clock and a positive sweep runs counterclockwise. dart:ui sweeps the
    // other way, so both angles are negated — the same correction
    // AndroidCanvas makes.
    const toRadians = math.pi / 180.0;
    _canvas.drawArc(
      ui.Rect.fromCircle(center: ui.Offset(centerX, centerY), radius: radius),
      -startAngle * toRadians,
      -swipeAngle * toRadians,
      true,
      _fillPaint,
    );
  }

  @override
  void drawText(String text, double x, double y) {
    final painter = _layout(text);
    final left = switch (_textAlign) {
      core.TextAlign.left => x,
      core.TextAlign.center => x - painter.width / 2,
      core.TextAlign.right => x - painter.width,
    };
    // The core anchors text on its visual centre, not on the baseline.
    painter.paint(_canvas, ui.Offset(left, y - painter.height / 2));
  }

  @override
  double measureText(String text) => _layout(text).width;

  painting.TextPainter _layout(String text) {
    final painter = painting.TextPainter(
      text: painting.TextSpan(
        text: text,
        style: painting.TextStyle(
          color: _color,
          fontSize: _fontSize,
          fontFamily: _font == core.Font.fontAwesome ? 'FontAwesome' : 'NotoSans',
          fontWeight:
              _font == core.Font.bold ? ui.FontWeight.w700 : ui.FontWeight.w400,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter;
  }

  @override
  core.Image toImage() {
    throw UnsupportedError(
      'FlutterCanvas draws straight to the screen. Golden capture goes through '
      'RecordingFlutterCanvas instead.',
    );
  }
}
