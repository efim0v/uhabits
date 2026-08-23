/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/ScoreCard.kt
///
/// The score card's whole job is bucketing: it takes the habit's one-score-per-
/// day series and collapses it into day, week, month, quarter or year buckets,
/// each carrying the arithmetic mean of its days. The chart that draws the
/// result is an Android view upstream and a Flutter widget here; neither is
/// part of this file.
library;

import '../../../../../gui/theme.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../models/score.dart';
import '../../../../../preferences/preferences.dart';
import '../../../../../time/local_date.dart';

/// Port of the Kotlin `data class ScoreCardState`.
class ScoreCardState {
  const ScoreCardState({
    required this.scores,
    required this.bucketSize,
    required this.spinnerPosition,
    required this.color,
    required this.theme,
  });

  /// One entry per bucket, NEWEST bucket first.
  final List<Score> scores;

  /// One of [ScoreCardPresenter.bucketSizes].
  final int bucketSize;

  final int spinnerPosition;

  final PaletteColor color;

  final Theme theme;

  @override
  bool operator ==(Object other) =>
      other is ScoreCardState &&
      _listEquals(other.scores, scores) &&
      other.bucketSize == bucketSize &&
      other.spinnerPosition == spinnerPosition &&
      other.color == color &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(scores),
        bucketSize,
        spinnerPosition,
        color,
        theme,
      );

  @override
  String toString() => 'ScoreCardState(scores=$scores, '
      'bucketSize=$bucketSize, spinnerPosition=$spinnerPosition, '
      'color=$color, theme=$theme)';
}

/// Port of the nested Kotlin interface `ScoreCardPresenter.Screen`. Dart has no
/// nested types, so the name is flattened the same way
/// `ListHabitsBehavior.Screen` became `ListHabitsBehaviorScreen`. The widget
/// layer implements it.
abstract interface class ScoreCardScreen {
  void updateWidgets();

  void refresh();
}

class ScoreCardPresenter {
  ScoreCardPresenter({required this.preferences, required this.screen});

  final Preferences preferences;

  final ScoreCardScreen screen;

  /// Kotlin: `val BUCKET_SIZES = intArrayOf(1, 7, 31, 92, 365)`, indexed by the
  /// spinner position 0..4 (Day, Week, Month, Quarter, Year). The labels
  /// themselves are a localized Android string array and belong to the widget
  /// layer.
  static const List<int> bucketSizes = <int>[1, 7, 31, 92, 365];

  /// Note the `else` branch: any bucket size that is not one of
  /// [bucketSizes] truncates by MONTH rather than throwing.
  static TruncateField getTruncateField(int bucketSize) {
    switch (bucketSize) {
      case 1:
        return TruncateField.day;
      case 7:
        return TruncateField.weekNumber;
      case 31:
        return TruncateField.month;
      case 92:
        return TruncateField.quarter;
      case 365:
        return TruncateField.year;
      default:
        return TruncateField.month;
    }
  }

  /// [firstWeekday] is the 1-based `Preferences.firstWeekdayInt`
  /// (1 == Sunday .. 7 == Saturday), exactly as the Kotlin signature takes it.
  static ScoreCardState buildState({
    required Habit habit,
    required int firstWeekday,
    required int spinnerPosition,
    required Theme theme,
  }) {
    final bucketSize = bucketSizes[spinnerPosition];
    final today = getToday();
    final known = habit.computedEntries.getKnown();
    final oldest = known.isEmpty ? today : known.last.date;

    // Kotlin: groupBy { … }.map { … }.sortedBy { it.date }.reversed().
    // groupBy is a LinkedHashMap, so the pre-sort order is first-seen order;
    // the explicit sort makes that irrelevant.
    final groups = <LocalDate, List<Score>>{};
    for (final score in habit.scores.getByInterval(oldest, today)) {
      final key = _truncateDate(getTruncateField(bucketSize), score.date,
          firstWeekday);
      (groups[key] ??= <Score>[]).add(score);
    }
    final scores = groups.entries
        .map((MapEntry<LocalDate, List<Score>> e) =>
            Score(e.key, _average(e.value.map((Score s) => s.value))))
        .toList()
      ..sort((Score a, Score b) => a.date.compareTo(b.date));

    return ScoreCardState(
      color: habit.color,
      scores: scores.reversed.toList(),
      bucketSize: bucketSize,
      spinnerPosition: spinnerPosition,
      theme: theme,
    );
  }

  /// Kotlin's private `truncateDate`. `firstWeekday` is 1 == Sunday .. 7 ==
  /// Saturday, and `DayOfWeek.entries` is SUNDAY(0) .. SATURDAY(6), hence the
  /// `- 1`.
  static LocalDate _truncateDate(
    TruncateField field,
    LocalDate date,
    int firstWeekday,
  ) {
    final firstWeekdayDow = DayOfWeek.values[firstWeekday - 1];
    switch (field) {
      case TruncateField.weekNumber:
        return date.startOfWeek(firstWeekdayDow);
      case TruncateField.month:
        return date.startOfMonth();
      case TruncateField.quarter:
        return date.startOfQuarter();
      case TruncateField.year:
        return date.startOfYear();
      case TruncateField.day:
        return date;
    }
  }

  /// Writes the preference first, so the widgets and the screen both read the
  /// new value. Nothing is deduplicated: selecting the position that is already
  /// selected runs the whole sequence again, which is exactly what the Android
  /// spinner does when `setSelection` fires its own listener during setState.
  void onSpinnerPosition(int position) {
    preferences.scoreCardSpinnerPosition = position;
    screen.updateWidgets();
    screen.refresh();
  }
}

/// Kotlin `Iterable<Double>.average()`: the running sum divided by the count.
/// An empty group is impossible here — `groupBy` never yields one.
double _average(Iterable<double> values) {
  var sum = 0.0;
  var count = 0;
  for (final value in values) {
    sum += value;
    count++;
  }
  return sum / count;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
