/// What a restored backup does with a computed habit's definition.
///
/// A backup is a byte-for-byte copy of the database, so a habit's definition
/// row is always inside the file. What loses it is the restore: habits are
/// matched by uuid and handed whatever id this device has free, while the
/// definition is filed under the id the other device used. Without this a
/// restored computed habit comes back an ordinary one.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/computed/definition_importer.dart';
import 'package:uhabits_core/src/computed/definition_repository.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
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

  late Database destination;
  late HabitList destinationList;
  late DefinitionRepository here;

  setUp(() {
    final (Database db, _) = makeDatabaseFile('uhabits_definition_dest');
    destination = db;
    destinationList = SQLModelFactory(destination).buildHabitList();
    here = DefinitionRepository(destination);
  });

  tearDown(() => destination.close());

  /// A file holding one computed habit and its definition.
  UserFile backupWithDefinition({
    required String uuid,
    // Deliberately several: the whole point is that the habit's id in the
    // file is not the id it will be given here.
    int decoys = 3,
  }) {
    final (Database source, String path) =
        makeDatabaseFile('uhabits_definition_src');
    final HabitList list = SQLModelFactory(source).buildHabitList();
    final SQLModelFactory factory = SQLModelFactory(source);
    for (int i = 0; i < decoys; i++) {
      list.add(factory.buildHabit()..name = 'Other $i');
    }
    final Habit habit = factory.buildHabit()
      ..name = 'Abstinence'
      ..uuid = uuid;
    list.add(habit);

    final DefinitionRepository there = DefinitionRepository(source);
    there.save(
      habit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8990,
      ),
    );
    source.close();
    return LocalUserFile(path);
  }

  Future<void> importFile(UserFile file, {DefinitionImporter? definitions}) =>
      LoopDBImporter(
        habitList: destinationList,
        modelFactory: SQLModelFactory(destination),
        opener: const Sqlite3DatabaseOpener(),
        runner: CommandRunner(CoroutineTaskRunner(
          mainDispatcher: const UnconfinedTestDispatcher(),
          ioDispatcher: const UnconfinedTestDispatcher(),
        )),
        logging: StandardLogging(out: StringBuffer(), err: StringBuffer()),
        fileOpener: assetsFileOpener(),
        definitionImporter: definitions ?? DefinitionImporter(here),
      ).importHabitsFromFile(file);

  test('a definition comes across onto the id this device gave it', () async {
    // This device is not empty: the restored habit takes the next id free
    // here, which is not the id it had in the file.
    final SQLModelFactory factory = SQLModelFactory(destination);
    for (int i = 0; i < 5; i++) {
      destinationList.add(factory.buildHabit()..name = 'Mine $i');
    }
    final UserFile file = backupWithDefinition(uuid: 'abst-uuid');
    final int idInFile = const Sqlite3DatabaseOpener()
        .open(file.pathString)
        .querySingle<int>(
          'select habit from HabitDefinitions',
          const <String>[],
          (stmt) => stmt.getInt(0),
        )!;

    await importFile(file);

    final Habit habit = destinationList.getByUUID('abst-uuid')!;
    expect(habit.id, isNot(idInFile),
        reason: 'the check is only worth making if the ids differ');
    expect(here.forHabit(habit.id!)?.kind, ComputedKind.abstinence,
        reason: 'computed.backup#1');
    expect(here.forHabit(habit.id!)?.committedFrom, 8990,
        reason:
            'computed.backup#2 — the day of the commitment travels with it');
  });

  test('a habit with no definition gains none', () async {
    final UserFile file = backupWithDefinition(uuid: 'abst-uuid');
    await importFile(file);

    for (final Habit habit in destinationList) {
      if (habit.uuid == 'abst-uuid') continue;
      expect(here.forHabit(habit.id!), isNull, reason: 'computed.backup#1');
    }
  });
}
