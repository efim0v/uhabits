import 'dart:math';

import '../time/local_date.dart';
import 'entry.dart';
import 'habit_type.dart';
import 'streak.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/StreakList.kt
///
/// The Kotlin class is annotated `@Synchronized`; Dart isolates are
/// single-threaded, so the annotations have no counterpart here.
class StreakList {
  final List<Streak> _list = [];

  /// The [limit] longest streaks, ordered from the newest to the oldest.
  ///
  /// Kotlin sorts the whole list by length, then sorts the first [limit]
  /// elements *through a subList view*, which reorders the backing list as
  /// well. Dart's [List.sublist] copies, so the sorted prefix is written back
  /// to reproduce that side effect.
  List<Streak> getBest(int limit) {
    _list.sort((s1, s2) => s2.compareLonger(s1));
    final count = min(_list.length, limit);
    final best = _list.sublist(0, count)
      ..sort((s1, s2) => s2.compareNewer(s1));
    _list.setRange(0, count, best);
    return List.unmodifiable(best);
  }

  /// Серия, накрывающая [day], или null, если день не входит ни в одну.
  ///
  /// Расширение порта: Kotlin отдаёт наружу только [getBest], а счётчик «дней
  /// без срыва» — это именно текущая серия, а не самая длинная
  /// (`computed.streak#3`).
  ///
  /// Перебором, а не по первому элементу: [getBest] переупорядочивает
  /// внутренний список как побочный эффект (`_list.setRange`, см.
  /// `models.streak-best#5`), поэтому после любого его вызова первая серия в
  /// списке — не самая новая.
  Streak? getCurrent(LocalDate day) {
    for (final Streak streak in _list) {
      if (streak.start <= day && day <= streak.end) return streak;
    }
    return null;
  }

  /// Discards every stored streak and rebuilds the list from the computed
  /// entries in `[from, to]`.
  ///
  /// [getEntriesByInterval] is `EntryList.getByInterval` in the original: it
  /// must return one entry per day in `[from, to]`, ordered newest-first.
  /// EntryList is not ported yet, so the callable is passed in directly
  /// (`streaks.recompute(computedEntries.getByInterval, ...)`) rather than the
  /// list itself.
  ///
  /// [silenceQualifies] — расширение порта, выключенное по умолчанию, чтобы
  /// каждая портированная привычка считалась дословно как в Kotlin. Его
  /// включает вид, для которого день без записи и есть успех: воздержание
  /// ничего не пишет, пока его держат (`computed.streak#1`, `#2`).
  void recompute(
    List<Entry> Function(LocalDate from, LocalDate to) getEntriesByInterval,
    LocalDate from,
    LocalDate to,
    bool isNumerical,
    double targetValue,
    NumericalHabitType targetType, {
    bool silenceQualifies = false,
  }) {
    _list.clear();
    final dates = getEntriesByInterval(from, to)
        .where((entry) {
          final value = entry.value;
          if (isNumerical) {
            switch (targetType) {
              case NumericalHabitType.atLeast:
                return value / 1000.0 >= targetValue;
              case NumericalHabitType.atMost:
                // Оригинал исключает UNKNOWN безусловно
                // (`models.streak-computation#3`), и для «не больше двух
                // сигарет» это верно: день, о котором ничего не известно,
                // ничего не подтверждает. Для вида, где молчание и есть
                // успех, — ровно наоборот.
                if (value == Entry.unknown) return silenceQualifies;
                return value / 1000.0 <= targetValue;
            }
          } else {
            return value > 0;
          }
        })
        .map((entry) => entry.date)
        .toList();

    if (dates.isEmpty) return;

    var begin = dates[0];
    var end = dates[0];
    for (var i = 1; i < dates.length; i++) {
      final current = dates[i];
      if (current == begin.minus(1)) {
        begin = current;
      } else {
        _list.add(Streak(begin, end));
        begin = current;
        end = current;
      }
    }
    _list.add(Streak(begin, end));
  }
}
