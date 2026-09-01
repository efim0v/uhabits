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
/// Частный случай [abstinenceStreakMillis]: начало той серии, которая идёт
/// сейчас. Серия начинается на следующий день после срыва, значит срыв лежит
/// на дне `start - 1`, а граница суток, которой серия в него упирается, есть
/// полночь дня `start`.
int? abstinenceSinceMillis(
  Habit habit,
  LapseRepository lapses, {
  LocalDate? asOf,
}) {
  final LocalDate day = asOf ?? getToday();
  final Streak? current = habit.streaks.getCurrent(day);
  if (current == null) return null;
  return _startMillis(habit, lapses, current);
}

/// Сколько миллисекунд длится [streak].
///
/// Длительность серии есть разница двух мгновений, и правило на обоих концах
/// одно и то же — то, которым [_boundaryMillis] находит границу чистого
/// времени (`computed.since#8`):
///
///  * начало — там, где кончился срыв, лежащий на дне `start - 1`;
///  * конец — там, где начался срыв, лежащий на дне `end + 1`;
///  * у идущей серии конца ещё нет, и вместо него берётся «сейчас».
///
/// Кончилась серия или идёт, решает **срыв, который её оборвал**, а не
/// сегодняшнее число: серия кончена тогда, когда день `end + 1` есть срыв
/// (`computed.since#10`). Спросить «конец старше сегодня?» было бы короче и
/// было бы неверно: список серий собирается один раз, а «сегодня» переезжает
/// в полночь, и у открытого экрана идущая серия за одну минуту превращалась
/// бы в завершённую — с концом на вчерашнем дне, на котором срыва нет, — и
/// надпись вставала бы на «N дней 00:00» до следующей перерисовки.
///
/// [isLapseValue] — тот самый судья, которым ячейка списка, клетка календаря,
/// кнопка карточки и подпись под счётчиком судят день по его хранимому
/// значению (`computed.abstinence-cell#2`). Он приходит швом, а не пишется
/// здесь заново: у ядра есть половина этого судьи — `isAbstinenceLapse`, — а
/// вторая половина, перевод шкалы и ступеньки `Entry`, живёт на поверхности,
/// и второго такого сравнения в приложении быть не должно.
///
/// У серии, о концах которой журнал молчит, ответ есть ровно число суток от
/// полуночи до полуночи: часы и минуты нулевые, и это не выдумка, а
/// единственное, что про такую серию известно (`computed.since#2`).
///
/// [nowMillis] — тот же крюк, которым читают текущий момент счётчик
/// воздержания и запись момента срыва (`computed.since#7`): подмена часов в
/// тесте обязана двигать все три числа одним поворотом одного винта.
int abstinenceStreakMillis(
  Habit habit,
  LapseRepository lapses,
  Streak streak, {
  required bool Function(int storedValue) isLapseValue,
  int? nowMillis,
}) {
  final int brokenOn = streak.end.daysSince2000 + 1;
  final bool over =
      isLapseValue(habit.computedEntries.get(LocalDate(brokenOn)).value);
  final int to = over
      ? _boundaryMillis(
          habit,
          lapses,
          lapseDay: brokenOn,
          cleanEdgeDay: brokenOn,
        )
      : nowMillis ?? systemCurrentTimeMillis();
  return to - _startMillis(habit, lapses, streak);
}

/// Мгновение, с которого идёт [streak].
int _startMillis(Habit habit, LapseRepository lapses, Streak streak) =>
    _boundaryMillis(
      habit,
      lapses,
      lapseDay: streak.start.daysSince2000 - 1,
      cleanEdgeDay: streak.start.daysSince2000,
    );

/// Граница чистого времени, упирающаяся в срыв на дне [lapseDay], в
/// миллисекундах эпохи.
///
/// Правило короче, чем кажется, и оно одно на оба конца серии:
///
///  * момент этого срыва известен — считаем от него (`computed.since#1`);
///  * момента нет, потому что строка старше миграции 104, приехала из чужой
///    копии или срыв отмечен задним числом (`computed.since#7`), — считаем от
///    полуночи [cleanEdgeDay]: это та граница суток, про которую точно
///    известно, с какой стороны от неё чисто (`computed.since#2`);
///  * срыва там нет вовсе, потому что серия упирается в обязательство, — та
///    же полночь (`computed.since#3`).
///
/// Две последние ветви дают один и тот же ответ, поэтому в коде их одна.
///
/// День срыва читается только тогда, когда он не старше дня обязательства:
/// день обязательства задаёт нижнюю границу окна целиком, в обе стороны, и
/// запись старше него в окно не входит (`computed.commitment#2`). Перенос
/// обязательства вперёд оставляет в журнале срыв, отмеченный до переноса, —
/// его момент по-прежнему лежит в базе, но серия начинается обязательством, а
/// не им, и считать от него значило бы тянуть счёт из-за границы, которую сам
/// человек только что подвинул. На конце серии эта охрана не срабатывает
/// никогда — серия не начинается раньше обязательства, а значит и не
/// кончается раньше, — но второго входа в журнал ради недостижимой ветви не
/// заводится: судья один.
int _boundaryMillis(
  Habit habit,
  LapseRepository lapses, {
  required int lapseDay,
  required int cleanEdgeDay,
}) {
  final int? id = habit.id;
  final int? committedFrom = habit.definition?.committedFrom;
  if (id != null && (committedFrom == null || lapseDay >= committedFrom)) {
    final int? at = lapses.momentOf(id, lapseDay);
    if (at != null) return at;
  }

  // Полночь границы, в зоне человека: и счётчик, и карточка серий показывают
  // длительность, и час её начала должен быть тем же часом, каким человек
  // видит смену суток. `unixTime` — местное время этой полуночи как если бы
  // она была UTC; `utcInstantOfLocal` находит настоящий момент, который на
  // местных часах читается так же.
  return utcInstantOfLocal(
    LocalDate(cleanEdgeDay).unixTime,
    DateUtils.currentTimeZone,
  );
}
