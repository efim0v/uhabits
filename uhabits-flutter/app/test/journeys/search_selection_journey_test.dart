/// Journey: searching, then selecting one of the results.
///
/// `audit9.search-bar-survives-selection-mode`. Upstream the toolbar and the
/// contextual action bar are two different menus with two different owners.
/// `ListHabitsMenu` is `@ActivityScope` — one instance for the whole activity —
/// and its `isSearchActive` field plus the expanded `SearchView` belong to the
/// options menu (ListHabitsMenu.kt:48, :73-95).
/// `ListHabitsSelectionMenu` is an `ActionMode.Callback`: it inflates
/// `R.menu.list_habits_selection` into the *ActionMode's* own `Menu` and never
/// touches the options menu, and `onDestroyActionMode` calls nothing but
/// `listController.onSelectionFinished()` (ListHabitsSelectionMenu.kt:88-90).
///
/// A long press therefore overlays the toolbar and destroying the action mode
/// uncovers it exactly as it was: search bar still open, query still in it.
/// That is what makes the two-stage X button of
/// `audit7.the-search-bar-s-x-button#1` meaningful — the search bar can never
/// be closed while a query is still in force, so a filtered list always shows
/// the query filtering it.
///
/// Only a journey can see this: the bar is swapped by the *screen*, so a test
/// that builds either menu by hand never crosses the two.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String rule = 'audit9.search-bar-survives-selection-mode#1';

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_search_selection');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// The `SearchView` behind `actionSearchContainer`.
  Finder searchField() =>
      find.byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.searchContainer));

  /// The `SearchView`'s X.
  Finder searchClose() =>
      find.byKey(const ValueKey<String>('listHabitsMenu.searchClose'));

  /// Filter > Search, then the query, keystroke by keystroke as far as the
  /// presenter is concerned.
  Future<void> searchFor(WidgetTester tester, String query) async {
    await tester.tap(find.byKey(
      ListHabitsMenuItems.keyOf(ListHabitsMenuItems.filter),
    ));
    await tester.pumpAndSettle();
    await tapListMenuItem(tester, ListHabitsMenuItems.search);
    await tester.enterText(searchField(), query);
    await tester.pumpAndSettle();
  }

  /// Launch, three habits, and a search that leaves exactly one of them.
  Future<void> launchAndSearch(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Wake up early');
    await createHabit(tester, name: 'Track time');
    await createHabit(tester, name: 'Meditate');

    await searchFor(tester, 'Track');

    verifyDisplaysText('Track time',
        reason: '$rule: the search leaves the matching row');
    verifyDoesNotDisplayText('Wake up early',
        reason: '$rule: the other rows are filtered out');
    verifyDoesNotDisplayText('Meditate',
        reason: '$rule: the other rows are filtered out');
  }

  /// Everything the toolbar has to look like once the contextual bar is gone.
  void expectSearchBarStillOpen(WidgetTester tester) {
    expect(find.byType(ListHabitsMenu), findsOneWidget,
        reason: '$rule: destroying the action mode uncovers the toolbar');
    expect(searchField(), findsOneWidget,
        reason: '$rule: onDestroyActionMode never invalidates the options '
            'menu, so the SearchView is still expanded on the toolbar');
    expect(
      tester.widget<TextField>(searchField()).controller?.text,
      'Track',
      reason: '$rule: the field still holds behavior.searchQuery — '
          'createSearchBar restores it with setQuery(behavior.searchQuery, '
          'false) even if the menu were rebuilt',
    );
    // `menu.setGroupVisible(R.id.actionItems, !isSearchActive)`: the search
    // bar and the action items are mutually exclusive, so the action items
    // being back would mean the search bar is gone.
    expect(
      find.byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.createHabit)),
      findsNothing,
      reason: '$rule: isSearchActive is still true, so the actionItems group '
          'is still hidden',
    );
    verifyDisplaysText('Track time',
        reason: '$rule: the list is still filtered');
    verifyDoesNotDisplayText('Wake up early',
        reason: '$rule: the list is still filtered by a query that is still '
            'on screen');
  }

  testWidgets('a long press and a Back leave the search bar exactly as it was',
      (WidgetTester tester) async {
    await launchAndSearch(tester);

    await longPressHabit(tester, 'Track time');
    expect(find.byType(ListHabitsSelectionMenu), findsOneWidget,
        reason: 'list-habits.selection-mode#3: a long press starts the '
            'contextual action bar');
    expect(searchField(), findsNothing,
        reason: '$rule: the contextual bar covers the toolbar while it is up');

    await pressBack(tester);

    expect(find.byType(ListHabitsSelectionMenu), findsNothing,
        reason: 'audit3.the-android-system-back-button-does#1: Back destroys '
            'the contextual action bar');
    expectSearchBarStillOpen(tester);
  });

  testWidgets("the contextual bar's own close button leaves it too",
      (WidgetTester tester) async {
    await launchAndSearch(tester);

    await longPressHabit(tester, 'Track time');
    await tester
        .tap(find.byKey(const ValueKey<String>('listHabitsSelection.close')));
    await tester.pumpAndSettle();

    expect(find.byType(ListHabitsSelectionMenu), findsNothing,
        reason: 'list-habits.selection-mode#6: the close button finishes the '
            'action mode');
    expectSearchBarStillOpen(tester);
  });

  testWidgets('the X button is still the way out of the filtered list',
      (WidgetTester tester) async {
    await launchAndSearch(tester);

    await longPressHabit(tester, 'Track time');
    await pressBack(tester);

    // `audit7.the-search-bar-s-x-button#1`: with a query in force the first
    // tap empties the field and rebuilds the matcher, which is the recovery
    // the user has. It only exists while the search bar is on screen.
    await tester.tap(searchClose());
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(searchField()).controller?.text,
      '',
      reason: '$rule: the X the selection did not destroy still empties the '
          'field (audit7.the-search-bar-s-x-button#1)',
    );
    verifyDisplaysText('Wake up early',
        reason: '$rule: the full list comes back');
    verifyDisplaysText('Meditate', reason: '$rule: the full list comes back');
    verifyDisplaysText('Track time', reason: '$rule: the full list comes back');
  });
}
