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

  final TimeZone Function() realZone = getDefaultTimeZone;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    // `computeToday` reads the top-level `getDefaultTimeZone`, not
    // `DateUtils.fixedTimeZone`, so pinning the clock is not enough on its
    // own: under a machine set to UTC+14 the stamped today is 9001 and every
    // commitment day here is off by one.
    getDefaultTimeZone = () => const FixedTimeZone(0);
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
    getDefaultTimeZone = realZone;
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

    test('nor back onto the epoch, which the storage refuses', () {
      // The other end of the same clamp. Day 0 is not a day anybody chose —
      // it is what an unfilled integer looks like — so
      // `DefinitionRepository.save` throws on one, from inside a command
      // listener, where the habit has already been created and the listeners
      // queued behind this one never run. The picker's floor keeps a person
      // away from it; this keeps the model away from it, which is where the
      // value is decided.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      model.setCommittedFrom(0);
      expect(model.committedFrom, EditHabitModel.commitmentFloorDay,
          reason: 'computed.commitment#6 — nobody commits on a day at or '
              'before the epoch, and the model must not be able to make the '
              'mistake the repository throws on');

      expect(model.save(), isTrue, reason: 'computed.commitment#6');
      expect(
          scope.definitions
              .forHabit(scope.habitList.getByPosition(0).id!)
              ?.committedFrom,
          EditHabitModel.commitmentFloorDay,
          reason: 'computed.commitment#6 — and the row is written rather than '
              'lost with the throw');
    });
  });

  group('the moment of commitment', () {
    test('the commitment day equal to today records the moment', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      expect(model.save(), isTrue, reason: 'computed.commitment#8');

      final HabitDefinition definition = scope.definitions
          .forHabit(scope.habitList.getByPosition(0).id!)!;
      expect(definition.committedFrom, 9000, reason: 'computed.create#8');
      expect(definition.committedAtMillis,
          (9000 + 10957) * 86400000 + 12 * 3600000,
          reason: 'computed.commitment#8 — день обязательства равен '
              'сегодняшнему, и момент есть те самые часы, из которых ядро '
              'выводит само «сегодня» (`systemCurrentTimeMillis`, прибитые в '
              'setUp вместе с ним)');
    });

    test('a backdated commitment at creation gets no moment', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No spending';
      model.setCommittedFrom(8960);
      expect(model.save(), isTrue, reason: 'computed.commitment#8');

      final HabitDefinition definition = scope.definitions
          .forHabit(scope.habitList.getByPosition(0).id!)!;
      expect(definition.committedAtMillis, isNull,
          reason: 'computed.commitment#8 — «я держусь с прошлого '
              'понедельника»: «сейчас» не было бы правдой о прошлом '
              'понедельнике, и момент остаётся пустым, а счётчик честно '
              'считает от полуночи того дня (`computed.since#3`)');
    });

    test('moving the commitment day backward erases the moment', () {
      // Обязательство дано сегодня — момент записан. Человек передумывает и
      // переносит день назад, к прошлому месяцу: прежний момент, записанный
      // под сегодняшним числом, перестаёт относиться к своему дню и обязан
      // исчезнуть — иначе счётчик прочитает месячную привычку как начатую
      // только что.
      final EditHabitModel create =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      create.nameController.text = 'No alcohol';
      expect(create.save(), isTrue, reason: 'computed.commitment#8');

      final int id = scope.habitList.getByPosition(0).id!;
      expect(scope.definitions.forHabit(id)!.committedAtMillis, isNotNull,
          reason: 'sanity — сегодняшнее обязательство получило момент, '
              'иначе следующая проверка не отличила бы стирание от того, что '
              'стирать было нечего');

      final EditHabitModel edit = EditHabitModel(scope: scope, habitId: id);
      edit.setCommittedFrom(8960);
      expect(edit.save(), isTrue, reason: 'computed.commitment#9');

      final HabitDefinition after = scope.definitions.forHabit(id)!;
      expect(after.committedFrom, 8960, reason: 'computed.commitment#9');
      expect(after.committedAtMillis, isNull,
          reason: 'computed.commitment#9 — перенесённый назад день '
              'обязательства не вправе унести с собой момент, записанный для '
              'другого дня: иначе счётчик показал бы «0 минут» привычке, '
              'которой на самом деле месяц');
    });

    test('editing something unrelated leaves an existing moment alone', () {
      // Обязательство дано позавчера, и момент уже лежит в строке — так, как
      // он лежал бы у привычки, пережившей хотя бы одно сохранение в день
      // своего обязательства. День с тех пор никто не трогал; строка
      // подставлена напрямую, а не через второй `save()`, чтобы момент был
      // ровно тем, что заведомо не совпадает с сегодняшним числом из setUp.
      final EditHabitModel create =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      create.nameController.text = 'No alcohol';
      expect(create.save(), isTrue, reason: 'computed.commitment#8');

      final int id = scope.habitList.getByPosition(0).id!;
      const int at = (8999 + 10957) * 86400000 + 12 * 3600000;
      scope.definitions.save(
        id,
        HabitDefinition(
          kind: ComputedKind.abstinence,
          committedFrom: 8999,
          committedAtMillis: at,
        ),
      );

      final EditHabitModel edit = EditHabitModel(scope: scope, habitId: id);
      expect(edit.committedFrom, 8999,
          reason: 'computed.commitment#9 — день читается из строки, а не из '
              '«сегодня»');
      edit.nameController.text = 'опечатку поправили';
      expect(edit.save(), isTrue, reason: 'computed.commitment#9');

      expect(scope.definitions.forHabit(id)!.committedAtMillis, at,
          reason: 'computed.commitment#9 — день обязательства не менялся, и '
              'посторонняя правка — здесь имя — не вправе стереть момент: '
              'иначе он терялся бы на первом же сохранении после дня, когда '
              'обязательство дано, а таких сохранений почти все');
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

    test('a pasted "Infinity" leaves no half a habit behind', () {
      // Ревью нашло: `double.tryParse` берёт «Infinity», «-Infinity», «NaN» и
      // «1e400», `validate()` их пропускала, а падало уже **после**
      // `CreateHabitCommand` — `HabitDefinition.encodedPayload` бросал
      // `JsonUnsupportedObjectError` из слушателя команды. Привычка
      // оставалась в базе с `targetValue = Infinity` и без строки
      // определения: заведена как воздержание и не воздержание. С клавиатуры
      // такого не набрать, а вставкой из буфера — можно, той же дверью, что
      // и минус (`computed.allowance#4`).
      for (final String written in <String>[
        'Infinity',
        '-Infinity',
        'NaN',
        '1e400',
      ]) {
        final EditHabitModel model =
            EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
        model.nameController.text = 'No $written';
        model.targetController.text = written;

        expect(model.save(), isFalse,
            reason: 'computed.create#11 — «$written» не число');
        expect(model.allowanceError, EditHabitFieldError.notANumber,
            reason: 'computed.create#11 — отказ рисуется в том поле, куда это '
                'вставили, а не в цели, которой форма не показывала');
        expect(scope.habitList.size(), 0,
            reason: 'computed.create#11 — «$written»: половины привычки не '
                'осталось');
      }
    });

    test('a pasted negative allowance is stored as none, on both sides', () {
      // The keyboard offers no minus sign; the clipboard does. Read back,
      // `abstinenceAllowanceOf` pulls a negative payload up to zero
      // (`computed.allowance#4`) — but `targetValue` was stored as written,
      // and the score compares `normalizedRollingSum > targetValue`. A silent
      // day contributes `max(0, -1) == 0`, and `0 > -5` is true, so every
      // single kept day halved the score while the cell, the counter and the
      // caption all swore there had been no lapse at all.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No spending';
      model.targetController.text = '-5';
      expect(model.save(), isTrue, reason: 'computed.allowance#1');

      final Habit habit = scope.habitList.getByPosition(0);
      expect(habit.targetValue, 0.0,
          reason: 'computed.allowance#1 — the judge the score uses');
      expect(
          abstinenceAllowanceOf(scope.definitions.forHabit(habit.id!)!), 0.0,
          reason: 'computed.allowance#1 — and the judge the interface uses; '
              'one parse makes them the same number by construction');

      // And the ring stays up: the silent day under this commitment is a day
      // kept, not a day of invisible lapse.
      attachDefinition(habit, scope.definitions);
      habit.recompute();
      expect(habit.scores[getToday()].value, closeTo(0.022840, 1e-6),
          reason: 'computed.allowance#1 — silence is success, and a number '
              'nobody can enter must not turn it into failure. The commitment '
              'day defaults to today, so today is the whole window, and one '
              'kept day earns exactly one step of the abstinence curve, '
              '1 - 0.5^(1/30). A day counted as a lapse would read 0.0');
    });
  });

  group('changing the allowance', () {
    test('re-judges the days already recorded', () {
      // The day's stored value does not move — the amount is the amount — but
      // whether that amount counts as a slip does, and that is the score.
      // Nothing else on this path does it: the sweep writes amounts and stops,
      // and a lapse row carries no allowance of its own.
      final EditHabitModel create =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      create.nameController.text = 'Screen time';
      create.targetController.text = '30';
      create.unitController.text = 'minutes';
      expect(create.save(), isTrue, reason: 'computed.allowance#1');

      final Habit habit = scope.habitList.getByPosition(0);
      const HabitDefinition definition = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8990,
      );
      scope.definitions.save(habit.id!, definition);
      attachDefinition(habit, scope.definitions);
      // Twenty minutes on one day. Under a thirty-minute allowance that is
      // not a slip at all.
      scope.lapses.save(habit.id!, 8995, amount: 20);
      scope.abstinence.recomputeAll(habit, definition);
      final double lenient = habit.scores[LocalDate(9000)].value;
      expect(lenient, closeTo(0.224428, 1e-6),
          reason: 'computed.allowance#1 — pinned, so that the comparison '
              'below cannot be two degenerate zeroes agreeing with each '
              'other: a twenty-minute day under a thirty-minute allowance is '
              'a kept promise, and eleven kept days — 8990, the commitment '
              'day, through 9000 — earn eleven steps of the abstinence '
              'curve, 1 - 0.5^(11/30)');

      final EditHabitModel edit =
          EditHabitModel(scope: scope, habitId: habit.id);
      expect(edit.targetController.text, '30',
          reason: 'computed.allowance#1 — the form opens on the allowance the '
              'habit is being kept at');
      edit.targetController.text = '10';
      expect(edit.save(), isTrue, reason: 'computed.allowance#1');

      final Habit saved = scope.habitList.getById(habit.id!)!;
      expect(saved.originalEntries.get(LocalDate(8995)).value, 20000,
          reason: 'computed.allowance#1 — the day itself is untouched: twenty '
              'minutes happened and no edit to the promise unhappens them');
      expect(saved.scores[LocalDate(9000)].value, lessThan(lenient),
          reason: 'computed.allowance#1 — but twenty minutes is now over the '
              'promise, so the day is a slip and the score says so. Left '
              'unrecomputed the history would be judged by a commitment '
              'nobody is keeping any more');
    });

    test('the row moves with the target it mirrors', () {
      // The other half of the same edit, and the half no other test here can
      // see: every one of them creates a habit, and the payload of a habit
      // that has just been created cannot disagree with its target yet. Two
      // copies of one number drift apart silently — `EditHabitCommand` moves
      // `targetValue` and never touches the payload — so the write that keeps
      // them together is asserted on the path that could break it. What breaks
      // when they drift is not pedantry: the score judges by `targetValue`
      // and the list cell by the payload, so the ring would call a day a slip
      // with no cross drawn on it.
      final EditHabitModel create =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      create.nameController.text = 'Screen time';
      create.targetController.text = '30';
      create.unitController.text = 'minutes';
      create.setCommittedFrom(8990);
      expect(create.save(), isTrue, reason: 'computed.allowance#1');

      final Habit habit = scope.habitList.getByPosition(0);
      final EditHabitModel edit =
          EditHabitModel(scope: scope, habitId: habit.id);
      edit.targetController.text = '10';
      expect(edit.save(), isTrue, reason: 'computed.allowance#1');

      final Habit saved = scope.habitList.getById(habit.id!)!;
      final HabitDefinition definition =
          scope.definitions.forHabit(habit.id!)!;
      expect(saved.targetValue, 10.0, reason: 'computed.allowance#1');
      expect(abstinenceAllowanceOf(definition), saved.targetValue,
          reason: 'computed.allowance#1 — one save puts down both: a row left '
              'at the old allowance would hand the form back thirty and give '
              'the cell its own idea of where a slip begins');
      expect(abstinenceAllowanceOf(definition), 10.0,
          reason: 'computed.allowance#1 — and it is the new number, not the '
              'old one they both happen to agree on');
      final HabitDefinition? live = saved.definition;
      expect(live, isNotNull,
          reason: 'computed.commitment#7 — the definition lives on the habit '
              'itself and not only in the database, and it gets there on the '
              'save rather than on the next app start: a recompute reads the '
              'field');
      expect(abstinenceAllowanceOf(live!), 10.0,
          reason: 'computed.allowance#1 — and the live habit carries the new '
              'number too: until the app is restarted everything reads it '
              'from here');
      expect(definition.committedFrom, 8990,
          reason: 'computed.create#8 — editing the allowance is not a new '
              'commitment: a day quietly moved to today would wipe out every '
              'clean day the person had accumulated, which is the count the '
              'whole thing exists for');
    });
  });

  group('the definition row', () {
    test('is written with the day and the allowance', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'Screen time';
      model.targetController.text = '30';
      model.unitController.text = 'minutes';
      model.setCommittedFrom(8960);
      expect(model.save(), isTrue, reason: 'computed.create#7');

      final Habit habit = scope.habitList.getByPosition(0);
      final HabitDefinition? definition = scope.definitions.forHabit(habit.id!);
      expect(definition, isNotNull, reason: 'computed.create#7');
      expect(definition!.kind, ComputedKind.abstinence,
          reason: 'computed.create#7 — the row is what makes a habit '
              'computed; without it nothing outside the app is kept away '
              'from its days');
      expect(definition.committedFrom, 8960,
          reason: 'computed.create#7 — the recompute range starts here, not '
              'at the oldest entry: there is no oldest entry while the habit '
              'is being kept');
      expect(abstinenceAllowanceOf(definition), 30.0,
          reason: 'computed.create#7');
      expect(abstinenceUnitOf(definition), 'minutes',
          reason: 'computed.create#7');
      expect(scope.definitions.isComputed(habit.id!), isTrue,
          reason: 'computed.create#7');
      // A real citation of `computed.write-paths#5`: the type here is not one
      // a test set on the habit, it is the one the editor created it with. The
      // unguarded yes/no toggle lives under `!habit.isNumerical`, and the
      // reason it cannot reach an abstinence habit is exactly that this line
      // is green.
      expect(habit.type, HabitType.numerical,
          reason: 'computed.write-paths#5 — a computed habit is numerical by '
              'construction, and there is nothing that could toggle it');
      expect(habit.targetType, NumericalHabitType.atMost,
          reason: 'computed.create#7 — "no more than the allowance"');
    });

    test('the allowance in the row and the target on the habit are one number',
        () {
      // Две копии одного числа разъезжаются молча: `EditHabitCommand` может
      // изменить `targetValue`, не тронув payload. Их пишет один save, и это
      // проверяется, а не подразумевается.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'Screen time';
      model.targetController.text = '30';
      model.setCommittedFrom(8960);
      model.save();

      final Habit habit = scope.habitList.getByPosition(0);
      expect(abstinenceAllowanceOf(scope.definitions.forHabit(habit.id!)!),
          habit.targetValue,
          reason: 'computed.allowance#1 — допуск назван один раз, иначе '
              'вчерашний день судится вчерашним правилом');
    });

    test('the default habit gets a row too, with today and no allowance', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      model.save();

      final HabitDefinition definition =
          scope.definitions.forHabit(scope.habitList.getByPosition(0).id!)!;
      expect(definition.committedFrom, 9000, reason: 'computed.create#8');
      expect(abstinenceAllowanceOf(definition), 0.0,
          reason: 'computed.create#5 — zero allowance means one tap is a slip');
      expect(definition.payload['unit'], abstinenceUnitCount,
          reason: 'computed.create#5 — the unit is named once, and an empty '
              'string never travels to the database (`computed.allowance#2`)');
    });

    test('an ordinary habit gets no row on this path', () {
      final EditHabitModel model =
          EditHabitModel(scope: scope, habitType: HabitType.numerical);
      model.nameController.text = 'Pages';
      model.unitController.text = 'pages';
      model.targetController.text = '30';
      model.save();

      expect(scope.definitions.forHabit(scope.habitList.getByPosition(0).id!),
          isNull,
          reason: 'computed.create#10 — an ordinary habit is not made '
              'computed by any path of this editor');
    });
  });

  group('on a device, not in a harness', () {
    /// A scope on the dispatchers production uses: a command handed to the
    /// real task runner has NOT run when `save()` returns.
    AppScope asyncScope() {
      final AppScope s = AppScope.open(database);
      addTearDown(s.close);
      return s;
    }

    test('the definition is stored even though the command has not run yet',
        () async {
      final AppScope real = asyncScope();
      final EditHabitModel model =
          EditHabitModel(scope: real, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      expect(model.save(), isTrue, reason: 'computed.create#9');

      await pumpEventQueue(times: 20);

      expect(real.habitList.size(), 1, reason: 'computed.create#9');
      final Habit habit = real.habitList.getByPosition(0);
      expect(real.definitions.forHabit(habit.id!)?.kind,
          ComputedKind.abstinence,
          reason: 'computed.create#9 — reading the command\'s result on the '
              'next line works in every test and silently does nothing on a '
              'phone');
    });
  });

  group('opening one that already exists', () {
    /// Creates an abstinence habit the way the editor does, and hands back its
    /// id.
    int makeOne({required String allowance, required int committedFrom}) {
      final EditHabitModel making =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      making.nameController.text = 'Screen time';
      making.targetController.text = allowance;
      making.unitController.text = 'minutes';
      making.setCommittedFrom(committedFrom);
      making.save();
      return scope.habitList.getByPosition(0).id!;
    }

    test('the kind comes from the definition row, not from a flag', () {
      final int id = makeOne(allowance: '30', committedFrom: 8960);

      final EditHabitModel editing = EditHabitModel(scope: scope, habitId: id);
      expect(editing.computedKind, ComputedKind.abstinence,
          reason: 'computed.create#10 — EDIT mode is never told the kind; the '
              'row is the only thing that knows');
      expect(editing.isAbstinence, isTrue, reason: 'computed.create#10');
      expect(editing.committedFrom, 8960, reason: 'computed.create#10');
      expect(editing.targetController.text, '30',
          reason: 'computed.create#10 — "30", not "30.0": an allowance is a '
              'count of minutes and that is how it was typed in');
      expect(editing.unitController.text, 'minutes',
          reason: 'computed.create#10');
    });

    test('changing the allowance updates the row instead of adding one', () {
      final int id = makeOne(allowance: '30', committedFrom: 8960);

      final EditHabitModel editing = EditHabitModel(scope: scope, habitId: id);
      editing.targetController.text = '10';
      editing.setCommittedFrom(8950);
      expect(editing.save(), isTrue, reason: 'computed.create#10');

      final HabitDefinition definition = scope.definitions.forHabit(id)!;
      expect(definition.kind, ComputedKind.abstinence,
          reason: 'computed.create#10 — the kind does not move');
      expect((definition.payload['allowance'] as num).toDouble(), 10.0,
          reason: 'computed.create#10');
      expect(definition.committedFrom, 8950, reason: 'computed.create#10');
      expect(scope.habitList.getById(id)!.targetValue, 10.0,
          reason: 'computed.create#6 — the habit and the row are written by '
              'the same save, so they cannot drift apart');
    });

    test('the habit is computing from the moment it is saved', () {
      // Строка в базе — половина дела: пересчёт читает `Habit.definition`, а
      // не репозиторий. Без прикрепления на живой модели только что созданное
      // воздержание до перезапуска считается с сегодняшнего дня, деление
      // пополам выключено, а «сорока дней» не существует. Тесты выше этого не
      // видят: они проверяют базу, а не модель.
      final EditHabitModel model =
          EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
      model.nameController.text = 'No alcohol';
      model.setCommittedFrom(8960);
      model.save();

      final Habit habit = scope.habitList.getByPosition(0);
      expect(habit.definition?.committedFrom, 8960,
          reason: 'computed.commitment#7 — без перезапуска');
      expect(habit.scores.halvesOnLapse, isTrue,
          reason: 'computed.lapse-score#11');
      expect(daysWithoutLapse(habit), 40, reason: 'computed.streak#4');
    });

    test('an ordinary habit opened for editing never becomes computed', () {
      // Built directly, not through `EditHabitModel.save()`: that save is a
      // second `save()` this test does not mean to exercise, and on the
      // broadest form of the mutation below (the definition write turned
      // unconditional) it would throw while creating this very fixture —
      // "Pages" has no commitment day, so `committedFrom` is still the field
      // default of 0, and `DefinitionRepository.save` refuses a day at or
      // before the epoch. That throw would kill this test for a reason that
      // has nothing to do with EDIT mode, before `editing` even exists.
      final Habit made = scope.modelFactory.buildHabit()
        ..name = 'Pages'
        ..type = HabitType.numerical
        ..unit = 'pages'
        ..targetValue = 30;
      scope.habitList.add(made);
      final int id = made.id!;

      final EditHabitModel editing = EditHabitModel(scope: scope, habitId: id);
      expect(editing.computedKind, isNull, reason: 'computed.create#10');
      expect(editing.isComputed, isFalse, reason: 'computed.create#10');
      editing.targetController.text = '40';
      editing.save();

      expect(scope.definitions.forHabit(id), isNull,
          reason: 'computed.create#10 — the transition ordinary → computed '
              'does not exist, and it does not exist because there is no code '
              'for it in either direction, not by agreement');
      expect(scope.definitions.isComputed(id), isFalse,
          reason: 'computed.create#10');
    });
  });
}
