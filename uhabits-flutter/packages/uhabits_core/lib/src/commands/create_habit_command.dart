import '../models/habit.dart';
import '../models/habit_list.dart';
import '../models/model_factory.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateHabitCommand.kt
///
/// Kotlin declares this as
/// `data class CreateHabitCommand(modelFactory, habitList, model) : Command`,
/// so the field order below is also the destructuring component order.
///
/// [model] is only a template. `run()` builds a brand-new [Habit] from the
/// factory and copies the template's fields into it, so the template itself
/// never enters the list and mutating it afterwards changes nothing. Because
/// `Habit.copyFrom` copies neither entries nor scores nor streaks, the created
/// habit starts empty; callers that need entries (LoopDBImporter) add them
/// afterwards.
class CreateHabitCommand implements Command {
  CreateHabitCommand(this.modelFactory, this.habitList, this.model);

  final ModelFactory modelFactory;

  final HabitList habitList;

  final Habit model;

  @override
  void run() {
    final habit = modelFactory.buildHabit();
    habit.copyFrom(model);
    habitList.add(habit);
    habit.recompute();
  }

  @override
  bool operator ==(Object other) =>
      other is CreateHabitCommand &&
      identical(other.modelFactory, modelFactory) &&
      identical(other.habitList, habitList) &&
      other.model == model;

  @override
  int get hashCode => Object.hash(
        identityHashCode(modelFactory),
        identityHashCode(habitList),
        model,
      );

  @override
  String toString() => 'CreateHabitCommand(modelFactory=$modelFactory, '
      'habitList=$habitList, model=$model)';
}
