import 'color.dart';
import 'font_awesome.dart';
import 'image.dart';

// Port of uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/Canvas.kt.

enum TextAlign { left, center, right }

enum Font { regular, bold, fontAwesome }

/// Kotlin `data class ScreenLocation(val x: Double, val y: Double)`.
class ScreenLocation {
  const ScreenLocation(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is ScreenLocation && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'ScreenLocation(x=$x, y=$y)';
}

/// The single drawing API every chart in this package speaks. Charts never
/// touch a platform drawing API, which is the whole reason the chart code is
/// portable. A backend (dart:ui in the Flutter app, a raster recorder in golden
/// tests) implements the sixteen abstract members below; [fill] and
/// [drawTestImage] are shared defaults and are not meant to be overridden.
///
/// Units. Every coordinate and size crossing this interface is a `double` in
/// logical, density-independent units. Backends multiply by the display density
/// on the way in and divide on the way out — see `AndroidCanvas.toDp()` and
/// `JavaCanvas.toPixel()`.
///
/// State. Colour, font, font size, stroke width and text alignment are sticky:
/// they persist until set again, and no drawing operation resets them. The
/// colour is shared by shapes and text; there is no separate text colour.
abstract class Canvas {
  void setColor(Color color);

  void drawLine(double x1, double y1, double x2, double y2);

  /// Draws [text] anchored so that its vertical *visual centre* — not its
  /// baseline — sits at [y]. Horizontally, [x] is the left edge, the centre or
  /// the right edge, according to the current [TextAlign].
  void drawText(String text, double x, double y);

  /// Fills the rectangle with the current colour. Never strokes an outline.
  void fillRect(double x, double y, double width, double height);

  void fillRoundRect(
    double x,
    double y,
    double width,
    double height,
    double cornerRadius,
  );

  /// Strokes the rectangle with the current colour and stroke width. Never
  /// fills the interior, and must leave the backend ready for the next
  /// [fillRect] — Android does this by setting `Paint.Style` per operation.
  void drawRect(double x, double y, double width, double height);

  double getHeight();

  double getWidth();

  void setFont(Font font);

  void setFontSize(double size);

  void setStrokeWidth(double size);

  /// Fills a pie sector (`useCenter = true`, so the centre point belongs to the
  /// shape), not a stroked ring.
  ///
  /// Angles are degrees, measured the way `java.awt.Graphics2D.fillArc` does:
  /// `startAngle = 0` is the 3 o'clock direction, `startAngle = 90` is 12
  /// o'clock, and a *positive* [swipeAngle] sweeps counterclockwise while a
  /// negative one sweeps clockwise. AndroidCanvas negates both angles because
  /// android.graphics measures the other way around.
  void fillArc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double swipeAngle,
  );

  void fillCircle(double centerX, double centerY, double radius);

  void setTextAlign(TextAlign align);

  Image toImage();

  /// The advance width of [text] in logical units, under the current font and
  /// font size.
  double measureText(String text);

  /// Fills entire canvas with the current color.
  void fill() {
    fillRect(0.0, 0.0, getWidth(), getHeight());
  }

  /// The canary golden. Every backend renders this and is compared against
  /// views/CanvasTest.png, so the call sequence must not drift.
  void drawTestImage() {
    // Draw transparent background
    setColor(const Color(0.1, 0.1, 0.1, 0.5));
    fillRect(0.0, 0.0, 500.0, 400.0);

    // Draw center rectangle
    setColor(const Color.fromRgb(0x606060));
    setStrokeWidth(25.0);
    drawRect(100.0, 100.0, 300.0, 200.0);

    // Draw squares, circles and arcs
    setColor(Color.YELLOW);
    setStrokeWidth(1.0);
    drawRect(0.0, 0.0, 100.0, 100.0);
    fillCircle(50.0, 50.0, 30.0);
    drawRect(0.0, 100.0, 100.0, 100.0);
    fillArc(50.0, 150.0, 30.0, 90.0, 135.0);
    drawRect(0.0, 200.0, 100.0, 100.0);
    fillArc(50.0, 250.0, 30.0, 90.0, -135.0);
    drawRect(0.0, 300.0, 100.0, 100.0);
    fillArc(50.0, 350.0, 30.0, 45.0, 90.0);

    // Draw two red crossing lines
    setColor(Color.RED);
    setStrokeWidth(2.0);
    drawLine(0.0, 0.0, 500.0, 400.0);
    drawLine(500.0, 0.0, 0.0, 400.0);

    // Draw text
    setFont(Font.bold);
    setFontSize(50.0);
    setColor(Color.GREEN);
    setTextAlign(TextAlign.center);
    drawText('HELLO', 250.0, 100.0);
    setTextAlign(TextAlign.right);
    drawText('HELLO', 250.0, 150.0);
    setTextAlign(TextAlign.left);
    drawText('HELLO', 250.0, 200.0);

    // Draw FontAwesome icon
    setFont(Font.fontAwesome);
    drawText(FontAwesome.check, 250.0, 300.0);
  }
}
