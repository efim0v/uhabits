import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
// The core view lives outside uhabits_core's public library; it is imported by
// path until the package exports lib/src/ui/views.
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/views/habit_list_header.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

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
    this.isCheckmarkSequenceReversed = false,
    this.maxDataOffset,
    this.today,
    this.theme,
    this.dateFormatter,
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

  /// `Preferences.isCheckmarkSequenceReversed`. The screen feeds it in and
  /// rebuilds on `onCheckmarkSequenceChanged`; the header does not subscribe.
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

  int get effectiveMaxDataOffset =>
      maxDataOffset ?? math.max(maxCheckmarkCount - buttonCount, 0);

  @override
  State<ListHeader> createState() => _ListHeaderState();
}

class _ListHeaderState extends State<ListHeader> {
  /// The scroller's bucket size (`list-habits.header-scrolling#2`).
  static final double _columnWidth = ListHeader.columnWidth;

  /// The scroller position, in pixels. Only the sub-column remainder is real
  /// state: the whole-column part is [_reportedOffset].
  double _scrollX = 0.0;

  /// The column the scroller believes it is on — `ScrollableChart.dataOffset`.
  /// It is what a new position is compared against before the callback fires,
  /// so a parent that ignores [ListHeader.onDataOffsetChanged] is told about
  /// each column once rather than on every touch event.
  int _reportedOffset = 0;

  @override
  void initState() {
    super.initState();
    _reportedOffset = widget.dataOffset;
    _scrollX = widget.dataOffset * _columnWidth;
  }

  @override
  void didUpdateWidget(ListHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  /// `HeaderView.updateScrollDirection`: -1, flipped by the reversed checkmark
  /// sequence (`list-habits.header-scrolling#4`). The RTL flip is not ported —
  /// the core view always lays its columns out left to right.
  int get _scrollDirection => widget.isCheckmarkSequenceReversed ? 1 : -1;

  int _offsetOf(double scrollX) => (scrollX / _columnWidth).floor();

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final maxOffset = widget.effectiveMaxDataOffset;
    // Unlike android.widget.Scroller, which lets currX run negative and makes
    // you drag the debt back, the position is clamped to the scrollable range.
    _scrollX = (_scrollX + details.delta.dx * _scrollDirection)
        .clamp(0.0, maxOffset * _columnWidth);
    final newOffset = _offsetOf(_scrollX).clamp(0, maxOffset);
    if (newOffset != _reportedOffset) {
      _reportedOffset = newOffset;
      widget.onDataOffsetChanged?.call(newOffset);
    }
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

    // HabitListHeader's `today` is the newest column, so scrolling back is a
    // subtraction: column i then shows today.minus(i + dataOffset)
    // (`list-habits.header-dates#2`).
    final core.View header = HabitListHeader(
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
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      child: SizedBox(
        // `HeaderView.onMeasure`: the incoming width, and exactly 48dp high.
        height: theme.checkmarkButtonSize,
        width: double.infinity,
        child: CoreView(
          view: widget.isCheckmarkSequenceReversed
              ? MirroredView(
                  header,
                  stripWidth: widget.buttonCount * theme.checkmarkButtonSize,
                )
              : header,
        ),
      ),
    );
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
  MirroredView(this._inner, {required this.stripWidth});

  final core.View _inner;

  /// `buttonCount * R.dimen.checkmarkWidth`.
  final double stripWidth;

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

  final double _stripWidth;

  /// Reflection about the band `[width - stripWidth, width)`.
  double _mirrorX(double x) => 2 * _target.getWidth() - _stripWidth - x;

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

  @override
  String shortMonthName(core.LocalDate date) =>
      _shortMonth.format(_toDateTime(date));

  @override
  String longMonthName(core.LocalDate date) =>
      _longMonth.format(_toDateTime(date));
}
