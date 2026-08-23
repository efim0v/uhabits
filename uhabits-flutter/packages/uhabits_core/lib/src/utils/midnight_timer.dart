/// Port of
/// uhabits-core/src/jvmMain/java/org/isoron/uhabits/core/utils/MidnightTimer.kt
library;

import 'dart:async';

import '../io/logging.dart';
import '../preferences/preferences.dart';
import '../time/date_utils.dart';
import '../time/local_date.dart';

/// Port of `java.util.concurrent.ScheduledExecutorService`, narrowed to the two
/// methods [MidnightTimer] calls. Injectable so that tests can drive the
/// schedule by hand, which is what `MidnightTimer.onResume(delay, testExecutor)`
/// is for in Kotlin.
abstract class ScheduledExecutorService {
  /// `scheduleAtFixedRate(command, initialDelay, period, MILLISECONDS)`.
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelayMillis,
    int periodMillis,
  );

  /// `shutdownNow()`: stops everything and returns the tasks that were still
  /// waiting to run.
  List<void Function()> shutdownNow();
}

/// `Executors.newSingleThreadScheduledExecutor()`.
///
/// A Dart isolate is already single-threaded, so the "single thread" part comes
/// for free and the schedule is two [Timer]s: a one-shot for the initial delay,
/// then a periodic one. Note that a periodic Dart timer, like Java's fixed-rate
/// schedule, keeps a constant period of exactly one day — DST shifts are NOT
/// compensated between firings.
class SingleThreadScheduledExecutor implements ScheduledExecutorService {
  final List<_ScheduledCommand> _scheduled = <_ScheduledCommand>[];
  bool _isShutdown = false;

  @override
  void scheduleAtFixedRate(
    void Function() command,
    int initialDelayMillis,
    int periodMillis,
  ) {
    if (_isShutdown) {
      // java.util.concurrent.RejectedExecutionException
      throw StateError('Executor has been shut down');
    }
    final entry = _ScheduledCommand(command);
    _scheduled.add(entry);
    entry.initial = Timer(
      Duration(milliseconds: initialDelayMillis),
      () {
        command();
        entry.periodic = Timer.periodic(
          Duration(milliseconds: periodMillis),
          (_) => command(),
        );
      },
    );
  }

  /// Java returns the tasks that never started. A repeating task sits in the
  /// queue between firings, so it is always one of them.
  @override
  List<void Function()> shutdownNow() {
    _isShutdown = true;
    final pending = <void Function()>[];
    for (final entry in _scheduled) {
      entry.cancel();
      pending.add(entry.command);
    }
    _scheduled.clear();
    return pending;
  }
}

class _ScheduledCommand {
  _ScheduledCommand(this.command);

  final void Function() command;
  Timer? initial;
  Timer? periodic;

  void cancel() {
    initial?.cancel();
    periodic?.cancel();
  }
}

/// Port of the Kotlin `fun interface MidnightTimer.MidnightListener`.
abstract class MidnightListener {
  const MidnightListener();

  /// Kotlin's SAM conversion, i.e. `midnightTimer.addListener { ... }`.
  const factory MidnightListener.of(void Function() atMidnight) =
      _CallbackMidnightListener;

  void atMidnight();
}

class _CallbackMidnightListener implements MidnightListener {
  const _CallbackMidnightListener(this._callback);

  final void Function() _callback;

  @override
  void atMidnight() => _callback();
}

/// A class that emits events when a new day starts.
///
/// Kotlin marks all five methods `@Synchronized`. Dart has no monitors: an
/// isolate runs one task at a time, so each method here is already a critical
/// section that no other task can interleave with, and — like a reentrant Java
/// monitor — a listener calling back into the timer is not blocked, it just
/// mutates the list the notify loop is iterating.
class MidnightTimer {
  MidnightTimer(Logging logging, this._preferences)
      : _logger = logging.getLogger('MidnightTimer');

  final Preferences _preferences;
  final Logger _logger;
  final List<MidnightListener> _listeners = <MidnightListener>[];

  /// Kotlin's `lateinit var executor`: reading it before the first [onResume]
  /// throws, and the port keeps that (as a `LateInitializationError`).
  late ScheduledExecutorService _executor;

  void addListener(MidnightListener listener) {
    _listeners.add(listener);
  }

  List<void Function()> onPause() {
    _logger.info('Pausing timer');
    return _executor.shutdownNow();
  }

  void onResume([
    int delayOffsetInMillis = DateUtils.secondLength,
    ScheduledExecutorService? testExecutor,
  ]) {
    _executor = testExecutor ?? SingleThreadScheduledExecutor();
    final initialDelay = DateUtils.millisecondsUntilTomorrowWithOffset(
          _preferences.midnightDelayHours,
          0,
        ) +
        delayOffsetInMillis;
    _logger.info('Scheduling refresh for $initialDelay ms from now');
    _executor.scheduleAtFixedRate(
      _notifyListeners,
      initialDelay,
      DateUtils.dayLength,
    );
  }

  bool removeListener(MidnightListener listener) => _listeners.remove(listener);

  void _notifyListeners() {
    _logger.info('Midnight refresh');
    setToday(computeToday(_preferences.midnightDelayHours, 0));
    for (final l in _listeners) {
      l.atMidnight();
    }
  }
}
