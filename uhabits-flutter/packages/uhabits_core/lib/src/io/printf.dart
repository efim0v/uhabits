/// Port of the `format` expect/actual declared in
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt, whose
/// JVM actual (uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaStrings.kt)
/// delegates to `java.lang.String.format` and whose JS actual delegates to the
/// npm `sprintf-js` package.
///
/// Kotlin declares three overloads — `format(String, String)`,
/// `format(String, Int)` and `format(String, Double)`. Dart has no overloading,
/// so there is a single entry point taking an `Object` and dispatching on its
/// runtime type; the three argument types Kotlin accepts are the three this
/// function accepts.
///
/// Only the conversions this codebase actually uses are implemented: `%s`,
/// `%d` and `%f`, with the `-` and `0` flags, a width, a precision, and the
/// `%%` literal escape (`Ring.kt` writes `format("%.0f%%", …)`).
///
/// One deliberate divergence from the JVM actual: `String.format` is called
/// there without an explicit `Locale`, so on a comma-decimal device the CSV
/// export writes `0,2557` instead of `0.2557`. This port is locale
/// independent and always writes a dot, which is what the reference fixtures
/// assume.
library;

/// Formats [arg] into [pattern], `String.format` style.
///
/// [arg] must be a `String` for `%s`, an `int` for `%d`, and a `num` for `%f`.
String format(String pattern, Object arg) {
  final out = StringBuffer();
  var i = 0;
  while (i < pattern.length) {
    final c = pattern[i];
    if (c != '%') {
      out.write(c);
      i++;
      continue;
    }
    i++;
    if (i >= pattern.length) {
      throw FormatException('Truncated conversion', pattern, i);
    }
    if (pattern[i] == '%') {
      out.write('%');
      i++;
      continue;
    }

    // Flags. Java accepts them in any order; only '-' and '0' are used here.
    var leftJustify = false;
    var zeroPad = false;
    while (i < pattern.length && (pattern[i] == '-' || pattern[i] == '0')) {
      if (pattern[i] == '-') {
        leftJustify = true;
      } else {
        zeroPad = true;
      }
      i++;
    }

    // Width.
    var width = 0;
    while (i < pattern.length && _isDigit(pattern.codeUnitAt(i))) {
      width = width * 10 + (pattern.codeUnitAt(i) - _zeroCodeUnit);
      i++;
    }

    // Precision.
    int? precision;
    if (i < pattern.length && pattern[i] == '.') {
      i++;
      var value = 0;
      while (i < pattern.length && _isDigit(pattern.codeUnitAt(i))) {
        value = value * 10 + (pattern.codeUnitAt(i) - _zeroCodeUnit);
        i++;
      }
      precision = value;
    }

    if (i >= pattern.length) {
      throw FormatException('Truncated conversion', pattern, i);
    }
    final conversion = pattern[i];
    i++;

    out.write(
      _pad(
        _convert(conversion, arg, precision, pattern),
        width,
        leftJustify: leftJustify,
        // '0' is not a valid flag for %s in Java; it is ignored here.
        zeroPad: zeroPad && conversion != 's',
      ),
    );
  }
  return out.toString();
}

String _convert(
  String conversion,
  Object arg,
  int? precision,
  String pattern,
) {
  switch (conversion) {
    case 's':
      var text = '$arg';
      if (precision != null && precision < text.length) {
        text = text.substring(0, precision);
      }
      return text;
    case 'd':
      if (arg is! int) {
        throw ArgumentError.value(
            arg, 'arg', 'Conversion %d requires an int in "$pattern"');
      }
      return arg.toString();
    case 'f':
      if (arg is! num) {
        throw ArgumentError.value(
            arg, 'arg', 'Conversion %f requires a num in "$pattern"');
      }
      // Java's default precision for %f is 6.
      return _fixed(arg.toDouble(), precision ?? 6);
    default:
      throw FormatException('Unsupported conversion %$conversion', pattern);
  }
}

String _pad(
  String text,
  int width, {
  required bool leftJustify,
  required bool zeroPad,
}) {
  if (text.length >= width) return text;
  final padding = width - text.length;
  // Java rejects '-' and '0' together; when both are given, '-' wins here.
  if (leftJustify) return text + ' ' * padding;
  if (zeroPad) {
    if (text.startsWith('-') || text.startsWith('+')) {
      return '${text[0]}${'0' * padding}${text.substring(1)}';
    }
    return '${'0' * padding}$text';
  }
  return '${' ' * padding}$text';
}

/// `%f`, the way `java.util.Formatter` does it.
///
/// `toStringAsFixed` is not a substitute: it rounds the *exact* binary value,
/// so `%.2f` of 2.675 (stored as 2.67499999999999982…) comes out as `2.67`.
/// Java instead takes the shortest decimal representation that round-trips —
/// what `Double.toString` prints, and what `double.toString()` prints here —
/// and rounds *that* HALF_UP, giving `2.68`. Score columns of the exported CSV
/// depend on the difference.
String _fixed(double value, int precision) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value.isNegative ? '-Infinity' : 'Infinity';

  final negative = value.isNegative; // true for -0.0 too, as in Java
  final text = value.abs().toString();

  // Split the shortest representation into digits and a decimal exponent.
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
  final digits = <int>[
    for (var i = 0; i < digitsText.length; i++)
      digitsText.codeUnitAt(i) - _zeroCodeUnit,
  ];
  // Number of digits before the decimal point; may be <= 0 or > digits.length.
  var pointPos = (dot < 0 ? mantissa.length : dot) + exponent;

  // HALF_UP at `precision` fractional digits.
  final keep = pointPos + precision;
  if (keep < digits.length) {
    final roundUp = keep >= 0 && digits[keep] >= 5;
    digits.removeRange(keep < 0 ? 0 : keep, digits.length);
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
  if (precision > 0) {
    out.write('.');
    for (var i = 0; i < precision; i++) {
      final index = pointPos + i;
      out.write(index >= 0 && index < digits.length ? digits[index] : 0);
    }
  }
  return out.toString();
}

const int _zeroCodeUnit = 0x30;

bool _isDigit(int codeUnit) => codeUnit >= _zeroCodeUnit && codeUnit <= 0x39;
