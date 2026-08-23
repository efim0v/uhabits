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
import '../../about/about_screen.dart';
import '../../common/dialogs/checkmark_dialog.dart';
import '../../common/dialogs/number_dialog.dart';
import '../../settings/settings_screen.dart';
import '../edit/edit_habit_screen.dart';
import '../show/show_habit_screen.dart';
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
      // `ListHabitsScreen.showHabitScreen(h)`: startActivity(
      // IntentFactory().startShowHabitActivity(context, h)).
      ..onShowHabitScreen = ((habit) => ShowHabitScreen.open(context, habit))
      ..onShowNumberPopup = _showNumberPopup
      ..onShowCheckmarkPopup = _showCheckmarkPopup;
  }

  @override
  void dispose() {
    _model
      ..onShowHabitScreen = null
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
    // `setupToolbar`: the habit palette colour, unless the theme says
    // otherwise — the dark themes paint the toolbar with colorPrimary instead
    // (list-habits.screen-layout#2).
    final toolbarColor = _toFlutterColor(
      theme.toolbarColorFor(theme.colorOf(const core.PaletteColor(17))),
    );

    return Scaffold(
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      appBar: AppBar(
        title: Text(l10n.mainActivityTitle),
        backgroundColor: toolbarColor,
        foregroundColor: Colors.white,
        // `toolbar.elevation = dp(2f)`
        elevation: 2,
        actions: <Widget>[
          // `res/menu/list_habits.xml`: Settings sits in the overflow menu.
          // The rest of that menu belongs to the list-menu slice; this is the
          // entry point the settings and about screens need to be reachable
          // at all.
          PopupMenuButton<String>(
            key: const Key('listHabits.overflowMenu'),
            onSelected: (value) {
              if (value == 'settings') _openSettings();
              if (value == 'about') _openAbout();
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'settings',
                child: Text(l10n.actionSettings),
              ),
              PopupMenuItem<String>(
                value: 'about',
                child: Text(l10n.about),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createHabit,
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

  /// `ListHabitsMenuBehavior.onCreateHabit()` asks the screen for the habit
  /// type chooser, and each of its two cards starts `EditHabitActivity` with
  /// the type it stands for (`habit-type-dialog.select-type#1`, `#6`).
  Future<void> _createHabit() => EditHabitScreen.selectTypeAndOpen(context);

  /// `res/menu/list_habits.xml` -> `SettingsActivity`.
  Future<void> _openSettings() {
    final scope = context.read<AppScope>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Provider<AppScope>.value(
          value: scope,
          child: SettingsScreen(
            storage: scope.preferencesStorage,
            onShowAbout: () => _openAbout(),
          ),
        ),
      ),
    );
  }

  /// `res/menu/list_habits.xml` -> `AboutActivity`.
  Future<void> _openAbout() {
    final scope = context.read<AppScope>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Provider<AppScope>.value(
          value: scope,
          child: AboutScreen(preferences: scope.preferences),
        ),
      ),
    );
  }

  /// `ListHabitsScreen.showNumberPopup(value, notes, callback)`.
  ///
  /// The real `NumberDialog` port, not a stand-in: the value field, the Skip
  /// and question-mark shortcuts, the notes field and the dismissal rules all
  /// come from `ui/common/dialogs/number_dialog.dart`
  /// (`list-habits.entry-edit-popup-numeric#2` .. `#10`). A dismissal that did
  /// not touch the notes completes with null, which is the presenter's
  /// `onNumberPickerDismissed` — the no-op that runs no command.
  Future<void> _showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) async {
    final theme = _coreThemeOf(context);
    final result = await showNumberDialog(
      context,
      value: value,
      notes: notes,
      // NumberDialog tints only the buttons of the boolean row, which stays
      // hidden here; the colour is passed because the Android arguments carry
      // it (`number-dialog.popup#1`).
      color: theme.colorOf(const core.PaletteColor(0)),
      preferences: _model.scope.preferences,
    );
    if (result == null) {
      callback.onNumberPickerDismissed();
      return;
    }
    callback.onNumberPicked(result.value, result.notes);
  }

  /// `ListHabitsScreen.showCheckmarkPopup(value, notes, color, callback)`.
  ///
  /// The real `CheckmarkDialog` port: four glyph buttons over a notes field,
  /// with Skip and Unknown gated on the preferences
  /// (`list-habits.entry-edit-popup-boolean#2` .. `#7`).
  Future<void> _showCheckmarkPopup(
    int selectedValue,
    String notes,
    core.PaletteColor color,
    CheckMarkDialogCallback callback,
  ) async {
    final theme = _coreThemeOf(context);
    final result = await showCheckmarkDialog(
      context,
      value: selectedValue,
      notes: notes,
      color: theme.colorOf(color),
      preferences: _model.scope.preferences,
    );
    if (result == null) {
      callback.onNotesDismissed();
      return;
    }
    callback.onNotesSaved(result.value, result.notes);
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


/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
