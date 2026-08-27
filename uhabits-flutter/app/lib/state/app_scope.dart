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

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

import '../platform/app_database.dart';
import '../platform/bug_reporter.dart';
import '../platform/file_preferences_storage.dart';
import '../platform/flutter_alarm_scheduler.dart';
import '../platform/flutter_files.dart';
import '../platform/flutter_notification_tray.dart';
import '../platform/home_widget_bridge.dart';
import 'app_preferences.dart';
import 'computed_habit_hooks.dart';
import 'intent_router.dart';
import '../platform/sleep_data_source_factory.dart';
import '../platform/sleep_prompt_scheduler.dart';
import 'reminder_link.dart';
import 'reminder_permission_gate.dart';
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
    required this.sleepRepository,
    required this.sleepSync,
    required this.definitions,
    required this.lapses,
    required this.abstinence,
  });

  final Database database;

  /// The nights and the goals.
  ///
  /// A habit is a sleep habit exactly when it has a goal here; nothing else in
  /// the model records that fact.
  final SleepSessionRepository sleepRepository;

  /// Where a habit says its days are computed. See [DefinitionRepository].
  final DefinitionRepository definitions;

  /// The journal an abstinence habit is scored from. See [LapseRepository].
  final LapseRepository lapses;

  /// Журнал срывов → значения дней. См. [AbstinenceSync].
  final AbstinenceSync abstinence;

  /// Reads sleep from the platform and turns it into scored days.
  final SleepSync sleepSync;

  /// Brings every sleep habit up to date from the platform.
  ///
  /// Which habits those are is asked of the repository each time rather than
  /// cached: a habit can become one, or stop being one, while the app runs.
  /// Whether the offer to excuse a trip has already been turned down.
  ///
  /// Keyed by the day the trip began, so turning one down says nothing about
  /// the next: a person who declines August's flight is not declining every
  /// flight they will ever take. Kept in preferences rather than in the sleep
  /// tables because it records what was said about the data, not the data.
  bool travelPromptDismissed(int habitId, int fromDay) =>
      preferencesStorage.getInt(_travelPromptKey(habitId), -1) == fromDay;

  /// Remembers that it was turned down, for good.
  void dismissTravelPrompt(int habitId, int fromDay) =>
      preferencesStorage.putInt(_travelPromptKey(habitId), fromDay);

  static String _travelPromptKey(int habitId) =>
      'sleep.travelPromptDismissed.$habitId';

  /// Whether the offer to move the goal to [bedMinutes]/[wakeMinutes] has been
  /// turned down.
  ///
  /// Keyed by the goal being offered rather than by the habit, so declining
  /// one suggestion says nothing about the next: a month later the nights say
  /// something different, and that is a new offer.
  bool goalSuggestionDismissed(int habitId, int? bedMinutes, int? wakeMinutes) =>
      preferencesStorage.getInt(_goalSuggestionKey(habitId), -1) ==
      _goalSuggestionValue(bedMinutes, wakeMinutes);

  /// Remembers that it was turned down.
  void dismissGoalSuggestion(int habitId, int? bedMinutes, int? wakeMinutes) =>
      preferencesStorage.putInt(
        _goalSuggestionKey(habitId),
        _goalSuggestionValue(bedMinutes, wakeMinutes),
      );

  static String _goalSuggestionKey(int habitId) =>
      'sleep.goalSuggestionDismissed.$habitId';

  /// The two times as one number, because preferences hold numbers. A time the
  /// suggestion leaves alone is null, which is a third value the pair has to be
  /// able to carry.
  static int _goalSuggestionValue(int? bedMinutes, int? wakeMinutes) =>
      (bedMinutes ?? 1441) * 2000 + (wakeMinutes ?? 1441);

  /// Announces that a computed habit's stored values changed.
  ///
  /// A computed day does not travel on a Command: the value is worked out
  /// rather than chosen, so there is nothing to undo and no command to carry
  /// it. But everything that shows those values refreshes on a command — the
  /// habit list holds its own copy of every checkmark and score, and the
  /// home-screen widgets are republished from the same signal. Without this
  /// the list keeps showing the value it had before the write, and re-entering
  /// the screen does not help.
  ///
  /// Not named after a kind. The first kind's writes called this by hand from
  /// three places of its own; the second kind writes from three places of its
  /// own too, and none of them would have had any reason to remember a method
  /// called `onSleepDataChanged`. One name for the whole layer, and — see
  /// [DayWriter] — a door that calls it without being asked.
  void onComputedDataChanged(int habitId) {
    if (_closed) return;
    cache.refreshHabit(habitId);
    unawaited(_started?.sync.updateWidgets(habitId) ?? Future<void>.value());
  }

  /// Whether the platform last said yes to reading sleep.
  ///
  /// Cached because the screen needs the answer while it builds and asking is
  /// asynchronous. Refreshed on every sync, so a permission granted in the
  /// system settings is picked up on the next return to the app.
  bool sleepSourceAuthorized = false;

  /// Every habit of [kind] this device still has, and still works on.
  ///
  /// The enumeration goes through the mark rather than through the kind's own
  /// side table. `SleepGoals` answers "which habits are sleep habits" only
  /// because sleep happens to have such a table; abstinence has no equivalent
  /// and never will — its mark *is* the row in `HabitDefinitions`. A loop
  /// written around a side table is a loop the second kind cannot reuse.
  ///
  /// Both filters live here rather than in each kind's sweep. The ported
  /// scheduler and the tray already skip archived habits, and arming a
  /// question for one is a notification for a habit the person put away; a
  /// mark whose habit is gone is the shape of a teardown race, and reaching
  /// for it would be `getById(habitId)!`. A rule spread across the kinds is a
  /// rule that will be carried to some and not the rest
  /// (`computed.lifecycle#4`).
  ///
  /// Lazy on purpose: a sweep awaits a platform read between two habits, and
  /// the list can change under it. Each step asks the list again.
  Iterable<Habit> computedHabits(ComputedKind kind) sync* {
    for (final int id in definitions.habitIdsOfKind(kind)) {
      final Habit? habit = habitList.getById(id);
      if (habit == null) continue;
      if (habit.isArchived) continue;
      yield habit;
    }
  }

  /// The sync currently running, so a second caller joins it rather than
  /// starting another.
  Future<void>? _sleepSyncInFlight;

  /// Brings every sleep habit up to date, one sync at a time.
  ///
  /// A cold start arms one and a return to the foreground arms another, and
  /// they overlap: the app was reading the same window two and three times
  /// over. On the first run of a habit's life that window is the whole
  /// history, because neither run has recorded how deep it got before the
  /// next begins.
  ///
  /// A caller that joins the one in flight loses nothing: it wanted the
  /// platform read, and the platform read is happening.
  Future<void> syncSleepHabits() {
    final Future<void>? running = _sleepSyncInFlight;
    if (running != null) return running;

    final Future<void> next = _syncSleepHabits().whenComplete(
      () => _sleepSyncInFlight = null,
    );
    _sleepSyncInFlight = next;
    return next;
  }

  Future<void> _syncSleepHabits() async {
    if (_closed) return;
    final bool authorized = await sleepSync.source.isAuthorized();
    if (_closed) return;
    sleepSourceAuthorized = authorized;

    for (final Habit habit in computedHabits(ComputedKind.sleep)) {
      // Read first, then check, then write. A sync waits on a permission
      // sheet and a fortnight of platform reads, and the person can leave the
      // app at any point during that; past this check there is no await left
      // for the teardown to slip through, so the writes cannot land on a
      // database that has been closed.
      final RecentNights? nights = await sleepSync.readRecent(habit);
      if (_closed) return;
      if (nights != null) sleepSync.applyRecent(nights);
      scheduleSleepPrompt(habit);
    }
  }

  /// Arms the morning question for one sleep habit.
  ///
  /// Its moment follows the goal rather than the clock, so it is worked out
  /// here and handed to the alarm scheduler directly; the reminder scheduler
  /// computes times from `habit.reminder`, which a drifting goal is not.
  void scheduleSleepPrompt(Habit habit) {
    final SleepPromptScheduler? prompts = _started?.sleepPrompts;
    if (prompts == null) return;
    final int? at = sleepPromptInstant(habit);
    if (at == null) return;
    unawaited(prompts.schedule(habit, sleepPromptDayOf(habit, at)!, at));
  }

  /// The day a question posted at [at] is about: the day the person wakes on.
  ///
  /// Handed to the scheduler rather than left to be derived there. The
  /// notification carries a day, and the night the person types in when they
  /// answer is filed against it; deriving it from the instant would put a
  /// question asked at 08:00 in Auckland on the day before, and the night with
  /// it.
  ///
  /// Null only for a habit with no goal, which is a habit that has no question
  /// to ask either.
  LocalDate? sleepPromptDayOf(Habit habit, int at) {
    final SleepGoal? goal = sleepRepository.goalFor(habit.id!);
    if (goal == null) return null;
    return LocalDate.fromUnixTime(
      at + _effectiveOffsetToday(habit, goal) * 60000,
    );
  }

  int _effectiveOffsetToday(Habit habit, SleepGoal goal) {
    final int today = sleepSync.today().daysSince2000;
    final int? firstNight = sleepRepository.firstDay(habit.id!);
    final Map<int, int> offsets = effectiveOffsets(
      firstDay: firstNight ?? today,
      lastDay: today,
      observedByDay: sleepRepository.observedOffsets(
        habit.id!,
        firstNight ?? today,
        today,
      ),
      homeOffsetMinutes: goal.homeUtcOffsetMinutes,
      ratePerDayMinutes: goal.adaptationMinutesPerDay,
    );
    return offsets[today] ?? goal.homeUtcOffsetMinutes;
  }

  /// When the morning question for [habit] should next be asked, or null when
  /// the habit is not a sleep habit.
  ///
  /// A query, kept apart from the arming above so the moment can be checked
  /// without a platform to arm anything on.
  int? sleepPromptInstant(Habit habit) {
    final SleepGoal? goal = sleepRepository.goalFor(habit.id!);
    if (goal == null) return null;

    final int today = sleepSync.today().daysSince2000;
    final int offset = _effectiveOffsetToday(habit, goal);
    return nextSleepPromptMillis(
      goal: goal,
      effectiveOffsetMinutes: offset,
      // The prompt works in UTC, and the clock the app reads is local. Taking
      // the shift back out is not a subtraction: the offset has to be looked
      // up at the instant, not at its local reading.
      nowMillis: sleepSync.nowMillis(),
      todaysNightRecorded: sleepRepository.forDay(habit.id!, today) != null,
    );
  }

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

  /// Step (2) of `HabitsApplication.onCreate`: open the database file, and
  /// when it cannot be used, set it aside and open a fresh one.
  ///
  /// `boot()` is awaited by `main()` *before* `runApp`, so anything that
  /// escapes here is a window with no widget tree at all — no message, no
  /// retry, nothing the user can do but reinstall and lose everything. There
  /// are two ways a file gets here, and upstream answers them differently:
  ///
  ///  * **The file is not readable as a database** — a zeroed header, a
  ///    truncated copy, a page killed mid-write. Android recovers, and does so
  ///    inside the framework: `HabitsDatabaseOpener` passes a null
  ///    `errorHandler` to `SQLiteOpenHelper` (HabitsDatabaseOpener.kt:35), so
  ///    `SQLiteDatabase.open()` catches the `SQLiteDatabaseCorruptException`
  ///    that SQLITE_NOTADB and SQLITE_CORRUPT map to, calls
  ///    `DefaultDatabaseErrorHandler.onCorruption()` — which deletes the file —
  ///    and reopens with `CREATE_IF_NECESSARY`. The app comes up empty
  ///    (`audit10.a-corrupt-database-file-recovers#1`).
  ///
  ///  * **The file is a database this build cannot use** — `user_version`
  ///    below 8 or above [databaseVersion]. Android does *not* recover from
  ///    this, however much HabitsApplication.kt:54-60 looks like it does:
  ///
  ///    ```kotlin
  ///    try {
  ///        DatabaseUtils.initializeDatabase(this)
  ///    } catch (e: UnsupportedDatabaseVersionException) { … rename … }
  ///    ```
  ///
  ///    `DatabaseUtils.initializeDatabase` (DatabaseUtils.kt:52-58) only
  ///    constructs the `SQLiteOpenHelper`, which by contract opens nothing
  ///    until `getWritableDatabase()`. The file is first opened lazily through
  ///    `providedDb` when `component.habitList` is touched at
  ///    HabitsApplication.kt:73 — thirteen lines past the catch — so the throw
  ///    from `onUpgrade`/`onDowngrade` escapes `Application.onCreate` and the
  ///    real app crashes on every launch with the data untouched on disk. The
  ///    catch is unreachable; the rename never happens
  ///    (`audit10.the-invalid-quarantine-is-the-ports-own#1`).
  ///
  /// This port recovers from both, and in both cases by setting the file aside
  /// rather than deleting it. Two deliberate divergences, recorded in
  /// DEVIATIONS.md: recovering from the unusable *version* at all, because a
  /// crash loop leaves the user with an app that cannot be opened and no way
  /// to act; and keeping the bytes as `<path>.invalid` where Android's error
  /// handler unlinks them, because that file is the only copy of the user's
  /// history.
  ///
  /// The retry is deliberately not itself guarded: the second call opens a
  /// path that no longer exists, which is the fresh-install path, and a
  /// failure there is a broken device rather than a bad file.
  static Future<AppDatabase> _initializeDatabase() async {
    try {
      return await AppDatabase.open();
    } on UnsupportedDatabaseVersionException catch (error) {
      return _quarantine(error);
    } on UnreadableDatabaseException catch (error) {
      return _quarantine(error);
    }
  }

  /// Moves the unusable file to `<path>.invalid` and opens a fresh database in
  /// its place — the port's stand-in both for the rename upstream never
  /// reaches and for the delete its error handler performs.
  static Future<AppDatabase> _quarantine(Object error) async {
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

    // Sleep arrives on the platform's schedule rather than the app's: a watch
    // uploads a night some time after the person got up. Asking to be woken
    // means the morning prompt finds the night already there instead of asking
    // for something the phone is holding.
    await sleepSync.source.enableBackgroundDelivery(syncSleepHabits);

    // Notification copy has to come from somewhere before any widget exists,
    // so it is looked up by locale rather than by BuildContext. It goes through
    // the same fallback the widget tree uses: `lookupL10n` throws for a
    // language the app does not translate, and handing it the raw device locale
    // aborted this method on its second statement — leaving the tray, the
    // scheduler and the widget publisher null for the whole session behind one
    // swallowed log line (`audit10.platform-services-start-on-every-device-
    // language#1`).
    //
    // Nothing is resolved here: the builder's default is
    // `platformNotificationStrings`, called afresh for every notification the
    // way `buildNotification` reads the Context at build time. Resolving once
    // and holding the answer froze every reminder in the language the process
    // started in (`audit24.reminder-strings-are-resolved-at-build-time#1`).
    final builder = ReminderNotificationBuilder(preferences: preferences);
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
    // Named, because two schedulers post through it: the reminder machinery
    // below, and the sleep habit's morning question, which cannot go through
    // that machinery at all.
    final alarmPlugin = LocalNotificationsAlarmPlugin(
      plugin: plugin,
      presenter: presenter,
    );
    final alarms = FlutterAlarmScheduler(
      plugin: alarmPlugin,
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
      isComputed: (int id) => definitions.isComputed(id),
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

    startServices(
      tray: tray,
      scheduler: scheduler,
      sleepPrompts: SleepPromptScheduler(alarms: alarmPlugin, builder: builder),
      sync: sync,
      // The two registrations the OS keeps a copy of — the Android channel
      // name and the Darwin category titles — which [onLocalesChanged] has to
      // re-issue (`audit24.reminder-strings-are-resolved-at-build-time#1`).
      registrations: presenter,
    );

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
    SleepPromptScheduler? sleepPrompts,
    NotificationPermissions? permissions,
    LocalizedNotificationRegistrations? registrations,
  }) {
    // `checkSelfPermission` / `requestPermissionLauncher`, which only a test
    // ever replaces: off a device there is no permission to ask for.
    _permissions = permissions;
    // The cached gate is bound to the scheduler and the permissions seam this
    // call is installing, so it cannot outlive them. Production starts the
    // services once, but a test that reuses a scope would otherwise get a gate
    // still holding the previous pair while `_permissions` read as the new one.
    _permissionGate = null;
    // (7) the widget updater: subscribe, then arm the start-of-day refresh at
    // getStartOfTomorrowWithOffset(midnightDelayHours, 0).
    sync.startListening();
    sync.scheduleStartDayWidgetUpdate();
    // (8) the reminder scheduler, and (9) the notification tray: both join the
    // command runner, and the tray also joins the preferences.
    scheduler.startListening();
    tray.startListening();

    // Withdraws whatever a computed habit armed with the system when the habit
    // goes away. Held so that close() can take it off again.
    _computedHooks = ComputedHabitHooks(
      withdrawAlarms: (Habit habit) =>
          unawaited(sleepPrompts?.cancel(habit) ?? Future<void>.value()),
    );
    commandRunner.addListener(_computedHooks!);

    _started = _Started(
      tray: tray,
      scheduler: scheduler,
      sleepPrompts: sleepPrompts,
      sync: sync,
      registrations: registrations,
    );

    // (10) the only asynchronous step. Nothing runs when an alarm fires (see
    // DEVIATIONS.md), so this scheduleAll at startup, plus the one after every
    // command, is what keeps alarms armed.
    taskRunner.execute(_StartupRefreshTask(scheduler, sync));

    // And the sleep habits, which otherwise only catch up on a return to the
    // foreground. A cold start is not a return: opening the app for the first
    // time that day would show yesterday's nights as zeros until the person
    // happened to switch away and back.
    //
    // Deliberately not awaited: reading a fortnight out of the platform is
    // slower than a first paint, and boot() runs before runApp.
    unawaited(syncSleepHabits());
  }

  _Started? _started;

  /// Held only so [close] can find the listener [startServices] registered.
  ComputedHabitHooks? _computedHooks;

  /// The device — or Loop's own, through the Android 13 per-app language
  /// picker — changed language while the app was running.
  ///
  /// Upstream there is nothing to do: `AndroidNotificationTray` reads all six
  /// strings out of the application `Context` when it builds a notification and
  /// re-creates the REMINDERS channel before every notify, so the next reminder
  /// is already translated. This port has no fire-time hook — its alarm IS the
  /// finished notification, see docs/parity/DEVIATIONS.md — so the copy is
  /// baked in at *schedule* time, and the two registrations the OS keeps its
  /// own copy of are made once. Both have to be redone here
  /// (`audit24.reminder-strings-are-resolved-at-build-time#1`):
  ///
  ///  * the Android channel name and the Darwin category action titles, which
  ///    no rebuild of a notification can reach;
  ///  * every armed alarm, through the same `scheduleAll()` that
  ///    `ReminderScheduler.onCommandFinished` and `ReminderPermissionGate`
  ///    already run — `FlutterAlarmScheduler` re-issues each alarm, and the
  ///    spec it rebuilds now resolves the strings afresh.
  Future<void> onLocalesChanged() async {
    final started = _started;
    if (started == null) return;
    try {
      await started.registrations?.refreshLocalizedRegistrations();
    } on Object catch (error) {
      logging
          .getLogger('HabitsApplication')
          .error('Could not refresh notification registrations: $error');
    }
    started.scheduler.scheduleAll();
  }

  /// Posts and cancels reminder notifications. Null until
  /// [startPlatformServices] has run, which widget tests never do.
  NotificationTray? get notificationTray => _started?.tray;

  /// Arms the next alarm for every habit that has a reminder.
  ReminderScheduler? get reminderScheduler => _started?.scheduler;

  NotificationPermissions? _permissions;

  ReminderPermissionGate? _permissionGate;

  /// The POST_NOTIFICATIONS block of `ListHabitsActivity.onResume`, built once
  /// per launch and shared by every caller. Null until [startServices] has run,
  /// which widget tests never do — upstream's `reminderScheduler` is what the
  /// block is guarded on, and there is nothing to arm without it.
  ///
  /// It lives on the scope rather than on a `State` because
  /// `permissionAlreadyRequested` is a *field of the activity*, and
  /// `EditHabitActivity` does not destroy `ListHabitsActivity`: the flag
  /// survives the editor round trip. Two gates over one launch would re-ask a
  /// user who already said no on every single route pop, which is the infinite
  /// `onResume` loop the flag exists to prevent
  /// (`reminders.app-start-and-permission#4`).
  ReminderPermissionGate? get reminderPermissionGate {
    final scheduler = _started?.scheduler;
    if (scheduler == null) return null;
    return _permissionGate ??= ReminderPermissionGate(
      scheduler: scheduler,
      permissions:
          _permissions ??
          LocalNotificationsPermissions(
            plugin: FlutterLocalNotificationsPlugin(),
          ),
      logging: logging,
    );
  }

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
    SleepDataSource? sleepSource,
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
    // Определение — до первого пересчёта, а не после: окно вычисляемой
    // привычки начинается со дня обязательства, и привычка, у которой ещё нет
    // ни одной записи, посчиталась бы пустой (`computed.commitment#5`).
    final definitions = DefinitionRepository(database);
    attachDefinitions(habitList, definitions);
    final lapses = LapseRepository(database);
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

    final sleepRepository = SleepSessionRepository(
      database,
      () => DateTime.now().millisecondsSinceEpoch,
    );
    // The announcement is handed to the door that writes days rather than left
    // for each kind to remember. It has to close over the scope, which does
    // not exist until the next statement — hence `late`, and hence a callback
    // rather than the scope itself.
    late final AppScope scope;
    scope = AppScope._(
      sleepRepository: sleepRepository,
      definitions: definitions,
      lapses: lapses,
      abstinence: AbstinenceSync(
        lapses: lapses,
        // Тот же объявляющий писатель, что у сна: тогда объявление списку идёт
        // даром, привычка пересчитывается до объявления
        // (`computed.freshness#4`), и жесту UI не нужно звать
        // `onComputedDataChanged` вторым вызовом.
        writer: DayWriter(
          onChanged: (int habitId) => scope.onComputedDataChanged(habitId),
        ),
      ),
      sleepSync: SleepSync(
        repository: sleepRepository,
        // The resolved one, not the parameter: a bare StandardLogging writes
        // to a stdout that nothing on a phone reads, and these lines are the
        // only account of why Health went quiet. They belong in the buffer the
        // bug report carries.
        source: sleepSource ?? defaultSleepDataSource(logging: resolvedLogging),
        writer: DayWriter(
          onChanged: (int habitId) => scope.onComputedDataChanged(habitId),
        ),
      ),
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
    return scope;
  }

  /// Whether [close] has run.
  ///
  /// The startup sleep sync is deliberately not awaited, so it can still be in
  /// flight when the scope is torn down — in a test that closes immediately,
  /// and in an app the person leaves the moment it opens. Its continuations
  /// check this before touching a database that may be gone.
  bool _closed = false;

  /// Whether [close] has been called. Read by anything holding the result of a
  /// slow platform read, to find out whether there is still a database to
  /// write it to.
  bool get isClosed => _closed;

  void close() {
    // Idempotent: a scope is closed from wherever ownership ends, and two
    // owners agreeing to close it is not an error worth throwing over — the
    // second `database.close()` would.
    if (_closed) return;
    _closed = true;
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
    final ComputedHabitHooks? hooks = _computedHooks;
    if (hooks != null) commandRunner.removeListener(hooks);
    _computedHooks = null;
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
  _Started({
    required this.tray,
    required this.scheduler,
    required this.sleepPrompts,
    required this.sync,
    this.registrations,
  });

  final NotificationTray tray;
  final ReminderScheduler scheduler;

  /// The morning question a sleep habit asks. Not the reminder scheduler and
  /// not the raw alarm scheduler: its moment comes from a drifting goal rather
  /// than from `habit.reminder`, and it needs an id namespace of its own.
  final SleepPromptScheduler? sleepPrompts;

  final WidgetSync sync;

  /// Null on a host with no plugin, and in every test that starts the services
  /// over fakes.
  final LocalizedNotificationRegistrations? registrations;
}
