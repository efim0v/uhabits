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

  /// The chart the card built for itself under [locale].
  Future<StreakChartView> chartFor(WidgetTester tester, String locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
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
      final chart = await chartFor(tester, 'de');

      expect(chart.labelFor(today), '25.01.2015',
          reason: '$rule A German device prints the German medium date, not '
              'the US one the port built out of shortMonthName.');
    });

    testWidgets('#1 nine locales, nine medium date patterns', (tester) async {
      for (final MapEntry<String, String> e in measured.entries) {
        final chart = await chartFor(tester, e.key);
        expect(chart.labelFor(today), e.value,
            reason: '$rule Measured on a JDK for ${e.key}.');
      }
    });

    testWidgets('#1 the label is a date, not an instant: no time zone can '
        'shift it', (tester) async {
      // `df.timeZone = TimeZone.getTimeZone("UTC")` is what keeps a LocalDate
      // from being read as a local instant and printed as the day before.
      final chart = await chartFor(tester, 'en');

      expect(chart.labelFor(core.LocalDate.ymd(2015, 1, 1)), 'Jan 1, 2015',
          reason: rule);
      expect(chart.labelFor(core.LocalDate.ymd(2014, 12, 31)), 'Dec 31, 2014',
          reason: rule);
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
}
