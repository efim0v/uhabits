/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCache.kt
///
/// Kotlin annotates almost every member `@Synchronized`, because the refresh
/// runs on a background thread while the list view reads the cache on the main
/// one. A Dart isolate is single threaded and [CoroutineTaskRunner] hands the
/// work back through the event loop rather than through a thread, so there is
/// no lock to port — what survives is the *order* in which the callbacks fire.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../../../commands/command.dart';
import '../../../../commands/command_runner.dart';
import '../../../../commands/create_repetition_command.dart';
import '../../../../io/logging.dart';
import '../../../../models/habit.dart';
import '../../../../models/habit_list.dart';
import '../../../../models/habit_matcher.dart';
import '../../../../tasks/task_runner.dart';
import '../../../../time/local_date.dart';

/// A HabitCardListCache fetches and keeps a cache of all the data necessary to
/// render a HabitCardListView.
///
/// This is needed since performing database lookups during scrolling can make
/// the ListView very slow. It also registers itself as an observer of the
/// models, in order to update itself automatically.
///
/// Note that this class is singleton-scoped (`@AppScope` in Kotlin), therefore
/// it is shared among all activities.
class HabitCardListCache implements CommandRunnerListener {
  HabitCardListCache(
    this._allHabits,
    this._commandRunner,
    this._taskRunner,
    Logging logging,
  ) : _logger = logging.getLogger('HabitCardListCache') {
    // Kotlin's `init` block.
    _filteredHabits = _allHabits;
    _listener = HabitCardListCacheListener();
    _data = CacheData(this);
  }

  final HabitList _allHabits;

  final CommandRunner _commandRunner;

  final TaskRunner _taskRunner;

  final Logger _logger;

  int _checkmarkCount = 0;

  Task? _currentFetchTask;

  late HabitCardListCacheListener _listener;

  late final CacheData _data;

  late HabitList _filteredHabits;

  void cancelTasks() {
    _currentFetchTask?.cancel();
  }

  /// Kotlin returns `data.checkmarks[habitId]!!`: asking for a habit that is
  /// not in the cache throws.
  List<int> getCheckmarks(int habitId) => _data.checkmarks[habitId]!;

  List<String> getNotes(int habitId) => _data.notes[habitId]!;

  /// Reads the *unfiltered* list, so an active filter that hides every habit
  /// does not make this true.
  bool hasNoHabit() => _allHabits.isEmpty;

  /// Returns the habit that occupies a certain position on the list, or null
  /// if the position is invalid.
  Habit? getHabitByPosition(int position) {
    return (position < 0 || position >= _data.habits.length)
        ? null
        : _data.habits[position];
  }

  int get habitCount => _data.habits.length;

  HabitListOrder get primaryOrder => _filteredHabits.primaryOrder;

  set primaryOrder(HabitListOrder order) {
    _allHabits.primaryOrder = order;
    _filteredHabits.primaryOrder = order;
    refreshAllHabits();
  }

  HabitListOrder get secondaryOrder => _filteredHabits.secondaryOrder;

  set secondaryOrder(HabitListOrder order) {
    _allHabits.secondaryOrder = order;
    _filteredHabits.secondaryOrder = order;
    refreshAllHabits();
  }

  double getScore(int habitId) => _data.scores[habitId]!;

  void onAttached() {
    refreshAllHabits();
    _commandRunner.addListener(this);
  }

  @override
  void onCommandFinished(Command command) {
    if (command is CreateRepetitionCommand) {
      // Kotlin: `command.habit.id?.let { refreshHabit(it) }` — nothing happens
      // at all when the habit has no id.
      final id = command.habit.id;
      if (id != null) refreshHabit(id);
    } else {
      refreshAllHabits();
    }
  }

  void onDetached() {
    _commandRunner.removeListener(this);
  }

  void refreshAllHabits() {
    if (_currentFetchTask != null) _currentFetchTask!.cancel();
    final task = _RefreshTask(this);
    _currentFetchTask = task;
    _taskRunner.execute(task);
  }

  /// Starts a task scoped to a single habit. Note that, unlike
  /// [refreshAllHabits], it neither cancels nor records the current fetch task
  /// — but its `onPostExecute` still clears `currentFetchTask`, exactly as
  /// upstream does.
  void refreshHabit(int id) {
    _taskRunner.execute(_RefreshTask(this, id));
  }

  /// Optimistic removal: drops the habit from every cache map and notifies the
  /// listener, without touching the database. The next refresh brings it back
  /// if it is still there.
  void remove(int id) {
    final h = _data.idToHabit[id];
    if (h == null) return;
    final position = _data.habits.indexOf(h);
    _data.habits.removeAt(position);
    _data.idToHabit.remove(id);
    _data.checkmarks.remove(id);
    _data.notes.remove(id);
    _data.scores.remove(id);
    _listener.onItemRemoved(position);
  }

  /// Optimistic reordering: cache only, database untouched.
  void reorder(int from, int to) {
    final fromHabit = _data.habits[from];
    _data.habits.removeAt(from);
    _data.habits.insert(to, fromHabit);
    _listener.onItemMoved(from, to);
  }

  void setCheckmarkCount(int checkmarkCount) {
    _checkmarkCount = checkmarkCount;
  }

  /// Replaces the filtered list. Deliberately does *not* refresh: the caller
  /// must call [refreshAllHabits] afterwards.
  void setFilter(HabitMatcher matcher) {
    _filteredHabits = _allHabits.getFiltered(matcher);
  }

  void setListener(HabitCardListCacheListener listener) {
    _listener = listener;
  }
}

/// Port of the nested Kotlin interface `HabitCardListCache.Listener`.
///
/// Dart has no nested classes, so it becomes a top-level one. Every method has
/// a no-op body in Kotlin too, which is what lets the cache start with
/// `object : Listener {}` and what lets the view layer override only the
/// callbacks it cares about.
class HabitCardListCacheListener {
  void onItemChanged(int position) {}

  void onItemInserted(int position) {}

  void onItemMoved(int oldPosition, int newPosition) {}

  void onItemRemoved(int position) {}

  void onRefreshFinished() {}
}

/// Port of the `private inner class CacheData`.
///
/// Dart privacy is per-library, and a private class cannot be reached from the
/// test file, so this one stays public. It is not exported from
/// `uhabits_core.dart` and nothing outside the refresh pipeline should touch
/// it.
@visibleForTesting
class CacheData {
  /// Creates a new CacheData without any content.
  CacheData(this._cache);

  /// Kotlin reads `checkmarkCount` and `filteredHabits` off the outer
  /// instance, at call time; holding the cache reproduces that.
  final HabitCardListCache _cache;

  final Map<int, Habit> idToHabit = <int, Habit>{};

  final List<Habit> habits = <Habit>[];

  final Map<int, List<int>> checkmarks = <int, List<int>>{};

  final Map<int, double> scores = <int, double>{};

  final Map<int, List<String>> notes = <int, List<String>>{};

  /// Habits with no previously cached data all share one zero-filled array of
  /// length `checkmarkCount`, exactly as `IntArray(checkmarkCount)` does in
  /// Kotlin.
  void copyCheckmarksFrom(CacheData oldData) {
    final empty = List<int>.filled(_cache._checkmarkCount, 0);
    for (final id in idToHabit.keys) {
      if (oldData.checkmarks.containsKey(id)) {
        checkmarks[id] = oldData.checkmarks[id]!;
      } else {
        checkmarks[id] = empty;
      }
    }
  }

  /// The default notes array is `(0..checkmarkCount).map { "" }`, so it holds
  /// `checkmarkCount + 1` strings — one more than the checkmark array. The
  /// off-by-one is upstream's.
  void copyNoteIndicatorsFrom(CacheData oldData) {
    final empty = List<String>.filled(_cache._checkmarkCount + 1, '');
    for (final id in idToHabit.keys) {
      if (oldData.notes.containsKey(id)) {
        notes[id] = oldData.notes[id]!;
      } else {
        notes[id] = empty;
      }
    }
  }

  void copyScoresFrom(CacheData oldData) {
    for (final id in idToHabit.keys) {
      if (oldData.scores.containsKey(id)) {
        scores[id] = oldData.scores[id]!;
      } else {
        scores[id] = 0.0;
      }
    }
  }

  /// Reads the currently filtered list, skipping any habit whose id is null.
  void fetchHabits() {
    for (final h in _cache._filteredHabits) {
      if (h.id == null) continue;
      habits.add(h);
      idToHabit[h.id!] = h;
    }
  }
}

/// Port of the `private inner class RefreshTask`.
class _RefreshTask extends Task {
  /// Kotlin has two constructors: the no-argument one is the full refresh, and
  /// the one taking a `targetId` refreshes a single habit.
  _RefreshTask(HabitCardListCache cache, [this._targetId])
      : _cache = cache,
        _newData = CacheData(cache);

  final HabitCardListCache _cache;

  final CacheData _newData;

  final int? _targetId;

  bool _isCancelled = false;

  TaskRunner? _runner;

  @override
  void cancel() {
    _isCancelled = true;
  }

  @override
  FutureOr<void> doInBackground() {
    final data = _cache._data;
    _newData.fetchHabits();
    _newData.copyScoresFrom(data);
    _newData.copyCheckmarksFrom(data);
    _newData.copyNoteIndicatorsFrom(data);
    final today = getToday();
    final dateFrom = today.minus(_cache._checkmarkCount - 1);
    // Kotlin guards this one call with `if (runner != null)` and then
    // dereferences `runner!!` unguarded inside the loop; both are kept.
    _runner?.publishProgress(this, -1);
    for (var position = 0; position < _newData.habits.length; position++) {
      if (_isCancelled) return null;
      final habit = _newData.habits[position];
      if (_targetId != null && _targetId != habit.id) continue;
      final id = habit.id!;
      _newData.scores[id] = habit.scores[today].value;
      final checkmarkList = <int>[];
      final noteList = <String>[];
      for (final entry in habit.computedEntries.getByInterval(dateFrom, today)) {
        checkmarkList.add(entry.value);
        noteList.add(entry.notes);
      }
      _newData.checkmarks[id] = checkmarkList;
      _newData.notes[id] = noteList;
      _runner!.publishProgress(this, position);
    }
    return null;
  }

  @override
  void onAttached(TaskRunner runner) {
    _runner = runner;
  }

  /// Clears `currentFetchTask` even for a targeted refresh, which can drop the
  /// handle of an unrelated in-flight full refresh. Upstream behaviour, kept.
  @override
  void onPostExecute() {
    _cache._currentFetchTask = null;
    _cache._listener.onRefreshFinished();
  }

  @override
  void onProgressUpdate(int currentPosition) {
    if (currentPosition < 0) {
      _processRemovedHabits();
    } else {
      _processPosition(currentPosition);
    }
  }

  void _performInsert(Habit habit, int position) {
    final data = _cache._data;
    final id = habit.id!;
    data.habits.insert(position, habit);
    data.idToHabit[id] = habit;
    data.scores[id] = _newData.scores[id]!;
    data.checkmarks[id] = _newData.checkmarks[id]!;
    data.notes[id] = _newData.notes[id]!;
    _cache._listener.onItemInserted(position);
  }

  void _performMove(Habit habit, int fromPosition, int toPosition) {
    final data = _cache._data;
    data.habits.removeAt(fromPosition);

    // Workaround for https://github.com/iSoron/uhabits/issues/968
    final int checkedToPosition;
    if (toPosition > data.habits.length) {
      _cache._logger.error(
          'performMove: $toPosition is strictly higher than '
          '${data.habits.length}');
      checkedToPosition = data.habits.length;
    } else {
      checkedToPosition = toPosition;
    }

    data.habits.insert(checkedToPosition, habit);
    _cache._listener.onItemMoved(fromPosition, checkedToPosition);
  }

  void _performUpdate(int id, int position) {
    final data = _cache._data;
    final oldScore = data.scores[id]!;
    final oldCheckmarks = data.checkmarks[id];
    final oldNoteIndicators = data.notes[id];
    final newScore = _newData.scores[id]!;
    final newCheckmarks = _newData.checkmarks[id]!;
    final newNoteIndicators = _newData.notes[id]!;
    var unchanged = true;
    if (oldScore != newScore) unchanged = false;
    if (!_contentEquals<int>(oldCheckmarks, newCheckmarks)) unchanged = false;
    if (!_contentEquals<String>(oldNoteIndicators, newNoteIndicators)) {
      unchanged = false;
    }
    if (unchanged) return;
    data.scores[id] = newScore;
    data.checkmarks[id] = newCheckmarks;
    data.notes[id] = newNoteIndicators;
    _cache._listener.onItemChanged(position);
  }

  void _processPosition(int currentPosition) {
    final data = _cache._data;
    final habit = _newData.habits[currentPosition];
    final id = habit.id;
    final prevPosition = data.habits.indexOf(habit);
    if (prevPosition < 0) {
      _performInsert(habit, currentPosition);
    } else {
      if (prevPosition != currentPosition) {
        _performMove(habit, prevPosition, currentPosition);
      }
      if (id == null) throw StateError('Null check operator used on a null id');
      _performUpdate(id, currentPosition);
    }
  }

  void _processRemovedHabits() {
    final data = _cache._data;
    final before = data.idToHabit.keys.toSet();
    final after = _newData.idToHabit.keys.toSet();
    final removed = before.difference(after);
    for (final id in removed) {
      _cache.remove(id);
    }
  }

  /// Kotlin's `IntArray?.contentEquals(IntArray?)`: a null receiver never
  /// equals a non-null argument.
  static bool _contentEquals<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
