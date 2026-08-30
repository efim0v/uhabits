/// `Lapses.csv` — журнал срывов в архиве экспорта.
///
/// Обвязка — та же, что у `sleep_export_test.dart` по соседству: архив
/// собирается в память, `entriesOf` даёт имена записей, `contentOf` — их
/// содержимое.
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/lapse_repository.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/io/habits_csv_exporter.dart';
import 'package:uhabits_core/src/io/zip.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

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
  late LapseRepository lapses;
  late MemoryHabitList habits;
  late Habit sober;
  late Habit run;

  setUp(() {
    setToday(LocalDate(9000));
    db = openAppSchemaDatabase();
    // Строки журнала висят на внешнем ключе, поэтому привычки должны быть в
    // базе, а не только в списке в памяти.
    db.run("insert into Habits (id, name, uuid) values (1, 'Sober', 'u1')");
    db.run("insert into Habits (id, name, uuid) values (2, 'Run', 'u2')");
    lapses = LapseRepository(db);

    habits = MemoryHabitList();
    final MemoryModelFactory factory = MemoryModelFactory();
    sober = factory.buildHabit()
      ..id = 1
      ..name = 'Sober'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 30
      ..unit = 'minutes';
    run = factory.buildHabit()
      ..id = 2
      ..name = 'Run';
    habits.add(sober);
    habits.add(run);
  });

  tearDown(() {
    db.close();
    resetToday();
  });

  group('an archive with nothing to add', () {
    test('is exactly what it was before', () async {
      final Uint8List withRepository = await HabitsCSVExporter(
        habits,
        <Habit>[run],
        lapseRepository: lapses,
      ).writeArchive();
      final Uint8List without =
          await HabitsCSVExporter(habits, <Habit>[run]).writeArchive();

      expect(await entriesOf(withRepository), await entriesOf(without),
          reason: 'computed.backup#5');
      expect(await entriesOf(withRepository), isNot(contains('Lapses.csv')),
          reason: 'computed.backup#5 — условный файл: пустая таблица в каждом '
              'архиве была бы налогом на всех ради немногих');
    });

    test('no repository at all is not an error', () async {
      lapses.save(1, 8990, amount: 45);

      final Uint8List bytes =
          await HabitsCSVExporter(habits, <Habit>[sober]).writeArchive();

      expect(await entriesOf(bytes), isNot(contains('Lapses.csv')),
          reason: 'computed.backup#5 — экспортёр без журнала обязан вести '
              'себя как upstream, байт в байт');
    });
  });

  group('an archive with lapses in it', () {
    setUp(() => lapses.save(1, 8990, amount: 45));

    test('carries a file of its own', () async {
      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[sober],
        lapseRepository: lapses,
      ).writeArchive();

      expect(await entriesOf(bytes), contains('Lapses.csv'),
          reason: 'computed.backup#5');
    });

    test('names its columns and writes one row per lapse', () async {
      lapses.save(1, 8990, amount: 45, atMillis: 1723454400000);

      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[sober],
        lapseRepository: lapses,
      ).writeArchive();

      final List<String> rows =
          (await contentOf(bytes, 'Lapses.csv')).trim().split('\n');

      expect(rows.first, 'Habit,Day,Moment,Amount',
          reason: 'computed.backup#5 — момент стоит рядом с днём, которому он '
              'принадлежит');
      expect(rows[1], 'Sober,2024-08-12,2024-08-12T09:20:00.000Z,45',
          reason: 'computed.backup#5');
    });

    test('the day is a date, spelled as every other date in the archive', () {
      // Ревью нашло: обе колонки `Day` печатались через `toString()`, то есть
      // `'LocalDate($year-$month-$day)'` — отладочное представление с именем
      // класса вокруг даты и без ведущих нулей. Колонка «день» обязана нести
      // дату: её читают глазами и разбирают инструментами, и `Scores.csv`,
      // `Checkmarks.csv` и все сводные файлы архива уже пишут
      // `toCSVString()`. Одинаковой ошибка была в двух местах, а не
      // договорённостью.
      expect(LocalDate(8990).toCSVString(), '2024-08-12',
          reason: 'computed.backup#5 — 8990-й день от 1 января 2000 года есть '
              '12 августа 2024 года, и в архиве это ISO-8601');
    });

    test('a habit that was not selected is left out', () async {
      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[run],
        lapseRepository: lapses,
      ).writeArchive();

      expect(await entriesOf(bytes), isNot(contains('Lapses.csv')),
          reason: 'computed.backup#5');
    });

    test('Habits.csv is still twelve columns', () async {
      final Uint8List bytes = await HabitsCSVExporter(
        habits,
        <Habit>[sober],
        lapseRepository: lapses,
      ).writeArchive();

      final String header =
          (await contentOf(bytes, 'Habits.csv')).split('\n').first;

      expect(header.split(',').length, 12,
          reason: 'computed.backup#5 — боковая таблица едет отдельным файлом; '
              'колонка, дописанная в Habits.csv, сломала бы всякий парсер '
              'снаружи');
    });
  });
}
