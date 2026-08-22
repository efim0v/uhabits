import '../entry_list.dart';
import '../model_factory.dart';
import '../score_list.dart';
import '../streak_list.dart';
import 'memory_habit_list.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/memory/MemoryModelFactory.kt
///
/// Every collaborator it builds is the plain in-memory implementation: nothing
/// is persisted, and each call returns a brand-new instance.
class MemoryModelFactory extends ModelFactory {
  @override
  EntryList buildComputedEntries() => EntryList();

  @override
  EntryList buildOriginalEntries() => EntryList();

  @override
  MemoryHabitList buildHabitList() => MemoryHabitList();

  @override
  ScoreList buildScoreList() => ScoreList();

  @override
  StreakList buildStreakList() => StreakList();
}
