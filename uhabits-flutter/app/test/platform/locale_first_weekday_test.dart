/// The platform half of `settings.preferences.first-weekday`.
///
/// The core declares `getFirstWeekdayNumberAccordingToLocale()` as a hook and
/// reads it from `Preferences.firstWeekday`; upstream has one implementation
/// per platform, and this file is the port's third one. Rules #1, #2, #3, #5,
/// #6, #7, #12, #14 and #15 are arithmetic and live in the core package's
/// tests; #8, #9 and #10 are the settings row. What is left here is #4 (the
/// JVM/Android source of the number), #13 (the JS one, including its CLDR
/// conversion and its fallback) and the wiring that makes either of them reach
/// the model at all.
///
/// The locale in #4 is `Locale.getDefault()`, the DEVICE locale — see
/// test/platform/device_locale_test.dart and
/// `audit9.first-weekday-follows-the-device-locale#1`. These tests therefore
/// drive `platformDispatcher.localesTestValue` and never `MaterialApp.locale`:
/// the app sets no `locale:`, and the locale its widget tree resolves is the
/// one that has already dropped the region.
// The preferences layer is not re-exported from uhabits_core.dart.
// ignore_for_file: implementation_imports
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/locale_first_weekday.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  late int Function() saved;

  setUp(() => saved = getFirstWeekdayNumberAccordingToLocale);
  tearDown(() {
    getFirstWeekdayNumberAccordingToLocale = saved;
    binding.platformDispatcher.clearLocalesTestValue();
  });

  group('settings.preferences.first-weekday', () {
    const String rule4 =
        'settings.preferences.first-weekday#4 — '
        'getFirstWeekdayNumberAccordingToLocale() on JVM/Android returns '
        'GregorianCalendar(Locale.getDefault()).firstDayOfWeek, i.e. 1 for '
        'Sunday through 7 for Saturday. Flutter has no GregorianCalendar; the '
        'same CLDR table reaches it as intl\'s DateSymbols.FIRSTDAYOFWEEK, '
        'which counts 0 for Monday through 6 for Sunday, so the conversion is '
        '(firstDayOfWeek + 1) % 7 + 1.';

    test('#4 the index is converted into the 1 = Sunday Calendar convention',
        () {
      // Monday through Saturday shift up by two; Sunday wraps round to 1.
      expect(calendarWeekdayFromIntlFirstDay(0), 2,
          reason: '$rule4 intl Monday is 0; Calendar Monday is 2.');
      expect(calendarWeekdayFromIntlFirstDay(5), 7,
          reason: '$rule4 intl Saturday is 5; Calendar Saturday is 7.');
      expect(calendarWeekdayFromIntlFirstDay(6), 1,
          reason: '$rule4 intl Sunday is 6 and Calendar Sunday is 1 — the one '
              'value the modulo exists for.');

      // Every answer is a legal Calendar weekday, whatever the table says.
      for (int intlFirstDay = 0; intlFirstDay <= 6; intlFirstDay++) {
        final int number = calendarWeekdayFromIntlFirstDay(intlFirstDay);
        expect(number, inInclusiveRange(1, 7), reason: rule4);
      }
    });

    testWidgets('#4 the number is looked up per locale', (tester) async {
      // A MaterialApp is pumped first only because that is what installs
      // intl's per-locale CLDR table; the lookup itself takes a locale name.
      await tester.pumpWidget(_shippedApp());
      await tester.pumpAndSettle();

      expect(firstWeekdayNumberOf('en_US'), 1, reason: '$rule4 Sunday.');
      expect(firstWeekdayNumberOf('de_DE'), 2, reason: '$rule4 Monday.');
      expect(firstWeekdayNumberOf('xx_YY'), 1,
          reason: '$rule4 A locale intl has no data for degrades the way Java '
              'degrades to the root locale, rather than throwing.');
    });

    testWidgets('#4 the device locale reaches the core hook', (tester) async {
      // en_US starts the week on Sunday; de_DE starts it on Monday. Both
      // numbers come out of the same table Android reads — and both are read
      // off `Locale.getDefault()`, which is the platform locale list, not
      // `MaterialApp.locale`.
      Future<void> device(Locale locale) async {
        tester.platformDispatcher.localesTestValue = <Locale>[locale];
        await tester.pumpWidget(_shippedApp());
        await tester.pumpAndSettle();
      }

      await device(const Locale('en', 'US'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 1,
          reason: '$rule4 en_US: Sunday, which is 1.');
      expect(Preferences(MemoryStorage()).firstWeekday, DayOfWeek.sunday,
          reason: '$rule4 …and that is what an unset pref_first_weekday '
              'resolves to, which is the only reason the number exists.');

      await device(const Locale('de', 'DE'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 2,
          reason: '$rule4 de_DE: Monday, which is 2.');
      expect(Preferences(MemoryStorage()).firstWeekday, DayOfWeek.monday,
          reason: rule4);

      // A relaunch is not needed: the installer runs on every build, so the
      // Android 13 per-app language picker is honoured in place.
      await device(const Locale('en', 'US'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 1, reason: rule4);
    });

    const String rule9 =
        'audit9.first-weekday-follows-the-device-locale#1 — In the Kotlin '
        'app: getFirstWeekdayNumberAccordingToLocale() returns '
        'GregorianCalendar(Locale.getDefault()).firstDayOfWeek, i.e. the '
        'first weekday of the DEVICE locale including its region — Monday on '
        'an English (United Kingdom) device, Sunday on an Español (México) '
        'one — never the locale the app resolved its translations against.';

    testWidgets('#4 the region of the device locale reaches the core hook',
        (tester) async {
      // The shipped shell: L10n's delegates and L10n's supported locales,
      // which list bare languages for everything but pt/zh/sr. en_GB and
      // es_MX therefore resolve to `en` and `es` — and the number must not
      // follow them there.
      Future<void> device(Locale locale) async {
        tester.platformDispatcher.localesTestValue = <Locale>[locale];
        await tester.pumpWidget(_shippedApp());
        await tester.pumpAndSettle();
      }

      await device(const Locale('en', 'GB'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 2,
          reason: '$rule9 en_GB: Monday, which is 2.');
      expect(Preferences(MemoryStorage()).firstWeekday, DayOfWeek.monday,
          reason: '$rule9 …and that is the week every chart is bucketed by.');

      await device(const Locale('en', 'IE'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 2,
          reason: '$rule9 en_IE: Monday, which is 2.');

      await device(const Locale('es', 'MX'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 1,
          reason: '$rule9 es_MX: Sunday, which is 1 — the mirror image, since '
              'bare `es` is Monday.');

      await device(const Locale('fr', 'CA'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 1,
          reason: '$rule9 fr_CA: Sunday, which is 1.');

      await device(const Locale('en', 'US'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 1,
          reason: '$rule9 en_US: Sunday, which is 1.');

      await device(const Locale('de', 'DE'));
      expect(getFirstWeekdayNumberAccordingToLocale(), 2,
          reason: '$rule9 de_DE: Monday, which is 2.');
    });

    const String rule13 =
        'settings.preferences.first-weekday#13 — '
        'getFirstWeekdayNumberAccordingToLocale() on JS reads '
        'Intl.Locale(navigator.language).getWeekInfo().firstDay (CLDR '
        '1=Monday..7=Sunday) and converts with firstDay % 7 + 1, defaulting to '
        '1 (Sunday) if Intl is unavailable.';

    test('#13 firstDay % 7 + 1 maps CLDR onto the Calendar convention', () {
      // Monday..Saturday shift up by one; Sunday wraps round to 1.
      expect(calendarWeekdayFromCldr(1), 2, reason: '$rule13 Monday.');
      expect(calendarWeekdayFromCldr(2), 3, reason: '$rule13 Tuesday.');
      expect(calendarWeekdayFromCldr(3), 4, reason: rule13);
      expect(calendarWeekdayFromCldr(4), 5, reason: rule13);
      expect(calendarWeekdayFromCldr(5), 6, reason: '$rule13 Friday.');
      expect(calendarWeekdayFromCldr(6), 7, reason: '$rule13 Saturday.');
      expect(calendarWeekdayFromCldr(7), 1,
          reason: '$rule13 Sunday is CLDR 7 and Calendar 1 — the one value '
              'the modulo exists for.');

      // Every answer is a legal Calendar weekday, so none of them can make
      // Preferences.firstWeekday throw.
      for (int cldr = 1; cldr <= 7; cldr++) {
        final int number = calendarWeekdayFromCldr(cldr);
        getFirstWeekdayNumberAccordingToLocale = () => number;
        expect(() => Preferences(MemoryStorage()).firstWeekday, returnsNormally,
            reason: rule13);
      }
    });

    test('#13 the fallback when the platform cannot answer is Sunday', () {
      expect(fallbackFirstWeekdayNumber, 1, reason: rule13);

      // The core hook ships with exactly that fallback, so a host that never
      // installs one behaves like a JS host without Intl rather than crashing.
      expect(saved(), fallbackFirstWeekdayNumber,
          reason: '$rule13 The core default is the JS default.');
    });

    testWidgets('#13 an unlocalized tree leaves the hook alone', (tester) async {
      getFirstWeekdayNumberAccordingToLocale = () => 5;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: FirstWeekdayFromLocale(child: SizedBox.shrink()),
        ),
      );
      expect(getFirstWeekdayNumberAccordingToLocale(), 5,
          reason: '$rule13 With no MaterialLocalizations above it there is '
              'nothing to read, and the installer overwrites nothing — the '
              '"Intl is unavailable" branch.');
    });
  });
}

/// The shell `main.dart` builds: the app's real delegates and supported
/// locales, with no `locale:` override, so the only locale in play is the
/// device's.
Widget _shippedApp() {
  return MaterialApp(
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    builder: (context, child) =>
        FirstWeekdayFromLocale(child: child ?? const SizedBox.shrink()),
    home: const SizedBox.shrink(),
  );
}

