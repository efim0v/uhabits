/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Frequency.kt
///
/// How often a habit should be performed: [numerator] times every
/// [denominator] days.
///
/// Kotlin declares this as `data class Frequency(var numerator: Int, var
/// denominator: Int)` and exposes the named frequencies as single shared
/// instances, so `habit.frequency = Frequency.DAILY` hands out the very object
/// behind the constant and any later mutation would corrupt it for everyone.
/// This port closes that hole by making the fields final; there is no setter
/// to call, so sharing a constant is safe and no copy-on-assignment is needed.
class Frequency {
  const Frequency._(this.numerator, this.denominator);

  /// Kotlin's `init` block: a frequency of n times every n days is exactly
  /// once per day, so both fields are rewritten to 1. Note that no other
  /// reduction happens: 2/4 stays 2/4.
  factory Frequency(int numerator, int denominator) {
    if (numerator == denominator) {
      return const Frequency._(1, 1);
    }
    return Frequency._(numerator, denominator);
  }

  final int numerator;

  final int denominator;

  double toDouble() => numerator.toDouble() / denominator;

  static const Frequency daily = Frequency._(1, 1);

  static const Frequency threeTimesPerWeek = Frequency._(3, 7);

  static const Frequency twoTimesPerWeek = Frequency._(2, 7);

  static const Frequency weekly = Frequency._(1, 7);

  @override
  bool operator ==(Object other) =>
      other is Frequency &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() =>
      'Frequency(numerator=$numerator, denominator=$denominator)';
}
