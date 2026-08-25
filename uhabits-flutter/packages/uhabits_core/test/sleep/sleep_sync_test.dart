import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/sleep/sleep_data_source.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_segment.dart';
import 'package:uhabits_core/src/sleep/sleep_session_repository.dart';
import 'package:uhabits_core/src/sleep/sleep_sync.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

/// Records what was asked for and answers with whatever it was given.
class RecordingSource implements SleepDataSource {
  RecordingSource([this.segments = const <SleepSegment>[]]);

  List<SleepSegment> segments;
  final List<List<int>> windows = <List<int>>[];
  final List<List<int>> written = <List<int>>[];
  bool authorized = true;

  @override
  Future<bool> isAuthorized() async => authorized;

  @override
  Future<bool> requestAuthorization() async => authorized;

  @override
  Future<List<SleepSegment>> readSegments(int fromMillis, int toMillis) async {
    windows.add(<int>[fromMillis, toMillis]);
    return authorized ? segments : const <SleepSegment>[];
  }

  @override
  Future<void> writeSession(int startMillis, int endMillis) async =>
      written.add(<int>[startMillis, endMillis]);

  @override
  Future<void> enableBackgroundDelivery(
      Future<void> Function() onChanged) async {}
}

const SleepGoal goal = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

/// Day 9000 since 2000 begins at this UTC instant.
int startOfDay(int day) => (day + 10957) * DateUtils.dayLength;

/// A night that ends on [day], asleep for [asleepMinutes] from [bedMinutes]
/// past the previous midnight.
List<SleepSegment> nightOn(
  int day, {
  int bedMinutes = 1380,
  int asleepMinutes = 480,
  String source = 'watch',
}) {
  final int start = startOfDay(day - 1) + bedMinutes * 60000;
  return <SleepSegment>[
    SleepSegment(
      startMillis: start,
      endMillis: start + asleepMinutes * 60000,
      kind: SleepSegmentKind.asleepCore,
      sourceId: source,
    ),
  ];
}

void main() {
  late Database db;
  late SleepSessionRepository repo;
  late RecordingSource source;
  late SleepSync sync;
  late Habit habit;
  const int today = 9000;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    // Noon on day 9000, so "today" is unambiguous.
    DateUtils.setFixedLocalTime(startOfDay(today) + 12 * 3600000);
    setToday(LocalDate(today));

    db = openAppSchemaDatabase();
    db.run("insert into Habits (id, name, description, freq_num, freq_den, "
        "color, position, archived, highlight, type, target_value, "
        "target_type, unit, question) "
        "values (1, 'Sleep', '', 1, 1, 0, 0, 0, 0, 1, 100, 0, '%', '')");
    repo = SleepSessionRepository(db, () => 1000);
    repo.saveGoal(1, goal);
    source = RecordingSource();
    sync = SleepSync(repository: repo, source: source);

    habit = MemoryModelFactory().buildHabit()..id = 1;
  });

  tearDown(() {
    db.close();
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  Map<int, int> writtenEntries() => <int, int>{
        for (final Entry e in habit.originalEntries.getKnown())
          e.date.daysSince2000: e.value,
      };

  group('the window', () {
    test('covers a fortnight, not yesterday', () async {
      await sync.syncRecent(habit);
      final List<int> window = source.windows.single;
      final int days =
          (window[1] - window[0]) ~/ DateUtils.dayLength;
      expect(days, recentWindowDays + 1, reason: 'sleep.sync#1');
      expect(recentWindowDays, 14, reason: 'sleep.sync#1');
    });

    test('starts a day early, because a night begins the evening before',
        () async {
      await sync.syncRecent(habit);
      expect(source.windows.single.first,
          startOfDay(today - recentWindowDays), reason: 'sleep.sync#1');
    });

    test('a habit without a goal is not read at all', () async {
      final Habit other = MemoryModelFactory().buildHabit()..id = 2;
      await sync.syncRecent(other);
      expect(source.windows, isEmpty, reason: 'sleep.habit-type#4');
    });
  });

  group('storing what was read', () {
    test('a night becomes a scored day', () async {
      source.segments = nightOn(today, bedMinutes: 1380, asleepMinutes: 480);
      await sync.syncRecent(habit);
      expect(repo.forDay(1, today), isNotNull, reason: 'sleep.sync#1');
      expect(writtenEntries()[today], 100000, reason: 'sleep.habit-type#3');
    });

    test('a poor night scores accordingly', () async {
      // In bed at 01:00, five hours of sleep.
      source.segments = nightOn(today, bedMinutes: 1500, asleepMinutes: 300);
      await sync.syncRecent(habit);
      final int value = writtenEntries()[today]!;
      expect(value, lessThan(30000), reason: 'sleep.scoring#5');
      expect(value, greaterThan(0), reason: 'sleep.scoring#5');
    });

    test('several nights in the window are all stored', () async {
      source.segments = <SleepSegment>[
        ...nightOn(today - 2),
        ...nightOn(today - 1),
        ...nightOn(today),
      ];
      await sync.syncRecent(habit);
      expect(repo.range(1, today - 2, today).length, 3,
          reason: 'sleep.sync#1');
      expect(writtenEntries().length, 3, reason: 'sleep.sync#1');
    });

    test('a nap loses to the night it shares a day with', () async {
      source.segments = <SleepSegment>[
        ...nightOn(today, asleepMinutes: 480),
        SleepSegment(
          startMillis: startOfDay(today) + 840 * 60000,
          endMillis: startOfDay(today) + 900 * 60000,
          kind: SleepSegmentKind.asleepCore,
          sourceId: 'watch',
        ),
      ];
      await sync.syncRecent(habit);
      expect(repo.forDay(1, today)!.asleepMinutes, 480,
          reason: 'sleep.merge#4');
    });
  });

  group('a day with no data', () {
    test('gets no entry at all, synthetic or otherwise', () async {
      await sync.syncRecent(habit);
      expect(writtenEntries(), isEmpty, reason: 'sleep.sync#4');
      expect(repo.range(1, today - 20, today), isEmpty,
          reason: 'sleep.sync#4');
    });

    test('heals when the data turns up later', () async {
      await sync.syncRecent(habit);
      expect(writtenEntries().containsKey(today - 3), isFalse,
          reason: 'sleep.sync#4');

      source.segments = nightOn(today - 3);
      await sync.syncRecent(habit);
      expect(writtenEntries()[today - 3], isNotNull, reason: 'sleep.sync#4');
    });

    test('a refused source is not an error', () async {
      source.authorized = false;
      source.segments = nightOn(today);
      await sync.syncRecent(habit);
      expect(writtenEntries(), isEmpty, reason: 'sleep.sync#5');
    });
  });

  group('idempotence', () {
    test('running twice writes the same values', () async {
      source.segments = <SleepSegment>[
        ...nightOn(today - 1, bedMinutes: 1400, asleepMinutes: 430),
        ...nightOn(today, bedMinutes: 1370, asleepMinutes: 470),
      ];
      await sync.syncRecent(habit);
      final Map<int, int> first = writtenEntries();
      await sync.syncRecent(habit);
      expect(writtenEntries(), equals(first), reason: 'sleep.sync#2');
      expect(db.queryInt('select count(*) from SleepSessions'), 2,
          reason: 'sleep.sync#2');
    });

    test('running five times changes nothing after the first', () async {
      source.segments = nightOn(today, bedMinutes: 1421, asleepMinutes: 408);
      await sync.syncRecent(habit);
      final Map<int, int> first = writtenEntries();
      for (var i = 0; i < 4; i++) {
        await sync.syncRecent(habit);
      }
      expect(writtenEntries(), equals(first), reason: 'sleep.sync#2');
    });
  });

  group('changing the goal', () {
    /// A night ending on [day]: in bed at 23:00, eight hours of sleep.
    SleepEpisode episodeOn(int day) => SleepEpisode(
          bedStartMillis: startOfDay(day - 1) + 1380 * 60000,
          wakeEndMillis: startOfDay(day) + 420 * 60000,
          asleepMinutes: 480,
          utcOffsetMinutes: 0,
        );

    test('rescores the whole history, not just the recent window', () {
      // A night well outside the fortnight a routine sync reads.
      const int old = today - 40;
      repo.upsert(1, old, episodeOn(old), manual: false);
      repo.upsert(1, today, episodeOn(today), manual: false);
      sync.recomputeAll(habit);
      final Map<int, int> before = writtenEntries();
      expect(before.containsKey(old), isTrue, reason: 'sleep.sync#3');

      repo.saveGoal(1, goal.copyWith(bedMinutes: 1200, wakeMinutes: 300));
      sync.recomputeAll(habit);
      final Map<int, int> after = writtenEntries();

      expect(after[old], isNot(before[old]), reason: 'sleep.sync#3');
      expect(after[today], isNot(before[today]), reason: 'sleep.sync#3');
    });

    test('a recent sync alone would leave the old days on the old scale',
        () async {
      const int old = today - 40;
      repo.upsert(1, old, episodeOn(old), manual: false);
      sync.recomputeAll(habit);
      final int before = writtenEntries()[old]!;

      repo.saveGoal(1, goal.copyWith(bedMinutes: 1200, wakeMinutes: 300));
      await sync.syncRecent(habit);
      expect(writtenEntries()[old], before,
          reason: 'sleep.sync#3 — the recent window does not reach that day');

      sync.recomputeAll(habit);
      expect(writtenEntries()[old], isNot(before), reason: 'sleep.sync#3');
    });
  });

  group('the day a night belongs to', () {
    test('is the day the person woke up', () async {
      // Asleep at 23:00 on day 8999, awake at 07:00 on day 9000.
      source.segments = nightOn(today, bedMinutes: 1380, asleepMinutes: 480);
      await sync.syncRecent(habit);
      expect(repo.forDay(1, today), isNotNull, reason: 'sleep.merge#7');
      expect(repo.forDay(1, today - 1), isNull, reason: 'sleep.merge#7');
    });

    test('the midnight-delay preference does not move it', () async {
      // getToday() carries that preference; a sleep habit must not.
      setToday(LocalDate(today - 1));
      source.segments = nightOn(today);
      await sync.syncRecent(habit);
      expect(sync.today().daysSince2000, today, reason: 'sleep.merge#8');
      expect(repo.forDay(1, today), isNotNull, reason: 'sleep.merge#8');
    });
  });
}
