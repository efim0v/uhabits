/// Ported from
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardListController.kt
/// and .../views/HabitCardListAdapter.kt, with the contextual-action-bar
/// contract read off .../list/ListHabitsSelectionMenu.kt.
///
/// There is no Kotlin unit test for either class (both live in the Android
/// source set); the expectations below are derived from the parity rules of
/// `list-habits.selection-mode` and `list-habits.adapter`, and every `expect`
/// carries the rule id it exercises.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_observable.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_adapter.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_controller.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart';
import 'package:uhabits_core/src/utils/midnight_timer.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _NullLogging implements Logging {
  @override
  Logger getLogger(String name) => _NullLogger();
}

class _NullLogger implements Logger {
  @override
  void debug(String msg) {}

  @override
  void info(String msg) {}

  @override
  void error(Object msgOrException, [StackTrace? stackTrace]) {}
}

/// Stands in for the RecyclerView notifications the Android adapter issues:
/// `notifyItemChanged`, `notifyItemInserted`, `notifyItemMoved`,
/// `notifyItemRemoved` and `notifyDataSetChanged`.
class _RecordingAdapterListener implements HabitCardListAdapterListener {
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
  void onDataSetChanged() => calls.add('onDataSetChanged()');

  void reset() => calls.clear();
}

/// Records every call the adapter makes into the cache, so the construction
/// sequence of `list-habits.adapter#2` can be asserted in order.
class _SpyCache extends HabitCardListCache {
  _SpyCache(
    super.habits,
    super.commandRunner,
    super.taskRunner,
    super.logging,
  );

  final List<String> calls = <String>[];

  @override
  void setListener(HabitCardListCacheListener listener) {
    calls.add('setListener');
    super.setListener(listener);
  }

  @override
  void setCheckmarkCount(int checkmarkCount) {
    calls.add('setCheckmarkCount($checkmarkCount)');
    super.setCheckmarkCount(checkmarkCount);
  }

  @override
  set primaryOrder(HabitListOrder order) {
    calls.add('primaryOrder=${order.name}');
    super.primaryOrder = order;
  }

  @override
  set secondaryOrder(HabitListOrder order) {
    calls.add('secondaryOrder=${order.name}');
    super.secondaryOrder = order;
  }

  @override
  void refreshAllHabits() {
    calls.add('refreshAllHabits');
    super.refreshAllHabits();
  }

  @override
  void reorder(int from, int to) {
    calls.add('reorder($from,$to)');
    super.reorder(from, to);
  }

  @override
  void remove(int id) {
    calls.add('remove($id)');
    super.remove(id);
  }

  @override
  void cancelTasks() {
    calls.add('cancelTasks');
    super.cancelTasks();
  }

  @override
  void onAttached() {
    calls.add('onAttached');
    super.onAttached();
  }

  @override
  void onDetached() {
    calls.add('onDetached');
    super.onDetached();
  }

  void reset() => calls.clear();
}

class _SpyMidnightTimer extends MidnightTimer {
  _SpyMidnightTimer(super.logging, super.preferences);

  final List<MidnightListener> listeners = <MidnightListener>[];

  @override
  void addListener(MidnightListener listener) {
    listeners.add(listener);
    super.addListener(listener);
  }

  @override
  bool removeListener(MidnightListener listener) {
    listeners.remove(listener);
    return super.removeListener(listener);
  }

  /// Drives what `MidnightTimer._notifyListeners` would do at 00:00.
  void fire() {
    for (final l in List<MidnightListener>.of(listeners)) {
      l.atMidnight();
    }
  }
}

class _SpyCommandRunner extends CommandRunner {
  _SpyCommandRunner(super.taskRunner);

  final List<CommandRunnerListener> listeners = <CommandRunnerListener>[];

  @override
  void addListener(CommandRunnerListener l) {
    listeners.add(l);
    super.addListener(l);
  }

  @override
  void removeListener(CommandRunnerListener l) {
    listeners.remove(l);
    super.removeListener(l);
  }
}

/// Stands in for `ListHabitsSelectionMenu`, whose three entry points are the
/// only part of the Android contextual action bar the controller can see.
class _RecordingSelectionMenu implements HabitCardListSelectionMenu {
  final List<String> calls = <String>[];

  @override
  void onSelectionStart() => calls.add('onSelectionStart');

  @override
  void onSelectionChange() => calls.add('onSelectionChange');

  @override
  void onSelectionFinish() => calls.add('onSelectionFinish');

  void reset() => calls.clear();
}

class _FakeScreen implements ListHabitsBehaviorScreen {
  final List<Habit> habitScreens = <Habit>[];

  @override
  void showHabitScreen(Habit h) => habitScreens.add(h);

  @override
  void showIntroScreen() {}

  @override
  void showMessage(ListHabitsBehaviorMessage m) {}

  @override
  void showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) {}

  @override
  void showCheckmarkPopup(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  ) {}

  @override
  void showSendBugReportToDeveloperScreen(String log) {}

  @override
  void showSendFileScreen(String filename) {}

  @override
  void showConfetti(PaletteColor color, double x, double y) {}
}

class _FakeDirFinder implements ListHabitsBehaviorDirFinder {
  @override
  UserFile getCSVOutputDir() => throw UnimplementedError();
}

class _FakeBugReporter implements ListHabitsBehaviorBugReporter {
  @override
  void dumpBugReportToFile() {}

  @override
  String getBugReport() => '';
}

class _ObservableCounter implements ModelObservableListener {
  int count = 0;

  @override
  void onModelChange() => count++;
}

void main() {
  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late TaskRunner taskRunner;
  late _SpyCommandRunner commandRunner;
  late MemoryStorage prefsStorage;
  late Preferences prefs;
  late _NullLogging logging;
  late _SpyCache cache;
  late _SpyMidnightTimer midnightTimer;
  late HabitCardListAdapter adapter;
  late _RecordingAdapterListener adapterListener;

  late _FakeScreen screen;
  late ListHabitsBehavior behavior;
  late _RecordingSelectionMenu selectionMenu;
  late HabitCardListController controller;

  final today = LocalDate.ymd(2015, 1, 25);

  /// Everything except the controller: the adapter tests do not need one.
  void buildAdapter() {
    setToday(today);
    modelFactory = MemoryModelFactory();
    habitList = modelFactory.buildHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    commandRunner = _SpyCommandRunner(taskRunner);
    habitList.removeAll();
    for (var i = 0; i < 5; i++) {
      final habit = fixtures.createEmptyHabit(
        name: 'Habit $i',
        color: PaletteColor(i),
        position: i,
      );
      habit.recompute();
      habitList.add(habit);
    }
    prefsStorage = MemoryStorage();
    prefs = Preferences(prefsStorage);
    logging = _NullLogging();
    cache = _SpyCache(habitList, commandRunner, taskRunner, logging);
    midnightTimer = _SpyMidnightTimer(logging, prefs);
    adapter = HabitCardListAdapter(cache, prefs, midnightTimer);
    adapterListener = _RecordingAdapterListener();
    adapter.setListener(adapterListener);
  }

  void buildController() {
    screen = _FakeScreen();
    behavior = ListHabitsBehavior(
      habitList,
      _FakeDirFinder(),
      taskRunner,
      screen,
      commandRunner,
      prefs,
      _FakeBugReporter(),
      exportCsvTaskFactory: (_, __, ___, ____) => throw UnimplementedError(),
    );
    selectionMenu = _RecordingSelectionMenu();
    controller = HabitCardListController(
      adapter,
      behavior,
      () => selectionMenu,
    );
  }

  setUp(buildAdapter);

  tearDown(resetToday);

  // =========================================================================
  // list-habits.adapter
  // =========================================================================

  group('list-habits.adapter', () {
    test('#1 item count and stable ids', () {
      expect(adapter.itemCount, cache.habitCount,
          reason: 'list-habits.adapter#1: the adapter reports itemCount == '
              'cache.habitCount');
      expect(adapter.itemCount, 5,
          reason: 'list-habits.adapter#1: the adapter reports itemCount == '
              'cache.habitCount');
      expect(adapter.hasStableIds, isTrue,
          reason: 'list-habits.adapter#1: setHasStableIds(true)');
      for (var i = 0; i < 5; i++) {
        expect(adapter.getItemId(i), cache.getHabitByPosition(i)!.id,
            reason: 'list-habits.adapter#1: stable ids equal the habit id');
      }
    });

    test('#2 construction sequence', () {
      // A fresh adapter over a fresh spy cache, so the log is only the ctor.
      cache.reset();
      final fresh = HabitCardListAdapter(cache, prefs, midnightTimer);
      expect(fresh.itemCount, 5,
          reason: 'list-habits.adapter#1: the adapter reports itemCount == '
              'cache.habitCount');
      expect(
          cache.calls.where((c) => c != 'refreshAllHabits').toList(),
          <String>[
            'setListener',
            'setCheckmarkCount(60)',
            'secondaryOrder=byNameAsc',
            'primaryOrder=byPosition',
          ],
          reason: 'list-habits.adapter#2: on construction the adapter sets '
              'cache.checkmarkCount = 60, then cache.secondaryOrder = '
              'preferences.defaultSecondaryOrder and cache.primaryOrder = '
              'preferences.defaultPrimaryOrder (secondary is assigned first)');
    });

    test('#2 the checkmark count really is 60 entries wide', () {
      final habit = cache.getHabitByPosition(0)!;
      expect(cache.getCheckmarks(habit.id!).length, 60,
          reason: 'list-habits.adapter#2: cache.checkmarkCount = 60');
    });

    test('#3 primaryOrder writes through to the cache and the preferences', () {
      cache.reset();
      adapter.primaryOrder = HabitListOrder.byScoreDesc;

      expect(cache.primaryOrder, HabitListOrder.byScoreDesc,
          reason: 'list-habits.adapter#3: setting adapter.primaryOrder writes '
              'through to the cache');
      expect(prefs.defaultPrimaryOrder, HabitListOrder.byScoreDesc,
          reason: 'list-habits.adapter#3: setting adapter.primaryOrder writes '
              'through to Preferences.defaultPrimaryOrder');
      expect(adapter.primaryOrder, HabitListOrder.byScoreDesc,
          reason: 'list-habits.adapter#3: the getter reads the cache back');
      expect(cache.calls, contains('refreshAllHabits'),
          reason: 'list-habits.adapter#3: writing the cache triggers a '
              'refresh');
    });

    test('#3 secondaryOrder writes through to the cache and the preferences',
        () {
      cache.reset();
      adapter.secondaryOrder = HabitListOrder.byColorDesc;

      expect(cache.secondaryOrder, HabitListOrder.byColorDesc,
          reason: 'list-habits.adapter#3: the same holds for secondaryOrder');
      expect(prefs.defaultSecondaryOrder, HabitListOrder.byColorDesc,
          reason: 'list-habits.adapter#3: the same holds for '
              'defaultSecondaryOrder');
      expect(adapter.secondaryOrder, HabitListOrder.byColorDesc,
          reason: 'list-habits.adapter#3: the getter reads the cache back');
      expect(cache.calls, contains('refreshAllHabits'),
          reason: 'list-habits.adapter#3: writing the cache triggers a '
              'refresh');
    });

    test('#4 isSortable iff the primary order is BY_POSITION', () {
      expect(adapter.primaryOrder, HabitListOrder.byPosition,
          reason: 'list-habits.adapter#4: isSortable is true if and only if '
              'cache.primaryOrder == BY_POSITION');
      expect(adapter.isSortable, isTrue,
          reason: 'list-habits.adapter#4: isSortable is true if and only if '
              'cache.primaryOrder == BY_POSITION');

      for (final order in HabitListOrder.values) {
        adapter.primaryOrder = order;
        expect(adapter.isSortable, order == HabitListOrder.byPosition,
            reason: 'list-habits.adapter#4: isSortable is true if and only if '
                'cache.primaryOrder == BY_POSITION');
      }
    });

    test('#5 binding a row passes habit, score, values, notes and selected',
        () {
      final habit = cache.getHabitByPosition(2)!;
      final data = adapter.bindCardView(2)!;

      expect(identical(data.habit, habit), isTrue,
          reason: 'list-habits.adapter#5: binding a row passes the habit');
      expect(data.score, cache.getScore(habit.id!),
          reason: 'list-habits.adapter#5: binding a row passes its cached '
              'score');
      expect(identical(data.checkmarks, cache.getCheckmarks(habit.id!)), isTrue,
          reason: 'list-habits.adapter#5: binding a row passes its cached '
              'IntArray of values');
      expect(identical(data.notes, cache.getNotes(habit.id!)), isTrue,
          reason: 'list-habits.adapter#5: binding a row passes its cached '
              'notes array');
      expect(data.selected, isFalse,
          reason: "list-habits.adapter#5: 'selected' = selected list contains "
              'this habit');

      adapter.toggleSelection(2);
      expect(adapter.bindCardView(2)!.selected, isTrue,
          reason: "list-habits.adapter#5: 'selected' = selected list contains "
              'this habit');
      expect(adapter.bindCardView(3)!.selected, isFalse,
          reason: "list-habits.adapter#5: 'selected' = selected list contains "
              'this habit');
    });

    test('#5 nothing is bound while no view is attached', () {
      adapter.setListener(null);
      expect(adapter.bindCardView(0), isNull,
          reason: 'list-habits.adapter#5: `if (listView == null) return` — no '
              'row is bound while the adapter has no view');
    });

    test('#6 toggleSelection adds, removes and notifies', () {
      adapterListener.reset();
      adapter.toggleSelection(99);
      expect(adapter.selected, isEmpty,
          reason: 'list-habits.adapter#6: if there is no habit at that '
              'position, do nothing');
      expect(adapterListener.calls, isEmpty,
          reason: 'list-habits.adapter#6: if there is no habit at that '
              'position, do nothing');

      final habit = cache.getHabitByPosition(1)!;
      adapter.toggleSelection(1);
      expect(adapter.selected, <Habit>[habit],
          reason: 'list-habits.adapter#6: add the habit to the selection if '
              'absent');
      expect(adapterListener.calls, <String>['onDataSetChanged()'],
          reason: 'list-habits.adapter#6: then notify the whole data set '
              'changed');

      adapterListener.reset();
      adapter.toggleSelection(1);
      expect(adapter.selected, isEmpty,
          reason: 'list-habits.adapter#6: or remove it if present');
      expect(adapterListener.calls, <String>['onDataSetChanged()'],
          reason: 'list-habits.adapter#6: then notify the whole data set '
              'changed');
    });

    test('#7 clearSelection is a no-op when nothing is selected', () {
      final counter = _ObservableCounter();
      adapter.observable.addListener(counter);
      adapterListener.reset();

      adapter.clearSelection();
      expect(adapterListener.calls, isEmpty,
          reason: 'list-habits.adapter#7: clearSelection() is a no-op when '
              'nothing is selected');
      expect(counter.count, 0,
          reason: 'list-habits.adapter#7: clearSelection() is a no-op when '
              'nothing is selected');
    });

    test('#7 clearSelection clears, notifies the data set and the observable',
        () {
      final counter = _ObservableCounter();
      adapter.observable.addListener(counter);
      adapter.toggleSelection(0);
      adapter.toggleSelection(1);
      adapterListener.reset();
      counter.count = 0;

      adapter.clearSelection();
      expect(adapter.selected, isEmpty,
          reason: 'list-habits.adapter#7: otherwise it clears the list');
      expect(adapterListener.calls, <String>['onDataSetChanged()'],
          reason: 'list-habits.adapter#7: notifies the whole data set '
              'changed');
      expect(counter.count, 1,
          reason: 'list-habits.adapter#7: and notifies the ModelObservable '
              'listeners');
    });

    test('#7 getSelected returns a copy, in selection order', () {
      final h0 = cache.getHabitByPosition(0)!;
      final h3 = cache.getHabitByPosition(3)!;
      adapter.toggleSelection(3);
      adapter.toggleSelection(0);

      expect(adapter.getSelected(), <Habit>[h3, h0],
          reason: 'list-habits.adapter#7: the selection storage keeps the '
              'order habits were selected in');
      adapter.getSelected().clear();
      expect(adapter.selected.length, 2,
          reason: 'list-habits.adapter#7: getSelected returns a copy '
              '(ArrayList(selected)), not the live list');
    });

    test('#8 every cache callback forwards and notifies the observable', () {
      final counter = _ObservableCounter();
      adapter.observable.addListener(counter);
      adapterListener.reset();
      counter.count = 0;

      adapter.onItemChanged(1);
      adapter.onItemInserted(2);
      adapter.onItemMoved(3, 4);
      adapter.onItemRemoved(0);

      expect(
          adapterListener.calls,
          <String>[
            'onItemChanged(1)',
            'onItemInserted(2)',
            'onItemMoved(3,4)',
            'onItemRemoved(0)',
          ],
          reason: 'list-habits.adapter#8: every cache listener callback '
              'forwards to the matching RecyclerView notification');
      expect(counter.count, 4,
          reason: 'list-habits.adapter#8: and then notifies the adapter '
              "ModelObservable");

      adapterListener.reset();
      adapter.onRefreshFinished();
      expect(adapterListener.calls, isEmpty,
          reason: 'list-habits.adapter#8: onRefreshFinished has no matching '
              'RecyclerView notification upstream — it only notifies the '
              'ModelObservable');
      expect(counter.count, 5,
          reason: 'list-habits.adapter#8: onRefreshFinished notifies the '
              'adapter ModelObservable');
    });

    test('#8 the adapter is the cache listener', () {
      adapterListener.reset();
      cache.remove(cache.getHabitByPosition(0)!.id!);
      expect(adapterListener.calls, <String>['onItemRemoved(0)'],
          reason: 'list-habits.adapter#8: the adapter registers itself as the '
              'cache listener, so cache callbacks reach the view');
    });

    test('#9 performRemove touches the cache only', () {
      final h1 = cache.getHabitByPosition(1)!;
      final h3 = cache.getHabitByPosition(3)!;
      cache.reset();

      adapter.performRemove(<Habit>[h1, h3]);

      expect(cache.calls, <String>['remove(${h1.id})', 'remove(${h3.id})'],
          reason: 'list-habits.adapter#9: performRemove(selected) removes each '
              'selected habit from the cache only');
      expect(adapter.itemCount, 3,
          reason: 'list-habits.adapter#9: the rows disappear immediately '
              '(optimistic UI)');
      expect(habitList.size(), 5,
          reason: 'list-habits.adapter#9: the database is untouched');

      adapter.refresh();
      expect(adapter.itemCount, 5,
          reason: 'list-habits.adapter#9: the change is reverted on the next '
              'refresh');
    });

    test('#10 performReorder calls cache.reorder only', () {
      final h0 = cache.getHabitByPosition(0)!;
      cache.reset();

      adapter.performReorder(0, 2);

      expect(cache.calls, <String>['reorder(0,2)'],
          reason: 'list-habits.adapter#10: performReorder(from, to) calls '
              'cache.reorder(from, to) only');
      expect(identical(cache.getHabitByPosition(2), h0), isTrue,
          reason: 'list-habits.adapter#10: the cache moved the row '
              '(optimistic UI)');
      expect(identical(habitList.getByPosition(0), h0), isTrue,
          reason: 'list-habits.adapter#10: the habit list is untouched '
              '(optimistic UI)');
    });

    test('#11 at midnight the adapter refreshes every habit', () {
      adapter.onAttached();
      cache.reset();

      midnightTimer.fire();

      expect(cache.calls, contains('refreshAllHabits'),
          reason: 'list-habits.adapter#11: at midnight it calls '
              'cache.refreshAllHabits()');
    });

    test('#12 onAttached and onDetached register and unregister both', () {
      expect(midnightTimer.listeners, isNot(contains(adapter)),
          reason: 'list-habits.adapter#12: the midnight listener is added by '
              'onAttached, not by the constructor');
      expect(commandRunner.listeners, isNot(contains(cache)),
          reason: 'list-habits.adapter#12: the cache registers with the '
              'CommandRunner in onAttached, not in the constructor');

      adapter.onAttached();
      expect(commandRunner.listeners, contains(cache),
          reason: 'list-habits.adapter#12: onAttached registers the cache with '
              'the CommandRunner');
      expect(midnightTimer.listeners, contains(adapter),
          reason: 'list-habits.adapter#12: onAttached adds the midnight '
              'listener');

      adapter.onDetached();
      expect(commandRunner.listeners, isNot(contains(cache)),
          reason: 'list-habits.adapter#12: onDetached removes the cache from '
              'the CommandRunner');
      expect(midnightTimer.listeners, isNot(contains(adapter)),
          reason: 'list-habits.adapter#12: onDetached removes the midnight '
              'listener');
    });

    test('#11 cancelRefresh and hasNoHabit delegate to the cache', () {
      cache.reset();
      adapter.cancelRefresh();
      expect(cache.calls, <String>['cancelTasks'],
          reason: 'list-habits.adapter#11: cancelRefresh() cancels the '
              'currently running cache task');
      expect(adapter.hasNoHabit(), isFalse,
          reason: 'list-habits.adapter#11: hasNoHabit() delegates to the '
              'cache');
      habitList.removeAll();
      expect(adapter.hasNoHabit(), isTrue,
          reason: 'list-habits.adapter#11: hasNoHabit() delegates to the '
              'cache');
    });
  });

  // =========================================================================
  // list-habits.sort-modes — the half of the feature that lives on this side
  // of the menu presenter. The arrow icons of rule #11 belong to the Android
  // Sort submenu, which the Flutter screen does not have.
  // =========================================================================

  group('list-habits.sort-modes', () {
    List<String> rowNames() => <String>[
          for (var i = 0; i < adapter.itemCount; i++) adapter.getItem(i)!.name,
        ];

    test('#12 a new order re-sorts the rows at once and survives a restart',
        () {
      expect(rowNames(),
          <String>['Habit 0', 'Habit 1', 'Habit 2', 'Habit 3', 'Habit 4'],
          reason: 'list-habits.sort-modes#12: BY_POSITION is the starting '
              'order');

      cache.reset();
      adapter.primaryOrder = HabitListOrder.byNameDesc;

      expect(cache.calls, contains('refreshAllHabits'),
          reason: 'list-habits.sort-modes#12: changing the sort order triggers '
              'a full cache refresh');
      expect(rowNames(),
          <String>['Habit 4', 'Habit 3', 'Habit 2', 'Habit 1', 'Habit 0'],
          reason: 'list-habits.sort-modes#12: so the rows are re-ordered '
              'immediately');

      // "Persists across app restarts": the order went into the preference
      // store, and a freshly built adapter seeds the cache from it again.
      expect(prefsStorage.getString('pref_default_order', ''), 'BY_NAME_DESC',
          reason: 'list-habits.sort-modes#12: the change is persisted');

      final restarted = HabitCardListAdapter(
        _SpyCache(habitList, commandRunner, taskRunner, logging),
        Preferences(prefsStorage),
        midnightTimer,
      );
      expect(restarted.primaryOrder, HabitListOrder.byNameDesc,
          reason: 'list-habits.sort-modes#12: a restart reads the same order '
              'back');
      expect(
        <String>[
          for (var i = 0; i < restarted.itemCount; i++)
            restarted.getItem(i)!.name,
        ],
        <String>['Habit 4', 'Habit 3', 'Habit 2', 'Habit 1', 'Habit 0'],
        reason: 'list-habits.sort-modes#12: and the rows come back sorted',
      );
    });
  });

  // =========================================================================
  // list-habits.selection-mode
  // =========================================================================

  group('list-habits.selection-mode', () {
    setUp(buildController);

    test('#1 there are exactly two modes and it starts in NormalMode', () {
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.selection-mode#1: the controller starts in '
              'NormalMode');
      expect(adapter.isSelectionEmpty, isTrue,
          reason: 'list-habits.selection-mode#1: NormalMode means nothing is '
              'selected');

      controller.onItemLongClick(0);
      expect(controller.activeMode, isA<SelectionMode>(),
          reason: 'list-habits.selection-mode#1: SelectionMode means at least '
              'one habit is selected');
      expect(adapter.isSelectionEmpty, isFalse,
          reason: 'list-habits.selection-mode#1: SelectionMode means at least '
              'one habit is selected');

      controller.onItemClick(0);
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.selection-mode#1: the controller has exactly '
              'two modes, NormalMode and SelectionMode');
    });

    test('#2 NormalMode tap opens the habit detail screen', () {
      final habit = cache.getHabitByPosition(2)!;
      controller.onItemClick(2);

      expect(screen.habitScreens, <Habit>[habit],
          reason: 'list-habits.selection-mode#2: NormalMode single tap on a '
              'row opens the habit detail screen for that habit');
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.selection-mode#2: a NormalMode tap does not '
              'change the mode');
      expect(adapter.isSelectionEmpty, isTrue,
          reason: 'list-habits.selection-mode#2: a NormalMode tap selects '
              'nothing');
    });

    test('#2 NormalMode tap on an invalid position does nothing', () {
      controller.onItemClick(99);
      expect(screen.habitScreens, isEmpty,
          reason: 'list-habits.selection-mode#2: if there is no habit at that '
              'position nothing happens');
      expect(selectionMenu.calls, isEmpty,
          reason: 'list-habits.selection-mode#2: if there is no habit at that '
              'position nothing happens');
    });

    test('#3 NormalMode long press starts selection', () {
      final habit = cache.getHabitByPosition(1)!;
      controller.onItemLongClick(1);

      expect(adapter.getSelected(), <Habit>[habit],
          reason: 'list-habits.selection-mode#3: NormalMode long press toggles '
              'that row into the selection');
      expect(controller.activeMode, isA<SelectionMode>(),
          reason: 'list-habits.selection-mode#3: NormalMode long press '
              'switches to SelectionMode');
      expect(selectionMenu.calls, <String>['onSelectionStart'],
          reason: 'list-habits.selection-mode#3: NormalMode long press starts '
              'the contextual action mode');
    });

    test('#3 long-pressing an invalid position still starts the action mode',
        () {
      controller.onItemLongClick(99);

      expect(adapter.isSelectionEmpty, isTrue,
          reason: 'list-habits.selection-mode#3: there is no habit at that '
              'position, so nothing is toggled into the selection');
      expect(controller.activeMode, isA<SelectionMode>(),
          reason: 'list-habits.selection-mode#3: upstream startSelection() '
              'forces SelectionMode after the toggle, even when the toggle '
              'selected nothing');
      expect(selectionMenu.calls, <String>['onSelectionStart'],
          reason: 'list-habits.selection-mode#3: upstream startSelection() '
              'starts the contextual action mode unconditionally');
    });

    test('#4 SelectionMode tap toggles and invalidates the action bar', () {
      final h0 = cache.getHabitByPosition(0)!;
      final h2 = cache.getHabitByPosition(2)!;
      controller.onItemLongClick(0);
      selectionMenu.reset();

      controller.onItemClick(2);
      expect(adapter.getSelected(), <Habit>[h0, h2],
          reason: 'list-habits.selection-mode#4: SelectionMode single tap '
              "toggles the tapped row's selection");
      expect(controller.activeMode, isA<SelectionMode>(),
          reason: 'list-habits.selection-mode#4: the selection is not empty, '
              'so the mode stays SelectionMode');
      expect(selectionMenu.calls, <String>['onSelectionChange'],
          reason: 'list-habits.selection-mode#4: otherwise the action bar is '
              'invalidated so its title and item visibility refresh');
    });

    test('#4 SelectionMode long press toggles too', () {
      final h0 = cache.getHabitByPosition(0)!;
      final h4 = cache.getHabitByPosition(4)!;
      controller.onItemLongClick(0);
      selectionMenu.reset();

      controller.onItemLongClick(4);
      expect(adapter.getSelected(), <Habit>[h0, h4],
          reason: 'list-habits.selection-mode#4: SelectionMode long press does '
              'the same');
      expect(selectionMenu.calls, <String>['onSelectionChange'],
          reason: 'list-habits.selection-mode#4: the action bar is '
              'invalidated');
    });

    test('#4 emptying the selection reverts to NormalMode and finishes the bar',
        () {
      controller.onItemLongClick(0);
      selectionMenu.reset();

      controller.onItemClick(0);
      expect(adapter.isSelectionEmpty, isTrue,
          reason: 'list-habits.selection-mode#4: the tap toggled the last '
              'selected row off');
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.selection-mode#4: if the selection is now empty '
              'the mode reverts to NormalMode');
      expect(selectionMenu.calls, <String>['onSelectionFinish'],
          reason: 'list-habits.selection-mode#4: and the contextual action bar '
              'is finished');
    });

    test('#5 a model change with an empty selection resets to NormalMode', () {
      controller.onItemLongClick(0);
      controller.onItemLongClick(1);
      selectionMenu.reset();

      // A model change while the selection is NOT empty changes nothing.
      adapter.onItemChanged(0);
      expect(controller.activeMode, isA<SelectionMode>(),
          reason: 'list-habits.selection-mode#5: the reset happens only when '
              'the selection is empty');
      expect(selectionMenu.calls, isEmpty,
          reason: 'list-habits.selection-mode#5: the reset happens only when '
              'the selection is empty');

      // clearSelection() notifies the ModelObservable, which is how the
      // selection menu's actions drop the controller back into NormalMode.
      adapter.clearSelection();
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.selection-mode#5: whenever the adapter notifies '
              'a model change and the selection is empty, the controller '
              'resets to NormalMode');
      expect(selectionMenu.calls, <String>['onSelectionFinish'],
          reason: 'list-habits.selection-mode#5: and finishes the contextual '
              'action bar');
    });

    test('#6 destroying the action bar cancels the selection', () {
      controller.onItemLongClick(0);
      controller.onItemLongClick(2);
      selectionMenu.reset();

      controller.onSelectionFinished();

      expect(adapter.selected, isEmpty,
          reason: 'list-habits.selection-mode#6: destroying the contextual '
              'action bar cancels the selection: the selection is cleared');
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.selection-mode#6: the mode resets to '
              'NormalMode');
      expect(selectionMenu.calls,
          <String>['onSelectionFinish', 'onSelectionFinish'],
          reason: 'list-habits.selection-mode#6: the action bar is finished — '
              'twice, because adapter.clearSelection() notifies the '
              'ModelObservable and onModelChange finishes it as well');
    });

    test('#6 cancelling an already empty selection finishes the bar once', () {
      controller.onSelectionFinished();
      expect(selectionMenu.calls, <String>['onSelectionFinish'],
          reason: 'list-habits.selection-mode#6: clearSelection() returns '
              'early when nothing is selected, so the ModelObservable is not '
              'notified');
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.selection-mode#6: the mode resets to '
              'NormalMode');
    });

    test('#7 startDrag goes through the same selection toggling path', () {
      final h1 = cache.getHabitByPosition(1)!;
      final h3 = cache.getHabitByPosition(3)!;

      controller.startDrag(1);
      expect(adapter.getSelected(), <Habit>[h1],
          reason: 'list-habits.selection-mode#7: NormalMode.startDrag starts '
              'selection');
      expect(controller.activeMode, isA<SelectionMode>(),
          reason: 'list-habits.selection-mode#7: NormalMode.startDrag starts '
              'selection');
      expect(selectionMenu.calls, <String>['onSelectionStart'],
          reason: 'list-habits.selection-mode#7: NormalMode.startDrag starts '
              'selection');

      selectionMenu.reset();
      controller.startDrag(3);
      expect(adapter.getSelected(), <Habit>[h1, h3],
          reason: 'list-habits.selection-mode#7: SelectionMode.startDrag '
              'toggles');
      expect(selectionMenu.calls, <String>['onSelectionChange'],
          reason: 'list-habits.selection-mode#7: SelectionMode.startDrag '
              'toggles');
    });

    test('#8 the action bar title is the selected count in plain decimal', () {
      controller.onItemLongClick(0);
      controller.onItemClick(3);

      expect(adapter.selected.length.toString(), '2',
          reason: 'list-habits.selection-mode#8: the contextual action bar '
              'title is the selected count rendered as a plain decimal string '
              "(e.g. '2')");

      controller.onItemClick(1);
      expect(adapter.selected.length.toString(), '3',
          reason: 'list-habits.selection-mode#8: the contextual action bar '
              'title is the selected count rendered as a plain decimal '
              'string');
    });

    test('#9 selecting an already-selected habit removes it', () {
      final h2 = cache.getHabitByPosition(2)!;
      controller.onItemLongClick(2);
      expect(adapter.getSelected(), <Habit>[h2],
          reason: 'list-habits.selection-mode#9: selection is a toggle');

      controller.onItemLongClick(2);
      expect(adapter.getSelected(), isEmpty,
          reason: 'list-habits.selection-mode#9: selecting an already-selected '
              'habit removes it from the selection (selection is a toggle, '
              'not additive-only)');
    });

    test('drop cancels the selection and reorders both cache and model', () {
      final h0 = cache.getHabitByPosition(0)!;
      final h2 = cache.getHabitByPosition(2)!;
      controller.onItemLongClick(4);
      selectionMenu.reset();
      cache.reset();

      controller.drop(0, 2);

      expect(adapter.selected, isEmpty,
          reason: 'list-habits.drag-reorder#5: drop first cancels the '
              'selection');
      expect(controller.activeMode, isA<NormalMode>(),
          reason: 'list-habits.drag-reorder#5: drop resets the mode to '
              'NormalMode');
      expect(cache.calls, contains('reorder(0,2)'),
          reason: 'list-habits.drag-reorder#5: then it reorders the cache '
              'optimistically');
      expect(identical(habitList.getByPosition(2), h0), isTrue,
          reason: 'list-habits.drag-reorder#5: and dispatches the persistent '
              'reorder');
      expect(identical(habitList.getByPosition(1), h2), isTrue,
          reason: 'list-habits.drag-reorder#5: the moved habit takes the index '
              "of the 'to' habit");
    });

    test('drop is a no-op when from == to', () {
      controller.onItemLongClick(0);
      selectionMenu.reset();
      cache.reset();

      controller.drop(2, 2);

      expect(adapter.selected.length, 1,
          reason: 'list-habits.drag-reorder#5: if from == to it returns '
              'immediately without any side effect');
      expect(controller.activeMode, isA<SelectionMode>(),
          reason: 'list-habits.drag-reorder#5: if from == to it returns '
              'immediately without any side effect');
      expect(cache.calls, isEmpty,
          reason: 'list-habits.drag-reorder#5: if from == to it returns '
              'immediately without any side effect');
    });

    test('drop returns after cancelling when either habit is missing', () {
      controller.onItemLongClick(0);
      selectionMenu.reset();
      cache.reset();

      controller.drop(0, 99);

      expect(adapter.selected, isEmpty,
          reason: 'list-habits.drag-reorder#5: the selection is cancelled '
              'before the habits are looked up');
      expect(cache.calls.where((c) => c.startsWith('reorder')), isEmpty,
          reason: 'list-habits.drag-reorder#5: if either is null it returns');
    });
  });
}
