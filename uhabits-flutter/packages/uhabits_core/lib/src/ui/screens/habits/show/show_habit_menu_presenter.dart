/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabitMenuPresenter.kt
///
/// The presenter behind the overflow menu of the habit detail screen. It owns
/// no views and no state: it answers the two visibility questions the menu asks
/// (`canArchive`, `canUnarchive`), and every menu item maps to one `on…`
/// method that dispatches a command, opens a dialog through [Screen], or —
/// in the case of Randomize — edits the model directly.
///
/// Which item is on screen at all is the view's business: the Android menu XML
/// declares Export, Archive, Unarchive, Delete, Edit and Randomize, hides
/// Randomize unless `preferences.isDeveloper`, and asks this class only whether
/// Archive and Unarchive apply. None of that is reproduced here.
///
/// Three quirks are load-bearing and reproduced verbatim:
///
///  * every command is built from `listOf(habit)`, a fresh one-element list;
///  * the confirmation messages are shown at dispatch time, right after
///    `commandRunner.run(...)`, not when the command finishes;
///  * `onRandomize` bypasses `CommandRunner` entirely — it mutates
///    `habit.originalEntries` in place, so the change is not undoable and no
///    command listener (widgets, reminders, the list cache) ever hears about
///    it.
library;

import 'dart:math' as math;

import '../../../../commands/archive_habits_command.dart';
import '../../../../commands/command_runner.dart';
import '../../../../commands/delete_habits_command.dart';
import '../../../../commands/unarchive_habits_command.dart';
import '../../../../io/files.dart';
import '../../../../io/habits_csv_exporter.dart';
import '../../../../models/entry.dart';
import '../../../../models/habit.dart';
import '../../../../models/habit_list.dart';
import '../../../../tasks/task_runner.dart';
import '../../../../time/local_date.dart';

// ---------------------------------------------------------------------------
// Nested Kotlin declarations, flattened
// ---------------------------------------------------------------------------

/// Port of the nested `ShowHabitMenuPresenter.Message` enum. Dart has no nested
/// types, so the Kotlin name is prefixed, as `ListHabitsBehavior.Message`
/// became `ListHabitsBehaviorMessage`. Exactly three values, in this order.
enum ShowHabitMenuPresenterMessage {
  couldNotExport,
  habitArchived,
  habitUnarchived,
}

/// Port of the nested `ShowHabitMenuPresenter.Screen` interface: every call the
/// presenter makes back into the UI. The widget layer implements it.
///
/// The Android implementation renders [showMessage] as a short Snackbar,
/// [showDeleteConfirmationScreen] as an AlertDialog with Yes/No buttons — the
/// quantity for its plural strings is hard-coded to 1 there, which is why no
/// count crosses this interface — and [close] as `finish()`.
abstract interface class ShowHabitMenuPresenterScreen {
  void showEditHabitScreen(Habit habit);

  /// Kotlin declares the parameter as `Message?`; the Android implementation
  /// has an `else -> {}` branch, so a null message shows nothing.
  void showMessage(ShowHabitMenuPresenterMessage? m);

  void showSendFileScreen(String filename);

  /// [callback] is Kotlin's `OnConfirmedCallback`, a `fun interface` with a
  /// single `onConfirmed()`; in Dart that is a plain `void Function()`. There
  /// is no `onCancelled` counterpart: a dialog answered "No" or dismissed
  /// simply never calls back, which is why cancelling a delete leaves the
  /// screen untouched.
  void showDeleteConfirmationScreen(void Function() callback);

  void close();

  void refresh();
}

/// Port of the nested `ShowHabitMenuPresenter.System` interface, whose only job
/// is to name the directory CSV exports are written into.
abstract interface class ShowHabitMenuPresenterSystem {
  UserFile getCSVOutputDir();
}

/// The lambda the Kotlin presenter passes to `ExportCSVTask`. Kotlin's
/// `ExportCSVListener` is a `fun interface`, so it accepts a lambda there; the
/// Dart port of the task takes an [ExportCSVListener] object, so the closure
/// becomes this one-method class.
class _ExportCSVScreenListener implements ExportCSVListener {
  _ExportCSVScreenListener(this._screen);

  final ShowHabitMenuPresenterScreen _screen;

  @override
  void onExportCSVFinished(String? archiveFilename) {
    if (archiveFilename != null) {
      _screen.showSendFileScreen(archiveFilename);
    } else {
      _screen.showMessage(ShowHabitMenuPresenterMessage.couldNotExport);
    }
  }
}

// ---------------------------------------------------------------------------
// The presenter
// ---------------------------------------------------------------------------

class ShowHabitMenuPresenter {
  /// The six named arguments are the Kotlin constructor, in its order.
  ///
  /// [random] is the one addition: Kotlin's [onRandomize] reaches for the
  /// global `kotlin.random.Random`, which nothing can steer, so the generator
  /// is taken as an optional seam here and defaults to a fresh
  /// [math.Random] — the same unseeded, unpredictable source the Kotlin code
  /// uses.
  ShowHabitMenuPresenter({
    required CommandRunner commandRunner,
    required Habit habit,
    required HabitList habitList,
    required ShowHabitMenuPresenterScreen screen,
    required ShowHabitMenuPresenterSystem system,
    required TaskRunner taskRunner,
    math.Random? random,
  })  : _commandRunner = commandRunner,
        _habit = habit,
        _habitList = habitList,
        _screen = screen,
        _system = system,
        _taskRunner = taskRunner,
        _random = random ?? math.Random();

  final CommandRunner _commandRunner;

  final Habit _habit;

  final HabitList _habitList;

  final ShowHabitMenuPresenterScreen _screen;

  final ShowHabitMenuPresenterSystem _system;

  final TaskRunner _taskRunner;

  final math.Random _random;

  /// Whether the Archive item applies: the plain negation of the flag, read
  /// fresh every time. The Android menu only asks once, in
  /// `onCreateOptionsMenu`, so the item it drew stays as it was until the
  /// options menu is rebuilt.
  bool canArchive() {
    return !_habit.isArchived;
  }

  /// Whether the Unarchive item applies. The exact mirror of [canArchive].
  bool canUnarchive() {
    return _habit.isArchived;
  }

  /// Opens the editor. Dispatches nothing and changes nothing: the edit screen
  /// builds and runs its own `EditHabitCommand` when the user saves, and the
  /// show screen is left open behind it.
  void onEditHabit() {
    _screen.showEditHabitScreen(_habit);
  }

  /// Archives the habit, then says so.
  ///
  /// The message is shown synchronously, immediately after the command is
  /// handed to the runner — not when it finishes — so it appears even if the
  /// command later throws. The screen is not closed.
  void onArchiveHabits() {
    _commandRunner.run(ArchiveHabitsCommand(_habitList, <Habit>[_habit]));
    _screen.showMessage(ShowHabitMenuPresenterMessage.habitArchived);
  }

  /// Exports this one habit to a CSV zip, straight on the task runner: no
  /// command is dispatched, so nothing else in the app is notified.
  ///
  /// The task swallows its own failures and reports a null filename, which is
  /// what turns into [ShowHabitMenuPresenterMessage.couldNotExport].
  void onExportCSV() {
    final outputDir = _system.getCSVOutputDir();
    _taskRunner.execute(
      ExportCSVTask(
        _habitList,
        <Habit>[_habit],
        outputDir,
        _ExportCSVScreenListener(_screen),
      ),
    );
  }

  /// Asks the screen to confirm, and deletes only if it does.
  ///
  /// On confirmation the command is dispatched and the screen closed straight
  /// away, without waiting for the command to complete. Answering "No" or
  /// dismissing the dialog never calls back, so nothing at all happens.
  void onDeleteHabit() {
    _screen.showDeleteConfirmationScreen(() {
      _commandRunner.run(DeleteHabitsCommand(_habitList, <Habit>[_habit]));
      _screen.close();
    });
  }

  /// Un-archives the habit, then says so. The mirror of [onArchiveHabits].
  void onUnarchiveHabits() {
    _commandRunner.run(UnarchiveHabitsCommand(_habitList, <Habit>[_habit]));
    _screen.showMessage(ShowHabitMenuPresenterMessage.habitUnarchived);
  }

  /// Replaces the habit's entries with five years of pseudo-random data.
  ///
  /// A developer-only action, hidden from the menu unless
  /// `preferences.isDeveloper` is set; the gating lives in the view, not here.
  ///
  /// It walks backwards from today one day at a time, carrying a `strength`
  /// that starts at 50 and is re-rolled every seventh day by a Gaussian step,
  /// clamped to 0..100. A day is skipped when a fresh `nextInt(100)` beats the
  /// current strength, so a weak stretch leaves gaps and a strong one fills in
  /// almost every day.
  ///
  /// This deliberately bypasses [CommandRunner]: the entries are written
  /// straight into the model, `recompute()` is called by hand and the screen is
  /// refreshed directly. Nothing is undoable and no command listener fires, so
  /// widgets, reminders and the habit-list cache keep showing the old data
  /// until something else refreshes them.
  void onRandomize() {
    _habit.originalEntries.clear();
    var strength = 50.0;
    for (var i = 0; i < 365 * 5; i++) {
      if (i % 7 == 0) {
        strength = math.max(
          0.0,
          math.min(100.0, strength + 10 * _nextGaussian()),
        );
      }
      if (_random.nextInt(100) > strength) continue;
      var value = Entry.yesManual;
      if (_habit.isNumerical) {
        value = (1000 + 250 * _nextGaussian() * strength / 100).toInt() * 1000;
      }
      _habit.originalEntries.add(Entry(getToday().minus(i), value));
    }
    _habit.recompute();
    _screen.refresh();
  }

  /// A Box-Muller transform over two uniform draws: Kotlin's
  /// `sqrt(-2.0 * ln(u1)) * cos(2.0 * PI * u2)`.
  ///
  /// `Random.nextDouble()` can return exactly 0 in both languages, and `ln(0)`
  /// is `-inf`, so this can hand back an infinite sample; the `min`/`max` clamp
  /// in [onRandomize] is what keeps `strength` finite when it does.
  double _nextGaussian() {
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
  }
}
