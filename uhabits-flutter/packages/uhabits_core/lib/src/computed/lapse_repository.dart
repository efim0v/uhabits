import '../database/database.dart';

/// The journal an abstinence habit is scored from.
///
/// A row says how much of the thing happened on a day, in the unit the habit's
/// definition names. Whether that amount is a lapse is deliberately not stored:
/// the allowance lives in the definition and can be changed afterwards, and a
/// judgement frozen into the row would keep yesterday's allowance for ever.
///
/// Silence is the default state and it is spelled by the absence of a row. A
/// stored zero would be a fact asserting nothing — at the default allowance of
/// zero it satisfies "no more than the allowance" — so [save] refuses it, in
/// the same spirit as a day with nothing to say staying absent for sleep.
///
/// Written the way `DefinitionRepository` is written: the schema is stated once,
/// here, and nothing outside prepares SQL against `Lapses`.
class LapseRepository {
  LapseRepository(this._db);

  final Database _db;

  /// The smallest amount a row may carry.
  ///
  /// One tap is one unit. Zero is not a smaller lapse; it is the absence of
  /// one, and the absence of one is the absence of the row.
  static const int minimumAmount = 1;

  /// How much happened on [day], or null when the journal is silent.
  int? forDay(int habitId, int day) => _db.querySingle<int>(
        'select amount from Lapses where habit = ? and day = ?',
        <String>['$habitId', '$day'],
        (stmt) => stmt.getInt(0),
      );

  /// Момент срыва за [day] в миллисекундах эпохи, или null.
  ///
  /// Null отвечает на два разных вопроса одинаково — срыва в этот день не
  /// было, или он был записан до миграции 104, — и это намеренно: пустота
  /// есть отсутствие момента, а не полночь, чей бы она ни была
  /// (`computed.schema#9`).
  int? momentOf(int habitId, int day) => _db.querySingle<int?>(
        'select at_millis from Lapses where habit = ? and day = ?',
        <String>['$habitId', '$day'],
        (stmt) => stmt.getIntOrNull(0),
      );

  /// The amounts recorded in `[fromDay, toDay]`, keyed by day.
  ///
  /// Days with nothing recorded are simply absent, exactly as in
  /// `SleepSessionRepository.range`: a missing day is not a day of zero, and
  /// inventing a zero here would make it one.
  Map<int, int> range(int habitId, int fromDay, int toDay) {
    final Map<int, int> result = <int, int>{};
    _db.query(
      'select day, amount from Lapses '
      'where habit = ? and day >= ? and day <= ? order by day',
      <String>['$habitId', '$fromDay', '$toDay'],
      (stmt) => result[stmt.getInt(0)] = stmt.getInt(1),
    );
    return result;
  }

  /// Записывает срыв величиной [amount] за [day], перезаписывая прежний.
  ///
  /// [amount] по умолчанию единица, потому что обычный жест — касание, а у
  /// касания своей величины нет.
  ///
  /// [atMillis] — момент срыва в миллисекундах эпохи, от которого считает
  /// счётчик воздержания. Необязателен: журнал знает дни с миграции 103, а
  /// моменты только со 104, и строка без момента — обычное дело
  /// (`computed.schema#9`). Перезапись дня меняет и момент: иначе счётчик
  /// считал бы от срыва, которого человек уже не помнит.
  void save(int habitId, int day,
      {int amount = minimumAmount, int? atMillis}) {
    if (amount < minimumAmount) {
      throw ArgumentError.value(
        amount,
        'amount',
        'a lapse of nothing is silence, and silence is the absent row',
      );
    }
    _db.run(
      'insert into Lapses (habit, day, amount, at_millis) '
      'values (?, ?, ?, ?) '
      'on conflict(habit, day) do update set '
      'amount = excluded.amount, at_millis = excluded.at_millis',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindInt(2, day);
        stmt.bindInt(3, amount);
        if (atMillis == null) {
          stmt.bindNull(4);
        } else {
          stmt.bindInt(4, atMillis);
        }
      },
    );
  }

  /// Takes [day] back out of the journal. Silent when nothing was there, which
  /// is what an undo tap on a clean day is.
  void remove(int habitId, int day) => _db.run(
        'delete from Lapses where habit = ? and day = ?',
        (stmt) {
          stmt.bindInt(1, habitId);
          stmt.bindInt(2, day);
        },
      );

  /// The earliest day with a row, or null when there is none.
  ///
  /// The recompute range of an abstinence habit cannot be taken from its
  /// entries — a habit that records nothing while it is being kept has no
  /// oldest entry — so the ends of the journal are asked of the journal.
  int? firstDay(int habitId) => _db.querySingle<int?>(
        'select min(day) from Lapses where habit = ?',
        <String>['$habitId'],
        (stmt) => stmt.getIntOrNull(0),
      );

  /// The latest day with a row, or null when there is none.
  int? lastDay(int habitId) => _db.querySingle<int?>(
        'select max(day) from Lapses where habit = ?',
        <String>['$habitId'],
        (stmt) => stmt.getIntOrNull(0),
      );
}
