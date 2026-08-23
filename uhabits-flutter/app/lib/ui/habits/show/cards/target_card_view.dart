/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/TargetCardView.kt,
/// the chart it hosts
/// (uhabits-android/.../activities/common/views/TargetChart.kt) and
/// res/layout/show_habit_target.xml.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/target_card.dart';
import 'package:uhabits_core/src/ui/views/number_button.dart' show ShortString;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';
import '../../../core_view.dart';
import 'score_card_view.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/views/target_card.dart'
    show TargetCardPresenter, TargetCardState;

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/TargetChart.kt.
///
/// One labelled progress bar per interval: a right-aligned label in a gutter
/// as wide as the widest of them, then a rounded background bar with the
/// completed part painted over it in the habit colour, and the completed and
/// remaining amounts written inside whichever half has room for them.
///
/// `paint.textSize` is `@dimen/tinyTextSize` (10sp), which the ported
/// [core.Theme] spells [core.Theme.smallTextSize]; the vertical centring
/// Android spells `centerY() - (descent + ascent) / 2` is what
/// [core.Canvas.drawText] does by itself, so those terms simply disappear.
///
/// Note that the remaining amount is not clamped: an over-target row shows a
/// negative number whenever it fits.
class TargetChartView extends core.View {
  TargetChartView({
    required this.values,
    required this.targets,
    required this.labels,
    required this.color,
    required this.theme,
  });

  /// `R.dimen.baseSize`, the height of one row.
  static const double baseSize = 20.0;

  /// `dpToPixels(context, 4f)`.
  static const double padding = 4.0;

  /// `dpToPixels(context, 2f)`.
  static const double cornerRadius = 2.0;

  /// The three lists are parallel and always the same length.
  final List<double> values;

  final List<double> targets;

  final List<String> labels;

  final core.Color color;

  final core.Theme theme;

  @override
  void draw(core.Canvas canvas) {
    if (labels.isEmpty) return;
    final width = canvas.getWidth();
    final height = canvas.getHeight();

    final textSize = theme.smallTextSize;
    canvas.setFontSize(textSize);
    var maxLabelSize = 0.0;
    for (final label in labels) {
      maxLabelSize = math.max(maxLabelSize, canvas.measureText(label));
    }

    // The block of rows is vertically centred. `onMeasure` sizes the view at
    // exactly labels.size * baseSize, so this is normally zero.
    final marginTop = (height - baseSize * labels.length) / 2.0;
    for (var row = 0; row < labels.length; row++) {
      _drawRow(canvas, row, marginTop + row * baseSize, width, maxLabelSize);
    }
  }

  void _drawRow(
    core.Canvas canvas,
    int row,
    double top,
    double width,
    double maxLabelSize,
  ) {
    final stop = maxLabelSize + padding * 2;
    final centerY = top + baseSize / 2;

    // Label.
    canvas.setColor(theme.mediumContrastTextColor);
    canvas.setTextAlign(core.TextAlign.right);
    canvas.drawText(labels[row], stop - padding, centerY);

    // Background box.
    final barLeft = stop + padding;
    final barRight = width - padding;
    final barTop = top + baseSize * 0.05;
    final barHeight = baseSize - 2 * (baseSize * 0.05);
    final barWidth = barRight - barLeft;
    canvas.setColor(theme.lowContrastTextColor);
    canvas.fillRoundRect(barLeft, barTop, barWidth, barHeight, cornerRadius);

    var percentage = targets[row] > 0 ? values[row] / targets[row] : 1.0;
    // Clamped above but never below, so a negative value stays negative.
    percentage = math.min(1.0, percentage);

    // Completed box.
    var completedWidth = percentage * barWidth;
    if (completedWidth > 0 && completedWidth < 2 * cornerRadius) {
      completedWidth = 2 * cornerRadius;
    }
    final remainingWidth = barWidth - completedWidth;
    canvas.setColor(color);
    canvas.fillRoundRect(
      barLeft,
      barTop,
      completedWidth,
      barHeight,
      cornerRadius,
    );

    // Values. TargetChart imports the Android `toShortString`, not the core
    // one, so the three smallest branches format with DecimalFormat.
    final remaining = targets[row] - values[row];
    final completedText = values[row].toShortStringAndroid();
    final remainingText = remaining.toShortStringAndroid();
    canvas.setTextAlign(core.TextAlign.center);
    if (completedWidth > canvas.measureText(completedText) + 2 * padding) {
      // contrast0; the ported Theme's nearest neighbour is the card
      // background (0xFAFAFA light, 0x303030 dark).
      canvas.setColor(theme.cardBackgroundColor);
      canvas.drawText(completedText, barLeft + completedWidth / 2, centerY);
    }
    if (remainingWidth > canvas.measureText(remainingText) + 2 * padding) {
      canvas.setColor(theme.mediumContrastTextColor);
      final remainingLeft = barLeft + completedWidth;
      canvas.drawText(
        remainingText,
        (remainingLeft + barRight) / 2,
        centerY,
      );
    }
  }
}

/// The Target card: a title and one [TargetChartView] row per interval.
///
/// Shown for numerical habits only — `ShowHabitView.setState` hides it for
/// boolean ones, which is the screen's decision rather than this widget's.
class TargetCardView extends StatelessWidget {
  const TargetCardView({
    required this.state,
    super.key,
  });

  final TargetCardState state;

  /// show_habit_target.xml asks for 300dp, but `TargetChart.onMeasure` only
  /// honours a `MATCH_PARENT` layout height; with a fixed one it answers
  /// `labels.size * baseSize` and the 300dp never takes effect.
  double get chartHeight => state.intervals.length * TargetChartView.baseSize;

  /// `state.intervals.map { intervalToLabel(resources, it) }`. Every interval
  /// that is not one of the first four — 365 included — is "Year".
  List<String> labels(L10n l10n) => <String>[
        for (final interval in state.intervals)
          switch (interval) {
            1 => l10n.today,
            7 => l10n.week,
            30 => l10n.month,
            91 => l10n.quarter,
            _ => l10n.year,
          },
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ChartCard(
      theme: state.theme,
      title: l10n.target,
      titleColor: state.titleColor,
      // `android:paddingTop="12dp"` on the target card.
      padding: ChartCard.cardPadding.copyWith(top: 12),
      child: SizedBox(
        height: chartHeight,
        width: double.infinity,
        child: CoreView(
          view: TargetChartView(
            values: state.values,
            targets: state.targets,
            labels: labels(l10n),
            color: state.titleColor,
            theme: state.theme,
          ),
        ),
      ),
    );
  }
}
