/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabit.kt,
/// together with the card ordering and the visibility decisions of
/// `ShowHabitView.setState`
/// (uhabits-android/.../activities/habits/show/ShowHabitView.kt) and
/// show_habit.xml.
///
/// `ShowHabitState` carries one slice per card and `ShowHabitPresenter` owns
/// the three sub-presenters the interactive cards need
/// (`HistoryCardPresenter`, `BarCardPresenter`, `ScoreCardPresenter`) plus the
/// [ShowHabitPresenterScreen] interface that unions their callbacks.
library;

import '../../../../commands/command_runner.dart';
import '../../../../models/habit.dart';
import '../../../../models/habit_list.dart';
import '../../../../models/palette_color.dart';
import '../../../../gui/theme.dart';
import '../../../../preferences/preferences.dart';
import 'views/bar_card.dart';
import 'views/frequency_card.dart';
import 'views/history_card.dart';
import 'views/notes_card.dart';
import 'views/overview_card.dart';
import 'views/score_card.dart';
import 'views/streak_card.dart';
import 'views/subtitle_card.dart';
import 'views/target_card.dart';

/// Kotlin: `data class ShowHabitState`. The three scalar defaults are the
/// Kotlin ones; in practice `buildState` overrides all three from the habit.
class ShowHabitState {
  const ShowHabitState({
    this.title = '',
    this.isNumerical = false,
    this.color = const PaletteColor(1),
    required this.subtitle,
    required this.overview,
    required this.notes,
    required this.target,
    required this.streaks,
    required this.scores,
    required this.frequency,
    required this.history,
    required this.bar,
    required this.theme,
  });

  final String title;

  final bool isNumerical;

  final PaletteColor color;

  final SubtitleCardState subtitle;

  final OverviewCardState overview;

  final NotesCardState notes;

  final TargetCardState target;

  final StreakCardState streaks;

  final ScoreCardState scores;

  final FrequencyCardState frequency;

  final HistoryCardState history;

  final BarCardState bar;

  final Theme theme;

  @override
  String toString() => 'ShowHabitState(title=$title, '
      'isNumerical=$isNumerical, color=$color, subtitle=$subtitle, '
      'overview=$overview, notes=$notes, target=$target, streaks=$streaks, '
      'scores=$scores, frequency=$frequency, history=$history, bar=$bar, '
      'theme=$theme)';
}

/// Port of the nested Kotlin interface `ShowHabitPresenter.Screen`, which is
/// declared as the union of the three interactive cards' own `Screen`
/// interfaces and adds nothing of its own. Dart has no nested types, so the
/// name is flattened the way `ListHabitsBehavior.Screen` became
/// `ListHabitsBehaviorScreen`.
abstract interface class ShowHabitPresenterScreen
    implements BarCardScreen, ScoreCardScreen, HistoryCardScreen {}

/// Kotlin: `class ShowHabitPresenter(...)`.
///
/// The instance half holds the habit, the habit list, the preferences, the
/// screen and the command runner only so that it can build the three chart
/// sub-presenters; every one of them is constructed eagerly in the Kotlin
/// property initialisers, so they are `final` fields here.
class ShowHabitPresenter {
  ShowHabitPresenter({
    required this.habit,
    required this.habitList,
    required this.preferences,
    required this.screen,
    required this.commandRunner,
  })  : historyCardPresenter = HistoryCardPresenter(
          commandRunner: commandRunner,
          habit: habit,
          habitList: habitList,
          preferences: preferences,
          screen: screen,
        ),
        barCardPresenter = BarCardPresenter(
          preferences: preferences,
          screen: screen,
        ),
        scoreCardPresenter = ScoreCardPresenter(
          preferences: preferences,
          screen: screen,
        );

  final Habit habit;

  final HabitList habitList;

  final Preferences preferences;

  final ShowHabitPresenterScreen screen;

  final CommandRunner commandRunner;

  /// The chart's `OnDateClickedListener`, shared by the History card and by
  /// the history editor dialog the card opens.
  final HistoryCardPresenter historyCardPresenter;

  final BarCardPresenter barCardPresenter;

  final ScoreCardPresenter scoreCardPresenter;

  /// `ShowHabitPresenter.buildState(habit, preferences, theme)`. The whole
  /// state is rebuilt from scratch: there is no incremental refresh anywhere
  /// on this screen.
  static ShowHabitState buildState({
    required Habit habit,
    required Preferences preferences,
    required Theme theme,
  }) {
    return ShowHabitState(
      title: habit.name,
      color: habit.color,
      isNumerical: habit.isNumerical,
      theme: theme,
      subtitle: SubtitleCardPresenter.buildState(
        habit: habit,
        theme: theme,
      ),
      overview: OverviewCardPresenter.buildState(
        habit: habit,
        theme: theme,
      ),
      notes: NotesCardPresenter.buildState(
        habit: habit,
      ),
      target: TargetCardPresenter.buildState(
        habit: habit,
        firstWeekday: preferences.firstWeekdayInt,
        theme: theme,
      ),
      streaks: StreakCartPresenter.buildState(habit, theme),
      scores: ScoreCardPresenter.buildState(
        spinnerPosition: preferences.scoreCardSpinnerPosition,
        habit: habit,
        firstWeekday: preferences.firstWeekdayInt,
        theme: theme,
      ),
      frequency: FrequencyCardPresenter.buildState(
        habit: habit,
        firstWeekday: preferences.firstWeekday,
        theme: theme,
      ),
      history: HistoryCardPresenter.buildState(
        habit: habit,
        firstWeekday: preferences.firstWeekday,
        theme: theme,
      ),
      bar: BarCardPresenter.buildState(
        habit: habit,
        firstWeekday: preferences.firstWeekdayInt,
        boolSpinnerPosition: preferences.barCardBoolSpinnerPosition,
        numericalSpinnerPosition: preferences.barCardNumericalSpinnerPosition,
        theme: theme,
      ),
    );
  }
}

/// The nine cards of show_habit.xml, in their top-to-bottom layout order.
///
/// The five that have no state object in this package yet are still listed:
/// the order is the contract the Flutter screen builds its column from.
enum ShowHabitCard {
  subtitle,
  notes,
  overview,
  target,
  score,
  bar,
  history,
  streak,
  frequency,
}

/// The visibility half of `ShowHabitView.setState`, and of
/// `NotesCardView.setState`.
///
/// Two upstream quirks are reproduced here rather than fixed:
///
///  * `ShowHabitView` only ever assigns GONE. It never assigns VISIBLE back,
///    so once a habit type has hidden the overview or the target card, that
///    card stays hidden for the life of the screen — visible if the habit is
///    later edited into the other type, or if the very same view instance is
///    handed a different habit's state;
///  * the notes card is hidden by `NotesCardView` itself, which *does* toggle
///    both ways, so its visibility tracks the description on every refresh.
class ShowHabitCardVisibility {
  final Set<ShowHabitCard> _gone = <ShowHabitCard>{};

  bool isVisible(ShowHabitCard card) => !_gone.contains(card);

  void setState(ShowHabitState state) {
    // NotesCardView.setState: GONE when empty, VISIBLE otherwise.
    if (state.notes.isVisible) {
      _gone.remove(ShowHabitCard.notes);
    } else {
      _gone.add(ShowHabitCard.notes);
    }

    // ShowHabitView.setState: one of the two is hidden, and neither is ever
    // shown again.
    if (state.isNumerical) {
      _gone.add(ShowHabitCard.overview);
    } else {
      _gone.add(ShowHabitCard.target);
    }
  }
}
