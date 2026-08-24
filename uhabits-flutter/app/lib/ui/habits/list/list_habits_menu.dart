/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsMenu.kt
/// and of the layout it inflates, `res/menu/list_habits.xml`.
///
/// The Kotlin class owns three things and nothing else: the inflated `Menu`,
/// the `isSearchActive` flag, and the dispatch table that turns a menu id into
/// a call on [core.ListHabitsMenuBehavior]. All of that lives here; the
/// presenter itself is the already-ported core class, reached through
/// [HabitListModel.menu].
///
/// The Android menu resource declares two action items shown as icons
/// (`Add habit` and `Filter`) and four overflow items, all inside the group
/// `actionItems`, plus a `SearchView` action-view container that is visible
/// only while the search bar is open. A Flutter `AppBar` has the same two
/// slots — `actions` for the icons and a `MenuAnchor` for the overflow — so
/// the structure survives one-to-one.
library;

// The core package does not re-export lib/src/ui/screens or lib/src/preferences.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_menu_behavior.dart'
    as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/habit_list_model.dart';

/// The `android:id` of every item in `res/menu/list_habits.xml`.
///
/// Kept as strings rather than an enum because
/// `list-habits.menu.overflow-items#9` is about what happens to an id the
/// `when` does not name, and an enum cannot express one.
class ListHabitsMenuItems {
  ListHabitsMenuItems._();

  static const String searchContainer = 'actionSearchContainer';
  static const String createHabit = 'actionCreateHabit';
  static const String filter = 'actionFilter';
  static const String toggleNightMode = 'actionToggleNightMode';
  static const String settings = 'actionSettings';
  static const String faq = 'actionFAQ';
  static const String about = 'actionAbout';
  static const String hideArchived = 'actionHideArchived';
  static const String hideCompleted = 'actionHideCompleted';
  static const String sort = 'actionSort';
  static const String sortManual = 'actionSortManual';
  static const String sortName = 'actionSortName';
  static const String sortColor = 'actionSortColor';
  static const String sortScore = 'actionSortScore';
  static const String sortStatus = 'actionSortStatus';
  static const String search = 'actionSearch';

  /// The `actionItems` group, hidden as a whole while the search bar is open.
  static const String actionItemsGroup = 'actionItems';

  static Key keyOf(String id) => ValueKey<String>('listHabitsMenu.$id');
}

/// The main screen's toolbar.
class ListHabitsMenu extends StatefulWidget implements PreferredSizeWidget {
  const ListHabitsMenu({
    required this.model,
    required this.title,
    required this.backgroundColor,
    super.key,
  });

  final HabitListModel model;

  /// `R.string.main_activity_title`.
  final String title;

  final Color backgroundColor;

  /// `toolbar.elevation = dp(2f)`.
  static const double elevation = 2.0;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ListHabitsMenuState createState() => ListHabitsMenuState();
}

class ListHabitsMenuState extends State<ListHabitsMenu> {
  /// `private var isSearchActive = false`.
  ///
  /// Kept on the activity-scoped [HabitListModel] rather than in this `State`:
  /// upstream `ListHabitsMenu` is `@ActivityScope` and the contextual action
  /// bar only *overlays* its options menu, so the search bar outlives a
  /// selection. Here the screen swaps this whole widget out while a selection
  /// is active, which would otherwise reset the flag and leave the list
  /// filtered by an invisible query
  /// (`audit9.search-bar-survives-selection-mode#1`).
  bool get isSearchActive => widget.model.isSearchActive;

  set isSearchActive(bool value) => widget.model.isSearchActive = value;

  /// The `SearchView`'s own text. `setQuery(behavior.searchQuery, false)` is
  /// what keeps it in step with the presenter across a menu invalidation
  /// (`list-habits.search#10`).
  late final TextEditingController _searchController =
      TextEditingController(text: widget.model.menu.searchQuery);

  /// `mSearchSrcTextView`'s focus, which [onCloseClicked] re-requests after it
  /// empties the field (`audit7.the-search-bar-s-x-button#1`).
  final FocusNode _searchFocusNode = FocusNode();

  /// `activity.invalidateOptionsMenu()`.
  void invalidateOptionsMenu() {
    if (mounted) setState(() {});
  }

  core.ListHabitsMenuBehavior get _behavior => widget.model.menu;

  core.Preferences get _preferences => widget.model.scope.preferences;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// `ListHabitsMenu.onItemSelected(item)`.
  ///
  /// Returns false for an id the `when` does not name
  /// (`list-habits.menu.overflow-items#9`).
  bool onItemSelected(String id) {
    switch (id) {
      case ListHabitsMenuItems.toggleNightMode:
        _behavior.onToggleNightMode();
        return true;
      case ListHabitsMenuItems.createHabit:
        _behavior.onCreateHabit();
        return true;
      case ListHabitsMenuItems.faq:
        _behavior.onViewFAQ();
        return true;
      case ListHabitsMenuItems.about:
        _behavior.onViewAbout();
        return true;
      case ListHabitsMenuItems.settings:
        _behavior.onViewSettings();
        return true;
      case ListHabitsMenuItems.hideArchived:
        _behavior.onToggleShowArchived();
        invalidateOptionsMenu();
        return true;
      case ListHabitsMenuItems.hideCompleted:
        _behavior.onToggleShowCompleted();
        invalidateOptionsMenu();
        return true;
      case ListHabitsMenuItems.sortColor:
        _behavior.onSortByColor();
        return true;
      case ListHabitsMenuItems.sortManual:
        _behavior.onSortByManually();
        return true;
      case ListHabitsMenuItems.sortName:
        _behavior.onSortByName();
        return true;
      case ListHabitsMenuItems.sortScore:
        _behavior.onSortByScore();
        return true;
      case ListHabitsMenuItems.sortStatus:
        _behavior.onSortByStatus();
        return true;
      case ListHabitsMenuItems.search:
        isSearchActive = true;
        invalidateOptionsMenu();
        return true;
      default:
        return false;
    }
  }

  /// `ListHabitsActivity.onOptionsItemSelected`: invalidate first, then
  /// dispatch (`list-habits.menu.overflow-items#9`).
  bool _select(String id) {
    invalidateOptionsMenu();
    return onItemSelected(id);
  }

  /// `SearchView.setOnQueryTextListener { onQueryTextChange }`.
  bool onQueryTextChange(String newText) {
    _behavior.onSearchQueryChanged(newText);
    return true;
  }

  /// `onQueryTextSubmit` — ignored (`list-habits.search#11`).
  bool onQueryTextSubmit(String query) => false;

  /// `SearchView.setOnCloseListener`.
  ///
  /// It puts the action items back and invalidates the menu, but never touches
  /// `behavior.searchQuery` (`list-habits.search#12`).
  ///
  /// This is the *listener*, not the X button's handler: it is reached only
  /// through [onCloseClicked], and only once the field is already empty.
  bool onSearchClosed() {
    isSearchActive = false;
    invalidateOptionsMenu();
    return true;
  }

  /// `androidx.appcompat.widget.SearchView.onCloseClicked()`, which is what the
  /// X button actually runs.
  ///
  /// ```java
  /// void onCloseClicked() {
  ///     CharSequence text = mSearchSrcTextView.getText();
  ///     if (TextUtils.isEmpty(text)) {
  ///         if (mIconifiedByDefault) {
  ///             if (mOnCloseListener == null || !mOnCloseListener.onClose()) {
  ///                 clearFocus();
  ///                 updateViewsVisibility(true);
  ///             }
  ///         }
  ///     } else {
  ///         mSearchSrcTextView.setText("");
  ///         mSearchSrcTextView.requestFocus();
  ///         setImeVisibility(true);
  ///     }
  /// }
  /// ```
  ///
  /// It is a two-stage control, not a close button
  /// (`audit7.the-search-bar-s-x-button#1`). While the query is non-empty the
  /// close listener is NOT called: the field is emptied, re-focused and left
  /// open, and emptying it fires the TextWatcher, so `onQueryTextChange("")`
  /// rebuilds the matcher with an empty query and the full list comes back.
  /// Only a second tap, on an already-empty field, reaches [onSearchClosed].
  /// The search bar can therefore never be closed while a query is still in
  /// force, which is the property that keeps the list from being left silently
  /// filtered.
  ///
  /// The listener's `true` is what suppresses the `clearFocus()` /
  /// `updateViewsVisibility(true)` fallback, so there is nothing after it.
  void onCloseClicked() {
    if (_searchController.text.isNotEmpty) {
      // `mSearchSrcTextView.setText("")`. Assigning to a Dart controller does
      // not fire `TextField.onChanged` the way Android's TextWatcher fires, so
      // the query change is carried to the presenter explicitly.
      _searchController.clear();
      onQueryTextChange('');
      // `requestFocus()` + `setImeVisibility(true)`: the field stays open with
      // the keyboard up.
      _searchFocusNode.requestFocus();
      return;
    }
    onSearchClosed();
  }

  /// `createMenuItems`: the hide-completed item is relabelled once either of
  /// the two extra entry values is in play
  /// (`list-habits.menu.overflow-items#5`).
  String hideCompletedTitle(L10n l10n) =>
      _preferences.areQuestionMarksEnabled || _preferences.isSkipEnabled
          ? l10n.hideEntered
          : l10n.hideCompleted;

  /// `createMenuItems`: `isChecked = !preferences.showArchived`
  /// (`list-habits.menu.overflow-items#4`).
  bool get isHideArchivedChecked => !_preferences.showArchived;

  bool get isHideCompletedChecked => !_preferences.showCompleted;

  /// `nightModeItem.isChecked = themeSwitcher.isNightMode`.
  bool get isNightModeChecked => widget.model.isNightMode;

  /// `updateArrows(menu)`: the icon each sort entry carries, or null.
  ///
  /// `*_ASC` orders take the down arrow, `*_DESC` the up arrow, and
  /// `BY_POSITION` puts the up arrow on 'Manually'. Everything else is bare
  /// (`list-habits.sort-modes#11`).
  IconData? sortArrowFor(String id) {
    final order = _preferences.defaultPrimaryOrder;
    switch (order) {
      case core.HabitListOrder.byNameAsc:
        return id == ListHabitsMenuItems.sortName ? _arrowDown : null;
      case core.HabitListOrder.byNameDesc:
        return id == ListHabitsMenuItems.sortName ? _arrowUp : null;
      case core.HabitListOrder.byColorAsc:
        return id == ListHabitsMenuItems.sortColor ? _arrowDown : null;
      case core.HabitListOrder.byColorDesc:
        return id == ListHabitsMenuItems.sortColor ? _arrowUp : null;
      case core.HabitListOrder.byScoreAsc:
        return id == ListHabitsMenuItems.sortScore ? _arrowDown : null;
      case core.HabitListOrder.byScoreDesc:
        return id == ListHabitsMenuItems.sortScore ? _arrowUp : null;
      case core.HabitListOrder.byStatusAsc:
        return id == ListHabitsMenuItems.sortStatus ? _arrowDown : null;
      case core.HabitListOrder.byStatusDesc:
        return id == ListHabitsMenuItems.sortStatus ? _arrowUp : null;
      case core.HabitListOrder.byPosition:
        return id == ListHabitsMenuItems.sortManual ? _arrowUp : null;
    }
  }

  /// `?attr/iconArrowUp` / `?attr/iconArrowDown`.
  static const IconData _arrowUp = Icons.arrow_upward;
  static const IconData _arrowDown = Icons.arrow_downward;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // `createSearchBar`: the container and the action items are mutually
    // exclusive (`list-habits.search#9`). Both live in the title slot so that
    // the row can be measured against the toolbar's own width.
    return AppBar(
      title: isSearchActive ? _buildSearchView(l10n) : _buildToolbar(l10n),
      backgroundColor: widget.backgroundColor,
      foregroundColor: Colors.white,
      elevation: ListHabitsMenu.elevation,
    );
  }

  /// The width one action icon takes on the bar, `?attr/actionBarSize` in
  /// miniature: the `minWidth` of a `IconButton`'s tap target.
  static const double _iconWidth = 48.0;

  /// The title and the `actionItems` group side by side.
  ///
  /// `showAsAction="always"` still yields to a toolbar with no room — but what
  /// the ActionBar does then is *move* the item into the overflow menu, not
  /// remove it (`audit5.toolbar-action-items-are-dropped-rather#1`). So the
  /// width test below decides where each of the two always-items is drawn, and
  /// never whether it exists: 'Create habit', 'Hide archived', 'Hide
  /// completed', 'Sort' and 'Search' are reachable at any toolbar width.
  Widget _buildToolbar(L10n l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final items = _buildActionItems(
          l10n,
          // Room for the icon itself plus everything to its right: the filter
          // icon and the overflow button.
          showCreate: available >= 3 * _iconWidth,
          showFilter: available >= 2 * _iconWidth,
        );
        return Row(
          children: <Widget>[
            Expanded(
              child: Text(widget.title, overflow: TextOverflow.ellipsis),
            ),
            ...items,
          ],
        );
      },
    );
  }

  /// The `SearchView` behind `actionSearchContainer`.
  Widget _buildSearchView(L10n l10n) {
    // `setQuery(behavior.searchQuery, false)`: the field is repopulated from
    // the presenter every time the menu is re-created, without submitting.
    if (_searchController.text != _behavior.searchQuery) {
      _searchController.text = _behavior.searchQuery;
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            key: ListHabitsMenuItems.keyOf(ListHabitsMenuItems.searchContainer),
            controller: _searchController,
            focusNode: _searchFocusNode,
            // `isIconified = false`: the field is open and focused already.
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: l10n.search,
              hintStyle: const TextStyle(color: Colors.white70),
            ),
            onChanged: onQueryTextChange,
            onSubmitted: onQueryTextSubmit,
          ),
        ),
        IconButton(
          key: const ValueKey<String>('listHabitsMenu.searchClose'),
          icon: const Icon(Icons.close),
          tooltip: l10n.search,
          // `SearchView`'s X runs onCloseClicked(), which only *sometimes*
          // reaches the close listener (`audit7.the-search-bar-s-x-button#1`).
          onPressed: onCloseClicked,
        ),
      ],
    );
  }

  /// The `actionItems` group.
  List<Widget> _buildActionItems(
    L10n l10n, {
    bool showCreate = true,
    bool showFilter = true,
  }) {
    return <Widget>[
      // `<item android:id="@+id/actionCreateHabit" showAsAction="always"/>`
      if (showCreate) IconButton(
        key: ListHabitsMenuItems.keyOf(ListHabitsMenuItems.createHabit),
        icon: const Icon(Icons.add),
        tooltip: l10n.addHabit,
        onPressed: () => _select(ListHabitsMenuItems.createHabit),
      ),
      // `<item android:id="@+id/actionFilter" showAsAction="always">` with a
      // submenu.
      if (showFilter) MenuAnchor(
        menuChildren: _buildFilterMenu(l10n),
        builder: (context, controller, child) => IconButton(
          key: ListHabitsMenuItems.keyOf(ListHabitsMenuItems.filter),
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: l10n.filter,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
      // Everything with `showAsAction="never"`, in orderInCategory order:
      // Dark theme (50), then Settings, Help & FAQ and About (100 each) —
      // preceded by whichever of the two always-items the bar had no room
      // for. An ActionBar moves such an item here rather than dropping it,
      // and it keeps its place in menu order, which puts it above the
      // never-items (`audit5.toolbar-action-items-are-dropped-rather#1`).
      MenuAnchor(
        menuChildren: <Widget>[
          if (!showCreate)
            MenuItemButton(
              key: ListHabitsMenuItems.keyOf(ListHabitsMenuItems.createHabit),
              leadingIcon: const Icon(Icons.add),
              onPressed: () => _select(ListHabitsMenuItems.createHabit),
              child: Text(l10n.addHabit),
            ),
          if (!showFilter)
            SubmenuButton(
              key: ListHabitsMenuItems.keyOf(ListHabitsMenuItems.filter),
              leadingIcon: const Icon(Icons.filter_alt_outlined),
              menuChildren: _buildFilterMenu(l10n),
              child: Text(l10n.filter),
            ),
          _checkableItem(
            id: ListHabitsMenuItems.toggleNightMode,
            label: l10n.nightMode,
            checked: isNightModeChecked,
          ),
          _item(id: ListHabitsMenuItems.settings, label: l10n.actionSettings),
          _item(id: ListHabitsMenuItems.faq, label: l10n.help),
          _item(id: ListHabitsMenuItems.about, label: l10n.about),
        ],
        builder: (context, controller, child) => IconButton(
          key: const ValueKey<String>('listHabits.overflowMenu'),
          icon: const Icon(Icons.more_vert),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    ];
  }

  /// `res/menu/list_habits.xml`, the `actionFilter` submenu
  /// (`list-habits.menu.overflow-items#2`).
  List<Widget> _buildFilterMenu(L10n l10n) => <Widget>[
        _checkableItem(
          id: ListHabitsMenuItems.hideArchived,
          label: l10n.hideArchived,
          checked: isHideArchivedChecked,
        ),
        _checkableItem(
          id: ListHabitsMenuItems.hideCompleted,
          label: hideCompletedTitle(l10n),
          checked: isHideCompletedChecked,
        ),
        SubmenuButton(
          key: ListHabitsMenuItems.keyOf(ListHabitsMenuItems.sort),
          menuChildren: _buildSortMenu(l10n),
          child: Text(l10n.sort),
        ),
        _item(id: ListHabitsMenuItems.search, label: l10n.search),
      ];

  /// The `actionSort` submenu (`list-habits.menu.overflow-items#3`).
  List<Widget> _buildSortMenu(L10n l10n) => <Widget>[
        _sortItem(ListHabitsMenuItems.sortManual, l10n.manually),
        _sortItem(ListHabitsMenuItems.sortName, l10n.byName),
        _sortItem(ListHabitsMenuItems.sortColor, l10n.byColor),
        _sortItem(ListHabitsMenuItems.sortScore, l10n.byScore),
        _sortItem(ListHabitsMenuItems.sortStatus, l10n.byStatus),
      ];

  Widget _item({required String id, required String label}) => MenuItemButton(
        key: ListHabitsMenuItems.keyOf(id),
        onPressed: () => _select(id),
        child: Text(label),
      );

  Widget _checkableItem({
    required String id,
    required String label,
    required bool checked,
  }) =>
      MenuItemButton(
        key: ListHabitsMenuItems.keyOf(id),
        onPressed: () => _select(id),
        leadingIcon: Icon(
          checked ? Icons.check_box : Icons.check_box_outline_blank,
        ),
        child: Text(label),
      );

  Widget _sortItem(String id, String label) {
    final arrow = sortArrowFor(id);
    return MenuItemButton(
      key: ListHabitsMenuItems.keyOf(id),
      onPressed: () => _select(id),
      trailingIcon: arrow == null ? null : Icon(arrow),
      child: Text(label),
    );
  }
}
