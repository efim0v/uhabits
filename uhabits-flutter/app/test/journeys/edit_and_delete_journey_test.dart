/// Journey: the user renames a habit, and later deletes it.
///
/// `verify.integration-harness#3`, journey 5 — "edit and delete a habit".
///
/// Upstream this is three tests of `HabitsTest`:
///
///  * `shouldEditHabit` — `longClickText(name)`, `clickMenu(EDIT)`,
///    `typeName`, `clickSave`, the list shows the new name and not the old;
///  * `shouldEditHabit_fromStatisticsScreen` — the same edit reached from the
///    detail screen, which comes back to the detail screen;
///  * `shouldDeleteHabit` — `longClickText(name)`, `clickMenu(DELETE)`,
///    `clickText("Yes")`, the row is gone.
///
/// Everything here goes through the contextual action bar the app swaps in for
/// its toolbar when a row is selected, which is the part a screen-level widget
/// test cannot reach without arranging the selection itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart' show Habit;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_edit_delete');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  Future<void> launchWithHabits(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Wake up early');
    await createHabit(tester, name: 'Track time');
  }

  List<String> listedNames() =>
      app.scope.habitList.toList().map((Habit h) => h.name).toList();

  testWidgets('a long press opens the contextual action bar',
      (WidgetTester tester) async {
    await launchWithHabits(tester);

    await longPressHabit(tester, 'Track time');

    expect(find.byType(ListHabitsSelectionMenu), findsOneWidget,
        reason: 'list-habits.selection-mode: a long press starts the '
            'ActionMode that replaces the toolbar. Without it the Edit, '
            'Colour, Archive and Delete actions are unreachable by any user.');
    verifyDisplaysText('1',
        reason: 'the action bar title is the number of selected habits');
  });

  testWidgets('Edit renames the habit and the list shows the new name',
      (WidgetTester tester) async {
    await launchWithHabits(tester);

    await longPressHabit(tester, 'Track time');
    await tapSelectionMenuItem(tester, ListHabitsSelectionMenuItems.edit);

    expect(find.byType(EditHabitScreen), findsOneWidget,
        reason: 'ListHabitsSelectionMenuBehavior.onEditHabits() starts '
            'EditHabitActivity for the selected habit');
    verifyDisplaysText(stringsOf(tester).editHabit,
        reason: 'edit-habit.entry-points#2: EDIT mode is titled "Edit habit"');

    await fillHabitForm(
      tester,
      name: 'Take a walk',
      question: 'Did you take a walk today?',
    );
    await saveHabit(tester);

    verifyDisplaysText('Take a walk',
        reason: 'verify.integration-harness#3: "edit and delete a habit". '
            'EditHabitCommand has to reach the list the user is looking at.');
    verifyDoesNotDisplayText('Track time',
        reason: 'HabitsTest.shouldEditHabit ends with '
            'verifyDoesNotDisplayText("Track time")');
    expect(listedNames(), <String>['Wake up early', 'Take a walk'],
        reason: 'edit-habit.save#1: an edit keeps the habit\'s position');
  });

  testWidgets('the rename survives a restart', (WidgetTester tester) async {
    await launchWithHabits(tester);
    await longPressHabit(tester, 'Track time');
    await tapSelectionMenuItem(tester, ListHabitsSelectionMenuItems.edit);
    await fillHabitForm(tester, name: 'Take a walk');
    await saveHabit(tester);

    await app.restart();

    verifyDisplaysText('Take a walk',
        reason: 'the edit has to have reached the database, not just the '
            'in-memory list');
    verifyDoesNotDisplayText('Track time');
  });

  testWidgets('Edit from the habit screen comes back to the habit screen',
      (WidgetTester tester) async {
    // `HabitsTest.shouldEditHabit_fromStatisticsScreen`.
    await launchWithHabits(tester);
    await tapHabit(tester, 'Track time');
    expect(find.byType(ShowHabitScreen), findsOneWidget);

    await tester.tap(find.byKey(ShowHabitScreen.editActionKey));
    await tester.pumpAndSettle();
    expect(find.byType(EditHabitScreen), findsOneWidget,
        reason: 'show-habit.edit-action: the toolbar\'s pencil starts '
            'EditHabitActivity for this habit');

    await fillHabitForm(tester, name: 'Take a walk');
    await saveHabit(tester);

    expect(find.byType(ShowHabitScreen), findsOneWidget,
        reason: 'clickSave() finishes the editor and the detail screen is '
            'underneath it');
    verifyDisplaysText('Take a walk',
        reason: 'and the detail screen has to repaint with the new name');

    await pressBack(tester);
    verifyDisplaysText('Take a walk', reason: 'so does the list');
    verifyDoesNotDisplayText('Track time');
  });

  testWidgets('Delete asks first, and "No" keeps the habit',
      (WidgetTester tester) async {
    await launchWithHabits(tester);
    final L10n l10n = stringsOf(tester);

    await longPressHabit(tester, 'Track time');
    await tapSelectionMenuItem(tester, ListHabitsSelectionMenuItems.delete);

    verifyDisplaysText(l10n.deleteHabitsTitle(1),
        reason: 'confirm-delete.dialog#1: deleting always asks');

    await tester.tap(find.byKey(const ValueKey<String>('confirm_delete_no')));
    await settleIo(tester);

    verifyDisplaysText('Track time',
        reason: 'confirm-delete.dialog#5: the negative button does nothing');
    expect(listedNames(), <String>['Wake up early', 'Track time']);
  });

  testWidgets('Delete then "Yes" removes the habit for good',
      (WidgetTester tester) async {
    await launchWithHabits(tester);

    await longPressHabit(tester, 'Track time');
    await tapSelectionMenuItem(tester, ListHabitsSelectionMenuItems.delete);
    await tester.tap(find.byKey(const ValueKey<String>('confirm_delete_yes')));
    await settleIo(tester);

    verifyDoesNotDisplayText('Track time',
        reason: 'HabitsTest.shouldDeleteHabit: after "Yes" the row is gone');
    verifyDisplaysText('Wake up early',
        reason: 'and only the selected habit is deleted');
    expect(find.byType(ListHabitsSelectionMenu), findsNothing,
        reason: 'list-habits.selection-mode: the action mode finishes with the '
            'command, and the normal toolbar comes back');

    await app.restart();
    expect(listedNames(), <String>['Wake up early'],
        reason: 'DeleteHabitsCommand writes through to the database: the habit '
            'must not come back on the next launch');
  });
}
