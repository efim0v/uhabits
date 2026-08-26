/// The offer to set a trip aside.
///
/// It was a card at the top of the screen with a "Not now" button whose body
/// was empty, so declining did nothing and the offer stood between the person
/// and their figures for ever. It is now a toast: shown once, answered however
/// it goes away, and never asked again about the same trip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int today = 9000;

  late Database database;
  late AppScope scope;
  late Habit habit;

  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    core_time.DateUtils.setFixedLocalTime(
        (today + 10957) * 86400000 + 10 * 3600000);
    setToday(LocalDate(today));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      preferencesStorage: MemoryStorage(),
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

  /// A night on [day], recorded in [offsetMinutes].
  void recordNight(int day, int offsetMinutes) {
    final int wake = (day + 10957) * 86400000 + 7 * 3600000 -
        offsetMinutes * 60000;
    scope.sleepRepository.upsert(
      habit.id!,
      day,
      SleepEpisode(
        bedStartMillis: wake - 450 * 60000,
        wakeEndMillis: wake,
        asleepMinutes: 450,
        utcOffsetMinutes: offsetMinutes,
      ),
      manual: false,
    );
  }

  /// Nights at [homeOffset], then nights at [awayOffset] from [jumpDay] on.
  void recordTrip({required int jumpDay, int homeOffset = 0, int awayOffset = 480}) {
    for (int d = today - 12; d < jumpDay; d++) {
      recordNight(d, homeOffset);
    }
    for (int d = jumpDay; d <= today; d++) {
      recordNight(d, awayOffset);
    }
    habit.recompute();
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: ShowHabitScreen(
          key: ValueKey<String?>(habit.uuid),
          habit: habit,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('when a trip is recent', () {
    testWidgets('the offer arrives as a toast, not as a card', (tester) async {
      recordTrip(jumpDay: today - 2);

      await openScreen(tester);

      expect(find.byKey(ShowHabitScreen.travelToastKey), findsOneWidget,
          reason: 'sleep.skip#8');
      expect(find.byType(SnackBar), findsOneWidget, reason: 'sleep.skip#8');
    });

    testWidgets('taking it up marks the days', (tester) async {
      recordTrip(jumpDay: today - 2);
      await openScreen(tester);

      await tester.tap(find.text('Mark'));
      await tester.pumpAndSettle();

      for (int d = today - 2; d <= today; d++) {
        expect(habit.originalEntries.get(LocalDate(d)).value, Entry.skip,
            reason: 'sleep.skip#1 — day $d');
      }
    });

    testWidgets('once it has gone, it does not come back', (tester) async {
      // The fault that started this: "Not now" had an empty body, so the same
      // offer stood on the screen every time the habit was opened.
      recordTrip(jumpDay: today - 2);
      await openScreen(tester);
      expect(find.byType(SnackBar), findsOneWidget, reason: 'sleep.skip#8');

      ScaffoldMessenger.of(
        tester.element(find.byType(ShowHabitScreen)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();

      // A real second visit, not a rebuild: the screen has to be taken down
      // and put up again, or its State is reused and the offer is never
      // reconsidered — which would make this test pass whatever the app does.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await openScreen(tester);

      expect(find.byType(SnackBar), findsNothing, reason: 'sleep.skip#8');
    });
  });

  group('when it is not', () {
    testWidgets('a trip long over is not mentioned', (tester) async {
      // An offer to excuse last month's flight is an offer to rewrite settled
      // history, and it would stand there for ever: a jump that happened never
      // stops having happened.
      recordTrip(jumpDay: today - 10);

      await openScreen(tester);

      expect(find.byType(SnackBar), findsNothing, reason: 'sleep.skip#4');
    });

    testWidgets('a habit that never moved is not mentioned', (tester) async {
      for (int d = today - 12; d <= today; d++) {
        recordNight(d, 0);
      }
      habit.recompute();

      await openScreen(tester);

      expect(find.byType(SnackBar), findsNothing, reason: 'sleep.skip#4');
    });

    testWidgets('an ordinary habit is not mentioned', (tester) async {
      final Habit plain = scope.modelFactory.buildHabit()..name = 'Run';
      scope.habitList.add(plain);
      habit = plain;

      await openScreen(tester);

      expect(find.byType(SnackBar), findsNothing, reason: 'sleep.skip#8');
    });
  });
}
