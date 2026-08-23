/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/ScrollableChart.kt
/// and uhabits-android/src/main/java/org/isoron/platform/gui/AndroidDataView.kt.
///
/// Android has two independent horizontal scrollers, one for each generation of
/// chart: `ScrollableChart` is the base class of the legacy Paint-based views
/// (Score, Frequency, the list header), and `AndroidDataView` hosts the core
/// `Canvas` charts (History, Bar). They differ only in bookkeeping — a bucket
/// size that is configured versus one read off the view, an upper bound versus
/// none — so a single widget covers both.
///
/// What either one does is quantise. A horizontal drag moves a scroller
/// position in pixels; the position divided by one data column, floored, is
/// [ScrollableChart.onDataOffsetChanged]'s `dataOffset`: the number of whole
/// columns the chart has been scrolled *into the past*. The chart itself never
/// sees a pixel — it is redrawn at a new column index, which is why nothing
/// ever half-scrolls.
///
/// Two Android warts are reproduced rather than smoothed over, because they are
/// what the offset arithmetic actually does:
///
///  * the scroller position may go negative. Dragging towards the future from
///    column 0 does nothing visible (`max(0, …)` clamps the offset), but the
///    distance is remembered and has to be dragged back before the chart moves
///    again.
///  * the position is *not* clamped at the top after
///    [ScrollableChart.maxDataOffset] shrinks; only the delta of a new drag is
///    (`dx = min(dx, maxX - currX)`), so a chart that was scrolled past the new
///    limit walks backwards first.
///
/// Known deviations, all of them Android plumbing with no Flutter counterpart:
///
///  * the fling runs on a [FrictionSimulation] rather than
///    `android.widget.Scroller`. The velocity halving, the direction and the
///    `0 .. maxX` bounds are kept; the exact deceleration curve is Flutter's.
///  * the scroller position is a `double` of logical pixels, not an `int` of
///    device pixels, so neither the per-event delta nor the bucket size is
///    truncated on the way in, and no density conversion happens on the way out
///    (`AndroidDataView` divides by `canvas.innerDensity`; a Flutter logical
///    pixel already is a density-independent one).
///  * `onSaveInstanceState`/`onRestoreInstanceState` have no equivalent: the
///    [State] outlives every rebuild, and Flutter has no configuration-change
///    teardown to restore from.
library;

import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../core_view.dart';

/// Builds the scrolled subtree from the current offset.
///
/// The alternative to handing [ScrollableChart] a [core.DataView] directly: a
/// show-habit card computes its own chart and already takes a `dataOffset`, so
/// the offset is fed to it rather than written into a view.
typedef ScrollableChartBuilder = Widget Function(
  BuildContext context,
  int dataOffset,
);

/// A handle on a [ScrollableChart]'s scroll position.
///
/// Kotlin keeps `dataOffset` on the chart itself and hands out `reset()` /
/// `resetDataOffset()`; the card calls them on the view it inflated
/// (`binding.chart.resetDataOffset()`). This is that reference.
///
/// Nothing here needs disposing: the controller holds no listeners, only a
/// pointer to the mounted [State] (or none, before the chart is built).
class ScrollableChartController {
  _ScrollableChartState? _state;

  /// Columns scrolled into the past, starting at 0
  /// (`charts-canvas-theming.scrollable-chart#1`).
  int get dataOffset => _state?._dataOffset ?? 0;

  /// `maxDataOffset * scrollerBucketSize`, the far end of the scrollable range
  /// (`charts-canvas-theming.scrollable-chart#3`).
  double get maxX => _state?._maxX ?? 0.0;

  /// Snaps back to the newest data, the way `ScrollableChart.reset()` and
  /// `AndroidDataView.resetDataOffset()` do — including cancelling a fling in
  /// flight, which `scroller.finalX = 0` finishes.
  void reset() => _state?._reset();

  void _attach(_ScrollableChartState state) => _state = state;

  void _detach(_ScrollableChartState state) {
    if (_state == state) _state = null;
  }
}

/// Hosts a horizontally scrollable chart.
///
/// Either [view] or [builder] is given, never both. With a [view] the widget
/// paints it through a [CoreView] and writes the current offset into
/// [core.DataView.dataOffset] before each frame — the `AndroidDataView`
/// arrangement. With a [builder] the offset is passed to the subtree instead,
/// which is what the show-habit cards need: they build their own chart and take
/// a `dataOffset` parameter.
class ScrollableChart extends StatefulWidget {
  ScrollableChart({
    super.key,
    this.view,
    this.builder,
    this.bucketSize,
    this.controller,
    this.onDataOffsetChanged,
    this.maxDataOffset = defaultMaxDataOffset,
    this.direction = defaultDirection,
    this.onTap,
    this.onLongPress,
  }) : assert(
          (view == null) != (builder == null),
          'ScrollableChart takes exactly one of view and builder',
        ) {
    // Kotlin: `require(!(direction != 1 && direction != -1))`, an
    // IllegalArgumentException at the call site — not an assertion that a
    // release build would drop.
    if (direction != 1 && direction != -1) {
      throw ArgumentError.value(
        direction,
        'direction',
        'The scroll direction must be 1 or -1',
      );
    }
  }

  /// `private var maxDataOffset = 12 * 200`.
  static const int defaultMaxDataOffset = 12 * 200;

  /// `private var direction = 1`.
  static const int defaultDirection = 1;

  /// `private var scrollerBucketSize = 1`. Only reached when there is no [view]
  /// to measure and no explicit [bucketSize]; every real chart has one or the
  /// other.
  static const double defaultBucketSize = 1.0;

  /// Half the fling velocity reaches the scroller: `direction * velocityX / 2`.
  static const double flingVelocityFactor = 0.5;

  /// The drag coefficient of the fling, Flutter's own scrolling default.
  static const double flingFriction = 0.135;

  /// The chart to paint and scroll, if the offset lives on a view.
  final core.DataView? view;

  /// The subtree to rebuild at each new offset, if it does not.
  final ScrollableChartBuilder? builder;

  /// One data column, in logical pixels. Defaults to the [view]'s
  /// [core.DataView.dataColumnWidth], read at gesture time because a chart only
  /// knows its column width once it has been laid out.
  final double? bucketSize;

  final ScrollableChartController? controller;

  /// `ScrollController.onDataOffsetChanged`: called with each new offset, and
  /// only when it actually changed.
  final ValueChanged<int>? onDataOffsetChanged;

  /// The oldest reachable column.
  final int maxDataOffset;

  /// 1 or -1. With 1 a rightward drag walks backwards in time, the way both
  /// Android scrollers behave by default; -1 mirrors it, which is what the
  /// habit list header asks for.
  final int direction;

  /// Notified after a tap has been dispatched to the [view].
  final VoidCallback? onTap;

  /// Notified after a long press has been dispatched to the [view].
  final VoidCallback? onLongPress;

  @override
  State<ScrollableChart> createState() => _ScrollableChartState();
}

class _ScrollableChartState extends State<ScrollableChart>
    with SingleTickerProviderStateMixin {
  /// A fling that has slowed to 20 logical pixels a second is over. Flutter's
  /// own scroll views use the same order of magnitude; the physics default
  /// (1e-3 px/s) would keep the ticker alive for seconds after the movement
  /// stopped being visible.
  static const Tolerance _flingTolerance =
      Tolerance(distance: 0.5, velocity: 20.0);

  /// `scroller.currX`, in logical pixels. May be negative — see the library
  /// comment.
  double _scrollX = 0.0;

  /// `ScrollableChart.dataOffset` / `DataView.dataOffset`.
  int _dataOffset = 0;

  late final AnimationController _fling;

  @override
  void initState() {
    super.initState();
    _fling = AnimationController.unbounded(vsync: this)
      ..addListener(_onFlingTick);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(ScrollableChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    // `setMaxDataOffset`: the offset is clamped down and the controller told,
    // which is what happens when the card gets wider and cannot reach as far
    // back as it did. The report waits for the end of the frame, since the
    // host is mid-build.
    if (widget.maxDataOffset != oldWidget.maxDataOffset &&
        _dataOffset > widget.maxDataOffset) {
      _dataOffset = widget.maxDataOffset;
      final clamped = _dataOffset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDataOffsetChanged?.call(clamped);
      });
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _fling.dispose();
    super.dispose();
  }

  /// `scrollerBucketSize`. Re-read on every event: `HistoryChart` computes its
  /// square size while drawing, so the column width of a chart that has never
  /// been painted is not the one it will scroll by.
  double get _bucketSize =>
      widget.bucketSize ??
      widget.view?.dataColumnWidth ??
      ScrollableChart.defaultBucketSize;

  /// `private val maxX get() = maxDataOffset * scrollerBucketSize`.
  double get _maxX => widget.maxDataOffset * _bucketSize;

  void _onDragStart(DragStartDetails details) => _fling.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    if (_bucketSize <= 0.0) return;
    // Kotlin reads `dx *= -direction` because Android's onScroll hands out the
    // distance the content moved, the negative of the finger's; Flutter's
    // delta is the finger's, so the negation cancels out.
    var dx = details.delta.dx * widget.direction;
    dx = math.min(dx, _maxX - _scrollX);
    _scrollX += dx;
    _updateDataOffset();
  }

  void _onDragEnd(DragEndDetails details) {
    if (_bucketSize <= 0.0) return;
    final velocity = (details.primaryVelocity ?? 0.0) *
        widget.direction *
        ScrollableChart.flingVelocityFactor;
    if (velocity == 0.0) return;
    _fling.animateWith(
      FrictionSimulation(
        ScrollableChart.flingFriction,
        _scrollX,
        velocity,
        tolerance: _flingTolerance,
      ),
    );
  }

  /// One animator tick: advance the scroller, recompute the offset, and stop
  /// once the fling has run out of range.
  void _onFlingTick() {
    if (_bucketSize <= 0.0) {
      _fling.stop();
      return;
    }
    final x = _fling.value;
    final clamped = x.clamp(0.0, _maxX);
    _scrollX = clamped;
    // `scroller.fling(…, 0, maxX, 0, 0)` bounds the trajectory, and the
    // scroller reports itself finished as soon as it reaches an edge.
    if (clamped != x) _fling.stop();
    _updateDataOffset();
  }

  /// `reset()`: `scroller.finalX = 0`, then recompute. A duration-0 scroller
  /// jumps straight to its final position, so the remainder goes too.
  void _reset() {
    _fling.stop();
    _scrollX = 0.0;
    _updateDataOffset();
  }

  /// `updateDataOffset()`.
  void _updateDataOffset() {
    final bucket = _bucketSize;
    if (bucket <= 0.0) return;
    var newDataOffset = (_scrollX / bucket).truncate();
    newDataOffset = math.max(0, newDataOffset);
    newDataOffset = math.min(widget.maxDataOffset, newDataOffset);
    if (newDataOffset != _dataOffset) {
      setState(() => _dataOffset = newDataOffset);
      widget.onDataOffsetChanged?.call(newDataOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final Widget child;
    if (view != null) {
      view.dataOffset = _dataOffset;
      child = CoreView(
        view: view,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
      );
    } else {
      child = widget.builder!(context, _dataOffset);
    }

    return GestureDetector(
      // The horizontal recogniser settles the arena against the vertically
      // scrolling page the card sits in, which is what the Android views ask
      // for with `requestDisallowInterceptTouchEvent(true)`.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: child,
    );
  }
}
