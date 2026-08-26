import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/habits/sleep/skip_range.dart';
import 'package:uhabits/ui/habits/sleep/sleep_section.dart';
import 'package:uhabits/ui/habits/sleep/stability_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: L10n.supportedLocales,
    home: Scaffold(body: child),
  ));
  await tester.pumpAndSettle();
}

core.Habit newHabit() {
  final core.Habit habit = core.MemoryModelFactory().buildHabit()
    ..id = 1
    ..type = core.sleepHabitType
    ..targetValue = core.sleepTargetValue;
  return habit;
}

void main() {
  setUp(() => core.setToday(core.LocalDate(9000)));
  tearDown(core.resetToday);

  group('the stability card', () {
    testWidgets('shows both spreads and the mean sleep', (tester) async {
      await pump(
        tester,
        StabilityCard(
          theme: core.LightTheme(),
          stability: const core.SleepStability(
            bedSpreadMinutes: 38.4,
            wakeSpreadMinutes: 21.6,
            meanAsleepMinutes: 424,
            nightCount: 14,
          ),
        ),
      );
      expect(find.text('±38 min'), findsOneWidget,
          reason: 'sleep.stability#1');
      expect(find.text('±22 min'), findsOneWidget,
          reason: 'sleep.stability#1');
      expect(find.text('7:04'), findsOneWidget, reason: 'sleep.stability#1');
    });

    testWidgets('says nothing rather than showing a zero when it cannot tell',
        (tester) async {
      // Below the minimum the core returns null, and a zero here would read as
      // a perfectly steady schedule.
      await pump(
        tester,
        StabilityCard(theme: core.LightTheme(), stability: null),
      );
      expect(find.textContaining('±'), findsNothing,
          reason: 'sleep.stability#3');
      expect(find.text('0'), findsNothing, reason: 'sleep.stability#3');
      expect(find.textContaining('No data'), findsOneWidget,
          reason: 'sleep.stability#3');
      expect(tester.takeException(), isNull, reason: 'sleep.ui#5');
    });
  });


  group('marking a range', () {
    test('writes a skip on every day of it', () {
      final core.Habit habit = newHabit();
      const SkipRange(8990, 8993).applyTo(habit);

      for (var day = 8990; day <= 8993; day++) {
        expect(habit.originalEntries.get(core.LocalDate(day)).value,
            core.Entry.skip,
            reason: 'sleep.skip#1');
      }
      expect(habit.originalEntries.get(core.LocalDate(8989)).value,
          core.Entry.unknown,
          reason: 'sleep.skip#1');
      expect(habit.originalEntries.get(core.LocalDate(8994)).value,
          core.Entry.unknown,
          reason: 'sleep.skip#1');
    });

    test('a single day is a range of one', () {
      final core.Habit habit = newHabit();
      const SkipRange range = SkipRange(9000, 9000);
      expect(range.length, 1, reason: 'sleep.skip#1');
      range.applyTo(habit);
      expect(habit.originalEntries.get(core.LocalDate(9000)).value,
          core.Entry.skip,
          reason: 'sleep.skip#1');
    });

    test('a backwards range writes nothing', () {
      final core.Habit habit = newHabit();
      const SkipRange(9000, 8990).applyTo(habit);
      expect(habit.originalEntries.getKnown(), isEmpty,
          reason: 'sleep.skip#1');
    });

    test('a range entirely in the past is accepted', () {
      // No rule stops back-dating. The count on the screen is what keeps it
      // honest, not a restriction here.
      final core.Habit habit = newHabit();
      const SkipRange(8000, 8002).applyTo(habit);
      expect(
        habit.originalEntries
            .getKnown()
            .where((core.Entry e) => e.value == core.Entry.skip)
            .length,
        3,
        reason: 'sleep.skip#2',
      );
    });

    test('clearing leaves no entry rather than a zero', () {
      // A zero would be a night of no sleep, and would stop later data from
      // healing the day.
      final core.Habit habit = newHabit();
      const SkipRange range = SkipRange(8990, 8992);
      range.applyTo(habit);
      range.clearFrom(habit);
      for (var day = 8990; day <= 8992; day++) {
        expect(habit.originalEntries.get(core.LocalDate(day)).value,
            core.Entry.unknown,
            reason: 'sleep.skip#1');
      }
    });

    test('clearing leaves a scored day alone', () {
      final core.Habit habit = newHabit();
      habit.originalEntries.add(core.Entry(core.LocalDate(8991), 87000));
      const SkipRange(8990, 8992).clearFrom(habit);
      expect(habit.originalEntries.get(core.LocalDate(8991)).value, 87000,
          reason: 'sleep.skip#1');
    });

    test('marking keeps the note the person left on the day', () {
      // The trip is the app's mark; the note is the person's, and nothing the
      // app writes over a day is allowed to take it.
      final core.Habit habit = newHabit();
      habit.originalEntries
          .add(core.Entry(core.LocalDate(8991), 87000, notes: 'wine'));

      const SkipRange(8990, 8992).applyTo(habit);

      expect(habit.originalEntries.get(core.LocalDate(8991)).value,
          core.Entry.skip,
          reason: 'sleep.skip#1');
      expect(habit.originalEntries.get(core.LocalDate(8991)).notes, 'wine',
          reason: 'computed.day-write#7');
    });

    test('and un-marking keeps it too', () {
      final core.Habit habit = newHabit();
      habit.originalEntries
          .add(core.Entry(core.LocalDate(8991), 87000, notes: 'wine'));
      const SkipRange range = SkipRange(8990, 8992);
      range.applyTo(habit);

      range.clearFrom(habit);

      expect(habit.originalEntries.get(core.LocalDate(8991)).value,
          core.Entry.unknown,
          reason: 'sleep.skip#1');
      expect(habit.originalEntries.get(core.LocalDate(8991)).notes, 'wine',
          reason: 'computed.day-write#7 — the note outlives the mark in both '
              'directions, or a trip marked and un-marked erases it twice');
    });
  });

  group('which nights the spread is measured from', () {
    core.SleepEpisode night(int day) => core.SleepEpisode(
          bedStartMillis: (day - 1 + 10957) * 86400000 + 1380 * 60000,
          wakeEndMillis: (day + 10957) * 86400000 + 420 * 60000,
          asleepMinutes: 480,
          utcOffsetMinutes: 0,
        );

    Map<int, core.SleepEpisode> fortnight() => <int, core.SleepEpisode>{
          for (var i = 0; i < 14; i++) 9000 - i: night(9000 - i),
        };

    test('a skipped day is left out', () {
      // One week of travel would otherwise inflate the spread for a fortnight
      // after it, and call the person erratic when what they were was away.
      final List<core.SleepEpisode> all =
          stabilityNights(fortnight(), const <int>{}, 9000);
      final List<core.SleepEpisode> withoutTrip =
          stabilityNights(fortnight(), <int>{8996, 8995, 8994}, 9000);

      expect(all, hasLength(14), reason: 'sleep.stability#2');
      expect(withoutTrip, hasLength(11), reason: 'sleep.stability#2');
    });

    test('a day with no night is left out too', () {
      final Map<int, core.SleepEpisode> gaps = fortnight()
        ..remove(8998)
        ..remove(8997);
      expect(stabilityNights(gaps, const <int>{}, 9000), hasLength(12),
          reason: 'sleep.stability#2');
    });

    test('nothing outside the window is counted', () {
      final Map<int, core.SleepEpisode> wide = <int, core.SleepEpisode>{
        for (var i = 0; i < 40; i++) 9000 - i: night(9000 - i),
      };
      expect(stabilityNights(wide, const <int>{}, 9000), hasLength(14),
          reason: 'sleep.stability#2');
    });

    test('the same list is what the goal suggestion sees', () {
      // A trip must not drag the suggested bedtime after it either, which it
      // would if the two measures were fed from different lists.
      final Map<int, core.SleepEpisode> nights = fortnight();
      final Set<int> skipped = <int>{8996, 8995, 8994};
      expect(
        stabilityNights(nights, skipped, 9000).length,
        lessThan(stabilityNights(nights, const <int>{}, 9000).length),
        reason: 'sleep.suggest-goal#1',
      );
    });
  });

}
