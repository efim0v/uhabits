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
// The preferences layer is not re-exported from uhabits_core.dart.
// ignore_for_file: implementation_imports
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/locale_first_weekday.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late int Function() saved;

  setUp(() => saved = getFirstWeekdayNumberAccordingToLocale);
  tearDown(() => getFirstWeekdayNumberAccordingToLocale = saved);

  group('settings.preferences.first-weekday', () {
    const String rule4 =
        'settings.preferences.first-weekday#4 — '
        'getFirstWeekdayNumberAccordingToLocale() on JVM/Android returns '
        'GregorianCalendar(Locale.getDefault()).firstDayOfWeek, i.e. 1 for '
        'Sunday through 7 for Saturday. Flutter has no GregorianCalendar; the '
        'same CLDR table reaches it as MaterialLocalizations'
        '.firstDayOfWeekIndex, which counts 0 for Sunday through 6 for '
        'Saturday, so firstWeekdayNumberOf is that index plus one.';

    test('#4 the index is converted into the 1 = Sunday Calendar convention',
        () {
      expect(firstWeekdayNumberOf(const _Localizations(0)), 1, reason: rule4);
      expect(firstWeekdayNumberOf(const _Localizations(1)), 2, reason: rule4);
      expect(firstWeekdayNumberOf(const _Localizations(6)), 7, reason: rule4);
    });

    testWidgets('#4 the ambient locale reaches the core hook', (tester) async {
      // en_US starts the week on Sunday; en_GB and de_DE start it on Monday.
      // Both numbers come out of the same table Android reads.
      await tester.pumpWidget(_app(const Locale('en', 'US')));
      expect(getFirstWeekdayNumberAccordingToLocale(), 1,
          reason: '$rule4 en_US: Sunday, which is 1.');
      expect(Preferences(MemoryStorage()).firstWeekday, DayOfWeek.sunday,
          reason: '$rule4 …and that is what an unset pref_first_weekday '
              'resolves to, which is the only reason the number exists.');

      await tester.pumpWidget(_app(const Locale('de', 'DE')));
      expect(getFirstWeekdayNumberAccordingToLocale(), 2,
          reason: '$rule4 de_DE: Monday, which is 2.');
      expect(Preferences(MemoryStorage()).firstWeekday, DayOfWeek.monday,
          reason: rule4);

      // A relaunch is not needed: the installer runs on every build, so the
      // Android 13 per-app language picker is honoured in place.
      await tester.pumpWidget(_app(const Locale('en', 'US')));
      expect(getFirstWeekdayNumberAccordingToLocale(), 1, reason: rule4);
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

Widget _app(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const <Locale>[
      Locale('en', 'US'),
      Locale('de', 'DE'),
    ],
    builder: (context, child) =>
        FirstWeekdayFromLocale(child: child ?? const SizedBox.shrink()),
    home: const SizedBox.shrink(),
  );
}

/// A [MaterialLocalizations] that answers one question, so the conversion can
/// be checked at every index without inventing seven locales.
class _Localizations extends DefaultMaterialLocalizations {
  const _Localizations(this._index);

  final int _index;

  @override
  int get firstDayOfWeekIndex => _index;
}
