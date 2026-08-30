import '../models/habit.dart';
import '../models/streak.dart';
import '../sleep/local_instant.dart';
import '../time/date_utils.dart';
import '../time/local_date.dart';
import 'lapse_repository.dart';

/// Мгновение, с которого идёт нынешнее воздержание, в миллисекундах эпохи.
///
/// Null, когда воздержание не идёт: человек сорвался сегодня
/// (`computed.since#4`).
///
/// Правило одно, и оно короче, чем кажется. Серия начинается на следующий
/// день после срыва, значит срыв лежит на дне `start - 1`:
///
///  * момент этого срыва известен — считаем от него (`computed.since#1`);
///  * момента нет, потому что строка старше миграции 104 или приехала из
///    чужой копии — считаем от полуночи дня `start`, то есть от полуночи
///    ПОСЛЕ дня срыва: это первый момент, про который точно известно, что он
///    был чистым (`computed.since#2`);
///  * срыва там нет вовсе, потому что серия началась с обязательства —
///    считаем от полуночи дня `start` (`computed.since#3`).
///
/// Две последние ветви дают один и тот же ответ, поэтому в коде их одна.
int? abstinenceSinceMillis(
  Habit habit,
  LapseRepository lapses, {
  LocalDate? asOf,
}) {
  final LocalDate day = asOf ?? getToday();
  final Streak? current = habit.streaks.getCurrent(day);
  if (current == null) return null;

  final int? id = habit.id;
  if (id != null) {
    final int? at = lapses.momentOf(id, current.start.daysSince2000 - 1);
    if (at != null) return at;
  }

  // Полночь дня начала серии, в зоне человека: счётчик показывает
  // длительность, и час её начала должен быть тем же часом, каким человек
  // видит смену суток. `start.unixTime` — местное время этой полуночи как
  // если бы она была UTC; `utcInstantOfLocal` находит настоящий момент,
  // который на местных часах читается так же.
  return utcInstantOfLocal(current.start.unixTime, DateUtils.currentTimeZone);
}
