/// The screen-facing half of the habit detail screen.
///
/// Port of the `Screen` inner class of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitActivity.kt
/// together with the activity's `onResume` / `onPause` / `onCommandFinished`
/// lifecycle.
///
/// Everything it knows how to do is: hold the habit, register itself as a
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
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit.dart';
import 'package:uhabits_core/uhabits_core.dart';

import 'app_scope.dart';

export 'package:uhabits_core/src/ui/screens/habits/show/show_habit.dart'
    show ShowHabitCard, ShowHabitCardVisibility, ShowHabitPresenter, ShowHabitState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/notes_card.dart'
    show NotesCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/overview_card.dart'
    show OverviewCardState;
export 'package:uhabits_core/src/ui/screens/habits/show/views/subtitle_card.dart'
    show SubtitleCardState;

class ShowHabitModel extends ChangeNotifier implements CommandRunnerListener {
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
  }) : _theme = theme {
    _rebuild();
  }

  final AppScope scope;

  /// `habitList.getById(ContentUris.parseId(intent.data!!))!!`.
  ///
  /// The Flutter navigation hands the habit over directly rather than through
  /// a content URI, so `show-habit.screen-scaffold#1` and `#2` (the `!!` that
  /// crashes when the id is unknown) have no counterpart here: there is no id
  /// to fail to resolve.
  final Habit habit;

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

  /// `onResume`: registers as a command listener and refreshes.
  void attach() {
    if (_attached) return;
    _attached = true;
    scope.commandRunner.addListener(this);
    refresh();
  }

  /// `onPause`: unregisters. Android also dismisses whatever dialog is open;
  /// a Flutter route takes its dialogs with it.
  void detach() {
    if (!_attached) return;
    _attached = false;
    scope.commandRunner.removeListener(this);
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // ShowHabitPresenter.Screen
  // -----------------------------------------------------------------------

  /// `Screen.refresh()`. Kotlin launches it on `Dispatchers.Main`
  /// (`show-habit.screen-scaffold#5`); Flutter has one UI isolate, so this is
  /// already the main thread.
  void refresh() {
    _rebuild();
    notifyListeners();
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
}
