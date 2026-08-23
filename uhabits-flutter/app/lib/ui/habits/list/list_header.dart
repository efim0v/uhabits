import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:intl/intl.dart' as intl;
// The core view and the preference model live outside uhabits_core's public
// library; they are imported by path until the package exports lib/src/ui/views
// and lib/src/preferences.
// ignore: implementation_imports
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/views/habit_list_header.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../common/scrollable_chart.dart';
import '../../core_view.dart';

/// The date strip above the habit list.
///
/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HeaderView.kt
/// (goldens: androidTest/assets/views/habits/list/HeaderView/{render,
/// render_reverse}.png), drawn by the already-ported core view
/// `HabitListHeader`, which paints the same background, hairline and two-line
/// date columns.
///
/// The widget owns no data. [buttonCount] is the number of visible date
/// columns, computed by the screen from its own width; [dataOffset] counts
/// whole columns scrolled into the past and is *not* held here: a horizontal
/// drag only reports the new value through [onDataOffsetChanged], and the
/// header does not move until the screen rebuilds it with that value. That is
/// what keeps the strip in lockstep with the entry buttons on every card, the
/// way `ListHabitsRootView` wires `HeaderView`'s ScrollController into
/// `HabitCardListView.dataOffset`.
///
/// Column direction follows the checkmark-sequence preference:
/// [isCheckmarkSequenceReversed] `false` puts today leftmost and walks
/// backwards to the right (`list-habits.header-dates#3`), `true` mirrors the
/// strip so today is rightmost (`#4`).
class ListHeader extends StatefulWidget {
  const ListHeader({
    required this.buttonCount,
    this.dataOffset = 0,
    this.onDataOffsetChanged,
    this.preferences,
    this.isCheckmarkSequenceReversed = false,
    this.maxDataOffset,
    this.today,
    this.theme,
    this.dateFormatter,
    this.restorationId,
    super.key,
  });

  /// Upstream `ListHabitsRootView.MAX_CHECKMARK_COUNT`: the list never reaches
  /// further back than 60 columns.
  static const int maxCheckmarkCount = 60;

  /// One date column, `R.dimen.checkmarkWidth`. Every [core.Theme] declares
  /// `checkmarkButtonSize` as a plain final field on the base class, so the
  /// value is the same under every variant — which is what lets the scroller
  /// quantise without a BuildContext, and lets the screen size its columns
  /// with the same number the entry buttons use.
  static final double columnWidth = core.LightTheme().checkmarkButtonSize;

  /// How many date columns to draw, right-aligned inside the strip.
  final int buttonCount;

  /// Columns scrolled into the past. 0 means the newest column is today.
  final int dataOffset;

  /// Called with the new [dataOffset] whenever a drag crosses a column
  /// boundary — and only then (`list-habits.header-scrolling#7`).
  final ValueChanged<int>? onDataOffsetChanged;

  /// `HeaderView(context, prefs, midnightTimer)`'s `prefs`.
  ///
  /// `HeaderView` is a `Preferences.Listener` in its own right: it registers in
  /// `onAttachedToWindow`, and `onCheckmarkSequenceChanged()` calls
  /// `updateScrollDirection()` and `postInvalidate()`. That is what keeps the
  /// strip in step with `ButtonPanelView`, which re-inflates its buttons on the
  /// very same notification — the label over a button has to go on being that
  /// button's date, and neither half may wait for an unrelated rebuild
  /// (`audit3.flipping-reverse-order-of-days-leaves#1`).
  ///
  /// When it is null the header falls back to [isCheckmarkSequenceReversed],
  /// which is the value a caller with no preferences to hand passes in.
  final core.Preferences? preferences;

  /// `Preferences.isCheckmarkSequenceReversed`, for a caller that has no
  /// [preferences] to subscribe to — a golden test, or a preview. Ignored when
  /// [preferences] is given: the preference itself is then the only source.
  final bool isCheckmarkSequenceReversed;

  /// Defaults to `max(60 - buttonCount, 0)`, the value
  /// `ListHabitsRootView.onSizeChanged` pushes into the header
  /// (`list-habits.header-scrolling#3`).
  final int? maxDataOffset;

  /// Defaults to the process-global [core.getToday]. The screen passes an
  /// explicit date when a midnight tick should repaint the strip
  /// (`list-habits.header-dates#8`).
  final core.LocalDate? today;

  /// Defaults to [core.LightTheme] or [core.DarkTheme], following the
  /// surrounding Flutter brightness.
  final core.Theme? theme;

  /// Defaults to an [IntlLocalDateFormatter] for the ambient locale.
  final core.LocalDateFormatter? dateFormatter;

  /// `ScrollableChart.onSaveInstanceState` / `onRestoreInstanceState`: the
  /// scroller position and the reported column survive a restart when the
  /// header is given a restoration id (`list-habits.header-scrolling#8`).
  final String? restorationId;

  int get effectiveMaxDataOffset =>
      maxDataOffset ?? math.max(maxCheckmarkCount - buttonCount, 0);

  /// The column direction actually in force: the preference when there is one
  /// to read, the constructor argument otherwise.
  bool get isReversed =>
      preferences?.isCheckmarkSequenceReversed ?? isCheckmarkSequenceReversed;

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader>
    with SingleTickerProviderStateMixin, RestorationMixin {
  /// The scroller's bucket size (`list-habits.header-scrolling#2`).
  static final double _columnWidth = ListHeader.columnWidth;

  /// A fling that has slowed to 20 logical pixels a second is over — the same
  /// tolerance the other scroller in this app uses.
  static const Tolerance _flingTolerance =
      Tolerance(distance: 0.5, velocity: 20.0);

  /// The scroller position, in pixels. Only the sub-column remainder is real
  /// state: the whole-column part is [_reportedOffset].
  ///
  /// `putInt("x", scroller.currX)` / `getInt("x")`
  /// (`list-habits.header-scrolling#8`). The scroller's `y` is always 0 here,
  /// as it is upstream: the header never scrolls vertically.
  final RestorableDouble _scrollXState = RestorableDouble(0.0);

  /// The column the scroller believes it is on — `ScrollableChart.dataOffset`.
  /// It is what a new position is compared against before the callback fires,
  /// so a parent that ignores [ListHeader.onDataOffsetChanged] is told about
  /// each column once rather than on every touch event.
  final RestorableInt _reportedOffsetState = RestorableInt(0);

  late final AnimationController _fling;

  double get _scrollX => _scrollXState.value;

  set _scrollX(double value) => _scrollXState.value = value;

  int get _reportedOffset => _reportedOffsetState.value;

  set _reportedOffset(int value) => _reportedOffsetState.value = value;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    // The properties can only be written once they are registered, which is
    // why the initial seeding lives here rather than in initState.
    registerForRestoration(_scrollXState, 'x');
    registerForRestoration(_reportedOffsetState, 'dataOffset');
    if (initialRestore && _reportedOffset == 0 && _scrollX == 0.0) {
      // Nothing came back from the bucket: start where the parent says.
      _reportedOffset = widget.dataOffset;
      _scrollX = widget.dataOffset * _columnWidth;
      return;
    }
    // A restored scroller position has to reach the parent, which keeps its
    // own copy of the offset.
    final restored = _reportedOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.dataOffset != restored) {
        widget.onDataOffsetChanged?.call(restored);
      }
    });
  }

  /// `HeaderView` itself, as a `Preferences.Listener`.
  late final _HeaderPreferencesListener _preferencesListener;

  @override
  void initState() {
    super.initState();
    _fling = AnimationController.unbounded(vsync: this)
      ..addListener(_onFlingTick);
    // `HeaderView.onAttachedToWindow`: `updateScrollDirection()` — which the
    // next build does — followed by `prefs.addListener(this)`.
    _preferencesListener =
        _HeaderPreferencesListener(_onCheckmarkSequenceChanged);
    widget.preferences?.addListener(_preferencesListener);
  }

  @override
  void dispose() {
    // `HeaderView.onDetachedFromWindow`: `prefs.removeListener(this)`.
    widget.preferences?.removeListener(_preferencesListener);
    _fling.dispose();
    _scrollXState.dispose();
    _reportedOffsetState.dispose();
    super.dispose();
  }

  /// `HeaderView.onCheckmarkSequenceChanged()`:
  ///
  /// ```kotlin
  /// override fun onCheckmarkSequenceChanged() {
  ///     updateScrollDirection()
  ///     postInvalidate()
  /// }
  /// ```
  ///
  /// Both halves are this rebuild: the direction is recomputed in [build] and
  /// the strip is redrawn from it.
  void _onCheckmarkSequenceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ListHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.preferences, widget.preferences)) {
      oldWidget.preferences?.removeListener(_preferencesListener);
      widget.preferences?.addListener(_preferencesListener);
    }
    // Follow the offset the parent decided on. When it accepted the value this
    // drag reported, the remainder is kept so a slow drag stays continuous;
    // when it set something else (a reset, or a clamp after the column count
    // changed) the scroller snaps to it.
    final maxOffset = widget.effectiveMaxDataOffset;
    if (widget.dataOffset != oldWidget.dataOffset) {
      _reportedOffset = widget.dataOffset;
    }
    final target = widget.dataOffset.clamp(0, maxOffset);
    if (_offsetOf(_scrollX) != target) {
      _scrollX = target * _columnWidth;
    }
    if (target != widget.dataOffset) {
      // `ScrollableChart.setMaxDataOffset` clamps the offset down and notifies
      // its controller — which happens here when the screen gets wider and
      // fits more columns. The parent is mid-build, so the report waits for
      // the end of the frame.
      _reportedOffset = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.dataOffset != target) {
          widget.onDataOffsetChanged?.call(target);
        }
      });
    }
  }

  /// `HeaderView.updateScrollDirection`: it starts at -1, is multiplied by -1
  /// when the checkmark sequence is reversed, and again when the layout is
  /// right-to-left (`list-habits.header-scrolling#4`,
  /// `list-habits.header-dates#11`).
  int _scrollDirectionOf(bool isRtl) {
    var direction = -1;
    if (widget.isReversed) direction *= -1;
    if (isRtl) direction *= -1;
    return direction;
  }

  /// The direction the last build resolved, so a gesture that arrives between
  /// two builds uses the same one the strip was drawn with.
  int _scrollDirection = -1;

  int _offsetOf(double scrollX) => (scrollX / _columnWidth).floor();

  /// `private val maxX get() = maxDataOffset * scrollerBucketSize`.
  double get _maxX => widget.effectiveMaxDataOffset * _columnWidth;

  void _onHorizontalDragStart(DragStartDetails details) => _fling.stop();

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Unlike android.widget.Scroller, which lets currX run negative and makes
    // you drag the debt back, the position is clamped to the scrollable range.
    _scrollX = (_scrollX + details.delta.dx * _scrollDirection)
        .clamp(0.0, _maxX);
    _updateDataOffset();
  }

  /// `onFling`: `scroller.fling(currX, currY, direction * velocityX / 2, 0, 0,
  /// maxX, 0, 0)`, animated for as long as the scroller says
  /// (`list-habits.header-scrolling#6`).
  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = (details.primaryVelocity ?? 0.0) *
        _scrollDirection *
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

  void _onFlingTick() {
    final x = _fling.value;
    final clamped = x.clamp(0.0, _maxX);
    _scrollX = clamped;
    // `scroller.fling(…, 0, maxX, 0, 0)` bounds the trajectory, and the
    // scroller reports itself finished as soon as it reaches an edge.
    if (clamped != x) _fling.stop();
    _updateDataOffset();
  }

  /// `updateDataOffset()`: the callback fires only when the quantised column
  /// actually moved (`list-habits.header-scrolling#7`).
  void _updateDataOffset() {
    final newOffset = _offsetOf(_scrollX).clamp(0, widget.effectiveMaxDataOffset);
    if (newOffset != _reportedOffset) {
      _reportedOffset = newOffset;
      widget.onDataOffsetChanged?.call(newOffset);
    }
  }

  /// `HeaderView.Drawer.draw`: the reversed order flips the columns inside the
  /// checkmark strip, and an RTL layout then mirrors every rect about the
  /// canvas width (`list-habits.header-dates#4`, `#5`).
  core.View _decorate(
    core.View header,
    core.Theme theme, {
    required bool isRtl,
  }) {
    var view = header;
    if (widget.isReversed) {
      view = MirroredView(
        view,
        stripWidth: widget.buttonCount * theme.checkmarkButtonSize,
      );
    }
    if (isRtl) view = MirroredView.aboutCanvasWidth(view);
    return view;
  }

  core.Theme _themeOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? core.DarkTheme()
          : core.LightTheme();

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? _themeOf(context);
    final today = widget.today ?? core.getToday();
    final formatter = widget.dateFormatter ?? IntlLocalDateFormatter.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    _scrollDirection = _scrollDirectionOf(isRtl);

    // HabitListHeader's `today` is the newest column, so scrolling back is a
    // subtraction: column i then shows today.minus(i + dataOffset)
    // (`list-habits.header-dates#2`).
    final core.View header = HeaderDatesView(
      today.minus(widget.dataOffset),
      widget.buttonCount,
      theme,
      formatter,
    );

    return GestureDetector(
      // The horizontal recogniser also settles the arena against a vertically
      // scrolling list, which is what HeaderView asks for with
      // requestDisallowInterceptTouchEvent.
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: SizedBox(
        // `HeaderView.onMeasure`: the incoming width, and exactly 48dp high.
        height: theme.checkmarkButtonSize,
        width: double.infinity,
        child: CoreView(
          view: _decorate(header, theme, isRtl: isRtl),
        ),
      ),
    );
  }
}

/// `Preferences.Listener`, narrowed to the one callback `HeaderView`
/// overrides.
class _HeaderPreferencesListener extends core.PreferencesListener {
  _HeaderPreferencesListener(this._onChanged);

  final VoidCallback _onChanged;

  @override
  void onCheckmarkSequenceChanged() => _onChanged();
}

/// The strip itself: the core [HabitListHeader]'s drawing with
/// `HeaderView.Drawer`'s vertical placement.
///
/// The two views paint the same thing and differ in exactly one respect. The
/// KMP header stacks its two lines `theme.smallTextSize * 0.6` either side of
/// the centre; `HeaderView.Drawer` — the one the shipping Android list screen
/// puts on screen, and the one the goldens under
/// androidTest/assets/views/habits/list/HeaderView/ were captured from —
/// stacks them at `rect.centerY() - 0.25 * em` and `rect.centerY() + 1.25 *
/// em`, where `em = paint.measureText("m")` under the header's own bold 10sp
/// paint (`list-habits.header-dates#7`, `#12`).
///
/// That is not a rescaling of the same layout: `em` is an advance *width*, so
/// the offsets track the font's proportions rather than its nominal size, and
/// the pair is not symmetric about the centre — the weekday name sits a
/// quarter of an em above it and the day number a full em and a quarter below.
///
/// Everything else is [HabitListHeader] verbatim, the hairline along the bottom
/// edge included. `HeaderView` has no hairline of its own — it separates itself
/// from the list with `elevation = dp(2f)` instead — and the port keeps the
/// drawn line because a Flutter header casts no shadow onto the list.
class HeaderDatesView extends core.View {
  HeaderDatesView(this._today, this._nButtons, this._theme, this._fmt);

  final core.LocalDate _today;
  final int _nButtons;
  final core.Theme _theme;
  final core.LocalDateFormatter _fmt;

  @override
  void draw(core.Canvas canvas) {
    final width = canvas.getWidth();
    final height = canvas.getHeight();
    final buttonSize = _theme.checkmarkButtonSize;
    canvas.setColor(_theme.headerBackgroundColor);
    canvas.fillRect(0.0, 0.0, width, height);

    canvas.setColor(_theme.headerBorderColor);
    canvas.setStrokeWidth(0.5);
    canvas.drawLine(0.0, height - 0.5, width, height - 0.5);

    // `paint = TextPaint().apply { textSize = dim(R.dimen.tinyTextSize);
    // textAlign = CENTER; typeface = Typeface.DEFAULT_BOLD; color =
    // sres.getColor(R.attr.contrast60) }` (`list-habits.header-dates#12`).
    canvas.setColor(_theme.headerTextColor);
    canvas.setFont(core.Font.bold);
    canvas.setFontSize(_theme.smallTextSize);

    // `val em = paint.measureText("m")`, hoisted out of the loop exactly as
    // the Drawer hoists it.
    final em = canvas.measureText('m');

    for (var index = 0; index < _nButtons; index++) {
      final date = _today.minus(_nButtons - index - 1);
      final name = _fmt.shortWeekdayName(date).toUpperCase();
      final number = date.day.toString();

      final x = width - (index + 1) * buttonSize + buttonSize / 2;
      final centerY = height / 2;
      // `val y1 = rect.centerY() - 0.25 * em`
      // `val y2 = rect.centerY() + 1.25 * em`
      canvas.drawText(name, x, centerY - 0.25 * em);
      canvas.drawText(number, x, centerY + 1.25 * em);
    }
  }
}

/// A [core.View] whose date columns are drawn flipped about the vertical
/// centre line of the *checkmark strip* — the right-aligned band of
/// [stripWidth] pixels the habit rows fill with their entry buttons.
///
/// `HabitListHeader` always puts today leftmost inside that band.
/// `HeaderView.Drawer` reverses the order **within the same band**: both
/// branches start from `canvas.width` and offset left, `(index - buttonCount) *
/// checkmarkWidth` normally and `-(index + 1) * checkmarkWidth` when reversed
/// (`settings.preferences.checkmark-reverse-order#7`,
/// `list-habits.header-dates#3`, `#4`). That is the same thing
/// `ButtonPanelView` does by adding its buttons in reverse order, which is why
/// the strip has to stay put: the dates line up with the buttons under it.
///
/// Mirroring about the canvas instead of about the band would slide the whole
/// strip to the left edge of a full-width header, leaving the dates floating
/// over the habit-name column — so the axis here is `2 * width - stripWidth`,
/// and no second copy of the drawing code is needed.
class MirroredView extends core.View {
  MirroredView(this._inner, {required double this.stripWidth});

  /// `if (isRTL()) rect.set(canvas.width - rect.right, …, canvas.width -
  /// rect.left, …)`: the reflection axis is the canvas itself, not the strip
  /// (`list-habits.header-dates#5`).
  MirroredView.aboutCanvasWidth(this._inner) : stripWidth = null;

  final core.View _inner;

  /// `buttonCount * R.dimen.checkmarkWidth`, or null to mirror about the whole
  /// canvas.
  final double? stripWidth;

  @override
  void draw(core.Canvas canvas) =>
      _inner.draw(_MirrorCanvas(canvas, stripWidth));

  /// Coordinates are forwarded unmirrored: the mirrored views have no
  /// position-dependent hit testing (the header ignores taps entirely).
  @override
  void onClick(double x, double y) => _inner.onClick(x, y);

  @override
  void onLongClick(double x, double y) => _inner.onLongClick(x, y);
}

/// Delegates every drawing call to [_target], mirroring the per-column
/// primitives about the checkmark strip. Text alignment is mirrored with them,
/// so a right-aligned label lands where its mirror image belongs.
///
/// Rectangles and lines are forwarded verbatim: in this view they are the
/// header background and the hairline along its bottom edge, both of which span
/// the whole width and must not travel with the strip.
class _MirrorCanvas extends core.Canvas {
  _MirrorCanvas(this._target, this._stripWidth);

  final core.Canvas _target;

  final double? _stripWidth;

  /// Reflection about the band `[width - stripWidth, width)`, or about the
  /// canvas width when there is no band.
  double _mirrorX(double x) =>
      2 * _target.getWidth() - (_stripWidth ?? _target.getWidth()) - x;

  @override
  double getWidth() => _target.getWidth();

  @override
  double getHeight() => _target.getHeight();

  @override
  void setColor(core.Color color) => _target.setColor(color);

  @override
  void setFont(core.Font font) => _target.setFont(font);

  @override
  void setFontSize(double size) => _target.setFontSize(size);

  @override
  void setStrokeWidth(double size) => _target.setStrokeWidth(size);

  @override
  void setTextAlign(core.TextAlign align) => _target.setTextAlign(
        switch (align) {
          core.TextAlign.left => core.TextAlign.right,
          core.TextAlign.right => core.TextAlign.left,
          core.TextAlign.center => core.TextAlign.center,
        },
      );

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _target.drawLine(x1, y1, x2, y2);

  @override
  void drawText(String text, double x, double y) =>
      _target.drawText(text, _mirrorX(x), y);


  @override
  void fillRect(double x, double y, double width, double height) =>
      _target.fillRect(x, y, width, height);

  @override
  void drawRect(double x, double y, double width, double height) =>
      _target.drawRect(x, y, width, height);

  @override
  void fillRoundRect(
    double x,
    double y,
    double width,
    double height,
    double cornerRadius,
  ) =>
      _target.fillRoundRect(x, y, width, height, cornerRadius);

  @override
  void fillCircle(double centerX, double centerY, double radius) =>
      _target.fillCircle(_mirrorX(centerX), centerY, radius);

  @override
  void fillArc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double swipeAngle,
  ) =>
      // Mirroring negates the sweep and reflects the start angle about the
      // vertical axis (0° points right, 180° points left).
      _target.fillArc(
        _mirrorX(centerX),
        centerY,
        radius,
        180.0 - startAngle,
        -swipeAngle,
      );

  @override
  double measureText(String text) => _target.measureText(text);

  @override
  core.Image toImage() => _target.toImage();
}

/// `JavaLocalDateFormatter`'s counterpart: locale-aware weekday and month
/// names, backed by package:intl.
///
/// It lives here because the header is the first widget that needs one; move it
/// into lib/platform/ once a second screen does.
class IntlLocalDateFormatter implements core.LocalDateFormatter {
  IntlLocalDateFormatter([String? localeName])
      : localeName = _resolve(localeName);

  /// The formatter for the locale the widget tree resolved. Locale data for it
  /// is loaded by GlobalMaterialLocalizations, which every app in this package
  /// installs through `L10n.localizationsDelegates`.
  factory IntlLocalDateFormatter.of(BuildContext context) =>
      IntlLocalDateFormatter(Localizations.maybeLocaleOf(context)?.toString());

  /// The locale whose data is actually installed; [_fallbackLocale] when the
  /// requested one has none, since package:intl ships en_US only.
  final String localeName;

  static const String _fallbackLocale = 'en_US';

  static String _resolve(String? requested) {
    if (requested == null || requested.isEmpty) return _fallbackLocale;
    final canonical = intl.Intl.canonicalizedLocale(requested);
    try {
      if (intl.DateFormat.localeExists(canonical)) return canonical;
      final language = canonical.split('_').first;
      if (intl.DateFormat.localeExists(language)) return language;
    } on Exception {
      // localeExists throws, rather than returning false, while no locale data
      // at all has been initialized.
    }
    return _fallbackLocale;
  }

  late final intl.DateFormat _shortWeekday = intl.DateFormat.E(localeName);
  late final intl.DateFormat _longWeekday = intl.DateFormat.EEEE(localeName);
  late final intl.DateFormat _shortMonth = intl.DateFormat.MMM(localeName);
  late final intl.DateFormat _longMonth = intl.DateFormat.MMMM(localeName);

  /// `DateFormat.getDateInstance(DateFormat.MEDIUM, locale)`.
  ///
  /// `DateSymbols.DATEFORMATS` is CLDR's `[full, long, medium, short]` pattern
  /// list, so index 2 is exactly Java's `MEDIUM` — "Jan 25, 2015" for en,
  /// "25.01.2015" for de, "2015年1月25日" for zh
  /// (`audit3.streak-chart-date-labels-are-hard#1`).
  late final intl.DateFormat _mediumDate = intl.DateFormat(
    _longMonth.dateSymbols.DATEFORMATS[2],
    localeName,
  );

  static DateTime _toDateTime(core.LocalDate date) =>
      DateTime.utc(date.year, date.month, date.day);

  /// LocalDate(1) is 2000-01-02, a Sunday, so adding [core.DayOfWeek]'s
  /// distance from Sunday lands on a date with that weekday.
  static core.LocalDate _dateWith(core.DayOfWeek weekday) =>
      core.LocalDate(1 + weekday.daysSinceSunday);

  @override
  String shortWeekdayName(core.LocalDate date) =>
      _shortWeekday.format(_toDateTime(date));

  @override
  String shortWeekdayNameOf(core.DayOfWeek weekday) =>
      shortWeekdayName(_dateWith(weekday));

  @override
  String longWeekdayNameOf(core.DayOfWeek weekday) =>
      _longWeekday.format(_toDateTime(_dateWith(weekday)));

  /// `JavaLocalDateFormatter.shortMonthName` asks the calendar for BOTH
  /// display names and returns the LONG one when it is three characters or
  /// shorter, because "for some locales, such as Japan, SHORT name is
  /// exceedingly short". It changes the answer for zh-CN, whose LONG January
  /// is 一月 and whose SHORT one is 1月
  /// (`audit3.shortmonthname-drops-the-use-the-long#1`).
  @override
  String shortMonthName(core.LocalDate date) {
    final dateTime = _toDateTime(date);
    final long = _longMonth.format(dateTime);
    if (long.length <= 3) return long;
    return _shortMonth.format(dateTime);
  }

  @override
  String longMonthName(core.LocalDate date) =>
      _longMonth.format(_toDateTime(date));

  /// Port of `JavaLocalDateFormatter.longFormat`, the one method of that class
  /// that is not on the `LocalDateFormatter` interface: the locale's medium
  /// date, which is what flanks a bar on the streak chart.
  ///
  /// Kotlin forces the formatter's time zone to UTC so that a `LocalDate` is
  /// never re-read as a local instant and printed as the day before;
  /// [_toDateTime] builds a UTC midnight for the same reason.
  String longFormat(core.LocalDate date) =>
      _mediumDate.format(_toDateTime(date));
}
