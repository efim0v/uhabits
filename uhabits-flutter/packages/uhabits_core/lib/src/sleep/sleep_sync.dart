import '../computed/day_writer.dart';
import '../models/habit.dart';
import '../time/date_utils.dart';
import '../time/local_date.dart';
import 'sleep_data_source.dart';
import 'sleep_episode.dart';
import 'sleep_episode_merger.dart';
import 'local_instant.dart';
import 'sleep_goal.dart';
import 'sleep_scorer.dart';
import 'sleep_segment.dart';
import 'sleep_session_repository.dart';
import 'timezone_drift.dart';

/// How far back a routine sync reads.
///
/// Not "yesterday": a watch uploads a night hours late, Health data can be
/// edited after the fact, and a phone left behind for a weekend catches up all
/// at once. Reading a fortnight every time is what lets a day heal itself.
const int recentWindowDays = 14;

/// How far back a history is read the first time.
///
/// The fortnight above is for healing, not for history: without this the app
/// simply never asked about anything older, so a person with years of nights
/// in their health store saw a fortnight and no reason for it.
///
/// Two years rather than everything, because a query with no floor is a
/// question with no answer — and because a night from four years ago changes
/// nothing anyone is looking at.
const int historyHorizonDays = 730;

/// Days without data are counted from the day the habit started, but a habit
/// created years ago with two nights recorded should not fold over a decade of
/// nothing. A full recompute starts at the first night on record.
const int _daysSince2000ToEpoch = 10957;

/// Turns raw stretches into scored days.
///
/// Lives in the core, on plain Dart: the platform's only job is to hand over
/// segments, so everything from there to the day's value can be run and tested
/// without a device.
class SleepSync {
  SleepSync({
    required this.repository,
    required this.source,
    TimeZone Function()? timeZone,
    required this.writer,
  }) : _timeZone = timeZone ?? (() => DateUtils.currentTimeZone);

  final SleepSessionRepository repository;
  final SleepDataSource source;

  /// The one door a computed day goes through, and — when the application
  /// built it — the thing that tells the list and the widgets about it.
  ///
  /// Required, with no default, on purpose. A default of `const DayWriter()`
  /// would let a kind be assembled with a door that says nothing: it would
  /// compile, its tests would be green, and its days would land on disk with
  /// the list still showing what it showed before. That is the deviation this
  /// layer just closed, growing back through a defaulted parameter. A caller
  /// that genuinely wants silence — every core test here — writes
  /// `const DayWriter()` and can be read to have chosen it.
  final DayWriter writer;

  final TimeZone Function() _timeZone;

  /// The day a sleep habit is currently on.
  ///
  /// Deliberately not [getToday]. That one carries the app's midnight-delay
  /// preference, which shifts when a day rolls over for ordinary habits. A
  /// sleep habit's day boundary is waking up, and stacking the delay on top of
  /// it would leave two different notions of "day" answering to one name.
  ///
  /// Read through [DateUtils.getLocalTime] rather than [computeToday] so that
  /// the clock a test pins is the clock this sees; `computeToday` goes to the
  /// system clock directly and ignores it.
  LocalDate today() => LocalDate(
        _floorDiv(DateUtils.getLocalTime(), DateUtils.dayLength) -
            _daysSince2000ToEpoch,
      );

  /// Reads the recent window and brings those days up to date.
  ///
  /// The two halves are also available separately — see [readRecent] — for a
  /// caller that has to check, between the reading and the writing, that the
  /// database it is about to write to is still there.
  Future<void> syncRecent(Habit habit) async {
    final RecentNights? nights = await readRecent(habit);
    if (nights != null) applyRecent(nights);
  }

  /// The oldest day this sync should ask the platform about.
  ///
  /// Two jobs in one range. The recent window is re-read every time, because
  /// that is what lets a day heal: a watch uploads a night hours late, and a
  /// record in the health store can be edited after the fact. Everything older
  /// is read exactly once — the first sync that reaches back that far records
  /// how deep it went, and no later sync asks again.
  ///
  /// So a habit that has never been read reaches back [historyHorizonDays],
  /// and one already read to that depth asks only for the fortnight. The
  /// difference is worked out from what is recorded rather than from an event,
  /// so it does not matter whether the habit was made a minute ago or a year
  /// ago, nor whether the app was opened in between: whatever has not been
  /// asked about is what gets asked about.
  int _readFromDay(int habitId, int toDay) {
    final int recent = toDay - recentWindowDays + 1;
    final int horizon = toDay - historyHorizonDays + 1;
    final int? covered = repository.coveredFromDay(habitId);
    if (covered != null && covered <= horizon) return recent;
    return horizon;
  }

  /// Asks the platform what it has for [habit], writing nothing.
  ///
  /// Answers null for a habit with no goal: that is simply a habit that is not
  /// about sleep.
  ///
  /// Split from [applyRecent] because everything slow lives here and
  /// everything that touches the database lives there. A sync spans a
  /// permission sheet and a fortnight of platform reads, and the app can be
  /// torn down while it waits; with the halves apart, the caller gets one seam
  /// to check, and past it there is no await left for a teardown to slip
  /// through.
  Future<RecentNights?> readRecent(Habit habit) async {
    final SleepGoal? goal = repository.goalFor(habit.id!);
    if (goal == null) return null;

    // Without this the platform never asks, `readSegments` answers with
    // nothing for ever, and the automatic half of the feature is dead while
    // looking like a person who simply has no nights recorded.
    //
    // Safe to call on every sync: the system shows its sheet once and answers
    // silently afterwards, and a refusal is an answer the habit works with.
    // Not safe to call where there is no store — that is not a question that
    // gets a different answer the tenth time it is put.
    if (source.hasHealthStore && !await source.isAuthorized()) {
      await source.requestAuthorization();
    }

    final int toDay = today().daysSince2000;
    final int fromDay = _readFromDay(habit.id!, toDay);

    // The window starts a day early: the night that closes `fromDay` began the
    // evening before.
    final List<SleepSegment> segments = await source.readSegments(
      _startOfDayMillis(fromDay - 1),
      _startOfDayMillis(toDay + 1),
    );

    return RecentNights(
      habit: habit,
      goal: goal,
      segments: segments,
      fromDay: fromDay,
      toDay: toDay,
    );
  }

  /// Writes down what [readRecent] found. Synchronous from end to end.
  void applyRecent(RecentNights nights) {
    _store(nights.habit, nights.goal, nights.segments);
    recomputeDays(nights.habit, nights.fromDay, nights.toDay);
    // Recorded only once the nights are stored: a read that was thrown away
    // between the two halves must not count as covered, or the days it would
    // have brought are never asked for again.
    repository.widenCoverage(nights.habit.id!, nights.fromDay);
  }

  /// Stores the nights found in [segments], newest wins on a tie.
  void _store(Habit habit, SleepGoal goal, List<SleepSegment> segments) {
    final List<SleepEpisode> episodes = splitIntoEpisodes(
      segments,
      mergeGapMinutes: goal.mergeGapMinutes,
      utcOffsetAt: _utcOffsetMinutesAt,
    );

    // A window can hold a nap and the night it sits beside, and both land on
    // the same day. The night wins, by the same measure that picks a night's
    // main chain: whichever holds more sleep.
    final byDay = <int, SleepEpisode>{};
    for (final SleepEpisode episode in episodes) {
      final int day = wakeDayOf(episode);
      final SleepEpisode? existing = byDay[day];
      if (existing == null || episode.asleepMinutes > existing.asleepMinutes) {
        byDay[day] = episode;
      }
    }

    for (final MapEntry<int, SleepEpisode> entry in byDay.entries) {
      repository.upsert(habit.id!, entry.key, entry.value, manual: false);
    }
  }

  /// The day a night closes: the local date the person woke up.
  int wakeDayOf(SleepEpisode episode) {
    final int localMillis =
        episode.wakeEndMillis + episode.utcOffsetMinutes * 60000;
    return _floorDiv(localMillis, DateUtils.dayLength) - _daysSince2000ToEpoch;
  }

  /// Rescores `[fromDay, toDay]` from the nights on record.
  ///
  /// A day with no night is left untouched — no entry written, none removed.
  /// An absent entry already scores zero, and writing that zero down would
  /// freeze it: a watch that uploads two days late could no longer heal the
  /// day, and neither could an edit in Health.
  void recomputeDays(Habit habit, int fromDay, int toDay) {
    final SleepGoal? goal = repository.goalFor(habit.id!);
    if (goal == null || !goal.isConfigured) return;
    if (toDay < fromDay) return;

    final int firstNight = repository.firstDay(habit.id!) ?? fromDay;
    // Drift is a fold over the whole history, so it has to start where the
    // history does, not where this window does.
    final Map<int, int> offsets = effectiveOffsets(
      firstDay: firstNight,
      lastDay: toDay,
      observedByDay: repository.observedOffsets(habit.id!, firstNight, toDay),
      homeOffsetMinutes: goal.homeUtcOffsetMinutes,
      ratePerDayMinutes: goal.adaptationMinutesPerDay,
    );

    final Map<int, SleepEpisode> nights =
        repository.range(habit.id!, fromDay, toDay);
    // Scored first, written second. `DayWriter` owns the rules the write has
    // to keep — a day the person marked as not applicable stays that way even
    // though a night is on record for it, the note survives, an unchanged
    // value is not rewritten — and, since the run is handed over whole, it
    // also owns the recompute and the one announcement that follow it.
    final Map<int, int?> scored = <int, int?>{};
    for (final MapEntry<int, SleepEpisode> night in nights.entries) {
      final SleepBreakdown? breakdown = scoreNight(
        night.value,
        goal,
        offsets[night.key] ?? goal.homeUtcOffsetMinutes,
      );
      if (breakdown == null) continue;
      scored[night.key] = breakdown.storedValue;
    }
    writer.writeDays(habit, scored);
  }

  /// Rescores every day the habit has a night for.
  ///
  /// Changing a goal changes what every past night was worth. Rescoring only
  /// from today forward would leave the history a mixture of two scales — a
  /// defect that shows up nowhere near the day the goal was edited.
  void recomputeAll(Habit habit) {
    final int? first = repository.firstDay(habit.id!);
    final int? last = repository.lastDay(habit.id!);
    if (first == null || last == null) return;
    recomputeDays(habit, first, last);
  }

  /// The offset in force right now, for a night being typed in.
  int currentOffsetMinutes() => _utcOffsetMinutesAt(nowMillis());

  /// Now, as a UTC instant.
  ///
  /// The clock a test pins is a local one, and the two differ by an offset
  /// that cannot be looked up at a local value — see [utcInstantOfLocal].
  int nowMillis() => utcInstantOfLocal(DateUtils.getLocalTime(), _timeZone());

  int _utcOffsetMinutesAt(int instantMillis) =>
      _timeZone().getOffset(instantMillis) ~/ 60000;

  int _startOfDayMillis(int daysSince2000) {
    final int localMillis =
        (daysSince2000 + _daysSince2000ToEpoch) * DateUtils.dayLength;
    // Converted through the offset in force at that moment, so a window across
    // a daylight saving change still starts where the day did.
    return utcInstantOfLocal(localMillis, _timeZone());
  }

  static int _floorDiv(int a, int b) {
    final int q = a ~/ b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
  }
}

/// What the platform had, before any of it was written down.
class RecentNights {
  const RecentNights({
    required this.habit,
    required this.goal,
    required this.segments,
    required this.fromDay,
    required this.toDay,
  });

  final Habit habit;
  final SleepGoal goal;
  final List<SleepSegment> segments;
  final int fromDay;
  final int toDay;
}
