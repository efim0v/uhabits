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
    this.lengths,
  });

  final PaletteColor color;

  /// At most ten streaks, ordered newest-ending first. Real streaks, start and
  /// end dates included: [lengths] is where a different count lives, and
  /// nothing here ever gets reshaped to fit it.
  final List<Streak> bestStreaks;

  final Theme theme;

  /// How many days to show for each streak of [bestStreaks], parallel to it,
  /// or null — every habit the original knows — to show each streak's own
  /// `Streak.length`, the inclusive count. Not upstream.
  ///
  /// A number, not a function: the state needs `==`, and a closure would
  /// break it. Kept apart from [bestStreaks] on purpose, so a shorter count
  /// for a running streak can never smuggle in a different end date — the
  /// two are true independently, and the card's job is to print both, not to
  /// reconcile them into one (`computed.streak#8`).
  final List<int>? lengths;

  @override
  bool operator ==(Object other) =>
      other is StreakCardState &&
      other.color == color &&
      _listEquals(other.bestStreaks, bestStreaks) &&
      other.theme == theme &&
      _nullableListEquals(other.lengths, lengths);

  @override
  int get hashCode => Object.hash(
        color,
        Object.hashAll(bestStreaks),
        theme,
        lengths == null ? null : Object.hashAll(lengths!),
      );

  @override
  String toString() => 'StreakCardState(color=$color, '
      'bestStreaks=$bestStreaks, theme=$theme, lengths=$lengths)';
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
      bestStreaks: best,
      lengths: lengthOf == null
          ? null
          : best.map(lengthOf).toList(growable: false),
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

bool _nullableListEquals<T>(List<T>? a, List<T>? b) {
  if (a == null || b == null) return a == b;
  return _listEquals(a, b);
}
