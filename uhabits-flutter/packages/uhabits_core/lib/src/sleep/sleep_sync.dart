import '../models/entry.dart';
import '../models/habit.dart';
import '../time/date_utils.dart';
import '../time/local_date.dart';
import 'sleep_data_source.dart';
import 'sleep_episode.dart';
import 'sleep_episode_merger.dart';
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
  }) : _timeZone = timeZone ?? (() => DateUtils.currentTimeZone);

  final SleepSessionRepository repository;
  final SleepDataSource source;
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
  /// Does nothing for a habit with no goal: that is simply a habit that is not
  /// about sleep.
  Future<void> syncRecent(Habit habit) async {
    final SleepGoal? goal = repository.goalFor(habit.id!);
    if (goal == null) return;

    final int toDay = today().daysSince2000;
    final int fromDay = toDay - recentWindowDays + 1;

    // The window starts a day early: the night that closes `fromDay` began the
    // evening before.
    final List<SleepSegment> segments = await source.readSegments(
      _startOfDayMillis(fromDay - 1),
      _startOfDayMillis(toDay + 1),
    );

    _store(habit, goal, segments);
    recomputeDays(habit, fromDay, toDay);
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
    var wrote = false;
    for (final MapEntry<int, SleepEpisode> night in nights.entries) {
      final SleepBreakdown? breakdown = scoreNight(
        night.value,
        goal,
        offsets[night.key] ?? goal.homeUtcOffsetMinutes,
      );
      if (breakdown == null) continue;
      habit.originalEntries
          .add(Entry(LocalDate(night.key), breakdown.storedValue));
      wrote = true;
    }
    if (wrote) habit.recompute();
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
  int currentOffsetMinutes() =>
      _utcOffsetMinutesAt(DateUtils.getLocalTime());

  int _utcOffsetMinutesAt(int instantMillis) =>
      _timeZone().getOffset(instantMillis) ~/ 60000;

  int _startOfDayMillis(int daysSince2000) {
    final int localMillis =
        (daysSince2000 + _daysSince2000ToEpoch) * DateUtils.dayLength;
    // Converted through the offset in force at that moment, so a window across
    // a daylight saving change still starts where the day did.
    return localMillis - _timeZone().getOffset(localMillis);
  }

  static int _floorDiv(int a, int b) {
    final int q = a ~/ b;
    return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
  }
}
