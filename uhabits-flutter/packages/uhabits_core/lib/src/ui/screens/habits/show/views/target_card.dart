/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/TargetCard.kt,
/// plus the row labels and the title colour of `TargetCardView.setState`
/// (uhabits-android/.../activities/habits/show/views/TargetCardView.kt).
///
/// `TargetChart` — the rounded bars, the "completed"/"remaining" texts and the
/// 300dp height — is an Android custom view and belongs to the widget layer.
library;

import 'dart:math' as math;

import '../../../../../gui/color.dart';
import '../../../../../gui/theme.dart';
import '../../../../../models/entry.dart';
import '../../../../../models/entry_list.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../time/local_date.dart';

/// Kotlin: `data class TargetCardState`. The three lists default to empty and
/// are always the same length: they are built by the same three `if` chains.
class TargetCardState {
  const TargetCardState({
    required this.color,
    this.values = const <double>[],
    this.targets = const <double>[],
    this.intervals = const <int>[],
    required this.theme,
  });

  final PaletteColor color;

  final List<double> values;

  final List<double> targets;

  final List<int> intervals;

  final Theme theme;

  /// `state.intervals.map { intervalToLabel(resources, it) }`.
  List<String> get labels => intervals.map(intervalToLabel).toList();

  /// `binding.title` and the filled part of every bar are tinted with the
  /// habit colour.
  Color get titleColor => theme.colorOf(color);

  /// `R.string.target`.
  static const String title = 'Target';

  /// Port of `TargetCardView.intervalToLabel`. Note the `else` branch: every
  /// interval that is not one of the first four — 365 included — is "Year".
  static String intervalToLabel(int interval) {
    switch (interval) {
      case 1:
        return 'Today';
      case 7:
        return 'Week';
      case 30:
        return 'Month';
      case 91:
        return 'Quarter';
      default:
        return 'Year';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TargetCardState &&
      other.color == color &&
      _listEquals(other.values, values) &&
      _listEquals(other.targets, targets) &&
      _listEquals(other.intervals, intervals) &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(color, Object.hashAll(values),
      Object.hashAll(targets), Object.hashAll(intervals), theme);

  @override
  String toString() => 'TargetCardState(color=$color, values=$values, '
      'targets=$targets, intervals=$intervals, theme=$theme)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class TargetCardPresenter {
  TargetCardPresenter._();

  static TargetCardState buildState({
    required Habit habit,
    required int firstWeekday,
    required Theme theme,
  }) {
    final today = getToday();
    // getKnown() is newest-first, so `lastOrNull` is the OLDEST known entry.
    final known = habit.computedEntries.getKnown();
    final oldest = known.isEmpty ? today : known.last.date;
    final entries = habit.computedEntries.getByInterval(oldest, today);

    // Both aggregations return their buckets newest-first, so `firstOrNull` is
    // the bucket that contains today.
    int firstValue(List<Entry> list) => list.isEmpty ? 0 : list.first.value;

    final valueToday = firstValue(entries.groupedSum(
      truncateField: TruncateField.day,
      isNumerical: habit.isNumerical,
    ));

    final skippedDayToday = firstValue(entries.countSkippedDays(
      truncateField: TruncateField.day,
    ));

    final valueThisWeek = firstValue(entries.groupedSum(
      truncateField: TruncateField.weekNumber,
      firstWeekday: firstWeekday,
      isNumerical: habit.isNumerical,
    ));

    final skippedDaysThisWeek = firstValue(entries.countSkippedDays(
      truncateField: TruncateField.weekNumber,
      firstWeekday: firstWeekday,
    ));

    final valueThisMonth = firstValue(entries.groupedSum(
      truncateField: TruncateField.month,
      isNumerical: habit.isNumerical,
    ));

    final skippedDaysThisMonth = firstValue(entries.countSkippedDays(
      truncateField: TruncateField.month,
    ));

    final valueThisQuarter = firstValue(entries.groupedSum(
      truncateField: TruncateField.quarter,
      isNumerical: habit.isNumerical,
    ));

    final skippedDaysThisQuarter = firstValue(entries.countSkippedDays(
      truncateField: TruncateField.quarter,
    ));

    final valueThisYear = firstValue(entries.groupedSum(
      truncateField: TruncateField.year,
      isNumerical: habit.isNumerical,
    ));

    final skippedDaysThisYear = firstValue(entries.countSkippedDays(
      truncateField: TruncateField.year,
    ));

    final daysInMonth = today.monthLength;
    const daysInWeek = 7;
    const daysInQuarter = 91;
    final daysInYear = today.yearLength;
    // Integer division, so this is 4 for every month length from 28 to 34.
    final weeksInMonth = daysInMonth ~/ 7;
    const weeksInQuarter = 13;
    const weeksInYear = 52;
    const monthsInQuarter = 3;
    const monthsInYear = 12;

    final denominator = habit.frequency.denominator;
    final dailyTarget = habit.targetValue / habit.frequency.denominator;

    var targetToday = dailyTarget;
    var targetThisWeek =
        denominator == 7 ? habit.targetValue : dailyTarget * daysInWeek;
    var targetThisMonth = denominator == 30
        ? habit.targetValue
        : denominator == 7
            ? habit.targetValue * weeksInMonth
            : dailyTarget * daysInMonth;
    var targetThisQuarter = denominator == 30
        ? habit.targetValue * monthsInQuarter
        : denominator == 7
            ? habit.targetValue * weeksInQuarter
            : dailyTarget * daysInQuarter;
    var targetThisYear = denominator == 30
        ? habit.targetValue * monthsInYear
        : denominator == 7
            ? habit.targetValue * weeksInYear
            : dailyTarget * daysInYear;

    targetToday = math.max(0.0, targetToday - dailyTarget * skippedDayToday);
    targetThisWeek =
        math.max(0.0, targetThisWeek - dailyTarget * skippedDaysThisWeek);
    targetThisMonth =
        math.max(0.0, targetThisMonth - dailyTarget * skippedDaysThisMonth);
    targetThisQuarter =
        math.max(0.0, targetThisQuarter - dailyTarget * skippedDaysThisQuarter);
    targetThisYear =
        math.max(0.0, targetThisYear - dailyTarget * skippedDaysThisYear);

    final values = <double>[];
    if (habit.frequency.denominator <= 1) values.add(valueToday / 1e3);
    if (habit.frequency.denominator <= 7) values.add(valueThisWeek / 1e3);
    values.add(valueThisMonth / 1e3);
    values.add(valueThisQuarter / 1e3);
    values.add(valueThisYear / 1e3);

    final targets = <double>[];
    if (habit.frequency.denominator <= 1) targets.add(targetToday);
    if (habit.frequency.denominator <= 7) targets.add(targetThisWeek);
    targets.add(targetThisMonth);
    targets.add(targetThisQuarter);
    targets.add(targetThisYear);

    final intervals = <int>[];
    if (habit.frequency.denominator <= 1) intervals.add(1);
    if (habit.frequency.denominator <= 7) intervals.add(7);
    intervals.add(30);
    intervals.add(91);
    intervals.add(365);

    return TargetCardState(
      color: habit.color,
      values: values,
      targets: targets,
      intervals: intervals,
      theme: theme,
    );
  }
}
