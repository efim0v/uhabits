import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/abstinence_sync.dart';
import 'package:uhabits_core/src/computed/day_writer.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/computed/lapse_repository.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late LapseRepository lapses;
  late AbstinenceSync sync;
  late Habit habit;
  late LocalDate today;

  setUp(() {
    setToday(LocalDate(9000));
    today = getToday();
    db = openAppSchemaDatabase();
    db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
    lapses = LapseRepository(db);
    sync = AbstinenceSync(lapses: lapses, writer: const DayWriter());
    habit = MemoryModelFactory().buildHabit()
      ..id = 1
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0
      ..definition = const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8960,
      );
  });

  tearDown(() {
    db.close();
    resetToday();
  });

  test('a second tap on the same day is still one lapse', () {
    sync.setLapse(habit, today, true);
    sync.setLapse(habit, today, true);

    expect(db.queryInt('select count(*) from Lapses'), 1,
        reason: 'computed.abstinence-sync#1');
    expect(habit.originalEntries.get(today).value, 1000,
        reason: 'computed.abstinence-sync#1 — журнал и день сходятся');
  });

  test('taking it back returns the day to silence', () {
    sync.setLapse(habit, today, true);
    sync.setLapse(habit, today, false);

    expect(lapses.forDay(1, today.daysSince2000), isNull,
        reason: 'computed.abstinence-sync#2');
    expect(habit.originalEntries.get(today).value, Entry.unknown,
        reason: 'computed.abstinence-sync#2 — иначе вчерашние 45000 остаются '
            'лежать в дне, который человек только что отменил');
  });

  test('a recompute covers the range, not the day', () {
    lapses.save(1, 8990, amount: 1);
    sync.recomputeDays(habit, 8985, 8995);

    expect(habit.originalEntries.get(LocalDate(8990)).value, 1000,
        reason: 'computed.abstinence-sync#3');
    for (final int day in <int>[8985, 8991, 8995]) {
      expect(habit.originalEntries.get(LocalDate(day)).value, Entry.unknown,
          reason: 'computed.abstinence-sync#3 — чистый день не пишется вовсе, '
              'иначе в диапазоне появятся десять срывов');
    }
  });

  test('the sweep does not touch a skip', () {
    habit.originalEntries.add(Entry(today, Entry.skip));
    sync.setLapse(habit, today, true);

    expect(habit.originalEntries.get(today).value, Entry.skip,
        reason: 'computed.abstinence-sync#4 — пропуск есть отметка человека '
            '(`computed.day-write#4`)');
  });

  test('the whole commitment is rescored from its first day', () {
    lapses.save(1, 8961, amount: 45);
    final bool wrote = sync.recomputeAll(
      habit,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8960,
      ),
    );

    expect(wrote, isTrue, reason: 'computed.abstinence-sync#5');
    expect(habit.originalEntries.get(LocalDate(8961)).value, 45000,
        reason: 'computed.abstinence-sync#5 — понижение допуска обязано '
            'переоценить уже записанные дни (`computed.allowance#1`)');
  });

  test('a definition with no commitment day has no commitment to rescore', () {
    lapses.save(1, 8961, amount: 45);

    final bool wrote = sync.recomputeAll(
      habit,
      const HabitDefinition(kind: ComputedKind.abstinence),
    );

    expect(wrote, isFalse, reason: 'computed.abstinence-sync#5');
    // Не «с нуля до сегодня»: подставленный ноль накрыл бы и этот срыв, и
    // двадцать шесть лет до него (`computed.commitment#6`).
    expect(habit.originalEntries.get(LocalDate(8961)).value, Entry.unknown,
        reason: 'computed.abstinence-sync#5 — обязательства без дня нет, и '
            'пересчитывать от эпохи — не то же самое, что не пересчитывать');
  });
}
