import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/lapse_repository.dart';
import 'package:uhabits_core/src/database/database.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late LapseRepository repository;

  setUp(() {
    db = openAppSchemaDatabase();
    repository = LapseRepository(db);
    db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
    db.run("insert into Habits (id, name, uuid) values (2, 'y', 'u2')");
  });

  tearDown(() => db.close());

  test('silence is the default, and it is spelled by no row at all', () {
    expect(repository.forDay(1, 9000), isNull, reason: 'computed.lapses#1');
    expect(repository.range(1, 8990, 9010), isEmpty,
        reason: 'computed.lapses#1');
    expect(db.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.lapses#1 — a clean day writes nothing, not a zero');
  });

  test('a tap records one unit', () {
    repository.save(1, 9000);

    expect(repository.forDay(1, 9000), LapseRepository.minimumAmount,
        reason: 'computed.lapses#2');
  });

  test('a lapse of nothing is refused', () {
    // A zero would satisfy "no more than the allowance" at the default
    // allowance of zero: a row asserting nothing. Silence is the absent row.
    expect(() => repository.save(1, 9000, amount: 0),
        throwsA(isA<ArgumentError>()), reason: 'computed.lapses#2');
    expect(() => repository.save(1, 9000, amount: -3),
        throwsA(isA<ArgumentError>()), reason: 'computed.lapses#2');
    expect(db.queryInt('select count(*) from Lapses'), 0,
        reason: 'computed.lapses#2 — and nothing is written on the way out');
  });

  test('recording the same day again replaces the amount', () {
    repository.save(1, 9000, amount: 20);
    repository.save(1, 9000, amount: 45);

    expect(repository.forDay(1, 9000), 45, reason: 'computed.lapses#3');
    expect(db.queryInt('select count(*) from Lapses'), 1,
        reason: 'computed.lapses#3 — replaced, not appended');
  });

  test('an amount below the allowance is still kept as it stands', () {
    // The journal records what happened; whether it is a lapse is the
    // definition's judgement and is made afresh every time it is asked.
    repository.save(1, 9000, amount: 20);

    expect(repository.forDay(1, 9000), 20, reason: 'computed.lapses#5');
  });

  test('taking a day back returns it to silence', () {
    repository.save(1, 9000);
    repository.save(1, 8999);
    repository.remove(1, 9000);

    expect(repository.forDay(1, 9000), isNull, reason: 'computed.lapses#4');
    expect(repository.forDay(1, 8999), 1,
        reason: 'computed.lapses#4 — removal touches only its own day');
    expect(db.queryInt('select count(*) from Lapses'), 1,
        reason: 'computed.lapses#4');
    // A second tap on a clean day must not throw.
    repository.remove(1, 9000);
    expect(repository.forDay(1, 9000), isNull, reason: 'computed.lapses#4');
  });

  test('a range gives back the recorded days of that habit and no others', () {
    repository.save(1, 8999, amount: 3);
    repository.save(1, 9000, amount: 5);
    repository.save(1, 9002, amount: 7);
    repository.save(2, 9000, amount: 99);

    expect(repository.range(1, 9000, 9002), <int, int>{9000: 5, 9002: 7},
        reason: 'computed.lapses#5');
    expect(repository.range(2, 8999, 9002), <int, int>{9000: 99},
        reason: 'computed.lapses#5 — one habit does not see another\'s');
  });

  test('the ends of the journal come from the journal', () {
    expect(repository.firstDay(1), isNull, reason: 'computed.lapses#6');
    expect(repository.lastDay(1), isNull, reason: 'computed.lapses#6');

    repository.save(1, 9002);
    repository.save(1, 8990);
    repository.save(2, 12000);

    expect(repository.firstDay(1), 8990, reason: 'computed.lapses#6');
    expect(repository.lastDay(1), 9002, reason: 'computed.lapses#6');
  });

  test('a lapse remembers the moment it happened', () {
    repository.save(1, 9000, amount: 1, atMillis: 1724832000000);

    expect(repository.momentOf(1, 9000), 1724832000000,
        reason: 'computed.schema#8 — момент возвращается тем же, каким его '
            'записали');
  });

  test('a lapse recorded without a moment has none', () {
    repository.save(1, 9000);

    expect(repository.momentOf(1, 9000), isNull,
        reason: 'computed.schema#9 — отсутствие момента есть null, а не ноль: '
            'ноль был бы полуночью первого января семидесятого');
    expect(repository.forDay(1, 9000), LapseRepository.minimumAmount,
        reason: 'computed.lapses#2 — величина при этом записана обычным '
            'образом');
  });

  test('re-saving a day replaces its moment along with its amount', () {
    repository.save(1, 9000, amount: 1, atMillis: 1724832000000);
    repository.save(1, 9000, amount: 5, atMillis: 1724900000000);

    expect(repository.forDay(1, 9000), 5, reason: 'computed.lapses#3');
    expect(repository.momentOf(1, 9000), 1724900000000,
        reason: 'computed.schema#8 — правка дня переписывает и момент, иначе '
            'счётчик считал бы от стёртого срыва');
  });

  test('the moment of a day with no lapse is null', () {
    expect(repository.momentOf(1, 9000), isNull, reason: 'computed.lapses#1');
  });
}
