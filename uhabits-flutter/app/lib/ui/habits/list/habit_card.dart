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
/// decides what happens. The `(x, y)` pair those behaviour methods take (the
/// confetti origin, computed by HabitCardView's `getAbsoluteButtonLocation`)
/// is therefore not this widget's business either — the caller can recover it
/// from the button's key.
///
/// What is deliberately not ported: the touch ripple and its hotspot
/// (`triggerRipple`, `setHotspot`, the 25 ms state flip), which are an
/// Android RippleDrawable detail; [InkWell] gives the same affordance for
/// free.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/ui/views/ring.dart' as core_views;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../core_view.dart';
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

  /// `elevation = dp(1f)` on the inner frame.
  static const double elevation = 1.0;

  /// `<stroke android:width="2dip" .../>` in res/drawable/selected_box.xml.
  static const double selectedBorderWidth = 2.0;

  /// HabitCardView's label is a bare TextView, so its size is the platform
  /// default rather than anything the app sets, and the ported [core.Theme]
  /// has no token for it — `regularTextSize` (17) belongs to the core charts.
  /// 14 is what the baseline measures: "Meditate" is 21 px tall from the top
  /// of the ascenders to the baseline at density 2, i.e. 10.5 dp of ascent.
  static const double labelFontSize = 14.0;

  /// `maxLines = 2` / `ellipsize = TruncateAt.END`.
  static const int labelMaxLines = 2;
}

class HabitCard extends StatelessWidget {
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

  /// `copyAttributesFrom`'s local `getActiveColor`: an archived habit is drawn
  /// in `?attr/contrast60`, which is [core.Theme.mediumContrastTextColor].
  core.Color get activeColor => habit.isArchived
      ? theme.mediumContrastTextColor
      : theme.colorOf(habit.color);

  @override
  Widget build(BuildContext context) {
    final color = activeColor;
    final flutterColor = _toFlutterColor(color);

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
        // a 2dp grey_500 stroke. The ported Theme has no token for
        // highlightedBackgroundColor (grey_100), so the selected fill uses
        // headerBackgroundColor, the closest one it does have.
        color: _toFlutterColor(
          isSelected ? theme.headerBackgroundColor : theme.cardBackgroundColor,
        ),
        elevation: _CardMetrics.elevation,
        shape: isSelected
            ? Border.all(
                color: _toFlutterColor(theme.mediumContrastTextColor),
                width: _CardMetrics.selectedBorderWidth,
              )
            : null,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
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
    );
  }

  Widget _buildRing(core.Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _CardMetrics.ringMargin),
      child: SizedBox(
        width: _CardMetrics.ringSize,
        height: _CardMetrics.ringSize,
        child: CoreView(
          view: core_views.Ring(
            color: color,
            percentage: score,
            thickness: _CardMetrics.ringThickness,
            radius: _CardMetrics.ringSize / 2,
            theme: theme,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(Color color) {
    return Text(
      habit.name,
      maxLines: _CardMetrics.labelMaxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: _CardMetrics.labelFontSize,
      ),
    );
  }

  Widget _buildPanel(core.Color color) {
    return EntryPanel(
      values: values,
      notes: notes,
      color: color,
      theme: theme,
      preferences: preferences,
      isNumerical: habit.isNumerical,
      unit: habit.unit,
      targetType: habit.targetType,
      targetValue: habit.targetValue,
      buttonCount: buttonCount,
      dataOffset: dataOffset,
      onToggle: onToggle,
      onEdit: onEdit,
    );
  }
}

/// The core [core.Color] carries normalised channels; `dart:ui` wants bytes.
/// Same rounding as [core.Color.toInt] and as `FlutterCanvas.setColor`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
