/// The guards are on instances, so they are only as good as their wiring.
///
/// `WidgetBehavior` and `ShowHabitMenuPresenter` both take "is this habit
/// computed" as a constructor argument rather than reaching for a repository:
/// the behaviour needs the answer, not the table. That makes every guard a
/// property of the object that was built, and a construction site that forgets
/// the argument builds an object with no guard at all — which is how the widget
/// tap door came to be open on `main.dart`'s `WidgetBehavior` while the plan
/// named only `AppScope`'s.
///
/// `WidgetBehavior` is app-side, so its argument is now required and the
/// compiler is the test. The ported core presenter's cannot be — its
/// constructor is the Kotlin one, and four ported test files build it without
/// anything of ours. The app has exactly one site of it, and this file is what
/// stands in for the compiler there.
library;

// The core's models are reached by their `src` path, exactly as lib/state does.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
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
      ..unit = '%'
      ..targetValue = 100;
    scope.habitList.add(habit);
    habit.originalEntries.add(Entry(LocalDate(9000), 89763));
    habit.recompute();
    return habit;
  }

  ShowHabitModel modelFor(Habit habit) {
    final ShowHabitModel model =
        ShowHabitModel(scope: scope, habit: habit, theme: LightTheme());
    addTearDown(model.dispose);
    return model;
  }

  test('the habit screen builds its menu with the computed guard wired', () {
    // Randomise is `originalEntries.clear()`, which is `deleteByHabitId` in
    // SQLite: it would take the computed values and the person's own skips
    // with it, unrecoverably outside the sync's read window.
    final Habit habit = addHabit('Sleep');
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));

    modelFor(habit).menuPresenter.onRandomize();

    expect(habit.originalEntries.get(LocalDate(9000)).value, 89763,
        reason: 'computed.lifecycle#3 — the screen the app really builds, not '
            'a presenter assembled by the test');
  });

  test('and randomises an ordinary habit as it always did', () {
    final Habit habit = addHabit('Meditate');

    modelFor(habit).menuPresenter.onRandomize();

    expect(habit.originalEntries.get(LocalDate(9000)).value, isNot(89763),
        reason: 'show-habit.randomize#2 — the check above is only worth '
            'making if randomise still does its work for everything else');
  });
}
