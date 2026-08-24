/// `audit3.streak-chart-date-labels-are-hard#1`: the dates that flank a streak
/// bar follow the device locale's medium date pattern.
///
/// Upstream `StreakChart` calls `df.longFormat(streak.start)` and
/// `df.longFormat(streak.end)`, where `df` is a `JavaLocalDateFormatter` and
/// `longFormat` is `DateFormat.getDateInstance(DateFormat.MEDIUM,
/// Locale.getDefault())` with the formatter's time zone forced to UTC. It is
/// not part of the `LocalDateFormatter` interface — that has five methods
/// upstream too — so the port's counterpart of `JavaLocalDateFormatter`,
/// `IntlLocalDateFormatter`, is where it belongs, and the card is what has to
/// hand it to the chart.
///
/// The port had the `dateLabel` seam, never supplied it, and had no
/// `longFormat` to supply it with, so every locale got the US medium shape
/// "Jan 25, 2015" built out of `shortMonthName`. The seam stays — it is what
/// the chart's own tests use to control label width — but the label the app
/// paints no longer depends on anyone remembering to pass it.
///
/// The nine strings below are the ones the ledger rule measured on a JDK; the
/// assertions read them off the chart the *card* built, never off a chart this
/// test configured.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/show/cards/streak_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const String rule = 'audit3.streak-chart-date-labels-are-hard#1 — In the '
    'Kotlin app: StreakChart flanks each bar with df.longFormat(streak.start) '
    'and df.longFormat(streak.end), where longFormat is '
    'DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault()) with '
    'the formatter\'s timezone forced to UTC. The label therefore follows the '
    'device locale\'s medium date pattern.';

/// The rule's own measurements for 2015-01-25, on a JDK.
const Map<String, String> measured = <String, String>{
  'en': 'Jan 25, 2015',
  'de': '25.01.2015',
  'fr': '25 janv. 2015',
  'ru': '25 янв. 2015 г.',
  'hu': '2015. jan. 25.',
  'ja': '2015/01/25',
  'ko': '2015. 1. 25.',
  'zh': '2015年1月25日',
  'vi': '25 thg 1, 2015',
};

void main() {
  final today = core.LocalDate.ymd(2015, 1, 25);
  final theme = core.LightTheme();

  setUp(() => core.setToday(today));
  tearDown(core.resetToday);

  StreakCardState streakState() => StreakCardState(
        color: const core.PaletteColor(7),
        bestStreaks: <core.Streak>[
          core.Streak(today.minus(9), today),
          core.Streak(core.LocalDate.ymd(2014, 12, 11),
              core.LocalDate.ymd(2014, 12, 18)),
        ],
        theme: theme,
      );

  /// The chart the card built for itself on a device set to [locale].
  ///
  /// The device locale is what `JavaLocalDateFormatter(Locale.getDefault())`
  /// reads (`audit9.chart-dates-follow-the-device-locale#1`); `MaterialApp
  /// .locale` is set alongside it because on Android the two are one setting.
  Future<StreakChartView> chartFor(WidgetTester tester, Locale locale) async {
    tester.platformDispatcher.localesTestValue = <Locale>[locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: StreakCardView(state: streakState()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<CoreView>(find.byType(CoreView)).view
        as StreakChartView;
  }

  group('audit3.streak-chart-date-labels-are-hard', () {
    testWidgets('#1 the chart the card built prints the locale\'s medium date',
        (tester) async {
      final chart = await chartFor(tester, const Locale('de'));

      expect(chart.labelFor(today), '25.01.2015',
          reason: '$rule A German device prints the German medium date, not '
              'the US one the port built out of shortMonthName.');
    });

    testWidgets('#1 nine locales, nine medium date patterns', (tester) async {
      for (final MapEntry<String, String> e in measured.entries) {
        final chart = await chartFor(tester, Locale(e.key));
        expect(chart.labelFor(today), e.value,
            reason: '$rule Measured on a JDK for ${e.key}.');
      }
    });

    testWidgets('#1 the label is a date, not an instant: no time zone can '
        'shift it', (tester) async {
      // `df.timeZone = TimeZone.getTimeZone("UTC")` is what keeps a LocalDate
      // from being read as a local instant and printed as the day before.
      final chart = await chartFor(tester, const Locale('en'));

      expect(chart.labelFor(core.LocalDate.ymd(2015, 1, 1)), 'Jan 1, 2015',
          reason: rule);
      expect(chart.labelFor(core.LocalDate.ymd(2014, 12, 31)), 'Dec 31, 2014',
          reason: rule);
    });

    const String rule9 =
        'audit9.chart-dates-follow-the-device-locale#1 — In the Kotlin app: '
        'StreakChart builds JavaLocalDateFormatter(Locale.getDefault()) and '
        'labels each streak with longFormat, i.e. '
        'DateFormat.getDateInstance(DateFormat.MEDIUM, Locale.getDefault()). '
        'The pattern is the DEVICE locale\'s, region included — "d MMM y" on '
        'an English (United Kingdom) device — never the language the app '
        'resolved its translations against.';

    testWidgets('#1 a British device gets the British date order',
        (tester) async {
      // The app ships no en_GB translation, so the tree resolves to bare `en`,
      // whose medium pattern is the American "MMM d, y".
      final chart = await chartFor(tester, const Locale('en', 'GB'));

      expect(chart.labelFor(today), '25 Jan 2015',
          reason: '$rule9 en_GB reads "25 Jan 2015"; bare `en` reads '
              '"Jan 25, 2015".');

      final BuildContext context = tester.element(find.byType(StreakCardView));
      expect(Localizations.localeOf(context), const Locale('en'),
          reason: '$rule9 …while the UI language stays on the resolved '
              'locale, which is the half that must not move.');
    });

    testWidgets('#1 the habit detail screen builds the card with it',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('uhabits_streaks');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      core.resetToday();
      final scope = AppScope.open(
        AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
      );
      addTearDown(scope.close);
      scope.preferences.isFirstRun = false;
      final habit = scope.modelFactory.buildHabit()
        ..name = 'Meditate'
        ..color = const core.PaletteColor(7);
      scope.habitList.add(habit);
      habit.recompute();

      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: ShowHabitScreen(habit: habit),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final StreakChartView chart = tester
          .widget<CoreView>(find.descendant(
            of: find.byType(StreakCardView),
            matching: find.byType(CoreView),
          ))
          .view as StreakChartView;
      expect(chart.labelFor(core.LocalDate.ymd(2015, 1, 25)), '25.01.2015',
          reason: '$rule The screen passes no dateLabel and no dateFormatter, '
              'so the card resolving one from the ambient locale is the only '
              'thing that can localize this label.');
    });
  });

  // The home-screen Streak widget draws the same chart a second time, in
  // Kotlin, inside the launcher's process — upstream literally reuses
  // `StreakChart` there (`StreakWidget.buildView()`), so it inherits
  // `JavaLocalDateFormatter.longFormat` and every locale's medium pattern with
  // it. Nothing in `flutter test` can execute that host: there is no Android
  // test target under `app/android`, so unlike the iOS extension — whose
  // sources are compiled into RunnerTests — the only guard available is to
  // read the Kotlin as text. It can see that the right formatter is built and
  // that the hard-coded template is gone; it cannot see what the formatter
  // prints. That weakness is the finding.
  group('audit21.android-widget-streak-labels-use-the-locale-medium-date', () {
    const String rule21 =
        'audit21.android-widget-streak-labels-use-the-locale-medium-date#1 — '
        'In the Kotlin app: the home-screen Streak widget IS StreakChart '
        '(StreakWidget.buildView returns GraphWidgetView(context, '
        'StreakChart(context))), and StreakChart.init builds '
        'JavaLocalDateFormatter(Locale.getDefault()), whose longFormat is '
        'DateFormat.getDateInstance(DateFormat.MEDIUM, locale) with '
        'df.timeZone = TimeZone.getTimeZone("UTC"). The widget\'s labels '
        'therefore follow the device locale\'s medium pattern — separators and '
        'field order included — exactly as the in-app Streak card\'s do.';

    late String formatter;

    setUpAll(() => formatter = _widgetDateFormatter());

    test('#1 longFormat is the locale\'s MEDIUM date instance, not a template',
        () {
      expect(
        formatter,
        contains(RegExp(
          r'DateFormat\.getDateInstance\(\s*DateFormat\.MEDIUM,\s*'
          r'Locale\.getDefault\(\)\s*\)',
        )),
        reason: '$rule21 The pattern has to come from the locale. A string '
            'built out of shortMonthName is the American "MMM d, yyyy" in '
            'every locale on earth.',
      );
      expect(
        formatter,
        isNot(contains(RegExp(r'\$day,\s*\$year'))),
        reason: '$rule21 …so the hard-coded "\$month \$day, \$year" template '
            'must be gone: it is what made a German widget read "Nov 24, '
            '2014" where the app\'s own Streak card reads "24.11.2014".',
      );
    });

    test('#1 the formatter is pinned to UTC, like the day key it prints', () {
      expect(
        formatter,
        contains(RegExp(r'timeZone\s*=\s*TimeZone\.getTimeZone\("UTC"\)')),
        reason: '$rule21 df.timeZone = TimeZone.getTimeZone("UTC") is the '
            'second half of longFormat upstream. A LocalDate is a UTC '
            'midnight, so a formatter left on the device zone names the '
            'previous day everywhere west of GMT.',
      );
      expect(
        formatter,
        contains(RegExp(r'GregorianCalendar\(TimeZone\.getTimeZone\("(UTC|GMT)"\)\)')),
        reason: '$rule21 …and the instant handed to it is the one '
            'LocalDate.toGregorianCalendar() builds: a GregorianCalendar in '
            'that same zone, not a default-zone one.',
      );
    });

    test('#1 java.text.DateFormat, not android.text.format.DateFormat', () {
      expect(
        _widgetCanvasSource(),
        contains('import java.text.DateFormat\n'),
        reason: '$rule21 android.text.format.DateFormat is a different class '
            'with no getDateInstance; the import is what decides which one '
            'DateFormat.MEDIUM resolves against.',
      );
    });
  });
}

/// `android/app/src/main/kotlin/.../widgets/views/WidgetCanvas.kt`, found from
/// wherever the test runner was started.
String _widgetCanvasSource() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', 'app/']) {
      final File file = File('${dir.path}/${prefix}android/app/src/main/kotlin/'
          'org/isoron/uhabits/widgets/views/WidgetCanvas.kt');
      if (file.existsSync()) return file.readAsStringSync();
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('WidgetCanvas.kt not found from ${Directory.current.path}');
}

/// The `object WidgetDateFormatter { ... }` declaration, comments stripped, so
/// no assertion below can be satisfied by prose.
String _widgetDateFormatter() {
  final String source = _widgetCanvasSource()
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp('//[^\n]*'), '');
  final int start = source.indexOf('object WidgetDateFormatter');
  if (start < 0) {
    throw StateError('object WidgetDateFormatter not found in WidgetCanvas.kt');
  }
  return source.substring(start);
}
