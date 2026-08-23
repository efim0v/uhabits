/// Journey: the user creates a habit and sees it on the list.
///
/// `verify.integration-harness#3`, journey 2 — "create a habit and see it
/// listed".
///
/// This is `HabitsTest.shouldCreateHabit` upstream: `clickMenu(ADD)`,
/// `clickText("Yes or No")`, `typeName`, `typeQuestion`, `typeDescription`,
/// `pickFrequency`, `pickColor`, `clickSave`, `verifyShowsScreen(LIST_HABITS)`,
/// `verifyDisplaysText(name)`.
///
/// Every step is a tap on a widget the running app built for itself. The
/// chain the journey crosses is long and entirely unmocked: toolbar item ->
/// `ListHabitsMenuBehavior.onCreateHabit()` -> `showSelectHabitTypeDialog()`
/// -> `HabitTypeDialog` -> `EditHabitActivity` -> `CreateHabitCommand` ->
/// `CommandRunner` -> `HabitCardListCache` -> the row. A missing callback
/// anywhere along it breaks this test and no other kind of test.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits_core/uhabits_core.dart' show Habit, HabitType;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_create');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  /// A launch that is past the first-run intro, which is journey 1's subject.
  Future<void> launchPastIntro(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
  }

  testWidgets('the toolbar + button opens the habit type chooser',
      (WidgetTester tester) async {
    await launchPastIntro(tester);
    final L10n l10n = stringsOf(tester);

    await tapListMenuItem(tester, ListHabitsMenuItems.createHabit);

    verifyDisplaysText(l10n.yesOrNo,
        reason: 'habit-type-dialog.select-type#1: onCreateHabit() asks the '
            'screen for the type chooser, whose two cards are "Yes or No" and '
            '"Measurable". A + button that opens nothing is the defect shape '
            'this harness exists for.');
    verifyDisplaysText(l10n.measurable, reason: 'the second card');
  });

  testWidgets('choosing "Yes or No" opens the create form',
      (WidgetTester tester) async {
    await launchPastIntro(tester);
    final L10n l10n = stringsOf(tester);

    await tapListMenuItem(tester, ListHabitsMenuItems.createHabit);
    await tester.tap(find.byKey(EditHabitScreen.yesNoTypeCardKey));
    await tester.pumpAndSettle();

    expect(find.byType(EditHabitScreen), findsOneWidget,
        reason: 'habit-type-dialog.select-type#6: each card starts '
            'EditHabitActivity with the type it stands for');
    verifyDisplaysText(l10n.createHabit,
        reason: 'edit-habit.entry-points#2: CREATE mode is titled '
            '"Create habit"');
  });

  testWidgets('a saved habit is listed, and it reached the database',
      (WidgetTester tester) async {
    await launchPastIntro(tester);
    final L10n l10n = stringsOf(tester);
    verifyDisplaysText(l10n.noHabitsFound,
        reason: 'the precondition: nothing on the list yet');

    await createHabit(
      tester,
      name: 'Wake up early',
      question: 'Did you wake up early today?',
      notes: 'this is a test description',
    );

    expect(find.byType(HabitListScreen), findsOneWidget,
        reason: 'clickSave() finishes EditHabitActivity and the list is what '
            'is left');
    verifyDisplaysText('Wake up early',
        reason: 'verify.integration-harness#3: "create a habit and see it '
            'listed". The row is what the user came for.');
    verifyDoesNotDisplayText(l10n.noHabitsFound,
        reason: 'EmptyListView goes away once the list has a habit');

    final Habit saved = app.scope.habitList.getByPosition(0);
    expect(saved.name, 'Wake up early');
    expect(saved.question, 'Did you wake up early today?',
        reason: 'the question the form typed has to be the one the command '
            'wrote');
    expect(saved.description, 'this is a test description');
    expect(saved.type, HabitType.yesNo,
        reason: 'habit-type-dialog.select-type#6: the card that was tapped '
            'decides the type');
  });

  testWidgets('a habit created with a blank description is listed too',
      (WidgetTester tester) async {
    // `HabitsTest.shouldCreateHabitBlankDescription`.
    await launchPastIntro(tester);

    await createHabit(tester, name: 'Meditate', question: 'Did you meditate?');

    verifyDisplaysText('Meditate');
    expect(app.scope.habitList.getByPosition(0).description, '');
  });

  testWidgets('the Measurable card creates a numerical habit',
      (WidgetTester tester) async {
    await launchPastIntro(tester);

    await createHabit(tester, name: 'Run', measurable: true);

    verifyDisplaysText('Run');
    expect(app.scope.habitList.getByPosition(0).type, HabitType.numerical,
        reason: 'habit-type-dialog.select-type#6: the Measurable card carries '
            'HabitType.NUMERICAL into the editor');
  });

  testWidgets('a created habit survives a restart', (WidgetTester tester) async {
    await launchPastIntro(tester);
    await createHabit(tester, name: 'Wake up early');
    verifyDisplaysText('Wake up early');

    await app.restart();

    verifyDisplaysText('Wake up early',
        reason: 'CreateHabitCommand writes through SQLiteHabitList, so the row '
            'has to come back from the file the second boot opens — not from '
            'anything the first launch left in memory');
  });
}
