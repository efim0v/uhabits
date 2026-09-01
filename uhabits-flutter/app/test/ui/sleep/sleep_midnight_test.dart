/// A sleep habit's show-habit screen shares one `ShowHabitModel` with every
/// other kind (`_isSleepHabit` only swaps which intensity and total
/// functions `_rebuild` hands the presenter), so the midnight fix in
/// `docs/parity/DEVIATIONS.md` ("экран привычки начинает слушать полночь")
/// reaches it exactly as it reaches a plain habit or an abstinence one —
/// nothing about `ShowHabitModel.atMidnight` singles either out. This is the
/// sleep-side check the wave's "прогон сна обязателен" note asks for.
library;

// The time seam is reached by its `src` path, exactly as
// app/test/state/show_habit_midnight_test.dart reaches it.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart'
    show UnconfinedTestDispatcher;
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart'
    show ScheduledExecutorService;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late Directory tempDir;
  late AppScope scope;
  final TimeZone Function() realZone = getDefaultTimeZone;

  final day1 = core.LocalDate.ymd(2015, 1, 25);
  final day2 = core.LocalDate.ymd(2015, 1, 26);

  setUp(() {
    // Both hooks, together — see app/test/state/show_habit_midnight_test.dart:
    // `computeToday` reads `getDefaultTimeZone` directly, not
    // `DateUtils.currentTimeZone`, so pinning only the latter leaves it
    // reading the host's real zone. Noon, not midnight: east of UTC+12, noon
    // Greenwich is already tomorrow.
    DateUtils.setFixedTimeZone(gmt);
    getDefaultTimeZone = () => gmt;
    systemCurrentTimeMillis = () => day1.unixTime + 12 * 3600000;
    tempDir = Directory.systemTemp.createTempSync('uhabits_sleep_midnight');
    // `AppScope.open` stamps "today" from the mocked clock itself.
    // Synchronous dispatchers, so a habit-list refresh triggered along the
    // way finishes before tearDown resets today out from under it.
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    // The score card buckets by week by default (stored default of
    // `Preferences.scoreCardSpinnerPosition` is 1, not 0) — daily buckets are
    // what makes "the newest score's date is today" an honest reading of
    // whether the card rebuilt at all, the same reason
    // app/test/state/show_habit_midnight_test.dart sets it.
    scope.preferences.scoreCardSpinnerPosition = 0;
  });

  tearDown(() {
    scope.close();
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    getDefaultTimeZone = realZone;
    DateUtils.setFixedTimeZone(null);
    core.resetToday();
    tempDir.deleteSync(recursive: true);
  });

  core.Habit addSleepHabit() {
    final core.Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = core.sleepHabitType
      ..targetValue = core.sleepTargetValue
      ..unit = core.sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const core.SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    // Both rows, because the sweep enumerates by the mark
    // (`computed.definition#8`), the same pairing
    // app/test/state/midnight_timer_resume_test.dart writes.
    scope.definitions.save(
        habit.id!, const core.HabitDefinition(kind: core.ComputedKind.sleep));
    habit.recompute();
    return habit;
  }

  test("a sleep habit's score card moves to the new day at midnight too", () {
    final habit = addSleepHabit();
    final model = ShowHabitModel(
      scope: scope,
      habit: habit,
      theme: core.LightTheme(),
    )..attach();
    addTearDown(model.dispose);
    final executor = _FakeExecutor();
    scope.midnightTimer.onResume(0, executor);

    expect(model.state.scores.scores.first.date, day1,
        reason: 'sanity: built while today was day1, before any night has '
            'been recorded');

    systemCurrentTimeMillis = () => day2.unixTime + 1000;
    executor.fire();

    expect(core.getToday(), day2);
    expect(model.state.scores.scores.first.date, day2,
        reason: 'the same fix that recomputes a plain or an abstinence '
            'habit at midnight recomputes a sleep habit too — a night left '
            'unrecorded across midnight would otherwise go on showing '
            "yesterday's score card and calendar the whole next day");
  });
}

/// Stand-in for the `testExecutor` `MidnightTimer.onResume` takes — the same
/// double app/test/state/show_habit_midnight_test.dart uses, duplicated
/// rather than shared: that file's copy is private to it.
class _FakeExecutor implements ScheduledExecutorService {
  final List<void Function()> scheduled = <void Function()>[];

  void fire() {
    for (final command in List<void Function()>.of(scheduled)) {
      command();
    }
  }

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelayMillis,
    int periodMillis,
  ) {
    scheduled.add(command);
  }

  @override
  List<void Function()> shutdownNow() {
    final pending = List<void Function()>.of(scheduled);
    scheduled.clear();
    return pending;
  }
}
