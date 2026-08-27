/// The type chooser and the editor, opened for an abstinence habit.
///
/// The model side is tested elsewhere. What is tested here is the fourth
/// card in the type chooser: that it exists, that it sits after the three
/// cards already there, and that tapping it opens the editor holding
/// `ComputedKind.abstinence`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
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

  Future<void> pumpChooser(WidgetTester tester) async {
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
                  onPressed: () => EditHabitScreen.selectTypeAndOpen(context),
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

  testWidgets('the chooser offers abstinence, last', (tester) async {
    await pumpChooser(tester);

    expect(find.byKey(EditHabitScreen.abstinenceTypeCardKey), findsOneWidget,
        reason: 'computed.create#1');
    expect(find.text('Abstinence'), findsOneWidget,
        reason: 'computed.create#1');

    final Rect yesNo =
        tester.getRect(find.byKey(EditHabitScreen.yesNoTypeCardKey));
    final Rect measurable =
        tester.getRect(find.byKey(EditHabitScreen.measurableTypeCardKey));
    final Rect sleep =
        tester.getRect(find.byKey(EditHabitScreen.sleepTypeCardKey));
    final Rect abstinence =
        tester.getRect(find.byKey(EditHabitScreen.abstinenceTypeCardKey));

    // The two ported cards keep the positions `habit-type-dialog.select-type#4`
    // gives them; the port's own cards go under them, one per kind.
    expect(measurable.top, greaterThan(yesNo.top),
        reason: 'computed.create#1');
    expect(sleep.top, greaterThan(measurable.top),
        reason: 'computed.create#1');
    expect(abstinence.top, greaterThan(sleep.top),
        reason: 'computed.create#1 — a new kind lands below the kinds that '
            'were already there, so nobody\'s muscle memory moves');
  });

  testWidgets('picking it opens the editor as an abstinence habit',
      (tester) async {
    await pumpChooser(tester);
    await tester.tap(find.byKey(EditHabitScreen.abstinenceTypeCardKey));
    await tester.pumpAndSettle();

    final EditHabitModel model = Provider.of<EditHabitModel>(
      tester.element(find.byKey(EditHabitScreen.saveButtonKey)),
      listen: false,
    );
    expect(model.computedKind, ComputedKind.abstinence,
        reason: 'computed.create#2 — the card that was tapped is the kind the '
            'form is holding');
    expect(model.habitType, HabitType.numerical,
        reason: 'computed.create#2 — and it is a numerical habit, because '
            'there is no third type and never will be');
  });
}
