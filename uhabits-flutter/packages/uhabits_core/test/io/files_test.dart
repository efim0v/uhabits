/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/FilesTest.kt,
/// .../ZipTest.kt and .../StringsTest.kt (the `testFormat` half), covering
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/{Files,Zip,Strings}.kt,
/// their JVM actuals in uhabits-core/src/jvmMain/java/org/isoron/platform/io/
/// and uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/Logging.kt.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/io/logging.dart';
import 'package:uhabits_core/src/io/printf.dart';
import 'package:uhabits_core/src/io/zip.dart';

void main() {
  // ---------------------------------------------------------------------
  // io.printf-format
  // ---------------------------------------------------------------------

  group('io.printf-format', () {
    test('#1 accepts a String, an int and a double argument', () {
      expect(format('hello %s!', 'world'), 'hello world!',
          reason: 'io.printf-format#1 the String overload substitutes %s');
      expect(format('%03d', 5), '005',
          reason: 'io.printf-format#1 the Int overload substitutes %d');
      expect(format('%.4f', 0.5), '0.5000',
          reason: 'io.printf-format#1 the Double overload substitutes %f');
      expect(format('%02d.sql', 9), '09.sql',
          reason: 'io.printf-format#1 %02d is one of the four conversions used '
              'in this domain');
      expect(format('%.1f', 13.419187263), '13.4',
          reason: 'io.printf-format#1 %.1f is one of the four conversions used '
              'in this domain');
    });

    test('#2 reproduces every case of StringsTest.testFormat', () {
      expect(format('hello %s!', 'world'), 'hello world!',
          reason: "io.printf-format#2 format('hello %s!', 'world')");
      expect(format('%3d', 5), '  5',
          reason: "io.printf-format#2 format('%3d', 5) == '  5'");
      expect(format('%03d', 5), '005',
          reason: "io.printf-format#2 format('%03d', 5) == '005'");
      expect(format('%3d', 45), ' 45',
          reason: "io.printf-format#2 format('%3d', 45) == ' 45'");
      expect(format('%3d', 145), '145',
          reason: "io.printf-format#2 format('%3d', 145) == '145'");
      expect(format('%8.2f', 13.419187263), '   13.42',
          reason: "io.printf-format#2 format('%8.2f', 13.419187263)");
      expect(format('%08.2f', 13.419187263), '00013.42',
          reason: "io.printf-format#2 format('%08.2f', 13.419187263)");
      expect(format('%-8.2f', 13.419187263), '13.42   ',
          reason: "io.printf-format#2 format('%-8.2f', 13.419187263)");
    });

    test('#3 always writes a dot as the decimal separator', () {
      // The JVM actual calls String.format without an explicit Locale, so a
      // comma-decimal device writes "0,2557" into the exported CSV. This port
      // is locale-independent and matches the reference fixtures.
      expect(format('%.4f', 0.2557), '0.2557',
          reason: 'io.printf-format#3 the reference fixtures assume a dot '
              'decimal separator; this port is locale-independent');
      expect(format('%.1f', 100.0), '100.0',
          reason: 'io.printf-format#3 the decimal separator never follows a '
              'device locale in this port');
    });

    test('#5 formats scores, targets, positions and migration file names', () {
      expect(format('%.4f', 0.25574123), '0.2557',
          reason: 'io.printf-format#5 score values always use exactly 4 '
              'decimals');
      expect(format('%.4f', 1.0), '1.0000',
          reason: 'io.printf-format#5 score values always use exactly 4 '
              'decimals, even for whole numbers');
      expect(format('%.4f', 0.56785), '0.5679',
          reason: 'io.printf-format#5 score values round the way '
              'java.util.Formatter does — HALF_UP on the shortest decimal '
              "representation, not on the double's exact binary value "
              '(which would give 0.5678)');
      expect(format('%.1f', 200.0), '200.0',
          reason: 'io.printf-format#5 target values always use exactly 1 '
              'decimal');
      expect(format('%.1f', 0.15), '0.2',
          reason: 'io.printf-format#5 target values round the way '
              'java.util.Formatter does (the exact binary value would give '
              '0.1)');
      expect(format('%03d', 1), '001',
          reason: 'io.printf-format#5 positions use %03d');
      expect(format('%03d', 145), '145',
          reason: 'io.printf-format#5 positions use %03d');
      expect(format('%02d.sql', 9), '09.sql',
          reason: 'io.printf-format#5 migration file names use %02d, exactly '
              'as LoopDBImporter does');
      expect(format('%02d.sql', 25), '25.sql',
          reason: 'io.printf-format#5 migration file names use %02d');
    });
  });

  // ---------------------------------------------------------------------
  // io.zip-writer-reader
  // ---------------------------------------------------------------------

  group('io.zip-writer-reader', () {
    Future<Map<String, String>> readZipEntries(Uint8List bytes) async {
      final entries = await ZipReader(bytes).entries();
      return <String, String>{for (final e in entries) e.name: e.content};
    }

    test('#1 starts empty, deflates each entry and closes on toBytes',
        () async {
      final empty = await ZipWriter().toBytes();
      expect(await ZipReader(empty).entries(), isEmpty,
          reason: 'io.zip-writer-reader#1 ZipWriter() is created empty');

      final zip = ZipWriter();
      zip.addEntry('hello.txt', 'Hello, World!');
      final bytes = await zip.toBytes();
      final entries = await readZipEntries(bytes);
      expect(entries.length, 1,
          reason: 'io.zip-writer-reader#1 addEntry appends one entry');
      expect(entries['hello.txt'], 'Hello, World!',
          reason: 'io.zip-writer-reader#1 the entry bytes are '
              'content.toByteArray() (UTF-8)');
      expect(bytes.sublist(8, 10), <int>[8, 0],
          reason: 'io.zip-writer-reader#1 the entry is deflated (local file '
              'header compression method 8)');
      expect(() => zip.addEntry('late.txt', 'x'), throwsStateError,
          reason: 'io.zip-writer-reader#1 toBytes() closes the stream, so no '
              'further entry can be appended');
    });

    test('#2 entry names may contain "/" and no directory entries are created',
        () async {
      final zip = ZipWriter();
      zip.addEntry('a.csv', 'name,value\nfoo,1\n');
      zip.addEntry('subdir/b.csv', 'col1,col2\nbar,2\n');
      zip.addEntry('subdir/c.csv', 'x\n');
      final bytes = await zip.toBytes();

      final entries = await readZipEntries(bytes);
      expect(entries.length, 3,
          reason: 'io.zip-writer-reader#2 no separate directory entry is '
              'created for "subdir/"');
      expect(entries['a.csv'], 'name,value\nfoo,1\n',
          reason: 'io.zip-writer-reader#2 top-level entry round-trips');
      expect(entries['subdir/b.csv'], 'col1,col2\nbar,2\n',
          reason: 'io.zip-writer-reader#2 "/" in the name expresses a folder');
      expect(entries['subdir/c.csv'], 'x\n',
          reason: 'io.zip-writer-reader#2 "/" in the name expresses a folder');
    });

    test('#3 entries() preserves the stored order and decodes UTF-8', () async {
      final zip = ZipWriter();
      zip.addEntry('001 Meditate/Checkmarks.csv', 'a\n');
      zip.addEntry('002 Wake up/Scores.csv', 'b\n');
      zip.addEntry('Habits.csv', 'Position,Name\n');
      final entries = await ZipReader(await zip.toBytes()).entries();

      expect(entries.map((e) => e.name).toList(),
          <String>['001 Meditate/Checkmarks.csv', '002 Wake up/Scores.csv', 'Habits.csv'],
          reason: 'io.zip-writer-reader#3 entries() returns the entries in the '
              "archive's stored order");

      final utf8Zip = ZipWriter();
      utf8Zip.addEntry('acentuação.csv', 'Álinson,ração,日本語\n');
      final utf8Entries = await ZipReader(await utf8Zip.toBytes()).entries();
      expect(utf8Entries.single.name, 'acentuação.csv',
          reason: 'io.zip-writer-reader#3 entry names are decoded as UTF-8');
      expect(utf8Entries.single.content, 'Álinson,ração,日本語\n',
          reason: "io.zip-writer-reader#3 each entry's bytes are decoded as "
              'UTF-8');
    });

    test('#4 repeated content compresses', () async {
      final zip = ZipWriter();
      final large = 'x' * 100000;
      zip.addEntry('large.txt', large);
      final bytes = await zip.toBytes();

      expect(bytes.length < large.length, isTrue,
          reason: 'io.zip-writer-reader#4 a 100_000-character repeated string '
              'produces an archive smaller than the raw content '
              '(${bytes.length} bytes)');
      final entries = await readZipEntries(bytes);
      expect(entries['large.txt'], large,
          reason: 'io.zip-writer-reader#4 the compressed content round-trips');
    });

    test('#5 an empty entry round-trips as the empty string', () async {
      final zip = ZipWriter();
      zip.addEntry('empty.txt', '');
      final entries = await readZipEntries(await zip.toBytes());

      expect(entries.length, 1,
          reason: 'io.zip-writer-reader#5 an entry with empty content is still '
              'an entry');
      expect(entries['empty.txt'], '',
          reason: 'io.zip-writer-reader#5 empty content round-trips as the '
              'empty string');
    });

    test('#6 the reader skips directory entries', () async {
      final zip = ZipWriter();
      zip.addEntry('subdir/', '');
      zip.addEntry('subdir/a.txt', 'a\n');
      final entries = await ZipReader(await zip.toBytes()).entries();

      expect(entries.map((e) => e.name).toList(), <String>['subdir/a.txt'],
          reason: "io.zip-writer-reader#6 entries whose 'dir' flag is true (a "
              'name ending in "/") are skipped when reading');
    });
  });

  // ---------------------------------------------------------------------
  // io.userfile-api
  // ---------------------------------------------------------------------

  group('io.userfile-api', () {
    late Directory tmp;
    late FileOpener fileOpener;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('uhabits_files_test');
      fileOpener = LocalFileOpener(userDataDir: tmp.path);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('#1 exposes the whole UserFile surface', () async {
      final file = fileOpener.openUserFile('test-write-string');
      expect(file.pathString, '${tmp.path}/test-write-string',
          reason: 'io.userfile-api#1 pathString is the resolved absolute path');

      await file.writeString('hello\nworld\n');
      expect(await file.exists(), isTrue,
          reason: 'io.userfile-api#1 exists() reports a written file');
      expect(await file.lines(), <String>['hello', 'world'],
          reason: 'io.userfile-api#1 lines() returns the lines of the file');

      await file.writeBytes(Uint8List.fromList(<int>[0x53, 0x51, 0x4C, 0x69, 0x74, 0x65]));
      expect(await file.readBytes(6), <int>[0x53, 0x51, 0x4C, 0x69, 0x74, 0x65],
          reason: 'io.userfile-api#1 writeBytes/readBytes round-trip raw bytes');

      final dir = fileOpener.openUserFile('nested');
      await dir.mkdirs();
      final child = dir.resolve('inner.txt');
      await child.writeString('x');
      expect((await dir.listFiles())!.map((f) => f.pathString).toList(),
          <String>['${tmp.path}/nested/inner.txt'],
          reason: 'io.userfile-api#1 resolve()/listFiles()/mkdirs() are part of '
              'the UserFile surface');

      await file.delete();
      expect(await file.exists(), isFalse,
          reason: 'io.userfile-api#1 delete() removes the file');
    });

    test('#2 lines() drops the line terminators and throws when missing',
        () async {
      final file = fileOpener.openUserFile('test-lines');
      await file.writeString('hello\nworld\n');
      expect(await file.lines(), <String>['hello', 'world'],
          reason: 'io.userfile-api#2 lines() returns the file split into lines '
              'WITHOUT trailing line terminators');

      await file.writeString('a\r\nb\r\n');
      expect(await file.lines(), <String>['a', 'b'],
          reason: 'io.userfile-api#2 CRLF terminators are dropped too');

      await file.writeString('a\n\nb');
      expect(await file.lines(), <String>['a', '', 'b'],
          reason: 'io.userfile-api#2 an interior blank line is preserved and a '
              'missing final terminator does not add a line');

      final missing = fileOpener.openUserFile('no-such-file');
      await expectLater(missing.lines(), throwsA(isA<FileSystemException>()),
          reason: 'io.userfile-api#2 lines() throws if the file does not exist');
    });

    test('#3 writeString/writeBytes overwrite and create parent directories',
        () async {
      final file = fileOpener.openUserFile('deep/nested/dir/file.txt');
      await file.writeString('first');
      expect(await file.lines(), <String>['first'],
          reason: 'io.userfile-api#3 writeString creates the parent '
              'directories first');
      await file.writeString('second');
      expect(await file.lines(), <String>['second'],
          reason: 'io.userfile-api#3 writeString overwrites the file');

      final bytesFile = fileOpener.openUserFile('deep/other/dir/file.bin');
      await bytesFile.writeBytes(Uint8List.fromList(<int>[1, 2, 3]));
      expect(await bytesFile.readBytes(10), <int>[1, 2, 3],
          reason: 'io.userfile-api#3 writeBytes creates the parent directories '
              'first');
      await bytesFile.writeBytes(Uint8List.fromList(<int>[9]));
      expect(await bytesFile.readBytes(10), <int>[9],
          reason: 'io.userfile-api#3 writeBytes overwrites the file');
    });

    test('#4 readBytes(limit) reads at most limit bytes from the start',
        () async {
      final file = fileOpener.openUserFile('test-read-limit');
      await file.writeBytes(Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]));
      final read = await file.readBytes(3);
      expect(read.length, 3,
          reason: 'io.userfile-api#4 readBytes reads at most limit bytes');
      expect(read, <int>[1, 2, 3],
          reason: 'io.userfile-api#4 readBytes reads from the start of the '
              'file');

      final short = fileOpener.openUserFile('test-read-short');
      await short.writeBytes(Uint8List.fromList(<int>[7, 7]));
      expect(await short.readBytes(64), <int>[7, 7],
          reason: 'io.userfile-api#4 readBytes returns fewer bytes when the '
              'file is shorter than the limit');

      final empty = fileOpener.openUserFile('test-read-empty');
      await empty.writeBytes(Uint8List(0));
      expect(await empty.readBytes(64), isEmpty,
          reason: 'io.userfile-api#4 readBytes returns an empty ByteArray when '
              'the file is empty (the read returns <= 0 bytes)');
    });

    test('#5 resolve(child) resolves the child against this path', () async {
      final dir = fileOpener.openUserFile('backups');
      expect(dir.resolve('2025-01-01.db').pathString,
          '${tmp.path}/backups/2025-01-01.db',
          reason: 'io.userfile-api#5 resolve(child) appends the child to this '
              'path, as java.nio.Path.resolve does');
      expect(dir.resolve('a/b/c').pathString, '${tmp.path}/backups/a/b/c',
          reason: 'io.userfile-api#5 a multi-segment child is appended whole');
      expect(dir.resolve('/etc/hosts').pathString, '/etc/hosts',
          reason: 'io.userfile-api#5 java.nio.Path.resolve returns an absolute '
              'child unchanged');
      expect(dir.resolve('').pathString, '${tmp.path}/backups',
          reason: 'io.userfile-api#5 java.nio.Path.resolve trivially returns '
              'this path for an empty child');
    });

    test('#6 listFiles() returns null unless the path is a directory',
        () async {
      final missing = fileOpener.openUserFile('not-there');
      expect(await missing.listFiles(), isNull,
          reason: 'io.userfile-api#6 listFiles() returns null when the path '
              'does not exist');

      final plain = fileOpener.openUserFile('plain.txt');
      await plain.writeString('x');
      expect(await plain.listFiles(), isNull,
          reason: 'io.userfile-api#6 listFiles() returns null when the path is '
              'not a directory');

      final dir = fileOpener.openUserFile('dir');
      await dir.mkdirs();
      expect(await dir.listFiles(), isEmpty,
          reason: 'io.userfile-api#6 an empty directory lists no children, but '
              'is not null');
      await dir.resolve('a.txt').writeString('a');
      await dir.resolve('b.txt').writeString('b');
      final names = (await dir.listFiles())!
          .map((f) => f.pathString.split('/').last)
          .toList()
        ..sort();
      expect(names, <String>['a.txt', 'b.txt'],
          reason: 'io.userfile-api#6 listFiles() otherwise returns the list of '
              'children');
    });

    test('#7 delete() throws when the file does not exist', () async {
      final file = fileOpener.openUserFile('test-exists');
      await file.writeString('data');
      expect(await file.exists(), isTrue,
          reason: 'io.userfile-api#7 the file exists before it is deleted');
      await file.delete();
      expect(await file.exists(), isFalse,
          reason: 'io.userfile-api#7 delete() removes an existing file');
      await expectLater(file.delete(), throwsA(isA<FileSystemException>()),
          reason: 'io.userfile-api#7 delete() uses Files.delete and throws when '
              'the file does not exist, unlike the interface doc');
    });

    test('#8 FileOpener has exactly two methods, both always succeeding',
        () async {
      final resourceFile = fileOpener.openResourceFile('migrations/09.sql');
      expect(resourceFile, isA<ResourceFile>(),
          reason: 'io.userfile-api#8 openResourceFile(path) is relative to the '
              "assets folder, e.g. 'migrations/09.sql'");
      final userFile = fileOpener.openUserFile('crash.log');
      expect(userFile, isA<UserFile>(),
          reason: 'io.userfile-api#8 openUserFile(path) is relative to the user '
              'data folder');

      expect(await fileOpener.openResourceFile('nope/nope.sql').exists(), isFalse,
          reason: 'io.userfile-api#8 openResourceFile always succeeds even when '
              'the file does not exist');
      expect(await fileOpener.openUserFile('nope.log').exists(), isFalse,
          reason: 'io.userfile-api#8 openUserFile always succeeds even when the '
              'file does not exist');
    });

    test('#9 openUserFile resolves against the user data folder', () async {
      expect(LocalFileOpener().openUserFile('crash.log').pathString,
          '/tmp/crash.log',
          reason: "io.userfile-api#9 on the JVM test platform openUserFile "
              "resolves against '/tmp/'");
      expect(LocalFileOpener().openUserFile('backup/db.db').pathString,
          '/tmp/backup/db.db',
          reason: "io.userfile-api#9 the path is resolved against '/tmp/' as a "
              'whole');
      expect(
          LocalFileOpener(userDataDir: '/data/data/org.isoron.uhabits/files')
              .openUserFile('crash.log')
              .pathString,
          '/data/data/org.isoron.uhabits/files/crash.log',
          reason: 'io.userfile-api#9 the user data folder is configurable, as '
              'Android resolves against context.filesDir');
    });
  });

  // ---------------------------------------------------------------------
  // io.resourcefile-api
  // ---------------------------------------------------------------------

  group('io.resourcefile-api', () {
    late Directory tmp;
    late FileOpener fileOpener;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('uhabits_resource_test');
      Directory('${tmp.path}/assets/main').createSync(recursive: true);
      Directory('${tmp.path}/assets/test').createSync(recursive: true);
      fileOpener = LocalFileOpener(
        userDataDir: '${tmp.path}/user',
        resourceRoots: <String>['${tmp.path}/assets/main', '${tmp.path}/assets/test'],
      );
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('#1 exposes copyTo, lines, exists and toImage', () async {
      final resource = fileOpener.openResourceFile('migrations/09.sql');
      expect(await resource.exists(), isFalse,
          reason: 'io.resourcefile-api#1 exists() is false for a missing '
              'resource');

      File('${tmp.path}/assets/main/migrations/09.sql')
        ..createSync(recursive: true)
        ..writeAsStringSync('CREATE TABLE Habits;\nCREATE TABLE Repetitions;\n');
      expect(await resource.exists(), isTrue,
          reason: 'io.resourcefile-api#1 exists() is true once the resource is '
              'there');
      expect(await resource.lines(),
          <String>['CREATE TABLE Habits;', 'CREATE TABLE Repetitions;'],
          reason: 'io.resourcefile-api#1 lines() returns the lines of the '
              'resource file');

      final dest = fileOpener.openUserFile('copied.sql');
      await resource.copyTo(dest);
      expect(await dest.lines(),
          <String>['CREATE TABLE Habits;', 'CREATE TABLE Repetitions;'],
          reason: 'io.resourcefile-api#1 copyTo(dest) copies the resource into '
              'the user file');

      await expectLater(resource.toImage(), throwsA(isA<UnimplementedError>()),
          reason: 'io.resourcefile-api#1 toImage() is part of the surface; the '
              'core ships no image codec, so it needs a decoder from the host');
    });

    test('#2 copyTo replaces the destination and creates its parents',
        () async {
      File('${tmp.path}/assets/main/greeting.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync('hello\n');
      final resource = fileOpener.openResourceFile('greeting.txt');

      final dest = fileOpener.openUserFile('deep/nested/greeting.txt');
      await resource.copyTo(dest);
      expect(await dest.lines(), <String>['hello'],
          reason: "io.resourcefile-api#2 copyTo creates the destination's "
              'parent directories');

      await dest.writeString('stale content that must go away\n');
      await resource.copyTo(dest);
      expect(await dest.lines(), <String>['hello'],
          reason: 'io.resourcefile-api#2 copyTo replaces the destination if it '
              'already exists (the Java implementation deletes it first)');
    });

    test('#4 assets/main is searched first, assets/test is the fallback',
        () async {
      File('${tmp.path}/assets/test/fixture.csv')
        ..createSync(recursive: true)
        ..writeAsStringSync('from-test\n');
      final resource = fileOpener.openResourceFile('fixture.csv');
      expect(await resource.lines(), <String>['from-test'],
          reason: 'io.resourcefile-api#4 a resource path falls back to '
              "'assets/test/<path>' when the main file does not exist");

      File('${tmp.path}/assets/main/fixture.csv')
        ..createSync(recursive: true)
        ..writeAsStringSync('from-main\n');
      expect(await resource.lines(), <String>['from-main'],
          reason: 'io.resourcefile-api#4 a resource path is looked up first '
              "under 'assets/main/<path>'");

      expect(LocalResourceFile('migrations/09.sql').resolvedPathString,
          'assets/test/migrations/09.sql',
          reason: 'io.resourcefile-api#4 the default roots are assets/main and '
              'assets/test, in that order');
    });

    test('#5 LoopDBImporter loads migrations/NN.sql through ResourceFile',
        () async {
      File('${tmp.path}/assets/main/migrations/21.sql')
        ..createSync(recursive: true)
        ..writeAsStringSync('alter table Habits add column question text;\n');

      // Exactly what LoopDBImporter does: format("%02d.sql", version) and then
      // openResourceFile("migrations/$filename").lines().joinToString("\n").
      final filename = format('%02d.sql', 21);
      final resource = fileOpener.openResourceFile('migrations/$filename');
      expect(await resource.exists(), isTrue,
          reason: 'io.resourcefile-api#5 the only production use of '
              "ResourceFile in this domain is LoopDBImporter loading "
              "'migrations/NN.sql'");
      expect((await resource.lines()).join('\n'),
          'alter table Habits add column question text;',
          reason: 'io.resourcefile-api#5 LoopDBImporter joins the resource '
              'lines with "\\n"');
    });
  });

  // ---------------------------------------------------------------------
  // io.logging
  // ---------------------------------------------------------------------

  group('io.logging', () {
    test('#1 getLogger(name) returns a Logger with the four methods', () {
      final out = StringBuffer();
      final err = StringBuffer();
      final Logging logging = StandardLogging(out: out, err: err);
      final logger = logging.getLogger('LoopDBImporter');
      expect(logger, isA<Logger>(),
          reason: 'io.logging#1 Logging.getLogger(name) returns a Logger');

      logger.info('i');
      logger.debug('d');
      logger.error('e');
      logger.error(Exception('boom'), StackTrace.fromString('#0 frame'));
      expect(out.toString(), '[LoopDBImporter] i\n[LoopDBImporter] d\n[LoopDBImporter] e\n',
          reason: 'io.logging#1 the Logger has info(msg), debug(msg) and '
              'error(msg)');
      expect(err.toString(), contains('Exception: boom'),
          reason: 'io.logging#1 the Logger also has error(exception)');
    });

    test('#2 StandardLogger prints "[<name>] <msg>" and stack traces', () {
      final out = StringBuffer();
      final err = StringBuffer();
      final logger = StandardLogger('HabitBullCSVImporter', out: out, err: err);

      logger.info('Creating habit: Wake up');
      expect(out.toString(), '[HabitBullCSVImporter] Creating habit: Wake up\n',
          reason: 'io.logging#2 info prints "[<name>] <msg>" to stdout');

      out.clear();
      logger.debug('some debug');
      expect(out.toString(), '[HabitBullCSVImporter] some debug\n',
          reason: 'io.logging#2 debug prints "[<name>] <msg>" to stdout');

      out.clear();
      logger.error('some error');
      expect(out.toString(), '[HabitBullCSVImporter] some error\n',
          reason: 'io.logging#2 error(msg) prints "[<name>] <msg>" to stdout, '
              'not to stderr');
      expect(err.toString(), isEmpty,
          reason: 'io.logging#2 error(msg) does not touch stderr');

      out.clear();
      logger.error(Exception('boom'), StackTrace.fromString('#0 frame'));
      expect(out.toString(), isEmpty,
          reason: 'io.logging#2 error(exception) calls printStackTrace instead '
              'of println, so nothing reaches stdout');
      expect(err.toString(), 'Exception: boom\n#0 frame\n',
          reason: 'io.logging#2 error(exception) calls printStackTrace');

      final defaultLogging = StandardLogging();
      expect(defaultLogging.getLogger('X'), isA<StandardLogger>(),
          reason: 'io.logging#2 StandardLogging.getLogger returns a '
              'StandardLogger');
    });

    test('#5 preserves the import messages verbatim', () {
      final out = StringBuffer();
      final logger = StandardLogger('HabitBullCSVImporter', out: out);

      logger.info(creatingHabitMessage('Wake up early'));
      logger.info(foundNumericalValueMessage(64));
      logger.error(couldNotParseIntMessage('12.5'));
      logger.error(cannotHandleFileTablesNotFound);
      logger.error(incompatibleVersionMessage(26, 25));

      expect(
          const LineSplitter().convert(out.toString()),
          <String>[
            '[HabitBullCSVImporter] Creating habit: Wake up early',
            '[HabitBullCSVImporter] Found a value of 64, considering this habit as numerical.',
            '[HabitBullCSVImporter] Could not parse int: 12.5. Replacing by zero.',
            '[HabitBullCSVImporter] Cannot handle file: tables not found',
            '[HabitBullCSVImporter] Cannot handle file: incompatible version: 26 > 25',
          ],
          reason: 'io.logging#5 the messages emitted during import are '
              'preserved verbatim');
    });
  });
}
