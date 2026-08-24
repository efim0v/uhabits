/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCache.kt
/// (plus .../models/EntryList.kt) and its Kotlin test
/// .../commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/HabitCardListCacheTest.kt.
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_matcher.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Stands in for mokkery's `mock<HabitCardListCache.Listener>()`.
///
/// Records every callback as a string so that a whole sequence can be compared
/// at once — the Dart equivalent of `verify { ... }` followed by
/// `verifyNoMoreCalls(listener)`.
class _RecordingListener extends HabitCardListCacheListener {
  final List<String> calls = <String>[];

  @override
  void onItemChanged(int position) => calls.add('onItemChanged($position)');

  @override
  void onItemInserted(int position) => calls.add('onItemInserted($position)');

  @override
  void onItemMoved(int oldPosition, int newPosition) =>
      calls.add('onItemMoved($oldPosition,$newPosition)');

  @override
  void onItemRemoved(int position) => calls.add('onItemRemoved($position)');

  @override
  void onRefreshFinished() => calls.add('onRefreshFinished()');

  void reset() => calls.clear();
}

/// A [_RecordingListener] that also samples what the cache actually holds at
/// the instant `onRefreshFinished` fires.
///
/// `onRefreshFinished` is the cache's "the list is now up to date" signal — the
/// adapter turns it straight into `notifyListeners()` — so whatever the cache
/// holds at that moment is what the view is asked to redraw.
class _SamplingListener extends _RecordingListener {
  _SamplingListener(this.cacheOf);

  final HabitCardListCache Function() cacheOf;

  /// One entry per `onRefreshFinished`: today's checkmark for the sampled id.
  final List<int> checkmarksAtRefreshFinished = <int>[];

  int? sampledId;

  @override
  void onRefreshFinished() {
    final id = sampledId;
    if (id != null) {
      checkmarksAtRefreshFinished.add(cacheOf().getCheckmarks(id)[0]);
    }
    super.onRefreshFinished();
  }
}

/// Captures what the cache logs, so the `performMove` workaround for upstream
/// issue 968 can be observed.
class _CapturingLogging implements Logging {
  final List<String> errors = <String>[];

  @override
  Logger getLogger(String name) => _CapturingLogger(errors);
}

class _CapturingLogger implements Logger {
  _CapturingLogger(this.errors);

  final List<String> errors;

  @override
  void debug(String msg) {}

  @override
  void info(String msg) {}

  @override
  void error(Object msgOrException, [StackTrace? stackTrace]) {
    errors.add(msgOrException.toString());
  }
}

/// A [TaskRunner] that never runs anything by itself.
///
/// The Kotlin unit tests build a `CoroutineTaskRunner` from two
/// `UnconfinedTestDispatcher`s, so every task completes inside `execute()` and
/// a cancellation can never be observed. This runner keeps the tasks so a test
/// can decide when — and whether — each one runs.
class _ManualTaskRunner implements TaskRunner {
  final List<Task> tasks = <Task>[];

  @override
  void execute(Task task) {
    task.onAttached(this);
    tasks.add(task);
  }

  /// The prologue/background/epilogue pipeline of `CoroutineTaskRunner`, run
  /// synchronously.
  void runTask(Task task) {
    task.onPreExecute();
    if (!task.isCanceled()) {
      final FutureOr<void> result = task.doInBackground();
      if (result is Future<void>) {
        throw StateError('RefreshTask must not suspend');
      }
    }
    task.onPostExecute();
  }

  @override
  void publishProgress(Task task, int progress) =>
      task.onProgressUpdate(progress);

  @override
  void addListener(TaskRunnerListener listener) {}

  @override
  void removeListener(TaskRunnerListener listener) {}

  @override
  int get activeTaskCount => 0;

  @override
  Future<void> awaitAll() async {}
}

void main() {
  // BaseUnitTest.setUp
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late MemoryModelFactory modelFactory;
  late TaskRunner taskRunner;
  late CommandRunner commandRunner;

  // HabitCardListCacheTest.setUp
  late HabitCardListCache cache;
  late _RecordingListener listener;
  late _CapturingLogging logging;

  final today = LocalDate.ymd(2015, 1, 25);

  setUp(() {
    setToday(today);
    modelFactory = MemoryModelFactory();
    habitList = modelFactory.buildHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = CommandRunner(taskRunner);

    habitList.removeAll();
    for (var i = 0; i <= 9; i++) {
      if (i == 3) {
        habitList.add(fixtures.createLongHabit());
      } else {
        habitList.add(fixtures.createShortHabit());
      }
    }
    logging = _CapturingLogging();
    cache = HabitCardListCache(habitList, commandRunner, taskRunner, logging);
    cache.setCheckmarkCount(10);
    cache.refreshAllHabits();
    cache.onAttached();
    listener = _RecordingListener();
    cache.setListener(listener);
  });

  tearDown(() {
    cache.onDetached();
    resetToday();
  });

  // -------------------------------------------------------------------------
  // #1, #3, #15 — what the cache holds, and how it is filled
  // -------------------------------------------------------------------------

  test('holds habits, scores, checkmarks and notes per habit id', () {
    expect(cache.habitCount, 10,
        reason: 'list-habits.card-list-cache#1: the cache holds the ordered '
            'list of habits');
    for (var i = 0; i < 10; i++) {
      expect(identical(cache.getHabitByPosition(i), habitList.getByPosition(i)),
          isTrue,
          reason: 'list-habits.card-list-cache#1: the cached habit list keeps '
              'the order of the filtered list');
    }

    final h = habitList.getByPosition(3);
    expect(cache.getScore(h.id!), isA<double>(),
        reason: 'list-habits.card-list-cache#1: a Double score per habit id');
    expect(cache.getCheckmarks(h.id!), isA<List<int>>(),
        reason: 'list-habits.card-list-cache#1: an int array of entry values '
            'per habit id');
    expect(cache.getNotes(h.id!), isA<List<String>>(),
        reason: 'list-habits.card-list-cache#1: a string array of notes per '
            'habit id');

    expect(cache.getScore(h.id!), h.scores[today].value,
        reason: 'list-habits.card-list-cache#3: score is '
            'habit.scores[today].value');

    final expectedEntries = h.computedEntries.getByInterval(today.minus(9), today);
    expect(cache.getCheckmarks(h.id!),
        expectedEntries.map((e) => e.value).toList(),
        reason: 'list-habits.card-list-cache#3: entries are read over the '
            'closed interval [today - (checkmarkCount - 1), today]');
    expect(cache.getNotes(h.id!), expectedEntries.map((e) => e.notes).toList(),
        reason: 'list-habits.card-list-cache#3: notes come from the same '
            'interval as the checkmarks');
    expect(cache.getCheckmarks(h.id!)[0], h.computedEntries.get(today).value,
        reason: 'list-habits.card-list-cache#3: index 0 of the arrays is today');
    expect(cache.getCheckmarks(h.id!)[4],
        h.computedEntries.get(today.minus(4)).value,
        reason: 'list-habits.card-list-cache#3: index i is today - i days');
  });

  test('getHabitByPosition returns null outside the list', () {
    expect(cache.getHabitByPosition(-1), isNull,
        reason: 'list-habits.card-list-cache#15: null when position < 0');
    expect(cache.getHabitByPosition(10), isNull,
        reason: 'list-habits.card-list-cache#15: null when position >= '
            'habitCount');
    expect(cache.getHabitByPosition(9), isNotNull,
        reason: 'list-habits.card-list-cache#15: the last valid position is '
            'habitCount - 1');
  });

  test('a full refresh skips habits whose id is null', () {
    final list = modelFactory.buildHabitList();
    final localFixtures = HabitFixtures(modelFactory, list);
    list.add(localFixtures.createShortHabit());
    final orphan = localFixtures.createShortHabit();
    orphan.name = 'Zebra';
    list.add(orphan);
    orphan.id = null;

    final localCache =
        HabitCardListCache(list, commandRunner, taskRunner, logging);
    localCache.setCheckmarkCount(10);
    localCache.refreshAllHabits();

    expect(localCache.habitCount, 1,
        reason: 'list-habits.card-list-cache#3: a full refresh skips any habit '
            'whose id is null');
  });

  // -------------------------------------------------------------------------
  // #2 — setCheckmarkCount
  // -------------------------------------------------------------------------

  test('setCheckmarkCount stores n and sizes the fetched interval', () {
    final h = habitList.getByPosition(3);
    expect(cache.getCheckmarks(h.id!).length, 10,
        reason: 'list-habits.card-list-cache#2: setCheckmarkCount(n) stores n');

    cache.setCheckmarkCount(5);
    cache.refreshAllHabits();
    expect(cache.getCheckmarks(h.id!).length, 5,
        reason: 'list-habits.card-list-cache#2: setCheckmarkCount(n) stores n');
    expect(cache.getCheckmarks(h.id!),
        h.computedEntries.getByInterval(today.minus(4), today)
            .map((e) => e.value)
            .toList(),
        reason: 'list-habits.card-list-cache#2: the stored n is the one the '
            'next refresh reads with');

    cache.setCheckmarkCount(60);
    cache.refreshAllHabits();
    expect(cache.getCheckmarks(h.id!).length, 60,
        reason: 'list-habits.card-list-cache#2: the list screen always calls '
            'setCheckmarkCount(60)');
  });

  // -------------------------------------------------------------------------
  // #4 — the defaults used when a habit has no previously cached data
  // -------------------------------------------------------------------------

  test('a habit with no cached data gets default score, checkmarks and notes',
      () {
    final blank = HabitCardListCache(
        habitList, commandRunner, taskRunner, logging)
      ..setCheckmarkCount(7);

    final oldData = CacheData(blank);
    final newData = CacheData(blank)..fetchHabits();
    newData
      ..copyScoresFrom(oldData)
      ..copyCheckmarksFrom(oldData)
      ..copyNoteIndicatorsFrom(oldData);

    final id = habitList.getByPosition(0).id!;
    expect(newData.scores[id], 0.0,
        reason: 'list-habits.card-list-cache#4: default score is 0.0');
    expect(newData.checkmarks[id], List<int>.filled(7, 0),
        reason: 'list-habits.card-list-cache#4: default checkmark array has '
            'length checkmarkCount, filled with 0');
    expect(newData.notes[id], List<String>.filled(8, ''),
        reason: 'list-habits.card-list-cache#4: default notes array has length '
            'checkmarkCount + 1 filled with empty strings (upstream '
            'off-by-one)');
  });

  // -------------------------------------------------------------------------
  // #5, #20 — task lifecycle
  // -------------------------------------------------------------------------

  test('refreshAllHabits cancels the in-flight task; refreshHabit does not',
      () {
    final manual = _ManualTaskRunner();
    final localListener = _RecordingListener();
    final localCache =
        HabitCardListCache(habitList, commandRunner, manual, logging)
          ..setCheckmarkCount(10)
          ..setListener(localListener);

    localCache.refreshAllHabits();
    localCache.refreshAllHabits();
    expect(manual.tasks.length, 2,
        reason: 'list-habits.card-list-cache#20: refreshAllHabits() starts a '
            'new full RefreshTask');

    manual.runTask(manual.tasks[0]);
    expect(localListener.calls, <String>['onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#5: refreshAllHabits() cancels any '
            'in-flight refresh task before starting a new one, so the '
            'cancelled task inserts nothing');

    localListener.reset();
    manual.runTask(manual.tasks[1]);
    expect(localListener.calls.where((c) => c.startsWith('onItemInserted')).length,
        10,
        reason: 'list-habits.card-list-cache#20: the newly started task is not '
            'cancelled and populates the cache');

    // refreshHabit cancels nothing.
    final manual2 = _ManualTaskRunner();
    final listener2 = _RecordingListener();
    final cache2 = HabitCardListCache(habitList, commandRunner, manual2, logging)
      ..setCheckmarkCount(10)
      ..setListener(listener2);
    cache2.refreshAllHabits();
    cache2.refreshHabit(habitList.getByPosition(0).id!);
    manual2.runTask(manual2.tasks[0]);
    expect(listener2.calls.where((c) => c.startsWith('onItemInserted')).length,
        10,
        reason: 'list-habits.card-list-cache#20: refreshHabit(id) starts a '
            'RefreshTask without cancelling anything');
  });

  test('refreshHabit recomputes only the habit with that id', () {
    final h2 = habitList.getByPosition(2);
    final h5 = habitList.getByPosition(5);
    for (final h in <Habit>[h2, h5]) {
      h.originalEntries.add(Entry(today, Entry.no));
      h.recompute();
    }

    cache.refreshHabit(h2.id!);

    expect(listener.calls, <String>['onItemChanged(2)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#5: refreshHabit(id) recomputes '
            'only the habit with that id and leaves every other row untouched');
    expect(cache.getCheckmarks(h5.id!)[0],
        isNot(h5.computedEntries.get(today).value),
        reason: 'list-habits.card-list-cache#5: the other rows keep their stale '
            'cached values');
  });

  // -------------------------------------------------------------------------
  // #6, #19 — onCommandFinished dispatch
  // -------------------------------------------------------------------------

  test('onCommandFinished refreshes one habit for CreateRepetitionCommand and '
      'the whole list otherwise', () {
    final h2 = habitList.getByPosition(2);
    final h5 = habitList.getByPosition(5);
    for (final h in <Habit>[h2, h5]) {
      h.originalEntries.add(Entry(today, Entry.no));
      h.recompute();
    }

    cache.onCommandFinished(
        CreateRepetitionCommand(habitList, h2, today, Entry.no, ''));
    expect(listener.calls, <String>['onItemChanged(2)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#6: a CreateRepetitionCommand '
            'refreshes only that command\'s habit');
    expect(listener.calls, <String>['onItemChanged(2)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#19: `command is '
            'CreateRepetitionCommand` calls refreshHabit(command.habit.id)');

    listener.reset();
    cache.onCommandFinished(DeleteHabitsCommand(habitList, <Habit>[]));
    expect(listener.calls, <String>['onItemChanged(5)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#6: every other command type '
            'refreshes the whole list');
    expect(listener.calls, <String>['onItemChanged(5)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#19: for EVERY other command type '
            'it calls refreshAllHabits()');
  });

  test('onCommandFinished does nothing when the repetition habit has no id',
      () {
    final orphan = fixtures.createShortHabit();
    expect(orphan.id, isNull,
        reason: 'list-habits.card-list-cache#19: the fixture is not registered '
            'in a habit list, so its id is null');

    cache.onCommandFinished(
        CreateRepetitionCommand(habitList, orphan, today, Entry.no, ''));

    expect(listener.calls, isEmpty,
        reason: 'list-habits.card-list-cache#19: '
            '`command.habit.id?.let { refreshHabit(it) }` does nothing at all '
            'if the habit id is null');
  });

  // -------------------------------------------------------------------------
  // #7 — the removed-habits pass
  // -------------------------------------------------------------------------

  test('refresh removes habits that disappeared from the list', () {
    habitList.remove(habitList.getByPosition(0));
    habitList.remove(habitList.getByPosition(3));
    cache.refreshAllHabits();

    expect(
        listener.calls,
        <String>[
          'onItemRemoved(0)',
          'onItemRemoved(3)',
          'onRefreshFinished()',
        ],
        reason: 'list-habits.card-list-cache#7: every id present in the old '
            'data but absent from the new data is removed and '
            'onItemRemoved(oldPosition) is fired for each, before anything '
            'else');
    expect(cache.habitCount, 8,
        reason: 'list-habits.card-list-cache#7: the removed habits are gone '
            'from the cache');
  });

  // -------------------------------------------------------------------------
  // #8 — insert / move
  // -------------------------------------------------------------------------

  test('refresh inserts habits that are new to the cache', () {
    habitList.add(fixtures.createEmptyHabit(name: 'Aardvark'));
    cache.refreshAllHabits();

    expect(listener.calls, <String>['onItemInserted(0)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#8: a habit not in the old data is '
            'inserted at that position and onItemInserted(position) fires');
    expect(cache.getHabitByPosition(0)!.name, 'Aardvark',
        reason: 'list-habits.card-list-cache#8: the habit is inserted at the '
            'new position');
  });

  test('refresh moves habits whose index changed, one step at a time', () {
    final h2 = habitList.getByPosition(2);
    final h3 = habitList.getByPosition(3);
    final h7 = habitList.getByPosition(7);
    habitList.reorder(h2, h7);
    cache.refreshAllHabits();

    expect(
        listener.calls,
        <String>[
          'onItemMoved(3,2)',
          'onItemMoved(4,3)',
          'onItemMoved(5,4)',
          'onItemMoved(6,5)',
          'onItemMoved(7,6)',
          'onRefreshFinished()',
        ],
        reason: 'list-habits.card-list-cache#8: when the old index differs from '
            'the new index the habit is moved and onItemMoved(oldIndex, '
            'newIndex) fires');
    expect(cache.getHabitByPosition(2), h3,
        reason: 'list-habits.card-list-cache#8: the cached order matches the '
            'new list order');
    expect(cache.getHabitByPosition(6), h7,
        reason: 'list-habits.card-list-cache#8: the cached order matches the '
            'new list order');
    expect(cache.getHabitByPosition(7), h2,
        reason: 'list-habits.card-list-cache#8: the cached order matches the '
            'new list order');
  });

  // -------------------------------------------------------------------------
  // #9, #13 — the update check and onRefreshFinished
  // -------------------------------------------------------------------------

  test('refresh with no changes only fires onRefreshFinished', () {
    cache.refreshAllHabits();
    expect(listener.calls, <String>['onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#9: if the score, the checkmarks '
            'and the notes are all unchanged no listener call is made');
    expect(listener.calls, <String>['onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#13: onRefreshFinished() fires '
            'once at the end of every refresh task');
  });

  test('onItemChanged fires when the score, the checkmarks or the notes differ',
      () {
    final h1 = habitList.getByPosition(1);
    h1.originalEntries.add(Entry(today, Entry.no));
    h1.recompute();
    cache.refreshAllHabits();
    expect(listener.calls, <String>['onItemChanged(1)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#9: onItemChanged(position) fires '
            'when the checkmark array differs from the cached value');

    listener.reset();
    final h4 = habitList.getByPosition(4);
    h4.originalEntries.add(Entry(
        today, h4.computedEntries.get(today).value,
        notes: 'a brand new note'));
    h4.recompute();
    cache.refreshAllHabits();
    expect(listener.calls, <String>['onItemChanged(4)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#9: onItemChanged(position) fires '
            'when only the notes array differs from the cached value');

    listener.reset();
    cache.refreshAllHabits();
    expect(listener.calls, <String>['onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#13: onRefreshFinished() fires '
            'after all incremental notifications, once per refresh task');
  });

  // -------------------------------------------------------------------------
  // #10 — the performMove clamp (upstream issue 968)
  // -------------------------------------------------------------------------

  test('performMove clamps a destination past the end of the list', () {
    final list = modelFactory.buildHabitList();
    final localFixtures = HabitFixtures(modelFactory, list);
    list.add(localFixtures.createShortHabit());
    final second = localFixtures.createShortHabit();
    second.name = 'Zebra';
    list.add(second);

    final localListener = _RecordingListener();
    final localLogging = _CapturingLogging();
    final localCache =
        HabitCardListCache(list, commandRunner, taskRunner, localLogging)
          ..setCheckmarkCount(10);
    localCache.refreshAllHabits();
    localCache.setListener(localListener);

    // Optimistically drop the first row, so the cache is one habit shorter
    // than the list. The targeted refresh then wants to move the surviving
    // habit to index 1 of a zero-length list.
    localCache.remove(list.getByPosition(0).id!);
    localListener.reset();
    localCache.refreshHabit(second.id!);

    expect(localListener.calls.first, 'onItemMoved(0,0)',
        reason: 'list-habits.card-list-cache#10: performMove clamps the '
            'destination index to data.habits.size when the requested '
            'destination is strictly greater than the list size');
    expect(localLogging.errors,
        contains('performMove: 1 is strictly higher than 0'),
        reason: 'list-habits.card-list-cache#10: the clamp logs an error '
            '(workaround for upstream issue 968)');
  });

  // -------------------------------------------------------------------------
  // #11, #23 — remove(id)
  // -------------------------------------------------------------------------

  test('remove(id) on an unknown id is a no-op', () {
    cache.remove(999999);
    expect(listener.calls, isEmpty,
        reason: 'list-habits.card-list-cache#11: remove(id) on an id not '
            'present in the cache is a no-op');
    expect(cache.habitCount, 10,
        reason: 'list-habits.card-list-cache#11: remove(id) on an id not '
            'present in the cache leaves the list untouched');
    expect(cache.habitCount, 10,
        reason: 'list-habits.card-list-cache#23: remove() is a no-op if the id '
            'is unknown');
  });

  test('remove(id) drops the habit and all of its cached data', () {
    final h = habitList.getByPosition(3);
    final id = h.id!;
    cache.remove(id);

    expect(listener.calls, <String>['onItemRemoved(3)'],
        reason: 'list-habits.card-list-cache#11: remove(id) deletes the habit '
            'and fires onItemRemoved(position)');
    expect(cache.habitCount, 9,
        reason: 'list-habits.card-list-cache#23: remove() drops the habit from '
            'data.habits');
    expect(cache.getHabitByPosition(3), isNot(h),
        reason: 'list-habits.card-list-cache#23: remove() drops the habit from '
            'data.idToHabit');
    expect(() => cache.getCheckmarks(id), throwsA(isA<TypeError>()),
        reason: 'list-habits.card-list-cache#11: remove(id) deletes the '
            'habit\'s checkmarks');
    expect(() => cache.getNotes(id), throwsA(isA<TypeError>()),
        reason: 'list-habits.card-list-cache#11: remove(id) deletes the '
            'habit\'s notes');
    expect(() => cache.getScore(id), throwsA(isA<TypeError>()),
        reason: 'list-habits.card-list-cache#23: remove() drops the habit from '
            'checkmarks, notes and scores');
  });

  // -------------------------------------------------------------------------
  // #12 — reorder
  // -------------------------------------------------------------------------

  test('reorder moves a habit inside the cache only', () {
    final h2 = cache.getHabitByPosition(2);
    final h3 = cache.getHabitByPosition(3);
    final h7 = cache.getHabitByPosition(7);
    final listOrderBefore = habitList.toList();

    cache.reorder(2, 7);

    expect(cache.getHabitByPosition(2), h3,
        reason: 'list-habits.card-list-cache#12: reorder(from, to) removes the '
            'habit at index from');
    expect(cache.getHabitByPosition(6), h7,
        reason: 'list-habits.card-list-cache#12: reorder(from, to) re-inserts '
            'it at index to');
    expect(cache.getHabitByPosition(7), h2,
        reason: 'list-habits.card-list-cache#12: reorder(from, to) re-inserts '
            'it at index to');
    expect(listener.calls, <String>['onItemMoved(2,7)'],
        reason: 'list-habits.card-list-cache#12: reorder(from, to) fires '
            'onItemMoved(from, to)');
    expect(habitList.toList(), listOrderBefore,
        reason: 'list-habits.card-list-cache#12: reorder does not touch the '
            'database — the underlying habit list is untouched');
  });

  // -------------------------------------------------------------------------
  // #14 — hasNoHabit ignores the filter
  // -------------------------------------------------------------------------

  test('hasNoHabit looks at the unfiltered list', () {
    expect(cache.hasNoHabit(), isFalse,
        reason: 'list-habits.card-list-cache#14: hasNoHabit() is false while '
            'the unfiltered habit list has habits');

    cache.setFilter(const HabitMatcher(isReminderRequired: true));
    cache.refreshAllHabits();
    expect(cache.habitCount, 0,
        reason: 'list-habits.card-list-cache#14: the filter empties the cached '
            'list');
    expect(cache.hasNoHabit(), isFalse,
        reason: 'list-habits.card-list-cache#14: hasNoHabit() ignores the '
            'active filter');

    habitList.removeAll();
    expect(cache.hasNoHabit(), isTrue,
        reason: 'list-habits.card-list-cache#14: hasNoHabit() returns true when '
            'the unfiltered habit list is empty');
  });

  // -------------------------------------------------------------------------
  // #16 — order setters
  // -------------------------------------------------------------------------

  test('setting primaryOrder or secondaryOrder assigns both lists and '
      'refreshes', () {
    cache.setFilter(const HabitMatcher(isArchivedAllowed: true));
    listener.reset();

    cache.primaryOrder = HabitListOrder.byNameDesc;
    expect(habitList.primaryOrder, HabitListOrder.byNameDesc,
        reason: 'list-habits.card-list-cache#16: the order is assigned to the '
            'unfiltered list');
    expect(cache.primaryOrder, HabitListOrder.byNameDesc,
        reason: 'list-habits.card-list-cache#16: the order is assigned to the '
            'filtered list, which the getter reads');
    expect(listener.calls, contains('onRefreshFinished()'),
        reason: 'list-habits.card-list-cache#16: setting primaryOrder triggers '
            'a full refresh');

    listener.reset();
    cache.secondaryOrder = HabitListOrder.byColorAsc;
    expect(habitList.secondaryOrder, HabitListOrder.byColorAsc,
        reason: 'list-habits.card-list-cache#16: the order is assigned to the '
            'unfiltered list');
    expect(cache.secondaryOrder, HabitListOrder.byColorAsc,
        reason: 'list-habits.card-list-cache#16: the order is assigned to the '
            'filtered list, which the getter reads');
    expect(listener.calls, contains('onRefreshFinished()'),
        reason: 'list-habits.card-list-cache#16: setting secondaryOrder '
            'triggers a full refresh');
  });

  // -------------------------------------------------------------------------
  // #17 — setFilter does not refresh
  // -------------------------------------------------------------------------

  test('setFilter replaces the filtered list without refreshing', () {
    habitList.getByPosition(9).isArchived = true;

    cache.setFilter(const HabitMatcher());
    expect(listener.calls, isEmpty,
        reason: 'list-habits.card-list-cache#17: setFilter(matcher) does NOT '
            'refresh by itself');
    expect(cache.habitCount, 10,
        reason: 'list-habits.card-list-cache#17: the cached rows are unchanged '
            'until the caller refreshes');

    cache.refreshAllHabits();
    expect(cache.habitCount, 9,
        reason: 'list-habits.card-list-cache#17: setFilter replaces the '
            'filtered list with allHabits.getFiltered(matcher); the caller '
            'must call refresh()');
    expect(listener.calls, contains('onItemRemoved(9)'),
        reason: 'list-habits.card-list-cache#17: the filtered-out habit is only '
            'dropped once refresh() runs');
  });

  // -------------------------------------------------------------------------
  // #18, #21, #22 — the CommandRunner subscription
  // -------------------------------------------------------------------------

  test('the cache subscribes in onAttached and unsubscribes in onDetached', () {
    expect(cache, isA<CommandRunnerListener>(),
        reason: 'list-habits.card-list-cache#18: HabitCardListCache implements '
            'CommandRunner.Listener');

    final h = habitList.getByPosition(0);
    commandRunner.run(DeleteHabitsCommand(habitList, <Habit>[h]));
    expect(listener.calls, contains('onRefreshFinished()'),
        reason: 'list-habits.card-list-cache#18: it subscribes in onAttached()');

    cache.onDetached();
    listener.reset();
    commandRunner
        .run(DeleteHabitsCommand(habitList, <Habit>[habitList.getByPosition(0)]));
    expect(listener.calls, isEmpty,
        reason: 'list-habits.card-list-cache#18: it unsubscribes in '
            'onDetached()');

    cache.onAttached();
  });

  test('testCommandListener_single', () {
    final h2 = habitList.getByPosition(2);
    commandRunner.run(CreateRepetitionCommand(habitList, h2, today, Entry.no, ''));

    expect(listener.calls, <String>['onItemChanged(2)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#21: running CreateRepetitionCommand '
            'on the habit at position 2 produces exactly onItemChanged(2) and '
            'onRefreshFinished() and no other listener callbacks');
  });

  // The same targeted refresh, seen from the row that toggled: every other
  // row keeps the values it already had cached.
  test('a toggle refreshes only the habit it touched', () {
    final h2 = habitList.getByPosition(2);
    final others = <int, List<int>>{
      for (var i = 0; i < 10; i++)
        if (i != 2)
          habitList.getByPosition(i).id!:
              List<int>.of(cache.getCheckmarks(habitList.getByPosition(i).id!)),
    };

    commandRunner.run(
      CreateRepetitionCommand(habitList, h2, today, Entry.no, ''),
    );

    expect(cache.getCheckmarks(h2.id!)[0], Entry.no,
        reason: 'list-habits.toggle-from-row#3: the toggled habit is the one '
            'that was refreshed');
    expect(listener.calls, <String>['onItemChanged(2)', 'onRefreshFinished()'],
        reason: 'list-habits.toggle-from-row#3: after a CreateRepetitionCommand '
            'the cache refreshes only that one habit');
    others.forEach((id, values) {
      expect(cache.getCheckmarks(id), values,
          reason: 'list-habits.toggle-from-row#3: so other rows keep their '
              'cached values');
    });
  });

  // -------------------------------------------------------------------------
  // #13 under the production wiring: two AsyncDispatchers, which is what
  // AppScope.open builds. Kotlin posts publishProgress and the continuation of
  // `withContext(ioDispatcher)` to the same FIFO main queue, so the
  // incremental notifications always land before onPostExecute.
  // -------------------------------------------------------------------------

  test('onRefreshFinished comes last when the runner actually defers',
      () async {
    final asyncRunner = CoroutineTaskRunner(
      mainDispatcher: const AsyncDispatcher(),
      ioDispatcher: const AsyncDispatcher(),
    );
    final asyncCache = HabitCardListCache(
        habitList, CommandRunner(asyncRunner), asyncRunner, logging);
    asyncCache.setCheckmarkCount(10);
    asyncCache.onAttached();
    await asyncRunner.awaitAll();
    await Future<void>.delayed(Duration.zero);

    final sampling = _SamplingListener(() => asyncCache);
    asyncCache.setListener(sampling);

    final h2 = habitList.getByPosition(2);
    sampling.sampledId = h2.id;
    h2.originalEntries.add(Entry(today, Entry.no));
    h2.recompute();
    asyncCache.refreshHabit(h2.id!);
    await asyncRunner.awaitAll();
    await Future<void>.delayed(Duration.zero);

    expect(sampling.calls, <String>['onItemChanged(2)', 'onRefreshFinished()'],
        reason: 'audit10.task-runner-progress-before-post#1: publishProgress '
            'and the post-background continuation share the main queue, so '
            'onRefreshFinished fires after every incremental notification '
            '(list-habits.card-list-cache#13) even when the task runner really '
            'defers.');
    expect(sampling.checkmarksAtRefreshFinished, <int>[Entry.no],
        reason: 'audit10.task-runner-progress-before-post#1: the cache is '
            'already up to date when it announces that it is, so the rebuild '
            'the adapter triggers never draws the pre-refresh checkmarks.');

    asyncCache.onDetached();
  });

  test('testCommandListener_all', () {
    expect(cache.habitCount, 10,
        reason: 'list-habits.card-list-cache#22: cache.habitCount starts at 10');
    final h = habitList.getByPosition(0);
    commandRunner.run(DeleteHabitsCommand(habitList, <Habit>[h]));

    expect(listener.calls, <String>['onItemRemoved(0)', 'onRefreshFinished()'],
        reason: 'list-habits.card-list-cache#22: running DeleteHabitsCommand on '
            'the habit at position 0 produces onItemRemoved(0) and '
            'onRefreshFinished()');
    expect(cache.habitCount, 9,
        reason: 'list-habits.card-list-cache#22: cache.habitCount drops from 10 '
            'to 9');
  });
}
