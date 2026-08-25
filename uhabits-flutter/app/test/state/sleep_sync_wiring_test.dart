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
    database.close();
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  /// A habit with a sleep goal attached, which is what makes it a sleep habit.
  Habit addSleepHabit({required String name}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository
        .saveGoal(habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    return habit;
  }

  Habit addOrdinaryHabit({required String name}) {
    final Habit habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    return habit;
  }

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
    test('the window is a fortnight of days', () async {
      addSleepHabit(name: 'Sleep');
      await scope.syncSleepHabits();
      expect(source.windows.single.last - source.windows.single.first,
          (recentWindowDays + 1) * DateUtils.dayLength,
          reason: 'sleep.sync#1');
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
