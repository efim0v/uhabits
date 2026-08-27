import '../models/habit.dart';
import '../models/streak.dart';
import '../time/local_date.dart';

/// Сколько дней прошло без срыва к [asOf] — по умолчанию к сегодняшнему дню.
///
/// Прошедшее время, а не порядковый номер дня: день начала серии даёт ноль,
/// следующий — единицу. «Сорок чистых дней до первого срыва» есть
/// `committedFrom.daysUntil(today)` (`computed.streak#4`).
///
/// Ноль, если [asOf] не входит ни в одну серию: сегодняшний срыв обнуляет счёт
/// сегодня же, а не завтра (`computed.streak#5`).
///
/// Считается по [asOf], а не длиной серии, и это не мелочь. Окно пересчёта
/// уходит на тридцать дней вперёд (`models.habit-recompute#2`), а у вида, для
/// которого молчание есть успех, будущие дни в серию входят все: `length`
/// показывал бы сорок первый день как семьдесят первый (`computed.streak#4`).
///
/// Отдельной функцией, а не методом [StreakList]: «срыв» — слово воздержания,
/// а `StreakList` — портированный класс, общий для всех привычек. Кому нужен
/// не счёт, а дата начала — зовёт `habit.streaks.getCurrent(getToday())`.
int daysWithoutLapse(Habit habit, {LocalDate? asOf}) {
  final LocalDate day = asOf ?? getToday();
  final Streak? current = habit.streaks.getCurrent(day);
  if (current == null) return 0;
  return current.start.daysUntil(day);
}
