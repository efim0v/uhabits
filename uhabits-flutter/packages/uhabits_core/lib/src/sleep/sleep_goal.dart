/// The three weights of a sleep goal, rescaled to sum to one.
class SleepWeights {
  const SleepWeights(this.sleep, this.bed, this.wake);

  final double sleep;
  final double bed;
  final double wake;
}

/// What a person is aiming for: a bedtime, a wake time, and a floor on how
/// much sleep counts as enough.
///
/// A value object. It holds no derived state and computes nothing beyond
/// rescaling its own weights, so scoring, drift and stability can each be
/// written and tested against it in isolation.
class SleepGoal {
  const SleepGoal({
    required this.bedMinutes,
    required this.wakeMinutes,
    this.minSleepMinutes = 450,
    this.weightSleep = 0.4,
    this.weightBed = 0.3,
    this.weightWake = 0.3,
    this.halfCreditTimeMinutes = 90,
    this.halfCreditSleepMinutes = 60,
    this.homeUtcOffsetMinutes = 0,
    this.adaptationMinutesPerDay = 60,
    this.mergeGapMinutes = 60,
    this.promptAfterWakeMinutes = 60,
  });

  /// Target bedtime, minutes from midnight.
  final int bedMinutes;

  /// Target wake time, minutes from midnight.
  final int wakeMinutes;

  /// Sleeping less than this is penalised; sleeping more is not.
  final int minSleepMinutes;

  final double weightSleep;
  final double weightBed;
  final double weightWake;

  /// Deviation, in minutes, at which a time component scores half credit.
  final int halfCreditTimeMinutes;

  /// Shortfall, in minutes, at which the duration component scores half credit.
  final int halfCreditSleepMinutes;

  /// The timezone the goal starts in, before any travel.
  final int homeUtcOffsetMinutes;

  /// How fast the goal follows a change of timezone.
  final int adaptationMinutesPerDay;

  /// Sleep separated by no more than this counts as one night.
  final int mergeGapMinutes;

  /// How long after the target wake time to ask for a missing night.
  final int promptAfterWakeMinutes;

  double get weightSum => weightSleep + weightBed + weightWake;

  /// A goal with no weight on anything scores nothing, so days are left alone
  /// rather than scored as failures.
  bool get isConfigured => weightSum > 0;

  /// Weights rescaled to sum to one.
  ///
  /// Rescaling here rather than at every use means only the ratios between the
  /// weights ever matter, and no caller can forget to divide.
  SleepWeights get normalizedWeights {
    final double sum = weightSum;
    if (sum <= 0) return const SleepWeights(0, 0, 0);
    return SleepWeights(weightSleep / sum, weightBed / sum, weightWake / sum);
  }

  SleepGoal copyWith({
    int? bedMinutes,
    int? wakeMinutes,
    int? minSleepMinutes,
    double? weightSleep,
    double? weightBed,
    double? weightWake,
    int? halfCreditTimeMinutes,
    int? halfCreditSleepMinutes,
    int? homeUtcOffsetMinutes,
    int? adaptationMinutesPerDay,
    int? mergeGapMinutes,
    int? promptAfterWakeMinutes,
  }) {
    return SleepGoal(
      bedMinutes: bedMinutes ?? this.bedMinutes,
      wakeMinutes: wakeMinutes ?? this.wakeMinutes,
      minSleepMinutes: minSleepMinutes ?? this.minSleepMinutes,
      weightSleep: weightSleep ?? this.weightSleep,
      weightBed: weightBed ?? this.weightBed,
      weightWake: weightWake ?? this.weightWake,
      halfCreditTimeMinutes:
          halfCreditTimeMinutes ?? this.halfCreditTimeMinutes,
      halfCreditSleepMinutes:
          halfCreditSleepMinutes ?? this.halfCreditSleepMinutes,
      homeUtcOffsetMinutes: homeUtcOffsetMinutes ?? this.homeUtcOffsetMinutes,
      adaptationMinutesPerDay:
          adaptationMinutesPerDay ?? this.adaptationMinutesPerDay,
      mergeGapMinutes: mergeGapMinutes ?? this.mergeGapMinutes,
      promptAfterWakeMinutes:
          promptAfterWakeMinutes ?? this.promptAfterWakeMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SleepGoal &&
      other.bedMinutes == bedMinutes &&
      other.wakeMinutes == wakeMinutes &&
      other.minSleepMinutes == minSleepMinutes &&
      other.weightSleep == weightSleep &&
      other.weightBed == weightBed &&
      other.weightWake == weightWake &&
      other.halfCreditTimeMinutes == halfCreditTimeMinutes &&
      other.halfCreditSleepMinutes == halfCreditSleepMinutes &&
      other.homeUtcOffsetMinutes == homeUtcOffsetMinutes &&
      other.adaptationMinutesPerDay == adaptationMinutesPerDay &&
      other.mergeGapMinutes == mergeGapMinutes &&
      other.promptAfterWakeMinutes == promptAfterWakeMinutes;

  @override
  int get hashCode => Object.hash(
        bedMinutes,
        wakeMinutes,
        minSleepMinutes,
        weightSleep,
        weightBed,
        weightWake,
        halfCreditTimeMinutes,
        halfCreditSleepMinutes,
        homeUtcOffsetMinutes,
        adaptationMinutesPerDay,
        mergeGapMinutes,
        promptAfterWakeMinutes,
      );

  @override
  String toString() => 'SleepGoal(bed: $bedMinutes, wake: $wakeMinutes, '
      'minSleep: $minSleepMinutes)';
}
