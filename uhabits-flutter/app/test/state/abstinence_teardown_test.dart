/// `computed.lifecycle#6`, `#7` — что остаётся от привычки-воздержания после
/// удаления, и что обязано остаться после архивации.
///
/// На настоящем файле, а не на `Sqlite3Database.memory()`: каскад держится на
/// `pragma foreign_keys`, а это настройка соединения, и вопрос стоит ровно к
/// тому соединению, которое открывает приложение
/// (см. `app/test/platform/first_run_foreign_keys_test.dart`).
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database database;
  late AppScope scope;

  setUp(() {
    setToday(LocalDate(9000));
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_gone');
    database = AppDatabase.openAndMigrate('${tempDir.path}/habits.db');
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    scope.preferences.isFirstRun = false;
  });

  tearDown(() {
    scope.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    resetToday();
  });

  Habit abstinenceHabit() {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'No smoking'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0
      ..unit = '';
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8960,
        payload: <String, Object?>{'allowance': 30.0, 'unit': 'minutes'},
      ),
    );
    scope.lapses.save(habit.id!, 8990, amount: 45);
    habit.originalEntries.add(Entry(LocalDate(8990), 500000));
    habit.recompute();
    return habit;
  }

  /// Every table in this file that files rows under a habit id.
  ///
  /// Asked of the schema rather than listed by hand: a kind added later brings
  /// a table of its own, and a hand-written list is a list that will not have
  /// been updated.
  List<String> tablesKeyedByHabit() {
    final List<String> tables = <String>[];
    database.query(
      "select name from sqlite_master where type = 'table' "
      "and name not like 'sqlite_%'",
      const <String>[],
      (stmt) => tables.add(stmt.getText(0)),
    );
    return tables.where((String table) {
      var found = false;
      database.query('pragma table_info($table)', const <String>[], (stmt) {
        if (stmt.getText(1).toLowerCase() == 'habit') found = true;
      });
      return found;
    }).toList();
  }

  List<String> tablesStillHolding(int habitId) => tablesKeyedByHabit()
      .where((String table) =>
          database.queryInt('select count(*) from $table where habit = $habitId') >
          0)
      .toList();

  test('the file has more than one table keyed by habit', () {
    // Guards the guard: a query that finds nothing to look at passes every
    // assertion below without asking anything.
    expect(tablesKeyedByHabit(),
        containsAll(<String>['Repetitions', 'HabitDefinitions', 'Lapses']),
        reason: 'computed.lifecycle#6');
  });

  test('deleting one leaves no row anywhere', () {
    final Habit habit = abstinenceHabit();
    final int id = habit.id!;
    expect(tablesStillHolding(id), isNotEmpty,
        reason: 'computed.lifecycle#6 — there has to be something to lose');

    scope.habitList.remove(habit);

    expect(tablesStillHolding(id), isEmpty,
        reason: 'computed.lifecycle#6 — a row left behind is a row the next '
            'habit at this id would inherit');
    expect(database.queryInt('select count(*) from Habits where id = $id'), 0,
        reason: 'computed.lifecycle#6');
  });

  test('and nothing of it is kept in preferences under its id', () {
    // The kind's parameters live in `HabitDefinitions.payload` and its lapses
    // in `Lapses`, both on the cascade. A preferences key would outlive the
    // habit, the restore and the reinstall, and nothing would ever collect it.
    final Habit habit = abstinenceHabit();
    final int id = habit.id!;
    scope.habitList.remove(habit);

    for (final String key in <String>[
      'abstinence.allowance.$id',
      'abstinence.committedFrom.$id',
      'abstinence.promptDismissed.$id',
    ]) {
      expect(scope.preferencesStorage.getString(key, ''), '',
          reason: 'computed.lifecycle#6 — the kind keeps nothing in '
              'preferences keyed by habit id');
    }
  });

  test('archiving keeps everything, and un-archiving gives it all back', () {
    final Habit habit = abstinenceHabit();
    final int id = habit.id!;

    habit.isArchived = true;
    scope.habitList.update(<Habit>[habit]);

    expect(scope.lapses.range(id, 8990, 8990), <int, int>{8990: 45},
        reason: 'computed.lifecycle#7 — archiving is reversible, so it '
            'destroys nothing');
    expect(scope.definitions.forHabit(id)?.committedFrom, 8960,
        reason: 'computed.lifecycle#7');

    habit.isArchived = false;
    scope.habitList.update(<Habit>[habit]);

    expect(scope.definitions.forHabit(id)?.payload['allowance'], 30.0,
        reason: 'computed.lifecycle#7 — the day of the commitment and the '
            'allowance come back with it, or forty clean days did not happen');
  });
}
