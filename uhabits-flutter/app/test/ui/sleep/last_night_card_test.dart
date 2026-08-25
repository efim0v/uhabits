import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/sleep/last_night_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const core.SleepGoal goal =
    core.SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

const int midnight = 1756080000000;

core.SleepBreakdown night(int bedMinutes, int wakeMinutes, int asleepMinutes) =>
    core.scoreNight(
      core.SleepEpisode(
        bedStartMillis: midnight + bedMinutes * 60000,
        wakeEndMillis: midnight + (wakeMinutes + 1440) * 60000,
        asleepMinutes: asleepMinutes,
        utcOffsetMinutes: 0,
      ),
      goal,
      0,
    )!;

Future<void> pumpCard(
  WidgetTester tester, {
  core.SleepBreakdown? breakdown,
  double habitScore = 0.78,
  int streakDays = 12,
  core.Theme? theme,
  bool use24HourFormat = true,
}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: L10n.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(alwaysUse24HourFormat: use24HourFormat),
      child: Scaffold(
        body: LastNightCard(
          theme: theme ?? core.LightTheme(),
          breakdown: breakdown,
          habitScore: habitScore,
          streakDays: streakDays,
          onEnterByHand: () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('a scored night', () {
    testWidgets('shows the percent and all three components', (tester) async {
      // 23:41 / 07:12 / 6:48 — the second control vector of the spec.
      await pumpCard(tester, breakdown: night(1421, 432, 408));

      expect(find.text('87'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.text('%'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.text('23:41'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.text('07:12'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.text('6:48'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.text('93%'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.text('99%'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.text('75%'), findsOneWidget, reason: 'sleep.ui#2');
    });

    testWidgets('the duration is hours and minutes, not a clock time',
        (tester) async {
      // 6:48 of sleep is a quantity; rendering it through the locale's clock
      // format would make it "6:48 AM", which is a different thing entirely.
      await pumpCard(
        tester,
        breakdown: night(1421, 432, 408),
        use24HourFormat: false,
      );
      expect(find.text('6:48'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.textContaining('6:48 '), findsNothing,
          reason: 'sleep.ui#2');
    });

    testWidgets('times follow the device clock setting', (tester) async {
      await pumpCard(
        tester,
        breakdown: night(1421, 432, 408),
        use24HourFormat: false,
      );
      expect(find.text('23:41'), findsNothing, reason: 'sleep.ui#2');
      expect(find.textContaining('11:41'), findsOneWidget,
          reason: 'sleep.ui#2');
    });

    testWidgets('the accumulated score and streak are shown beside it',
        (tester) async {
      await pumpCard(
        tester,
        breakdown: night(1421, 432, 408),
        habitScore: 0.78,
        streakDays: 12,
      );
      expect(find.textContaining('78%'), findsOneWidget, reason: 'sleep.ui#2');
      expect(find.textContaining('12'), findsWidgets, reason: 'sleep.ui#2');
    });
  });

  group('the explanation', () {
    testWidgets('names the duration when that is what cost the most',
        (tester) async {
      // In bed on time, up on time, five hours of sleep.
      await pumpCard(tester, breakdown: night(1380, 420, 300));
      expect(find.textContaining('slept less'), findsOneWidget,
          reason: 'sleep.scoring#8');
    });

    testWidgets('names the bedtime when that is what cost the most',
        (tester) async {
      await pumpCard(tester, breakdown: night(1560, 420, 480));
      expect(find.textContaining('went to bed off schedule'), findsOneWidget,
          reason: 'sleep.scoring#8');
    });

    testWidgets('names the wake time when that is what cost the most',
        (tester) async {
      await pumpCard(tester, breakdown: night(1380, 600, 480));
      expect(find.textContaining('got up off schedule'), findsOneWidget,
          reason: 'sleep.scoring#8');
    });

    testWidgets('says nothing was wrong with a night that was fine',
        (tester) async {
      await pumpCard(tester, breakdown: night(1380, 420, 480));
      expect(find.textContaining('On schedule'), findsOneWidget,
          reason: 'sleep.scoring#8');
    });
  });

  group('typing a night in', () {
    testWidgets('is offered even when a night was recorded', (tester) async {
      // The watch can record a night and get it wrong; somewhere to say so is
      // not only for the nights it missed.
      var entered = 0;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: L10n.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: Scaffold(
            body: LastNightCard(
              theme: core.LightTheme(),
              breakdown: night(1421, 432, 408),
              habitScore: 0.78,
              streakDays: 12,
              onEnterByHand: () => entered++,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter night'));
      await tester.pumpAndSettle();
      expect(entered, 1, reason: 'sleep.ui#5');
    });

    testWidgets('is offered when there is no night at all', (tester) async {
      var entered = 0;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: L10n.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: Scaffold(
            body: LastNightCard(
              theme: core.LightTheme(),
              breakdown: null,
              habitScore: 0,
              streakDays: 0,
              onEnterByHand: () => entered++,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter night'));
      await tester.pumpAndSettle();
      expect(entered, 1, reason: 'sleep.ui#5');
    });
  });

  group('without data', () {
    testWidgets('renders without throwing and says so', (tester) async {
      await pumpCard(tester, breakdown: null, habitScore: 0, streakDays: 0);
      expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
      expect(find.textContaining('No data'), findsOneWidget,
          reason: 'sleep.ui#5');
    });
  });

  group('themes', () {
    testWidgets('reads its colours from the theme, in all three of them',
        (tester) async {
      for (final core.Theme theme in <core.Theme>[
        core.LightTheme(),
        core.DarkTheme(),
        core.PureBlackTheme(),
      ]) {
        await pumpCard(
          tester,
          breakdown: night(1421, 432, 408),
          theme: theme,
        );
        expect(tester.takeException(), isNull, reason: 'sleep.ui#5');

        final Material card = tester.widget<Material>(
          find.ancestor(
            of: find.text('23:41'),
            matching: find.byType(Material),
          ).last,
        );
        expect(card.color, isNotNull, reason: 'sleep.ui#5');
      }
    });
  });
}
