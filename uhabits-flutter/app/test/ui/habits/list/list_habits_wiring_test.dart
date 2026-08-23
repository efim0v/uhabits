// The core src layers are reached by their `src` path, exactly as the app
// package reaches them; the two platform interfaces are transitive
// dependencies of url_launcher / path_provider and exist so that a test can
// stand in for the plugin.
// ignore_for_file: implementation_imports, depend_on_referenced_packages

/// Wiring tests for the three seams the final audit found unplugged.
///
/// All three findings are the same defect: a screen exposes the right callback
/// and nobody supplies it, so a widget test that passes the callback itself
/// cannot see the hole. These tests therefore build the screens exactly as the
/// app does — `HabitListScreen()` with nothing wired — and assert the effect
/// on the far side of the seam: a file on disk, a message, a launched URL.
///
/// The two plugin boundaries are crossed through their platform interfaces:
/// [UrlLauncherPlatform] stands in for `startActivitySafely`'s target and
/// [PathProviderPlatform] for `ContextCompat.getExternalFilesDirs`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/bug_reporter.dart' show SendEmailScreen;
import 'package:uhabits/platform/flutter_files.dart' show HabitsDirFinder;
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/uhabits_core.dart' show resetToday;
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// `Activity.startActivitySafely(intent)`'s far side: whatever app the system
/// would have handed the ACTION_VIEW / mailto intent to.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = <String>[];

  /// False is `ActivityNotFoundException`: nothing on the device handles it.
  bool answer = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => answer;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return answer;
  }
}

/// `ContextCompat.getExternalFilesDirs(context, null)` and
/// `activity.externalCacheDir`, both pointed at the test's temp directory.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => '$root/cache';
}

void main() {
  late Directory tempDir;
  late _FakeUrlLauncher launcher;
  final scopes = <AppScope>[];
  var databaseIndex = 0;

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_list_wiring');
    Directory('${tempDir.path}/cache').createSync(recursive: true);
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final path = '${tempDir.path}/habits${databaseIndex++}.db';
    final scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      databasePath: path,
    );
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  /// The screen as `main.dart` builds it: no callbacks supplied at all.
  Future<AppScope> pumpScreen(WidgetTester tester) async {
    final scope = openScope();
    // The settings screen is one long scroll view; a tall surface keeps every
    // row hit-testable without scrolling between assertions.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: const HabitListScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return scope;
  }

  /// Lets the real file system catch up: `File.copy`, the CSV writer and the
  /// zip archiver all complete on the real event loop, which the tester's fake
  /// async does not pump.
  ///
  /// Plain pumps rather than `pumpAndSettle`, because the task progress bar
  /// animates for as long as a task is running and would never settle.
  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openOverflowMenu(WidgetTester tester) async {
    await tester
        .tap(find.byKey(const ValueKey<String>('listHabits.overflowMenu')));
    await tester.pumpAndSettle();
  }

  Future<void> tapMenuItem(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ListHabitsMenuItems.keyOf(id)));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await openOverflowMenu(tester);
    await tapMenuItem(tester, ListHabitsMenuItems.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  /// Taps one `<Preference>` row by its `android:key`.
  Future<void> tapSettingsRow(WidgetTester tester, String key) async {
    final row = find.byKey(ValueKey<String>(key));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await settleIo(tester);
  }

  L10n stringsOf(WidgetTester tester, Type screen) =>
      L10n.of(tester.element(find.byType(screen).first));

  Directory backupsDir() =>
      Directory('${tempDir.path}/${HabitsDirFinder.backupsDirName}');

  Directory csvDir() =>
      Directory('${tempDir.path}/${HabitsDirFinder.csvDirName}');

  // -----------------------------------------------------------------------
  // audit.every-data-troubleshooting-row-in-settings
  // -----------------------------------------------------------------------

  group('audit.every-data-troubleshooting-row-in-settings', () {
    const rule1 = 'audit.every-data-troubleshooting-row-in-settings#1 — '
        'RESULT_EXPORT_DB -> onExportDB(), RESULT_EXPORT_CSV -> '
        'behavior.onExportCSV(), RESULT_IMPORT_DATA -> showImportScreen(), '
        'RESULT_BUG_REPORT -> behavior.onSendBugReport(), RESULT_REPAIR_DB -> '
        'behavior.onRepairDB()';
    const rule2 = 'audit.every-data-troubleshooting-row-in-settings#2 — '
        '_openSettings() must await the popped SettingsResult and hand it to a '
        'DataActions, instead of pushing a MaterialPageRoute<void> and '
        'dropping the result';

    testWidgets('Export full backup writes a database copy into Backups',
        (tester) async {
      await pumpScreen(tester);
      await openSettings(tester);
      await tapSettingsRow(tester, 'exportDB');

      expect(find.byType(SettingsScreen), findsNothing,
          reason: '$rule1 — the row is `setResult(103); finish()`');
      expect(backupsDir().existsSync(), isTrue, reason: rule2);
      expect(
        backupsDir().listSync().whereType<File>().map((f) => f.path).toList(),
        hasLength(1),
        reason: '$rule2 — 103 exports the database',
      );
    });

    testWidgets('Export to CSV writes an archive into the CSV directory',
        (tester) async {
      await pumpScreen(tester);
      await openSettings(tester);
      await tapSettingsRow(tester, 'exportCSV');

      expect(csvDir().existsSync(), isTrue, reason: rule2);
      expect(csvDir().listSync().whereType<File>(), hasLength(1),
          reason: '$rule2 — 102 exports the CSV archive');
    });

    testWidgets('Repair database repairs and reports "Database repaired."',
        (tester) async {
      await pumpScreen(tester);
      final l10n = stringsOf(tester, HabitListScreen);
      await openSettings(tester);
      await tapSettingsRow(tester, 'repairDB');

      expect(find.text(l10n.databaseRepaired), findsOneWidget,
          reason: '$rule1 — 105 runs onRepairDB(), which toasts '
              'R.string.database_repaired. $rule2');
    });

    testWidgets('Generate bug report opens the mail composer', (tester) async {
      await pumpScreen(tester);
      await openSettings(tester);
      await tapSettingsRow(tester, 'bugReport');

      expect(launcher.launched, hasLength(1),
          reason: '$rule1 — 104 runs onSendBugReport(), which ends in '
              'showSendBugReportToDeveloperScreen(log). $rule2');
      expect(
        launcher.launched.single,
        startsWith('mailto:${SendEmailScreen.bugReportTo}'),
        reason: rule1,
      );
    });

    testWidgets('a settings screen dismissed with Back runs nothing',
        (tester) async {
      await pumpScreen(tester);
      await openSettings(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await settleIo(tester);

      // `RESULT_CANCELED`: `onSettingsResult` is never reached.
      expect(backupsDir().existsSync(), isFalse, reason: rule2);
      expect(csvDir().existsSync(), isFalse, reason: rule2);
      expect(launcher.launched, isEmpty, reason: rule2);
    });
  });

  // -----------------------------------------------------------------------
  // audit.overflow-menu-help-faq-does-nothing
  // -----------------------------------------------------------------------

  group('audit.overflow-menu-help-faq-does-nothing', () {
    const rule1 = 'audit.overflow-menu-help-faq-does-nothing#1 — '
        'showFAQScreen() starts ACTION_VIEW on @string/helpURL; the Settings '
        'Help row carries the same intent and rateApp starts ACTION_VIEW on '
        '@string/playStoreURL';
    const rule2 = 'audit.overflow-menu-help-faq-does-nothing#2 — '
        'HabitListScreen.onOpenUrl is never supplied, so the menu item is a '
        'no-op and the Settings Help / Rate-this-app rows render disabled';

    testWidgets('Help & FAQ opens the FAQ page', (tester) async {
      await pumpScreen(tester);
      await openOverflowMenu(tester);
      await tapMenuItem(tester, ListHabitsMenuItems.faq);
      await settleIo(tester);

      expect(launcher.launched, <String>[SettingsScreen.helpUrl],
          reason: '$rule1. $rule2');
    });

    testWidgets('the Settings Help row is enabled and opens the FAQ page',
        (tester) async {
      await pumpScreen(tester);
      await openSettings(tester);
      final l10n = stringsOf(tester, SettingsScreen);

      final row = tester.widget<ListTile>(find.descendant(
        of: find.byKey(const ValueKey<String>('help')),
        matching: find.byType(ListTile),
      ));
      expect(row.enabled, isTrue, reason: rule2);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('help')),
          matching: find.text(l10n.activityNotFound),
        ),
        findsNothing,
        reason: '$rule2 — the row no longer carries the "no app found" note',
      );

      await tester.tap(find.byKey(const ValueKey<String>('help')));
      await settleIo(tester);
      expect(launcher.launched, <String>[SettingsScreen.helpUrl],
          reason: '$rule1. $rule2');
    });

    testWidgets('the Settings Rate this app row opens the Play Store',
        (tester) async {
      await pumpScreen(tester);
      await openSettings(tester);

      final row = tester.widget<ListTile>(find.descendant(
        of: find.byKey(const ValueKey<String>('rateApp')),
        matching: find.byType(ListTile),
      ));
      expect(row.enabled, isTrue, reason: rule2);

      await tester.tap(find.byKey(const ValueKey<String>('rateApp')));
      await settleIo(tester);
      expect(launcher.launched, <String>[SettingsScreen.rateAppUrl],
          reason: '$rule1. $rule2');
    });
  });

  // -----------------------------------------------------------------------
  // audit.all-six-about-screen-links-do
  // -----------------------------------------------------------------------

  group('audit.all-six-about-screen-links-do', () {
    const rule1 = 'audit.all-six-about-screen-links-do#1 — every clickable row '
        'calls activity.startActivitySafely(intents.<link>(activity)), which '
        'opens the Play Store, the mail composer or one of the three web URLs '
        'in an external app';
    const rule2 = 'audit.all-six-about-screen-links-do#2 — neither _openAbout() '
        'in habit_list_screen.dart nor the settings screen\'s onShowAbout '
        'passes onOpenLink, so all six rows are inert';

    Future<void> openAboutFromMenu(WidgetTester tester) async {
      await openOverflowMenu(tester);
      await tapMenuItem(tester, ListHabitsMenuItems.about);
      expect(find.byType(AboutScreen), findsOneWidget);
    }

    Future<void> tapLink(WidgetTester tester, String label) async {
      final link = find.text(label);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await settleIo(tester);
    }

    testWidgets('all six rows open their link', (tester) async {
      await pumpScreen(tester);
      await openAboutFromMenu(tester);
      final l10n = stringsOf(tester, AboutScreen);

      await tapLink(tester, l10n.prefRateThisApp);
      await tapLink(tester, l10n.prefSendFeedback);
      await tapLink(tester, l10n.helpTranslate);
      await tapLink(tester, l10n.prefViewSourceCode);
      await tapLink(tester, l10n.prefViewPrivacy);
      await tapLink(tester, l10n.viewAllContributors);

      expect(
        launcher.launched,
        <String>[
          AboutLinks.rateApp.toString(),
          AboutLinks.sendFeedback.toString(),
          AboutLinks.helpTranslate.toString(),
          AboutLinks.viewSourceCode.toString(),
          AboutLinks.privacyPolicy.toString(),
          AboutLinks.codeContributors.toString(),
        ],
        reason: '$rule1. $rule2',
      );
      expect(find.text(l10n.activityNotFound), findsNothing,
          reason: '$rule2 — a handled link shows no "no app found" message');
    });

    testWidgets('the About screen reached from Settings opens links too',
        (tester) async {
      await pumpScreen(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey<String>('about')));
      await tester.pumpAndSettle();
      expect(find.byType(AboutScreen), findsOneWidget, reason: rule2);

      final l10n = stringsOf(tester, AboutScreen);
      await tapLink(tester, l10n.prefViewSourceCode);
      expect(launcher.launched, <String>[AboutLinks.viewSourceCode.toString()],
          reason: '$rule1. $rule2');
    });
  });
}
