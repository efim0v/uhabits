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
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
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
      expect(find.text('Settings'), findsOneWidget);
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
      ]);
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
      ]);
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
  });

  // -------------------------------------------------------------------
  // Interface category
  // -------------------------------------------------------------------

  group('interface category', () {
    testWidgets(
        'settings.preferences.short-toggle#1,#2 — first row of the Interface '
        'category, default false, writes pref_short_toggle', (tester) async {
      final harness = await open(tester);
      expect(rowKeys(tester).first, 'pref_short_toggle');
      expect(find.text('Toggle with short press'), findsOneWidget);
      expect(
        find.text('Put checkmarks with a single tap instead of press-and-hold.'),
        findsOneWidget,
      );
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
      expect(find.text('Extend day a few hours past midnight'), findsOneWidget);
      expect(
        find.text(
          'Wait until 3:00 AM to show a new day. Useful if you typically go to '
          'sleep after midnight. Requires app restart.',
        ),
        findsOneWidget,
      );
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
      expect(find.text('Enable skip days'), findsOneWidget);
      expect(
        find.text(
          'Toggle twice to add a skip instead of a checkmark. Skips keep your '
          "score unchanged and don't break your streak.",
        ),
        findsOneWidget,
      );
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
      expect(find.text('Show question marks for missing data'), findsOneWidget);
      expect(
        find.text(
          'Differentiate days without data from actual lapses. To enter a '
          'lapse, toggle twice.',
        ),
        findsOneWidget,
      );
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
      expect(find.text('Reverse order of days'), findsOneWidget);
      expect(
        find.text('Show days in reverse order on the main screen.'),
        findsOneWidget,
      );
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
      expect(find.text('Use pure black in dark theme'), findsOneWidget);
      expect(
        find.text(
          'Replaces gray backgrounds with pure black in dark theme. Reduces '
          'battery usage in phones with AMOLED display.',
        ),
        findsOneWidget,
      );
      await tapSwitch(tester, 'pref_pure_black');
      expect(harness.scope.preferences.isPureBlackEnabled, isTrue);
      expect(harness.storage.getBoolean('pref_pure_black', false), isTrue);
    });

    testWidgets(
        'settings.preferences.disable-animations#1,#2 — writes '
        'pref_disable_animation', (tester) async {
      final harness = await open(tester);
      expect(find.text('Disable animations'), findsOneWidget);
      expect(
        find.text('Disable confetti animation after adding a checkmark.'),
        findsOneWidget,
      );
      await tapSwitch(tester, 'pref_disable_animation');
      expect(harness.scope.preferences.isConfettiAnimationDisabled, isTrue);
      expect(harness.storage.getBoolean('pref_disable_animation', false), isTrue);
    });

    testWidgets(
        'settings.preferences.widget-opacity#1,#2,#3 — list row with the six '
        'index-aligned entries, writing the value as a string',
        (tester) async {
      expect(SettingsModel.widgetOpacityLabels,
          <String>['100%', '80%', '60%', '40%', '20%', '0%']);
      expect(SettingsModel.widgetOpacityValues,
          <String>['255', '204', '153', '102', '51', '0']);

      final harness = await open(tester);
      expect(find.text('Widget opacity'), findsOneWidget);
      expect(
        find.text(
          'Makes widgets more transparent or more opaque in your home screen.',
        ),
        findsOneWidget,
      );
      expect(harness.scope.preferences.widgetOpacity, 255);

      await tester.tap(rowNamed('pref_widget_opacity'));
      await tester.pumpAndSettle();
      final options = tester
          .widgetList<ListTile>(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(ListTile),
          ))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(options, SettingsModel.widgetOpacityLabels);

      await tester.tap(find.text('60%'));
      await tester.pumpAndSettle();
      expect(harness.storage.getString('pref_widget_opacity', ''), '153');
      expect(harness.scope.preferences.widgetOpacity, 153);
    });

    testWidgets(
        'settings.preferences.first-weekday#8,#9,#10 — list row titled "First '
        'day of the week", summarised with dayNames[firstWeekday % 7]',
        (tester) async {
      await open(tester);
      expect(find.text('First day of the week'), findsOneWidget);
      // The locale hook defaults to 1 (Sunday); dayNames starts at Saturday, so
      // the summary is dayNames[1 % 7] == "Sunday".
      expect(
        find.descendant(
          of: rowNamed('pref_first_weekday'),
          matching: find.text('Sunday'),
        ),
        findsOneWidget,
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
      ]);
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

      expect(harness.storage.getString('pref_first_weekday', ''), '2');
      expect(harness.scope.preferences.firstWeekday, core.DayOfWeek.monday);
      expect(
        find.descendant(
          of: rowNamed('pref_first_weekday'),
          matching: find.text('Monday'),
        ),
        findsOneWidget,
      );

      await tester.tap(rowNamed('pref_first_weekday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saturday'));
      await tester.pumpAndSettle();
      expect(harness.storage.getString('pref_first_weekday', ''), '7');
      expect(harness.scope.preferences.firstWeekday, core.DayOfWeek.saturday);
      // dayNames[7 % 7] == dayNames[0] == "Saturday".
      expect(
        find.descendant(
          of: rowNamed('pref_first_weekday'),
          matching: find.text('Saturday'),
        ),
        findsOneWidget,
      );
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
        'settings.preferences.sticky-notifications#1,#2,#3 — writes '
        'pref_sticky_notifications and always fires onNotificationsChanged',
        (tester) async {
      final harness = await open(tester);
      final listener = _RecordingListener();
      harness.scope.preferences.addListener(listener);
      expect(find.text('Make notifications sticky'), findsOneWidget);
      expect(
        find.text('Prevents notifications from being swiped away.'),
        findsOneWidget,
      );
      expect(harness.scope.preferences.shouldMakeNotificationsSticky(), isFalse);
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
      );
      expect(find.text('Export full backup'), findsOneWidget);
      expect(
        find.text(
          'Generates a file that contains all your data. This file can be '
          'imported back.',
        ),
        findsOneWidget,
      );
      expect(find.text('Export as CSV'), findsOneWidget);
      expect(find.text('Import data'), findsOneWidget);
      expect(find.text('Select public backup folder'), findsOneWidget);
      expect(
        find.descendant(
          of: rowNamed('publicBackupFolder'),
          matching: find.text('No folder selected'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<SettingsRow>(rowNamed('publicBackupFolder')).enabled,
        isFalse,
      );
    });

    testWidgets(
        'settings.screen.database-category#4,#13 — exportDB closes the screen '
        'with result 103', (tester) async {
      final harness = await open(tester);
      await tester.tap(rowNamed('exportDB'));
      await tester.pumpAndSettle();
      expect(harness.popped, isTrue);
      expect(harness.result, SettingsResult.exportDb);
      expect(harness.result!.code, 103);
    });

    testWidgets(
        'settings.screen.database-category#4,#13 — exportCSV closes the screen '
        'with result 102', (tester) async {
      final harness = await open(tester);
      await tester.tap(rowNamed('exportCSV'));
      await tester.pumpAndSettle();
      expect(harness.result, SettingsResult.exportCsv);
      expect(harness.result!.code, 102);
    });

    testWidgets(
        'settings.screen.database-category#4,#13 — importData closes the screen '
        'with result 101', (tester) async {
      final harness = await open(tester);
      await tester.tap(rowNamed('importData'));
      await tester.pumpAndSettle();
      expect(harness.result, SettingsResult.importData);
      expect(harness.result!.code, 101);
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
      expect(harness.result!.code, 104);

      harness = await open(tester);
      await tester.tap(rowNamed('repairDB'));
      await tester.pumpAndSettle();
      expect(harness.result, SettingsResult.repairDb);
      expect(harness.result!.code, 105);
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
      ]);
      expect(find.text('Enable developer mode'), findsOneWidget);
      expect(find.text('Sync server'), findsOneWidget);
      expect(find.text('https://sync.loophabits.org'), findsOneWidget);
      expect(find.text('Sync key'), findsOneWidget);
      expect(find.text('Encryption key'), findsOneWidget);
      expect(switchValue(tester, 'pref_developer'), isTrue);
    });

    testWidgets(
        'settings.developer.sync-preference-rows#5,#6 — editing a sync row '
        'writes the raw key and nothing else reads it', (tester) async {
      final harness = await openAsDeveloper(tester);
      await tester.tap(rowNamed('pref_sync_key'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'abc123');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(harness.storage.getString('pref_sync_key', ''), 'abc123');
      expect(
        find.descendant(
          of: rowNamed('pref_sync_key'),
          matching: find.text('abc123'),
        ),
        findsOneWidget,
      );
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
