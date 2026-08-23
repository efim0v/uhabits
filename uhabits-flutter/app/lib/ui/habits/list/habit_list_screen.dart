/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/{ListHabitsActivity,ListHabitsRootView,ListHabitsScreen}.kt
///
/// The three Kotlin classes collapse into one widget plus one [HabitListModel]:
///
///  * `ListHabitsActivity` is the lifecycle — `onResume` attaches the adapter
///    and refreshes it, `onPause` detaches and cancels. That is
///    [HabitListModel.attach] / [HabitListModel.detach], driven here by the
///    provider that owns the model.
///  * `ListHabitsRootView` is the layout: a toolbar, the date strip, the card
///    list, and the empty view stacked on top of the list. Its
///    `getCheckmarkCount()` is [_checkmarkCount], and its `updateEmptyView()`
///    is the branch in [_HabitListView._buildList].
///  * `ListHabitsScreen` is `ListHabitsBehavior.Screen`: the dialogs and
///    navigation the presenter asks for. Those need a `BuildContext`, so they
///    are installed on the model as handlers while this widget is mounted.
///
/// The Android toolbar carries the create-habit action; this screen also has a
/// floating action button for it.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../../../state/habit_list_model.dart';
import 'habit_card.dart';
import 'list_header.dart';

/// The main screen. Owns the [HabitListModel] for as long as it is mounted.
class HabitListScreen extends StatelessWidget {
  const HabitListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HabitListModel>(
      create: (context) => HabitListModel(context.read<AppScope>())..attach(),
      child: const _HabitListView(),
    );
  }
}

class _HabitListView extends StatefulWidget {
  const _HabitListView();

  @override
  State<_HabitListView> createState() => _HabitListViewState();
}

class _HabitListViewState extends State<_HabitListView> {
  /// `HabitCardListView.dataOffset`, fed by the header's scroll controller —
  /// `ListHabitsRootView.setupControllers`.
  int _dataOffset = 0;

  late final HabitListModel _model;

  @override
  void initState() {
    super.initState();
    _model = context.read<HabitListModel>();
    // ListHabitsScreen implements ListHabitsBehavior.Screen; here the model
    // holds the presenter and re-emits its callbacks to whoever is mounted.
    _model
      ..onShowNumberPopup = _showNumberPopup
      ..onShowCheckmarkPopup = _showCheckmarkPopup;
  }

  @override
  void dispose() {
    _model
      ..onShowNumberPopup = null
      ..onShowCheckmarkPopup = null;
    super.dispose();
  }

  /// Port of `ListHabitsRootView.getCheckmarkCount()`. The label column takes a
  /// third of the width but never less than `R.dimen.habitNameWidth`; whatever
  /// is left is divided into 48dp buttons and clamped to 0..60.
  static int _checkmarkCount(double width) {
    const double nameWidth = 160.0;
    const double buttonWidth = 48.0;
    final labelWidth = math.max(width / 3.0, nameWidth);
    final buttonCount = ((width - labelWidth) / buttonWidth).truncate();
    return math.min(
      ListHeader.maxCheckmarkCount,
      math.max(0, buttonCount),
    );
  }

  core.Theme _coreThemeOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? core.DarkTheme()
          : core.LightTheme();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final model = context.watch<HabitListModel>();
    final theme = _coreThemeOf(context);
    // `rootView.setupToolbar(..., color = PaletteColor(17))`: the list screen
    // is the one toolbar that is not tinted by a habit's colour.
    final toolbarColor = _toFlutterColor(theme.colorOf(const core.PaletteColor(17)));

    return Scaffold(
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      appBar: AppBar(
        title: Text(l10n.mainActivityTitle),
        backgroundColor: toolbarColor,
        foregroundColor: Colors.white,
        // `toolbar.elevation = dp(2f)`
        elevation: 2,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createHabit(model),
        tooltip: l10n.addHabit,
        backgroundColor: toolbarColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final buttonCount = _checkmarkCount(constraints.maxWidth);
          final maxDataOffset =
              math.max(ListHeader.maxCheckmarkCount - buttonCount, 0);
          final dataOffset = _dataOffset.clamp(0, maxDataOffset);
          // `onSizeChanged` pushes the column count into the header and the
          // list; notifying from inside build is not allowed, so it lands
          // after the frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) model.buttonCount = buttonCount;
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListHeader(
                buttonCount: buttonCount,
                dataOffset: dataOffset,
                isCheckmarkSequenceReversed:
                    model.scope.preferences.isCheckmarkSequenceReversed,
                onDataOffsetChanged: (value) =>
                    setState(() => _dataOffset = value),
                theme: theme,
              ),
              Expanded(
                child: _buildList(
                  context,
                  model: model,
                  theme: theme,
                  buttonCount: buttonCount,
                  dataOffset: dataOffset,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// `ListHabitsRootView.updateEmptyView()`.
  Widget _buildList(
    BuildContext context, {
    required HabitListModel model,
    required core.Theme theme,
    required int buttonCount,
    required int dataOffset,
  }) {
    final l10n = L10n.of(context);
    if (model.showEmptyState) {
      return _EmptyListView(
        icon: core.FontAwesome.starHalfO,
        text: l10n.noHabitsFound,
        theme: theme,
      );
    }
    if (model.showDoneState) {
      return _EmptyListView(
        icon: core.FontAwesome.umbrellaBeach,
        text: l10n.noHabitsLeftToDo,
        theme: theme,
      );
    }
    return ListView.builder(
      // The Android list has no top padding; the bottom one keeps the last
      // card clear of the floating action button.
      padding: const EdgeInsets.only(top: 0, bottom: 88),
      itemCount: model.itemCount,
      itemBuilder: (context, index) => _buildCard(
        model: model,
        theme: theme,
        index: index,
        buttonCount: buttonCount,
        dataOffset: dataOffset,
      ),
    );
  }

  Widget _buildCard({
    required HabitListModel model,
    required core.Theme theme,
    required int index,
    required int buttonCount,
    required int dataOffset,
  }) {
    final data = model.cardAt(index);
    // `onBindViewHolder` returns early while no view is attached.
    if (data == null) return const SizedBox.shrink();
    final habit = data.habit;
    return HabitCard(
      key: ValueKey<int>(habit.id ?? index),
      habit: habit,
      score: data.score,
      values: data.checkmarks,
      notes: data.notes,
      theme: theme,
      preferences: model.scope.preferences,
      buttonCount: buttonCount,
      dataOffset: dataOffset,
      isSelected: data.selected,
      onToggle: (date, value, notes) => model.onToggle(habit, date, value, notes),
      onEdit: (date) => model.onEdit(habit, date),
      // HabitCardListController.onItemClick / onItemLongClick: a tap selects
      // while a selection is active, and opens the habit otherwise.
      onTap: () {
        if (model.isSelectionEmpty) {
          model.onClickHabit(habit);
        } else {
          model.toggleSelection(index);
        }
      },
      onLongPress: () => model.toggleSelection(index),
    );
  }

  // -----------------------------------------------------------------------
  // Dialogs
  // -----------------------------------------------------------------------

  Future<void> _createHabit(HabitListModel model) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateHabitDialog(),
    );
    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    model.createHabit(model.buildHabitTemplate(name: trimmed));
  }

  /// Stands in for `NumberDialog` until the dialogs slice lands.
  Future<void> _showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) async {
    final picked = await showDialog<double>(
      context: context,
      builder: (context) => _NumberPickerDialog(initialValue: value),
    );
    if (picked == null) {
      callback.onNumberPickerDismissed();
      return;
    }
    callback.onNumberPicked(picked, notes);
  }

  /// Stands in for `CheckmarkDialog` until the dialogs slice lands.
  Future<void> _showCheckmarkPopup(
    int selectedValue,
    String notes,
    core.PaletteColor color,
    CheckMarkDialogCallback callback,
  ) async {
    final theme = _coreThemeOf(context);
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => _CheckmarkDialog(
        selectedValue: selectedValue,
        color: _toFlutterColor(theme.colorOf(color)),
        isSkipEnabled: _model.scope.preferences.isSkipEnabled,
        areQuestionMarksEnabled:
            _model.scope.preferences.areQuestionMarksEnabled,
      ),
    );
    if (picked == null) {
      callback.onNotesDismissed();
      return;
    }
    callback.onNotesSaved(picked, notes);
  }
}

/// Port of
/// uhabits-android/.../habits/list/views/EmptyListView.kt (goldens:
/// androidTest/assets/views/habits/list/EmptyListView/{empty,done}.png): a
/// FontAwesome glyph at 40sp over a label, both centred and both drawn in
/// `?attr/contrast60`, which is [core.Theme.mediumContrastTextColor].
class _EmptyListView extends StatelessWidget {
  const _EmptyListView({
    required this.icon,
    required this.text,
    required this.theme,
  });

  final String icon;
  final String text;
  final core.Theme theme;

  @override
  Widget build(BuildContext context) {
    final color = _toFlutterColor(theme.mediumContrastTextColor);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            icon,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 40,
              fontFamily: core.FontAssets.fontAwesomeFamily,
            ),
          ),
          // `setPadding(0, dp(20f), 0, 0)`
          const SizedBox(height: 20),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

/// The create-habit prompt behind the floating action button.
///
/// Android routes `actionCreateHabit` to a habit-type chooser and then to
/// `EditHabitActivity`; neither is ported yet, so this asks for the one field
/// `CreateHabitCommand` cannot default — the name.
class _CreateHabitDialog extends StatefulWidget {
  const _CreateHabitDialog();

  @override
  State<_CreateHabitDialog> createState() => _CreateHabitDialogState();
}

class _CreateHabitDialogState extends State<_CreateHabitDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.createHabit),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.name),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

class _CheckmarkDialog extends StatelessWidget {
  const _CheckmarkDialog({
    required this.selectedValue,
    required this.color,
    required this.isSkipEnabled,
    required this.areQuestionMarksEnabled,
  });

  final int selectedValue;
  final Color color;
  final bool isSkipEnabled;
  final bool areQuestionMarksEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final options = <int, String>{
      core.Entry.yesManual: l10n.yes,
      core.Entry.no: l10n.no,
      if (isSkipEnabled) core.Entry.skip: l10n.skipDay,
      // No ARB entry describes the unknown state; `clear` is the closest one.
      if (areQuestionMarksEnabled) core.Entry.unknown: l10n.clear,
    };
    return SimpleDialog(
      children: <Widget>[
        for (final option in options.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(option.key),
            child: Row(
              children: <Widget>[
                Icon(
                  option.key == selectedValue
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: color,
                ),
                const SizedBox(width: 16),
                Text(option.value),
              ],
            ),
          ),
      ],
    );
  }
}

class _NumberPickerDialog extends StatefulWidget {
  const _NumberPickerDialog({required this.initialValue});

  final double initialValue;

  @override
  State<_NumberPickerDialog> createState() => _NumberPickerDialogState();
}

class _NumberPickerDialogState extends State<_NumberPickerDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue == 0 ? '' : _format(widget.initialValue),
  );

  static String _format(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.trim());
    Navigator.of(context).pop(value ?? 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l10n.value),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
