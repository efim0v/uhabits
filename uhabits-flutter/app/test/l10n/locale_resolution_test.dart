/// Which locale the running app resolves for a device language it does not
/// translate.
///
/// Android resolves resources against the device locale and falls back to
/// `res/values/` — the English set — whenever no `values-<lang>` directory
/// matches. `uhabits-android/src/main/res/values/strings.xml:21-23` opens with
/// `tools:ignore="MissingTranslation"` precisely so that fallback is legal, and
/// the app ships `values-*` directories for 47 languages only, so a phone set
/// to Thai, Estonian or Lithuanian runs Loop in plain English.
///
/// Flutter has no default resource set. `basicLocaleListResolution`'s last
/// resort is `supportedLocales.first`, and gen-l10n emits that list
/// alphabetically by ARB filename, so the app's first entry — and therefore its
/// last resort — is `af`: an ARB carrying 22 of the template's ~200 messages,
/// which also drags `GlobalMaterialLocalizations` into Afrikaans.
///
/// The device language is driven through `platformDispatcher.localesTestValue`
/// and never through `MaterialApp.locale`. Pinning the locale is exactly what
/// hides this — `lib/main.dart` passes no `locale:` at all, so resolution is
/// the only thing that decides the UI language on a real device.
library;

// The core's preferences layer is not re-exported from uhabits_core.dart, and
// is imported by path exactly as lib/state/app_scope.dart imports it.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';

const String rule =
    'audit10.untranslated-device-language-serves-english#1 — Android serves '
    'the default res/values/ strings, which are English, to every device whose '
    'language has no values-<lang> directory. The port must resolve the same '
    'way: a device language absent from L10n.supportedLocales lands on '
    "Locale('en'), never on supportedLocales.first — which is af, a 22-message "
    'translation.';

void main() {
  late Directory tempDir;
  final List<AppScope> scopes = <AppScope>[];
  int databaseIndex = 0;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_locale_resolution');
  });

  tearDown(() {
    for (final AppScope scope in scopes) {
      try {
        scope.close();
      } on Object {
        // Already closed.
      }
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final AppScope scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits${databaseIndex++}.db'),
      preferencesStorage: MemoryStorage(),
    );
    // `BaseUserInterfaceTest.setUp`: a scope over an empty preference store IS
    // a first run, and a first run opens the intro on top of the habit list.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  /// Runs the app the way `main()` runs it — no `locale:`, the device list as
  /// the only input — and reports what its widget tree resolved.
  Future<Locale> resolvedBy(WidgetTester tester, List<Locale> device) async {
    tester.platformDispatcher.localesTestValue = device;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(UhabitsApp(scope: openScope()));
    await tester.pumpAndSettle();
    return Localizations.localeOf(tester.element(find.byType(Navigator).first));
  }

  String titleOf(WidgetTester tester) =>
      L10n.of(tester.element(find.byType(Navigator).first)).mainActivityTitle;

  group('audit10.untranslated-device-language-serves-english', () {
    testWidgets('#1 a device language the app does not translate resolves to '
        'English', (WidgetTester tester) async {
      expect(await resolvedBy(tester, const <Locale>[Locale('th', 'TH')]),
          const Locale('en'),
          reason: '$rule Thai has no ARB and no values-th/.');
      expect(titleOf(tester), 'Habits',
          reason: '$rule …so every string the Thai user reads is the template '
              'value, exactly as on Android.');
    });

    testWidgets('#1 the same holds for the other untranslated languages the '
        'app is shipped to', (WidgetTester tester) async {
      for (final Locale device in const <Locale>[
        Locale('et', 'EE'),
        Locale('lt', 'LT'),
        Locale('ms', 'MY'),
        Locale('bn', 'BD'),
        Locale('sw'),
      ]) {
        tester.platformDispatcher.localesTestValue = <Locale>[device];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        await tester.pumpWidget(UhabitsApp(scope: openScope()));
        await tester.pumpAndSettle();
        expect(
            Localizations.localeOf(
                tester.element(find.byType(Navigator).first)),
            const Locale('en'),
            reason: '$rule $device has no translation either.');
      }
    });

    testWidgets('#1 the bootstrap shell resolves the same way as the themed '
        'app', (WidgetTester tester) async {
      // `UhabitsApp` has two MaterialApps: the one above and the one that
      // shows the toolbar while `AppScope.boot()` is still running. A user on
      // an untranslated device sees both.
      tester.platformDispatcher.localesTestValue =
          const <Locale>[Locale('th', 'TH')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(const UhabitsApp());
      await tester.pumpAndSettle();

      expect(
          Localizations.localeOf(tester.element(find.byType(Navigator).first)),
          const Locale('en'),
          reason: '$rule Both MaterialApps in lib/main.dart resolve from the '
              'same list, so both need the same rule.');
    });

    testWidgets('#1 a translated device language is still served its '
        'translation', (WidgetTester tester) async {
      expect(await resolvedBy(tester, const <Locale>[Locale('ru', 'RU')]),
          const Locale('ru'),
          reason: '$rule The fallback only applies when no values-<lang> '
              'matches; Russian has one.');
      expect(titleOf(tester), 'Привычки', reason: rule);
    });

    testWidgets('#1 Afrikaans is still served to an Afrikaans device',
        (WidgetTester tester) async {
      expect(await resolvedBy(tester, const <Locale>[Locale('af', 'ZA')]),
          const Locale('af'),
          reason: '$rule values-af-rZA/ exists, so an Afrikaans phone really '
              'does get Afrikaans — the defect is everyone else getting it.');
      expect(titleOf(tester), 'Gewoontes', reason: rule);
    });

    testWidgets('#1 a region the app does not ship keeps its language',
        (WidgetTester tester) async {
      expect(await resolvedBy(tester, const <Locale>[Locale('en', 'GB')]),
          const Locale('en'),
          reason: '$rule values-en-rGB/ does not exist and values/ does, which '
              'is the plain-language match, not the last resort.');
      expect(await resolvedBy(tester, const <Locale>[Locale('pt', 'BR')]),
          const Locale('pt', 'BR'),
          reason: '$rule …and a region that IS shipped still wins over its '
              'language.');
    });

    testWidgets('#1 a second preferred language is consulted before the '
        'fallback', (WidgetTester tester) async {
      // Android 7+ resolves against the whole LocaleList, not just its head.
      expect(
          await resolvedBy(
              tester, const <Locale>[Locale('th', 'TH'), Locale('de', 'DE')]),
          const Locale('de'),
          reason: '$rule German is on the list and is translated, so it is '
              'what values-de/ answers with.');
    });
  });
}
