/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/views/StreakCardView.kt,
/// the chart it hosts
/// (uhabits-android/.../activities/common/views/StreakChart.kt) and
/// res/layout/show_habit_streak.xml.
library;

// uhabits_core exports neither lib/src/ui/screens nor lib/src/ui/views yet.
// ignore_for_file: implementation_imports

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/streak_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../../l10n/app_localizations.dart';
import '../../../core_view.dart';
import '../../list/list_header.dart' show IntlLocalDateFormatter;
import 'score_card_view.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/views/streak_card.dart'
    show StreakCardState, StreakCartPresenter;

/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/common/views/StreakChart.kt.
///
/// One horizontal bar per streak, top to bottom, each `@dimen/baseSize` (20dp)
/// tall and centred on the view; the streak length sits inside the bar, and
/// the start and end dates flank it when there is room.
///
/// Substitutions forced by the core [core.Canvas], all of them mechanical:
///
///  * `paint.fontSpacing` becomes [chartFontSpacing] times the text size and
///    every baseline goes through [chartTextCenter];
///  * `JavaLocalDateFormatter.longFormat` (a `DateFormat.MEDIUM` instance) has
///    no counterpart on [core.LocalDateFormatter], so the flanking labels are
///    built from `shortMonthName` as "Jan 25, 2015". Override [dateLabel] to
///    supply a properly localized medium date.
///
/// One upstream oddity is kept: `maxLabelWidth` is never reset at the start of
/// `updateMaxMinLengths`, so within one Android view instance it only grows.
/// A Flutter view is rebuilt from scratch on every frame, which means the
/// widest label of the *current* streak list always wins — the same value the
/// Android view converges on.
class StreakChartView extends core.View {
  StreakChartView({
    required this.streaks,
    required this.color,
    required this.theme,
    required this.dateFormatter,
    this.dateLabel,
  });

  /// `R.dimen.baseSize`.
  static const double baseSize = 20.0;

  /// `dpToPixels(context, 2f)` — the bar's corner radius.
  static const double cornerRadius = 2.0;

  /// Newest-ending first, as [StreakCardState.bestStreaks] delivers it.
  final List<core.Streak> streaks;

  final core.Color color;

  final core.Theme theme;

  final core.LocalDateFormatter dateFormatter;

  final String Function(core.LocalDate date)? dateLabel;

  String _label(core.LocalDate date) =>
      dateLabel?.call(date) ??
      '${dateFormatter.shortMonthName(date)} ${date.day}, ${date.year}';

  @override
  void draw(core.Canvas canvas) {
    // `if (streaks!!.isEmpty()) return` — an empty card body.
    if (streaks.isEmpty) return;
    final width = canvas.getWidth();

    // onSizeChanged: max(min(baseSize * 0.5, regularTextSize), tinyTextSize).
    // The ported Theme spells Android's tinyTextSize `smallTextSize`.
    final textSize = math.max(
      math.min(baseSize * 0.5, theme.regularTextSize),
      theme.smallTextSize,
    );
    canvas.setFontSize(textSize);
    final em = textSize * chartFontSpacing;
    final textMargin = 0.5 * em;

    // updateMaxMinLengths.
    var maxLength = 0;
    var maxLabelWidth = 0.0;
    for (final streak in streaks) {
      maxLength = math.max(maxLength, streak.length);
      maxLabelWidth = math.max(
        maxLabelWidth,
        math.max(
          canvas.measureText(_label(streak.start)),
          canvas.measureText(_label(streak.end)),
        ),
      );
    }
    var shouldShowLabels = true;
    if (width - 2 * maxLabelWidth < width * 0.25) {
      maxLabelWidth = 0.0;
      shouldShowLabels = false;
    }
    // `drawRow` bails on every row when the longest streak is empty.
    if (maxLength == 0) return;

    var top = 0.0;
    for (final streak in streaks) {
      _drawRow(
        canvas,
        streak,
        top,
        width,
        maxLength,
        maxLabelWidth,
        shouldShowLabels,
        textMargin,
        em,
        textSize,
      );
      top += baseSize;
    }
  }

  void _drawRow(
    core.Canvas canvas,
    core.Streak streak,
    double top,
    double width,
    int maxLength,
    double maxLabelWidth,
    bool shouldShowLabels,
    double textMargin,
    double em,
    double textSize,
  ) {
    final percentage = streak.length / maxLength;
    var availableWidth = width - 2 * maxLabelWidth;
    if (shouldShowLabels) availableWidth -= 2 * textMargin;

    final lengthText = streak.length.toString();
    // A bar is never narrower than its own number plus one em.
    final barWidth = math.max(
      percentage * availableWidth,
      canvas.measureText(lengthText) + em,
    );
    final gap = (width - barWidth) / 2;
    final paddingTopBottom = baseSize * 0.05;

    canvas.setColor(_barColor(percentage));
    canvas.fillRoundRect(
      gap,
      top + paddingTopBottom,
      barWidth,
      baseSize - 2 * paddingTopBottom,
      cornerRadius,
    );

    // `yOffset = rect.centerY() + 0.3f * em` is the baseline of text centred
    // in the row; chartTextCenter turns it back into a centre.
    final baselineY = top + baseSize / 2 + 0.3 * em;
    final y = chartTextCenter(baselineY, textSize);

    canvas.setColor(_numberColor(percentage));
    canvas.setTextAlign(core.TextAlign.center);
    canvas.drawText(lengthText, width / 2, y);

    if (shouldShowLabels) {
      canvas.setColor(theme.mediumContrastTextColor);
      canvas.setTextAlign(core.TextAlign.right);
      canvas.drawText(_label(streak.start), gap - textMargin, y);
      canvas.setTextAlign(core.TextAlign.left);
      canvas.drawText(_label(streak.end), width - gap + textMargin, y);
    }
  }

  /// `percentageToColor`: the habit colour, then the same colour at alpha 192
  /// and 96, then contrast20 — [core.Theme.lowContrastTextColor].
  core.Color _barColor(double percentage) {
    if (percentage >= 1.0) return color;
    if (percentage >= 0.8) return color.withAlpha(192 / 255);
    if (percentage >= 0.5) return color.withAlpha(96 / 255);
    return theme.lowContrastTextColor;
  }

  /// `percentageToTextColor`: contrast0 over a filled bar, contrast60
  /// otherwise. The ported [core.Theme] has no contrast0 token; its nearest
  /// neighbour is the card background (0xFAFAFA light, 0x303030 dark against
  /// Android's 0xFFFFFF / 0x212121).
  core.Color _numberColor(double percentage) => percentage >= 0.5
      ? theme.cardBackgroundColor
      : theme.mediumContrastTextColor;
}

/// The Best streaks card: a title and a [StreakChartView] as tall as the
/// streaks it has to show.
class StreakCardView extends StatelessWidget {
  const StreakCardView({
    required this.state,
    this.dateFormatter,
    this.dateLabel,
    super.key,
  });

  final StreakCardState state;

  final core.LocalDateFormatter? dateFormatter;

  final String Function(core.LocalDate date)? dateLabel;

  /// show_habit_streak.xml gives the chart `wrap_content`, and
  /// `StreakChart.onMeasure` answers `streaks.size * baseSize`.
  double get chartHeight => state.bestStreaks.length * StreakChartView.baseSize;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ChartCard(
      theme: state.theme,
      title: l10n.bestStreaks,
      titleColor: state.theme.colorOf(state.color),
      child: SizedBox(
        height: chartHeight,
        width: double.infinity,
        child: CoreView(
          view: StreakChartView(
            streaks: state.bestStreaks,
            color: state.theme.colorOf(state.color),
            theme: state.theme,
            dateFormatter: dateFormatter ?? IntlLocalDateFormatter.of(context),
            dateLabel: dateLabel,
          ),
        ),
      ),
    );
  }
}
