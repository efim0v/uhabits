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
    // The scope owns the database, and closing it is how a scope is told to
    // stop: a sleep sync can still be waiting on the platform, and it checks
    // before it writes. Closing the database behind the scope's back leaves
    // that check answering yes to a database that is gone.
    scope.close();
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  group('creating one on a device, not in a harness', () {
    /// A scope on the dispatchers production uses.
    ///
    /// Every other test here runs on UnconfinedTestDispatcher, which executes a
    /// command the instant it is handed over. The real one does not, and code
    /// that reads the command's result on the next line is code that works only
    /// in the harness.
    AppScope asyncScope() {
      final AppScope s = AppScope.open(database);
      addTearDown(s.close);
      return s;
    }

    test('the goal is stored even though the command has not run yet',
        () async {
      final AppScope real = asyncScope();
      final EditHabitModel model =
          EditHabitModel(scope: real, sleep: true);
      model.nameController.text = 'Sleep';
      expect(model.save(), isTrue, reason: 'sleep.habit-type#4');

      // Nothing has happened yet: the command is on a task runner.
      await pumpEventQueue(times: 20);

      expect(real.habitList.size(), 1, reason: 'sleep.habit-type#4');
      final Habit habit = real.habitList.getByPosition(0);
      expect(real.sleepRepository.goalFor(habit.id!), isNotNull,
          reason: 'sleep.habit-type#4 — without the goal the habit is not a '
              'sleep habit at all, and its screen shows none of its blocks');
      expect(real.sleepRepository.sleepHabitIds(), <int>[habit.id!],
          reason: 'sleep.habit-type#4');
    });

    test('the goal that is stored is the one the person set', () async {
      final AppScope real = asyncScope();
      final EditHabitModel model =
          EditHabitModel(scope: real, sleep: true);
      model.nameController.text = 'Sleep';
      model.setSleepGoal(model.sleepGoal!.copyWith(
        bedMinutes: 1320,
        wakeMinutes: 360,
        minSleepMinutes: 480,
      ));
      model.save();
      await pumpEventQueue(times: 20);

      final SleepGoal saved =
          real.sleepRepository.goalFor(real.habitList.getByPosition(0).id!)!;
      expect(saved.bedMinutes, 1320, reason: 'sleep.ui#6');
      expect(saved.wakeMinutes, 360, reason: 'sleep.ui#6');
      expect(saved.minSleepMinutes, 480, reason: 'sleep.ui#6');
    });

    test('an ordinary habit stores no goal on this path either', () async {
      final AppScope real = asyncScope();
      final EditHabitModel model =
          EditHabitModel(scope: real, habitType: HabitType.yesNo);
      model.nameController.text = 'Run';
      model.save();
      await pumpEventQueue(times: 20);

      expect(real.sleepRepository.sleepHabitIds(), isEmpty,
          reason: 'sleep.habit-type#4');
    });
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

    test('a new sleep habit is marked as computed', () {
      final EditHabitModel model = EditHabitModel(scope: scope, sleep: true);
      model.nameController.text = 'Sleep';
      model.save();

      final Habit habit = scope.habitList.getByPosition(0);
      expect(scope.definitions.forHabit(habit.id!)?.kind, ComputedKind.sleep,
          reason: 'computed.definition#7');
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

  group('the fields the editor offers', () {
    test('a new goal starts in the timezone the device is in', () {
      // Not zero: a person in Vladivostok whose goal thinks it is in London
      // would be judged eleven hours off from the first night.
      DateUtils.setFixedTimeZone(const FixedTimeZone(5 * 3600000));
      final EditHabitModel model = EditHabitModel(scope: scope, sleep: true);
      expect(model.sleepGoal!.homeUtcOffsetMinutes, 300,
          reason: 'sleep.goal#1');
    });

    test('the home timezone is part of the goal and survives a save', () {
      final EditHabitModel creating =
          EditHabitModel(scope: scope, sleep: true);
      creating.nameController.text = 'Sleep';
      creating.setSleepGoal(
          creating.sleepGoal!.copyWith(homeUtcOffsetMinutes: -480));
      creating.save();

      final int id = scope.habitList.getByPosition(0).id!;
      expect(scope.sleepRepository.goalFor(id)!.homeUtcOffsetMinutes, -480,
          reason: 'sleep.ui#6');
    });

    test('the weights are part of the goal and survive a save', () {
      // The person asked for three weighted parts; a goal whose weights
      // cannot be said is not a goal they set.
      final EditHabitModel creating =
          EditHabitModel(scope: scope, sleep: true);
      creating.nameController.text = 'Sleep';
      creating.setSleepGoal(creating.sleepGoal!.copyWith(
        weightSleep: 0.6,
        weightBed: 0.3,
        weightWake: 0.1,
      ));
      creating.save();

      final int id = scope.habitList.getByPosition(0).id!;
      final SleepGoal saved = scope.sleepRepository.goalFor(id)!;
      expect(saved.weightSleep, closeTo(0.6, 1e-9), reason: 'sleep.ui#6');
      expect(saved.weightBed, closeTo(0.3, 1e-9), reason: 'sleep.ui#6');
      expect(saved.weightWake, closeTo(0.1, 1e-9), reason: 'sleep.ui#6');
    });

    test('the half credit points are part of the goal too', () {
      final EditHabitModel creating =
          EditHabitModel(scope: scope, sleep: true);
      creating.nameController.text = 'Sleep';
      creating.setSleepGoal(creating.sleepGoal!.copyWith(
        halfCreditTimeMinutes: 45,
        halfCreditSleepMinutes: 30,
      ));
      creating.save();

      final int id = scope.habitList.getByPosition(0).id!;
      final SleepGoal saved = scope.sleepRepository.goalFor(id)!;
      expect(saved.halfCreditTimeMinutes, 45, reason: 'sleep.ui#6');
      expect(saved.halfCreditSleepMinutes, 30, reason: 'sleep.ui#6');
    });

    test('changed weights change what a night is worth', () {
      final EditHabitModel creating =
          EditHabitModel(scope: scope, sleep: true);
      creating.nameController.text = 'Sleep';
      creating.save();
      final int id = scope.habitList.getByPosition(0).id!;

      const SleepEpisode episode = SleepEpisode(
        bedStartMillis: (8998 + 10957) * 86400000 + 1500 * 60000,
        wakeEndMillis: (8999 + 10957) * 86400000 + 420 * 60000,
        asleepMinutes: 480,
        utcOffsetMinutes: 0,
      );
      scope.sleepRepository.upsert(id, 8999, episode, manual: false);
      scope.sleepSync.recomputeAll(scope.habitList.getById(id)!);
      final int before = scope.habitList
          .getById(id)!
          .originalEntries
          .get(LocalDate(8999))
          .value;

      final EditHabitModel editing =
          EditHabitModel(scope: scope, habitId: id);
      editing.setSleepGoal(editing.sleepGoal!.copyWith(
        weightSleep: 0.1,
        weightBed: 0.8,
        weightWake: 0.1,
      ));
      editing.save();

      final int after = scope.habitList
          .getById(id)!
          .originalEntries
          .get(LocalDate(8999))
          .value;
      expect(after, isNot(before), reason: 'sleep.ui#6');
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
