/// Journey: the user ticks a check-mark and it is still there tomorrow.
///
/// `verify.integration-harness#3`, journey 3 — "tick a checkmark and see the
/// entry persist".
///
/// Upstream this is `HabitsTest.shouldToggleCheckmarksAndUpdateScore`, which
/// long-presses cells on the list and then reads the score off the detail
/// screen. `pref_short_toggle` is off by default, so a *long* press is what
/// toggles and a tap opens the notes editor — the journey uses the gesture the
/// shipped app is configured for, not the one that happens to be easier to
/// drive.
///
/// The persistence half is what makes this a journey rather than a widget
/// test: the app is quit and booted again over the same files, so the entry
/// has to have gone through `CreateRepetitionCommand` -> `CommandRunner` ->
/// `SQLiteEntryList` -> the database file, and come back out of it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/entry_button_views.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits_core/uhabits_core.dart'
    show Entry, Habit, LocalDate, getToday;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_checkmark');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  Future<void> launchWithHabit(WidgetTester tester, String name) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: name);
  }

  /// What the cell for [date] is painting, read off the view the app built.
  int paintedValue(WidgetTester tester, String habit, LocalDate date) {
    final EntryButton button = tester.widget<EntryButton>(find.descendant(
      of: habitRow(habit),
      matching: find.byKey(entryButtonKey(date)),
    ));
    final CheckmarkButtonView view = button.view as CheckmarkButtonView;
    return view.value;
  }

  /// What the database says, read back through the habit the app is showing.
  int storedValue(String habit, LocalDate date) {
    final Habit found = app.scope.habitList
        .toList()
        .firstWhere((Habit h) => h.name == habit);
    return found.computedEntries.get(date).value;
  }

  testWidgets('a long press on today ticks the check-mark',
      (WidgetTester tester) async {
    await launchWithHabit(tester, 'Wake up early');
    final LocalDate today = getToday();

    expect(paintedValue(tester, 'Wake up early', today), Entry.unknown,
        reason: 'the precondition: a brand-new habit has no entry today');

    await toggleCheckmark(tester, 'Wake up early', today);

    expect(paintedValue(tester, 'Wake up early', today), Entry.yesManual,
        reason: 'list-habits.toggle-from-row: CheckmarkButtonView.performToggle '
            'advances the cell to YES_MANUAL and reports it. A cell that '
            'repaints but never reaches a command, or a command with no cell '
            'behind it, is the defect shape this harness exists for.');
    expect(storedValue('Wake up early', today), Entry.yesManual,
        reason: 'and the toggle has to end in a CreateRepetitionCommand: the '
            'painted value alone is optimistic');
  });

  testWidgets('the entry is still there after the app is restarted',
      (WidgetTester tester) async {
    await launchWithHabit(tester, 'Wake up early');
    final LocalDate today = getToday();
    await toggleCheckmark(tester, 'Wake up early', today);
    expect(storedValue('Wake up early', today), Entry.yesManual);

    await app.restart();

    expect(storedValue('Wake up early', today), Entry.yesManual,
        reason: 'verify.integration-harness#3: "tick a checkmark and see the '
            'entry persist". The second boot opens the same database file, so '
            'this value can only have come off the disk.');
    expect(paintedValue(tester, 'Wake up early', today), Entry.yesManual,
        reason: 'and the freshly launched list has to paint it — the cell is '
            'fed from HabitCardListCache, which is filled at startup');
  });

  testWidgets('a second long press clears it again, and that persists too',
      (WidgetTester tester) async {
    await launchWithHabit(tester, 'Wake up early');
    final LocalDate today = getToday();

    await toggleCheckmark(tester, 'Wake up early', today);
    await toggleCheckmark(tester, 'Wake up early', today);

    expect(paintedValue(tester, 'Wake up early', today), Entry.no,
        reason: 'Entry.nextToggleValue with skip and question marks off '
            'cycles YES_MANUAL -> NO');
    await app.restart();
    expect(storedValue('Wake up early', today), Entry.no,
        reason: 'a cleared day is a stored NO, not a missing row: it has to '
            'survive the restart exactly as the tick does');
  });

  testWidgets('a check-mark on an earlier day lands on that day',
      (WidgetTester tester) async {
    await launchWithHabit(tester, 'Wake up early');
    final LocalDate today = getToday();
    final LocalDate twoDaysAgo = today.minus(2);

    await toggleCheckmark(tester, 'Wake up early', twoDaysAgo);
    await app.restart();

    expect(storedValue('Wake up early', twoDaysAgo), Entry.yesManual,
        reason: 'the cell carries its own date into the command — a panel that '
            'always wrote today would pass every single-day test');
    expect(storedValue('Wake up early', today), Entry.unknown,
        reason: 'and today is left alone');
  });
}
