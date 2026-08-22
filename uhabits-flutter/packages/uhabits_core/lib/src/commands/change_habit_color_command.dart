import '../models/habit.dart';
import '../models/habit_list.dart';
import '../models/palette_color.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/ChangeHabitColorCommand.kt
///
/// The Kotlin declaration is, in full:
///
/// ```kotlin
/// data class ChangeHabitColorCommand(
///     val habitList: HabitList,
///     val selected: List<Habit>,
///     val newColor: PaletteColor
/// ) : Command {
///     override fun run() {
///         for (h in selected) h.color = newColor
///         habitList.update(selected)
///     }
/// }
/// ```
///
/// Three components, in the order habitList, selected, newColor. Every selected
/// habit ends up holding the identical [PaletteColor] instance, whatever its
/// previous colour was.
///
/// [newColor] is not validated: the default habit colour is `PaletteColor(8)`
/// and the colour picker hands back indices well above that (the Kotlin tests
/// use `PaletteColor(30)`), so nothing here clamps or range-checks the index.
class ChangeHabitColorCommand implements Command {
  ChangeHabitColorCommand(this.habitList, this.selected, this.newColor);

  final HabitList habitList;

  final List<Habit> selected;

  final PaletteColor newColor;

  /// Writes [newColor] onto every selected habit, then persists all of them
  /// with a single [HabitList.update] call.
  ///
  /// Only the `color` column changes: entries, scores, streaks and the archived
  /// state are untouched, and `Habit.recompute()` is not called.
  @override
  void run() {
    for (final h in selected) {
      h.color = newColor;
    }
    habitList.update(selected);
  }

  /// Kotlin's `data class` generates equals/hashCode/toString. `selected`
  /// compares element-wise, as `List.equals` does there; `habitList` compares
  /// by identity, since HabitList does not override equals.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChangeHabitColorCommand) return false;
    if (!identical(other.habitList, habitList)) return false;
    if (other.newColor != newColor) return false;
    if (other.selected.length != selected.length) return false;
    for (var i = 0; i < selected.length; i++) {
      if (other.selected[i] != selected[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(habitList),
        Object.hashAll(selected),
        newColor,
      );

  @override
  String toString() => 'ChangeHabitColorCommand(habitList=$habitList, '
      'selected=$selected, newColor=$newColor)';
}
