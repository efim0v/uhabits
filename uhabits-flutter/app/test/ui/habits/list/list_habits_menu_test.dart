/// Widget tests for the main screen's toolbar menu.
///
/// Port target: `res/menu/list_habits.xml` plus
/// uhabits-android/.../habits/list/ListHabitsMenu.kt — the item set and its
/// order, the three checkbox states, the sort arrows, the dispatch table and
/// the SearchView's open/close semantics. The presenter behind every item is
/// the already-ported core `ListHabitsMenuBehavior`, so what is asserted here
/// is only what the menu itself owns.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_list_menu');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope({PreferencesStorage? preferencesStorage}) {
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
      preferencesStorage: preferencesStorage,
    );
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  final openedUrls = <String>[];

  Future<void> pumpScreen(WidgetTester tester, AppScope scope) async {
    openedUrls.clear();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: HabitListScreen(onOpenUrl: openedUrls.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ListHabitsMenuState menuOf(WidgetTester tester) =>
      tester.state<ListHabitsMenuState>(find.byType(ListHabitsMenu));

  HabitListModel modelOf(WidgetTester tester) => Provider.of<HabitListModel>(
        tester.element(find.byType(Scaffold)),
        listen: false,
      );

  Finder itemFinder(String id) => find.byKey(ListHabitsMenuItems.keyOf(id));

  Future<void> openFilterMenu(WidgetTester tester) async {
    await tester.tap(itemFinder(ListHabitsMenuItems.filter));
    await tester.pumpAndSettle();
  }

  Future<void> openOverflowMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey<String>('listHabits.overflowMenu')));
    await tester.pumpAndSettle();
  }

  Future<void> openSortMenu(WidgetTester tester) async {
    await openFilterMenu(tester);
    await tester.tap(itemFinder(ListHabitsMenuItems.sort));
    await tester.pumpAndSettle();
  }

  group('list-habits.menu.overflow-items', () {
    testWidgets('#1 two icon actions, then the four overflow items in order',
        (tester) async {
      await pumpScreen(tester, openScope());

      // `showAsAction="always"`: Add habit and Filter live on the toolbar.
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#1');
      expect(itemFinder(ListHabitsMenuItems.filter), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#1');
      final add = tester.getRect(itemFinder(ListHabitsMenuItems.createHabit));
      final filter = tester.getRect(itemFinder(ListHabitsMenuItems.filter));
      expect(add.left, lessThan(filter.left),
          reason: 'list-habits.menu.overflow-items#1 — Add habit comes first');

      // …and the rest are `showAsAction="never"`, so they are in the overflow,
      // Dark theme first (orderInCategory 50) and the other three after it.
      expect(itemFinder(ListHabitsMenuItems.toggleNightMode), findsNothing,
          reason: 'list-habits.menu.overflow-items#1');
      await openOverflowMenu(tester);

      final ids = <String>[
        ListHabitsMenuItems.toggleNightMode,
        ListHabitsMenuItems.settings,
        ListHabitsMenuItems.faq,
        ListHabitsMenuItems.about,
      ];
      var previousTop = double.negativeInfinity;
      for (final id in ids) {
        expect(itemFinder(id), findsOneWidget,
            reason: 'list-habits.menu.overflow-items#1');
        final top = tester.getRect(itemFinder(id)).top;
        expect(top, greaterThan(previousTop),
            reason: 'list-habits.menu.overflow-items#1 — $id is out of order');
        previousTop = top;
      }
      expect(find.text('Dark theme'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#1');
      expect(find.text('Settings'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#1');
      expect(find.text('Help & FAQ'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#1');
      expect(find.text('About'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#1');
    });

    testWidgets('#2 the Filter submenu: hide archived, hide completed, Sort, '
        'Search', (tester) async {
      await pumpScreen(tester, openScope());
      await openFilterMenu(tester);

      final ids = <String>[
        ListHabitsMenuItems.hideArchived,
        ListHabitsMenuItems.hideCompleted,
        ListHabitsMenuItems.sort,
        ListHabitsMenuItems.search,
      ];
      var previousTop = double.negativeInfinity;
      for (final id in ids) {
        expect(itemFinder(id), findsOneWidget,
            reason: 'list-habits.menu.overflow-items#2');
        final top = tester.getRect(itemFinder(id)).top;
        expect(top, greaterThan(previousTop),
            reason: 'list-habits.menu.overflow-items#2 — $id is out of order');
        previousTop = top;
      }
      expect(find.text('Hide archived'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#2');
      expect(find.text('Sort'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#2');
      expect(find.text('Search'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#2');
    });

    testWidgets('#3 the Sort submenu, in order', (tester) async {
      await pumpScreen(tester, openScope());
      await openSortMenu(tester);

      final expected = <String, String>{
        ListHabitsMenuItems.sortManual: 'Manually',
        ListHabitsMenuItems.sortName: 'By name',
        ListHabitsMenuItems.sortColor: 'By color',
        ListHabitsMenuItems.sortScore: 'By score',
        ListHabitsMenuItems.sortStatus: 'By status',
      };
      var previousTop = double.negativeInfinity;
      for (final entry in expected.entries) {
        expect(itemFinder(entry.key), findsOneWidget,
            reason: 'list-habits.menu.overflow-items#3');
        expect(
          find.descendant(
            of: itemFinder(entry.key),
            matching: find.text(entry.value),
          ),
          findsOneWidget,
          reason: 'list-habits.menu.overflow-items#3',
        );
        final top = tester.getRect(itemFinder(entry.key)).top;
        expect(top, greaterThan(previousTop),
            reason: 'list-habits.menu.overflow-items#3 — ${entry.key} is out '
                'of order');
        previousTop = top;
      }
    });

    testWidgets('#4 the three checkbox states come from the preferences and '
        'the theme switcher', (tester) async {
      // Defaults: showArchived false, showCompleted true, night mode off.
      await pumpScreen(tester, openScope());
      final menu = menuOf(tester);
      expect(menu.isHideArchivedChecked, isTrue,
          reason: 'list-habits.menu.overflow-items#4 — !showArchived');
      expect(menu.isHideCompletedChecked, isFalse,
          reason: 'list-habits.menu.overflow-items#4 — !showCompleted');
      expect(menu.isNightModeChecked, isFalse,
          reason: 'list-habits.menu.overflow-items#4');

      // Flip both preferences and the theme, then rebuild the menu.
      final storage = MemoryStorage()
        ..putBoolean('pref_show_archived', true)
        ..putBoolean('pref_show_completed', false)
        ..putInt('pref_theme', 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(tester, openScope(preferencesStorage: storage));

      final flipped = menuOf(tester);
      expect(flipped.isHideArchivedChecked, isFalse,
          reason: 'list-habits.menu.overflow-items#4');
      expect(flipped.isHideCompletedChecked, isTrue,
          reason: 'list-habits.menu.overflow-items#4');
      expect(flipped.isNightModeChecked, isTrue,
          reason: 'list-habits.menu.overflow-items#4 — THEME_DARK');
    });

    testWidgets('#5 the hide-completed item is relabelled "Hide entered"',
        (tester) async {
      await pumpScreen(tester, openScope());
      final l10n = L10n.of(tester.element(find.byType(Scaffold)));
      final menu = menuOf(tester);
      final preferences = modelOf(tester).scope.preferences;

      expect(menu.hideCompletedTitle(l10n), 'Hide completed',
          reason: 'list-habits.menu.overflow-items#5');
      await openFilterMenu(tester);
      expect(find.text('Hide completed'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#5');
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();

      preferences.isSkipEnabled = true;
      expect(menu.hideCompletedTitle(l10n), 'Hide entered',
          reason: 'list-habits.menu.overflow-items#5 — isSkipEnabled alone is '
              'enough');

      preferences
        ..isSkipEnabled = false
        ..areQuestionMarksEnabled = true;
      expect(menu.hideCompletedTitle(l10n), 'Hide entered',
          reason: 'list-habits.menu.overflow-items#5 — and so is '
              'areQuestionMarksEnabled');

      menu.invalidateOptionsMenu();
      await tester.pumpAndSettle();
      await openFilterMenu(tester);
      expect(find.text('Hide entered'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#5');
      expect(find.text('Hide completed'), findsNothing,
          reason: 'list-habits.menu.overflow-items#5');
    });

    testWidgets('#9 an unknown id is not handled, and a known one is '
        'dispatched after the menu is invalidated', (tester) async {
      await pumpScreen(tester, openScope());
      final menu = menuOf(tester);

      expect(menu.onItemSelected('actionNotInTheMenu'), isFalse,
          reason: 'list-habits.menu.overflow-items#9 — the `when` has no '
              'branch for it, so `else -> return false`');
      expect(menu.onItemSelected(ListHabitsMenuItems.searchContainer), isFalse,
          reason: 'list-habits.menu.overflow-items#9 — the action-view '
              'container itself is never dispatched either');

      // Every named id is handled.
      for (final id in <String>[
        ListHabitsMenuItems.toggleNightMode,
        ListHabitsMenuItems.createHabit,
        ListHabitsMenuItems.faq,
        ListHabitsMenuItems.about,
        ListHabitsMenuItems.settings,
        ListHabitsMenuItems.hideArchived,
        ListHabitsMenuItems.hideCompleted,
        ListHabitsMenuItems.sortColor,
        ListHabitsMenuItems.sortManual,
        ListHabitsMenuItems.sortName,
        ListHabitsMenuItems.sortScore,
        ListHabitsMenuItems.sortStatus,
        ListHabitsMenuItems.search,
      ]) {
        expect(menu.onItemSelected(id), isTrue,
            reason: 'list-habits.menu.overflow-items#9 — $id');
      }
      await tester.pumpAndSettle();
    });

    testWidgets('#8 toggling a filter re-draws the checkbox', (tester) async {
      await pumpScreen(tester, openScope());
      final menu = menuOf(tester);
      expect(menu.isHideArchivedChecked, isTrue,
          reason: 'list-habits.menu.overflow-items#8');

      await openFilterMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.hideArchived));
      await tester.pumpAndSettle();

      expect(menu.isHideArchivedChecked, isFalse,
          reason: 'list-habits.menu.overflow-items#8');
      expect(modelOf(tester).scope.preferences.showArchived, isTrue,
          reason: 'list-habits.menu.overflow-items#8');
      // The checkbox is redrawn from the new state, not the old one.
      await openFilterMenu(tester);
      final checkbox = tester.widget<MenuItemButton>(
        itemFinder(ListHabitsMenuItems.hideArchived),
      );
      expect((checkbox.leadingIcon! as Icon).icon, Icons.check_box_outline_blank,
          reason: 'list-habits.menu.overflow-items#8');
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
    });

    testWidgets('#6 #7 the four navigation items reach their screens',
        (tester) async {
      await pumpScreen(tester, openScope());

      await openOverflowMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.faq));
      await tester.pumpAndSettle();
      expect(openedUrls, <String>['http://loophabits.org/faq.html'],
          reason: 'list-habits.menu.overflow-items#7');

      await openOverflowMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.about));
      await tester.pumpAndSettle();
      expect(find.text('Loop Habit Tracker'), findsWidgets,
          reason: 'list-habits.menu.overflow-items#7');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(itemFinder(ListHabitsMenuItems.createHabit));
      await tester.pumpAndSettle();
      expect(find.text('Yes or No'), findsOneWidget,
          reason: 'list-habits.menu.overflow-items#6 — the habit-type dialog');
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
    });
  });

  group('list-habits.sort-modes', () {
    testWidgets('#11 only the active primary order carries an arrow',
        (tester) async {
      await pumpScreen(tester, openScope());
      final menu = menuOf(tester);
      final preferences = modelOf(tester).scope.preferences;

      const arrowUp = Icons.arrow_upward;
      const arrowDown = Icons.arrow_downward;
      final expected = <HabitListOrder, (String, IconData)>{
        HabitListOrder.byPosition: (ListHabitsMenuItems.sortManual, arrowUp),
        HabitListOrder.byNameAsc: (ListHabitsMenuItems.sortName, arrowDown),
        HabitListOrder.byNameDesc: (ListHabitsMenuItems.sortName, arrowUp),
        HabitListOrder.byColorAsc: (ListHabitsMenuItems.sortColor, arrowDown),
        HabitListOrder.byColorDesc: (ListHabitsMenuItems.sortColor, arrowUp),
        HabitListOrder.byScoreAsc: (ListHabitsMenuItems.sortScore, arrowDown),
        HabitListOrder.byScoreDesc: (ListHabitsMenuItems.sortScore, arrowUp),
        HabitListOrder.byStatusAsc: (ListHabitsMenuItems.sortStatus, arrowDown),
        HabitListOrder.byStatusDesc: (ListHabitsMenuItems.sortStatus, arrowUp),
      };
      const allSortItems = <String>[
        ListHabitsMenuItems.sortManual,
        ListHabitsMenuItems.sortName,
        ListHabitsMenuItems.sortColor,
        ListHabitsMenuItems.sortScore,
        ListHabitsMenuItems.sortStatus,
      ];

      for (final entry in expected.entries) {
        preferences.defaultPrimaryOrder = entry.key;
        final (markedItem, arrow) = entry.value;
        for (final id in allSortItems) {
          expect(
            menu.sortArrowFor(id),
            id == markedItem ? arrow : isNull,
            reason: 'list-habits.sort-modes#11 — ${entry.key} marks '
                '$markedItem and nothing else',
          );
        }
      }
    });

    testWidgets('#11 the arrow is drawn on the item in the open submenu',
        (tester) async {
      await pumpScreen(tester, openScope());
      // BY_POSITION is the default, so 'Manually' carries the up arrow.
      await openSortMenu(tester);
      expect(
        find.descendant(
          of: itemFinder(ListHabitsMenuItems.sortManual),
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
        reason: 'list-habits.sort-modes#11',
      );
      expect(
        find.descendant(
          of: itemFinder(ListHabitsMenuItems.sortName),
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsNothing,
        reason: 'list-habits.sort-modes#11',
      );

      // Sorting by name puts the down arrow there instead.
      await tester.tap(itemFinder(ListHabitsMenuItems.sortName));
      await tester.pumpAndSettle();
      await openSortMenu(tester);
      expect(
        find.descendant(
          of: itemFinder(ListHabitsMenuItems.sortName),
          matching: find.byIcon(Icons.arrow_downward),
        ),
        findsOneWidget,
        reason: 'list-habits.sort-modes#11 — BY_NAME_ASC shows a down arrow',
      );
      expect(
        find.descendant(
          of: itemFinder(ListHabitsMenuItems.sortManual),
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsNothing,
        reason: 'list-habits.sort-modes#11');

      // Tapping it again reverses it, and the arrow flips.
      await tester.tap(itemFinder(ListHabitsMenuItems.sortName));
      await tester.pumpAndSettle();
      await openSortMenu(tester);
      expect(
        find.descendant(
          of: itemFinder(ListHabitsMenuItems.sortName),
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
        reason: 'list-habits.sort-modes#11 — BY_NAME_DESC shows an up arrow',
      );
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
    });
  });

  group('list-habits.search', () {
    testWidgets('#9 Filter > Search swaps the action items for the search bar',
        (tester) async {
      await pumpScreen(tester, openScope());
      expect(menuOf(tester).isSearchActive, isFalse,
          reason: 'list-habits.search#9');
      expect(itemFinder(ListHabitsMenuItems.searchContainer), findsNothing,
          reason: 'list-habits.search#9 — the container is hidden while the '
              'search is not active');
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'list-habits.search#9');

      await openFilterMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.search));
      await tester.pumpAndSettle();

      expect(menuOf(tester).isSearchActive, isTrue,
          reason: 'list-habits.search#9');
      expect(itemFinder(ListHabitsMenuItems.searchContainer), findsOneWidget,
          reason: 'list-habits.search#9');
      // `menu.setGroupVisible(R.id.actionItems, !isSearchActive)`.
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsNothing,
          reason: 'list-habits.search#9');
      expect(itemFinder(ListHabitsMenuItems.filter), findsNothing,
          reason: 'list-habits.search#9');
      expect(find.byKey(const ValueKey<String>('listHabits.overflowMenu')),
          findsNothing,
          reason: 'list-habits.search#9');
    });

    testWidgets('#10 the field is open, hinted and repopulated from the '
        'presenter', (tester) async {
      await pumpScreen(tester, openScope());
      await openFilterMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.search));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        itemFinder(ListHabitsMenuItems.searchContainer),
      );
      // `isIconified = false`: the field is already open, not a magnifier.
      expect(field.autofocus, isTrue, reason: 'list-habits.search#10');
      expect(field.decoration?.hintText, 'Search',
          reason: 'list-habits.search#10 — queryHint = R.string.search');
      expect(field.controller?.text, '', reason: 'list-habits.search#10');

      await tester.enterText(
        itemFinder(ListHabitsMenuItems.searchContainer),
        'yoga',
      );
      await tester.pumpAndSettle();
      expect(modelOf(tester).menu.searchQuery, 'yoga',
          reason: 'list-habits.search#10');

      // `setQuery(behavior.searchQuery, false)` on every menu invalidation:
      // the text survives, and it is not submitted.
      menuOf(tester).invalidateOptionsMenu();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(itemFinder(ListHabitsMenuItems.searchContainer))
            .controller
            ?.text,
        'yoga',
        reason: 'list-habits.search#10',
      );
      expect(modelOf(tester).menu.searchQuery, 'yoga',
          reason: 'list-habits.search#10');
    });

    testWidgets('#11 every keystroke reaches the presenter; submit is ignored',
        (tester) async {
      final scope = openScope();
      for (final name in <String>['Yoga practice', 'Read']) {
        final habit = scope.modelFactory.buildHabit()..name = name;
        scope.habitList.add(habit);
        habit.recompute();
      }
      await pumpScreen(tester, scope);
      await openFilterMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.search));
      await tester.pumpAndSettle();

      final menu = menuOf(tester);
      expect(menu.onQueryTextChange('yo'), isTrue,
          reason: 'list-habits.search#11 — onQueryTextChange returns true');
      expect(modelOf(tester).menu.searchQuery, 'yo',
          reason: 'list-habits.search#11');
      expect(menu.onQueryTextSubmit('yo'), isFalse,
          reason: 'list-habits.search#11 — onQueryTextSubmit returns false');

      await tester.enterText(
        itemFinder(ListHabitsMenuItems.searchContainer),
        'yoga',
      );
      await tester.pumpAndSettle();
      expect(modelOf(tester).menu.searchQuery, 'yoga',
          reason: 'list-habits.search#11');
      // …and the filter really moved: only the matching row is left.
      expect(find.text('Yoga practice'), findsOneWidget,
          reason: 'list-habits.search#11');
      expect(find.text('Read'), findsNothing,
          reason: 'list-habits.search#11');
    });

    testWidgets('#12 closing the search bar keeps the query filtering',
        (tester) async {
      final scope = openScope();
      for (final name in <String>['Yoga practice', 'Read']) {
        final habit = scope.modelFactory.buildHabit()..name = name;
        scope.habitList.add(habit);
        habit.recompute();
      }
      await pumpScreen(tester, scope);
      await openFilterMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.search));
      await tester.pumpAndSettle();
      await tester.enterText(
        itemFinder(ListHabitsMenuItems.searchContainer),
        'yoga',
      );
      await tester.pumpAndSettle();

      expect(menuOf(tester).onSearchClosed(), isTrue,
          reason: 'list-habits.search#12 — the close listener returns true');
      await tester.pumpAndSettle();

      expect(menuOf(tester).isSearchActive, isFalse,
          reason: 'list-habits.search#12');
      // The actionItems group is visible again.
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'list-habits.search#12');
      expect(itemFinder(ListHabitsMenuItems.searchContainer), findsNothing,
          reason: 'list-habits.search#12');
      // …but the query was never cleared, so the list stays filtered.
      expect(modelOf(tester).menu.searchQuery, 'yoga',
          reason: 'list-habits.search#12');
      expect(find.text('Yoga practice'), findsOneWidget,
          reason: 'list-habits.search#12');
      expect(find.text('Read'), findsNothing,
          reason: 'list-habits.search#12');
    });
  });
}
