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
import '../platform/bug_reporter.dart';
import '../platform/file_preferences_storage.dart';
import '../platform/flutter_alarm_scheduler.dart';
import '../platform/flutter_files.dart';
import '../platform/flutter_notification_tray.dart';
import '../platform/home_widget_bridge.dart';
import 'app_preferences.dart';
import 'intent_router.dart';
import 'reminder_link.dart';
import 'widget_sync.dart';
import 'widget_toggle_queue.dart';

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

  /// The application's preferences.
  ///
  /// [AppPreferences] rather than plain [Preferences] because a Flutter app
  /// has no activity to recreate: the models that read a preference are built
  /// once per launch, so a write has to be announced to them
  /// (`audit3.toggling-use-pure-black-background-in#1`). Everything that reads
  /// a preference keeps taking a [Preferences]; only the handful of objects
  /// that must repaint when one changes ask for the callback.
  final AppPreferences preferences;

  /// The backing store, kept because the settings screen writes a handful of
  /// keys core has no setter for (`pref_first_weekday` and the inert sync keys).
  final PreferencesStorage preferencesStorage;

  final TaskRunner taskRunner;

  final CommandRunner commandRunner;

  final MidnightTimer midnightTimer;

  final Logging logging;

  /// `AndroidBugReporter`, which `ListHabitsModule` binds as the
  /// `ListHabitsBehavior.BugReporter` and which `BaseExceptionHandler` builds
  /// on the spot to dump a crash (`platform-glue.crash-handler#4`,
  /// `io.bug-report-dump#8`).
  ///
  /// One per application, because the crash handler and the Troubleshooting row
  /// dump the same report to the same place. [boot] points it at the resolved
  /// external files directory; a scope that never booted — every widget test —
  /// still answers with a reporter, one whose `getFilesDir` finds nothing.
  /// That is upstream's own `log dir should not be null` branch: an IOException
  /// the dump catches and prints, which keeps the crash path's collaborator
  /// non-null without inventing a directory.
  FlutterBugReporter get bugReporter => _bugReporter ??= FlutterBugReporter(
        dirFinder: HabitsDirFinder(const <String>[]),
        deviceInfo: DeviceInfo.current(),
      );

  FlutterBugReporter? _bugReporter;

  final HabitCardListCache cache;

  final HabitCardListAdapter adapter;

  /// Opens the application database and wires everything on top of it.
  ///
  /// This is `HabitsApplication.onCreate`: call it once, before `runApp`.
  static Future<AppScope> boot() async {
    final appDatabase = await _initializeDatabase();
    // Settings live in a JSON file next to the database, the way the Android
    // app keeps them in SharedPreferences. Without this they would reset on
    // every launch.
    final storage = await FilePreferencesStorage.open();
    final scope = AppScope.open(
      appDatabase.database,
      databasePath: appDatabase.path,
      preferencesStorage: storage,
    );
    await scope._resolveBugReporter();
    await scope.startPlatformServices();
    return scope;
  }

  /// Step (2) of `HabitsApplication.onCreate`, with the `try`/`catch` that is
  /// the difference between a bad file and a permanent crash loop:
  ///
  /// ```kotlin
  /// try {
  ///     DatabaseUtils.initializeDatabase(this)
  /// } catch (e: UnsupportedDatabaseVersionException) {
  ///     val db = DatabaseUtils.getDatabaseFile(this)
  ///     db.renameTo(File(db.absolutePath + ".invalid"))
  ///     DatabaseUtils.initializeDatabase(this)
  /// }
  /// ```
  ///
  /// `boot()` is awaited by `main()` *before* `runApp`, so anything that
  /// escapes here is a window with no widget tree at all — no message, no
  /// retry, nothing the user can do but reinstall and lose everything. The
  /// file is set aside instead of deleted, so the data is still there to be
  /// recovered (`platform-glue.app-startup-order#3`,
  /// `persistence.android-opener#7`).
  ///
  /// The retry is deliberately not itself guarded: the second call opens a
  /// path that no longer exists, which is the fresh-install path, and a
  /// failure there is a broken device rather than a bad file.
  static Future<AppDatabase> _initializeDatabase() async {
    try {
      return await AppDatabase.open();
    } on UnsupportedDatabaseVersionException catch (error) {
      final file = await AppDatabase.resolveFile();
      // `File.renameTo` overwrites an existing target on POSIX, so a second
      // unusable file replaces the first `.invalid` rather than failing.
      if (file.existsSync()) {
        file.renameSync('${file.path}.invalid');
      }
      final database = await AppDatabase.open();
      // After the reopen, so that the logger this writes to is the one the
      // fresh scope will keep using.
      BugReportLogging(StandardLogging(), BugReportLog.instance)
          .getLogger('HabitsApplication')
          .error('Unusable database set aside as ${file.path}.invalid: $error');
      return database;
    }
  }

  /// Points [bugReporter] at `ContextCompat.getExternalFilesDirs(context,
  /// null)`, which is a platform call and so cannot happen in [open].
  ///
  /// Upstream `AndroidBugReporter` takes a `Context` and asks it for the
  /// directory on every dump; here the answer is resolved once, at startup,
  /// because the crash handler that dumps through it is installed before the
  /// first frame and cannot await anything.
  Future<void> _resolveBugReporter() async {
    try {
      final directories = await AppDirectories.resolve();
      _bugReporter = FlutterBugReporter(
        dirFinder: HabitsDirFinder.of(directories),
        deviceInfo: DeviceInfo.current(),
      );
    } on Object catch (error) {
      // The fallback below still answers, and its dump fails the way upstream's
      // does when `getFilesDir` returns null.
      logging
          .getLogger('HabitsApplication')
          .error('Bug report directory unavailable: $error');
    }
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

    // `AndroidNotificationTray` sets `R.drawable.ic_notification` on every
    // notification it builds and creates the REMINDERS channel before
    // notifying. Both of those are things this plugin is told once, at
    // initialisation — and so is the pair of callbacks without which nothing
    // the user does to a notification reaches Dart at all. Constructing the
    // presenter without initialising it is what made every scheduled reminder
    // throw inside the plugin at fire time, and every button a dead end.
    //
    // The response callback is registered here, and not from a widget,
    // because a notification can start the app: by the time the first frame
    // is built the response has already been delivered. See
    // lib/state/reminder_link.dart.
    ReminderResponseRouter? responses;
    final presenter = await LocalNotificationsPresenter.initialize(
      builder: builder,
      plugin: plugin,
      onResponse: (response) => responses?.handleResponse(response),
      // An Android action button that shows no user interface — "Yes" and
      // "No" — is delivered to a background isolate and to nothing else.
      onBackgroundResponse: reminderBackgroundResponse,
    );

    // The scheduler is built before the tray, because the tray needs it: an
    // alarm here IS the notification the tray cancels, filed under the same id,
    // so every cancel has to re-arm the day's alarm behind it
    // (`audit3.recording-a-non-completing-entry-silently#1`). Upstream the two
    // are independent and `AndroidNotificationTray` knows nothing of the
    // scheduler.
    final alarms = FlutterAlarmScheduler(
      plugin:
          LocalNotificationsAlarmPlugin(plugin: plugin, presenter: presenter),
      builder: builder,
      logging: logging,
    );
    // FlutterReminderScheduler, not the core one: with no fire-time hook, the
    // two gates the core reproduces by skipping a habit have to withdraw its
    // alarm instead, or a reminder switched off at 22:00 still goes off at
    // 08:00 (`audit9.obsolete-reminder-alarm-withdrawn#1`).
    final scheduler = FlutterReminderScheduler(
      commandRunner: commandRunner,
      habitList: habitList,
      alarms: alarms,
      widgetPreferences: WidgetPreferences(preferencesStorage),
    );

    final flutterTray = FlutterNotificationTray(
      presenter: presenter,
      builder: builder,
      logging: logging,
      scheduler: scheduler,
    );
    final tray = NotificationTray(
      taskRunner,
      commandRunner,
      preferences,
      flutterTray,
    );

    // The App Group the iOS widget extension reads, named before anything is
    // published. `HomeWidgetPlugin()` used to be built with no argument and
    // `ensureInitialized()` had no caller at all, so on iOS every publish went
    // into the app's own UserDefaults, the extension read an empty suite, and
    // all six home-screen widgets stayed permanently blank
    // (`audit4.ios-the-app-group-is-never#1`). It is a no-op on Android.
    final widgetPlatform = HomeWidgetPlugin(
      appGroupId: HomeWidgetPlugin.iosAppGroupId,
    );
    await widgetPlatform.ensureInitialized();

    // The core of `WidgetReceiver`: one instance, because a widget tap and a
    // notification button are the same behaviour reached two ways.
    final widgetBehavior = WidgetBehavior(
      habitList: habitList,
      commandRunner: commandRunner,
      notificationTray: tray,
      preferences: preferences,
    );

    final sync = WidgetSync(
      bridge: HomeWidgetBridge(
        habitList: habitList,
        registry: WidgetRegistry(preferencesStorage),
        platform: widgetPlatform,
        // `settings.preferences.widget-opacity#4`: the settings row writes
        // `pref_widget_opacity` and asks for a republish; this is the half
        // that carries the new value to the launcher's process.
        preferences: preferences,
      ),
      commandRunner: commandRunner,
      taskRunner: taskRunner,
      midnightTimer: midnightTimer,
      preferences: preferences,
      // The taps an iOS widget performed in place while the app was closed.
      // Drained on the way to every publish, which is where upstream's
      // `WidgetReceiver` broadcast would have arrived
      // (`audit4.tapping-a-boolean-checkmark-widget-now#1`).
      pendingToggles: WidgetToggleQueue(
        store: HomeWidgetStore(plugin: widgetPlatform),
        habitList: habitList,
        behavior: widgetBehavior,
        logging: logging,
      ),
    );

    // `ReminderReceiver` + `ReminderController` + the two `WidgetReceiver`
    // actions a reminder carries. Built here because the callback registered
    // above has to have something to call from the moment the plugin is
    // initialised.
    final controller = ReminderController(scheduler, tray, preferences);
    responses = ReminderResponseRouter(
      habits: habitList,
      controller: controller,
      checkmarks: WidgetIntentReceiver(
        parser: IntentParser(habitList),
        controller: widgetBehavior,
        preferences: preferences,
        updateWidgets: sync.updateWidgets,
        scheduleStartDayWidgetUpdate: sync.scheduleStartDayWidgetUpdate,
        logging: logging,
      ),
      // The delete intent this plugin does not have — and the fire-time hook
      // it does not have either, which is what puts a reminder the OS posted
      // on its own into the two registries the dismissal is read against.
      dismissals: DismissedReminderDetector(
        tray: flutterTray,
        registry: tray,
        habits: habitList,
        platform: presenter,
        onDismiss: controller.onDismiss,
        logging: logging,
      ),
      logging: logging,
    );
    _reminderResponses = responses;

    startServices(tray: tray, scheduler: scheduler, sync: sync);

    // Last, because it can act immediately: the notification that started the
    // app is not replayed through the callback, and everything else has to be
    // listening before it is answered.
    await responses.replayLaunchResponse(plugin);
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

  ReminderResponseRouter? _reminderResponses;

  /// Answers a tap on a reminder notification. Null until
  /// [startPlatformServices] has run, which widget tests never do.
  ///
  /// It is a property of the scope rather than of a screen because the plugin
  /// callback is registered before `runApp`: a notification can be what
  /// launched the app, and the response arrives before any widget exists.
  ReminderResponseRouter? get reminderResponses => _reminderResponses;

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
    // `Logging = AndroidLogging`, whose loggers write to `android.util.Log` —
    // which is exactly what `AndroidBugReporter.getLogcat()` reads back out of
    // `logcat -d`. Off Android there is no system log to write into and read
    // from, so [BugReportLog] is that shared buffer and [BugReportLogging] is
    // the half that fills it: without this decorator every generated bug report
    // has a blank space where 250 log lines should be
    // (`io.bug-report-dump#3`, `#4`).
    //
    // An injected [logging] is a test replacing the binding outright — upstream
    // `HabitsApplicationTestComponent` overriding a `@Provides` — so it is
    // taken as given rather than wrapped.
    final resolvedLogging =
        logging ?? BugReportLogging(StandardLogging(), BugReportLog.instance);
    final modelFactory = SQLModelFactory(database);
    final habitList = modelFactory.buildHabitList();
    final storage = preferencesStorage ?? MemoryStorage();
    // `SharedPreferencesStorage`, whose `init` block registers it as a
    // `SharedPreferences.OnSharedPreferenceChangeListener`: every write is
    // announced, and whoever has to repaint because of one subscribes here
    // (lib/state/app_preferences.dart).
    final preferences = AppPreferences(storage);

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
    _reminderResponses?.dispose();
    _reminderResponses = null;
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
