import 'package:test/test.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  setUp(() => setToday(LocalDate(9000)));
  tearDown(resetToday);

  /// Привычка-воздержание с обязательством от [committedFrom] и срывами в
  /// перечисленные дни.
  Habit makeHabit({required int committedFrom, List<int> lapses = const []}) {
    final Habit habit = MemoryModelFactory().buildHabit()
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

  test('#10 with no lapse at all there is no record to compare against', () {
    final AbstinenceStreaks s =
        abstinenceStreaksOf(makeHabit(committedFrom: 8960));

    expect(s.currentDays, 40, reason: 'computed.streak#8');
    expect(s.currentIsBest, isTrue,
        reason: 'computed.streak#10 — первая же серия и есть лучшая');
    expect(s.previousDays, isNull,
        reason: 'computed.streak#10 — прошлой попытки не было, и выдумывать '
            'её нечем');
    expect(s.shareOfPrevious, isNull, reason: 'computed.streak#10');
  });

  test('#10 the current run is measured against the record and the last try',
      () {
    // Обязательство с 8960, срывы 8980 и 8985. Отсюда три серии:
    //   8960..8979 — завершённая, 20 прошедших суток;
    //   8981..8984 — завершённая, 4 суток;
    //   8986..9000 — идущая, включительно 15 дней, прошедших суток 14.
    final AbstinenceStreaks s = abstinenceStreaksOf(
        makeHabit(committedFrom: 8960, lapses: <int>[8980, 8985]));

    expect(s.currentDays, 14,
        reason: 'computed.streak#8 — сегодня ещё идёт и целыми сутками не '
            'стало');
    expect(s.bestDays, 20, reason: 'computed.streak#10');
    expect(s.previousDays, 4,
        reason: 'computed.streak#10 — прошлая есть предыдущая по времени, а '
            'не вторая по длине: двадцатидневная старше и длиннее, но между '
            'ней и нынешней была четырёхдневная');
    expect(s.currentIsBest, isFalse, reason: 'computed.streak#10');
    expect(s.shareOfBest, closeTo(0.7, 0.001), reason: 'computed.streak#10');
    expect(s.shareOfPrevious, closeTo(3.5, 0.001),
        reason: 'computed.streak#10 — прошлую попытку можно и перерасти, и '
            'доля тогда больше единицы');
  });

  test('#10 the day asked about is the day answered about', () {
    // `asOf` идёт вниз в три места разом: `getCurrent`, `elapsedDaysOf` и
    // `daysWithoutLapse`. Забыть его в любом из них — значит посчитать не тот
    // день, о котором спросили, и ни один тест выше этого не заметит: у них
    // сегодня и есть день вопроса.
    //
    // Часы двигаются вперёд, а спрашивают про прежний день. Серии при этом
    // не пересчитываются, поэтому текущая серия по-прежнему кончается 9000-м.
    final Habit habit =
        makeHabit(committedFrom: 8960, lapses: <int>[8980, 8985]);
    setToday(LocalDate(9005));

    final AbstinenceStreaks asked =
        abstinenceStreaksOf(habit, asOf: LocalDate(9000));
    final AbstinenceStreaks byClock = abstinenceStreaksOf(habit);

    expect(asked.currentDays, 14,
        reason: 'computed.streak#10 — спросили про 9000-й, и ответ про него');
    expect(byClock.currentDays, 0,
        reason: 'computed.streak#10 — а по часам серия уже кончилась пять '
            'дней назад, и это другой ответ: значит день берётся из вопроса, '
            'а не из часов');
  });

  test('#10 the record too is measured on the day asked about', () {
    // Проверка выше стережёт только текущую длительность, а она приходит из
    // `daysWithoutLapse`. Лучшую и прошлую считает `elapsedDaysOf`, и `asOf`
    // теряется там незаметно: у завершённой серии конец старше любого из двух
    // дней, и ответ один и тот же.
    //
    // Разводит их случай, когда рекорд — сама текущая серия. Тогда её
    // длительность считают оба пути: `daysWithoutLapse` на дне вопроса и
    // `elapsedDaysOf` на том дне, который ему передали. Совпадут они, только
    // если день один.
    final Habit habit = makeHabit(committedFrom: 8960, lapses: <int>[8970]);
    setToday(LocalDate(9005));

    final AbstinenceStreaks asked =
        abstinenceStreaksOf(habit, asOf: LocalDate(9000));

    expect(asked.currentDays, 29,
        reason: 'computed.streak#10 — с 8971-го по 9000-й прошло двадцать '
            'девять полных суток');
    expect(asked.bestDays, 29,
        reason: 'computed.streak#10 — идущая серия и есть рекорд, и меряется '
            'она тем же днём, каким меряется текущая');
    expect(asked.currentIsBest, isTrue,
        reason: 'computed.streak#10 — два пути к одному числу сошлись; '
            'разойдись они на день, рекорд оказался бы чужим');
  });

  test('#12 a habit begun and broken on one day leaves no record at all', () {
    // Самый короткий путь к пустоте, и обычный: день обязательства по
    // умолчанию есть сегодняшний, окно серий равно [обязательство, сегодня],
    // и срыв выбрасывает из него единственный день. Серий не остаётся ни
    // одной, а карточка спрашивала у пустоты и долю, и слово вместо неё.
    final AbstinenceStreaks s = abstinenceStreaksOf(
        makeHabit(committedFrom: 9000, lapses: <int>[9000]));

    expect(s.bestDays, isNull,
        reason: 'computed.streak#12 — серий нет вовсе, и лучшей среди них не '
            'заводится');
    expect(s.hasRecord, isFalse,
        reason: 'computed.streak#12 — сравнивать не с чем');
    expect(s.currentIsBest, isFalse,
        reason: 'computed.streak#12 — нечему быть рекордом');
    expect(s.shareOfBest, isNull,
        reason: 'computed.streak#12 — и доли от него нет: делить не на что');
  });

  test('#12 nought days lived through is not a record', () {
    // Привычка, заведённая сегодня и не сорвавшаяся: серия одна, и длится
    // она ноль суток. Рекорд, равный нулю, поздравлял продержавшегося
    // нисколько.
    final AbstinenceStreaks s = abstinenceStreaksOf(makeHabit(
      committedFrom: 9000,
    ));

    expect(s.currentDays, 0,
        reason: 'computed.streak#8 — сегодняшний день ещё идёт');
    expect(s.bestDays, 0,
        reason: 'computed.streak#12 — серия есть, а прожитых суток в ней нет');
    expect(s.hasRecord, isFalse,
        reason: 'computed.streak#12 — ноль суток рекордом не бывает');
    expect(s.currentIsBest, isFalse,
        reason: 'computed.streak#12 — и «рекорд» человеку, продержавшемуся '
            'нисколько, читать нечего');
  });

  test('#11 a lapse today leaves the counter at nothing', () {
    final AbstinenceStreaks s = abstinenceStreaksOf(
        makeHabit(committedFrom: 8960, lapses: <int>[9000]));

    expect(s.currentDays, 0,
        reason: 'computed.streak#11 — сорвался сегодня, значит не держится '
            'нисколько');
    expect(s.previousDays, 40,
        reason: 'computed.streak#11 — а прошлая серия есть та, что только что '
            'оборвалась');
  });
}
