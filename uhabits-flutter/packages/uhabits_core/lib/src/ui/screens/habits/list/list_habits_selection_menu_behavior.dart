import '../../../../commands/archive_habits_command.dart';
import '../../../../commands/change_habit_color_command.dart';
import '../../../../commands/command_runner.dart';
import '../../../../commands/delete_habits_command.dart';
import '../../../../commands/unarchive_habits_command.dart';
import '../../../../models/habit.dart';
import '../../../../models/habit_list.dart';
import '../../../../models/palette_color.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/callbacks/OnColorPickedCallback.kt
///
/// ```kotlin
/// fun interface OnColorPickedCallback {
///     fun onColorPicked(color: PaletteColor)
/// }
/// ```
///
/// A Kotlin `fun interface` with a single method is a Dart function type. It
/// belongs in `ui/callbacks/`, and moves there when that slice lands; it is
/// declared here so this file can be ported on its own.
typedef OnColorPickedCallback = void Function(PaletteColor color);

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/callbacks/OnConfirmedCallback.kt
///
/// ```kotlin
/// fun interface OnConfirmedCallback {
///     fun onConfirmed()
/// }
/// ```
///
/// There is no `onCancelled` counterpart: a dialog that is dismissed simply
/// never calls back, which is why cancelling any of these menu actions leaves
/// the selection untouched.
typedef OnConfirmedCallback = void Function();

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsSelectionMenuBehavior.kt
///
/// The presenter behind the contextual action bar that appears once at least
/// one habit is selected in the habit list. It owns no state of its own: the
/// selection lives in the list adapter, which it reads through [Adapter], and
/// every dialog it needs is opened through [Screen]. Both of those are
/// implemented by the view layer.
///
/// Kotlin nests the two interfaces inside the class; Dart has no nested
/// classes, so they become the top-level
/// [ListHabitsSelectionMenuBehaviorAdapter] and
/// [ListHabitsSelectionMenuBehaviorScreen].
///
/// This is the only place that dispatches `ArchiveHabitsCommand`,
/// `UnarchiveHabitsCommand` and `ChangeHabitColorCommand` from a multiple
/// selection. Note that `onEditHabits` dispatches nothing at all: editing is
/// the edit screen's own job, and this class only opens it.
///
/// Every method reads `adapter.getSelected()` afresh, several times per action,
/// rather than capturing it once. For the dialog-driven actions that means the
/// command is built from whatever is selected *when the dialog is answered*,
/// which need not be what was selected when it was opened.
class ListHabitsSelectionMenuBehavior {
  ListHabitsSelectionMenuBehavior(
    this._habitList,
    this._screen,
    this._adapter,
    this.commandRunner,
  );

  final HabitList _habitList;

  final ListHabitsSelectionMenuBehaviorScreen _screen;

  final ListHabitsSelectionMenuBehaviorAdapter _adapter;

  /// `var commandRunner: CommandRunner` in Kotlin: the one constructor
  /// parameter that is a mutable public property rather than a private val.
  CommandRunner commandRunner;

  /// Whether the Archive item should be offered: false as soon as any selected
  /// habit is already archived.
  ///
  /// An empty selection returns true, vacuously — the loop simply never runs.
  /// The menu never shows in that state, so upstream never noticed.
  bool canArchive() {
    for (final habit in _adapter.getSelected()) {
      if (habit.isArchived) return false;
    }
    return true;
  }

  /// Whether the Edit item should be offered: only for a selection of exactly
  /// one habit — zero and two or more both return false.
  bool canEdit() {
    return _adapter.getSelected().length == 1;
  }

  /// Whether the Unarchive item should be offered: false as soon as any
  /// selected habit is not archived. Vacuously true for an empty selection.
  bool canUnarchive() {
    for (final habit in _adapter.getSelected()) {
      if (!habit.isArchived) return false;
    }
    return true;
  }

  /// Archives every selected habit, then drops the selection.
  ///
  /// No confirmation is asked for, and there is no undo: un-archiving is a
  /// separate forward action. The command is dispatched unconditionally, so an
  /// empty selection still runs a no-op `ArchiveHabitsCommand`.
  void onArchiveHabits() {
    commandRunner.run(ArchiveHabitsCommand(_habitList, _adapter.getSelected()));
    _adapter.clearSelection();
  }

  /// Opens the colour picker seeded with the colour of the *first* selected
  /// habit, and, if a colour comes back, paints the whole selection with it.
  ///
  /// The seed is read as `adapter.getSelected()[0].color` with no emptiness
  /// check, reproducing upstream: calling this with nothing selected throws
  /// (Kotlin `IndexOutOfBoundsException`, Dart [RangeError]) before the picker
  /// is even shown. The menu is only reachable from selection mode, where the
  /// selection is non-empty by construction.
  ///
  /// Dismissing the picker never calls back, so nothing runs and the selection
  /// survives.
  void onChangeColor() {
    final color = _adapter.getSelected()[0].color;
    _screen.showColorPicker(color, (PaletteColor selectedColor) {
      commandRunner.run(
        ChangeHabitColorCommand(
          _habitList,
          _adapter.getSelected(),
          selectedColor,
        ),
      );
      _adapter.clearSelection();
    });
  }

  /// Asks the screen for a confirmation, passing the number of selected habits
  /// so the dialog can pluralise its title and message.
  ///
  /// Only confirmation does anything, and then in this exact order: the habits
  /// are removed from the adapter's cache first — optimistically, so the list
  /// animates out immediately — then `DeleteHabitsCommand` removes them from
  /// the habit list, then the selection is cleared. Deletion is permanent.
  void onDeleteHabits() {
    _screen.showDeleteConfirmationScreen(
      () {
        _adapter.performRemove(_adapter.getSelected());
        commandRunner.run(
          DeleteHabitsCommand(_habitList, _adapter.getSelected()),
        );
        _adapter.clearSelection();
      },
      _adapter.getSelected().length,
    );
  }

  /// Opens the edit screen for the selection, then drops it.
  ///
  /// Unlike every other action here this dispatches no command — the edit
  /// screen builds and runs its own `EditHabitCommand` when the user saves.
  /// The selection is cleared whether or not the screen was opened.
  void onEditHabits() {
    final selected = _adapter.getSelected();
    if (selected.isNotEmpty) _screen.showEditHabitsScreen(selected);
    _adapter.clearSelection();
  }

  /// Un-archives every selected habit, then drops the selection. The mirror of
  /// [onArchiveHabits], and equally unconditional.
  void onUnarchiveHabits() {
    commandRunner.run(
      UnarchiveHabitsCommand(_habitList, _adapter.getSelected()),
    );
    _adapter.clearSelection();
  }
}

/// Port of `ListHabitsSelectionMenuBehavior.Adapter`.
///
/// The selection itself belongs to the list adapter, not to the behavior; this
/// is the whole of what the behavior needs from it. Implemented by the widget
/// layer.
abstract interface class ListHabitsSelectionMenuBehaviorAdapter {
  /// Deselects everything. Called at the end of every completed menu action.
  void clearSelection();

  /// The currently selected habits, in selection order. Called repeatedly
  /// rather than cached — see the class doc of
  /// [ListHabitsSelectionMenuBehavior].
  List<Habit> getSelected();

  /// Drops the given habits from the adapter's cache without touching the
  /// habit list, so the rows disappear before the delete command has run.
  void performRemove(List<Habit> selected);
}

/// Port of `ListHabitsSelectionMenuBehavior.Screen`.
///
/// Every member opens something the behavior itself cannot draw. Implemented by
/// the widget layer.
abstract interface class ListHabitsSelectionMenuBehaviorScreen {
  /// Opens the colour picker, pre-selecting [defaultColor]. [callback] fires
  /// only when a colour is chosen; a dismissal is silent.
  void showColorPicker(
    PaletteColor defaultColor,
    OnColorPickedCallback callback,
  );

  /// Opens the delete confirmation. [quantity] is the number of habits about
  /// to be deleted, used to pluralise the strings. [callback] fires only on
  /// Yes.
  void showDeleteConfirmationScreen(
    OnConfirmedCallback callback,
    int quantity,
  );

  /// Opens the edit screen for [selected]; upstream edits its first element.
  void showEditHabitsScreen(List<Habit> selected);
}
