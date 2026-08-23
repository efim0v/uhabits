/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/{ShowHabitActivity,ShowHabitView}.kt
/// and res/layout/show_habit.xml.
///
/// The three Kotlin pieces collapse into one widget plus one [ShowHabitModel]:
///
///  * `ShowHabitActivity` is the lifecycle and the `Screen` implementation.
///    Its `onResume` / `onPause` pair is [ShowHabitModel.attach] /
///    [ShowHabitModel.detach], driven by the provider that owns the model, and
///    its `Screen.refresh()` is [ShowHabitModel.refresh]. The half of `Screen`
///    that needs a navigator — the two entry popups, the history editor, the
///    delete confirmation, the editor and `finish()` — is implemented here, as
///    [ShowHabitScreenDelegate];
///  * `ShowHabitView` is `setState`: it pushes one slice of the state into
///    each card and hides the two that do not apply to the habit's type. Both
///    halves are the core's — [ShowHabitPresenter.buildState] and
///    `ShowHabitCardVisibility` — so what is left here is the column;
///  * show_habit.xml is the column itself: a fixed toolbar over a scrolling
///    list of nine cards (`show-habit.screen-scaffold#12`).
///
/// `AndroidThemeSwitcher.currentTheme` is the shared `coreThemeOf` of
/// ui/theme/app_theme.dart, so the cards see whichever of LightTheme,
/// DarkTheme and PureBlackTheme the app was built from
/// (`show-habit.screen-scaffold#11`).
///
/// The overflow menu is [ShowHabitMenu], a straight port of ShowHabitMenu.kt
/// and res/menu/show_habit.xml; this file only draws it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

// The presenter callbacks and the chart listener are still reached by their
// `src` path.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/ui/intent_parser.dart' show parseContentUriId;
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart'
    show CheckMarkDialogCallback, NumberPickerCallback;
import 'package:uhabits_core/src/ui/views/history_chart.dart'
    show OnDateClickedListener;

import '../../../l10n/app_localizations.dart';
import '../../../state/app_scope.dart';
import '../../../state/show_habit_model.dart';
import '../../common/dialogs/checkmark_dialog.dart';
import '../../common/dialogs/confirm_delete_dialog.dart';
// Prefixed: the file's `showHistoryEditorDialog` function and this screen's
// `Screen.showHistoryEditorDialog` override have the same name.
import '../../common/dialogs/history_editor_dialog.dart' as editor;
import '../../common/dialogs/number_dialog.dart';
import '../../theme/app_theme.dart' show coreThemeOf;
import '../edit/edit_habit_screen.dart';
import 'cards/bar_card_view.dart';
import 'cards/frequency_card_view.dart';
import 'cards/history_card_view.dart';
import 'cards/notes_card_view.dart';
import 'cards/overview_card_view.dart';
import 'cards/score_card_view.dart';
import 'cards/streak_card_view.dart';
import 'cards/subtitle_card_view.dart';
import 'cards/target_card_view.dart';
import 'show_habit_menu.dart';

export 'show_habit_menu.dart' show ShowHabitMenu, ShowHabitMenuItem;

/// The habit detail screen. Owns the [ShowHabitModel] for as long as it is
/// mounted.
class ShowHabitScreen extends StatelessWidget {
  const ShowHabitScreen({required this.habit, this.system, super.key});

  /// The habit `ShowHabitActivity` would have resolved from the intent's
  /// `content://org.isoron.uhabits/habit/<id>` URI. The Flutter list hands the
  /// model over directly instead — see [habitFromUri] for the resolution step.
  final core.Habit habit;

  /// `HabitsDirFinder(AndroidDirFinder(this))`, the CSV export's output
  /// directory. Optional because it needs directories the app resolves
  /// asynchronously at startup.
  final ShowHabitMenuPresenterSystem? system;

  /// `habit = habitList.getById(ContentUris.parseId(intent.data!!))!!` —
  /// the first three statements of `onCreate` (`show-habit.screen-scaffold#1`).
  ///
  /// The `!!` is upstream's and is kept: an id that is not in the list throws
  /// here rather than opening a "habit not found" screen, because there is no
  /// such screen (`show-habit.screen-scaffold#2`).
  static core.Habit habitFromUri(core.HabitList habitList, Uri uri) =>
      habitList.getById(parseContentUriId(uri))!;

  /// The route `IntentFactory.startShowHabitActivity` builds.
  ///
  /// The scope has to be captured by the caller: `MaterialApp.home` provides
  /// it *below* the navigator, so a pushed route sits outside it.
  static Route<void> route({
    required AppScope scope,
    required core.Habit habit,
  }) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: habit.uriString),
      builder: (context) => Provider<AppScope>.value(
        value: scope,
        child: ShowHabitScreen(habit: habit),
      ),
    );
  }

  /// `ListHabitsScreen.showHabitScreen(habit)`.
  static Future<void> open(BuildContext context, core.Habit habit) {
    return Navigator.of(context).push(
      route(scope: context.read<AppScope>(), habit: habit),
    );
  }

  /// The key of one card in the column, so a test can ask where it is.
  static Key cardKey(ShowHabitCard card) => ValueKey<ShowHabitCard>(card);

  /// The toolbar's Edit action — `R.id.action_edit_habit`.
  static const Key editActionKey = Key('showHabit.actionEditHabit');

  /// The overflow button itself — the three dots the five `showAsAction=never`
  /// items live behind.
  static const Key overflowMenuKey = Key('showHabit.overflowMenu');

  /// One overflow entry, by item.
  static Key menuItemKey(ShowHabitMenuItem item) =>
      ValueKey<ShowHabitMenuItem>(item);

  @override
  Widget build(BuildContext context) {
    // Both are read here rather than inside the state: a provider's factory
    // and `initState` may not depend on an inherited widget, and `Theme.of`
    // is one.
    return _ShowHabitView(
      scope: context.read<AppScope>(),
      habit: habit,
      theme: coreThemeOf(context),
      system: system,
    );
  }
}

class _ShowHabitView extends StatefulWidget {
  const _ShowHabitView({
    required this.scope,
    required this.habit,
    required this.theme,
    required this.system,
  });

  final AppScope scope;

  final core.Habit habit;

  final core.Theme theme;

  final ShowHabitMenuPresenterSystem? system;

  @override
  State<_ShowHabitView> createState() => _ShowHabitViewState();
}

class _ShowHabitViewState extends State<_ShowHabitView>
    implements ShowHabitScreenDelegate {
  late final ShowHabitModel _model;

  /// `DialogUtils`' process-wide `currentDialog`, narrowed to this screen.
  ///
  /// `dialogs.single-current-dialog` is superseded by route stacking, so the
  /// slot is a plain closure that pops whatever tracked dialog is on top
  /// rather than a `WeakReference<Dialog>`. The dialogs routed through it are
  /// the ones `dismissCurrentAndShow` covers on this screen: the check-mark
  /// popup, the number popup and the delete confirmation.
  VoidCallback? _currentDialog;

  @override
  void initState() {
    super.initState();
    // `onCreate`: build the presenters, then wire the view to them. Nothing
    // is listening to the model yet — the provider below only starts when
    // this state first builds — so `attach()`'s refresh is free to notify.
    _model = ShowHabitModel(
      scope: widget.scope,
      habit: widget.habit,
      theme: widget.theme,
      system: widget.system,
    );
    // `ShowHabitActivity` *is* the Screen; here the widget supplies the half
    // of it that needs a navigator.
    _model.delegate = this;
    _model.reattachHistoryEditor = _reattachHistoryEditor;
    // `onResume`.
    _model.attach();
  }

  @override
  void dispose() {
    // `onPause`: dismiss whatever dialog is open, then unregister
    // (`show-habit.screen-scaffold#6`).
    _dismissCurrentDialog();
    _model.reattachHistoryEditor = null;
    if (identical(_model.delegate, this)) _model.delegate = null;
    _model.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ShowHabitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `AndroidThemeSwitcher.apply()` restarts the activity when the theme
    // changes; here the model rebuilds its state instead
    // (`show-habit.screen-scaffold#11`).
    //
    // didUpdateWidget runs inside the build phase, and the model's setter
    // refreshes and notifies — which would mark the provider below dirty
    // mid-build and throw — so the switch is deferred by one frame.
    final theme = widget.theme;
    if (theme.runtimeType == _model.theme.runtimeType) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _model.theme = theme;
    });
  }

  // -----------------------------------------------------------------------
  // The current-dialog slot
  // -----------------------------------------------------------------------

  /// `Dialog.dismissCurrentAndShow()`: dismiss the tracked dialog, register
  /// this one as current, then show it.
  Future<T?> _dismissCurrentAndShow<T>(Future<T?> Function() show) {
    _dismissCurrentDialog();
    // `showDialog` pushes onto the root navigator, so that is the one the
    // slot has to pop from.
    final navigator = Navigator.of(context, rootNavigator: true);
    late final VoidCallback token;
    token = () {
      if (navigator.canPop()) navigator.pop();
    };
    _currentDialog = token;
    final future = show();
    future.whenComplete(() {
      if (identical(_currentDialog, token)) _currentDialog = null;
    });
    return future;
  }

  /// `dismissCurrentDialog()`.
  void _dismissCurrentDialog() {
    final dismiss = _currentDialog;
    _currentDialog = null;
    dismiss?.call();
  }

  // -----------------------------------------------------------------------
  // ShowHabitActivity.Screen, the half that needs a navigator
  // -----------------------------------------------------------------------

  /// `supportFragmentManager.findFragmentByTag("historyEditor")?.let {
  ///     (it as HistoryEditorDialog).setOnDateClickedListener(
  ///         presenter.historyCardPresenter)
  /// }` — `onResume`'s middle statement (`show-habit.screen-scaffold#7`,
  /// `history-editor.dialog#13`).
  void _reattachHistoryEditor(OnDateClickedListener listener) {
    editor.HistoryEditorDialog.current?.setOnDateClickedListener(listener);
  }

  @override
  void showHistoryEditorDialog(OnDateClickedListener listener) {
    // Deliberately NOT through `_dismissCurrentAndShow`: the editor keeps its
    // own slot so that it can stay open under the entry popups
    // (`history-editor.dialog#10`, `#16`).
    editor.showHistoryEditorDialog(
      context,
      habitId: _model.habit.id!,
      habitList: _model.scope.habitList,
      commandRunner: _model.scope.commandRunner,
      preferences: _model.scope.preferences,
      listener: listener,
    );
  }

  /// `window.decorView.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)`.
  @override
  void showFeedback() {
    Feedback.forTap(context);
  }

  @override
  Future<void> showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) async {
    final theme = coreThemeOf(context);
    final result = await _dismissCurrentAndShow<NumberDialogResult>(
      () => showNumberDialog(
        context,
        value: value,
        notes: notes,
        color: theme.colorOf(_model.habit.color),
        preferences: _model.scope.preferences,
      ),
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
    final theme = coreThemeOf(context);
    final result = await _dismissCurrentAndShow<CheckmarkDialogResult>(
      () => showCheckmarkDialog(
        context,
        value: selectedValue,
        notes: notes,
        color: theme.colorOf(color),
        preferences: _model.scope.preferences,
      ),
    );
    if (result == null) {
      callback.onNotesDismissed();
      return;
    }
    callback.onNotesSaved(result.value, result.notes);
  }

  @override
  void showEditHabitScreen(core.Habit habit) {
    EditHabitScreen.open(context, habit);
  }

  /// `showMessage(resources.getQuantityString(...))`, which is
  /// `ViewExtensions.showMessage`: a short white-on-dark Snackbar at the
  /// bottom of the screen (`show-habit.archive-unarchive#3`).
  ///
  /// The Kotlin helper wraps the `Snackbar.make` in a try/catch that swallows
  /// `IllegalArgumentException` — thrown when no suitable parent view can be
  /// found — and shows nothing at all in that case; `ScaffoldMessenger.of`
  /// throws its own assertion when there is no messenger above this widget, so
  /// the same guard is spelled with `maybeOf` (`show-habit.archive-unarchive#5`).
  @override
  void showMessage(ShowHabitMenuPresenterMessage? m) {
    final l10n = L10n.of(context);
    final String text;
    switch (m) {
      case ShowHabitMenuPresenterMessage.couldNotExport:
        text = l10n.couldNotExport;
      case ShowHabitMenuPresenterMessage.habitArchived:
        text = l10n.toastHabitsArchived(1);
      case ShowHabitMenuPresenterMessage.habitUnarchived:
        text = l10n.toastHabitsUnarchived(1);
      case null:
        // Kotlin's `else -> {}`.
        return;
    }
    showShowHabitMessage(context, text);
  }

  @override
  void showSendFileScreen(String filename) =>
      throw UnsupportedError('The send file screen is not ported yet');

  /// `ConfirmDeleteDialog(this, callback, 1).dismissCurrentAndShow()`
  /// (`show-habit.delete#4`, `show-habit.delete#5`).
  @override
  Future<void> showDeleteConfirmationScreen(void Function() callback) async {
    final confirmed = await _dismissCurrentAndShow<bool>(
      () => showConfirmDeleteDialog(context, quantity: 1),
    );
    // `OnConfirmedCallback` has no cancel half: "No" simply never calls back.
    if (confirmed ?? false) callback();
  }

  /// `finish()`.
  @override
  void close() {
    Navigator.of(context).pop();
  }

  // -----------------------------------------------------------------------
  // The view
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ShowHabitModel>.value(
      value: _model,
      child: Builder(builder: _buildScaffold),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final model = context.watch<ShowHabitModel>();
    final state = model.state;
    final theme = state.theme;
    final l10n = L10n.of(context);

    // `onCreateOptionsMenu` is called once per menu build, exactly as Android
    // rebuilds the options menu.
    final items = model.menu.onCreateOptionsMenu();

    return Scaffold(
      // `@style/CardList` and the ScrollView both take ?windowBackgroundColor.
      backgroundColor: _toFlutterColor(theme.appBackgroundColor),
      appBar: AppBar(
        // `show-habit.screen-scaffold#8`: the title is habit.name, verbatim.
        title: Text(state.title),
        // `show-habit.screen-scaffold#9`. The Android dark themes set
        // useHabitColorAsPrimary=false and fall back to ?colorPrimary, a value
        // the ported core Theme does not carry, so the habit colour is used in
        // both themes here.
        // The habit's colour tints the toolbar only while the theme says so;
        // the dark themes use colorPrimary (show-habit.screen-scaffold#9).
        backgroundColor:
            _toFlutterColor(theme.toolbarColorFor(theme.colorOf(state.color))),
        // `@style/Toolbar` applies ThemeOverlay.AppCompat.Dark.ActionBar.
        foregroundColor: Colors.white,
        // `toolbar.elevation = dpToPixels(context, 2f)`
        elevation: 2,
        actions: <Widget>[
          // `app:showAsAction="ifRoom"` — only Edit is ever promoted out of
          // the overflow (`show-habit.menu#2`).
          for (final item in items)
            if (item.isActionButton)
              IconButton(
                key: item == ShowHabitMenuItem.edit
                    ? ShowHabitScreen.editActionKey
                    : ShowHabitScreen.menuItemKey(item),
                tooltip: item.title(l10n),
                icon: const Icon(Icons.edit),
                onPressed: () => model.menu.onOptionsItemSelected(item),
              ),
          // …and everything else lives behind the three dots.
          PopupMenuButton<ShowHabitMenuItem>(
            key: ShowHabitScreen.overflowMenuKey,
            onSelected: model.menu.onOptionsItemSelected,
            itemBuilder: (context) => <PopupMenuEntry<ShowHabitMenuItem>>[
              for (final item in items)
                if (!item.isActionButton)
                  PopupMenuItem<ShowHabitMenuItem>(
                    key: ShowHabitScreen.menuItemKey(item),
                    value: item,
                    child: Text(item.title(l10n)),
                  ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          // `show-habit.card-order-and-visibility#1`: the column follows
          // ShowHabitCard's declaration order, and #2/#3/#4 decide which of
          // them survive.
          children: _buildCards(context, model),
        ),
      ),
    );
  }

  /// `ShowHabitView.setState` walking show_habit.xml top to bottom.
  List<Widget> _buildCards(BuildContext context, ShowHabitModel model) {
    final widgets = <Widget>[];
    for (final card in model.cards) {
      if (!model.isVisible(card)) continue;
      widgets.add(_buildCard(context, model: model, card: card));
    }
    return widgets;
  }

  Widget _buildCard(
    BuildContext context, {
    required ShowHabitModel model,
    required ShowHabitCard card,
  }) {
    final state = model.state;
    final key = ShowHabitScreen.cardKey(card);
    switch (card) {
      case ShowHabitCard.subtitle:
        return _SubtitleCard(
          key: key,
          theme: state.theme,
          child: SubtitleCardView(state: state.subtitle),
        );
      case ShowHabitCard.notes:
        return _Card(
          key: key,
          theme: state.theme,
          child: NotesCardView(state: state.notes, theme: state.theme),
        );
      case ShowHabitCard.overview:
        return _Card(
          key: key,
          theme: state.theme,
          child: OverviewCardView(state: state.overview),
        );
      // The six chart cards bring their own `@style/Card` chrome with them.
      case ShowHabitCard.target:
        return TargetCardView(key: key, state: state.target);
      case ShowHabitCard.score:
        return ScoreCardView(
          key: key,
          state: state.scores,
          onSpinnerPosition: model.presenter.scoreCardPresenter.onSpinnerPosition,
        );
      case ShowHabitCard.bar:
        return BarCardView(
          key: key,
          state: state.bar,
          onNumericalSpinnerPosition:
              model.presenter.barCardPresenter.onNumericalSpinnerPosition,
          onBoolSpinnerPosition:
              model.presenter.barCardPresenter.onBoolSpinnerPosition,
        );
      case ShowHabitCard.history:
        return HistoryCardView(
          key: key,
          state: state.history,
          // `HistoryCardPresenter` is itself the chart's OnDateClickedListener,
          // so a tap on a calendar cell lands in the presenter and leaves again
          // as one of the two entry popups or as a CreateRepetitionCommand.
          listener: model.presenter.historyCardPresenter,
          onClickEditButton: model.presenter.historyCardPresenter.onClickEditButton,
        );
      case ShowHabitCard.streak:
        return StreakCardView(key: key, state: state.streaks);
      case ShowHabitCard.frequency:
        return FrequencyCardView(key: key, state: state.frequency);
    }
  }
}

/// Port of `ViewExtensions.showMessage(text)`, the helper every message on
/// this screen goes through:
///
/// ```kotlin
/// fun Activity.showMessage(msg: String?) {
///     if (msg == null) return
///     try {
///         val snackbar = Snackbar.make(findViewById(android.R.id.content), msg, LENGTH_SHORT)
///         (snackbar.view.findViewById(...) as TextView).setTextColor(Color.WHITE)
///         snackbar.show()
///     } catch (e: IllegalArgumentException) {
///         // Ignored: no suitable parent view
///     }
/// }
/// ```
///
/// A short snackbar with white text at the bottom of the screen
/// (`show-habit.archive-unarchive#3`); the `catch` is the part that matters
/// here — when no host can be found the message is dropped in silence rather
/// than crashing (`show-habit.archive-unarchive#5`).
void showShowHabitMessage(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// `@style/Card`, from res/values/styles.xml, on top of `@style/CardCommon`:
/// full width, 16dp/4dp horizontal padding, 16dp vertical padding, 3dp side
/// margins, a 1dp bottom margin, 1dp of elevation and the ?cardBgColor
/// background (`show-habit.card-order-and-visibility#5`).
class _Card extends StatelessWidget {
  const _Card({required this.theme, required this.child, super.key});

  final core.Theme theme;
  final Widget child;

  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 16, 4, 16);
  static const EdgeInsets margin = EdgeInsets.fromLTRB(3, 0, 3, 1);
  static const double elevation = 1.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        elevation: elevation,
        color: _toFlutterColor(theme.cardBackgroundColor),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// `@style/ShowHabit.Subtitle`, from res/values/styles_show_habit.xml: the one
/// card that is not a `@style/Card` — ?headerBackgroundColor, 2dp of
/// elevation, no margins and a 60dp start padding
/// (`show-habit.card-order-and-visibility#6`).
class _SubtitleCard extends StatelessWidget {
  const _SubtitleCard({required this.theme, required this.child, super.key});

  final core.Theme theme;
  final Widget child;

  static const EdgeInsetsDirectional padding =
      EdgeInsetsDirectional.fromSTEB(60, 15, 10, 10);
  static const double elevation = 2.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      color: _toFlutterColor(theme.headerBackgroundColor),
      child: Padding(padding: padding, child: child),
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
