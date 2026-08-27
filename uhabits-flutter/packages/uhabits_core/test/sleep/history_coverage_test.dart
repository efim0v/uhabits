/// How far back the history is read, and how often.
///
/// The fortnight the sync re-reads is for healing — a watch uploads late, a
/// record is edited after the fact. It was also, by accident, the whole of the
/// history the app ever asked for: a person with two years of nights in their
/// health store saw a fortnight and no reason why.
///
/// The depth is decided from what has been recorded as covered, not from an
/// event. It does not matter whether the habit was made a minute ago or a year
/// ago, nor whether the app was opened in between.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/day_writer.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/extension_migrations.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/sleep/sleep_data_source.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_segment.dart';
import 'package:uhabits_core/src/sleep/sleep_session_repository.dart';
import 'package:uhabits_core/src/sleep/sleep_sync.dart';
import 'package:uhabits_core/src/sleep/stored_value.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Records the windows it was asked about and answers with nothing.
class WindowRecorder implements SleepDataSource {
  final List<(int, int)> windows = <(int, int)>[];

  @override
  bool get hasHealthStore => true;

  @override
  Future<bool> isAuthorized() async => true;

  @override
  Future<bool> requestAuthorization() async => true;

  @override
  Future<List<SleepSegment>> readSegments(int from, int to) async {
    windows.add((from, to));
    return const <SleepSegment>[];
  }

  @override
  Future<void> writeSession(int start, int end) async {}

  @override
  Future<void> enableBackgroundDelivery(
      Future<void> Function() onChanged) async {}
}

void main() {
  const int today = 9000;

  late Database database;
  late SleepSessionRepository repository;
  late WindowRecorder source;
  late SleepSync sync;
  late Habit habit;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    DateUtils.setFixedLocalTime((today + 10957) * 86400000 + 10 * 3600000);
    setToday(LocalDate(today));

    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);

    final SQLModelFactory factory = SQLModelFactory(database);
    habit = factory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    factory.buildHabitList().add(habit);

    repository = SleepSessionRepository(database, () => 1770000000000);
    repository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    source = WindowRecorder();
    sync = SleepSync(
      repository: repository,
      source: source,
      // Writes, tells nobody: there is no application here to tell.
      writer: const DayWriter(),
    );
  });

  tearDown(() {
    database.close();
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  /// How many days the nth window spanned.
  int spanOf(int index) =>
      (source.windows[index].$2 - source.windows[index].$1) ~/
      DateUtils.dayLength;

  test('a habit never read before reaches back to the horizon', () async {
    expect(repository.coveredFromDay(habit.id!), isNull,
        reason: 'sleep.history#1 — nothing has been asked yet');

    await sync.syncRecent(habit);

    expect(spanOf(0), historyHorizonDays + 1, reason: 'sleep.history#1');
    expect(historyHorizonDays, greaterThan(recentWindowDays),
        reason: 'sleep.history#1 — the check means nothing otherwise');
  });

  test('the depth reached is written down', () async {
    await sync.syncRecent(habit);

    expect(repository.coveredFromDay(habit.id!),
        today - historyHorizonDays + 1, reason: 'sleep.history#2');
  });

  test('the second sync asks only for the fortnight', () async {
    // The point of the whole exercise: an app already carrying its history
    // must not fetch it again on every return to the foreground.
    await sync.syncRecent(habit);
    await sync.syncRecent(habit);

    expect(spanOf(1), recentWindowDays + 1, reason: 'sleep.history#3');
  });

  test('and every sync after it', () async {
    await sync.syncRecent(habit);
    for (int i = 0; i < 5; i++) {
      await sync.syncRecent(habit);
    }
    for (int i = 1; i < source.windows.length; i++) {
      expect(spanOf(i), recentWindowDays + 1, reason: 'sleep.history#3');
    }
  });

  test('a habit read only shallowly before is deepened once', () async {
    // Exactly the state a phone is in after an app that only ever knew the
    // fortnight: some coverage, but not enough.
    repository.widenCoverage(habit.id!, today - recentWindowDays + 1);

    await sync.syncRecent(habit);
    expect(spanOf(0), historyHorizonDays + 1,
        reason: 'sleep.history#4 — the gap is what gets asked for');

    await sync.syncRecent(habit);
    expect(spanOf(1), recentWindowDays + 1,
        reason: 'sleep.history#4 — and then never again');
  });

  test('coverage only ever deepens', () async {
    repository.widenCoverage(habit.id!, 100);
    repository.widenCoverage(habit.id!, 500);
    expect(repository.coveredFromDay(habit.id!), 100,
        reason: 'sleep.history#2 — a shallower read cannot un-cover what a '
            'deeper one already reached');
  });

  test('a read thrown away before it is written does not count', () async {
    // The halves are apart so the caller can check, between them, that the
    // database is still there. A read that is dropped at that seam must not
    // leave the days it would have brought marked as covered.
    await sync.readRecent(habit);

    expect(repository.coveredFromDay(habit.id!), isNull,
        reason: 'sleep.history#5');
  });
}
