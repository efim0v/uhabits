import 'package:uhabits_core/uhabits_core.dart' as core;

const int _daysSince2000ToEpoch = 10957;
const int _dayMillis = 86400000;

/// The night a person describes by hand.
///
/// Kept apart from the sheet that collects it so the arithmetic — which day
/// the instants land on, what happens when the times cross midnight, what
/// "actually asleep" defaults to — can be tested without pumping a widget.
class ManualNight {
  const ManualNight({
    required this.day,
    required this.bedMinutes,
    required this.wakeMinutes,
    this.asleepMinutes,
    this.utcOffsetMinutes = 0,
    this.skipped = false,
  });

  /// The day the night closes, as `daysSince2000`: the day they woke up.
  final int day;

  /// Times of day, `[0, 1440)`.
  final int bedMinutes;
  final int wakeMinutes;

  /// Time actually asleep. Null means "as long as they were in bed".
  ///
  /// Optional rather than required because most people know when they lay down
  /// and got up, and only sometimes know they lay awake for an hour. Asking
  /// for it every time would turn a thirty second entry into a puzzle.
  final int? asleepMinutes;

  final int utcOffsetMinutes;

  /// Whether this day should be left out of the reckoning.
  ///
  /// Independent of the times, and deliberately so: a night spent on a plane
  /// has a bedtime and a waking, and both are worth recording — what it does
  /// not have is any bearing on whether the person is keeping their goal.
  /// Saying "skip" is a judgement about the day, not a refusal to describe it.
  final bool skipped;

  /// How long the person was in bed, going forward from bedtime to wake time.
  ///
  /// A bedtime later in the clock than the wake time means the night crossed
  /// midnight, which is the ordinary case rather than the exception.
  int get inBedMinutes {
    final int span = wakeMinutes - bedMinutes;
    return span > 0 ? span : span + 1440;
  }

  /// The night [episode] describes, as the sheet asks for it.
  ///
  /// The inverse of [toEpisode], and it has to exist: without it the sheet
  /// opens on the goal every time, so a person who opens a recorded night only
  /// to mark the day skipped would overwrite what the watch measured with the
  /// times they were aiming for.
  factory ManualNight.fromEpisode(
    core.SleepEpisode episode, {
    required int day,
    bool skipped = false,
  }) {
    final int bed =
        core.localMinutesOf(episode.bedStartMillis, episode.utcOffsetMinutes);
    final int wake =
        core.localMinutesOf(episode.wakeEndMillis, episode.utcOffsetMinutes);
    final int inBed = (wake - bed) > 0 ? wake - bed : wake - bed + 1440;
    return ManualNight(
      day: day,
      bedMinutes: bed,
      wakeMinutes: wake,
      // Left unsaid when it adds nothing: the sheet shows the time in bed by
      // default, and repeating it as an override would make an ordinary night
      // look like one that had been corrected.
      asleepMinutes: episode.asleepMinutes == inBed ? null : episode.asleepMinutes,
      utcOffsetMinutes: episode.utcOffsetMinutes,
      skipped: skipped,
    );
  }

  /// The night as the rest of the app understands one.
  core.SleepEpisode toEpisode() {
    // The wake time belongs to `day`; the bedtime is however long before it.
    final int wakeLocalMillis =
        (day + _daysSince2000ToEpoch) * _dayMillis + wakeMinutes * 60000;
    final int wakeMillis = wakeLocalMillis - utcOffsetMinutes * 60000;
    final int bedMillis = wakeMillis - inBedMinutes * 60000;

    return core.SleepEpisode(
      bedStartMillis: bedMillis,
      wakeEndMillis: wakeMillis,
      // Never longer than the time in bed: a person cannot sleep more than
      // they lay down for, and a slip of the finger should not say they did.
      asleepMinutes: (asleepMinutes ?? inBedMinutes).clamp(0, inBedMinutes),
      utcOffsetMinutes: utcOffsetMinutes,
      // Entered by hand, so the boundaries are what the person said rather
      // than something inferred from when sleep was detected.
      derivedFromAsleep: false,
    );
  }
}
