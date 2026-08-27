/// `computed.freshness` — что рассказывают остальному приложению, когда день
/// вычисляемой привычки записан.
///
/// Вычисленное значение не едет на команде: его не выбирают, а считают, и
/// отменять нечего. Но перерисовывается всё именно по команде — список держит
/// свою копию каждой галочки и каждого балла, виджеты публикуются из того же
/// сигнала. Канал один, и он не назван по виду: второй вид пишет из своих
/// мест, и ни одно из них не имело бы повода вспомнить про сонное имя.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/uhabits_core.dart';

// ignore_for_file: implementation_imports

class RecordingCacheListener extends HabitCardListCacheListener {
  int changes = 0;

  @override
  void onItemChanged(int position) => changes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;
  late RecordingCacheListener listener;

  setUp(() {
    setToday(LocalDate(9000));
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
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
    listener = RecordingCacheListener();
  });

  tearDown(() {
    scope.close();
    resetToday();
    DateUtils.setFixedTimeZone(null);
  });

  Habit computedHabit() {
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
        committedFrom: 9000,
      ),
    );
    scope.cache.setListener(listener);
    scope.cache.onAttached();
    listener.changes = 0;
    return habit;
  }

  test('the channel is not named after a kind', () {
    final Habit habit = computedHabit();

    // Deviation from the plan's literal test body (documented in the task
    // report): a bare `definitions.save` never touches `habit.scores` or
    // `habit.computedEntries` — nothing wires a definition into either yet
    // (that door is Task 17's `attachDefinition`). Without a recompute in
    // between, both refreshes read the identical cached-nothing value and the
    // cache's own change-suppression would hide a correct rename exactly as
    // it would hide a broken one. `recompute()` stands in for the write door
    // that will call it automatically once 6-hooks.3 lands.
    habit.recompute();
    scope.onComputedDataChanged(habit.id!);

    expect(listener.changes, greaterThan(0),
        reason: 'computed.freshness#1 — a write nothing is told about is a '
            'row that goes on showing what it showed before');
  });

  test('a closed scope announces nothing', () {
    final Habit habit = computedHabit();
    // Same deviation as above, and load-bearing here too: without a real
    // change sitting in the habit, the assertion below would pass whether or
    // not the guard this test exists for is even there.
    habit.recompute();
    scope.close();
    listener.changes = 0;

    scope.onComputedDataChanged(habit.id!);

    expect(listener.changes, 0,
        reason: 'computed.freshness#1 — refreshing a cache whose database is '
            'gone is a crash, not a redraw');
  });

  test('a sweep announces once for the whole run, and only through the door',
      () async {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1390, wakeMinutes: 400));
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    scope.cache.setListener(listener);
    scope.cache.onAttached();
    listener.changes = 0;

    // Three nights land in one sweep. One announcement, not three — and not
    // four, which is what a hand-written call in the loop would add.
    for (final int day in <int>[8998, 8999, 9000]) {
      scope.sleepRepository.upsert(
        habit.id!,
        day,
        SleepEpisode(
          bedStartMillis: (day + 10956) * 86400000 + 23 * 3600000,
          wakeEndMillis: (day + 10957) * 86400000 + 7 * 3600000,
          asleepMinutes: 460,
          utcOffsetMinutes: 0,
        ),
        manual: true,
      );
    }
    scope.sleepSync.recomputeDays(habit, 8998, 9000);

    expect(listener.changes, 1, reason: 'computed.freshness#2');
  });
}
