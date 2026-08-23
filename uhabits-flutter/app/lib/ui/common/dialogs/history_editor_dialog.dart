/// Port of
/// uhabits-android/.../activities/common/dialogs/HistoryEditorDialog.kt.
///
/// A bare dialog whose entire content is the calendar heat-map, sized to the
/// full width of the screen and at most 350dp tall
/// (`history-editor.dialog#2`, `#15`). The chart itself is the already-ported
/// core view `HistoryChart`, hosted by [CoreView]; everything this file adds is
/// the shell around it:
///
///  * the habit is resolved from the habit list by id, and a missing one
///    crashes exactly as `getById(...)!!` does (`history-editor.dialog#1`);
///  * the dialog subscribes to the command runner for as long as it is on
///    screen and refreshes the grid on every finished command, which is what
///    makes a day toggled from inside the dialog light up immediately
///    (`history-editor.dialog#5`, `#6`);
///  * it keeps its own static `currentDialog` slot, separate from the app-wide
///    single-dialog mechanism, so it can stay visible *under* the number and
///    check-mark popups (`history-editor.dialog#10`, `#16`);
///  * a tap on a day goes to the same [HistoryCardPresenter] the History card
///    uses (`history-editor.dialog#11`, `#17`);
///  * `setContentView(dataView)` is an `AndroidDataView`, so the calendar is
///    scrollable: a horizontal drag walks it backwards through weeks, which is
///    the only way to reach — and edit — a day that is not on screen
///    (`show-habit.chart-scrolling#1`,
///    `audit3.charts-on-the-habit-detail-screen#1`). The chart object outlives
///    every `refreshData()`, so the scroll position does too.
///
/// The Android lifecycle maps onto the widget lifecycle: `onCreateDialog` is
/// [State.didChangeDependencies] (the first time round), `onResume` is
/// [State.initState], `onPause` and `onDismiss` are [State.dispose].
///
/// `ShowHabitActivity.onResume` re-attaches the date-clicked listener by
/// looking the fragment up by tag (`history-editor.dialog#13`,
/// `show-habit.screen-scaffold#7`); [HistoryEditorDialog.current] is that
/// lookup and [HistoryEditorHandle.setOnDateClickedListener] is the setter it
/// calls.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// uhabits_core exports neither lib/src/ui nor lib/src/commands and
// lib/src/preferences yet.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart'
    show CheckMarkDialogCallback, NumberPickerCallback;
import 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../habits/list/list_header.dart' show IntlLocalDateFormatter;
import '../../theme/app_theme.dart' show coreThemeOf, toFlutterColor;
import '../scrollable_chart.dart';
import 'checkmark_dialog.dart';
import 'number_dialog.dart';

export 'package:uhabits_core/src/ui/views/history_chart.dart'
    show HistoryChart, OnDateClickedListener, Square;

/// Opens the history editor for the habit with the given [habitId].
///
/// `ShowHabitActivity.Screen.showHistoryEditorDialog` builds the fragment with
/// a single Long argument and shows it under the tag "historyEditor"
/// (`history-editor.dialog#14`); the habit id is the argument here too, so the
/// caller hands over an id and not a habit, and the lookup — including its
/// crash on a missing habit — happens inside
/// (`history-editor.dialog#1`).
///
/// [listener] is the card's own [HistoryCardPresenter], so a day edited from
/// inside the dialog goes through exactly the same code path as a day edited on
/// the card (`history-editor.dialog#17`). Left null, the dialog builds an
/// equivalent presenter of its own and shows the popups itself.
Future<void> showHistoryEditorDialog(
  BuildContext context, {
  required int habitId,
  required core.HabitList habitList,
  required CommandRunner commandRunner,
  required Preferences preferences,
  OnDateClickedListener? listener,
}) {
  // `component.habitList.getById(requireArguments().getLong("habit"))!!`.
  final habit = HistoryEditorDialog.habitOf(habitList, habitId);

  // `clearCurrentDialog()`, the first statement of onCreateDialog
  // (`history-editor.dialog#16`).
  HistoryEditorDialog.clearCurrentDialog();

  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    settings: const RouteSettings(name: HistoryEditorDialog.tag),
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    // The window is laid out against the raw screen size, cutouts included.
    useSafeArea: false,
    builder: (context) => HistoryEditorDialog(
      habit: habit,
      habitList: habitList,
      commandRunner: commandRunner,
      preferences: preferences,
      listener: listener,
    ),
  );

  HistoryEditorDialog.currentDialog = route;
  final future = navigator.push(route);
  // `onDismiss` clears the slot, however the dialog was closed
  // (`history-editor.dialog#10`).
  future.whenComplete(() {
    if (identical(HistoryEditorDialog.currentDialog, route)) {
      HistoryEditorDialog.currentDialog = null;
    }
  });
  return future;
}

/// What `supportFragmentManager.findFragmentByTag("historyEditor")` hands back
/// when the editor is still up: the two members `ShowHabitActivity.onResume`
/// uses, plus the chart itself so a caller can see which listener is attached.
abstract interface class HistoryEditorHandle {
  /// `HistoryEditorDialog.setOnDateClickedListener(listener)`: remembers the
  /// listener and pushes it into the live chart.
  void setOnDateClickedListener(OnDateClickedListener listener);

  /// The `chart` field. Null only before `onCreateDialog` has run.
  HistoryChart? get chart;
}

class HistoryEditorDialog extends StatefulWidget {
  const HistoryEditorDialog({
    super.key,
    required this.habit,
    required this.habitList,
    required this.commandRunner,
    required this.preferences,
    this.listener,
  });

  /// The fragment tag `ShowHabitActivity` shows the dialog under, reused here
  /// as the route name (`history-editor.dialog#14`).
  static const String tag = 'historyEditor';

  /// `R.dimen.history_editor_max_height`, 350dp (`history-editor.dialog#2`).
  static const double maxHeight = 350.0;

  /// `padding = 10.0` on the chart (`history-editor.dialog#3`, `#15`).
  static const double chartPadding = 10.0;

  /// The editor's own single-dialog slot.
  ///
  /// Deliberately *not* the app-wide `dismissCurrentDialog` mechanism of
  /// `dialogs.single-current-dialog`: the entry popups route through that one,
  /// and the editor has to survive them (`history-editor.dialog#10`, `#16`).
  static Route<void>? currentDialog;

  /// `supportFragmentManager.findFragmentByTag("historyEditor")`: the live
  /// dialog, or null when none is up (`history-editor.dialog#13`).
  ///
  /// A fragment manager is keyed by tag and holds at most one fragment per
  /// tag; `clearCurrentDialog` guarantees the same here, so a single slot is
  /// the whole lookup.
  static HistoryEditorHandle? current;

  /// `HistoryEditorDialog.clearCurrentDialog()`: dismiss whatever editor is
  /// open and empty the slot.
  static void clearCurrentDialog() {
    final route = currentDialog;
    currentDialog = null;
    if (route == null) return;
    final navigator = route.navigator;
    // `removeRoute` rather than `pop`, because the editor may be sitting under
    // an entry popup, and Kotlin's `dismiss()` does not care what is on top.
    if (navigator != null && route.isActive) navigator.removeRoute(route);
  }

  /// `component.habitList.getById(id)!!` — a missing habit is a crash, not an
  /// empty dialog (`history-editor.dialog#1`).
  static core.Habit habitOf(core.HabitList habitList, int habitId) =>
      habitList.getById(habitId)!;

  /// The chart as `onCreateDialog` builds it: no data at all, and a default
  /// square of OFF until the first refresh fills it in
  /// (`history-editor.dialog#3`).
  static HistoryChart buildChart({
    required core.Habit habit,
    required Preferences preferences,
    required core.Theme theme,
    required core.LocalDateFormatter dateFormatter,
    OnDateClickedListener? listener,
  }) {
    final chart = HistoryChart(
      dateFormatter: dateFormatter,
      firstWeekday: preferences.firstWeekday,
      paletteColor: habit.color,
      series: const <Square>[],
      defaultSquare: Square.off,
      notesIndicators: const <bool>[],
      theme: theme,
      today: core.getToday(),
      padding: chartPadding,
    );
    if (listener != null) chart.onDateClickedListener = listener;
    return chart;
  }

  /// `refreshData()`'s call into the core presenter.
  ///
  /// The theme is hardcoded to `LightTheme()` upstream, in every app theme —
  /// a wart that costs nothing, since only the series, the default square and
  /// the notes indicators are read back out of the state; the chart keeps
  /// rendering with the real theme (`history-editor.dialog#7`).
  static HistoryCardState buildState({
    required core.Habit habit,
    required Preferences preferences,
  }) {
    return HistoryCardPresenter.buildState(
      habit: habit,
      firstWeekday: preferences.firstWeekday,
      theme: core.LightTheme(),
    );
  }

  final core.Habit habit;

  final core.HabitList habitList;

  final CommandRunner commandRunner;

  final Preferences preferences;

  /// The History card's presenter, when the dialog was opened from the card.
  final OnDateClickedListener? listener;

  @override
  State<HistoryEditorDialog> createState() => _HistoryEditorDialogState();
}

class _HistoryEditorDialogState extends State<HistoryEditorDialog>
    implements CommandRunnerListener, HistoryEditorHandle {
  HistoryChart? _chart;

  late OnDateClickedListener _listener;

  @override
  HistoryChart? get chart => _chart;

  /// `fun setOnDateClickedListener(listener) { onDateClickedListener =
  /// listener; chart?.onDateClickedListener = listener }`.
  @override
  void setOnDateClickedListener(OnDateClickedListener listener) {
    _listener = listener;
    _chart?.onDateClickedListener = listener;
  }

  @override
  void initState() {
    super.initState();
    // `setOnDateClickedListener`, or — when the dialog stands on its own — a
    // presenter of its very own class (`history-editor.dialog#17`).
    _listener = widget.listener ??
        HistoryCardPresenter(
          commandRunner: widget.commandRunner,
          habit: widget.habit,
          habitList: widget.habitList,
          preferences: widget.preferences,
          screen: _HistoryEditorScreen(this),
        );
    // The fragment joins the fragment manager under its tag as soon as it is
    // added, which is what makes `findFragmentByTag` find it.
    HistoryEditorDialog.current = this;
    // `onResume`: addListener (`history-editor.dialog#5`).
    widget.commandRunner.addListener(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_chart != null) return;
    // `onCreateDialog`: the theme is applied first, so the chart is built with
    // whichever of light/dark/pure-black is current
    // (`history-editor.dialog#4`).
    _chart = HistoryEditorDialog.buildChart(
      habit: widget.habit,
      preferences: widget.preferences,
      theme: coreThemeOf(context),
      dateFormatter: IntlLocalDateFormatter.of(context),
      listener: _listener,
    );
    // `onResume` refreshes immediately after registering
    // (`history-editor.dialog#5`). No setState: this build is still ahead.
    _refreshData(notify: false);
  }

  @override
  void dispose() {
    // `onPause`: removeListener (`history-editor.dialog#5`).
    widget.commandRunner.removeListener(this);
    // The fragment leaves the manager with the dialog, so the tag lookup goes
    // back to null.
    if (identical(HistoryEditorDialog.current, this)) {
      HistoryEditorDialog.current = null;
    }
    super.dispose();
  }

  /// `onCommandFinished(command)` — every command, of every kind
  /// (`history-editor.dialog#6`).
  @override
  void onCommandFinished(Command command) => _refreshData();

  /// `refreshData()`: rebuild the state, push the three data fields into the
  /// live chart and invalidate.
  void _refreshData({bool notify = true}) {
    final chart = _chart;
    if (chart == null) return;
    final model = HistoryEditorDialog.buildState(
      habit: widget.habit,
      preferences: widget.preferences,
    );
    chart.series = model.series;
    chart.defaultSquare = model.defaultSquare;
    chart.notesIndicators = model.notesIndicators;
    // `dataView.postInvalidate()`.
    if (notify && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart!;
    final screen = MediaQuery.sizeOf(context);
    // `window.setLayout(metrics.widthPixels, min(metrics.heightPixels,
    // R.dimen.history_editor_max_height))` (`history-editor.dialog#2`, `#15`).
    final size = Size(
      screen.width,
      math.min(screen.height, HistoryEditorDialog.maxHeight),
    );

    return Dialog(
      insetPadding: EdgeInsets.zero,
      // A window as wide as the screen has no room for the rounded corners of
      // the default dialog background.
      shape: const RoundedRectangleBorder(),
      backgroundColor: toFlutterColor(chart.theme.cardBackgroundColor),
      child: SizedBox(
        width: size.width,
        height: size.height,
        // `setContentView(dataView)`: the AndroidDataView is the whole
        // content, and the chart is the view it scrolls.
        child: ScrollableChart(
          view: chart,
          maxDataOffset: ScrollableChart.dataViewMaxDataOffset,
        ),
      ),
    );
  }
}

/// The half of `ShowHabitActivity.Screen` a standalone editor has to supply
/// itself: the haptic buzz and the two entry popups
/// (`history-editor.dialog#11`, `#12`).
class _HistoryEditorScreen implements HistoryCardScreen {
  _HistoryEditorScreen(this._state);

  final _HistoryEditorDialogState _state;

  /// `window.decorView.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)`
  /// — the constant Flutter's `lightImpact` maps to on Android
  /// (`history-editor.dialog#12`).
  @override
  void showFeedback() {
    HapticFeedback.lightImpact();
  }

  @override
  Future<void> showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) async {
    if (!_state.mounted) return;
    final context = _state.context;
    final theme = coreThemeOf(context);
    final result = await showNumberDialog(
      context,
      value: value,
      notes: notes,
      color: theme.colorOf(_state.widget.habit.color),
      preferences: _state.widget.preferences,
    );
    if (result == null) {
      callback.onNumberPickerDismissed();
      return;
    }
    callback.onNumberPicked(result.value, result.notes);
  }

  @override
  Future<void> showCheckmarkPopup(
    int selectedValue,
    String notes,
    core.PaletteColor color,
    CheckMarkDialogCallback callback,
  ) async {
    if (!_state.mounted) return;
    final context = _state.context;
    final theme = coreThemeOf(context);
    final result = await showCheckmarkDialog(
      context,
      value: selectedValue,
      notes: notes,
      color: theme.colorOf(color),
      preferences: _state.widget.preferences,
    );
    if (result == null) {
      callback.onNotesDismissed();
      return;
    }
    callback.onNotesSaved(result.value, result.notes);
  }

  /// Only `onClickEditButton` reaches this, and the editor has no edit button:
  /// the dialog it would open is the one already on screen.
  @override
  void showHistoryEditorDialog(OnDateClickedListener listener) {}
}
