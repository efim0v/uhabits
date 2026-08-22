import 'package:test/test.dart';
import 'package:uhabits_core/src/database/sql_parser.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/SQLParserTest.kt
///
/// Rules #11..#17 restate #1..#10 (merged duplicate id `io.sql-parser`), so the
/// tests below cite both ids wherever they describe the same behavior.
void main() {
  group('persistence.sql-parser', () {
    test('#1/#11 splits on top-level ; trimming and dropping empty commands',
        () {
      final commands = SQLParser.parse('  select 1  ;;  select 2 ; ');
      expect(commands, isA<List<String>>(),
          reason: 'persistence.sql-parser#1 returns a List<String>');
      expect(commands.length, 2,
          reason: 'persistence.sql-parser#1 empty statements are dropped');
      expect(commands, ['select 1', 'select 2'],
          reason: 'persistence.sql-parser#1 each statement is trimmed');

      expect(SQLParser.parse('a;b;c'), ['a', 'b', 'c'],
          reason: 'persistence.sql-parser#11 splits on top level ;');
      expect(SQLParser.parse(';;;'), isEmpty,
          reason:
              'persistence.sql-parser#11 empty statements produce no commands');
    });

    test('#2/#17 basic parsing drops the trailing semicolons', () {
      final commands =
          SQLParser.parse('create table t(a int); insert into t values(1);');
      expect(commands.length, 2, reason: 'persistence.sql-parser#2');
      expect(commands[0], 'create table t(a int)',
          reason: 'persistence.sql-parser#2');
      expect(commands[1], 'insert into t values(1)',
          reason: 'persistence.sql-parser#2');
      expect(commands, ['create table t(a int)', 'insert into t values(1)'],
          reason: 'persistence.sql-parser#17');
    });

    test('#3/#12 -- starts a line comment ended by \\r or \\n', () {
      expect(SQLParser.parse('-- comment\nselect 1;'), ['select 1'],
          reason: 'persistence.sql-parser#3 line comment ends at \\n');
      expect(SQLParser.parse('-- comment\rselect 1;'), ['select 1'],
          reason: 'persistence.sql-parser#3 line comment ends at \\r');
      expect(SQLParser.parse('select 1 -- ; not a separator\n, 2;'),
          ['select 1 , 2'],
          reason:
              'persistence.sql-parser#3 comment content, including the ;, is '
              'discarded');
      // Upstream wart: the terminating newline is discarded too, so the text
      // before and after a line comment is glued together with no separator.
      expect(SQLParser.parse('select 1--c\nselect 2;'), ['select 1select 2'],
          reason: 'persistence.sql-parser#3 the \\n itself is discarded');
      expect(SQLParser.parse('-- c\nselect 1;'), ['select 1'],
          reason: 'persistence.sql-parser#12 line comments are removed');
    });

    test('#4/#12 /* starts a block comment ended by the first */', () {
      expect(SQLParser.parse('select /* comment */ 1;'), ['select 1'],
          reason: 'persistence.sql-parser#4 block comment is discarded');
      expect(SQLParser.parse('select /* ; -- */ 1;'), ['select 1'],
          reason:
              'persistence.sql-parser#4 block comment content is discarded '
              'entirely');
      // Nesting is not supported: the first */ closes the comment.
      expect(SQLParser.parse('select /* a /* b */ 1;'), ['select 1'],
          reason: 'persistence.sql-parser#4 nesting is not supported');
      expect(SQLParser.parse('/* a /* b */ c */ 1;'), ['c */ 1'],
          reason:
              'persistence.sql-parser#4 the first */ ends the comment, the '
              'rest is SQL');
      // Upstream wart: nothing is substituted for the removed comment.
      expect(SQLParser.parse('cre/*x*/ate;'), ['create'],
          reason: 'persistence.sql-parser#12 block comments are removed');
    });

    test('#5/#13 a single quote toggles string mode', () {
      final commands = SQLParser.parse("insert into t values('hello; world');");
      expect(commands.length, 1, reason: 'persistence.sql-parser#5');
      expect(commands[0], "insert into t values('hello; world')",
          reason: 'persistence.sql-parser#5');
      expect(SQLParser.parse("insert into t values('hello; world');"),
          ["insert into t values('hello; world')"],
          reason: 'persistence.sql-parser#13 a ; inside a string does not '
              'split the statement');
      expect(SQLParser.parse("select '-- /* ;' , 2;"), ["select '-- /* ;' , 2"],
          reason:
              'persistence.sql-parser#5 --, /* and ; are literal text inside a '
              'string');
      // The quote characters themselves are kept in the emitted command.
      expect(SQLParser.parse("select 'a';"), ["select 'a'"],
          reason: 'persistence.sql-parser#5 quotes are part of the statement');
      // Closing the string returns to STATE_NONE, so ; splits again.
      expect(SQLParser.parse("select 'a'; select 'b';"),
          ["select 'a'", "select 'b'"],
          reason: 'persistence.sql-parser#13 a closing quote leaves string '
              'mode');
    });

    test('#6/#14 whitespace outside strings collapses to a single space', () {
      expect(SQLParser.parse('select\r\n\t  1  ,\t2;'), ['select 1 , 2'],
          reason: 'persistence.sql-parser#6 runs of whitespace collapse to one '
              'space');
      expect(SQLParser.parse('   \n\t select 1;'), ['select 1'],
          reason: 'persistence.sql-parser#6 statements never start with a '
              'space');
      expect(SQLParser.parse('select 1 \t\r\n ;'), ['select 1'],
          reason: 'persistence.sql-parser#6 each command is trimmed');
      expect(SQLParser.parse('a  b\n\nc;').single.contains('  '), isFalse,
          reason: 'persistence.sql-parser#14 no command contains a double '
              'space');
      expect(SQLParser.parse('a  b\n\nc;'), ['a b c'],
          reason: 'persistence.sql-parser#14 runs of \\r \\n \\t and space '
              'collapse into a single space');
    });

    test('#7 whitespace inside a quoted string is preserved verbatim', () {
      expect(SQLParser.parse("select 'a  \n b';"), ["select 'a  \n b'"],
          reason: 'persistence.sql-parser#7');
      expect(SQLParser.parse("select '\t\r\n';"), ["select '\t\r\n'"],
          reason: 'persistence.sql-parser#7');
    });

    test('#8/#16 non-blank text after the final ; becomes another command', () {
      expect(SQLParser.parse('select 1; select 2'), ['select 1', 'select 2'],
          reason: 'persistence.sql-parser#8');
      expect(SQLParser.parse('select 1;   \n\t '), ['select 1'],
          reason: 'persistence.sql-parser#8 blank trailing text is not '
              'emitted');
      expect(SQLParser.parse('select 1;  select 2  '), ['select 1', 'select 2'],
          reason: 'persistence.sql-parser#16 the trailing command is trimmed');
      expect(SQLParser.parse('select 1; -- trailing comment'), ['select 1'],
          reason: 'persistence.sql-parser#16 trailing text that is empty after '
              'trimming is dropped');
    });

    test('#9/#15 empty input, blank input and a lone comment yield no commands',
        () {
      expect(SQLParser.parse('').length, 0, reason: 'persistence.sql-parser#9');
      expect(SQLParser.parse('  \n  ').length, 0,
          reason: 'persistence.sql-parser#9');
      expect(SQLParser.parse('-- just a comment').length, 0,
          reason: 'persistence.sql-parser#9');
      expect(SQLParser.parse(''), isEmpty,
          reason: 'persistence.sql-parser#15 empty commands are dropped');
      expect(SQLParser.parse('  \n  '), isEmpty,
          reason: 'persistence.sql-parser#15 empty commands are dropped');
      expect(SQLParser.parse('-- just a comment'), isEmpty,
          reason: 'persistence.sql-parser#15 empty commands are dropped');
    });

    test('#10 a script mixing line and block comments yields 2 commands', () {
      const sql = '-- This is a comment\n'
          'create table t(a int);\n'
          '/* block comment */\n'
          'insert into t values(1);';
      final commands = SQLParser.parse(sql);
      expect(commands.length, 2, reason: 'persistence.sql-parser#10');
      expect(commands, ['create table t(a int)', 'insert into t values(1)'],
          reason: 'persistence.sql-parser#10');
    });
  });
}
