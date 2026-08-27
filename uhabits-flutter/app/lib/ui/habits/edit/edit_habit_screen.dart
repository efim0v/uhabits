/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/edit/{EditHabitActivity,HabitTypeDialog}.kt
/// and res/layout/{activity_edit_habit,select_habit_type}.xml.
///
/// `EditHabitActivity` is one class doing three jobs. Two of them live in
/// [EditHabitModel] — the form state and the `validate()`/`save()` pair — and
/// what is left here is the third: the layout of activity_edit_habit.xml, the
/// six pickers hanging off it, and the two `populate*` methods that turn the
/// state back into label text.
///
/// The form is a scrolling column of labelled boxes
/// (`edit-habit.form-layout#1`); each box is a [_FormBox], which reproduces
/// `@style/FormOuterBox` + `@style/FormInnerBox` + `@style/FormLabel` from
/// res/values/styles.xml — a rounded 1dp outline with the label straddling its
/// top edge. Which boxes are on screen is decided once, from the habit type,
/// and never changes (`edit-habit.type-field-visibility#3`).
///
/// Ported with known deviations, all of them noted at the point of use:
///
///  * the radial `TimePickerDialog` is a vendored AOSP widget with no Flutter
///    equivalent, so [showTimePicker] stands in. Its "Clear" button has no
///    counterpart, and `edit-habit.reminder-time#6` is load-bearing (clearing
///    resets the days too), so the clear action becomes a small button on the
///    reminder row instead;
///  * `updateColors()` repaints the toolbar only in light themes
///    (`edit-habit.color-control#4`); the ported [core.Theme] carries no
///    `?attr/colorPrimary`, so — exactly as `ShowHabitScreen` already does —
///    the habit colour is used in both themes;
///  * the name error is drawn in white by wrapping it in HTML
///    (`edit-habit.validation#3`), which is an artifact of the Android error
///    popup; both errors are rendered the same way here.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../sleep/sleep_goal_fields.dart';
import '../../../platform/device_time_format.dart';
import '../../../state/app_scope.dart';
import '../../../state/edit_habit_model.dart';
import '../../common/dialogs/color_picker_dialog.dart';
import '../../common/dialogs/current_dialog.dart';
import '../../common/dialogs/frequency_picker_dialog.dart';
import '../../common/dialogs/weekday_picker_dialog.dart';
import '../../theme/app_theme.dart';
import '../list/list_header.dart' show IntlLocalDateFormatter;

// ---------------------------------------------------------------------------
// The two label formatters, both top-level functions in Kotlin too
// ---------------------------------------------------------------------------

/// Port of the top-level `formatFrequency(freqNum, freqDen, resources)`.
///
/// The seven branches are evaluated in exactly this order, and the order is
/// what makes (1, 30) read "Every month" rather than "1 times per month"
/// (`edit-habit.frequency-display#1`, `#2`).
String formatFrequency(int freqNum, int freqDen, L10n l10n) {
  if (freqNum == 1 && (freqDen == 30 || freqDen == 31)) return l10n.everyMonth;
  if (freqDen == 30 || freqDen == 31) return l10n.xTimesPerMonth(freqNum);
  if (freqNum == 1 && freqDen == 1) return l10n.everyDay;
  if (freqNum == 1 && freqDen == 7) return l10n.everyWeek;
  if (freqNum == 1 && freqDen > 1) return l10n.everyXDays(freqDen);
  if (freqDen == 7) return l10n.xTimesPerWeek(freqNum);
  return l10n.xTimesPerYDays(freqNum, freqDen);
}

/// The numerical habit's frequency label, computed separately from
/// [formatFrequency] and ignoring the numerator for the three known
/// denominators — so a habit stored as 3/7 still reads "Every week"
/// (`edit-habit.frequency-display#4`, `#5`).
String formatNumericalFrequency(int freqNum, int freqDen, L10n l10n) {
  switch (freqDen) {
    case 1:
      return l10n.everyDay;
    case 7:
      return l10n.everyWeek;
    case 30:
      return l10n.everyMonth;
    default:
      return '$freqNum/$freqDen';
  }
}

/// Port of `WeekdayList.toFormattedString(context)` from
/// uhabits-android/.../utils/DateExtensions.kt.
///
/// [shortNames] and [longNames] are the seven weekday names starting at
/// Saturday, which is what makes indexes 0 and 1 the weekend
/// (`edit-habit.reminder-days#4`). The five tests are evaluated in the order
/// of `edit-habit.reminder-days#3`; an empty list formats to the empty string,
/// a state the screen never allows (`#6`).
String formatWeekdayList(
  core.WeekdayList days,
  L10n l10n, {
  required List<String> shortNames,
  required List<String> longNames,
}) {
  final array = days.toArray();
  final selected = <int>[];
  for (var i = 0; i <= 6; i++) {
    if (array[i]) selected.add(i);
  }
  if (selected.length == 1) return longNames[selected.first];
  if (selected.length == 2 && array[0] && array[1]) return l10n.weekends;
  if (selected.length == 5 && !array[0] && !array[1]) return l10n.anyWeekday;
  if (selected.length == 7) return l10n.anyDay;
  return selected.map((i) => shortNames[i]).join(', ');
}

/// `JavaLocalDateFormatter(Locale.getDefault()).longWeekdayNames(SATURDAY)`
/// and its short counterpart, the pair `WeekdayList.toFormattedString(context)`
/// builds.
///
/// The locale is the DEVICE one, not the locale the UI resolved to
/// (`audit10.weekday-name-rows-follow-the-device-locale#1`): upstream builds
/// one `JavaLocalDateFormatter(Locale.getDefault())` for both name sets, and it
/// is the same formatter [WeekdayPickerDialog] uses, so the summary and the
/// picker it opens can never disagree. Reading `Localizations.localeOf` here
/// made them disagree in a single pump on any device whose language the app
/// does not translate.
List<String> _weekdayNamesFromSaturday(
  BuildContext context, {
  required bool long,
}) {
  final formatter = IntlLocalDateFormatter.of(context);
  return <String>[
    for (final day in core.getWeekdaySequence(core.DayOfWeek.saturday))
      long
          ? formatter.longWeekdayNameOf(day)
          : formatter.shortWeekdayNameOf(day),
  ];
}

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

/// The numbers of res/values/styles.xml and res/drawable/bg_input_group.xml
/// (`edit-habit.window-insets-and-chrome#5`, `edit-habit.form-layout#10`).
class EditHabitMetrics {
  EditHabitMetrics._();

  /// `@style/FormOuterBox`: 4dp top, 8dp bottom, 4dp sides.
  static const EdgeInsets outerBoxPadding = EdgeInsets.fromLTRB(4, 4, 4, 8);

  /// The 8dp top padding declared by the `bg_input_group` shape.
  static const EdgeInsets innerBoxPadding = EdgeInsets.only(top: 8);

  static const double innerBoxRadius = 4.0;

  static const double innerBoxStrokeWidth = 1.0;

  /// `@style/FormInput`: 16dp on every side.
  static const EdgeInsets inputPadding = EdgeInsets.all(16);

  /// `@style/FormDropdown`: 16dp except at the bottom, where it is 14dp.
  static const EdgeInsets dropdownPadding = EdgeInsets.fromLTRB(16, 16, 16, 14);

  /// `@dimen/regularTextSize`.
  static const double regularTextSize = 16.0;

  /// `@dimen/smallerTextSize`, the floating label.
  static const double labelTextSize = 12.0;

  /// `@style/FormLabel`: 8dp start margin, 8dp of horizontal padding, and a
  /// -15dp top margin that lifts it over the box's top border.
  static const double labelInset = 8.0;

  static const double labelOffset = -8.0;

  /// The colour box is a fixed 80dp column beside the name.
  static const double colorBoxWidth = 80.0;

  /// The colour button's own margins inside that box.
  static const EdgeInsets colorButtonMargin = EdgeInsets.fromLTRB(16, 8, 16, 8);

  /// `@style/FormDivider`.
  static const double dividerHeight = 1.0;

  /// The form's own padding: 8dp on top, 4dp at the sides.
  static const EdgeInsets formPadding = EdgeInsets.fromLTRB(4, 8, 4, 8);

  /// `android:maxLength="50"` on the name input (`edit-habit.form-layout#2`).
  static const int nameMaxLength = 50;
}

// ---------------------------------------------------------------------------
// The screen
// ---------------------------------------------------------------------------

/// The create/edit habit screen.
///
/// [habitId] null is CREATE and any non-null value is EDIT — the Android
/// activity branches on `intent.hasExtra("habitId")`
/// (`edit-habit.entry-points#1`). [habitType] is only read in CREATE mode; the
/// Kotlin code reads it as `HabitType.fromInt(getIntExtra("habitType",
/// HabitType.YES_NO.value))`, so YES_NO is the default
/// (`edit-habit.entry-points#3`).
class EditHabitScreen extends StatelessWidget {
  const EditHabitScreen({
    super.key,
    this.habitId,
    this.habitType = core.HabitType.yesNo,
    this.computed,
  });

  final int? habitId;

  final core.HabitType habitType;

  /// Start the form as a computed habit of this kind.
  ///
  /// Only ever set for a new habit: an existing one carries its kind in its
  /// definition row, and the form reads it from there.
  final core.ComputedKind? computed;

  static const Key nameFieldKey = Key('editHabit.nameInput');
  static const Key questionFieldKey = Key('editHabit.questionInput');
  static const Key notesFieldKey = Key('editHabit.notesInput');
  static const Key unitFieldKey = Key('editHabit.unitInput');
  static const Key sleepTypeCardKey = Key('habitType.sleepCard');
  static const Key abstinenceTypeCardKey = Key('habitType.abstinenceCard');
  static const Key targetFieldKey = Key('editHabit.targetInput');
  static const Key colorButtonKey = Key('editHabit.colorButton');
  static const Key frequencyBoxKey = Key('editHabit.frequencyOuterBox');
  static const Key frequencyPickerKey = Key('editHabit.booleanFrequencyPicker');
  static const Key unitBoxKey = Key('editHabit.unitOuterBox');
  static const Key targetBoxKey = Key('editHabit.targetOuterBox');
  static const Key numericalFrequencyPickerKey =
      Key('editHabit.numericalFrequencyPicker');
  static const Key targetTypeBoxKey = Key('editHabit.targetTypeOuterBox');
  static const Key targetTypePickerKey = Key('editHabit.targetTypePicker');
  static const Key reminderTimePickerKey = Key('editHabit.reminderTimePicker');
  static const Key reminderDividerKey = Key('editHabit.reminderDivider');
  static const Key reminderDaysPickerKey = Key('editHabit.reminderDatePicker');
  static const Key reminderClearKey = Key('editHabit.reminderClear');
  static const Key saveButtonKey = Key('editHabit.buttonSave');
  static const Key yesNoTypeCardKey = Key('habitType.buttonYesNo');
  static const Key measurableTypeCardKey = Key('habitType.buttonMeasurable');

  /// The fragment tag `EditHabitActivity` shows the radial time picker under,
  /// reused here as the route name the way `HistoryEditorDialog` reuses its own
  /// (`edit-habit.reminder-time#7`).
  static const String timePickerTag = 'timePicker';

  /// What `TimePickerDialog.newInstance(...)` is seeded with: the current
  /// reminder, or 08:00 when there is none (`edit-habit.reminder-time#3`).
  static TimeOfDay initialReminderTime(int hour, int minute) => TimeOfDay(
        hour: hour >= 0 ? hour : 8,
        minute: minute >= 0 ? minute : 0,
      );

  /// The route `IntentFactory.startEditActivity` builds.
  ///
  /// The scope has to be captured by the caller, exactly as in
  /// `ShowHabitScreen.route`: `MaterialApp.home` provides it *below* the
  /// navigator, so a pushed route sits outside it.
  static Route<void> route({
    required AppScope scope,
    int? habitId,
    core.HabitType habitType = core.HabitType.yesNo,
    core.ComputedKind? computed,
  }) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'editHabit'),
      builder: (context) => Provider<AppScope>.value(
        value: scope,
        child: EditHabitScreen(
          habitId: habitId,
          habitType: habitType,
          computed: computed,
        ),
      ),
    );
  }

  /// `IntentFactory.startEditActivity(context, habit)` — EDIT mode.
  ///
  /// Kotlin puts *both* extras on the intent — `habitId` and `habitType`
  /// (`show-habit.edit-action#2`) — even though EDIT mode reads the type back
  /// off the habit it loaded and never looks at the extra. Both are passed
  /// here for the same reason: so the route carries what the intent carried.
  static Future<void> open(BuildContext context, core.Habit habit) {
    return Navigator.of(context).push(
      route(
        scope: context.read<AppScope>(),
        habitId: habit.id,
        habitType: habit.type,
      ),
    );
  }

  /// `IntentFactory.startEditActivity(context, habitType)` — CREATE mode.
  static Future<void> openForType(
    BuildContext context,
    core.HabitType habitType,
  ) {
    return Navigator.of(context).push(
      route(scope: context.read<AppScope>(), habitType: habitType),
    );
  }

  /// `ListHabitsScreen.showSelectHabitTypeDialog()` followed by
  /// `HabitTypeDialog`'s two click listeners: pick a type, then start the
  /// editor with it (`habit-type-dialog.select-type#1`, `#6`). Dismissing the
  /// dialog starts nothing (`#7`).
  static Future<void> selectTypeAndOpen(BuildContext context) async {
    final scope = context.read<AppScope>();
    final navigator = Navigator.of(context);
    final selection = await showDialog<HabitTypeSelection>(
      context: context,
      // The scrim belongs to the dialog's own layout here
      // (`habit-type-dialog.select-type#3`).
      barrierColor: Colors.transparent,
      // `@style/Translucent` is neither floating nor fitting system windows,
      // so the window is the whole screen and the `match_parent` scrim covers
      // the status bar and the navigation bar too
      // (`habit-type-dialog.select-type#2`). Left at its default, `showDialog`
      // would inset the dialog by `MediaQuery.padding` and — with the barrier
      // transparent — leave those bands undimmed
      // (`audit18.the-type-choosers-scrim-must-reach-the-screen-edges#1`).
      useSafeArea: false,
      builder: (context) => const HabitTypeDialog(),
    );
    if (selection == null) return;
    await navigator.push(route(
      scope: scope,
      habitType: selection.type,
      computed: selection.computed,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<EditHabitModel>(
      create: (context) => EditHabitModel(
        scope: context.read<AppScope>(),
        habitId: habitId,
        habitType: habitType,
        computed: computed,
      ),
      child: const _EditHabitView(),
    );
  }
}

class _EditHabitView extends StatefulWidget {
  const _EditHabitView();

  @override
  State<_EditHabitView> createState() => _EditHabitViewState();
}

class _EditHabitViewState extends State<_EditHabitView> {
  /// `fun Dialog.dismissCurrentAndShow()` / the `DialogFragment` overload,
  /// against the process-wide slot of `DialogUtils`
  /// (`platform-glue.transient-ui-helpers#4`).
  ///
  /// Five of the screen's six pickers go through it — colour, boolean
  /// frequency, target type, reminder time and reminder days — and the sixth
  /// deliberately does not; see [_onPickNumericalFrequency].
  Future<T?> _dismissCurrentAndShow<T>(Future<T?> Function() show) =>
      dismissCurrentAndShow<T>(context, show);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final model = context.watch<EditHabitModel>();
    final theme = coreThemeOf(context);
    // `updateColors()` paints the toolbar with the habit colour only outside
    // night mode (edit-habit.color-control#4).
    final toolbarColor =
        toFlutterColor(theme.toolbarColorFor(theme.colorOf(model.color)));


    return Scaffold(
      // `android:background="?attr/contrast0"` on the root and on the
      // ScrollView (`edit-habit.window-insets-and-chrome#4`) — pure white in
      // the light theme, where `appBackgroundColor` is #f4f4f4
      // (`audit22.edit-habit-screen-paints-appbackgroundcolor-where-the-layout-paints-contrast0#1`).
      backgroundColor: toFlutterColor(theme.contrast0),
      appBar: AppBar(
        // `edit-habit.entry-points#2`: the layout's `app:title` is
        // "Create habit"; EDIT mode replaces it with "Edit habit".
        title: Text(model.isEditing ? l10n.editHabit : l10n.createHabit),
        // `updateColors()` (`edit-habit.color-control#3`, `#4`).
        backgroundColor: toolbarColor,
        foregroundColor: Colors.white,
        // `supportActionBar?.elevation = 10.0f`
        // (`edit-habit.window-insets-and-chrome#2`).
        elevation: 10,
        actions: <Widget>[
          Padding(
            // `android:layout_marginEnd="16dp"` — direction-relative, so the
            // gap follows the edge the button sits against
            // (`audit10.the-edit-habit-form-pins-its-floating#1`). The colour
            // button below stays a plain `EdgeInsets`: upstream spells that
            // one marginLeft/marginRight, which is the split
            // `platform-glue.rtl-layout#6` is about.
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: OutlinedButton(
              key: EditHabitScreen.saveButtonKey,
              onPressed: _onSave,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              // `Widget.MaterialComponents.Button.OutlinedButton` renders its
              // label upper-case (`edit-habit.window-insets-and-chrome#1`).
              child: Text(l10n.save.toUpperCase()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EditHabitMetrics.formPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: _buildForm(context, model, theme, l10n),
          ),
        ),
      ),
    );
  }

  /// activity_edit_habit.xml top to bottom, minus whatever the habit type
  /// hides (`edit-habit.form-layout#1`,
  /// `edit-habit.type-field-visibility#1`, `#2`).
  List<Widget> _buildForm(
    BuildContext context,
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    return <Widget>[
      _buildNameAndColorRow(model, theme, l10n),
      _buildQuestionBox(model, theme, l10n),
      if (!model.isNumerical) _buildFrequencyBox(model, theme, l10n),
      // A sleep habit is stored as a numerical one, but its unit, target and
      // target type are settled by the model rather than offered here: what is
      // being measured is a percentage out of a hundred, scored daily, and a
      // person who edited that would be scored against a different question.
      if (model.isSleep)
        SleepGoalFields(
          theme: theme,
          goal: model.sleepGoal!,
          onChanged: model.setSleepGoal,
        )
      else if (model.isNumerical) ...<Widget>[
        _buildUnitBox(model, theme, l10n),
        _buildTargetRow(model, theme, l10n),
        _buildTargetTypeBox(model, theme, l10n),
      ],
      _buildReminderBox(context, model, theme, l10n),
      _buildNotesBox(model, theme, l10n),
    ];
  }

  // -----------------------------------------------------------------------
  // Boxes
  // -----------------------------------------------------------------------

  Widget _buildNameAndColorRow(
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _FormBox(
              label: l10n.name,
              theme: theme,
              child: _FormInput(
                key: EditHabitScreen.nameFieldKey,
                controller: model.nameController,
                theme: theme,
                // `edit-habit.form-layout#3`: the hint is swapped at runtime
                // for numerical habits.
                hintText: model.isNumerical
                    ? l10n.measurableShortExample
                    : l10n.yesOrNoShortExample,
                errorText: _errorTextOf(model.nameError, l10n),
                maxLines: 2,
                maxLength: EditHabitMetrics.nameMaxLength,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),
          SizedBox(
            width: EditHabitMetrics.colorBoxWidth,
            child: _FormBox(
              label: l10n.color,
              theme: theme,
              child: Padding(
                padding: EditHabitMetrics.colorButtonMargin,
                child: SizedBox(
                  height: EditHabitMetrics.regularTextSize * 2,
                  child: Material(
                    key: EditHabitScreen.colorButtonKey,
                    color: toFlutterColor(theme.colorOf(model.color)),
                    child: InkWell(onTap: _onPickColor, child: const SizedBox()),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionBox(
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    return _FormBox(
      label: l10n.question,
      theme: theme,
      child: _FormInput(
        key: EditHabitScreen.questionFieldKey,
        controller: model.questionController,
        theme: theme,
        // A sleep habit is a numerical habit underneath, and the numerical
        // hint asks about miles run. Its own hint, because the placeholder is
        // the only thing on the form that says what the question is for.
        hintText: model.isSleep
            ? l10n.sleepQuestionExample
            : model.isNumerical
                ? l10n.measurableQuestionExample
                : l10n.exampleQuestionBoolean,
        // No maxLines cap and no maxLength (`edit-habit.form-layout#4`).
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  Widget _buildFrequencyBox(
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    return _FormBox(
      key: EditHabitScreen.frequencyBoxKey,
      label: l10n.frequency,
      theme: theme,
      child: _FormDropdown(
        key: EditHabitScreen.frequencyPickerKey,
        theme: theme,
        // `populateFrequency()` (`edit-habit.frequency-display#3`).
        text: formatFrequency(model.freqNum, model.freqDen, l10n),
        onTap: _onPickFrequency,
      ),
    );
  }

  Widget _buildUnitBox(EditHabitModel model, core.Theme theme, L10n l10n) {
    return _FormBox(
      key: EditHabitScreen.unitBoxKey,
      label: l10n.unit,
      theme: theme,
      child: _FormInput(
        key: EditHabitScreen.unitFieldKey,
        controller: model.unitController,
        theme: theme,
        hintText: l10n.measurableUnitsExample,
        maxLines: 1,
        // unitInput is the one input of the form that declares no
        // `android:inputType`, so it has no capitalization mode: the hinted
        // example types back as "miles", lower case, and that is the string
        // the Target card and the list subtitle render next to the number
        // (`audit4.the-unit-field-auto-capitalizes-which#1`).
        textCapitalization: TextCapitalization.none,
      ),
    );
  }

  Widget _buildTargetRow(EditHabitModel model, core.Theme theme, L10n l10n) {
    return IntrinsicHeight(
      key: EditHabitScreen.targetBoxKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _FormBox(
              label: l10n.target,
              theme: theme,
              child: _FormInput(
                key: EditHabitScreen.targetFieldKey,
                controller: model.targetController,
                theme: theme,
                hintText: l10n.exampleTarget,
                errorText: _errorTextOf(model.targetError, l10n),
                maxLines: 1,
                // `android:inputType="numberDecimal"`
                // (`edit-habit.form-layout#8`).
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ),
          Expanded(
            child: _FormBox(
              label: l10n.frequency,
              theme: theme,
              child: _FormDropdown(
                key: EditHabitScreen.numericalFrequencyPickerKey,
                theme: theme,
                text: formatNumericalFrequency(
                  model.freqNum,
                  model.freqDen,
                  l10n,
                ),
                onTap: _onPickNumericalFrequency,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTypeBox(
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    return _FormBox(
      key: EditHabitScreen.targetTypeBoxKey,
      label: l10n.targetType,
      theme: theme,
      child: _FormDropdown(
        key: EditHabitScreen.targetTypePickerKey,
        theme: theme,
        // `populateTargetType()`: AT_MOST is the only named branch and
        // AT_LEAST is the `else` (`edit-habit.target-type-picker#4`).
        text: model.targetType == core.NumericalHabitType.atMost
            ? l10n.targetTypeAtMost
            : l10n.targetTypeAtLeast,
        onTap: _onPickTargetType,
      ),
    );
  }

  Widget _buildReminderBox(
    BuildContext context,
    EditHabitModel model,
    core.Theme theme,
    L10n l10n,
  ) {
    // `populateReminder()` (`edit-habit.reminder-time#1`, `#2`).
    return _FormBox(
      label: l10n.reminder,
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _FormDropdown(
            key: EditHabitScreen.reminderTimePickerKey,
            theme: theme,
            text: model.hasReminder
                ? _formatTime(context, model.reminderHour, model.reminderMin)
                : l10n.reminderOff,
            onTap: _onPickReminderTime,
            // The radial picker's "Clear" button, which `showTimePicker` has
            // no room for (`edit-habit.reminder-time#6`).
            trailing: model.hasReminder
                ? IconButton(
                    key: EditHabitScreen.reminderClearKey,
                    tooltip: l10n.clearLabel,
                    icon: const Icon(Icons.close),
                    color: toFlutterColor(theme.mediumContrastTextColor),
                    onPressed: model.clearReminder,
                  )
                : null,
          ),
          if (model.hasReminder)
            _FormDivider(key: EditHabitScreen.reminderDividerKey, theme: theme),
          if (model.hasReminder)
            _FormDropdown(
              key: EditHabitScreen.reminderDaysPickerKey,
              theme: theme,
              text: formatWeekdayList(
                model.reminderDays,
                l10n,
                shortNames: _weekdayNamesFromSaturday(context, long: false),
                longNames: _weekdayNamesFromSaturday(context, long: true),
              ),
              onTap: _onPickReminderDays,
            ),
        ],
      ),
    );
  }

  Widget _buildNotesBox(EditHabitModel model, core.Theme theme, L10n l10n) {
    return _FormBox(
      label: l10n.notes,
      theme: theme,
      child: _FormInput(
        key: EditHabitScreen.notesFieldKey,
        controller: model.notesController,
        theme: theme,
        hintText: l10n.exampleNotes,
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  /// Both validation failures use the one string the Android app has
  /// (`edit-habit.validation#2`, `#4`). `notANumber` is the port's own state
  /// (`edit-habit.validation#9`) and has no string of its own, so it borrows
  /// the same one.
  String? _errorTextOf(EditHabitFieldError? error, L10n l10n) {
    switch (error) {
      case null:
        return null;
      case EditHabitFieldError.blank:
      case EditHabitFieldError.notANumber:
        return l10n.validationCannotBeBlank;
    }
  }

  /// `formatTime(context, hours, minutes)`: the user's 12/24h system
  /// preference picks the skeleton and the DEVICE locale supplies the pattern
  /// (`edit-habit.reminder-time#8`).
  ///
  /// `DateExtensions.formatTime` has exactly two callers — this row and
  /// `SubtitleCardView` — and both go through
  /// `DateFormat.getTimeFormat(context)`, whose locale is the configuration
  /// locale, region and all, never the locale the app's strings resolved to
  /// (`audit22.edit-habit-reminder-time-follows-the-app-locale#1`,
  /// `audit15.subtitle-card-reminder-time-ignores-the-device-locale#1`). That
  /// is the same seam the reminder-days row below already reads, so the two
  /// rows of one box can never disagree.
  ///
  /// Known divergence: [showTimePicker]'s own header still renders through
  /// `MaterialLocalizations`, because the vendored AOSP radial dialog has no
  /// Flutter equivalent to point at the device locale (see the library
  /// comment).
  String _formatTime(BuildContext context, int hour, int minute) {
    // `(hours * 60 + minutes) * 60 * 1000L`, rendered in UTC so no zone can
    // shift it; `populateReminder` only reaches here with a valid 0..23 hour.
    return formatDeviceTime(context, minuteOfDay: hour * 60 + minute);
  }

  // -----------------------------------------------------------------------
  // Pickers
  // -----------------------------------------------------------------------

  /// `colorPickerDialogFactory.create(color, theme)`
  /// (`edit-habit.color-control#1`, `#2`).
  Future<void> _onPickColor() async {
    final model = context.read<EditHabitModel>();
    // `picker.dismissCurrentAndShow(supportFragmentManager, "colorPicker")`.
    final picked = await _dismissCurrentAndShow<core.PaletteColor>(
      () => showColorPickerDialog(context, selected: model.color),
    );
    if (picked == null) return;
    model.setColor(picked);
  }

  /// `FrequencyPickerDialog(freqNum, freqDen)`.
  Future<void> _onPickFrequency() async {
    final model = context.read<EditHabitModel>();
    // `picker.dismissCurrentAndShow(supportFragmentManager,
    // "frequencyPicker")`.
    final picked = await _dismissCurrentAndShow<core.Frequency>(
      () => showFrequencyPickerDialog(
        context,
        frequency: core.Frequency(model.freqNum, model.freqDen),
      ),
    );
    if (picked == null) return;
    model.setFrequency(picked.numerator, picked.denominator);
  }

  /// The three-item `AlertDialog` the numerical frequency control opens
  /// (`edit-habit.numerical-frequency-picker#1`, `#2`).
  ///
  /// Deliberately *not* routed through [_dismissCurrentAndShow]: this is the
  /// one picker on the screen whose last statement is a bare `builder.show()`
  /// rather than `dialog.dismissCurrentAndShow()`, so it neither closes the
  /// tracked dialog nor becomes the tracked one
  /// (`edit-habit.numerical-frequency-picker#5`). Whether that is an oversight
  /// upstream or not, it is reproduced rather than tidied.
  Future<void> _onPickNumericalFrequency() async {
    final l10n = L10n.of(context);
    final model = context.read<EditHabitModel>();
    final picked = await _showListDialog<int>(
      context,
      // "Every day", "Every week", "Every month", in this order.
      options: <String, int>{
        l10n.everyDay: 1,
        l10n.everyWeek: 7,
        l10n.everyMonth: 30,
      },
    );
    if (picked == null) return;
    model.setFrequencyDenominator(picked);
  }

  /// The two-item `AlertDialog` behind the Target Type control
  /// (`edit-habit.target-type-picker#1`, `#2`).
  Future<void> _onPickTargetType() async {
    final l10n = L10n.of(context);
    final model = context.read<EditHabitModel>();
    // `val dialog = builder.create(); dialog.dismissCurrentAndShow()` — the
    // only one of the two list dialogs that goes through the slot
    // (`edit-habit.target-type-picker#6`).
    final picked = await _dismissCurrentAndShow<core.NumericalHabitType>(
      () => _showListDialog<core.NumericalHabitType>(
        context,
        options: <String, core.NumericalHabitType>{
          l10n.targetTypeAtLeast: core.NumericalHabitType.atLeast,
          l10n.targetTypeAtMost: core.NumericalHabitType.atMost,
        },
      ),
    );
    if (picked == null) return;
    model.setTargetType(picked);
  }

  /// `TimePickerDialog.newInstance(...)` seeded with 08:00 when no reminder is
  /// set yet (`edit-habit.reminder-time#3`), shown under the fragment tag
  /// "timePicker" (`edit-habit.reminder-time#7`) and tinted with `androidColor`
  /// — the habit colour resolved against the current theme, which is what
  /// `newInstance` is handed as the accent (`edit-habit.color-control#5`).
  Future<void> _onPickReminderTime() async {
    final model = context.read<EditHabitModel>();
    final theme = coreThemeOf(context);
    final accent = toFlutterColor(theme.colorOf(model.color));
    // `dialog.dismissCurrentAndShow(supportFragmentManager, "timePicker")`.
    final picked = await _dismissCurrentAndShow<TimeOfDay>(
      () => showTimePicker(
        context: context,
        initialTime: EditHabitScreen.initialReminderTime(
          model.reminderHour,
          model.reminderMin,
        ),
        routeSettings: const RouteSettings(
          name: EditHabitScreen.timePickerTag,
        ),
        builder: (context, child) {
          final base = Theme.of(context);
          return Theme(
            data: base.copyWith(
              colorScheme: base.colorScheme.copyWith(primary: accent),
            ),
            child: child!,
          );
        },
      ),
    );
    if (picked == null) return;
    model.setReminderTime(picked.hour, picked.minute);
  }

  /// `WeekdayPickerDialog` pre-checked with the current days
  /// (`edit-habit.reminder-days#1`).
  Future<void> _onPickReminderDays() async {
    final model = context.read<EditHabitModel>();
    // `dialog.dismissCurrentAndShow(supportFragmentManager, "dayPicker")`.
    final picked = await _dismissCurrentAndShow<core.WeekdayList>(
      () => showWeekdayPickerDialog(context, selected: model.reminderDays),
    );
    if (picked == null) return;
    model.setReminderDays(picked);
  }

  /// `if (validate()) save()`, then `finish()`
  /// (`edit-habit.save#11`, `#13`).
  void _onSave() {
    final model = context.read<EditHabitModel>();
    if (!model.save()) return;
    Navigator.of(context).pop();
  }
}

/// The `ArrayAdapter` + `AlertDialog.Builder.setAdapter` pair the two dropdown
/// lists are built from: a bare list of labels, no title and no buttons, that
/// dismisses itself on a tap (`edit-habit.numerical-frequency-picker#1`,
/// `edit-habit.target-type-picker#1`, `#3`). Tapping outside returns nothing
/// (`edit-habit.numerical-frequency-picker#6`).
Future<T?> _showListDialog<T>(
  BuildContext context, {
  required Map<String, T> options,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      children: <Widget>[
        for (final option in options.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(option.value),
            child: Text(option.key),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Form primitives — @style/Form*
// ---------------------------------------------------------------------------

/// `@style/FormOuterBox` wrapping `@style/FormInnerBox`, with a
/// `@style/FormLabel` floating over the top border
/// (`edit-habit.window-insets-and-chrome#5`).
class _FormBox extends StatelessWidget {
  const _FormBox({
    super.key,
    required this.label,
    required this.theme,
    required this.child,
  });

  final String label;
  final core.Theme theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // `?attr/contrast0` is the background of the screen, of the box and of the
    // label — the label punches a hole in the border by painting over it.
    final background = toFlutterColor(theme.contrast0);
    return Padding(
      padding: EditHabitMetrics.outerBoxPadding,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: <Widget>[
          Container(
            padding: EditHabitMetrics.innerBoxPadding,
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                // `?attr/contrast20`, which the ported theme spells
                // lowContrastTextColor — the same #e0e0e0 / #424242 pair.
                color: toFlutterColor(theme.lowContrastTextColor),
                width: EditHabitMetrics.innerBoxStrokeWidth,
              ),
              borderRadius:
                  BorderRadius.circular(EditHabitMetrics.innerBoxRadius),
            ),
            child: child,
          ),
          // `@style/FormLabel` sets no layout_gravity, so the caption takes
          // `@style/FormInnerBox`'s default LinearLayout gravity — START —
          // and `android:layout_marginStart="8dp"` insets it from whichever
          // border that resolves to. Under RTL that is the right one
          // (`audit10.the-edit-habit-form-pins-its-floating#1`).
          PositionedDirectional(
            start: EditHabitMetrics.labelInset,
            top: EditHabitMetrics.labelOffset,
            child: Container(
              color: background,
              padding: const EdgeInsets.symmetric(
                horizontal: EditHabitMetrics.labelInset,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: EditHabitMetrics.labelTextSize,
                  color: toFlutterColor(theme.mediumContrastTextColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `@style/FormInput`: a borderless `EditText` with 16dp of padding.
class _FormInput extends StatelessWidget {
  const _FormInput({
    super.key,
    required this.controller,
    required this.theme,
    required this.hintText,
    this.errorText,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final core.Theme theme;
  final String hintText;
  final String? errorText;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  /// The `textCapSentences` half of `android:inputType`.
  ///
  /// Three of the form's inputs declare
  /// `android:inputType="textCapSentences|textMultiLine"` — nameInput,
  /// questionInput and notesInput — which is why this defaults to
  /// [TextCapitalization.sentences]. unitInput declares no `android:inputType`
  /// at all and is therefore a plain text field with no capitalization mode
  /// (`audit4.the-unit-field-auto-capitalizes-which#1`).
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      // `android:inputType="textCapSentences|..."`, where the layout declares
      // one.
      textCapitalization: textCapitalization,
      inputFormatters: maxLength == null
          ? null
          : <TextInputFormatter>[
              LengthLimitingTextInputFormatter(maxLength),
            ],
      style: TextStyle(
        fontSize: EditHabitMetrics.regularTextSize,
        color: toFlutterColor(theme.highContrastTextColor),
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EditHabitMetrics.inputPadding,
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: EditHabitMetrics.regularTextSize,
          color: toFlutterColor(theme.mediumContrastTextColor),
        ),
        errorText: errorText,
        // Android's EditText shows no character counter.
        counterText: '',
      ),
    );
  }
}

/// `@style/FormDropdown`: a `TextView` with a drop-down arrow, not a spinner
/// (`edit-habit.form-layout#11`).
class _FormDropdown extends StatelessWidget {
  const _FormDropdown({
    super.key,
    required this.theme,
    required this.text,
    required this.onTap,
    this.trailing,
  });

  final core.Theme theme;
  final String text;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EditHabitMetrics.dropdownPadding,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: EditHabitMetrics.regularTextSize,
                  color: toFlutterColor(theme.highContrastTextColor),
                ),
              ),
            ),
            ?trailing,
            Icon(
              Icons.arrow_drop_down,
              color: toFlutterColor(theme.mediumContrastTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// `@style/FormDivider`: 1dp of `?attr/contrast20`.
class _FormDivider extends StatelessWidget {
  const _FormDivider({super.key, required this.theme});

  final core.Theme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: EditHabitMetrics.dividerHeight,
      color: toFlutterColor(theme.lowContrastTextColor),
    );
  }
}

// ---------------------------------------------------------------------------
// HabitTypeDialog
// ---------------------------------------------------------------------------

/// What the type chooser came back with.
///
/// A pair rather than a bare [core.HabitType] because a computed habit is
/// stored as a numerical one: the type alone cannot tell three kinds apart.
class HabitTypeSelection {
  const HabitTypeSelection(this.type, {this.computed});

  final core.HabitType type;
  final core.ComputedKind? computed;

  @override
  bool operator ==(Object other) =>
      other is HabitTypeSelection &&
      other.type == type &&
      other.computed == computed;

  @override
  int get hashCode => Object.hash(type, computed);
}

/// Port of `HabitTypeDialog` and res/layout/select_habit_type.xml.
///
/// A full-screen, vertically centred column of two cards over a #a0000000
/// scrim (`habit-type-dialog.select-type#2`, `#3`, `#4`). The layout's third
/// "Subjective" card is commented out upstream and is not ported (`#5`).
/// Completes with the chosen [core.HabitType], or null when the scrim is
/// tapped (`#7`).
class HabitTypeDialog extends StatelessWidget {
  const HabitTypeDialog({super.key});

  /// `@color/translucent_black`, the scrim behind the cards.
  static const Color scrimColor = Color(0xA0000000);

  /// Card titles are 20sp bold with an 8dp bottom margin, bodies use the small
  /// text size with a 1.25 line-spacing multiplier, and each card has 6dp of
  /// elevation (`habit-type-dialog.select-type#8`).
  static const double titleTextSize = 20.0;

  static const double bodyTextSize = 14.0;

  static const double bodyLineHeight = 1.25;

  static const double cardElevation = 6.0;

  /// `@style/SelectHabitTypeButton`'s `android:background` is
  /// `@drawable/round_ripple`: a `<ripple android:color="?colorAccent">`
  /// wrapping a rectangle with `<solid android:color="?cardBgColor"/>`, a
  /// `<stroke android:width="2dp" android:color="?android:textColor"/>` and
  /// `<corners android:radius="5dp"/>`
  /// (`audit15.habit-type-cards-lose-their-2dp-outline#1`).
  ///
  /// The two colours are the themed *attributes*, not the Themes.kt tokens
  /// nearest to them — the same distinction `audit8.entry-popups-paint-
  /// themselves-cardbgcolor-over#1` draws for the entry popups. `?cardBgColor`
  /// is #FAFAFA / #303030 / #000000 and `?android:textColor` is
  /// #424242 / #F5F5F5 / #EEEEEE, which the core theme carries as `cardBgColor`
  /// and `contrast100`.
  static const BorderRadius cardBorderRadius =
      BorderRadius.all(Radius.circular(5));

  static const double cardStrokeWidth = 2.0;

  /// Android's `RippleDrawable` paints the steady press state with its own
  /// colour at the platform's `colorControlHighlight` alpha; Flutter's default
  /// `ThemeData.highlightColor` is black at the same 12%. Only the hue moves.
  static const double cardRippleHighlightOpacity = 0.12;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: scrimColor,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _HabitTypeCard(
                  key: EditHabitScreen.yesNoTypeCardKey,
                  title: l10n.yesOrNo,
                  body: l10n.yesOrNoExample,
                  onTap: () => Navigator.of(context)
                      .pop(const HabitTypeSelection(core.HabitType.yesNo)),
                ),
                const SizedBox(height: 16),
                _HabitTypeCard(
                  key: EditHabitScreen.measurableTypeCardKey,
                  title: l10n.measurable,
                  body: l10n.measurableExample,
                  onTap: () => Navigator.of(context)
                      .pop(const HabitTypeSelection(core.HabitType.numerical)),
                ),
                const SizedBox(height: 16),
                // The port's own third card, and a deliberate departure from
                // `habit-type-dialog.select-type#4`, which says exactly two.
                // A sleep goal is something the original cannot express, and
                // every other surface that could offer it is specified just as
                // precisely; the divergence is recorded in DEVIATIONS.md
                // rather than hidden somewhere less visible.
                _HabitTypeCard(
                  key: EditHabitScreen.sleepTypeCardKey,
                  title: l10n.sleepHabitType,
                  body: l10n.sleepHabitTypeExample,
                  onTap: () => Navigator.of(context).pop(
                      const HabitTypeSelection(core.HabitType.numerical,
                          computed: core.ComputedKind.sleep)),
                ),
                const SizedBox(height: 16),
                // The port's fourth card. `habit-type-dialog.select-type#4`
                // says exactly two, and the port has departed from it once
                // already, for sleep; this does not depart from it a second
                // time, it makes the first departure a shape: one card per
                // computed kind, all of them after the two the original has.
                // DEVIATIONS.md carries the entry, widened from "the third
                // card" to this.
                _HabitTypeCard(
                  key: EditHabitScreen.abstinenceTypeCardKey,
                  title: l10n.abstinenceHabitType,
                  body: l10n.abstinenceHabitTypeExample,
                  onTap: () => Navigator.of(context).pop(
                      const HabitTypeSelection(core.HabitType.numerical,
                          computed: core.ComputedKind.abstinence)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitTypeCard extends StatelessWidget {
  const _HabitTypeCard({
    super.key,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = coreThemeOf(context);
    // `<ripple android:color="?colorAccent">`, and `colorAccent` is
    // `?aboutScreenColor` in both AppBaseTheme and AppBaseThemeDark.
    final accent = toFlutterColor(theme.aboutScreenColor);
    return Material(
      elevation: HabitTypeDialog.cardElevation,
      color: toFlutterColor(theme.cardBgColor),
      shape: RoundedRectangleBorder(
        borderRadius: HabitTypeDialog.cardBorderRadius,
        side: BorderSide(
          color: toFlutterColor(theme.contrast100),
          width: HabitTypeDialog.cardStrokeWidth,
        ),
      ),
      child: InkWell(
        borderRadius: HabitTypeDialog.cardBorderRadius,
        splashColor: accent,
        highlightColor: accent.withValues(
          alpha: HabitTypeDialog.cardRippleHighlightOpacity,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: HabitTypeDialog.titleTextSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  fontSize: HabitTypeDialog.bodyTextSize,
                  height: HabitTypeDialog.bodyLineHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
