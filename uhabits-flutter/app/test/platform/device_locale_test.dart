/// The port's `java.util.Locale.getDefault()`.
///
/// Android reads the *device* locale — region and all — for every
/// locale-derived data convention: the first day of the week
/// (`GregorianCalendar(Locale.getDefault()).firstDayOfWeek`), the number
/// symbols the entry popup formats and parses with
/// (`DecimalFormatSymbols.getInstance()`, `NumberFormat.getInstance()`) and the
/// date order the charts label with (`JavaLocalDateFormatter(
/// Locale.getDefault())`). None of those is the locale the app's *strings* come
/// from: Android resolves resources separately, and falls back to `values/`
/// when it ships no translation for the region.
///
/// This file pins the one source the port now reads them from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/device_locale.dart';

const String ruleFirstWeekday =
    'audit9.first-weekday-follows-the-device-locale#1 — In the Kotlin app: '
    'getFirstWeekdayNumberAccordingToLocale() returns '
    'GregorianCalendar(Locale.getDefault()).firstDayOfWeek, i.e. the first '
    'weekday of the DEVICE locale including its region — Monday on an '
    'English (United Kingdom) device, Sunday on an Español (México) one — '
    'never the locale the app resolved its translations against.';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => binding.platformDispatcher.clearLocalesTestValue());

  group('audit9.first-weekday-follows-the-device-locale', () {
    testWidgets('#1 the device locale keeps its region', (tester) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'GB'),
        Locale('fr'),
      ];

      expect(
        deviceLocale(),
        const Locale('en', 'GB'),
        reason:
            '$ruleFirstWeekday Locale.getDefault() is the first of the '
            "platform's locales, not a list.",
      );
      expect(
        deviceLocaleName(),
        'en_GB',
        reason: '$ruleFirstWeekday …spelled the way `intl` spells it.',
      );
    });

    testWidgets('#1 it is NOT the locale the app resolved', (tester) async {
      // The app ships no en_GB translation, so `basicLocaleListResolution`
      // hands `Localizations` the bare `en`. On Android that same device shows
      // the `values/` strings and still reports en_GB from
      // `Locale.getDefault()`; the two are different questions.
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'GB'),
      ];

      late Locale resolved;
      late Locale device;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Builder(
            builder: (context) {
              resolved = Localizations.localeOf(context);
              device = DeviceLocale.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        resolved,
        const Locale('en'),
        reason:
            '$ruleFirstWeekday The UI language must keep coming from the '
            'resolved locale — the app has no en_GB translation and must not '
            'try to load one.',
      );
      expect(
        device,
        const Locale('en', 'GB'),
        reason:
            '$ruleFirstWeekday …while the data conventions follow the device.',
      );
    });

    testWidgets('#1 a device locale change reaches the tree', (tester) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'GB'),
      ];
      final List<Locale> seen = <Locale>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          builder: (context, child) =>
              DeviceLocale(child: child ?? const SizedBox.shrink()),
          home: Builder(
            builder: (context) {
              seen.add(DeviceLocale.of(context));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(seen.last, const Locale('en', 'GB'), reason: ruleFirstWeekday);

      // en_GB -> en_US resolves to the same `en`, so nothing above would
      // rebuild on its own; Locale.getDefault() changed all the same.
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'US'),
      ];
      await tester.pumpAndSettle();

      expect(
        seen.last,
        const Locale('en', 'US'),
        reason:
            '$ruleFirstWeekday Locale.getDefault() is process-global on '
            'Android and every view reads it afresh after a configuration '
            'change, even one the resource resolution cannot see.',
      );
    });

    testWidgets('#1 without a scope the platform is read directly', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('es', 'MX'),
      ];

      late Locale device;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              device = DeviceLocale.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        device,
        const Locale('es', 'MX'),
        reason:
            '$ruleFirstWeekday The scope only exists to notice changes; the '
            'answer itself is the platform value.',
      );
    });
  });
}
