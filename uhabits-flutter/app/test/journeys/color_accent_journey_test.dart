/// `audit4.coloraccent-aboutscreencolor-is-never-mapped-so` — the blue accent.
///
/// All three Android themes alias `colorAccent` to `?aboutScreenColor`, and
/// under `Theme.MaterialComponents` that one attribute tints every *activated*
/// control: the Settings switches when on, the frequency picker's radio buttons
/// when selected, and (in the light theme) the dialog buttons' text. The port's
/// `appThemeData` mapped `statusBarBackgroundColor` and the default palette
/// colour and stopped — nothing carried `aboutScreenColor` into the widget
/// theme, so every one of those controls fell back to Material's own
/// `colorScheme.primary`, which here is the toolbar grey `#333333`.
///
/// ## Why the journey half is here
///
/// A `ThemeData` assertion proves the mapping exists. It cannot prove the
/// screens the user actually opens are built from that `ThemeData` — the habit
/// list and its header are built from a different one — and "the screens read
/// as one palette" is the sentence the rule ends on. So the switches are found
/// on the running Settings screen and the radios in the frequency dialog the
/// editor opens, both reached from the entry point.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import 'journey.dart';

const String rule =
    'audit4.coloraccent-aboutscreencolor-is-never-mapped-so#1 — All three app '
    'themes alias colorAccent to ?aboutScreenColor. Under '
    'Theme.MaterialComponents that attribute tints every activated control: '
    'the seven SwitchPreferenceCompat switches in Settings are blue when on, '
    'the five radio buttons in the frequency picker are blue when selected, '
    'and the light theme\'s dialog buttons are blue text (the dark themes '
    'override the buttons with DialogButtonStyle/grey_100, but the switch and '
    'radio tint stays blue_300). It is the same blue the About card headers '
    'and the settings category headers use, so the screens read as one '
    'palette.';

/// `@color/blue_800`, `?aboutScreenColor` in `AppBaseTheme`.
const Color blue800 = Color(0xFF1565C0);

/// `@color/blue_300`, `?aboutScreenColor` in `AppBaseThemeDark` — which
/// `AppBaseThemeDark.PureBlack` does not restate, so it inherits it.
const Color blue300 = Color(0xFF64B5F6);

/// `@color/grey_100`, the `android:textColor` of `@style/DialogButtonStyle`.
const Color grey100 = Color(0xFFF5F5F5);

const Set<WidgetState> selected = <WidgetState>{WidgetState.selected};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -----------------------------------------------------------------------
  // The mapping itself
  // -----------------------------------------------------------------------

  group('the accent reaches the widget theme', () {
    void expectAccent(core.Theme theme, Color accent) {
      final ThemeData data = appThemeData(theme);
      final String which = theme.runtimeType.toString();

      expect(data.switchTheme.thumbColor?.resolve(selected), accent,
          reason: '$rule ($which: the switch thumb when on — AppCompat tints '
              'it with colorControlActivated, which colorAccent is)');
      expect(
        data.switchTheme.trackColor?.resolve(selected),
        accent.withValues(alpha: switchTrackOpacity),
        reason: '$rule ($which: and the track is the same colour at the '
            'track drawable\'s ~30% alpha)',
      );
      expect(data.switchTheme.thumbColor?.resolve(<WidgetState>{}), isNull,
          reason: '$rule ($which: colorAccent tints the activated state only; '
              'the unchecked one stays on colorControlNormal)');
      expect(data.radioTheme.fillColor?.resolve(selected), accent,
          reason: '$rule ($which: the radio when selected)');
      expect(data.checkboxTheme.fillColor?.resolve(selected), accent,
          reason: '$rule ($which: colorAccent tints every activated control, '
              'checkboxes included)');
    }

    test('light: blue_800 on switch, radio and dialog button', () {
      expectAccent(core.LightTheme(), blue800);
      expect(
        appThemeData(core.LightTheme())
            .textButtonTheme
            .style
            ?.foregroundColor
            ?.resolve(<WidgetState>{}),
        blue800,
        reason: '$rule The light theme leaves the dialog buttons on '
            'colorAccent, so their text is blue.',
      );
    });

    test('dark: blue_300 on switch and radio, grey_100 on the dialog button',
        () {
      expectAccent(core.DarkTheme(), blue300);
      expect(
        appThemeData(core.DarkTheme())
            .textButtonTheme
            .style
            ?.foregroundColor
            ?.resolve(<WidgetState>{}),
        grey100,
        reason: '$rule buttonBarPositiveButtonStyle and '
            'buttonBarNegativeButtonStyle are overridden with '
            '@style/DialogButtonStyle, whose android:textColor is @color/'
            'grey_100 — the one place the dark themes do NOT use the accent.',
      );
    });

    test('pure black inherits the dark accent, because it restates none', () {
      expectAccent(core.PureBlackTheme(), blue300);
      expect(
        appThemeData(core.PureBlackTheme())
            .textButtonTheme
            .style
            ?.foregroundColor
            ?.resolve(<WidgetState>{}),
        grey100,
        reason: '$rule AppBaseThemeDark.PureBlack overrides neither the '
            'accent nor the two buttonBar styles.',
      );
    });

    test('it is the core theme token, not a literal', () {
      // The rule's last sentence: the same blue the About card headers and the
      // settings category headers use. Those read `theme.aboutScreenColor`
      // directly, so the accent has to be the same token or the screens drift.
      for (final core.Theme theme in <core.Theme>[
        core.LightTheme(),
        core.DarkTheme(),
        core.PureBlackTheme(),
      ]) {
        expect(
          appThemeData(theme).radioTheme.fillColor?.resolve(selected),
          toFlutterColor(theme.aboutScreenColor),
          reason: '$rule (${theme.runtimeType})',
        );
      }
    });
  });

  // -----------------------------------------------------------------------
  // The same attribute, one widget family over: the text caret
  // -----------------------------------------------------------------------

  group('the accent reaches the text-input colours', () {
    test('the caret and the selection handles are colorAccent', () {
      for (final core.Theme theme in <core.Theme>[
        core.LightTheme(),
        core.DarkTheme(),
        core.PureBlackTheme(),
      ]) {
        final ThemeData data = appThemeData(theme);
        final Color accent = toFlutterColor(theme.aboutScreenColor);
        final String which = theme.runtimeType.toString();

        expect(data.textSelectionTheme.cursorColor, accent,
            reason: 'audit12.coloraccent-never-reaches-the-text-input#1 '
                '($which: text_cursor_material carries '
                'android:tint="?attr/colorControlActivated", which AppCompat '
                'resolves from colorAccent)');
        expect(data.textSelectionTheme.selectionHandleColor, accent,
            reason: 'audit12.coloraccent-never-reaches-the-text-input#1 '
                '($which: abc_text_select_handle_* is tinted from the same '
                'attribute)');
      }
    });

    testWidgets('a field on a dark screen resolves a blue_300 caret, not the '
        'toolbar grey', (tester) async {
      // The number popup autofocuses its value field, so in the dark themes
      // the very first thing a measurable-habit tap shows is a caret. Assert
      // the colour EditableText actually resolves: the whole gap was that
      // Flutter DERIVES it from colorScheme.primary when nothing declares it.
      Future<Color> caretUnder(core.Theme theme) async {
        await tester.pumpWidget(MaterialApp(
          theme: appThemeData(theme),
          home: const Scaffold(body: TextField(autofocus: true)),
        ));
        await tester.pumpAndSettle();
        return tester.widget<EditableText>(find.byType(EditableText)).cursorColor;
      }

      expect(await caretUnder(core.LightTheme()), blue800,
          reason: 'audit12.coloraccent-never-reaches-the-text-input#1');
      expect(await caretUnder(core.DarkTheme()), blue300,
          reason: 'audit12.coloraccent-never-reaches-the-text-input#1');
      expect(await caretUnder(core.PureBlackTheme()), blue300,
          reason: 'audit12.coloraccent-never-reaches-the-text-input#1 — '
              'AppBaseThemeDark.PureBlack restates no aboutScreenColor');

      // And it is not the toolbar grey the ColorScheme still carries: that is
      // #333333 in all three themes, invisible on #212121 and on #000000, and
      // exactly equal to the AppBar the search field draws its caret on.
      for (final core.Theme theme in <core.Theme>[
        core.LightTheme(),
        core.DarkTheme(),
        core.PureBlackTheme(),
      ]) {
        expect(appThemeData(theme).textSelectionTheme.cursorColor,
            isNot(appThemeData(theme).colorScheme.primary),
            reason: 'audit12.coloraccent-never-reaches-the-text-input#1 — '
                '(${theme.runtimeType})');
      }
    });
  });

  // -----------------------------------------------------------------------
  // …and reaches the screens that draw those controls
  // -----------------------------------------------------------------------

  group('on the running app', () {
    late TestDevice device;
    late JourneySession app;

    setUp(() {
      device = TestDevice.create('uhabits_journey_accent');
    });

    tearDown(() {
      app.dispose();
      device.dispose();
    });

    Future<void> launch(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      app = JourneySession(tester, device);
      await app.launch();
      await skipIntro(tester);
    }

    /// The `ThemeData` the widget under [finder] is actually built from.
    ThemeData themeAround(WidgetTester tester, Finder finder) =>
        Theme.of(tester.element(finder));

    testWidgets('the Settings switches are blue when on',
        (WidgetTester tester) async {
      await launch(tester);
      await openSettings(tester);

      final Finder switches = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Switch),
      );
      expect(tester.widgetList<Switch>(switches).length, greaterThanOrEqualTo(7),
          reason: '$rule The seven SwitchPreferenceCompat rows.');

      for (final Switch box in tester.widgetList<Switch>(switches)) {
        expect(box.activeThumbColor, isNull,
            reason: '$rule A per-row colour would hide the theme mapping and '
                'leave every other activated control grey.');
      }

      final ThemeData data = themeAround(tester, switches.first);
      expect(data.switchTheme.thumbColor?.resolve(selected), blue800,
          reason: '\$rule The screen the user opens is built from a ThemeData '
              'that carries the accent.');
      expect(
        data.switchTheme.thumbColor?.resolve(selected),
        toFlutterColor(coreThemeOf(tester.element(switches.first))
            .aboutScreenColor),
        reason: '\$rule The same token the category headers above the switches '
            'use, so the screen reads as one palette.',
      );
    });

    testWidgets('the frequency picker radios are blue when selected',
        (WidgetTester tester) async {
      await launch(tester);

      // The editor is where the picker lives: + → Yes or No → Frequency.
      await tapListMenuItem(tester, ListHabitsMenuItems.createHabit);
      await tester.tap(find.byKey(EditHabitScreen.yesNoTypeCardKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EditHabitScreen.frequencyPickerKey));
      await tester.pumpAndSettle();

      final Finder radios = find.byType(Radio<Object?>, skipOffstage: false);
      final Finder anyRadio = find.byWidgetPredicate(
        (Widget w) => w.runtimeType.toString().startsWith('Radio<'),
      );
      expect(anyRadio, findsWidgets,
          reason: '$rule The frequency dialog is five radio rows. ($radios)');

      final ThemeData data = themeAround(tester, anyRadio.first);
      expect(data.radioTheme.fillColor?.resolve(selected), blue800,
          reason: '$rule The dialog inherits the app theme, so the selected '
              'row is blue.');
    });
  });
}
