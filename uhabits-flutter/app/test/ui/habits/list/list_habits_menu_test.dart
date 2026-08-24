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

      // The close LISTENER, invoked directly. Reaching it from the X button
      // takes a second tap on an already-empty field
      // (`audit7.the-search-bar-s-x-button`); what #12 pins is that the
      // listener itself never touches behavior.searchQuery.
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

  // =======================================================================
  // audit5.toolbar-action-items-are-dropped-rather
  //
  // `showAsAction="always"` keeps 'Add habit' and 'Filter' on the action bar
  // at any width, and an item the ActionBar genuinely cannot fit is *moved
  // into the overflow menu*, never removed. Every one of 'Create habit',
  // 'Hide archived', 'Hide completed', 'Sort' and 'Search' is therefore
  // always reachable.
  // =======================================================================

  group('audit5.toolbar-action-items-are-dropped-rather', () {
    /// The toolbar on its own, inside a box of exactly [width] logical pixels,
    /// so the width test inside `_buildToolbar` is driven directly rather than
    /// through the whole screen's layout.
    Future<void> pumpMenu(
      WidgetTester tester,
      AppScope scope,
      double width,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: ChangeNotifierProvider<HabitListModel>(
              create: (context) => HabitListModel(context.read<AppScope>()),
              child: Builder(
                builder: (context) => Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: 400,
                    child: Scaffold(
                      appBar: ListHabitsMenu(
                        model: context.read<HabitListModel>(),
                        title: 'Loop Habit Tracker',
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('#1 a toolbar with no room for the Add habit icon moves it '
        'into the overflow instead of dropping it', (tester) async {
      final scope = openScope();
      await pumpMenu(tester, scope, 160);

      // The bar has no room for it…
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsNothing,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — the '
              'toolbar is too narrow to fit the icon');

      // …so it is in the overflow, which is where an ActionBar moves an item
      // it cannot fit. It is never removed.
      await openOverflowMenu(tester);
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — an item '
              'the ActionBar cannot fit is moved into the overflow menu, '
              "never removed, so 'Create habit' is always reachable");
      expect(
        tester.widget(itemFinder(ListHabitsMenuItems.createHabit)),
        isA<MenuItemButton>(),
        reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — as a '
            'menu entry, not as the bar icon',
      );
      // …and it is the real menu item: selecting it runs onCreateHabit.
      final requests = <void>[];
      modelOf(tester).onShowSelectHabitTypeDialog = () => requests.add(null);
      await tester.tap(itemFinder(ListHabitsMenuItems.createHabit));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1),
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — the '
              'moved item still dispatches to the presenter');
    });

    testWidgets('#1 a toolbar with no room for the Filter icon keeps Hide '
        'archived, Hide completed, Sort and Search reachable', (tester) async {
      final scope = openScope();
      await pumpMenu(tester, scope, 100);

      expect(itemFinder(ListHabitsMenuItems.filter), findsNothing,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — the bar '
              'has no room for the Filter icon either');

      await openOverflowMenu(tester);
      expect(itemFinder(ListHabitsMenuItems.filter), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — the '
              'Filter item moves into the overflow menu, submenu and all');
      await tester.tap(itemFinder(ListHabitsMenuItems.filter));
      await tester.pumpAndSettle();

      for (final id in <String>[
        ListHabitsMenuItems.hideArchived,
        ListHabitsMenuItems.hideCompleted,
        ListHabitsMenuItems.sort,
        ListHabitsMenuItems.search,
      ]) {
        expect(itemFinder(id), findsOneWidget,
            reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — $id '
                'is always reachable');
      }

      // The submenu still works from there: 'Sort' opens the five orders…
      await tester.tap(itemFinder(ListHabitsMenuItems.sort));
      await tester.pumpAndSettle();
      expect(itemFinder(ListHabitsMenuItems.sortName), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1');
      await tester.tap(itemFinder(ListHabitsMenuItems.sortName));
      await tester.pumpAndSettle();
      expect(scope.preferences.defaultPrimaryOrder, HabitListOrder.byNameAsc,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — a moved '
              'item dispatches exactly as it does from the action bar');
    });

    testWidgets('#1 a wide toolbar still shows both icons and leaves the '
        'overflow to the four never-items', (tester) async {
      final scope = openScope();
      await pumpMenu(tester, scope, 400);

      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1');
      expect(itemFinder(ListHabitsMenuItems.filter), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1');

      await openOverflowMenu(tester);
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — with '
              'room on the bar the item is not duplicated into the overflow');
      expect(
        tester.widget(itemFinder(ListHabitsMenuItems.createHabit)),
        isA<IconButton>(),
        reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — the one '
            'left is the bar icon',
      );
      expect(itemFinder(ListHabitsMenuItems.filter), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1');
      expect(
        tester.widget(itemFinder(ListHabitsMenuItems.filter)),
        isA<IconButton>(),
        reason: 'audit5.toolbar-action-items-are-dropped-rather#1');
      expect(itemFinder(ListHabitsMenuItems.settings), findsOneWidget,
          reason: 'audit5.toolbar-action-items-are-dropped-rather#1 — the '
              'four showAsAction="never" items are unaffected');
    });
  });

  // =======================================================================
  // audit7.the-search-bar-s-x-button
  //
  // The action view is an `androidx.appcompat.widget.SearchView`, and its X
  // button runs `onCloseClicked()`, which is a two-stage control:
  //
  //     void onCloseClicked() {
  //         CharSequence text = mSearchSrcTextView.getText();
  //         if (TextUtils.isEmpty(text)) {
  //             if (mIconifiedByDefault) {
  //                 if (mOnCloseListener == null || !mOnCloseListener.onClose()) {
  //                     clearFocus();
  //                     updateViewsVisibility(true);
  //                 }
  //             }
  //         } else {
  //             mSearchSrcTextView.setText("");
  //             mSearchSrcTextView.requestFocus();
  //             setImeVisibility(true);
  //         }
  //     }
  //
  // While the query is non-empty the close LISTENER is never reached: the
  // field is emptied, refocused and left open, and the TextWatcher carries
  // `onQueryTextChange("")` to the presenter so the full list comes back.
  // Only a second tap, on an already-empty field, reaches
  // `setOnCloseListener` and closes the bar. The search bar therefore can
  // never be closed while a query is still in force.
  // =======================================================================

  group('audit7.the-search-bar-s-x-button', () {
    Finder searchCloseFinder() =>
        find.byKey(const ValueKey<String>('listHabitsMenu.searchClose'));

    Future<AppScope> openSearchWithQuery(WidgetTester tester) async {
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
      return scope;
    }

    testWidgets('#1 the first tap clears the query and keeps the bar open',
        (tester) async {
      await openSearchWithQuery(tester);
      expect(find.text('Read'), findsNothing,
          reason: 'audit7.the-search-bar-s-x-button#1 — the list starts out '
              'filtered');

      await tester.tap(searchCloseFinder());
      await tester.pumpAndSettle();

      // `mSearchSrcTextView.setText("")` plus the TextWatcher it fires.
      expect(modelOf(tester).menu.searchQuery, '',
          reason: 'audit7.the-search-bar-s-x-button#1 — clearing the text '
              'fires onQueryTextChange("") -> '
              'behavior.onSearchQueryChanged("")');
      expect(
        tester
            .widget<TextField>(itemFinder(ListHabitsMenuItems.searchContainer))
            .controller
            ?.text,
        '',
        reason: 'audit7.the-search-bar-s-x-button#1 — the field itself is '
            'emptied',
      );
      // …and the matcher was rebuilt with an empty query, so the full list is
      // back. This is the whole point: the list must never be left silently
      // filtered.
      expect(find.text('Yoga practice'), findsOneWidget,
          reason: 'audit7.the-search-bar-s-x-button#1 — the full list comes '
              'back');
      expect(find.text('Read'), findsOneWidget,
          reason: 'audit7.the-search-bar-s-x-button#1 — the full list comes '
              'back');

      // The close listener was NOT called: the bar is still open.
      expect(menuOf(tester).isSearchActive, isTrue,
          reason: 'audit7.the-search-bar-s-x-button#1 — while the query is '
              'non-empty the close listener is not reached, so isSearchActive '
              'stays true');
      expect(itemFinder(ListHabitsMenuItems.searchContainer), findsOneWidget,
          reason: 'audit7.the-search-bar-s-x-button#1 — the search field is '
              'still on the toolbar');
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsNothing,
          reason: 'audit7.the-search-bar-s-x-button#1 — the actionItems group '
              'is still hidden');
      // `requestFocus()` + `setImeVisibility(true)`: the keyboard stays up.
      expect(
        tester
            .widget<TextField>(itemFinder(ListHabitsMenuItems.searchContainer))
            .focusNode
            ?.hasFocus,
        isTrue,
        reason: 'audit7.the-search-bar-s-x-button#1 — the field re-requests '
            'focus and the keyboard is kept up',
      );
    });

    testWidgets('#1 the second tap, on an empty field, closes the bar',
        (tester) async {
      await openSearchWithQuery(tester);

      await tester.tap(searchCloseFinder());
      await tester.pumpAndSettle();
      await tester.tap(searchCloseFinder());
      await tester.pumpAndSettle();

      expect(menuOf(tester).isSearchActive, isFalse,
          reason: 'audit7.the-search-bar-s-x-button#1 — the second tap, on an '
              'already-empty field, reaches setOnCloseListener');
      expect(itemFinder(ListHabitsMenuItems.searchContainer), findsNothing,
          reason: 'audit7.the-search-bar-s-x-button#1 — the search container '
              'is hidden again');
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'audit7.the-search-bar-s-x-button#1 — the actionItems group '
              'is restored');
      expect(modelOf(tester).menu.searchQuery, '',
          reason: 'audit7.the-search-bar-s-x-button#1 — the bar closes with no '
              'query left in force');
      expect(find.text('Yoga practice'), findsOneWidget,
          reason: 'audit7.the-search-bar-s-x-button#1');
      expect(find.text('Read'), findsOneWidget,
          reason: 'audit7.the-search-bar-s-x-button#1 — the list is not left '
              'silently filtered');
    });

    testWidgets('#1 one tap closes a bar that was never typed into',
        (tester) async {
      final scope = openScope();
      final habit = scope.modelFactory.buildHabit()..name = 'Yoga practice';
      scope.habitList.add(habit);
      habit.recompute();
      await pumpScreen(tester, scope);
      await openFilterMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.search));
      await tester.pumpAndSettle();

      await tester.tap(searchCloseFinder());
      await tester.pumpAndSettle();

      expect(menuOf(tester).isSearchActive, isFalse,
          reason: 'audit7.the-search-bar-s-x-button#1 — an empty field takes '
              'the `TextUtils.isEmpty(text)` branch on the very first tap');
      expect(itemFinder(ListHabitsMenuItems.createHabit), findsOneWidget,
          reason: 'audit7.the-search-bar-s-x-button#1');
    });

    testWidgets('#1 onCloseClicked is the two-stage control, onSearchClosed '
        'stays the close listener', (tester) async {
      await openSearchWithQuery(tester);
      final menu = menuOf(tester);

      // Stage one: a non-empty field. The listener is not run.
      menu.onCloseClicked();
      await tester.pumpAndSettle();
      expect(menu.isSearchActive, isTrue,
          reason: 'audit7.the-search-bar-s-x-button#1 — onCloseClicked on a '
              'non-empty field does not call the close listener');
      expect(modelOf(tester).menu.searchQuery, '',
          reason: 'audit7.the-search-bar-s-x-button#1');

      // Stage two: an empty field. Now the listener runs, and it still
      // returns true (`list-habits.search#12`).
      menu.onCloseClicked();
      await tester.pumpAndSettle();
      expect(menu.isSearchActive, isFalse,
          reason: 'audit7.the-search-bar-s-x-button#1 — onCloseClicked on an '
              'empty field delegates to the close listener');
    });
  });

  group('audit10.the-overflow-menu-button-and-the', () {
    const rule = 'audit10.the-overflow-menu-button-and-the#1 — the three-dot '
        'button on the main toolbar is AppCompat\'s '
        '`ActionMenuPresenter.OverflowMenuButton`, whose constructor sets '
        '`contentDescription = R.string.abc_action_menu_overflow_description` '
        '("More options") and installs it as a TooltipCompat tooltip, so '
        'TalkBack names it and a long press shows it. Nothing in the port '
        'declares a menu resource, so every such control has to carry the '
        'label itself.';

    testWidgets('#1 the toolbar overflow button is named', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, openScope());
      final material = MaterialLocalizations.of(
        tester.element(find.byType(HabitListScreen)),
      );

      // Read back what a screen reader would announce, not what a ValueKey
      // says: every other toolbar control already publishes a name, and the
      // three-dot button is the only route to Settings, Dark theme, Help &
      // FAQ and About.
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey<String>('listHabits.overflowMenu')),
            )
            .tooltip,
        material.showMenuTooltip,
        reason: rule,
      );
      handle.dispose();
    });

    testWidgets('#1 the search bar\'s X says "clear", not "search"',
        (tester) async {
      await pumpScreen(tester, openScope());
      await openFilterMenu(tester);
      await tester.tap(itemFinder(ListHabitsMenuItems.search));
      await tester.pumpAndSettle();

      final close = tester.widget<IconButton>(
        find.byKey(const ValueKey<String>('listHabitsMenu.searchClose')),
      );
      final l10n = L10n.of(tester.element(find.byType(HabitListScreen)));
      final material = MaterialLocalizations.of(
        tester.element(find.byType(HabitListScreen)),
      );
      expect(close.tooltip, isNot(l10n.search),
          reason: '$rule AppCompat\'s SearchView close button carries '
              '`abc_searchview_description_clear` ("Clear query"), not the '
              'query hint — and its first tap clears the field rather than '
              'closing the bar (`audit7.the-search-bar-s-x-button#1`).');
      expect(close.tooltip, material.clearButtonTooltip, reason: rule);
    });
  });
}
