/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt
/// (the HabitBull, Rewire and Tickmate halves), covering
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/{HabitBullCSVImporter,
/// RewireDBImporter,TickmateDBImporter}.kt and
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/utils/FileExtensions.kt.
///
/// The Kotlin test drives the three importers through `GenericImporter`; that
/// class belongs to the `io.importer-dispatch` slice, so here each importer is
/// exercised directly.
///
/// The fixtures live in the Kotlin module (`uhabits-core/assets/test`). They are
/// always copied into a temporary directory before being opened: the importers
/// open the databases read-write and run BEGIN/COMMIT on them.
library;

import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/habit_bull_csv_importer.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/io/rewire_db_importer.dart';
import 'package:uhabits_core/src/io/tickmate_db_importer.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/weekday_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Records every `add` / `update` so the tests can show that the importers go
/// straight to the list and never build a Command.
class _RecordingHabitList extends MemoryHabitList {
  final List<String> ops = <String>[];

  @override
  void add(Habit habit) {
    ops.add('add:${habit.name}');
    super.add(habit);
  }

  @override
  void update(List<Habit> habits) {
    ops.add('update:${habits.map((h) => h.name).join(',')}');
    super.update(habits);
  }
}

/// Counts `recompute()` calls per habit.
class _CountingHabit extends Habit {
  _CountingHabit({
    required super.computedEntries,
    required super.originalEntries,
    required super.scores,
    required super.streaks,
  });

  int recomputeCount = 0;

  @override
  void recompute() {
    recomputeCount++;
    super.recompute();
  }
}

class _CountingModelFactory extends MemoryModelFactory {
  @override
  Habit buildHabit() => _CountingHabit(
        scores: buildScoreList(),
        streaks: buildStreakList(),
        originalEntries: buildOriginalEntries(),
        computedEntries: buildComputedEntries(),
      );
}

/// Records `open`, every prepared statement and `close`, in order.
class _RecordingOpener implements DatabaseOpener {
  _RecordingOpener();

  final DatabaseOpener inner = const Sqlite3DatabaseOpener();
  final List<String> sql = <String>[];
  final List<String> events = <String>[];
  int openCount = 0;
  int closeCount = 0;

  @override
  Database open(String path) {
    openCount++;
    events.add('open');
    return _RecordingDatabase(inner.open(path), this);
  }
}

class _RecordingDatabase implements Database {
  _RecordingDatabase(this.inner, this.rec);

  final Database inner;
  final _RecordingOpener rec;

  @override
  PreparedStatement prepareStatement(String sql) {
    rec.sql.add(sql);
    rec.events.add(sql);
    return inner.prepareStatement(sql);
  }

  @override
  void close() {
    rec.closeCount++;
    rec.events.add('close');
    inner.close();
  }
}

class _CapturingSink implements StringSink {
  final List<String> lines = <String>[];
  final StringBuffer _pending = StringBuffer();

  @override
  void write(Object? obj) => _pending.write(obj);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _pending.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _pending.writeCharCode(charCode);

  @override
  void writeln([Object? obj = '']) {
    lines.add('$_pending$obj');
    _pending.clear();
  }

  String get text => lines.join('\n');

  int count(String needle) => lines.where((l) => l.contains(needle)).length;
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Walks up from the working directory until `uhabits-core/assets/test` is
/// found. The Dart package lives under `uhabits-flutter/packages/uhabits_core`,
/// three levels below the repository root.
String _findAssetsDir() {
  var dir = Directory.current.absolute;
  while (true) {
    final candidate = Directory('${dir.path}/uhabits-core/assets/test');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate uhabits-core/assets/test');
    }
    dir = parent;
  }
}

void main() {
  final assetsDir = _findAssetsDir();

  late Directory tmp;
  late _RecordingHabitList habitList;
  late _CountingModelFactory modelFactory;
  late _CapturingSink out;
  late _CapturingSink err;
  late StandardLogging logging;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('uhabits_importers_test');
    habitList = _RecordingHabitList();
    modelFactory = _CountingModelFactory();
    out = _CapturingSink();
    err = _CapturingSink();
    logging = StandardLogging(out: out, err: err);
    setToday(LocalDate.ymd(2023, 1, 1));
  });

  tearDown(() {
    resetToday();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Copies one of the Kotlin fixtures into the temporary directory. Never
  /// opens the original: the DB importers write to the file they are given.
  UserFile fixture(String name) {
    final dest = '${tmp.path}/$name';
    File('$assetsDir/$name').copySync(dest);
    return LocalUserFile(dest);
  }

  UserFile writeFile(String name, String content) {
    final dest = '${tmp.path}/$name';
    File(dest).writeAsStringSync(content);
    return LocalUserFile(dest);
  }

  UserFile writeBytes(String name, List<int> bytes) {
    final dest = '${tmp.path}/$name';
    File(dest).writeAsBytesSync(bytes);
    return LocalUserFile(dest);
  }

  UserFile buildDatabase(String name, List<String> statements) {
    final dest = '${tmp.path}/$name';
    final db = sqlite.sqlite3.open(dest);
    for (final statement in statements) {
      db.execute(statement);
    }
    db.dispose();
    return LocalUserFile(dest);
  }

  HabitBullCSVImporter habitBull() =>
      HabitBullCSVImporter(habitList, modelFactory, logging);

  int valueAt(Habit h, int year, int month, int day) =>
      h.originalEntries.get(LocalDate.ymd(year, month, day)).value;

  String notesAt(Habit h, int year, int month, int day) =>
      h.originalEntries.get(LocalDate.ymd(year, month, day)).notes;

  bool isChecked(Habit h, int year, int month, int day) =>
      valueAt(h, year, month, day) == Entry.yesManual;

  // =========================================================================
  // io.habitbull-detection
  // =========================================================================

  group('io.habitbull-detection', () {
    test('#1 an empty file is never handled', () async {
      expect(await habitBull().canHandle(writeFile('empty.csv', '')), isFalse,
          reason: 'io.habitbull-detection#1 canHandle reads file.lines(); if '
              'the list is empty it returns false');
    });

    test('#2 only the first three header columns are checked', () async {
      expect(await habitBull().canHandle(fixture('habitbull.csv')), isTrue,
          reason: 'io.habitbull-detection#2 the real HabitBull header starts '
              "with 'HabitName,HabitDescription,HabitCategory'");
      expect(
          await habitBull().canHandle(
              writeFile('short.csv', 'HabitName,HabitDescription,HabitCategory\n')),
          isTrue,
          reason: 'io.habitbull-detection#2 the remaining header columns '
              '(CalendarDate,Value,CommentText) are not checked');
      expect(
          await habitBull().canHandle(writeFile('other.csv',
              'Name,Description,Category,CalendarDate,Value,CommentText\n')),
          isFalse,
          reason: "io.habitbull-detection#2 returns true only when lines[0] "
              "starts with 'HabitName,HabitDescription,HabitCategory'");
      expect(
          await habitBull().canHandle(writeFile('later.csv',
              'junk\nHabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n')),
          isFalse,
          reason: 'io.habitbull-detection#2 only lines[0] is inspected, not '
              'any later line');
    });

    test('#3 any read error is swallowed and yields false', () async {
      // 0xC3 0x28 is an invalid UTF-8 sequence, so decoding throws.
      expect(await habitBull().canHandle(writeBytes('binary.bin', <int>[0xc3, 0x28, 0xff])),
          isFalse,
          reason: 'io.habitbull-detection#3 a binary file that cannot be '
              'decoded is caught and canHandle returns false');
      expect(await habitBull().canHandle(fixture('tickmate.db')), isFalse,
          reason: 'io.habitbull-detection#3 a real SQLite file is not valid '
              'UTF-8, so the exception is caught and canHandle returns false');
      expect(await habitBull().canHandle(LocalUserFile('${tmp.path}/missing.csv')),
          isFalse,
          reason: 'io.habitbull-detection#3 a missing file throws while '
              'reading and canHandle returns false');
    });

    test('#4 detection is prefix based', () async {
      expect(
          await habitBull().canHandle(writeFile(
              'extra.csv',
              'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,'
                  'CommentText,ExtraColumn,AnotherOne\n')),
          isTrue,
          reason: 'io.habitbull-detection#4 a header with extra trailing '
              'columns still matches');
      expect(
          await habitBull().canHandle(
              writeFile('glued.csv', 'HabitName,HabitDescription,HabitCategoryX\n')),
          isTrue,
          reason: 'io.habitbull-detection#4 startsWith does not require a '
              'column boundary after the prefix');
    });
  });

  // =========================================================================
  // io.habitbull-mapping
  // =========================================================================

  group('io.habitbull-mapping', () {
    test('#1 lines with fewer than 6 columns are skipped silently', () async {
      final file = writeFile(
          'short.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Short,only,five,cols,here\n'
          '\n'
          'Good,desc,cat,2016-01-01,1,note\n');
      await habitBull().importHabitsFromFile(file);
      expect(habitList.size(), 1,
          reason: 'io.habitbull-mapping#1 lines producing fewer than 6 columns '
              'are skipped silently');
      expect(habitList.getByPosition(0).name, 'Good',
          reason: 'io.habitbull-mapping#1 only the 6-column line produced a '
              'habit; the 5-column line and the blank line were skipped');
      expect(out.count('Creating habit'), 1,
          reason: 'io.habitbull-mapping#1 skipping is silent: no extra log '
              'line is emitted for the short lines');
    });

    test('#2 a line whose column 0 is exactly HabitName is skipped', () async {
      final file = writeFile(
          'headers.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'A,d,c,2016-01-01,1,\n'
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'B,d,c,2016-01-02,1,\n'
          'HabitNames,d,c,2016-01-03,1,\n');
      await habitBull().importHabitsFromFile(file);
      expect(habitList.map((h) => h.name).toList(), <String>['A', 'B', 'HabitNames'],
          reason: 'io.habitbull-mapping#2 the header is skipped wherever it '
              "appears, but only when column 0 equals exactly 'HabitName'");
      expect(habitList.getByPosition(2).name, 'HabitNames',
          reason: "io.habitbull-mapping#2 'HabitNames' is not 'HabitName', so "
              'it creates a habit');
    });

    test('#3 column layout: 0 name, 1 description, 2 ignored, 3 date, 4 value, '
        '5 notes', () async {
      final file = writeFile(
          'layout.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Alpha,the description,IGNORED CATEGORY,2016-05-04,1,the notes\n');
      await habitBull().importHabitsFromFile(file);
      final h = habitList.getByPosition(0);
      expect(h.name, 'Alpha',
          reason: 'io.habitbull-mapping#3 column 0 is HabitName');
      expect(h.description, 'the description',
          reason: 'io.habitbull-mapping#3 column 1 is HabitDescription');
      expect(h.question, '',
          reason: 'io.habitbull-mapping#3 column 2 (HabitCategory) is IGNORED: '
              'it is written nowhere on the habit');
      expect(h.unit, '',
          reason: 'io.habitbull-mapping#3 column 2 (HabitCategory) is IGNORED');
      expect(valueAt(h, 2016, 5, 4), Entry.yesManual,
          reason: 'io.habitbull-mapping#3 column 3 is CalendarDate and column 4 '
              'is Value');
      expect(notesAt(h, 2016, 5, 4), 'the notes',
          reason: 'io.habitbull-mapping#3 column 5 (CommentText) is used as the '
              'entry notes');
    });

    test('#4 habits are keyed by name and the description is never updated',
        () async {
      final file = writeFile(
          'reuse.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Alpha,first description,c,2016-01-01,1,\n'
          'Alpha,second description,c,2016-01-02,1,\n');
      await habitBull().importHabitsFromFile(file);
      expect(habitList.size(), 1,
          reason: 'io.habitbull-mapping#4 habits are keyed by name in a '
              'HashMap, so the second line reuses the habit');
      final h = habitList.getByPosition(0);
      expect(h.description, 'first description',
          reason: 'io.habitbull-mapping#4 later lines for the same name do NOT '
              'update the description');
      expect(h.frequency, Frequency.daily,
          reason: 'io.habitbull-mapping#4 the first line for a name creates the '
              'habit with frequency = Frequency.DAILY');
      expect(valueAt(h, 2016, 1, 2), Entry.yesManual,
          reason: 'io.habitbull-mapping#4 later lines still add their entries '
              'to the reused habit');
      expect(habitList.ops, <String>['add:Alpha'],
          reason: 'io.habitbull-mapping#4 the habit is added to habitList once, '
              'when it is created');
    });

    test('#5 date parsing: dash is y-m-d, slash is M/D/Y, anything else throws',
        () async {
      final dashed = writeFile(
          'dash.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Dash,d,c,2016-03-18,1,\n');
      await habitBull().importHabitsFromFile(dashed);
      expect(isChecked(habitList.getByPosition(0), 2016, 3, 18), isTrue,
          reason: "io.habitbull-mapping#5 a raw value containing '-' is split "
              'on it and read as year-month-day');

      habitList = _RecordingHabitList();
      final slashed = writeFile(
          'slash.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Slash,d,c,4/11/2019,1,\n');
      await habitBull().importHabitsFromFile(slashed);
      expect(isChecked(habitList.getByPosition(0), 2019, 4, 11), isTrue,
          reason: "io.habitbull-mapping#5 a raw value containing '/' is read as "
              'MONTH/DAY/YEAR: LocalDate(parts[2], parts[0], parts[1])');
      expect(isChecked(habitList.getByPosition(0), 2019, 11, 4), isFalse,
          reason: 'io.habitbull-mapping#5 slash dates are US-style, so 4/11 is '
              'April 11 and not November 4');

      habitList = _RecordingHabitList();
      final bad = writeFile(
          'bad.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Before,d,c,2016-01-01,1,\n'
          'Broken,d,c,2016.03.18,1,\n'
          'After,d,c,2016-01-02,1,\n');
      await expectLater(
          () => habitBull().importHabitsFromFile(bad),
          throwsA(isA<Exception>().having((Object e) => e.toString(), 'message',
              contains('Unrecognized date format: 2016.03.18'))),
          reason: "io.habitbull-mapping#5 a date with neither '-' nor '/' "
              "throws Exception('Unrecognized date format: <raw>')");
      expect(habitList.map((h) => h.name).toList(), <String>['Before'],
          reason: 'io.habitbull-mapping#5 the exception aborts the whole '
              'import, so the line after the broken one is never processed');
      expect((habitList.getByPosition(0) as _CountingHabit).recomputeCount, 0,
          reason: 'io.habitbull-mapping#5 the import aborts before the '
              'recompute loop, leaving the already-created habit unrecomputed');
    });

    test('#6 an unparsable or out-of-Int-range value becomes zero', () async {
      final file = writeFile(
          'ints.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Overflow,d,c,2020-11-05,-2150000000,\n'
          'Garbage,d,c,2020-11-06,abc,\n');
      await habitBull().importHabitsFromFile(file);
      final overflow = habitList.getByPosition(1);
      expect(overflow.name, 'Overflow',
          reason: 'io.habitbull-mapping#6 sanity check on the fixture layout');
      expect(valueAt(overflow, 2020, 11, 5), Entry.no,
          reason: "io.habitbull-mapping#6 '-2150000000' is outside Int range, "
              'so rawValue.toInt() throws and the value becomes 0');
      expect(valueAt(habitList.getByPosition(0), 2020, 11, 6), Entry.no,
          reason: "io.habitbull-mapping#6 'abc' throws NumberFormatException "
              'and the value becomes 0');
      expect(
          out.text,
          contains('Could not parse int: -2150000000. Replacing by zero.'),
          reason: 'io.habitbull-mapping#6 logs '
              "'Could not parse int: <raw>. Replacing by zero.'");
      expect(out.text, contains('Could not parse int: abc. Replacing by zero.'),
          reason: 'io.habitbull-mapping#6 logs '
              "'Could not parse int: <raw>. Replacing by zero.'");
    });

    test('#7 value 0 is NO and value 1 is YES_MANUAL', () async {
      final file = writeFile(
          'bool.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Bool,d,c,2016-01-01,0,zero notes\n'
          'Bool,d,c,2016-01-02,1,one notes\n');
      await habitBull().importHabitsFromFile(file);
      final h = habitList.getByPosition(0);
      expect(valueAt(h, 2016, 1, 1), Entry.no,
          reason: 'io.habitbull-mapping#7 value 0 adds Entry(date, Entry.NO = 0, '
              'notes)');
      expect(valueAt(h, 2016, 1, 1), 0,
          reason: 'io.habitbull-mapping#7 Entry.NO is 0');
      expect(notesAt(h, 2016, 1, 1), 'zero notes',
          reason: 'io.habitbull-mapping#7 the notes come from column 5');
      expect(valueAt(h, 2016, 1, 2), Entry.yesManual,
          reason: 'io.habitbull-mapping#7 value 1 adds Entry(date, '
              'Entry.YES_MANUAL = 2, notes)');
      expect(valueAt(h, 2016, 1, 2), 2,
          reason: 'io.habitbull-mapping#7 Entry.YES_MANUAL is 2');
      expect(notesAt(h, 2016, 1, 2), 'one notes',
          reason: 'io.habitbull-mapping#7 the notes come from column 5');
      expect(h.type, HabitType.yesNo,
          reason: 'io.habitbull-mapping#7 values 0 and 1 never change the '
              'habit type');
    });

    test('#8 any other value is value*1000; only value > 1 flips the type',
        () async {
      final file = writeFile(
          'numeric.csv',
          'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,CommentText\n'
          'Pushups,d,c,2021-09-01,30,\n'
          'Pushups,d,c,2021-09-02,100,\n'
          'Neg,d,c,2021-09-01,-3,\n');
      await habitBull().importHabitsFromFile(file);
      final pushups = habitList.getByPosition(1);
      expect(pushups.name, 'Pushups',
          reason: 'io.habitbull-mapping#8 sanity check on the fixture layout');
      expect(valueAt(pushups, 2021, 9, 1), 30000,
          reason: 'io.habitbull-mapping#8 any other value adds Entry(date, '
              'value * 1000, notes)');
      expect(pushups.type, HabitType.numerical,
          reason: 'io.habitbull-mapping#8 a value > 1 switches the habit to '
              'HabitType.NUMERICAL');
      expect(out.text,
          contains('Found a value of 30, considering this habit as numerical.'),
          reason: "io.habitbull-mapping#8 logs 'Found a value of <v>, "
              "considering this habit as numerical.'");
      expect(out.count('considering this habit as numerical'), 1,
          reason: 'io.habitbull-mapping#8 the type is only switched (and the '
              'message only logged) when the habit is not already NUMERICAL');

      final neg = habitList.getByPosition(0);
      expect(neg.name, 'Neg',
          reason: 'io.habitbull-mapping#8 sanity check on the fixture layout');
      expect(valueAt(neg, 2021, 9, 1), -3000,
          reason: 'io.habitbull-mapping#8 negative values (< 0) also take the '
              'else branch and are stored as value * 1000');
      expect(neg.type, HabitType.yesNo,
          reason: 'io.habitbull-mapping#8 negative values do NOT flip the type');
    });

    test('#9 recompute() runs exactly once per habit created by this import',
        () async {
      await habitBull().importHabitsFromFile(fixture('habitbull.csv'));
      expect(habitList.size(), 4,
          reason: 'io.habitbull-mapping#9 sanity check before counting '
              'recompute() calls');
      for (final habit in habitList) {
        expect((habit as _CountingHabit).recomputeCount, 1,
            reason: 'io.habitbull-mapping#9 after all lines are processed, '
                'recompute() is called once on every habit created during this '
                'import');
      }
      expect(habitList.getByPosition(0).computedEntries.getKnown(), isNotEmpty,
          reason: 'io.habitbull-mapping#9 recompute() populated the derived '
              'entries');
    });

    test('#10 habitbull.csv fixture', () async {
      await habitBull().importHabitsFromFile(fixture('habitbull.csv'));
      expect(habitList.size(), 4,
          reason: 'io.habitbull-mapping#10 habitbull.csv -> 4 habits');
      final h = habitList.getByPosition(0);
      expect(h.name, 'Breed dragons',
          reason: "io.habitbull-mapping#10 habitbull.csv -> 'Breed dragons'");
      expect(h.description, 'with love and fire',
          reason: "io.habitbull-mapping#10 'Breed dragons' has description "
              "'with love and fire'");
      expect(h.frequency, Frequency.daily,
          reason: "io.habitbull-mapping#10 'Breed dragons' is daily");
      expect(isChecked(h, 2016, 3, 18), isTrue,
          reason: "io.habitbull-mapping#10 'Breed dragons' is checked on "
              '2016-03-18');
      expect(isChecked(h, 2016, 3, 19), isTrue,
          reason: "io.habitbull-mapping#10 'Breed dragons' is checked on "
              '2016-03-19');
      expect(isChecked(h, 2016, 3, 20), isFalse,
          reason: "io.habitbull-mapping#10 'Breed dragons' is not checked on "
              '2016-03-20');
      expect(notesAt(h, 2016, 3, 18), 'text',
          reason: "io.habitbull-mapping#10 'Breed dragons' carries notes 'text' "
              'on 2016-03-18');
    });

    test('#10 habitbull2.csv fixture (US-style slash dates)', () async {
      await habitBull().importHabitsFromFile(fixture('habitbull2.csv'));
      expect(habitList.size(), 6,
          reason: 'io.habitbull-mapping#10 habitbull2.csv -> 6 habits with '
              'US-style slash dates');
      final h = habitList.getByPosition(2);
      expect(h.name, 'H3',
          reason: "io.habitbull-mapping#10 habitbull2.csv -> 'H3'");
      expect(h.description, 'Habit 3',
          reason: "io.habitbull-mapping#10 'H3' has description 'Habit 3'");
      expect(h.frequency, Frequency.daily,
          reason: "io.habitbull-mapping#10 'H3' is daily");
      expect(isChecked(h, 2019, 4, 11), isTrue,
          reason: "io.habitbull-mapping#10 'H3' is checked on 2019-04-11");
      expect(isChecked(h, 2019, 5, 7), isTrue,
          reason: "io.habitbull-mapping#10 'H3' is checked on 2019-05-07");
      expect(isChecked(h, 2019, 6, 14), isFalse,
          reason: "io.habitbull-mapping#10 'H3' is not checked on 2019-06-14");
      expect(notesAt(h, 2019, 6, 14), 'Habit 3 notes',
          reason: "io.habitbull-mapping#10 2019-06-14 carries notes 'Habit 3 "
              "notes'");
      expect(notesAt(h, 2019, 4, 11), 'text',
          reason: "io.habitbull-mapping#10 'H3' carries notes 'text' on "
              '2019-04-11');
    });

    test('#10 habitbull3.csv fixture (numerical vs yes/no)', () async {
      await habitBull().importHabitsFromFile(fixture('habitbull3.csv'));
      expect(habitList.size(), 2,
          reason: 'io.habitbull-mapping#10 habitbull3.csv -> 2 habits');
      final pushups = habitList.getByPosition(0);
      expect(pushups.name, 'Pushups',
          reason: "io.habitbull-mapping#10 habitbull3.csv -> 'Pushups'");
      expect(pushups.type, HabitType.numerical,
          reason: "io.habitbull-mapping#10 'Pushups' becomes NUMERICAL");
      expect(pushups.description, '',
          reason: "io.habitbull-mapping#10 'Pushups' has an empty description");
      expect(pushups.frequency, Frequency.daily,
          reason: "io.habitbull-mapping#10 'Pushups' is daily");
      expect(valueAt(pushups, 2021, 9, 1), 30000,
          reason: "io.habitbull-mapping#10 'Pushups' has value 30000 on "
              '2021-09-01');
      expect(valueAt(pushups, 2022, 1, 8), 100000,
          reason: "io.habitbull-mapping#10 'Pushups' has value 100000 on "
              '2022-01-08');
      final run = habitList.getByPosition(1);
      expect(run.name, 'run',
          reason: "io.habitbull-mapping#10 habitbull3.csv -> 'run'");
      expect(run.type, HabitType.yesNo,
          reason: "io.habitbull-mapping#10 'run' stays YES_NO");
      expect(isChecked(run, 2022, 1, 3), isTrue,
          reason: "io.habitbull-mapping#10 'run' is checked on 2022-01-03");
      expect(isChecked(run, 2022, 1, 18), isTrue,
          reason: "io.habitbull-mapping#10 'run' is checked on 2022-01-18");
      expect(isChecked(run, 2022, 1, 19), isTrue,
          reason: "io.habitbull-mapping#10 'run' is checked on 2022-01-19");
    });

    test('#10 habitbull4.csv fixture', () async {
      await habitBull().importHabitsFromFile(fixture('habitbull4.csv'));
      expect(habitList.size(), 1,
          reason: 'io.habitbull-mapping#10 habitbull4.csv -> 1 habit');
      final h = habitList.getByPosition(0);
      expect(h.name, 'Caffeine',
          reason: "io.habitbull-mapping#10 habitbull4.csv -> 'Caffeine'");
      expect(h.type, HabitType.numerical,
          reason: "io.habitbull-mapping#10 'Caffeine' becomes NUMERICAL");
      expect(h.description, '',
          reason: "io.habitbull-mapping#10 'Caffeine' has an empty description");
      expect(h.frequency, Frequency.daily,
          reason: "io.habitbull-mapping#10 'Caffeine' is daily");
      expect(valueAt(h, 2022, 11, 21), 80000,
          reason: "io.habitbull-mapping#10 'Caffeine' has 80000 on 2022-11-21");
      expect(valueAt(h, 2022, 11, 22), 80000,
          reason: "io.habitbull-mapping#10 'Caffeine' has 80000 on 2022-11-22");
    });

    test('#11 habits go straight into the list, with no Command', () async {
      await habitBull().importHabitsFromFile(fixture('habitbull.csv'));
      expect(
          habitList.ops,
          <String>[
            'add:Breed dragons',
            'add:Reduce sleep',
            'add:No-arms pushup',
            'add:Grow spiritually',
          ],
          reason: 'io.habitbull-mapping#11 habits are added with '
              'habitList.add(h) directly, in file order, and nothing else '
              'touches the list — so a HabitBull import is not undoable');
      expect(habitList.ops.where((op) => op.startsWith('update')), isEmpty,
          reason: 'io.habitbull-mapping#11 no Command and no update() call is '
              'involved in a HabitBull import');
    });
  });

  // =========================================================================
  // io.rewire-import
  // =========================================================================

  group('io.rewire-import', () {
    const rewireCountSql =
        "select count(*) from SQLITE_MASTER where name='CHECKINS' or name='UNIT'";
    const rewireHabitsSql = 'select _id, name, description, schedule, '
        'active_days, repeating_count, days, period '
        'from habits';
    const rewireCheckinsSql =
        'select distinct date from checkins where habit_id=? and type=2';
    const rewireRemindersSql =
        'select time, active_days from reminders where habit_id=? limit 1';

    RewireDBImporter rewire([DatabaseOpener? opener]) => RewireDBImporter(
        habitList, modelFactory, opener ?? const Sqlite3DatabaseOpener());

    /// A minimal Rewire schema.
    List<String> rewireSchema() => <String>[
          'CREATE TABLE CHECKINS (_id INTEGER PRIMARY KEY, Habit_id INTEGER NOT NULL, '
              'date TEXT NOT NULL, type INTEGER NOT NULL)',
          'CREATE TABLE UNIT (_id INTEGER PRIMARY KEY, name TEXT)',
          'CREATE TABLE Habits (_id INTEGER PRIMARY KEY, Name TEXT NOT NULL, '
              'description TEXT, active_days TEXT, schedule INTEGER, days INTEGER, '
              'period INTEGER, repeating_count INTEGER)',
          'CREATE TABLE REMINDERS (_id INTEGER PRIMARY KEY, habit_id INTEGER, '
              'time INTEGER, active_days TEXT)',
        ];

    test('#1 canHandle requires a SQLite3 file with exactly CHECKINS and UNIT',
        () async {
      final opener = _RecordingOpener();
      expect(await rewire(opener).canHandle(fixture('rewire.db')), isTrue,
          reason: 'io.rewire-import#1 rewire.db is a SQLite3 file whose '
              "SQLITE_MASTER holds both 'CHECKINS' and 'UNIT'");
      expect(opener.sql, <String>[rewireCountSql],
          reason: 'io.rewire-import#1 canHandle runs exactly '
              "select count(*) from SQLITE_MASTER where name='CHECKINS' or "
              "name='UNIT'");

      expect(await rewire().canHandle(fixture('tickmate.db')), isFalse,
          reason: 'io.rewire-import#1 a Tickmate database has neither CHECKINS '
              'nor UNIT, so the count is 0 and canHandle returns false');
      expect(await rewire().canHandle(fixture('habitbull.csv')), isFalse,
          reason: 'io.rewire-import#1 canHandle returns false unless '
              'isSQLite3File(file)');
      expect(await rewire().canHandle(LocalUserFile('${tmp.path}/missing.db')),
          isFalse,
          reason: 'io.rewire-import#1 a missing file is not a SQLite3 file');

      final onlyCheckins = buildDatabase('only_checkins.db',
          <String>['CREATE TABLE CHECKINS (_id INTEGER PRIMARY KEY)']);
      expect(await rewire().canHandle(onlyCheckins), isFalse,
          reason: 'io.rewire-import#1 returns true only when the count is '
              'exactly 2');

      final lowercase = buildDatabase('lowercase.db', <String>[
        'CREATE TABLE checkins (_id INTEGER PRIMARY KEY)',
        'CREATE TABLE unit (_id INTEGER PRIMARY KEY)',
      ]);
      expect(await rewire().canHandle(lowercase), isFalse,
          reason: 'io.rewire-import#1 table names are matched in UPPERCASE, so '
              'lowercase tables do not count');

      final both = buildDatabase('both.db', <String>[
        'CREATE TABLE CHECKINS (_id INTEGER PRIMARY KEY)',
        'CREATE TABLE UNIT (_id INTEGER PRIMARY KEY)',
        'CREATE TABLE something_else (_id INTEGER PRIMARY KEY)',
      ]);
      expect(await rewire().canHandle(both), isTrue,
          reason: 'io.rewire-import#1 only CHECKINS and UNIT are counted; other '
              'tables are irrelevant');
    });

    test('#2 open, BEGIN, create habits, COMMIT, close', () async {
      final opener = _RecordingOpener();
      await rewire(opener).importHabitsFromFile(fixture('rewire.db'));
      expect(opener.openCount, 1,
          reason: 'io.rewire-import#2 importHabitsFromFile opens the file once');
      expect(opener.events.first, 'open',
          reason: 'io.rewire-import#2 the file is opened first');
      expect(opener.events[1], 'BEGIN',
          reason: 'io.rewire-import#2 BEGIN is issued on the imported database '
              'before any habit is read');
      expect(opener.events[2], rewireHabitsSql,
          reason: 'io.rewire-import#2 the habits are created inside the '
              'transaction');
      expect(opener.events[opener.events.length - 2], 'COMMIT',
          reason: 'io.rewire-import#2 COMMIT is issued after the habits are '
              'created');
      expect(opener.events.last, 'close',
          reason: 'io.rewire-import#2 the database is closed last');
      expect(opener.closeCount, 1,
          reason: 'io.rewire-import#2 the database is closed exactly once');
    });

    test('#3 habits query and NULL description', () async {
      final opener = _RecordingOpener();
      await rewire(opener).importHabitsFromFile(fixture('rewire.db'));
      expect(opener.sql, contains(rewireHabitsSql),
          reason: 'io.rewire-import#3 habits query: select _id, name, '
              'description, schedule, active_days, repeating_count, days, '
              'period from habits');

      habitList = _RecordingHabitList();
      final db = buildDatabase('null_desc.db', <String>[
        ...rewireSchema(),
        "INSERT INTO Habits VALUES (1, 'No description', NULL, '1,2', 0, 0, 0, 0)",
      ]);
      await rewire().importHabitsFromFile(db);
      expect(habitList.getByPosition(0).description, '',
          reason: "io.rewire-import#3 a NULL description becomes ''");
    });

    test('#4 frequency mapping by schedule', () async {
      await rewire().importHabitsFromFile(fixture('rewire.db'));
      expect(habitList.getByPosition(1).frequency, Frequency(3, 7),
          reason: "io.rewire-import#4 schedule 0 -> numerator = number of "
              "comma-separated tokens in active_days ('1,3,5' -> 3), "
              'denominator = 7');
      expect(habitList.getByPosition(2).frequency, Frequency(3, 7),
          reason: 'io.rewire-import#4 schedule 1 -> numerator = days (3), '
              'denominator = periods[period] with periods = [7, 31, 365]');
      expect(habitList.getByPosition(0).frequency, Frequency(1, 5),
          reason: 'io.rewire-import#4 schedule 2 -> numerator = 1, denominator '
              '= repeating_count (5)');

      habitList = _RecordingHabitList();
      final periods = buildDatabase('periods.db', <String>[
        ...rewireSchema(),
        "INSERT INTO Habits VALUES (1, 'Monthly', '', '', 1, 2, 1, 0)",
        "INSERT INTO Habits VALUES (2, 'Yearly', '', '', 1, 5, 2, 0)",
      ]);
      await rewire().importHabitsFromFile(periods);
      expect(habitList.getByPosition(0).frequency, Frequency(2, 31),
          reason: 'io.rewire-import#4 schedule 1 with period 1 uses '
              'periods[1] = 31 as the denominator');
      expect(habitList.getByPosition(1).frequency, Frequency(5, 365),
          reason: 'io.rewire-import#4 schedule 1 with period 2 uses '
              'periods[2] = 365 as the denominator');

      habitList = _RecordingHabitList();
      final bogus = buildDatabase('bogus_schedule.db', <String>[
        ...rewireSchema(),
        "INSERT INTO Habits VALUES (1, 'Bogus', '', '1,2', 3, 1, 0, 1)",
      ]);
      await expectLater(() => rewire().importHabitsFromFile(bogus),
          throwsA(isA<StateError>()),
          reason: 'io.rewire-import#4 any other schedule throws '
              'IllegalStateException');
    });

    test('#5 only type 2 checkins are imported, as YYYYMMDD dates', () async {
      final opener = _RecordingOpener();
      await rewire(opener).importHabitsFromFile(fixture('rewire.db'));
      expect(opener.sql, contains(rewireCheckinsSql),
          reason: 'io.rewire-import#5 entries query: select distinct date from '
              'checkins where habit_id=? and type=2');
      final wakeUp = habitList.getByPosition(1);
      expect(wakeUp.name, 'Wake up early',
          reason: 'io.rewire-import#5 sanity check on the fixture layout');
      expect(isChecked(wakeUp, 2016, 1, 18), isTrue,
          reason: "io.rewire-import#5 '20160118' is parsed as year = "
              'substring(0,4), month = substring(4,6), day = substring(6,8) and '
              'added as Entry(LocalDate(y, m, d), Entry.YES_MANUAL)');
      expect(valueAt(wakeUp, 2016, 1, 18), Entry.yesManual,
          reason: 'io.rewire-import#5 each imported checkin is stored as '
              'Entry.YES_MANUAL');
      expect(isChecked(wakeUp, 2015, 12, 31), isFalse,
          reason: 'io.rewire-import#5 the 2015-12-31 row has type 1, so it is '
              'not a check');
      expect(isChecked(wakeUp, 2016, 1, 11), isFalse,
          reason: 'io.rewire-import#5 only type 2 rows count as checks (the '
              '2016-01-11 row has type 1)');
      expect(isChecked(wakeUp, 2016, 1, 13), isFalse,
          reason: 'io.rewire-import#5 only type 2 rows count as checks (the '
              '2016-01-13 row has type 3)');
    });

    test('#6 reminder time is minutes since midnight, bounded to 0 < t < 1440',
        () async {
      final opener = _RecordingOpener();
      await rewire(opener).importHabitsFromFile(fixture('rewire.db'));
      expect(opener.sql, contains(rewireRemindersSql),
          reason: 'io.rewire-import#6 reminder query: select time, active_days '
              'from reminders where habit_id=? limit 1');
      final brush = habitList.getByPosition(2);
      expect(brush.reminder?.hour, 8,
          reason: 'io.rewire-import#6 hour = time / 60 (480 / 60 = 8)');
      expect(brush.reminder?.minute, 0,
          reason: 'io.rewire-import#6 minute = time % 60 (480 % 60 = 0)');
      expect(habitList.getByPosition(1).hasReminder(), isFalse,
          reason: 'io.rewire-import#6 a habit with no row in reminders gets no '
              'reminder');

      habitList = _RecordingHabitList();
      final bounds = buildDatabase('reminder_bounds.db', <String>[
        ...rewireSchema(),
        "INSERT INTO Habits VALUES (1, 'Zero', '', '1', 0, 0, 0, 0)",
        "INSERT INTO Habits VALUES (2, 'Negative', '', '1', 0, 0, 0, 0)",
        "INSERT INTO Habits VALUES (3, 'TooLate', '', '1', 0, 0, 0, 0)",
        "INSERT INTO Habits VALUES (4, 'LastMinute', '', '1', 0, 0, 0, 0)",
        "INSERT INTO REMINDERS VALUES (1, 1, 0, '0')",
        "INSERT INTO REMINDERS VALUES (2, 2, -5, '0')",
        "INSERT INTO REMINDERS VALUES (3, 3, 1440, '0')",
        "INSERT INTO REMINDERS VALUES (4, 4, 1439, '0')",
      ]);
      await rewire().importHabitsFromFile(bounds);
      Habit byName(String name) => habitList.firstWhere((h) => h.name == name);
      expect(byName('Zero').hasReminder(), isFalse,
          reason: 'io.rewire-import#6 a time <= 0 produces no reminder');
      expect(byName('Negative').hasReminder(), isFalse,
          reason: 'io.rewire-import#6 a time <= 0 produces no reminder');
      expect(byName('TooLate').hasReminder(), isFalse,
          reason: 'io.rewire-import#6 a time >= 1440 produces no reminder');
      expect(byName('LastMinute').reminder?.hour, 23,
          reason: 'io.rewire-import#6 hour = time / 60 (1439 / 60 = 23)');
      expect(byName('LastMinute').reminder?.minute, 59,
          reason: 'io.rewire-import#6 minute = time % 60 (1439 % 60 = 59)');
    });

    test('#7 reminder weekdays shift Monday=0 to Sunday=0', () async {
      await rewire().importHabitsFromFile(fixture('rewire.db'));
      final brush = habitList.getByPosition(2);
      expect(brush.name, 'brush teeth',
          reason: 'io.rewire-import#7 sanity check on the fixture layout');
      expect(
          brush.reminder?.days.toArray(),
          <bool>[false, true, true, true, true, true, false],
          reason: "io.rewire-import#7 active_days '0,1,2,3,4' sets index "
              '(d + 1) % 7 for each token, yielding Mon–Fri');
      expect(brush.reminder?.days, WeekdayList.fromArray(
          <bool>[false, true, true, true, true, true, false]),
          reason: 'io.rewire-import#7 Rewire uses Monday = 0 while WeekdayList '
              'uses Sunday = 0');

      habitList = _RecordingHabitList();
      final wrap = buildDatabase('weekday_wrap.db', <String>[
        ...rewireSchema(),
        "INSERT INTO Habits VALUES (1, 'Sunday only', '', '1', 0, 0, 0, 0)",
        "INSERT INTO REMINDERS VALUES (1, 1, 600, '6')",
      ]);
      await rewire().importHabitsFromFile(wrap);
      expect(
          habitList.getByPosition(0).reminder?.days.toArray(),
          <bool>[true, false, false, false, false, false, false],
          reason: "io.rewire-import#7 token '6' (Rewire Sunday) maps to index "
              '(6 + 1) % 7 = 0');
    });

    test('#8 a reminder is assigned and habitList.update(habit) is called',
        () async {
      await rewire().importHabitsFromFile(fixture('rewire.db'));
      expect(habitList.ops.where((op) => op.startsWith('update')).toList(),
          <String>['update:brush teeth'],
          reason: 'io.rewire-import#8 when a reminder is produced it is assigned '
              'to the habit and habitList.update(habit) is called — only '
              "'brush teeth' has a reminder");
      expect(habitList.getByPosition(2).hasReminder(), isTrue,
          reason: 'io.rewire-import#8 the reminder is assigned to the habit');
    });

    test('#9 habits are built by modelFactory and added with habitList.add',
        () async {
      await rewire().importHabitsFromFile(fixture('rewire.db'));
      expect(
          habitList.ops.where((op) => op.startsWith('add')).toList(),
          <String>[
            'add:Wake up early',
            'add:brush teeth',
            'add:Sleep early',
          ],
          reason: 'io.rewire-import#9 habits are added with habitList.add(habit) '
              'in query order, with no Command');
      expect(habitList.every((h) => h is _CountingHabit), isTrue,
          reason: 'io.rewire-import#9 habits are created with '
              'modelFactory.buildHabit()');
    });

    test('#10 rewire.db fixture', () async {
      await rewire().importHabitsFromFile(fixture('rewire.db'));
      expect(habitList.size(), 3,
          reason: 'io.rewire-import#10 rewire.db yields 3 habits');

      final wakeUp = habitList.getByPosition(1);
      expect(wakeUp.name, 'Wake up early',
          reason: "io.rewire-import#10 rewire.db contains 'Wake up early'");
      expect(wakeUp.frequency, Frequency.threeTimesPerWeek,
          reason: "io.rewire-import#10 'Wake up early' (schedule 0, active_days "
              "'1,3,5') has frequency 3/7");
      expect(wakeUp.hasReminder(), isFalse,
          reason: "io.rewire-import#10 'Wake up early' has no reminder");
      expect(isChecked(wakeUp, 2015, 12, 31), isFalse,
          reason: "io.rewire-import#10 'Wake up early' is not checked on "
              '2015-12-31');
      expect(isChecked(wakeUp, 2016, 1, 18), isTrue,
          reason: "io.rewire-import#10 'Wake up early' is checked on 2016-01-18");
      expect(isChecked(wakeUp, 2016, 1, 28), isTrue,
          reason: "io.rewire-import#10 'Wake up early' is checked on 2016-01-28");
      expect(isChecked(wakeUp, 2016, 3, 10), isFalse,
          reason: "io.rewire-import#10 'Wake up early' is not checked on "
              '2016-03-10');

      final brush = habitList.getByPosition(2);
      expect(brush.name, 'brush teeth',
          reason: "io.rewire-import#10 rewire.db contains 'brush teeth'");
      expect(brush.frequency, Frequency.threeTimesPerWeek,
          reason: "io.rewire-import#10 'brush teeth' (schedule 1, days 3, "
              'period 0) has frequency 3/7');
      expect(brush.hasReminder(), isTrue,
          reason: "io.rewire-import#10 'brush teeth' has a reminder");
      expect(brush.reminder!.hour, 8,
          reason: "io.rewire-import#10 'brush teeth' has a reminder at 08:00");
      expect(brush.reminder!.minute, 0,
          reason: "io.rewire-import#10 'brush teeth' has a reminder at 08:00");
      expect(brush.reminder!.days.toArray(),
          <bool>[false, true, true, true, true, true, false],
          reason: "io.rewire-import#10 'brush teeth' fires Mon–Fri");

      final sleep = habitList.getByPosition(0);
      expect(sleep.name, 'Sleep early',
          reason: "io.rewire-import#10 rewire.db contains 'Sleep early'");
      expect(sleep.frequency, Frequency(1, 5),
          reason: "io.rewire-import#10 'Sleep early' (schedule 2, "
              'repeating_count 5) has frequency 1/5');
    });
  });

  // =========================================================================
  // io.tickmate-import
  // =========================================================================

  group('io.tickmate-import', () {
    const tickmateCountSql = "select count(*) from SQLITE_MASTER where "
        "name='tracks' or name='track2groups'";
    const tickmateTracksSql = 'select _id, name, description from tracks';
    const tickmateTicksSql =
        'select distinct year, month, day from ticks where _track_id=?';

    TickmateDBImporter tickmate([DatabaseOpener? opener]) => TickmateDBImporter(
        habitList, modelFactory, opener ?? const Sqlite3DatabaseOpener());

    List<String> tickmateSchema() => <String>[
          'CREATE TABLE tracks (_id INTEGER PRIMARY KEY, name TEXT, description TEXT)',
          'CREATE TABLE track2groups (_id INTEGER PRIMARY KEY)',
          'CREATE TABLE ticks (_id INTEGER PRIMARY KEY, _track_id INTEGER, '
              'year INTEGER, month INTEGER, day INTEGER)',
        ];

    test('#1 canHandle requires a SQLite3 file with tracks and track2groups',
        () async {
      final opener = _RecordingOpener();
      expect(await tickmate(opener).canHandle(fixture('tickmate.db')), isTrue,
          reason: 'io.tickmate-import#1 tickmate.db is a SQLite3 file whose '
              "SQLITE_MASTER holds both 'tracks' and 'track2groups'");
      expect(opener.sql, <String>[tickmateCountSql],
          reason: 'io.tickmate-import#1 canHandle runs exactly '
              "select count(*) from SQLITE_MASTER where name='tracks' or "
              "name='track2groups'");

      expect(await tickmate().canHandle(fixture('rewire.db')), isFalse,
          reason: 'io.tickmate-import#1 a Rewire database has neither tracks '
              'nor track2groups');
      expect(await tickmate().canHandle(fixture('habitbull.csv')), isFalse,
          reason: 'io.tickmate-import#1 canHandle returns false unless '
              'isSQLite3File(file)');
      expect(await tickmate().canHandle(LocalUserFile('${tmp.path}/missing.db')),
          isFalse,
          reason: 'io.tickmate-import#1 a missing file is not a SQLite3 file');

      final onlyTracks = buildDatabase('only_tracks.db',
          <String>['CREATE TABLE tracks (_id INTEGER PRIMARY KEY)']);
      expect(await tickmate().canHandle(onlyTracks), isFalse,
          reason: 'io.tickmate-import#1 returns true only when the count is '
              'exactly 2');

      final uppercase = buildDatabase('uppercase.db', <String>[
        'CREATE TABLE TRACKS (_id INTEGER PRIMARY KEY)',
        'CREATE TABLE TRACK2GROUPS (_id INTEGER PRIMARY KEY)',
      ]);
      expect(await tickmate().canHandle(uppercase), isFalse,
          reason: 'io.tickmate-import#1 the table names are matched in '
              'lowercase, so uppercase tables do not count');
    });

    test('#2 open, BEGIN, create habits, COMMIT, close', () async {
      final opener = _RecordingOpener();
      await tickmate(opener).importHabitsFromFile(fixture('tickmate.db'));
      expect(opener.openCount, 1,
          reason: 'io.tickmate-import#2 importHabitsFromFile opens the file '
              'once');
      expect(opener.events.first, 'open',
          reason: 'io.tickmate-import#2 the file is opened first');
      expect(opener.events[1], 'BEGIN',
          reason: 'io.tickmate-import#2 BEGIN is issued before any habit is '
              'read');
      expect(opener.events[2], tickmateTracksSql,
          reason: 'io.tickmate-import#2 the habits are created inside the '
              'transaction');
      expect(opener.events[opener.events.length - 2], 'COMMIT',
          reason: 'io.tickmate-import#2 COMMIT is issued after the habits are '
              'created');
      expect(opener.events.last, 'close',
          reason: 'io.tickmate-import#2 the database is closed last');
      expect(opener.closeCount, 1,
          reason: 'io.tickmate-import#2 the database is closed exactly once');
    });

    test('#3 habits query, NULL description and daily frequency', () async {
      final opener = _RecordingOpener();
      await tickmate(opener).importHabitsFromFile(fixture('tickmate.db'));
      expect(opener.sql, contains(tickmateTracksSql),
          reason: 'io.tickmate-import#3 habits query: select _id, name, '
              'description from tracks');
      for (final habit in habitList) {
        expect(habit.frequency, Frequency.daily,
            reason: 'io.tickmate-import#3 every imported habit gets frequency = '
                'Frequency.DAILY');
      }
      expect(habitList.getByPosition(2).description, 'Ate no animal products',
          reason: 'io.tickmate-import#3 the description comes from the tracks '
              'table');

      habitList = _RecordingHabitList();
      final nullDesc = buildDatabase('tickmate_null_desc.db', <String>[
        ...tickmateSchema(),
        "INSERT INTO tracks VALUES (1, 'No description', NULL)",
      ]);
      await tickmate().importHabitsFromFile(nullDesc);
      expect(habitList.getByPosition(0).description, '',
          reason: "io.tickmate-import#3 a NULL description becomes ''");
    });

    test('#4 entries query is scoped to the track', () async {
      final opener = _RecordingOpener();
      await tickmate(opener).importHabitsFromFile(fixture('tickmate.db'));
      expect(opener.sql, contains(tickmateTicksSql),
          reason: 'io.tickmate-import#4 entries query: select distinct year, '
              'month, day from ticks where _track_id=?');
      expect(opener.sql.where((s) => s == tickmateTicksSql).length, 3,
          reason: 'io.tickmate-import#4 the entries query runs once per track');

      habitList = _RecordingHabitList();
      final scoped = buildDatabase('tickmate_scoped.db', <String>[
        ...tickmateSchema(),
        "INSERT INTO tracks VALUES (1, 'A', '')",
        "INSERT INTO tracks VALUES (2, 'B', '')",
        'INSERT INTO ticks VALUES (1, 1, 2016, 0, 24)',
        'INSERT INTO ticks VALUES (2, 1, 2016, 0, 24)',
        'INSERT INTO ticks VALUES (3, 2, 2016, 5, 9)',
      ]);
      await tickmate().importHabitsFromFile(scoped);
      final a = habitList.getByPosition(0);
      expect(a.originalEntries.getKnown().length, 1,
          reason: 'io.tickmate-import#4 select distinct collapses the duplicate '
              'tick rows into a single entry');
      expect(isChecked(a, 2016, 6, 9), isFalse,
          reason: "io.tickmate-import#4 the query filters on _track_id, so B's "
              "tick does not reach A");
      expect(isChecked(habitList.getByPosition(1), 2016, 6, 9), isTrue,
          reason: "io.tickmate-import#4 B's own tick is imported into B");
    });

    test('#5 months are 0-based and every tick is YES_MANUAL', () async {
      await tickmate().importHabitsFromFile(fixture('tickmate.db'));
      final vegan = habitList.getByPosition(2);
      expect(vegan.name, 'Vegan',
          reason: 'io.tickmate-import#5 sanity check on the fixture layout');
      expect(valueAt(vegan, 2016, 1, 24), Entry.yesManual,
          reason: 'io.tickmate-import#5 the tick (year 2016, month 0, day 24) '
              'becomes LocalDate(2016, 1, 24) and is stored as Entry.YES_MANUAL');
      expect(valueAt(vegan, 2016, 0 + 1, 25), Entry.yesManual,
          reason: 'io.tickmate-import#5 the entry date is LocalDate(year, month '
              '+ 1, day)');
      expect(
          vegan.originalEntries
              .getKnown()
              .every((e) => e.value == Entry.yesManual),
          isTrue,
          reason: 'io.tickmate-import#5 every tick is stored as '
              'Entry.YES_MANUAL');
      expect(vegan.originalEntries.getKnown().every((e) => e.notes == ''),
          isTrue,
          reason: 'io.tickmate-import#5 Entry(date, Entry.YES_MANUAL) carries no '
              'notes');
    });

    test('#6 habits go straight into the list and no reminders are imported',
        () async {
      await tickmate().importHabitsFromFile(fixture('tickmate.db'));
      expect(habitList.ops,
          <String>['add:Vegan', 'add:Sport', 'add:I love you'],
          reason: 'io.tickmate-import#6 habits are added with '
              'habitList.add(habit) in query order, with no Command');
      expect(habitList.ops.where((op) => op.startsWith('update')), isEmpty,
          reason: 'io.tickmate-import#6 nothing calls update(), because no '
              'reminders are imported');
      expect(habitList.any((h) => h.hasReminder()), isFalse,
          reason: 'io.tickmate-import#6 no reminders are imported');
    });

    test('#7 tickmate.db fixture', () async {
      await tickmate().importHabitsFromFile(fixture('tickmate.db'));
      expect(habitList.size(), 3,
          reason: 'io.tickmate-import#7 tickmate.db holds 3 tracks');
      expect(habitList.map((h) => h.name).toSet(),
          <String>{'Vegan', 'Sport', 'I love you'},
          reason: "io.tickmate-import#7 the 3 tracks are 'Vegan', 'Sport' and "
              "'I love you'");
      final vegan = habitList.getByPosition(2);
      expect(vegan.name, 'Vegan',
          reason: 'io.tickmate-import#7 sanity check on the fixture layout');
      expect(isChecked(vegan, 2016, 1, 24), isTrue,
          reason: "io.tickmate-import#7 'Vegan' is checked on 2016-01-24");
      expect(isChecked(vegan, 2016, 2, 5), isTrue,
          reason: "io.tickmate-import#7 'Vegan' is checked on 2016-02-05");
      expect(isChecked(vegan, 2016, 3, 18), isTrue,
          reason: "io.tickmate-import#7 'Vegan' is checked on 2016-03-18");
      expect(isChecked(vegan, 2016, 3, 14), isFalse,
          reason: "io.tickmate-import#7 'Vegan' is not checked on 2016-03-14");
    });
  });
}
