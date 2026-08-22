import 'canvas.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/platform/gui/View.kt.
///
/// A [View] is a chart that knows how to paint itself onto a [Canvas] and,
/// optionally, how to react to a tap. Hosts (AndroidView / the Flutter widget
/// that replaces it) own the surface and the gesture detector; the view owns
/// the geometry.
///
/// Click coordinates arrive in the same logical unit system as [draw], i.e.
/// device pixels already divided by the display density — see
/// `AndroidView.handleClick`.
abstract class View {
  void draw(Canvas canvas);

  void onClick(double x, double y) {}

  void onLongClick(double x, double y) {}
}

/// A [View] whose contents scroll horizontally in whole data columns.
///
/// [dataOffset] counts columns scrolled back into the past: 0 always means "the
/// newest column is flush against the right edge of the chart", and larger
/// values scroll into older data. The host never produces a negative value —
/// `AndroidDataView.updateDataOffset` clamps the scroller position with
/// `max(0, ...)` before assigning it.
abstract class DataView extends View {
  abstract int dataOffset;

  /// The width of one data column, in logical units. Read-only: the host reads
  /// it to translate a scroll distance into a [dataOffset].
  double get dataColumnWidth;
}
