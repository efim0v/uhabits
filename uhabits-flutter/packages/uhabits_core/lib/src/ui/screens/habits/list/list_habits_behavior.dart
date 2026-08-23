/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt
///
/// The presenter behind every tap on the main screen. It owns no views: it
/// reads and writes the model, dispatches commands, and calls back into the
/// screen through [ListHabitsBehaviorScreen], which the Flutter widget layer
/// implements. Nothing here may import Flutter.
///
/// Two Kotlin quirks are load-bearing and reproduced verbatim:
///
///  * `onToggle` runs the command FIRST and shows the confetti afterwards,
///    while the numerical branch of `onEdit` shows the confetti BEFORE the
///    command. Both orders matter because the command mutates the habit whose
///    `color` the confetti reads.
///  * `onReorderHabit` and `onRepairDB` go straight to the model on a task
///    runner, bypassing `CommandRunner`, so no command listener — and
///    therefore no widget or reminder refresh — ever fires for them.
library;

import 'dart:async';
import 'dart:io';

import '../../../../commands/command_runner.dart';
import '../../../../commands/create_repetition_command.dart';
import '../../../../io/files.dart';
import '../../../../models/entry.dart';
import '../../../../models/habit.dart';
import '../../../../models/habit_list.dart';
import '../../../../models/habit_type.dart';
import '../../../../models/palette_color.dart';
import '../../../../preferences/preferences.dart';
import '../../../../tasks/task_runner.dart';
import '../../../../time/local_date.dart';

// ---------------------------------------------------------------------------
// Dialog callbacks
// ---------------------------------------------------------------------------

/// Port of `NumberPickerCallback` from
/// uhabits-core/.../ui/callbacks/DialogCallbacks.kt.
///
/// Kotlin declares it a `fun interface` with one abstract method and one
/// defaulted no-op, so the presenter can pass a lambda and the dialog still
/// gets an `onNumberPickerDismissed`. Dart has no SAM conversion and
/// `implements` would not inherit the default body, so this is an abstract
/// *class* that implementations extend. The number dialog itself belongs to
/// the widget layer.
abstract class NumberPickerCallback {
  void onNumberPicked(double newValue, String notes);

  /// Defaulted to a no-op in Kotlin, which is exactly why a dismissed popup
  /// runs no command.
  void onNumberPickerDismissed() {}
}

/// Port of `CheckMarkDialogCallback` from the same Kotlin file.
abstract class CheckMarkDialogCallback {
  void onNotesSaved(int value, String notes);

  /// Defaulted to a no-op in Kotlin.
  void onNotesDismissed() {}
}

/// The lambda the Kotlin presenter passes to `showNumberPopup`.
class _FunctionNumberPickerCallback extends NumberPickerCallback {
  _FunctionNumberPickerCallback(this._onPicked);

  final void Function(double newValue, String notes) _onPicked;

  @override
  void onNumberPicked(double newValue, String notes) =>
      _onPicked(newValue, notes);
}

/// The lambda the Kotlin presenter passes to `showCheckmarkPopup`.
class _FunctionCheckMarkDialogCallback extends CheckMarkDialogCallback {
  _FunctionCheckMarkDialogCallback(this._onSaved);

  final void Function(int value, String notes) _onSaved;

  @override
  void onNotesSaved(int value, String notes) => _onSaved(value, notes);
}

// ---------------------------------------------------------------------------
// Nested Kotlin declarations, flattened
// ---------------------------------------------------------------------------

/// Port of the nested `ListHabitsBehavior.Message` enum. Dart has no nested
/// types, so the Kotlin name is prefixed, as `Preferences.Listener` became
/// `PreferencesListener`. Exactly six values, in this order.
enum ListHabitsBehaviorMessage {
  couldNotExport,
  importSuccessful,
  importFailed,
  databaseRepaired,
  couldNotGenerateBugReport,
  fileNotRecognized,
}

/// Port of the nested `ListHabitsBehavior.BugReporter` interface. The Android
/// implementation dumps logcat to a file; the Flutter app supplies its own.
abstract interface class ListHabitsBehaviorBugReporter {
  void dumpBugReportToFile();

  String getBugReport();
}

/// Port of the nested `ListHabitsBehavior.DirFinder` interface.
abstract interface class ListHabitsBehaviorDirFinder {
  UserFile getCSVOutputDir();
}

/// Port of the nested `ListHabitsBehavior.Screen` interface: every call the
/// presenter makes back into the UI. The widget layer implements it.
abstract interface class ListHabitsBehaviorScreen {
  void showHabitScreen(Habit h);

  void showIntroScreen();

  void showMessage(ListHabitsBehaviorMessage m);

  void showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  );

  void showCheckmarkPopup(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  );

  void showSendBugReportToDeveloperScreen(String log);

  void showSendFileScreen(String filename);

  /// `x` and `y` are `Float` in Kotlin. A burst at exactly (0, 0) is skipped
  /// by the Android implementation; that is the screen's business, not the
  /// presenter's.
  void showConfetti(PaletteColor color, double x, double y);
}

/// Port of `ExportCSVListener`, the `fun interface` `ExportCSVTask` reports to.
typedef ExportCsvListener = void Function(String? filename);

/// Builds the `ExportCSVTask` that [ListHabitsBehavior.onExportCSV] runs.
///
/// `ExportCSVTask` lives in `uhabits-core/.../tasks/` and drives
/// `HabitsCSVExporter`; neither belongs to this slice, so the presenter takes
/// the constructor as a seam instead. The arguments and their order mirror the
/// Kotlin constructor exactly: `ExportCSVTask(habitList, selectedHabits,
/// outputDir, listener)`. The task is expected to swallow its own failures and
/// report a null filename, as the Kotlin one does.
typedef ExportCsvTaskFactory = Task Function(
  HabitList habitList,
  List<Habit> selectedHabits,
  UserFile outputDir,
  ExportCsvListener listener,
);

// ---------------------------------------------------------------------------
// The presenter
// ---------------------------------------------------------------------------

class ListHabitsBehavior {
  /// The first seven arguments are the Kotlin `@Inject` constructor, in order.
  /// [exportCsvTaskFactory] is the extra seam described on
  /// [ExportCsvTaskFactory]; it is named so the positional prefix keeps
  /// matching the original.
  ListHabitsBehavior(
    this._habitList,
    this._dirFinder,
    this._taskRunner,
    this._screen,
    this._commandRunner,
    this._prefs,
    this._bugReporter, {
    required ExportCsvTaskFactory exportCsvTaskFactory,
  }) : _exportCsvTaskFactory = exportCsvTaskFactory;

  final HabitList _habitList;
  final ListHabitsBehaviorDirFinder _dirFinder;
  final TaskRunner _taskRunner;
  final ListHabitsBehaviorScreen _screen;
  final CommandRunner _commandRunner;
  final Preferences _prefs;
  final ListHabitsBehaviorBugReporter _bugReporter;
  final ExportCsvTaskFactory _exportCsvTaskFactory;

  void onClickHabit(Habit h) {
    _screen.showHabitScreen(h);
  }

  /// Opens the entry edit popup for [habit] on [date].
  ///
  /// Reads `habit.computedEntries.get(date)` — the derived list, so a YES_AUTO
  /// day shows up as such — and branches on the habit type.
  void onEdit(Habit habit, LocalDate date, double x, double y) {
    final entry = habit.computedEntries.get(date);
    if (habit.type == HabitType.numerical) {
      final oldValue = entry.value / 1000;
      _screen.showNumberPopup(
        oldValue,
        entry.notes,
        _FunctionNumberPickerCallback((double newValue, String newNotes) {
          final value = _roundToInt(newValue * 1000);
          if (newValue != oldValue) {
            if ((habit.targetType == NumericalHabitType.atLeast &&
                    newValue >= habit.targetValue) ||
                (habit.targetType == NumericalHabitType.atMost &&
                    newValue <= habit.targetValue)) {
              _screen.showConfetti(habit.color, x, y);
            }
          }
          _commandRunner.run(
            CreateRepetitionCommand(_habitList, habit, date, value, newNotes),
          );
        }),
      );
    } else {
      _screen.showCheckmarkPopup(
        entry.value,
        entry.notes,
        habit.color,
        _FunctionCheckMarkDialogCallback((int newValue, String newNotes) {
          if (newValue != entry.value && newValue == Entry.yesManual) {
            _screen.showConfetti(habit.color, x, y);
          }
          _commandRunner.run(
            CreateRepetitionCommand(
              _habitList,
              habit,
              date,
              newValue,
              newNotes,
            ),
          );
        }),
      );
    }
  }

  /// Exports every habit in the list — `habitList.toList()`, not a selection
  /// and not the current filter — into the CSV output directory.
  void onExportCSV() {
    final selected = _habitList.toList();
    final outputDir = _dirFinder.getCSVOutputDir();
    _taskRunner.execute(
      _exportCsvTaskFactory(_habitList, selected, outputDir, (String? filename) {
        if (filename != null) {
          _screen.showSendFileScreen(filename);
        } else {
          _screen.showMessage(ListHabitsBehaviorMessage.couldNotExport);
        }
      }),
    );
  }

  /// Seeds `last_hint_number` with -1 and `last_hint_timestamp` with today, so
  /// `HintList.shouldShow()` stays false until the next day.
  void onFirstRun() {
    _prefs.isFirstRun = false;
    _prefs.updateLastHint(-1, getToday());
    _screen.showIntroScreen();
  }

  /// Manual drag-and-drop reordering. Straight to the model on a background
  /// task: no command, so nothing listening to [CommandRunner] is notified.
  void onReorderHabit(Habit from, Habit to) {
    _taskRunner.execute(_FunctionTask(() => _habitList.reorder(from, to)));
  }

  /// Also bypasses [CommandRunner]. The Kotlin body is an anonymous
  /// `object : Task` whose `doInBackground` repairs and whose `onPostExecute`
  /// reports, which is why the message always follows the repair.
  void onRepairDB() {
    _taskRunner.execute(_RepairTask(_habitList, _screen));
  }

  void onSendBugReport() {
    _bugReporter.dumpBugReportToFile();
    try {
      final log = _bugReporter.getBugReport();
      _screen.showSendBugReportToDeveloperScreen(log);
    } catch (e, s) {
      // Kotlin catches `Exception` and calls `e.printStackTrace()`, which
      // writes to stderr. Dart's `Error` subtypes stand for the Java
      // RuntimeExceptions that `Exception` would have caught, so the catch is
      // deliberately untyped.
      stderr.writeln(e);
      stderr.writeln(s);
      _screen.showMessage(
        ListHabitsBehaviorMessage.couldNotGenerateBugReport,
      );
    }
  }

  void onStartup() {
    _prefs.incrementLaunchCount();
    if (_prefs.isFirstRun) onFirstRun();
  }

  /// A toggle straight from a row. The command runs first; the confetti is
  /// shown afterwards, and only for [Entry.yesManual].
  void onToggle(
    Habit habit,
    LocalDate date,
    int value,
    String notes,
    double x,
    double y,
  ) {
    _commandRunner.run(
      CreateRepetitionCommand(_habitList, habit, date, value, notes),
    );
    if (value == Entry.yesManual) _screen.showConfetti(habit.color, x, y);
  }
}

/// Port of Kotlin's `Double.roundToInt()`, which delegates to `Math.round` and
/// therefore rounds ties towards positive infinity. Dart's `double.round()`
/// rounds ties away from zero instead, so `-0.5` would give -1 there and 0
/// here.
int _roundToInt(double value) => (value + 0.5).floor();

/// The SAM-converted `taskRunner.execute { ... }` of `onReorderHabit`.
class _FunctionTask extends Task {
  _FunctionTask(this._block);

  final void Function() _block;

  @override
  FutureOr<void> doInBackground() {
    _block();
  }
}

/// The anonymous `object : Task` of `onRepairDB`.
class _RepairTask extends Task {
  _RepairTask(this._habitList, this._screen);

  final HabitList _habitList;
  final ListHabitsBehaviorScreen _screen;

  @override
  FutureOr<void> doInBackground() {
    _habitList.repair();
  }

  @override
  void onPostExecute() {
    _screen.showMessage(ListHabitsBehaviorMessage.databaseRepaired);
  }
}
