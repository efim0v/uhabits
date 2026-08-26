/// The four sleep blocks, assembled, at the metrics of real phones.
///
/// Each block is tested on its own elsewhere. What is tested here is the thing
/// that only shows once they are put together and given a real amount of room:
/// that nothing overflows, on a narrow phone or a wide one, in any of the
/// three themes, and in the state a brand new habit is in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/sleep/last_night_card.dart';
import 'package:uhabits/ui/habits/sleep/nights_chart.dart';
import 'package:uhabits/ui/habits/sleep/stability_card.dart';
import 'package:uhabits/ui/habits/sleep/suggestion_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const core.SleepGoal goal =
    core.SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

int startOfDay(int day) => (day + 10957) * 86400000;

core.SleepEpisode night(int day, {int bed = 1380, int wake = 420}) =>
    core.SleepEpisode(
      bedStartMillis: startOfDay(day - 1) + bed * 60000,
      wakeEndMillis: startOfDay(day) + wake * 60000,
      asleepMinutes: 470,
      utcOffsetMinutes: 0,
    );

/// Every phone this app is likely to meet, from the narrowest to a tablet.
const Map<String, Size> screens = <String, Size>{
  'iPhone SE': Size(320, 568),
  'iPhone 15': Size(393, 852),
  'iPhone 15 Pro Max': Size(430, 932),
  'Pixel 4a': Size(393, 851),
  'iPad': Size(768, 1024),
};

Widget section({
  required core.Theme theme,
  required Map<int, core.SleepEpisode> nights,
  required Set<int> skipped,
  required core.SleepStability? stability,
  required bool withSuggestion,
  int today = 9000,
}) {
  return MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: L10n.supportedLocales,
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (withSuggestion)
              Builder(
                builder: (BuildContext context) => SuggestionCard(
                  theme: theme,
                  message: L10n.of(context).sleepSuggestSkip,
                  applyLabel: L10n.of(context).sleepMarkSkipped,
                  onApply: () {},
                  onDismiss: () {},
                ),
              ),
            LastNightCard(
              theme: theme,
              breakdown: nights.isEmpty
                  ? null
                  : core.scoreNight(nights[today] ?? nights.values.first,
                      goal, 0),
              habitScore: 0.78,
              streakDays: 12,
              onEnterByHand: () {},
            ),
            NightsChart(
              theme: theme,
              color: const core.Color.fromRgb(0x2196F3),
              nights: nights,
              skippedDays: skipped,
              goal: goal,
              effectiveOffsets: <int, int>{
                for (final int d in nights.keys) d: 0,
              },
              lastDay: today,
              firstDay: today - 13,
            ),
            StabilityCard(theme: theme, stability: stability),
          ],
        ),
      ),
    ),
  );
}

Map<int, core.SleepEpisode> fortnight(int today) => <int, core.SleepEpisode>{
      for (var i = 0; i < 14; i++)
        if (i != 5 && i != 6)
          today - i: night(today - i, bed: 1380 + i * 7, wake: 420 + i * 3),
    };

void main() {
  const core.SleepStability stability = core.SleepStability(
    bedSpreadMinutes: 38.4,
    wakeSpreadMinutes: 21.6,
    meanAsleepMinutes: 424,
    nightCount: 12,
  );

  group('a full fortnight', () {
    for (final MapEntry<String, Size> screen in screens.entries) {
      testWidgets('fits on ${screen.key}', (WidgetTester tester) async {
        tester.view.physicalSize = screen.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(section(
          theme: core.LightTheme(),
          nights: fortnight(9000),
          skipped: <int>{8994, 8995},
          stability: stability,
          withSuggestion: true,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
        expect(find.byType(LastNightCard), findsOneWidget,
            reason: 'sleep.ui#2');
        expect(find.byType(NightsChart), findsOneWidget, reason: 'sleep.ui#3');
        expect(find.byType(StabilityCard), findsOneWidget,
            reason: 'sleep.stability#1');
      });
    }
  });

  group('every theme', () {
    for (final core.Theme theme in <core.Theme>[
      core.LightTheme(),
      core.DarkTheme(),
      core.PureBlackTheme(),
    ]) {
      testWidgets('renders in ${theme.runtimeType}',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(section(
          theme: theme,
          nights: fortnight(9000),
          skipped: <int>{8994},
          stability: stability,
          withSuggestion: false,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
      });
    }
  });

  group('a habit with nothing in it yet', () {
    testWidgets('renders on the narrowest phone without throwing',
        (WidgetTester tester) async {
      // The state every sleep habit is in on the day it is created, and the
      // state it returns to when access to Health is refused.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(section(
        theme: core.PureBlackTheme(),
        nights: const <int, core.SleepEpisode>{},
        skipped: const <int>{},
        stability: null,
        withSuggestion: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
      expect(find.byType(NightsChart), findsOneWidget, reason: 'sleep.ui#5');
      expect(find.byType(StabilityCard), findsOneWidget,
          reason: 'sleep.ui#5');
    });
  });

  group('a very long night', () {
    testWidgets('a fourteen hour lie-in does not break the chart',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(section(
        theme: core.LightTheme(),
        nights: <int, core.SleepEpisode>{
          9000: night(9000, bed: 1200, wake: 600),
        },
        skipped: const <int>{},
        stability: null,
        withSuggestion: false,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
    });
  });
}
