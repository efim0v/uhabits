import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/definition_repository.dart';
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/database/database.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late DefinitionRepository repository;

  setUp(() {
    db = openAppSchemaDatabase();
    repository = DefinitionRepository(db);
    db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
  });

  tearDown(() => db.close());

  test('a habit with no definition is not computed', () {
    expect(repository.forHabit(1), isNull, reason: 'computed.definition#1');
    expect(repository.isComputed(1), isFalse, reason: 'computed.definition#1');
  });

  test('what is saved is what is read back', () {
    const HabitDefinition definition = HabitDefinition(
      kind: ComputedKind.abstinence,
      committedFrom: 9000,
      payload: <String, Object?>{'allowance': 30, 'unit': 'min'},
    );

    repository.save(1, definition);

    expect(repository.forHabit(1), definition,
        reason: 'computed.definition#2');
  });

  test('saving twice replaces rather than duplicates', () {
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.save(1,
        const HabitDefinition(kind: ComputedKind.sleep, committedFrom: 9001));

    expect(repository.forHabit(1)!.committedFrom, 9001,
        reason: 'computed.definition#2');
    expect(db.queryInt('select count(*) from HabitDefinitions'), 1,
        reason: 'computed.definition#2');
  });

  test('a kind nobody knows reads as no definition at all', () {
    // A file written by a newer build. Guessing would be worse than admitting
    // there is nothing here this build understands.
    db.run("insert into HabitDefinitions (habit, kind, payload) "
        "values (1,'telepathy','{}')");
    expect(repository.forHabit(1), isNull, reason: 'computed.definition#3');
  });

  test('but a kind nobody knows is still computed', () {
    // Two different questions. "What do I compute this with?" — not knowing
    // means there is nothing here to compute with. "May something outside
    // write this habit's days?" — not knowing has to mean no, or a habit from
    // a newer build is writable from a widget and clearable by randomise.
    db.run("insert into HabitDefinitions (habit, kind, payload) "
        "values (1,'telepathy','{}')");
    expect(repository.isComputed(1), isTrue, reason: 'computed.definition#9');
  });

  test('a known kind is computed too', () {
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));

    expect(repository.isComputed(1), isTrue, reason: 'computed.definition#9');
  });

  test('the habits of one kind are listed, and no others', () {
    db.run("insert into Habits (id, name, uuid) values (2, 'y', 'u2')");
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.save(2, const HabitDefinition(kind: ComputedKind.abstinence));

    expect(repository.habitIdsOfKind(ComputedKind.sleep), <int>[1],
        reason: 'computed.definition#4');
  });

  // The commitment day is a `daysSince2000`, so 0 is 2000-01-01 — the first
  // day the type can express, and a day nobody committed on. It is also what
  // an unset integer looks like, and nothing on the write side rejects it:
  // `DefinitionImporter` copies whatever the other file held, and the table
  // has no CHECK. Read back as a real day it would pull the lower bound of
  // every recompute to the epoch and show a quarter of a century without a
  // lapse.
  test('a commitment day at or before the epoch is no commitment day', () {
    db.run("insert into HabitDefinitions (habit, kind, committed_from, payload) "
        "values (1,'abstinence',0,'{}')");
    expect(repository.forHabit(1)?.committedFrom, isNull,
        reason: 'computed.commitment#6');

    // And a day before the epoch even more so: a hand-edited row, or a file
    // written by something that counted from a different zero.
    db.run('update HabitDefinitions set committed_from = -1 where habit = 1');
    expect(repository.forHabit(1)?.committedFrom, isNull,
        reason: 'computed.commitment#6');
  });

  test('but the day after the epoch is a real day, and survives', () {
    // The boundary is the epoch itself, not a guess at how old a habit may
    // be. Someone else's twenty-year-old commitment is theirs to keep.
    db.run("insert into HabitDefinitions (habit, kind, committed_from, payload) "
        "values (1,'abstinence',1,'{}')");

    expect(repository.forHabit(1)?.committedFrom, 1,
        reason: 'computed.commitment#6');
  });

  test('dropping the impossible day keeps the kind and the payload', () {
    // Only the day is unusable. Dropping the whole definition would be a lie
    // in the other direction: the habit would stop being an abstinence one,
    // lose the halving and the silent-day streak, and merely fall back to the
    // ported window instead (`computed.commitment#3`).
    db.run("insert into HabitDefinitions (habit, kind, committed_from, payload) "
        "values (1,'abstinence',0,'{\"allowance\":30}')");

    final HabitDefinition? definition = repository.forHabit(1);
    expect(definition?.kind, ComputedKind.abstinence,
        reason: 'computed.commitment#6');
    expect(definition?.payload['allowance'], 30,
        reason: 'computed.commitment#6');
  });

  test('removing one leaves the habit alone', () {
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.remove(1);

    expect(repository.forHabit(1), isNull, reason: 'computed.definition#5');
    expect(db.queryInt('select count(*) from Habits'), 1,
        reason: 'computed.definition#5');
  });
}
