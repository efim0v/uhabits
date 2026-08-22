import 'package:test/test.dart';
import 'package:uhabits_core/src/models/frequency.dart';

/// Rules ported from docs/parity/FEATURES.md -> models.frequency
/// Source: uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Frequency.kt
/// (Frequency.kt has no dedicated Kotlin test; cases are written from the rules.)
void main() {
  group('models.frequency', () {
    test('#1/#9 value object of numerator and denominator (both int)', () {
      final f = Frequency(3, 7);
      expect(f.numerator, 3, reason: 'models.frequency#1');
      expect(f.denominator, 7, reason: 'models.frequency#9');
      expect(f.numerator, isA<int>(), reason: 'models.frequency#1');
      expect(f.denominator, isA<int>(), reason: 'models.frequency#9');
      expect(f.toString(), 'Frequency(numerator=3, denominator=7)',
          reason: 'models.frequency#9');
    });

    test('#2/#10 numerator == denominator normalises to exactly 1/1', () {
      final two = Frequency(2, 2);
      expect(two.numerator, 1, reason: 'models.frequency#2');
      expect(two.denominator, 1, reason: 'models.frequency#2');

      final seven = Frequency(7, 7);
      expect(seven.numerator, 1, reason: 'models.frequency#10');
      expect(seven.denominator, 1, reason: 'models.frequency#10');
      expect(seven, Frequency(1, 1), reason: 'models.frequency#10');

      final thirty = Frequency(30, 30);
      expect(thirty, Frequency(1, 1), reason: 'models.frequency#10');

      final zero = Frequency(0, 0);
      expect(zero.numerator, 1, reason: 'models.frequency#2');
      expect(zero.denominator, 1, reason: 'models.frequency#2');

      // Non-equal pairs are left exactly as given, never reduced.
      final threeSevenths = Frequency(3, 7);
      expect(threeSevenths.numerator, 3, reason: 'models.frequency#2');
      expect(threeSevenths.denominator, 7, reason: 'models.frequency#2');
      final twoFourths = Frequency(2, 4);
      expect(twoFourths.numerator, 2, reason: 'models.frequency#2');
      expect(twoFourths.denominator, 4, reason: 'models.frequency#2');
      expect(twoFourths == Frequency(1, 2), isFalse,
          reason: 'models.frequency#2');
    });

    test('#3/#11 toDouble() is numerator / denominator as a double', () {
      expect(Frequency(1, 1).toDouble(), 1.0, reason: 'models.frequency#3');
      expect(Frequency(1, 2).toDouble(), 0.5, reason: 'models.frequency#3');
      expect(Frequency(3, 7).toDouble(), closeTo(0.42857142857142855, 1e-15),
          reason: 'models.frequency#11');
      expect(Frequency(3, 7).toDouble(), 3 / 7, reason: 'models.frequency#11');
      expect(Frequency(1, 7).toDouble(), 1 / 7, reason: 'models.frequency#11');
      expect(Frequency(2, 7).toDouble(), 2 / 7, reason: 'models.frequency#11');
      // Normalisation happens first: 7/7 is 1/1, so toDouble() is 1.0.
      expect(Frequency(7, 7).toDouble(), 1.0, reason: 'models.frequency#3');
      // Integer division must not be used: 1/30 is not 0.
      expect(Frequency(1, 30).toDouble(), 1 / 30, reason: 'models.frequency#11');
    });

    test('#4/#12 the four named constants', () {
      expect(Frequency.daily.numerator, 1, reason: 'models.frequency#4');
      expect(Frequency.daily.denominator, 1, reason: 'models.frequency#4');
      expect(Frequency.threeTimesPerWeek.numerator, 3,
          reason: 'models.frequency#4');
      expect(Frequency.threeTimesPerWeek.denominator, 7,
          reason: 'models.frequency#4');
      expect(Frequency.twoTimesPerWeek.numerator, 2,
          reason: 'models.frequency#12');
      expect(Frequency.twoTimesPerWeek.denominator, 7,
          reason: 'models.frequency#12');
      expect(Frequency.weekly.numerator, 1, reason: 'models.frequency#12');
      expect(Frequency.weekly.denominator, 7, reason: 'models.frequency#12');

      expect(Frequency.daily, Frequency(1, 1), reason: 'models.frequency#4');
      expect(Frequency.threeTimesPerWeek, Frequency(3, 7),
          reason: 'models.frequency#4');
      expect(Frequency.twoTimesPerWeek, Frequency(2, 7),
          reason: 'models.frequency#12');
      expect(Frequency.weekly, Frequency(1, 7), reason: 'models.frequency#12');
    });

    test('#5 constants are immutable, so sharing them cannot alias', () {
      // Kotlin's Frequency has `var` fields, so `habit.frequency =
      // Frequency.DAILY` hands out the one shared instance and a later
      // mutation would corrupt the constant. The Dart port is immutable
      // instead: there is no setter to call, and the constant survives being
      // handed around.
      final a = Frequency.daily;
      final b = Frequency.daily;
      expect(identical(a, b), isTrue, reason: 'models.frequency#5');

      // Re-reading a constant after other frequencies have been built still
      // yields the original values.
      Frequency(5, 9);
      Frequency(2, 2);
      expect(Frequency.daily.numerator, 1, reason: 'models.frequency#5');
      expect(Frequency.daily.denominator, 1, reason: 'models.frequency#5');
      expect(Frequency.weekly.numerator, 1, reason: 'models.frequency#5');
      expect(Frequency.weekly.denominator, 7, reason: 'models.frequency#5');

      // A freshly built equal frequency is a distinct object, so callers that
      // build their own never share storage with the constant.
      final fresh = Frequency(1, 7);
      expect(identical(fresh, Frequency.weekly), isFalse,
          reason: 'models.frequency#5');
      expect(fresh, Frequency.weekly, reason: 'models.frequency#5');
    });

    test('#6 equality is structural on (numerator, denominator)', () {
      expect(Frequency(3, 7) == Frequency(3, 7), isTrue,
          reason: 'models.frequency#6');
      expect(Frequency(3, 7).hashCode, Frequency(3, 7).hashCode,
          reason: 'models.frequency#6');
      expect(Frequency(3, 7) == Frequency(2, 7), isFalse,
          reason: 'models.frequency#6');
      expect(Frequency(1, 7) == Frequency(1, 30), isFalse,
          reason: 'models.frequency#6');

      // After normalisation, every n/n is equal to 1/1 and hashes alike.
      expect(Frequency(7, 7) == Frequency(1, 1), isTrue,
          reason: 'models.frequency#6');
      expect(Frequency(7, 7).hashCode, Frequency(1, 1).hashCode,
          reason: 'models.frequency#6');
      expect(Frequency(0, 0) == Frequency.daily, isTrue,
          reason: 'models.frequency#6');

      // Usable as a set/map key.
      final set = {Frequency(3, 7), Frequency(3, 7), Frequency(7, 7)};
      expect(set.length, 2, reason: 'models.frequency#6');
      expect(set.contains(Frequency.daily), isTrue,
          reason: 'models.frequency#6');
      expect(set.contains(Frequency.threeTimesPerWeek), isTrue,
          reason: 'models.frequency#6');
    });
  });
}
