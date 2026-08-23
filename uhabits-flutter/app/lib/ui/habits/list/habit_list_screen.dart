/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/{ListHabitsActivity,ListHabitsRootView,ListHabitsScreen}.kt
///
/// The three Kotlin classes collapse into one widget plus one [HabitListModel]:
///
///  * `ListHabitsActivity` is the lifecycle — `onResume` attaches the adapter
///    and refreshes it, `onPause` detaches and cancels. That is
///    [HabitListModel.attach] / [HabitListModel.detach], driven here by the
///    provider that owns the model.
///  * `ListHabitsRootView` is the layout: the konfetti overlay, a toolbar, the
///    date strip, the card list with the empty view over it, the task progress
///    bar and the hint box — see `list_habits_root_view.dart` for the last
///    four. Its `getCheckmarkCount()` is [_HabitListViewState._checkmarkCount]
///    and its `updateEmptyView()` is [_HabitListViewState._buildEmptyView].
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
// The core package does not re-export lib/src/ui/screens yet.
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/screens/habits/list/hint_list.dart' as core;
// ignore: implementation_imports
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_selection_menu_behavior.dart'
    as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../../../state/habit_list_model.dart';
import '../../../state/intent_router.dart' as intents;
import '../../../state/theme_model.dart';
import '../../../state/widget_link.dart';
import '../../about/about_screen.dart';
import '../../common/dialogs/checkmark_dialog.dart';
import '../../common/dialogs/color_picker_dialog.dart';
import '../../common/dialogs/confirm_delete_dialog.dart';
import '../../common/dialogs/number_dialog.dart';
import '../../settings/settings_screen.dart';
import '../edit/edit_habit_screen.dart';
import '../show/show_habit_screen.dart';
import 'habit_card.dart';
import 'list_habits_command_toasts.dart';
import 'list_habits_menu.dart';
import 'list_habits_root_view.dart';
import 'list_habits_selection_menu.dart';
import 'list_header.dart';

/// The main screen. Owns the [HabitListModel] for as long as it is mounted.
class HabitListScreen extends StatelessWidget {
  const HabitListScreen({this.onOpenUrl, this.widgetLinks, super.key});

  /// The habit card list — a `ListView` or a `ReorderableListView`, depending
  /// on whether the adapter is sortable, so callers that only want "the list"
  /// address it by key.
  static const Key habitCardListKey = ValueKey<String>('habitCardList');

  /// `Activity.startActivitySafely(Intent(ACTION_VIEW, uri))`, which the
  /// 'Help & FAQ' menu item goes through. Null degrades to the no-op Android
  /// falls back to when nothing can handle the intent.
  final void Function(String url)? onOpenUrl;

  /// The app-level receiver for `uhabits://widget/...`.
  ///
  /// This screen is `ListHabitsActivity`, and upstream the ACTION_EDIT deep
  /// link is delivered straight to it: the system sets `Activity.intent`, and
  /// `parseIntents()` reads it at the end of the next `onResume`. A Flutter app
  /// has one activity for the whole process, so the link lands app-wide first;
  /// registering with the router while this screen is mounted is what puts it
  /// back where upstream had it. Null in every test that pumps the screen on
  /// its own, and on any host with no widget support.
  final WidgetLinkRouter? widgetLinks;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HabitListModel>(
      create: (context) => HabitListModel(context.read<AppScope>())..attach(),
      child: _HabitListView(onOpenUrl: onOpenUrl, widgetLinks: widgetLinks),
    );
  }
}

class _HabitListView extends StatefulWidget {
  const _HabitListView({this.onOpenUrl, this.widgetLinks});

  final void Function(String url)? onOpenUrl;

  final WidgetLinkRouter? widgetLinks;

  @override
  State<_HabitListView> createState() => _HabitListViewState();
}

class _HabitListViewState extends State<_HabitListView> with RestorationMixin {
  /// `HabitCardListView.dataOffset`, fed by the header's scroll controller —
  /// `ListHabitsRootView.setupControllers`.
  ///
  /// `HabitCardListView.onSaveInstanceState` puts it in the saved instance
  /// state next to the header's own scroller state
  /// (`list-habits.header-scrolling#8`).
  final RestorableInt _dataOffsetState = RestorableInt(0);

  int get _dataOffset => _dataOffsetState.value;

  set _dataOffset(int value) => _dataOffsetState.value = value;

  @override
  String? get restorationId => 'listHabits';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_dataOffsetState, 'dataOffset');
  }

  late final HabitListModel _model;

  /// `ListHabitsScreen` as a `CommandRunner.Listener`: the per-command toast,
  /// registered while the screen is in the foreground
  /// (`commands.listener-list-habits-toasts#1`).
  late final ListHabitsCommandToasts _toasts;

  /// `ListHabitsRootView.konfettiView`.
  final GlobalKey<ConfettiOverlayState> _confettiKey =
      GlobalKey<ConfettiOverlayState>();

  /// `ListHabitsRootView.hintView`, and the `HintList` it was built with.
  final GlobalKey<HintViewState> _hintKey = GlobalKey<HintViewState>();

  late final core.HintList _hintList;

  /// `ListHabitsActivity.menu`.
  final GlobalKey<ListHabitsMenuState> _menuKey =
      GlobalKey<ListHabitsMenuState>();

  /// `component.themeSwitcher`. The app installs one above this screen; the
  /// widget tests pump the screen on its own, so a local one stands in.
  late final ThemeModel _themeSwitcher;

  /// The window position of the entry button the last gesture landed on, which
  /// is `HabitCardView.getAbsoluteButtonLocation(date)`; null until one does.
  Offset? _lastEntryPress;

  /// The animator duration scale `showConfetti` reads off Settings.Global. On
  /// Flutter it is the ambient "disable animations" accessibility flag, which
  /// is the same switch (`list-habits.confetti#2`).
  double get _animatorDurationScale =>
      MediaQuery.disableAnimationsOf(context) ? 0.0 : 1.0;

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
      ..onShowCheckmarkPopup = _showCheckmarkPopup
      ..onShowConfetti = _showConfetti;
    // `ListHabitsMenu` is constructed with the activity's ThemeSwitcher and
    // the four navigation callbacks of `ListHabitsMenuBehavior.Screen`.
    _themeSwitcher = _readThemeModel() ?? ThemeModel(_model.scope.preferences);
    _model
      ..nightModeGetter = (() => _themeSwitcher.isNightMode)
      ..nightModeToggle = _themeSwitcher.toggleNightMode
      // `ListHabitsScreen.applyTheme()` restarts the activity with a fade;
      // here the ThemeModel notifies and the app rebuilds itself.
      ..onApplyTheme = _themeSwitcher.apply
      ..onShowAboutScreen = _openAbout
      ..onShowFAQScreen = _openFAQ
      ..onShowSettingsScreen = _openSettings
      ..onShowSelectHabitTypeDialog = _createHabit
      // `ListHabitsSelectionMenu` as the controller's ActionMode.Callback, and
      // as `ListHabitsSelectionMenuBehavior.Screen`.
      ..onSelectionStarted = _refreshSelectionBar
      ..onSelectionChanged = _refreshSelectionBar
      ..onSelectionFinished = _refreshSelectionBar
      ..onShowColorPicker = _showColorPicker
      ..onShowDeleteConfirmationScreen = _showDeleteConfirmation
      ..onShowEditHabitsScreen = _showEditHabitsScreen;
    // `ListHabitsRootView.init`: the root builds the hint list from the
    // `R.array.hints` string-array and hands it to its HintView.
    _hintList = core.HintList(
      _model.scope.preferences,
      core.listHabitsHints,
    );
    // `ListHabitsActivity.onResume` -> `screen.onAttached()`.
    _toasts = ListHabitsCommandToasts(
      commandRunner: _model.scope.commandRunner,
      strings: () => L10n.of(context),
      showMessage: (message) {
        if (mounted) showListHabitsMessage(context, message);
      },
    )..onAttached();
    // After the first frame, because acting on the intent means showing a
    // dialog and there is no route to show one on until then. `onResume` has
    // the same property upstream: the window exists before `parseIntents()`
    // runs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.widgetLinks?.attachListScreen(_onDeepLinkIntent);
    });
  }

  /// `ListHabitsActivity.onNewIntent` -> `setIntent(intent)`, followed by the
  /// `parseIntents()` its next `onResume` would have run.
  ///
  /// Both halves are the model's already (`list-habits.startup-lifecycle#8`);
  /// this only delivers.
  void _onDeepLinkIntent(intents.Intent intent) {
    _model
      ..pendingIntent = intent
      ..parseIntents();
  }

  @override
  void dispose() {
    _dataOffsetState.dispose();
    // `ListHabitsActivity.onPause` -> `screen.onDetached()`.
    _toasts.onDetached();
    _model
      ..onShowHabitScreen = null
      ..onShowNumberPopup = null
      ..onShowCheckmarkPopup = null
      ..onShowConfetti = null
      ..nightModeGetter = null
      ..nightModeToggle = null
      ..onApplyTheme = null
      ..onShowAboutScreen = null
      ..onShowFAQScreen = null
      ..onShowSettingsScreen = null
      ..onShowSelectHabitTypeDialog = null
      ..onSelectionStarted = null
      ..onSelectionChanged = null
      ..onSelectionFinished = null
      ..onShowColorPicker = null
      ..onShowDeleteConfirmationScreen = null
      ..onShowEditHabitsScreen = null;
    widget.widgetLinks?.detachListScreen(_onDeepLinkIntent);
    super.dispose();
  }

  ThemeModel? _readThemeModel() {
    try {
      return Provider.of<ThemeModel>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// `startSupportActionMode` / `invalidate` / `finish`: all three come down
  /// to redrawing the toolbar from the current selection.
  void _refreshSelectionBar() {
    if (mounted) setState(() {});
  }

  /// `ListHabitsSelectionMenuBehavior.Screen.showColorPicker`.
  Future<void> _showColorPicker(
    core.PaletteColor defaultColor,
    core.OnColorPickedCallback callback,
  ) async {
    final picked = await showColorPickerDialog(context, selected: defaultColor);
    // A dismissal runs no command (`list-habits.selection-menu-actions#15`).
    if (picked == null) return;
    callback(picked);
  }

  /// `ListHabitsSelectionMenuBehavior.Screen.showDeleteConfirmationScreen`.
  Future<void> _showDeleteConfirmation(
    core.OnConfirmedCallback callback,
    int quantity,
  ) async {
    final confirmed =
        await showConfirmDeleteDialog(context, quantity: quantity);
    if (!confirmed) return;
    callback();
  }

  /// `ListHabitsSelectionMenuBehavior.Screen.showEditHabitsScreen`, which
  /// upstream edits the first selected habit.
  Future<void> _showEditHabitsScreen(List<core.Habit> selected) {
    if (selected.isEmpty) return Future<void>.value();
    return EditHabitScreen.open(context, selected.first);
  }

  /// `ListHabitsScreen.showConfetti(color, x, y)`.
  ///
  /// The guards and the party are [buildConfettiParty]; all that is left here
  /// is handing the burst to the KonfettiView.
  void _showConfetti(core.PaletteColor color, double x, double y) {
    final theme = _coreThemeOf(context);
    final party = buildConfettiParty(
      baseColor: theme.colorOf(color),
      position: Offset(x, y),
      preferences: _model.scope.preferences,
      animatorDurationScale: _animatorDurationScale,
    );
    if (party == null) return;
    _confettiKey.currentState?.start(party);
  }

  /// `HabitCardView.getAbsoluteButtonLocation(date)`, resolved into the
  /// konfetti view's own coordinates: the root already carried the left window
  /// inset away as padding, so this is the window position less that inset
  /// (`list-habits.confetti#5`).
  Offset _confettiOrigin() {
    final press = _lastEntryPress;
    final overlay = _confettiKey.currentContext?.findRenderObject();
    if (press == null || overlay is! RenderBox) return Offset.zero;
    return overlay.globalToLocal(press);
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

    // `rootView.applyRootViewInsets()`: the left and right window insets become
    // padding on the root, and the root paints itself black behind them
    // (`list-habits.screen-layout#7`). The top inset stays with the toolbar,
    // which Scaffold gives its AppBar for free, and the bottom one is consumed
    // by the card list (`#8`).
    final padding = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.only(left: padding.left, right: padding.right),
        child: MediaQuery.removePadding(
          context: context,
          removeLeft: true,
          removeRight: true,
          child: Stack(
            children: <Widget>[
              _buildScaffold(context, l10n, model, theme, toolbarColor,
                  bottomInset: padding.bottom),
              // `addAtTop(konfettiView)` with `translationZ = 10f`: the burst
              // covers the whole root, toolbar included, and its origin is the
              // window position of the tapped button less the left inset the
              // root padding above already took out
              // (`list-habits.screen-layout#1`, `list-habits.confetti#5`).
              Positioned.fill(child: ConfettiOverlay(key: _confettiKey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    L10n l10n,
    HabitListModel model,
    core.Theme theme,
    Color toolbarColor, {
    required double bottomInset,
  }) {
    return Scaffold(
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      // `res/menu/list_habits.xml`, inflated by `ListHabitsMenu.onCreate` —
      // or the contextual action bar, while a selection is active.
      appBar: model.isSelectionEmpty
          ? ListHabitsMenu(
              key: _menuKey,
              model: model,
              title: l10n.mainActivityTitle,
              backgroundColor: toolbarColor,
            )
          : ListHabitsSelectionMenu(
              model: model,
              backgroundColor: toolbarColor,
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

          // `ListHabitsRootView.init`, in the order the RelativeLayout stacks
          // its children (`list-habits.screen-layout#1`): the konfetti view at
          // translationZ 10 above everything, the toolbar (Scaffold's AppBar,
          // just above), the header below it, the card list and the empty view
          // sharing the area below the header, the progress bar overlapping the
          // header's bottom edge by 6dp, and the hint pinned to the bottom.
          return Stack(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ListHeader(
                    restorationId: 'header',
                    buttonCount: buttonCount,
                    dataOffset: dataOffset,
                    isCheckmarkSequenceReversed:
                        model.scope.preferences.isCheckmarkSequenceReversed,
                    onDataOffsetChanged: (value) =>
                        setState(() => _dataOffset = value),
                    theme: theme,
                  ),
                  Expanded(
                    child: Stack(
                      children: <Widget>[
                        _buildList(
                          context,
                          model: model,
                          theme: theme,
                          buttonCount: buttonCount,
                          dataOffset: dataOffset,
                          bottomInset: bottomInset,
                        ),
                        // `addBelow(llEmpty, header, height = MATCH_PARENT)`.
                        _buildEmptyView(context, model: model, theme: theme),
                      ],
                    ),
                  ),
                ],
              ),
              // `addBelow(progressBar, header) { it.topMargin = dp(-6f) }`.
              Positioned(
                left: 0,
                right: 0,
                top: theme.checkmarkButtonSize - 6,
                child: TaskProgressBar(
                  runner: model.scope.taskRunner,
                  color: toolbarColor,
                ),
              ),
              // `addAtBottom(hintView)`.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HintView(
                  key: _hintKey,
                  hintList: _hintList,
                  title: l10n.hintTitle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// `ListHabitsRootView.updateEmptyView()`.
  Widget _buildEmptyView(
    BuildContext context, {
    required HabitListModel model,
    required core.Theme theme,
  }) {
    final l10n = L10n.of(context);
    return EmptyListView(
      theme: theme,
      mode: model.showEmptyState
          ? EmptyListMode.empty
          : model.showDoneState
              ? EmptyListMode.done
              : EmptyListMode.hidden,
      emptyText: l10n.noHabitsFound,
      doneText: l10n.noHabitsLeftToDo,
    );
  }

  Widget _buildList(
    BuildContext context, {
    required HabitListModel model,
    required core.Theme theme,
    required int buttonCount,
    required int dataOffset,
    required double bottomInset,
  }) {
    // The Android list has no top padding; the bottom one keeps the last card
    // clear of the floating action button. `applyBottomInset` adds the bottom
    // systemBars inset to the last card, exactly once
    // (`list-habits.screen-layout#8`).
    final padding = EdgeInsets.only(top: 0, bottom: 88 + bottomInset);
    Widget buildRow(
      BuildContext context,
      int index, {
      bool ownLongPress = true,
    }) =>
        _buildCard(
          model: model,
          theme: theme,
          index: index,
          buttonCount: buttonCount,
          dataOffset: dataOffset,
          ownLongPress: ownLongPress,
        );

    // `HabitCardListView.attachedToItemTouchHelper`: the helper is only wired
    // up while the adapter is sortable, i.e. while the primary order is
    // BY_POSITION (`list-habits.drag-reorder#1`).
    if (!model.isSortable) {
      return ListView.builder(
        key: HabitListScreen.habitCardListKey,
        padding: padding,
        itemCount: model.itemCount,
        itemBuilder: buildRow,
      );
    }
    return ReorderableListView.builder(
      key: HabitListScreen.habitCardListKey,
      padding: padding,
      itemCount: model.itemCount,
      // `isLongPressDragEnabled() == false`: the helper never starts a drag by
      // itself, the row does (`list-habits.drag-reorder#3`).
      buildDefaultDragHandles: false,
      // `getMovementFlags` allows UP or DOWN only; swipe is declared but
      // `isItemViewSwipeEnabled()` is false, so `onSwiped` never runs
      // (`list-habits.drag-reorder#3`, `#9`).
      onReorderStart: model.listController.startDrag,
      onReorder: (from, to) {
        // ReorderableListView reports the index the row lands at *after* it
        // has been lifted out, which is one further along than the adapter
        // position `onMove` hands the controller.
        model.listController.drop(from, to > from ? to - 1 : to);
      },
      // `HabitCardListView.onItemLongClick`: the long press goes to the touch
      // helper, whose `startDrag` runs the very same selection path
      // (`NormalMode.startDrag` -> `startSelection`), so the row does not need
      // a long-press handler of its own (`list-habits.drag-reorder#2`).
      itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
        key: ValueKey<int>(model.cardAt(index)?.habit.id ?? index),
        index: index,
        child: buildRow(context, index, ownLongPress: false),
      ),
    );
  }

  Widget _buildCard({
    required HabitListModel model,
    required core.Theme theme,
    required int index,
    required int buttonCount,
    required int dataOffset,
    bool ownLongPress = true,
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
      // `HabitCardView` passes `getAbsoluteButtonLocation(date)` into both
      // presenter calls; that is what places the confetti burst.
      onEntryPressed: (_, globalCenter) => _lastEntryPress = globalCenter,
      onToggle: (date, value, notes) {
        final origin = _confettiOrigin();
        model.onToggle(habit, date, value, notes, origin.dx, origin.dy);
      },
      onEdit: (date) {
        final origin = _confettiOrigin();
        model.onEdit(habit, date, origin.dx, origin.dy);
      },
      // `HabitCardListController.onItemClick` / `onItemLongClick`: the mode
      // decides whether a tap opens the habit or toggles its selection.
      onTap: () => model.listController.onItemClick(index),
      onLongPress:
          ownLongPress ? () => model.listController.onItemLongClick(index) : null,
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

  /// `ListHabitsScreen.showFAQScreen()`:
  /// `activity.showSendEmailScreen`'s sibling, `startActivitySafely(
  /// Intent(ACTION_VIEW, Uri.parse(getString(R.string.helpURL))))`.
  void _openFAQ() => widget.onOpenUrl?.call(SettingsScreen.helpUrl);

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

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
