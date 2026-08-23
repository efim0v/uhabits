/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/io/ImportTest.kt
/// (the dispatch half) and
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/utils/FileExtensionsTest.kt,
/// covering
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/GenericImporter.kt,
/// .../io/AbstractImporter.kt, .../utils/FileExtensions.kt, the `canHandle`
/// half of .../io/LoopDBImporter.kt and
/// uhabits-android/src/main/java/org/isoron/uhabits/tasks/ImportDataTask.kt.
///
/// The three sibling importers (Rewire, Tickmate, HabitBull) and the *import*
/// half of LoopDBImporter belong to other slices, so the fakes below stand in
/// for them; each one reproduces the Kotlin `canHandle` body it replaces,
/// verbatim, and says so.
library;

import 'dart:io';
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/io/abstract_importer.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/generic_importer.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';

import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// An [AbstractImporter] that records every call and claims (or not) whatever
/// it is given. Nothing in `GenericImporter` looks at the concrete type of its
/// importers, so this is the whole surface the dispatcher exercises.
class RecordingImporter extends AbstractImporter {
  RecordingImporter(this.name, {required this.claims, required this.log});

  final String name;
  final List<String> log;
  bool claims;
  Object? throwOnImport;
  int canHandleCount = 0;
  int importCount = 0;

  @override
  Future<bool> canHandle(UserFile file) async {
    canHandleCount++;
    log.add('$name.canHandle');
    return claims;
  }

  @override
  Future<void> importHabitsFromFile(UserFile file) async {
    importCount++;
    log.add('$name.importHabitsFromFile');
    final error = throwOnImport;
    if (error != null) throw error;
  }
}

/// The smallest possible subclass: it supplies exactly the two members
/// `AbstractImporter` declares. It would not compile if the Kotlin class had a
/// third abstract member (io.importer-dispatch#5).
class MinimalImporter extends AbstractImporter {
  @override
  Future<bool> canHandle(UserFile file) async => false;

  @override
  Future<void> importHabitsFromFile(UserFile file) async {}
}

/// Stands in for `RewireDBImporter`/`TickmateDBImporter`, whose `canHandle`
/// bodies are identical up to the two table names:
///
///     if (!isSQLite3File(file)) return false
///     val db = opener.open(file.pathString)
///     val count = db.querySingle("select count(*) from SQLITE_MASTER " +
///         "where name='A' or name='B'") { it.getInt(0) }
///     db.close()
///     return count == 2
class TableGateImporter extends AbstractImporter {
  TableGateImporter(this.opener, this.tableA, this.tableB);

  final DatabaseOpener opener;
  final String tableA;
  final String tableB;

  @override
  Future<bool> canHandle(UserFile file) async {
    if (!await isSQLite3File(file)) return false;
    final db = opener.open(file.pathString);
    final count = db.querySingle(
      "select count(*) from SQLITE_MASTER where name='$tableA' "
      "or name='$tableB'",
      const <String>[],
      (stmt) => stmt.getInt(0),
    );
    db.close();
    return count == 2;
  }

  @override
  Future<void> importHabitsFromFile(UserFile file) async {}
}

/// Stands in for `HabitBullCSVImporter.canHandle`:
///
///     return try {
///         val lines = file.lines()
///         if (lines.isEmpty()) return false
///         lines[0].startsWith("HabitName,HabitDescription,HabitCategory")
///     } catch (e: Exception) { false }
class HabitBullGateImporter extends AbstractImporter {
  @override
  Future<bool> canHandle(UserFile file) async {
    try {
      final lines = await file.lines();
      if (lines.isEmpty) return false;
      return lines[0].startsWith('HabitName,HabitDescription,HabitCategory');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> importHabitsFromFile(UserFile file) async {}
}

/// A [Logging] that keeps every message, so the two `LoopDBImporter` rejection
/// messages and `ImportDataTask`'s failure log can be asserted.
class RecordingLogging implements Logging {
  final Map<String, RecordingLogger> loggers = <String, RecordingLogger>{};

  @override
  Logger getLogger(String name) =>
      loggers.putIfAbsent(name, () => RecordingLogger(name));

  List<Object> errorsOf(String name) => loggers[name]?.errors ?? <Object>[];
}

class RecordingLogger implements Logger {
  RecordingLogger(this.name);

  final String name;
  final List<Object> errors = <Object>[];
  final List<String> infos = <String>[];

  @override
  void debug(String msg) => infos.add(msg);

  @override
  void info(String msg) => infos.add(msg);

  @override
  void error(Object msgOrException, [StackTrace? stackTrace]) =>
      errors.add(msgOrException);
}

/// Wraps a real [Database], recording the SQL that reaches it and how often it
/// was closed.
class RecordingDatabase implements Database {
  RecordingDatabase(this._delegate, this.log);

  final Database _delegate;
  final List<String> log;
  int closeCount = 0;
  bool failOnCommit = false;

  @override
  PreparedStatement prepareStatement(String sql) {
    log.add(sql);
    if (failOnCommit && sql == 'COMMIT') {
      throw const FormatException('commit failed');
    }
    return _delegate.prepareStatement(sql);
  }

  @override
  void close() {
    closeCount++;
    _delegate.close();
  }
}

/// A [DatabaseOpener] that hands out [RecordingDatabase]s over the real
/// sqlite3 opener.
class RecordingOpener implements DatabaseOpener {
  RecordingOpener({this.log});

  static const Sqlite3DatabaseOpener _delegate = Sqlite3DatabaseOpener();

  final List<String>? log;
  final List<RecordingDatabase> opened = <RecordingDatabase>[];

  @override
  Database open(String path) {
    log?.add('open($path)');
    final db = RecordingDatabase(_delegate.open(path), log ?? <String>[]);
    opened.add(db);
    return db;
  }
}

/// A [DatabaseOpener] that must never be reached.
class ExplodingOpener implements DatabaseOpener {
  @override
  Database open(String path) =>
      throw StateError('the database must not be opened: $path');
}

class RecordingListener implements ImportDataTaskListener {
  final List<int> results = <int>[];

  @override
  void onImportDataFinished(int result) => results.add(result);
}

// ---------------------------------------------------------------------------

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('uhabits_importer_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Writes [bytes] to `<tmp>/<name>` and returns it as a [UserFile].
  UserFile writeFile(String name, List<int> bytes) {
    final path = '${tmp.path}/$name';
    File(path).writeAsBytesSync(bytes);
    return LocalUserFile(path);
  }

  UserFile writeText(String name, String content) =>
      writeFile(name, content.codeUnits);

  /// Builds a Loop-shaped backup: the two tables `canHandle` looks for, at the
  /// requested `user_version`.
  UserFile writeLoopDB(
    String name, {
    int userVersion = databaseVersion,
    bool habits = true,
    bool repetitions = true,
  }) {
    final path = '${tmp.path}/$name';
    final db = sqlite.sqlite3.open(path);
    if (habits) {
      db.execute('create table Habits (id integer primary key, name text)');
    }
    if (repetitions) {
      db.execute('create table Repetitions (id integer primary key, '
          'habit integer, timestamp integer, value integer, notes text)');
    }
    db.execute('pragma user_version = $userVersion');
    db.dispose();
    return LocalUserFile(path);
  }

  // -------------------------------------------------------------------------
  // io.importer-dispatch
  // -------------------------------------------------------------------------

  group('io.importer-dispatch', () {
    late List<String> log;
    late RecordingImporter loop;
    late RecordingImporter rewire;
    late RecordingImporter tickmate;
    late RecordingImporter habitBull;
    late GenericImporter importer;
    late UserFile file;

    setUp(() {
      log = <String>[];
      loop = RecordingImporter('loop', claims: false, log: log);
      rewire = RecordingImporter('rewire', claims: false, log: log);
      tickmate = RecordingImporter('tickmate', claims: false, log: log);
      habitBull = RecordingImporter('habitBull', claims: false, log: log);
      importer = GenericImporter(loop, rewire, tickmate, habitBull);
      file = writeText('anything.txt', 'hello');
    });

    test('#1 holds the four importers in order', () {
      expect(importer.importers, <AbstractImporter>[
        loop,
        rewire,
        tickmate,
        habitBull,
      ],
          reason: 'io.importer-dispatch#1 importers is '
              '[LoopDBImporter, RewireDBImporter, TickmateDBImporter, '
              'HabitBullCSVImporter], in that order');
      expect(importer.importers.length, 4,
          reason: 'io.importer-dispatch#1 there are exactly four importers');
      expect(importer, isA<AbstractImporter>(),
          reason: 'io.importer-dispatch#1 GenericImporter is itself an '
              'AbstractImporter');
    });

    test('#2 canHandle returns true at the first importer that claims the file',
        () async {
      tickmate.claims = true;
      expect(await importer.canHandle(file), isTrue,
          reason: 'io.importer-dispatch#2 canHandle returns true as soon as '
              'any importer claims the file');
      expect(log, <String>['loop.canHandle', 'rewire.canHandle',
        'tickmate.canHandle'],
          reason: 'io.importer-dispatch#2 the importers are probed in list '
              'order and the loop returns at the first match, so the fourth '
              'importer is never asked');
      expect(habitBull.canHandleCount, 0,
          reason: 'io.importer-dispatch#2 canHandle short-circuits at the '
              'first importer that returns true');
    });

    test('#2 canHandle returns false only after asking every importer',
        () async {
      expect(await importer.canHandle(file), isFalse,
          reason: 'io.importer-dispatch#2 canHandle returns false when no '
              'importer claims the file');
      expect(log, <String>[
        'loop.canHandle',
        'rewire.canHandle',
        'tickmate.canHandle',
        'habitBull.canHandle',
      ],
          reason: 'io.importer-dispatch#2 every importer is evaluated, in '
              'list order, before returning false');
    });

    test('#3 importHabitsFromFile imports through EVERY matching importer',
        () async {
      loop.claims = true;
      tickmate.claims = true;
      await importer.importHabitsFromFile(file);
      expect(loop.importCount, 1,
          reason: 'io.importer-dispatch#3 the first matching importer imports '
              'the file');
      expect(tickmate.importCount, 1,
          reason: 'io.importer-dispatch#3 the loop does not stop after the '
              'first match, so a file recognised by two importers is imported '
              'twice');
      expect(rewire.importCount, 0,
          reason: 'io.importer-dispatch#3 an importer that does not claim the '
              'file is not asked to import it');
      expect(habitBull.importCount, 0,
          reason: 'io.importer-dispatch#3 an importer that does not claim the '
              'file is not asked to import it');
      expect(log, <String>[
        'loop.canHandle',
        'loop.importHabitsFromFile',
        'rewire.canHandle',
        'tickmate.canHandle',
        'tickmate.importHabitsFromFile',
        'habitBull.canHandle',
      ],
          reason: 'io.importer-dispatch#3 importHabitsFromFile iterates the '
              'same ordered list and imports through each importer that '
              'claims the file');
    });

    test('#4 canHandle is re-evaluated inside importHabitsFromFile', () async {
      loop.claims = true;
      expect(await importer.canHandle(file), isTrue,
          reason: 'io.importer-dispatch#4 the caller probes the file first');
      expect(loop.canHandleCount, 1,
          reason: 'io.importer-dispatch#4 one probe so far');
      await importer.importHabitsFromFile(file);
      expect(loop.canHandleCount, 2,
          reason: 'io.importer-dispatch#4 importHabitsFromFile probes the '
              'file a second time — the file is opened and probed again');
      expect(rewire.canHandleCount, 1,
          reason: 'io.importer-dispatch#4 every importer in the list is '
              're-probed inside importHabitsFromFile — rewire was never asked '
              'during the caller\'s canHandle, which short-circuited at loop, '
              'and is asked once during the import');
    });

    test('#4 the second probe really reopens the file', () async {
      // A LoopDBImporter-shaped gate over a real backup: every probe reads the
      // 16-byte magic and reopens the database.
      final opener = RecordingOpener(log: log);
      final logging = RecordingLogging();
      final backup = writeLoopDB('loop.db', userVersion: 12);
      final gate = _LoopGateImporter(opener, logging);
      final generic = GenericImporter(
        gate,
        RecordingImporter('rewire', claims: false, log: log),
        RecordingImporter('tickmate', claims: false, log: log),
        RecordingImporter('habitBull', claims: false, log: log),
      );
      expect(await generic.canHandle(backup), isTrue,
          reason: 'io.importer-dispatch#4 the Loop backup is claimed');
      expect(opener.opened.length, 1,
          reason: 'io.importer-dispatch#4 canHandle opened the file once');
      await generic.importHabitsFromFile(backup);
      expect(opener.opened.length, 3,
          reason: 'io.importer-dispatch#4 importHabitsFromFile opens and '
              'probes the file a second time (open #2) before opening it '
              'again to import (open #3)');
    });

    test('#5 AbstractImporter declares exactly two members', () async {
      final minimal = MinimalImporter();
      expect(minimal, isA<AbstractImporter>(),
          reason: 'io.importer-dispatch#5 a subclass that supplies only '
              'canHandle and importHabitsFromFile is complete');
      expect(minimal.canHandle(file), isA<Future<bool>>(),
          reason: 'io.importer-dispatch#5 canHandle(file: UserFile): Boolean '
              'is suspend, so the Dart port returns a Future<bool>');
      expect(minimal.importHabitsFromFile(file), isA<Future<void>>(),
          reason: 'io.importer-dispatch#5 importHabitsFromFile(file: UserFile) '
              'is suspend, so the Dart port returns a Future<void>');

      final declared = reflectClass(AbstractImporter)
          .declarations
          .values
          .whereType<MethodMirror>()
          .where((m) => !m.isConstructor && !m.isStatic)
          .map((m) => MirrorSystem.getName(m.simpleName))
          .toSet();
      expect(declared, <String>{'canHandle', 'importHabitsFromFile'},
          reason: 'io.importer-dispatch#5 AbstractImporter defines exactly '
              'two members: canHandle and importHabitsFromFile');
    });

    test('#6 there is no CSV importer for the app\'s own CSV export', () async {
      final opener = RecordingOpener();
      final logging = RecordingLogging();
      final real = GenericImporter(
        _LoopGateImporter(opener, logging),
        TableGateImporter(opener, 'CHECKINS', 'UNIT'),
        TableGateImporter(opener, 'tracks', 'track2groups'),
        HabitBullGateImporter(),
      );

      // Habits.csv, exactly as HabitList.writeCSV() emits it.
      final habitsCsv = writeText(
        'Habits.csv',
        'Position,Name,Type,Question,Description,FrequencyNumerator,'
            'FrequencyDenominator,Color,Unit,Target Type,Target Value,'
            'Archived?\n'
            '001,Wake up early,YES_NO,,,3,7,#FF8F00,,0,0.0,0\n',
      );
      expect(await real.canHandle(habitsCsv), isFalse,
          reason: 'io.importer-dispatch#6 there is no CSV importer for the '
              "app's own CSV export: Habits.csv cannot be imported back");

      final checkmarksCsv = writeText(
        'Checkmarks.csv',
        'Date,Wake up early\n2016-03-14,2\n',
      );
      expect(await real.canHandle(checkmarksCsv), isFalse,
          reason: 'io.importer-dispatch#6 the exported Checkmarks.csv is not '
              'recognised either');

      // Only the .db full backup comes back.
      final backup = writeLoopDB('loop.db', userVersion: 12);
      expect(await real.canHandle(backup), isTrue,
          reason: 'io.importer-dispatch#6 only the .db full backup can be '
              'imported back');

      // The single CSV importer that does exist reads HabitBull's format.
      final habitBullCsv = writeText(
        'habitbull.csv',
        'HabitName,HabitDescription,HabitCategory,CalendarDate,Value,'
            'CommentText\n'
            'Breed dragons,with love and fire,Uncategorized,2016-03-18,1,text\n',
      );
      expect(await real.canHandle(habitBullCsv), isTrue,
          reason: 'io.importer-dispatch#6 the only CSV importer is '
              "HabitBullCSVImporter, which reads HabitBull's format, not the "
              "app's own");
    });
  });

  // -------------------------------------------------------------------------
  // io.sqlite-magic-detection
  // -------------------------------------------------------------------------

  group('io.sqlite-magic-detection', () {
    test('#1 returns false when the file does not exist', () async {
      final missing = LocalUserFile('${tmp.path}/does-not-exist.db');
      expect(await missing.exists(), isFalse,
          reason: 'io.sqlite-magic-detection#1 precondition: the file is '
              'missing');
      expect(await isSQLite3File(missing), isFalse,
          reason: 'io.sqlite-magic-detection#1 isSQLite3File returns false '
              'immediately if file.exists() is false');
    });

    test('#2 reads 16 bytes and matches the 15-character magic', () async {
      final real = writeLoopDB('loop.db', userVersion: 12);
      expect(await isSQLite3File(real), isTrue,
          reason: 'io.sqlite-magic-detection#2 a real SQLite file starts with '
              "'SQLite format 3'");
      expect(await real.readBytes(16), hasLength(16),
          reason: 'io.sqlite-magic-detection#2 the header is read via '
              'file.readBytes(16)');

      final noNul = writeText('nonul.db', 'SQLite format 3');
      expect(await isSQLite3File(noNul), isTrue,
          reason: 'io.sqlite-magic-detection#2 only the 15 characters of '
              "'SQLite format 3' are checked: there is no trailing NUL check");

      final trailing = writeText('trailing.db', 'SQLite format 3xyz');
      expect(await isSQLite3File(trailing), isTrue,
          reason: 'io.sqlite-magic-detection#2 startsWith, so anything may '
              'follow the 15-character magic');

      final version2 = writeText('v2.db', 'SQLite format 2 rest');
      expect(await isSQLite3File(version2), isFalse,
          reason: 'io.sqlite-magic-detection#2 a different magic does not '
              'match');

      final lower = writeText('lower.db', 'sqlite format 3 ');
      expect(await isSQLite3File(lower), isFalse,
          reason: 'io.sqlite-magic-detection#2 the comparison is '
              'case-sensitive');

      final offset = writeText('offset.db', ' SQLite format 3 ');
      expect(await isSQLite3File(offset), isFalse,
          reason: 'io.sqlite-magic-detection#2 the magic must be at offset 0, '
              'because only the first 16 bytes are read');

      final csv = writeText('habits.csv', 'HabitName,HabitDescription,');
      expect(await isSQLite3File(csv), isFalse,
          reason: 'io.sqlite-magic-detection#2 a CSV file is not a SQLite '
              'file');

      // decodeToString() replaces malformed sequences rather than throwing.
      final binary = writeFile('binary.bin',
          Uint8List.fromList(<int>[0xFF, 0xFE, 0x00, 0x80, 0xC3, 0x28]));
      expect(await isSQLite3File(binary), isFalse,
          reason: 'io.sqlite-magic-detection#2 invalid UTF-8 decodes to '
              'replacement characters and simply fails the startsWith check');
    });

    test('#3 is the first gate of the database importers', () async {
      final logging = RecordingLogging();
      final csv = writeText('habits.csv', 'Position,Name,Type,Question\n');
      // LoopDBImporter.canHandle: `if (!isSQLite3File(file)) return false`
      // happens before `opener.open(...)`.
      expect(
          await loopDBCanHandle(csv,
              opener: ExplodingOpener(),
              logger: logging.getLogger(loopDBImporterLoggerName)),
          isFalse,
          reason: 'io.sqlite-magic-detection#3 LoopDBImporter gates on '
              'isSQLite3File, so a non-SQLite file never reaches '
              'SQLiteDatabase.openDatabase');
      expect(logging.errorsOf(loopDBImporterLoggerName), isEmpty,
          reason: 'io.sqlite-magic-detection#3 the early return happens '
              'before any table or version check');

      // RewireDBImporter and TickmateDBImporter open with the same gate.
      final rewire = TableGateImporter(ExplodingOpener(), 'CHECKINS', 'UNIT');
      final tickmate =
          TableGateImporter(ExplodingOpener(), 'tracks', 'track2groups');
      expect(await rewire.canHandle(csv), isFalse,
          reason: 'io.sqlite-magic-detection#3 RewireDBImporter gates on '
              'isSQLite3File before opening the database');
      expect(await tickmate.canHandle(csv), isFalse,
          reason: 'io.sqlite-magic-detection#3 TickmateDBImporter gates on '
              'isSQLite3File before opening the database');
    });

    test('#4 a short file returns false instead of throwing', () async {
      final short = writeText('short.db', 'SQLi');
      expect(await short.readBytes(16), hasLength(4),
          reason: 'io.sqlite-magic-detection#4 readBytes returns only the '
              'available bytes when the file is shorter than the limit');
      expect(await isSQLite3File(short), isFalse,
          reason: 'io.sqlite-magic-detection#4 a short file returns false '
              'rather than throwing');

      final empty = writeText('empty.db', '');
      expect(await empty.readBytes(16), isEmpty,
          reason: 'io.sqlite-magic-detection#4 an empty file reads back an '
              'empty array');
      expect(await isSQLite3File(empty), isFalse,
          reason: 'io.sqlite-magic-detection#4 an empty file returns false '
              'rather than throwing');

      final exact = writeText('exact.db', 'SQLite format 3 ');
      expect(await exact.readBytes(16), hasLength(16),
          reason: 'io.sqlite-magic-detection#4 a 16-byte file reads back all '
              '16 bytes');
      expect(await isSQLite3File(exact), isTrue,
          reason: 'io.sqlite-magic-detection#4 a file exactly as long as the '
              'limit is accepted');
    });
  });

  // -------------------------------------------------------------------------
  // io.loop-db-detection
  // -------------------------------------------------------------------------

  group('io.loop-db-detection', () {
    late RecordingLogging logging;
    late Logger logger;
    late RecordingOpener opener;

    setUp(() {
      logging = RecordingLogging();
      logger = logging.getLogger(loopDBImporterLoggerName);
      opener = RecordingOpener();
    });

    List<Object> errors() => logging.errorsOf(loopDBImporterLoggerName);

    test('#1 rejects a non-SQLite file without opening it', () async {
      final txt = writeText('notes.txt', 'not a database at all');
      expect(
          await loopDBCanHandle(txt,
              opener: ExplodingOpener(), logger: logger),
          isFalse,
          reason: 'io.loop-db-detection#1 canHandle returns false immediately '
              'if isSQLite3File(file) is false');
      expect(errors(), isEmpty,
          reason: 'io.loop-db-detection#1 the early return logs nothing');

      final missing = LocalUserFile('${tmp.path}/missing.db');
      expect(
          await loopDBCanHandle(missing,
              opener: ExplodingOpener(), logger: logger),
          isFalse,
          reason: 'io.loop-db-detection#1 a missing file is not a SQLite '
              'file either');
    });

    test('#2 requires both Habits and Repetitions', () async {
      final both = writeLoopDB('both.db');
      expect(await loopDBCanHandle(both, opener: opener, logger: logger),
          isTrue,
          reason: 'io.loop-db-detection#2 the count of SQLITE_MASTER rows '
              "named 'Habits' or 'Repetitions' is exactly 2");
      expect(errors(), isEmpty,
          reason: 'io.loop-db-detection#2 an accepted file logs nothing');

      final onlyHabits = writeLoopDB('habits.db', repetitions: false);
      expect(
          await loopDBCanHandle(onlyHabits, opener: opener, logger: logger),
          isFalse,
          reason: 'io.loop-db-detection#2 a count of 1 rejects the file');
      expect(errors(), contains(cannotHandleFileTablesNotFound),
          reason: "io.loop-db-detection#2 it logs 'Cannot handle file: "
              "tables not found'");

      final onlyRepetitions = writeLoopDB('reps.db', habits: false);
      expect(
          await loopDBCanHandle(onlyRepetitions,
              opener: opener, logger: logger),
          isFalse,
          reason: 'io.loop-db-detection#2 the other half alone is rejected '
              'too');

      final neither = writeLoopDB('empty.db',
          habits: false, repetitions: false);
      expect(
          await loopDBCanHandle(neither, opener: opener, logger: logger),
          isFalse,
          reason: 'io.loop-db-detection#2 a SQLite file with neither table is '
              'rejected');
    });

    test('#3 rejects a schema newer than DATABASE_VERSION', () async {
      expect(databaseVersion, 25,
          reason: 'io.loop-db-detection#3 DATABASE_VERSION is currently 25');

      final newer = writeLoopDB('newer.db', userVersion: 26);
      expect(await loopDBCanHandle(newer, opener: opener, logger: logger),
          isFalse,
          reason: 'io.loop-db-detection#3 a user_version greater than '
              'DATABASE_VERSION is rejected');
      expect(errors(), contains(incompatibleVersionMessage(26, 25)),
          reason: "io.loop-db-detection#3 it logs 'Cannot handle file: "
              "incompatible version: 26 > 25'");
      expect(incompatibleVersionMessage(26, 25),
          'Cannot handle file: incompatible version: 26 > 25',
          reason: 'io.loop-db-detection#3 the message is built from the '
              "file's version and DATABASE_VERSION");

      final same = writeLoopDB('same.db', userVersion: 25);
      expect(await loopDBCanHandle(same, opener: opener, logger: logger),
          isTrue,
          reason: 'io.loop-db-detection#3 a version equal to 25 is accepted');

      final older = writeLoopDB('older.db', userVersion: 24);
      expect(await loopDBCanHandle(older, opener: opener, logger: logger),
          isTrue,
          reason: 'io.loop-db-detection#3 a version lower than 25 is '
              'accepted');
    });

    test('#4 both checks run and the database is always closed', () async {
      final bad = writeLoopDB('bad.db', userVersion: 26, repetitions: false);
      expect(await loopDBCanHandle(bad, opener: opener, logger: logger),
          isFalse,
          reason: 'io.loop-db-detection#4 a file that fails both checks is '
              'rejected');
      expect(errors(), <Object>[
        cannotHandleFileTablesNotFound,
        incompatibleVersionMessage(26, 25),
      ],
          reason: 'io.loop-db-detection#4 the version check runs even when '
              'the table check already failed, so both messages are logged');
      expect(opener.opened.single.closeCount, 1,
          reason: 'io.loop-db-detection#4 the database is closed before '
              'returning, on the rejection path');

      final good = writeLoopDB('good.db', userVersion: 12);
      final goodOpener = RecordingOpener();
      expect(
          await loopDBCanHandle(good, opener: goodOpener, logger: logger),
          isTrue,
          reason: 'io.loop-db-detection#4 an acceptable file is accepted');
      expect(goodOpener.opened.single.closeCount, 1,
          reason: 'io.loop-db-detection#4 the database is closed before '
              'returning, on the acceptance path too');
    });

    test('#5 accepts a backup at an older schema version', () async {
      final old = writeLoopDB('loop.db', userVersion: 12);
      final db = opener.open(old.pathString);
      expect(db.getVersion(), 12,
          reason: 'io.loop-db-detection#5 the loop.db fixture is at '
              'user_version 12');
      db.close();
      expect(await loopDBCanHandle(old, opener: opener, logger: logger),
          isTrue,
          reason: 'io.loop-db-detection#5 a Loop backup at an older schema '
              'version IS accepted (it is migrated during import)');
      expect(errors(), isEmpty,
          reason: 'io.loop-db-detection#5 an old but compatible backup is not '
              'rejected');

      // The real Kotlin fixture, when the JVM sources are next to this
      // package: uhabits-core/assets/test/loop.db.
      final fixture = File('../../../uhabits-core/assets/test/loop.db');
      if (fixture.existsSync()) {
        final copyPath = '${tmp.path}/fixture-loop.db';
        fixture.copySync(copyPath);
        final copy = LocalUserFile(copyPath);
        final fixtureDb = opener.open(copyPath);
        expect(fixtureDb.getVersion(), 12,
            reason: 'io.loop-db-detection#5 the test fixture loop.db has '
                'user_version = 12');
        fixtureDb.close();
        expect(
            await loopDBCanHandle(copy, opener: opener, logger: logger),
            isTrue,
            reason: 'io.loop-db-detection#5 the loop.db fixture is accepted '
                'by LoopDBImporter.canHandle');
      }
    });
  });

  // -------------------------------------------------------------------------
  // io.import-task
  // -------------------------------------------------------------------------

  group('io.import-task', () {
    late List<String> sql;
    late RecordingDatabase database;
    late SQLModelFactory modelFactory;
    late List<String> log;
    late RecordingImporter loop;
    late GenericImporter importer;
    late RecordingLogging logging;
    late RecordingListener listener;
    late UserFile file;

    setUp(() {
      sql = <String>[];
      log = <String>[];
      database = RecordingDatabase(openMigratedDatabase(), sql);
      modelFactory = SQLModelFactory(database);
      loop = RecordingImporter('loop', claims: false, log: log);
      importer = GenericImporter(
        loop,
        RecordingImporter('rewire', claims: false, log: log),
        RecordingImporter('tickmate', claims: false, log: log),
        RecordingImporter('habitBull', claims: false, log: log),
      );
      logging = RecordingLogging();
      listener = RecordingListener();
      file = writeText('backup.db', 'whatever');
      sql.clear();
    });

    tearDown(() {
      database.close();
    });

    ImportDataTask buildTask() => ImportDataTask(
          importer,
          modelFactory,
          file,
          listener,
          logging: logging,
        );

    test('#1 wraps the import in a transaction on the app database', () async {
      loop.claims = true;
      final task = buildTask();
      await task.doInBackground();
      expect(sql.where((s) => s == 'BEGIN' || s == 'COMMIT').toList(),
          <String>['BEGIN', 'COMMIT'],
          reason: 'io.import-task#1 database.begin() runs before the import '
              'and commit() after it');
      expect(log, <String>[
        'loop.canHandle',
        'loop.canHandle',
        'loop.importHabitsFromFile',
        'rewire.canHandle',
        'tickmate.canHandle',
        'habitBull.canHandle',
      ],
          reason: 'io.import-task#1 the whole import — the task\'s own '
              'canHandle probe and the dispatcher\'s second pass over all '
              'four importers — happens between begin() and commit()');
      expect(sql.indexOf('BEGIN') < sql.indexOf('COMMIT'), isTrue,
          reason: 'io.import-task#1 BEGIN comes first, COMMIT last');
    });

    test('#2 result constants are SUCCESS=1, NOT_RECOGNIZED=2, FAILED=3', () {
      expect(ImportDataTask.success, 1,
          reason: 'io.import-task#2 SUCCESS = 1');
      expect(ImportDataTask.notRecognized, 2,
          reason: 'io.import-task#2 NOT_RECOGNIZED = 2');
      expect(ImportDataTask.failed, 3,
          reason: 'io.import-task#2 FAILED = 3');
    });

    test('#3 a recognised file imports, succeeds and commits', () async {
      loop.claims = true;
      final task = buildTask();
      await task.doInBackground();
      task.onPostExecute();
      expect(loop.importCount, 1,
          reason: 'io.import-task#3 importHabitsFromFile runs when '
              'canHandle(file) is true');
      expect(listener.results, <int>[ImportDataTask.success],
          reason: 'io.import-task#3 result = SUCCESS (1)');
      expect(sql, contains('COMMIT'),
          reason: 'io.import-task#3 the transaction is committed');
    });

    test('#4 an unrecognised file is NOT_RECOGNIZED and still commits',
        () async {
      final task = buildTask();
      await task.doInBackground();
      task.onPostExecute();
      expect(loop.importCount, 0,
          reason: 'io.import-task#4 nothing is imported when canHandle is '
              'false');
      expect(listener.results, <int>[ImportDataTask.notRecognized],
          reason: 'io.import-task#4 result = NOT_RECOGNIZED (2)');
      expect(sql, contains('COMMIT'),
          reason: 'io.import-task#4 the transaction is still committed');
      expect(sql, isNot(contains('ROLLBACK')),
          reason: 'io.import-task#4 there is no rollback');
    });

    test('#5 a failing import is FAILED, logged, and still committed',
        () async {
      loop.claims = true;
      loop.throwOnImport = const FormatException('boom');
      final task = buildTask();
      await task.doInBackground();
      task.onPostExecute();
      expect(listener.results, <int>[ImportDataTask.failed],
          reason: 'io.import-task#5 result = FAILED (3) when an Exception '
              'escapes');
      expect(logging.errorsOf(importDataTaskLoggerName),
          contains(importFailedMessage),
          reason: "io.import-task#5 the exception is logged as "
              "'ImportDataTask'/'Import failed'");
      expect(logging.errorsOf(importDataTaskLoggerName),
          contains(const FormatException('boom')),
          reason: 'io.import-task#5 the exception itself is logged too');
      expect(sql, contains('COMMIT'),
          reason: 'io.import-task#5 commit() is attempted again so the '
              'transaction is always closed — the partial import is '
              'COMMITTED, not rolled back');
      expect(sql, isNot(contains('ROLLBACK')),
          reason: 'io.import-task#5 the partial import is COMMITTED, not '
              'rolled back');
    });

    test('#5 a commit that itself fails is swallowed', () async {
      loop.claims = true;
      database.failOnCommit = true;
      final task = buildTask();
      await task.doInBackground();
      task.onPostExecute();
      expect(listener.results, <int>[ImportDataTask.failed],
          reason: 'io.import-task#5 a commit failure is an Exception like any '
              'other: result = FAILED (3)');
      expect(sql.where((s) => s == 'COMMIT').length, 2,
          reason: 'io.import-task#5 commit() is attempted again inside a '
              'nested try/catch');
      database.failOnCommit = false;
    });

    test('#6 onPostExecute always reports the result', () async {
      // NOT_RECOGNIZED
      final unrecognised = buildTask();
      await unrecognised.doInBackground();
      unrecognised.onPostExecute();
      expect(listener.results, <int>[ImportDataTask.notRecognized],
          reason: 'io.import-task#6 onPostExecute calls '
              'listener.onImportDataFinished(result)');

      // SUCCESS
      loop.claims = true;
      final ok = buildTask();
      await ok.doInBackground();
      ok.onPostExecute();
      expect(listener.results.last, ImportDataTask.success,
          reason: 'io.import-task#6 onPostExecute reports SUCCESS too');

      // FAILED
      loop.throwOnImport = const FormatException('boom');
      final failing = buildTask();
      await failing.doInBackground();
      failing.onPostExecute();
      expect(listener.results.last, ImportDataTask.failed,
          reason: 'io.import-task#6 onPostExecute reports FAILED too');
      expect(listener.results, hasLength(3),
          reason: 'io.import-task#6 every task reports exactly once');
    });

    test('#7 a non-SQL model factory throws at construction', () {
      expect(
          () => ImportDataTask(
                importer,
                MemoryModelFactory(),
                file,
                listener,
                logging: logging,
              ),
          throwsA(isA<TypeError>()),
          reason: 'io.import-task#7 the task casts the injected ModelFactory '
              'to SQLModelFactory, so a non-SQL model factory throws '
              'ClassCastException at construction');
      expect(buildTask(), isA<ImportDataTask>(),
          reason: 'io.import-task#7 an SQLModelFactory is accepted and its '
              'database is the one the transaction runs on');
    });
  });
}

/// `LoopDBImporter` minus the import half, which belongs to the
/// io.loop-db-migration slice: `canHandle` delegates to [loopDBCanHandle],
/// exactly as the Kotlin class body does.
class _LoopGateImporter extends AbstractImporter {
  _LoopGateImporter(this.opener, Logging logging)
      : logger = logging.getLogger(loopDBImporterLoggerName);

  final DatabaseOpener opener;
  final Logger logger;

  @override
  Future<bool> canHandle(UserFile file) =>
      loopDBCanHandle(file, opener: opener, logger: logger);

  @override
  Future<void> importHabitsFromFile(UserFile file) async {
    // The real body migrates and reads the backup; all this stand-in needs is
    // to open the file a second time, which is what rule #4 observes.
    final db = opener.open(file.pathString);
    db.close();
  }
}
