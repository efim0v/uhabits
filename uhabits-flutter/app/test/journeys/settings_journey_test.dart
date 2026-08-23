/// Journey: the user opens Settings, changes a preference, and the app changes.
///
/// `verify.integration-harness#3`, journey 6 — "open settings and change a
/// preference that repaints the app".
///
/// A preference is only worth anything if the app it configures notices. The
/// two halves below are the two ways it can notice:
///
///  * through `Preferences.Listener` — "Show question marks" reaches
///    `ListHabitsActivity.onQuestionMarksChanged()`, the list refreshes and
///    every unset cell is drawn with a `?` instead of a `✗`;
///  * through the theme — "Use pure black background" is
///    `settings.theme.pure-black#6`: with the theme on Dark, Android restarts
///    the list activity with a fade and the whole app comes back painted in
///    `PureBlackTheme`.
///
/// Both are driven by tapping the row, not by writing the preference: a test
/// that sets `preferences.isPureBlackEnabled` itself proves the theme class
/// works and says nothing about whether any user can get there.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/list/entry_button_views.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/uhabits_core.dart'
    show FontAwesome, LocalDate, getToday;

import 'journey.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDevice device;
  late JourneySession app;

  setUp(() {
    device = TestDevice.create('uhabits_journey_settings');
  });

  tearDown(() {
    app.dispose();
    device.dispose();
  });

  Future<void> launchWithHabit(WidgetTester tester) async {
    app = JourneySession(tester, device);
    await app.launch();
    await skipIntro(tester);
    await createHabit(tester, name: 'Wake up early');
  }

  /// The glyph the cell for [date] is painting, read off the view the running
  /// app built for it.
  String paintedGlyph(WidgetTester tester, String habit, LocalDate date) {
    final EntryButton button = tester.widget<EntryButton>(find.descendant(
      of: habitRow(habit),
      matching: find.byKey(entryButtonKey(date)),
    ));
    return (button.view as CheckmarkButtonView).glyph;
  }

  /// What `MaterialApp.theme` is painting the whole app with.
  Color appBackground(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!
          .scaffoldBackgroundColor;

  testWidgets('the overflow menu opens Settings', (WidgetTester tester) async {
    await launchWithHabit(tester);
    final L10n l10n = stringsOf(tester);

    await openSettings(tester);

    verifyDisplaysText(l10n.settings,
        reason: 'res/menu/list_habits.xml -> SettingsActivity');
    expect(find.byKey(const ValueKey<String>('pref_unknown_enabled')),
        findsOneWidget,
        reason: 'settings.screen.interface-category: the interface category '
            'rows are what the user came for');
  });

  testWidgets('"Show question marks" repaints the list',
      (WidgetTester tester) async {
    await launchWithHabit(tester);
    final LocalDate today = getToday();

    expect(paintedGlyph(tester, 'Wake up early', today), FontAwesome.times,
        reason: 'list-habits.checkmark-button-rendering#3: with question marks '
            'off an unset day is drawn as a cross');

    await openSettings(tester);
    await tapSettingsRow(tester, 'pref_unknown_enabled');
    await pressBack(tester);
    await settleIo(tester);

    expect(find.byType(HabitListScreen), findsOneWidget,
        reason: 'Back closes SettingsActivity');
    expect(paintedGlyph(tester, 'Wake up early', today), FontAwesome.question,
        reason: 'verify.integration-harness#3: "open settings and change a '
            'preference that repaints the app". '
            'ListHabitsActivity is a Preferences.Listener; '
            'onQuestionMarksChanged() refreshes the list, and every unset cell '
            'comes back as a "?". A settings row nothing listens to is the '
            'defect shape this harness exists for.');
  });

  testWidgets('and that preference is still set after a restart',
      (WidgetTester tester) async {
    await launchWithHabit(tester);
    await openSettings(tester);
    await tapSettingsRow(tester, 'pref_unknown_enabled');
    await pressBack(tester);

    await app.restart();

    expect(app.scope.preferences.areQuestionMarksEnabled, isTrue,
        reason: 'settings.preferences.android-storage-bridge: the settings '
            'file is the app\'s SharedPreferences. A switch that forgets '
            'itself on the next launch has not really been changed.');
    expect(paintedGlyph(tester, 'Wake up early', getToday()),
        FontAwesome.question,
        reason: 'and the freshly launched list paints it that way from the '
            'first frame');
  });

  testWidgets('"Use pure black background" repaints the app in dark mode',
      (WidgetTester tester) async {
    // `settings.theme.pure-black#6` only applies in night mode, so the device
    // is put in dark mode the way the OS puts it there.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await launchWithHabit(tester);

    final Color darkBackground = appBackground(tester);
    expect(darkBackground, isNot(const Color(0xFF000000)),
        reason: 'the precondition: pref_theme is automatic and the system is '
            'dark, so the app starts on DarkTheme — which is grey, not black');

    await openSettings(tester);
    await tapSettingsRow(tester, 'pref_pure_black');
    await pressBack(tester);
    await settleIo(tester);

    expect(appBackground(tester), const Color(0xFF000000),
        reason: 'audit3.toggling-use-pure-black-background-in#1: with the theme '
            'on Dark, flipping the switch restarts the list activity with a '
            'fade and the whole app — list, detail screen, editor, toolbars — '
            'comes back painted in PureBlackTheme. In the port the repaint is '
            'in place rather than an activity restart, but the app still has '
            'to come back black: SettingsModel.isPureBlackEnabled writes '
            'Preferences and ThemeModel is the object that actually paints, '
            'so unless the write reaches ThemeModel nothing happens at all.');
    expect(app.scope.preferences.isPureBlackEnabled, isTrue,
        reason: 'and the preference itself is written either way');
  });

  testWidgets('the Settings screen is dismissed without running anything',
      (WidgetTester tester) async {
    // `RESULT_CANCELED`: `onSettingsResult` is never reached, so none of the
    // database rows fire just because settings was open.
    await launchWithHabit(tester);
    await openSettings(tester);
    await pressBack(tester);
    await settleIo(tester);

    expect(find.byType(SettingsScreen), findsNothing);
    // `Backups` is deliberately not checked here: `ListHabitsActivity.onResume`
    // runs `AutoBackup(this).run()`, which writes into that same folder on
    // every launch. `CSV` has no such second writer.
    expect(device.csvDir.existsSync(), isFalse, reason: 'no export ran');
    expect(device.sharedFiles, isEmpty, reason: 'and no share sheet opened');
    expect(device.launchedUrls, isEmpty,
        reason: 'and no ACTION_VIEW was started either — the bug-report row is '
            'part of the same `when` block');
  });
}
