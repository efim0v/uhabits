import 'dart:math';

import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

/// Множитель порта для ежедневной привычки, выписанный независимо от Score.
final double m = pow(0.5, sqrt(1.0) / 13.0).toDouble();

/// Тот же обход, что у `EntryList.getByInterval`: по одной записи на каждый
/// день из [from, to], новейший первым, UNKNOWN за день без записи.
class FakeEntries {
  final Map<LocalDate, Entry> _byDate = <LocalDate, Entry>{};

  void put(LocalDate date, int value) => _byDate[date] = Entry(date, value);

  List<Entry> getByInterval(LocalDate from, LocalDate to) {
    final List<Entry> result = <Entry>[];
    if (from.isNewerThan(to)) return result;
    LocalDate current = to;
    while (!current.isOlderThan(from)) {
      result.add(_byDate[current] ?? Entry(current, Entry.unknown));
      current = current.minus(1);
    }
    return result;
  }
}

void main() {
  late LocalDate today;
  late FakeEntries entries;
  late ScoreList scores;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    today = getToday();
    entries = FakeEntries();
    scores = ScoreList();
  });

  tearDown(resetToday);

  void reset() {
    entries = FakeEntries();
    scores = ScoreList();
  }

  /// Пересчёт по диапазону [today - days, today]. Нижняя граница задаётся
  /// явно: у воздержания она есть день обязательства, а не первая запись, —
  /// и это отдельная работа, от которой арифметика не зависит.
  void recompute({
    required int days,
    double targetValue = 0.0,
    bool halvesOnLapse = true,
    NumericalHabitType targetType = NumericalHabitType.atMost,
  }) {
    scores.halvesOnLapse = halvesOnLapse;
    scores.recompute(
      frequency: Frequency.daily,
      isNumerical: true,
      numericalHabitType: targetType,
      targetValue: targetValue,
      computedEntries: entries.getByInterval,
      from: today.minus(days),
      to: today,
    );
  }

  void lapse(int offset, {int amount = 1}) =>
      entries.put(today.minus(offset), amount * 1000);

  test('silence is success', () {
    // Ни одной записи: max(0, -1) даёт нулевую сумму, ветвь допуска 0 отдаёт
    // 1.0, и оценка стоит на 1.0 — подтверждать нечего.
    recompute(days: 3);
    expect(scores[today].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#1');
    expect(scores[today.minus(3)].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#1');
  });

  test('a lapse halves the score', () {
    lapse(0);
    recompute(days: 5);
    expect(scores[today.minus(1)].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#3');
    expect(scores[today].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#3');
    // Ни затухание порта, ни ноль.
    expect((scores[today].value - m).abs(), greaterThan(0.4),
        reason: 'computed.lapse-score#3 — не 5% порта');
    expect(scores[today].value, greaterThan(0.4),
        reason: 'computed.lapse-score#3 — не обнуление');
  });

  test('a lapse is a fact, not an amount', () {
    // Допуск 30 минут. Сорок пять минут и семьдесят пять часов — один и тот
    // же срыв: «срыв есть факт, но с допуском».
    lapse(0, amount: 45);
    recompute(days: 5, targetValue: 30.0);
    final double afterSmall = scores[today].value;

    reset();
    lapse(0, amount: 4500);
    recompute(days: 5, targetValue: 30.0);
    expect(scores[today].value, closeTo(afterSmall, 1e-12),
        reason: 'computed.lapse-score#4');
    expect(afterSmall, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#4');
  });

  test('the tolerance decides where a lapse begins', () {
    lapse(0, amount: 20);
    recompute(days: 5, targetValue: 30.0);
    expect(scores[today].value, closeTo(1.0, 1e-12),
        reason: 'computed.lapse-score#5');

    reset();
    lapse(0, amount: 31);
    recompute(days: 5, targetValue: 30.0);
    expect(scores[today].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#5');

    // При допуске 0 срывом становится любая запись: один тап.
    reset();
    lapse(0);
    recompute(days: 5);
    expect(scores[today].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#5');
  });

  test('with the flag off the port is bit-identical', () {
    // Набор правила models.score-list-recompute-numerical-at-most#5: 1000 за
    // двадцать дней до сегодня и 5000 в каждый из двадцати последних дней при
    // цели 2.0.
    for (int i = 0; i < 20; i++) {
      lapse(i, amount: 5);
    }
    lapse(20, amount: 1);
    recompute(days: 21, targetValue: 2.0, halvesOnLapse: false);
    expect(scores[today].value, closeTo(0.344253, 1e-6),
        reason: 'computed.lapse-score#6');
    expect(scores[today.minus(20)].value, closeTo(1.0, 1e-9),
        reason: 'computed.lapse-score#6');
    expect(scores[today.minus(1)].value, closeTo(0.363106, 1e-6),
        reason: 'computed.lapse-score#6');
  });

  test('the halving is an at-most rule only', () {
    // Цель 2.0 при 3000 в день: сумма превышает цель каждый день. Без охраны
    // `isAtMost` включённое поле делило бы пополам и здесь.
    for (int i = 0; i < 20; i++) {
      lapse(i, amount: 3);
    }
    recompute(
      days: 20,
      targetValue: 2.0,
      targetType: NumericalHabitType.atLeast,
    );
    expect(scores[today].value, closeTo(0.655747, 1e-6),
        reason: 'computed.lapse-score#7');
  });

  test('a skip is not a lapse', () {
    lapse(2);
    entries.put(today.minus(1), Entry.skip);
    recompute(days: 5);
    expect(scores[today.minus(2)].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#8');
    // Пропуск переносит оценку срыва, а не делит её ещё раз, хотя его
    // собственная тройка и попадает в скользящую сумму.
    expect(scores[today.minus(1)].value, closeTo(0.5, 1e-12),
        reason: 'computed.lapse-score#8');
    expect(scores[today].value, closeTo(0.525961, 1e-6),
        reason: 'computed.lapse-score#8');
  });
}
