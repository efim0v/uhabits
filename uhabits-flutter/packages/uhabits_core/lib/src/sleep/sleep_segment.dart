/// A stretch of a night as the source recorded it.
enum SleepSegmentKind {
  inBed,
  asleepCore,
  asleepDeep,
  asleepRem,
  asleepUnspecified,
  awake;

  /// Whether this stretch counts toward how long the person actually slept.
  ///
  /// Being in bed does not, and neither does lying awake in the middle of the
  /// night: both are time in bed, which is a different quantity.
  bool get isAsleep =>
      this == asleepCore ||
      this == asleepDeep ||
      this == asleepRem ||
      this == asleepUnspecified;
}

/// One raw stretch from a data source. Carries no interpretation.
class SleepSegment {
  const SleepSegment({
    required this.startMillis,
    required this.endMillis,
    required this.kind,
    required this.sourceId,
    this.utcOffsetMinutes,
  });

  final int startMillis;
  final int endMillis;
  final SleepSegmentKind kind;

  /// Bundle id of the app that recorded it. Several apps commonly record the
  /// same night, so the segments have to say which one they came from.
  final String sourceId;

  /// The offset from UTC the recording device was keeping at the time, in
  /// minutes, or null when the source did not say.
  ///
  /// A night belongs to the clock the person was living by. Reading it later
  /// from a device in another zone must not re-date it: that is not a
  /// correction, it is a fortnight of history rewriting itself the moment a
  /// plane lands.
  final int? utcOffsetMinutes;

  int get durationMinutes => (endMillis - startMillis) ~/ 60000;

  @override
  String toString() =>
      'SleepSegment($kind, $startMillis..$endMillis, $sourceId)';
}
