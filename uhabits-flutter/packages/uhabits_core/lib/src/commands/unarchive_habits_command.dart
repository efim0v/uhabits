import '../models/habit.dart';
import '../models/habit_list.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/UnarchiveHabitsCommand.kt
///
/// The Kotlin declaration is, in full:
///
/// ```kotlin
/// data class UnarchiveHabitsCommand(
///     val habitList: HabitList,
///     val selected: List<Habit>
/// ) : Command {
///     override fun run() {
///         for (h in selected) h.isArchived = false
///         habitList.update(selected)
///     }
/// }
/// ```
///
/// The exact structural mirror of `ArchiveHabitsCommand` — same two components
/// in the same order, same loop, same single update — differing only in the
/// boolean written. It is nevertheless NOT wired as an undo of it: `Command`
/// has no undo, no history is kept, and both are ordinary forward commands the
/// user invokes from the selection menu or the habit detail menu.
class UnarchiveHabitsCommand implements Command {
  UnarchiveHabitsCommand(this.habitList, this.selected);

  final HabitList habitList;

  final List<Habit> selected;

  /// Sets `isArchived = false` on every selected habit, then persists all of
  /// them with a single [HabitList.update] call.
  ///
  /// Unarchiving is idempotent and touches nothing else on the habit: no
  /// entries, scores, streaks, colors, positions, reminders or names, and no
  /// `Habit.recompute()`.
  @override
  void run() {
    for (final h in selected) {
      h.isArchived = false;
    }
    habitList.update(selected);
  }

  /// Kotlin's `data class` generates equals/hashCode/toString. `selected`
  /// compares element-wise, as `List.equals` does there; `habitList` compares
  /// by identity, since HabitList does not override equals.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! UnarchiveHabitsCommand) return false;
    if (!identical(other.habitList, habitList)) return false;
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
      );

  @override
  String toString() =>
      'UnarchiveHabitsCommand(habitList=$habitList, selected=$selected)';
}
