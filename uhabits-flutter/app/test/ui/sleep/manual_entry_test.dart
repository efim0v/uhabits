import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/sleep/manual_entry.dart';
import 'package:uhabits/ui/habits/sleep/manual_entry_sheet.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

const core.SleepGoal goal =
    core.SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

/// Day 9000 since 2000 begins at this UTC instant.
int startOfDay(int day) => (day + 10957) * 86400000;


/// A host whose MediaQuery covers the navigator overlay too.
///
/// A modal sheet is inserted into that overlay, which sits above `home`: a
/// MediaQuery wrapped around `home` is not an ancestor of the sheet, and the
/// sheet would silently fall back to the twelve hour default.
Widget host(void Function(BuildContext) onPressed) => MaterialApp(
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
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  group('the arithmetic of a typed-in night', () {
    test('the wake time lands on the day it was entered for', () {
      const ManualNight night =
          ManualNight(day: 9000, bedMinutes: 1380, wakeMinutes: 420);
      final core.SleepEpisode episode = night.toEpisode();
      expect(episode.wakeEndMillis, startOfDay(9000) + 420 * 60000,
          reason: 'sleep.merge#7');
    });

    test('a bedtime later on the clock than the wake time crosses midnight',
        () {
      // 23:00 to 07:00 is eight hours forward, not sixteen back.
      const ManualNight night =
          ManualNight(day: 9000, bedMinutes: 1380, wakeMinutes: 420);
      expect(night.inBedMinutes, 480, reason: 'sleep.merge#7');
      final core.SleepEpisode episode = night.toEpisode();
      expect(episode.bedStartMillis, startOfDay(8999) + 1380 * 60000,
          reason: 'sleep.merge#7');
    });

    test('a night entirely within one day is handled too', () {
      // Asleep at 01:00, up at 09:00.
      const ManualNight night =
          ManualNight(day: 9000, bedMinutes: 60, wakeMinutes: 540);
      expect(night.inBedMinutes, 480, reason: 'sleep.merge#7');
      expect(night.toEpisode().bedStartMillis, startOfDay(9000) + 60 * 60000,
          reason: 'sleep.merge#7');
    });

    test('actual sleep defaults to the whole time in bed', () {
      const ManualNight night =
          ManualNight(day: 9000, bedMinutes: 1380, wakeMinutes: 420);
      expect(night.toEpisode().asleepMinutes, 480, reason: 'sleep.merge#5');
    });

    test('actual sleep can be shorter, and the boundaries stay put', () {
      // In bed at 23:00, asleep at 02:00, up at 07:00: the times are perfect
      // and only the duration is short. Keeping them apart is the whole point.
      const ManualNight night = ManualNight(
        day: 9000,
        bedMinutes: 1380,
        wakeMinutes: 420,
        asleepMinutes: 300,
      );
      final core.SleepEpisode episode = night.toEpisode();
      expect(episode.asleepMinutes, 300, reason: 'sleep.scoring#6');
      expect(episode.inBedMinutes, 480, reason: 'sleep.scoring#6');

      final core.SleepBreakdown scored = core.scoreNight(episode, goal, 0)!;
      expect(scored.devBed, 0, reason: 'sleep.scoring#6');
      expect(scored.devWake, 0, reason: 'sleep.scoring#6');
      expect(scored.devSleep, 150, reason: 'sleep.scoring#6');
    });

    test('sleep longer than the time in bed is impossible', () {
      // A slip of the finger must not claim nine hours of sleep in an eight
      // hour night.
      const ManualNight night = ManualNight(
        day: 9000,
        bedMinutes: 1380,
        wakeMinutes: 420,
        asleepMinutes: 600,
      );
      expect(night.toEpisode().asleepMinutes, 480, reason: 'sleep.merge#5');
    });

    test('negative sleep is impossible too', () {
      const ManualNight night = ManualNight(
        day: 9000,
        bedMinutes: 1380,
        wakeMinutes: 420,
        asleepMinutes: -30,
      );
      expect(night.toEpisode().asleepMinutes, 0, reason: 'sleep.merge#5');
    });

    test('the boundaries are the ones given, not inferred from sleep', () {
      const ManualNight night =
          ManualNight(day: 9000, bedMinutes: 1380, wakeMinutes: 420);
      expect(night.toEpisode().derivedFromAsleep, isFalse,
          reason: 'sleep.merge#6');
    });

    test('a timezone offset moves the instants, not the local times', () {
      const ManualNight home =
          ManualNight(day: 9000, bedMinutes: 1380, wakeMinutes: 420);
      const ManualNight east = ManualNight(
        day: 9000,
        bedMinutes: 1380,
        wakeMinutes: 420,
        utcOffsetMinutes: 180,
      );
      expect(east.toEpisode().wakeEndMillis,
          home.toEpisode().wakeEndMillis - 180 * 60000,
          reason: 'sleep.merge#7');
      expect(
        core.localMinutesOf(east.toEpisode().wakeEndMillis, 180),
        420,
        reason: 'sleep.merge#7',
      );
    });
  });

  group('the sheet', () {
    testWidgets('opens on the goal rather than on nothing', (tester) async {
      await tester.pumpWidget(host((BuildContext context) {
        showManualEntrySheet(context,
            theme: core.LightTheme(), day: 9000, goal: goal);
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('23:00'), findsOneWidget, reason: 'sleep.ui#5');
      expect(find.text('07:00'), findsOneWidget, reason: 'sleep.ui#5');
      expect(find.text('8:00'), findsOneWidget, reason: 'sleep.ui#5');
    });

    testWidgets('confirming returns the night', (tester) async {
      ManualNight? result;
      await tester.pumpWidget(host((BuildContext context) async {
        result = await showManualEntrySheet(context,
            theme: core.LightTheme(), day: 9000, goal: goal);
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(result, isNotNull, reason: 'sleep.ui#5');
      expect(result!.day, 9000, reason: 'sleep.ui#5');
      expect(result!.bedMinutes, 1380, reason: 'sleep.ui#5');
      expect(result!.wakeMinutes, 420, reason: 'sleep.ui#5');
      expect(result!.asleepMinutes, isNull,
          reason: 'sleep.ui#5 — untouched, so it follows the two times');
    });

    testWidgets('backing out returns nothing', (tester) async {
      ManualNight? result;
      var completed = false;
      await tester.pumpWidget(host((BuildContext context) async {
        result = await showManualEntrySheet(context,
            theme: core.LightTheme(), day: 9000, goal: goal);
        completed = true;
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(ManualEntrySheet))).pop();
      await tester.pumpAndSettle();

      expect(completed, isTrue, reason: 'sleep.ui#5');
      expect(result, isNull, reason: 'sleep.ui#5');
    });

    testWidgets('a night already entered is opened as it stands',
        (tester) async {
      await tester.pumpWidget(host((BuildContext context) {
        showManualEntrySheet(
          context,
          theme: core.LightTheme(),
          day: 9000,
          goal: goal,
          initial: const ManualNight(
            day: 9000,
            bedMinutes: 1440 - 30,
            wakeMinutes: 450,
            asleepMinutes: 400,
          ),
        );
      }));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('23:30'), findsOneWidget, reason: 'sleep.ui#5');
      expect(find.text('07:30'), findsOneWidget, reason: 'sleep.ui#5');
      expect(find.text('6:40'), findsOneWidget, reason: 'sleep.ui#5');
    });
  });
}
