import 'package:test/test.dart';
import 'package:uhabits_core/src/models/model_observable.dart';

/// Written from the parity rules for `models.model-observable`.
///
/// Upstream has no dedicated ModelObservableTest; the only Kotlin coverage is
/// indirect, through SQLiteHabitListTest, which registers a mock
/// `ModelObservable.Listener` on `habitList.observable` and verifies
/// `onModelChange()` fires.

/// Records every notification it receives, tagged with its own name so that
/// notification ORDER across several listeners can be asserted.
class _RecordingListener implements ModelObservableListener {
  _RecordingListener(this.name, this.log);

  final String name;
  final List<String> log;

  @override
  void onModelChange() => log.add(name);
}

void main() {
  group('models.model-observable', () {
    test('#1 a fresh observable has no listeners', () {
      final log = <String>[];
      final observable = ModelObservable();

      // Nothing registered yet: notifying is a no-op, not a crash.
      observable.notifyListeners();
      expect(log, isEmpty, reason: 'models.model-observable#1');

      // ... and the list is a real mutable list, so it can grow afterwards.
      observable.addListener(_RecordingListener('a', log));
      observable.notifyListeners();
      expect(log, ['a'], reason: 'models.model-observable#1');
    });

    test('#1 the listener list keeps registration order', () {
      final log = <String>[];
      final observable = ModelObservable();
      observable.addListener(_RecordingListener('a', log));
      observable.addListener(_RecordingListener('b', log));
      observable.addListener(_RecordingListener('c', log));

      observable.notifyListeners();
      expect(log, ['a', 'b', 'c'], reason: 'models.model-observable#1');
    });

    test('#2 addListener appends to the end of the list', () {
      final log = <String>[];
      final observable = ModelObservable();
      final a = _RecordingListener('a', log);
      final b = _RecordingListener('b', log);

      observable.addListener(a);
      observable.notifyListeners();
      expect(log, ['a'], reason: 'models.model-observable#2');

      log.clear();
      observable.addListener(b);
      observable.notifyListeners();
      expect(log, ['a', 'b'], reason: 'models.model-observable#2');
    });

    test('#2 removeListener unsubscribes a registered listener', () {
      final log = <String>[];
      final observable = ModelObservable();
      final a = _RecordingListener('a', log);
      final b = _RecordingListener('b', log);
      observable.addListener(a);
      observable.addListener(b);

      observable.removeListener(a);
      observable.notifyListeners();
      expect(log, ['b'], reason: 'models.model-observable#2');
    });

    test('#2 removeListener removes only the first matching occurrence', () {
      final log = <String>[];
      final observable = ModelObservable();
      final a = _RecordingListener('a', log);
      final b = _RecordingListener('b', log);
      observable.addListener(a);
      observable.addListener(b);
      observable.addListener(a);

      observable.removeListener(a);
      observable.notifyListeners();
      // The first `a` is gone; the second one, registered after `b`, remains.
      expect(log, ['b', 'a'], reason: 'models.model-observable#2');
    });

    test('#2 removing an unregistered listener does nothing', () {
      final log = <String>[];
      final observable = ModelObservable();
      final a = _RecordingListener('a', log);
      final stranger = _RecordingListener('stranger', log);
      observable.addListener(a);

      // Never registered: no throw, no effect on the existing registrations.
      observable.removeListener(stranger);
      observable.notifyListeners();
      expect(log, ['a'], reason: 'models.model-observable#2');

      // Removing twice: the second call is equally harmless.
      log.clear();
      observable.removeListener(a);
      observable.removeListener(a);
      observable.notifyListeners();
      expect(log, isEmpty, reason: 'models.model-observable#2');
    });

    test('#3 notifyListeners calls onModelChange on every listener in order',
        () {
      final log = <String>[];
      final observable = ModelObservable();
      observable.addListener(_RecordingListener('first', log));
      observable.addListener(_RecordingListener('second', log));
      observable.addListener(_RecordingListener('third', log));

      observable.notifyListeners();
      expect(log, ['first', 'second', 'third'],
          reason: 'models.model-observable#3');

      // Every subsequent call notifies everybody again.
      observable.notifyListeners();
      expect(log, ['first', 'second', 'third', 'first', 'second', 'third'],
          reason: 'models.model-observable#3');
    });

    test('#4 Listener is a functional interface with one onModelChange method',
        () {
      var calls = 0;
      // SAM conversion: a bare callback is a Listener.
      final ModelObservableListener listener =
          ModelObservableListener(() => calls++);

      listener.onModelChange();
      expect(calls, 1, reason: 'models.model-observable#4');

      final observable = ModelObservable();
      observable.addListener(listener);
      observable.notifyListeners();
      expect(calls, 2, reason: 'models.model-observable#4');

      // An explicit implementation of the same single method works too.
      final log = <String>[];
      final ModelObservableListener explicit = _RecordingListener('x', log);
      explicit.onModelChange();
      expect(log, ['x'], reason: 'models.model-observable#4');
    });

    test('#5 the same listener added twice is notified twice', () {
      final log = <String>[];
      final observable = ModelObservable();
      final a = _RecordingListener('a', log);
      observable.addListener(a);
      observable.addListener(a);
      observable.addListener(a);

      observable.notifyListeners();
      expect(log, ['a', 'a', 'a'], reason: 'models.model-observable#5');

      // Duplicates are independent registrations: one removal drops one.
      log.clear();
      observable.removeListener(a);
      observable.notifyListeners();
      expect(log, ['a', 'a'], reason: 'models.model-observable#5');
    });

    test('#5 each observable has its own independent listener list', () {
      final log = <String>[];
      final first = ModelObservable();
      final second = ModelObservable();
      first.addListener(_RecordingListener('first', log));
      second.addListener(_RecordingListener('second', log));

      first.notifyListeners();
      expect(log, ['first'], reason: 'models.model-observable#5');

      log.clear();
      second.notifyListeners();
      expect(log, ['second'], reason: 'models.model-observable#5');
    });
  });
}
