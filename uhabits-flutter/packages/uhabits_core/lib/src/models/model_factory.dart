import 'entry_list.dart';
import 'habit.dart';
import 'habit_list.dart';
import 'score_list.dart';
import 'streak_list.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ModelFactory.kt
///
/// Interface implemented by factories that provide concrete implementations of
/// the core model classes.
///
/// Kotlin declares this as an `interface` whose `buildHabit()` carries a default
/// body. Dart interfaces cannot carry bodies, so this is an abstract class with
/// five abstract methods and one concrete one; implementors `extends` it (or
/// `implements` it and re-supply [buildHabit]).
abstract class ModelFactory {
  /// The derived entries, recomputed from [buildOriginalEntries] by
  /// `Habit.recompute()`. Never edited by the user directly.
  EntryList buildComputedEntries();

  /// The entries the user actually enters.
  EntryList buildOriginalEntries();

  HabitList buildHabitList();

  ScoreList buildScoreList();

  StreakList buildStreakList();

  /// Builds a habit whose four collaborators are freshly built by this factory.
  /// Every other field takes its declared default, so the habit gets a fresh
  /// random uuid.
  Habit buildHabit() {
    final scores = buildScoreList();
    final streaks = buildStreakList();
    return Habit(
      scores: scores,
      streaks: streaks,
      originalEntries: buildOriginalEntries(),
      computedEntries: buildComputedEntries(),
    );
  }
}
