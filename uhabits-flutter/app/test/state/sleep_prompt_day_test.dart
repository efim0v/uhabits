/// Which day the morning question is about.
///
/// The notification carries a day, and the night a person types in when they
/// answer it is filed against that day. Deriving it from the instant the
/// question is posted at is wrong wherever the offset is large enough to push
/// the instant onto the day before — every zone east of UTC+8 for a question
/// asked in the morning.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int day = 9000;
  const int aucklandMinutes = 13 * 60;

  late Database database;
  late AppScope scope;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(aucklandMinutes * 60000));
    // 05:00 local on day 9000, which is before the question is due.
    DateUtils.setFixedLocalTime((day + 10957) * 86400000 + 5 * 3600000);
    setToday(LocalDate(day));
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
    scope.close();
    DateUtils.setFixedTimeZone(null);
    DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  Habit sleepHabit({int homeOffsetMinutes = aucklandMinutes}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
      habit.id!,
      SleepGoal(
        bedMinutes: 23 * 60,
        wakeMinutes: 7 * 60,
        homeUtcOffsetMinutes: homeOffsetMinutes,
      ),
    );
    return habit;
  }

  test('is the day the person wakes on, not the day the instant falls on', () {
    final Habit habit = sleepHabit();
    final int? at = scope.sleepPromptInstant(habit);
    expect(at, isNotNull, reason: 'sleep.freshness#4');

    expect(
      LocalDate.fromUnixTime(at!).daysSince2000,
      day - 1,
      reason: 'sleep.freshness#4 — the check is only worth making because the '
          'instant itself falls on the day before in Auckland',
    );
    expect(scope.sleepPromptDayOf(habit, at)!.daysSince2000, day,
        reason: 'sleep.freshness#4');
  });

  test('west of UTC the two agree, and the answer is still the local day', () {
    // Nothing about the correction may move a day that was already right.
    DateUtils.setFixedTimeZone(const FixedTimeZone(-5 * 60 * 60000));
    final Habit habit = sleepHabit(homeOffsetMinutes: -5 * 60);
    final int? at = scope.sleepPromptInstant(habit);
    expect(at, isNotNull, reason: 'sleep.freshness#4');
    expect(scope.sleepPromptDayOf(habit, at!)!.daysSince2000, day,
        reason: 'sleep.freshness#4');
  });

  test('a habit with no goal has no day, because it has no question', () {
    final Habit habit = scope.modelFactory.buildHabit()..name = 'Run';
    scope.habitList.add(habit);
    expect(scope.sleepPromptDayOf(habit, 1770000000000), isNull,
        reason: 'sleep.freshness#4');
  });
}
