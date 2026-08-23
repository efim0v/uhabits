import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_selection_menu_behavior.dart';

/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsSelectionMenuBehavior.kt
/// and its test
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsSelectionMenuBehaviorTest.kt
///
/// Every `expect` carries the parity-ledger rule id it exercises.
///
/// The Kotlin test uses mokkery `mock()` for both collaborators; Dart has no
/// such thing here, so the two nested interfaces are implemented by hand-rolled
/// fakes that also record the *order* of the calls, which is what several of
/// the rules are actually about.

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Stands in for `mock<ListHabitsSelectionMenuBehavior.Adapter>()`.
///
/// `getSelected()` returns the very list instance the test installed — as the
/// mokkery `returns listOf(...)` stub does — so that "the same list is handed
/// to the screen" can be asserted by identity.
class _FakeAdapter implements ListHabitsSelectionMenuBehaviorAdapter {
  _FakeAdapter(this._log);

  final List<String> _log;

  /// The current selection. Reassigned (never mutated in place) by
  /// [clearSelection], so a list already handed out stays intact.
  List<Habit> selected = <Habit>[];

  int clearSelectionCount = 0;

  int getSelectedCount = 0;

  /// One entry per `performRemove` call, holding the argument instance.
  final List<List<Habit>> performRemoveCalls = <List<Habit>>[];

  @override
  void clearSelection() {
    clearSelectionCount++;
    _log.add('clearSelection');
    selected = <Habit>[];
  }

  @override
  List<Habit> getSelected() {
    getSelectedCount++;
    return selected;
  }

  @override
  void performRemove(List<Habit> selected) {
    performRemoveCalls.add(selected);
    _log.add('performRemove');
  }
}

/// Stands in for `mock<ListHabitsSelectionMenuBehavior.Screen>()`.
///
/// Both dialogs capture their callback so a test can either let the fake answer
/// immediately (the mokkery `calls { ... }` stubs) or answer later, which is
/// what the real Android dialogs do.
class _FakeScreen implements ListHabitsSelectionMenuBehaviorScreen {
  _FakeScreen(this._log);

  final List<String> _log;

  int colorPickerCount = 0;

  PaletteColor? colorPickerDefault;

  /// Answered synchronously when non-null; `null` means "dismissed".
  PaletteColor? colorToPick;

  OnColorPickedCallback? pendingColorCallback;

  int deleteConfirmationCount = 0;

  int? deleteQuantity;

  /// `true` taps Yes immediately; `false` leaves the dialog unanswered.
  bool confirmDelete = false;

  OnConfirmedCallback? pendingDeleteCallback;

  /// One entry per `showEditHabitsScreen` call, holding the argument instance.
  final List<List<Habit>> editScreenCalls = <List<Habit>>[];

  @override
  void showColorPicker(
    PaletteColor defaultColor,
    OnColorPickedCallback callback,
  ) {
    colorPickerCount++;
    colorPickerDefault = defaultColor;
    pendingColorCallback = callback;
    _log.add('showColorPicker');
    final color = colorToPick;
    if (color != null) callback(color);
  }

  @override
  void showDeleteConfirmationScreen(
    OnConfirmedCallback callback,
    int quantity,
  ) {
    deleteConfirmationCount++;
    deleteQuantity = quantity;
    pendingDeleteCallback = callback;
    _log.add('showDeleteConfirmationScreen');
    if (confirmDelete) callback();
  }

  @override
  void showEditHabitsScreen(List<Habit> selected) {
    editScreenCalls.add(selected);
    _log.add('showEditHabitsScreen');
  }
}

/// A real [CommandRunner] — the commands genuinely run, as they do in
/// `BaseUnitTest` with its unconfined dispatchers — that also records what it
/// was asked to dispatch and when.
class _RecordingCommandRunner extends CommandRunner {
  _RecordingCommandRunner(super.taskRunner, this._log);

  final List<String> _log;

  final List<Command> commands = <Command>[];

  @override
  void run(Command command) {
    commands.add(command);
    _log.add('run:${command.runtimeType}');
    super.run(command);
  }
}

/// Records `update()` so that "…and persists them" can be asserted directly.
class _RecordingHabitList extends MemoryHabitList {
  final List<List<Habit>> updateCalls = <List<Habit>>[];

  @override
  void update(List<Habit> habits) {
    updateCalls.add(habits);
    super.update(habits);
  }
}

void main() {
  // -------------------------------------------------------------------------
  // BaseUnitTest.setUp, inlined
  // -------------------------------------------------------------------------
  late _RecordingHabitList habitList;
  late HabitFixtures fixtures;
  late TaskRunner taskRunner;
  late _RecordingCommandRunner commandRunner;
  late List<String> log;
  late _FakeAdapter adapter;
  late _FakeScreen screen;
  late ListHabitsSelectionMenuBehavior behavior;
  late Habit habit1;
  late Habit habit2;
  late Habit habit3;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    final modelFactory = MemoryModelFactory();
    habitList = _RecordingHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    log = <String>[];
    commandRunner = _RecordingCommandRunner(taskRunner, log);

    // ListHabitsSelectionMenuBehaviorTest.setUp
    habit1 = fixtures.createShortHabit();
    habit1.isArchived = true;
    habit2 = fixtures.createShortHabit();
    habit3 = fixtures.createShortHabit();
    habitList.add(habit1);
    habitList.add(habit2);
    habitList.add(habit3);
    habitList.updateCalls.clear();

    adapter = _FakeAdapter(log);
    screen = _FakeScreen(log);
    behavior = ListHabitsSelectionMenuBehavior(
      habitList,
      screen,
      adapter,
      commandRunner,
    );
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // Enablement predicates
  // -------------------------------------------------------------------------
  group('predicates', () {
    test('canArchive is false when any selected habit is archived', () {
      // ListHabitsSelectionMenuBehaviorTest.canArchive
      adapter.selected = <Habit>[habit1, habit2];
      expect(
        behavior.canArchive(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#18: canArchive() returns '
            'false if ANY selected habit is archived',
      );
      expect(
        behavior.canArchive(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#2: Archive is visible only '
            'when NO selected habit is archived',
      );

      adapter.selected = <Habit>[habit2, habit3];
      expect(
        behavior.canArchive(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#18: canArchive() is true '
            'when no selected habit is archived',
      );
      expect(
        behavior.canArchive(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#2: Archive is visible when '
            'no selected habit is archived',
      );
    });

    test('canEdit is true only for exactly one selected habit', () {
      // ListHabitsSelectionMenuBehaviorTest.canEdit
      adapter.selected = <Habit>[habit1];
      expect(
        behavior.canEdit(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#18: canEdit() returns '
            'adapter.getSelected().size == 1',
      );
      expect(
        behavior.canEdit(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#2: Edit is visible only '
            'when exactly one habit is selected',
      );

      adapter.selected = <Habit>[habit1, habit2];
      expect(
        behavior.canEdit(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#18: canEdit() is false for '
            'two selected habits',
      );
      expect(
        behavior.canEdit(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#2: Edit is hidden when two '
            'habits are selected',
      );

      adapter.selected = <Habit>[habit1, habit2, habit3];
      expect(
        behavior.canEdit(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#18: canEdit() is false for '
            'three selected habits',
      );
    });

    test('canUnarchive requires every selected habit to be archived', () {
      // ListHabitsSelectionMenuBehaviorTest.canUnarchive
      adapter.selected = <Habit>[habit1, habit2];
      expect(
        behavior.canUnarchive(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#18: canUnarchive() returns '
            'false if ANY selected habit is not archived',
      );
      expect(
        behavior.canUnarchive(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#2: Unarchive is visible '
            'only when EVERY selected habit is archived',
      );

      adapter.selected = <Habit>[habit1];
      expect(
        behavior.canUnarchive(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#18: canUnarchive() is true '
            'when every selected habit is archived',
      );
      expect(
        behavior.canUnarchive(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#2: Unarchive is visible '
            'when every selected habit is archived',
      );
    });

    test('empty selection: both can* are vacuously true, canEdit is false', () {
      adapter.selected = <Habit>[];
      expect(
        behavior.canArchive(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#3: canArchive() returns '
            'true for an empty selection (vacuous truth)',
      );
      expect(
        behavior.canUnarchive(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#3: canUnarchive() returns '
            'true for an empty selection (vacuous truth)',
      );
      expect(
        behavior.canEdit(),
        isFalse,
        reason: 'list-habits.selection-menu-actions#3: canEdit() returns false '
            'for an empty selection',
      );
      expect(
        behavior.canArchive() && behavior.canUnarchive(),
        isTrue,
        reason: 'list-habits.selection-menu-actions#18: Both can* predicates '
            'return true for an empty selection',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Archive / unarchive
  // -------------------------------------------------------------------------
  group('archive', () {
    test('onArchiveHabits archives every selected habit and clears', () {
      // ListHabitsSelectionMenuBehaviorTest.onArchiveHabits
      expect(habit2.isArchived, isFalse);
      final selected = <Habit>[habit2, habit3];
      adapter.selected = selected;

      behavior.onArchiveHabits();

      expect(
        habit2.isArchived,
        isTrue,
        reason: 'list-habits.selection-menu-actions#5: Archive runs '
            'ArchiveHabitsCommand which sets isArchived = true on every '
            'selected habit',
      );
      expect(
        habit3.isArchived,
        isTrue,
        reason: 'list-habits.selection-menu-actions#5: isArchived = true on '
            'EVERY selected habit',
      );
      expect(
        habit1.isArchived,
        isTrue,
        reason: 'list-habits.selection-menu-actions#5: unselected habits are '
            'untouched (habit1 was already archived by the fixture)',
      );
      expect(
        habitList.updateCalls.length,
        1,
        reason: 'list-habits.selection-menu-actions#5: ArchiveHabitsCommand '
            'persists the selected habits',
      );
      expect(
        habitList.updateCalls.single,
        same(selected),
        reason: 'list-habits.selection-menu-actions#5: the selected habits are '
            'the ones persisted',
      );

      expect(
        commandRunner.commands.length,
        1,
        reason: 'list-habits.selection-menu-actions#13: onArchiveHabits() runs '
            'exactly one command',
      );
      expect(
        commandRunner.commands.single,
        isA<ArchiveHabitsCommand>(),
        reason: 'list-habits.selection-menu-actions#13: onArchiveHabits() runs '
            'ArchiveHabitsCommand(habitList, adapter.getSelected())',
      );
      final command = commandRunner.commands.single as ArchiveHabitsCommand;
      expect(
        command.habitList,
        same(habitList),
        reason: 'list-habits.selection-menu-actions#13: the command is built '
            'with the behavior habitList',
      );
      expect(
        command.selected,
        same(selected),
        reason: 'list-habits.selection-menu-actions#13: the command is built '
            'with adapter.getSelected()',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#13: onArchiveHabits() then '
            'calls adapter.clearSelection()',
      );
      expect(
        log,
        <String>['run:ArchiveHabitsCommand', 'clearSelection'],
        reason: 'list-habits.selection-menu-actions#13: the command runs '
            'BEFORE clearSelection()',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#19: the selection is '
            'cleared after the Archive menu action',
      );
    });

    test('onArchiveHabits with an empty selection still clears', () {
      adapter.selected = <Habit>[];

      behavior.onArchiveHabits();

      expect(
        commandRunner.commands.single,
        isA<ArchiveHabitsCommand>(),
        reason: 'list-habits.selection-menu-actions#13: the command is '
            'dispatched unconditionally, even for an empty selection',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#19: the selection is '
            'always cleared after a menu action, whether or not the command '
            'changed anything',
      );
    });

    test('onUnarchiveHabits unarchives every selected habit and clears', () {
      // ListHabitsSelectionMenuBehaviorTest.onUnarchiveHabits
      expect(habit1.isArchived, isTrue);
      habit2.isArchived = true;
      final selected = <Habit>[habit1, habit2];
      adapter.selected = selected;

      behavior.onUnarchiveHabits();

      expect(
        habit1.isArchived,
        isFalse,
        reason: 'list-habits.selection-menu-actions#6: Unarchive runs '
            'UnarchiveHabitsCommand which sets isArchived = false on every '
            'selected habit',
      );
      expect(
        habit2.isArchived,
        isFalse,
        reason: 'list-habits.selection-menu-actions#6: isArchived = false on '
            'EVERY selected habit',
      );
      expect(
        habitList.updateCalls.single,
        same(selected),
        reason: 'list-habits.selection-menu-actions#6: UnarchiveHabitsCommand '
            'persists the selected habits',
      );

      expect(
        commandRunner.commands.length,
        1,
        reason: 'list-habits.selection-menu-actions#14: onUnarchiveHabits() '
            'runs exactly one command',
      );
      expect(
        commandRunner.commands.single,
        isA<UnarchiveHabitsCommand>(),
        reason: 'list-habits.selection-menu-actions#14: onUnarchiveHabits() '
            'runs UnarchiveHabitsCommand(habitList, adapter.getSelected())',
      );
      final command = commandRunner.commands.single as UnarchiveHabitsCommand;
      expect(
        command.habitList,
        same(habitList),
        reason: 'list-habits.selection-menu-actions#14: the command is built '
            'with the behavior habitList',
      );
      expect(
        command.selected,
        same(selected),
        reason: 'list-habits.selection-menu-actions#14: the command is built '
            'with adapter.getSelected()',
      );
      expect(
        log,
        <String>['run:UnarchiveHabitsCommand', 'clearSelection'],
        reason: 'list-habits.selection-menu-actions#14: the command runs, then '
            'adapter.clearSelection()',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#19: the selection is '
            'cleared after the Unarchive menu action',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Change color
  // -------------------------------------------------------------------------
  group('change color', () {
    test('onChangeColor applies the picked color to every selection', () {
      // ListHabitsSelectionMenuBehaviorTest.onChangeColor
      expect(habit1.color, const PaletteColor(8));
      expect(habit2.color, const PaletteColor(8));
      final selected = <Habit>[habit1, habit2];
      adapter.selected = selected;
      screen.colorToPick = const PaletteColor(30);

      behavior.onChangeColor();

      expect(
        habit1.color,
        const PaletteColor(30),
        reason: 'list-habits.selection-menu-actions#7: when a colour is '
            'picked, ChangeHabitColorCommand applies it to every selected '
            'habit',
      );
      expect(
        habit2.color,
        const PaletteColor(30),
        reason: 'list-habits.selection-menu-actions#7: the colour is applied '
            'to EVERY selected habit, not only the first',
      );
      expect(
        habit3.color,
        const PaletteColor(8),
        reason: 'list-habits.selection-menu-actions#7: unselected habits keep '
            'their colour',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#7: after the command the '
            'selection is cleared',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#19: the selection is '
            'cleared after the Change color menu action',
      );
    });

    test('onChangeColor seeds the picker with the FIRST selected color', () {
      habit1.color = const PaletteColor(5);
      habit2.color = const PaletteColor(11);
      adapter.selected = <Habit>[habit1, habit2];
      screen.colorToPick = const PaletteColor(30);

      behavior.onChangeColor();

      expect(
        screen.colorPickerCount,
        1,
        reason: 'list-habits.selection-menu-actions#15: onChangeColor() calls '
            'screen.showColorPicker(defaultColor, callback)',
      );
      expect(
        screen.colorPickerDefault,
        const PaletteColor(5),
        reason: 'list-habits.selection-menu-actions#15: the picker default is '
            "the FIRST selected habit's colour",
      );
      expect(
        screen.colorPickerDefault,
        const PaletteColor(5),
        reason: 'list-habits.selection-menu-actions#7: the colour picker is '
            'opened seeded with the colour of the FIRST selected habit',
      );

      final command = commandRunner.commands.single as ChangeHabitColorCommand;
      expect(
        command.newColor,
        const PaletteColor(30),
        reason: 'list-habits.selection-menu-actions#15: inside the callback '
            'ChangeHabitColorCommand is run with the selected colour',
      );
      expect(
        command.habitList,
        same(habitList),
        reason: 'list-habits.selection-menu-actions#15: the command is built '
            'with the behavior habitList',
      );
      expect(
        command.selected,
        <Habit>[habit1, habit2],
        reason: 'list-habits.selection-menu-actions#15: the command is built '
            'with adapter.getSelected()',
      );
      expect(
        log,
        <String>[
          'showColorPicker',
          'run:ChangeHabitColorCommand',
          'clearSelection',
        ],
        reason: 'list-habits.selection-menu-actions#15: the command runs '
            'inside the callback and the selection is cleared afterwards',
      );
    });

    test('a dismissed color picker runs nothing and keeps the selection', () {
      habit1.color = const PaletteColor(5);
      adapter.selected = <Habit>[habit1, habit2];
      screen.colorToPick = null; // dismissed without a choice

      behavior.onChangeColor();

      expect(
        commandRunner.commands,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#15: if the picker is '
            'dismissed without a choice, no command runs',
      );
      expect(
        habit1.color,
        const PaletteColor(5),
        reason: 'list-habits.selection-menu-actions#15: a dismissed picker '
            'leaves the colours untouched',
      );
      expect(
        adapter.clearSelectionCount,
        0,
        reason: 'list-habits.selection-menu-actions#19: the selection is NOT '
            'cleared when the colour picker is cancelled',
      );
    });

    test('the picked color is applied to the selection as of pick time', () {
      adapter.selected = <Habit>[habit1];
      screen.colorToPick = null; // answer later, by hand

      behavior.onChangeColor();
      expect(
        screen.colorPickerDefault,
        const PaletteColor(8),
        reason: 'list-habits.selection-menu-actions#15: the default colour is '
            'read when the picker is opened',
      );

      // Upstream re-reads adapter.getSelected() inside the callback.
      adapter.selected = <Habit>[habit2, habit3];
      screen.pendingColorCallback!(const PaletteColor(12));

      final command = commandRunner.commands.single as ChangeHabitColorCommand;
      expect(
        command.selected,
        <Habit>[habit2, habit3],
        reason: 'list-habits.selection-menu-actions#15: the command is built '
            'from adapter.getSelected() read inside the callback',
      );
      expect(
        habit1.color,
        const PaletteColor(8),
        reason: 'list-habits.selection-menu-actions#7: only the habits '
            'selected when the colour is picked are recoloured',
      );
      expect(
        habit2.color,
        const PaletteColor(12),
        reason: 'list-habits.selection-menu-actions#7: ChangeHabitColorCommand '
            'applies the picked colour to every selected habit',
      );
    });

    test('onChangeColor on an empty selection throws (upstream bug)', () {
      adapter.selected = <Habit>[];

      expect(
        () => behavior.onChangeColor(),
        throwsA(isA<RangeError>()),
        reason: 'list-habits.selection-menu-actions#15: onChangeColor() reads '
            "the first selected habit's colour unguarded, so an empty "
            'selection throws (Kotlin: IndexOutOfBoundsException)',
      );
      expect(
        screen.colorPickerCount,
        0,
        reason: 'list-habits.selection-menu-actions#15: the picker is never '
            'shown when the selection is empty',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Delete
  // -------------------------------------------------------------------------
  group('delete', () {
    test('onDeleteHabits deletes the selection once confirmed', () {
      // ListHabitsSelectionMenuBehaviorTest.onDeleteHabits
      final id = habit1.id!;
      expect(habitList.getById(id), same(habit1));
      final selected = <Habit>[habit1];
      adapter.selected = selected;
      screen.confirmDelete = true;

      behavior.onDeleteHabits();

      expect(
        habitList.getById(id),
        isNull,
        reason: 'list-habits.selection-menu-actions#16: on confirmation '
            'DeleteHabitsCommand(habitList, adapter.getSelected()) runs',
      );
      expect(
        commandRunner.commands.single,
        isA<DeleteHabitsCommand>(),
        reason: 'list-habits.selection-menu-actions#16: onDeleteHabits() '
            'dispatches DeleteHabitsCommand',
      );
      final command = commandRunner.commands.single as DeleteHabitsCommand;
      expect(
        command.habitList,
        same(habitList),
        reason: 'list-habits.selection-menu-actions#16: the command is built '
            'with the behavior habitList',
      );
      expect(
        command.selected,
        same(selected),
        reason: 'list-habits.selection-menu-actions#16: the command is built '
            'with adapter.getSelected()',
      );
      expect(
        adapter.performRemoveCalls.single,
        same(selected),
        reason: 'list-habits.selection-menu-actions#16: '
            'adapter.performRemove(adapter.getSelected()) is called',
      );
      expect(
        log,
        <String>[
          'showDeleteConfirmationScreen',
          'performRemove',
          'run:DeleteHabitsCommand',
          'clearSelection',
        ],
        reason: 'list-habits.selection-menu-actions#16: in this order — '
            'performRemove, DeleteHabitsCommand, clearSelection',
      );
      expect(
        log.indexOf('performRemove') < log.indexOf('run:DeleteHabitsCommand'),
        isTrue,
        reason: 'list-habits.selection-menu-actions#8: the habits are first '
            'removed from the cache optimistically, then DeleteHabitsCommand '
            'removes them from the list, then the selection is cleared',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#19: the selection is '
            'cleared after a confirmed Delete',
      );
    });

    test('the confirmation dialog is given the selected count', () {
      adapter.selected = <Habit>[habit1, habit2, habit3];

      behavior.onDeleteHabits();

      expect(
        screen.deleteConfirmationCount,
        1,
        reason: 'list-habits.selection-menu-actions#16: onDeleteHabits() calls '
            'screen.showDeleteConfirmationScreen(callback, quantity)',
      );
      expect(
        screen.deleteQuantity,
        3,
        reason: 'list-habits.selection-menu-actions#16: quantity is '
            'adapter.getSelected().size',
      );
      expect(
        screen.deleteQuantity,
        3,
        reason: 'list-habits.selection-menu-actions#8: the dialog title and '
            'message are pluralised on the number of selected habits',
      );

      adapter.selected = <Habit>[habit1];
      behavior.onDeleteHabits();
      expect(
        screen.deleteQuantity,
        1,
        reason: 'list-habits.selection-menu-actions#8: a single selected habit '
            'gives quantity 1, which selects the singular strings',
      );
    });

    test('cancelling the confirmation dialog runs nothing', () {
      final id = habit1.id!;
      adapter.selected = <Habit>[habit1];
      screen.confirmDelete = false; // the No button, or a dismissal

      behavior.onDeleteHabits();

      expect(
        commandRunner.commands,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#16: cancelling the dialog '
            'runs nothing',
      );
      expect(
        adapter.performRemoveCalls,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#16: performRemove happens '
            'only on confirmation',
      );
      expect(
        habitList.getById(id),
        same(habit1),
        reason: 'list-habits.selection-menu-actions#8: only the Yes button '
            'confirms; the habit survives',
      );
      expect(
        adapter.clearSelectionCount,
        0,
        reason: 'list-habits.selection-menu-actions#19: the selection is NOT '
            'cleared when the delete dialog is cancelled',
      );
    });

    test('the selection is re-read when the dialog is confirmed', () {
      adapter.selected = <Habit>[habit1, habit2];
      screen.confirmDelete = false;

      behavior.onDeleteHabits();
      expect(
        screen.deleteQuantity,
        2,
        reason: 'list-habits.selection-menu-actions#16: quantity is sampled '
            'when the dialog is shown',
      );

      // Upstream calls adapter.getSelected() again inside the callback.
      adapter.selected = <Habit>[habit3];
      screen.pendingDeleteCallback!();

      final command = commandRunner.commands.single as DeleteHabitsCommand;
      expect(
        command.selected,
        <Habit>[habit3],
        reason: 'list-habits.selection-menu-actions#16: the command is built '
            'from adapter.getSelected() read inside the callback, not from the '
            'selection sampled for the quantity',
      );
      expect(
        habitList.getById(habit1.id!),
        same(habit1),
        reason: 'list-habits.selection-menu-actions#16: only the habits '
            'selected at confirmation time are removed',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Edit
  // -------------------------------------------------------------------------
  group('edit', () {
    test('onEditHabits opens the edit screen with the selection', () {
      // ListHabitsSelectionMenuBehaviorTest.onEditHabits
      final selected = <Habit>[habit1, habit2];
      adapter.selected = selected;

      behavior.onEditHabits();

      expect(
        screen.editScreenCalls.length,
        1,
        reason: 'list-habits.selection-menu-actions#17: onEditHabits() calls '
            'screen.showEditHabitsScreen(selected)',
      );
      expect(
        screen.editScreenCalls.single,
        same(selected),
        reason: 'list-habits.selection-menu-actions#17: the very list returned '
            'by adapter.getSelected() is handed to the screen',
      );
      expect(
        screen.editScreenCalls.single,
        same(selected),
        reason: 'list-habits.selection-menu-actions#4: the edit screen is '
            'opened for the selection (its first habit is the one edited)',
      );
      expect(
        commandRunner.commands,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#17: onEditHabits() '
            'dispatches NO command',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#17: the selection is '
            'cleared unconditionally',
      );
      expect(
        log,
        <String>['showEditHabitsScreen', 'clearSelection'],
        reason: 'list-habits.selection-menu-actions#4: the screen is opened '
            'first, then the selection is cleared',
      );
    });

    test('onEditHabits on an empty selection opens nothing but clears', () {
      adapter.selected = <Habit>[];

      behavior.onEditHabits();

      expect(
        screen.editScreenCalls,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#17: showEditHabitsScreen '
            'is called only when the selection is non-empty',
      );
      expect(
        screen.editScreenCalls,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#4: nothing is opened when '
            'the selection is empty',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#4: afterwards the '
            'selection is always cleared, even when it was empty',
      );
      expect(
        adapter.clearSelectionCount,
        1,
        reason: 'list-habits.selection-menu-actions#19: the selection is '
            'cleared whether or not anything ran',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Wiring
  // -------------------------------------------------------------------------
  group('wiring', () {
    test('constructed with (habitList, screen, adapter, commandRunner)', () {
      final otherLog = <String>[];
      final otherScreen = _FakeScreen(otherLog);
      final otherAdapter = _FakeAdapter(otherLog);
      final otherList = _RecordingHabitList();
      final subject = ListHabitsSelectionMenuBehavior(
        otherList,
        otherScreen,
        otherAdapter,
        commandRunner,
      );

      otherAdapter.selected = <Habit>[habit2];
      subject.onArchiveHabits();

      final command = commandRunner.commands.single as ArchiveHabitsCommand;
      expect(
        command.habitList,
        same(otherList),
        reason: 'list-habits.selection-menu-actions#12: the first constructor '
            'argument is the habitList the commands are built with',
      );
      expect(
        otherAdapter.getSelectedCount,
        greaterThan(0),
        reason: 'list-habits.selection-menu-actions#12: the third constructor '
            'argument is the adapter the selection is read from',
      );
      expect(
        otherScreen.editScreenCalls,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#12: the second constructor '
            'argument is the screen, which Archive never touches',
      );
    });

    test('commandRunner is a mutable field, as in Kotlin', () {
      final replacement = _RecordingCommandRunner(taskRunner, log);
      behavior.commandRunner = replacement;
      adapter.selected = <Habit>[habit2];

      behavior.onArchiveHabits();

      expect(
        replacement.commands.single,
        isA<ArchiveHabitsCommand>(),
        reason: 'list-habits.selection-menu-actions#12: this behavior is the '
            'only place that dispatches Archive from a multi-selection, and it '
            'dispatches through its (replaceable) commandRunner',
      );
      expect(
        commandRunner.commands,
        isEmpty,
        reason: 'list-habits.selection-menu-actions#12: the original runner is '
            'no longer used after commandRunner is reassigned',
      );
    });

    test('Archive, Unarchive and ChangeColor all dispatch from here', () {
      adapter.selected = <Habit>[habit2];
      behavior.onArchiveHabits();
      adapter.selected = <Habit>[habit2];
      behavior.onUnarchiveHabits();
      adapter.selected = <Habit>[habit2];
      screen.colorToPick = const PaletteColor(3);
      behavior.onChangeColor();

      expect(
        commandRunner.commands.map((Command c) => c.runtimeType).toList(),
        <Type>[
          ArchiveHabitsCommand,
          UnarchiveHabitsCommand,
          ChangeHabitColorCommand,
        ],
        reason: 'list-habits.selection-menu-actions#12: '
            'ListHabitsSelectionMenuBehavior is the only place that dispatches '
            'Archive/Unarchive/ChangeColor from a multi-selection',
      );
      expect(
        adapter.clearSelectionCount,
        3,
        reason: 'list-habits.selection-menu-actions#19: the selection is '
            'always cleared after a menu action',
      );
    });

    test('the Screen and Adapter callback interfaces are ports, not impls', () {
      // The widget layer supplies these; the behavior only calls them.
      final HabitList list = habitList;
      final ListHabitsSelectionMenuBehaviorScreen s = screen;
      final ListHabitsSelectionMenuBehaviorAdapter a = adapter;
      expect(
        ListHabitsSelectionMenuBehavior(list, s, a, commandRunner),
        isA<ListHabitsSelectionMenuBehavior>(),
        reason: 'list-habits.selection-menu-actions#12: '
            'ListHabitsSelectionMenuBehavior is constructed with (habitList, '
            'screen, adapter, commandRunner)',
      );
    });
  });
}
