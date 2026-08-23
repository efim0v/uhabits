/// Tests for the create/edit habit screen.
///
/// Every expectation cites the parity-ledger rule it pins, from the
/// `edit-habit.*`, `habit-type-dialog.*` and `weekday-picker.*` features of
/// docs/parity/FEATURES.md. There is no Kotlin unit test for this screen —
/// most of its features are marked "Kotlin tests: none — write Dart test from
/// rules" — so the rules are the only spec.
library;

// The commands, the preferences and the dispatchers are not re-exported from
// uhabits_core.dart yet; see app_scope.dart.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits/ui/common/dialogs/weekday_picker_dialog.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits/ui/theme/app_theme.dart' show toFlutterColor;
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  late L10n l10n;
  final scopes = <AppScope>[];
  final databases = <Database>[];
  var nextDatabase = 0;
  var nextTree = 0;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l10n = await L10n.delegate.load(const Locale('en'));
  });

  setUp(() {
    // Nothing may read a habit before startup has stamped today.
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_edit_habit_screen');
    nextDatabase = 0;
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    for (final database in databases) {
      database.close();
    }
    databases.clear();
    tempDir.deleteSync(recursive: true);
  });

  /// [dispatcher] defaults to the unconfined one so a `commandRunner.run(...)`
  /// has finished by the time it returns, which is what
  /// `BaseUnitTest` gives the Kotlin command tests. The widget tests below
  /// keep the production [AsyncDispatcher] and settle instead.
  AppScope openScope({
    Dispatcher dispatcher = const UnconfinedTestDispatcher(),
  }) {
    final path = '${tempDir.path}/habits${nextDatabase++}.db';
    final database = AppDatabase.openAndMigrate(path);
    final scope = AppScope.open(
      database,
      databasePath: path,
      mainDispatcher: dispatcher,
      ioDispatcher: dispatcher,
    );
    scopes.add(scope);
    return scope;
  }

  /// A second connection to the same file: enough to prove a write reached
  /// the disk.
  HabitList reopen(AppScope scope) {
    final database = AppDatabase.openAndMigrate(scope.databasePath!);
    databases.add(database);
    return SQLModelFactory(database).buildHabitList();
  }

  Habit addHabit(
    AppScope scope,
    String name, {
    PaletteColor color = const PaletteColor(8),
    HabitType type = HabitType.yesNo,
    Frequency frequency = Frequency.daily,
    Reminder? reminder,
    String question = '',
    String description = '',
    String unit = '',
    double targetValue = 0.0,
    NumericalHabitType targetType = NumericalHabitType.atLeast,
  }) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..color = color
      ..type = type
      ..frequency = frequency
      ..reminder = reminder
      ..question = question
      ..description = description
      ..unit = unit
      ..targetValue = targetValue
      ..targetType = targetType;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  EditHabitModel createModel(
    AppScope scope, {
    int? habitId,
    HabitType habitType = HabitType.yesNo,
  }) {
    return EditHabitModel(
      scope: scope,
      habitId: habitId,
      habitType: habitType,
    );
  }

  // -----------------------------------------------------------------------
  // Widget harness: the editor always lives on a pushed route, so that the
  // `finish()` of `edit-habit.save#11` has somewhere to pop back to.
  // -----------------------------------------------------------------------

  Future<void> pumpEditor(
    WidgetTester tester,
    AppScope scope, {
    int? habitId,
    HabitType habitType = HabitType.yesNo,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // A fresh key per call: a test that opens the editor twice must get a
        // fresh navigator, not the one still holding the first route.
        key: ValueKey<int>(nextTree++),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    EditHabitScreen.route(
                      scope: scope,
                      habitId: habitId,
                      habitType: habitType,
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

  EditHabitModel modelOf(WidgetTester tester) => Provider.of<EditHabitModel>(
        tester.element(find.byKey(EditHabitScreen.saveButtonKey)),
        listen: false,
      );

  // =======================================================================
  // edit-habit.frequency-display
  // =======================================================================

  group('edit-habit.frequency-display', () {
    test('#1/#2: formatFrequency evaluates its branches in order', () {
      expect(formatFrequency(1, 1, l10n), 'Every day',
          reason: 'edit-habit.frequency-display#2');
      expect(formatFrequency(1, 7, l10n), 'Every week',
          reason: 'edit-habit.frequency-display#2');
      expect(formatFrequency(1, 3, l10n), 'Every 3 days',
          reason: 'edit-habit.frequency-display#2');
      expect(formatFrequency(3, 7, l10n), '3 times per week',
          reason: 'edit-habit.frequency-display#2');
      // The month branch is tested first, which is why (1, 30) and (1, 31)
      // never reach "1 times per month" (`#1`).
      expect(formatFrequency(1, 30, l10n), 'Every month',
          reason: 'edit-habit.frequency-display#1');
      expect(formatFrequency(1, 31, l10n), 'Every month',
          reason: 'edit-habit.frequency-display#1');
      expect(formatFrequency(5, 30, l10n), '5 times per month',
          reason: 'edit-habit.frequency-display#2');
      expect(formatFrequency(5, 31, l10n), '5 times per month',
          reason: 'edit-habit.frequency-display#2');
      expect(formatFrequency(3, 14, l10n), '3 times in 14 days',
          reason: 'edit-habit.frequency-display#2');
    });

    test('#4/#5: the numerical label is computed separately and ignores '
        'the numerator', () {
      expect(formatNumericalFrequency(1, 1, l10n), 'Every day',
          reason: 'edit-habit.frequency-display#4');
      expect(formatNumericalFrequency(1, 7, l10n), 'Every week',
          reason: 'edit-habit.frequency-display#4');
      expect(formatNumericalFrequency(1, 30, l10n), 'Every month',
          reason: 'edit-habit.frequency-display#4');
      // 31 is NOT one of the three known denominators here, unlike
      // formatFrequency (`#4`).
      expect(formatNumericalFrequency(1, 31, l10n), '1/31',
          reason: 'edit-habit.frequency-display#4');
      expect(formatNumericalFrequency(3, 7, l10n), 'Every week',
          reason: 'edit-habit.frequency-display#5');
    });
  });

  // =======================================================================
  // edit-habit.reminder-days
  // =======================================================================

  group('edit-habit.reminder-days', () {
    const shortNames = <String>[
      'Sat',
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
    ];
    const longNames = <String>[
      'Saturday',
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];

    String format(WeekdayList days) => formatWeekdayList(
          days,
          l10n,
          shortNames: shortNames,
          longNames: longNames,
        );

    WeekdayList listOf(List<int> indexes) => WeekdayList.fromArray(
          List<bool>.generate(7, indexes.contains),
        );

    test('#3/#5: the label follows the five ordered tests', () {
      expect(format(WeekdayList(127)), 'Any day of the week',
          reason: 'edit-habit.reminder-days#5');
      // Index 2 is Monday, because index 0 is Saturday (`#4`).
      expect(format(listOf(<int>[2])), 'Monday',
          reason: 'edit-habit.reminder-days#5');
      expect(format(listOf(<int>[0, 1])), 'Weekends',
          reason: 'edit-habit.reminder-days#5');
      expect(format(listOf(<int>[2, 3, 4, 5, 6])), 'Monday to Friday',
          reason: 'edit-habit.reminder-days#5');
      expect(format(listOf(<int>[0, 2])), 'Sat, Mon',
          reason: 'edit-habit.reminder-days#5');
    });

    test('#6: an empty list formats to the empty string', () {
      expect(format(WeekdayList(0)), '',
          reason: 'edit-habit.reminder-days#6');
    });
  });

  // =======================================================================
  // edit-habit.entry-points
  // =======================================================================

  group('edit-habit.entry-points', () {
    test('#8/#9: the create-mode defaults are blue, daily and reminder-less',
        () {
      final model = createModel(openScope());
      expect(model.habitId, -1, reason: 'edit-habit.entry-points#8');
      expect(model.habitType, HabitType.yesNo,
          reason: 'edit-habit.entry-points#3');
      // PaletteColor(11), not the Habit model's own PaletteColor(8) (`#9`).
      expect(model.color, const PaletteColor(11),
          reason: 'edit-habit.entry-points#9');
      expect(model.freqNum, 1, reason: 'edit-habit.entry-points#8');
      expect(model.freqDen, 1, reason: 'edit-habit.entry-points#8');
      expect(model.reminderHour, -1, reason: 'edit-habit.entry-points#8');
      expect(model.reminderMin, -1, reason: 'edit-habit.entry-points#8');
      expect(model.reminderDays, WeekdayList.everyDay,
          reason: 'edit-habit.entry-points#8');
      expect(model.targetType, NumericalHabitType.atLeast,
          reason: 'edit-habit.entry-points#8');
      expect(model.unitController.text, '',
          reason: 'edit-habit.entry-points#8');
      expect(model.isEditing, isFalse, reason: 'edit-habit.entry-points#1');
    });

    test('#4/#5: edit mode seeds every field from the habit', () {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Run',
        color: const PaletteColor(3),
        type: HabitType.numerical,
        frequency: Frequency(3, 7),
        question: 'How far?',
        description: 'morning',
        unit: 'miles',
        targetValue: 15.0,
        targetType: NumericalHabitType.atMost,
        reminder: Reminder(7, 30, WeekdayList(3)),
      );

      final model = createModel(scope, habitId: habit.id);

      expect(model.isEditing, isTrue, reason: 'edit-habit.entry-points#1');
      expect(model.habitType, HabitType.numerical,
          reason: 'edit-habit.entry-points#4');
      expect(model.color, const PaletteColor(3),
          reason: 'edit-habit.entry-points#4');
      expect(model.freqNum, 3, reason: 'edit-habit.entry-points#4');
      expect(model.freqDen, 7, reason: 'edit-habit.entry-points#4');
      expect(model.targetType, NumericalHabitType.atMost,
          reason: 'edit-habit.entry-points#4');
      expect(model.nameController.text, 'Run',
          reason: 'edit-habit.entry-points#4');
      expect(model.questionController.text, 'How far?',
          reason: 'edit-habit.entry-points#4');
      // The Notes field is Habit.description (`edit-habit.form-layout#6`).
      expect(model.notesController.text, 'morning',
          reason: 'edit-habit.form-layout#6');
      expect(model.unitController.text, 'miles',
          reason: 'edit-habit.entry-points#4');
      // `habit.targetValue.toString()`, so 15.0 shows as "15.0" (`#4`).
      expect(model.targetController.text, '15.0',
          reason: 'edit-habit.entry-points#4');
      expect(model.reminderHour, 7, reason: 'edit-habit.entry-points#5');
      expect(model.reminderMin, 30, reason: 'edit-habit.entry-points#5');
      expect(model.reminderDays, WeekdayList(3),
          reason: 'edit-habit.entry-points#5');
    });

    test('#5: a habit without a reminder keeps the (-1, -1, EVERY_DAY) '
        'defaults', () {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      final model = createModel(scope, habitId: habit.id);
      expect(model.reminderHour, -1, reason: 'edit-habit.entry-points#5');
      expect(model.reminderMin, -1, reason: 'edit-habit.entry-points#5');
      expect(model.reminderDays, WeekdayList.everyDay,
          reason: 'edit-habit.entry-points#5');
    });

    test('#7: editing an id that is not in the list throws', () {
      final scope = openScope();
      expect(
        () => createModel(scope, habitId: 999),
        throwsA(isA<TypeError>()),
        reason: 'edit-habit.entry-points#7',
      );
    });
  });

  // =======================================================================
  // edit-habit.validation
  // =======================================================================

  group('edit-habit.validation', () {
    test('#2/#13: an empty name blocks the save', () {
      final scope = openScope();
      final model = createModel(scope);
      expect(model.save(), isFalse, reason: 'edit-habit.validation#2');
      expect(model.nameError, EditHabitFieldError.blank,
          reason: 'edit-habit.validation#2');
      expect(scope.habitList.isEmpty, isTrue,
          reason: 'edit-habit.save#13');
    });

    test('#6: a whitespace-only name passes and is saved trimmed to empty',
        () {
      final scope = openScope();
      final model = createModel(scope)..nameController.text = '   ';
      expect(model.save(), isTrue, reason: 'edit-habit.validation#6');
      expect(model.nameError, isNull, reason: 'edit-habit.validation#6');
      expect(scope.habitList.getByPosition(0).name, '',
          reason: 'edit-habit.validation#6');
    });

    test('#4: a numerical habit with an empty target blocks the save', () {
      final scope = openScope();
      final model = createModel(scope, habitType: HabitType.numerical)
        ..nameController.text = 'Run';
      expect(model.save(), isFalse, reason: 'edit-habit.validation#4');
      expect(model.targetError, EditHabitFieldError.blank,
          reason: 'edit-habit.validation#4');
      expect(model.nameError, isNull, reason: 'edit-habit.validation#4');
    });

    test('#7: a yes/no habit never looks at the target', () {
      final scope = openScope();
      final model = createModel(scope)..nameController.text = 'Meditate';
      expect(model.save(), isTrue, reason: 'edit-habit.validation#7');
      expect(model.targetError, isNull, reason: 'edit-habit.validation#7');
    });

    test('#5: both errors are reported in the same pass', () {
      final scope = openScope();
      final model = createModel(scope, habitType: HabitType.numerical);
      expect(model.save(), isFalse, reason: 'edit-habit.validation#5');
      expect(model.nameError, EditHabitFieldError.blank,
          reason: 'edit-habit.validation#5');
      expect(model.targetError, EditHabitFieldError.blank,
          reason: 'edit-habit.validation#5');
    });

    test('#8: 0, negatives and huge targets are all accepted', () {
      final scope = openScope();
      for (final target in <String>['0', '-5', '1e30']) {
        final model = createModel(scope, habitType: HabitType.numerical)
          ..nameController.text = 'Run'
          ..targetController.text = target;
        expect(model.save(), isTrue, reason: 'edit-habit.validation#8');
      }
      expect(scope.habitList.size(), 3, reason: 'edit-habit.validation#8');
      expect(scope.habitList.getByPosition(1).targetValue, -5.0,
          reason: 'edit-habit.validation#8');
    });

    test('#9: an unparseable target is refused instead of crashing', () {
      final scope = openScope();
      final model = createModel(scope, habitType: HabitType.numerical)
        ..nameController.text = 'Run'
        ..targetController.text = '1,5';
      // Kotlin throws NumberFormatException out of save() here; the ledger
      // asks the port to reject with an inline error instead.
      expect(model.save(), isFalse, reason: 'edit-habit.validation#9');
      expect(model.targetError, EditHabitFieldError.notANumber,
          reason: 'edit-habit.validation#9');
      expect(scope.habitList.isEmpty, isTrue,
          reason: 'edit-habit.validation#9');
    });

    test('#1: nothing is validated before Save is pressed', () {
      final model = createModel(openScope());
      expect(model.nameError, isNull, reason: 'edit-habit.validation#1');
      model.nameController.text = '';
      expect(model.nameError, isNull, reason: 'edit-habit.validation#1');
    });
  });

  // =======================================================================
  // edit-habit.save
  // =======================================================================

  group('edit-habit.save', () {
    test('#8/#9: create mode dispatches a CreateHabitCommand', () {
      final scope = openScope();
      final model = createModel(scope)
        ..nameController.text = '  Meditate  '
        ..questionController.text = '  Did you? '
        ..notesController.text = ' every morning '
        ..setColor(const PaletteColor(4))
        ..setFrequency(3, 7);

      expect(model.save(), isTrue, reason: 'edit-habit.save#8');

      expect(scope.habitList.size(), 1, reason: 'edit-habit.save#9');
      final saved = scope.habitList.getByPosition(0);
      // The trimmed text of the three free-text fields (`#2`).
      expect(saved.name, 'Meditate', reason: 'edit-habit.save#2');
      expect(saved.question, 'Did you?', reason: 'edit-habit.save#2');
      expect(saved.description, 'every morning', reason: 'edit-habit.save#2');
      expect(saved.color, const PaletteColor(4), reason: 'edit-habit.save#3');
      expect(saved.frequency, Frequency(3, 7), reason: 'edit-habit.save#5');
      expect(saved.reminder, isNull, reason: 'edit-habit.save#4');
      expect(saved.type, HabitType.yesNo, reason: 'edit-habit.save#7');
      // The command ran, so it is on disk too.
      expect(reopen(scope).getByPosition(0).name, 'Meditate',
          reason: 'edit-habit.save#9');
    });

    test('#4: the reminder is written whole or set to null', () {
      final scope = openScope();
      final model = createModel(scope)
        ..nameController.text = 'Meditate'
        ..setReminderTime(8, 30)
        ..setReminderDays(WeekdayList(3));
      expect(model.save(), isTrue);
      expect(
        scope.habitList.getByPosition(0).reminder,
        Reminder(8, 30, WeekdayList(3)),
        reason: 'edit-habit.save#4',
      );

      final second = createModel(scope)..nameController.text = 'Read';
      expect(second.save(), isTrue);
      expect(scope.habitList.getByPosition(1).reminder, isNull,
          reason: 'edit-habit.save#4');
    });

    test('#6: only numerical habits write target, target type and unit', () {
      final scope = openScope();
      final model = createModel(scope, habitType: HabitType.numerical)
        ..nameController.text = 'Run'
        ..unitController.text = '  miles '
        ..targetController.text = '15'
        ..setTargetType(NumericalHabitType.atMost);
      expect(model.save(), isTrue);

      final saved = scope.habitList.getByPosition(0);
      expect(saved.type, HabitType.numerical, reason: 'edit-habit.save#7');
      expect(saved.targetValue, 15.0, reason: 'edit-habit.save#6');
      expect(saved.targetType, NumericalHabitType.atMost,
          reason: 'edit-habit.save#6');
      expect(saved.unit, 'miles', reason: 'edit-habit.save#6');
    });

    test('#8/#10/#14: edit mode dispatches an EditHabitCommand and keeps '
        'position, uuid and archived state', () {
      final scope = openScope();
      addHabit(scope, 'First');
      final habit = addHabit(scope, 'Meditate', color: const PaletteColor(2));
      habit.isArchived = true;
      scope.habitList.updateOne(habit);
      final uuid = habit.uuid;
      final position = habit.position;

      final model = createModel(scope, habitId: habit.id)
        ..nameController.text = 'Meditate more'
        ..setColor(const PaletteColor(9));
      expect(model.save(), isTrue, reason: 'edit-habit.save#8');

      // The stored instance was edited in place: same id, same list size.
      expect(scope.habitList.size(), 2, reason: 'edit-habit.save#10');
      final saved = scope.habitList.getById(habit.id!)!;
      expect(saved.name, 'Meditate more', reason: 'edit-habit.save#10');
      expect(saved.color, const PaletteColor(9), reason: 'edit-habit.save#3');
      expect(saved.uuid, uuid, reason: 'edit-habit.save#14');
      expect(saved.position, position, reason: 'edit-habit.save#14');
      expect(saved.isArchived, isTrue, reason: 'edit-habit.save#14');
    });

    test('#6 + type-field-visibility#4: a yes/no habit never reads back the '
        'hidden unit and target fields', () {
      final scope = openScope();
      // The hidden inputs still hold text — `edit-habit.type-field-visibility#4`
      // — but save() only reads them for NUMERICAL habits.
      final model = createModel(scope)
        ..nameController.text = 'Meditate'
        ..unitController.text = 'miles'
        ..targetController.text = '99'
        ..setTargetType(NumericalHabitType.atMost);
      expect(model.save(), isTrue);

      final saved = scope.habitList.getByPosition(0);
      expect(saved.unit, '', reason: 'edit-habit.save#6');
      expect(saved.targetValue, 0.0, reason: 'edit-habit.save#6');
      expect(saved.targetType, NumericalHabitType.atLeast,
          reason: 'edit-habit.save#6');
    });

    test('#16 + entry-points#6: the type is not editable, so an existing '
        'numerical habit stays numerical', () {
      final scope = openScope();
      final habit = addHabit(
        scope,
        'Run',
        type: HabitType.numerical,
        unit: 'miles',
        targetValue: 15.0,
        targetType: NumericalHabitType.atMost,
      );

      // There is no control for the type and the editor always seeds it from
      // the habit, so `edit-habit.save#16`'s edge case — a numerical habit
      // saved as yes/no with its target left intact — is unreachable here.
      final model = createModel(scope, habitId: habit.id);
      expect(model.habitType, HabitType.numerical,
          reason: 'edit-habit.entry-points#6');

      model.nameController.text = 'Run further';
      expect(model.save(), isTrue);
      final saved = scope.habitList.getById(habit.id!)!;
      expect(saved.type, HabitType.numerical,
          reason: 'edit-habit.entry-points#6');
      expect(saved.targetValue, 15.0, reason: 'edit-habit.save#6');
      expect(saved.targetType, NumericalHabitType.atMost,
          reason: 'edit-habit.save#6');
      expect(saved.unit, 'miles', reason: 'edit-habit.save#6');
    });

    test('#5: the frequency is written for numerical habits too', () {
      final scope = openScope();
      final model = createModel(scope, habitType: HabitType.numerical)
        ..nameController.text = 'Run'
        ..targetController.text = '15'
        ..setFrequencyDenominator(30);
      expect(model.save(), isTrue);
      expect(scope.habitList.getByPosition(0).frequency, Frequency(1, 30),
          reason: 'edit-habit.save#5');
    });
  });

  // =======================================================================
  // The pickers, as model operations
  // =======================================================================

  group('pickers', () {
    test('edit-habit.numerical-frequency-picker#3: the numerical list changes '
        'only the denominator', () {
      final model = createModel(openScope(), habitType: HabitType.numerical)
        ..setFrequency(3, 7)
        ..setFrequencyDenominator(30);
      expect(model.freqNum, 3,
          reason: 'edit-habit.numerical-frequency-picker#3');
      expect(model.freqDen, 30,
          reason: 'edit-habit.numerical-frequency-picker#3');
    });

    test('edit-habit.reminder-time#6: clearing the time also resets the days',
        () {
      final model = createModel(openScope())
        ..setReminderTime(8, 0)
        ..setReminderDays(WeekdayList(3));
      expect(model.hasReminder, isTrue,
          reason: 'edit-habit.reminder-time#2');

      model.clearReminder();
      expect(model.reminderHour, -1, reason: 'edit-habit.reminder-time#6');
      expect(model.reminderMin, -1, reason: 'edit-habit.reminder-time#6');
      expect(model.reminderDays, WeekdayList.everyDay,
          reason: 'edit-habit.reminder-time#6');
      expect(model.hasReminder, isFalse,
          reason: 'edit-habit.reminder-time#1');
    });

    test('edit-habit.reminder-days#2: an empty selection becomes every day',
        () {
      final model = createModel(openScope())
        ..setReminderDays(WeekdayList(0));
      expect(model.reminderDays, WeekdayList.everyDay,
          reason: 'edit-habit.reminder-days#2');
    });

  });

  // =======================================================================
  // The screen
  // =======================================================================

  group('the screen', () {
    testWidgets('edit-habit.entry-points#2: the toolbar title is Create habit '
        'in create mode and Edit habit in edit mode', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Create habit'),
        ),
        findsOneWidget,
        reason: 'edit-habit.entry-points#2',
      );

      final habit = addHabit(scope, 'Meditate');
      await pumpEditor(tester, scope, habitId: habit.id);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Edit habit'),
        ),
        findsOneWidget,
        reason: 'edit-habit.entry-points#2',
      );
    });

    testWidgets('edit-habit.form-layout#1 + type-field-visibility#1: a yes/no '
        'habit shows Frequency and hides Unit, Target and Target Type',
        (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      expect(find.byKey(EditHabitScreen.nameFieldKey), findsOneWidget,
          reason: 'edit-habit.form-layout#1');
      expect(find.byKey(EditHabitScreen.questionFieldKey), findsOneWidget,
          reason: 'edit-habit.form-layout#1');
      expect(find.byKey(EditHabitScreen.notesFieldKey), findsOneWidget,
          reason: 'edit-habit.form-layout#1');
      expect(find.byKey(EditHabitScreen.frequencyBoxKey), findsOneWidget,
          reason: 'edit-habit.type-field-visibility#1');
      expect(find.byKey(EditHabitScreen.unitBoxKey), findsNothing,
          reason: 'edit-habit.type-field-visibility#1');
      expect(find.byKey(EditHabitScreen.targetBoxKey), findsNothing,
          reason: 'edit-habit.type-field-visibility#1');
      expect(find.byKey(EditHabitScreen.targetTypeBoxKey), findsNothing,
          reason: 'edit-habit.type-field-visibility#1');
    });

    testWidgets('edit-habit.type-field-visibility#2: a numerical habit hides '
        'the yes/no Frequency box and shows the three target boxes',
        (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );

      expect(find.byKey(EditHabitScreen.frequencyBoxKey), findsNothing,
          reason: 'edit-habit.type-field-visibility#2');
      expect(find.byKey(EditHabitScreen.unitBoxKey), findsOneWidget,
          reason: 'edit-habit.type-field-visibility#2');
      expect(find.byKey(EditHabitScreen.targetBoxKey), findsOneWidget,
          reason: 'edit-habit.type-field-visibility#2');
      expect(find.byKey(EditHabitScreen.targetTypeBoxKey), findsOneWidget,
          reason: 'edit-habit.type-field-visibility#2');
    });

    testWidgets('edit-habit.form-layout#3/#4: the name and question hints '
        'follow the habit type', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope);
      expect(find.text('e.g. Exercise'), findsOneWidget,
          reason: 'edit-habit.form-layout#3');
      expect(find.text('e.g. Did you exercise today?'), findsOneWidget,
          reason: 'edit-habit.form-layout#4');

      await pumpEditor(tester, scope, habitType: HabitType.numerical);
      expect(find.text('e.g. Run'), findsOneWidget,
          reason: 'edit-habit.form-layout#3');
      expect(find.text('e.g. How many miles did you run today?'),
          findsOneWidget,
          reason: 'edit-habit.form-layout#4');
      expect(find.text('e.g. miles'), findsOneWidget,
          reason: 'edit-habit.form-layout#7');
      expect(find.text('e.g. 15'), findsOneWidget,
          reason: 'edit-habit.form-layout#8');
    });

    testWidgets('edit-habit.form-layout#6: the Notes hint is "(Optional)"',
        (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      expect(find.text('(Optional)'), findsOneWidget,
          reason: 'edit-habit.form-layout#6');
    });

    testWidgets('edit-habit.form-layout#2: the name field is capped at 50 '
        'characters', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(EditHabitScreen.nameFieldKey),
          matching: find.byType(TextField),
        ),
      );
      expect(field.maxLength, 50, reason: 'edit-habit.form-layout#2');
      expect(field.maxLines, 2, reason: 'edit-habit.form-layout#2');

      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        'x' * 60,
      );
      await tester.pump();
      expect(modelOf(tester).nameController.text.length, 50,
          reason: 'edit-habit.form-layout#2');
    });

    testWidgets('edit-habit.frequency-display#3: a fresh yes/no habit reads '
        '"Every day"', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.frequencyPickerKey),
          matching: find.text('Every day'),
        ),
        findsOneWidget,
        reason: 'edit-habit.frequency-display#3',
      );
    });

    testWidgets('edit-habit.frequency-display#6: populateFrequency overwrites '
        'the layout default, so a new numerical habit reads "Every day"',
        (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.numericalFrequencyPickerKey),
          matching: find.text('Every day'),
        ),
        findsOneWidget,
        reason: 'edit-habit.frequency-display#6',
      );
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.numericalFrequencyPickerKey),
          matching: find.text('Every week'),
        ),
        findsNothing,
        reason: 'edit-habit.frequency-display#6',
      );
    });

    testWidgets('edit-habit.numerical-frequency-picker#1/#2: three options, '
        'mapped to denominators 1, 7 and 30', (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );

      await tester.tap(find.byKey(EditHabitScreen.numericalFrequencyPickerKey));
      await tester.pumpAndSettle();

      final options = find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.byType(Text),
      );
      expect(
        tester.widgetList<Text>(options).map((t) => t.data).toList(),
        <String>['Every day', 'Every week', 'Every month'],
        reason: 'edit-habit.numerical-frequency-picker#1',
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Every month'),
        ),
      );
      await tester.pumpAndSettle();
      expect(modelOf(tester).freqDen, 30,
          reason: 'edit-habit.numerical-frequency-picker#2');
    });

    testWidgets('edit-habit.target-type-picker#1/#2/#4: At least, then '
        'At most', (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );

      // AT_LEAST is the `else` branch, so it is what an untouched control
      // shows (`#4`).
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.targetTypePickerKey),
          matching: find.text('At least'),
        ),
        findsOneWidget,
        reason: 'edit-habit.target-type-picker#4',
      );

      await tester.tap(find.byKey(EditHabitScreen.targetTypePickerKey));
      await tester.pumpAndSettle();
      final options = find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.byType(Text),
      );
      expect(
        tester.widgetList<Text>(options).map((t) => t.data).toList(),
        <String>['At least', 'At most'],
        reason: 'edit-habit.target-type-picker#1',
      );

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('At most'),
        ),
      );
      await tester.pumpAndSettle();
      expect(modelOf(tester).targetType, NumericalHabitType.atMost,
          reason: 'edit-habit.target-type-picker#2');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.targetTypePickerKey),
          matching: find.text('At most'),
        ),
        findsOneWidget,
        reason: 'edit-habit.target-type-picker#4',
      );
    });

    testWidgets('edit-habit.reminder-time#1/#2: Off hides the days row, and '
        'a time shows it', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('Off'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-time#1',
      );
      expect(find.byKey(EditHabitScreen.reminderDaysPickerKey), findsNothing,
          reason: 'edit-habit.reminder-time#1');
      expect(find.byKey(EditHabitScreen.reminderDividerKey), findsNothing,
          reason: 'edit-habit.reminder-time#1');

      modelOf(tester).setReminderTime(8, 30);
      await tester.pumpAndSettle();

      expect(find.byKey(EditHabitScreen.reminderDaysPickerKey), findsOneWidget,
          reason: 'edit-habit.reminder-time#2');
      expect(find.byKey(EditHabitScreen.reminderDividerKey), findsOneWidget,
          reason: 'edit-habit.reminder-time#2');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderDaysPickerKey),
          matching: find.text('Any day of the week'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-days#3',
      );
    });

    testWidgets('edit-habit.reminder-time#6: the clear action turns the '
        'reminder off and resets the days', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      modelOf(tester)
        ..setReminderTime(8, 30)
        ..setReminderDays(WeekdayList(4));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderDaysPickerKey),
          matching: find.text('Monday'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-days#3',
      );

      await tester.tap(find.byKey(EditHabitScreen.reminderClearKey));
      await tester.pumpAndSettle();

      expect(modelOf(tester).reminderDays, WeekdayList.everyDay,
          reason: 'edit-habit.reminder-time#6');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('Off'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-time#6',
      );
      expect(find.byKey(EditHabitScreen.reminderDaysPickerKey), findsNothing,
          reason: 'edit-habit.reminder-time#6');
    });

    testWidgets('edit-habit.reminder-time#3: tapping the control opens a '
        'time picker seeded with 08:00', (tester) async {
      // The seed itself, which the Material picker hides behind its dial.
      expect(EditHabitScreen.initialReminderTime(-1, -1),
          const TimeOfDay(hour: 8, minute: 0),
          reason: 'edit-habit.reminder-time#3');
      expect(EditHabitScreen.initialReminderTime(7, 30),
          const TimeOfDay(hour: 7, minute: 30),
          reason: 'edit-habit.reminder-time#3');

      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();
      // The vendored AOSP radial dialog has no Flutter equivalent; the
      // Material one stands in for it.
      expect(find.text('Cancel'), findsOneWidget,
          reason: 'edit-habit.reminder-time#3');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('edit-habit.color-control#1/#2/#3: the colour button opens '
        'the palette and repaints the toolbar', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      final theme = LightTheme();
      AppBar appBar() => tester.widget<AppBar>(find.byType(AppBar));
      // PaletteColor(11) is the screen's default.
      expect(
        appBar().backgroundColor,
        toFlutterColor(theme.color(11)),
        reason: 'edit-habit.color-control#3',
      );

      await tester.tap(find.byKey(EditHabitScreen.colorButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('Change color'), findsOneWidget,
          reason: 'edit-habit.color-control#1');

      await tester.tap(find.byKey(const ValueKey<String>('color_swatch_0')));
      await tester.pumpAndSettle();

      expect(modelOf(tester).color, const PaletteColor(0),
          reason: 'edit-habit.color-control#2');
      expect(
        appBar().backgroundColor,
        toFlutterColor(theme.color(0)),
        reason: 'edit-habit.color-control#3',
      );
    });

    testWidgets('edit-habit.validation#2/#4/#5: both inline errors are shown '
        'at once and nothing is dispatched', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope, habitType: HabitType.numerical);

      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('Cannot be blank'), findsNWidgets(2),
          reason: 'edit-habit.validation#5');
      expect(scope.habitList.isEmpty, isTrue,
          reason: 'edit-habit.save#13');
      // The editor is still open (`edit-habit.save#11` only fires on success).
      expect(find.byKey(EditHabitScreen.saveButtonKey), findsOneWidget,
          reason: 'edit-habit.save#13');
    });

    testWidgets('edit-habit.save#11: a successful save dispatches the command '
        'and closes the screen', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope);

      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        'Meditate',
      );
      await tester.enterText(
        find.byKey(EditHabitScreen.questionFieldKey),
        'Did you meditate today?',
      );
      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();

      expect(scope.habitList.size(), 1, reason: 'edit-habit.save#9');
      final saved = scope.habitList.getByPosition(0);
      expect(saved.name, 'Meditate', reason: 'edit-habit.save#2');
      expect(saved.question, 'Did you meditate today?',
          reason: 'edit-habit.save#2');
      expect(saved.color, const PaletteColor(11),
          reason: 'edit-habit.entry-points#9');
      expect(find.byKey(EditHabitScreen.saveButtonKey), findsNothing,
          reason: 'edit-habit.save#11');
      expect(find.text('host'), findsOneWidget,
          reason: 'edit-habit.save#11');
    });

    testWidgets('edit-habit.save#12: leaving with the up button discards the '
        'edits silently', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      final habit = addHabit(scope, 'Meditate');
      await pumpEditor(tester, scope, habitId: habit.id);

      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        'Something else',
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(scope.habitList.getById(habit.id!)!.name, 'Meditate',
          reason: 'edit-habit.save#12');
      expect(find.text('host'), findsOneWidget,
          reason: 'edit-habit.save#12');
    });

    testWidgets('edit-habit.reminder-days#1/#3: the days control opens the '
        'weekday picker and renders what it returns', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      modelOf(tester).setReminderTime(8, 0);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EditHabitScreen.reminderDaysPickerKey));
      await tester.pumpAndSettle();
      expect(find.text('Select days'), findsOneWidget,
          reason: 'edit-habit.reminder-days#1');

      // Leave only Monday, which is index 2 because index 0 is Saturday
      // (`edit-habit.reminder-days#4`).
      for (final index in <int>[0, 1, 3, 4, 5, 6]) {
        await tester.tap(find.byKey(ValueKey<String>('weekday_$index')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey<String>('weekday_ok')));
      await tester.pumpAndSettle();

      expect(modelOf(tester).reminderDays, WeekdayList(4),
          reason: 'edit-habit.reminder-days#1');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderDaysPickerKey),
          matching: find.text('Monday'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-days#3',
      );
    });

    testWidgets('edit-habit.reminder-days#2: an empty selection coming back '
        'from the picker becomes every day', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      modelOf(tester).setReminderTime(8, 0);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EditHabitScreen.reminderDaysPickerKey));
      await tester.pumpAndSettle();
      for (var index = 0; index < 7; index++) {
        await tester.tap(find.byKey(ValueKey<String>('weekday_$index')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey<String>('weekday_ok')));
      await tester.pumpAndSettle();

      expect(modelOf(tester).reminderDays, WeekdayList.everyDay,
          reason: 'edit-habit.reminder-days#2');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderDaysPickerKey),
          matching: find.text('Any day of the week'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-days#3',
      );
    });

    testWidgets('edit-habit.reminder-days#1: cancelling the picker leaves the '
        'days alone', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      modelOf(tester).setReminderTime(8, 0);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EditHabitScreen.reminderDaysPickerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('weekday_0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('weekday_cancel')));
      await tester.pumpAndSettle();

      expect(modelOf(tester).reminderDays, WeekdayList.everyDay,
          reason: 'edit-habit.reminder-days#1');
    });

    testWidgets('frequency-picker.save-and-validation#9: the editor stores '
        'the picked pair verbatim and re-renders the summary',
        (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      await tester.tap(find.byKey(EditHabitScreen.frequencyPickerKey));
      await tester.pumpAndSettle();

      // "3 times per week": the row keeps its hard-coded placeholder of 3.
      await tester.tap(
        find.byKey(const ValueKey<String>('frequency_radio_xTimesPerWeek')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('frequency_save')));
      await tester.pumpAndSettle();

      final model = modelOf(tester);
      expect(model.freqNum, 3,
          reason: 'frequency-picker.save-and-validation#9');
      expect(model.freqDen, 7,
          reason: 'frequency-picker.save-and-validation#9');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.frequencyPickerKey),
          matching: find.text('3 times per week'),
        ),
        findsOneWidget,
        reason: 'edit-habit.frequency-display#3',
      );
    });
  });

  // =======================================================================
  // habit-type-dialog.select-type and the two entry points
  // =======================================================================

  group('habit-type-dialog.select-type', () {
    testWidgets('#4: exactly two cards, Yes or No then Measurable',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(body: HabitTypeDialog()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Yes or No'), findsOneWidget,
          reason: 'habit-type-dialog.select-type#4');
      expect(
        find.text(
          'e.g. Did you wake up early today? Did you exercise? '
          'Did you play chess?',
        ),
        findsOneWidget,
        reason: 'habit-type-dialog.select-type#4',
      );
      expect(find.text('Measurable'), findsOneWidget,
          reason: 'habit-type-dialog.select-type#4');
      expect(
        find.text(
          'e.g. How many miles did you run today? How many pages did '
          'you read?',
        ),
        findsOneWidget,
        reason: 'habit-type-dialog.select-type#4',
      );
      // The third "Subjective" card is commented out upstream (`#5`).
      expect(find.byKey(EditHabitScreen.yesNoTypeCardKey), findsOneWidget,
          reason: 'habit-type-dialog.select-type#5');
      expect(find.byKey(EditHabitScreen.measurableTypeCardKey), findsOneWidget,
          reason: 'habit-type-dialog.select-type#5');
    });

    testWidgets('#1/#6: the list screen\'s add action opens the chooser, and '
        'Measurable opens the editor for a numerical habit', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: const HabitListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(HabitTypeDialog), findsOneWidget,
          reason: 'habit-type-dialog.select-type#1');

      await tester.tap(find.byKey(EditHabitScreen.measurableTypeCardKey));
      await tester.pumpAndSettle();

      expect(find.byType(EditHabitScreen), findsOneWidget,
          reason: 'habit-type-dialog.select-type#6');
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Create habit'),
        ),
        findsOneWidget,
        reason: 'edit-habit.entry-points#2',
      );
      // habitType = 1 -> the numerical form (`#6`).
      expect(find.byKey(EditHabitScreen.targetBoxKey), findsOneWidget,
          reason: 'habit-type-dialog.select-type#6');
    });

    testWidgets('#7: tapping the scrim starts nothing', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: const HabitListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      // The very top of the scrim, well clear of both cards.
      await tester.tapAt(const Offset(400, 8));
      await tester.pumpAndSettle();

      expect(find.byType(HabitTypeDialog), findsNothing,
          reason: 'habit-type-dialog.select-type#7');
      expect(find.byType(EditHabitScreen), findsNothing,
          reason: 'habit-type-dialog.select-type#7');
    });

    testWidgets('edit-habit.entry-points#1: the detail screen\'s edit action '
        'opens the editor in EDIT mode', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: ShowHabitScreen(habit: habit),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ShowHabitScreen.editActionKey));
      await tester.pumpAndSettle();

      expect(find.byType(EditHabitScreen), findsOneWidget,
          reason: 'edit-habit.entry-points#1');
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Edit habit'),
        ),
        findsOneWidget,
        reason: 'edit-habit.entry-points#2',
      );
      expect(modelOf(tester).nameController.text, 'Meditate',
          reason: 'edit-habit.entry-points#4');
    });
  });
  // =======================================================================
  // reminders.edit-ui — the same screen, seen from the reminders domain
  // =======================================================================

  group('reminders.edit-ui', () {
    test('#1 #2 the three fields and where they are seeded from', () {
      final scope = openScope();

      final blank = createModel(scope);
      expect(blank.reminderHour, -1,
          reason: "reminders.edit-ui#1: reminderHour, -1 meaning 'no "
              "reminder'");
      expect(blank.reminderMin, -1, reason: 'reminders.edit-ui#1');
      expect(blank.reminderDays, WeekdayList.everyDay,
          reason: 'reminders.edit-ui#1: reminderDays defaults to '
              'WeekdayList.EVERY_DAY');

      final withReminder = addHabit(
        scope,
        'Meditate',
        reminder: Reminder(7, 30, WeekdayList(3)),
      );
      final seeded = createModel(scope, habitId: withReminder.id);
      expect(seeded.reminderHour, 7,
          reason: 'reminders.edit-ui#2: seeded from habit.reminder when it is '
              'non-null');
      expect(seeded.reminderMin, 30, reason: 'reminders.edit-ui#2');
      expect(seeded.reminderDays, WeekdayList(3), reason: 'reminders.edit-ui#2');

      final without = addHabit(scope, 'Run');
      final unseeded = createModel(scope, habitId: without.id);
      expect(unseeded.reminderHour, -1,
          reason: 'reminders.edit-ui#2: otherwise they stay at -1/-1/'
              'EVERY_DAY');
      expect(unseeded.reminderMin, -1, reason: 'reminders.edit-ui#2');
      expect(unseeded.reminderDays, WeekdayList.everyDay,
          reason: 'reminders.edit-ui#2');
    });

    test('#3 the picker opens on the current time, or 08:00', () {
      expect(EditHabitScreen.initialReminderTime(-1, -1),
          const TimeOfDay(hour: 8, minute: 0),
          reason: 'reminders.edit-ui#3: pre-set to reminderHour if >= 0 else '
              '8, and reminderMin if >= 0 else 0 — the default suggested '
              'reminder time is 08:00');
      expect(EditHabitScreen.initialReminderTime(21, 45),
          const TimeOfDay(hour: 21, minute: 45),
          reason: 'reminders.edit-ui#3: an existing reminder seeds the picker');
      expect(EditHabitScreen.initialReminderTime(0, 0),
          const TimeOfDay(hour: 0, minute: 0),
          reason: 'reminders.edit-ui#3: hour 0 is >= 0, so midnight is kept');
    });

    test('#5 onTimeSet stores, onTimeCleared resets all three', () {
      final model = createModel(openScope())
        ..setReminderTime(21, 45);
      expect(model.reminderHour, 21,
          reason: 'reminders.edit-ui#5: onTimeSet stores the picked hour');
      expect(model.reminderMin, 45,
          reason: 'reminders.edit-ui#5: and the picked minute');

      model.setReminderDays(WeekdayList(3));
      model.clearReminder();
      expect(model.reminderHour, -1,
          reason: 'reminders.edit-ui#5: onTimeCleared resets reminderHour = -1');
      expect(model.reminderMin, -1,
          reason: 'reminders.edit-ui#5: reminderMin = -1');
      expect(model.reminderDays, WeekdayList.everyDay,
          reason: 'reminders.edit-ui#5: AND reminderDays = '
              'WeekdayList.EVERY_DAY');
    });

    test('#8 an empty weekday selection is silently replaced by every day',
        () {
      final model = createModel(openScope())
        ..setReminderDays(WeekdayList(0));
      expect(model.reminderDays, WeekdayList.everyDay,
          reason: 'reminders.edit-ui#8: if the resulting list isEmpty it is '
              'silently replaced by WeekdayList.EVERY_DAY');

      model.setReminderDays(WeekdayList(3));
      expect(model.reminderDays, WeekdayList(3),
          reason: 'reminders.edit-ui#8: a non-empty selection is kept as it '
              'is');
    });

    testWidgets('#8 the weekday row opens a "Select days" multi-choice list, '
        'pre-checked and starting at Saturday', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      modelOf(tester)
        ..setReminderTime(8, 0)
        ..setReminderDays(WeekdayList(3));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EditHabitScreen.reminderDaysPickerKey));
      await tester.pumpAndSettle();

      expect(find.text('Select days'), findsOneWidget,
          reason: 'reminders.edit-ui#8: tapping the weekday row opens '
              'WeekdayPickerDialog, titled "Select days"');
      final tiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(tiles.length, 7, reason: 'reminders.edit-ui#8');
      expect(
        tiles.map((t) => (t.title! as Text).data).toList(),
        <String>[
          'Saturday',
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
        ],
        reason: 'reminders.edit-ui#8: multi-choice items = long weekday names '
            'starting at Saturday',
      );
      expect(
        tiles.map((t) => t.value).toList(),
        <bool>[true, true, false, false, false, false, false],
        reason: 'reminders.edit-ui#8: pre-checked from the current '
            'WeekdayList — WeekdayList(3) is Saturday and Sunday',
      );

      // Untick everything and confirm: the empty result is replaced.
      for (var index = 0; index < 7; index++) {
        if (tiles[index].value!) {
          await tester.tap(find.byKey(ValueKey<String>('weekday_$index')));
          await tester.pump();
        }
      }
      await tester.tap(find.byKey(const ValueKey<String>('weekday_ok')));
      await tester.pumpAndSettle();

      expect(modelOf(tester).reminderDays, WeekdayList.everyDay,
          reason: 'reminders.edit-ui#8: confirming builds '
              'WeekdayList(selectedDays); if the resulting list isEmpty it is '
              'silently replaced by WeekdayList.EVERY_DAY');
    });

    test('#9 the reminder is written whole, or set to null', () {
      final scope = openScope();
      final model = createModel(scope)
        ..nameController.text = 'Meditate'
        ..setReminderTime(8, 30)
        ..setReminderDays(WeekdayList(3));
      model.save();
      final saved = scope.habitList.getByPosition(0);
      expect(saved.reminder, isNotNull,
          reason: 'reminders.edit-ui#9: if reminderHour >= 0 then '
              'habit.reminder = Reminder(reminderHour, reminderMin, '
              'reminderDays)');
      expect(saved.reminder!.hour, 8, reason: 'reminders.edit-ui#9');
      expect(saved.reminder!.minute, 30, reason: 'reminders.edit-ui#9');
      expect(saved.reminder!.days, WeekdayList(3),
          reason: 'reminders.edit-ui#9');

      final second = createModel(scope)..nameController.text = 'Run';
      second.save();
      expect(scope.habitList.getByPosition(1).reminder, isNull,
          reason: 'reminders.edit-ui#9: else habit.reminder = null');
    });

    testWidgets('#6 #7 Off hides the weekday row and its divider; a time '
        'shows both', (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('Off'),
        ),
        findsOneWidget,
        reason: 'reminders.edit-ui#6: when reminderHour < 0 the time row shows '
            'the string reminder_off',
      );
      expect(find.byKey(EditHabitScreen.reminderDaysPickerKey), findsNothing,
          reason: 'reminders.edit-ui#6: and the weekday row is GONE');
      expect(find.byKey(EditHabitScreen.reminderDividerKey), findsNothing,
          reason: 'reminders.edit-ui#6: together with its divider');

      modelOf(tester)
        ..setReminderTime(8, 30)
        ..setReminderDays(WeekdayList(3));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('8:30 AM'),
        ),
        findsOneWidget,
        reason: 'reminders.edit-ui#7: when reminderHour >= 0 the time row '
            'shows formatTime(context, hour, minute)',
      );
      expect(find.byKey(EditHabitScreen.reminderDividerKey), findsOneWidget,
          reason: 'reminders.edit-ui#7');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderDaysPickerKey),
          matching: find.text('Weekends'),
        ),
        findsOneWidget,
        reason: 'reminders.edit-ui#7: and the weekday row is visible showing '
            'reminderDays.toFormattedString(context)',
      );
    });

    testWidgets('#11 the time row renders the wall-clock hour and minute',
        (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      modelOf(tester).setReminderTime(0, 5);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('12:05 AM'),
        ),
        findsOneWidget,
        reason: 'reminders.edit-ui#11: formatTime formats (hours * 60 + '
            'minutes) * 60000 ms in UTC, so the rendered time is exactly the '
            "wall-clock hour:minute in the user's 12/24-hour preference",
      );

      modelOf(tester).setReminderTime(23, 59);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('11:59 PM'),
        ),
        findsOneWidget,
        reason: 'reminders.edit-ui#11: no time zone is ever applied to it',
      );
    });
  });

  // =======================================================================
  // reminders.weekday-label
  // =======================================================================

  group('reminders.weekday-label', () {
    const shortNames = <String>[
      'Sat',
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
    ];
    const longNames = <String>[
      'Saturday',
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];

    String format(WeekdayList days) => formatWeekdayList(
          days,
          l10n,
          shortNames: shortNames,
          longNames: longNames,
        );

    WeekdayList listOf(List<int> indexes) => WeekdayList.fromArray(
          List<bool>.generate(7, indexes.contains),
        );

    test('#7 #8 the seven names are taken in Saturday-first order', () {
      expect(
        getWeekdaySequence(DayOfWeek.saturday),
        <DayOfWeek>[
          DayOfWeek.saturday,
          DayOfWeek.sunday,
          DayOfWeek.monday,
          DayOfWeek.tuesday,
          DayOfWeek.wednesday,
          DayOfWeek.thursday,
          DayOfWeek.friday,
        ],
        reason: 'reminders.weekday-label#7: getWeekdaySequence(SATURDAY) '
            'yields [SATURDAY, SUNDAY, MONDAY, TUESDAY, WEDNESDAY, THURSDAY, '
            'FRIDAY] via allDays[(firstWeekday.daysSinceSunday + offset) % 7]',
      );
      expect(WeekdayPickerDialog.weekdays.first, DayOfWeek.saturday,
          reason: 'reminders.weekday-label#8: the short and long weekday names '
              'are built anchored at DayOfWeek.SATURDAY, so array index 0 '
              'corresponds to Saturday');
      expect(WeekdayPickerDialog.weekdays.last, DayOfWeek.friday,
          reason: 'reminders.weekday-label#8: and index 6 to Friday');
      expect(format(listOf(<int>[0])), 'Saturday',
          reason: 'reminders.weekday-label#1: index 0 is Saturday');
      expect(format(listOf(<int>[6])), 'Friday',
          reason: 'reminders.weekday-label#1: through index 6 Friday');
    });

    test('#2 to #6 the five ordered branches', () {
      expect(format(listOf(<int>[4])), 'Wednesday',
          reason: 'reminders.weekday-label#2: exactly one day selected gives '
              'the LONG name of that day');
      expect(format(listOf(<int>[0, 1])), 'Weekends',
          reason: 'reminders.weekday-label#3: exactly two days at indices 0 '
              'and 1 (Saturday and Sunday) give the string weekends');
      expect(format(listOf(<int>[2, 3, 4, 5, 6])), 'Monday to Friday',
          reason: 'reminders.weekday-label#4: exactly five days with indices 0 '
              'and 1 both false give any_weekday');
      expect(format(WeekdayList(127)), 'Any day of the week',
          reason: 'reminders.weekday-label#5: all seven days give any_day');
      expect(format(listOf(<int>[0, 2])), 'Sat, Mon',
          reason: 'reminders.weekday-label#6: otherwise the SHORT names of the '
              'selected days are joined with ", " in index order starting at '
              'Saturday');
      expect(format(listOf(<int>[1, 2])), 'Sun, Mon',
          reason: 'reminders.weekday-label#3: two days that are NOT the '
              'weekend fall through to the short-name join');
      expect(format(listOf(<int>[0, 2, 3, 4, 5])), 'Sat, Mon, Tue, Wed, Thu',
          reason: 'reminders.weekday-label#4: five days that include Saturday '
              'fall through as well');
    });

    test('#9 the join is comma + space, the first without a separator', () {
      expect(format(listOf(<int>[0, 1, 2])), 'Sat, Sun, Mon',
          reason: 'reminders.weekday-label#9: selected days are appended as '
              'short names joined by ", ", the first without a separator');
      expect(format(listOf(<int>[6, 0])).startsWith('Sat'), isTrue,
          reason: 'reminders.weekday-label#9: it iterates i in 0..6, so the '
              'order is the array order and not the selection order');
    });
  });

  // =======================================================================
  // intents.actions-and-extras#14 — what the edit entry point carries
  // =======================================================================

  group('intents.actions-and-extras', () {
    testWidgets('#14 the editor route carries habitId and habitType',
        (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      final habit = addHabit(scope, 'Meditate');

      await pumpEditor(tester, scope, habitId: habit.id);
      expect(modelOf(tester).habitId, habit.id,
          reason: 'intents.actions-and-extras#14: startEditActivity(context, '
              "habit) puts the extras 'habitId' (Long) and 'habitType' (Int)");
      expect(modelOf(tester).habitType, HabitType.yesNo,
          reason: 'intents.actions-and-extras#14');

      await pumpEditor(tester, scope, habitType: HabitType.numerical);
      expect(modelOf(tester).habitId, -1,
          reason: 'intents.actions-and-extras#14: startEditActivity(context, '
              "habitType) puts only 'habitType'");
      expect(modelOf(tester).habitType, HabitType.numerical,
          reason: 'intents.actions-and-extras#14');
    });
  });
}
