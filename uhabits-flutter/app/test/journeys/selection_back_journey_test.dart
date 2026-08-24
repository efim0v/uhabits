/// Journey: the Android system Back button on the habit list.
///
/// `audit3.the-android-system-back-button-does`. Upstream the contextual
/// action bar is an `ActionMode`, and the system Back key is one of the things
/// that destroys it —
/// `ListHabitsSelectionMenu.onDestroyActionMode(mode)` ->
/// `listController.value.onSelectionFinished()` -> `cancelSelection()`
/// (`list-habits.selection-mode#6`, "e.g. system back"). The activity itself
/// never sees that Back press: the ActionMode swallows it, so the user stays
/// on the habit list with the normal toolbar restored.
///
/// With no selection there is no ActionMode, so Back reaches
/// `ListHabitsActivity` and finishes it — the app closes. Both halves are
/// asserted here, because a screen that simply refuses every Back press would
/// satisfy the first one while trapping the user in the app.
///
/// The press is delivered the way the platform delivers it, through
/// [pressBack] — a `popRoute` call on `flutter/navigation`. Whether the app
/// then asks to be closed is read off `flutter/platform`: an unhandled
/// `popRoute` makes `WidgetsBinding.handlePopRoute` call
/// `SystemNavigator.pop()`, which is `Activity.finish()`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  /// Everything the app sent down `flutter/platform`, which is where
  /// `SystemNavigator.pop()` — the framework's `Activity.finish()` — goes.
  late List<MethodCall> platformCalls;

  TestDefaultBinaryMessenger messenger() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    device = TestDevice.create('uhabits_journey_selection_back');
    platformCalls = <MethodCall>[];
    messenger().setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        platformCalls.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    messenger().setMockMethodCallHandler(SystemChannels.platform, null);
    app.dispose();
    device.dispose();
  });

  /// True once the app has asked the system to close it.
  bool appAskedToClose() => platformCalls
      .any((MethodCall call) => call.method == 'SystemNavigator.pop');

  Future<void> launchWithHabits(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Wake up early');
    await createHabit(tester, name: 'Track time');
    // Whatever the launch itself sent down the platform channel is not the
    // subject; only what a Back press sends is.
    platformCalls.clear();
  }

  testWidgets('the contextual bar recolours itself when selection starts',
      (WidgetTester tester) async {
    await launchWithHabits(tester);

    final Color toolbar = tester
        .widget<AppBar>(find.descendant(
            of: find.byType(ListHabitsMenu), matching: find.byType(AppBar)))
        .backgroundColor!;

    await longPressHabit(tester, 'Track time');

    final Color contextual = tester
        .widget<AppBar>(find.descendant(
            of: find.byType(ListHabitsSelectionMenu),
            matching: find.byType(AppBar)))
        .backgroundColor!;

    expect(contextual, isNot(toolbar),
        reason: 'audit14.selection-bar-keeps-the-toolbar-colour#1 — AppCompat '
            "paints the contextual bar from ?attr/actionModeBackground, so it "
            'is visibly a different bar from the toolbar it covers. Asserting '
            'this through the running screen rather than on the theme, because '
            'a token nothing reads is the defect this port keeps finding.');
    expect(contextual, const Color(0xFF616161),
        reason: 'audit14.selection-bar-keeps-the-toolbar-colour#1 — '
            '@color/grey_700, the light theme value.');
  });

  testWidgets('Back cancels selection mode instead of closing the app',
      (WidgetTester tester) async {
    await launchWithHabits(tester);

    await longPressHabit(tester, 'Track time');
    expect(find.byType(ListHabitsSelectionMenu), findsOneWidget,
        reason: 'list-habits.selection-mode#3: a long press starts the '
            'contextual action bar');

    await pressBack(tester);

    expect(appAskedToClose(), isFalse,
        reason: 'audit3.the-android-system-back-button-does#1: with a habit '
            'selected the Back press is swallowed by the contextual action '
            'bar, so ListHabitsActivity never finishes — the user stays in '
            'the app');
    expect(find.byType(ListHabitsSelectionMenu), findsNothing,
        reason: 'audit3.the-android-system-back-button-does#1: Back destroys '
            'the contextual action bar');
    expect(find.byType(ListHabitsMenu), findsOneWidget,
        reason: 'audit3.the-android-system-back-button-does#1: destroying the '
            'action mode restores the normal toolbar');
    verifyDisplaysText(stringsOf(tester).mainActivityTitle,
        reason: 'audit3.the-android-system-back-button-does#1: the normal '
            'toolbar is back, titled with the app name');
    expect(app.scope.adapter.isSelectionEmpty, isTrue,
        reason: 'audit3.the-android-system-back-button-does#1: '
            'onDestroyActionMode -> onSelectionFinished -> cancelSelection() '
            'clears the selection and returns the controller to NormalMode');
    expect(
      tester
          .widgetList<HabitCard>(find.byType(HabitCard))
          .any((HabitCard card) => card.isSelected),
      isFalse,
      reason: 'audit3.the-android-system-back-button-does#1: no row is left '
          'drawn as selected (list-habits.selection-mode#10)',
    );
  });

  testWidgets('the list is back in NormalMode: a tap opens the habit again',
      (WidgetTester tester) async {
    await launchWithHabits(tester);

    await longPressHabit(tester, 'Track time');
    await pressBack(tester);

    // `list-habits.selection-mode#2`: NormalMode single tap opens the detail
    // screen. If Back had only hidden the bar without resetting the mode, this
    // tap would toggle the selection instead.
    await tapHabit(tester, 'Track time');

    expect(find.byType(ShowHabitScreen), findsOneWidget,
        reason: 'audit3.the-android-system-back-button-does#1: Back returns '
            'the controller to NormalMode, so the next tap opens the habit '
            'instead of toggling its selection');
    expect(find.byType(ListHabitsSelectionMenu), findsNothing,
        reason: 'audit3.the-android-system-back-button-does#1: the tap after '
            'Back is a NormalMode tap, not a selection toggle');
  });

  testWidgets('Back with nothing selected still closes the app',
      (WidgetTester tester) async {
    await launchWithHabits(tester);

    expect(find.byType(ListHabitsSelectionMenu), findsNothing,
        reason: 'nothing is selected yet');

    await pressBack(tester);

    expect(appAskedToClose(), isTrue,
        reason: 'audit3.the-android-system-back-button-does#1: only the '
            'contextual action bar swallows Back. With no selection Back '
            'reaches ListHabitsActivity, which is the root activity, and '
            'finishes it — the app must not trap the user.');
  });
}
