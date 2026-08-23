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

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

import '../l10n/app_localizations.dart';
import '../platform/app_database.dart';
import '../platform/file_preferences_storage.dart';
import '../platform/flutter_alarm_scheduler.dart';
import '../platform/flutter_notification_tray.dart';
import '../platform/home_widget_bridge.dart';
import 'widget_sync.dart';

/// This build's `BuildConfig.VERSION_CODE`.
///
/// Android derives `versionCode` from `flutter.versionCode`, which is the `+N`
/// build number of `version:` in app/pubspec.yaml — so this constant has to
/// track that number, and test/state/app_startup_test.dart reads the pubspec
/// back to make sure it still does. `HabitsApplication.onCreate` writes it into
/// `Preferences.lastAppVersion` on every launch
/// (`settings.preferences.first-run-and-launch-count#4`); upstream's own value
/// at the ported revision was 20301.
const int appVersionCode = 1;

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
    final scope = AppScope.open(
      appDatabase.database,
      databasePath: appDatabase.path,
      preferencesStorage: storage,
    );
    await scope.startPlatformServices();
    return scope;
  }

  /// Constructs and starts the singletons `HabitsApplication.onCreate` starts:
  /// the notification tray, the reminder scheduler and the widget publisher.
  ///
  /// They are deliberately absent from [open] so that widget tests can build a
  /// scope without touching a plugin. Skipping this on a real device is what
  /// made the app schedule no reminders and publish no widget data even though
  /// every one of these classes was written and tested.
  Future<void> startPlatformServices() async {
    // Reminders and widgets are conveniences layered on top of a working app.
    // If a host cannot provide them — macOS has no widget extension, a test
    // has no method channels — the app still has to open.
    try {
      await _startPlatformServices();
    } on Object catch (error) {
      logging
          .getLogger('HabitsApplication')
          .error('Platform services unavailable: $error');
    }
  }

  Future<void> _startPlatformServices() async {
    await LocalNotificationsAlarmPlugin.ensureTimeZones();

    // Notification copy has to come from somewhere before any widget exists,
    // so it is looked up by locale rather than by BuildContext.
    final l10n = lookupL10n(PlatformDispatcher.instance.locale);
    final builder = ReminderNotificationBuilder(
      preferences: preferences,
      strings: NotificationStrings.from(l10n),
    );
    final plugin = FlutterLocalNotificationsPlugin();
    final presenter =
        LocalNotificationsPresenter(plugin: plugin, builder: builder);

    final tray = NotificationTray(
      taskRunner,
      commandRunner,
      preferences,
      FlutterNotificationTray(
        presenter: presenter,
        builder: builder,
        logging: logging,
      ),
    );

    final scheduler = ReminderScheduler(
      commandRunner,
      habitList,
      FlutterAlarmScheduler(
        plugin:
            LocalNotificationsAlarmPlugin(plugin: plugin, presenter: presenter),
        builder: builder,
        logging: logging,
      ),
      WidgetPreferences(preferencesStorage),
    );

    final sync = WidgetSync(
      bridge: HomeWidgetBridge(
        habitList: habitList,
        registry: WidgetRegistry(preferencesStorage),
        platform: HomeWidgetPlugin(),
        // `settings.preferences.widget-opacity#4`: the settings row writes
        // `pref_widget_opacity` and asks for a republish; this is the half
        // that carries the new value to the launcher's process.
        preferences: preferences,
      ),
      commandRunner: commandRunner,
      taskRunner: taskRunner,
      midnightTimer: midnightTimer,
      preferences: preferences,
    );

    startServices(tray: tray, scheduler: scheduler, sync: sync);
  }

  /// Steps (7) to (10) of `HabitsApplication.onCreate`, once the three
  /// singletons exist.
  ///
  /// Kept separate from [_startPlatformServices] — which is the half that
  /// cannot run without plugins — so the sequence itself is exercisable with
  /// test doubles. Upstream:
  ///
  /// ```kotlin
  /// widgetUpdater.startListening()
  /// widgetUpdater.scheduleStartDayWidgetUpdate()
  /// reminderScheduler.startListening()
  /// notificationTray.startListening()
  /// taskRunner.execute {
  ///     reminderScheduler.scheduleAll()
  ///     widgetUpdater.updateWidgets()
  /// }
  /// ```
  void startServices({
    required NotificationTray tray,
    required ReminderScheduler scheduler,
    required WidgetSync sync,
  }) {
    // (7) the widget updater: subscribe, then arm the start-of-day refresh at
    // getStartOfTomorrowWithOffset(midnightDelayHours, 0).
    sync.startListening();
    sync.scheduleStartDayWidgetUpdate();
    // (8) the reminder scheduler, and (9) the notification tray: both join the
    // command runner, and the tray also joins the preferences.
    scheduler.startListening();
    tray.startListening();

    _started = _Started(tray: tray, scheduler: scheduler, sync: sync);

    // (10) the only asynchronous step. Nothing runs when an alarm fires (see
    // DEVIATIONS.md), so this scheduleAll at startup, plus the one after every
    // command, is what keeps alarms armed.
    taskRunner.execute(_StartupRefreshTask(scheduler, sync));
  }

  _Started? _started;

  /// Posts and cancels reminder notifications. Null until
  /// [startPlatformServices] has run, which widget tests never do.
  NotificationTray? get notificationTray => _started?.tray;

  /// Arms the next alarm for every habit that has a reminder.
  ReminderScheduler? get reminderScheduler => _started?.scheduler;

  /// Publishes the data the native home-screen widgets read.
  WidgetSync? get widgetSync => _started?.sync;

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
    //
    // (4) `prefs.lastAppVersion = BuildConfig.VERSION_CODE`, unconditionally
    // and before today is stamped. Nothing reads it back — upstream keeps it so
    // that a future migration can tell which build wrote the database — so the
    // only observable effect is the write itself.
    preferences.lastAppVersion = appVersionCode;
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
    // `HabitsApplication.onTerminate`, in its exact order:
    // reminderScheduler.stopListening(), widgetUpdater.stopListening(),
    // notificationTray.stopListening() (`commands.command-runner-listeners#8`).
    // Null in every test that never started the platform services.
    final started = _started;
    if (started != null) {
      started.scheduler.stopListening();
      started.sync.stopListening();
      started.tray.stopListening();
    }
    cache.cancelTasks();
    database.close();
  }
}


/// `taskRunner.execute { reminderScheduler.scheduleAll(); widgetUpdater
/// .updateWidgets() }` — the last step of `HabitsApplication.onCreate`, in that
/// order.
class _StartupRefreshTask extends Task {
  _StartupRefreshTask(this._scheduler, this._sync);

  final ReminderScheduler _scheduler;

  final WidgetSync _sync;

  @override
  FutureOr<void> doInBackground() {
    _scheduler.scheduleAll();
    return _sync.updateWidgets();
  }
}

/// The platform singletons, once [AppScope.startPlatformServices] has run.
class _Started {
  _Started({required this.tray, required this.scheduler, required this.sync});

  final NotificationTray tray;
  final ReminderScheduler scheduler;
  final WidgetSync sync;
}
