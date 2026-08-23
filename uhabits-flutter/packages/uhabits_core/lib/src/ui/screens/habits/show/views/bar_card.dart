/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/BarCard.kt
///
/// Despite the name, this is the card the Android layout titles "History": one
/// bar per bucket, summing the computed entries in that bucket. Boolean and
/// numerical habits each get their own spinner and their own bucket table —
/// the boolean one deliberately has no Day option, because a boolean day is
/// either 0 or 1000 and a per-day bar chart would say nothing the calendar
/// does not already say.
library;

import '../../../../../gui/theme.dart';
import '../../../../../models/entry.dart';
import '../../../../../models/entry_list.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../preferences/preferences.dart';
import '../../../../../time/local_date.dart';
import 'score_card.dart';

/// Port of the Kotlin `data class BarCardState`.
class BarCardState {
  const BarCardState({
    required this.theme,
    required this.boolSpinnerPosition,
    required this.bucketSize,
    required this.color,
    required this.entries,
    required this.isNumerical,
    required this.numericalSpinnerPosition,
  });

  final Theme theme;

  /// Both spinner positions are always carried, whichever one the habit type
  /// actually uses; the Android view merely hides the other spinner.
  final int boolSpinnerPosition;

  final int bucketSize;

  final PaletteColor color;

  /// One entry per bucket, newest first. The value is the summed thousandths;
  /// the chart divides by 1000 when it plots.
  final List<Entry> entries;

  final bool isNumerical;

  final int numericalSpinnerPosition;

  @override
  bool operator ==(Object other) =>
      other is BarCardState &&
      other.theme == theme &&
      other.boolSpinnerPosition == boolSpinnerPosition &&
      other.bucketSize == bucketSize &&
      other.color == color &&
      _listEquals(other.entries, entries) &&
      other.isNumerical == isNumerical &&
      other.numericalSpinnerPosition == numericalSpinnerPosition;

  @override
  int get hashCode => Object.hash(
        theme,
        boolSpinnerPosition,
        bucketSize,
        color,
        Object.hashAll(entries),
        isNumerical,
        numericalSpinnerPosition,
      );

  @override
  String toString() => 'BarCardState(theme=$theme, '
      'boolSpinnerPosition=$boolSpinnerPosition, bucketSize=$bucketSize, '
      'color=$color, entries=$entries, isNumerical=$isNumerical, '
      'numericalSpinnerPosition=$numericalSpinnerPosition)';
}

/// Port of the nested Kotlin interface `BarCardPresenter.Screen`.
abstract interface class BarCardScreen {
  void updateWidgets();

  void refresh();
}

class BarCardPresenter {
  BarCardPresenter({required this.preferences, required this.screen});

  final Preferences preferences;

  final BarCardScreen screen;

  /// Day, Week, Month, Quarter, Year.
  static const List<int> numericalBucketSizes = <int>[1, 7, 31, 92, 365];

  /// Week, Month, Quarter, Year — no Day.
  static const List<int> boolBucketSizes = <int>[7, 31, 92, 365];

  /// [firstWeekday] is the 1-based `Preferences.firstWeekdayInt`.
  static BarCardState buildState({
    required Habit habit,
    required int firstWeekday,
    required int numericalSpinnerPosition,
    required int boolSpinnerPosition,
    required Theme theme,
  }) {
    final bucketSize = habit.isNumerical
        ? numericalBucketSizes[numericalSpinnerPosition]
        : boolBucketSizes[boolSpinnerPosition];
    final today = getToday();
    final known = habit.computedEntries.getKnown();
    final oldest = known.isEmpty ? today : known.last.date;
    final entries = habit.computedEntries.getByInterval(oldest, today).groupedSum(
          truncateField: ScoreCardPresenter.getTruncateField(bucketSize),
          firstWeekday: firstWeekday,
          isNumerical: habit.isNumerical,
        );
    return BarCardState(
      theme: theme,
      entries: entries,
      bucketSize: bucketSize,
      color: habit.color,
      isNumerical: habit.isNumerical,
      numericalSpinnerPosition: numericalSpinnerPosition,
      boolSpinnerPosition: boolSpinnerPosition,
    );
  }

  void onNumericalSpinnerPosition(int position) {
    preferences.barCardNumericalSpinnerPosition = position;
    screen.updateWidgets();
    screen.refresh();
  }

  void onBoolSpinnerPosition(int position) {
    preferences.barCardBoolSpinnerPosition = position;
    screen.updateWidgets();
    screen.refresh();
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
