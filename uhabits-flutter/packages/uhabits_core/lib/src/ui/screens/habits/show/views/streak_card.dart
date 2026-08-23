/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/StreakCart.kt
///
/// The Kotlin file name and the presenter class are both spelled "StreakCart"
/// upstream; the typo is preserved in the class name so the two trees grep
/// alike, while the Dart file takes the corrected name required by the slice.
///
/// The presenter is a one-liner: all the ordering work lives in
/// `StreakList.getBest`, which takes the ten longest streaks and then re-sorts
/// just those ten by end date.
library;

import '../../../../../gui/theme.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../models/streak.dart';

/// Port of the Kotlin `data class StreakCardState`.
class StreakCardState {
  const StreakCardState({
    required this.color,
    required this.bestStreaks,
    required this.theme,
  });

  final PaletteColor color;

  /// At most ten streaks, ordered newest-ending first.
  final List<Streak> bestStreaks;

  final Theme theme;

  @override
  bool operator ==(Object other) =>
      other is StreakCardState &&
      other.color == color &&
      _listEquals(other.bestStreaks, bestStreaks) &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(color, Object.hashAll(bestStreaks), theme);

  @override
  String toString() =>
      'StreakCardState(color=$color, bestStreaks=$bestStreaks, theme=$theme)';
}

/// Port of `class StreakCartPresenter`. It has no constructor parameters and no
/// screen callbacks: the card is not interactive.
class StreakCartPresenter {
  const StreakCartPresenter();

  static StreakCardState buildState(Habit habit, Theme theme) =>
      StreakCardState(
        color: habit.color,
        bestStreaks: habit.streaks.getBest(10),
        theme: theme,
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
