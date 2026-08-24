/// One night: when the person went to bed, when they got up, and how much of
/// the time in between they were actually asleep.
///
/// The three are stored separately on purpose. Being in bed at 23:00, falling
/// asleep at 02:00 and getting up at 07:00 is a punctual night with a short
/// one — a distinction that collapses the moment sleep is derived from the
/// span between the boundaries.
class SleepEpisode {
  const SleepEpisode({
    required this.bedStartMillis,
    required this.wakeEndMillis,
    required this.asleepMinutes,
    required this.utcOffsetMinutes,
    this.derivedFromAsleep = false,
    this.sourceId = '',
  });

  /// Going to bed, as an instant in UTC milliseconds.
  final int bedStartMillis;

  /// Getting up, as an instant in UTC milliseconds.
  final int wakeEndMillis;

  /// Time actually asleep. Never derived from the two boundaries.
  final int asleepMinutes;

  /// The UTC offset in force when the person woke up.
  final int utcOffsetMinutes;

  /// The data held no in-bed boundaries, so they were taken from the sleep
  /// itself. Bedtime then means "fell asleep" rather than "lay down".
  final bool derivedFromAsleep;

  /// Bundle id of the app that recorded this night; empty when entered by hand.
  final String sourceId;

  /// Time between going to bed and getting up. Not the same as [asleepMinutes]
  /// and never used in its place.
  int get inBedMinutes => (wakeEndMillis - bedStartMillis) ~/ 60000;

  SleepEpisode copyWith({
    int? bedStartMillis,
    int? wakeEndMillis,
    int? asleepMinutes,
    int? utcOffsetMinutes,
    bool? derivedFromAsleep,
    String? sourceId,
  }) =>
      SleepEpisode(
        bedStartMillis: bedStartMillis ?? this.bedStartMillis,
        wakeEndMillis: wakeEndMillis ?? this.wakeEndMillis,
        asleepMinutes: asleepMinutes ?? this.asleepMinutes,
        utcOffsetMinutes: utcOffsetMinutes ?? this.utcOffsetMinutes,
        derivedFromAsleep: derivedFromAsleep ?? this.derivedFromAsleep,
        sourceId: sourceId ?? this.sourceId,
      );

  @override
  bool operator ==(Object other) =>
      other is SleepEpisode &&
      other.bedStartMillis == bedStartMillis &&
      other.wakeEndMillis == wakeEndMillis &&
      other.asleepMinutes == asleepMinutes &&
      other.utcOffsetMinutes == utcOffsetMinutes &&
      other.derivedFromAsleep == derivedFromAsleep &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(bedStartMillis, wakeEndMillis, asleepMinutes,
      utcOffsetMinutes, derivedFromAsleep, sourceId);

  @override
  String toString() => 'SleepEpisode(bed: $bedStartMillis, '
      'wake: $wakeEndMillis, asleep: $asleepMinutes min)';
}

/// Minutes from midnight for an instant read in a given UTC offset.
///
/// Always lands in `[0, 1440)`, including for negative offsets, where Dart's
/// remainder would otherwise go negative.
int localMinutesOf(int millis, int utcOffsetMinutes) {
  final int total = (millis ~/ 60000) + utcOffsetMinutes;
  final int remainder = total % 1440;
  return remainder < 0 ? remainder + 1440 : remainder;
}
