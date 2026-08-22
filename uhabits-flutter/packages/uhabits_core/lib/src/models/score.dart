import 'dart:math';

import '../time/local_date.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Score.kt
class Score {
  const Score(this.date, this.value);

  final LocalDate date;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is Score && other.date == date && other.value == value;

  @override
  int get hashCode => Object.hash(date, value);

  @override
  String toString() => 'Score(date=$date, value=$value)';

  /// Given the frequency of the habit, the previous score, and the value of
  /// the current checkmark, computes the current score for the habit.
  ///
  /// The frequency of the habit is the number of repetitions divided by the
  /// length of the interval. For example, a habit that should be repeated 3
  /// times in 8 days has frequency 3.0 / 8.0 = 0.375.
  static double compute(
    double frequency,
    double previousScore,
    double checkmarkValue,
  ) {
    final multiplier = pow(0.5, sqrt(frequency) / 13.0).toDouble();
    var score = previousScore * multiplier;
    score += checkmarkValue * (1 - multiplier);
    return score;
  }
}
