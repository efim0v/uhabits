/// The screen-facing half of the habit detail screen.
///
/// Port of the `Screen` inner class of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt
/// together with the activity's `onResume` / `onPause` / `onCommandFinished`
/// lifecycle.
///
/// Kotlin's `Screen` is an inner class of the activity and implements both
/// `ShowHabitPresenter.Screen` and `ShowHabitMenuPresenter.Screen`; half of its
/// members are pure model work (`refresh`, `updateWidgets`) and half are
/// dialogs and navigation, which need a `BuildContext`. This class is that
/// inner class: it does the model half itself and forwards the other half to a
/// [ShowHabitScreenDelegate] the widget installs when it mounts.
///
/// Everything else it knows how to do is: hold the habit, register itself as a
/// [CommandRunnerListener], and rebuild the whole [ShowHabitState] from
/// [ShowHabitPresenter.buildState] whenever anything happens
/// (`show-habit.screen-scaffold#3`: there is no incremental card update, the
/// state is thrown away and rebuilt from scratch every single time).
///
/// The card *order* and the per-habit-type *visibility* are the core's
/// [ShowHabitCardVisibility], not this class's: it is fed the freshly built
/// state and asked which cards survive.
library;

// The presenters, the commands and the preferences are still reached by their
// `src` path — the core library re-exports only its models, database, time and
// drawing layers.
// ignore_for_file: implementation_imports

import 'package:flutter/foundation.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart'
    show CheckMarkDialogCallback, NumberPickerCallback;
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit_menu_presenter.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart'
    show OnDateClickedListener;
import 'package:uhabits_core/uhabits_core.dart';

import '../ui/habits/show/show_habit_menu.dart';
import 'app_scope.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/show_habit.dart'
    show
        ShowHabitCard,
        ShowHabitCardVisibility,
        ShowHabitPresenter,
        ShowHabitPresenterScreen,
        ShowHabitState;
export 'package:uhabits_core/src/ui/screens/habits/show/show_habit_menu_presenter.dart'
    show
        ShowHabitMenuPresenter,
        ShowHabitMenuPresenterMessage,
        ShowHabitMenuPresenterScreen,
        ShowHabitMenuPresenterSystem;
export 'package:uhabits_core/src/ui/screens/habits/show/views/bar_card.dart'
    show BarCardPresenter, BarCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/frequency_card.dart'
    show FrequencyCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart'
    show HistoryCardPresenter, HistoryCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/notes_card.dart'
    show NotesCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/overview_card.dart'
    show OverviewCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/score_card.dart'
    show ScoreCardPresenter, ScoreCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/streak_card.dart'
    show StreakCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/subtitle_card.dart'
    show SubtitleCardState;

/// The half of `ShowHabitActivity.Screen` that needs a `BuildContext`: every
/// dialog it opens, the editor it starts and `finish()`.
///
/// The widget implements it and hands itself to [ShowHabitModel.delegate] when
/// it mounts, which is what makes the model usable from a plain unit test.
abstract interface class ShowHabitScreenDelegate {
  void showHistoryEditorDialog(OnDateClickedListener listener);

  void showFeedback();

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

  void showEditHabitScreen(Habit habit);

  void showMessage(ShowHabitMenuPresenterMessage? m);

  void showSendFileScreen(String filename);

  void showDeleteConfirmationScreen(void Function() callback);

  void close();
}

class ShowHabitModel extends ChangeNotifier
    implements
        CommandRunnerListener,
        ShowHabitPresenterScreen,
        ShowHabitMenuPresenterScreen {
  /// Builds the first state immediately.
  ///
  /// `ShowHabitActivity.onCreate` does not: it inflates the layout with the XML
  /// defaults and waits for `onResume` to call `refresh()`, so the Android
  /// screen shows a frame of empty labels. A Flutter widget has no "inflated
  /// but unset" state to show, so the first build happens here and [attach]
  /// — which is `onResume` — refreshes on top of it.
  ShowHabitModel({
    required this.scope,
    required this.habit,
    required Theme theme,
    ShowHabitMenuPresenterSystem? system,
    void Function()? widgetUpdater,
  })  : _theme = theme,
        _widgetUpdater = widgetUpdater {
    // `ShowHabitPresenter(...)` and `ShowHabitMenuPresenter(...)`, both built
    // in onCreate with `screen = this`.
    presenter = ShowHabitPresenter(
      commandRunner: scope.commandRunner,
      habit: habit,
      habitList: scope.habitList,
      preferences: scope.preferences,
      screen: this,
    );
    menuPresenter = ShowHabitMenuPresenter(
      commandRunner: scope.commandRunner,
      habit: habit,
      habitList: scope.habitList,
      screen: this,
      system: system ?? const _UnresolvedCSVOutputDir(),
      taskRunner: scope.taskRunner,
    );
    menu = ShowHabitMenu(
      presenter: menuPresenter,
      preferences: scope.preferences,
    );
    _rebuild();
  }

  final AppScope scope;

  /// `habitList.getById(ContentUris.parseId(intent.data!!))!!`.
  ///
  /// The Flutter navigation hands the habit over directly rather than through
  /// a content URI; `ShowHabitScreen.habitFromUri` is the resolution step
  /// itself, `!!` and all (`show-habit.screen-scaffold#1`, `#2`).
  final Habit habit;

  /// `presenter`, the field `onResume` reaches into for
  /// `presenter.historyCardPresenter`.
  late final ShowHabitPresenter presenter;

  /// `menuPresenter`.
  late final ShowHabitMenuPresenter menuPresenter;

  /// `menu`.
  late final ShowHabitMenu menu;

  /// The dialog half of `ShowHabitActivity.Screen`. Null until the widget
  /// mounts, and again after it goes.
  ShowHabitScreenDelegate? delegate;

  /// `widgetUpdater.updateWidgets()`. Injected so a test can watch the call
  /// without a live platform channel; by default it is the app's real
  /// [WidgetSync], which is null until `startPlatformServices` has run.
  final void Function()? _widgetUpdater;

  Theme _theme;

  late ShowHabitState _state;

  final ShowHabitCardVisibility _visibility = ShowHabitCardVisibility();

  bool _attached = false;

  /// The whole state of the screen, rebuilt by every [refresh].
  ShowHabitState get state => _state;

  /// `AndroidThemeSwitcher.currentTheme`. The widget layer decides which one
  /// it is — the Flutter brightness stands in for `pref_theme` plus the system
  /// dark mode of `show-habit.screen-scaffold#11`.
  Theme get theme => _theme;

  set theme(Theme value) {
    // Themes carry no identity of their own, so two instances of the same
    // class are the same theme.
    if (value.runtimeType == _theme.runtimeType) return;
    _theme = value;
    refresh();
  }

  /// The nine cards of show_habit.xml in layout order —
  /// `show-habit.card-order-and-visibility#1`.
  List<ShowHabitCard> get cards => ShowHabitCard.values;

  /// `View.getVisibility() != GONE` for one card, as decided by
  /// `ShowHabitView.setState` and `NotesCardView.setState`.
  bool isVisible(ShowHabitCard card) => _visibility.isVisible(card);

  // -----------------------------------------------------------------------
  // Lifecycle. Port of ShowHabitActivity.onResume / onPause.
  // -----------------------------------------------------------------------

  /// `onResume`: registers as a command listener, re-attaches the history
  /// editor's date-clicked listener, and refreshes.
  void attach() {
    if (_attached) return;
    _attached = true;
    scope.commandRunner.addListener(this);
    // supportFragmentManager.findFragmentByTag("historyEditor")?.let {
    //     (it as HistoryEditorDialog).setOnDateClickedListener(
    //         presenter.historyCardPresenter)
    // }
    // (`show-habit.screen-scaffold#7`, `history-editor.dialog#13`.)
    reattachHistoryEditor?.call(presenter.historyCardPresenter);
    refresh();
  }

  /// The `findFragmentByTag("historyEditor")` lookup, installed by the widget
  /// because only it can reach the navigator. Left null in a unit test, where
  /// there is no fragment manager to search.
  void Function(OnDateClickedListener listener)? reattachHistoryEditor;

  /// `onPause`: dismisses the open dialog and unregisters.
  void detach() {
    if (!_attached) return;
    _attached = false;
    scope.commandRunner.removeListener(this);
  }

  @override
  void dispose() {
    detach();
    delegate = null;
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // ShowHabitPresenter.Screen
  // -----------------------------------------------------------------------

  /// `Screen.refresh()`. Kotlin launches it on `Dispatchers.Main`
  /// (`show-habit.screen-scaffold#5`); Flutter has one UI isolate, so this is
  /// already the main thread.
  @override
  void refresh() {
    _rebuild();
    notifyListeners();
  }

  /// `Screen.updateWidgets()` — `widgetUpdater.updateWidgets()`, which pushes
  /// new data to every home-screen widget (`show-habit.widget-refresh#2`).
  ///
  /// The bucket spinners write their choice into [Preferences] *before* this
  /// runs, and the widgets read their bucket size out of the very same
  /// preferences, so the refresh is what makes their charts follow the screen.
  @override
  void updateWidgets() {
    if (_widgetUpdater != null) {
      _widgetUpdater();
      return;
    }
    scope.widgetSync?.updateWidgets();
  }

  void _rebuild() {
    _state = ShowHabitPresenter.buildState(
      habit: habit,
      preferences: scope.preferences,
      theme: _theme,
    );
    _visibility.setState(_state);
  }

  /// `CommandRunner.Listener.onCommandFinished` — every command refreshes the
  /// whole screen, whatever it was and whichever habit it touched
  /// (`show-habit.screen-scaffold#4`).
  @override
  void onCommandFinished(Command command) => refresh();

  // -----------------------------------------------------------------------
  // The dialog half, forwarded to the widget
  // -----------------------------------------------------------------------

  @override
  void showHistoryEditorDialog(OnDateClickedListener listener) =>
      delegate?.showHistoryEditorDialog(listener);

  @override
  void showFeedback() => delegate?.showFeedback();

  @override
  void showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) =>
      delegate?.showNumberPopup(value, notes, callback);

  @override
  void showCheckmarkPopup(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  ) =>
      delegate?.showCheckmarkPopup(selectedValue, notes, color, callback);

  @override
  void showEditHabitScreen(Habit habit) =>
      delegate?.showEditHabitScreen(habit);

  @override
  void showMessage(ShowHabitMenuPresenterMessage? m) =>
      delegate?.showMessage(m);

  @override
  void showSendFileScreen(String filename) =>
      delegate?.showSendFileScreen(filename);

  @override
  void showDeleteConfirmationScreen(void Function() callback) =>
      delegate?.showDeleteConfirmationScreen(callback);

  @override
  void close() => delegate?.close();
}

/// `HabitsDirFinder(AndroidDirFinder(this))` needs the app's external files
/// directories, which are resolved asynchronously at startup and are not
/// threaded into this screen yet — the same gap the habit list's own Export
/// action has. Selecting Export without one throws rather than silently
/// exporting nowhere.
class _UnresolvedCSVOutputDir implements ShowHabitMenuPresenterSystem {
  const _UnresolvedCSVOutputDir();

  @override
  UserFile getCSVOutputDir() =>
      throw UnsupportedError('No CSV output directory has been resolved');
}
