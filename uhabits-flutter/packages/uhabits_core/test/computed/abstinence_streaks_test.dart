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
      ..frequency = Frequency(1, 1)
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
