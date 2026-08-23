/// `time.midnight-listeners#5` — the rollover only runs while the habit list is
/// in the foreground.
///
/// The two listeners themselves are asserted elsewhere: `#1`..`#4` in
/// packages/uhabits_core/test/time/midnight_listeners_test.dart (the adapter
/// half) and app/test/time/midnight_header_test.dart (the header half). What is
/// left is the *timer*, which neither of them owns: `MidnightTimer.onResume`
/// and `onPause` are called from `ListHabitsActivity.onResume` and `onPause`,
/// nowhere else, so a backgrounded app has no rollover at all — the new day is
/// noticed the next time the list comes forward.
///
/// The port keeps that shape. `_ThemedAppState._onResume` / `_onPause` are the
/// activity callbacks, and both go through [MidnightTimerLifecycle], which is
/// what this file drives.
library;

// The core's platform seams live under `src`, as they do for lib/main.dart.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/reminder_permission_gate.dart'
    show MidnightTimerLifecycle;
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';
import 'package:uhabits_core/uhabits_core.dart'
    show LocalDate, getToday, resetToday, setToday;

void main() {
  const rule = 'time.midnight-listeners#5';

  late MidnightTimer timer;
  late _FakeExecutor executor;
  late MidnightTimerLifecycle lifecycle;
  late int notifications;

  // 2015-01-25 20:00 UTC and the day after it, the same fixtures
  // test/time/midnight_header_test.dart uses.
  final day1 = LocalDate.ymd(2015, 1, 25);
  final day2 = LocalDate.ymd(2015, 1, 26);

  setUp(() {
    systemCurrentTimeMillis = () => day1.unixTime + 20 * 3600000;
    setToday(day1);
    timer = MidnightTimer(
      StandardLogging(),
      Preferences(MemoryStorage()),
    );
    executor = _FakeExecutor();
    lifecycle = MidnightTimerLifecycle(timer);
    notifications = 0;
    timer.addListener(MidnightListener.of(() => notifications++));
  });

  tearDown(() {
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    resetToday();
  });

  /// The clock crosses into [day2].
  void crossMidnight() {
    systemCurrentTimeMillis = () => day2.unixTime + 1000;
  }

  test('#5 nothing is scheduled until the habit list resumes', () {
    expect(executor.schedules, 0,
        reason: '$rule — MidnightTimer is started by '
            "ListHabitsActivity's onResume, so a process that has not shown "
            'the list yet has no rollover armed');
    expect(lifecycle.isRunning, isFalse, reason: rule);
    expect(notifications, 0, reason: rule);

    lifecycle.onResume(testExecutor: executor);

    expect(lifecycle.isRunning, isTrue, reason: rule);
    expect(executor.schedules, 1,
        reason: '$rule — onResume arms it, and only onResume does');
  });

  test('#5 the rollover fires while the list is in the foreground', () {
    lifecycle.onResume(testExecutor: executor);

    // Cross midnight, then let the scheduled command run.
    crossMidnight();
    executor.fire();

    expect(notifications, 1,
        reason: '$rule — a resumed timer notifies its listeners');
    expect(getToday(), day2,
        reason: '$rule — and stamps the new day before it does');
  });

  test('#5 a paused list stops the rollover', () {
    lifecycle.onResume(testExecutor: executor);
    final pending = lifecycle.onPause();

    expect(lifecycle.isRunning, isFalse,
        reason: '$rule — ListHabitsActivity.onPause calls '
            'midnightTimer.onPause()');
    expect(executor.shutdowns, 1,
        reason: '$rule — which shuts the executor down rather than leaving it '
            'queued');
    expect(pending, hasLength(1),
        reason: '$rule — handing back the rollover that never ran');

    // Midnight passes with the app in the background: nothing observes it.
    crossMidnight();
    executor.fire();

    expect(getToday(), day1,
        reason: '$rule — the day the list was left on is still the one every '
            'screen sees');

    expect(notifications, 0,
        reason: '$rule — so the rollover only fires while the habit list is '
            'in the foreground');
  });

  test('#5 coming back to the foreground arms it again', () {
    lifecycle.onResume(testExecutor: executor);
    lifecycle.onPause();
    lifecycle.onResume(testExecutor: executor);

    expect(executor.schedules, 2,
        reason: '$rule — every foreground stretch re-arms the rollover, '
            'because onResume is the only thing that ever arms it');

    crossMidnight();
    executor.fire();
    expect(notifications, 1, reason: rule);
  });
}

/// Records the schedule instead of running it, so a rollover can be driven by
/// hand — `MidnightTimer.onResume(delay, testExecutor)`'s reason for existing.
class _FakeExecutor implements ScheduledExecutorService {
  final List<void Function()> scheduled = <void Function()>[];

  int schedules = 0;
  int shutdowns = 0;

  void fire() {
    for (final command in List<void Function()>.from(scheduled)) {
      command();
    }
  }

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelayMillis,
    int periodMillis,
  ) {
    schedules++;
    scheduled.add(command);
  }

  @override
  List<void Function()> shutdownNow() {
    shutdowns++;
    final pending = List<void Function()>.from(scheduled);
    scheduled.clear();
    return pending;
  }
}
