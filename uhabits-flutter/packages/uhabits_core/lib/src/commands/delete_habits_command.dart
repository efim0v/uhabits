import '../models/habit.dart';
import '../models/habit_list.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/DeleteHabitsCommand.kt
///
/// Kotlin declares this as
/// `data class DeleteHabitsCommand(habitList, selected) : Command`, so the
/// field order below is also the destructuring component order.
///
/// `run()` is a single loop: one `habitList.remove(h)` per selected habit, in
/// the order the list was given. There is no batching and no transaction, and
/// no copy of the habit or of its entries is retained anywhere — deletion is
/// permanent and nothing can restore it. An empty [selected] list makes `run()`
/// a complete no-op, but `CommandRunner` still notifies all listeners
/// afterwards.
class DeleteHabitsCommand implements Command {
  DeleteHabitsCommand(this.habitList, this.selected);

  final HabitList habitList;

  final List<Habit> selected;

  @override
  void run() {
    for (final h in selected) {
      habitList.remove(h);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DeleteHabitsCommand &&
      identical(other.habitList, habitList) &&
      _sameHabits(other.selected, selected);

  @override
  int get hashCode =>
      Object.hash(identityHashCode(habitList), Object.hashAll(selected));

  @override
  String toString() =>
      'DeleteHabitsCommand(habitList=$habitList, selected=$selected)';

  /// Kotlin's `List.equals` is structural; Dart's is identity, so the
  /// element-wise comparison is spelled out.
  static bool _sameHabits(List<Habit> a, List<Habit> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
