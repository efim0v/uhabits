import 'dart:math';

import '../../gui/canvas.dart';
import '../../gui/color.dart';
import '../../gui/theme.dart';
import '../../gui/view.dart';
import '../../io/printf.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/Ring.kt.
///
/// A progress ring: a full disc in the low-contrast colour, a pie sector of it
/// in the habit colour, and a smaller disc punched out of the middle. Nothing
/// here is stateful — every constructor argument is final and `draw` reads
/// only them plus the canvas size — so the same instance can be painted onto
/// any number of canvases.
///
/// The shipping Android widget (`RingView`) is a different, richer
/// implementation: it quantises the percentage, paints the remainder in a
/// separate inactive colour, can stroke its text and can switch to the
/// FontAwesome typeface. This class is the core one used by the shared views.
class Ring extends View {
  Ring({
    required this.color,
    required this.percentage,
    required this.thickness,
    required this.radius,
    required this.theme,
    this.label = false,
  });

  final Color color;
  final double percentage;
  final double thickness;
  final double radius;
  final Theme theme;
  final bool label;

  @override
  void draw(Canvas canvas) {
    final width = canvas.getWidth();
    final height = canvas.getHeight();

    // Kept verbatim from Ring.kt, parenthesisation included. Note that the
    // min(360.0, ...) clamp is applied to the *fraction*, not to the degrees:
    // it only bites at percentages above 360, and a percentage of, say, 2
    // still sweeps two whole turns. max(0.0, ...) is the clamp that matters in
    // practice, since scores never exceed 1 but callers do pass negatives.
    final angle = 360.0 * max(0.0, min(360.0, percentage));

    canvas.setColor(theme.lowContrastTextColor);
    canvas.fillCircle(width / 2, height / 2, radius);

    // Angles follow the Canvas contract: 90 is the 12 o'clock direction and a
    // negative sweep runs clockwise, so progress fills clockwise from the top.
    canvas.setColor(color);
    canvas.fillArc(width / 2, height / 2, radius, 90.0, -angle);

    // The hole is *overpainted*, not cleared. Under WidgetTheme, whose
    // cardBackgroundColor is fully transparent, this fill paints nothing at
    // all under normal source-over compositing and the widget shows a filled
    // pie rather than a ring. Upstream behaviour, deliberately preserved.
    canvas.setColor(theme.cardBackgroundColor);
    canvas.fillCircle(width / 2, height / 2, radius - thickness);

    if (label) {
      // The text is centred at the canvas centre and relies on the backend's
      // default CENTER alignment — Ring never calls setTextAlign. The label
      // formats the raw percentage, so a negative one prints a negative
      // number even though the arc above was clamped to nothing.
      canvas.setColor(color);
      canvas.setFontSize(radius * 0.4);
      canvas.drawText(format('%.0f%%', percentage * 100), width / 2, height / 2);
    }
  }
}

/// The notes-indicator radius, in the raw units of the canvas being drawn on.
///
/// Upstream this is the bare literal `8f` handed to `android.graphics.Canvas`,
/// whose units are *device pixels*, so the dot does not scale with display
/// density: it is visibly smaller on a dense screen than on a sparse one.
/// Preserved as a bare constant here rather than being turned into a
/// density-independent size, because the Android goldens were accepted with
/// it.
const double notesIndicatorRadius = 8.0;

/// Port of `fun View.drawNotesIndicator(...)` from
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt.
///
/// Draws the little dot that marks an entry carrying a note, inset from the
/// top-right corner of the view by 0.8 em both ways. Shared by
/// CheckmarkButtonView and NumberButtonView, each of which passes its own
/// cached `em` (the width of "m" in its number/glyph paint) as [size].
///
/// Two deliberate differences from the Kotlin extension, both forced by the
/// core [Canvas] API:
///
///  * the `pNotesIndicator: Paint` argument is gone — [Canvas] carries a single
///    sticky colour instead of per-shape paints, so the colour is set on the
///    canvas. That also means this helper leaves the canvas colour changed,
///    whereas the Android version tinted a private Paint and left the view's
///    text paint alone. Harmless at both call sites, where the dot is the last
///    thing drawn;
///  * the receiver `View.width` becomes `canvas.getWidth()`, the width of the
///    surface being painted, which is what the Android views' canvas covers.
void drawNotesIndicator(
  Canvas canvas,
  Color color,
  double size,
  String notes,
) {
  if (notes.trim().isEmpty) return;

  final cy = 0.8 * size;
  canvas.setColor(color);
  canvas.fillCircle(canvas.getWidth() - cy, cy, notesIndicatorRadius);
}
