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
// `Theme` is ambiguous: Flutter's inherited widget and the core's palette
// holder share the name, and this file needs both.
import 'package:flutter/material.dart' as material show Color, Theme;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits/ui/common/dialogs/current_dialog.dart';
import 'package:uhabits/ui/common/dialogs/weekday_picker_dialog.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/list_header.dart'
    show IntlLocalDateFormatter;
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/show/show_habit_screen.dart';
import 'package:uhabits/ui/theme/app_theme.dart'
    show appThemeData, toFlutterColor;
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';
// `Theme` is exported by both `material.dart` and the core, so the core's
// palette holder needs a prefix to be nameable at all.
import 'package:uhabits_core/uhabits_core.dart' as core show Theme;

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
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
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

  /// [dark] stands for `AndroidThemeSwitcher` having applied a night theme,
  /// and [use24HourFormat] for the Android system setting
  /// `DateFormat.is24HourFormat` — which is what `MediaQuery.alwaysUse24Hour
  /// Format` carries in Flutter (`edit-habit.reminder-time#4`, `#8`).
  Future<void> pumpEditor(
    WidgetTester tester,
    AppScope scope, {
    int? habitId,
    HabitType habitType = HabitType.yesNo,
    bool dark = false,
    bool? use24HourFormat,
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
  }) async {
    final Widget host = Provider<AppScope>.value(
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
    );
    await tester.pumpWidget(
      MaterialApp(
        // A fresh key per call: a test that opens the editor twice must get a
        // fresh navigator, not the one still holding the first route.
        key: ValueKey<int>(nextTree++),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        navigatorObservers: observers,
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        // `builder` sits *above* the navigator, so the pushed editor route —
        // and the dialogs it opens — see the overridden MediaQuery too.
        builder: use24HourFormat == null
            ? null
            : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: use24HourFormat),
                  child: child!,
                ),
        home: host,
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

    testWidgets(
        'audit10.weekday-name-rows-follow-the-device-locale#1: the days '
        'summary names the day in the device language, exactly as the picker '
        'it opens does', (tester) async {
      const String rule =
          'audit10.weekday-name-rows-follow-the-device-locale#1 — '
          'WeekdayList.toFormattedString(context) builds '
          'JavaLocalDateFormatter(Locale.getDefault()) — the DEVICE locale — '
          'for both its short and its long names, the same formatter '
          'WeekdayPickerDialog uses. The two can never disagree upstream.';

      // A device language the app ships no translation for: only there do the
      // device locale and the locale the UI resolved to differ.
      tester.platformDispatcher.localesTestValue =
          const <Locale>[Locale('th', 'TH')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));
      modelOf(tester)
        ..setReminderTime(8, 30)
        ..setReminderDays(WeekdayList(4));
      await tester.pumpAndSettle();

      // Built after the first pump: flutter_localizations installs intl's
      // per-locale date tables the first time one of its delegates loads.
      final formatter = IntlLocalDateFormatter('th');
      expect(formatter.localeName, 'th',
          reason: '$rule The fixture is only meaningful with real Thai date '
              'data installed.');
      final monday = formatter.longWeekdayNameOf(DayOfWeek.monday);

      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderDaysPickerKey),
          matching: find.text(monday),
        ),
        findsOneWidget,
        reason: '$rule WeekdayList(4) is Monday, and Android names it in the '
            "device's language while the form around it stays English.",
      );

      await tester.tap(find.byKey(EditHabitScreen.reminderDaysPickerKey));
      await tester.pumpAndSettle();
      final pickerNames = tester
          .widgetList<CheckboxListTile>(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(CheckboxListTile),
          ))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(
        pickerNames,
        <String>[
          for (final day in getWeekdaySequence(DayOfWeek.saturday))
            formatter.longWeekdayNameOf(day),
        ],
        reason: '$rule The picker already reads the device locale; the label '
            'that opens it has to agree, or one pump shows both spellings.',
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

      await tester.tap(find
          .byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.createHabit)));
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

      await tester.tap(find
          .byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.createHabit)));
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

    testWidgets(
        '#10 the three reminder fields survive a configuration change',
        (tester) async {
      // `onSaveInstanceState` persists "reminderHour", "reminderMin" and
      // "reminderDays" so that a rotation does not lose an unsaved reminder.
      // Flutter never destroys the route on a metrics change, so what stands
      // in for the rotation here is the resize itself: the same three fields
      // must still be there, and still be on screen, afterwards.
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        use24HourFormat: true,
      );
      modelOf(tester)
        ..setReminderTime(21, 45)
        ..setReminderDays(WeekdayList(3));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('21:45'),
        ),
        findsOneWidget,
        reason: 'reminders.edit-ui#10: instance state persists "reminderHour" '
            '(Int), "reminderMin" (Int) and "reminderDays" (Int, the packed '
            'WeekdayList) across rotation',
      );

      // Landscape.
      await tester.binding.setSurfaceSize(const Size(900, 400));
      await tester.pumpAndSettle();

      final model = modelOf(tester);
      expect(
        <Object?>[model.reminderHour, model.reminderMin, model.reminderDays],
        <Object?>[21, 45, WeekdayList(3)],
        reason: 'reminders.edit-ui#10: instance state persists "reminderHour" '
            '(Int), "reminderMin" (Int) and "reminderDays" (Int, the packed '
            'WeekdayList) across rotation',
      );
      expect(model.reminderDays.toInteger(), 3,
          reason: 'reminders.edit-ui#10: reminderDays travels as the packed '
              'integer');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('21:45'),
        ),
        findsOneWidget,
        reason: 'reminders.edit-ui#10: and the rebuilt screen shows them again',
      );
      expect(find.byKey(EditHabitScreen.reminderDaysPickerKey), findsOneWidget,
          reason: 'reminders.edit-ui#10: including the weekday row, which only '
              'exists while a reminder is set');
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

  // =======================================================================
  // Rules that only became assertable once the whole screen existed.
  // =======================================================================

  group('edit-habit.form-layout, revisited', () {
    test('#5 Name and Question are two independent fields', () {
      final scope = openScope();
      final model = createModel(scope)
        ..nameController.text = 'Meditate'
        ..questionController.text = 'Did you meditate today?';
      expect(model.save(), isTrue);

      final saved = scope.habitList.getByPosition(0);
      expect(saved.name, 'Meditate',
          reason: 'edit-habit.form-layout#5 — Habit.name is stored on its own');
      expect(saved.question, 'Did you meditate today?',
          reason: 'edit-habit.form-layout#5 — Habit.question is stored on its '
              'own, and neither field is derived from the other');

      // Editing one leaves the other alone, in both directions.
      final second = createModel(scope, habitId: saved.id)
        ..questionController.text = 'Did you sit today?';
      expect(second.save(), isTrue);
      final again = scope.habitList.getById(saved.id!)!;
      expect(again.name, 'Meditate', reason: 'edit-habit.form-layout#5');
      expect(again.question, 'Did you sit today?',
          reason: 'edit-habit.form-layout#5');
    });

    testWidgets('#9 Target Type is a dropdown, not a text field',
        (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );

      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.targetTypeBoxKey),
          matching: find.text('Target Type'),
        ),
        findsOneWidget,
        reason: 'edit-habit.form-layout#9 — the box is labelled "Target Type"',
      );
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.targetTypeBoxKey),
          matching: find.byType(TextField),
        ),
        findsNothing,
        reason: 'edit-habit.form-layout#9 — it is a TextView, so there is no '
            'free text to type into',
      );
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.targetTypePickerKey),
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
        reason: 'edit-habit.form-layout#9',
      );
    });

    testWidgets('#10 the colour control is an 80dp button tinted with the '
        'resolved habit colour', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      final habit = addHabit(scope, 'Meditate', color: const PaletteColor(4));
      await pumpEditor(tester, scope, habitId: habit.id);

      expect(EditHabitMetrics.colorBoxWidth, 80.0,
          reason: 'edit-habit.form-layout#10 — an 80dp-wide button');
      final colorColumn = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == EditHabitMetrics.colorBoxWidth,
      );
      expect(tester.getSize(colorColumn).width, EditHabitMetrics.colorBoxWidth,
          reason: 'edit-habit.form-layout#10 — the colour column really is '
              'laid out 80dp wide, whatever the name field beside it takes');
      expect(find.text('Color'), findsOneWidget,
          reason: 'edit-habit.form-layout#10 — its label is "Color"');
      expect(
        tester
            .widget<Material>(find.byKey(EditHabitScreen.colorButtonKey))
            .color,
        toFlutterColor(LightTheme().color(4)),
        reason: 'edit-habit.form-layout#10 — the background tint is the '
            'resolved habit colour',
      );
    });

    testWidgets('#11 both frequency controls and the reminder controls are '
        'dropdown TextViews', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());

      await pumpEditor(tester, scope);
      for (final key in <Key>[
        EditHabitScreen.frequencyPickerKey,
        EditHabitScreen.reminderTimePickerKey,
      ]) {
        expect(
          find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
          findsNothing,
          reason: 'edit-habit.form-layout#11 — no spinner and no free text',
        );
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byIcon(Icons.arrow_drop_down),
          ),
          findsOneWidget,
          reason: 'edit-habit.form-layout#11 — @style/FormDropdown draws a '
              'drop-down arrow',
        );
      }

      // The reminder-days control only exists while a reminder is set.
      modelOf(tester).setReminderTime(8, 0);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderDaysPickerKey),
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
        reason: 'edit-habit.form-layout#11',
      );

      await pumpEditor(tester, scope, habitType: HabitType.numerical);
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.numericalFrequencyPickerKey),
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
        findsOneWidget,
        reason: 'edit-habit.form-layout#11 — the numerical frequency control '
            'too',
      );
    });
  });

  group('edit-habit.type-field-visibility, revisited', () {
    testWidgets('#3 the visible fields are decided once and never change',
        (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope, habitType: HabitType.numerical);

      // There is no control for the type on screen at all
      // (`edit-habit.entry-points#6`), so nothing can flip the visibility.
      expect(find.byKey(EditHabitScreen.yesNoTypeCardKey), findsNothing,
          reason: 'edit-habit.type-field-visibility#3');
      expect(find.byKey(EditHabitScreen.measurableTypeCardKey), findsNothing,
          reason: 'edit-habit.type-field-visibility#3');

      // Exercise everything the form *can* change and re-check the boxes.
      await tester.enterText(find.byKey(EditHabitScreen.nameFieldKey), 'Run');
      await tester.enterText(find.byKey(EditHabitScreen.targetFieldKey), '15');
      modelOf(tester)
        ..setColor(const PaletteColor(2))
        ..setFrequencyDenominator(30)
        ..setTargetType(NumericalHabitType.atMost)
        ..setReminderTime(8, 30);
      await tester.pumpAndSettle();

      expect(modelOf(tester).habitType, HabitType.numerical,
          reason: 'edit-habit.type-field-visibility#3 — habitType is a '
              '`late final`: the screen cannot change it');
      expect(find.byKey(EditHabitScreen.unitBoxKey), findsOneWidget,
          reason: 'edit-habit.type-field-visibility#3');
      expect(find.byKey(EditHabitScreen.targetBoxKey), findsOneWidget,
          reason: 'edit-habit.type-field-visibility#3');
      expect(find.byKey(EditHabitScreen.targetTypeBoxKey), findsOneWidget,
          reason: 'edit-habit.type-field-visibility#3');
      expect(find.byKey(EditHabitScreen.frequencyBoxKey), findsNothing,
          reason: 'edit-habit.type-field-visibility#3 — the yes/no frequency '
              'box stays gone for the life of the screen');
    });
  });

  group('edit-habit.validation, revisited', () {
    testWidgets('#3 both inline errors are rendered the same way', (
      tester,
    ) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope, habitType: HabitType.numerical);

      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();

      final errors = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.decoration?.errorText)
          .where((t) => t != null)
          .toList();
      expect(errors, <String>['Cannot be blank', 'Cannot be blank'],
          reason: 'edit-habit.validation#3 (deviation) — Kotlin wraps only the '
              'name error in <font color=#FFFFFF>…</font> and renders it with '
              'Html.fromHtml, an artifact of the Android error popup. The port '
              'has no such popup, so both errors carry the same plain string '
              'and are drawn identically',
      );
      // Neither error carries markup of any kind.
      expect(find.textContaining('<font'), findsNothing,
          reason: 'edit-habit.validation#3 (deviation)');
    });
  });

  group('edit-habit.save, revisited', () {
    test('#1 edit mode starts from copyFrom(original), which copies every '
        'field except the id', () {
      final scope = openScope();
      final original = addHabit(
        scope,
        'Run',
        color: const PaletteColor(2),
        type: HabitType.numerical,
        frequency: Frequency(3, 7),
        reminder: Reminder(6, 15, WeekdayList(12)),
        question: 'How far?',
        description: 'morning loop',
        unit: 'miles',
        targetValue: 15.0,
        targetType: NumericalHabitType.atMost,
      );
      original.isArchived = true;
      scope.habitList.updateOne(original);

      // What `save()` builds before any form value is written: a fresh habit
      // from the factory with the original copied over it.
      final copy = scope.modelFactory.buildHabit()..copyFrom(original);
      expect(copy.color, original.color, reason: 'edit-habit.save#1');
      expect(copy.description, original.description,
          reason: 'edit-habit.save#1');
      expect(copy.frequency, original.frequency, reason: 'edit-habit.save#1');
      expect(copy.isArchived, original.isArchived, reason: 'edit-habit.save#1');
      expect(copy.name, original.name, reason: 'edit-habit.save#1');
      expect(copy.position, original.position, reason: 'edit-habit.save#1');
      expect(copy.question, original.question, reason: 'edit-habit.save#1');
      expect(copy.reminder, original.reminder, reason: 'edit-habit.save#1');
      expect(copy.targetType, original.targetType, reason: 'edit-habit.save#1');
      expect(copy.targetValue, original.targetValue,
          reason: 'edit-habit.save#1');
      expect(copy.type, original.type, reason: 'edit-habit.save#1');
      expect(copy.unit, original.unit, reason: 'edit-habit.save#1');
      expect(copy.uuid, original.uuid, reason: 'edit-habit.save#1');
      expect(copy.id, isNull,
          reason: 'edit-habit.save#1 — the id is the one field copyFrom does '
              'NOT take, which is what keeps the command able to tell an edit '
              'from a create');

      // …and the form values then overwrite the relevant fields.
      final model = createModel(scope, habitId: original.id)
        ..nameController.text = 'Run further';
      expect(model.save(), isTrue, reason: 'edit-habit.save#1');
      final saved = scope.habitList.getById(original.id!)!;
      expect(saved.name, 'Run further', reason: 'edit-habit.save#1');
      expect(saved.isArchived, isTrue,
          reason: 'edit-habit.save#1 — untouched fields survive the copy');
    });

    test('#15 the form values are applied in the documented order', () {
      final scope = openScope();
      final model = createModel(scope, habitType: HabitType.numerical)
        ..nameController.text = '  Run  '
        ..questionController.text = '  How far?  '
        ..notesController.text = '  morning loop  '
        ..unitController.text = '  miles  '
        ..targetController.text = '15'
        ..setColor(const PaletteColor(4))
        ..setFrequency(3, 7)
        ..setTargetType(NumericalHabitType.atMost)
        ..setReminderTime(6, 15)
        ..setReminderDays(WeekdayList(12));
      expect(model.save(), isTrue);

      final saved = scope.habitList.getByPosition(0);
      expect(saved.name, 'Run', reason: 'edit-habit.save#15 — name trimmed');
      expect(saved.question, 'How far?',
          reason: 'edit-habit.save#15 — question trimmed');
      expect(saved.description, 'morning loop',
          reason: 'edit-habit.save#15 — description trimmed');
      expect(saved.color, const PaletteColor(4),
          reason: 'edit-habit.save#15 — colour from the picker');
      expect(saved.reminder, Reminder(6, 15, WeekdayList(12)),
          reason: 'edit-habit.save#15 — reminderHour >= 0 writes a Reminder');
      expect(saved.frequency, Frequency(3, 7),
          reason: 'edit-habit.save#15 — Frequency(freqNum, freqDen)');
      expect(saved.targetValue, 15.0,
          reason: 'edit-habit.save#15 — numerical habits write the target');
      expect(saved.targetType, NumericalHabitType.atMost,
          reason: 'edit-habit.save#15');
      expect(saved.unit, 'miles',
          reason: 'edit-habit.save#15 — the unit is trimmed too');
      expect(saved.type, HabitType.numerical,
          reason: 'edit-habit.save#15 — habit.type is assigned last');

      // reminderHour < 0 is the other branch of the same statement.
      final second = createModel(scope)..nameController.text = 'Meditate';
      expect(second.save(), isTrue);
      expect(scope.habitList.getByPosition(1).reminder, isNull,
          reason: 'edit-habit.save#15 — otherwise the reminder is null');
    });

    testWidgets('#17 the dispatch branches on habitId and the screen closes '
        'without waiting for the command', (tester) async {
      // CREATE: habitId < 0.
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope);
      expect(modelOf(tester).habitId, -1, reason: 'edit-habit.save#17');
      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        'Meditate',
      );
      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();
      expect(scope.habitList.size(), 1,
          reason: 'edit-habit.save#17 — CreateHabitCommand(modelFactory, '
              'habitList, habit)');
      final created = scope.habitList.getByPosition(0);

      // EDIT: habitId >= 0 runs EditHabitCommand instead, so the list keeps
      // its size and the same row is rewritten.
      await pumpEditor(tester, scope, habitId: created.id);
      expect(modelOf(tester).habitId, created.id, reason: 'edit-habit.save#17');
      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        'Meditate more',
      );
      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();
      expect(scope.habitList.size(), 1,
          reason: 'edit-habit.save#17 — EditHabitCommand(habitList, habitId, '
              'habit)');
      expect(scope.habitList.getById(created.id!)!.name, 'Meditate more',
          reason: 'edit-habit.save#17');
    });

    test('#17 the command is handed to the runner and save() returns without '
        'waiting for it', () async {
      // The Android activity calls `finish()` on the next line after
      // `commandRunner.run(command)`; `save()` is that line's counterpart, so
      // what it must guarantee is that it returns before the command has run.
      final scope = openScope(dispatcher: const AsyncDispatcher());
      final model = createModel(scope)..nameController.text = 'Meditate';

      expect(model.save(), isTrue, reason: 'edit-habit.save#17');
      expect(scope.habitList.isEmpty, isTrue,
          reason: 'edit-habit.save#17 — the runner has not executed the '
              'command yet, and the screen is already gone');

      await pumpEventQueue();
      expect(scope.habitList.size(), 1,
          reason: 'edit-habit.save#17 — it lands one turn later');
    });

    testWidgets('#18 the editor itself shows no confirmation', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope);
      await tester.enterText(
        find.byKey(EditHabitScreen.nameFieldKey),
        'Meditate',
      );
      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing,
          reason: 'edit-habit.save#18 — the editor is already gone by the time '
              'the command finishes, so the "Habit created" toast is the list '
              "screen's to show, not this screen's");
      expect(find.text('host'), findsOneWidget,
          reason: 'edit-habit.save#18 — control has returned to the caller');
    });
  });

  group('edit-habit.color-control, revisited', () {
    testWidgets('#4 the dark theme paints the toolbar with colorPrimary',
        (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      final habit = addHabit(scope, 'Meditate', color: const PaletteColor(4));

      await pumpEditor(tester, scope, habitId: habit.id, dark: true);
      expect(
        tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
        toFlutterColor(DarkTheme().primaryColor),
        reason: 'edit-habit.color-control#4 — updateColors() repaints the '
            'toolbar with the habit colour only outside night mode; the dark '
            'themes set useHabitColorAsPrimary=false and fall back to '
            'colorPrimary, grey_950',
      );
    });

    test('#6 the LightTheme palette', () {
      const List<int> rgb = <int>[
        0xD32F2F, 0xE64A19, 0xF57C00, 0xFF8F00, 0xF9A825,
        0xAFB42B, 0x7CB342, 0x388E3C, 0x00897B, 0x00ACC1,
        0x039BE5, 0x1976D2, 0x303F9F, 0x5E35B1, 0x8E24AA,
        0xD81B60, 0x5D4037, 0x424242, 0x757575, 0x9E9E9E,
      ];
      final theme = LightTheme();
      for (var i = 0; i < rgb.length; i++) {
        expect(theme.color(i).toInt(), 0xFF000000 | rgb[i],
            reason: 'edit-habit.color-control#6 — palette index $i');
      }
      for (final index in <int>[-1, 20, 99]) {
        expect(theme.color(index).toInt(), 0xFF000000,
            reason: 'edit-habit.color-control#6 — any other index is black');
      }
    });

    test('#7 the DarkTheme palette', () {
      const List<int> rgb = <int>[
        0xEF9A9A, 0xFFAB91, 0xFFCC80, 0xFFECB3, 0xFFF59D,
        0xE6EE9C, 0xC5E1A5, 0x69F0AE, 0x80CBC4, 0x80DEEA,
        0x81D4FA, 0x64B5F6, 0x9FA8DA, 0xB39DDB, 0xCE93D8,
        0xF48FB1, 0xBCAAA4, 0xF5F5F5, 0xE0E0E0, 0x9E9E9E,
      ];
      final theme = DarkTheme();
      for (var i = 0; i < rgb.length; i++) {
        expect(theme.color(i).toInt(), 0xFF000000 | rgb[i],
            reason: 'edit-habit.color-control#7 — palette index $i');
      }
      for (final index in <int>[-1, 20, 99]) {
        expect(theme.color(index).toInt(), 0xFFFFFFFF,
            reason: 'edit-habit.color-control#7 — any other index is white');
      }
    });
  });

  group('edit-habit.numerical-frequency-picker, revisited', () {
    testWidgets('#4 the list dismisses itself and the label is re-rendered',
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
        reason: 'edit-habit.frequency-display#4',
      );

      await tester.tap(find.byKey(EditHabitScreen.numericalFrequencyPickerKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('Every week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing,
          reason: 'edit-habit.numerical-frequency-picker#4 — the click handler '
              'dismisses the dialog');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.numericalFrequencyPickerKey),
          matching: find.text('Every week'),
        ),
        findsOneWidget,
        reason: 'edit-habit.numerical-frequency-picker#4 — and the label is '
            're-rendered',
      );
    });

    testWidgets('#6 there is no cancel button, and tapping outside changes '
        'nothing', (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );
      await tester.tap(find.byKey(EditHabitScreen.numericalFrequencyPickerKey));
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsNothing,
          reason: 'edit-habit.numerical-frequency-picker#6 — the builder sets '
              'an adapter and no buttons at all');
      expect(find.text('Cancel'), findsNothing,
          reason: 'edit-habit.numerical-frequency-picker#6');

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing,
          reason: 'edit-habit.numerical-frequency-picker#6 — a tap outside '
              'dismisses it');
      expect(modelOf(tester).freqDen, 1,
          reason: 'edit-habit.numerical-frequency-picker#6 — without changing '
              'the frequency');
    });
  });

  group('the DialogUtils current-dialog slot', () {
    setUp(resetCurrentDialog);
    tearDown(resetCurrentDialog);

    testWidgets('edit-habit.target-type-picker#6: the target-type dialog is '
        'shown via dismissCurrentAndShow, so it becomes the tracked one',
        (tester) async {
      const rule = 'edit-habit.target-type-picker#6';
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );
      expect(hasCurrentDialog, isFalse, reason: rule);

      await tester.tap(find.byKey(EditHabitScreen.targetTypePickerKey));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget, reason: rule);
      expect(hasCurrentDialog, isTrue,
          reason: '\$rule — dismissCurrentAndShow registers the dialog in the '
              'process-wide slot before showing it');

      // …and being tracked is what lets anything else close it: the next
      // dismissCurrentAndShow, or a screen going to the background.
      dismissCurrentDialog();
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing,
          reason: '\$rule — so it first dismisses any other dialog tracked as '
              "'current', and is itself dismissed the same way");
      expect(hasCurrentDialog, isFalse, reason: rule);
      expect(modelOf(tester).targetType, NumericalHabitType.atLeast,
          reason: '\$rule — closing it picks nothing');
    });

    testWidgets('edit-habit.target-type-picker#6: opening another tracked '
        'picker closes it', (tester) async {
      const rule = 'edit-habit.target-type-picker#6';
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );

      // The colour picker is one of the five that share the slot.
      await tester.tap(find.byKey(EditHabitScreen.colorButtonKey));
      await tester.pumpAndSettle();
      expect(hasCurrentDialog, isTrue, reason: rule);

      dismissCurrentDialog();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(EditHabitScreen.targetTypePickerKey));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget,
          reason: '\$rule — the target-type list opens in the slot the colour '
              'picker has vacated');
    });

    testWidgets('edit-habit.numerical-frequency-picker#5: builder.show() '
        'leaves the slot alone', (tester) async {
      const rule = 'edit-habit.numerical-frequency-picker#5';
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );

      await tester.tap(find.byKey(EditHabitScreen.numericalFrequencyPickerKey));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget, reason: rule);
      expect(hasCurrentDialog, isFalse,
          reason: '\$rule — it is shown with builder.show(), so it never '
              'registers itself as the current dialog');

      // Which is exactly what makes it survive a dismissCurrentDialog() that
      // would have closed any of the other five.
      dismissCurrentDialog();
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget,
          reason: '\$rule — so it does NOT participate in the global '
              '"dismiss current dialog first" mechanism');

      // It also does not evict a dialog that *is* tracked: the two mechanisms
      // simply never meet.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsNothing, reason: rule);
      expect(hasCurrentDialog, isFalse, reason: rule);
    });
  });

  group('edit-habit.target-type-picker, revisited', () {
    testWidgets('#3 the click handler dismisses the dialog', (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        habitType: HabitType.numerical,
      );
      await tester.tap(find.byKey(EditHabitScreen.targetTypePickerKey));
      await tester.pumpAndSettle();
      expect(find.byType(SimpleDialog), findsOneWidget,
          reason: 'edit-habit.target-type-picker#3');

      await tester.tap(
        find.descendant(
          of: find.byType(SimpleDialog),
          matching: find.text('At most'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SimpleDialog), findsNothing,
          reason: 'edit-habit.target-type-picker#3 — dialog.dismiss() runs '
              'inside the click handler, not on a button');
    });

    testWidgets('#5 the dropdown is unreachable for a yes/no habit',
        (tester) async {
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      expect(find.byKey(EditHabitScreen.targetTypeBoxKey), findsNothing,
          reason: 'edit-habit.target-type-picker#5 — the whole box is GONE');
      expect(find.byKey(EditHabitScreen.targetTypePickerKey), findsNothing,
          reason: 'edit-habit.target-type-picker#5');
      expect(find.text('Target Type'), findsNothing,
          reason: 'edit-habit.target-type-picker#5');
    });
  });

  group('edit-habit.reminder-time, revisited', () {
    testWidgets('#4 the picker is a 24-hour one exactly when the system says '
        'so', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());

      await pumpEditor(tester, scope, use24HourFormat: true);
      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();
      expect(find.text('AM'), findsNothing,
          reason: 'edit-habit.reminder-time#4 — DateFormat.is24HourFormat is '
              'MediaQuery.alwaysUse24HourFormat here, and a 24-hour picker '
              'hides the AM/PM control');
      expect(find.text('PM'), findsNothing,
          reason: 'edit-habit.reminder-time#4');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await pumpEditor(tester, scope, use24HourFormat: false);
      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();
      expect(find.text('AM'), findsOneWidget,
          reason: 'edit-habit.reminder-time#4 — and a 12-hour one shows it');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    test('#5 onTimeSet stores the hour and the minute', () {
      final model = createModel(openScope());
      expect(model.hasReminder, isFalse, reason: 'edit-habit.reminder-time#5');

      model.setReminderTime(21, 45);
      expect(model.reminderHour, 21, reason: 'edit-habit.reminder-time#5');
      expect(model.reminderMin, 45, reason: 'edit-habit.reminder-time#5');
      expect(model.hasReminder, isTrue, reason: 'edit-habit.reminder-time#5');
    });

    testWidgets('#5 #8 the control re-renders the stored time in the system '
        '12/24h format', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());

      await pumpEditor(tester, scope, use24HourFormat: false);
      modelOf(tester).setReminderTime(8, 0);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('8:00 AM'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-time#5 — onTimeSet re-renders the '
            'control; #8 — formatTime uses DateFormat.getTimeFormat(context), '
            'which follows the 12/24h system preference',
      );

      await pumpEditor(tester, scope, use24HourFormat: true);
      modelOf(tester).setReminderTime(8, 0);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.reminderTimePickerKey),
          matching: find.text('08:00'),
        ),
        findsOneWidget,
        reason: 'edit-habit.reminder-time#8 — the same instant renders as '
            '"08:00" under a 24-hour preference',
      );
    });

    test('#9 a saved habit has a complete reminder or none at all', () {
      final scope = openScope();
      final withReminder = createModel(scope)
        ..nameController.text = 'Meditate'
        ..setReminderTime(8, 30)
        ..setReminderDays(WeekdayList(12));
      expect(withReminder.save(), isTrue);
      final saved = scope.habitList.getByPosition(0).reminder!;
      expect(saved.hour, 8, reason: 'edit-habit.reminder-time#9');
      expect(saved.minute, 30, reason: 'edit-habit.reminder-time#9');
      expect(saved.days, WeekdayList(12), reason: 'edit-habit.reminder-time#9');

      // Clearing the time clears the whole reminder: there is no state in
      // which only the hour or only the days survive.
      final cleared = createModel(scope, habitId: scope.habitList
          .getByPosition(0)
          .id)
        ..clearReminder();
      expect(cleared.save(), isTrue);
      expect(scope.habitList.getByPosition(0).reminder, isNull,
          reason: 'edit-habit.reminder-time#9 — no partial state');
    });
  });

  group('edit-habit.instance-state', () {
    testWidgets('#3 the Target Type is NOT reset behind the user\'s back',
        (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope, habitType: HabitType.numerical);

      modelOf(tester).setTargetType(NumericalHabitType.atMost);
      await tester.pumpAndSettle();

      // The Android bundle never writes targetType, so a rotation silently
      // put the control back to AT_LEAST. The port keeps the value in the
      // model for the life of the route, which the ledger asks for
      // explicitly: "Reproduce it in the port only if bug-for-bug fidelity is
      // wanted; otherwise persist it."
      await tester.binding.setSurfaceSize(const Size(1400, 600));
      await tester.pumpAndSettle();
      addTearDown(() => tester.binding.setSurfaceSize(null));

      expect(modelOf(tester).targetType, NumericalHabitType.atMost,
          reason: 'edit-habit.instance-state#3 (deviation) — the upstream bug '
              'is deliberately not reproduced');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.targetTypePickerKey),
          matching: find.text('At most'),
        ),
        findsOneWidget,
        reason: 'edit-habit.instance-state#3 (deviation)',
      );
    });

    testWidgets('#4 the five text fields survive the same way', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope, habitType: HabitType.numerical);

      await tester.enterText(find.byKey(EditHabitScreen.nameFieldKey), 'Run');
      await tester.enterText(
        find.byKey(EditHabitScreen.questionFieldKey),
        'How far?',
      );
      await tester.enterText(
        find.byKey(EditHabitScreen.notesFieldKey),
        'morning loop',
      );
      await tester.enterText(find.byKey(EditHabitScreen.unitFieldKey), 'miles');
      await tester.enterText(find.byKey(EditHabitScreen.targetFieldKey), '15');

      await tester.binding.setSurfaceSize(const Size(1400, 600));
      await tester.pumpAndSettle();
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final model = modelOf(tester);
      // Upstream these five are not in the bundle at all; they survive only
      // because the platform saves EditText view state. Here they are fields
      // of the model, so they survive by construction.
      expect(model.nameController.text, 'Run',
          reason: 'edit-habit.instance-state#4');
      expect(model.questionController.text, 'How far?',
          reason: 'edit-habit.instance-state#4');
      expect(model.notesController.text, 'morning loop',
          reason: 'edit-habit.instance-state#4');
      expect(model.unitController.text, 'miles',
          reason: 'edit-habit.instance-state#4');
      expect(model.targetController.text, '15',
          reason: 'edit-habit.instance-state#4');
    });
  });

  group('edit-habit.window-insets-and-chrome', () {
    testWidgets('#1 #2 the Save button and the toolbar', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope);

      final save = tester.widget<OutlinedButton>(
        find.byKey(EditHabitScreen.saveButtonKey),
      );
      expect(save.style?.foregroundColor?.resolve(<WidgetState>{}),
          Colors.white,
          reason: 'edit-habit.window-insets-and-chrome#1 — white text');
      expect(save.style?.side?.resolve(<WidgetState>{})?.color, Colors.white,
          reason: 'edit-habit.window-insets-and-chrome#1 — white stroke');
      expect(
        find.descendant(
          of: find.byKey(EditHabitScreen.saveButtonKey),
          matching: find.text('SAVE'),
        ),
        findsOneWidget,
        reason: 'edit-habit.window-insets-and-chrome#1 — R.string.save, '
            'rendered upper-case by the Material outlined button style',
      );
      // Gravity end with a 16dp end margin.
      final bar = tester.getRect(find.byType(AppBar));
      final button = tester.getRect(find.byKey(EditHabitScreen.saveButtonKey));
      expect(bar.right - button.right, 16.0,
          reason: 'edit-habit.window-insets-and-chrome#1 — 16dp end margin');

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.elevation, 10.0,
          reason: 'edit-habit.window-insets-and-chrome#2 — '
              'supportActionBar.elevation = 10.0f');
      expect(find.byType(BackButton), findsOneWidget,
          reason: 'edit-habit.window-insets-and-chrome#2 — '
              'setDisplayHomeAsUpEnabled');
    });

    testWidgets('#3 #4 the form scrolls inside the safe area over a contrast0 '
        'background', (tester) async {
      final scope = openScope(dispatcher: const AsyncDispatcher());
      await pumpEditor(tester, scope);

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        toFlutterColor(LightTheme().appBackgroundColor),
        reason: 'edit-habit.window-insets-and-chrome#4 — the root and the '
            'ScrollView both take ?attr/contrast0',
      );
      final scroll = find.descendant(
        of: find.byType(Scaffold).last,
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget,
          reason: 'edit-habit.window-insets-and-chrome#4 — the form is inside '
              'a scroll view filling everything under the AppBar');
      expect(
        find.ancestor(of: scroll, matching: find.byType(SafeArea)),
        findsWidgets,
        reason: 'edit-habit.window-insets-and-chrome#3 — the bottom inset is '
            'applied so the last field is not covered by the navigation bar '
            '(Flutter SafeArea stands in for the manual inset plumbing)',
      );
    });

    test('#5 the form and box metrics', () {
      expect(EditHabitMetrics.formPadding.top, 8.0,
          reason: 'edit-habit.window-insets-and-chrome#5 — 8dp top padding');
      expect(EditHabitMetrics.formPadding.left, 4.0,
          reason: 'edit-habit.window-insets-and-chrome#5 — 4dp side padding');
      expect(EditHabitMetrics.formPadding.right, 4.0,
          reason: 'edit-habit.window-insets-and-chrome#5');
      expect(EditHabitMetrics.outerBoxPadding,
          const EdgeInsets.fromLTRB(4, 4, 4, 8),
          reason: 'edit-habit.window-insets-and-chrome#5 — @style/FormOuterBox '
              'is 4dp top, 8dp bottom, 4dp sides');
      expect(EditHabitMetrics.innerBoxRadius, 4.0,
          reason: 'edit-habit.window-insets-and-chrome#5 — a rounded outlined '
              'background');
      expect(EditHabitMetrics.innerBoxStrokeWidth, 1.0,
          reason: 'edit-habit.window-insets-and-chrome#5');
      expect(EditHabitMetrics.labelOffset, lessThan(0.0),
          reason: 'edit-habit.window-insets-and-chrome#5 — the floating label '
              'overlaps the top border (-15dp top margin upstream)');
    });
  });

  // =======================================================================
  // The colour the time picker is tinted with, and the tag it is shown under
  // =======================================================================

  group('edit-habit.color-control, the picker accent', () {
    /// The colour scheme the radial picker is themed with. Upstream that is
    /// the `accentColor` argument of `TimePickerDialog.newInstance(...)`.
    material.Color accentOf(WidgetTester tester) => material.Theme.of(
          tester.element(find.byType(TimePickerDialog)),
        ).colorScheme.primary;

    testWidgets('#5 androidColor is the accent handed to the time picker, so '
        'changing the colour changes the picker highlight', (tester) async {
      final theme = LightTheme();
      await pumpEditor(tester, openScope(dispatcher: const AsyncDispatcher()));

      // PaletteColor(11) is the screen's default.
      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();
      expect(accentOf(tester), toFlutterColor(theme.color(11)),
          reason: 'edit-habit.color-control#5 — the picker opens tinted with '
              'androidColor, not with the app accent');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Repaint the screen red and re-open the picker.
      await tester.tap(find.byKey(EditHabitScreen.colorButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('color_swatch_0')));
      await tester.pumpAndSettle();
      expect(modelOf(tester).color, const PaletteColor(0),
          reason: 'edit-habit.color-control#5');

      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();
      expect(accentOf(tester), toFlutterColor(theme.color(0)),
          reason: 'edit-habit.color-control#5 — changing the colour changes '
              "the time picker's highlight colour");
      expect(accentOf(tester), isNot(toFlutterColor(theme.color(11))),
          reason: 'edit-habit.color-control#5');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('#5 the dark theme resolves androidColor through its own '
        'palette', (tester) async {
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        dark: true,
      );

      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();
      expect(accentOf(tester), toFlutterColor(DarkTheme().color(11)),
          reason: 'edit-habit.color-control#5 — androidColor is '
              'themeSwitcher.currentTheme.color(color), so a night theme tints '
              'the picker with the dark palette entry');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('edit-habit.reminder-time, the tag', () {
    testWidgets('#7 the time picker route carries the "timePicker" tag',
        (tester) async {
      final names = <String?>[];
      await pumpEditor(
        tester,
        openScope(dispatcher: const AsyncDispatcher()),
        observers: <NavigatorObserver>[_RouteNameObserver(names)],
      );

      expect(EditHabitScreen.timePickerTag, 'timePicker',
          reason: 'edit-habit.reminder-time#7');
      expect(names, isNot(contains('timePicker')),
          reason: 'edit-habit.reminder-time#7 — nothing is shown until the '
              'control is tapped');

      await tester.tap(find.byKey(EditHabitScreen.reminderTimePickerKey));
      await tester.pumpAndSettle();

      expect(names, contains('timePicker'),
          reason: 'edit-habit.reminder-time#7 — the dialog is shown with tag '
              '"timePicker", reused here as the route name');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  // =======================================================================
  // habit-type-dialog.select-type: the window it is shown in and its metrics
  // =======================================================================

  group('habit-type-dialog.select-type, revisited', () {
    /// Opens the chooser the way `ListHabitsMenuBehavior.onCreateHabit` does,
    /// but from a bare host so the chooser is the only thing on screen.
    Future<void> pumpChooser(
      WidgetTester tester,
      AppScope scope, {
      ThemeData? themeData,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<int>(nextTree++),
          theme: themeData,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: Builder(
              builder: (context) => Scaffold(
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

    /// The `Material` the dialog paints its own scrim with.
    Finder scrim() => find
        .descendant(
          of: find.byType(HabitTypeDialog),
          matching: find.byType(Material),
        )
        .first;

    testWidgets('#2 the Translucent theme: no title, a transparent window and '
        'fade animations', (tester) async {
      await pumpChooser(tester, openScope(dispatcher: const AsyncDispatcher()));

      // `@style/Theme.Translucent` sets windowNoTitle, so there is no dialog
      // chrome of any kind between the window and the two cards.
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'habit-type-dialog.select-type#2 — windowNoTitle');
      expect(find.byType(AppBar), findsNothing,
          reason: 'habit-type-dialog.select-type#2 — windowNoTitle');

      // windowBackground = @android:color/transparent: the only colour the
      // window carries is the scrim the layout paints itself, so the route
      // must not add a barrier colour of its own.
      final route = ModalRoute.of(tester.element(find.byType(HabitTypeDialog)));
      expect(route?.barrierColor, const material.Color(0x00000000),
          reason: 'habit-type-dialog.select-type#2 — a transparent window '
              'background, the scrim belongs to the layout');

      // windowAnimationStyle = fade in / fade out.
      expect(
        find.ancestor(
          of: find.byType(HabitTypeDialog),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
        reason: 'habit-type-dialog.select-type#2 — fade-in/fade-out window '
            'animations',
      );
    });

    testWidgets('#2 #3 a full-screen, vertically centred column over the '
        '#a0000000 scrim', (tester) async {
      await pumpChooser(tester, openScope(dispatcher: const AsyncDispatcher()));

      expect(HabitTypeDialog.scrimColor, const material.Color(0xA0000000),
          reason: 'habit-type-dialog.select-type#3 — @color/translucent_black, '
              'black at 62.7% alpha');
      expect(tester.widget<Material>(scrim()).color, HabitTypeDialog.scrimColor,
          reason: 'habit-type-dialog.select-type#3');

      // Full screen, status bar included — the translucent status bar of the
      // Translucent theme is what lets the scrim reach the top edge.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getRect(scrim()), Offset.zero & screen,
          reason: 'habit-type-dialog.select-type#3 — the dialog is '
              'full-screen; #2 — under a translucent status bar');

      // The two cards are one vertically centred column.
      final first = tester.getRect(find.byKey(EditHabitScreen.yesNoTypeCardKey));
      final last =
          tester.getRect(find.byKey(EditHabitScreen.measurableTypeCardKey));
      expect(last.top, greaterThan(first.top),
          reason: 'habit-type-dialog.select-type#3 — a column, in order');
      expect(
        (first.top + last.bottom) / 2,
        moreOrLessEquals(screen.height / 2, epsilon: 0.5),
        reason: 'habit-type-dialog.select-type#3 — vertically centred',
      );
    });

    testWidgets('#8 20sp bold titles, 1.25-spaced bodies and 6dp cards',
        (tester) async {
      await pumpChooser(tester, openScope(dispatcher: const AsyncDispatcher()));

      final title = tester.widget<Text>(find.text('Yes or No'));
      expect(title.style?.fontSize, 20.0,
          reason: 'habit-type-dialog.select-type#8 — 20sp titles');
      expect(title.style?.fontWeight, FontWeight.bold,
          reason: 'habit-type-dialog.select-type#8 — bold titles');

      final body = tester.widget<Text>(
        find.text(
          'e.g. Did you wake up early today? Did you exercise? '
          'Did you play chess?',
        ),
      );
      expect(body.style?.fontSize, HabitTypeDialog.bodyTextSize,
          reason: 'habit-type-dialog.select-type#8 — the small text size');
      expect(body.style?.height, 1.25,
          reason: 'habit-type-dialog.select-type#8 — lineSpacingMultiplier');
      expect(body.style?.fontSize, lessThan(title.style!.fontSize!),
          reason: 'habit-type-dialog.select-type#8');

      // 8dp between the title and the body it introduces.
      expect(
        tester.getRect(find.text(
          'e.g. Did you wake up early today? Did you exercise? '
          'Did you play chess?',
        )).top -
            tester.getRect(find.text('Yes or No')).bottom,
        8.0,
        reason: 'habit-type-dialog.select-type#8 — 8dp bottom margin on the '
            'title',
      );

      // 6dp of elevation and a rounded ripple background.
      final card = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(EditHabitScreen.yesNoTypeCardKey),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.elevation, 6.0,
          reason: 'habit-type-dialog.select-type#8 — 6dp elevation');
      // `@drawable/round_ripple` is a rectangle with `<corners
      // android:radius="5dp"/>`, so "rounded" has a value.
      expect(
        card.shape,
        isA<RoundedRectangleBorder>().having(
          (s) => s.borderRadius,
          'borderRadius',
          BorderRadius.circular(5),
        ),
        reason: 'habit-type-dialog.select-type#8 — a rounded background',
      );
      final ink = tester.widget<InkWell>(
        find
            .descendant(
              of: find.byKey(EditHabitScreen.yesNoTypeCardKey),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(ink.borderRadius, BorderRadius.circular(5),
          reason: 'habit-type-dialog.select-type#8 — the ripple is clipped to '
              'the same rounded background');
    });

    testWidgets(
        'audit15.habit-type-cards-lose-their-2dp-outline#1: the cards are '
        'cardBgColor behind a 2dp textColor stroke', (tester) async {
      const rule = 'audit15.habit-type-cards-lose-their-2dp-outline#1';

      Future<void> check(core.Theme theme) async {
        await pumpChooser(
          tester,
          openScope(dispatcher: const AsyncDispatcher()),
          themeData: appThemeData(theme),
        );

        for (final key in <Key>[
          EditHabitScreen.yesNoTypeCardKey,
          EditHabitScreen.measurableTypeCardKey,
        ]) {
          final card = tester.widget<Material>(
            find
                .descendant(of: find.byKey(key), matching: find.byType(Material))
                .first,
          );
          expect(
            card.color,
            toFlutterColor(theme.cardBgColor),
            reason: '$rule — `<solid android:color="?cardBgColor"/>`, not the '
                'window background',
          );
          expect(
            card.shape,
            isA<RoundedRectangleBorder>()
                .having((s) => s.side.width, 'side.width', 2.0)
                .having(
                  (s) => s.side.color,
                  'side.color',
                  toFlutterColor(theme.contrast100),
                )
                .having(
                  (s) => s.borderRadius,
                  'borderRadius',
                  BorderRadius.circular(5),
                ),
            reason: '$rule — `<stroke android:width="2dp" '
                'android:color="?android:textColor"/>` and `<corners '
                'android:radius="5dp"/>`',
          );

          final ink = tester.widget<InkWell>(
            find
                .descendant(of: find.byKey(key), matching: find.byType(InkWell))
                .first,
          );
          expect(
            ink.splashColor,
            toFlutterColor(theme.aboutScreenColor),
            reason: '$rule — `<ripple android:color="?colorAccent">`, and '
                'colorAccent is ?aboutScreenColor',
          );
        }
      }

      // Pure black is where the loss is total: a #000000 card with no stroke
      // over a #a0000000 scrim is invisible.
      await check(PureBlackTheme());
      await check(DarkTheme());
      await check(LightTheme());
    });
  });
}

/// Records the name of every route that is pushed, so a test can assert the
/// fragment tag a dialog is shown under.
class _RouteNameObserver extends NavigatorObserver {
  _RouteNameObserver(this.names);

  final List<String?> names;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }
}
