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
    ComputedKind? computed,
  }) {
    final id = habitId;
    if (id == null) {
      computedKind = computed;
      // Every computed kind is a numerical habit — `sleepHabitType` is that
      // same constant, spelled for sleep. There is no third `HabitType` and
      // there will not be one: `models.habit-type-enums#1` closes the enum at
      // two, and both tests on it pass unchanged.
      this.habitType = computed == null ? habitType : HabitType.numerical;
      if (computed == ComputedKind.sleep) {
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
      if (computed == ComputedKind.abstinence) {
        // Everything this form asks for has a default, so it can be saved with
        // nothing but a name: today, and no allowance at all.
        committedFrom = getToday().daysSince2000;
        targetController.text = '0';
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
    final HabitDefinition? definition = scope.definitions.forHabit(id);
    computedKind = definition?.kind;
    committedFrom = definition?.committedFrom ?? getToday().daysSince2000;
    if (computedKind == ComputedKind.abstinence) {
      // `targetValue.toString()` renders 30 as "30.0", which is what the
      // ported line above does and what its rule asks for. An allowance is a
      // count of minutes or of drinks, and "30.0 minutes" is not how anyone
      // writes one down.
      final double allowance = habit.targetValue;
      targetController.text = allowance == allowance.roundToDouble()
          ? allowance.round().toString()
          : allowance.toString();
    }
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

  /// The allowance field's error. Its own rather than [targetError]: the form
  /// that shows the allowance never shows the target, so an error on the one
  /// would be drawn on a box that is not on screen.
  EditHabitFieldError? allowanceError;

  /// The day the person committed, as `daysSince2000`.
  ///
  /// Only an abstinence habit has one, and it is what the recompute range
  /// starts from. It cannot come from the entries: a habit that records
  /// nothing while it is being kept has no oldest entry, and the first row it
  /// ever gets is the first slip — which would make the clean stretch before
  /// it not exist.
  int committedFrom = 0;

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

  /// What computes this habit's days, or null for an ordinary habit.
  ///
  /// In CREATE it is what the type chooser came back with. In EDIT it is read
  /// from the definition row, because the form has no control that could
  /// change it: a habit's kind is settled when it is created and there is no
  /// code, in either direction, that would move it (DEVIATIONS.md, "computed:
  /// вид привычки после создания не меняется").
  ComputedKind? computedKind;

  bool get isAbstinence => computedKind == ComputedKind.abstinence;

  /// Whether the app computes this habit's days, by either route.
  ///
  /// [isSleep] is deliberately still the goal rather than the kind: in CREATE
  /// the goal exists before any definition row does, and a sleep habit whose
  /// definition row went missing must keep showing its own fields.
  bool get isComputed => isSleep || computedKind != null;

  void setSleepGoal(SleepGoal value) {
    sleepGoal = value;
    notifyListeners();
  }

  /// The earliest day a commitment can be made on, as `daysSince2000`.
  ///
  /// Day 1, not day 0. `daysSince2000` expresses the epoch and the days before
  /// it perfectly well, but `computed.commitment#6` reads a stored commitment
  /// day of 0 back as no commitment day at all — zero is what an unfilled
  /// integer looks like, not a decision anybody made, so
  /// [DefinitionRepository.save] throws on one rather than store a value the
  /// next read would drop.
  ///
  /// Named here rather than on the screen because this is where the value is
  /// decided: the picker's `firstDate` reads it, and so does [setCommittedFrom]
  /// — one floor, whichever way the day arrives.
  static const int commitmentFloorDay = 1;

  /// The commitment day, never in the future and never on the epoch.
  ///
  /// The picker's `lastDate` already refuses tomorrow and its `firstDate`
  /// already refuses 2000-01-01; this refuses both again, because the picker is
  /// one of three ways this value can be set and the other two are a restored
  /// backup and a future build. The lower clamp is not tidiness: a day of 0
  /// reaches [DefinitionRepository.save] from inside a command listener, and
  /// the throw leaves a created habit with no row and skips every listener
  /// queued behind it.
  void setCommittedFrom(int day) {
    final int today = getToday().daysSince2000;
    final int notInTheFuture = day > today ? today : day;
    committedFrom = notInTheFuture < commitmentFloorDay
        ? commitmentFloorDay
        : notInTheFuture;
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
    allowanceError = null;

    if (nameController.text.isEmpty) {
      nameError = EditHabitFieldError.blank;
      isValid = false;
    }
    // A computed habit is numerical, but its target is settled by the kind and
    // the field that would carry it is never shown. Validating it would refuse
    // to save a form the person was never given a chance to fill in.
    //
    // The pair, not [isComputed]: this has to name exactly the states
    // `_buildForm` hides the target for, and those two differ on one — a sleep
    // definition row whose goal row is missing, where the form still draws
    // Unit, Target and Target type. Under [isComputed] a person could fill all
    // three in and watch the save ignore them without a word.
    if (isNumerical && !isSleep && !isAbstinence) {
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

    // The allowance is the same control asked a different question. Blank is
    // not an error here — it means no allowance, which is the default — but a
    // word where a number belongs still refuses the save, for the reason
    // `edit-habit.validation#9` gives about the target.
    if (isAbstinence &&
        targetController.text.isNotEmpty &&
        double.tryParse(targetController.text) == null) {
      allowanceError = EditHabitFieldError.notANumber;
      isValid = false;
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
    // Same reason as in validate(): a computed form never shows these, so
    // there is nothing here to parse — and spelled as the same pair the form
    // branches on, so the two cannot drift apart.
    if (habitType == HabitType.numerical && !isSleep && !isAbstinence) {
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

    // An abstinence habit is an at-most numerical habit whose target is the
    // day's allowance. Nothing new is needed for "silence is success": the
    // ported at-most branch starts its score at 1.0 and counts a day with no
    // entry through `max(0, -1)`, which is exactly "innocent until proven
    // otherwise".
    //
    // The row that makes it an abstinence habit is built here, from the same
    // two values, rather than read out of the fields a second time later: the
    // allowance is stored twice on purpose — in `targetValue`, which is what
    // the score judges by, and in the payload, which is what the cell draws a
    // cross from — and one parse is what makes those two the same number by
    // construction instead of by agreement (`computed.allowance#1`). Parsed
    // twice they can differ, and a day the ring calls a lapse with no cross on
    // it is the shape of that bug.
    HabitDefinition? abstinenceRow;
    if (isAbstinence) {
      final double allowance = double.tryParse(targetController.text) ?? 0;
      final String unit = unitController.text.trim();
      habit.targetValue = allowance;
      habit.targetType = NumericalHabitType.atMost;
      habit.unit = unit;
      habit.frequency = Frequency(1, 1);
      // The payload is assembled by the core's own door rather than by
      // literals: the keys are named once, the allowance is a `double`, and an
      // empty unit becomes `count` instead of `''` (`computed.allowance#2`).
      abstinenceRow = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
        payload: abstinencePayload(allowance: allowance, unit: unit),
      );
    }

    // Last, as in Kotlin (`edit-habit.save#7`).
    habit.type = habitType;

    final command = habitId >= 0
        ? EditHabitCommand(scope.habitList, habitId, habit)
        : CreateHabitCommand(scope.modelFactory, scope.habitList, habit);

    // The side rows a computed habit needs are written once the command has
    // actually run, not on the next line. `CommandRunner.run` hands the
    // command to a task runner; the dispatcher a test uses executes it at
    // once, the one a device uses does not. Reading the result immediately
    // worked in every test and silently did nothing on a phone — the habit was
    // created and the row that makes it computed was never stored.
    //
    // The kind picks the writer; the registration is written once. Two
    // `addListener` blocks differing only in their callback are two places to
    // remember when the listener changes, and the third kind would make three.
    final SleepGoal? goal = sleepGoal;
    final HabitDefinition? row = abstinenceRow;
    void Function(AppScope scope, Habit saved)? write;
    if (goal != null) {
      write = (AppScope scope, Habit saved) =>
          _writeSleepGoal(scope, saved, goal);
    } else if (row != null) {
      write = (AppScope scope, Habit saved) =>
          _writeAbstinenceRow(scope, saved, row);
    }
    if (write != null) {
      scope.commandRunner.addListener(_AfterCommand(
        scope: scope,
        command: command,
        habitId: habitId,
        uuid: habit.uuid,
        apply: write,
      ));
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

/// Runs [apply] once the command that creates or edits its habit has finished.
///
/// A listener rather than a line after `run`: the command goes through a task
/// runner, so on a device the habit is not in the list yet when `save`
/// returns. It was written for the sleep goal and is now shared, which is what
/// a second computed kind is for.
class _AfterCommand implements CommandRunnerListener {
  _AfterCommand({
    required this.scope,
    required this.command,
    required this.habitId,
    required this.uuid,
    required this.apply,
  });

  final AppScope scope;
  final Command command;
  final int habitId;

  /// `CreateHabitCommand` keeps the form's habit as a template and builds its
  /// own, so that object never gets an id. The uuid is copied across, and is
  /// what identifies the one that did enter the list.
  final String? uuid;

  final void Function(AppScope scope, Habit saved) apply;

  bool _done = false;

  @override
  void onCommandFinished(Command finished) {
    if (_done || !identical(finished, command)) return;
    _done = true;
    // Removed on a microtask: `notifyListeners` is iterating the very list
    // this would mutate.
    scheduleMicrotask(() => scope.commandRunner.removeListener(this));

    // The command runs on a task runner, so this can arrive after the screen
    // and the scope behind it are gone.
    if (scope.isClosed) return;

    final Habit? saved =
        habitId >= 0 ? scope.habitList.getById(habitId) : _byUuid();
    if (saved?.id == null) return;
    apply(scope, saved!);
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

/// Everything an abstinence habit needs beside its row in `Habits`.
void _writeAbstinenceRow(
  AppScope scope,
  Habit saved,
  HabitDefinition definition,
) {
  scope.definitions.save(saved.id!, definition);
  // The row in the database and the live model are two different things: a
  // recompute reads the field, not the repository (`computed.commitment#7`),
  // and `attachDefinition` is also what turns the halving on
  // (`computed.lapse-score#11`). Without these two lines an abstinence habit
  // created or edited in this session would go on being scored from today,
  // with the ported decay, until the app is restarted.
  attachDefinition(saved, scope.definitions);
  saved.recompute();
  scope.onComputedDataChanged(saved.id!);
}

/// Everything a sleep habit needs beside its row in `Habits`.
void _writeSleepGoal(AppScope scope, Habit saved, SleepGoal goal) {
  scope.sleepRepository.saveGoal(saved.id!, goal);
  // The goal is what sleep needs; the definition is what the app needs to know
  // there is anything to compute at all. Written together because a habit with
  // one and not the other is a habit half of the app can see.
  scope.definitions.save(
    saved.id!,
    const HabitDefinition(kind: ComputedKind.sleep),
  );
  // No `attachDefinition` here, and no `recompute`: a sleep definition carries
  // no commitment day and does not halve on a lapse, so there is nothing on it
  // for a recompute to read, and `recomputeAll` on the next line recomputes
  // anyway. Abstinence needs both and has a test that says so; sleep would
  // have had two lines nothing could prove.
  //
  // Changing a goal changes what every past night was worth. Rescoring only
  // from today would leave the history a mixture of two scales.
  scope.sleepSync.recomputeAll(saved);
  scope.onComputedDataChanged(saved.id!);
  // And a habit that has just become a sleep habit has never been synced:
  // without this it shows nothing until the app is backgrounded once.
  unawaited(scope.syncSleepHabits());
}
