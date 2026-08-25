/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/OverviewCard.kt,
/// plus the formatting and colour decisions of `OverviewCardView.setState`
/// (uhabits-android/.../activities/habits/show/views/OverviewCardView.kt).
///
/// The ring geometry and the row weights stay with the widget layer: they are
/// `RingView` attributes and layout parameters, not behaviour.
library;

import '../../../../../gui/color.dart';
import '../../../../../gui/theme.dart';
import '../../../../../io/printf.dart';
import '../../../../../models/entry.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../time/local_date.dart';

/// Kotlin: `data class OverviewCardState`.
///
/// Kotlin types the three scores as `Float` and the count as `Long`; Dart has
/// neither, so they are `double` and `int`. The only visible consequence is
/// precision: a Float would round 0.005 to 0.004999999888, while this port
/// keeps the double and therefore prints the "1%" the ledger describes.
class OverviewCardState {
  const OverviewCardState({
    required this.color,
    required this.scoreMonthDiff,
    required this.scoreYearDiff,
    required this.scoreToday,
    required this.totalCount,
    required this.theme,
  });

  final PaletteColor color;

  final double scoreMonthDiff;

  final double scoreYearDiff;

  final double scoreToday;

  final int totalCount;

  final Theme theme;

  // -------------------------------------------------------------------------
  // OverviewCardView.setState
  // -------------------------------------------------------------------------

  /// `String.format("%.0f%%", state.scoreToday * 100)`.
  String get scoreText => format('%.0f%%', scoreToday * 100);

  String get monthDiffText => formatPercentageDiff(scoreMonthDiff);

  String get yearDiffText => formatPercentageDiff(scoreYearDiff);

  /// `state.totalCount.toString()` — no abbreviation and no digit grouping.
  String get totalCountText => totalCount.toString();

  /// The title, the score label and the total-count label are always tinted
  /// with the habit colour.
  Color get titleColor => theme.colorOf(color);

  Color get scoreColor => theme.colorOf(color);

  Color get totalCountColor => theme.colorOf(color);

  /// The four captions use `?attr/contrast60`, which is grey_500 in every
  /// Android theme — the same value the core theme calls
  /// [Theme.mediumContrastTextColor].
  Color get captionColor => theme.mediumContrastTextColor;

  /// A non-negative diff (zero included) keeps the habit colour; a negative
  /// one falls back to contrast60.
  Color get monthDiffColor => diffColor(scoreMonthDiff);

  Color get yearDiffColor => diffColor(scoreYearDiff);

  Color diffColor(double diff) =>
      diff >= 0 ? theme.colorOf(color) : theme.mediumContrastTextColor;

  /// Port of `OverviewCardView.formatPercentageDiff`:
  /// `String.format("%s%.0f%%", if (diff >= 0) "+" else "−",
  /// abs(diff) * 100)`.
  ///
  /// The negative sign is U+2212 MINUS SIGN, not an ASCII hyphen.
  static String formatPercentageDiff(double percentageDiff) {
    final sign = percentageDiff >= 0 ? '+' : '−';
    return '$sign${format('%.0f%%', percentageDiff.abs() * 100)}';
  }

  /// The four caption labels of the row, left to right, as declared by
  /// show_habit_overview.xml.
  static const List<String> captions = <String>[
    'Score',
    'Month',
    'Year',
    'Total',
  ];

  @override
  bool operator ==(Object other) =>
      other is OverviewCardState &&
      other.color == color &&
      other.scoreMonthDiff == scoreMonthDiff &&
      other.scoreYearDiff == scoreYearDiff &&
      other.scoreToday == scoreToday &&
      other.totalCount == totalCount &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(
      color, scoreMonthDiff, scoreYearDiff, scoreToday, totalCount, theme);

  @override
  String toString() => 'OverviewCardState(color=$color, '
      'scoreMonthDiff=$scoreMonthDiff, scoreYearDiff=$scoreYearDiff, '
      'scoreToday=$scoreToday, totalCount=$totalCount, theme=$theme)';
}

class OverviewCardPresenter {
  OverviewCardPresenter._();

  /// [counts] is not upstream: given a day's entry it answers whether that day
  /// belongs in the total. Null for every habit the original knows, which
  /// leaves the count exactly as it was — the days marked done by hand.
  ///
  /// A habit whose days carry a measurement has no such value: nothing it ever
  /// stores equals [Entry.yesManual], so the total would read zero for ever.
  static OverviewCardState buildState({
    required Habit habit,
    required Theme theme,
    bool Function(Entry)? counts,
  }) {
    final today = getToday();
    final lastMonth = today.minus(30);
    final lastYear = today.minus(365);
    final scores = habit.scores;
    // ScoreList returns Score(date, 0.0) for any date it has not computed, so
    // a habit younger than a year simply reports a zero year-ago score.
    final scoreToday = scores[today].value;
    final scoreLastMonth = scores[lastMonth].value;
    final scoreLastYear = scores[lastYear].value;
    // The ORIGINAL entries, so the YES_AUTO days the computed list fills in
    // for non-daily habits are not counted.
    final totalCount = habit.originalEntries
        .getKnown()
        .where(counts ?? (Entry it) => it.value == Entry.yesManual)
        .length;
    return OverviewCardState(
      color: habit.color,
      scoreToday: scoreToday,
      scoreMonthDiff: scoreToday - scoreLastMonth,
      scoreYearDiff: scoreToday - scoreLastYear,
      totalCount: totalCount,
      theme: theme,
    );
  }
}
