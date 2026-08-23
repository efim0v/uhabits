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
/// One upstream oddity is kept verbatim: [maxLabelWidth] is a *field*, and
/// `updateMaxMinLengths` never resets it, so within one view instance it only
/// ever grows (`charts-canvas-theming.streak-chart#13`). The card builds a
/// fresh view on every frame, so the app never sees the stale value; a caller
/// that reuses one instance across two streak lists does.
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

  /// ```kotlin
  /// val maxStreakCount: Int
  ///     get() = floor((measuredHeight / baseSize).toDouble()).toInt()
  /// ```
  ///
  /// "The maximum number of streaks this view is able to show, given its
  /// current size" — exposed so the caller can decide how many streaks to
  /// fetch (`charts-canvas-theming.streak-chart#3`). Both operands are `Int`
  /// upstream, so the division already truncates and `floor` changes nothing.
  static int maxStreakCount(double measuredHeight) =>
      measuredHeight ~/ baseSize;

  /// `private var maxLabelWidth = 0f`.
  ///
  /// Public because it is observable state, not a local: see the class doc.
  double maxLabelWidth = 0.0;

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

    // updateMaxMinLengths. `maxLength` is reset here and `maxLabelWidth` is
    // not (`charts-canvas-theming.streak-chart#13`).
    var maxLength = 0;
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
    // The one place the field *is* cleared (`charts-canvas-theming.streak-chart#12`).
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

  /// `initColors`' four-entry bar ramp
  /// (`charts-canvas-theming.streak-chart#14`):
  ///
  /// ```kotlin
  /// colors[3] = primaryColor
  /// colors[2] = Color.argb(192, red, green, blue)
  /// colors[1] = Color.argb(96, red, green, blue)
  /// colors[0] = res.getColor(R.attr.contrast20)
  /// ```
  ///
  /// The three habit-coloured entries keep the primary colour's red, green
  /// and blue and differ only in alpha — 255, 192 and 96 — so the ramp is the
  /// habit colour fading out, with the grid colour at the bottom.
  List<core.Color> get colors => <core.Color>[
        theme.lowContrastTextColor,
        color.withAlpha(96 / 255),
        color.withAlpha(192 / 255),
        color,
      ];

  /// `initColors`' three-entry text ramp: contrast80, contrast60, contrast0 at
  /// 0, 1 and 2 (`charts-canvas-theming.streak-chart#14`).
  ///
  /// Index 0 is dead weight — `percentageToTextColor` only ever picks 1 or 2 —
  /// and is kept so the ramp matches the Kotlin entry for entry. The ported
  /// [core.Theme] has neither a contrast80 nor a contrast0 token: their
  /// nearest neighbours are the high-contrast text colour (0x202020 light
  /// against Android's 0x616161) and the card background (0xFAFAFA light
  /// against Android's 0xFFFFFF).
  List<core.Color> get textColors => <core.Color>[
        theme.highContrastTextColor,
        theme.mediumContrastTextColor,
        theme.cardBackgroundColor,
      ];

  /// `percentageToColor`: the habit colour, then the same colour at alpha 192
  /// and 96, then contrast20 — [core.Theme.lowContrastTextColor].
  core.Color _barColor(double percentage) {
    final ramp = colors;
    if (percentage >= 1.0) return ramp[3];
    if (percentage >= 0.8) return ramp[2];
    if (percentage >= 0.5) return ramp[1];
    return ramp[0];
  }

  /// `percentageToTextColor`: contrast0 over a filled bar, contrast60
  /// otherwise.
  core.Color _numberColor(double percentage) =>
      percentage >= 0.5 ? textColors[2] : textColors[1];

  /// ```kotlin
  /// fun populateWithRandomData() {
  ///     var start = getToday()
  ///     val streaks: MutableList<Streak> = LinkedList()
  ///     for (i in 0..9) {
  ///         val length = Random().nextInt(100)
  ///         val end = start.plus(length)
  ///         streaks.add(Streak(start, end))
  ///         start = end.plus(1)
  ///     }
  ///     setStreaks(streaks)
  /// }
  /// ```
  ///
  /// Ten consecutive streaks of random length 0..99, the first starting today
  /// and each one beginning the day after the previous ends
  /// (`charts-canvas-theming.streak-chart#15`). Kotlin builds a fresh
  /// `java.util.Random` per iteration and installs the result on the view;
  /// this returns the list instead, because the Dart view takes its streaks in
  /// the constructor, and takes the generator as a seam so a test can pin it.
  static List<core.Streak> populateWithRandomData({math.Random? random}) {
    final rand = random ?? math.Random();
    var start = core.getToday();
    final streaks = <core.Streak>[];
    for (var i = 0; i <= 9; i++) {
      final length = rand.nextInt(100);
      final end = start.plus(length);
      streaks.add(core.Streak(start, end));
      start = end.plus(1);
    }
    return streaks;
  }
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
