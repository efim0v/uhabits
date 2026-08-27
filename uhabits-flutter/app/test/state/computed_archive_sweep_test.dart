/// `computed.lifecycle#4` — какие привычки вид вообще сводит.
///
/// Перечисление идёт по метке, а не по боковой таблице вида: у воздержания
/// боковой таблицы вроде `SleepGoals` нет, и цикл, написанный вокруг неё,
/// второму виду не достаётся. Фильтры — архив и исчезнувшая привычка — стоят
/// здесь, а не в каждом своде: правило, размазанное по видам, будет отнесено к
/// одним и не отнесено к другим.
library;

// Core models are reached by their `src` path, exactly as lib/state does.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Database database;
  late AppScope scope;

  setUp(() {
    setToday(LocalDate(9000));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    scope.preferences.isFirstRun = false;
  });

  tearDown(() {
    scope.close();
    resetToday();
  });

  Habit addHabit(String name) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = HabitType.numerical
      ..targetValue = 100
      ..unit = '%';
    scope.habitList.add(habit);
    return habit;
  }

  List<String> namesOf(ComputedKind kind) =>
      scope.computedHabits(kind).map((Habit h) => h.name).toList();

  test('a habit with the mark is enumerated', () {
    final Habit habit = addHabit('Sleep');
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));

    expect(namesOf(ComputedKind.sleep), <String>['Sleep'],
        reason: 'computed.lifecycle#4');
  });

  test('a habit with a goal but no mark is not', () {
    // The mark is what makes a habit computed (`computed.definition#1`), so it
    // is also what says which sweep a habit belongs to. Enumerating out of
    // SleepGoals answers this one yes.
    final Habit habit = addHabit('Sleep');
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));

    expect(namesOf(ComputedKind.sleep), isEmpty,
        reason: 'computed.lifecycle#4');
  });

  test('an archived habit is not swept', () {
    final Habit habit = addHabit('Sleep');
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    habit.isArchived = true;
    scope.habitList.update(<Habit>[habit]);

    expect(namesOf(ComputedKind.sleep), isEmpty,
        reason: 'computed.lifecycle#4 — reading a platform for a habit the '
            'person put away is work nobody asked for');
  });

  test('another kind is not swept by this one', () {
    final Habit sleep = addHabit('Sleep');
    scope.definitions
        .save(sleep.id!, const HabitDefinition(kind: ComputedKind.sleep));
    final Habit quit = addHabit('No smoking');
    scope.definitions.save(
      quit.id!,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 9000,
      ),
    );

    expect(namesOf(ComputedKind.sleep), <String>['Sleep'],
        reason: 'computed.lifecycle#4');
    expect(namesOf(ComputedKind.abstinence), <String>['No smoking'],
        reason: 'computed.lifecycle#4');
  });

  test('a mark whose habit is gone is skipped rather than crashed on', () {
    // The row goes with the habit on the cascade, so this is the shape of a
    // race rather than of a leak, and the race has to be staged as one: the
    // ids are read once, at the first step, and the habit disappears before
    // the loop reaches it. Deleting before the sweep starts proves nothing —
    // the mark is gone with the habit and the body never runs.
    final Habit first = addHabit('Sleep');
    scope.definitions
        .save(first.id!, const HabitDefinition(kind: ComputedKind.sleep));
    final Habit deleted = addHabit('Naps');
    scope.definitions
        .save(deleted.id!, const HabitDefinition(kind: ComputedKind.sleep));
    final Habit last = addHabit('Siesta');
    scope.definitions
        .save(last.id!, const HabitDefinition(kind: ComputedKind.sleep));

    final Iterator<Habit> sweep =
        scope.computedHabits(ComputedKind.sleep).iterator;
    expect(sweep.moveNext(), isTrue,
        reason: 'computed.lifecycle#4 — the race is only staged if the sweep '
            'has read the ids and stopped on the first habit');
    expect(sweep.current.name, 'Sleep', reason: 'computed.lifecycle#4');
    // What a real sweep does between two habits is await a platform read, and
    // that is time enough for the person to delete one.
    scope.habitList.remove(deleted);

    final List<String> rest = <String>[];
    expect(() {
      while (sweep.moveNext()) {
        rest.add(sweep.current.name);
      }
    }, returnsNormally,
        reason: 'computed.lifecycle#4 — a mark whose habit is gone is skipped, '
            'not reached for');
    expect(rest, <String>['Siesta'],
        reason: 'computed.lifecycle#4 — and the habits after it are still '
            'swept');
  });
}
