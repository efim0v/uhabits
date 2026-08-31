import 'package:test/test.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late LapseRepository lapses;

  /// Привычка-воздержание с обязательством от [committedFrom] и срывами в
  /// перечисленные дни. Собрана как `makeHabit` в
  /// `abstinence_streaks_test.dart` — записи и оценка напрямую, без прогона
  /// через `AbstinenceSync` — плюс строка в `Habits`, на которую сможет
  /// сослаться `lapses.save`.
  Habit makeAbstinence({
    required int committedFrom,
    List<int> lapses = const <int>[],
  }) {
    db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
    final Habit habit = MemoryModelFactory().buildHabit()
      ..id = 1
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0.0
      ..frequency = Frequency.daily
      ..definition = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
        payload: abstinencePayload(),
      );
    for (final int day in lapses) {
      habit.originalEntries.add(Entry(LocalDate(day), 1000));
    }
    applyLapseScoring(habit, habit.definition);
    habit.recompute();
    return habit;
  }

  setUp(() {
    setToday(LocalDate(9000));
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    db = openAppSchemaDatabase();
    lapses = LapseRepository(db);
  });
  tearDown(() {
    DateUtils.setFixedTimeZone(null);
    resetToday();
    db.close();
  });

  test('#1 the count starts at the moment of the last lapse', () {
    // Срыв 8995-го в 14:30 UTC.
    const int at = (8995 + 10957) * 86400000 + 14 * 3600000 + 30 * 60000;
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8995]);
    lapses.save(habit.id!, 8995, amount: 1, atMillis: at);

    expect(abstinenceSinceMillis(habit, lapses), at,
        reason: 'computed.since#1 — считаем от того мгновения, когда сорвался');
  });

  test('#2 a lapse with no moment counts from the midnight after it', () {
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8995]);

    expect(abstinenceSinceMillis(habit, lapses),
        (8996 + 10957) * 86400000,
        reason: 'computed.since#2 — полночь ПОСЛЕ дня срыва: первый момент, '
            'про который точно известно, что он был чистым');
  });

  test('#3 the midnight is the one on the person\'s clock', () {
    // Все проверки выше прибивают зону нулём, а при нулевом смещении перевод
    // местной полуночи в момент — тождественная функция: она вернёт то же
    // число, даже если зону выбросить вовсе. Здесь смещение ненулевое, и
    // потому проверка различает «зона применена» и «зона проигнорирована».
    //
    // Разница видна человеку: у живущего в пятом часовом поясе счётчик,
    // забывшего про зону, показал бы на пять часов больше выдержанного.
    DateUtils.setFixedTimeZone(const FixedTimeZone(5 * 3600000));
    final habit = makeAbstinence(committedFrom: 8960);

    expect(abstinenceSinceMillis(habit, lapses),
        (8960 + 10957) * 86400000 - 5 * 3600000,
        reason: 'computed.since#3 — полночь 8960-го в зоне UTC+5 наступает на '
            'пять часов раньше, чем полночь того же дня в UTC');
  });

  test('#4 with no lapse at all the count starts at the commitment', () {
    final habit = makeAbstinence(committedFrom: 8960);

    expect(abstinenceSinceMillis(habit, lapses), (8960 + 10957) * 86400000,
        reason: 'computed.since#3 — день, который человек выбрал сам, с его '
            'полуночи');
  });

  test('#5 a lapse today means the count has not started', () {
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[9000]);

    expect(abstinenceSinceMillis(habit, lapses), isNull,
        reason: 'computed.since#4 — сорвался сегодня, считать нечего');
  });
}
