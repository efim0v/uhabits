/// What happens at midnight in the UI: who is subscribed to [MidnightTimer]
/// and what each subscriber does when the day rolls over.
///
/// Kotlin source: `HabitCardListAdapter.onAttached/onDetached/atMidnight` and
/// `HeaderView.onAttachedToWindow/onDetachedFromWindow/atMidnight`. The adapter
/// is core and is ported verbatim; the header is a view, and its half is
/// asserted in app/test/ui/habits/list/midnight_header_test.dart.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_adapter.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

/// Records the schedule instead of running it, so a day can pass in a
/// microsecond. Same shape as the one in midnight_timer_test.dart.
class _RecordingExecutor implements ScheduledExecutorService {
  final List<void Function()> commands = <void Function()>[];
  bool isShutdown = false;

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelay,
    int period,
  ) {
    commands.add(command);
  }

  @override
  List<void Function()> shutdownNow() {
    isShutdown = true;
    final pending = List<void Function()>.of(commands);
    commands.clear();
    return pending;
  }

  /// One firing of the schedule.
  void tick() {
    for (final command in List<void Function()>.of(commands)) {
      command();
    }
  }
}

/// A cache that records the refreshes the adapter asks it for.
class _SpyCache extends HabitCardListCache {
  _SpyCache(super.allHabits, super.commandRunner, super.taskRunner,
      super.logging);

  int refreshAllCount = 0;

  @override
  void refreshAllHabits() {
    refreshAllCount++;
    super.refreshAllHabits();
  }
}

/// A listener of the third kind: whatever else subscribes (the widget
/// publisher does, in the Flutter port).
class _CountingListener implements MidnightListener {
  int count = 0;

  @override
  void atMidnight() => count++;
}

void main() {
  late MemoryModelFactory factory;
  late Preferences prefs;
  late MidnightTimer timer;
  late _RecordingExecutor executor;
  late _SpyCache cache;
  late HabitCardListAdapter adapter;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    DateUtils.setFixedTimeZone(gmt);
    DateUtils.setFixedLocalTime(LocalDate.ymd(2015, 1, 25).unixTime + 20 * 3600000);
    factory = MemoryModelFactory();
    final log = StringBuffer();
    final logging = StandardLogging(out: log, err: log);
    prefs = Preferences(MemoryStorage());
    timer = MidnightTimer(logging, prefs);
    executor = _RecordingExecutor();
    final taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    cache = _SpyCache(
      factory.buildHabitList(),
      CommandRunner(taskRunner),
      taskRunner,
      logging,
    );
    adapter = HabitCardListAdapter(cache, prefs, timer);
    // `onAttached()` refreshes as a side effect; start the count from zero so
    // only the midnight refreshes are counted below.
    timer.onResume(1000, executor);
  });

  tearDown(() {
    DateUtils.setFixedLocalTime(null);
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  group('time.midnight-listeners', () {
    test('#1/#4 the adapter is a MidnightListener, registered by onAttached '
        'and removed by onDetached', () {
      expect(adapter, isA<MidnightListener>(),
          reason: 'time.midnight-listeners#1 — HabitCardListAdapter is one of '
              'the registered MidnightListeners');

      // Not yet attached: a rollover reaches nobody.
      cache.refreshAllCount = 0;
      executor.tick();
      expect(cache.refreshAllCount, 0,
          reason: 'time.midnight-listeners#4 — HabitCardListAdapter registers '
              'in onAttached(), not in its constructor');

      adapter.onAttached();
      cache.refreshAllCount = 0;
      executor.tick();
      expect(cache.refreshAllCount, 1,
          reason: 'time.midnight-listeners#1 — it is registered while attached');

      adapter.onDetached();
      cache.refreshAllCount = 0;
      executor.tick();
      expect(cache.refreshAllCount, 0,
          reason: 'time.midnight-listeners#4 — and unregisters in '
              'onDetached()');
    });

    test('#3 the adapter reloads every habit card at midnight', () {
      adapter.onAttached();
      cache.refreshAllCount = 0;

      adapter.atMidnight();

      expect(cache.refreshAllCount, 1,
          reason: 'time.midnight-listeners#3 — '
              'HabitCardListAdapter.atMidnight() calls '
              'cache.refreshAllHabits(), reloading every habit card');

      // And that is the only thing it does: no selection is cleared, no filter
      // is touched.
      expect(adapter.selected, isEmpty,
          reason: 'time.midnight-listeners#3 — atMidnight() reloads and does '
              'nothing else');
    });

    test('#1 every registered listener hears the same rollover, after today '
        'has already moved', () {
      adapter.onAttached();
      final other = _CountingListener();
      timer.addListener(other);
      cache.refreshAllCount = 0;

      // The day the timer will compute when it fires.
      systemCurrentTimeMillis =
          () => LocalDate.ymd(2015, 1, 26).unixTime + 1000;
      getDefaultTimeZone = () => const FixedTimeZone(0);
      addTearDown(() {
        systemCurrentTimeMillis = defaultCurrentTimeMillis;
        getDefaultTimeZone = systemDefaultTimeZone;
      });

      executor.tick();

      expect(getToday(), LocalDate.ymd(2015, 1, 26),
          reason: 'time.midnight-listeners#1 — the timer stamps the new day '
              'before notifying, so every listener sees the new today');
      expect(cache.refreshAllCount, 1,
          reason: 'time.midnight-listeners#1 — the adapter is notified');
      expect(other.count, 1,
          reason: 'time.midnight-listeners#1 — so is every other registered '
              'listener; the Flutter port registers the widget publisher here, '
              'where Android registers HeaderView');
    });
  });
}
