import '../models/habit.dart';
import '../models/habit_list.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/EditHabitCommand.kt
///
/// Kotlin declares this as
/// `data class EditHabitCommand(habitList, habitId, modified) : Command`, so
/// the field order below is also the destructuring component order.
///
/// This is the only command that can throw a domain exception: when
/// `habitList.getById(habitId)` finds nothing, `run()` throws
/// [HabitNotFoundException] before touching anything. Since `CommandRunner`
/// wraps `run()` in a task with no try/catch, that means `onPostExecute` is
/// never reached, no listener is notified and no toast is shown — the exception
/// escapes the coroutine.
///
/// [modified] is only a value carrier and is never inserted into the list; the
/// stored instance is edited in place. `Habit.copyFrom` does not copy the id
/// but does copy position and uuid, which is why callers build [modified] by
/// first doing `modified.copyFrom(original)`.
class EditHabitCommand implements Command {
  EditHabitCommand(this.habitList, this.habitId, this.modified);

  final HabitList habitList;

  final int habitId;

  final Habit modified;

  @override
  void run() {
    final habit = habitList.getById(habitId);
    if (habit == null) throw HabitNotFoundException();
    habit.copyFrom(modified);
    // Kotlin's `habitList.update(habit)` is the single-habit overload, which
    // delegates to `update(listOf(habit))`; Dart has no overloads, so the
    // port spells it `updateOne`.
    habitList.updateOne(habit);
    habit.observable.notifyListeners();
    habit.recompute();
    // Re-sorting last means score-based orderings see the fresh scores.
    habitList.resort();
  }

  @override
  bool operator ==(Object other) =>
      other is EditHabitCommand &&
      identical(other.habitList, habitList) &&
      other.habitId == habitId &&
      other.modified == modified;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(habitList), habitId, modified);

  @override
  String toString() => 'EditHabitCommand(habitList=$habitList, '
      'habitId=$habitId, modified=$modified)';
}
