/// The type chooser and the editor, opened for an abstinence habit.
///
/// The model side is tested elsewhere. What is tested here is the fourth card
/// in the type chooser — that it exists, that it sits after the three cards
/// already there, and that tapping it opens the editor holding
/// `ComputedKind.abstinence` — and then the form that editor draws: which
/// boxes it offers and, just as much, which of the numerical ones it refuses
/// to offer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_header.dart'
    show IntlLocalDateFormatter;
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;

  setUp(() {
    core_time.DateUtils.setFixedTimeZone(const core_time.FixedTimeZone(0));
    // `AppScope.open` stamps today itself, from the wall clock rather than
    // from `setToday` — so the clock is what has to be pinned. Without this
    // the commitment day the form shows is the day the suite happens to run.
    core_time.systemCurrentTimeMillis =
        () => (9000 + 10957) * 86400000 + 12 * 3600000;
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
    core_time.systemCurrentTimeMillis = core_time.defaultCurrentTimeMillis;
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

  /// The editor itself, opened directly rather than through the chooser.
  ///
  /// The same shape as [pumpChooser] and for the same reason: the scope is
  /// provided below the navigator by `MaterialApp.home`, so a pushed route has
  /// to be handed the scope the way `EditHabitScreen.route` takes it.
  Future<void> pumpEditor(
    WidgetTester tester, {
    required ComputedKind computed,
  }) async {
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
                      habitType: HabitType.numerical,
                      computed: computed,
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

  testWidgets('the form asks about the allowance, not about miles run',
      (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);

    expect(find.byKey(EditHabitScreen.abstinenceAllowanceBoxKey), findsOneWidget,
        reason: 'computed.create#4');
    expect(find.byKey(EditHabitScreen.abstinenceCommittedBoxKey), findsOneWidget,
        reason: 'computed.create#4');
    expect(find.text('Allowance'), findsOneWidget, reason: 'computed.create#4');
    expect(find.text('Counted in'), findsOneWidget,
        reason: 'computed.create#4 — the unit is asked for under the '
            'allowance\'s name, because it is the allowance\'s unit');
    expect(find.text('Committed since'), findsOneWidget,
        reason: 'computed.create#4');

    // What it must NOT show: the four numerical boxes and the yes/no
    // frequency. Every one of them would let a person change something the
    // kind settles — the frequency it is scored at, the unit and the target
    // that ARE the allowance, and the target type that is what makes silence
    // count as success.
    expect(find.byKey(EditHabitScreen.unitBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.targetBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.targetTypeBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.frequencyBoxKey), findsNothing,
        reason: 'computed.create#3');
    expect(find.byKey(EditHabitScreen.numericalFrequencyPickerKey), findsNothing,
        reason: 'computed.create#3 — the numerical frequency shares a row with '
            'the target upstream, and that row is not on this form');

    // And what it keeps: the reminder, off, which is the answer to the spec's
    // second open question.
    expect(find.byKey(EditHabitScreen.reminderTimePickerKey), findsOneWidget,
        reason: 'computed.create#4');
    expect(find.byKey(EditHabitScreen.reminderDividerKey), findsNothing,
        reason: 'computed.create#4 — there is nothing to confirm every '
            'evening, so the reminder starts off');
  });

  testWidgets('the allowance box carries the target and the unit controllers',
      (tester) async {
    // The two boxes above exist; these are the two controllers behind them.
    // Without this the form could draw an Allowance box over a third, unread
    // controller and every assertion above would still be green — and the
    // habit would save with an allowance of zero whatever was typed.
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    final EditHabitModel model = Provider.of<EditHabitModel>(
      tester.element(find.byKey(EditHabitScreen.saveButtonKey)),
      listen: false,
    );

    await tester.enterText(
        find.byKey(EditHabitScreen.abstinenceAllowanceFieldKey), '30');
    await tester.enterText(
        find.byKey(EditHabitScreen.abstinenceUnitFieldKey), 'minutes');

    expect(model.targetController.text, '30',
        reason: 'computed.create#6 — `habit.targetValue` IS the allowance, so '
            'the allowance box is the target controller asked a different '
            'question');
    expect(model.unitController.text, 'minutes',
        reason: 'computed.create#6 — and `habit.unit` IS what it is counted '
            'in');
  });

  testWidgets('a word where a number belongs is drawn on the allowance box',
      (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey), 'No doomscrolling');
    await tester.enterText(
        find.byKey(EditHabitScreen.abstinenceAllowanceFieldKey), 'lots');
    await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
    await tester.pumpAndSettle();

    final TextField allowance = tester.widget<TextField>(find.descendant(
      of: find.byKey(EditHabitScreen.abstinenceAllowanceFieldKey),
      matching: find.byType(TextField),
    ));
    expect(allowance.decoration!.errorText, 'Cannot be blank',
        reason: 'computed.create#11 — the refusal has to be drawn where the '
            'person typed: the target box that carries it upstream is not on '
            'this form, so an unwired error is a save that fails in silence');
    expect(scope.habitList.size(), 0,
        reason: 'computed.create#11 — and nothing was created');
  });

  testWidgets('the question box has its own example', (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    final TextField question = tester.widget<TextField>(find.descendant(
      of: find.byKey(EditHabitScreen.questionFieldKey),
      matching: find.byType(TextField),
    ));
    expect(question.decoration!.hintText, 'e.g. Did you slip today?',
        reason: 'computed.create#4 — the placeholder is the only thing on the '
            'form that says what the question is for');
  });

  testWidgets('the commitment day reads as a date and starts today',
      (tester) async {
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    final Text shown = tester.widget<Text>(find
        .descendant(
          of: find.byKey(EditHabitScreen.abstinenceCommittedPickerKey),
          matching: find.byType(Text),
        )
        .first);
    expect(shown.data, IntlLocalDateFormatter('en').longFormat(LocalDate(9000)),
        reason: 'computed.create#8 — a day number is not a date a person can '
            'check');
  });

  testWidgets('picking an earlier day moves the commitment back to it',
      (tester) async {
    // Today is 2024-08-22. The picker deals in calendar dates and the model
    // deals in `daysSince2000`, and the conversion between them is exactly
    // where an off-by-one lives: 2024-08-05 is day 8983.
    await pumpEditor(tester, computed: ComputedKind.abstinence);
    final EditHabitModel model = Provider.of<EditHabitModel>(
      tester.element(find.byKey(EditHabitScreen.saveButtonKey)),
      listen: false,
    );

    await tester.tap(find.byKey(EditHabitScreen.abstinenceCommittedPickerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(model.committedFrom, 8983,
        reason: 'computed.create#8 — backwards is the whole point: the clean '
            'stretch before the first slip is counted from this day');
  });
}
