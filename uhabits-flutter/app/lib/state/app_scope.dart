// The core library only re-exports its models, database, time and drawing
// layers; the commands, preferences, tasks and presenters this file wires are
// still reached by their `src` path, exactly as the slice brief describes.
// ignore_for_file: implementation_imports

import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_adapter.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';
import 'package:uhabits_core/uhabits_core.dart';

import '../platform/app_database.dart';
import '../platform/file_preferences_storage.dart';

/// The long-lived objects of the application, built once and shared by every
/// screen.
///
/// Port of the `@AppScope` half of `HabitsApplicationComponent` plus the
/// startup sequence of `HabitsApplication.onCreate`:
///
///  1. the database file is opened and migrated,
///  2. the model factory and the habit list are built on top of it,
///  3. `setToday(computeToday(midnightDelayHours, 0))` is called — before
///     anything reads a habit, because `getToday()` throws until it has been,
///  4. every habit is recomputed,
///  5. the task runner, command runner, midnight timer, list cache and list
///     adapter are wired together.
///
/// The Android app builds the [HabitCardListAdapter] per activity
/// (`@ActivityScope`) while the [HabitCardListCache] is application scoped.
/// Flutter has a single activity, so both live here and the screen attaches
/// and detaches the adapter as it mounts and unmounts.
class AppScope {
  AppScope._({
    required this.database,
    required this.databasePath,
    required this.modelFactory,
    required this.habitList,
    required this.preferences,
    required this.preferencesStorage,
    required this.taskRunner,
    required this.commandRunner,
    required this.midnightTimer,
    required this.logging,
    required this.cache,
    required this.adapter,
  });

  final Database database;

  /// Null when the database was opened from something other than a file, which
  /// only happens in tests.
  final String? databasePath;

  final SQLModelFactory modelFactory;

  final SQLiteHabitList habitList;

  final Preferences preferences;

  /// The backing store, kept because the settings screen writes a handful of
  /// keys core has no setter for (`pref_first_weekday` and the inert sync keys).
  final PreferencesStorage preferencesStorage;

  final TaskRunner taskRunner;

  final CommandRunner commandRunner;

  final MidnightTimer midnightTimer;

  final Logging logging;

  final HabitCardListCache cache;

  final HabitCardListAdapter adapter;

  /// Opens the application database and wires everything on top of it.
  ///
  /// This is `HabitsApplication.onCreate`: call it once, before `runApp`.
  static Future<AppScope> boot() async {
    final appDatabase = await AppDatabase.open();
    // Settings live in a JSON file next to the database, the way the Android
    // app keeps them in SharedPreferences. Without this they would reset on
    // every launch.
    final storage = await FilePreferencesStorage.open();
    return AppScope.open(
      appDatabase.database,
      databasePath: appDatabase.path,
      preferencesStorage: storage,
    );
  }

  /// Wires the scope around an already-opened [database].
  ///
  /// [preferencesStorage] defaults to a [MemoryStorage]: the Android app reads
  /// `SharedPreferences`, and the Flutter app has no persistent storage
  /// implementation yet, so preferences currently live for one run only.
  ///
  /// The dispatchers default to [AsyncDispatcher] for both roles, which is what
  /// `Dispatchers.Main` / `Dispatchers.IO` mean on a single-threaded isolate:
  /// commands and refreshes never run on the caller's stack.
  static AppScope open(
    Database database, {
    String? databasePath,
    PreferencesStorage? preferencesStorage,
    Dispatcher mainDispatcher = const AsyncDispatcher(),
    Dispatcher ioDispatcher = const AsyncDispatcher(),
    Logging? logging,
  }) {
    final resolvedLogging = logging ?? StandardLogging();
    final modelFactory = SQLModelFactory(database);
    final habitList = modelFactory.buildHabitList();
    final storage = preferencesStorage ?? MemoryStorage();
    final preferences = Preferences(storage);

    // HabitsApplication.onCreate, in order. Nothing above this line touches a
    // habit, because recompute(), the scores and every matcher read getToday().
    setToday(computeToday(preferences.midnightDelayHours, 0));
    for (final habit in habitList) {
      habit.recompute();
    }

    final taskRunner = CoroutineTaskRunner(
      mainDispatcher: mainDispatcher,
      ioDispatcher: ioDispatcher,
    );
    final commandRunner = CommandRunner(taskRunner);
    final midnightTimer = MidnightTimer(resolvedLogging, preferences);
    final cache = HabitCardListCache(
      habitList,
      commandRunner,
      taskRunner,
      resolvedLogging,
    );
    final adapter = HabitCardListAdapter(cache, preferences, midnightTimer);

    // `ListHabitsMenuBehavior`'s init block, which is what normally installs
    // the first filter. The menu itself is a later slice; without this the list
    // would show archived habits, which the Android app never does.
    adapter.setFilter(
      HabitMatcher(
        isArchivedAllowed: preferences.showArchived,
        isCompletedAllowed: preferences.showCompleted,
      ),
    );

    return AppScope._(
      database: database,
      databasePath: databasePath,
      modelFactory: modelFactory,
      habitList: habitList,
      preferences: preferences,
      preferencesStorage: storage,
      taskRunner: taskRunner,
      commandRunner: commandRunner,
      midnightTimer: midnightTimer,
      logging: resolvedLogging,
      cache: cache,
      adapter: adapter,
    );
  }

  void close() {
    cache.cancelTasks();
    database.close();
  }
}
