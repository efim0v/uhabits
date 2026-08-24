/// Port of the `CommandRunner.Listener` half of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsScreen.kt:
///
/// ```kotlin
/// fun onAttached() { commandRunner.addListener(this) }
/// fun onDetached() { commandRunner.removeListener(this) }
///
/// override fun onCommandFinished(command: Command) {
///     val msg = getExecuteString(command)
///     if (msg != null) activity.showMessage(msg)
/// }
/// ```
///
/// The listener is registered from `ListHabitsActivity.onResume` and removed in
/// `onPause`, so toasts appear only while the habit list screen is in the
/// foreground (`commands.listener-list-habits-toasts#1`). It is notified for
/// every command type; the filtering is [getExecuteString]'s `else -> null`
/// branch, not the runner's (`commands.listener-list-habits-toasts#2`, `#4`).
///
/// `Activity.showMessage` is a `Snackbar.LENGTH_SHORT` with no action button:
/// none of these messages carries an UNDO affordance, because this fork has no
/// undo (`commands.listener-list-habits-toasts#5`, `commands.no-undo-redo#1`).
/// The snackbar itself lives in lib/ui/common/show_message.dart — one helper
/// for the whole app, the way upstream has exactly one `View.showMessage`
/// (`audit24.one-show-message-helper-one-lifetime#1`).
library;

// The command layer is not re-exported from uhabits_core.dart; see
// state/app_scope.dart.
// ignore_for_file: implementation_imports

import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/edit_habit_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';

import '../../../l10n/app_localizations.dart';

/// `ListHabitsScreen.getExecuteString(command)`.
///
/// Returns null for every command the `when` does not name — most importantly
/// `CreateRepetitionCommand`, so ticking a checkmark never produces a toast
/// (`commands.listener-list-habits-toasts#4`).
///
/// The quantity of each plural is `command.selected.size`, except for
/// `EditHabitCommand`, whose quantity is hard-coded to 1
/// (`commands.listener-list-habits-toasts#3`).
String? getExecuteString(L10n l10n, Command command) {
  if (command is ArchiveHabitsCommand) {
    // R.plurals.toast_habits_archived (`commands.archive-habits#9`).
    return l10n.toastHabitsArchived(command.selected.length);
  }
  if (command is ChangeHabitColorCommand) {
    // R.plurals.toast_habits_changed (`commands.change-habit-color#8`).
    return l10n.toastHabitsChanged(command.selected.length);
  }
  if (command is CreateHabitCommand) {
    // R.string.toast_habit_created — not a plural.
    return l10n.toastHabitCreated;
  }
  if (command is DeleteHabitsCommand) {
    // R.plurals.toast_habits_deleted.
    return l10n.toastHabitsDeleted(command.selected.length);
  }
  if (command is EditHabitCommand) {
    // R.plurals.toast_habits_changed with quantity hard-coded to 1.
    return l10n.toastHabitsChanged(1);
  }
  if (command is UnarchiveHabitsCommand) {
    // R.plurals.toast_habits_unarchived (`commands.unarchive-habits#7`).
    return l10n.toastHabitsUnarchived(command.selected.length);
  }
  return null;
}

/// The listener itself, owned by the habit list screen for as long as it is
/// mounted.
class ListHabitsCommandToasts implements CommandRunnerListener {
  ListHabitsCommandToasts({
    required this.commandRunner,
    required this.strings,
    required this.showMessage,
  });

  final CommandRunner commandRunner;

  /// Read at notification time rather than captured, because the locale can
  /// change while the screen is up.
  final L10n Function() strings;

  /// `activity.showMessage(msg)`.
  final void Function(String message) showMessage;

  /// Whether this listener is currently registered.
  ///
  /// `CommandRunner.addListener` appends without a duplicate check, so a
  /// second `onAttached()` would make every toast appear twice. Android cannot
  /// reach that state — `onResume` always follows an `onPause` — but a Flutter
  /// screen hears about a resume from two sources at once (the app lifecycle
  /// and the route it sits on), so the guard is what keeps the pair balanced
  /// (`audit5.the-habit-list-command-toast-listener#1`).
  bool _attached = false;

  /// `ListHabitsActivity.onResume`.
  void onAttached() {
    if (_attached) return;
    _attached = true;
    commandRunner.addListener(this);
  }

  /// `ListHabitsActivity.onPause`.
  void onDetached() {
    if (!_attached) return;
    _attached = false;
    commandRunner.removeListener(this);
  }

  @override
  void onCommandFinished(Command command) {
    final msg = getExecuteString(strings(), command);
    if (msg != null) showMessage(msg);
  }
}
