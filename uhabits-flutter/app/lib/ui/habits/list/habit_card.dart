/// Port of uhabits-android/.../habits/list/views/HabitCardView.kt.
///
/// One row of the main screen: a score ring, the habit name in the habit's
/// colour, and an [EntryPanel] flush against the right edge.
///
/// The Kotlin view is mutable and self-refreshing — it registers itself as a
/// `ModelObservable.Listener` on the habit and re-reads every attribute in
/// `copyAttributesFrom` whenever the model changes. A Flutter widget is
/// rebuilt by whoever owns the state instead, so all of that collapses into
/// the constructor arguments: the card renders what it is handed and nothing
/// else.
///
/// It also runs no commands. HabitCardView calls `behavior.onToggle` /
/// `behavior.onEdit` directly; here both leave through [HabitCard.onToggle]
/// and [HabitCard.onEdit], and the screen that owns [ListHabitsBehavior]
/// decides what happens. The `(x, y)` pair those behaviour methods take — the
/// confetti origin, `getAbsoluteButtonLocation(date)` — is reported separately
/// through [HabitCard.onEntryPressed], because only the row knows where its
/// buttons ended up.
///
/// The touch ripple that a *button* gesture triggers on the row behind it
/// (`triggerRipple`, `setHotspot`, the 25 ms state flip) is ported explicitly
/// as [HabitCardRipple]: an [InkWell] only ripples for gestures it handles
/// itself, and an entry button consumes its own.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../common/views/ring_view.dart';
import 'entry_panel.dart';

/// The geometry of HabitCardView, in logical pixels.
///
/// Every number is a `dp(...)` literal from the Kotlin `init` block, and each
/// one was confirmed against
/// uhabits-android/src/androidTest/assets/views/habits/list/HabitCardView/render.png
/// (800x100 px at density 2, i.e. a 400x50 dp card): the ring occupies
/// x = 22..51 px = 11..25.5 dp, and the five checkmarks are 48 dp apart with
/// the last one flush against the card's inner right edge.
class _CardMetrics {
  /// `setPadding(margin, 0, margin, margin)` with `margin = dp(3f)`.
  static const double cardMargin = 3.0;

  /// `LinearLayout.LayoutParams(ringSize, ringSize)` with `ringSize = dp(15f)`.
  static const double ringSize = 15.0;

  /// `setMargins(margin, 0, margin, 0)` with `margin = dp(8f)`.
  static const double ringMargin = 8.0;

  /// `setThickness(dp(3f))`.
  static const double ringThickness = 3.0;

  /// `scoreRing.setPrecision(1.0f / 16)`, the second half of the `score`
  /// setter, which quantises the drawn sweep to 22.5-degree steps
  /// (`list-habits.habit-card#2`, `verify.ring-not-quantised#1`).
  static const double ringPrecision = 1.0 / 16;

  /// `elevation = dp(1f)` on the inner frame.
  static const double elevation = 1.0;

  /// `<stroke android:width="2dip" .../>` in res/drawable/selected_box.xml.
  static const double selectedBorderWidth = 2.0;

  /// `Handler().postDelayed({ background.state = intArrayOf() }, 25)`.
  static const Duration rippleDuration = Duration(milliseconds: 25);

  /// HabitCardView's label is a bare TextView, so its size is the platform
  /// default rather than anything the app sets, and the ported [core.Theme]
  /// has no token for it — `regularTextSize` (17) belongs to the core charts.
  /// 14 is what the baseline measures: "Meditate" is 21 px tall from the top
  /// of the ascenders to the baseline at density 2, i.e. 10.5 dp of ascent.
  static const double labelFontSize = 14.0;

  /// `maxLines = 2` / `ellipsize = TruncateAt.END`.
  static const int labelMaxLines = 2;
}

class HabitCard extends StatefulWidget {
  const HabitCard({
    required this.habit,
    required this.score,
    required this.values,
    required this.theme,
    required this.preferences,
    this.notes = const <String>[],
    this.buttonCount = 5,
    this.dataOffset = 0,
    this.isSelected = false,
    this.onToggle,
    this.onEdit,
    this.onTap,
    this.onLongPress,
    this.onEntryPressed,
    super.key,
  });

  final core.Habit habit;

  /// `habit.scores[today].value`, in 0..1. HabitCardView feeds it to
  /// `RingView.setPercentage`.
  final double score;

  /// Raw [core.Entry] values, newest first — `HabitCardListCache.getCheckmarks`.
  final List<int> values;

  /// `HabitCardListCache.getNotes`, indexed like [values].
  final List<String> notes;

  final core.Theme theme;

  final core.Preferences preferences;

  final int buttonCount;

  final int dataOffset;

  final bool isSelected;

  /// An entry button asked to move to a new value. Run
  /// [CreateRepetitionCommand] (or [ListHabitsBehavior.onToggle]) from here.
  final EntryToggleCallback? onToggle;

  /// An entry button asked for the editor popup —
  /// [ListHabitsBehavior.onEdit].
  final EntryEditCallback? onEdit;

  /// The row itself was tapped: `HabitCardListController.onItemClick`.
  final VoidCallback? onTap;

  /// The row itself was long-pressed: `onItemLongClick`, which starts the
  /// selection.
  final VoidCallback? onLongPress;

  /// An entry button was pressed, reported with its centre in *global*
  /// coordinates — `HabitCardView.getAbsoluteButtonLocation(date)`. Fires
  /// before [onToggle] / [onEdit], just as `triggerRipple(date)` does.
  final EntryPressedCallback? onEntryPressed;

  /// `copyAttributesFrom`'s local `getActiveColor`: an archived habit is drawn
  /// in `?attr/contrast60`, which is [core.Theme.mediumContrastTextColor].
  core.Color get activeColor => habit.isArchived
      ? theme.mediumContrastTextColor
      : theme.colorOf(habit.color);

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  /// The panel is the only child whose geometry the ripple needs, and it is
  /// laid out by a `Row`, so its origin is not something the card can compute.
  final GlobalKey _panelKey = GlobalKey();

  /// `innerFrame`, the view whose background the hotspot is set on.
  ///
  /// The ripple is driven imperatively, the way `background.setHotspot(x, y)`
  /// is: nothing above it in the tree is rebuilt, so an entry button keeps the
  /// value `performToggle()` just wrote into it.
  final GlobalKey<HabitCardRippleState> _innerFrameKey =
      GlobalKey<HabitCardRippleState>();

  /// The focus node of the row's own [InkWell].
  ///
  /// The port keeps the row focusable on purpose — upstream
  /// `HabitCardListView.bindCardView` binds the card with `setOnTouchListener`
  /// only, so `HabitCardView` is never a D-pad stop and there is no keyboard
  /// path to the detail screen; the port adds one (recorded deviation). What
  /// does *not* follow from that deviation is the highlight: Android draws the
  /// default focus highlight in `View.onDrawForeground` on `isFocused()` — the
  /// view's own primary focus — never on `hasFocus()`, so a focused child
  /// never tints its parent, and walking a habit row tints exactly one 48dp
  /// cell at a time (`audit11.focusing-one-check-mark-cell-paints#1`).
  ///
  /// `InkResponse` does the opposite: its highlight is driven from the Focus
  /// node's `hasFocus`, which is true while any descendant holds primary
  /// focus, so every check-mark cell of the row would flood the whole 794px
  /// card. The stock highlight is therefore switched off
  /// ([InkWell.focusColor] transparent) and the row paints its own from
  /// [FocusNode.hasPrimaryFocus].
  final FocusNode _rowFocusNode = FocusNode(debugLabel: 'HabitCard');

  bool _rowHasPrimaryFocus = false;

  @override
  void initState() {
    super.initState();
    _rowFocusNode.addListener(_onRowFocusChanged);
  }

  @override
  void dispose() {
    _rowFocusNode.removeListener(_onRowFocusChanged);
    _rowFocusNode.dispose();
    super.dispose();
  }

  void _onRowFocusChanged() {
    if (_rowHasPrimaryFocus == _rowFocusNode.hasPrimaryFocus) return;
    setState(() => _rowHasPrimaryFocus = _rowFocusNode.hasPrimaryFocus);
  }

  /// `HabitCardView.triggerRipple(x, y)`: place the hotspot, drive the
  /// background into the pressed+enabled state, and drop back out of it 25 ms
  /// later (`list-habits.habit-card#9`).
  void _onEntryPressed(core.LocalDate date, Offset centerInPanel) {
    final panel = _panelKey.currentContext?.findRenderObject();
    if (panel is! RenderBox) return;
    final global = panel.localToGlobal(centerInPanel);
    widget.onEntryPressed?.call(date, global);
    final inner = _innerFrameKey.currentContext?.findRenderObject();
    if (inner is! RenderBox) return;
    _innerFrameKey.currentState?.trigger(inner.globalToLocal(global));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor;
    final flutterColor = _toFlutterColor(color);
    final theme = widget.theme;

    return Padding(
      // setPadding(margin, 0, margin, margin)
      padding: const EdgeInsets.only(
        left: _CardMetrics.cardMargin,
        right: _CardMetrics.cardMargin,
        bottom: _CardMetrics.cardMargin,
      ),
      child: Material(
        // res/drawable/ripple.xml is `?attr/cardBgColor` under a ripple;
        // res/drawable/selected_box.xml is `?highlightedBackgroundColor` under
        // a 2dp grey_500 stroke — grey_100 (#F5F5F5) in the light theme,
        // grey_800 (#424242) in the dark one and black in pure black, so a
        // selected row lightens against its card except in pure black, where
        // the stroke carries the selection on its own.
        color: _toFlutterColor(
          widget.isSelected
              ? theme.highlightedBackgroundColor
              : theme.cardBackgroundColor,
        ),
        elevation: _CardMetrics.elevation,
        shape: widget.isSelected
            ? Border.all(
                color: _toFlutterColor(theme.mediumContrastTextColor),
                width: _CardMetrics.selectedBorderWidth,
              )
            : null,
        child: HabitCardRipple(
          key: _innerFrameKey,
          color: _toFlutterColor(theme.mediumContrastTextColor),
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            focusNode: _rowFocusNode,
            // `InkResponse` lights this highlight from `hasFocus`, which is
            // true for any focused descendant — one focused check-mark cell
            // would tint the whole row. Android tints only the cell, so the
            // stock highlight is off and the row paints its own below, from
            // primary focus (`audit11.focusing-one-check-mark-cell-paints#1`).
            focusColor: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _rowHasPrimaryFocus
                    ? Theme.of(context).focusColor
                    : null,
              ),
              child: Row(
                // gravity = Gravity.CENTER_VERTICAL
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  _buildRing(color),
                  Expanded(child: _buildLabel(flutterColor)),
                  _buildPanel(color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `scoreRing`, the `RingView` the Kotlin `init` block puts first in the
  /// inner frame:
  ///
  /// ```kotlin
  /// scoreRing = RingView(context).apply { … setThickness(dp(3f)) }
  /// …
  /// var score
  ///     set(value) {
  ///         scoreRing.setPercentage(value.toFloat())
  ///         scoreRing.setPrecision(1.0f / 16)
  ///     }
  /// ```
  ///
  /// This is the Android widget, not the core `Ring` view: only the Android one
  /// has a precision, and the card's is 1/16, so a score of 0.03 rounds down to
  /// no arc at all and one of 0.97 rounds up to a closed ring
  /// (`verify.ring-not-quantised#1`). Its two other colours come from `init()`:
  /// the remainder is `?attr/contrast100` at 15% alpha and the hole is
  /// `?attr/cardBgColor`, whatever the row's own selected background is.
  Widget _buildRing(core.Color color) {
    final theme = widget.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _CardMetrics.ringMargin),
      child: SizedBox(
        width: _CardMetrics.ringSize,
        height: _CardMetrics.ringSize,
        child: RingView(
          // `scoreRing.setColor(c)` in `copyAttributesFrom`: the label's colour,
          // i.e. contrast60 for an archived habit.
          color: _toFlutterColor(color),
          percentage: widget.score,
          precision: _CardMetrics.ringPrecision,
          thickness: _CardMetrics.ringThickness,
          backgroundColor: _toFlutterColor(theme.cardBgColor),
          inactiveColor:
              RingView.applyInactiveAlpha(_toFlutterColor(theme.contrast100)),
        ),
      ),
    );
  }

  Widget _buildLabel(Color color) {
    return Text(
      widget.habit.name,
      maxLines: _CardMetrics.labelMaxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: _CardMetrics.labelFontSize,
      ),
    );
  }

  Widget _buildPanel(core.Color color) {
    final habit = widget.habit;
    return EntryPanel(
      key: _panelKey,
      values: widget.values,
      notes: widget.notes,
      color: color,
      theme: widget.theme,
      preferences: widget.preferences,
      isNumerical: habit.isNumerical,
      unit: habit.unit,
      targetType: habit.targetType,
      // `HabitCardView.copyAttributesFrom` sets `threshold = h.targetValue`,
      // and then `HabitCardListView.bindCardView` overwrites it with
      // `habit.targetValue / habit.frequency.denominator` — the second write
      // is the one that survives (`list-habits.habit-card#7`). A daily habit
      // divides by 1 and is unaffected; a "300 pages per week" habit colours
      // a day once it reaches 300/7, not 300.
      targetValue: habit.targetValue / habit.frequency.denominator,
      buttonCount: widget.buttonCount,
      dataOffset: widget.dataOffset,
      onToggle: widget.onToggle,
      onEdit: widget.onEdit,
      // Both `onToggle` and `onEdit` call `triggerRipple(date)` first, and
      // both read `getAbsoluteButtonLocation(date)` for the confetti origin.
      onPressed: _onEntryPressed,
    );
  }
}

/// The `?attr/cardBgColor` ripple that sits under a habit row.
///
/// Port of `HabitCardView.triggerRipple`: `background.setHotspot(x, y)` puts
/// the splash origin under the entry button that was pressed, the background
/// then enters `state_pressed | state_enabled`, and 25 ms later it is driven
/// back to the empty state so the splash fades out
/// (`list-habits.habit-card#9`).
///
/// [HabitCardRippleState.hotspot] is in this widget's own coordinates — the
/// innerFrame's, in Kotlin — and is null until the first gesture, which is
/// exactly when `RippleDrawable` has no hotspot either.
class HabitCardRipple extends StatefulWidget {
  const HabitCardRipple({
    required this.child,
    required this.color,
    super.key,
  });

  final Widget child;

  /// `?attr/colorControlHighlight`, the ripple tint.
  final Color color;

  @override
  HabitCardRippleState createState() => HabitCardRippleState();
}

class HabitCardRippleState extends State<HabitCardRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// `background.setHotspot(x, y)`, or null while no gesture has landed.
  Offset? hotspot;

  /// True while the background carries `state_pressed | state_enabled`.
  bool pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Un-pressing is what RippleDrawable animates; the press itself is
      // immediate.
      duration: const Duration(milliseconds: 200),
    );
  }

  Timer? _release;

  void trigger(Offset at) {
    setState(() {
      hotspot = at;
      pressed = true;
    });
    _controller.value = 1.0;
    _release?.cancel();
    _release = Timer(_CardMetrics.rippleDuration, () {
      if (!mounted) return;
      setState(() => pressed = false);
      _controller.reverse(from: 1.0);
    });
  }

  @override
  void dispose() {
    _release?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _RipplePainter(
        hotspot: hotspot,
        color: widget.color,
        opacity: _controller,
      ),
      child: widget.child,
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.hotspot,
    required this.color,
    required this.opacity,
  }) : super(repaint: opacity);

  final Offset? hotspot;
  final Color color;
  final Animation<double> opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = hotspot;
    if (center == null || opacity.value <= 0.0) return;
    canvas.drawCircle(
      center,
      size.height / 2 * opacity.value,
      Paint()..color = color.withValues(alpha: 0.2 * opacity.value),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.hotspot != hotspot || oldDelegate.color != color;
}

/// The core [core.Color] carries normalised channels; `dart:ui` wants bytes.
/// Same rounding as [core.Color.toInt] and as `FlutterCanvas.setColor`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
