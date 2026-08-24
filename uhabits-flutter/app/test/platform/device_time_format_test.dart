/// The port's `android.text.format.DateFormat.getTimeFormat(context)`.
///
/// `utils/DateExtensions.kt`'s `formatTime(context, hours, minutes)` renders a
/// reminder with `SimpleDateFormat(LocaleData.get(locale).timeFormat_(h|H)m,
/// locale)`, where `locale` is
/// `context.getResources().getConfiguration().locale` — the DEVICE locale,
/// region and all, the same one `audit9.chart-dates-follow-the-device-locale#1`
/// and `audit10.weekday-name-rows-follow-the-device-locale#1` record for dates
/// and weekday names. The app's strings resolve separately.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/device_time_format.dart';

const String rule =
    'audit15.subtitle-card-reminder-time-ignores-the-device-locale#1 — In the '
    'Kotlin app: formatTime(context, hours, minutes) formats the reminder with '
    'android.text.format.DateFormat.getTimeFormat(context), whose pattern is '
    "ICU's best match for the \"hm\" or \"Hm\" skeleton in the configuration "
    'locale — the device locale, region included — so a Korean phone shows '
    '"오전 8:30" and an en-AU one "8:30 am".';

void main() {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => binding.platformDispatcher.clearLocalesTestValue());

  /// Pumps the delegates — `GlobalMaterialLocalizations` is what installs the
  /// `package:intl` date data every locale's pattern is read from — and hands
  /// back a context below them.
  Future<BuildContext> hostContext(
    WidgetTester tester, {
    Locale? uiLocale,
    bool alwaysUse24HourFormat = false,
  }) async {
    late BuildContext host;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: MaterialApp(
          locale: uiLocale,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return host;
  }

  testWidgets('#1 the 12-hour pattern is the device locale\'s', (tester) async {
    binding.platformDispatcher.localesTestValue = const <Locale>[Locale('ko')];
    expect(
      formatDeviceTime(
        await hostContext(tester, uiLocale: const Locale('ko')),
        minuteOfDay: 8 * 60 + 30,
        use24HourFormat: false,
      ),
      '오전 8:30',
      reason: '$rule Korean puts the day period first.',
    );
  });

  testWidgets('#1 it is NOT the locale the app resolved', (tester) async {
    // The app ships no en_AU translation, so the strings resolve to plain
    // `en` — whose pattern would give the American "8:30 AM" — while the
    // device keeps its region and its lowercase "am".
    binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('en', 'AU'),
    ];
    final BuildContext context = await hostContext(tester);
    expect(
      Localizations.localeOf(context),
      const Locale('en'),
      reason: '$rule The two are different questions.',
    );
    expect(
      formatDeviceTime(context, minuteOfDay: 8 * 60 + 30,
          use24HourFormat: false),
      '8:30 am',
      reason: rule,
    );
  });

  testWidgets('#1 is24HourFormat picks the skeleton, not the language',
      (tester) async {
    binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('fr', 'CA'),
    ];
    final BuildContext context = await hostContext(tester);
    expect(
      formatDeviceTime(context, minuteOfDay: 8 * 60 + 30,
          use24HourFormat: true),
      '08 h 30',
      reason: '$rule The "Hm" branch is just as locale-specific as the other; '
          'it is not a hard-coded "HH:mm".',
    );
  });

  testWidgets('#1 the switch defaults to MediaQuery.alwaysUse24HourFormat',
      (tester) async {
    binding.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    expect(
      formatDeviceTime(
        await hostContext(tester, alwaysUse24HourFormat: true),
        minuteOfDay: 8 * 60 + 30,
      ),
      '08:30',
      reason: '$rule DateFormat.is24HourFormat(context) is the system setting, '
          "and MediaQuery is Flutter's window onto it.",
    );
    expect(
      formatDeviceTime(
        await hostContext(tester, alwaysUse24HourFormat: false),
        minuteOfDay: 8 * 60 + 30,
      ),
      '8:30 AM',
      reason: rule,
    );
  });

  testWidgets('#1 no time zone can shift the rendered clock', (tester) async {
    binding.platformDispatcher.localesTestValue = const <Locale>[Locale('en')];
    final BuildContext context = await hostContext(tester);
    // `df.timeZone = TimeZone.getTimeZone("UTC")`: the answer depends on
    // nothing but the minute it is handed, whatever the host's zone is.
    expect(DateTime.now().timeZoneOffset, isNotNull);
    expect(
      formatDeviceTime(context, minuteOfDay: 0, use24HourFormat: true),
      '00:00',
      reason: rule,
    );
    expect(
      formatDeviceTime(context, minuteOfDay: 23 * 60 + 59,
          use24HourFormat: true),
      '23:59',
      reason: rule,
    );
  });
}
