import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/list/list_header.dart'
    show IntlLocalDateFormatter;
import 'package:uhabits/ui/habits/sleep/nights_chart.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const core.SleepGoal goal =
    core.SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

/// Day 9000 since 2000 begins at this UTC instant.
int startOfDay(int day) => (day + 10957) * 86400000;

core.SleepEpisode nightOn(
  int day, {
  int bedMinutes = 1380,
  int wakeMinutes = 420,
  int asleepMinutes = 480,
}) =>
    core.SleepEpisode(
      bedStartMillis: startOfDay(day - 1) + bedMinutes * 60000,
      wakeEndMillis: startOfDay(day) + wakeMinutes * 60000,
      asleepMinutes: asleepMinutes,
      utcOffsetMinutes: 0,
    );

Future<void> pumpChart(
  WidgetTester tester, {
  required List<int> days,
  Map<int, core.SleepEpisode>? nights,
  Set<int> skipped = const <int>{},
  Map<int, int>? offsets,
  int visibleDays = 14,
}) async {
  final int lastDay = days.isEmpty ? 9000 : days.reduce((a, b) => a > b ? a : b);
  final int firstDay = lastDay - visibleDays + 1;
  final Map<int, core.SleepEpisode> resolved = nights ??
      <int, core.SleepEpisode>{for (final int d in days) d: nightOn(d)};

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
        body: NightsChart(
          theme: core.LightTheme(),
          color: const core.Color.fromRgb(0x2196F3),
          nights: resolved,
          skippedDays: skipped,
          goal: goal,
          effectiveOffsets: offsets ??
              <int, int>{for (final int d in days) d: 0},
          lastDay: lastDay,
          firstDay: firstDay,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('orientation', () {
    testWidgets('days run left to right, newest on the right', (tester) async {
      await pumpChart(tester, days: <int>[8998, 8999, 9000]);
      final List<NightBar> bars =
          tester.widgetList<NightBar>(find.byType(NightBar)).toList();
      expect(bars.length, 3, reason: 'sleep.ui#3');

      final double oldestX = tester.getCenter(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 8998),
      ).dx;
      final double newestX = tester.getCenter(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 9000),
      ).dx;
      expect(newestX, greaterThan(oldestX), reason: 'sleep.ui#3');
    });

    testWidgets('a later bedtime sits lower on the chart', (tester) async {
      // Time runs downward: an 01:00 bedtime is below a 23:00 one.
      await pumpChart(
        tester,
        days: <int>[8999, 9000],
        nights: <int, core.SleepEpisode>{
          8999: nightOn(8999, bedMinutes: 1380),
          9000: nightOn(9000, bedMinutes: 1500),
        },
      );
      final Rect early = tester.getRect(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 8999),
      );
      final Rect late = tester.getRect(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 9000),
      );
      final NightBar earlyBar = tester.widget<NightBar>(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 8999),
      );
      final NightBar lateBar = tester.widget<NightBar>(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 9000),
      );
      expect(lateBar.topFraction, greaterThan(earlyBar.topFraction),
          reason: 'sleep.ui#3');
      expect(early.height, greaterThan(0), reason: 'sleep.ui#3');
      expect(late.height, greaterThan(0), reason: 'sleep.ui#3');
    });

    testWidgets('the window wraps around midnight', (tester) async {
      // 23:00 is early in the window and 01:00 is later, even though one is a
      // larger number of minutes than the other.
      final SleepWindow window =
          SleepWindow.covering(goal: goal, nights: const <int, core.SleepEpisode>{});
      final double? evening = window.fractionOf(1380);
      final double? afterMidnight = window.fractionOf(60);
      expect(evening, isNotNull, reason: 'sleep.ui#3');
      expect(afterMidnight, isNotNull, reason: 'sleep.ui#3');
      expect(afterMidnight!, greaterThan(evening!), reason: 'sleep.ui#3');
    });

    testWidgets('a time far from any night is not drawn', (tester) async {
      // With nothing recorded the window is the goal and an hour either side,
      // so midday is outside it.
      final SleepWindow window =
          SleepWindow.covering(goal: goal, nights: const <int, core.SleepEpisode>{});
      expect(window.fractionOf(12 * 60), isNull, reason: 'sleep.ui#3');
    });
  });

  group('the window is measured from the nights it has to hold', () {
    // It used to be a constant — 20:00 plus fifteen hours — and a night
    // outside it was dropped without trace. Someone who wakes at noon saw an
    // empty strip and no reason for it.
    core.SleepEpisode at(int day, {required int bed, required int wake}) {
      final int startOfDay = (day + 10957) * 86400000;
      return core.SleepEpisode(
        bedStartMillis: startOfDay - 86400000 + bed * 60000,
        wakeEndMillis: startOfDay + wake * 60000,
        asleepMinutes: 400,
        utcOffsetMinutes: 0,
      );
    }

    test('a night the old window would have dropped is inside this one', () {
      // Bed 05:28, up 13:31 — one of the real nights that vanished.
      final Map<int, core.SleepEpisode> nights = <int, core.SleepEpisode>{
        9000: at(9000, bed: 24 * 60 + 5 * 60 + 28, wake: 13 * 60 + 31),
      };
      final SleepWindow window =
          SleepWindow.covering(goal: goal, nights: nights);

      expect(window.fractionOf(5 * 60 + 28), isNotNull, reason: 'sleep.ui#10');
      expect(window.fractionOf(13 * 60 + 31), isNotNull, reason: 'sleep.ui#10');
    });

    test('the goal is always inside it, whatever the nights say', () {
      final Map<int, core.SleepEpisode> nights = <int, core.SleepEpisode>{
        9000: at(9000, bed: 24 * 60 + 5 * 60, wake: 13 * 60),
      };
      final SleepWindow window =
          SleepWindow.covering(goal: goal, nights: nights);

      expect(window.fractionOf(goal.bedMinutes), isNotNull,
          reason: 'sleep.ui#10 — or the target band is cropped instead');
      expect(window.fractionOf(goal.wakeMinutes), isNotNull,
          reason: 'sleep.ui#10');
    });

    test('with nothing recorded it stays tight around the goal', () {
      final SleepWindow window = SleepWindow.covering(
          goal: goal, nights: const <int, core.SleepEpisode>{});
      // The goal is 23:00 to 07:00 — eight hours — plus an hour either side.
      expect(window.spanMinutes, 10 * 60, reason: 'sleep.ui#10');
      expect(window.startMinutes, 22 * 60, reason: 'sleep.ui#10');
    });

    test('it never runs past a whole day', () {
      final Map<int, core.SleepEpisode> nights = <int, core.SleepEpisode>{
        9000: at(9000, bed: 24 * 60 + 11 * 60, wake: 10 * 60),
      };
      final SleepWindow window =
          SleepWindow.covering(goal: goal, nights: nights);

      expect(window.spanMinutes, lessThanOrEqualTo(1440), reason: 'sleep.ui#10');
      // And at a whole day nothing at all can fall outside it.
      for (int m = 0; m < 1440; m += 30) {
        expect(window.fractionOf(m), isNotNull, reason: 'sleep.ui#10 — at $m');
      }
    });

    test('every night given to the strip really is drawable', () {
      // The property that matters, stated as a property rather than a case.
      final Map<int, core.SleepEpisode> nights = <int, core.SleepEpisode>{
        8998: at(8998, bed: 24 * 60 + 2 * 60, wake: 11 * 60 + 54),
        8999: at(8999, bed: 21 * 60 + 33, wake: 6 * 60 + 54),
        9000: at(9000, bed: 24 * 60 + 5 * 60 + 28, wake: 13 * 60 + 31),
      };
      final SleepWindow window =
          SleepWindow.covering(goal: goal, nights: nights);

      for (final core.SleepEpisode e in nights.values) {
        expect(window.fractionOf(core.localMinutesOf(e.bedStartMillis, 0)),
            isNotNull, reason: 'sleep.ui#10');
        expect(window.fractionOf(core.localMinutesOf(e.wakeEndMillis, 0)),
            isNotNull, reason: 'sleep.ui#10');
      }
    });
  });

  group('what is drawn', () {
    testWidgets('a skipped day is marked on its own column', (tester) async {
      await pumpChart(
        tester,
        days: <int>[8999, 9000],
        skipped: <int>{9000},
      );
      expect(find.byType(SkippedDayMark), findsOneWidget,
          reason: 'sleep.ui#4');
    });

    testWidgets('the mark covers exactly one day, no more', (tester) async {
      // It was diagonal hatching, and a diagonal does not stop at a column:
      // the strokes of one excused day ran into its neighbours, so three read
      // as a week.
      await pumpChart(
        tester,
        days: <int>[8997, 8998, 8999, 9000],
        skipped: <int>{8998},
        visibleDays: 4,
      );

      final Rect mark = tester.getRect(find.byType(SkippedDayMark));
      final Rect chart = tester.getRect(find.byType(NightsChart));
      expect(mark.width, lessThan(chart.width / 3),
          reason: 'sleep.ui#4 — one column of four, gutter and all');
    });

    testWidgets('a night recorded on a skipped day is still shown',
        (tester) async {
      // Skipping says the day does not count, not that nothing happened. The
      // mark used to replace the bar, so a night on a plane vanished the
      // moment it was excused.
      await pumpChart(tester, days: <int>[9000], skipped: <int>{9000});
      expect(find.byType(NightBar), findsOneWidget, reason: 'sleep.ui#4');
      expect(find.byType(SkippedDayMark), findsOneWidget,
          reason: 'sleep.ui#4');
    });

    testWidgets('a night below half is warned about in colour',
        (tester) async {
      await pumpChart(
        tester,
        days: <int>[8999, 9000],
        nights: <int, core.SleepEpisode>{
          8999: nightOn(8999),
          // 02:00 to 09:00, seven hours: the spec's worst control vector.
          9000: nightOn(9000,
              bedMinutes: 1560, wakeMinutes: 540, asleepMinutes: 420),
        },
      );
      final NightBar good = tester.widget<NightBar>(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 8999),
      );
      final NightBar poor = tester.widget<NightBar>(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 9000),
      );
      expect(good.score, greaterThanOrEqualTo(0.5), reason: 'sleep.ui#4');
      expect(poor.score, lessThan(0.5), reason: 'sleep.ui#4');
    });

    testWidgets('the newest night is marked out', (tester) async {
      await pumpChart(tester, days: <int>[8999, 9000]);
      final NightBar newest = tester.widget<NightBar>(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 9000),
      );
      final NightBar older = tester.widget<NightBar>(
        find.byWidgetPredicate((w) => w is NightBar && w.day == 8999),
      );
      expect(newest.isLast, isTrue, reason: 'sleep.ui#3');
      expect(older.isLast, isFalse, reason: 'sleep.ui#3');
    });

    testWidgets('a day with neither night nor skip draws nothing',
        (tester) async {
      await pumpChart(
        tester,
        days: <int>[8998, 9000],
        nights: <int, core.SleepEpisode>{8998: nightOn(8998)},
      );
      expect(find.byType(NightBar), findsOneWidget, reason: 'sleep.ui#3');
      expect(find.byType(SkippedDayMark), findsNothing, reason: 'sleep.ui#3');
    });
  });

  group('robustness', () {
    testWidgets('an empty chart renders without throwing', (tester) async {
      await pumpChart(tester, days: const <int>[]);
      expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
      expect(find.byType(NightBar), findsNothing, reason: 'sleep.ui#5');
    });

    testWidgets('the strip scrolls sideways', (tester) async {
      await pumpChart(
        tester,
        days: List<int>.generate(60, (int i) => 8941 + i),
        visibleDays: 60,
      );
      expect(find.byType(Scrollable), findsWidgets, reason: 'sleep.ui#3');
      await tester.drag(find.byType(NightsChart), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'sleep.ui#3');
    });

    testWidgets('a long history really is longer than the screen',
        (tester) async {
      // The strip was a fixed fourteen columns of 22 points — 308 in all,
      // narrower than any phone. It sat inside a scroll view that could never
      // scroll, and no test noticed because none of them asked whether it did.
      await pumpChart(
        tester,
        days: List<int>.generate(90, (int i) => 8911 + i),
        visibleDays: 90,
      );

      final ScrollableState scrollable =
          tester.state(find.byType(Scrollable).first);
      expect(scrollable.position.maxScrollExtent, greaterThan(0),
          reason: 'sleep.ui#8 — a strip that fits is a strip that never '
              'scrolls, whatever it is wrapped in');
    });

    testWidgets('it opens on last night, not on the oldest', (tester) async {
      await pumpChart(
        tester,
        days: List<int>.generate(90, (int i) => 8911 + i),
        visibleDays: 90,
      );

      final ScrollableState scrollable =
          tester.state(find.byType(Scrollable).first);
      expect(scrollable.position.pixels, 0,
          reason: 'sleep.ui#8 — reversed, so the resting position is the most '
              'recent night');
      expect(find.text('${core.LocalDate(9000).day}'), findsWidgets,
          reason: 'sleep.ui#8 — and last night is the one on screen');
    });

    testWidgets('only a fraction of a long history is built', (tester) async {
      // A year of nights must not be a year of widgets.
      await pumpChart(
        tester,
        days: List<int>.generate(365, (int i) => 8636 + i),
        visibleDays: 365,
      );

      expect(find.byType(NightBar, skipOffstage: false).evaluate().length,
          lessThan(60),
          reason: 'sleep.ui#8 — the strip is built on demand');
    });
  });

  group('the date under each night', () {
    testWidgets('names the weekday and the day of the month', (tester) async {
      // Day 9000 since 2000-01-01 is Thursday 22 August 2024. One column
      // only: a fortnight holds two of every weekday, and the point here is
      // the wording, not which column carries it.
      await pumpChart(tester, days: <int>[9000], visibleDays: 1);

      final core.LocalDate date = core.LocalDate(9000);
      expect(find.text('${date.day}'), findsOneWidget, reason: 'sleep.ui#7');
      expect(
        find.text(IntlLocalDateFormatter('en_US')
            .shortWeekdayName(date)
            .toUpperCase()),
        findsOneWidget,
        reason: 'sleep.ui#7 — the same wording the habit list header uses',
      );
    });

    testWidgets('every night carries its own date', (tester) async {
      await pumpChart(tester, days: <int>[8998, 8999, 9000]);

      for (final int day in <int>[8998, 8999, 9000]) {
        expect(find.text('${core.LocalDate(day).day}'), findsOneWidget,
            reason: 'sleep.ui#7 — a bar nobody can place is a bar nobody can '
                'read');
      }
    });

    testWidgets('a night with nothing recorded is still dated', (tester) async {
      // The column is empty, but the date says which night is missing.
      await pumpChart(
        tester,
        days: <int>[9000],
        nights: const <int, core.SleepEpisode>{},
      );

      expect(find.text('${core.LocalDate(9000).day}'), findsOneWidget,
          reason: 'sleep.ui#7');
    });

    testWidgets('a night whose times fall outside the window is skipped',
        (tester) async {
      await pumpChart(
        tester,
        days: <int>[9000],
        nights: <int, core.SleepEpisode>{
          // Asleep from noon to two, which no window of the evening covers.
          9000: nightOn(9000,
              bedMinutes: 720 + 1440, wakeMinutes: 840, asleepMinutes: 120),
        },
      );
      expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
    });
  });

  group('the target band', () {
    testWidgets('follows the goal as it adapts, rather than staying straight',
        (tester) async {
      // Two days of a seven hour flight: the goal has moved an hour between
      // them, so the band cannot be one straight stripe.
      await pumpChart(
        tester,
        days: <int>[8999, 9000],
        offsets: <int, int>{8999: 0, 9000: -60},
      );
      expect(tester.takeException(), isNull, reason: 'sleep.ui#3');
      expect(find.byType(NightBar), findsNWidgets(2), reason: 'sleep.ui#3');
    });
  });
}
