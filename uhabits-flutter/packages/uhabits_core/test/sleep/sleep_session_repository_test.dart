import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_session_repository.dart';

import '../helpers/test_database.dart';

const SleepEpisode fromHealth = SleepEpisode(
  bedStartMillis: 1756080000000,
  wakeEndMillis: 1756108800000,
  asleepMinutes: 400,
  utcOffsetMinutes: 180,
  sourceId: 'com.apple.health.watch',
);

const SleepEpisode byHand = SleepEpisode(
  bedStartMillis: 1756083600000,
  wakeEndMillis: 1756112400000,
  asleepMinutes: 450,
  utcOffsetMinutes: 180,
);

void main() {
  late Database db;
  late SleepSessionRepository repo;
  const int now = 1000;

  setUp(() {
    db = openAppSchemaDatabase();
    db.run("insert into Habits (id, name, description, freq_num, freq_den, "
        "color, position, archived, highlight, type, target_value, "
        "target_type, unit, question) "
        "values (1, 'Sleep', '', 1, 1, 0, 0, 0, 0, 1, 100, 0, '%', '')");
    db.run("insert into Habits (id, name, description, freq_num, freq_den, "
        "color, position, archived, highlight, type, target_value, "
        "target_type, unit, question) "
        "values (2, 'Other', '', 1, 1, 0, 1, 0, 0, 0, 0, 0, '', '')");
    repo = SleepSessionRepository(db, () => now);
  });

  tearDown(() => db.close());

  group('the schema', () {
    test('migration 100 creates both tables', () {
      expect(db.getVersion(), 100, reason: 'sleep.persistence#1');
      for (final table in <String>['SleepSessions', 'SleepGoals']) {
        expect(
          db.queryInt("select count(*) from sqlite_master "
              "where type = 'table' and name = '$table'"),
          1,
          reason: 'sleep.persistence#1',
        );
      }
    });

    test('existing habits survive the upgrade', () {
      expect(db.queryInt('select count(*) from Habits'), 2,
          reason: 'sleep.persistence#2');
    });
  });

  group('storing a night', () {
    test('round trips', () {
      repo.upsert(1, 9000, fromHealth, manual: false);
      final loaded = repo.forDay(1, 9000)!;
      expect(loaded.bedStartMillis, fromHealth.bedStartMillis,
          reason: 'sleep.persistence#5');
      expect(loaded.wakeEndMillis, fromHealth.wakeEndMillis,
          reason: 'sleep.persistence#5');
      expect(loaded.asleepMinutes, 400, reason: 'sleep.persistence#5');
      expect(loaded.utcOffsetMinutes, 180, reason: 'sleep.persistence#5');
      expect(loaded.sourceId, 'com.apple.health.watch',
          reason: 'sleep.persistence#5');
      expect(loaded.derivedFromAsleep, isFalse,
          reason: 'sleep.persistence#5');
    });

    test('millisecond instants survive the round trip intact', () {
      // Comfortably past the 32 bit range. The driver in use would survive
      // either binding — Dart integers are already 64 bit — but the interface
      // draws the distinction, and this pins the contract rather than the
      // driver that happens to satisfy it today.
      const far = SleepEpisode(
        bedStartMillis: 4102444800000,
        wakeEndMillis: 4102473600000,
        asleepMinutes: 400,
        utcOffsetMinutes: 0,
      );
      repo.upsert(1, 9000, far, manual: false);
      expect(repo.forDay(1, 9000)!.bedStartMillis, 4102444800000,
          reason: 'sleep.persistence#5');
    });

    test('one night per habit and day', () {
      repo.upsert(1, 9000, fromHealth, manual: false);
      repo.upsert(1, 9000, fromHealth.copyWith(asleepMinutes: 410),
          manual: false);
      expect(db.queryInt('select count(*) from SleepSessions'), 1,
          reason: 'sleep.persistence#5');
      expect(repo.forDay(1, 9000)!.asleepMinutes, 410,
          reason: 'sleep.persistence#5');
    });

    test('different days and habits do not collide', () {
      repo.upsert(1, 9000, fromHealth, manual: false);
      repo.upsert(1, 9001, fromHealth.copyWith(asleepMinutes: 410),
          manual: false);
      repo.upsert(2, 9000, fromHealth.copyWith(asleepMinutes: 420),
          manual: false);
      expect(repo.forDay(1, 9000)!.asleepMinutes, 400,
          reason: 'sleep.persistence#5');
      expect(repo.forDay(1, 9001)!.asleepMinutes, 410,
          reason: 'sleep.persistence#5');
      expect(repo.forDay(2, 9000)!.asleepMinutes, 420,
          reason: 'sleep.persistence#5');
    });

    test('a day with nothing stored is absent, not empty', () {
      expect(repo.forDay(1, 9000), isNull, reason: 'sleep.persistence#5');
    });
  });

  group('a manual night', () {
    test('is not overwritten by a later health sync', () {
      repo.upsert(1, 9000, byHand, manual: true);
      repo.upsert(1, 9000, fromHealth, manual: false);
      expect(repo.forDay(1, 9000)!.asleepMinutes, 450,
          reason: 'sleep.merge#9');
      expect(repo.isManual(1, 9000), isTrue, reason: 'sleep.merge#9');
    });

    test('does overwrite a health night', () {
      repo.upsert(1, 9000, fromHealth, manual: false);
      repo.upsert(1, 9000, byHand, manual: true);
      expect(repo.forDay(1, 9000)!.asleepMinutes, 450,
          reason: 'sleep.merge#9');
      expect(repo.isManual(1, 9000), isTrue, reason: 'sleep.merge#9');
    });

    test('can itself be replaced by another manual entry', () {
      repo.upsert(1, 9000, byHand, manual: true);
      repo.upsert(1, 9000, byHand.copyWith(asleepMinutes: 300), manual: true);
      expect(repo.forDay(1, 9000)!.asleepMinutes, 300,
          reason: 'sleep.merge#9');
    });
  });

  group('reading a range', () {
    setUp(() {
      repo.upsert(1, 9000, fromHealth, manual: false);
      repo.upsert(1, 9002, fromHealth.copyWith(utcOffsetMinutes: -240),
          manual: false);
      repo.upsert(1, 9005, fromHealth, manual: false);
    });

    test('returns the nights inside it, keyed by day', () {
      final range = repo.range(1, 9000, 9002);
      expect(range.keys.toList()..sort(), <int>[9000, 9002],
          reason: 'sleep.persistence#5');
    });

    test('excludes days outside it', () {
      expect(repo.range(1, 9001, 9004).keys, <int>[9002],
          reason: 'sleep.persistence#5');
    });

    test('observed offsets come back only for days that have a night', () {
      final offsets = repo.observedOffsets(1, 9000, 9005);
      expect(offsets[9000], 180, reason: 'sleep.timezone#5');
      expect(offsets[9002], -240, reason: 'sleep.timezone#5');
      expect(offsets.containsKey(9001), isFalse, reason: 'sleep.timezone#5');
    });

    test('another habit sees none of it', () {
      expect(repo.range(2, 9000, 9005), isEmpty,
          reason: 'sleep.persistence#5');
    });

    test('the first and last recorded days are reported', () {
      expect(repo.firstDay(1), 9000, reason: 'sleep.sync#3');
      expect(repo.lastDay(1), 9005, reason: 'sleep.sync#3');
      expect(repo.firstDay(2), isNull, reason: 'sleep.sync#3');
    });
  });

  group('goals', () {
    const goal = SleepGoal(
      bedMinutes: 1380,
      wakeMinutes: 420,
      homeUtcOffsetMinutes: 180,
      weightSleep: 0.5,
      weightBed: 0.25,
      weightWake: 0.25,
    );

    test('round trip in full', () {
      repo.saveGoal(1, goal);
      final loaded = repo.goalFor(1)!;
      expect(loaded, goal, reason: 'sleep.persistence#1');
    });

    test('saving twice replaces rather than duplicating', () {
      repo.saveGoal(1, goal);
      repo.saveGoal(1, goal.copyWith(bedMinutes: 1320));
      expect(db.queryInt('select count(*) from SleepGoals'), 1,
          reason: 'sleep.persistence#1');
      expect(repo.goalFor(1)!.bedMinutes, 1320,
          reason: 'sleep.persistence#1');
    });

    test('a habit without a goal is not a sleep habit', () {
      expect(repo.goalFor(2), isNull, reason: 'sleep.habit-type#4');
      expect(repo.isSleepHabit(2), isFalse, reason: 'sleep.habit-type#4');
      repo.saveGoal(2, goal);
      expect(repo.isSleepHabit(2), isTrue, reason: 'sleep.habit-type#4');
    });

    test('every sleep habit can be listed at once', () {
      repo.saveGoal(1, goal);
      expect(repo.sleepHabitIds(), <int>[1], reason: 'sleep.habit-type#4');
      repo.saveGoal(2, goal);
      expect(repo.sleepHabitIds(), <int>[1, 2], reason: 'sleep.habit-type#4');
    });
  });

  group('deleting a habit', () {
    test('takes its goal and its nights with it', () {
      repo.saveGoal(1, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
      repo.upsert(1, 9000, fromHealth, manual: false);
      repo.upsert(1, 9001, fromHealth, manual: false);
      repo.saveGoal(2, const SleepGoal(bedMinutes: 60, wakeMinutes: 480));
      repo.upsert(2, 9000, fromHealth, manual: false);

      db.run('delete from Habits where id = 1');

      expect(repo.goalFor(1), isNull, reason: 'sleep.habit-type#5');
      expect(repo.range(1, 8000, 10000), isEmpty,
          reason: 'sleep.habit-type#5');
      // And nothing else was touched.
      expect(repo.goalFor(2), isNotNull, reason: 'sleep.habit-type#5');
      expect(repo.range(2, 8000, 10000).length, 1,
          reason: 'sleep.habit-type#5');
    });

    test('a connection that ran no migrations still enforces the cascade', () {
      // Migrating through 22 replays that script's `pragma foreign_keys=ON`
      // and leaves the setting on for the connection that did the upgrade —
      // which is every connection in this test file, and no connection in
      // production. There, the file is already at the current schema and no
      // migration runs, so the setting exists only because the opener applies
      // it. Simulated here by clearing it first.
      db.run('pragma foreign_keys=OFF');
      applyConnectionSettings(db);
      expect(db.queryInt('pragma foreign_keys'), 1,
          reason: 'sleep.habit-type#5');

      repo.saveGoal(1, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
      repo.upsert(1, 9000, fromHealth, manual: false);
      db.run('delete from Habits where id = 1');
      expect(db.queryInt('select count(*) from SleepSessions'), 0,
          reason: 'sleep.habit-type#5');
      expect(db.queryInt('select count(*) from SleepGoals'), 0,
          reason: 'sleep.habit-type#5');
    });

    test('the cascade is enforced by the database, not by a caller', () {
      // Nothing in this test calls the repository to clean up: the rule lives
      // in the schema, where no future code path can forget it.
      repo.saveGoal(1, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
      repo.upsert(1, 9000, fromHealth, manual: false);
      expect(db.queryInt('select count(*) from SleepSessions'), 1,
          reason: 'sleep.habit-type#5');
      db.run('delete from Habits where id = 1');
      expect(db.queryInt('select count(*) from SleepSessions'), 0,
          reason: 'sleep.habit-type#5');
      expect(db.queryInt('select count(*) from SleepGoals'), 0,
          reason: 'sleep.habit-type#5');
    });
  });
}
