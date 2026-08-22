/// Factory that provides models backed by an SQLite database.
///
/// Ported line by line from
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/sqlite/SQLModelFactory.kt`.
library;

import '../../database/database.dart';
import '../../database/entry_repository.dart';
import '../../database/habit_repository.dart';
import '../entry_list.dart';
import '../model_factory.dart';
import '../score_list.dart';
import '../streak_list.dart';
import 'sqlite_entry_list.dart';
import 'sqlite_habit_list.dart';

/// The single seam between the model and the database.
///
/// It owns exactly one [HabitRepository] and one [EntryRepository], both built
/// over the same [Database] and shared by everything it builds: every
/// [SQLiteEntryList] handed out by [buildOriginalEntries] writes through the
/// same `Repetitions` table, and every [SQLiteHabitList] reads the same
/// `Habits` table.
///
/// Only the *original* entries are database-backed. Scores, streaks and the
/// computed entries are recomputed from them on demand and never persisted.
///
/// Kotlin builds both repositories in property initializers, so they are
/// created eagerly with the factory; the prepared statements inside them are
/// still lazy.
class SQLModelFactory extends ModelFactory {
  SQLModelFactory(this.database)
      : habitRepository = HabitRepository(database),
        entryRepository = EntryRepository(database);

  final Database database;

  final HabitRepository habitRepository;

  final EntryRepository entryRepository;

  @override
  EntryList buildOriginalEntries() => SQLiteEntryList(entryRepository);

  @override
  EntryList buildComputedEntries() => EntryList();

  @override
  SQLiteHabitList buildHabitList() => SQLiteHabitList(this);

  @override
  ScoreList buildScoreList() => ScoreList();

  @override
  StreakList buildStreakList() => StreakList();
}
