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
  ///
  /// [committedAtMillis] — момент обязательства; по умолчанию его нет, как у
  /// всякой привычки, заведённой до миграции 105 (`computed.schema#11`).
  /// [allowance] зеркалит `targetValue`: это одно число, записанное дважды
  /// (`computed.allowance#1`).
  Habit makeAbstinence({
    required int committedFrom,
    List<int> lapses = const <int>[],
    int? committedAtMillis,
    double allowance = 0.0,
    List<Entry> entries = const <Entry>[],
  }) {
    db.run("insert into Habits (id, name, uuid) values (1, 'x', 'u1')");
    final Habit habit = MemoryModelFactory().buildHabit()
      ..id = 1
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = allowance
      ..frequency = Frequency.daily
      ..definition = HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
        committedAtMillis: committedAtMillis,
        payload: abstinencePayload(allowance: allowance),
      );
    for (final int day in lapses) {
      habit.originalEntries.add(Entry(LocalDate(day), 1000));
    }
    for (final Entry entry in entries) {
      habit.originalEntries.add(entry);
    }
    applyLapseScoring(habit, habit.definition);
    habit.recompute();
    return habit;
  }

  /// Судья дня по хранимому значению — тот же, что на поверхностях
  /// воздержания: ступеньки `Entry` срывом не бывают, а всё прочее судится
  /// допуском (`computed.abstinence-cell#2`). В приложении он живёт в
  /// `abstinence_button_view.dart`, куда ядру не дотянуться; здесь записан
  /// теми же двумя строками, чтобы шов проверялся тем, чем его кормят.
  bool Function(int) judgeOf(Habit habit) => (int value) =>
      value > Entry.skip &&
      isAbstinenceLapse(habit.definition!, value / 1000.0);

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

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        at,
        reason: 'computed.since#1 — считаем от того мгновения, когда сорвался');
  });

  test('#21 the last lapse is the newest one, not the first', () {
    // Два срыва под одним обязательством, у обоих момент записан.
    const int older = (8990 + 10957) * 86400000 + 6 * 3600000;
    const int newer = (8995 + 10957) * 86400000 + 20 * 3600000;
    final habit =
        makeAbstinence(committedFrom: 8960, lapses: <int>[8990, 8995]);
    lapses.save(habit.id!, 8990, amount: 1, atMillis: older);
    lapses.save(habit.id!, 8995, amount: 1, atMillis: newer);

    expect(lastAbstinenceLapseDay(habit, isLapseValue: judgeOf(habit)), 8995,
        reason: 'computed.since#1 — последний срыв это самый новый: перебор '
            'идёт с сегодняшнего дня назад и останавливается на первом же '
            'найденном');
    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        newer,
        reason: 'computed.since#1 — и счёт идёт от его мгновения, а не от '
            'того, с которого воздержание начиналось пять дней раньше');
  });

  test('#2 a lapse with no moment counts from the midnight after it', () {
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8995]);

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
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

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8960 + 10957) * 86400000 - 5 * 3600000,
        reason: 'computed.since#3 — полночь 8960-го в зоне UTC+5 наступает на '
            'пять часов раньше, чем полночь того же дня в UTC');
  });

  test('#4 with no lapse at all the count starts at the commitment', () {
    final habit = makeAbstinence(committedFrom: 8960);

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8960 + 10957) * 86400000,
        reason: 'computed.since#3 — момента обязательства у этой привычки нет, '
            'и остаётся полночь того дня, который человек выбрал сам');
  });

  test('#5 a lapse today starts the count at that lapse, not at midnight', () {
    // Жалоба владельца дословно: «почему у меня таймер начинает отсчитывать с
    // начала дня, а не с момента, когда я говорю, что сорвался?». Сорвался
    // сегодня в половине третьего.
    const int at = (9000 + 10957) * 86400000 + 14 * 3600000 + 30 * 60000;
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[9000]);
    lapses.save(habit.id!, 9000, amount: 1, atMillis: at);

    expect(habit.streaks.getCurrent(LocalDate(9000)), isNull,
        reason: 'sanity: сегодня перестало быть чистым днём, и серии, '
            'накрывающей его, не осталось ни одной — ровно то, обо что '
            'счётчик спотыкался');
    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        at,
        reason: 'computed.since#4 — счёт идёт с половины третьего, а не стоит '
            'на нуле до полуночи: через серию счётчик не ходит вовсе');
  });

  test('#13 a lapse today with no moment counts from the midnight ending it',
      () {
    // Тот же день, но момента у срыва нет: отметили задним числом, а потом
    // перенесли часы (`computed.since#7`). Полночь после дня срыва ещё не
    // наступила, и это честно: про сегодня неизвестно ничего, кроме того, что
    // он не был чистым.
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[9000]);

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (9001 + 10957) * 86400000,
        reason: 'computed.since#2 — полночь ПОСЛЕ дня срыва, даже когда этот '
            'день сегодняшний: счётчик прочитает её нулём, потому что она ещё '
            'впереди');
  });

  test('#14 with no lapse at all the count starts at the commitment moment',
      () {
    // Обязательство дано в девять утра, а не в полночь.
    const int at = (8960 + 10957) * 86400000 + 9 * 3600000;
    final habit = makeAbstinence(committedFrom: 8960, committedAtMillis: at);

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        at,
        reason: 'computed.since#3 — срывов не было, и счёт идёт от того '
            'мгновения, когда обязательство дано, а не от полуночи его дня');
  });

  test('#15 a commitment moment of zero is no moment at all', () {
    final habit = makeAbstinence(committedFrom: 8960, committedAtMillis: 0);

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8960 + 10957) * 86400000,
        reason: 'computed.since#11 — ноль есть первое января семидесятого, и '
            'принять его за настоящий момент значило бы напечатать полвека '
            'свободы; остаётся полночь дня обязательства');
  });

  test(
      '#23 a commitment moment stranded on a day the commitment no longer '
      'names is no moment at all', () {
    // Так её принёс бы `copyWith` до собственного исправления — заменить день
    // обязательства этим методом можно, а стереть повисший момент нельзя было
    // в принципе (`computed.definition#11`) — или чужая копия базы, ни разу
    // не видевшая стирания (`computed.commitment#9`): день обязательства
    // перенесён назад, момент остался тем, что был записан для прежнего,
    // более позднего дня.
    const int at = (8990 + 10957) * 86400000 + 9 * 3600000; // 9 утра 8990-го
    final habit = makeAbstinence(committedFrom: 8990, committedAtMillis: at);
    habit.definition = habit.definition!.copyWith(committedFrom: 8960);
    habit.recompute();

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8960 + 10957) * 86400000,
        reason: 'computed.since#13 — момент остался висеть на дне, которого '
            'у обязательства больше нет: он не про 8960-й, и читается как '
            'отсутствие, а не как «эта привычка начата только что»');
  });

  test(
      '#24 a commitment moment exactly at the next midnight belongs to the '
      'next day, not this one', () {
    // Ровно та полночь, которой кончаются сутки дня обязательства, — уже
    // начало следующих суток, а не их конец: момент обязательства обязан
    // лежать строго внутри своего дня, границу с чужим не разделяя с ним.
    final int nextMidnight = (8960 + 1 + 10957) * 86400000;
    final habit =
        makeAbstinence(committedFrom: 8960, committedAtMillis: nextMidnight);

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8960 + 10957) * 86400000,
        reason: 'computed.since#13 — момент лёг точно на границу дня и '
            'принадлежит уже следующим суткам, а не этим; остаётся полночь '
            'дня обязательства');
  });

  test('#22 a lapse moment of zero is no moment at all', () {
    // Ноль сюда не могла положить ни одна дверь записи — `setLapse` кладёт
    // либо часы, либо пустоту (`computed.since#7`), — но чужая копия базы
    // донесёт что угодно, и счётчик её всё равно спросят.
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8995]);
    lapses.save(habit.id!, 8995, amount: 1, atMillis: 0);

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8996 + 10957) * 86400000,
        reason: 'computed.since#12 — ноль есть первое января семидесятого, и '
            'принять его за настоящий момент значило бы напечатать полвека '
            'свободы; остаётся полночь после дня срыва (`computed.since#2`)');
  });

  test('#16 without a commitment day there is nothing to count from', () {
    final habit = makeAbstinence(committedFrom: 8960);
    habit.definition = HabitDefinition(
      kind: ComputedKind.abstinence,
      payload: abstinencePayload(),
    );

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        isNull,
        reason: 'computed.since#4 — пусто только тогда, когда считать не от '
            'чего вовсе: без дня обязательства нет ни окна, в котором ищется '
            'срыв, ни второй точки отсчёта');
  });

  test('#17 the counter reads day values, not the journal', () {
    // Пропуск приезжает восстановлением копии, `DayWriter` его не
    // переписывает, и строка журнала на таком дне остаётся строкой без дня
    // (`computed.day-write#4`). Тот же случай, на котором подпись под
    // счётчиком когда-то расходилась с самим счётчиком.
    final habit = makeAbstinence(
      committedFrom: 8960,
      entries: <Entry>[Entry(LocalDate(8990), Entry.skip)],
    );
    lapses.save(habit.id!, 8990,
        amount: 1, atMillis: (8990 + 10957) * 86400000 + 3600000);

    expect(habit.computedEntries.get(LocalDate(8990)).value, Entry.skip,
        reason: 'sanity: значение дня осталось пропуском');
    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8960 + 10957) * 86400000,
        reason: 'computed.since#1 — срыв ищется в значениях дней, а не в '
            'журнале: строка, не ставшая значением дня, счёта не сбрасывает');
  });

  test('#18 a day inside the allowance is no lapse for the counter', () {
    // Двадцать минут при допуске тридцать. Судья приходит швом, и второго
    // сравнения — «записано хоть что-нибудь» — у счётчика нет.
    final habit = makeAbstinence(
      committedFrom: 8960,
      allowance: 30.0,
      entries: <Entry>[Entry(LocalDate(8990), 20000)],
    );

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8960 + 10957) * 86400000,
        reason: 'computed.since#1 — судья тот же, что красит ячейку: «не '
            'более 30» обещание держит, и счёт не сбрасывается '
            '(`computed.abstinence-cell#2`)');
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

    expect(abstinenceSinceMillis(habit, lapses, isLapseValue: judgeOf(habit)),
        (8990 + 10957) * 86400000,
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

  test('#20 a lapse older than the commitment is not the last lapse', () {
    // Пересчёт значение старого дня из кэша не выбрасывает: строка 8989-го
    // как лежала со значением, так и лежит, — и без нижней границы окна
    // подпись назвала бы её последним срывом, а счётчик рядом считал бы от
    // обязательства. Ровно то расхождение, ради которого стоит охрана.
    final habit = makeAbstinence(committedFrom: 8960, lapses: <int>[8989]);
    habit.definition = habit.definition!.copyWith(committedFrom: 8990);
    habit.recompute();

    expect(habit.computedEntries.get(LocalDate(8989)).value, 1000,
        reason: 'sanity: значение дня осталось в кэше после переноса');
    expect(lastAbstinenceLapseDay(habit, isLapseValue: judgeOf(habit)), isNull,
        reason: 'computed.commitment#2 — день старше обязательства в окно не '
            'входит: ни счётчику, ни подписи под ним он не последний срыв');
  });

  test('#19 the first streak starts at the commitment moment too', () {
    // Обязательство дано в девять утра сорокового дня назад. Перед этой
    // серией срыва нет по построению — раньше обязательства их не бывает, —
    // и её началом становится то же мгновение, от которого считает счётчик.
    const int at = (8960 + 10957) * 86400000 + 9 * 3600000;
    final habit = makeAbstinence(committedFrom: 8960, committedAtMillis: at);
    final Streak streak = streakFrom(habit, 8960);

    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit),
            nowMillis: (9000 + 10957) * 86400000 + 9 * 3600000),
        40 * 86400000,
        reason: 'computed.since#3 — ровно сорок суток от девяти утра до '
            'девяти утра, а не сорок суток и девять часов от полуночи: у '
            'первой серии начало есть момент обязательства');
    expect(
        abstinenceStreakMillis(habit, lapses, streak,
            isLapseValue: judgeOf(habit),
            nowMillis: (9000 + 10957) * 86400000 + 9 * 3600000),
        (9000 + 10957) * 86400000 +
            9 * 3600000 -
            abstinenceSinceMillis(habit, lapses,
                isLapseValue: judgeOf(habit))!,
        reason: 'computed.since#8 — надпись в полосе и счётчик над карточкой '
            'считают от одного мгновения, и расходиться им не в чем');
  });
}
