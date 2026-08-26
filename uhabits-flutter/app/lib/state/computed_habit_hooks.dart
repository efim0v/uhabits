// The command types are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches CommandRunner itself: the core library's
// barrel only re-exports its models, database, time and drawing layers.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// The lifecycle a computed habit has and a ported one does not.
///
/// A habit whose day value the app computes owns things outside the habit
/// list: a question armed with the system, rows in tables of its own. Nothing
/// in the ported command layer knows they exist, so a deleted habit used to
/// leave its question standing — and a question that fires for a habit that is
/// gone walks into `getById(habitId)!`.
///
/// A listener rather than a call at each site: deletion and archiving each
/// have several entry points, and a rule spread across them is a rule that
/// will be carried to some and not the rest.
class ComputedHabitHooks implements CommandRunnerListener {
  ComputedHabitHooks({required void Function(Habit) cancelPrompt})
      : _cancelPrompt = cancelPrompt;

  final void Function(Habit) _cancelPrompt;

  @override
  void onCommandFinished(Command command) {
    // Un-archiving deliberately withdraws nothing: the next sync arms the
    // question again, and cancelling here would race it.
    final List<Habit> gone = switch (command) {
      DeleteHabitsCommand(:final List<Habit> selected) => selected,
      ArchiveHabitsCommand(:final List<Habit> selected) => selected,
      _ => const <Habit>[],
    };
    for (final Habit habit in gone) {
      if (habit.id != null) _cancelPrompt(habit);
    }
  }
}
