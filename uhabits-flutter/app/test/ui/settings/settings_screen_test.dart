// ignore_for_file: implementation_imports

/// Widget tests for the port of
/// uhabits-android/src/main/res/xml/preferences.xml plus
/// uhabits-android/.../activities/settings/{SettingsActivity,SettingsFragment}.kt.
///
/// Every expectation quotes the parity rule id it stands for.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/settings_model.dart';
import 'package:uhabits/ui/settings/data_actions.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/time/date_utils.dart' show computeToday;
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  var databaseIndex = 0;

  setUp(() {
    // AppScope.open stamps today; nothing may read a habit before it has.
    core.resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_settings_screen');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope(PreferencesStorage storage) {
    final database =
        AppDatabase.openAndMigrate('${tempDir.path}/habits${databaseIndex++}.db');
    final scope = AppScope.open(database, preferencesStorage: storage);
    scopes.add(scope);
    return scope;
  }

  /// Pushes the settings screen on top of an empty route, so the rows that port
  /// `setResult(...); finish()` can be observed as a route result.
  Future<_Harness> open(
    WidgetTester tester, {
    PreferencesStorage? storage,
    AppScope? scope,
    Locale? locale,
    bool wireLinks = true,
  }) async {
    final resolvedStorage = storage ?? MemoryStorage();
    final resolvedScope = scope ?? openScope(resolvedStorage);
    final harness = _Harness(resolvedScope, resolvedStorage);
    // The whole preference screen is one scroll view; a tall surface keeps
    // every row hit-testable without scrolling between assertions.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: const Scaffold(body: SizedBox.shrink()),
    ));
    navigatorKey.currentState!
        .push<SettingsResult>(MaterialPageRoute<SettingsResult>(
      builder: (_) => Provider<AppScope>.value(
        value: resolvedScope,
        child: SettingsScreen(
          storage: resolvedStorage,
          onOpenUrl: wireLinks ? (url) => harness.openedUrls.add(url) : null,
          onShowAbout: wireLinks ? () => harness.aboutShown = true : null,
        ),
      ),
    ))
        .then((value) {
      harness.popped = true;
      harness.result = value;
    });
    await tester.pumpAndSettle();
    return harness;
  }

  List<String> rowKeys(WidgetTester tester) => tester
      .widgetList<SettingsRow>(find.byType(SettingsRow))
      .map((row) => row.preferenceKey)
      .toList();

  List<String> categoryTitles(WidgetTester tester) => tester
      .widgetList<SettingsCategoryHeader>(find.byType(SettingsCategoryHeader))
      .map((header) => header.title)
      .toList();

  Finder rowNamed(String key) => find.byKey(ValueKey<String>(key));

  Future<void> tapSwitch(WidgetTester tester, String key) async {
    await tester.tap(
      find.descendant(of: rowNamed(key), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String key) => tester
      .widget<Switch>(
        find.descendant(of: rowNamed(key), matching: find.byType(Switch)),
      )
      .value;

  // -------------------------------------------------------------------
  // settings.screen.structure
  // -------------------------------------------------------------------

  group('structure', () {
    testWidgets('settings.screen.structure#1 — toolbar titled Settings, '
        'coloured with PaletteColor(11)', (tester) async {
      await open(tester);
      expect(find.text('Settings'), findsOneWidget,
          reason: 'settings.screen.structure#1');
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final expected = core.LightTheme().colorOf(const core.PaletteColor(11));
      expect(
        appBar.backgroundColor,
        Color.fromARGB(
          (expected.alpha * 255).round(),
          (expected.red * 255).round(),
          (expected.green * 255).round(),
          (expected.blue * 255).round(),
        ),
      );
    });

    testWidgets(
        'settings.screen.structure#2 — six categories, in order, with the '
        'original titles', (tester) async {
      final storage = MemoryStorage();
      final scope = openScope(storage);
      // devCategory only renders for a developer (structure#7).
      scope.preferences.isDeveloper = true;
      await open(tester, storage: storage, scope: scope);
      expect(categoryTitles(tester), <String>[
        'Interface',
        'Reminder',
        'Database',
        'Troubleshooting',
        'Links',
        'Development',
      ], reason: 'settings.screen.structure#2');
    });

    testWidgets(
        'settings.screen.structure#3 — the Interface rows keep their XML order',
        (tester) async {
      await open(tester);
      expect(rowKeys(tester).take(9), <String>[
        'pref_short_toggle',
        'pref_midnight_delay',
        'pref_skip_enabled',
        'pref_unknown_enabled',
        'pref_checkmark_reverse_order',
        'pref_pure_black',
        'pref_disable_animation',
        'pref_widget_opacity',
        'pref_first_weekday',
      ], reason: 'settings.screen.structure#3');
    });

    testWidgets(
        'settings.screen.structure#7 / settings.screen.developer-category#1 — '
        'the Development category is hidden while isDeveloper is false',
        (tester) async {
      await open(tester);
      expect(categoryTitles(tester), isNot(contains('Development')));
      expect(rowKeys(tester), isNot(contains('pref_developer')));
    });

    testWidgets(
        'settings.screen.structure#6 — the screen follows Preferences while it '
        'is mounted', (tester) async {
      final harness = await open(tester);
      expect(switchValue(tester, 'pref_skip_enabled'), isFalse);
      harness.scope.preferences.areQuestionMarksEnabled = true;
      await tester.pumpAndSettle();
      expect(switchValue(tester, 'pref_unknown_enabled'), isTrue);
    });

    testWidgets(
        'settings.screen.structure#4 — no row reserves leading icon space',
        (tester) async {
      final storage = MemoryStorage();
      final scope = openScope(storage);
      scope.preferences.isDeveloper = true;
      await open(tester, storage: storage, scope: scope);

      final tiles = tester.widgetList<ListTile>(
        find.descendant(of: find.byType(SettingsRow), matching: find.byType(ListTile)),
      );
      expect(tiles, isNotEmpty,
          reason: 'settings.screen.structure#4 — precondition: the rows are '
              'ListTiles');
      for (final tile in tiles) {
        expect(tile.leading, isNull,
            reason: 'settings.screen.structure#4 — every preference sets '
                'app:iconSpaceReserved="false", so nothing indents for an '
                'icon');
        expect(
          tile.contentPadding,
          const EdgeInsets.symmetric(horizontal: 16),
          reason: 'settings.screen.structure#4 — and the content starts at the '
              'same inset on every row, switches included',
        );
      }
    });

    testWidgets(
        'settings.screen.structure#5 — the screen paints its own background '
        'from the theme', (tester) async {
      await open(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      final expected = core.LightTheme().appBackgroundColor;
      expect(
        scaffold.backgroundColor,
        Color.fromARGB(
          (expected.alpha * 255).round(),
          (expected.red * 255).round(),
          (expected.green * 255).round(),
          (expected.blue * 255).round(),
        ),
        reason: 'settings.screen.structure#5 — SettingsFragment paints its '
            'root view in onViewCreated instead of leaving it transparent; '
            'the port paints the core theme background, which is what '
            'R.attr.contrast0 resolves to',
      );
    });

    testWidgets(
        'settings.preferences.card-spinner-positions#5 and '
        'settings.preferences.show-archived-completed#3 — four preferences '
        'have no settings row at all', (tester) async {
      final storage = MemoryStorage();
      final scope = openScope(storage);
      scope.preferences.isDeveloper = true;
      await open(tester, storage: storage, scope: scope);

      final keys = rowKeys(tester);
      for (final key in <String>[
        'pref_score_view_interval',
        'pref_bar_card_bool_spinner',
        'pref_bar_card_numerical_spinner',
      ]) {
        expect(keys, isNot(contains(key)),
            reason: 'settings.preferences.card-spinner-positions#5 — the three '
                'spinner positions have no settings-screen row; they are '
                'written by the chart spinners on the habit detail screen');
      }
      for (final key in <String>['pref_show_archived', 'pref_show_completed']) {
        expect(keys, isNot(contains(key)),
            reason: 'settings.preferences.show-archived-completed#3 — these '
                'have no settings-screen row either; they are toggled from '
                'the main-screen filter menu');
      }
    });

    testWidgets(
        'settings.preferences.midnight-delay#5 — the day is stamped once at '
        'startup, so the switch only takes effect on the next launch',
        (tester) async {
      final storage = MemoryStorage()
        ..putBoolean('pref_midnight_delay', true);
      final scope = openScope(storage);
      expect(scope.preferences.midnightDelayHours, 3,
          reason: 'settings.preferences.midnight-delay#5');
      expect(core.getToday(), computeToday(3, 0),
          reason: 'settings.preferences.midnight-delay#5 — '
              'HabitsApplication.onCreate calls '
              'setToday(computeToday(preferences.midnightDelayHours, 0)) at '
              'startup');

      final harness = await open(tester, storage: storage, scope: scope);
      final stamped = core.getToday();
      await tapSwitch(tester, 'pref_midnight_delay');
      expect(harness.scope.preferences.midnightDelayHours, 0,
          reason: 'settings.preferences.midnight-delay#5');
      expect(core.getToday(), stamped,
          reason: 'settings.preferences.midnight-delay#5 — flipping the '
              'switch does not re-date the world: the change only takes '
              'effect after a restart or a midnight-timer tick');
    });
  });

  // -------------------------------------------------------------------
  // Interface category
  // -------------------------------------------------------------------

  group('interface category', () {
    testWidgets(
        'settings.preferences.short-toggle#1,#2 — first row of the Interface '
        'category, default false, writes pref_short_toggle', (tester) async {
      final harness = await open(tester);
      expect(rowKeys(tester).first, 'pref_short_toggle',
          reason: 'settings.preferences.short-toggle#2 — the first '
              'SwitchPreferenceCompat of the Interface category');
      expect(find.text('Toggle with short press'), findsOneWidget,
          reason: 'settings.preferences.short-toggle#2');
      expect(
        find.text('Put checkmarks with a single tap instead of press-and-hold.'),
        findsOneWidget,
        reason: 'settings.preferences.short-toggle#2',
      );
      expect(switchValue(tester, 'pref_short_toggle'), isFalse,
          reason: 'settings.preferences.short-toggle#2 — default false');
      expect(harness.scope.preferences.isShortToggleEnabled, isFalse);
      await tapSwitch(tester, 'pref_short_toggle');
      expect(harness.scope.preferences.isShortToggleEnabled, isTrue);
      expect(harness.storage.getBoolean('pref_short_toggle', false), isTrue);
    });

    testWidgets(
        'settings.preferences.midnight-delay#1,#2,#3,#4 — writes '
        'pref_midnight_delay, fires onCheckmarkSequenceChanged and moves '
        'midnightDelayHours to 3', (tester) async {
      final harness = await open(tester);
      final listener = _RecordingListener();
      harness.scope.preferences.addListener(listener);
      expect(find.text('Extend day a few hours past midnight'), findsOneWidget,
          reason: 'settings.preferences.midnight-delay#4');
      expect(
        find.text(
          'Wait until 3:00 AM to show a new day. Useful if you typically go to '
          'sleep after midnight. Requires app restart.',
        ),
        findsOneWidget,
        reason: 'settings.preferences.midnight-delay#4',
      );
      expect(switchValue(tester, 'pref_midnight_delay'), isFalse,
          reason: 'settings.preferences.midnight-delay#4 — default false');
      expect(harness.scope.preferences.midnightDelayHours, 0);
      await tapSwitch(tester, 'pref_midnight_delay');
      expect(harness.storage.getBoolean('pref_midnight_delay', false), isTrue);
      expect(harness.scope.preferences.midnightDelayHours, 3);
      expect(listener.checkmarkSequenceChanged, 1);
    });

    testWidgets(
        'settings.preferences.skip-enabled#1,#2 — writes pref_skip_enabled',
        (tester) async {
      final harness = await open(tester);
      expect(find.text('Enable skip days'), findsOneWidget,
          reason: 'settings.preferences.skip-enabled#2');
      expect(
        find.text(
          'Toggle twice to add a skip instead of a checkmark. Skips keep your '
          "score unchanged and don't break your streak.",
        ),
        findsOneWidget,
        reason: 'settings.preferences.skip-enabled#2',
      );
      expect(switchValue(tester, 'pref_skip_enabled'), isFalse,
          reason: 'settings.preferences.skip-enabled#2 — default false');
      await tapSwitch(tester, 'pref_skip_enabled');
      expect(harness.scope.preferences.isSkipEnabled, isTrue);
      expect(harness.storage.getBoolean('pref_skip_enabled', false), isTrue);
    });

    testWidgets(
        'settings.preferences.question-marks#1,#2,#3 — writes '
        'pref_unknown_enabled and fires onQuestionMarksChanged',
        (tester) async {
      final harness = await open(tester);
      final listener = _RecordingListener();
      harness.scope.preferences.addListener(listener);
      expect(find.text('Show question marks for missing data'), findsOneWidget,
          reason: 'settings.preferences.question-marks#3');
      expect(
        find.text(
          'Differentiate days without data from actual lapses. To enter a '
          'lapse, toggle twice.',
        ),
        findsOneWidget,
        reason: 'settings.preferences.question-marks#3',
      );
      expect(switchValue(tester, 'pref_unknown_enabled'), isFalse,
          reason: 'settings.preferences.question-marks#3 — default false');
      await tapSwitch(tester, 'pref_unknown_enabled');
      expect(harness.scope.preferences.areQuestionMarksEnabled, isTrue);
      expect(harness.storage.getBoolean('pref_unknown_enabled', false), isTrue);
      expect(listener.questionMarksChanged, 1);
    });

    testWidgets(
        'settings.preferences.checkmark-reverse-order#1,#3,#4 — writes '
        'pref_checkmark_reverse_order and fires onCheckmarkSequenceChanged',
        (tester) async {
      final harness = await open(tester);
      final listener = _RecordingListener();
      harness.scope.preferences.addListener(listener);
      expect(find.text('Reverse order of days'), findsOneWidget,
          reason: 'settings.preferences.checkmark-reverse-order#4');
      expect(
        find.text('Show days in reverse order on the main screen.'),
        findsOneWidget,
        reason: 'settings.preferences.checkmark-reverse-order#4',
      );
      expect(switchValue(tester, 'pref_checkmark_reverse_order'), isFalse,
          reason: 'settings.preferences.checkmark-reverse-order#4 — '
              'default false');
      await tapSwitch(tester, 'pref_checkmark_reverse_order');
      expect(harness.scope.preferences.isCheckmarkSequenceReversed, isTrue);
      expect(
        harness.storage.getBoolean('pref_checkmark_reverse_order', false),
        isTrue,
      );
      expect(listener.checkmarkSequenceChanged, 1);
    });

    testWidgets(
        'settings.theme.pure-black#1,#2 — writes pref_pure_black from the '
        'Interface category', (tester) async {
      final harness = await open(tester);
      expect(find.text('Use pure black in dark theme'), findsOneWidget,
          reason: 'settings.theme.pure-black#2');
      expect(
        find.text(
          'Replaces gray backgrounds with pure black in dark theme. Reduces '
          'battery usage in phones with AMOLED display.',
        ),
        findsOneWidget,
        reason: 'settings.theme.pure-black#2',
      );
      expect(switchValue(tester, 'pref_pure_black'), isFalse,
          reason: 'settings.theme.pure-black#2 — default false');
      await tapSwitch(tester, 'pref_pure_black');
      expect(harness.scope.preferences.isPureBlackEnabled, isTrue);
      expect(harness.storage.getBoolean('pref_pure_black', false), isTrue);
    });

    testWidgets(
        'settings.preferences.disable-animations#1,#2 — writes '
        'pref_disable_animation', (tester) async {
      final harness = await open(tester);
      expect(find.text('Disable animations'), findsOneWidget,
          reason: 'settings.preferences.disable-animations#2');
      expect(
        find.text('Disable confetti animation after adding a checkmark.'),
        findsOneWidget,
        reason: 'settings.preferences.disable-animations#2',
      );
      expect(switchValue(tester, 'pref_disable_animation'), isFalse,
          reason: 'settings.preferences.disable-animations#2 — default false');
      await tapSwitch(tester, 'pref_disable_animation');
      expect(harness.scope.preferences.isConfettiAnimationDisabled, isTrue);
      expect(harness.storage.getBoolean('pref_disable_animation', false), isTrue);
    });

    testWidgets(
        'settings.preferences.widget-opacity#1,#2,#3 — list row with the six '
        'index-aligned entries, writing the value as a string',
        (tester) async {
      expect(SettingsModel.widgetOpacityLabels,
          <String>['100%', '80%', '60%', '40%', '20%', '0%'],
          reason: 'settings.preferences.widget-opacity#3');
      expect(SettingsModel.widgetOpacityValues,
          <String>['255', '204', '153', '102', '51', '0'],
          reason: 'settings.preferences.widget-opacity#3 — index-aligned with '
              'the labels');

      final harness = await open(tester);
      expect(find.text('Widget opacity'), findsOneWidget,
          reason: 'settings.preferences.widget-opacity#2');
      expect(
        find.text(
          'Makes widgets more transparent or more opaque in your home screen.',
        ),
        findsOneWidget,
        reason: 'settings.preferences.widget-opacity#2',
      );
      expect(harness.scope.preferences.widgetOpacity, 255,
          reason: 'settings.preferences.widget-opacity#2 — '
              'android:defaultValue "255"');

      await tester.tap(rowNamed('pref_widget_opacity'));
      await tester.pumpAndSettle();
      final options = tester
          .widgetList<ListTile>(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(ListTile),
          ))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(options, SettingsModel.widgetOpacityLabels,
          reason: 'settings.preferences.widget-opacity#3');

      await tester.tap(find.text('60%'));
      await tester.pumpAndSettle();
      expect(harness.storage.getString('pref_widget_opacity', ''), '153',
          reason: 'settings.preferences.widget-opacity#3 — "60%" is the third '
              'label and "153" the third value');
      expect(harness.scope.preferences.widgetOpacity, 153);
    });

    testWidgets(
        'settings.preferences.first-weekday#8,#9,#10 — list row titled "First '
        'day of the week", summarised with dayNames[firstWeekday % 7]',
        (tester) async {
      await open(tester);
      expect(find.text('First day of the week'), findsOneWidget,
          reason: 'settings.preferences.first-weekday#8');
      expect(SettingsModel.firstWeekdayValues, <int>[7, 1, 2, 3, 4, 5, 6],
          reason: 'settings.preferences.first-weekday#9 — entryValues are '
              'exactly ["7","1","2","3","4","5","6"]');
      // The locale hook defaults to 1 (Sunday); dayNames starts at Saturday, so
      // the summary is dayNames[1 % 7] == "Sunday".
      expect(
        find.descendant(
          of: rowNamed('pref_first_weekday'),
          matching: find.text('Sunday'),
        ),
        findsOneWidget,
        reason: 'settings.preferences.first-weekday#10 — the row summary is '
            'dayNames[currentFirstWeekday % 7], and SUNDAY gives index 1',
      );

      await tester.tap(rowNamed('pref_first_weekday'));
      await tester.pumpAndSettle();
      final options = tester
          .widgetList<ListTile>(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(ListTile),
          ))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(options, <String>[
        'Saturday',
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
      ], reason: 'settings.preferences.first-weekday#9 — the entries are the '
          'seven localized long weekday names starting at Saturday, i.e. '
          'longWeekdayNames(DayOfWeek.SATURDAY)');
    });

    testWidgets(
        'settings.preferences.first-weekday#1,#2,#9,#10 — picking a day writes '
        'the Calendar-convention number and re-summarises the row',
        (tester) async {
      final harness = await open(tester);
      await tester.tap(rowNamed('pref_first_weekday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monday'));
      await tester.pumpAndSettle();

      expect(harness.storage.getString('pref_first_weekday', ''), '2',
          reason: 'settings.preferences.first-weekday#9 — "Monday" is the '
              'third entry, whose value is "2"');
      expect(harness.scope.preferences.firstWeekday, core.DayOfWeek.monday,
          reason: 'settings.preferences.first-weekday#9');
      expect(
        find.descendant(
          of: rowNamed('pref_first_weekday'),
          matching: find.text('Monday'),
        ),
        findsOneWidget,
        reason: 'settings.preferences.first-weekday#10 — MONDAY gives '
            'dayNames[2] == "Monday"',
      );

      await tester.tap(rowNamed('pref_first_weekday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saturday'));
      await tester.pumpAndSettle();
      expect(harness.storage.getString('pref_first_weekday', ''), '7',
          reason: 'settings.preferences.first-weekday#9 — "Saturday" is the '
              'first entry, whose value is "7"');
      expect(harness.scope.preferences.firstWeekday, core.DayOfWeek.saturday,
          reason: 'settings.preferences.first-weekday#9');
      // dayNames[7 % 7] == dayNames[0] == "Saturday".
      expect(
        find.descendant(
          of: rowNamed('pref_first_weekday'),
          matching: find.text('Saturday'),
        ),
        findsOneWidget,
        reason: 'settings.preferences.first-weekday#10 — 7 % 7 == 0, so the '
            'summary wraps back onto the first name',
      );
    });

    testWidgets(
        'settings.preferences.first-weekday#11 — the row\'s default is the '
        'current weekday, recomputed every time the screen rebuilds',
        (tester) async {
      const String rule =
          'settings.preferences.first-weekday#11 — updateWeekdayPreference() '
          'also calls setDefaultValue(currentFirstWeekday.toString()) each time '
          'it runs, and it runs on every onResume and on every '
          'SharedPreferences change. The XML carries no android:defaultValue '
          '(#8), so this is the only thing that gives the row a default at all: '
          'whatever the weekday currently resolves to, including the value the '
          'locale supplies while pref_first_weekday is unset. The port has no '
          'ListPreference to configure — the row derives everything from '
          'model.firstWeekday on each build, which is the same "recomputed, '
          'never captured" property.';

      final int savedHook = getFirstWeekdayNumberAccordingToLocale();
      addTearDown(
          () => getFirstWeekdayNumberAccordingToLocale = () => savedHook);

      final harness = await open(tester);
      expect(harness.storage.getString('pref_first_weekday', 'unset'), 'unset',
          reason: '$rule Nothing has been stored, so only the default is '
              'speaking.');

      Future<int?> checkedValue() async {
        await tester.tap(rowNamed('pref_first_weekday'));
        await tester.pumpAndSettle();
        final ListTile checked = tester
            .widgetList<ListTile>(find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(ListTile),
            ))
            .firstWhere((tile) => tile.trailing != null);
        final int value =
            int.parse((checked.key! as ValueKey<Object?>).value.toString().split('-').last);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        return value;
      }

      expect(await checkedValue(), 1,
          reason: '$rule The default the dialog opens on is the current '
              'weekday — Sunday, from the locale hook.');

      // "on every SharedPreferences change": the locale moves and an unrelated
      // preference is written, which is what makes the fragment re-run
      // updateWeekdayPreference. The row follows.
      getFirstWeekdayNumberAccordingToLocale = () => 2;
      await tapSwitch(tester, 'pref_short_toggle');

      expect(
        find.descendant(
          of: rowNamed('pref_first_weekday'),
          matching: find.text('Monday'),
        ),
        findsOneWidget,
        reason: '$rule The summary was recomputed rather than captured once at '
            'first build.',
      );
      expect(await checkedValue(), 2,
          reason: '$rule …and so was the default the dialog opens on.');

      // Once a value really is stored it wins over the recomputed default,
      // exactly as setDefaultValue does for a ListPreference whose key exists.
      await tester.tap(rowNamed('pref_first_weekday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wednesday'));
      await tester.pumpAndSettle();
      getFirstWeekdayNumberAccordingToLocale = () => 6;
      await tapSwitch(tester, 'pref_short_toggle');
      expect(await checkedValue(), 4,
          reason: '$rule A stored value is not overwritten by the default, '
              'however often the default is set.');
    });
  });

  // -------------------------------------------------------------------
  // Reminder category
  // -------------------------------------------------------------------

  group('reminder category', () {
    testWidgets(
        'settings.screen.reminder-category#9 — three rows, in the XML order',
        (tester) async {
      await open(tester);
      expect(
        rowKeys(tester).skip(9).take(3),
        <String>['reminderSound', 'pref_sticky_notifications', 'reminderCustomize'],
      );
      expect(find.text('Reminder sound'), findsOneWidget);
      expect(find.text('Customize notifications'), findsOneWidget);
      expect(
        find.text(
          'Change sound, vibration, light and other notification settings',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'the ringtone picker and the notification-channel intent are Android '
        'only, so both rows render disabled', (tester) async {
      await open(tester);
      expect(tester.widget<SettingsRow>(rowNamed('reminderSound')).enabled,
          isFalse);
      expect(tester.widget<SettingsRow>(rowNamed('reminderCustomize')).enabled,
          isFalse);
      expect(
        find.descendant(
          of: rowNamed('reminderSound'),
          matching: find.text('No app was found to support this action'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'settings.screen.reminder-category#7 — the "reminderCustomize" row and '
        'its two strings', (tester) async {
      await open(tester);

      expect(rowKeys(tester), contains('reminderCustomize'),
          reason: 'settings.screen.reminder-category#7: Row '
              '"reminderCustomize"');
      expect(find.text('Customize notifications'), findsOneWidget,
          reason: 'settings.screen.reminder-category#7: title "Customize '
              'notifications"');
      expect(
        find.descendant(
          of: rowNamed('reminderCustomize'),
          matching: find.text(
            'Change sound, vibration, light and other notification settings',
          ),
        ),
        findsOneWidget,
        reason: 'settings.screen.reminder-category#7: summary "Change sound, '
            'vibration, light and other notification settings"',
      );
      // The other half of the rule — createAndroidNotificationChannel followed
      // by Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS with EXTRA_APP_PACKAGE
      // and EXTRA_CHANNEL_ID = "REMINDERS" — is an Android intent with no
      // cross-platform counterpart, so the row carries no action at all.
      expect(tester.widget<SettingsRow>(rowNamed('reminderCustomize')).onTap,
          isNull,
          reason: 'settings.screen.reminder-category#7: the click that would '
              'create the channel and open its system settings screen has no '
              'counterpart here, so nothing is wired to the row');
    });

    testWidgets(
        'settings.reminder-sound-row-hidden#2,#3 — the ringtone picker is a '
        'dead path and pref_ringtone_uri is never written', (tester) async {
      final harness = await open(tester);

      final row = tester.widget<SettingsRow>(rowNamed('reminderSound'));
      expect(row.onTap, isNull,
          reason: 'settings.reminder-sound-row-hidden#2: the '
              "onPreferenceTreeClick showRingtonePicker() branch and "
              'updateRingtoneDescription() are dead paths — nothing on this '
              'row can launch ACTION_RINGTONE_PICKER');
      expect(row.enabled, isFalse,
          reason: 'settings.reminder-sound-row-hidden#2: RingtoneManager'
              '.update() is never invoked');

      // Tapping it — the gesture that upstream would have opened the picker
      // with, request code 1 — changes nothing at all.
      await tester.tap(rowNamed('reminderSound'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(harness.popped, isFalse,
          reason: 'settings.reminder-sound-row-hidden#2: the dead branch is '
              'not reachable through the row');
      expect(harness.storage.getString('pref_ringtone_uri', ''), '',
          reason: 'settings.reminder-sound-row-hidden#3: consequently the '
              'SharedPreferences key pref_ringtone_uri is never written');
      // The empty-string value is what would make getURI() return null and
      // getName() return "None"; there is no way to reach it from the UI, so
      // the key is not merely empty, it is absent.
      expect(harness.storage.getString('pref_ringtone_uri', 'absent'), 'absent',
          reason: "settings.reminder-sound-row-hidden#3: the 'silent' state "
              '(empty-string value) is unreachable through the UI');
    });

    testWidgets(
        'settings.preferences.sticky-notifications#1,#2,#3 — writes '
        'pref_sticky_notifications and always fires onNotificationsChanged',
        (tester) async {
      final harness = await open(tester);
      final listener = _RecordingListener();
      harness.scope.preferences.addListener(listener);
      expect(find.text('Make notifications sticky'), findsOneWidget,
          reason: 'settings.preferences.sticky-notifications#3 and '
              'settings.screen.reminder-category#6');
      expect(
        find.text('Prevents notifications from being swiped away.'),
        findsOneWidget,
        reason: 'settings.preferences.sticky-notifications#3 and '
            'settings.screen.reminder-category#6',
      );
      expect(harness.scope.preferences.shouldMakeNotificationsSticky(), isFalse,
          reason: 'settings.preferences.sticky-notifications#3 and '
              'settings.screen.reminder-category#6 — default false');
      expect(switchValue(tester, 'pref_sticky_notifications'), isFalse,
          reason: 'settings.screen.reminder-category#6 — a '
              'SwitchPreferenceCompat, off by default');
      await tapSwitch(tester, 'pref_sticky_notifications');
      expect(harness.scope.preferences.shouldMakeNotificationsSticky(), isTrue);
      expect(
        harness.storage.getBoolean('pref_sticky_notifications', false),
        isTrue,
      );
      expect(listener.notificationsChanged, 1);
    });
  });

  // -------------------------------------------------------------------
  // Database category
  // -------------------------------------------------------------------

  group('database category', () {
    testWidgets(
        'settings.screen.database-category#1,#2,#3,#6,#12 — four rows in order '
        'with their titles and summaries', (tester) async {
      await open(tester);
      expect(
        rowKeys(tester).skip(12).take(4),
        <String>['exportDB', 'exportCSV', 'importData', 'publicBackupFolder'],
        reason: 'settings.screen.database-category#12 — the Database category '
            'holds exactly these four rows, in this order',
      );
      expect(find.text('Export full backup'), findsOneWidget,
          reason: 'settings.screen.database-category#1');
      expect(
        find.text(
          'Generates a file that contains all your data. This file can be '
          'imported back.',
        ),
        findsOneWidget,
        reason: 'settings.screen.database-category#1',
      );
      expect(find.text('Export as CSV'), findsOneWidget,
          reason: 'settings.screen.database-category#2');
      expect(
        find.text(
          'Generates files that can be opened by spreadsheet software such as '
          'Microsoft Excel or OpenOffice Calc. This file cannot be imported '
          'back.',
        ),
        findsOneWidget,
        reason: 'settings.screen.database-category#2',
      );
      expect(find.text('Import data'), findsOneWidget,
          reason: 'settings.screen.database-category#3');
      expect(
        find.text(
          'Supports full backups exported by this app, as well as files '
          'generated by Tickmate, HabitBull or Rewire. See FAQ for more '
          'information.',
        ),
        findsOneWidget,
        reason: 'settings.screen.database-category#3',
      );
      expect(find.text('Select public backup folder'), findsOneWidget,
          reason: 'settings.screen.database-category#6');
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text('No folder selected'),
        ),
        findsOneWidget,
        reason: 'settings.screen.database-category#6 — the summary while the '
            '"publicBackupFolder" key is unset',
      );
      expect(
        tester.widget<SettingsRow>(rowNamed('publicBackupFolder')).enabled,
        isFalse,
      );
    });

    testWidgets(
        'io.public-backup-folder-pref#1 — key, title and default summary',
        (tester) async {
      await open(tester);

      expect(rowKeys(tester), contains('publicBackupFolder'),
          reason: "io.public-backup-folder-pref#1: The preference lives in "
              "Settings > Database with key 'publicBackupFolder'");
      expect(
        rowKeys(tester).indexOf('publicBackupFolder'),
        greaterThan(rowKeys(tester).indexOf('importData')),
        reason: 'io.public-backup-folder-pref#1: it sits in the Database '
            'category, after the three export/import rows',
      );
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text('Select public backup folder'),
        ),
        findsOneWidget,
        reason: "io.public-backup-folder-pref#1: title 'Select public backup "
            "folder'",
      );
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text('No folder selected'),
        ),
        findsOneWidget,
        reason: "io.public-backup-folder-pref#1: default summary 'No folder "
            "selected'",
      );
    });

    testWidgets(
        'io.public-backup-folder-pref#7 — a stored folder is shown as the '
        'summary, an unset key as the "no folder" string', (tester) async {
      final storage = MemoryStorage();
      const String tree =
          'content://com.android.externalstorage.documents/tree/primary%3ALoop';
      storage.putString('publicBackupFolder', tree);

      final harness = await open(tester, storage: storage);

      expect(SettingsModel(harness.scope, storage: storage).publicBackupFolder,
          tree,
          reason: 'io.public-backup-folder-pref#7: the raw getter still holds '
              'the stored URI string, which is what the picker would write');
      // The summary is the human-readable path derived from the tree document
      // id — `SettingsFragment.fullPathFor`, ported in lib/state/
      // settings_model.dart and asserted in detail under
      // settings.screen.database-category#9.
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text('$primaryExternalStorageDir/Loop'),
        ),
        findsOneWidget,
        reason: 'io.public-backup-folder-pref#7: the human-readable path when '
            'it can be resolved',
      );
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text(tree),
        ),
        findsNothing,
        reason: 'io.public-backup-folder-pref#7: the raw URI string is the '
            'fallback, not the first choice',
      );
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text('No folder selected'),
        ),
        findsNothing,
        reason: 'io.public-backup-folder-pref#7: the "no public backup folder '
            'selected" string is only used when the key is unset',
      );
    });

    testWidgets(
        'io.public-backup-folder-pref#7 — an unset key falls back to the '
        '"no folder selected" string', (tester) async {
      final storage = MemoryStorage();
      final harness = await open(tester, storage: storage);

      expect(SettingsModel(harness.scope, storage: storage).publicBackupFolder,
          isNull,
          reason: 'io.public-backup-folder-pref#7: when the key is unset the '
              'summary is the "no public backup folder selected" string');
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text('No folder selected'),
        ),
        findsOneWidget,
        reason: 'io.public-backup-folder-pref#7: when the key is unset the '
            'summary is the "no public backup folder selected" string',
      );
    });

    testWidgets(
        'settings.screen.database-category#4,#13 — exportDB closes the screen '
        'with result 103', (tester) async {
      final harness = await open(tester);
      await tester.tap(rowNamed('exportDB'));
      await tester.pumpAndSettle();
      expect(harness.popped, isTrue,
          reason: 'settings.screen.database-category#4 — the row calls '
              'setResult(code) and then finish(); the Flutter screen pops');
      expect(harness.result, SettingsResult.exportDb,
          reason: 'settings.screen.database-category#4');
      expect(harness.result!.code, 103,
          reason: 'settings.screen.database-category#13 — RESULT_EXPORT_DB');
    });

    testWidgets(
        'settings.screen.database-category#4,#13 — exportCSV closes the screen '
        'with result 102', (tester) async {
      final harness = await open(tester);
      await tester.tap(rowNamed('exportCSV'));
      await tester.pumpAndSettle();
      expect(harness.result, SettingsResult.exportCsv,
          reason: 'settings.screen.database-category#4');
      expect(harness.result!.code, 102,
          reason: 'settings.screen.database-category#13 — RESULT_EXPORT_CSV');
    });

    testWidgets(
        'settings.screen.database-category#4,#13 — importData closes the screen '
        'with result 101', (tester) async {
      final harness = await open(tester);
      await tester.tap(rowNamed('importData'));
      await tester.pumpAndSettle();
      expect(harness.result, SettingsResult.importData,
          reason: 'settings.screen.database-category#4');
      expect(harness.result!.code, 101,
          reason: 'settings.screen.database-category#13 — RESULT_IMPORT_DATA');
    });

    testWidgets(
        'settings.screen.database-category#15 and '
        'settings.screen.troubleshooting-and-links#3 — the six messages keep '
        'their strings', (tester) async {
      await open(tester);
      final l10n = L10n.of(tester.element(find.byType(SettingsRow).first));

      expect(
        dataActionMessageText(l10n, DataActionMessage.couldNotExport),
        'Failed to export data.',
        reason: 'settings.screen.database-category#15 — COULD_NOT_EXPORT',
      );
      expect(
        dataActionMessageText(l10n, DataActionMessage.importSuccessful),
        'Habits imported successfully.',
        reason: 'settings.screen.database-category#15 — IMPORT_SUCCESSFUL',
      );
      expect(
        dataActionMessageText(l10n, DataActionMessage.importFailed),
        'Failed to import data.',
        reason: 'settings.screen.database-category#15 — IMPORT_FAILED',
      );
      expect(
        dataActionMessageText(l10n, DataActionMessage.fileNotRecognized),
        'File not recognized.',
        reason: 'settings.screen.database-category#15 — FILE_NOT_RECOGNIZED',
      );
      expect(
        l10n.databaseRepaired,
        'Database repaired.',
        reason: 'settings.screen.database-category#15 and '
            'settings.screen.troubleshooting-and-links#3 — DATABASE_REPAIRED '
            'is what a finished repair shows',
      );
      expect(
        l10n.bugReportFailed,
        'Failed to generate bug report.',
        reason: 'settings.screen.database-category#15 — '
            'COULD_NOT_GENERATE_BUG_REPORT',
      );
      // The repair row is the one that reaches that message: it closes the
      // screen with 105, and ListHabitsBehavior.onRepairDB shows
      // DATABASE_REPAIRED when the background repair finishes
      // (asserted in list_habits_behavior_test.dart).
      expect(
        tester.widget<SettingsRow>(rowNamed('repairDB')).title,
        'Repair database',
        reason: 'settings.screen.troubleshooting-and-links#3',
      );
    });
  });

  // -------------------------------------------------------------------
  // Troubleshooting and Links
  // -------------------------------------------------------------------

  group('troubleshooting and links', () {
    testWidgets(
        'settings.screen.troubleshooting-and-links#1 — exactly two rows, '
        'closing with 104 and 105', (tester) async {
      var harness = await open(tester);
      expect(rowKeys(tester).skip(16).take(2), <String>['bugReport', 'repairDB']);
      expect(find.text('Generate bug report'), findsOneWidget);
      expect(find.text('Repair database'), findsOneWidget);
      await tester.tap(rowNamed('bugReport'));
      await tester.pumpAndSettle();
      expect(harness.result, SettingsResult.bugReport);
      expect(harness.result!.code, 104,
          reason: 'settings.screen.database-category#13 — RESULT_BUG_REPORT');

      harness = await open(tester);
      await tester.tap(rowNamed('repairDB'));
      await tester.pumpAndSettle();
      expect(harness.result, SettingsResult.repairDb);
      expect(harness.result!.code, 105,
          reason: 'settings.screen.database-category#13 — RESULT_REPAIR_DB');
    });

    testWidgets(
        'settings.screen.troubleshooting-and-links#4,#5 — three link rows in '
        'order, opening the original URLs', (tester) async {
      final harness = await open(tester);
      expect(
        rowKeys(tester).skip(18).take(3),
        <String>['help', 'rateApp', 'about'],
      );
      expect(find.text('Help & FAQ'), findsOneWidget);
      expect(find.text('Rate this app on Google Play'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);

      await tester.tap(rowNamed('help'));
      await tester.pumpAndSettle();
      await tester.tap(rowNamed('rateApp'));
      await tester.pumpAndSettle();
      expect(harness.openedUrls, <String>[
        'http://loophabits.org/faq.html',
        'market://details?id=org.isoron.uhabits',
      ]);

      await tester.tap(rowNamed('about'));
      await tester.pumpAndSettle();
      expect(harness.aboutShown, isTrue);
    });

    testWidgets(
        'settings.screen.troubleshooting-and-links#2 — the report is mailed to '
        'dev@loophabits.org, subject "Bug Report - Loop Habit Tracker"',
        (tester) async {
      const String rule =
          'settings.screen.troubleshooting-and-links#2 — Bug reports are '
          'emailed to "dev@loophabits.org" with subject "Bug Report - Loop '
          'Habit Tracker"; if BugReporter.getBugReport() throws, the list '
          'screen shows the message for COULD_NOT_GENERATE_BUG_REPORT instead.';

      await open(tester);
      final l10n = L10n.of(tester.element(find.byType(SettingsRow).first));

      expect(SettingsScreen.bugReportTo, 'dev@loophabits.org',
          reason: '$rule @string/bugReportTo.');
      expect(SettingsScreen.bugReportSubject, 'Bug Report - Loop Habit Tracker',
          reason: '$rule @string/bugReportSubject.');

      // showSendEmailScreen(to, subject, content) as a mailto URI: EXTRA_EMAIL
      // is the recipient, EXTRA_SUBJECT and EXTRA_TEXT the two parameters.
      final Uri mail = SettingsScreen.bugReportMailto('log line 1\nline 2');
      expect(mail.scheme, 'mailto', reason: rule);
      expect(mail.path, 'dev@loophabits.org', reason: rule);
      expect(mail.queryParameters['subject'], 'Bug Report - Loop Habit Tracker',
          reason: rule);
      expect(mail.queryParameters['body'], 'log line 1\nline 2',
          reason: '$rule The report itself is the body, as EXTRA_TEXT was.');

      // The other branch of the same rule: when the report cannot be produced,
      // nothing is mailed and COULD_NOT_GENERATE_BUG_REPORT is shown instead.
      // ListHabitsBehavior.onSendBugReport is what chooses between the two, and
      // that choice is asserted in
      // packages/uhabits_core/test/ui/screens/habits/list/
      // list_habits_behavior_test.dart; what belongs to this screen is the
      // string the message resolves to.
      expect(l10n.bugReportFailed, 'Failed to generate bug report.',
          reason: '$rule …the message for COULD_NOT_GENERATE_BUG_REPORT.');
      expect(
        tester.widget<SettingsRow>(rowNamed('bugReport')).title,
        'Generate bug report',
        reason: '$rule The row that starts the whole flow.',
      );
    });

    testWidgets(
        'settings.screen.troubleshooting-and-links#6 — with no URL handler '
        'wired the link rows are disabled instead of crashing', (tester) async {
      await open(tester, wireLinks: false);
      expect(tester.widget<SettingsRow>(rowNamed('help')).enabled, isFalse);
      expect(tester.widget<SettingsRow>(rowNamed('rateApp')).enabled, isFalse);
      expect(tester.widget<SettingsRow>(rowNamed('about')).enabled, isFalse);
    });
  });

  // -------------------------------------------------------------------
  // Development category
  // -------------------------------------------------------------------

  group('development category', () {
    Future<_Harness> openAsDeveloper(WidgetTester tester,
        {Locale? locale}) async {
      final storage = MemoryStorage();
      final scope = openScope(storage);
      scope.preferences.isDeveloper = true;
      return open(tester, storage: storage, scope: scope, locale: locale);
    }

    testWidgets(
        'settings.screen.developer-category#1,#2,#3,#4 / '
        'settings.developer.sync-preference-rows#1,#2,#3,#4 — four rows with '
        'their defaults', (tester) async {
      await openAsDeveloper(tester);
      expect(rowKeys(tester).skip(21).take(4), <String>[
        'pref_developer',
        'pref_sync_base_url',
        'pref_sync_key',
        'pref_encryption_key',
      ], reason: 'settings.developer.sync-preference-rows#1 — four rows, not '
          'one');
      expect(find.text('Enable developer mode'), findsOneWidget,
          reason: 'settings.screen.developer-category#2 and '
              'settings.developer.sync-preference-rows#2');
      expect(find.text('Sync server'), findsOneWidget,
          reason: 'settings.screen.developer-category#3 and '
              'settings.developer.sync-preference-rows#3');
      expect(find.text('https://sync.loophabits.org'), findsOneWidget,
          reason: 'settings.screen.developer-category#3 and '
              'settings.developer.sync-preference-rows#3 — the default value '
              'is @string/syncBaseURL');
      expect(SettingsModel.defaultSyncBaseUrl, 'https://sync.loophabits.org',
          reason: 'settings.developer.sync-preference-rows#3');
      expect(find.text('Sync key'), findsOneWidget,
          reason: 'settings.screen.developer-category#4 and '
              'settings.developer.sync-preference-rows#4');
      expect(find.text('Encryption key'), findsOneWidget,
          reason: 'settings.screen.developer-category#5 and '
              'settings.developer.sync-preference-rows#4');
      expect(switchValue(tester, 'pref_developer'), isTrue,
          reason: 'settings.screen.developer-category#2');
    });

    testWidgets(
        'settings.developer.sync-preference-rows#5,#6 — editing a sync row '
        'writes the raw key and nothing else reads it', (tester) async {
      final harness = await openAsDeveloper(tester);
      expect(harness.storage.getString('pref_sync_key', 'unset'), 'unset',
          reason: 'settings.screen.developer-category#4 and '
              'settings.developer.sync-preference-rows#4 — pref_sync_key '
              'starts empty');
      expect(harness.storage.getString('pref_encryption_key', 'unset'), 'unset',
          reason: 'settings.screen.developer-category#5 and '
              'settings.developer.sync-preference-rows#4 — and so does '
              'pref_encryption_key');

      await tester.tap(rowNamed('pref_sync_key'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(harness.storage.getString('pref_sync_key', ''), 'abc123',
          reason: 'settings.developer.sync-preference-rows#5 — editing writes '
              'the raw string into the preference store');
      expect(
        find.descendant(
          of: rowNamed('pref_sync_key'),
          matching: find.text('abc123'),
        ),
        findsOneWidget,
      );

      // Nothing outside the settings screen ever reads the three keys: they
      // are not on Preferences, and the app's behaviour does not change.
      for (final key in <String>[
        'pref_sync_base_url',
        'pref_sync_key',
        'pref_encryption_key',
      ]) {
        harness.storage.putString(key, 'poisoned');
      }
      expect(harness.scope.preferences.theme, SettingsModel.themeAutomatic,
          reason: 'settings.screen.developer-category#6 and '
              'settings.developer.sync-preference-rows#6 — the three sync '
              'keys are inert: no core preference and no behaviour reads '
              'them, so poisoning them changes nothing');
      expect(harness.scope.preferences.isDeveloper, isTrue,
          reason: 'settings.screen.developer-category#6 and '
              'settings.developer.sync-preference-rows#6');
      expect(harness.scope.habitList.isEmpty, isTrue,
          reason: 'settings.screen.developer-category#6 and '
              'settings.developer.sync-preference-rows#6 — there is no sync '
              'feature in this fork, so nothing was fetched');
    });

    testWidgets(
        'settings.developer.sync-preference-rows#7 — the Development titles are '
        'hardcoded English, never translated', (tester) async {
      await openAsDeveloper(tester, locale: const Locale('ru'));
      // The neighbouring translated category proves the locale really applied.
      expect(find.text('Интерфейс'), findsOneWidget);
      expect(categoryTitles(tester).last, 'Development');
      expect(find.text('Enable developer mode'), findsOneWidget);
      expect(find.text('Sync server'), findsOneWidget);
      expect(find.text('Sync key'), findsOneWidget);
      expect(find.text('Encryption key'), findsOneWidget);
    });

    testWidgets(
        'settings.screen.developer-category#1 — visibility is recomputed on '
        'entry, so switching developer mode off keeps the category until the '
        'screen is reopened', (tester) async {
      final harness = await openAsDeveloper(tester);
      await tapSwitch(tester, 'pref_developer');
      expect(harness.scope.preferences.isDeveloper, isFalse);
      expect(categoryTitles(tester), contains('Development'));

      await open(tester, storage: harness.storage, scope: harness.scope);
      expect(categoryTitles(tester), isNot(contains('Development')));
    });
  });

  // -------------------------------------------------------------------
  // Theme modes, read off the same Preferences the rows write
  // -------------------------------------------------------------------

  group('theme modes', () {
    SettingsModel modelWith(int theme, {bool pureBlack = false}) {
      final storage = MemoryStorage();
      final scope = openScope(storage);
      scope.preferences.theme = theme;
      scope.preferences.isPureBlackEnabled = pureBlack;
      return SettingsModel(scope, storage: storage);
    }

    test('settings.theme.theme-modes#1 — the three constants and the default',
        () {
      expect(SettingsModel.themeAutomatic, 0);
      expect(SettingsModel.themeDark, 1);
      expect(SettingsModel.themeLight, 2);
      final storage = MemoryStorage();
      expect(openScope(storage).preferences.theme, SettingsModel.themeAutomatic);
    });

    test('settings.theme.theme-modes#2,#3 — isNightMode truth table', () {
      final automatic = modelWith(SettingsModel.themeAutomatic);
      expect(automatic.isNightMode(SettingsModel.themeLight), isFalse);
      expect(automatic.isNightMode(SettingsModel.themeDark), isTrue);

      final light = modelWith(SettingsModel.themeLight);
      expect(light.isNightMode(SettingsModel.themeLight), isFalse);
      expect(light.isNightMode(SettingsModel.themeDark), isFalse);

      final dark = modelWith(SettingsModel.themeDark);
      expect(dark.isNightMode(SettingsModel.themeLight), isTrue);
      expect(dark.isNightMode(SettingsModel.themeDark), isTrue);
    });

    test(
        'settings.theme.theme-modes#4 / settings.theme.pure-black#3,#4 — apply() '
        'picks pure black only in night mode', () {
      expect(
        modelWith(SettingsModel.themeDark, pureBlack: true)
            .currentTheme(SettingsModel.themeLight),
        isA<core.PureBlackTheme>(),
      );
      expect(
        modelWith(SettingsModel.themeDark)
            .currentTheme(SettingsModel.themeLight),
        isA<core.DarkTheme>(),
      );
      expect(
        modelWith(SettingsModel.themeLight, pureBlack: true)
            .currentTheme(SettingsModel.themeDark),
        isA<core.LightTheme>(),
      );
    });

    test('settings.theme.toggle-night-mode#3,#6 — toggleNightMode truth table',
        () {
      void check(int userTheme, int systemTheme, int expected) {
        final model = modelWith(userTheme)..toggleNightMode(systemTheme);
        expect(model.theme, expected,
            reason: 'user=$userTheme system=$systemTheme');
      }

      check(SettingsModel.themeAutomatic, SettingsModel.themeLight,
          SettingsModel.themeDark);
      check(SettingsModel.themeAutomatic, SettingsModel.themeDark,
          SettingsModel.themeLight);
      check(SettingsModel.themeLight, SettingsModel.themeLight,
          SettingsModel.themeDark);
      check(SettingsModel.themeLight, SettingsModel.themeDark,
          SettingsModel.themeAutomatic);
      check(SettingsModel.themeDark, SettingsModel.themeLight,
          SettingsModel.themeAutomatic);
      check(SettingsModel.themeDark, SettingsModel.themeDark,
          SettingsModel.themeLight);
    });
  });

  // -------------------------------------------------------------------
  // The reminder and troubleshooting rows, seen from the reminders/io
  // features of the ledger rather than from settings.*
  // -------------------------------------------------------------------

  group('reminder and troubleshooting rows', () {
    testWidgets(
        'notifications.sticky-and-dismiss#7 — a switch titled "Make '
        'notifications sticky", defaulting to off', (tester) async {
      final harness = await open(tester);

      expect(find.text('Make notifications sticky'), findsOneWidget,
          reason: 'notifications.sticky-and-dismiss#7: the settings screen '
              'exposes this as a SwitchPreferenceCompat with that title');
      expect(
        find.text('Prevents notifications from being swiped away.'),
        findsOneWidget,
        reason: 'notifications.sticky-and-dismiss#7: with that summary',
      );
      expect(switchValue(tester, 'pref_sticky_notifications'), isFalse,
          reason: 'notifications.sticky-and-dismiss#7: default false');
      expect(harness.scope.preferences.shouldMakeNotificationsSticky(), isFalse,
          reason: 'notifications.sticky-and-dismiss#7: default false');
    });

    testWidgets(
        'notifications.sticky-and-dismiss#8 — the dead "notification light" '
        'string is not a preference', (tester) async {
      await open(tester);

      expect(rowKeys(tester), isNot(contains('led_notifications')),
          reason: 'notifications.sticky-and-dismiss#8: a "Notification light" '
              '(led_notifications) string exists in the Android resources but '
              'is not wired to any preference or code — it is dead and must '
              'not be ported as a feature');
      expect(find.textContaining('Notification light'), findsNothing,
          reason: 'notifications.sticky-and-dismiss#8');
    });

    testWidgets(
        'notifications.sound#7 — the ringtone picker is unreachable from the '
        'UI in this build', (tester) async {
      await open(tester);

      final row = tester.widget<SettingsRow>(rowNamed('reminderSound'));
      expect(row.enabled, isFalse,
          reason: 'notifications.sound#7: the "reminderSound" row is not '
              'actionable, so the picker cannot be reached from the UI in '
              'this build even though the plumbing exists elsewhere');
      expect(row.onTap, isNull,
          reason: 'notifications.sound#7: tapping it does nothing');
    });

    testWidgets(
        'io.bug-report-dump#1,#11 — "Generate bug report" lives under '
        'Troubleshooting and closes with 104', (tester) async {
      final harness = await open(tester);

      expect(categoryTitles(tester), contains('Troubleshooting'),
          reason: 'io.bug-report-dump#11: the bug report is reachable from '
              'Settings via the preference under the troubleshooting category');
      expect(rowKeys(tester), contains('bugReport'),
          reason: 'io.bug-report-dump#11: with the key "bugReport"');
      expect(find.text('Generate bug report'), findsOneWidget,
          reason: 'io.bug-report-dump#11: titled @string/generate_bug_report');

      await tester.tap(rowNamed('bugReport'));
      await tester.pumpAndSettle();

      expect(harness.result, SettingsResult.bugReport,
          reason: 'io.bug-report-dump#1: Settings > Troubleshooting > '
              "'Generate bug report' (preference key 'bugReport') returns "
              'RESULT_BUG_REPORT');
      expect(harness.result!.code, 104,
          reason: 'io.bug-report-dump#1: RESULT_BUG_REPORT = 104');
    });
  });

  // -------------------------------------------------------------------
  // Localization rules the settings screen is the evidence for
  // -------------------------------------------------------------------

  group('platform-glue localization', () {
    testWidgets(
        'platform-glue.locale-config#10 — there is no language row; the '
        'system picker is the whole mechanism', (tester) async {
      await open(tester);

      // Not one of the 22 rows offers a language choice, and no message in the
      // catalogue would label one.
      expect(rowKeys(tester).where((key) => key.contains('lang')), isEmpty,
          reason: 'platform-glue.locale-config#10 — There is no in-app '
              'language-selection row in preferences.xml; language selection '
              'is delegated entirely to the Android 13+ per-app language '
              'system setting driven by this locale-config. Flutter resolves '
              'the locale from the platform the same way, through '
              'MaterialApp.supportedLocales.');
      expect(find.text('Language'), findsNothing,
          reason: 'platform-glue.locale-config#10: nor any row titled so');
      expect(categoryTitles(tester).where((t) => t.contains('Language')),
          isEmpty,
          reason: 'platform-glue.locale-config#10: nor a category');
    });

    testWidgets(
        'platform-glue.locale-config#11 — Development and "Enable developer '
        'mode" stay English while everything around them translates',
        (tester) async {
      final storage = MemoryStorage();
      final scope = openScope(storage);
      scope.preferences.isDeveloper = true;
      await open(
        tester,
        storage: storage,
        scope: scope,
        locale: const Locale('ru'),
      );

      expect(categoryTitles(tester), contains('Development'),
          reason: 'platform-glue.locale-config#11 — All user-facing settings '
              'strings are localized resources except the Development category '
              'title "Development" and its row title "Enable developer mode", '
              'which are hard-coded English in preferences.xml.');
      expect(find.text('Enable developer mode'), findsOneWidget,
          reason: 'platform-glue.locale-config#11: the row title too');

      // The categories on either side of it do translate, so this is the
      // exception the rule describes and not a locale that simply failed to
      // load.
      expect(categoryTitles(tester), containsAll(<String>[
        'Напоминание',
        'База данных',
        'Устранение неполадок',
        'Ссылки',
      ]), reason: 'platform-glue.locale-config#11: everything else is a '
          'localized resource');
    });

    testWidgets(
        'platform-glue.localized-arrays#5 — the widget opacity entries and '
        'values stay index-aligned, defaulting to "255"', (tester) async {
      expect(SettingsModel.widgetOpacityLabels,
          <String>['100%', '80%', '60%', '40%', '20%', '0%'],
          reason: 'platform-glue.localized-arrays#5 — widget_opacity_entries '
              'are ["100%", "80%", "60%", "40%", "20%", "0%"] index-aligned '
              'with widget_opacity_values [255, 204, 153, 102, 51, 0]; the '
              'default persisted value is the string "255".');
      expect(SettingsModel.widgetOpacityValues,
          <String>['255', '204', '153', '102', '51', '0'],
          reason: 'platform-glue.localized-arrays#5: the values array');
      expect(SettingsModel.widgetOpacityLabels.length,
          SettingsModel.widgetOpacityValues.length,
          reason: 'platform-glue.localized-arrays#5: index-aligned');

      final harness = await open(tester);
      expect(SettingsModel.widgetOpacityValues.first, '255',
          reason: 'platform-glue.localized-arrays#5: the default persisted '
              'value is the string "255", not the int — it is the first entry '
              'of the values array, which is what android:defaultValue names');
      expect(harness.scope.preferences.widgetOpacity, 255,
          reason: 'platform-glue.localized-arrays#5: and an untouched '
              'preference reads back as that value');
      await tester.tap(rowNamed('pref_widget_opacity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100%'));
      await tester.pumpAndSettle();
      expect(harness.storage.getString('pref_widget_opacity', ''), '255',
          reason: 'platform-glue.localized-arrays#5: picking the first entry '
              'writes the string "255", not the int');

      // The labels are percentages, so they are the same in every locale —
      // which is why upstream could get away with translating them.
      await tester.pumpAndSettle();
      for (final String label in SettingsModel.widgetOpacityLabels) {
        expect(int.tryParse(label.replaceAll('%', '')), isNotNull,
            reason: 'platform-glue.localized-arrays#5: every entry is a '
                'percentage of the value beside it ($label)');
      }
      for (var i = 0; i < SettingsModel.widgetOpacityLabels.length; i++) {
        final int percent =
            int.parse(SettingsModel.widgetOpacityLabels[i].replaceAll('%', ''));
        final int alpha = int.parse(SettingsModel.widgetOpacityValues[i]);
        expect((percent * 255 / 100).round(), alpha,
            reason: 'platform-glue.localized-arrays#5: entry $i really is '
                '$percent percent of 255');
      }
    });
  });
}

class _Harness {
  _Harness(this.scope, this.storage);

  final AppScope scope;
  final PreferencesStorage storage;
  final List<String> openedUrls = <String>[];
  bool aboutShown = false;
  bool popped = false;
  SettingsResult? result;
}

class _RecordingListener extends PreferencesListener {
  int checkmarkSequenceChanged = 0;
  int notificationsChanged = 0;
  int questionMarksChanged = 0;

  @override
  void onCheckmarkSequenceChanged() => checkmarkSequenceChanged++;

  @override
  void onNotificationsChanged() => notificationsChanged++;

  @override
  void onQuestionMarksChanged() => questionMarksChanged++;
}
