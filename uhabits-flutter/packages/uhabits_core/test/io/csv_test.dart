import 'package:test/test.dart';
import 'package:uhabits_core/src/io/csv.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/StringsTest.kt
/// (`testParseCsvLine`), covering
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt.
void main() {
  group('io.csv-line-writer', () {
    test('#1 joins fields with a comma and appends a trailing newline', () {
      expect(csvLine(<String>['a', 'b', 'c']), 'a,b,c\n',
          reason: 'io.csv-line-writer#1 joins fields with "," and appends "\\n"');
      expect(csvLine(<String>['only']), 'only\n',
          reason: 'io.csv-line-writer#1 a single field still gets the trailing '
              'newline and no separator');
      expect(csvLine(<String>[]), '\n',
          reason: 'io.csv-line-writer#1 joining nothing leaves just the '
              'trailing newline');
      expect(csvLine(<String>['Date', 'Value', 'Notes']), 'Date,Value,Notes\n',
          reason: 'io.csv-line-writer#1 header rows follow the same rule');
    });

    test('#2 quotes a field if and only if it contains , " CR or LF', () {
      expect(csvLine(<String>['a,b']), '"a,b"\n',
          reason: 'io.csv-line-writer#2 a comma forces quoting');
      expect(csvLine(<String>['a"b']), '"a""b"\n',
          reason: 'io.csv-line-writer#2 a double quote forces quoting');
      expect(csvLine(<String>['a\nb']), '"a\nb"\n',
          reason: 'io.csv-line-writer#2 a line feed forces quoting');
      expect(csvLine(<String>['a\rb']), '"a\rb"\n',
          reason: 'io.csv-line-writer#2 a carriage return forces quoting');
      // Everything else is left alone: no other separator-looking character
      // triggers quoting.
      expect(csvLine(<String>["a;b\tc'd|e"]), "a;b\tc'd|e\n",
          reason: 'io.csv-line-writer#2 semicolons, tabs, single quotes and '
              'pipes do not force quoting');
      expect(csvLine(<String>['Café · 日本語 🙂']), 'Café · 日本語 🙂\n',
          reason: 'io.csv-line-writer#2 non-ASCII text does not force quoting');
      // Quoting is per field, not per line.
      expect(csvLine(<String>['plain', 'a,b', 'other']), 'plain,"a,b",other\n',
          reason: 'io.csv-line-writer#2 only the offending field is quoted');
    });

    test('#3 doubles every embedded quote before wrapping', () {
      expect(csvLine(<String>['"']), '""""\n',
          reason: 'io.csv-line-writer#3 a lone quote becomes "" inside the '
              'wrapping quotes');
      expect(csvLine(<String>['a"b"c']), '"a""b""c"\n',
          reason: 'io.csv-line-writer#3 every embedded quote is doubled');
      expect(csvLine(<String>['""']), '""""""\n',
          reason: 'io.csv-line-writer#3 already doubled quotes are doubled '
              'again');
      expect(csvLine(<String>['a",b']), '"a"",b"\n',
          reason: 'io.csv-line-writer#3 quotes are doubled even when the comma '
              'is what triggered the quoting');
    });

    test('#4 emits unquoted fields verbatim, including surrounding spaces', () {
      expect(csvLine(<String>['  spaced  ']), '  spaced  \n',
          reason: 'io.csv-line-writer#4 leading and trailing spaces are kept '
              'and do not trigger quoting');
      expect(csvLine(<String>['hello world', 'foo']), 'hello world,foo\n',
          reason: 'io.csv-line-writer#4 inner spaces are emitted verbatim');
      expect(csvLine(<String>[' ', '\t']), ' ,\t\n',
          reason: 'io.csv-line-writer#4 whitespace-only fields are emitted '
              'verbatim');
    });

    test('#5 emits an empty field as the empty string, never as ""', () {
      expect(csvLine(<String>['']), '\n',
          reason: 'io.csv-line-writer#5 a single empty field yields just the '
              'newline');
      expect(csvLine(<String>['a', '', 'b']), 'a,,b\n',
          reason: 'io.csv-line-writer#5 an empty field between two others is '
              'emitted as nothing');
      expect(csvLine(<String>['', '', '']), ',,\n',
          reason: 'io.csv-line-writer#5 empty fields are never written as '
              'a quoted empty string');
    });

    test('#6 matches the documented examples', () {
      expect(csvLine(<String>['a', 'b']), 'a,b\n',
          reason: 'io.csv-line-writer#6 csvLine(["a","b"]) == "a,b\\n"');
      expect(csvLine(<String>['x,y']), '"x,y"\n',
          reason: 'io.csv-line-writer#6 csvLine(["x,y"]) == "\\"x,y\\"\\n"');
      expect(csvLine(<String>['say "hi"']), '"say ""hi"""\n',
          reason: 'io.csv-line-writer#6 csvLine(["say \\"hi\\""]) == '
              '"\\"say \\"\\"hi\\"\\"\\"\\n"');
    });

    test('#7 Habits.csv quotes through csvLine while hand-built combined '
        'lines do not', () {
      // Habits.csv is written by HabitList.writeCSV, which feeds every row
      // through csvLine, so a habit name containing a comma comes out quoted.
      final list = MemoryHabitList();
      final fixtures = HabitFixtures(MemoryModelFactory(), list);
      final habit = fixtures.createEmptyHabit(name: 'Meditate, daily');
      habit.question = 'Did you "meditate" today?';
      list.add(habit);
      final row = list.writeCSV().split('\n')[1];
      expect(row.contains('"Meditate, daily"'), isTrue,
          reason: 'io.csv-line-writer#7 Habits.csv goes through csvLine, so a '
              'name containing a comma is quoted');
      expect(row.contains('"Did you ""meditate"" today?"'), isTrue,
          reason: 'io.csv-line-writer#7 Habits.csv goes through csvLine, so '
              'embedded quotes are doubled');
      // The combined (multi-habit) files instead append each cell followed by
      // the "," delimiter and then a bare "\n", which is exactly what the raw
      // join below produces: no quoting and no escaping at all.
      const cells = <String>['2015-01-25', 'Meditate, daily', '30000'];
      final handBuilt = StringBuffer();
      for (final cell in cells) {
        handBuilt.write(cell);
        handBuilt.write(',');
      }
      handBuilt.write('\n');
      expect(handBuilt.toString(), '2015-01-25,Meditate, daily,30000,\n',
          reason: 'io.csv-line-writer#7 the combined files build lines by hand '
              'and do NOT quote, so an embedded comma is emitted raw');
      expect(handBuilt.toString() == csvLine(cells), isFalse,
          reason: 'io.csv-line-writer#7 the hand-built combined line differs '
              'from what csvLine would have produced');
    });
  });

  group('io.csv-line-parser', () {
    test('#1 splits a line into comma separated fields, honoring quotes', () {
      expect(parseCsvLine('a,b,c'), <String>['a', 'b', 'c'],
          reason: 'io.csv-line-parser#1 returns the comma separated fields');
      expect(parseCsvLine('hello world,foo,bar'),
          <String>['hello world', 'foo', 'bar'],
          reason: 'io.csv-line-parser#1 fields may contain spaces');
      expect(parseCsvLine('"quoted",b'), <String>['quoted', 'b'],
          reason: 'io.csv-line-parser#1 double-quoted fields are honored');
      expect(parseCsvLine('a,b,c'), isA<List<String>>(),
          reason: 'io.csv-line-parser#1 the result is a List<String>');
    });

    test('#2 doubled quotes yield one literal quote; a single quote closes '
        'the quoted section', () {
      expect(parseCsvLine('"a""b"'), <String>['a"b'],
          reason: 'io.csv-line-parser#2 a doubled "" inside quotes yields one '
              'literal quote');
      expect(parseCsvLine('""""'), <String>['"'],
          reason: 'io.csv-line-parser#2 four quotes parse as a single literal '
              'quote');
      expect(parseCsvLine('"ab"cd'), <String>['abcd'],
          reason: 'io.csv-line-parser#2 a single quote ends the quoted section '
              'and parsing continues in the same field');
      expect(parseCsvLine('"a","b"'), <String>['a', 'b'],
          reason: 'io.csv-line-parser#2 the closing quote leaves quoted mode so '
              'the following comma splits fields');
    });

    test('#3 outside quotes, "," ends a field, \'"\' opens a quoted section, '
        'everything else is verbatim', () {
      expect(parseCsvLine('a,b'), <String>['a', 'b'],
          reason: 'io.csv-line-parser#3 outside quotes a comma terminates the '
              'field');
      expect(parseCsvLine('a"b,c"d'), <String>['ab,cd'],
          reason: 'io.csv-line-parser#3 a quote outside quotes begins a quoted '
              'section mid-field, so the comma inside it is literal');
      expect(parseCsvLine('  x \t;|é🙂'), <String>['  x \t;|é🙂'],
          reason: 'io.csv-line-parser#3 every other character, whitespace and '
              'non-ASCII included, is appended verbatim');
      expect(parseCsvLine('a"",b'), <String>['a', 'b'],
          reason: 'io.csv-line-parser#3 an empty quoted section outside quotes '
              'contributes nothing: the second quote merely closes it');
    });

    test('#4 a final field is always emitted', () {
      expect(parseCsvLine(',,'), <String>['', '', ''],
          reason: 'io.csv-line-parser#4 parseCsvLine(",,") == three empty '
              'fields');
      expect(parseCsvLine('single'), <String>['single'],
          reason: 'io.csv-line-parser#4 parseCsvLine("single") == ["single"]');
      expect(parseCsvLine(''), <String>[''],
          reason: 'io.csv-line-parser#4 the empty line still emits one empty '
              'field');
      expect(parseCsvLine('a,'), <String>['a', ''],
          reason: 'io.csv-line-parser#4 a trailing comma emits a final empty '
              'field');
    });

    test('#5 quoted field containing a comma', () {
      expect(parseCsvLine('"has,comma",normal'),
          <String>['has,comma', 'normal'],
          reason: 'io.csv-line-parser#5 parseCsvLine(\'"has,comma",normal\') == '
              "['has,comma', 'normal']");
    });

    test('#6 quoted field containing an escaped quote', () {
      expect(parseCsvLine('"has""quote",x'), <String>['has"quote', 'x'],
          reason: 'io.csv-line-parser#6 parseCsvLine(\'"has""quote",x\') == '
              '[\'has"quote\', \'x\']');
    });

    test('#7 newlines inside quotes are preserved', () {
      expect(parseCsvLine('a,"line\nbreak",b'),
          <String>['a', 'line\nbreak', 'b'],
          reason: 'io.csv-line-parser#7 a line feed inside quotes is kept');
      expect(parseCsvLine('"carriage\rreturn"'), <String>['carriage\rreturn'],
          reason: 'io.csv-line-parser#7 a carriage return inside quotes is '
              'kept');
      // The importer feeds one physical line at a time, so a record split
      // across two lines is NOT reassembled: each half parses on its own, with
      // the unterminated quote of the first half swallowing the rest.
      expect(parseCsvLine('a,"line'), <String>['a', 'line'],
          reason: 'io.csv-line-parser#7 multi-line quoted records are not '
              'reassembled: the first physical line parses alone');
      expect(parseCsvLine('break",b'), <String>['break,b'],
          reason: 'io.csv-line-parser#7 multi-line quoted records are not '
              'reassembled: the second physical line parses alone, and its '
              'leading quote is read as *opening* a quoted section rather than '
              'closing the one from the previous line');
    });

    test('#8 an unterminated quote consumes the rest of the line', () {
      expect(parseCsvLine('"unterminated'), <String>['unterminated'],
          reason: 'io.csv-line-parser#8 an unterminated quote does not throw');
      expect(parseCsvLine('a,"b,c'), <String>['a', 'b,c'],
          reason: 'io.csv-line-parser#8 the rest of the line, commas included, '
              'is swallowed into the last field');
      expect(parseCsvLine('"'), <String>[''],
          reason: 'io.csv-line-parser#8 a lone quote yields a single empty '
              'field');
    });

    test('round trip: parseCsvLine undoes csvLine for single-line fields', () {
      const fields = <String>['a,b', 'say "hi"', '', '  spaced  ', 'plain'];
      final line = csvLine(fields);
      expect(parseCsvLine(line.substring(0, line.length - 1)), fields,
          reason: 'io.csv-line-writer#1 and io.csv-line-parser#1 are inverse '
              'for fields without embedded newlines');
    });
  });
}
