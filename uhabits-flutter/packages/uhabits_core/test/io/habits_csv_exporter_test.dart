import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/habits_csv_exporter.dart';
import 'package:uhabits_core/src/io/zip.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporterTest.kt
/// covering
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt
/// and uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/ExportCSVTask.kt.
///
/// The Kotlin test diffs the produced archive against the reference files in
/// uhabits-core/assets/test/csv_export/. Those files are inlined below as
/// [_expected], so this port asserts the very same bytes without needing the
/// asset loader.
///
/// The Kotlin `setUp` lives in BaseUnitTest; the parts this file needs (today =
/// 2015-01-25, a MemoryModelFactory, a habit list and HabitFixtures) are
/// inlined into the [setUp] below.
///
/// Every `expect` carries the parity-ledger rule id it exercises.
void main() {
  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    modelFactory = MemoryModelFactory();
    habitList = modelFactory.buildHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    // HabitsCSVExporterTest.setUp
    habitList.add(fixtures.createShortHabit());
    habitList.add(fixtures.createEmptyHabit());
  });

  tearDown(resetToday);

  /// Every habit of [list], in display order.
  List<Habit> allOf(HabitList list) => list.toList();

  Future<List<ZipEntry>> entriesOf(HabitsCSVExporter exporter) async {
    final bytes = await exporter.writeArchive();
    expect(bytes, isNotEmpty, reason: 'io.csv-archive-layout#1 writeArchive() '
        'returns the ZIP file as a ByteArray');
    return ZipReader(bytes).entries();
  }

  Future<Map<String, String>> exportAll() async {
    final exporter = HabitsCSVExporter(habitList, allOf(habitList));
    final entries = await entriesOf(exporter);
    return <String, String>{
      for (final e in entries) e.name: e.content,
    };
  }

  // The reference archive checked into uhabits-core/assets/test/csv_export/.
  const expectedHabits = 'Position,Name,Type,Question,Description,'
      'FrequencyNumerator,FrequencyDenominator,Color,Unit,Target Type,'
      'Target Value,Archived?\n'
      '001,Meditate,YES_NO,Did you meditate this morning?,,1,1,#FF8F00,,,,'
      'false\n'
      '002,Wake up early,YES_NO,Did you wake up before 6am?,,2,3,#00897B,,,,'
      'false\n';

  const expectedMeditateScores = 'Date,Score\n'
      '2015-01-25,0.0000\n';

  const expectedMeditateCheckmarks = 'Date,Value,Notes\n';

  const expectedWakeScores = 'Date,Score\n'
      '2015-01-25,0.2557\n'
      '2015-01-24,0.2226\n'
      '2015-01-23,0.1991\n'
      '2015-01-22,0.1746\n'
      '2015-01-21,0.1379\n'
      '2015-01-20,0.0995\n'
      '2015-01-19,0.0706\n'
      '2015-01-18,0.0515\n'
      '2015-01-17,0.0315\n'
      '2015-01-16,0.0107\n';

  const expectedWakeCheckmarks = 'Date,Value,Notes\n'
      '2015-01-25,YES_MANUAL,\n'
      '2015-01-24,NO,Sick\n'
      '2015-01-23,YES_AUTO,"Forgot to do it, really"\n'
      '2015-01-22,YES_MANUAL,\n'
      '2015-01-21,YES_MANUAL,\n'
      '2015-01-20,YES_MANUAL,\n'
      '2015-01-19,YES_AUTO,"""Vacation"""\n'
      '2015-01-18,YES_AUTO,\n'
      '2015-01-17,YES_MANUAL,\n'
      '2015-01-16,YES_MANUAL,\n';

  const expectedCombinedScores = 'Date,Meditate,Wake up early,\n'
      '2015-01-25,0.0000,0.2557,\n'
      '2015-01-24,0.0000,0.2226,\n'
      '2015-01-23,0.0000,0.1991,\n'
      '2015-01-22,0.0000,0.1746,\n'
      '2015-01-21,0.0000,0.1379,\n'
      '2015-01-20,0.0000,0.0995,\n'
      '2015-01-19,0.0000,0.0706,\n'
      '2015-01-18,0.0000,0.0515,\n'
      '2015-01-17,0.0000,0.0315,\n'
      '2015-01-16,0.0000,0.0107,\n';

  const expectedCombinedCheckmarks = 'Date,Meditate,Wake up early,\n'
      '2015-01-25,UNKNOWN,YES_MANUAL,\n'
      '2015-01-24,UNKNOWN,NO,\n'
      '2015-01-23,UNKNOWN,YES_AUTO,\n'
      '2015-01-22,UNKNOWN,YES_MANUAL,\n'
      '2015-01-21,UNKNOWN,YES_MANUAL,\n'
      '2015-01-20,UNKNOWN,YES_MANUAL,\n'
      '2015-01-19,UNKNOWN,YES_AUTO,\n'
      '2015-01-18,UNKNOWN,YES_AUTO,\n'
      '2015-01-17,UNKNOWN,YES_MANUAL,\n'
      '2015-01-16,UNKNOWN,YES_MANUAL,\n';

  group('io.csv-archive-layout', () {
    test('#1 #2 #4 #6 entry names, in order', () async {
      final exporter = HabitsCSVExporter(habitList, allOf(habitList));
      final entries = await entriesOf(exporter);
      final names = entries.map((e) => e.name).toList();
      expect(
        names,
        <String>[
          'Habits.csv',
          '001 Meditate/Scores.csv',
          '001 Meditate/Checkmarks.csv',
          '002 Wake up early/Scores.csv',
          '002 Wake up early/Checkmarks.csv',
          'Scores.csv',
          'Checkmarks.csv',
        ],
        reason: 'io.csv-archive-layout#2 writeArchive() adds Habits.csv, then '
            '<dir>Scores.csv and <dir>Checkmarks.csv per selected habit, then '
            'the combined Scores.csv and Checkmarks.csv',
      );
      expect(names.where((n) => n.contains('/')).toList(),
          <String>['001 Meditate/Scores.csv', '001 Meditate/Checkmarks.csv',
            '002 Wake up early/Scores.csv', '002 Wake up early/Checkmarks.csv'],
          reason: 'io.csv-archive-layout#4 per-habit files use forward-slash '
              'paths and no explicit directory entries are written');
      expect(names.where((n) => n.endsWith('/')), isEmpty,
          reason: 'io.csv-archive-layout#4 no explicit directory entries');
      expect(names.length, 7,
          reason: 'io.csv-archive-layout#6 two selected habits produce exactly '
              '7 entries');
    });

    test('#1 the two constructor arguments are allHabits and selectedHabits',
        () async {
      final meditate = habitList.getByPosition(0);
      final exporter = HabitsCSVExporter(habitList, <Habit>[meditate]);
      final entries = await entriesOf(exporter);
      expect(entries.map((e) => e.name).toList(),
          <String>['Habits.csv', '001 Meditate/Scores.csv',
            '001 Meditate/Checkmarks.csv', 'Scores.csv', 'Checkmarks.csv'],
          reason: 'io.csv-archive-layout#1 HabitsCSVExporter(allHabits, '
              'selectedHabits); only the selected habits get a folder');
    });

    test('#3 Habits.csv always holds every habit of allHabits', () async {
      final meditate = habitList.getByPosition(0);
      final exporter = HabitsCSVExporter(habitList, <Habit>[meditate]);
      final entries = await entriesOf(exporter);
      final habits = entries.firstWhere((e) => e.name == 'Habits.csv').content;
      expect(habits, expectedHabits,
          reason: 'io.csv-archive-layout#3 Habits.csv contains ALL habits from '
              'allHabits even when a single habit was selected');
    });

    test('#5 the combined files hold one column per selected habit', () async {
      final wake = habitList.getByPosition(1);
      final exporter = HabitsCSVExporter(habitList, <Habit>[wake]);
      final entries = await entriesOf(exporter);
      final scores = entries.firstWhere((e) => e.name == 'Scores.csv').content;
      final checks =
          entries.firstWhere((e) => e.name == 'Checkmarks.csv').content;
      expect(scores.split('\n').first, 'Date,Wake up early,',
          reason: 'io.csv-archive-layout#5 the top-level Scores.csv has one '
              'column per SELECTED habit, not per habit in allHabits');
      expect(checks.split('\n').first, 'Date,Wake up early,',
          reason: 'io.csv-archive-layout#5 the top-level Checkmarks.csv has one '
              'column per SELECTED habit, not per habit in allHabits');
    });

    test('#7 an empty selection still produces the three top-level files',
        () async {
      final exporter = HabitsCSVExporter(habitList, <Habit>[]);
      final entries = await entriesOf(exporter);
      expect(entries.map((e) => e.name).toList(),
          <String>['Habits.csv', 'Scores.csv', 'Checkmarks.csv'],
          reason: 'io.csv-archive-layout#7 an empty selectedHabits still yields '
              'Habits.csv, Scores.csv and Checkmarks.csv');
      expect(entries.firstWhere((e) => e.name == 'Scores.csv').content, 'Date,\n',
          reason: 'io.csv-archive-layout#7 the combined Scores.csv holds only '
              "the header line 'Date,' plus a newline");
      expect(entries.firstWhere((e) => e.name == 'Checkmarks.csv').content,
          'Date,\n',
          reason: 'io.csv-archive-layout#7 the combined Checkmarks.csv holds '
              "only the header line 'Date,' plus a newline");
    });
  });

  group('io.csv-habits-file', () {
    test('#1 #13 header and line termination', () async {
      final habits = (await exportAll())['Habits.csv']!;
      final lines = habits.split('\n');
      expect(lines.first,
          'Position,Name,Type,Question,Description,FrequencyNumerator,'
              'FrequencyDenominator,Color,Unit,Target Type,Target Value,'
              'Archived?',
          reason: 'io.csv-habits-file#1 the first line is the twelve column '
              'names');
      expect(habits.startsWith(
          'Position,Name,Type,Question,Description,FrequencyNumerator,'
              'FrequencyDenominator,Color,Unit,Target Type,Target Value,'
              'Archived?\n'),
          isTrue,
          reason: "io.csv-habits-file#1 the header line ends with '\\n'");
      expect(habits.endsWith('false\n'), isTrue,
          reason: "io.csv-habits-file#13 every line ends with '\\n'");
      expect(lines.length, 4,
          reason: 'io.csv-habits-file#13 header + 2 habit rows + the empty '
              'remainder after the final newline; no trailing blank data line');
      expect(lines.last, '',
          reason: 'io.csv-habits-file#13 nothing follows the final newline');
    });

    test('#2 rows follow the display order of the habit list', () {
      final list = MemoryHabitList();
      final zebra = fixtures.createEmptyHabit(name: 'Zebra');
      final apple = fixtures.createEmptyHabit(name: 'Apple');
      list.add(zebra);
      list.add(apple);
      var names = list
          .writeCSV()
          .split('\n')
          .sublist(1, 3)
          .map((l) => l.split(',')[1])
          .toList();
      expect(names, <String>['Apple', 'Zebra'],
          reason: 'io.csv-habits-file#2 with the default BY_POSITION primary '
              'order and BY_NAME_ASC secondary order, equal positions fall back '
              'to the name');
      zebra.position = 0;
      apple.position = 1;
      list.resort();
      names = list
          .writeCSV()
          .split('\n')
          .sublist(1, 3)
          .map((l) => l.split(',')[1])
          .toList();
      expect(names, <String>['Zebra', 'Apple'],
          reason: 'io.csv-habits-file#2 one row per habit, in the list current '
              'display order (primary order BY_POSITION)');
    });

    test('#3 Position is the 1-based index zero-padded to three digits', () {
      final list = MemoryHabitList();
      for (var i = 0; i < 1000; i++) {
        final habit = fixtures.createEmptyHabit(name: 'H$i', position: i);
        list.add(habit);
      }
      final lines = list.writeCSV().split('\n');
      expect(lines[1].split(',')[0], '001',
          reason: 'io.csv-habits-file#3 Position = %03d of indexOf(habit) + 1');
      expect(lines[2].split(',')[0], '002',
          reason: 'io.csv-habits-file#3 Position = %03d of indexOf(habit) + 1');
      expect(lines[10].split(',')[0], '010',
          reason: 'io.csv-habits-file#3 the tenth habit is 010');
      expect(lines[100].split(',')[0], '100',
          reason: 'io.csv-habits-file#3 the hundredth habit is 100');
      expect(lines[1000].split(',')[0], '1000',
          reason: 'io.csv-habits-file#3 %03d never truncates: the thousandth '
              'habit is 1000');
    });

    test('#4 Name is verbatim, CSV-quoted only when it must be', () {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'Meditate, daily'));
      list.add(fixtures.createEmptyHabit(name: 'Wake up early'));
      final rows = list.writeCSV().split('\n');
      expect(rows[1].startsWith('001,"Meditate, daily",YES_NO,'), isTrue,
          reason: 'io.csv-habits-file#4 a name containing a comma is CSV '
              'quoted');
      expect(rows[2].startsWith('002,Wake up early,YES_NO,'), isTrue,
          reason: 'io.csv-habits-file#4 a name with no special character is '
              'written verbatim');
    });

    test('#5 #9 #10 #11 Type, Unit, Target Type and Target Value', () {
      final list = MemoryHabitList();
      final yesNo = fixtures.createEmptyHabit(name: 'Meditate');
      final numerical = fixtures.createNumericalHabit();
      list.add(yesNo);
      list.add(numerical);
      final rows =
          list.writeCSV().split('\n').map((l) => l.split(',')).toList();
      // Row 1 is Meditate, row 2 is Run: BY_NAME_ASC breaks the position tie.
      expect(rows[1][2], 'YES_NO',
          reason: "io.csv-habits-file#5 Type is the enum NAME 'YES_NO'");
      expect(rows[2][2], 'NUMERICAL',
          reason: "io.csv-habits-file#5 Type is the enum NAME 'NUMERICAL'");
      expect(rows[1][8], '',
          reason: 'io.csv-habits-file#9 Unit is empty for a non-numerical '
              'habit');
      expect(rows[2][8], 'miles',
          reason: 'io.csv-habits-file#9 Unit is habit.unit for a numerical '
              'habit');
      expect(rows[1][9], '',
          reason: 'io.csv-habits-file#10 Target Type is empty for a '
              'non-numerical habit');
      expect(rows[2][9], 'AT_LEAST',
          reason: "io.csv-habits-file#10 Target Type is the enum NAME "
              "'AT_LEAST'");
      expect(rows[1][10], '',
          reason: 'io.csv-habits-file#11 Target Value is empty for a '
              'non-numerical habit');
      expect(rows[2][10], '2.0',
          reason: "io.csv-habits-file#11 Target Value is format('%.1f', "
              'habit.targetValue)');

      numerical.targetType = NumericalHabitType.atMost;
      numerical.targetValue = 12.75;
      final updated =
          list.writeCSV().split('\n')[2].split(',');
      expect(updated[9], 'AT_MOST',
          reason: "io.csv-habits-file#10 Target Type is the enum NAME "
              "'AT_MOST'");
      expect(updated[10], '12.8',
          reason: "io.csv-habits-file#11 format('%.1f', 12.75) rounds HALF_UP "
              "to '12.8'");
    });

    test('#6 Question and Description', () {
      final list = MemoryHabitList();
      final habit = fixtures.createEmptyHabit();
      habit.description = 'this is a test description';
      list.add(habit);
      final row = list.writeCSV().split('\n')[1].split(',');
      expect(row[3], 'Did you meditate this morning?',
          reason: 'io.csv-habits-file#6 column 4 is habit.question');
      expect(row[4], 'this is a test description',
          reason: 'io.csv-habits-file#6 column 5 is habit.description');
    });

    test('#7 frequency numerator and denominator are plain integers', () {
      final list = MemoryHabitList();
      final daily = fixtures.createEmptyHabit(name: 'Daily');
      final twoOfThree = fixtures.createEmptyHabit(name: 'Every other');
      twoOfThree.frequency = Frequency(2, 3);
      list.add(daily);
      list.add(twoOfThree);
      final rows =
          list.writeCSV().split('\n').map((l) => l.split(',')).toList();
      expect(<String>[rows[1][5], rows[1][6]], <String>['1', '1'],
          reason: 'io.csv-habits-file#7 columns 6 and 7 are the frequency '
              'numerator and denominator (1 and 1 for daily)');
      expect(<String>[rows[2][5], rows[2][6]], <String>['2', '3'],
          reason: 'io.csv-habits-file#7 columns 6 and 7 are the frequency '
              'numerator and denominator (2 and 3)');
    });

    test('#8 Color is the palette hex string', () {
      const palette = <String>[
        '#D32F2F', '#E64A19', '#F57C00', '#FF8F00', '#F9A825', //
        '#AFB42B', '#7CB342', '#388E3C', '#00897B', '#00ACC1',
        '#039BE5', '#1976D2', '#303F9F', '#5E35B1', '#8E24AA',
        '#D81B60', '#5D4037', '#303030', '#757575', '#aaaaaa',
      ];
      for (var i = 0; i < palette.length; i++) {
        final list = MemoryHabitList();
        list.add(fixtures.createEmptyHabit(color: PaletteColor(i)));
        expect(list.writeCSV().split('\n')[1].split(',')[7], palette[i],
            reason: 'io.csv-habits-file#8 Color for paletteIndex $i is '
                '${palette[i]}');
      }
    });

    test('#12 Archived? is the Kotlin Boolean.toString', () {
      final list = MemoryHabitList();
      final active = fixtures.createEmptyHabit(name: 'Active');
      final archived = fixtures.createEmptyHabit(name: 'Buried');
      archived.isArchived = true;
      list.add(active);
      list.add(archived);
      final rows =
          list.writeCSV().split('\n').map((l) => l.split(',')).toList();
      expect(rows[1][11], 'false',
          reason: "io.csv-habits-file#12 Archived? is 'false' for an active "
              'habit');
      expect(rows[2][11], 'true',
          reason: "io.csv-habits-file#12 Archived? is 'true' for an archived "
              'habit');
    });

    test('#14 the exact expected output of the upstream 3-habit list', () {
      final list = MemoryHabitList();
      final h1 = fixtures.createEmptyHabit();
      h1.description = 'this is a test description';
      h1.frequency = Frequency.daily;
      h1.color = const PaletteColor(3);
      final h2 = fixtures.createEmptyHabit();
      h2.name = 'Wake up early';
      h2.question = 'Did you wake up before 6am?';
      h2.description = '';
      h2.frequency = Frequency(2, 3);
      h2.color = const PaletteColor(5);
      final h3 = fixtures.createNumericalHabit();
      list.add(h1);
      list.add(h2);
      list.add(h3);
      expect(
        list.writeCSV(),
        'Position,Name,Type,Question,Description,FrequencyNumerator,'
            'FrequencyDenominator,Color,Unit,Target Type,Target Value,'
            'Archived?\n'
            '001,Meditate,YES_NO,Did you meditate this morning?,this is a test '
            'description,1,1,#FF8F00,,,,false\n'
            '002,Run,NUMERICAL,How many miles did you run today?,,1,1,#E64A19,'
            'miles,AT_LEAST,2.0,false\n'
            '003,Wake up early,YES_NO,Did you wake up before 6am?,,2,3,#AFB42B,'
            ',,,false\n',
        reason: 'io.csv-habits-file#14 exact expected output for the 3-habit '
            'list',
      );
    });

    test('the exported Habits.csv matches the reference fixture', () async {
      expect((await exportAll())['Habits.csv'], expectedHabits,
          reason: 'io.csv-habits-file#14 the archived Habits.csv matches '
              'uhabits-core/assets/test/csv_export/Habits.csv');
    });
  });

  group('io.csv-per-habit-scores', () {
    test('#1 #2 #5 #6 #7 the reference per-habit Scores.csv', () async {
      final files = await exportAll();
      expect(files.containsKey('002 Wake up early/Scores.csv'), isTrue,
          reason: "io.csv-per-habit-scores#1 the file is named "
              "'<NNN Habit Name>/Scores.csv'");
      final scores = files['002 Wake up early/Scores.csv']!;
      expect(scores.startsWith('Date,Score\n'), isTrue,
          reason: "io.csv-per-habit-scores#2 the header is exactly "
              "'Date,Score\\n'");
      expect(scores, expectedWakeScores,
          reason: 'io.csv-per-habit-scores#6 each row is '
              "'<yyyy-MM-dd>,<%.4f of the score>'");
      final rows = scores.split('\n').sublist(1)
        ..removeLast();
      expect(rows.map((r) => r.split(',')[0]).toList(), <String>[
        '2015-01-25', '2015-01-24', '2015-01-23', '2015-01-22', '2015-01-21', //
        '2015-01-20', '2015-01-19', '2015-01-18', '2015-01-17', '2015-01-16',
      ],
          reason: 'io.csv-per-habit-scores#5 getByInterval yields descending '
              'dates, one row per calendar day with no gaps');
      expect(scores.endsWith('\n'), isTrue,
          reason: "io.csv-per-habit-scores#7 every row ends with '\\n'");
      expect(scores.split('\n').last, '',
          reason: "io.csv-per-habit-scores#7 every row ends with '\\n'");
    });

    test('#3 the range starts at the oldest known computed entry', () async {
      final numerical = fixtures.createNumericalHabit();
      habitList.add(numerical);
      final files = await exportAll();
      final scores = files['002 Run/Scores.csv']!;
      final dates =
          scores.split('\n').sublist(1).where((l) => l.isNotEmpty).map(
              (l) => l.split(',')[0]).toList();
      // createNumericalHabit marks today-0 .. today-10; the oldest known
      // computed entry is 2015-01-15, so the file covers 11 days.
      expect(dates.first, '2015-01-25',
          reason: 'io.csv-per-habit-scores#3 the range ends at today = '
              'getToday()');
      expect(dates.last, '2015-01-15',
          reason: 'io.csv-per-habit-scores#3 the range starts at the LAST '
              '(oldest) element of computedEntries.getKnown()');
      expect(dates.length, 11,
          reason: 'io.csv-per-habit-scores#3 [oldest .. today] is inclusive at '
              'both ends');
      // The habit's computed entries have gaps (2015-01-23, 2015-01-21 and
      // 2015-01-19 are unknown); the scores file has none.
      expect(dates, <String>[
        '2015-01-25', '2015-01-24', '2015-01-23', '2015-01-22', '2015-01-21', //
        '2015-01-20', '2015-01-19', '2015-01-18', '2015-01-17', '2015-01-16',
        '2015-01-15',
      ],
          reason: 'io.csv-per-habit-scores#5 scores.getByInterval yields one '
              'row per calendar day with no gaps, in DESCENDING order, even '
              'where the entry list has gaps');
    });

    test('#4 an empty habit gets a single row for today', () async {
      final files = await exportAll();
      expect(files['001 Meditate/Scores.csv'], expectedMeditateScores,
          reason: 'io.csv-per-habit-scores#4 when computedEntries.getKnown() is '
              'empty, oldest defaults to today, so only today is written');
    });

    test('#6 the score is formatted with four decimals', () async {
      final files = await exportAll();
      expect(files['002 Wake up early/Scores.csv']!.split('\n')[1],
          '2015-01-25,0.2557',
          reason: "io.csv-per-habit-scores#6 score = format('%.4f', "
              'score.value)');
      expect(files['001 Meditate/Scores.csv']!.split('\n')[1],
          '2015-01-25,0.0000',
          reason: "io.csv-per-habit-scores#6 a zero score is written "
              "'0.0000'");
    });
  });

  group('io.csv-per-habit-checkmarks', () {
    test('#1 #2 #4 #6 #7 #8 #9 the reference per-habit Checkmarks.csv',
        () async {
      final files = await exportAll();
      expect(files.containsKey('002 Wake up early/Checkmarks.csv'), isTrue,
          reason: "io.csv-per-habit-checkmarks#1 the file is named "
              "'<NNN Habit Name>/Checkmarks.csv'");
      final checks = files['002 Wake up early/Checkmarks.csv']!;
      expect(checks.startsWith('Date,Value,Notes\n'), isTrue,
          reason: "io.csv-per-habit-checkmarks#2 the header is exactly "
              "'Date,Value,Notes\\n'");
      expect(checks, expectedWakeCheckmarks,
          reason: 'io.csv-per-habit-checkmarks#6 column 1 is '
              'entry.date.toCSVString()');
      final rows = checks.split('\n').sublist(1).where((l) => l.isNotEmpty);
      expect(rows.map((r) => r.split(',')[0]).toList(), <String>[
        '2015-01-25', '2015-01-24', '2015-01-23', '2015-01-22', '2015-01-21', //
        '2015-01-20', '2015-01-19', '2015-01-18', '2015-01-17', '2015-01-16',
      ],
          reason: 'io.csv-per-habit-checkmarks#4 getKnown() is newest date '
              'first, and rows follow that descending-date order');
      expect(checks.split('\n')[1], '2015-01-25,YES_MANUAL,',
          reason: 'io.csv-per-habit-checkmarks#7 column 2 is '
              "entry.formattedValue ('YES_MANUAL' for 2)");
      expect(checks.contains('2015-01-24,NO,Sick\n'), isTrue,
          reason: "io.csv-per-habit-checkmarks#7 'NO' for 0");
      expect(checks.contains('2015-01-23,YES_AUTO,'), isTrue,
          reason: "io.csv-per-habit-checkmarks#7 'YES_AUTO' for 1");
      expect(checks.split('\n')[1].endsWith(','), isTrue,
          reason: 'io.csv-per-habit-checkmarks#8 an empty note produces an '
              "empty trailing field, e.g. '2015-01-25,YES_MANUAL,'");
      expect(checks.contains('2015-01-23,YES_AUTO,"Forgot to do it, really"\n'),
          isTrue,
          reason: 'io.csv-per-habit-checkmarks#9 a note containing a comma is '
              'quoted');
      expect(checks.contains('2015-01-19,YES_AUTO,"""Vacation"""\n'), isTrue,
          reason: 'io.csv-per-habit-checkmarks#9 a note containing double '
              'quotes has them doubled');
    });

    test('#3 rows come from computedEntries, not originalEntries', () async {
      final wake = habitList.getByPosition(1);
      expect(wake.originalEntries.get(LocalDate.ymd(2015, 1, 23)).value,
          Entry.no,
          reason: 'io.csv-per-habit-checkmarks#3 the ORIGINAL entry for '
              '2015-01-23 is NO');
      final files = await exportAll();
      final checks = files['002 Wake up early/Checkmarks.csv']!;
      expect(checks.contains('2015-01-23,YES_AUTO,'), isTrue,
          reason: 'io.csv-per-habit-checkmarks#3 the exported value is the '
              'COMPUTED YES_AUTO synthesized from the habit frequency');
    });

    test('#5 #7 only known dates are emitted, values are raw integers',
        () async {
      final numerical = fixtures.createNumericalHabit();
      numerical.originalEntries
          .add(Entry(LocalDate.ymd(2015, 1, 25), 30000));
      numerical.recompute();
      habitList.add(numerical);
      final files = await exportAll();
      final checks = files['002 Run/Checkmarks.csv']!;
      final dates = checks
          .split('\n')
          .sublist(1)
          .where((l) => l.isNotEmpty)
          .map((l) => l.split(',')[0])
          .toList();
      // The fixture marks today-{0,1,3,5,7,8,9,10}: 2015-01-23, 2015-01-21 and
      // 2015-01-19 are unknown and therefore absent.
      expect(dates, <String>[
        '2015-01-25', '2015-01-24', '2015-01-22', '2015-01-20', //
        '2015-01-18', '2015-01-17', '2015-01-16', '2015-01-15',
      ],
          reason: 'io.csv-per-habit-checkmarks#5 only dates with a known entry '
              'are emitted, so the list can have gaps');
      expect(checks.split('\n')[1], '2015-01-25,30000,',
          reason: 'io.csv-per-habit-checkmarks#7 a numerical value is written '
              "as the raw integer ('30000' for 30 units)");
    });

    test('#10 a habit with no known computed entries gets only the header',
        () async {
      final files = await exportAll();
      expect(files['001 Meditate/Checkmarks.csv'], expectedMeditateCheckmarks,
          reason: 'io.csv-per-habit-checkmarks#10 with no known computed '
              'entries the file holds only the header line');
    });
  });

  group('io.csv-combined-scores', () {
    test('#1 #7 #8 #9 the reference top-level Scores.csv', () async {
      final files = await exportAll();
      final scores = files['Scores.csv']!;
      expect(scores.split('\n').first, 'Date,Meditate,Wake up early,',
          reason: 'io.csv-combined-scores#1 the header is Date + a trailing '
              'comma, then every selected habit name followed by a comma');
      expect(scores, expectedCombinedScores,
          reason: "io.csv-combined-scores#7 each row is '<date>,' then "
              "format('%.4f', score) + ',' per habit, then '\\n'");
      for (final row in scores.split('\n').where((l) => l.isNotEmpty)) {
        expect(row.endsWith(','), isTrue,
            reason: 'io.csv-combined-scores#7 every row ends with a trailing '
                'comma');
      }
      expect(scores.split('\n')[1], '2015-01-25,0.0000,0.2557,',
          reason: 'io.csv-combined-scores#8 index i aligns with the date '
              'today.minus(i), so row 0 holds the scores of today');
      expect(scores.split('\n')[10], '2015-01-16,0.0000,0.0107,',
          reason: 'io.csv-combined-scores#8 getByInterval is newest-first, so '
              'the last row holds the oldest scores');
      expect(scores.contains('2015-01-25,0.0000,0.2557,\n'), isTrue,
          reason: 'io.csv-combined-scores#9 the fixture row '
              "'2015-01-25,0.0000,0.2557,'");
    });

    test('#2 habit names are appended raw, without CSV quoting', () async {
      final list = MemoryHabitList();
      final tricky = fixtures.createEmptyHabit(name: 'Meditate, daily');
      final quoted = fixtures.createEmptyHabit(name: 'Say "hi"');
      list.add(tricky);
      list.add(quoted);
      final exporter = HabitsCSVExporter(list, allOf(list));
      final entries = await entriesOf(exporter);
      final header = entries
          .firstWhere((e) => e.name == 'Scores.csv')
          .content
          .split('\n')
          .first;
      expect(header, 'Date,Meditate, daily,Say "hi",',
          reason: 'io.csv-combined-scores#2 habit names are appended RAW, so a '
              'name containing a comma or quote corrupts the header');
    });

    test('#3 #4 #5 the range is [oldest .. today] over original entries',
        () async {
      final files = await exportAll();
      final dates = files['Scores.csv']!
          .split('\n')
          .sublist(1)
          .where((l) => l.isNotEmpty)
          .map((l) => l.split(',')[0])
          .toList();
      expect(dates.first, '2015-01-25',
          reason: 'io.csv-combined-scores#3 the newest row is today = '
              'getToday()');
      expect(dates.last, '2015-01-16',
          reason: 'io.csv-combined-scores#3 the oldest row is getTimeframe()[0]'
              ', the minimum oldest originalEntries date over selectedHabits');
      expect(dates.length, 10,
          reason: 'io.csv-combined-scores#5 the loop runs i in 0..days where '
              'days = oldest.daysUntil(today), so both ends are included');
      expect(dates, <String>[
        '2015-01-25', '2015-01-24', '2015-01-23', '2015-01-22', '2015-01-21', //
        '2015-01-20', '2015-01-19', '2015-01-18', '2015-01-17', '2015-01-16',
      ],
          reason: 'io.csv-combined-scores#5 the row date is today.minus(i), so '
              'rows run from today backwards to oldest');
      // The Meditate fixture has no original entries at all; the range comes
      // entirely from Wake up early.
      expect(habitList.getByPosition(0).originalEntries.getKnown(), isEmpty,
          reason: 'io.csv-combined-scores#4 habits with no known original '
              'entries are skipped by getTimeframe');
    });

    test('#6 no known original entry at all leaves only the header', () async {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'Meditate'));
      final exporter = HabitsCSVExporter(list, allOf(list));
      final entries = await entriesOf(exporter);
      expect(entries.firstWhere((e) => e.name == 'Scores.csv').content,
          'Date,Meditate,\n',
          reason: 'io.csv-combined-scores#6 with no known original entry, '
              'oldest stays LocalDate(1000000), days is negative and the loop '
              'body never runs');
    });
  });

  group('io.csv-combined-checkmarks', () {
    test('#1 #2 #3 #4 #5 the reference top-level Checkmarks.csv', () async {
      final files = await exportAll();
      final checks = files['Checkmarks.csv']!;
      expect(checks.split('\n').first, 'Date,Meditate,Wake up early,',
          reason: 'io.csv-combined-checkmarks#1 the header is identical to the '
              'combined Scores.csv header, trailing comma included');
      expect(checks, expectedCombinedCheckmarks,
          reason: 'io.csv-combined-checkmarks#4 every cell is '
              "entry.formattedValue followed by ',', and the row ends with "
              "'\\n'");
      final dates = checks
          .split('\n')
          .sublist(1)
          .where((l) => l.isNotEmpty)
          .map((l) => l.split(',')[0])
          .toList();
      expect(dates.first, '2015-01-25',
          reason: 'io.csv-combined-checkmarks#2 the range and loop match the '
              'combined Scores.csv');
      expect(dates.last, '2015-01-16',
          reason: 'io.csv-combined-checkmarks#2 the range and loop match the '
              'combined Scores.csv');
      expect(dates.length, 10,
          reason: 'io.csv-combined-checkmarks#2 i runs 0..oldest.daysUntil('
              'today)');
      expect(checks.contains('2015-01-25,UNKNOWN,YES_MANUAL,\n'), isTrue,
          reason: 'io.csv-combined-checkmarks#3 getByInterval fills unknown '
              'days with Entry(date, UNKNOWN)');
      expect(checks.split('\n')[1], '2015-01-25,UNKNOWN,YES_MANUAL,',
          reason: 'io.csv-combined-checkmarks#5 the fixture row '
              "'2015-01-25,UNKNOWN,YES_MANUAL,'");
      expect(checks.split('\n')[3], '2015-01-23,UNKNOWN,YES_AUTO,',
          reason: 'io.csv-combined-checkmarks#5 the fixture row '
              "'2015-01-23,UNKNOWN,YES_AUTO,'");
    });

    test('#6 cells are not CSV quoted', () async {
      final numerical = fixtures.createNumericalHabit();
      numerical.originalEntries.add(Entry(LocalDate.ymd(2015, 1, 25), 30000,
          notes: 'ran, a lot'));
      numerical.recompute();
      habitList.add(numerical);
      final files = await exportAll();
      final checks = files['Checkmarks.csv']!;
      expect(checks.split('\n')[1], '2015-01-25,UNKNOWN,30000,YES_MANUAL,',
          reason: 'io.csv-combined-checkmarks#6 cells are NOT CSV-quoted and '
              "numerical values render as raw integers such as '30000'");
    });
  });

  group('io.csv-habit-folder-naming', () {
    test('#1 #5 the folder is the padded index, a space, the sanitized name',
        () async {
      final files = await exportAll();
      expect(files.keys.where((k) => k.startsWith('001 Meditate/')).length, 2,
          reason: "io.csv-habit-folder-naming#1 habitDirName = format('%03d', "
              "indexOf + 1) + ' ' + sanitizeFilename(name).trim() + '/'");
      expect(files.containsKey('001 Meditate/Scores.csv'), isTrue,
          reason: 'io.csv-habit-folder-naming#5 the habit at index 0 named '
              "'Meditate' produces the folder '001 Meditate/'");

      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'Aardvark'));
      list.add(fixtures.createEmptyHabit(name: 'Café / Naps!'));
      final exporter = HabitsCSVExporter(list, allOf(list));
      final entries = await entriesOf(exporter);
      expect(entries.map((e) => e.name), contains('002 Caf  Naps/Scores.csv'),
          reason: "io.csv-habit-folder-naming#5 'Café / Naps!' at index 1 "
              "becomes '002 Caf  Naps/' after stripping and trimming");
    });

    test('#2 sanitizeFilename keeps only [ a-zA-Z0-9._-]', () async {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: r'a_b.c-d 9Z/\:*?"<>|,;!@#$%^&'));
      list.add(fixtures.createEmptyHabit(name: 'zzz 日本語 café 🎉 end'));
      final exporter = HabitsCSVExporter(list, allOf(list));
      final names = (await entriesOf(exporter)).map((e) => e.name).toList();
      expect(names, contains('001 a_b.c-d 9Z/Scores.csv'),
          reason: r"io.csv-habit-folder-naming#2 [^ a-zA-Z0-9._-]+ is replaced "
              'with the empty string, so only space, dot, underscore and hyphen '
              'survive alongside letters and digits');
      expect(names, contains('002 zzz  caf  end/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#2 accented, CJK and emoji '
              'characters are all stripped');
    });

    test('#3 the name is truncated to 100 characters before trimming',
        () async {
      final list = MemoryHabitList();
      // 99 letters, a space, then more: the cut at 100 leaves a trailing space
      // which habitDirName then trims away.
      final long = '${'y' * 99} zzzzz';
      list.add(fixtures.createEmptyHabit(name: long));
      final exporter = HabitsCSVExporter(list, allOf(list));
      final names = (await entriesOf(exporter)).map((e) => e.name).toList();
      expect(names, contains('001 ${'y' * 99}/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#3 the sanitized name is cut to '
              '100 characters BEFORE habitDirName trims it');

      final list2 = MemoryHabitList();
      list2.add(fixtures.createEmptyHabit(name: 'x' * 150));
      final exporter2 = HabitsCSVExporter(list2, allOf(list2));
      final names2 = (await entriesOf(exporter2)).map((e) => e.name).toList();
      expect(names2, contains('001 ${'x' * 100}/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#3 substring(0, min(length, 100))');

      // Leading spaces count towards the 100 characters, because they are only
      // trimmed afterwards: 3 spaces + 105 letters is cut to 3 spaces + 97
      // letters, and the trim then leaves 97 — not the 100 a trim-first
      // implementation would leave.
      final list3 = MemoryHabitList();
      list3.add(fixtures.createEmptyHabit(name: '   ${'w' * 105}'));
      final exporter3 = HabitsCSVExporter(list3, allOf(list3));
      final names3 = (await entriesOf(exporter3)).map((e) => e.name).toList();
      expect(names3, contains('001 ${'w' * 97}/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#3 the truncation happens BEFORE '
              'the .trim() applied by habitDirName');
    });

    test('#4 the index is allHabits.indexOf, and -1 yields 000', () async {
      final orphan = fixtures.createEmptyHabit(name: 'Orphan');
      final wake = habitList.getByPosition(1);
      final exporter = HabitsCSVExporter(habitList, <Habit>[orphan, wake]);
      final names = (await entriesOf(exporter)).map((e) => e.name).toList();
      expect(names, contains('000 Orphan/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#4 a habit missing from allHabits '
              "gets indexOf == -1, so the folder becomes '000 ...'");
      expect(names, contains('002 Wake up early/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#4 the index is allHabits.indexOf, '
              'matching the Position column, NOT the index within '
              'selectedHabits');
    });

    test('#6 the numeric prefix keeps colliding names apart', () async {
      final list = MemoryHabitList();
      list.add(fixtures.createEmptyHabit(name: 'Café'));
      list.add(fixtures.createEmptyHabit(name: 'Cafè'));
      final exporter = HabitsCSVExporter(list, allOf(list));
      final names = (await entriesOf(exporter)).map((e) => e.name).toList();
      expect(names.where((n) => n.contains('/')).toSet().length, 4,
          reason: 'io.csv-habit-folder-naming#6 two habits whose sanitized '
              'names collide still get distinct folders, because the numeric '
              'prefix is unique per habit');
      expect(names, contains('001 Caf/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#6 the numeric prefix is unique '
              'per habit');
      expect(names, contains('002 Caf/Scores.csv'),
          reason: 'io.csv-habit-folder-naming#6 the numeric prefix is unique '
              'per habit');
    });
  });

  group('io.export-csv-task', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('uhabits-export-');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('#1 #2 #6 the archive is written as Loop Habits CSV <date>.zip',
        () async {
      final listener = _RecordingListener();
      final outputDir = LocalUserFile(tempDir.path);
      final task =
          ExportCSVTask(habitList, allOf(habitList), outputDir, listener);
      await task.doInBackground();
      task.onPostExecute();

      final expectedPath = '${tempDir.path}/Loop Habits CSV 2015-01-25.zip';
      expect(File(expectedPath).existsSync(), isTrue,
          reason: 'io.export-csv-task#1 the bytes are written to '
              "outputDir.resolve('Loop Habits CSV <yyyy-MM-dd>.zip')");
      final zipped = ZipReader(
              Uint8List.fromList(File(expectedPath).readAsBytesSync()))
          .entries();
      expect((await zipped).map((e) => e.name), contains('Habits.csv'),
          reason: 'io.export-csv-task#1 the file holds the archive produced by '
              'HabitsCSVExporter(habitList, selectedHabits).writeArchive()');
      expect(listener.calls, 1,
          reason: 'io.export-csv-task#6 onPostExecute always calls '
              'listener.onExportCSVFinished');
      expect(listener.filenames.single, expectedPath,
          reason: 'io.export-csv-task#2 on success the listener receives '
              'zipFile.pathString');
    });

    test('#3 #6 an exception leaves archiveFilename null', () async {
      final listener = _RecordingListener();
      final task = ExportCSVTask(
          habitList, allOf(habitList), _ThrowingUserFile(), listener);
      await task.doInBackground();
      task.onPostExecute();
      expect(listener.calls, 1,
          reason: 'io.export-csv-task#6 the listener is called whether or not '
              'the export succeeded');
      expect(listener.filenames.single, isNull,
          reason: 'io.export-csv-task#3 any exception is caught, '
              'archiveFilename stays null and the listener receives null');
    });

    test('#4 exporting twice on the same day overwrites the file', () async {
      final outputDir = LocalUserFile(tempDir.path);
      final listener = _RecordingListener();
      for (var i = 0; i < 2; i++) {
        final task =
            ExportCSVTask(habitList, allOf(habitList), outputDir, listener);
        await task.doInBackground();
        task.onPostExecute();
      }
      expect(tempDir.listSync().map((e) => e.path).toList(),
          <String>['${tempDir.path}/Loop Habits CSV 2015-01-25.zip'],
          reason: 'io.export-csv-task#4 the name contains only the date, with '
              'no time component, so a second export overwrites the first');
      expect(listener.filenames.toSet().length, 1,
          reason: 'io.export-csv-task#4 both exports resolve the same path');
    });

    test('#5 missing parent directories are created', () async {
      final listener = _RecordingListener();
      final nested = '${tempDir.path}/a/b/c';
      expect(Directory(nested).existsSync(), isFalse,
          reason: 'io.export-csv-task#5 the parent directories do not exist '
              'yet');
      final task = ExportCSVTask(
          habitList, allOf(habitList), LocalUserFile(nested), listener);
      await task.doInBackground();
      task.onPostExecute();
      expect(File('$nested/Loop Habits CSV 2015-01-25.zip').existsSync(), isTrue,
          reason: 'io.export-csv-task#5 writeBytes creates any missing parent '
              'directories before writing');
    });
  });
}

class _RecordingListener implements ExportCSVListener {
  final List<String?> filenames = <String?>[];

  int get calls => filenames.length;

  @override
  void onExportCSVFinished(String? archiveFilename) {
    filenames.add(archiveFilename);
  }
}

/// A [UserFile] whose [writeBytes] always fails, standing in for a full disk or
/// a revoked content URI.
class _ThrowingUserFile implements UserFile {
  @override
  String get pathString => '/nonexistent';

  @override
  UserFile resolve(String child) => this;

  @override
  Future<void> writeBytes(List<int> bytes) async {
    throw const FileSystemException('cannot write');
  }

  @override
  Future<void> delete() => throw UnimplementedError();

  @override
  Future<bool> exists() => throw UnimplementedError();

  @override
  Future<List<String>> lines() => throw UnimplementedError();

  @override
  Future<List<UserFile>?> listFiles() => throw UnimplementedError();

  @override
  Future<void> mkdirs() => throw UnimplementedError();

  @override
  Future<Uint8List> readBytes(int limit) => throw UnimplementedError();

  @override
  Future<void> writeString(String content) => throw UnimplementedError();
}
