/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/ShowHabit.kt,
/// together with the card ordering and the visibility decisions of
/// `ShowHabitView.setState`
/// (uhabits-android/.../activities/habits/show/ShowHabitView.kt) and
/// show_habit.xml.
///
/// Scope note: Kotlin's `ShowHabitState` also carries the streak, score,
/// frequency, history and bar card states, and `ShowHabitPresenter` owns the
/// three sub-presenters those cards need (`HistoryCardPresenter`,
/// `BarCardPresenter`, `ScoreCardPresenter`) plus the `Screen` interface that
/// unions their callbacks. None of those five cards exists in this package
/// yet, so this file carries the four that do — subtitle, notes, overview and
/// target — and the rest join `ShowHabitState` when their slice lands. Nothing
/// here depends on their shape.
library;

import '../../../../models/habit.dart';
import '../../../../models/palette_color.dart';
import '../../../../gui/theme.dart';
import '../../../../preferences/preferences.dart';
import 'views/notes_card.dart';
import 'views/overview_card.dart';
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
    required this.theme,
  });

  final String title;

  final bool isNumerical;

  final PaletteColor color;

  final SubtitleCardState subtitle;

  final OverviewCardState overview;

  final NotesCardState notes;

  final TargetCardState target;

  final Theme theme;

  @override
  String toString() => 'ShowHabitState(title=$title, '
      'isNumerical=$isNumerical, color=$color, subtitle=$subtitle, '
      'overview=$overview, notes=$notes, target=$target, theme=$theme)';
}

/// Kotlin: `class ShowHabitPresenter(...)` — the instance half holds the habit,
/// the habit list, the preferences, the screen and the command runner only so
/// that it can build the three chart sub-presenters, so this port carries just
/// the companion builder until those exist.
class ShowHabitPresenter {
  ShowHabitPresenter._();

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
