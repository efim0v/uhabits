import '../models/habit.dart';
import '../models/streak.dart';
import '../time/local_date.dart';
import 'days_without_lapse.dart';
import 'streak_duration.dart';

/// Предел, которым берётся весь список серий.
///
/// `StreakList.getBest` отдаёт `limit` самых длинных, отсортированных от
/// новой к старой. Своего «отдай все» у него нет — Kotlin наружу отдаёт
/// только лучшие, — поэтому предел берётся заведомо больше любого мыслимого
/// числа серий.
const int _allStreaks = 1 << 30;

/// Текущая серия воздержания в сравнении с лучшей и с прошлой.
///
/// Все три длины — в прошедших полных сутках (`computed.streak#8`), поэтому
/// число на карточке серий и число в счётчике совпадают по построению, а не
/// по совпадению.
class AbstinenceStreaks {
  const AbstinenceStreaks({
    required this.currentDays,
    required this.bestDays,
    required this.previousDays,
  });

  /// Сколько суток идёт нынешнее воздержание. Ноль, если сорвался сегодня.
  final int currentDays;

  /// Лучшая серия за всю историю привычки, или null, если серий нет вовсе.
  final int? bestDays;

  /// Серия, оборвавшаяся перед нынешней, или null для первой попытки.
  final int? previousDays;

  /// Есть ли рекорд, с которым можно сравнивать.
  ///
  /// Серий может не быть вовсе: привычка, заведённая и сорванная в один день,
  /// не оставляет ни одной. А у заведённой сегодня и не сорванной единственная
  /// серия длится ноль суток. В обоих случаях сравнивать не с чем, и Overview
  /// не рисует строку сравнения вовсе — ровно как не рисует её первой попытке
  /// (`computed.streak#12`).
  bool get hasRecord => (bestDays ?? 0) > 0;

  /// Нынешняя серия и есть рекорд.
  ///
  /// Показывается словом «рекорд» вместо ста процентов: сто процентов от
  /// самого себя — это не новость, а рекорд — новость. Ноль прожитых суток
  /// рекордом не бывает: человеку, продержавшемуся нисколько, читать про
  /// рекорд нечего (`computed.streak#12`).
  bool get currentIsBest => hasRecord && currentDays >= bestDays!;

  /// Доля от рекорда, или null, когда сравнивать не с чем.
  double? get shareOfBest {
    final int? best = bestDays;
    if (best == null || best == 0) return null;
    return currentDays / best;
  }

  /// Доля от прошлой попытки. Больше единицы значит «уже дольше».
  double? get shareOfPrevious {
    final int? previous = previousDays;
    if (previous == null || previous == 0) return null;
    return currentDays / previous;
  }
}

/// Собирает три длины для привычки-воздержания.
AbstinenceStreaks abstinenceStreaksOf(Habit habit, {LocalDate? asOf}) {
  final LocalDate day = asOf ?? getToday();
  final List<Streak> newestFirst = habit.streaks.getBest(_allStreaks);
  final Streak? current = habit.streaks.getCurrent(day);

  // `getCurrent` отвечает null, когда сегодня в серию не входит — то есть
  // когда человек сорвался сегодня. Тогда прошлой считается самая новая
  // из списка: та, что только что оборвалась.
  final int skip = current == null ? 0 : 1;
  final Streak? previous =
      newestFirst.length > skip ? newestFirst[skip] : null;

  int? best;
  for (final Streak streak in newestFirst) {
    final int days = elapsedDaysOf(streak, asOf: day);
    if (best == null || days > best) best = days;
  }

  return AbstinenceStreaks(
    currentDays: daysWithoutLapse(habit, asOf: day),
    bestDays: best,
    previousDays: previous == null ? null : elapsedDaysOf(previous, asOf: day),
  );
}
