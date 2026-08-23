/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/ListHabitsSelectionMenu.kt
/// and `res/menu/list_habits_selection.xml`.
///
/// Upstream this is an `ActionMode.Callback`: the contextual action bar that
/// replaces the toolbar while at least one row is selected. Flutter has no
/// action mode, so the bar is an ordinary [AppBar] the screen swaps in — the
/// three signals `onSelectionStart` / `onSelectionChange` /
/// `onSelectionFinish` become "the selection is non-empty", "rebuild", and
/// "swap the toolbar back".
///
/// Everything the items do is [core.ListHabitsSelectionMenuBehavior]'s, which
/// is already ported and tested; the only action that lives here is the
/// developer-only `action_notify`, which upstream does not route through the
/// behavior either.
library;

// The core package does not re-export lib/src/ui/screens or lib/src/preferences.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_selection_menu_behavior.dart'
    as core;

import '../../../l10n/app_localizations.dart';
import '../../../state/habit_list_model.dart';

/// The `android:id` of every item in `res/menu/list_habits_selection.xml`, in
/// declaration order (`list-habits.selection-menu-actions#1`).
class ListHabitsSelectionMenuItems {
  ListHabitsSelectionMenuItems._();

  static const String edit = 'action_edit_habit';
  static const String color = 'action_color';
  static const String archive = 'action_archive_habit';
  static const String unarchive = 'action_unarchive_habit';
  static const String delete = 'action_delete';
  static const String notify = 'action_notify';

  /// The six items, in the order the menu resource declares them.
  static const List<String> all = <String>[
    edit,
    color,
    archive,
    unarchive,
    delete,
    notify,
  ];

  static Key keyOf(String id) => ValueKey<String>('listHabitsSelection.$id');
}

/// The contextual action bar.
class ListHabitsSelectionMenu extends StatelessWidget
    implements PreferredSizeWidget {
  const ListHabitsSelectionMenu({
    required this.model,
    required this.backgroundColor,
    super.key,
  });

  final HabitListModel model;

  final Color backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  core.ListHabitsSelectionMenuBehavior get _behavior => model.selectionMenu;

  core.Preferences get _preferences => model.scope.preferences;

  /// `onPrepareActionMode`, which runs on every `invalidate()`
  /// (`list-habits.selection-menu-actions#2`).
  bool isVisible(String id) {
    switch (id) {
      case ListHabitsSelectionMenuItems.color:
        return true;
      case ListHabitsSelectionMenuItems.edit:
        return _behavior.canEdit();
      case ListHabitsSelectionMenuItems.archive:
        return _behavior.canArchive();
      case ListHabitsSelectionMenuItems.unarchive:
        return _behavior.canUnarchive();
      case ListHabitsSelectionMenuItems.notify:
        return _preferences.isDeveloper;
      default:
        // `action_delete` has no visibility rule at all.
        return true;
    }
  }

  /// `onActionItemClicked`. Returns false for an id the `when` does not name.
  bool onItemSelected(String id) {
    switch (id) {
      case ListHabitsSelectionMenuItems.edit:
        _behavior.onEditHabits();
        return true;
      case ListHabitsSelectionMenuItems.archive:
        _behavior.onArchiveHabits();
        return true;
      case ListHabitsSelectionMenuItems.unarchive:
        _behavior.onUnarchiveHabits();
        return true;
      case ListHabitsSelectionMenuItems.delete:
        _behavior.onDeleteHabits();
        return true;
      case ListHabitsSelectionMenuItems.color:
        _behavior.onChangeColor();
        return true;
      case ListHabitsSelectionMenuItems.notify:
        // `for (h in listAdapter.selected) notificationTray.show(h,
        // getToday(), 0)` — no behavior call, and no clearSelection either
        // (`list-habits.selection-menu-actions#9`).
        model.onNotifyHabits();
        return true;
      default:
        return false;
    }
  }

  String titleOf(String id, L10n l10n) {
    switch (id) {
      case ListHabitsSelectionMenuItems.edit:
        return l10n.edit;
      case ListHabitsSelectionMenuItems.color:
        return l10n.colorPickerDefaultTitle;
      case ListHabitsSelectionMenuItems.archive:
        return l10n.archive;
      case ListHabitsSelectionMenuItems.unarchive:
        return l10n.unarchive;
      case ListHabitsSelectionMenuItems.delete:
        return l10n.delete;
      case ListHabitsSelectionMenuItems.notify:
        return l10n.reminder;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // `activeActionMode?.title = listAdapter.selected.size.toString()`
    // (`list-habits.selection-mode#8`).
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      elevation: 2,
      leading: IconButton(
        key: const ValueKey<String>('listHabitsSelection.close'),
        icon: const Icon(Icons.close),
        // `onDestroyActionMode` -> `listController.onSelectionFinished()`.
        onPressed: model.listController.onSelectionFinished,
      ),
      title: Text('${model.selected.length}'),
      actions: <Widget>[
        // The two items with an icon are shown on the bar itself.
        if (isVisible(ListHabitsSelectionMenuItems.edit))
          IconButton(
            key: ListHabitsSelectionMenuItems.keyOf(
                ListHabitsSelectionMenuItems.edit),
            icon: const Icon(Icons.edit),
            tooltip: l10n.edit,
            onPressed: () => onItemSelected(ListHabitsSelectionMenuItems.edit),
          ),
        if (isVisible(ListHabitsSelectionMenuItems.color))
          IconButton(
            key: ListHabitsSelectionMenuItems.keyOf(
                ListHabitsSelectionMenuItems.color),
            icon: const Icon(Icons.palette_outlined),
            tooltip: l10n.colorPickerDefaultTitle,
            onPressed: () => onItemSelected(ListHabitsSelectionMenuItems.color),
          ),
        // …and the four `showAsAction="never"` ones go to the overflow.
        MenuAnchor(
          menuChildren: <Widget>[
            for (final id in <String>[
              ListHabitsSelectionMenuItems.archive,
              ListHabitsSelectionMenuItems.unarchive,
              ListHabitsSelectionMenuItems.delete,
              ListHabitsSelectionMenuItems.notify,
            ])
              if (isVisible(id))
                MenuItemButton(
                  key: ListHabitsSelectionMenuItems.keyOf(id),
                  onPressed: () => onItemSelected(id),
                  child: Text(titleOf(id, l10n)),
                ),
          ],
          builder: (context, controller, child) => IconButton(
            key: const ValueKey<String>('listHabitsSelection.overflowMenu'),
            icon: const Icon(Icons.more_vert),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
      ],
    );
  }
}
