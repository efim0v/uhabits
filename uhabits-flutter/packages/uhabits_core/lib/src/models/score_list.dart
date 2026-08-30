import 'dart:math';

import '../time/local_date.dart';
import 'entry.dart';
import 'frequency.dart';
import 'habit_type.dart';
import 'score.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/ScoreList.kt
///
/// Kotlin annotates every method with `@Synchronized`; Dart isolates are
/// single-threaded, so the annotation has no counterpart here.
class ScoreList {
  final Map<LocalDate, Score> _map = {};

  /// Делить ли оценку пополам в день срыва вместо шага порта.
  ///
  /// Расширение слоя вычисляемых привычек, а не порт. Ни один портированный
  /// путь этого поля не пишет: `ModelFactory.buildScoreList()` отдаёт список с
  /// выключенным полем, и при выключенном поле [recompute] считает ровно то
  /// же, что Kotlin, — весь портированный набор проходит без правки.
  /// Включатель `applyLapseScoring` (`computed/lapse_scoring.dart`) уже
  /// существует и переживает `Habit.recompute()`, но из кода приложения его
  /// пока не зовёт ничто: эту дверь откроет `attachDefinition` (Задача 17).
  /// Читает поле ветвь at-most ниже.
  ///
  /// Правила: `docs/extensions/COMPUTED.md` `computed.lapse-score`.
  /// Отклонение: `docs/parity/DEVIATIONS.md`, запись «computed: срыв делит
  /// оценку пополам мимо формулы порта».
  bool halvesOnLapse = false;

  /// Период полураспада кривой роста в днях, или null для портовой кривой.
  ///
  /// Расширение слоя вычисляемых привычек. При null всё в точности как в
  /// Kotlin: старт с единицы для привычки «не больше» и множитель из
  /// `Score.compute`. При заданном периоде уровень стартует с нуля и растёт
  /// своим множителем — это единственная форма, в которой «уровень
  /// сдержанности» вообще может расти (`computed.lapse-score#14`).
  ///
  /// Шаг остаётся портовым, аффинным. Именно поэтому «срыв делит пополам»
  /// продолжает работать: делить есть что.
  ///
  /// Ставить его будет `applyLapseScoring`, рядом с [halvesOnLapse], — но
  /// пока не ставит: эту дверь открывает Задача 5. До неё поле пусто у всех,
  /// и обе ветви ниже недостижимы. Оговорка снимается вместе с тем коммитом,
  /// который делает её ложной.
  int? growthHalfLifeDays;

  /// Returns the score for a given day. If the date given happens before the
  /// first repetition of the habit or after the last computed score, returns a
  /// score with value zero.
  Score operator [](LocalDate date) => _map[date] ?? Score(date, 0.0);

  /// Returns the list of scores that fall within the given interval.
  ///
  /// There is exactly one score per day in the interval. The endpoints of the
  /// interval are included. The list is ordered by date (decreasing). That is,
  /// the first score corresponds to the newest date, and the last score
  /// corresponds to the oldest date.
  List<Score> getByInterval(LocalDate from, LocalDate to) {
    final result = <Score>[];
    if (from.isNewerThan(to)) return result;
    var current = to;
    while (!current.isOlderThan(from)) {
      result.add(this[current]);
      current = current.minus(1);
    }
    return result;
  }

  /// Recomputes all scores between the provided [from] and [to] dates.
  ///
  /// Kotlin takes the habit's computed `EntryList` here and calls
  /// `getByInterval` on it. EntryList is not ported yet, so [computedEntries]
  /// is that method itself: it must return one entry per day in `[from, to]`,
  /// ordered newest-first, exactly like `EntryList.getByInterval`.
  void recompute({
    required Frequency frequency,
    required bool isNumerical,
    required NumericalHabitType numericalHabitType,
    required double targetValue,
    required List<Entry> Function(LocalDate from, LocalDate to) computedEntries,
    required LocalDate from,
    required LocalDate to,
  }) {
    _map.clear();
    var rollingSum = 0.0;
    var numerator = frequency.numerator;
    var denominator = frequency.denominator;
    final freq = frequency.toDouble();
    final values = computedEntries(from, to).map((e) => e.value).toList();
    final isAtMost = numericalHabitType == NumericalHabitType.atMost;

    // For non-daily boolean habits, we double the numerator and the denominator
    // to smooth out irregular repetition schedules (for example, weekly habits
    // performed on different days of the week)
    if (!isNumerical && freq < 1.0) {
      numerator *= 2;
      denominator *= 2;
    }

    final int? halfLife = growthHalfLifeDays;
    var previousValue =
        (isNumerical && isAtMost && halfLife == null) ? 1.0 : 0.0;
    for (var i = 0; i < values.length; i++) {
      final offset = values.length - i - 1;
      if (isNumerical) {
        rollingSum += max(0, values[offset]);
        if (offset + denominator < values.length) {
          rollingSum -= max(0, values[offset + denominator]);
        }

        final normalizedRollingSum = rollingSum / 1000;
        if (values[offset] != Entry.skip) {
          final double percentageCompleted;
          if (!isAtMost) {
            if (targetValue > 0) {
              percentageCompleted =
                  min(1.0, normalizedRollingSum / targetValue);
            } else {
              percentageCompleted = 1.0;
            }
          } else {
            if (targetValue > 0) {
              percentageCompleted =
                  (1 - ((normalizedRollingSum - targetValue) / targetValue))
                      .clamp(0.0, 1.0)
                      .toDouble();
            } else {
              percentageCompleted = normalizedRollingSum > 0 ? 0.0 : 1.0;
            }
          }

          // Срыв делит оценку пополам. Шагом порта половину не выразить: он
          // аффинный, previousValue * multiplier + pct * (1 - multiplier), и
          // при multiplier 0.948078 один день не может опустить оценку больше
          // чем на 5.2% — ни при каком значении дня и ни при какой цели.
          //
          // Только при окне в один день. `normalizedRollingSum` есть сумма за
          // `denominator` дней, и делить по ней можно, лишь когда она есть
          // значение самого дня. При 1/7 одна запись держится в окне семь
          // дней и была бы наказана семь раз (1/128), а тройка `Entry.skip`,
          // попадающая в сумму выше по циклу, при допуске 0 сама читалась бы
          // срывом. Частота приходит и из восстановленного файла, поэтому
          // охрана стоит здесь, у арифметики, а не только на пути создания.
          // Отказ безопасен: день уходит шагу порта.
          if (halvesOnLapse &&
              isAtMost &&
              frequency.denominator == 1 &&
              normalizedRollingSum > targetValue) {
            previousValue = previousValue / 2;
          } else if (halfLife != null) {
            // Тот же аффинный шаг, что у порта, но на своём множителе:
            // `Score.compute` считает его из частоты и портовой тринадцатки,
            // а воздержанию нужен свой период (`computed.lapse-score#15`).
            final double m = pow(0.5, 1.0 / halfLife).toDouble();
            previousValue =
                previousValue * m + percentageCompleted * (1 - m);
          } else {
            previousValue =
                Score.compute(freq, previousValue, percentageCompleted);
          }
        }
      } else {
        if (values[offset] == Entry.yesManual) {
          rollingSum += 1.0;
        }
        if (offset + denominator < values.length) {
          if (values[offset + denominator] == Entry.yesManual) {
            rollingSum -= 1.0;
          }
        }
        if (values[offset] != Entry.skip) {
          final percentageCompleted = min(1.0, rollingSum / numerator);
          previousValue =
              Score.compute(freq, previousValue, percentageCompleted);
        }
      }
      final date = from.plus(i);
      _map[date] = Score(date, previousValue);
    }
  }
}
