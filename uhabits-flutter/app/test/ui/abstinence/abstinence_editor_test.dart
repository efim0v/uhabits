/// Заведение привычки-воздержания: модель формы.
///
/// Арифметика вида живёт в ядре. Здесь проверяется ровно то, что делает
/// редактор: какой вид он несёт, какие поля предлагает и что кладёт в базу,
/// когда человек нажимает «Сохранить».
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    // `AppScope.open` stamps today itself, from the wall clock rather than
    // from `setToday` — so the clock is what has to be pinned. Without this
    // the form's default commitment day is the day the suite happens to run.
    systemCurrentTimeMillis = () => (9000 + 10957) * 86400000 + 12 * 3600000;
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
    DateUtils.setFixedTimeZone(null);
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    resetToday();
  });

  test('the chooser carries a kind, not a sleep flag', () {
    final EditHabitModel abstinence =
        EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
    expect(abstinence.computedKind, ComputedKind.abstinence,
        reason: 'computed.create#2 — the editor is opened with a kind, and a '
            'boolean cannot name the second one');
    expect(abstinence.isAbstinence, isTrue, reason: 'computed.create#2');
    expect(abstinence.isSleep, isFalse,
        reason: 'computed.create#2 — the two kinds are not each other');
    expect(abstinence.isComputed, isTrue, reason: 'computed.create#2');

    final EditHabitModel sleep =
        EditHabitModel(scope: scope, computed: ComputedKind.sleep);
    expect(sleep.isSleep, isTrue,
        reason: 'computed.create#2 — the sleep path is the same path');
    expect(sleep.isAbstinence, isFalse, reason: 'computed.create#2');

    final EditHabitModel plain = EditHabitModel(scope: scope);
    expect(plain.computedKind, isNull, reason: 'computed.create#2');
    expect(plain.isComputed, isFalse, reason: 'computed.create#2');
  });

  group('defaults', () {
    test('a new abstinence habit can be saved with nothing but a name', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';

      expect(model.save(), isTrue,
          reason: 'computed.create#5 — every field of this form has a default, '
              'so a person who commits and types a name is done');
      expect(model.targetError, isNull, reason: 'computed.create#5');
      expect(model.allowanceError, isNull, reason: 'computed.create#5');
      expect(scope.habitList.size(), 1, reason: 'computed.create#5');
    });

    test('the allowance starts at zero: one tap is a slip', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      expect(model.targetController.text, '0',
          reason: 'computed.create#5 — the default is "any slip counts", and '
              'it is on screen rather than implied');
    });

    test('the commitment day starts today and cannot be moved forward', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      expect(model.committedFrom, 9000, reason: 'computed.create#8');

      model.setCommittedFrom(8960);
      expect(model.committedFrom, 8960,
          reason: 'computed.create#8 — backwards is the whole point: forty '
              'clean days before the first slip have to exist');

      model.setCommittedFrom(9001);
      expect(model.committedFrom, 9000,
          reason: 'computed.create#8 — a habit committed to tomorrow would '
              'score days nobody has lived');
    });
  });

  group('the habit an abstinence habit is stored as', () {
    test('at-most, daily, target equal to the allowance', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'Screen time';
      model.targetController.text = '30';
      model.unitController.text = 'minutes';
      expect(model.save(), isTrue, reason: 'computed.create#6');

      final Habit habit = scope.habitList.getByPosition(0);
      expect(habit.type, HabitType.numerical, reason: 'computed.create#6');
      expect(habit.targetType, NumericalHabitType.atMost,
          reason: 'computed.create#6 — "no more than the allowance" is what '
              'at-most already means, and its score starts at 1.0');
      expect(habit.targetValue, 30.0,
          reason: 'computed.create#6 — a slip starts past the allowance, so '
              'the allowance is the target');
      expect(habit.unit, 'minutes', reason: 'computed.create#6');
      expect(habit.frequency.numerator, 1, reason: 'computed.create#6');
      expect(habit.frequency.denominator, 1,
          reason: 'computed.create#6 — the frequency is pinned: it sets the '
              'decay through sqrt(frequency), the width of the rolling window '
              'and the list cell threshold all at once');
    });

    test('the frequency is pinned, not merely left at its default', () {
      // The two assertions above are both satisfied by the form's own
      // defaults — `freqNum` and `freqDen` start at 1 — so on their own they
      // cannot tell a pinned frequency from an unpinned one. This one can:
      // it hands the model a frequency first, the way the EDIT branch does
      // when it seeds `freqNum`/`freqDen` from a habit that arrived at 3/7
      // from a restored file, and then asks what was saved.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      model.setFrequency(3, 7);
      expect(model.save(), isTrue, reason: 'computed.create#6');

      final Habit habit = scope.habitList.getByPosition(0);
      expect(habit.frequency.numerator, 1,
          reason: 'computed.create#6 — nothing the form was carrying survives '
              'into the frequency of an abstinence habit');
      expect(habit.frequency.denominator, 1,
          reason: 'computed.create#6 — the halving in `ScoreList` is guarded '
              'by `denominator == 1`, so a weekly abstinence habit is safe '
              'rather than right: it silently falls back to the port\'s decay');
    });

    test('re-saving a habit stored weekly pins it back to daily', () {
      // The whole EDIT path, on the shape a restored backup can produce: the
      // frequency is a column of the file and nothing on the way in re-pins
      // it. Opening the form and pressing Save has to.
      final EditHabitModel create =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      create.nameController.text = 'No alcohol';
      create.targetController.text = '30';
      create.unitController.text = 'minutes';
      expect(create.save(), isTrue, reason: 'computed.create#6');

      final Habit stored = scope.habitList.getByPosition(0);
      stored.frequency = Frequency(1, 7);
      scope.definitions.save(
        stored.id!,
        const HabitDefinition(
          kind: ComputedKind.abstinence,
          committedFrom: 8960,
        ),
      );

      final EditHabitModel edit =
          EditHabitModel(scope: scope, habitId: stored.id);
      expect(edit.isAbstinence, isTrue,
          reason: 'computed.create#10 — the kind of an existing habit is read '
              'from its definition row');
      expect(edit.committedFrom, 8960,
          reason: 'computed.create#8 — and so is the day it was committed');
      expect(edit.freqDen, 7,
          reason: 'computed.create#6 — the form really did load the weekly '
              'frequency, so the assertion below is about the save');
      expect(edit.save(), isTrue, reason: 'computed.create#6');

      expect(scope.habitList.getById(stored.id!)!.frequency.denominator, 1,
          reason: 'computed.create#6 — a save of an abstinence habit leaves it '
              'scored daily whatever the file held');
    });

    test('the allowance comes back as a count, not as "30.0"', () {
      final EditHabitModel create =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      create.nameController.text = 'Screen time';
      create.targetController.text = '30';
      create.unitController.text = 'minutes';
      expect(create.save(), isTrue, reason: 'computed.create#6');

      final Habit stored = scope.habitList.getByPosition(0);
      scope.definitions.save(
        stored.id!,
        const HabitDefinition(
          kind: ComputedKind.abstinence,
          committedFrom: 8960,
        ),
      );

      final EditHabitModel edit =
          EditHabitModel(scope: scope, habitId: stored.id);
      expect(edit.targetController.text, '30',
          reason: 'computed.create#6 — an allowance is a count of minutes or '
              'of drinks, and "30.0 minutes" is not how anyone writes one '
              'down');
    });

    test('a blank allowance is zero; a word where a number belongs refuses',
        () {
      final EditHabitModel blank =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      blank.nameController.text = 'No alcohol';
      blank.targetController.text = '';
      // `returnsNormally`, not just `isTrue`: the ported numerical branch
      // reads this same box with `double.parse`, which throws a
      // FormatException on an empty string. Keeping an abstinence form out of
      // that branch is what lets the save button return at all.
      expect(blank.save, returnsNormally, reason: 'computed.create#11');
      expect(scope.habitList.size(), 1,
          reason: 'computed.create#11 — and it saved, rather than refusing a '
              'box the form asked nothing about');
      expect(scope.habitList.getByPosition(0).targetValue, 0.0,
          reason: 'computed.create#11 — an emptied allowance means none');

      final EditHabitModel wrong =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      wrong.nameController.text = 'No doomscrolling';
      wrong.targetController.text = 'lots';
      expect(wrong.save(), isFalse, reason: 'computed.create#11');
      expect(wrong.allowanceError, EditHabitFieldError.notANumber,
          reason: 'computed.create#11 — the error lands on the allowance, not '
              'on the target field the form never showed');
      expect(wrong.targetError, isNull,
          reason: 'computed.create#11 — and the box that is not on screen '
              'carries no error to draw');
      expect(scope.habitList.size(), 1,
          reason: 'computed.create#11 — and nothing was created');
    });
  });
}
