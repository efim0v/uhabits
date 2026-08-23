/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/FrequencyCard.kt
///
/// The weekday-by-month bubble chart. Note which entry list it reads: the
/// ORIGINAL entries, not the computed ones, so the YES_AUTO days a non-daily
/// frequency generates never appear here — not even as an empty month column.
library;

import '../../../../../gui/theme.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../time/local_date.dart';

/// Port of the Kotlin `data class FrequencyCardState`.
class FrequencyCardState {
  const FrequencyCardState({
    required this.color,
    required this.firstWeekday,
    required this.frequency,
    required this.theme,
    required this.isNumerical,
  });

  final PaletteColor color;

  final DayOfWeek firstWeekday;

  /// Keyed by the first day of the month; the value is a 7-element histogram
  /// indexed Saturday-first (0 = Saturday, 1 = Sunday, ... 6 = Friday).
  ///
  /// Kotlin types this `HashMap<LocalDate, Array<Int>>`, and `Array.equals` is
  /// identity — so two `FrequencyCardState`s built from equal data are never
  /// equal upstream. Dart's `List` has identity equality too, so [==] below
  /// reproduces that without any special casing.
  final Map<LocalDate, List<int>> frequency;

  final Theme theme;

  final bool isNumerical;

  @override
  bool operator ==(Object other) =>
      other is FrequencyCardState &&
      other.color == color &&
      other.firstWeekday == firstWeekday &&
      _mapEquals(other.frequency, frequency) &&
      other.theme == theme &&
      other.isNumerical == isNumerical;

  @override
  int get hashCode =>
      Object.hash(color, firstWeekday, frequency.length, theme, isNumerical);

  @override
  String toString() => 'FrequencyCardState(color=$color, '
      'firstWeekday=$firstWeekday, frequency=$frequency, theme=$theme, '
      'isNumerical=$isNumerical)';
}

/// Port of `class FrequencyCardPresenter`. Like the streak card it has no
/// constructor parameters and no screen callbacks.
class FrequencyCardPresenter {
  const FrequencyCardPresenter();

  static FrequencyCardState buildState({
    required Habit habit,
    required DayOfWeek firstWeekday,
    required Theme theme,
  }) =>
      FrequencyCardState(
        color: habit.color,
        isNumerical: habit.isNumerical,
        frequency: habit.originalEntries
            .computeWeekdayFrequency(isNumerical: habit.isNumerical),
        firstWeekday: firstWeekday,
        theme: theme,
      );
}

/// Kotlin `HashMap.equals`: same size, and for every key the values compare
/// equal — with `Array<Int>` that means reference identity.
bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    if (a[key] != b[key]) return false;
  }
  return true;
}
