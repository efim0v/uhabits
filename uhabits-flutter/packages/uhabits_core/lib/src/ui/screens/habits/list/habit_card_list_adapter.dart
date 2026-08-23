/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/HabitCardListAdapter.kt
///
/// The Kotlin class is a `RecyclerView.Adapter<HabitCardViewHolder?>`, but
/// almost nothing in it is about Android: it owns the selection, it wires the
/// [HabitCardListCache] to the [Preferences] and the [MidnightTimer], and it is
/// the `Adapter` that both `ListHabitsMenuBehavior` and
/// `ListHabitsSelectionMenuBehavior` talk to. That part is what lives here.
///
/// What was left behind, because it has no meaning outside Android:
///
///  * `RecyclerView.Adapter` itself, `onCreateViewHolder`,
///    `onViewAttachedToWindow` / `onViewDetachedFromWindow` and the
///    `HabitCardViewHolder` they pass around;
///  * the `notifyItem*` / `notifyDataSetChanged` calls, which are replaced by
///    the [HabitCardListAdapterListener] the widget layer implements — modelled
///    on [HabitCardListCacheListener], which reports the same four events;
///  * `setListView(HabitCardListView?)`, which becomes [setListener]: the
///    presence of a listener is what "a view is attached" means here, and it is
///    what gates [bindCardView] the way `listView == null` gates
///    `onBindViewHolder` upstream.
library;

import '../../../../models/habit.dart';
import '../../../../models/habit_list.dart';
import '../../../../models/habit_matcher.dart';
import '../../../../models/model_observable.dart';
import '../../../../preferences/preferences.dart';
import '../../../../utils/midnight_timer.dart';
import 'habit_card_list_cache.dart';
import 'list_habits_menu_behavior.dart';
import 'list_habits_selection_menu_behavior.dart';

/// Port of `MAX_CHECKMARK_COUNT` from
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsRootView.kt.
///
/// It lives in a view file upstream, but the only reason the adapter exists is
/// to hand this number to the cache, so it is declared next to its one core
/// use. The root view also uses it to clamp the number of drawn columns; that
/// belongs to the widget layer.
const int maxCheckmarkCount = 60;

/// The change notifications the Android adapter sends to its `RecyclerView`.
///
/// The four positional callbacks mirror [HabitCardListCacheListener] one for
/// one — `notifyItemChanged`, `notifyItemInserted`, `notifyItemMoved`,
/// `notifyItemRemoved` — and [onDataSetChanged] stands for
/// `notifyDataSetChanged`, which the adapter sends on every selection change.
///
/// Note that `onRefreshFinished` has no counterpart here: upstream forwards it
/// to the [ModelObservable] only, never to the `RecyclerView`.
abstract interface class HabitCardListAdapterListener {
  void onItemChanged(int position);

  void onItemInserted(int position);

  void onItemMoved(int oldPosition, int newPosition);

  void onItemRemoved(int position);

  void onDataSetChanged();
}

/// Everything `onBindViewHolder` reads out of the cache for one row.
///
/// Kotlin pushes these five values into the view —
/// `listView.bindCardView(holder, habit, score, checkmarks, notes, selected)` —
/// because a `RecyclerView` binds by mutating a recycled holder. A Flutter list
/// pulls instead, so [HabitCardListAdapter.bindCardView] returns them.
///
/// [checkmarks] and [notes] are the cache's own arrays, handed over without
/// copying, exactly as upstream does.
class HabitCardData {
  const HabitCardData({
    required this.habit,
    required this.score,
    required this.checkmarks,
    required this.notes,
    required this.selected,
  });

  final Habit habit;

  final double score;

  final List<int> checkmarks;

  final List<String> notes;

  /// `selected.contains(habit)`.
  final bool selected;
}

/// Provides the data that backs the habit card list.
///
/// The data is fetched and cached by a [HabitCardListCache]. This adapter also
/// holds the list of habits that have been selected.
class HabitCardListAdapter extends HabitCardListCacheListener
    implements
        MidnightListener,
        ListHabitsMenuBehaviorAdapter,
        ListHabitsSelectionMenuBehaviorAdapter {
  /// Kotlin's `init` block, which runs after the field initialisers.
  ///
  /// The order is load-bearing: the listener is installed first, so the
  /// refreshes triggered by the two order assignments are already observed,
  /// and the *secondary* order is assigned before the primary one.
  HabitCardListAdapter(this._cache, this._preferences, this._midnightTimer) {
    _cache.setListener(this);
    _cache.setCheckmarkCount(maxCheckmarkCount);
    _cache.secondaryOrder = _preferences.defaultSecondaryOrder;
    _cache.primaryOrder = _preferences.defaultPrimaryOrder;
    setHasStableIds(true);
  }

  final HabitCardListCache _cache;

  final Preferences _preferences;

  final MidnightTimer _midnightTimer;

  final ModelObservable observable = ModelObservable();

  /// Kotlin's `LinkedList<Habit>`: insertion ordered, and the identity of the
  /// list matters — [getSelected] copies it, [selected] does not.
  final List<Habit> selected = <Habit>[];

  /// `private var listView: HabitCardListView? = null`.
  HabitCardListAdapterListener? _listener;

  bool _hasStableIds = false;

  @override
  void atMidnight() {
    _cache.refreshAllHabits();
  }

  void cancelRefresh() {
    _cache.cancelTasks();
  }

  bool hasNoHabit() {
    return _cache.hasNoHabit();
  }

  /// Sets all items as not selected.
  @override
  void clearSelection() {
    if (selected.isEmpty) return;

    selected.clear();
    _notifyDataSetChanged();
    observable.notifyListeners();
  }

  /// `ArrayList(selected)`: a snapshot, so a caller that mutates the result
  /// does not touch the selection.
  @override
  List<Habit> getSelected() {
    return List<Habit>.of(selected);
  }

  /// Returns the item that occupies a certain position on the list, or null if
  /// the position is invalid.
  ///
  /// Kotlin marks this `@Deprecated("")` without a replacement; it is still the
  /// only way the controller resolves a tapped row.
  Habit? getItem(int position) {
    return _cache.getHabitByPosition(position);
  }

  /// `getItemCount()`.
  int get itemCount => _cache.habitCount;

  /// `getItemId(position)`. Kotlin is `getItem(position)!!.id!!`, so both an
  /// out-of-range position and a habit without an id throw.
  int getItemId(int position) {
    return getItem(position)!.id!;
  }

  /// `setHasStableIds(true)` is called from the constructor and never again.
  bool get hasStableIds => _hasStableIds;

  void setHasStableIds(bool value) {
    _hasStableIds = value;
  }

  /// Returns whether the list of selected items is empty.
  bool get isSelectionEmpty => selected.isEmpty;

  /// Manual drag reordering only makes sense while the list is in its manual
  /// order.
  bool get isSortable => _cache.primaryOrder == HabitListOrder.byPosition;

  /// Notify the adapter that it has been attached to a list view.
  void onAttached() {
    _cache.onAttached();
    _midnightTimer.addListener(this);
  }

  /// Port of `onBindViewHolder`.
  ///
  /// Returns null while no view is attached, which is upstream's
  /// `if (listView == null) return`. Otherwise every lookup is unguarded: an
  /// invalid position or a habit missing from the cache maps throw, as the
  /// `!!` chain does in Kotlin.
  HabitCardData? bindCardView(int position) {
    if (_listener == null) return null;
    final habit = _cache.getHabitByPosition(position)!;
    final score = _cache.getScore(habit.id!);
    final checkmarks = _cache.getCheckmarks(habit.id!);
    final notes = _cache.getNotes(habit.id!);
    final isSelected = selected.contains(habit);
    return HabitCardData(
      habit: habit,
      score: score,
      checkmarks: checkmarks,
      notes: notes,
      selected: isSelected,
    );
  }

  /// Notify the adapter that it has been detached from a list view.
  void onDetached() {
    _cache.onDetached();
    _midnightTimer.removeListener(this);
  }

  @override
  void onItemChanged(int position) {
    _listener?.onItemChanged(position);
    observable.notifyListeners();
  }

  @override
  void onItemInserted(int position) {
    _listener?.onItemInserted(position);
    observable.notifyListeners();
  }

  @override
  void onItemMoved(int oldPosition, int newPosition) {
    _listener?.onItemMoved(oldPosition, newPosition);
    observable.notifyListeners();
  }

  @override
  void onItemRemoved(int position) {
    _listener?.onItemRemoved(position);
    observable.notifyListeners();
  }

  /// The one cache callback with no view notification attached to it upstream.
  @override
  void onRefreshFinished() {
    observable.notifyListeners();
  }

  /// Removes a list of habits from the adapter.
  ///
  /// Note that this only has effect on the adapter cache. The database is not
  /// modified, and the change is lost when the cache is refreshed. This method
  /// is useful for making the list more responsive: while we wait for the
  /// database operation to finish, the cache can be modified to reflect the
  /// changes immediately.
  @override
  void performRemove(List<Habit> selected) {
    for (final habit in selected) {
      _cache.remove(habit.id!);
    }
  }

  /// Changes the order of habits on the adapter.
  ///
  /// Cache only, exactly like [performRemove].
  void performReorder(int from, int to) {
    _cache.reorder(from, to);
  }

  @override
  void refresh() {
    _cache.refreshAllHabits();
  }

  @override
  void setFilter(HabitMatcher matcher) {
    _cache.setFilter(matcher);
  }

  /// Port of `setListView`. Passing null detaches, which stops [bindCardView]
  /// from returning anything.
  void setListener(HabitCardListAdapterListener? listener) {
    _listener = listener;
  }

  @override
  HabitListOrder get primaryOrder => _cache.primaryOrder;

  @override
  set primaryOrder(HabitListOrder value) {
    _cache.primaryOrder = value;
    _preferences.defaultPrimaryOrder = value;
  }

  @override
  HabitListOrder get secondaryOrder => _cache.secondaryOrder;

  @override
  set secondaryOrder(HabitListOrder value) {
    _cache.secondaryOrder = value;
    _preferences.defaultSecondaryOrder = value;
  }

  /// Selects or deselects the item at a given position.
  ///
  /// Kotlin looks the habit up with `indexOf` and then removes it by value, so
  /// the selection is a plain toggle. A position with no habit behind it is
  /// ignored entirely — not even the data-set notification is sent.
  void toggleSelection(int position) {
    final h = getItem(position);
    if (h == null) return;
    final k = selected.indexOf(h);
    if (k < 0) {
      selected.add(h);
    } else {
      selected.remove(h);
    }
    _notifyDataSetChanged();
  }

  /// `notifyDataSetChanged()`.
  void _notifyDataSetChanged() {
    _listener?.onDataSetChanged();
  }
}
