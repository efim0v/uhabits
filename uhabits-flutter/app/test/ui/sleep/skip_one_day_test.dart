/// Marking one day as not counting.
///
/// It used to be a card of its own with a date-range picker, which is a heavy
/// instrument for a question that is always about one night, and it lived
/// apart from the place a person describes that night. The toggle now sits in
/// the sheet the night is typed into — which opens from the habit list, from
/// the calendar and from the last-night block, so it is wherever the day is.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/sleep/manual_entry.dart';
import 'package:uhabits/ui/habits/sleep/manual_entry_sheet.dart';
import 'package:uhabits/ui/habits/sleep/sleep_section.dart';
import 'package:uhabits/ui/habits/sleep/skip_range.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int day = 9000;
  final int wake = (day + 10957) * 86400000 + 7 * 3600000;
  final int bed = wake - 450 * 60000;

  late Database database;
  late AppScope scope;
  late Habit habit;

  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    core_time.DateUtils.setFixedLocalTime(
        (day + 10957) * 86400000 + 10 * 3600000);
    setToday(LocalDate(day));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
  });

  tearDown(() {
    scope.close();
    core_time.DateUtils.setFixedTimeZone(null);
    core_time.DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  /// Opens the sheet the way the app does, and returns when it has closed.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => enterNightByHand(
                  context,
                  scope: scope,
                  habit: habit,
                  goal: scope.sleepRepository.goalFor(habit.id!)!,
                  day: day,
                  theme: LightTheme(),
                  onChanged: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Enter night'));
    await tester.pumpAndSettle();
  }

  int valueOn(int d) => habit.originalEntries.get(LocalDate(d)).value;

  group('the toggle', () {
    testWidgets('marks the day, and the night is stored all the same',
        (tester) async {
      await openSheet(tester);
      await tester.tap(find.byKey(ManualEntrySheet.skipToggleKey));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(valueOn(day), Entry.skip, reason: 'sleep.skip#3');
      expect(scope.sleepRepository.forDay(habit.id!, day), isNotNull,
          reason: 'sleep.skip#7 — the night happened, it just does not count');
    });

    testWidgets('left alone, the day is scored as usual', (tester) async {
      await openSheet(tester);
      await confirm(tester);

      expect(valueOn(day), isNot(Entry.skip), reason: 'sleep.skip#3');
      expect(valueOn(day), greaterThan(0), reason: 'sleep.skip#3');
    });

    testWidgets('opens showing the day it is about', (tester) async {
      SkipRange(day, day).applyTo(habit);

      await openSheet(tester);

      final SwitchListTile toggle = tester
          .widget<SwitchListTile>(find.byKey(ManualEntrySheet.skipToggleKey));
      expect(toggle.value, isTrue,
          reason: 'sleep.skip#3 — a toggle that opens off on a skipped day '
              'would un-skip it the moment the person confirms anything else');
    });

    testWidgets('turning it off puts the day back into the reckoning',
        (tester) async {
      SkipRange(day, day).applyTo(habit);
      scope.sleepRepository.upsert(
        habit.id!,
        day,
        SleepEpisode(
          bedStartMillis: bed,
          wakeEndMillis: wake,
          asleepMinutes: 450,
          utcOffsetMinutes: 0,
        ),
        manual: true,
      );

      await openSheet(tester);
      await tester.tap(find.byKey(ManualEntrySheet.skipToggleKey));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(valueOn(day), isNot(Entry.skip), reason: 'sleep.skip#3');
      expect(valueOn(day), greaterThan(0),
          reason: 'sleep.skip#3 — and it is scored, not merely un-skipped');
    });
  });

  group('what the sheet opens on', () {
    testWidgets('the night already recorded, not the goal', (tester) async {
      // Otherwise opening a night to mark it skipped would overwrite what the
      // watch measured with the times the person was aiming for.
      scope.sleepRepository.upsert(
        habit.id!,
        day,
        SleepEpisode(
          // 01:30 to 09:00, nowhere near the goal's 23:00 to 07:00.
          bedStartMillis: (day + 10957) * 86400000 + 90 * 60000,
          wakeEndMillis: (day + 10957) * 86400000 + 9 * 3600000,
          asleepMinutes: 450,
          utcOffsetMinutes: 0,
        ),
        manual: true,
      );

      await openSheet(tester);
      await tester.tap(find.byKey(ManualEntrySheet.skipToggleKey));
      await tester.pumpAndSettle();
      await confirm(tester);

      final SleepEpisode kept = scope.sleepRepository.forDay(habit.id!, day)!;
      expect(localMinutesOf(kept.bedStartMillis, 0), 90,
          reason: 'sleep.skip#7');
      expect(localMinutesOf(kept.wakeEndMillis, 0), 9 * 60,
          reason: 'sleep.skip#7');
    });
  });

  group('the round trip', () {
    test('a night survives being turned into the sheet and back', () {
      final SleepEpisode original = SleepEpisode(
        bedStartMillis: bed,
        wakeEndMillis: wake,
        asleepMinutes: 400,
        utcOffsetMinutes: 0,
      );

      final ManualNight night =
          ManualNight.fromEpisode(original, day: day, skipped: true);
      final SleepEpisode back = night.toEpisode();

      expect(back.bedStartMillis, original.bedStartMillis,
          reason: 'sleep.skip#7');
      expect(back.wakeEndMillis, original.wakeEndMillis,
          reason: 'sleep.skip#7');
      expect(back.asleepMinutes, original.asleepMinutes,
          reason: 'sleep.skip#7 — including the part that was typed over');
      expect(night.skipped, isTrue, reason: 'sleep.skip#7');
    });
  });
}
