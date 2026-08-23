/// Application startup, asserted through the entry point that actually runs it.
///
/// `HabitsApplication.onCreate` is ten steps long and its note says the order
/// is load-bearing: `setToday()` has to happen before anything reads a habit,
/// because `getToday()` throws until it has. This port collapses the DI
/// component and `onCreate` into one place — `AppScope.boot()` opens the
/// database and the settings file, `AppScope.open()` wires the graph on top of
/// them — and `main()` does nothing but await `boot()` and hand the result to
/// the widget tree.
///
/// What is asserted here is the *sequence*, not the inventory: the graph itself
/// belongs to `platform-glue.di-app-component` and is covered in
/// test/state/app_scope_test.dart. The tests below drive the real
/// `AppScope.boot()` over a mocked application-support directory, and where a
/// claim is about ordering they instrument the collaborators and read back the
/// order the calls actually arrived in, rather than inferring it from the
/// finished state.
///
/// ## Rules that have no counterpart in this build
///
/// Reported as gaps rather than asserted, because asserting them would mean
/// pinning behaviour the port should grow, not keep:
///
///  * `#5` — nothing writes `prefs.lastAppVersion` at startup. The preference
///    itself is ported (key `last_version`, default 0) and is asserted below;
///    the launch-time write is missing, so an upgrade is indistinguishable
///    from a relaunch.
///  * `#9`, `#11` — no widget updater is started and no start-of-day widget
///    refresh is scheduled. `WidgetSync` exists in lib/state/widget_sync.dart
///    and nothing constructs it.
///  * `#10` — no reminder scheduler and no notification tray are registered as
///    command listeners at launch, so a freshly started app schedules no
///    reminders until something else runs a command.
///  * `#12` — `onTerminate`'s three `stopListening()` calls have nothing to
///    stop. The half of the rule that does exist — tearing the scope down in
///    an order that cannot touch a closed database — is asserted.
///
/// Two more are asserted only in the half the port kept: `#2` (there is no test
/// mode, so the database file is never deleted at launch and is always
/// `uhabits.db`) and `#3` (an unknown database version does not crash startup,
/// but is not quarantined either).
library;

// The commands, preferences, task and time layers are reached by their `src`
// path, exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/file_preferences_storage.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_adapter.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';
import 'package:uhabits_core/uhabits_core.dart';

// ---------------------------------------------------------------------------
// Instrumentation
// ---------------------------------------------------------------------------

/// Whether the process-global "today" has been stamped yet.
///
/// `getToday()` throws until `setToday()` has run, which is exactly the
/// tripwire the startup order exists to avoid — so it doubles as a probe.
bool todayIsSet() {
  try {
    getToday();
    return true;
  } on StateError {
    return false;
  }
}

/// One thing the startup sequence did, and whether today was already stamped
/// when it did it.
class Step {
  Step(this.label) : todayWasSet = todayIsSet();

  /// `pref:<key>` for a settings read, `sql:<verb> <table>` for a database
  /// statement, or a marker planted by the test.
  final String label;

  final bool todayWasSet;

  @override
  String toString() => '$label${todayWasSet ? '' : ' (today unset)'}';
}

/// A [Database] that records every statement it is asked to prepare.
class RecordingDatabase implements Database {
  RecordingDatabase(this.inner, this.steps);

  final Database inner;
  final List<Step> steps;

  @override
  PreparedStatement prepareStatement(String sql) {
    steps.add(Step('sql:${_summarize(sql)}'));
    return inner.prepareStatement(sql);
  }

  @override
  void close() {
    steps.add(Step('db:close'));
    inner.close();
  }

  /// `SELECT ... FROM Habits ...` -> `SELECT Habits`; enough to tell a habit
  /// read from an entry read from a PRAGMA.
  static String _summarize(String sql) {
    final String flat = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
    final RegExpMatch? table =
        RegExp(r'\b(?:FROM|INTO|UPDATE)\s+(\w+)', caseSensitive: false)
            .firstMatch(flat);
    final String verb = flat.split(' ').first.toUpperCase();
    return table == null ? verb : '$verb ${table.group(1)}';
  }
}

/// A [PreferencesStorage] that records every read, delegating the values.
class RecordingStorage extends PreferencesStorage {
  RecordingStorage(this.steps, {PreferencesStorage? inner})
      : inner = inner ?? MemoryStorage();

  final PreferencesStorage inner;
  final List<Step> steps;

  void _read(String key) => steps.add(Step('pref:$key'));

  @override
  void onAttached(Preferences preferences) => inner.onAttached(preferences);

  @override
  void clear() => inner.clear();

  @override
  bool getBoolean(String key, bool defValue) {
    _read(key);
    return inner.getBoolean(key, defValue);
  }

  @override
  int getInt(String key, int defValue) {
    _read(key);
    return inner.getInt(key, defValue);
  }

  @override
  int getLong(String key, int defValue) {
    _read(key);
    return inner.getLong(key, defValue);
  }

  @override
  String getString(String key, String defValue) {
    _read(key);
    return inner.getString(key, defValue);
  }

  @override
  void putBoolean(String key, bool value) => inner.putBoolean(key, value);

  @override
  void putInt(String key, int value) => inner.putInt(key, value);

  @override
  void putLong(String key, int value) => inner.putLong(key, value);

  @override
  void putString(String key, String value) => inner.putString(key, value);

  @override
  void remove(String key) => inner.remove(key);
}

/// A [CommandRunnerListener] that only remembers what it was told.
class ProbeListener implements CommandRunnerListener {
  final List<Command> finished = <Command>[];

  @override
  void onCommandFinished(Command command) => finished.add(command);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The directory `getApplicationSupportDirectory()` answers with — the one
  /// `AppScope.boot()` puts `uhabits.db` and `preferences.json` in.
  late Directory supportDir;

  final List<AppScope> scopes = <AppScope>[];
  final int Function() realClock = systemCurrentTimeMillis;
  final TimeZone Function() realZone = getDefaultTimeZone;

  setUp(() {
    resetToday();
    supportDir = Directory.systemTemp.createTempSync('uhabits_startup');
    // `flutter test` registers no plugins, so path_provider is still its
    // method-channel implementation and answering the channel is enough to
    // point the whole app at a temporary directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => supportDir.path,
    );
    // `computeToday` reads the top-level clock and `getDefaultTimeZone`, not
    // the `DateUtils` test hooks, so those are what a test has to pin.
    getDefaultTimeZone = () => const FixedTimeZone(0);
    systemCurrentTimeMillis = realClock;
  });

  tearDown(() async {
    // `AppScope.open` queues the list cache's first refresh, which reads
    // `getToday()` and touches the database. Letting it run before anything is
    // reset or closed keeps a finished test from failing a later one.
    await pumpEventQueue();
    for (final AppScope scope in scopes) {
      try {
        scope.close();
      } on Object {
        // Already closed by the test that opened it.
      }
    }
    scopes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    supportDir.deleteSync(recursive: true);
    systemCurrentTimeMillis = realClock;
    getDefaultTimeZone = realZone;
    resetToday();
  });

  AppScope track(AppScope scope) {
    scopes.add(scope);
    return scope;
  }

  Future<AppScope> boot() async => track(await AppScope.boot());

  /// A scope over [path] on synchronous dispatchers, so everything `open` sets
  /// in motion has finished by the time it returns.
  AppScope openScope(
    String path, {
    PreferencesStorage? storage,
    Database Function(Database)? wrap,
    Dispatcher dispatcher = const UnconfinedTestDispatcher(),
  }) {
    final Database database = AppDatabase.openAndMigrate(path);
    return track(AppScope.open(
      wrap == null ? database : wrap(database),
      databasePath: path,
      preferencesStorage: storage,
      logging: StandardLogging(),
      mainDispatcher: dispatcher,
      ioDispatcher: dispatcher,
    ));
  }

  /// Puts [count] habits, each with two entries, into the database at [path].
  void seedHabits(String path, {int count = 2}) {
    setToday(computeToday());
    final Database database = AppDatabase.openAndMigrate(path);
    final SQLModelFactory factory = SQLModelFactory(database);
    final HabitList list = factory.buildHabitList();
    for (int i = 0; i < count; i++) {
      final Habit habit =
          HabitFixtures(factory, list).createEmptyHabit(name: 'Habit $i');
      list.add(habit);
      habit.originalEntries.add(Entry(getToday(), Entry.yesManual));
      habit.originalEntries.add(Entry(getToday().minus(1), Entry.yesManual));
    }
    database.close();
    resetToday();
  }

  // =======================================================================
  // platform-glue.app-startup-order
  // =======================================================================

  group('platform-glue.app-startup-order', () {
    test('#1 boot() is onCreate: the database, the graph, today, the habits, '
        'then the runners', () async {
      seedHabits(p.join(supportDir.path, databaseFilename));
      expect(todayIsSet(), isFalse,
          reason: 'platform-glue.app-startup-order#1: nothing has stamped '
              'today before the app starts');

      final AppScope scope = await boot();

      const String rule =
          'platform-glue.app-startup-order#1 — HabitsApplication.onCreate '
          'performs steps in this exact order: (1) if isTestMode(), delete the '
          'database file; (2) DatabaseUtils.initializeDatabase(context); (3) '
          'build the DI component; (4) write prefs.lastAppVersion = '
          'BuildConfig.VERSION_CODE; (5) setToday(computeToday('
          'prefs.midnightDelayHours, 0)); (6) recompute every habit; (7) start '
          'the widget updater; (8) start the reminder scheduler; (9) start the '
          'notification tray; (10) run scheduleAll + updateWidgets on the task '
          'runner. Steps 1, 4 and 7-10 have no counterpart here: there is no '
          'test mode, nothing writes lastAppVersion, and nothing starts the '
          'three listeners at launch (see the library comment). Steps 2, 3, 5 '
          'and 6 are all of AppScope.boot, in this order.';

      // (2) the database file is open and migrated.
      expect(scope.databasePath, p.join(supportDir.path, databaseFilename),
          reason: rule);
      expect(File(scope.databasePath!).existsSync(), isTrue, reason: rule);
      expect(scope.database.getVersion(), databaseVersion,
          reason: 'platform-glue.app-startup-order#1: (2) opened AND migrated '
              '— boot returns only once the file is at the current schema');

      // (3) the graph on top of it.
      expect(scope.modelFactory.database, same(scope.database),
          reason: 'platform-glue.app-startup-order#1: (3) the model factory is '
              'built over that same connection');
      expect(scope.habitList.modelFactory, same(scope.modelFactory),
          reason: 'platform-glue.app-startup-order#1: (3) and the habit list '
              'over that factory');

      // (5) today, from the preference the settings file holds.
      expect(getToday(), computeToday(scope.preferences.midnightDelayHours, 0),
          reason: 'platform-glue.app-startup-order#1: (5) today is stamped '
              'from the midnight-delay preference');

      // (6) every habit recomputed — scores exist without anything having
      // pumped a frame or awaited a task.
      expect(scope.habitList.size(), 2, reason: rule);
      for (final Habit habit in scope.habitList) {
        expect(habit.scores[getToday()].value, greaterThan(0.0),
            reason: 'platform-glue.app-startup-order#1: (6) recompute ran for '
                'every habit before boot returned');
      }

      // and the runners and timers, wired last.
      expect(scope.taskRunner, isA<CoroutineTaskRunner>(), reason: rule);
      expect(scope.commandRunner, isA<CommandRunner>(), reason: rule);
      expect(scope.midnightTimer, isA<MidnightTimer>(), reason: rule);
      expect(scope.cache, isA<HabitCardListCache>(), reason: rule);
      expect(scope.adapter, isA<HabitCardListAdapter>(), reason: rule);
      expect(scope.preferencesStorage, isA<FilePreferencesStorage>(),
          reason: 'platform-glue.app-startup-order#1: settings are read from a '
              'file next to the database, which is this port\'s '
              'SharedPreferences');
      expect(
        File(p.join(supportDir.path, preferencesFilename)).existsSync(),
        isTrue,
        reason: rule,
      );
    });

    test('#1 the recorded order: the midnight-delay preference, then today, '
        'then every habit read', () {
      final String path = p.join(supportDir.path, databaseFilename);
      seedHabits(path);

      final List<Step> steps = <Step>[];
      final AppScope scope = openScope(
        path,
        storage: RecordingStorage(steps),
        wrap: (Database database) => RecordingDatabase(database, steps),
      );
      expect(scope.habitList.size(), 2);

      const String rule =
          'platform-glue.app-startup-order#1: the ordering clause, read back '
          'from the calls themselves. Every settings read and every SQL '
          'statement issued while the scope was being built was recorded, in '
          'order, together with whether the global "today" had been stamped '
          'yet.';

      expect(steps, isNotEmpty, reason: rule);
      final List<Step> reads =
          steps.where((Step s) => s.label.startsWith('pref:')).toList();
      final List<Step> sql =
          steps.where((Step s) => s.label.startsWith('sql:')).toList();

      expect(reads.first.label, 'pref:pref_midnight_delay',
          reason: '$rule The first thing the sequence reads at all is the '
              'midnight-delay preference, which is step (5)\'s argument.');
      expect(reads.first.todayWasSet, isFalse,
          reason: '$rule It is read before today exists — it is what today is '
              'computed from.');

      expect(sql, isNotEmpty,
          reason: '$rule The habits really were read from the database.');
      expect(
        steps.indexOf(reads.first),
        lessThan(steps.indexOf(sql.first)),
        reason: '$rule No statement is prepared before it.',
      );
      expect(
        sql.where((Step s) => !s.todayWasSet),
        isEmpty,
        reason: '$rule And no statement at all is prepared while today is '
            'still unset — which is the whole point of putting (5) before (6).',
      );
      expect(
        sql.map((Step s) => s.label).toSet(),
        containsAll(<String>['sql:SELECT Habits', 'sql:SELECT Repetitions']),
        reason: '$rule Both the habit rows and their entries are read, because '
            'recompute() walks the entries.',
      );
    });

    test('#1 the ordering is load-bearing: recompute before setToday throws',
        () {
      final String path = p.join(supportDir.path, databaseFilename);
      seedHabits(path, count: 1);

      // The same two steps as `open`, in the wrong order.
      final Database database = AppDatabase.openAndMigrate(path);
      addTearDown(database.close);
      final SQLModelFactory factory = SQLModelFactory(database);
      final HabitList list = factory.buildHabitList();

      expect(todayIsSet(), isFalse);
      expect(
        () {
          for (final Habit habit in list) {
            habit.recompute();
          }
        },
        throwsA(isA<StateError>().having((StateError e) => e.message,
            'message', contains('getToday() called before setToday()'))),
        reason: 'platform-glue.app-startup-order#1: the note on this feature '
            'says setToday() must happen before any habit recompute, because '
            'getToday() throws "getToday() called before setToday()" if unset. '
            'It really does — so a scope that comes back at all has done (5) '
            'before (6).',
      );
    });

    test('#2 the file is always uhabits.db, and startup never deletes it',
        () async {
      expect(databaseFilename, 'uhabits.db',
          reason: 'platform-glue.app-startup-order#2 — isTestMode() returns '
              'true iff Class.forName("org.isoron.uhabits.BaseAndroidTest") '
              'succeeds; when true the database file is deleted at startup and '
              'the filename used is "test.db" instead of "uhabits.db". There '
              'is no Dart equivalent of a class-path probe and no test build '
              'variant here: the name is a single constant with no second '
              'branch, so the only half of the rule the port can hold is the '
              'production one.');

      final AppScope first = await boot();
      final Habit habit = HabitFixtures(first.modelFactory, first.habitList)
          .createEmptyHabit(name: 'Meditate');
      first.habitList.add(habit);
      await pumpEventQueue();
      first.close();
      scopes.remove(first);
      resetToday();

      final AppScope second = await boot();
      expect(second.habitList.size(), 1,
          reason: 'platform-glue.app-startup-order#2: a second launch opens '
              'the same file and finds the habit still in it — step (1) never '
              'fires');
      expect(second.habitList.first.name, 'Meditate',
          reason: 'platform-glue.app-startup-order#2');
    });

    test('#3 an unknown database version does not crash startup', () {
      final String path = p.join(supportDir.path, databaseFilename);
      seedHabits(path, count: 1);

      // A file written by a newer build of the app.
      final Database stamped = AppDatabase.openAndMigrate(path);
      stamped.setVersion(databaseVersion + 40);
      stamped.close();

      const String rule =
          'platform-glue.app-startup-order#3 — DatabaseUtils.initializeDatabase '
          'is wrapped in try/catch for UnsupportedDatabaseVersionException: on '
          'that exception the existing database file is renamed to its absolute '
          'path + ".invalid" and initializeDatabase is retried, so a too-new/'
          'too-old DB never crashes startup but silently starts a fresh empty '
          'database. Only the first half is ported: opening a file stamped '
          'past the app\'s own schema version returns normally. The quarantine '
          'is NOT ported — there is no UnsupportedDatabaseVersionException in '
          'this codebase and nothing renames a file aside — so a database whose '
          'schema really has moved on would fail later, at the first query, '
          'instead of being set aside at the door. Reported as a gap.';

      late Database reopened;
      expect(() => reopened = AppDatabase.openAndMigrate(path), returnsNormally,
          reason: rule);
      addTearDown(reopened.close);

      // The other direction — a file older than the app — is ported in full:
      // an unstamped file is taken to be schema 8 and migrated up to the
      // current version, which is the whole "never crashes startup" half.
      final String old = p.join(supportDir.path, 'old.db');
      File(old).createSync();
      final Database migrated = AppDatabase.openAndMigrate(old);
      addTearDown(migrated.close);
      expect(migrated.getVersion(), databaseVersion,
          reason: 'platform-glue.app-startup-order#3: an older file is brought '
              'forward rather than rejected');
    });

    test('#4 the DI root is a value passed to the app, not a global', () async {
      final AppScope first = await boot();
      final AppScope second = track(AppScope.open(
        AppDatabase.openAndMigrate(p.join(supportDir.path, 'second.db')),
        databasePath: p.join(supportDir.path, 'second.db'),
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      ));

      expect(identical(first, second), isFalse,
          reason: 'platform-glue.app-startup-order#4 — The DI root is created '
              'as HabitsApplicationComponent::class.create(appContext = '
              'applicationContext, dbFile = DatabaseUtils.getDatabaseFile(this)'
              ') and stored in a static (companion) lateinit var '
              'HabitsApplication.component; the instance property `component` '
              'just returns that static. The port has no static: boot() '
              'returns the scope and main() passes it into the widget tree, so '
              'two scopes can exist side by side — which is what lets every '
              'test in this file build one without tearing down a global.');
      expect(identical(first.database, second.database), isFalse,
          reason: 'platform-glue.app-startup-order#4: each one owns its own '
              'connection');
      expect(first.databasePath, isNot(second.databasePath),
          reason: 'platform-glue.app-startup-order#4: and its own file, which '
              'is the `dbFile` constructor binding');
    });

    test('#5 lastAppVersion is the int under "last_version", default 0', () {
      final String path = p.join(supportDir.path, preferencesFilename);
      final Preferences preferences =
          Preferences(FilePreferencesStorage.atPath(path));

      const String rule =
          'platform-glue.app-startup-order#5 — prefs.lastAppVersion is '
          'persisted as SharedPreferences int key "last_version" (default 0 '
          'when absent) and is set to BuildConfig.VERSION_CODE (20301) on every '
          'launch. The preference is ported exactly, including the key and the '
          'default; the launch-time write is NOT — nothing in AppScope.boot '
          'touches it, and this build has no version code to write. Reported '
          'as a gap; asserting the current value would pin the gap in place.';

      expect(preferences.lastAppVersion, 0, reason: rule);

      preferences.lastAppVersion = 20301;
      expect(
        (jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>)[
            'last_version'],
        '20301',
        reason: '$rule The key really is "last_version".',
      );

      // And it survives a relaunch, which is what "persisted" buys.
      expect(Preferences(FilePreferencesStorage.atPath(path)).lastAppVersion,
          20301,
          reason: rule);
    });

    test('#6 today follows the midnight-delay preference in the settings file',
        () async {
      // 2015-01-26 01:30 UTC. With the delay off the logical day is the 26th;
      // with it on, the first three hours still belong to the 25th.
      systemCurrentTimeMillis = () => 1422235800000;

      File(p.join(supportDir.path, preferencesFilename)).writeAsStringSync(
          jsonEncode(<String, String>{'pref_midnight_delay': 'true'}));

      final AppScope delayed = await boot();
      expect(delayed.preferences.midnightDelayHours, 3,
          reason: 'platform-glue.app-startup-order#6 — The global "today" is '
              'set once at startup: setToday(computeToday(hourOffset = '
              'preferences.midnightDelayHours, minuteOffset = 0)). '
              'midnightDelayHours is 3 when SharedPreferences boolean '
              '"pref_midnight_delay" is true, otherwise 0.');
      expect(getToday(), computeToday(3, 0),
          reason: 'platform-glue.app-startup-order#6: and that is the offset '
              'today was computed with');
      expect(getToday(), isNot(computeToday(0, 0)),
          reason: 'platform-glue.app-startup-order#6: at 01:30 the two answers '
              'really differ, so the assertion above is not vacuous');
      await pumpEventQueue();
      delayed.close();
      scopes.remove(delayed);
      resetToday();

      File(p.join(supportDir.path, preferencesFilename)).writeAsStringSync(
          jsonEncode(<String, String>{'pref_midnight_delay': 'false'}));

      final AppScope plain = await boot();
      expect(plain.preferences.midnightDelayHours, 0,
          reason: 'platform-glue.app-startup-order#6: otherwise 0');
      expect(getToday(), computeToday(0, 0),
          reason: 'platform-glue.app-startup-order#6');
    });

    test('#7 computeToday floors, so instants before 2000 land a day earlier',
        () {
      const String rule =
          'platform-glue.app-startup-order#7 — computeToday(hourOffset, '
          'minuteOffset) = LocalDate(daysSince2000) where daysSince2000 = '
          'floorDiv(System.currentTimeMillis() + timezoneOffset(now) - '
          'hourOffset*3600000 - minuteOffset*60000, 86400000) - 10957.';

      // The epoch itself: 0 days since 1970 is 10957 days before 2000.
      systemCurrentTimeMillis = () => 0;
      expect(computeToday().daysSince2000, -10957, reason: rule);

      // One millisecond earlier is a *whole day* earlier, because the division
      // floors rather than truncating towards zero. Dart's `~/` would answer
      // -10957 here, so this is the assertion that pins floorDiv.
      systemCurrentTimeMillis = () => -1;
      expect(computeToday().daysSince2000, -10958, reason: rule);

      // 2000-01-01T00:00:00Z is day 0 by construction.
      systemCurrentTimeMillis = () => 946684800000;
      expect(computeToday().daysSince2000, 0, reason: rule);

      // The hour offset is subtracted before the division, so 02:00 with a
      // three-hour delay is still the previous day.
      systemCurrentTimeMillis = () => 946684800000 + 2 * 3600000;
      expect(computeToday(3, 0).daysSince2000, -1, reason: rule);
      expect(computeToday(0, 0).daysSince2000, 0, reason: rule);

      // ...and so is 00:59 with a one-hour, zero-minute offset, while
      // 00:59 with 0h59m is not.
      systemCurrentTimeMillis = () => 946684800000 + 59 * 60000;
      expect(computeToday(1, 0).daysSince2000, -1, reason: rule);
      expect(computeToday(0, 59).daysSince2000, 0, reason: rule);

      // The timezone offset is added, not subtracted: east of UTC the day
      // turns over earlier in absolute time.
      getDefaultTimeZone = () => const FixedTimeZone(2 * 3600000);
      systemCurrentTimeMillis = () => 946684800000 - 1 * 3600000;
      expect(computeToday().daysSince2000, 0, reason: rule);
    });

    test('#8 every habit is recomputed, synchronously, before boot returns',
        () async {
      final String path = p.join(supportDir.path, databaseFilename);
      seedHabits(path, count: 3);

      final AppScope scope = await boot();

      // Nothing is pumped and nothing is awaited between boot() and these
      // reads: if recompute were queued on the task runner instead of run
      // inline, the scores would still be zero here.
      for (final Habit habit in scope.habitList) {
        expect(habit.scores[getToday()].value, greaterThan(0.0),
            reason: 'platform-glue.app-startup-order#8 — Every habit in the '
                'habit list has recompute() called synchronously on the main '
                'thread during onCreate, before widgets/reminders start. '
                '(${habit.name})');
        expect(habit.computedEntries.get(getToday()).value, Entry.yesManual,
            reason: 'platform-glue.app-startup-order#8: the computed entries '
                'are filled in too (${habit.name})');
      }
      expect(scope.habitList.size(), 3,
          reason: 'platform-glue.app-startup-order#8: every habit, not the '
              'first one');
    });

    test('#10 the command runner is the listener registry the three '
        'collaborators would join', () async {
      final AppScope scope = await boot();
      final ProbeListener probe = ProbeListener();

      scope.commandRunner.addListener(probe);
      final Habit habit = HabitFixtures(scope.modelFactory, scope.habitList)
          .createEmptyHabit(name: 'Run');
      final Command command = CreateHabitCommand(
        scope.modelFactory,
        scope.habitList,
        habit,
      );
      scope.commandRunner.run(command);
      await pumpEventQueue();

      expect(probe.finished, <Command>[command],
          reason: 'platform-glue.app-startup-order#10 — '
              'reminderScheduler.startListening() and '
              'notificationTray.startListening() register them as CommandRunner '
              'listeners (notificationTray additionally registers as a '
              'Preferences listener). Neither collaborator is started at launch '
              'here — that is the gap this slice reports — but the registry '
              'they would join is built by boot() and works: a listener added '
              'to it hears every finished command.');
      expect(scope.cache, isA<CommandRunnerListener>(),
          reason: 'platform-glue.app-startup-order#10: the one listener this '
              'build does have is the habit-list cache, which registers itself '
              'on attach rather than at launch');

      scope.commandRunner.removeListener(probe);
    });

    test('#12 close() is onTerminate: the cache is cancelled and the '
        'connection is released', () async {
      final String path = p.join(supportDir.path, databaseFilename);
      seedHabits(path);

      final List<Step> steps = <Step>[];
      final AppScope scope = openScope(
        path,
        wrap: (Database database) => RecordingDatabase(database, steps),
      );
      expect(scope.habitList.size(), 2);

      scope.close();
      scopes.remove(scope);

      expect(steps.last.label, 'db:close',
          reason: 'platform-glue.app-startup-order#12 — onTerminate stops '
              'listening in the reverse-ish order: '
              'reminderScheduler.stopListening(), widgetUpdater.stopListening()'
              ', notificationTray.stopListening(), then super.onTerminate(). '
              'None of the three exists in this build (reported as a gap), so '
              'what is left of the rule is the shape: AppScope.close cancels '
              'the list cache\'s work first and releases the connection last, '
              'so the connection is the final thing the scope touches.');
      expect(() => scope.database.prepareStatement('SELECT 1'),
          throwsA(anything),
          reason: 'platform-glue.app-startup-order#12: and it really is '
              'released — Android never closes the database at all, because '
              'the process is going away; a Flutter test process is not, so '
              'the scope owns the connection and hands it back.');
    });
  });
}
