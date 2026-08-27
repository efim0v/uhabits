import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/io/habits_csv_exporter.dart';
import 'package:uhabits_core/src/io/zip.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_session_repository.dart';
import 'package:uhabits_core/src/sleep/stored_value.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

int startOfDay(int day) => (day + 10957) * 86400000;

SleepEpisode night(int day) => SleepEpisode(
      bedStartMillis: startOfDay(day - 1) + 1380 * 60000,
      wakeEndMillis: startOfDay(day) + 420 * 60000,
      asleepMinutes: 480,
      utcOffsetMinutes: 180,
      sourceId: 'com.apple.health.watch',
    );

/// The names of the entries in an exported archive.
Future<Set<String>> entriesOf(Uint8List bytes) async => <String>{
      for (final ZipEntry e in await ZipReader(bytes).entries()) e.name,
    };

Future<String> contentOf(Uint8List bytes, String name) async =>
    (await ZipReader(bytes).entries())
        .firstWhere((ZipEntry e) => e.name == name)
        .content;

void main() {
  late Database db;
  late SleepSessionRepository repo;
  late MemoryHabitList habits;
  late Habit sleep;
  late Habit run;

  setUp(() {
    setToday(LocalDate(9000));
    db = openAppSchemaDatabase();
    db.run("insert into Habits (id, name, description, freq_num, freq_den, "
        "color, position, archived, highlight, type, target_value, "
        "target_type, unit, question) "
        "values (1, 'Sleep', '', 1, 1, 0, 0, 0, 0, 1, 100, 0, '%', '')");
    db.run("insert into Habits (id, name, description, freq_num, freq_den, "
        "color, position, archived, highlight, type, target_value, "
        "target_type, unit, question) "
        "values (2, 'Run', '', 1, 1, 0, 1, 0, 0, 0, 0, 0, '', '')");
    repo = SleepSessionRepository(db, () => 1000);

    habits = MemoryHabitList();
    final MemoryModelFactory factory = MemoryModelFactory();
    sleep = factory.buildHabit()
      ..id = 1
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    run = factory.buildHabit()
      ..id = 2
      ..name = 'Run';
    habits.add(sleep);
    habits.add(run);
  });

  tearDown(() {
    db.close();
    resetToday();
  });

  group('an archive with no sleep habit', () {
    test('is exactly what it was before', () async {
      final Uint8List withRepository =
          await HabitsCSVExporter(habits, <Habit>[run], sleepRepository: repo)
              .writeArchive();
      final Uint8List without =
          await HabitsCSVExporter(habits, <Habit>[run]).writeArchive();

      expect(await entriesOf(withRepository), await entriesOf(without),
          reason: 'sleep.export#2');
      expect(await entriesOf(withRepository),
          isNot(contains('SleepSessions.csv')),
          reason: 'sleep.export#2');
    });

    test('a sleep habit with no nights adds nothing either', () async {
      repo.saveGoal(1, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sleep], sleepRepository: repo)
              .writeArchive();
      expect(await entriesOf(bytes), isNot(contains('SleepSessions.csv')),
          reason: 'sleep.export#2');
    });

    test('no repository at all is not an error', () async {
      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sleep]).writeArchive();
      expect(await entriesOf(bytes), isNot(contains('SleepSessions.csv')),
          reason: 'sleep.export#2');
    });
  });

  group('an archive with nights in it', () {
    setUp(() {
      repo.saveGoal(1, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
      repo.upsert(1, 8999, night(8999), manual: false);
      repo.upsert(1, 9000, night(9000), manual: false);
    });

    test('carries a file of its own', () async {
      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sleep], sleepRepository: repo)
              .writeArchive();
      expect(await entriesOf(bytes), contains('SleepSessions.csv'),
          reason: 'sleep.export#2');
    });

    test('names its columns', () async {
      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sleep], sleepRepository: repo)
              .writeArchive();
      final String csv = await contentOf(bytes, 'SleepSessions.csv');
      final String header = csv.split('\n').first;
      for (final String column in <String>[
        'Habit',
        'Day',
        'BedStart',
        'WakeEnd',
        'AsleepMinutes',
        'UtcOffset',
        'DerivedFromAsleep',
        'Source',
      ]) {
        expect(header, contains(column), reason: 'sleep.export#2');
      }
    });

    test('carries what cannot be reconstructed from the percentages',
        () async {
      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sleep], sleepRepository: repo)
              .writeArchive();
      final String csv = await contentOf(bytes, 'SleepSessions.csv');
      expect(csv, contains('480'), reason: 'sleep.export#2');
      expect(csv, contains('180'), reason: 'sleep.export#2');
      expect(csv, contains('com.apple.health.watch'),
          reason: 'sleep.export#2');
    });

    test('one row per night, in order', () async {
      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sleep], sleepRepository: repo)
              .writeArchive();
      final List<String> rows = (await contentOf(bytes, 'SleepSessions.csv'))
          .trim()
          .split('\n')
          .skip(1)
          .toList();
      expect(rows, hasLength(2), reason: 'sleep.export#2');
      // Колонка «день» несёт дату, а не отладочное представление класса
      // вокруг неё: тот же `toCSVString()`, что и во всех прочих файлах
      // архива.
      expect(rows.first, contains('2024-08-21'),
          reason: 'sleep.export#2');
      expect(rows.last, contains('2024-08-22'),
          reason: 'sleep.export#2');
    });

    test('a habit that was not selected is left out', () async {
      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[run], sleepRepository: repo)
              .writeArchive();
      expect(await entriesOf(bytes), isNot(contains('SleepSessions.csv')),
          reason: 'sleep.export#2');
    });
  });

  group('the percentages themselves', () {
    test('go out as an ordinary numerical habit', () async {
      // Nothing about the checkmark file says "sleep": the habit is numerical,
      // its unit is a percent sign, and its values are percentages. That is
      // what keeps the export readable by anything that reads the original's.
      expect(sleep.type, HabitType.numerical, reason: 'sleep.export#1');
      expect(sleep.unit, '%', reason: 'sleep.export#1');
      expect(sleep.targetValue, 100.0, reason: 'sleep.export#1');

      final String csv = habits.writeCSV();
      expect(csv, contains('NUMERICAL'), reason: 'sleep.export#1');
      expect(csv, isNot(contains('SLEEP')), reason: 'sleep.export#1');
    });
  });
}
