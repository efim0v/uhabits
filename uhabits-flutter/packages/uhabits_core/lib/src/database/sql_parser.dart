/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/SQLParser.kt
///
/// Splits a SQL script into individual statements with a small character state
/// machine. Ported character by character, warts included:
///
///  * Comments are removed without substituting anything, so `cre/*x*/ate`
///    parses as the single token `create`, and the `\n` that terminates a line
///    comment is swallowed as well.
///  * Block comments do not nest; the first `*/` closes the comment.
///  * There is no escape handling inside strings — every `'` toggles string
///    mode, so `'it''s'` leaves and re-enters the string.
class SQLParser {
  SQLParser._();

  static const int _stateNone = 0;
  static const int _stateString = 1;
  static const int _stateComment = 2;
  static const int _stateCommentBlock = 3;

  /// Parses [input] into the list of SQL statements it contains.
  static List<String> parse(String input) {
    final commands = <String>[];
    final sb = StringBuffer();
    // Kotlin indexes into the StringBuilder to look at its last character;
    // Dart's StringBuffer is write-only, so we track it as we append.
    String? sbLast;
    void append(String c) {
      sb.write(c);
      sbLast = c;
    }

    void clear() {
      sb.clear();
      sbLast = null;
    }

    var state = _stateNone;
    var i = 0;
    while (i < input.length) {
      final c = input[i];
      if (state == _stateCommentBlock) {
        if (c == '*' && i + 1 < input.length && input[i + 1] == '/') {
          state = _stateNone;
          i += 2;
          continue;
        }
        i++;
        continue;
      } else if (state == _stateComment) {
        if (c == '\r' || c == '\n') {
          state = _stateNone;
        }
        i++;
        continue;
      } else if (state == _stateNone &&
          c == '/' &&
          i + 1 < input.length &&
          input[i + 1] == '*') {
        state = _stateCommentBlock;
        i += 2;
        continue;
      } else if (state == _stateNone &&
          c == '-' &&
          i + 1 < input.length &&
          input[i + 1] == '-') {
        state = _stateComment;
        i += 2;
        continue;
      } else if (state == _stateNone && c == ';') {
        final command = sb.toString().trim();
        if (command.isNotEmpty) {
          commands.add(command);
        }
        clear();
        i++;
        continue;
      } else if (state == _stateNone && c == "'") {
        state = _stateString;
      } else if (state == _stateString && c == "'") {
        state = _stateNone;
      }
      if (state == _stateNone || state == _stateString) {
        if (state == _stateNone &&
            (c == '\r' || c == '\n' || c == '\t' || c == ' ')) {
          if (sb.isNotEmpty && sbLast != ' ') {
            append(' ');
          }
        } else {
          append(c);
        }
      }
      i++;
    }
    final remaining = sb.toString().trim();
    if (remaining.isNotEmpty) {
      commands.add(remaining);
    }
    return commands;
  }
}
