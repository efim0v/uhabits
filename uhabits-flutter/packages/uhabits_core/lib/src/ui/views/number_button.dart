import '../../gui/canvas.dart';
import '../../gui/color.dart';
import '../../gui/theme.dart';
import '../../gui/view.dart';
import '../../io/printf.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/views/NumberButton.kt,
/// plus the duplicated `Double.toShortString` from
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/NumberButtonView.kt.

/// Kotlin: `fun Double.toShortString(): String`, in
/// `org.isoron.uhabits.core.ui.views`.
///
/// A compact, at-most-four-character rendering of a measurement. The branches
/// are tried in the order written and each one rounds inside *its own* unit,
/// which is where the surprises come from: 99999 renders as "100.0k" (not
/// "100k") and 999999 as "1000k" (not "1.0M"), because the branch is chosen
/// before the rounding happens.
///
/// Also used by the bar-chart labels and by TargetChart.
extension ShortString on double {
  String toShortString() {
    final value = this;
    if (value >= 1e9) return format('%.1fG', value / 1e9);
    if (value >= 1e8) return format('%.0fM', value / 1e6);
    if (value >= 1e7) return format('%.1fM', value / 1e6);
    if (value >= 1e6) return format('%.1fM', value / 1e6);
    if (value >= 1e5) return format('%.0fk', value / 1e3);
    if (value >= 1e4) return format('%.1fk', value / 1e3);
    if (value >= 1e3) return format('%.1fk', value / 1e3);
    if (value >= 1e2) return format('%.0f', value);
    if (value >= 1e1) {
      // Kotlin's `round` is ties-to-even and Dart's `roundToDouble` is
      // ties-away-from-zero, but the comparison below only ever succeeds for
      // an integral value — a tie is never equal to its own rounding — so the
      // two agree here.
      if (value.roundToDouble() == value) return format('%.0f', value);
      return format('%.1f', value);
    }
    if (value.roundToDouble() == value) return format('%.0f', value);
    if ((value * 10).roundToDouble() == value * 10) {
      return format('%.1f', value);
    }
    return format('%.2f', value);
  }

  /// The duplicate that lives in `org.isoron.uhabits.activities.habits.list.views`
  /// (NumberButtonView.kt) and is exercised by
  /// NumberButtonViewTest.testFormatValue.
  ///
  /// The seven largest branches are copied verbatim from the core version; the
  /// three smallest use `DecimalFormat` patterns instead of `%f`, so trailing
  /// zeros are stripped ("#.#" never emits a lone ".0") and ties round
  /// HALF_EVEN rather than HALF_UP. Both versions agree on integral values.
  String toShortStringAndroid() {
    final value = this;
    if (value >= 1e9) return format('%.1fG', value / 1e9);
    if (value >= 1e8) return format('%.0fM', value / 1e6);
    if (value >= 1e7) return format('%.1fM', value / 1e6);
    if (value >= 1e6) return format('%.1fM', value / 1e6);
    if (value >= 1e5) return format('%.0fk', value / 1e3);
    if (value >= 1e4) return format('%.1fk', value / 1e3);
    if (value >= 1e3) return format('%.1fk', value / 1e3);
    if (value >= 1e2) return _decimalFormat(value, 0); // DecimalFormat("#")
    if (value >= 1e1) return _decimalFormat(value, 1); // DecimalFormat("#.#")
    return _decimalFormat(value, 2); // DecimalFormat("#.##")
  }
}

/// One cell of the numerical checkmark panel: the measurement above its unit
/// label, both centred horizontally and stacked 0.6em either side of the
/// vertical centre.
///
/// Like [CheckmarkButton] this core view is stateless and paints no
/// background. The Android NumberButtonView is the richer one: it also handles
/// skips, unknown values, at-most targets, notes indicators, and it trims the
/// unit label to fit — none of which happens here.
class NumberButton extends View {
  NumberButton(
    this.color,
    this.value,
    this.threshold,
    this.units,
    this.theme,
  );

  final Color color;
  final double value;
  final double threshold;
  final String units;
  final Theme theme;

  @override
  void draw(Canvas canvas) {
    final width = canvas.getWidth();
    final height = canvas.getHeight();
    final em = theme.smallTextSize;

    canvas.setColor(
      value >= threshold
          ? color
          : value >= 0.01
              ? theme.mediumContrastTextColor
              : theme.lowContrastTextColor,
    );

    canvas.setFontSize(theme.regularTextSize);
    canvas.setFont(Font.bold);
    canvas.drawText(value.toShortString(), width / 2, height / 2 - 0.6 * em);

    canvas.setFontSize(theme.smallTextSize);
    canvas.setFont(Font.regular);
    canvas.drawText(units, width / 2, height / 2 + 0.6 * em);
  }
}

/// `java.text.DecimalFormat("#"), ("#.#"), ("#.##")`, i.e. at most
/// [maxFractionDigits] fractional digits, no minimum, no grouping.
///
/// Java rounds the *shortest decimal representation* of the double (what
/// `Double.toString` prints, and what `double.toString()` prints here) rather
/// than its exact binary value, using HALF_EVEN plus the two hints
/// FloatingDecimal supplies about which side of that representation the true
/// value falls on. That is why `DecimalFormat("#.#").format(12.35)` is "12.3"
/// while `String.format("%.1f", 12.35)` is "12.4".
String _decimalFormat(double value, int maxFractionDigits) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';

  final negative = value.isNegative; // true for -0.0 too, as in Java
  final abs = value.abs();

  // The shortest representation, split into significant digits and Java's
  // DigitList.decimalAt (the number of digits before the decimal point).
  final text = abs.toString();
  var mantissa = text;
  var exponent = 0;
  final e = text.indexOf('e');
  if (e >= 0) {
    mantissa = text.substring(0, e);
    exponent = int.parse(text.substring(e + 1));
  }
  final dot = mantissa.indexOf('.');
  final digitsText = dot < 0
      ? mantissa
      : mantissa.substring(0, dot) + mantissa.substring(dot + 1);
  var pointPos = (dot < 0 ? mantissa.length : dot) + exponent;
  var digits = <int>[
    for (var i = 0; i < digitsText.length; i++)
      digitsText.codeUnitAt(i) - _zeroCodeUnit,
  ];
  // DigitList keeps significant digits only: no leading and no trailing zeros.
  var lead = 0;
  while (lead < digits.length - 1 && digits[lead] == 0) {
    lead++;
    pointPos--;
  }
  digits = digits.sublist(lead);
  while (digits.length > 1 && digits.last == 0) {
    digits.removeLast();
  }
  if (digits.length == 1 && digits[0] == 0) pointPos = 0;

  // Round to `maxFractionDigits` fractional digits.
  final keep = pointPos + maxFractionDigits;
  if (keep < 0) {
    // Underflow to zero, e.g. 0.0009 at two fractional digits.
    digits = [0];
    pointPos = 0;
  } else if (keep < digits.length) {
    final roundUp = _shouldRoundUp(digits, keep, abs, pointPos);
    digits = digits.sublist(0, keep);
    if (roundUp) {
      var i = digits.length - 1;
      while (i >= 0) {
        digits[i]++;
        if (digits[i] < 10) break;
        digits[i] = 0;
        i--;
      }
      if (i < 0) {
        digits.insert(0, 1);
        pointPos++;
      }
    }
    while (digits.isNotEmpty && digits.last == 0) {
      digits.removeLast();
    }
    if (digits.isEmpty) {
      digits = [0];
      pointPos = 0;
    }
  }

  final out = StringBuffer();
  if (negative) out.write('-');
  if (pointPos <= 0) {
    out.write('0');
  } else {
    for (var i = 0; i < pointPos; i++) {
      out.write(i < digits.length ? digits[i] : 0);
    }
  }
  // Fractional digits, minus the trailing zeros the pattern does not require.
  final fraction = StringBuffer();
  for (var i = 0; i < maxFractionDigits; i++) {
    final index = pointPos + i;
    fraction.write(index >= 0 && index < digits.length ? digits[index] : 0);
  }
  var fractionText = fraction.toString();
  while (fractionText.endsWith('0')) {
    fractionText = fractionText.substring(0, fractionText.length - 1);
  }
  if (fractionText.isNotEmpty) {
    out.write('.');
    out.write(fractionText);
  }
  return out.toString();
}

/// `java.text.DigitList.shouldRoundUp` for RoundingMode.HALF_EVEN.
bool _shouldRoundUp(List<int> digits, int keep, double abs, int pointPos) {
  final digit = digits[keep];
  if (digit > 5) return true;
  if (digit < 5) return false;
  if (keep < digits.length - 1) {
    // The shortest representation carries no trailing zeros, so anything left
    // after the 5 puts the value above the tie.
    for (var i = keep + 1; i < digits.length; i++) {
      if (digits[i] != 0) return true;
    }
    return false;
  }
  final comparison = _compareToShortest(abs, digits, pointPos);
  // FloatingDecimal rounded the last digit up, so the value is below the tie.
  if (comparison < 0) return false;
  // The digits do not represent the value exactly, so it is above the tie.
  if (comparison > 0) return true;
  // An exact tie: round half to even.
  return keep > 0 && digits[keep - 1] % 2 != 0;
}

/// The sign of (exact value of [abs]) - (the decimal [digits] spell out).
///
/// Java gets this from FloatingDecimal for free; here it is recovered by
/// rendering both sides to twenty fractional digits, which is far more
/// resolution than the (at most three significant digit) decimals this
/// formatter ever ties on.
int _compareToShortest(double abs, List<int> digits, int pointPos) {
  const precision = 20;
  final exact = abs.toStringAsFixed(precision);
  final decimal = StringBuffer();
  if (pointPos <= 0) {
    decimal.write('0');
  } else {
    for (var i = 0; i < pointPos; i++) {
      decimal.write(i < digits.length ? digits[i] : 0);
    }
  }
  decimal.write('.');
  for (var i = 0; i < precision; i++) {
    final index = pointPos + i;
    decimal.write(index >= 0 && index < digits.length ? digits[index] : 0);
  }
  final exactParts = exact.split('.');
  final decimalParts = decimal.toString().split('.');
  final integerComparison =
      int.parse(exactParts[0]).compareTo(int.parse(decimalParts[0]));
  if (integerComparison != 0) return integerComparison;
  return exactParts[1].compareTo(decimalParts[1]);
}

const int _zeroCodeUnit = 0x30;
