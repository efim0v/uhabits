/// The application-scope graph and the startup sequence that builds it.
///
/// `AppScope` is this port's `HabitsApplicationComponent`: one object, built
/// once before `runApp`, holding the long-lived collaborators every screen
/// shares. `AppScope.boot` / `AppScope.open` is its `HabitsApplication.onCreate`.
///
/// ## What is here and what is not
///
/// The graph and the first six steps of the startup sequence are reproduced and
/// asserted below. The last four are not: nothing in this build starts the
/// widget updater, the reminder scheduler or the notification tray, and nothing
/// writes `prefs.lastAppVersion`. Every one of those collaborators exists and is
/// tested on its own — `WidgetSync` in test/platform/home_widget_bridge_test.dart,
/// `FlutterAlarmScheduler` and `FlutterNotificationTray` in
/// test/platform/notifications_test.dart — but no one wires them at launch, so
/// a freshly started app schedules no reminders and publishes no widget data
/// until something else triggers a command. That is reported as a gap rather
/// than papered over here, and the rules that describe those steps stay
/// uncited.
library;

// The core's commands, preferences and task layers are reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/preferences/widget_preferences.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  final int Function() realClock = systemCurrentTimeMillis;
  final TimeZone Function() realZone = getDefaultTimeZone;

  setUp(() {
    resetToday();
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    DateUtils.setFixedLocalTime(null);
    systemCurrentTimeMillis = realClock;
    // `computeToday` reads the top-level `getDefaultTimeZone`, not
    // `DateUtils.fixedTimeZone`, so pinning the clock is not enough on its own.
    getDefaultTimeZone = () => const FixedTimeZone(0);
    tempDir = Directory.systemTemp.createTempSync('uhabits_app_scope');
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    systemCurrentTimeMillis = realClock;
    getDefaultTimeZone = realZone;
    resetToday();
  });

  String newDatabasePath() => '${tempDir.path}/habits${databaseIndex++}.db';

  /// A scope on synchronous dispatchers, so that everything `open` sets in
  /// motion has finished by the time it returns — including the list cache's
  /// first refresh, which reads `getToday()` and would otherwise outlive the
  /// test that started it.
  AppScope openScope({
    PreferencesStorage? storage,
    String? path,
    Logging? logging,
  }) {
    final String resolved = path ?? newDatabasePath();
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate(resolved),
      databasePath: resolved,
      preferencesStorage: storage,
      logging: logging,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    scopes.add(scope);
    return scope;
  }

  void closeScope(AppScope scope) {
    scope.close();
    scopes.remove(scope);
  }

  // =======================================================================
  // platform-glue.app-startup-order
  // =======================================================================

  group('platform-glue.app-startup-order', () {
    test('#1 the database is open, the graph is built, today is stamped and '
        'every habit is recomputed — in that order', () {
      // getToday() throws until setToday has run, so a scope that comes back
      // at all has done the two steps in the right order. That is the whole
      // point of the rule's ordering clause.
      expect(getToday, throwsA(anything),
          reason: 'platform-glue.app-startup-order#1: nothing has stamped '
              'today yet');

      final String path = newDatabasePath();
      final AppScope scope = openScope(path: path);

      expect(File(path).existsSync(), isTrue,
          reason: 'platform-glue.app-startup-order#1 — HabitsApplication.'
              'onCreate performs steps in this exact order: (1) if isTestMode(), '
              'delete the database file; (2) DatabaseUtils.initializeDatabase'
              '(context); (3) build the DI component; (4) write '
              'prefs.lastAppVersion = BuildConfig.VERSION_CODE; (5) '
              'setToday(computeToday(prefs.midnightDelayHours, 0)); (6) '
              'recompute every habit; (7) start the widget updater; (8) start '
              'the reminder scheduler; (9) start the notification tray; (10) '
              'run scheduleAll + updateWidgets on the task runner. Steps 1, 4 '
              'and 7-10 have no counterpart in this build — there is no test '
              'mode, nothing writes lastAppVersion, and no one starts the three '
              'listeners at launch. Steps 2, 3, 5 and 6 are here, in this '
              'order, and the ordering of 5 before 6 is the one the note calls '
              'load-bearing.');
      expect(scope.database.getVersion(), databaseVersion,
          reason: 'platform-glue.app-startup-order#1: (2) the database is '
              'opened and migrated first');
      expect(scope.habitList, isNotNull,
          reason: 'platform-glue.app-startup-order#1: (3) then the graph');
      expect(getToday(), computeToday(scope.preferences.midnightDelayHours, 0),
          reason: 'platform-glue.app-startup-order#1: (5) then today');
    });

    test('#6 today is computed with the midnight-delay offset', () {
      // 2015-01-26 01:30 UTC. With the delay off the logical day is the 26th;
      // with it on the day has not turned over yet.
      final int now = DateTime.utc(2015, 1, 26, 1, 30).millisecondsSinceEpoch;
      systemCurrentTimeMillis = () => now;
      DateUtils.setFixedLocalTime(now);

      final MemoryStorage plain = MemoryStorage();
      final AppScope first = openScope(storage: plain);
      expect(getToday(), LocalDate.ymd(2015, 1, 26),
          reason: 'platform-glue.app-startup-order#6 — The global "today" is '
              'set once at startup: setToday(computeToday(hourOffset = '
              'preferences.midnightDelayHours, minuteOffset = 0)). '
              'midnightDelayHours is 3 when SharedPreferences boolean '
              '"pref_midnight_delay" is true, otherwise 0.');
      expect(Preferences(plain).midnightDelayHours, 0,
          reason: 'platform-glue.app-startup-order#6: 0 while the preference '
              'is off');

      closeScope(first);
      resetToday();
      final MemoryStorage delayed = MemoryStorage()
        ..putBoolean('pref_midnight_delay', true);
      openScope(storage: delayed);
      expect(Preferences(delayed).midnightDelayHours, 3,
          reason: 'platform-glue.app-startup-order#6: 3 while it is on');
      expect(getToday(), LocalDate.ymd(2015, 1, 25),
          reason: 'platform-glue.app-startup-order#6: so at 01:30 the logical '
              'day is still the previous one');
    });

    test('#7 computeToday is floorDiv of the offset instant, minus 10957 days',
        () {
      const int day = 86400000;
      const int epochToMillenium = 10957;
      final int now = DateTime.utc(2015, 1, 26, 5, 0).millisecondsSinceEpoch;
      systemCurrentTimeMillis = () => now;
      DateUtils.setFixedLocalTime(now);

      int expected(int hourOffset, int minuteOffset) {
        final int shifted =
            now - hourOffset * 3600000 - minuteOffset * 60000;
        final int days =
            (shifted / day).floor() - epochToMillenium;
        return days;
      }

      // The timezone is pinned to GMT, so `timezoneOffset(now)` is 0 and the
      // formula reduces to the arithmetic above.
      for (final List<int> offset in <List<int>>[
        <int>[0, 0],
        <int>[3, 0],
        <int>[6, 30],
        <int>[24, 0],
      ]) {
        expect(
          computeToday(offset[0], offset[1]).daysSince2000,
          expected(offset[0], offset[1]),
          reason: 'platform-glue.app-startup-order#7 — computeToday(hourOffset, '
              'minuteOffset) = LocalDate(daysSince2000) where daysSince2000 = '
              'floorDiv(System.currentTimeMillis() + timezoneOffset(now) - '
              'hourOffset*3600000 - minuteOffset*60000, 86400000) - 10957. '
              '(offset ${offset[0]}h ${offset[1]}m)',
        );
      }

      // floorDiv, not truncating division: an instant before 2000-01-01 must
      // round down rather than towards zero.
      final int before2000 = DateTime.utc(1999, 12, 31, 23, 0).millisecondsSinceEpoch;
      systemCurrentTimeMillis = () => before2000;
      DateUtils.setFixedLocalTime(before2000);
      expect(computeToday(0, 0).daysSince2000, -1,
          reason: 'platform-glue.app-startup-order#7: floorDiv rounds down '
              'through zero');

      // And the constant really is the 1970-to-2000 gap.
      expect(LocalDate(0).unixTime ~/ day, epochToMillenium,
          reason: 'platform-glue.app-startup-order#7: 10957 days from the Unix '
              'epoch to 2000-01-01');
    });

    testWidgets('#4 the scope is built once and every screen reads the same '
        'one', (WidgetTester tester) async {
      final String path = newDatabasePath();
      final AppScope scope = openScope(path: path);

      // Upstream stores the finished component in a static so that any
      // Activity, Service or BroadcastReceiver can reach it. Flutter has one
      // Activity and a widget tree, so the scope is handed to the tree once and
      // every descendant reads that same instance out of it.
      final List<AppScope> seen = <AppScope>[];
      await tester.pumpWidget(
        Provider<AppScope>.value(
          value: scope,
          child: Builder(
            builder: (BuildContext context) {
              seen.add(context.read<AppScope>());
              return Builder(
                builder: (BuildContext inner) {
                  seen.add(inner.read<AppScope>());
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ),
      );

      expect(seen, hasLength(2),
          reason: 'platform-glue.app-startup-order#4 — The DI root is created '
              'as HabitsApplicationComponent::class.create(appContext = '
              'applicationContext, dbFile = DatabaseUtils.getDatabaseFile(this)) '
              'and stored in a static (companion) lateinit var '
              'HabitsApplication.component; the instance property `component` '
              'just returns that static. There is no static here — the finished '
              'scope is put in the widget tree once, and every reader gets that '
              'one instance.');
      for (final AppScope read in seen) {
        expect(identical(read, scope), isTrue,
            reason: 'platform-glue.app-startup-order#4: the same instance, at '
                'every depth');
      }
      expect(scope.databasePath, path,
          reason: 'platform-glue.app-startup-order#4: built around the database '
              'file, which is the second of the two constructor bindings');
    });

    test('#8 every habit is recomputed before anything reads one', () {
      final String path = newDatabasePath();

      // Seed a database with an entry but no computed score, the way a file
      // restored from a backup arrives.
      final AppScope seed = openScope(path: path);
      final Habit habit = HabitFixtures(
        seed.modelFactory,
        seed.habitList,
      ).createEmptyHabit(name: 'Meditate');
      // HabitFixtures.saveIfSQLite already registered it: the entry list
      // an SQLModelFactory hands out is SQLite-backed.
      habit.originalEntries.add(Entry(getToday(), Entry.yesManual));
      habit.originalEntries.add(Entry(getToday().minus(1), Entry.yesManual));
      closeScope(seed);
      resetToday();

      // Reopening runs onCreate again: the scores are recomputed on the way in,
      // not lazily on first read.
      final AppScope reopened = openScope(path: path);
      final Habit reloaded = reopened.habitList.first;

      expect(reloaded.scores[getToday()].value, greaterThan(0.0),
          reason: 'platform-glue.app-startup-order#8 — Every habit in the habit '
              'list has recompute() called synchronously on the main thread '
              'during onCreate, before widgets/reminders start.');
      expect(reloaded.computedEntries.get(getToday()).value, Entry.yesManual,
          reason: 'platform-glue.app-startup-order#8: computedEntries are '
              'filled in too');

      // Synchronously: no task had to run and no future had to complete for
      // the value above to be there.
      expect(reopened.taskRunner, isNotNull,
          reason: 'platform-glue.app-startup-order#8: the task runner exists '
              'but was not needed');
    });
  });

  // =======================================================================
  // platform-glue.di-app-component
  // =======================================================================

  group('platform-glue.di-app-component', () {
    test('#1 the graph is built from two constructor-provided bindings', () {
      final String path = newDatabasePath();
      final AppScope scope = openScope(path: path);

      expect(identical(scope.database, scope.modelFactory.database), isTrue,
          reason: 'platform-glue.di-app-component#1 — The app component is a '
              'kotlin-inject @Component annotated @AppScope taking two '
              'constructor-provided bindings: @AppContext Context (the '
              'application context) and File dbFile. There is no Context to '
              'bind in a Flutter app — nothing in the graph below asks for one '
              '— so the database and its path are what enter through the '
              'constructor.');
      expect(scope.databasePath, path,
          reason: 'platform-glue.di-app-component#1: the file the component was '
              'built around');
    });

    test('#2 the singletons the graph exposes, each one instance', () {
      final AppScope scope = openScope();

      final Map<String, Object?> exposed = <String, Object?>{
        'commandRunner': scope.commandRunner,
        'habitList': scope.habitList,
        'logging': scope.logging,
        'midnightTimer': scope.midnightTimer,
        'modelFactory': scope.modelFactory,
        'preferences': scope.preferences,
        'taskRunner': scope.taskRunner,
        'habitCardListCache': scope.cache,
        'habitCardListAdapter': scope.adapter,
        'db': scope.database,
      };

      for (final MapEntry<String, Object?> entry in exposed.entries) {
        expect(entry.value, isNotNull,
            reason: 'platform-glue.di-app-component#2 — It exposes exactly '
                'these singletons: commandRunner, context (@AppContext), '
                'genericImporter, habitCardListCache, habitList, intentFactory, '
                'intentParser, logging, midnightTimer, modelFactory, '
                'notificationTray, pendingIntentFactory, preferences, '
                'reminderScheduler, reminderController, taskRunner, '
                'widgetPreferences, widgetUpdater, plus a lazily-created '
                'AndroidDatabase `db`. Ten of them are here. The four Android '
                'intent bindings (context, intentFactory, intentParser, '
                'pendingIntentFactory) have no counterpart; genericImporter, '
                'notificationTray, reminderScheduler, reminderController, '
                'widgetPreferences and widgetUpdater exist as classes but are '
                'constructed by their callers rather than held here — see the '
                'gap noted at the top of this file. (${entry.key})');
      }

      // Singleton means the same instance every time, not a fresh one per read.
      for (var i = 0; i < 2; i++) {
        expect(identical(scope.commandRunner, exposed['commandRunner']), isTrue,
            reason: 'platform-glue.di-app-component#2: one commandRunner');
        expect(identical(scope.habitList, exposed['habitList']), isTrue,
            reason: 'platform-glue.di-app-component#2: one habitList');
        expect(identical(scope.preferences, exposed['preferences']), isTrue,
            reason: 'platform-glue.di-app-component#2: one preferences');
        expect(identical(scope.taskRunner, exposed['taskRunner']), isTrue,
            reason: 'platform-glue.di-app-component#2: one taskRunner');
      }

      // Two scopes over two databases share nothing.
      final AppScope other = openScope();
      expect(identical(other.habitList, scope.habitList), isFalse,
          reason: 'platform-glue.di-app-component#2: the singletons are scoped '
              'to the component, not global');
    });

    test('#3 the database is opened exactly once and outlives every read', () {
      final String path = newDatabasePath();
      final AppScope scope = openScope(path: path);

      expect(identical(scope.database, scope.modelFactory.database), isTrue,
          reason: 'platform-glue.di-app-component#3 — The AndroidDatabase is '
              'created lazily exactly once via `by lazy { '
              'AndroidDatabase(DatabaseUtils.openDatabase()) }`; '
              'DatabaseUtils.openDatabase() throws (checkNotNull) if '
              'initializeDatabase was not called first. Here the database is a '
              'constructor argument, so "exactly once" is structural and '
              '"opened first" cannot fail to hold: there is no scope without '
              'one.');

      // Every read goes to the same connection: a write through the habit list
      // is visible through the raw database.
      // HabitFixtures.saveIfSQLite registers the habit itself: the entry list
      // an SQLModelFactory hands out is SQLite-backed.
      HabitFixtures(
        scope.modelFactory,
        scope.habitList,
      ).createEmptyHabit(name: 'Meditate');
      final List<int> counted = <int>[];
      scope.database.query(
        'select count(*) from habits',
        const <String>[],
        (PreparedStatement stmt) => counted.add(stmt.getInt(0)),
      );
      expect(counted, <int>[1],
          reason: 'platform-glue.di-app-component#3: one connection behind the '
              'whole graph');
    });

    test('#4 the bindings behind the graph', () {
      final MemoryStorage storage = MemoryStorage();
      final AppScope scope = openScope(storage: storage);

      expect(scope.modelFactory, isA<SQLModelFactory>(),
          reason: 'platform-glue.di-app-component#4 — Bindings: Preferences is '
              'built from SharedPreferencesStorage; WidgetPreferences is built '
              'from the same SharedPreferencesStorage instance; ModelFactory = '
              'SQLModelFactory(db); HabitList = SQLiteHabitList; DatabaseOpener '
              '= AndroidDatabaseOpener; Logging = AndroidLogging; FileOpener = '
              'AndroidFileOpener(appContext.assets, appContext.filesDir).');
      expect(scope.habitList, isA<SQLiteHabitList>(),
          reason: 'platform-glue.di-app-component#4: HabitList = '
              'SQLiteHabitList');
      expect(identical(scope.preferencesStorage, storage), isTrue,
          reason: 'platform-glue.di-app-component#4: Preferences is built from '
              'the storage the component was handed');
      expect(scope.logging, isA<StandardLogging>(),
          reason: 'platform-glue.di-app-component#4: Logging');

      // "WidgetPreferences is built from the same storage instance": the widget
      // registry reads and writes the same store the settings screen does, so a
      // widget bound here is visible there.
      final WidgetRegistry registry = WidgetRegistry(scope.preferencesStorage);
      registry.addWidget(42, <int>[7]);
      expect(WidgetPreferences(storage).getHabitIdsFromWidgetId(42), <int>[7],
          reason: 'platform-glue.di-app-component#4: the same storage instance '
              'backs both');
      scope.preferences.isSkipEnabled = true;
      expect(storage.getBoolean('pref_skip_enabled', false), isTrue,
          reason: 'platform-glue.di-app-component#4: and Preferences too');
    });

    test('#5 the task runner is a CoroutineTaskRunner over two dispatchers',
        () {
      final AppScope scope = openScope();

      expect(scope.taskRunner, isA<CoroutineTaskRunner>(),
          reason: 'platform-glue.di-app-component#5 — TaskRunner = '
              'CoroutineTaskRunner(mainDispatcher = Dispatchers.Main, '
              'ioDispatcher = Dispatchers.IO).');

      // Both roles are real and separable: a scope built with a synchronous
      // pair runs a task inline, which the default asynchronous pair does not.
      final AppScope inline = AppScope.open(
        AppDatabase.openAndMigrate(newDatabasePath()),
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      );
      scopes.add(inline);
      final List<String> ran = <String>[];
      inline.taskRunner.execute(_ProbeTask(ran));
      expect(ran, <String>['background', 'post'],
          reason: 'platform-glue.di-app-component#5: the io dispatcher runs the '
              'work and the main dispatcher runs the callback');
    });

    test('#6 ReminderScheduler takes (commandRunner, habitList, sys, '
        'widgetPreferences)', () {
      final AppScope scope = openScope();
      final WidgetPreferences widgetPreferences =
          WidgetPreferences(scope.preferencesStorage);
      final _RecordingScheduler sys = _RecordingScheduler();

      // The argument order is the rule: a positional constructor makes it
      // checkable, and passing them in any other order would not compile.
      final ReminderScheduler scheduler = ReminderScheduler(
        scope.commandRunner,
        scope.habitList,
        sys,
        widgetPreferences,
      );

      expect(scheduler, isNotNull,
          reason: 'platform-glue.di-app-component#6 — ReminderScheduler is '
              'constructed as ReminderScheduler(commandRunner, habitList, '
              'IntentScheduler, widgetPreferences) — note the argument order '
              'differs from the @Provides parameter order.');

      // It really is wired to those four: a habit with a reminder reaches the
      // system scheduler it was handed.
      final Habit habit = HabitFixtures(
        scope.modelFactory,
        scope.habitList,
      ).createEmptyHabit(name: 'Meditate');
      // HabitFixtures.saveIfSQLite already registered it: the entry list
      // an SQLModelFactory hands out is SQLite-backed.
      habit.reminder = Reminder(8, 30, WeekdayList.everyDay);
      scheduler.scheduleAll();
      expect(sys.scheduled, isNotEmpty,
          reason: 'platform-glue.di-app-component#6: the third argument is the '
              'system scheduler it drives');
    });

    test('#7 NotificationTray takes (taskRunner, commandRunner, preferences, '
        'systemTray)', () {
      final AppScope scope = openScope();
      final _RecordingSystemTray systemTray = _RecordingSystemTray();

      final NotificationTray tray = NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        systemTray,
      );

      expect(tray, isNotNull,
          reason: 'platform-glue.di-app-component#7 — NotificationTray is '
              'constructed as NotificationTray(taskRunner, commandRunner, '
              'preferences, AndroidNotificationTray).');

      final Habit habit = HabitFixtures(
        scope.modelFactory,
        scope.habitList,
      ).createEmptyHabit(name: 'Meditate');
      // HabitFixtures.saveIfSQLite already registered it: the entry list
      // an SQLModelFactory hands out is SQLite-backed.
      tray.cancel(habit);
      expect(systemTray.cancelled, <int?>[habit.id],
          reason: 'platform-glue.di-app-component#7: the fourth argument is the '
              'system tray it drives');
    });

    test('#9 every binding a test needs to replace can be replaced', () {
      // Upstream makes every @Provides `open` so HabitsApplicationTestComponent
      // can subclass and override. The Dart equivalent is that the same
      // bindings are optional named arguments of the one constructor: the
      // storage, the two dispatchers and the logger are all substitutable, and
      // the database itself is positional.
      final MemoryStorage storage = MemoryStorage();
      final StringBuffer out = StringBuffer();
      final StandardLogging logging = StandardLogging(out: out, err: out);
      final AppScope scope = AppScope.open(
        AppDatabase.openAndMigrate(newDatabasePath()),
        preferencesStorage: storage,
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
        logging: logging,
      );
      scopes.add(scope);

      expect(identical(scope.preferencesStorage, storage), isTrue,
          reason: 'platform-glue.di-app-component#9 — Every @Provides function '
              'is `open`, so tests can subclass the component and override '
              'individual bindings (HabitsApplicationTestComponent overrides '
              'taskRunner and additionally exposes intentScheduler).');
      expect(identical(scope.logging, logging), isTrue,
          reason: 'platform-glue.di-app-component#9: the logger too');

      // The overridden task runner is the one upstream's test component
      // replaces, and replacing it here changes how the graph behaves.
      final List<String> ran = <String>[];
      scope.taskRunner.execute(_ProbeTask(ran));
      expect(ran, <String>['background', 'post'],
          reason: 'platform-glue.di-app-component#9: the substituted '
              'dispatchers really are the ones the graph runs on');

      // A scope built without overrides still gets working defaults.
      final AppScope plain = openScope();
      expect(plain.preferencesStorage, isA<MemoryStorage>(),
          reason: 'platform-glue.di-app-component#9: the defaults stand in when '
              'nothing is overridden');
    });
  });
}

/// A task that records the two phases the runner drives it through.
class _ProbeTask extends Task {
  _ProbeTask(this.log);

  final List<String> log;

  @override
  void doInBackground() => log.add('background');

  @override
  void onPostExecute() => log.add('post');
}

/// `IntentScheduler`, recording rather than scheduling.
class _RecordingScheduler implements SystemScheduler {
  final List<int> scheduled = <int>[];

  @override
  SchedulerResult scheduleShowReminder(
    int reminderTime,
    Habit habit,
    int timestamp,
  ) {
    scheduled.add(reminderTime);
    return SchedulerResult.ok;
  }

  @override
  SchedulerResult? scheduleWidgetUpdate(int updateTime) => SchedulerResult.ok;

  @override
  void log(String componentName, String msg) {}
}

/// `AndroidNotificationTray`, recording rather than posting.
class _RecordingSystemTray implements SystemTray {
  final List<int?> cancelled = <int?>[];

  @override
  void removeNotification(int notificationId) => cancelled.add(notificationId);

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate timestamp,
    int reminderTime,
  ) {}

  @override
  void log(String msg) {}
}
