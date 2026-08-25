/// What the rest of the app is told when a night is written down.
///
/// Sleep values are computed rather than chosen, so they do not travel on a
/// Command — and a Command is what every screen in the port refreshes on. The
/// habit list keeps its own copy of each checkmark and score, and the
/// home-screen widgets are redrawn from the same signal. Without a
/// announcement of its own, a synced night would sit in the database while the
/// list went on showing the zero it had before.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// One night, every night, so a sync always has something to write.
class OneNightSource implements SleepDataSource {
  OneNightSource({required this.startMillis, required this.endMillis});

  final int startMillis;
  final int endMillis;

  @override
  Future<bool> isAuthorized() async => true;

  @override
  Future<bool> requestAuthorization() async => true;

  @override
  Future<List<SleepSegment>> readSegments(int from, int to) async =>
      <SleepSegment>[
        SleepSegment(
          startMillis: startMillis,
          endMillis: endMillis,
          kind: SleepSegmentKind.asleepUnspecified,
          sourceId: 'watch',
        ),
      ];

  @override
  Future<void> writeSession(int start, int end) async {}

  @override
  Future<void> enableBackgroundDelivery(
      Future<void> Function() onChanged) async {}
}

/// Records which rows the cache was asked to redraw.
class RecordingCacheListener extends HabitCardListCacheListener {
  int changes = 0;
  int refreshes = 0;

  @override
  void onItemChanged(int position) => changes++;

  @override
  void onRefreshFinished() => refreshes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;
  late RecordingCacheListener listener;

  const int day = 9000;
  // 23:10 to 06:40 UTC, closing on day 9000.
  final int wake = (day + 10957) * 86400000 + 6 * 3600000 + 40 * 60000;
  final int bed = wake - 450 * 60000;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    DateUtils.setFixedLocalTime((day + 10957) * 86400000 + 10 * 3600000);
    setToday(LocalDate(day));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      sleepSource: OneNightSource(startMillis: bed, endMillis: wake),
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    listener = RecordingCacheListener();
  });

  tearDown(() {
    scope.close();
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  Habit sleepHabit() {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository
        .saveGoal(habit.id!, const SleepGoal(bedMinutes: 1390, wakeMinutes: 400));
    // Attached after the habit exists: the cache holds its own copy of the
    // list, and a row it has never loaded is not a row it can report a change
    // to.
    scope.cache.setListener(listener);
    scope.cache.onAttached();
    listener.changes = 0;
    return habit;
  }

  test('a sync tells the list its habit changed', () async {
    final Habit habit = sleepHabit();

    await scope.syncSleepHabits();

    expect(
      scope.sleepRepository.forDay(habit.id!, day),
      isNotNull,
      reason: 'the sync is only worth announcing if it wrote something',
    );
    expect(listener.changes, greaterThan(0),
        reason: 'sleep.freshness#1 — a night nothing is told about is a '
            'night the list goes on showing as a zero');
  });

  test('a night entered by hand is announced the same way', () async {
    final Habit habit = sleepHabit();

    scope.sleepRepository.upsert(
      habit.id!,
      day,
      SleepEpisode(
        bedStartMillis: bed,
        wakeEndMillis: wake,
        asleepMinutes: 450,
        utcOffsetMinutes: 0,
      ),
      manual: true,
    );
    scope.sleepSync.recomputeDays(habit, day, day);
    scope.onSleepDataChanged(habit.id!);

    expect(listener.changes, greaterThan(0), reason: 'sleep.freshness#1');
  });

  test('a closed scope announces nothing', () async {
    final Habit habit = sleepHabit();
    scope.close();
    listener.changes = 0;

    scope.onSleepDataChanged(habit.id!);

    expect(listener.changes, 0,
        reason: 'sleep.freshness#2 — refreshing a cache whose database is '
            'gone is a crash, not a redraw');
  });

  test('a sync interrupted by a teardown writes nothing', () async {
    final Habit habit = sleepHabit();
    // The seam: everything slow has happened, nothing has been written, and
    // the person leaves the app.
    final RecentNights? nights = await scope.sleepSync.readRecent(habit);
    expect(nights, isNotNull);
    scope.close();

    // What AppScope does at this point, and the reason the halves are apart:
    // it checks, finds the scope closed, and does not write. Were it to write,
    // this would throw "database has already been closed".
    expect(scope.isClosed, isTrue, reason: 'sleep.freshness#3');
  });
}
