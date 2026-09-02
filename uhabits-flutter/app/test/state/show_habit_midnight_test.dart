/// `ShowHabitModel` recomputes the shown habit and rebuilds the screen when
/// the day rolls over while it is attached to `scope.midnightTimer` — the fix
/// `docs/parity/DEVIATIONS.md` calls "экран привычки начинает слушать
/// полночь".
///
/// Before it, nothing rebuilt `_state` at midnight at all: it stayed exactly
/// what the last `refresh()` built. For an abstinence habit specifically,
/// `habit.streaks` stayed anchored to the day it was last recomputed on, so
/// `getCurrent(getToday())` found no streak covering the new day and the
/// running counter read "0 minutes" even though nobody had lapsed. This file
/// checks the subscription lifecycle and both the "still running" and the
/// "genuinely lapsed" shape of that bug, plus the plain habit the same fix
/// reaches for free.
///
/// The counter no longer goes through `habit.streaks` at all
/// (`computed.since#4`), so the rollover no longer decides what it prints:
/// `abstinenceSinceMillis` answers the same instant on both sides of
/// midnight, and it is checked here for that instant and nothing else. What
/// proves the screen rebuilt is `habit.streaks` itself — the very list the
/// bug left anchored to yesterday — and it is asserted on its own line.
library;

// The commands, preferences and time seams are reached by their `src` path,
// exactly as lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_button_view.dart'
    show isAbstinenceLapseDay;
import 'package:uhabits_core/src/tasks/task_runner.dart'
    show UnconfinedTestDispatcher;
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart'
    show ScheduledExecutorService;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  var nextDatabase = 0;
  final TimeZone Function() realZone = getDefaultTimeZone;

  // Three consecutive days, the same shape
  // app/test/state/midnight_timer_resume_test.dart uses.
  final day1 = core.LocalDate.ymd(2015, 1, 25);
  final day2 = core.LocalDate.ymd(2015, 1, 26);
  final day3 = core.LocalDate.ymd(2015, 1, 27);

  setUp(() {
    // Both hooks, together: `computeToday` — what `AppScope.open` and
    // `MidnightTimer._notifyListeners` both stamp "today" from — reads
    // `getDefaultTimeZone` directly rather than `DateUtils.currentTimeZone`,
    // so pinning only `DateUtils.setFixedTimeZone` leaves it reading the
    // host's real zone. Noon, not midnight: east of UTC+12, noon Greenwich is
    // already tomorrow, and a host in such a zone would see day1 arrive
    // already rolled over.
    DateUtils.setFixedTimeZone(gmt);
    getDefaultTimeZone = () => gmt;
    systemCurrentTimeMillis = () => day1.unixTime + 12 * 3600000;
    tempDir =
        Directory.systemTemp.createTempSync('uhabits_show_habit_midnight');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    getDefaultTimeZone = realZone;
    DateUtils.setFixedTimeZone(null);
    core.resetToday();
    tempDir.deleteSync(recursive: true);
  });

  /// `AppScope.open` stamps "today" from the mocked clock itself
  /// (`setToday(computeToday(...))`, before any habit is touched), so the
  /// fixture never has to call `setToday` by hand.
  AppScope openScope() {
    final path = '${tempDir.path}/habits${nextDatabase++}.db';
    // Synchronous dispatchers, so a habit-list refresh triggered along the
    // way finishes before tearDown resets today out from under it — the same
    // reason app/test/commands/command_listener_lifecycle_test.dart takes
    // them.
    final scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    // The score card buckets by week by default
    // (`Preferences.scoreCardSpinnerPosition`'s stored default is 1, not 0):
    // day1 and day2 can land in the same week, and its newest bucket's date
    // would then stay put across the rollover even though the scores inside
    // it changed. Daily buckets are what makes "the newest score's date is
    // today" an honest reading of whether the card rebuilt at all.
    scope.preferences.scoreCardSpinnerPosition = 0;
    scopes.add(scope);
    return scope;
  }

  core.Habit addPlainHabit(AppScope scope, String name) {
    final core.Habit habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  /// An abstinence habit committed [daysAgo] days before whatever "today" is
  /// when this is called, allowance zero — the same shape
  /// app/test/ui/habits/abstinence/abstinence_overview_test.dart's
  /// `addAbstinence` builds.
  core.Habit addAbstinence(AppScope scope, {required int daysAgo}) {
    final core.Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sober'
      ..type = core.HabitType.numerical
      ..targetType = core.NumericalHabitType.atMost
      ..targetValue = 0.0;
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      core.HabitDefinition(
        kind: core.ComputedKind.abstinence,
        committedFrom: core.getToday().daysSince2000 - daysAgo,
        payload: core.abstinencePayload(allowance: 0.0, unit: ''),
      ),
    );
    core.attachDefinition(habit, scope.definitions);
    habit.recompute();
    return habit;
  }

  /// The one judge every abstinence surface uses
  /// (`computed.abstinence-cell#2`); the counter takes it as a seam, because
  /// the half that translates the scale lives up here and not in the core.
  bool Function(int) judgeOf(core.Habit habit) =>
      (int value) => isAbstinenceLapseDay(habit.definition!, value);

  /// Records the schedule instead of running it — `MidnightTimer.onResume`'s
  /// reason for taking a `testExecutor` — the same double
  /// app/test/state/midnight_timer_resume_test.dart uses.
  test('attach subscribes ShowHabitModel to the midnight timer, detach '
      'unsubscribes it', () {
    final scope = openScope();
    final habit = addPlainHabit(scope, 'Meditate');
    final model = ShowHabitModel(
      scope: scope,
      habit: habit,
      theme: core.LightTheme(),
    );
    addTearDown(model.dispose);
    final executor = _FakeExecutor();
    scope.midnightTimer.onResume(0, executor);

    // Before attach(), the model is not on the runner or the timer.
    systemCurrentTimeMillis = () => day2.unixTime + 1000;
    executor.fire();
    expect(core.getToday(), day2,
        reason: 'the timer itself always stamps the day, whether or not this '
            'screen is listening');
    expect(model.state.scores.scores.first.date, day1,
        reason: 'the model is not attached yet, so the rollover reaches '
            'nobody and the state built for day1 is untouched');

    // attach() always refreshes once, same as onResume always has — this
    // alone is not the fix, it is the pre-existing baseline.
    model.attach();
    expect(model.state.scores.scores.first.date, day2,
        reason: 'attach() refreshes unconditionally, and today is already '
            'day2 by the time it runs');

    // Now the day rolls over again while the screen stays attached — the
    // scenario the bug report describes: nobody navigated away and back,
    // nothing else touched the habit, midnight is the only thing that
    // happened.
    systemCurrentTimeMillis = () => day3.unixTime + 1000;
    executor.fire();
    expect(model.state.scores.scores.first.date, day3,
        reason: 'attach() registered the model with scope.midnightTimer, so '
            'the rollover reaches it and rebuilds the state on its own — '
            'this is the fix');

    // detach() takes the subscription off again.
    model.detach();
    final day4 = core.LocalDate.ymd(2015, 1, 28);
    systemCurrentTimeMillis = () => day4.unixTime + 1000;
    executor.fire();
    expect(model.state.scores.scores.first.date, day3,
        reason: 'detach() removed the listener along with the command '
            'runner one, so a later rollover reaches nobody and the state '
            'stays exactly where it was left');
  });

  test("a plain habit's score card moves to the new day too", () {
    final scope = openScope();
    final habit = addPlainHabit(scope, 'Meditate');
    final model = ShowHabitModel(
      scope: scope,
      habit: habit,
      theme: core.LightTheme(),
    )..attach();
    addTearDown(model.dispose);
    final executor = _FakeExecutor();
    scope.midnightTimer.onResume(0, executor);

    expect(model.state.scores.scores.first.date, day1,
        reason: 'sanity: the state was built while today was day1');

    systemCurrentTimeMillis = () => day2.unixTime + 1000;
    executor.fire();

    expect(core.getToday(), day2);
    expect(model.state.scores.scores.first.date, day2,
        reason: 'the fix rebuilds the whole screen on every rollover, not '
            'only for computed habits — a plain habit\'s score card was '
            'exactly as pinned to yesterday before it');
  });

  test('an abstinence habit keeps ticking across midnight when nobody '
      'lapsed', () {
    final scope = openScope();
    final habit = addAbstinence(scope, daysAgo: 20);
    final model = ShowHabitModel(
      scope: scope,
      habit: habit,
      theme: core.LightTheme(),
    )..attach();
    addTearDown(model.dispose);
    final executor = _FakeExecutor();
    scope.midnightTimer.onResume(0, executor);

    expect(
        core.abstinenceSinceMillis(habit, scope.lapses,
            isLapseValue: judgeOf(habit)),
        day1.minus(20).unixTime,
        reason: 'sanity: nobody has lapsed and the commitment has no moment '
            'of its own, so the counter reads the midnight of the day it was '
            'made — twenty days before day1, in the pinned zone');

    systemCurrentTimeMillis = () => day2.unixTime + 1000;
    executor.fire();

    expect(core.getToday(), day2);
    // The bug, stated exactly: without the fix, `habit.streaks` is still the
    // list built for day1, and no streak in it covers day2 at all.
    expect(habit.streaks.getCurrent(day2), isNotNull,
        reason: 'atMidnight() recomputes the habit, and a silence-qualifying '
            'streak extends to cover a day nobody lapsed on');
    expect(
        core.abstinenceSinceMillis(habit, scope.lapses,
            isLapseValue: judgeOf(habit)),
        day1.minus(20).unixTime,
        reason: 'computed.since#3 — the same instant as before the rollover, '
            'to the millisecond: the commitment did not move, so neither did '
            'the count. This is not what proves the rebuild — the streak line '
            'above is — it is what proves the counter says one thing on both '
            'sides of midnight');
  });

  test('an abstinence habit that lapses on the new day counts from that '
      'lapse', () {
    final scope = openScope();
    final habit = addAbstinence(scope, daysAgo: 20);
    final model = ShowHabitModel(
      scope: scope,
      habit: habit,
      theme: core.LightTheme(),
    )..attach();
    addTearDown(model.dispose);
    final executor = _FakeExecutor();
    scope.midnightTimer.onResume(0, executor);

    systemCurrentTimeMillis = () => day2.unixTime + 1000;
    executor.fire();
    expect(
        core.abstinenceSinceMillis(habit, scope.lapses,
            isLapseValue: judgeOf(habit)),
        day1.minus(20).unixTime,
        reason: 'sanity: the rollover alone does not end anything — this is '
            'the same habit as the test above, one line before it lapses, '
            'still counting from the midnight of its commitment day');

    // The person lapses today — day2, now that it really is "today" — the
    // same door the button on screen calls.
    scope.abstinence.setLapse(habit, day2, true);

    expect(core.getToday(), day2);
    expect(habit.streaks.getCurrent(day2), isNull,
        reason: 'a real lapse on the new day is still a lapse: no streak '
            'covers day2 any more, and this is exactly what the counter used '
            'to be asking');
    expect(
        core.abstinenceSinceMillis(habit, scope.lapses,
            isLapseValue: judgeOf(habit)),
        day2.unixTime + 1000,
        reason: 'computed.since#4 — счёт идёт от мгновения того срыва: '
            'секунду назад записанный момент и есть начало счёта, а не ноль '
            'до следующей полуночи');
  });
}

/// Stand-in for the `testExecutor` `MidnightTimer.onResume` takes: it records
/// the schedule instead of running it, so a rollover can be driven by hand.
/// The same double app/test/state/midnight_timer_resume_test.dart uses,
/// duplicated rather than shared — that file's copy is private to it.
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
