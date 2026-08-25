/// The editor, opened for a sleep habit.
///
/// The model side is tested elsewhere. What is tested here is what the form
/// puts in front of a person: a sleep habit is a numerical habit underneath,
/// and left alone the form asks it numerical questions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;

  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
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
    scope.close();
    core_time.DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  Future<void> pumpEditor(WidgetTester tester, {required bool sleep}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    EditHabitScreen.route(
                      scope: scope,
                      habitType: sleep ? sleepHabitType : HabitType.numerical,
                      sleep: sleep,
                    ),
                  ),
                  child: const Text('host'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();
  }

  String hintOf(WidgetTester tester) {
    final TextField field =
        tester.widget<TextField>(find.descendant(
      of: find.byKey(EditHabitScreen.questionFieldKey),
      matching: find.byType(TextField),
    ));
    return field.decoration!.hintText!;
  }

  testWidgets('asks about sleep, not about miles run', (tester) async {
    await pumpEditor(tester, sleep: true);
    expect(hintOf(tester), 'e.g. How did you sleep last night?',
        reason: 'sleep.ui#6 — the placeholder is the only thing on the form '
            'that says what the question is for');
  });

  testWidgets('an ordinary numerical habit keeps its own example',
      (tester) async {
    await pumpEditor(tester, sleep: false);
    expect(hintOf(tester), 'e.g. How many miles did you run today?',
        reason: 'sleep.ui#6 — nothing changes for a habit that is not about '
            'sleep');
  });
}
