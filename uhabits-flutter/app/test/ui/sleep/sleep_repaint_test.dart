/// What the sleep blocks do after they have written something.
///
/// They read straight out of the database rather than from the habit's model,
/// so nothing rebuilds them on its own. Every block can change what the others
/// show — a granted permission fills in nights that were not there, a night
/// typed by hand moves the strip and the spread — and without a repaint the
/// screen goes on showing what was true before the tap.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits/ui/habits/sleep/last_night_card.dart';
import 'package:uhabits/ui/habits/sleep/nights_chart.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart';

/// Refuses the sheet the sync raises, and grants the one the person asks for.
///
/// Which is the situation the card exists for: the automatic request was
/// declined, and the offer on screen is how it is reconsidered.
class _AskableSource implements SleepDataSource {
  _AskableSource({required this.nightStart, required this.nightEnd});

  final int nightStart;
  final int nightEnd;
  bool granted = false;
  int asked = 0;

  @override
  bool get hasHealthStore => true;

  @override
  Future<bool> isAuthorized() async => granted;

  @override
  Future<bool> requestAuthorization() async {
    asked++;
    granted = asked >= 2;
    return granted;
  }

  @override
  Future<List<SleepSegment>> readSegments(int from, int to) async => granted
      ? <SleepSegment>[
          SleepSegment(
            startMillis: nightStart,
            endMillis: nightEnd,
            kind: SleepSegmentKind.asleepUnspecified,
            sourceId: 'watch',
          ),
        ]
      : const <SleepSegment>[];

  @override
  Future<void> writeSession(int start, int end) async {}

  @override
  Future<void> enableBackgroundDelivery(
      Future<void> Function() onChanged) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const int day = 9000;
  final int wake = (day + 10957) * 86400000 + 7 * 3600000;
  final int bed = wake - 450 * 60000;

  late Database database;
  late AppScope scope;
  late _AskableSource source;

  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    core_time.DateUtils.setFixedLocalTime(
        (day + 10957) * 86400000 + 10 * 3600000);
    setToday(LocalDate(day));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    source = _AskableSource(nightStart: bed, nightEnd: wake);
    scope = AppScope.open(
      database,
      sleepSource: source,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
  });

  tearDown(() {
    scope.close();
    core_time.DateUtils.setFixedTimeZone(null);
    core_time.DateUtils.setFixedLocalTime(null);
    resetToday();
  });

  Habit addSleepHabit() {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sleep'
      ..type = sleepHabitType
      ..targetValue = sleepTargetValue
      ..unit = sleepUnit;
    scope.habitList.add(habit);
    scope.sleepRepository.saveGoal(
        habit.id!, const SleepGoal(bedMinutes: 1380, wakeMinutes: 420));
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

  testWidgets('granting access repaints the card that offered it',
      (tester) async {
    final Habit habit = addSleepHabit();
    // The state a refusal leaves: the app asked once and was told no.
    await scope.syncSleepHabits();
    expect(scope.sleepSourceAuthorized, isFalse,
        reason: 'the test is only worth running from a refusal');

    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    final Finder button = find.widgetWithText(TextButton, 'Allow access to Health');
    expect(button, findsOneWidget, reason: 'sleep.freshness#6');

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(source.asked, 2, reason: 'sleep.freshness#6 — the tap asks again');
    expect(button, findsNothing,
        reason: 'sleep.freshness#6 — the card cannot go on offering access '
            'that has been granted');
    expect(
      scope.sleepRepository.forDay(habit.id!, day),
      isNotNull,
      reason: 'sleep.freshness#6 — and the night the refusal was hiding is '
          'read in the same breath',
    );
  });

  testWidgets('the night that arrives with the permission is on screen',
      (tester) async {
    final Habit habit = addSleepHabit();
    await scope.syncSleepHabits();
    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    const String denied =
        'Without access to Health, nights have to be entered by hand.';
    expect(find.text(denied), findsOneWidget,
        reason: 'sleep.freshness#6 — this is what the card says before');
    expect(find.byType(NightBar), findsNothing,
        reason: 'sleep.freshness#6 — and the strip has nothing to draw');

    await tester.tap(find.widgetWithText(TextButton, 'Allow access to Health'));
    await tester.pumpAndSettle();

    expect(find.text(denied), findsNothing, reason: 'sleep.freshness#6');
    expect(find.byType(NightBar), findsWidgets,
        reason: 'sleep.freshness#6 — every block reads the same database, so '
            'the repaint has to reach all of them, not only the one tapped');
  });

  testWidgets('a platform with no health store offers nothing to allow',
      (tester) async {
    // Android has no health integration in this work. The card used to read a
    // refusal into that absence — blaming a permission that was never asked
    // for, and offering to ask again, which did nothing when tapped.
    scope.close();
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      sleepSource: const NoSleepDataSource(),
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );

    final Habit habit = addSleepHabit();
    await scope.syncSleepHabits();
    await tester.pumpWidget(wrap(habit));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Allow access to Health'),
        findsNothing,
        reason: 'sleep.ui#7');
    expect(
      find.text('Without access to Health, nights have to be entered by hand.'),
      findsNothing,
      reason: 'sleep.ui#7 — nothing refused anything',
    );
    expect(find.byType(LastNightCard), findsOneWidget,
        reason: 'sleep.ui#7 — the block itself is unchanged, and its "Enter '
            'night" action is the way in');
    expect(find.text('Enter night'), findsOneWidget, reason: 'sleep.ui#7');
  });
}
