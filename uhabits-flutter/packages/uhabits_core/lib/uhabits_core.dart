/// Pure Dart core of Loop Habit Tracker.
///
/// Ported one to one from the Kotlin `uhabits-core` module. This library must
/// never depend on Flutter — see test/no_flutter_dependency_test.dart — so that
/// its tests run under plain `dart test` and the same code can later drive a
/// background sync isolate and a parity-checking CLI.
library;

// Dates
export 'src/time/local_date.dart';

// Domain model
export 'src/models/entry.dart';
export 'src/models/entry_list.dart';
export 'src/models/frequency.dart';
export 'src/models/habit.dart';
export 'src/models/habit_list.dart';
export 'src/models/habit_matcher.dart';
export 'src/models/habit_type.dart';
export 'src/models/memory/memory_habit_list.dart';
export 'src/models/memory/memory_model_factory.dart';
export 'src/models/model_factory.dart';
export 'src/models/model_observable.dart';
export 'src/models/palette_color.dart';
export 'src/models/reminder.dart';
export 'src/models/score.dart';
export 'src/models/score_list.dart';
export 'src/models/streak.dart';
export 'src/models/streak_list.dart';
export 'src/models/weekday_list.dart';

// Persistence
export 'src/database/database.dart';
export 'src/database/entry_repository.dart';
export 'src/database/habit_repository.dart';
export 'src/database/migrations.g.dart';
export 'src/database/extension_migrations.dart';
export 'src/database/sql_parser.dart';
export 'src/database/sqlite3_database.dart';

// Drawing and theming
export 'src/gui/canvas.dart';
export 'src/gui/color.dart';
export 'src/gui/font_awesome.dart';
export 'src/gui/image.dart';
export 'src/gui/theme.dart';
export 'src/gui/view.dart';
export 'src/sleep/sleep_data_source.dart';
export 'src/sleep/sleep_episode.dart';
export 'src/sleep/sleep_episode_merger.dart';
export 'src/sleep/local_instant.dart';
export 'src/sleep/sleep_goal.dart';
export 'src/sleep/sleep_importer.dart';
export 'src/sleep/sleep_scorer.dart';
export 'src/sleep/sleep_segment.dart';
export 'src/sleep/sleep_session_repository.dart';
export 'src/sleep/sleep_stability.dart';
export 'src/sleep/stored_value.dart';
export 'src/sleep/timezone_drift.dart';
export 'src/sleep/sleep_sync.dart';
export 'src/sleep/sleep_reminder.dart';
export 'src/sleep/sleep_suggestions.dart';

// Computed habits
export 'src/computed/abstinence_payload.dart';
export 'src/computed/day_writer.dart';
export 'src/computed/days_without_lapse.dart';
export 'src/computed/definition_repository.dart';
export 'src/computed/habit_definition.dart';
export 'src/computed/lapse_day_value.dart';
export 'src/computed/lapse_repository.dart';
export 'src/computed/lapse_scoring.dart';
