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

  /// [lengthOf] не из порта: он отвечает, сколько дней показывать за серию.
  /// Null у всякой привычки, которую знает оригинал, и тогда длина берётся
  /// у самой серии, включительным счётом. Воздержание передаёт своё:
  /// длительность есть прошедшие полные сутки (`computed.streak#8`).
  static StreakCardState buildState(
    Habit habit,
    Theme theme, {
    int Function(Streak)? lengthOf,
  }) {
    final List<Streak> best = habit.streaks.getBest(10);
    return StreakCardState(
      color: habit.color,
      // A finished streak's own length already is the elapsed time
      // (`computed.streak#8`), so this reshapes nothing for it: start stays
      // put and the replacement end lands exactly where the real one was.
      // Only the one streak still running — the one whose count `lengthOf`
      // actually shortens — gets a different end date here.
      bestStreaks: lengthOf == null
          ? best
          : best
              .map((Streak s) => Streak(s.start, s.start.plus(lengthOf(s) - 1)))
              .toList(),
      theme: theme,
    );
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
