/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/OverviewCardView.kt,
/// res/layout/show_habit_overview.xml and
/// .../activities/common/views/RingView.kt (baseline:
/// androidTest/assets/views/habits/show/OverviewCard/render.png).
///
/// A title, a score ring and four value/caption pairs laid out on one weighted
/// row. Every string and every colour decision is already a getter on the core
/// [OverviewCardState] — `scoreText`, `monthDiffText`, `yearDiffText`,
/// `totalCountText`, `titleColor`, `scoreColor`, `monthDiffColor`,
/// `yearDiffColor`, `totalCountColor`, `captionColor` — so nothing is
/// recomputed here.
///
/// The card is hidden entirely for numerical habits
/// (`show-habit.overview-card#12`); that decision belongs to the core's
/// `ShowHabitCardVisibility` and is taken by the screen, which then never
/// builds this widget.
library;

// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/overview_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';

class OverviewCardView extends StatelessWidget {
  const OverviewCardView({required this.state, super.key});

  final OverviewCardState state;

  /// `@style/CardHeader`: `@dimen/regularTextSize` and a 12dp bottom margin.
  static const double titleFontSize = 16.0;
  static const double titleBottomMargin = 12.0;

  /// The value and caption labels declare no text size, so they take the
  /// platform default.
  static const double labelFontSize = 14.0;

  /// `android:layout_width="30dp"` / `habit:thickness="5"` on `scoreRing`.
  static const double ringSize = 30.0;
  static const double ringThickness = 5.0;

  /// `android:layout_weight` of the five columns of `llOverview`.
  static const int ringWeight = 5;
  static const int columnWeight = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: titleBottomMargin),
          child: Text(
            // `@string/overview`, the title of show_habit_overview.xml.
            l10n.overview,
            key: titleKey,
            style: TextStyle(
              color: _toFlutterColor(state.titleColor),
              fontSize: titleFontSize,
            ),
          ),
        ),
        Row(
          // `android:gravity="center"` on llOverview.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: ringWeight,
              child: Center(
                child: SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: CustomPaint(
                    key: ringKey,
                    painter: RingPainter(
                      color: _toFlutterColor(state.theme.colorOf(state.color)),
                      // `?attr/contrast100` at 15% alpha, applied by
                      // `RingView.init`.
                      inactiveColor: _toFlutterColor(
                        state.theme.highContrastTextColor,
                      ).withValues(alpha: RingPainter.inactiveAlpha),
                      backgroundColor:
                          _toFlutterColor(state.theme.cardBackgroundColor),
                      percentage: state.scoreToday,
                      thickness: ringThickness,
                    ),
                  ),
                ),
              ),
            ),
            _OverviewColumn(
              value: state.scoreText,
              valueColor: _toFlutterColor(state.scoreColor),
              caption: l10n.score,
              captionColor: _toFlutterColor(state.captionColor),
              valueKey: scoreLabelKey,
            ),
            _OverviewColumn(
              value: state.monthDiffText,
              valueColor: _toFlutterColor(state.monthDiffColor),
              caption: l10n.month,
              captionColor: _toFlutterColor(state.captionColor),
              valueKey: monthDiffLabelKey,
            ),
            _OverviewColumn(
              value: state.yearDiffText,
              valueColor: _toFlutterColor(state.yearDiffColor),
              caption: l10n.year,
              captionColor: _toFlutterColor(state.captionColor),
              valueKey: yearDiffLabelKey,
            ),
            _OverviewColumn(
              value: state.totalCountText,
              valueColor: _toFlutterColor(state.totalCountColor),
              caption: l10n.total,
              captionColor: _toFlutterColor(state.captionColor),
              valueKey: totalCountLabelKey,
            ),
          ],
        ),
      ],
    );
  }

  /// The ids of show_habit_overview.xml.
  static const Key titleKey = Key('overviewCard.title');
  static const Key ringKey = Key('overviewCard.scoreRing');
  static const Key scoreLabelKey = Key('overviewCard.scoreLabel');
  static const Key monthDiffLabelKey = Key('overviewCard.monthDiffLabel');
  static const Key yearDiffLabelKey = Key('overviewCard.yearDiffLabel');
  static const Key totalCountLabelKey = Key('overviewCard.totalCountLabel');
}

/// One of the four `LinearLayout`s of weight 4: a value over a caption, both
/// `wrap_content` and therefore start-aligned.
class _OverviewColumn extends StatelessWidget {
  const _OverviewColumn({
    required this.value,
    required this.valueColor,
    required this.caption,
    required this.captionColor,
    required this.valueKey,
  });

  final String value;
  final Color valueColor;
  final String caption;
  final Color captionColor;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: OverviewCardView.columnWeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            key: valueKey,
            style: TextStyle(
              color: valueColor,
              fontSize: OverviewCardView.labelFontSize,
            ),
          ),
          Text(
            caption,
            style: TextStyle(
              color: captionColor,
              fontSize: OverviewCardView.labelFontSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of `RingView.onDraw`, which is *not* the core `Ring` view: the Android
/// widget quantises the percentage, paints the remainder in its own inactive
/// colour and punches the hole with the card background rather than with the
/// theme's low-contrast colour.
///
/// `show-habit.overview-card#10`: the sweep is
/// `360 * round(percentage / precision) * precision` degrees starting at -90
/// (12 o'clock), and the remainder is drawn in contrast100 at 15% alpha.
class RingPainter extends CustomPainter {
  const RingPainter({
    required this.color,
    required this.inactiveColor,
    required this.backgroundColor,
    required this.percentage,
    required this.thickness,
    this.precision = defaultPrecision,
  });

  final Color color;
  final Color inactiveColor;
  final Color backgroundColor;
  final double percentage;
  final double thickness;
  final double precision;

  /// `precision = 0.01f` — the constructor default, which show_habit_overview
  /// does not override.
  static const double defaultPrecision = 0.01;

  /// `setAlpha(inactiveColor, 0.15f)`.
  static const double inactiveAlpha = 0.15;

  /// `val angle = 360 * (percentage / precision).roundToLong() * precision`,
  /// in degrees.
  double get sweepDegrees => 360 * (percentage / precision).round() * precision;

  @override
  void paint(Canvas canvas, Size size) {
    // `diameter = max(1, min(height, width))`.
    final diameter = math.max(1.0, math.min(size.height, size.width));
    final rect = Rect.fromLTWH(0, 0, diameter, diameter);
    final angle = sweepDegrees;
    final paint = Paint()..isAntiAlias = true;

    canvas.drawArc(
      rect,
      _radians(-90),
      _radians(angle),
      true,
      paint..color = color,
    );
    canvas.drawArc(
      rect,
      _radians(angle - 90),
      _radians(360 - angle),
      true,
      paint..color = inactiveColor,
    );
    if (thickness > 0) {
      // `rect.inset(thickness, thickness)` then a full 360 arc: the hole is
      // overpainted with the card background, not cleared.
      canvas.drawArc(
        rect.deflate(thickness),
        0,
        _radians(360),
        true,
        paint..color = backgroundColor,
      );
    }
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  @override
  bool shouldRepaint(RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.percentage != percentage ||
      oldDelegate.thickness != thickness ||
      oldDelegate.precision != precision;
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
