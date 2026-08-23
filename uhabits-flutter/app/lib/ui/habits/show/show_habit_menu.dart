/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/show/ShowHabitMenu.kt
/// and res/menu/show_habit.xml.
///
/// `ShowHabitMenu` is a two-method class over an inflated `Menu`: it decides
/// which of the six items are visible, and it routes a selected item to the
/// matching `ShowHabitMenuPresenter` call. Neither half knows anything about
/// the screen, so both survive the crossing unchanged; what changes is the
/// menu resource, which becomes the [ShowHabitMenuItem] enum below — the
/// declaration order of show_habit.xml is the enum's order, and each item
/// carries the two attributes the XML gives it.
library;

// The presenter and the preferences are still reached by their `src` path.
// ignore_for_file: implementation_imports

import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/show_habit_menu_presenter.dart';

import '../../../l10n/app_localizations.dart';

/// The six items of res/menu/show_habit.xml, in declaration order
/// (`show-habit.menu#1`).
enum ShowHabitMenuItem {
  /// `@+id/export`.
  export,

  /// `@+id/action_archive_habit`.
  archive,

  /// `@+id/action_unarchive_habit`.
  unarchive,

  /// `@+id/action_delete`.
  delete,

  /// `@+id/action_edit_habit` — the only `showAsAction="ifRoom"` item.
  edit,

  /// `@+id/action_randomize`, declared `android:visible="false"`.
  randomize;

  /// `app:showAsAction="ifRoom"` versus `"never"` (`show-habit.menu#2`).
  ///
  /// Only Edit can be promoted out of the overflow; the other five are
  /// overflow-only whatever the toolbar's width.
  bool get isActionButton => this == ShowHabitMenuItem.edit;

  /// `android:title` (`show-habit.menu#6`), with the one untranslated literal
  /// upstream spells straight into the XML (`show-habit.menu#5`).
  String title(L10n l10n) {
    switch (this) {
      case ShowHabitMenuItem.export:
        return l10n.export;
      case ShowHabitMenuItem.archive:
        return l10n.archive;
      case ShowHabitMenuItem.unarchive:
        return l10n.unarchive;
      case ShowHabitMenuItem.delete:
        return l10n.delete;
      case ShowHabitMenuItem.edit:
        return l10n.edit;
      case ShowHabitMenuItem.randomize:
        return randomizeTitle;
    }
  }

  /// `android:title="Randomize"` — a bare string literal in the menu XML, so
  /// it is never translated (`show-habit.menu#5`).
  static const String randomizeTitle = 'Randomize';
}

/// Port of `class ShowHabitMenu(activity, presenter, preferences)`.
///
/// The `activity` parameter is only ever used for `menuInflater`, which has no
/// counterpart here: [onCreateOptionsMenu] returns the inflated menu instead of
/// mutating one.
class ShowHabitMenu {
  ShowHabitMenu({required this.presenter, required this.preferences});

  final ShowHabitMenuPresenter presenter;

  final Preferences preferences;

  /// `onCreateOptionsMenu(menu)`: inflate all six items, then hide the three
  /// that do not apply.
  ///
  /// Randomize starts hidden in the XML and is only ever *shown*, so a
  /// developer build gets six items and every other build five
  /// (`show-habit.menu#5`); Archive and Unarchive are mutually exclusive
  /// (`show-habit.menu#3`, `#4`).
  ///
  /// Kotlin asks the presenter once, when the options menu is created, and the
  /// answer sticks until the menu is rebuilt — which is why archiving from
  /// this screen leaves a stale Archive item behind
  /// (`show-habit.archive-unarchive#4`).
  List<ShowHabitMenuItem> onCreateOptionsMenu() {
    return <ShowHabitMenuItem>[
      for (final item in ShowHabitMenuItem.values)
        if (_isVisible(item)) item,
    ];
  }

  bool _isVisible(ShowHabitMenuItem item) {
    switch (item) {
      case ShowHabitMenuItem.randomize:
        return preferences.isDeveloper;
      case ShowHabitMenuItem.archive:
        return presenter.canArchive();
      case ShowHabitMenuItem.unarchive:
        return presenter.canUnarchive();
      case ShowHabitMenuItem.export:
      case ShowHabitMenuItem.delete:
      case ShowHabitMenuItem.edit:
        return true;
    }
  }

  /// `onOptionsItemSelected(item)`.
  ///
  /// [itemId] is `MenuItem.itemId`, an `Int` upstream: the `when` handles the
  /// six ids of this menu and every other id — the Up button's
  /// `android.R.id.home` above all — falls out of the bottom and returns
  /// false, so the platform's default handler gets it
  /// (`show-habit.menu#7`).
  bool onOptionsItemSelected(Object? itemId) {
    switch (itemId) {
      case ShowHabitMenuItem.edit:
        presenter.onEditHabit();
        return true;
      case ShowHabitMenuItem.archive:
        presenter.onArchiveHabits();
        return true;
      case ShowHabitMenuItem.unarchive:
        presenter.onUnarchiveHabits();
        return true;
      case ShowHabitMenuItem.delete:
        presenter.onDeleteHabit();
        return true;
      case ShowHabitMenuItem.randomize:
        presenter.onRandomize();
        return true;
      case ShowHabitMenuItem.export:
        presenter.onExportCSV();
        return true;
    }
    return false;
  }
}
