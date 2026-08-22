import '../models/habit.dart';
import '../models/habit_list.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/ArchiveHabitsCommand.kt
///
/// The Kotlin declaration is, in full:
///
/// ```kotlin
/// data class ArchiveHabitsCommand(
///     val habitList: HabitList,
///     val selected: List<Habit>
/// ) : Command {
///     override fun run() {
///         for (h in selected) h.isArchived = true
///         habitList.update(selected)
///     }
/// }
/// ```
///
/// Two components, in the order habitList, selected. [selected] is held by
/// reference, never copied: the command sees whatever that list holds when
/// [run] is finally called.
///
/// Despite the `Command` name there is no undo. Un-archiving is a separate
/// forward command the user issues explicitly (`UnarchiveHabitsCommand`).
class ArchiveHabitsCommand implements Command {
  ArchiveHabitsCommand(this.habitList, this.selected);

  final HabitList habitList;

  final List<Habit> selected;

  /// Sets `isArchived = true` on every selected habit, then persists all of
  /// them with a single [HabitList.update] call — not one call per habit.
  ///
  /// It touches nothing else: no entries, scores, streaks, colors, positions,
  /// reminders or names, and it never calls `Habit.recompute()`. Archiving an
  /// already-archived habit is a no-op on the flag but still performs the
  /// update, and an empty [selected] still calls `update(<Habit>[])`, which
  /// still resorts the list and notifies its observable.
  @override
  void run() {
    for (final h in selected) {
      h.isArchived = true;
    }
    habitList.update(selected);
  }

  /// Kotlin's `data class` generates equals/hashCode/toString. `selected`
  /// compares element-wise, as `List.equals` does there; `habitList` compares
  /// by identity, since HabitList does not override equals.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArchiveHabitsCommand) return false;
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
      'ArchiveHabitsCommand(habitList=$habitList, selected=$selected)';
}
