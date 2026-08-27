/// How the app keeps sleep habits current.
///
/// The logic of a sync is tested in the core, on plain Dart. What is tested
/// here is the wiring: that the app actually asks for it, at the two moments
/// that matter — coming back to the foreground, and the platform reporting new
/// data — and that a habit which is not about sleep is left alone.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/health_kit_sleep_source.dart';
import 'package:uhabits/platform/sleep_data_source_factory.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Counts what was asked of it and answers with nothing.
class CountingSource implements SleepDataSource {
  int reads = 0;
  int backgroundDeliveryCalls = 0;
  final List<List<int>> windows = <List<int>>[];
  Future<void> Function()? onChanged;

  @override
  bool get hasHealthStore => true;

  @override
  Future<bool> isAuthorized() async => true;

  @override
  Future<bool> requestAuthorization() async => true;

  @override
  Future<List<SleepSegment>> readSegments(int from, int to) async {
    reads++;
    windows.add(<int>[from, to]);
    return const <SleepSegment>[];
  }

  @override
  Future<void> writeSession(int start, int end) async {}

  @override
  Future<void> enableBackgroundDelivery(
      Future<void> Function() onChanged) async {
    backgroundDeliveryCalls++;
    this.onChanged = onChanged;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;
  late CountingSource source;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    // SleepSync deliberately does not read getToday(), which carries the
    // midnight-delay preference, so pinning that alone would leave the sleep
    // side on the real clock.
    DateUtils.setFixedLocalTime((9000 + 10957) * 86400000 + 3 * 3600000);
    setToday(LocalDate(9000));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    source = CountingSource();
    scope = AppScope.open(
      database,
      sleepSource: source,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
  });

  tearDown(() {
    // The scope owns the database, and closing it is how a scope is told to
    // stop: a sleep sync can still be waiting on the platform, and it checks
    // before it writes. Closing the database behind the scope's back leaves
    // that check answering yes to a database that is gone. Closing twice is
    // allowed, which is why the tests that close it themselves need nothing
    // here.
    scope.close();
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  /// A habit with both rows a sleep habit has: the goal sleep is scored
  /// against, and the mark the sweep enumerates by.
  ///
  /// Written as a pair because every path that makes one writes both
  /// (`computed.definition#8`); a fixture with only the goal is a device state
  /// the app cannot produce.
  Habit addSleepHabit({required String name}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository
        .saveGoal(habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    return habit;
  }

  Habit addOrdinaryHabit({required String name}) {
    final Habit habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    return habit;
  }

  group('a habit that has just been made a sleep habit', () {
    test('is read from the platform without waiting for a resume', () async {
      // The editor is what creates one, and until it does the habit has no
      // goal, so no sync has ever had anything to look for. Left to the
      // foreground sync, the screen a person opens straight after saving
      // shows an empty fortnight until they switch away and back.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.sleep);
      model.nameController.text = 'Sleep';
      expect(source.reads, 0, reason: 'sleep.sync#7');

      expect(model.save(), isTrue, reason: 'sleep.sync#7');
      await pumpEventQueue();

      expect(source.reads, greaterThan(0), reason: 'sleep.sync#7');
    });
  });

  group('which habits are synced', () {
    test('one read per sleep habit, and none for the others', () async {
      addSleepHabit(name: 'Sleep');
      addSleepHabit(name: 'Nap');
      addOrdinaryHabit(name: 'Run');

      await scope.syncSleepHabits();

      expect(source.reads, 2, reason: 'sleep.habit-type#4');
    });

    test('a habit with no goal is not a sleep habit', () async {
      addOrdinaryHabit(name: 'Run');
      expect(scope.sleepRepository.sleepHabitIds(), isEmpty,
          reason: 'sleep.habit-type#4');
      await scope.syncSleepHabits();
      expect(source.reads, 0, reason: 'sleep.habit-type#4');
    });

    test('syncing with no sleep habits at all does nothing and does not throw',
        () async {
      await scope.syncSleepHabits();
      expect(scope.sleepRepository.sleepHabitIds(), isEmpty,
          reason: 'sleep.habit-type#4');
    });

    test('a habit becoming a sleep habit is picked up without a restart',
        () async {
      final Habit habit = addOrdinaryHabit(name: 'Bedtime');
      expect(scope.sleepRepository.sleepHabitIds(), isEmpty,
          reason: 'sleep.habit-type#4');

      scope.sleepRepository.saveGoal(
          habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));

      expect(scope.sleepRepository.sleepHabitIds(), <int>[habit.id!],
          reason: 'sleep.habit-type#4');
    });

    test('an archived habit is left alone', () async {
      final Habit habit = addSleepHabit(name: 'Sleep');
      habit.isArchived = true;

      await scope.syncSleepHabits();

      expect(source.reads, 0, reason: 'computed.lifecycle#1');
    });
  });

  group('the platform source', () {
    test('is HealthKit on iOS and absent elsewhere', () {
      // The factory is the one place that decides, so that nothing above it
      // has to know which platform it is running on.
      final SleepDataSource resolved = defaultSleepDataSource();
      expect(
        resolved,
        isA<HealthKitSleepSource>().or(isA<NoSleepDataSource>()),
        reason: 'sleep.sync#5',
      );
    });

    test('background delivery is asked for once, with somewhere to report',
        () async {
      await source.enableBackgroundDelivery(() async {});
      expect(source.backgroundDeliveryCalls, 1, reason: 'sleep.sync#1');
      expect(source.onChanged, isNotNull,
          reason: 'sleep.sync#1 — waking the app with nowhere to report would '
              'be worse than not waking it');
    });

    test('what the platform reports triggers a sync', () async {
      var synced = 0;
      await source.enableBackgroundDelivery(() async => synced++);
      await source.onChanged!();
      expect(synced, 1, reason: 'sleep.sync#1');
    });
  });

  group('the morning question', () {
    test('is an hour after the goal wake time', () {
      final Habit habit = addSleepHabit(name: 'Sleep');
      final int? at = scope.sleepPromptInstant(habit);
      expect(at, isNotNull, reason: 'sleep.reminder#1');

      final int minuteOfDay = localMinutesOf(at!, 0);
      expect(minuteOfDay, 8 * 60, reason: 'sleep.reminder#1');
    });

    test('a habit that is not about sleep has none', () {
      final Habit habit = addOrdinaryHabit(name: 'Run');
      expect(scope.sleepPromptInstant(habit), isNull,
          reason: 'sleep.reminder#3');
    });

    test('moves to tomorrow once the night is on record', () {
      final Habit habit = addSleepHabit(name: 'Sleep');
      final int before = scope.sleepPromptInstant(habit)!;

      scope.sleepRepository.upsert(
        habit.id!,
        9000,
        const SleepEpisode(
          bedStartMillis: 0,
          wakeEndMillis: 1,
          asleepMinutes: 480,
          utcOffsetMinutes: 0,
        ),
        manual: false,
      );

      final int after = scope.sleepPromptInstant(habit)!;
      expect(after, greaterThan(before), reason: 'sleep.reminder#3');
      expect(after - before, 86400000, reason: 'sleep.reminder#3');
    });

    test('follows the goal rather than the device clock', () {
      final Habit habit = addSleepHabit(name: 'Sleep');
      final int home = scope.sleepPromptInstant(habit)!;

      // Two nights recorded three hours east start the goal drifting.
      for (final int day in <int>[8998, 8999]) {
        scope.sleepRepository.upsert(
          habit.id!,
          day,
          const SleepEpisode(
            bedStartMillis: 0,
            wakeEndMillis: 1,
            asleepMinutes: 480,
            utcOffsetMinutes: 180,
          ),
          manual: false,
        );
      }

      final int drifted = scope.sleepPromptInstant(habit)!;
      expect(drifted, isNot(home), reason: 'sleep.reminder#2');
    });
  });

  group('a scope that is torn down mid-sync', () {
    test('stops rather than reaching a closed database', () async {
      // The startup sync is deliberately not awaited, so it can still be in
      // flight when the app is closed — in a test that closes at once, and in
      // an app the person leaves the moment it opens.
      addSleepHabit(name: 'Sleep');
      final Future<void> inFlight = scope.syncSleepHabits();
      scope.close();
      await inFlight;
      expect(true, isTrue, reason: 'sleep.sync#1 — it did not throw');
    });

    test('a sync started after close does nothing at all', () async {
      addSleepHabit(name: 'Sleep');
      final int before = source.reads;
      scope.close();
      await scope.syncSleepHabits();
      expect(source.reads, before, reason: 'sleep.sync#1');
    });
  });

  group('a cold start', () {
    test('syncs without waiting for a return to the foreground', () async {
      // Opening the app for the first time that day is not a resume, so a
      // habit that only caught up on resume would show yesterday's nights as
      // zeros until the person happened to switch away and back.
      addSleepHabit(name: 'Sleep');
      scope.sleepRepository.upsert(
        1,
        8999,
        SleepEpisode(
          bedStartMillis: (8998 + 10957) * 86400000 + 1380 * 60000,
          wakeEndMillis: (8999 + 10957) * 86400000 + 420 * 60000,
          asleepMinutes: 480,
          utcOffsetMinutes: 0,
        ),
        manual: false,
      );

      final Habit habit = scope.habitList.getById(1)!;
      expect(habit.originalEntries.get(LocalDate(8999)).value, Entry.unknown,
          reason: 'sleep.sync#1');

      await scope.syncSleepHabits();

      expect(habit.originalEntries.get(LocalDate(8999)).value,
          greaterThan(0), reason: 'sleep.sync#1');
    });
  });

  group('what a sync actually asks for', () {
    test('the first sync reaches back through the history', () async {
      // A habit nothing has ever been read for. The fortnight below is the
      // healing window, which is a different job.
      addSleepHabit(name: 'Sleep');
      await scope.syncSleepHabits();
      expect(source.windows.single.last - source.windows.single.first,
          (historyHorizonDays + 1) * DateUtils.dayLength,
          reason: 'sleep.history#1');
    });

    test('and every one after it is a fortnight of days', () async {
      final Habit habit = addSleepHabit(name: 'Sleep');
      await scope.syncSleepHabits();
      await scope.syncSleepHabits();

      expect(source.windows.last.last - source.windows.last.first,
          (recentWindowDays + 1) * DateUtils.dayLength,
          reason: 'sleep.history#3');
      expect(scope.sleepRepository.coveredFromDay(habit.id!), isNotNull,
          reason: 'sleep.history#2 — because the depth was written down');
    });

    test('two syncs at once are one sync', () async {
      // A cold start arms one and a return to the foreground arms another.
      // Overlapping, they read the same window twice — and on the first run of
      // a habit's life that window is the whole history, because neither has
      // recorded how deep it got before the other begins.
      addSleepHabit(name: 'Sleep');

      await Future.wait<void>(<Future<void>>[
        scope.syncSleepHabits(),
        scope.syncSleepHabits(),
        scope.syncSleepHabits(),
      ]);

      expect(source.reads, 1, reason: 'sleep.history#6');
    });

    test('but one after another still reads again', () async {
      // Joining is for overlap, not for caching: a sync that has finished
      // tells the next one nothing.
      addSleepHabit(name: 'Sleep');
      await scope.syncSleepHabits();
      await scope.syncSleepHabits();

      expect(source.reads, 2, reason: 'sleep.history#6');
    });

    test('a second sync reads again rather than trusting a cache', () async {
      addSleepHabit(name: 'Sleep');
      await scope.syncSleepHabits();
      await scope.syncSleepHabits();
      expect(source.reads, 2, reason: 'sleep.sync#1');
    });
  });
}

/// `isA<A>().or(isA<B>())` reads better than either alone.
extension _EitherMatcher on TypeMatcher<Object> {
  Matcher or(Matcher other) => anyOf(this, other);
}
