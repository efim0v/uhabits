/// The habit screen, for a habit that has a sleep goal and one that has not.
///
/// The ported cards below the sleep blocks are the original's, and they stay
/// exactly as they are — with one exception, which is what this file pins.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/show/cards/subtitle_card_view.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits/ui/habits/sleep/last_night_card.dart';
import 'package:uhabits/ui/habits/sleep/nights_chart.dart';
import 'package:uhabits/ui/habits/sleep/stability_card.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;

  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    core_time.DateUtils.setFixedLocalTime((9000 + 10957) * 86400000 + 3 * 3600000);
    setToday(LocalDate(9000));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
  });

  tearDown(() {
    // The scope owns the database, and closing it is how a scope is told to
    // stop: a sleep sync can still be waiting on the platform, and it checks
    // before it writes. Closing the database behind the scope's back leaves
    // that check answering yes to a database that is gone.
    scope.close();
    core_time.DateUtils.setFixedTimeZone(null);
    core_time.DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  Habit addHabit({required String name, required bool sleep}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = sleep ? sleepHabitType : HabitType.numerical
      ..targetValue = sleep ? sleepTargetValue : 30
      ..unit = sleep ? sleepUnit : 'pages';
    scope.habitList.add(habit);
    if (sleep) {
      scope.sleepRepository.saveGoal(
          habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
    }
    habit.recompute();
    return habit;
  }

  Widget wrap(Habit habit) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: ShowHabitScreen(
            key: ValueKey<String?>(habit.uuid),
            habit: habit,
          ),
        ),
      );

  group('a habit with a sleep goal', () {
    testWidgets('gets its own blocks among the ported cards', (tester) async {
      final Habit habit = addHabit(name: 'Sleep', sleep: true);
      await tester.pumpWidget(wrap(habit));
      await tester.pumpAndSettle();

      expect(find.byType(LastNightCard), findsOneWidget,
          reason: 'sleep.ui#2');
      expect(find.byType(NightsChart), findsOneWidget, reason: 'sleep.ui#3');
      expect(find.byType(StabilityCard), findsOneWidget,
          reason: 'sleep.stability#1');
    });

    testWidgets('says what the goal is where the target figure would go',
        (tester) async {
      // "at least 100 %" says nothing about a habit whose target is 100 by
      // construction, and reads as a score: an up arrow beside a round
      // hundred, under the question, on a screen full of percentages.
      final Habit habit = addHabit(name: 'Sleep', sleep: true);
      await tester.pumpWidget(wrap(habit));
      await tester.pumpAndSettle();

      final Text target =
          tester.widget<Text>(find.byKey(SubtitleCardView.targetTextKey));
      expect(target.data, isNot(contains('100')), reason: 'sleep.ui#11');
      expect(target.data, contains('→'), reason: 'sleep.ui#11');
    });

    testWidgets('shows the overview the target displaced', (tester) async {
      // A numerical habit is given the target instead of the overview. Hiding
      // the target for sleep left it with neither, so the ring and the
      // month/year figures — the first thing a person looks at — were gone.
      final Habit habit = addHabit(name: 'Sleep', sleep: true);
      await tester.pumpWidget(wrap(habit));
      await tester.pumpAndSettle();

      expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.overview)),
          findsOneWidget, reason: 'sleep.ui#6');
    });

    testWidgets('does not show the target card', (tester) async {
      // The target card adds a habit's values up over a week and a month.
      // Seven good nights are not "700% per week"; they are seven nights.
      final Habit habit = addHabit(name: 'Sleep', sleep: true);
      await tester.pumpWidget(wrap(habit));
      await tester.pumpAndSettle();

      expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.target)),
          findsNothing, reason: 'sleep.ui#6');
    });

    testWidgets('keeps every other ported card the original would show',
        (tester) async {
      // Stated as a difference rather than a list, so the assertion cannot
      // drift away from whatever the port decides to show: the sleep habit's
      // ported cards are the numerical habit's, less the target.
      Set<ShowHabitCard> visibleFor(Habit habit) => <ShowHabitCard>{
            for (final ShowHabitCard card in ShowHabitCard.values)
              if (find
                  .byKey(ShowHabitScreen.cardKey(card))
                  .evaluate()
                  .isNotEmpty)
                card,
          };

      final Habit plain = addHabit(name: 'Pages', sleep: false);
      await tester.pumpWidget(wrap(plain));
      await tester.pumpAndSettle();
      final Set<ShowHabitCard> ordinary = visibleFor(plain);

      final Habit sleep = addHabit(name: 'Sleep', sleep: true);
      await tester.pumpWidget(wrap(sleep));
      await tester.pumpAndSettle();
      final Set<ShowHabitCard> withGoal = visibleFor(sleep);

      expect(ordinary, contains(ShowHabitCard.target),
          reason: 'sleep.ui#6 — the comparison is only worth making if the '
              'ordinary habit does show the card');
      expect(ordinary, isNot(contains(ShowHabitCard.overview)),
          reason: 'sleep.ui#6 — and only if it does NOT show the other half '
              'of the pair, which is the whole point of the swap');
      expect(
        withGoal,
        ordinary
            .difference(<ShowHabitCard>{ShowHabitCard.target})
            .union(<ShowHabitCard>{ShowHabitCard.overview}),
        reason: 'sleep.ui#6 — the pair is swapped, not emptied: a nightly '
            'percentage has no period total but does have a ring',
      );
    });
  });

  group('a habit without one', () {
    testWidgets('gets none of the blocks', (tester) async {
      final Habit habit = addHabit(name: 'Pages', sleep: false);
      await tester.pumpWidget(wrap(habit));
      await tester.pumpAndSettle();

      expect(find.byType(LastNightCard), findsNothing,
          reason: 'sleep.habit-type#4');
      expect(find.byType(NightsChart), findsNothing,
          reason: 'sleep.habit-type#4');
      expect(find.byType(StabilityCard), findsNothing,
          reason: 'sleep.habit-type#4');
    });

    testWidgets('keeps the target figure it was given', (tester) async {
      final Habit habit = addHabit(name: 'Pages', sleep: false);
      await tester.pumpWidget(wrap(habit));
      await tester.pumpAndSettle();

      final Text target =
          tester.widget<Text>(find.byKey(SubtitleCardView.targetTextKey));
      expect(target.data, contains('30'),
          reason: 'sleep.ui#11 — nothing changes for a habit that is not '
              'about sleep');
    });

    testWidgets('still shows the target card the rule gives it',
        (tester) async {
      final Habit habit = addHabit(name: 'Pages', sleep: false);
      await tester.pumpWidget(wrap(habit));
      await tester.pumpAndSettle();

      expect(find.byKey(ShowHabitScreen.cardKey(ShowHabitCard.target)),
          findsOneWidget,
          reason: 'sleep.ui#6 — nothing changes for a habit that is not '
              'about sleep');
    });
  });
}
