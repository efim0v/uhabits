/// Creating and editing a sleep habit.
///
/// The model's arithmetic is tested in the core. What is tested here is that
/// the form offers the right fields, settles the ones a person must not
/// change, and stores the goal that makes the habit a sleep habit at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
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
  });

  tearDown(() {
    database.close();
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  group('creating one', () {
    test('starts with a goal, so the form has something to edit', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, sleep: true);
      expect(model.isSleep, isTrue, reason: 'sleep.habit-type#4');
      expect(model.sleepGoal, isNotNull, reason: 'sleep.habit-type#4');
      expect(model.sleepGoal!.bedMinutes, 23 * 60,
          reason: 'sleep.goal#1');
      expect(model.sleepGoal!.wakeMinutes, 7 * 60, reason: 'sleep.goal#1');
      expect(model.sleepGoal!.minSleepMinutes, 450, reason: 'sleep.goal#1');
    });

    test('an ordinary habit gets no goal', () {
      final EditHabitModel model = EditHabitModel(scope: scope);
      expect(model.isSleep, isFalse, reason: 'sleep.habit-type#4');
      expect(model.sleepGoal, isNull, reason: 'sleep.habit-type#4');
    });

    test('saving settles the numerical parameters the model needs', () {
      final EditHabitModel model = EditHabitModel(scope: scope, sleep: true);
      model.nameController.text = 'Sleep';
      expect(model.save(), isTrue, reason: 'sleep.habit-type#2');

      final Habit habit = scope.habitList.getByPosition(0);
      expect(habit.type, sleepHabitType, reason: 'sleep.habit-type#2');
      expect(habit.type, HabitType.numerical,
          reason: 'sleep.habit-type#1 — no third type exists');
      expect(habit.targetValue, 100.0, reason: 'sleep.habit-type#2');
      expect(habit.targetType, NumericalHabitType.atLeast,
          reason: 'sleep.habit-type#2');
      expect(habit.unit, '%', reason: 'sleep.habit-type#2');
      expect(habit.frequency.numerator, 1, reason: 'sleep.habit-type#2');
      expect(habit.frequency.denominator, 1, reason: 'sleep.habit-type#2');
    });

    test('saving stores the goal, which is what makes it a sleep habit', () {
      final EditHabitModel model = EditHabitModel(scope: scope, sleep: true);
      model.nameController.text = 'Sleep';
      model.save();

      final Habit habit = scope.habitList.getByPosition(0);
      expect(scope.sleepRepository.isSleepHabit(habit.id!), isTrue,
          reason: 'sleep.habit-type#4');
      expect(scope.sleepRepository.sleepHabitIds(), <int>[habit.id!],
          reason: 'sleep.habit-type#4');
    });

    test('an ordinary numerical habit stays out of the sleep list', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, habitType: HabitType.numerical);
      model.nameController.text = 'Pages';
      model.unitController.text = 'pages';
      model.targetController.text = '30';
      model.save();

      expect(scope.sleepRepository.sleepHabitIds(), isEmpty,
          reason: 'sleep.habit-type#4');
    });
  });

  group('editing one', () {
    late int habitId;

    setUp(() {
      final EditHabitModel creating =
          EditHabitModel(scope: scope, sleep: true);
      creating.nameController.text = 'Sleep';
      creating.save();
      habitId = scope.habitList.getByPosition(0).id!;
    });

    test('opens on the goal already stored', () {
      scope.sleepRepository.saveGoal(
        habitId,
        const SleepGoal(bedMinutes: 1320, wakeMinutes: 360),
      );
      final EditHabitModel model =
          EditHabitModel(scope: scope, habitId: habitId);
      expect(model.isSleep, isTrue, reason: 'sleep.habit-type#4');
      expect(model.sleepGoal!.bedMinutes, 1320, reason: 'sleep.ui#6');
      expect(model.sleepGoal!.wakeMinutes, 360, reason: 'sleep.ui#6');
    });

    test('an ordinary habit opens without one', () {
      final EditHabitModel creating =
          EditHabitModel(scope: scope, habitType: HabitType.yesNo);
      creating.nameController.text = 'Run';
      creating.save();
      final Habit run = scope.habitList
          .toList()
          .firstWhere((Habit h) => h.name == 'Run');

      final EditHabitModel model =
          EditHabitModel(scope: scope, habitId: run.id!);
      expect(model.isSleep, isFalse, reason: 'sleep.habit-type#4');
    });

    test('a changed goal is stored', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, habitId: habitId);
      model.setSleepGoal(model.sleepGoal!.copyWith(bedMinutes: 1300));
      model.save();

      expect(scope.sleepRepository.goalFor(habitId)!.bedMinutes, 1300,
          reason: 'sleep.ui#6');
    });

    test('changing the goal rescores the whole history', () {
      // Two nights, one of them well outside the fortnight a routine sync
      // reads, so only a full recompute can reach it.
      const int old = 8960;
      for (final int day in <int>[old, 8999]) {
        scope.sleepRepository.upsert(
          habitId,
          day,
          SleepEpisode(
            bedStartMillis: (day - 1 + 10957) * 86400000 + 1380 * 60000,
            wakeEndMillis: (day + 10957) * 86400000 + 420 * 60000,
            asleepMinutes: 480,
            utcOffsetMinutes: 0,
          ),
          manual: false,
        );
      }
      scope.sleepSync.recomputeAll(scope.habitList.getById(habitId)!);
      final int before = scope.habitList
          .getById(habitId)!
          .originalEntries
          .get(LocalDate(old))
          .value;
      expect(before, greaterThan(0), reason: 'sleep.sync#3');

      final EditHabitModel model =
          EditHabitModel(scope: scope, habitId: habitId);
      model.setSleepGoal(
          model.sleepGoal!.copyWith(bedMinutes: 1200, wakeMinutes: 300));
      model.save();

      final int after = scope.habitList
          .getById(habitId)!
          .originalEntries
          .get(LocalDate(old))
          .value;
      expect(after, isNot(before), reason: 'sleep.sync#3');
    });
  });

  group('the day cell in the list', () {
    test('is the ordinary numerical cell, showing a percentage', () {
      // Nothing new is drawn in the list: the value is a number and the unit
      // is a percent sign, which the existing cell already knows how to show.
      final EditHabitModel model = EditHabitModel(scope: scope, sleep: true);
      model.nameController.text = 'Sleep';
      model.save();

      final Habit habit = scope.habitList.getByPosition(0);
      habit.originalEntries.add(Entry(LocalDate(9000), 87000));
      habit.recompute();

      expect(habit.type, HabitType.numerical, reason: 'sleep.ui#1');
      expect(habit.unit, '%', reason: 'sleep.ui#1');
      expect(habit.computedEntries.get(LocalDate(9000)).value, 87000,
          reason: 'sleep.ui#1');
    });
  });
}
