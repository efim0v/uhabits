/// The screen-facing half of the create/edit habit screen.
///
/// Port of the state and the two behaviours of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/EditHabitActivity.kt
/// that are not view code: the fields the activity keeps between `onCreate`
/// and `save()`, its `validate()` and its `save()`.
///
/// The Android activity keeps eleven loose `var`s next to five `EditText`s and
/// reads them back on save. That is exactly what this class is: eleven fields,
/// five [TextEditingController]s, and the two methods that turn them into a
/// `CreateHabitCommand` or an `EditHabitCommand`. There is no core presenter
/// for this screen — the activity *is* the presenter upstream — so the rules
/// reproduced here come from the parity ledger's `edit-habit.*` features.
///
/// Deliberate deviations, both called out by the ledger itself:
///
///  * `edit-habit.validation#9` — Kotlin parses the target with
///    `String.toDouble()` and lets a `NumberFormatException` crash the screen.
///    The ledger asks the port to "parse defensively and reject with an inline
///    error instead", which is [EditHabitFieldError.notANumber].
///  * `edit-habit.instance-state#3` — the Android bundle drops `targetType` on
///    rotation, silently resetting the control to AT_LEAST. Flutter keeps the
///    state in this object for the life of the route, so the bug simply cannot
///    happen; the ledger says not to reproduce it.
library;

import 'dart:async';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/command.dart';

// The commands are not re-exported from uhabits_core.dart yet; see
// app_scope.dart, which reaches for them the same way.
// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/commands/edit_habit_command.dart';
import 'package:uhabits_core/uhabits_core.dart';

import 'app_scope.dart';

/// Why a field failed [EditHabitModel.validate].
///
/// The activity stores the rendered message on the `EditText` itself; this
/// carries the reason instead, so the widget layer owns the localisation.
enum EditHabitFieldError {
  /// `R.string.validation_cannot_be_blank`, the only validation string the
  /// Android app has (`edit-habit.validation#2`, `#4`).
  blank,

  /// The target text is not a number. Kotlin crashes here
  /// (`edit-habit.validation#9`); the port refuses the save instead.
  notANumber,
}

class EditHabitModel extends ChangeNotifier {
  /// [habitId] null means CREATE, and any non-null value means EDIT —
  /// `intent.hasExtra("habitId")` is what selects the mode
  /// (`edit-habit.entry-points#1`).
  ///
  /// In EDIT mode every field is seeded from the habit
  /// (`edit-habit.entry-points#4`, `#5`) and [habitType] is ignored, exactly
  /// as the Kotlin `if/else` ignores the `habitType` extra whenever `habitId`
  /// is present. Looking up an id that is not in the list throws, reproducing
  /// the non-null assertion of `edit-habit.entry-points#7`.
  EditHabitModel({
    required this.scope,
    int? habitId,
    HabitType habitType = HabitType.yesNo,
    bool sleep = false,
  }) {
    final id = habitId;
    if (id == null) {
      this.habitType = sleep ? sleepHabitType : habitType;
      if (sleep) {
        // A goal has to exist before the form can edit one. The defaults are
        // the model's, so a person who changes nothing is still measured
        // against something sensible.
        sleepGoal = SleepGoal(
          bedMinutes: 23 * 60,
          wakeMinutes: 7 * 60,
          homeUtcOffsetMinutes:
              DateUtils.currentTimeZone.getOffset(DateUtils.getLocalTime()) ~/
                  60000,
        );
      }
      return;
    }

    this.habitId = id;
    final habit = scope.habitList.getById(id)!;
    this.habitType = habit.type;
    color = habit.color;
    freqNum = habit.frequency.numerator;
    freqDen = habit.frequency.denominator;
    targetType = habit.targetType;
    final reminder = habit.reminder;
    if (reminder != null) {
      reminderHour = reminder.hour;
      reminderMin = reminder.minute;
      reminderDays = reminder.days;
    }
    nameController.text = habit.name;
    questionController.text = habit.question;
    notesController.text = habit.description;
    unitController.text = habit.unit;
    // `habit.targetValue.toString()`, so 15.0 shows as the literal "15.0".
    targetController.text = habit.targetValue.toString();
    sleepGoal = scope.sleepRepository.goalFor(id);
  }

  final AppScope scope;

  // -----------------------------------------------------------------------
  // The activity's own fields, with the defaults of
  // `edit-habit.entry-points#8`
  // -----------------------------------------------------------------------

  /// `var habitId = -1L`. Negative means CREATE — this is the value
  /// [save] branches on (`edit-habit.save#8`).
  int habitId = -1;

  /// `lateinit var habitType`. Never editable from this screen: there is no
  /// control for it and [save] always writes back what the screen was opened
  /// with (`edit-habit.entry-points#6`).
  late final HabitType habitType;

  /// `var color = PaletteColor(11)` — blue. Note this is NOT the `Habit`
  /// model's own default of `PaletteColor(8)` (teal): a habit created here
  /// without touching the picker is blue (`edit-habit.entry-points#9`).
  PaletteColor color = const PaletteColor(11);

  int freqNum = 1;

  int freqDen = 1;

  int reminderHour = -1;

  int reminderMin = -1;

  WeekdayList reminderDays = WeekdayList.everyDay;

  NumericalHabitType targetType = NumericalHabitType.atLeast;

  final TextEditingController nameController = TextEditingController();

  final TextEditingController questionController = TextEditingController();

  /// `notesInput`, which is persisted into `Habit.description`
  /// (`edit-habit.form-layout#6`).
  final TextEditingController notesController = TextEditingController();

  final TextEditingController unitController = TextEditingController();

  final TextEditingController targetController = TextEditingController();

  /// `nameInput.error`, as a reason rather than a rendered string.
  EditHabitFieldError? nameError;

  /// `targetInput.error`.
  EditHabitFieldError? targetError;

  // -----------------------------------------------------------------------
  // Derived state the view asks for
  // -----------------------------------------------------------------------

  /// EDIT mode. Decides the toolbar title (`edit-habit.entry-points#2`) and
  /// which command [save] dispatches (`edit-habit.save#8`).
  bool get isEditing => habitId >= 0;

  bool get isNumerical => habitType == HabitType.numerical;

  /// The sleep goal being edited, or null when this is not a sleep habit.
  ///
  /// There is no third [HabitType]: a habit is a sleep habit exactly when it
  /// has one of these. Holding it here rather than deriving it lets the editor
  /// build a goal for a habit that does not have one yet.
  SleepGoal? sleepGoal;

  /// Whether the form should show the sleep fields in place of the numerical
  /// ones.
  bool get isSleep => sleepGoal != null;

  void setSleepGoal(SleepGoal value) {
    sleepGoal = value;
    notifyListeners();
  }

  /// `reminderHour >= 0`: the whole reminder section is on or off together,
  /// there is no partial state (`edit-habit.reminder-time#1`, `#9`).
  bool get hasReminder => reminderHour >= 0;

  // -----------------------------------------------------------------------
  // The pickers
  // -----------------------------------------------------------------------

  /// `picker.setListener { paletteColor -> this.color = paletteColor;
  /// updateColors() }` (`edit-habit.color-control#2`).
  void setColor(PaletteColor value) {
    color = value;
    notifyListeners();
  }

  /// `FrequencyPickerDialog.onFrequencyPicked`: the pair is stored verbatim,
  /// with no further validation on this side
  /// (`frequency-picker.save-and-validation#9`).
  void setFrequency(int numerator, int denominator) {
    freqNum = numerator;
    freqDen = denominator;
    notifyListeners();
  }

  /// The numerical habit's three-item frequency list. It changes ONLY the
  /// denominator; the numerator is left alone, so a habit stored as 3/7 that
  /// picks "Every month" becomes 3/30
  /// (`edit-habit.numerical-frequency-picker#3`).
  void setFrequencyDenominator(int denominator) {
    freqDen = denominator;
    notifyListeners();
  }

  void setTargetType(NumericalHabitType value) {
    targetType = value;
    notifyListeners();
  }

  /// `TimePickerDialog.onTimeSet` (`edit-habit.reminder-time#5`).
  void setReminderTime(int hour, int minute) {
    reminderHour = hour;
    reminderMin = minute;
    notifyListeners();
  }

  /// `TimePickerDialog.onTimeCleared`: clearing the time also resets the days
  /// to every day (`edit-habit.reminder-time#6`).
  void clearReminder() {
    reminderHour = -1;
    reminderMin = -1;
    reminderDays = WeekdayList.everyDay;
    notifyListeners();
  }

  /// `WeekdayPickerDialog`'s listener. An empty selection is replaced by every
  /// day, so a reminder with zero days can never be saved
  /// (`edit-habit.reminder-days#2`).
  void setReminderDays(WeekdayList days) {
    reminderDays = days.isEmpty ? WeekdayList.everyDay : days;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // validate() and save()
  // -----------------------------------------------------------------------

  /// Port of `EditHabitActivity.validate()`.
  ///
  /// Both fields are checked in one pass, so a numerical habit with an empty
  /// name and an empty target shows both errors at once
  /// (`edit-habit.validation#5`). The name check runs on the raw text, before
  /// trimming, which is why a name of pure whitespace passes here and is then
  /// saved as an empty string (`edit-habit.validation#6`). Nothing else on the
  /// form is validated (`edit-habit.validation#7`, `#8`).
  bool validate() {
    var isValid = true;
    nameError = null;
    targetError = null;

    if (nameController.text.isEmpty) {
      nameError = EditHabitFieldError.blank;
      isValid = false;
    }
    // A sleep habit is numerical, but its target is settled by the model and
    // the field that would carry it is never shown. Validating it would refuse
    // to save a form the person was never given a chance to fill in.
    if (isNumerical && !isSleep) {
      if (targetController.text.isEmpty) {
        targetError = EditHabitFieldError.blank;
        isValid = false;
      } else if (double.tryParse(targetController.text) == null) {
        // Kotlin gets here and throws NumberFormatException out of save();
        // `edit-habit.validation#9` asks the port to reject instead.
        targetError = EditHabitFieldError.notANumber;
        isValid = false;
      }
    }

    notifyListeners();
    return isValid;
  }

  /// Port of `binding.buttonSave.setOnClickListener { if (validate()) save() }`
  /// plus `save()` itself.
  ///
  /// Returns whether the command was dispatched, which is what the view uses
  /// to decide whether to `finish()` (`edit-habit.save#11`, `#13`).
  bool save() {
    if (!validate()) return false;

    // Always a fresh habit from the factory; in EDIT mode the original is
    // copied over it first, which preserves position, uuid, isArchived and
    // everything the form does not touch (`edit-habit.save#1`, `#14`).
    final habit = scope.modelFactory.buildHabit();
    if (habitId >= 0) {
      habit.copyFrom(scope.habitList.getById(habitId)!);
    }

    habit.name = nameController.text.trim();
    habit.question = questionController.text.trim();
    habit.description = notesController.text.trim();
    habit.color = color;
    if (reminderHour >= 0) {
      habit.reminder = Reminder(reminderHour, reminderMin, reminderDays);
    } else {
      habit.reminder = null;
    }

    // Written for both habit types (`edit-habit.save#5`).
    habit.frequency = Frequency(freqNum, freqDen);

    // Only numerical habits write these three, so switching an existing
    // numerical habit to yes/no leaves the copied target and unit intact
    // (`edit-habit.save#6`, `#16`).
    // Same reason as in validate(): the sleep form never shows these, so
    // there is nothing here to parse.
    if (habitType == HabitType.numerical && !isSleep) {
      habit.targetValue = double.parse(targetController.text);
      habit.targetType = targetType;
      habit.unit = unitController.text.trim();
    }

    // A sleep habit is a numerical habit with these four settled for it. They
    // are not offered in the form: a percentage out of a hundred, scored daily,
    // is what the model measures, and a person who changed the target to fifty
    // would silently be scored against something else.
    if (isSleep) {
      habit.type = sleepHabitType;
      habit.targetValue = sleepTargetValue;
      habit.targetType = NumericalHabitType.atLeast;
      habit.unit = sleepUnit;
      habit.frequency = Frequency(1, 1);
    }

    // Last, as in Kotlin (`edit-habit.save#7`).
    habit.type = habitType;

    final command = habitId >= 0
        ? EditHabitCommand(scope.habitList, habitId, habit)
        : CreateHabitCommand(scope.modelFactory, scope.habitList, habit);

    // The goal is written once the command has actually run, not on the next
    // line. `CommandRunner.run` hands the command to a task runner; the
    // dispatcher a test uses executes it at once, the one a device uses does
    // not. Reading the result immediately worked in every test and silently
    // did nothing on a phone — the habit was created and the goal that makes
    // it a sleep habit was never stored.
    final SleepGoal? goal = sleepGoal;
    if (goal != null) {
      scope.commandRunner.addListener(
        _SleepGoalWriter(
          scope: scope,
          command: command,
          habitId: habitId,
          uuid: habit.uuid,
          goal: goal,
        ),
      );
    }

    scope.commandRunner.run(command);
    return true;
  }

  @override
  void dispose() {
    nameController.dispose();
    questionController.dispose();
    notesController.dispose();
    unitController.dispose();
    targetController.dispose();
    super.dispose();
  }
}

/// Stores a sleep goal once the command that creates or edits its habit has
/// finished.
///
/// A listener rather than a line after `run`: the command goes through a task
/// runner, so on a device the habit is not in the list yet when `save` returns.
class _SleepGoalWriter implements CommandRunnerListener {
  _SleepGoalWriter({
    required this.scope,
    required this.command,
    required this.habitId,
    required this.uuid,
    required this.goal,
  });

  final AppScope scope;
  final Command command;
  final int habitId;

  /// `CreateHabitCommand` keeps the form's habit as a template and builds its
  /// own, so that object never gets an id. The uuid is copied across, and is
  /// what identifies the one that did enter the list.
  final String? uuid;

  final SleepGoal goal;

  bool _done = false;

  @override
  void onCommandFinished(Command finished) {
    if (_done || !identical(finished, command)) return;
    _done = true;
    // Removed on a microtask: `notifyListeners` is iterating the very list
    // this would mutate.
    scheduleMicrotask(() => scope.commandRunner.removeListener(this));

    final Habit? saved =
        habitId >= 0 ? scope.habitList.getById(habitId) : _byUuid();
    if (saved?.id == null) return;

    scope.sleepRepository.saveGoal(saved!.id!, goal);
    // Changing a goal changes what every past night was worth. Rescoring only
    // from today would leave the history a mixture of two scales.
    scope.sleepSync.recomputeAll(saved);
    scope.onSleepDataChanged(saved.id!);
    // And a habit that has just become a sleep habit has never been synced:
    // without this it shows nothing until the app is backgrounded once.
    unawaited(scope.syncSleepHabits());
  }

  Habit? _byUuid() {
    final String? id = uuid;
    if (id == null) return null;
    for (final Habit habit in scope.habitList.toList()) {
      if (habit.uuid == id) return habit;
    }
    return null;
  }
}
