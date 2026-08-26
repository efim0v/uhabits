import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/extension_migrations.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';

import '../helpers/test_database.dart';

void main() {
  group('the two ranges are kept apart', () {
    test('extension versions start at 100 and never collide with Kotlin', () {
      expect(firstExtensionVersion, 100, reason: 'sleep.persistence#4');
      expect(databaseVersion, lessThan(firstExtensionVersion),
          reason: 'sleep.persistence#4');
      for (final int version in extensionMigrationSql.keys) {
        expect(version, greaterThanOrEqualTo(firstExtensionVersion),
            reason: 'sleep.persistence#4');
        expect(migrationSql.containsKey(version), isFalse,
            reason: 'sleep.persistence#4');
      }
    });

    test('no version has a script in both maps', () {
      final Set<int> both = migrationSql.keys.toSet()
        ..retainAll(extensionMigrationSql.keys);
      expect(both, isEmpty, reason: 'sleep.persistence#4');
    });

    test('the gap between them is genuinely empty', () {
      for (var v = databaseVersion + 1; v < firstExtensionVersion; v++) {
        expect(migrationSqlFor(v), isNull, reason: 'sleep.persistence#4');
        expect(isKotlinMigration(v), isFalse, reason: 'sleep.persistence#4');
      }
    });

    test('the lookup routes each version to the right map', () {
      expect(migrationSqlFor(databaseVersion), migrationSql[databaseVersion],
          reason: 'sleep.persistence#4');
      expect(migrationSqlFor(appDatabaseVersion),
          extensionMigrationSql[appDatabaseVersion],
          reason: 'sleep.persistence#4');
    });
  });

  group('the version this build ships', () {
    test('is distinct from the last version Kotlin defined', () {
      expect(appDatabaseVersion, isNot(databaseVersion),
          reason: 'sleep.persistence#7');
      expect(appDatabaseVersion, greaterThan(databaseVersion),
          reason: 'sleep.persistence#7');
    });

    test('accepts every version this build can migrate from', () {
      for (var v = 8; v <= databaseVersion; v++) {
        expect(isKnownDatabaseVersion(v), isTrue,
            reason: 'sleep.persistence#7');
      }
      expect(isKnownDatabaseVersion(appDatabaseVersion), isTrue,
          reason: 'sleep.persistence#7');
    });

    test('refuses the empty gap and anything past this build', () {
      // A file in the gap came from a build whose schema is unknown; stamping
      // it forward would be a guess dressed up as an upgrade.
      for (var v = databaseVersion + 1; v < firstExtensionVersion; v++) {
        expect(isKnownDatabaseVersion(v), isFalse,
            reason: 'sleep.persistence#6');
      }
      expect(isKnownDatabaseVersion(appDatabaseVersion + 1), isFalse,
          reason: 'sleep.persistence#7');
      expect(isKnownDatabaseVersion(appDatabaseVersion + 40), isFalse,
          reason: 'sleep.persistence#7');
    });
  });

  group('migration 100', () {
    test('creates both tables and the uniqueness that guards them', () {
      final Database db = openAppSchemaDatabase();
      addTearDown(db.close);
      expect(db.getVersion(), appDatabaseVersion,
          reason: 'sleep.persistence#1');
      for (final String table in <String>['SleepSessions', 'SleepGoals']) {
        expect(
          db.queryInt("select count(*) from sqlite_master "
              "where type = 'table' and name = '$table'"),
          1,
          reason: 'sleep.persistence#1',
        );
      }
      expect(
        db.queryInt("select count(*) from sqlite_master "
            "where type = 'index' and name = 'idx_sleep_sessions_habit_day'"),
        1,
        reason: 'sleep.persistence#5',
      );
    });

    test('carries a database at the Kotlin schema forward without loss', () {
      final Database db = openMigratedDatabase();
      addTearDown(db.close);
      db.run("insert into Habits (name, description, freq_num, freq_den, "
          "color, position, archived, highlight, type, target_value, "
          "target_type, unit, question) "
          "values ('Run', '', 1, 1, 0, 0, 0, 0, 0, 0, 0, '', '')");
      expect(db.getVersion(), databaseVersion,
          reason: 'sleep.persistence#2');

      db.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');

      expect(db.getVersion(), appDatabaseVersion,
          reason: 'sleep.persistence#2');
      expect(db.queryInt('select count(*) from Habits'), 1,
          reason: 'sleep.persistence#2');
      expect(db.queryInt('select count(*) from SleepSessions'), 0,
          reason: 'sleep.persistence#2');
    });

    test('running it again changes nothing', () {
      final Database db = openAppSchemaDatabase();
      addTearDown(db.close);
      db.run("insert into Habits (name, description, freq_num, freq_den, "
          "color, position, archived, highlight, type, target_value, "
          "target_type, unit, question) "
          "values ('Run', '', 1, 1, 0, 0, 0, 0, 0, 0, 0, '', '')");

      // At or past the target, migrateTo returns without touching anything.
      db.migrateTo(appDatabaseVersion, (int v) {
        fail('sleep.persistence#3: nothing should be loaded on a second run');
      });

      expect(db.getVersion(), appDatabaseVersion,
          reason: 'sleep.persistence#3');
      expect(db.queryInt('select count(*) from Habits'), 1,
          reason: 'sleep.persistence#3');
    });

    test('a fresh database reaches the same schema as an upgraded one', () {
      // Two roads to the current schema; they have to arrive at the same place,
      // or a defect hides on whichever road the tests do not take.
      final Database fresh = openAppSchemaDatabase();
      final Database upgraded = openMigratedDatabase();
      addTearDown(fresh.close);
      addTearDown(upgraded.close);
      upgraded.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');

      List<String> schemaOf(Database db) {
        final rows = <String>[];
        db.query(
          "select name, sql from sqlite_master "
          "where sql is not null order by name",
          const <String>[],
          (PreparedStatement stmt) => rows.add(stmt.getText(1)),
        );
        return rows;
      }

      expect(schemaOf(fresh), schemaOf(upgraded),
          reason: 'sleep.persistence#3');
    });
  });

  group('migration 102', () {
    test('migration 102 creates the definitions table with a cascade', () {
      final Database db = openAppSchemaDatabase();
      addTearDown(db.close);

      expect(db.getVersion(), 102, reason: 'computed.schema#1');
      expect(
        db.queryInt("select count(*) from sqlite_master "
            "where type = 'table' and name = 'HabitDefinitions'"),
        1,
        reason: 'computed.schema#1',
      );

      // The cascade, exercised rather than read off the DDL.
      db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
      db.run("insert into HabitDefinitions (habit, kind, payload) "
          "values (1,'sleep','{}')");
      db.run('delete from Habits where id = 1');

      expect(db.queryInt('select count(*) from HabitDefinitions'), 0,
          reason: 'computed.schema#2 — a habit takes its definition with it');
    });

    test('a habit that already had a sleep goal is marked', () {
      final Database db = openAppSchemaDatabaseAt(101);
      addTearDown(db.close);
      db.run("insert into Habits (id, name, uuid) values (1, 'Sleep', 'u1')");
      db.run('insert into SleepGoals (habit, bed_minutes, wake_minutes, '
          'min_sleep_minutes, weight_sleep, weight_bed, weight_wake, '
          'half_credit_time_minutes, half_credit_sleep_minutes, home_utc_offset, '
          'adaptation_minutes_per_day, merge_gap_minutes, prompt_after_wake_minutes) '
          'values (1,1380,420,450,0.4,0.3,0.3,90,60,0,60,60,60)');

      db.migrateTo(102, (int v) => migrationSqlFor(v) ?? '');

      expect(
          db.queryInt("select count(*) from HabitDefinitions "
              "where habit = 1 and kind = 'sleep'"),
          1,
          reason: 'computed.schema#3 — an existing sleep habit is not left '
              'unmarked');
    });
  });
}
