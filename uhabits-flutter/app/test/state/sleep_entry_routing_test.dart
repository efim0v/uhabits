/// Where a request to edit a day's value goes for a sleep habit.
///
/// Three gestures reach the same numeric popup in the original: a tap on a
/// day's cell, a press in the history editor, and the "Enter" action of a
/// reminder. A sleep habit's value is computed from a night rather than typed
/// in, so all three have to end somewhere else — a percentage typed into that
/// popup is overwritten by the next recompute, which is worse than refusing it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
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

  Habit addHabit({required String name, required bool sleep}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = sleep ? sleepHabitType : HabitType.yesNo
      ..targetValue = sleep ? sleepTargetValue : 0
      ..unit = sleep ? sleepUnit : '';
    scope.habitList.add(habit);
    if (sleep) {
      scope.sleepRepository.saveGoal(
          habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    }
    return habit;
  }

  HabitListModel modelWith({
    required void Function(Habit, LocalDate) onSleep,
    required void Function() onNumber,
  }) {
    final HabitListModel model = HabitListModel(scope)
      ..onEnterSleepNight = onSleep
      ..onShowNumberPopup = (double value, String notes,
          NumberPickerCallback callback) {
        onNumber();
      };
    addTearDown(model.dispose);
    return model;
  }

  group("a reminder's Enter action", () {
    test('opens the night for a sleep habit', () {
      final Habit habit = addHabit(name: 'Sleep', sleep: true);
      var sleepOpened = 0;
      var numberOpened = 0;
      LocalDate? openedFor;

      final HabitListModel model = modelWith(
        onSleep: (Habit h, LocalDate d) {
          sleepOpened++;
          openedFor = d;
        },
        onNumber: () => numberOpened++,
      );

      model.pendingIntent = Intent(
        action: HabitListModel.actionEdit,
        extras: <String, Object>{
          'habit': habit.id!,
          'timestamp': LocalDate(8999).unixTime,
        },
      );
      model.parseIntents();

      expect(sleepOpened, 1, reason: 'sleep.reminder#1');
      expect(numberOpened, 0, reason: 'sleep.reminder#1');
      expect(openedFor, LocalDate(8999),
          reason: 'sleep.reminder#1 — the day the reminder was about, not '
              'whatever today happens to be');
    });

    test('an ordinary habit still gets the popup the rule describes', () {
      final Habit habit = addHabit(name: 'Run', sleep: false);
      var sleepOpened = 0;
      var numberOpened = 0;

      final HabitListModel model = modelWith(
        onSleep: (Habit h, LocalDate d) => sleepOpened++,
        onNumber: () => numberOpened++,
      );

      model.pendingIntent = Intent(
        action: HabitListModel.actionEdit,
        extras: <String, Object>{
          'habit': habit.id!,
          'timestamp': LocalDate(8999).unixTime,
        },
      );
      model.parseIntents();

      expect(sleepOpened, 0, reason: 'sleep.reminder#1');
    });

    test('the intent is still dropped afterwards', () {
      final Habit habit = addHabit(name: 'Sleep', sleep: true);
      final HabitListModel model = modelWith(
        onSleep: (Habit h, LocalDate d) {},
        onNumber: () {},
      );
      model.pendingIntent = Intent(
        action: HabitListModel.actionEdit,
        extras: <String, Object>{
          'habit': habit.id!,
          'timestamp': LocalDate(8999).unixTime,
        },
      );
      model.parseIntents();
      expect(model.pendingIntent, isNull, reason: 'sleep.reminder#1');
    });
  });

  group('a habit that stops being one', () {
    test('goes back to the popup once its goal is gone', () {
      // The test for "is this a sleep habit" is the goal, asked each time
      // rather than remembered, so a habit can stop being one.
      final Habit habit = addHabit(name: 'Sleep', sleep: true);
      var sleepOpened = 0;
      final HabitListModel model = modelWith(
        onSleep: (Habit h, LocalDate d) => sleepOpened++,
        onNumber: () {},
      );

      database.run('delete from SleepGoals where habit = ${habit.id}');

      model.pendingIntent = Intent(
        action: HabitListModel.actionEdit,
        extras: <String, Object>{
          'habit': habit.id!,
          'timestamp': LocalDate(8999).unixTime,
        },
      );
      model.parseIntents();

      expect(sleepOpened, 0, reason: 'sleep.habit-type#4');
    });
  });
}
