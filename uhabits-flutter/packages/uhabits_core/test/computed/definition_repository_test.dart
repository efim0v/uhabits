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

  test('the habits of one kind are listed, and no others', () {
    db.run("insert into Habits (id, name, uuid) values (2, 'y', 'u2')");
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.save(2, const HabitDefinition(kind: ComputedKind.abstinence));

    expect(repository.habitIdsOfKind(ComputedKind.sleep), <int>[1],
        reason: 'computed.definition#4');
  });

  test('removing one leaves the habit alone', () {
    repository.save(1, const HabitDefinition(kind: ComputedKind.sleep));
    repository.remove(1);

    expect(repository.forHabit(1), isNull, reason: 'computed.definition#5');
    expect(db.queryInt('select count(*) from Habits'), 1,
        reason: 'computed.definition#5');
  });
}
