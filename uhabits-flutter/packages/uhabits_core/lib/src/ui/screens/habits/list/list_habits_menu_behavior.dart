import '../../../../models/habit_list.dart';
import '../../../../models/habit_matcher.dart';
import '../../../../preferences/preferences.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsMenuBehavior.kt
///
/// The presenter behind the main screen's toolbar menu: the two visibility
/// filters (archived / completed), the free-text search, the five sort entries
/// and the four navigation actions. It owns no widgets — the Android menu
/// (`ListHabitsMenu.kt`) only inflates XML, reads the current preference values
/// to tick its checkboxes, and forwards taps here.
///
/// Everything the class does is a call into one of its three collaborators:
/// [ListHabitsMenuBehaviorAdapter] (the habit-card list), a
/// [ListHabitsMenuBehaviorScreen] (navigation) and a
/// [ListHabitsMenuThemeSwitcher].
///
/// Note that [showArchived] / [showCompleted] are kept as private fields *and*
/// written to [Preferences]: the preference is the persisted copy, the field is
/// what the filter is rebuilt from. They are read from the preferences exactly
/// once, in the constructor.
class ListHabitsMenuBehavior {
  /// Kotlin's `init` block runs after the field initialisers: it seeds both
  /// flags from the preferences and applies the filter immediately, so the
  /// adapter is filtered before the first frame is drawn.
  ListHabitsMenuBehavior(
    this._screen,
    this._adapter,
    this._preferences,
    this._themeSwitcher,
  ) {
    _showCompleted = _preferences.showCompleted;
    _showArchived = _preferences.showArchived;
    _updateAdapterFilter();
  }

  final ListHabitsMenuBehaviorScreen _screen;
  final ListHabitsMenuBehaviorAdapter _adapter;
  final Preferences _preferences;
  final ListHabitsMenuThemeSwitcher _themeSwitcher;

  late bool _showCompleted;
  late bool _showArchived;

  String _searchQuery = '';

  /// Kotlin: `var searchQuery: String = "" private set`.
  ///
  /// Stored verbatim, untrimmed: the trimming happens inside
  /// [HabitMatcher.matches], so the search field can show exactly what the user
  /// typed.
  String get searchQuery => _searchQuery;

  void onCreateHabit() {
    _screen.showSelectHabitTypeDialog();
  }

  void onViewFAQ() {
    _screen.showFAQScreen();
  }

  void onViewAbout() {
    _screen.showAboutScreen();
  }

  void onViewSettings() {
    _screen.showSettingsScreen();
  }

  /// Called on every keystroke of the search field. Unlike the two visibility
  /// flags, the query is *not* persisted — it lives only as long as the screen.
  void onSearchQueryChanged(String query) {
    _searchQuery = query;
    _updateAdapterFilter();
  }

  void onToggleShowArchived() {
    _showArchived = !_showArchived;
    _preferences.showArchived = _showArchived;
    _updateAdapterFilter();
  }

  void onToggleShowCompleted() {
    _showCompleted = !_showCompleted;
    _preferences.showCompleted = _showCompleted;
    _updateAdapterFilter();
  }

  /// Unconditional, and it never touches the secondary order — the only sort
  /// entry that does not toggle.
  void onSortByManually() {
    _adapter.primaryOrder = HabitListOrder.byPosition;
  }

  void onSortByColor() {
    _onSortToggleBy(HabitListOrder.byColorAsc, HabitListOrder.byColorDesc);
  }

  /// Note the inverted pair: the *default* order for the score entry is
  /// `BY_SCORE_DESC`. Combined with the inverted score comparator in
  /// `MemoryHabitList`, the first tap sorts by lowest score first.
  void onSortByScore() {
    _onSortToggleBy(HabitListOrder.byScoreDesc, HabitListOrder.byScoreAsc);
  }

  void onSortByName() {
    _onSortToggleBy(HabitListOrder.byNameAsc, HabitListOrder.byNameDesc);
  }

  void onSortByStatus() {
    _onSortToggleBy(HabitListOrder.byStatusAsc, HabitListOrder.byStatusDesc);
  }

  /// The three-way toggle every sort entry except 'Manually' goes through.
  ///
  /// Arriving from an *unrelated* order pushes that order down into the
  /// secondary slot, so the previous sort becomes the tie-breaker. Flipping
  /// between the two directions of the same entry leaves the secondary order
  /// alone.
  void _onSortToggleBy(
    HabitListOrder defaultOrder,
    HabitListOrder reversedOrder,
  ) {
    if (_adapter.primaryOrder != defaultOrder) {
      if (_adapter.primaryOrder != reversedOrder) {
        _adapter.secondaryOrder = _adapter.primaryOrder;
      }
      _adapter.primaryOrder = defaultOrder;
    } else {
      _adapter.primaryOrder = reversedOrder;
    }
  }

  void onToggleNightMode() {
    _themeSwitcher.toggleNightMode();
    _screen.applyTheme();
  }

  /// Called when a preference the filter depends on changed elsewhere — in
  /// practice `areQuestionMarksEnabled`, from the settings screen.
  void onPreferencesChanged() {
    _updateAdapterFilter();
  }

  /// With question marks enabled the "hide completed" switch becomes a "hide
  /// entered" switch: the flag is routed to a different matcher field, and the
  /// field it used to drive keeps its default `true`.
  void _updateAdapterFilter() {
    if (_preferences.areQuestionMarksEnabled) {
      _adapter.setFilter(
        HabitMatcher(
          isArchivedAllowed: _showArchived,
          isEnteredAllowed: _showCompleted,
          searchQuery: _searchQuery,
        ),
      );
    } else {
      _adapter.setFilter(
        HabitMatcher(
          isArchivedAllowed: _showArchived,
          isCompletedAllowed: _showCompleted,
          searchQuery: _searchQuery,
        ),
      );
    }
    _adapter.refresh();
  }
}

/// Port of the nested Kotlin interface `ListHabitsMenuBehavior.Adapter`. Dart
/// has no nested classes, so the name is flattened.
///
/// Implemented by the habit-card list adapter, which owns the cache; here it is
/// only the two mutations (filter and sort order) plus the refresh trigger.
abstract class ListHabitsMenuBehaviorAdapter {
  void refresh();

  void setFilter(HabitMatcher matcher);

  HabitListOrder get primaryOrder;

  set primaryOrder(HabitListOrder value);

  HabitListOrder get secondaryOrder;

  set secondaryOrder(HabitListOrder value);
}

/// Port of the nested Kotlin interface `ListHabitsMenuBehavior.Screen`.
///
/// Pure navigation callbacks: the widget layer implements them by pushing a
/// route or showing a dialog. Nothing here returns a value, so the presenter
/// never learns what the user chose — the dialog reports back through its own
/// callback instead.
abstract class ListHabitsMenuBehaviorScreen {
  void applyTheme();

  void showAboutScreen();

  void showFAQScreen();

  void showSettingsScreen();

  void showSelectHabitTypeDialog();
}

/// The slice of `uhabits-core/.../ui/ThemeSwitcher.kt` this presenter depends
/// on.
///
/// The full `ThemeSwitcher` (light / dark / pure-black application, the system
/// theme probe, the three-state toggle table) belongs to
/// `settings.theme.theme-modes` and has not been ported yet; declaring the two
/// members used here keeps this file free of that dependency, and the real
/// class can implement this interface when it lands.
abstract class ListHabitsMenuThemeSwitcher {
  /// Read by the menu to tick the "Dark theme" checkbox.
  bool get isNightMode;

  void toggleNightMode();
}
