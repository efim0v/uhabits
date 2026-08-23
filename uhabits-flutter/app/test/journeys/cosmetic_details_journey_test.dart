/// Journey: the four measurements a user sees but no journey ever measured.
///
/// The fourth audit pass found these by reading the Kotlin views next to the
/// port's widgets — an icon at half its upstream size, glyphs that stopped
/// following the OS text-scale setting, dead space under the last habit row,
/// and a Unit field that capitalises what upstream leaves alone. All four are
/// reachable from `main()`, so all four are asserted here on the *running*
/// app: `AppScope.boot()` + `UhabitsApp`, then taps.
///
/// Rules:
///
///  * `audit4.empty-list-star-beach-icon-is#1`
///  * `audit4.check-mark-cell-glyphs-no-longer#1`
///  * `audit4.habit-list-keeps-88dp-of-dead#1`
///  * `audit4.the-unit-field-auto-capitalizes-which#1`
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/entry_button_views.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits_core/uhabits_core.dart'
    show FontAwesome, LocalDate, getToday;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_cosmetic_details');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  Future<void> launchToList(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
  }

  // -------------------------------------------------------------------------
  // audit4.empty-list-star-beach-icon-is
  // -------------------------------------------------------------------------

  testWidgets('the empty list draws its star at the size Android draws it',
      (WidgetTester tester) async {
    await launchToList(tester);

    final Finder icon = find.text(FontAwesome.starHalfO);
    expect(icon, findsOneWidget,
        reason: 'the precondition: a fresh install shows EmptyListView');
    expect(
      tester.widget<Text>(icon).style?.fontSize,
      80.0,
      reason: 'audit4.empty-list-star-beach-icon-is#1 — `sp(40f)` is '
          '`InterfaceUtils.spToPixels`, which already returns *pixels*; the '
          'result is then handed to `TextView.textSize`, whose one-argument '
          'setter re-reads it as SP. The glyph is scaled twice and lands at '
          'roughly 80dp — which is why the checked-in baseline '
          'EmptyListView/empty.png shows the half-star spanning ~85dp of a '
          '200dp view. 40 is half the icon the Android user sees.',
    );
  });

  // -------------------------------------------------------------------------
  // audit4.check-mark-cell-glyphs-no-longer
  // -------------------------------------------------------------------------

  /// The check-mark cell the running app built for [date].
  CheckmarkButtonView cell(WidgetTester tester, String habit, LocalDate date) {
    final EntryButton button = tester.widget<EntryButton>(find.descendant(
      of: habitRow(habit),
      matching: find.byKey(entryButtonKey(date)),
    ));
    return button.view as CheckmarkButtonView;
  }

  testWidgets('check-mark glyphs follow the OS font-size setting',
      (WidgetTester tester) async {
    // The accessibility text-scale slider, two notches up. This is the only
    // thing the journey changes: everything else is the shipped app.
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await launchToList(tester);
    await createHabit(tester, name: 'Wake up early');

    expect(
      cell(tester, 'Wake up early', getToday()).fontSize,
      14.0 * 1.5,
      reason: 'audit4.check-mark-cell-glyphs-no-longer#1 — `paint.textSize = '
          'sp(14f)` goes through spToPixels, so the check, cross, skip and '
          'question-mark glyphs of every habit row grow and shrink with '
          "Android's system font-size / accessibility text-scale setting. A "
          'cell pinned to 14 logical pixels ignores the setting entirely.',
    );
  });

  testWidgets('and stay at their declared size when the user has not moved it',
      (WidgetTester tester) async {
    await launchToList(tester);
    await createHabit(tester, name: 'Wake up early');

    expect(
      cell(tester, 'Wake up early', getToday()).fontSize,
      14.0,
      reason: 'audit4.check-mark-cell-glyphs-no-longer#1 — at fontScale 1 '
          'spToPixels is the identity in dp terms, so the glyph is the 14sp '
          'of `list-habits.checkmark-button-rendering#4`.',
    );
  });

  // -------------------------------------------------------------------------
  // audit4.habit-list-keeps-88dp-of-dead
  // -------------------------------------------------------------------------

  testWidgets('the last habit row sits against the navigation bar',
      (WidgetTester tester) async {
    // A gesture bar: 96 physical pixels at the tester's 3.0 device pixel
    // ratio, i.e. 32dp of systemBars inset.
    tester.view.padding = const FakeViewPadding(bottom: 96);
    addTearDown(tester.view.reset);

    await launchToList(tester);
    await createHabit(tester, name: 'Meditate');

    final double bottomInset =
        MediaQuery.paddingOf(tester.element(find.byType(HabitListScreen)))
            .bottom;
    expect(bottomInset, 32.0,
        reason: 'the precondition: the window reports a 32dp bottom inset');

    final ReorderableListView list = tester.widget<ReorderableListView>(
      find.byKey(HabitListScreen.habitCardListKey),
    );
    expect(
      list.padding?.resolve(TextDirection.ltr).bottom,
      bottomInset,
      reason: 'audit4.habit-list-keeps-88dp-of-dead#1 — `applyBottomInset()` '
          'adds one ItemDecoration that gives the LAST item '
          '`outRect.bottom = systemBarsInsets.bottom` and nothing more '
          '(`list-habits.screen-layout#8`). The extra 88dp was room for a '
          'floating action button this port does not have, so it is 88dp of '
          'dead space under the last card.',
    );
  });

  // -------------------------------------------------------------------------
  // audit4.the-unit-field-auto-capitalizes-which
  // -------------------------------------------------------------------------

  testWidgets('the Unit field types the hint back exactly as typed',
      (WidgetTester tester) async {
    await launchToList(tester);
    await tapListMenuItem(tester, ListHabitsMenuItems.createHabit);
    await tester.tap(find.byKey(EditHabitScreen.measurableTypeCardKey));
    await tester.pumpAndSettle();

    TextField field(Key key) => tester.widget<TextField>(find.descendant(
          of: find.byKey(key),
          matching: find.byType(TextField),
        ));

    expect(
      field(EditHabitScreen.unitFieldKey).textCapitalization,
      TextCapitalization.none,
      reason: 'audit4.the-unit-field-auto-capitalizes-which#1 — unitInput '
          'declares no android:inputType at all, so it is a plain text field '
          'with no capitalization mode: typing the hinted example produces '
          '"miles", lower case, and that is the string the Target card and '
          'the list subtitle render next to the number.',
    );

    // The three siblings that *do* declare textCapSentences|textMultiLine —
    // the fix must not take the capitalisation off them.
    for (final Key key in <Key>[
      EditHabitScreen.nameFieldKey,
      EditHabitScreen.questionFieldKey,
      EditHabitScreen.notesFieldKey,
    ]) {
      expect(
        field(key).textCapitalization,
        TextCapitalization.sentences,
        reason: 'audit4.the-unit-field-auto-capitalizes-which#1 — nameInput, '
            'questionInput and notesInput each declare '
            'android:inputType="textCapSentences|textMultiLine"; the Unit '
            'field is the sibling that declares nothing.',
      );
    }
  });
}
