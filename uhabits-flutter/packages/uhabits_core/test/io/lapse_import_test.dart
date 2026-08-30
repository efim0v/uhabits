/// What a restored backup does with an abstinence habit's journal of lapses.
///
/// A backup is a byte-for-byte copy of the database, so the `Lapses` rows are
/// always inside the file. What loses them is the restore: habits are matched
/// by uuid and handed whatever id this device has free, while every lapse is
/// filed under the id the other device used. Without this the restored habit
/// comes back with its commitment day and an empty history behind it — which
/// reads as a clean run since the day it was made, and is the most flattering
/// possible lie.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/computed/lapse_importer.dart';
import 'package:uhabits_core/src/computed/lapse_repository.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/io/loop_db_importer.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import 'loop_db_importer_sleep_test.dart' show makeDatabaseFile;
import 'loop_db_importer_test.dart' show assetsFileOpener;

void main() {
  setUp(() => setToday(LocalDate.ymd(2016, 3, 20)));
  tearDown(resetToday);

  const Sqlite3DatabaseOpener opener = Sqlite3DatabaseOpener();

  late Database hereDb;
  late HabitList here;

  setUp(() {
    final (Database db, _) = makeDatabaseFile('uhabits_lapse_dest');
    hereDb = db;
    here = SQLModelFactory(hereDb).buildHabitList();
  });

  tearDown(() => hereDb.close());

  /// A file holding one habit, written under an id this device does not use.
  ///
  /// The id is spelled out rather than taken from an autoincrement: the whole
  /// question is what happens to rows filed under the *other* device's id, and
  /// a source that happened to agree with this device would answer it by luck.
  UserFile sourceFileWithHabit({required String uuid, required int sourceId}) {
    final (Database source, String path) = makeDatabaseFile('uhabits_lapse_src');
    source.run(
      'insert into Habits (id, name, uuid, description, question, freq_num, '
      'freq_den, color, position, archived, highlight, type, target_value, '
      'target_type, unit) values '
      "($sourceId, 'Sober', '$uuid', '', '', 1, 1, 0, 0, 0, 0, 1, 0, 1, '')",
    );
    source.close();
    return LocalUserFile(path);
  }

  LoopDBImporter buildImporter({required LapseImporter? lapseImporter}) =>
      LoopDBImporter(
        habitList: here,
        modelFactory: SQLModelFactory(hereDb),
        opener: opener,
        runner: CommandRunner(CoroutineTaskRunner(
          mainDispatcher: const UnconfinedTestDispatcher(),
          ioDispatcher: const UnconfinedTestDispatcher(),
        )),
        logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        fileOpener: assetsFileOpener(),
        lapseImporter: lapseImporter,
      );

  Future<void> importFile(UserFile file) =>
      buildImporter(lapseImporter: LapseImporter(LapseRepository(hereDb)))
          .importHabitsFromFile(file);

  /// Runs [import] and hands back what it threw, or null.
  ///
  /// Caught rather than left to escape: an escaping throw fails the test with
  /// a stack trace instead of through an assertion, and `completes` does not
  /// help — it rethrows the error rather than reporting a mismatch. "The
  /// import does not throw" is the whole of what two of the tests below
  /// assert, so it has to be a value something is asserted about.
  Future<Object?> thrownBy(Future<void> Function() import) async {
    try {
      await import();
      return null;
    } on Object catch (error) {
      return error;
    }
  }

  test('a restored habit comes back with its journal', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source)
      ..save(41, 8990, amount: 1)
      ..save(41, 8997, amount: 3);
    source.close();

    await importFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(restored.id, isNot(41),
        reason: 'the check is only worth making if the ids differ');
    expect(LapseRepository(hereDb).range(restored.id!, 8990, 8997),
        <int, int>{8990: 1, 8997: 3},
        reason: 'computed.backup#4');
  });

  test('the amount travels, not just the day', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source).save(41, 8990, amount: 30);
    source.close();

    await importFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).range(restored.id!, 8990, 8990)[8990], 30,
        reason: 'computed.backup#4 — «не более 30 минут» есть допуск, и '
            'потерянная величина превращает срыв в другой срыв');
  });

  test('a habit with no journal is answered silently', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);

    // The load-bearing assertion is that nothing was thrown, not the
    // emptiness below it: an empty journal stays empty however badly the
    // importer is written, while the ends of a journal that has none are two
    // nulls, and reaching for the days between them is how it throws.
    expect(await thrownBy(() => importFile(file)), isNull,
        reason: 'computed.backup#4 — это почти каждая привычка');

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).firstDay(restored.id!), isNull,
        reason: 'computed.backup#4 — a habit with no journal gains none');
  });

  test('an importer with no journal to write to behaves as upstream',
      () async {
    // Null вместо сотрудника — это каждый тест импорта, написанный до этой
    // задачи, и они обязаны продолжать проходить без правки.
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source).save(41, 8990, amount: 1);
    source.close();

    expect(
        await thrownBy(() =>
            buildImporter(lapseImporter: null).importHabitsFromFile(file)),
        isNull,
        reason: 'computed.backup#4 — the employee is optional');

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).firstDay(restored.id!), isNull,
        reason: 'computed.backup#4 — and an absent one writes nothing');
  });

  /// A file whose journal holds a row that says nothing.
  ///
  /// Written through raw SQL because [LapseRepository.save] refuses it: a zero
  /// is the trace of another build or of a file edited by hand, never of this
  /// one. Real days on both sides of it, so that "the rest of the journal
  /// survives" has something to be true of.
  UserFile sourceFileWithASilentDay({required String uuid}) {
    final UserFile file = sourceFileWithHabit(uuid: uuid, sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source)
      ..save(41, 8990, amount: 1)
      ..save(41, 9007, amount: 12);
    source.run('insert into Lapses (habit, day, amount) values (41, 9000, 0)');
    source.close();
    return file;
  }

  test('a zero in the file does not tear the restore down', () async {
    final UserFile file = sourceFileWithASilentDay(uuid: 'abc');

    expect(await thrownBy(() => importFile(file)), isNull,
        reason: 'computed.backup#4 — импорт ловит бросок и всё равно '
            'фиксирует сделанное: восстановление разваливается посередине, '
            'а не откатывается');
  });

  test('a day that says nothing is skipped, and the days after it are not',
      () async {
    final UserFile file = sourceFileWithASilentDay(uuid: 'abc');

    // Брошенное здесь проглочено намеренно: что бросок сносит восстановление,
    // сказано тестом выше, а этот — о том, что осталось в журнале, и он
    // обязан дойти до своей проверки.
    await thrownBy(() => importFile(file));

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).range(restored.id!, 8990, 9007),
        <int, int>{8990: 1, 9007: 12},
        reason: 'computed.backup#4 — день, который ничего не утверждает, '
            'отсутствующей строкой и представлен; а дни после него — срывы, '
            'и они переезжают');
  });

  test('a restored lapse keeps the moment it happened', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source).save(41, 8990, amount: 1, atMillis: 1724832000000);
    source.close();

    await importFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).momentOf(restored.id!, 8990), 1724832000000,
        reason: 'computed.backup#6 — момент едет вместе со срывом, иначе '
            'после восстановления счётчик начал бы с полуночи');
  });

  test('a lapse with no moment restores without one', () async {
    final UserFile file = sourceFileWithHabit(uuid: 'abc', sourceId: 41);
    final Database source = opener.open(file.pathString);
    LapseRepository(source).save(41, 8990, amount: 1);
    source.close();

    await importFile(file);

    final Habit restored = here.getByUUID('abc')!;
    expect(LapseRepository(hereDb).momentOf(restored.id!, 8990), isNull,
        reason: 'computed.backup#6 — пустота переносится пустотой, а не '
            'выдумывается на месте');
  });
}
