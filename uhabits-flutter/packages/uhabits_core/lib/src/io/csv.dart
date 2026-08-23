/// Port of the CSV helpers in
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt.
///
/// Both functions work on a single physical line. The exporter writes one line
/// at a time with [csvLine] and the importer reads one line at a time with
/// [parseCsvLine]; neither knows anything about multi-line records, so a quoted
/// field containing a line break survives export but is *not* reassembled on
/// import — see the note on [parseCsvLine].
library;

/// Splits [line] into its comma separated fields, honoring double quotes.
///
/// Ported character by character from the Kotlin original, including its
/// quirks:
///
///  * Outside quotes a `"` opens a quoted section anywhere in the field, so
///    `a"b,c"d` parses as the single field `ab,cd`.
///  * Inside quotes a doubled `""` yields one literal `"`; any other `"` simply
///    closes the quoted section and parsing continues in the same field.
///  * A final field is always emitted, so `parseCsvLine(",,")` returns three
///    empty strings and `parseCsvLine("")` returns one.
///  * An unterminated quote is not an error: it swallows the rest of the line.
List<String> parseCsvLine(String line) {
  final result = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < line.length) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        sb.write(c);
      }
    } else {
      switch (c) {
        case ',':
          result.add(sb.toString());
          sb.clear();
        case '"':
          inQuotes = true;
        default:
          sb.write(c);
      }
    }
    i++;
  }
  result.add(sb.toString());
  return result;
}

/// Joins [fields] with `,` and appends a trailing `\n`.
///
/// A field is wrapped in double quotes if and only if it contains a `,`, a `"`,
/// a `\n` or a `\r`; when it is, every embedded `"` is doubled first. Fields
/// that need no quoting — the empty field included, which is written as nothing
/// rather than as `""` — are emitted verbatim, leading and trailing spaces and
/// all.
String csvLine(List<String> fields) {
  return '${fields.map((field) {
    if (field.codeUnits.any((c) =>
        c == 0x2c /* , */ ||
        c == 0x22 /* " */ ||
        c == 0x0a /* \n */ ||
        c == 0x0d /* \r */)) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }).join(',')}\n';
}
