import '../database/database.dart';
import 'sleep_episode.dart';
import 'sleep_goal.dart';

/// The night came from the platform's health store.
const int sourceHealth = 0;

/// The night was typed in by the person.
const int sourceManual = 1;

/// Stores the nights and the goals.
///
/// A habit is a sleep habit exactly when it has a goal here; there is no flag
/// anywhere else saying so, and no third [HabitType] to keep in step.
class SleepSessionRepository {
  SleepSessionRepository(this._db, this._nowMillis);

  final Database _db;

  /// Injected so the repository can be tested without reading the system
  /// clock, and so `updated_at` is reproducible.
  final int Function() _nowMillis;

  /// Stores a night, replacing whatever was there for that day.
  ///
  /// A night from the health store never replaces one entered by hand. The
  /// rule lives here rather than at the call sites because there is more than
  /// one of those, and a rule spread across several of them is a rule that
  /// will be carried to some and not the rest.
  void upsert(int habitId, int day, SleepEpisode episode,
      {required bool manual}) {
    if (!manual && isManual(habitId, day)) return;

    _db.run(
      'insert into SleepSessions '
      '(habit, day, bed_start, wake_end, asleep_minutes, derived_from_asleep, '
      ' utc_offset, source, source_id, updated_at) '
      'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'on conflict(habit, day) do update set '
      ' bed_start = excluded.bed_start, wake_end = excluded.wake_end, '
      ' asleep_minutes = excluded.asleep_minutes, '
      ' derived_from_asleep = excluded.derived_from_asleep, '
      ' utc_offset = excluded.utc_offset, source = excluded.source, '
      ' source_id = excluded.source_id, updated_at = excluded.updated_at',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindInt(2, day);
        // Millisecond instants are bound as longs. The sqlite driver in use
        // makes no distinction — Dart integers are already 64 bit — but the
        // Database interface draws one, and a driver that honours it would
        // truncate these.
        stmt.bindLong(3, episode.bedStartMillis);
        stmt.bindLong(4, episode.wakeEndMillis);
        stmt.bindInt(5, episode.asleepMinutes);
        stmt.bindInt(6, episode.derivedFromAsleep ? 1 : 0);
        stmt.bindInt(7, episode.utcOffsetMinutes);
        stmt.bindInt(8, manual ? sourceManual : sourceHealth);
        stmt.bindText(9, episode.sourceId);
        stmt.bindLong(10, _nowMillis());
      },
    );
  }

  /// Whether the night stored for that day was entered by hand.
  bool isManual(int habitId, int day) =>
      _db.querySingle<int>(
        'select source from SleepSessions where habit = ? and day = ?',
        <String>['$habitId', '$day'],
        (stmt) => stmt.getInt(0),
      ) ==
      sourceManual;

  SleepEpisode? forDay(int habitId, int day) => range(habitId, day, day)[day];

  /// The nights recorded in `[fromDay, toDay]`, keyed by day.
  ///
  /// Days with no night are simply absent: a missing night is not a night of
  /// no sleep, and inventing a zero here would make it one.
  Map<int, SleepEpisode> range(int habitId, int fromDay, int toDay) {
    final result = <int, SleepEpisode>{};
    _db.query(
      'select day, bed_start, wake_end, asleep_minutes, derived_from_asleep, '
      ' utc_offset, source_id from SleepSessions '
      'where habit = ? and day >= ? and day <= ? order by day',
      <String>['$habitId', '$fromDay', '$toDay'],
      (stmt) {
        result[stmt.getInt(0)] = SleepEpisode(
          bedStartMillis: stmt.getLong(1),
          wakeEndMillis: stmt.getLong(2),
          asleepMinutes: stmt.getInt(3),
          utcOffsetMinutes: stmt.getInt(5),
          derivedFromAsleep: stmt.getInt(4) == 1,
          sourceId: stmt.getTextOrNull(6) ?? '',
        );
      },
    );
    return result;
  }

  /// The UTC offsets actually observed, keyed by day.
  ///
  /// Days without a night are absent rather than filled in: deciding what a
  /// silent day inherits belongs to `effectiveOffsets`, which is where that
  /// rule is written down.
  Map<int, int> observedOffsets(int habitId, int fromDay, int toDay) {
    final result = <int, int>{};
    _db.query(
      'select day, utc_offset from SleepSessions '
      'where habit = ? and day >= ? and day <= ?',
      <String>['$habitId', '$fromDay', '$toDay'],
      (stmt) => result[stmt.getInt(0)] = stmt.getInt(1),
    );
    return result;
  }

  /// The earliest day with a night, or null when there is none.
  int? firstDay(int habitId) => _db.querySingle<int?>(
        'select min(day) from SleepSessions where habit = ?',
        <String>['$habitId'],
        (stmt) => stmt.getIntOrNull(0),
      );

  /// The latest day with a night, or null when there is none.
  int? lastDay(int habitId) => _db.querySingle<int?>(
        'select max(day) from SleepSessions where habit = ?',
        <String>['$habitId'],
        (stmt) => stmt.getIntOrNull(0),
      );

  /// Whether this habit is a sleep habit, which is to say whether it has a
  /// goal.
  bool isSleepHabit(int habitId) => goalFor(habitId) != null;

  /// Every habit that has a sleep goal, in id order.
  List<int> sleepHabitIds() {
    final result = <int>[];
    _db.query('select habit from SleepGoals order by habit', const <String>[],
        (stmt) => result.add(stmt.getInt(0)));
    return result;
  }

  /// The oldest day this habit's history has ever been read for, or null when
  /// nothing has been read at all.
  ///
  /// Separate from the oldest night on record, which says only where the data
  /// happens to start. This says how far back the question has been *put* —
  /// so a stretch of nights the person simply did not sleep through is not
  /// asked for again for ever, and a stretch never asked about is.
  int? coveredFromDay(int habitId) => _db.querySingle<int?>(
        'select covered_from_day from SleepGoals where habit = ?',
        <String>['$habitId'],
        (stmt) => stmt.getIntOrNull(0),
      );

  /// Records that the history has now been read back to [day].
  ///
  /// Never moves forward: coverage only ever deepens. A caller that has read
  /// less than what is already recorded leaves it alone.
  void widenCoverage(int habitId, int day) {
    final int? current = coveredFromDay(habitId);
    if (current != null && current <= day) return;
    _db.run(
      'update SleepGoals set covered_from_day = ? where habit = ?',
      (stmt) {
        stmt.bindInt(1, day);
        stmt.bindInt(2, habitId);
      },
    );
  }

  SleepGoal? goalFor(int habitId) => _db.querySingle<SleepGoal>(
        'select bed_minutes, wake_minutes, min_sleep_minutes, weight_sleep, '
        ' weight_bed, weight_wake, half_credit_time_minutes, '
        ' half_credit_sleep_minutes, home_utc_offset, '
        ' adaptation_minutes_per_day, merge_gap_minutes, '
        ' prompt_after_wake_minutes from SleepGoals where habit = ?',
        <String>['$habitId'],
        (stmt) => SleepGoal(
          bedMinutes: stmt.getInt(0),
          wakeMinutes: stmt.getInt(1),
          minSleepMinutes: stmt.getInt(2),
          weightSleep: stmt.getReal(3),
          weightBed: stmt.getReal(4),
          weightWake: stmt.getReal(5),
          halfCreditTimeMinutes: stmt.getInt(6),
          halfCreditSleepMinutes: stmt.getInt(7),
          homeUtcOffsetMinutes: stmt.getInt(8),
          adaptationMinutesPerDay: stmt.getInt(9),
          mergeGapMinutes: stmt.getInt(10),
          promptAfterWakeMinutes: stmt.getInt(11),
        ),
      );

  void saveGoal(int habitId, SleepGoal goal) {
    _db.run(
      'insert into SleepGoals (habit, bed_minutes, wake_minutes, '
      ' min_sleep_minutes, weight_sleep, weight_bed, weight_wake, '
      ' half_credit_time_minutes, half_credit_sleep_minutes, '
      ' home_utc_offset, adaptation_minutes_per_day, merge_gap_minutes, '
      ' prompt_after_wake_minutes) '
      'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'on conflict(habit) do update set '
      ' bed_minutes = excluded.bed_minutes, '
      ' wake_minutes = excluded.wake_minutes, '
      ' min_sleep_minutes = excluded.min_sleep_minutes, '
      ' weight_sleep = excluded.weight_sleep, '
      ' weight_bed = excluded.weight_bed, '
      ' weight_wake = excluded.weight_wake, '
      ' half_credit_time_minutes = excluded.half_credit_time_minutes, '
      ' half_credit_sleep_minutes = excluded.half_credit_sleep_minutes, '
      ' home_utc_offset = excluded.home_utc_offset, '
      ' adaptation_minutes_per_day = excluded.adaptation_minutes_per_day, '
      ' merge_gap_minutes = excluded.merge_gap_minutes, '
      ' prompt_after_wake_minutes = excluded.prompt_after_wake_minutes',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindInt(2, goal.bedMinutes);
        stmt.bindInt(3, goal.wakeMinutes);
        stmt.bindInt(4, goal.minSleepMinutes);
        stmt.bindReal(5, goal.weightSleep);
        stmt.bindReal(6, goal.weightBed);
        stmt.bindReal(7, goal.weightWake);
        stmt.bindInt(8, goal.halfCreditTimeMinutes);
        stmt.bindInt(9, goal.halfCreditSleepMinutes);
        stmt.bindInt(10, goal.homeUtcOffsetMinutes);
        stmt.bindInt(11, goal.adaptationMinutesPerDay);
        stmt.bindInt(12, goal.mergeGapMinutes);
        stmt.bindInt(13, goal.promptAfterWakeMinutes);
      },
    );
  }
}
