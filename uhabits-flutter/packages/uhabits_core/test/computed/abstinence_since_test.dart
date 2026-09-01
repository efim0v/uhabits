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

  test(
      '#6 moving the commitment forward strands a lapse moment before it, '
      'and the count does not follow it', () {
    // Срыв на 8989-м, ещё под старым обязательством от 8960-го.
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8989]);
    const int staleAt =
        (8989 + 10957) * 86400000 + 9 * 3600000; // 09:00 UTC того дня
    lapses.save(habit.id!, 8989, amount: 1, atMillis: staleAt);

    // Владелец переносит обязательство на день после того срыва: запись
    // остаётся в журнале, но окно её больше не видит (`computed.commitment#2`).
    habit.definition = habit.definition!.copyWith(committedFrom: 8990);
    habit.recompute();

    expect(abstinenceSinceMillis(habit, lapses), (8990 + 10957) * 86400000,
        reason: 'computed.commitment#2 — день срыва старше нового дня '
            'обязательства, значит он вне окна: счётчик идёт от полуночи '
            'обязательства, а не от мгновения, которое обязательство '
            'исключило');
  });

  /// Серия привычки, начинающаяся в день [start]. Берётся у самой привычки, а
  /// не собирается рядом: длительность считается про ту серию, которую нашёл
  /// пересчёт, и подставленная вручную пара дат проверяла бы не то.
  Streak streakFrom(Habit habit, int start) => habit.streaks
      .getBest(1 << 20)
      .firstWhere((Streak s) => s.start == LocalDate(start));

  /// Судья дня по хранимому значению — тот же, что на поверхностях
  /// воздержания: ступеньки `Entry` срывом не бывают, а всё прочее судится
  /// допуском (`computed.abstinence-cell#2`). В приложении он живёт в
  /// `abstinence_button_view.dart`, куда ядру не дотянуться; здесь записан
  /// теми же двумя строками, чтобы шов проверялся тем, чем его кормят.
  bool Function(int) judgeOf(Habit habit) => (int value) =>
      value > Entry.skip &&
      isAbstinenceLapse(habit.definition!, value / 1000.0);

  test('#7 a streak the journal says nothing about runs midnight to midnight',
      () {
    // Срывы 8990-го и 8996-го, ни у одного момента не записано: между ними
    // серия [8991, 8995].
    final habit =
        makeAbstinence(committedFrom: 8960, lapses: <int>[8990, 8996]);
    final Streak streak = streakFrom(habit, 8991);

    expect(streak.end, LocalDate(8995),
        reason: 'computed.since#8 — серия кончается днём перед срывом');
    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit)),
        5 * 86400000,
        reason: 'computed.since#8 — ровно пять суток: от полуночи 8991-го до '
            'полуночи 8996-го, часы и минуты нулевые. Это не выдумка, а '
            'единственное, что про такую серию известно (`computed.since#2`)');
  });

  test('#8 a streak between two recorded moments is the distance between them',
      () {
    // Сорвался 8990-го в 06:00 и снова 8996-го в 20:00.
    const int first = (8990 + 10957) * 86400000 + 6 * 3600000;
    const int second = (8996 + 10957) * 86400000 + 20 * 3600000;
    final habit =
        makeAbstinence(committedFrom: 8960, lapses: <int>[8990, 8996]);
    lapses.save(habit.id!, 8990, atMillis: first);
    lapses.save(habit.id!, 8996, atMillis: second);
    final Streak streak = streakFrom(habit, 8991);

    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit)),
        second - first,
        reason: 'computed.since#8 — правило на обоих концах одно: от '
            'мгновения одного срыва до мгновения следующего');
    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit)),
        6 * 86400000 + 14 * 3600000,
        reason: 'computed.since#8 — шесть суток и четырнадцать часов, тогда '
            'как чистых суток в серии пять: чистое время начинается утром '
            'одного дня и кончается вечером другого, и полными сутками его '
            'больше, чем календарными днями между срывами');
  });

  test('#9 a running streak is measured up to now', () {
    const int now = (9000 + 10957) * 86400000 + 9 * 3600000;
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8996]);
    final Streak streak = streakFrom(habit, 8997);

    expect(streak.end, LocalDate(9000),
        reason: 'computed.since#8 — идущая серия кончается сегодняшним днём');
    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit), nowMillis: now),
        3 * 86400000 + 9 * 3600000,
        reason: 'computed.since#8 — у идущей серии конца ещё нет, и вместо '
            'него берётся «сейчас»: от полуночи 8997-го до девяти утра '
            'сегодня');
  });

  test('#11 midnight does not end a streak that no lapse ended', () {
    // Список серий собирается один раз, а «сегодня» переезжает в полночь.
    // Строим список вчерашним днём и переводим часы через полночь, ничего
    // больше не трогая, — ровно то, что происходит с открытым экраном.
    setToday(LocalDate(8999));
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8996]);
    setToday(LocalDate(9000));
    final Streak streak = streakFrom(habit, 8997);

    expect(streak.end, LocalDate(8999),
        reason: 'computed.since#10 — серия осталась той, какой её собрали до '
            'полуночи: её конец — вчерашний день');

    const int now = (9000 + 10957) * 86400000 + 9 * 3600000;
    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit), nowMillis: now),
        3 * 86400000 + 9 * 3600000,
        reason: 'computed.since#10 — серия идёт: на дне после её конца срыва '
            'нет. Спроси мы «конец старше сегодня?», ответ был бы ровно трое '
            'суток — надпись встала бы на «3 дня 00:00» и стояла бы до '
            'следующей перерисовки экрана');
  });

  test('#12 a lapse on the day after does end it, whatever the date is', () {
    // Та же форма, но срыв на дне после конца есть. Дата тут ни при чём:
    // кончает серию срыв.
    final habit =
        makeAbstinence(committedFrom: 8960, lapses: <int>[8990, 8996]);
    final Streak streak = streakFrom(habit, 8991);

    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit), nowMillis: (9000 + 10957) * 86400000),
        5 * 86400000,
        reason: 'computed.since#10 — пять суток, а не двадцать один день до '
            '«сейчас»: серию оборвал срыв 8996-го, и на нём она кончилась');
  });

  test('#10 the streak does not read a moment its own commitment excluded',
      () {
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8989]);
    const int staleAt = (8989 + 10957) * 86400000 + 9 * 3600000;
    lapses.save(habit.id!, 8989, atMillis: staleAt);

    habit.definition = habit.definition!.copyWith(committedFrom: 8990);
    habit.recompute();
    final Streak streak = streakFrom(habit, 8990);

    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit),
            nowMillis: (9000 + 10957) * 86400000),
        10 * 86400000,
        reason: 'computed.commitment#2 — охрана у карточки серий та же, что у '
            'счётчика: день срыва старше нового дня обязательства, значит он '
            'вне окна, и серия считается от полуночи обязательства');
  });
}
