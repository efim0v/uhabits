import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/migrations.g.dart';
import 'package:uhabits_core/src/database/sqlite3_database.dart';

import '../helpers/test_database.dart';

/// Ported from
/// uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/DatabaseTest.kt,
/// uhabits-core/src/commonTest/kotlin/org/isoron/platform/io/DatabaseQueryHelpersTest.kt
/// and
/// uhabits-android/src/androidTest/java/org/isoron/uhabits/database/AndroidDatabaseTest.kt
void main() {
  group('persistence.database-abstraction', () {
    late Database db;

    setUp(() {
      db = openMemoryDatabase();
    });

    tearDown(() {
      db.close();
    });

    test('#1 getters are 0-indexed, binders are 1-indexed', () {
      db.run('create table demo(key int, value text)');

      final insert = db.prepareStatement('insert into demo(key, value) values (?, ?)');
      insert.bindInt(1, 42);
      insert.bindText(2, 'Hello World');
      insert.step();
      insert.finalizeStatement();

      final select = db.prepareStatement('select * from demo where key > ?');
      select.bindInt(1, 10);
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#1');
      expect(select.getInt(0), 42,
          reason: 'persistence.database-abstraction#1');
      expect(select.getText(1), 'Hello World',
          reason: 'persistence.database-abstraction#1');
      select.finalizeStatement();

      // bindLong / bindReal / bindNull are 1-indexed too.
      db.run('create table demo2(a int, b real, c text)');
      final insert2 = db.prepareStatement('insert into demo2(a, b, c) values (?, ?, ?)');
      insert2.bindLong(1, 7);
      insert2.bindReal(2, 1.5);
      insert2.bindNull(3);
      insert2.step();
      insert2.finalizeStatement();

      final select2 = db.prepareStatement('select a, b, c from demo2');
      select2.step();
      expect(select2.getLong(0), 7, reason: 'persistence.database-abstraction#1');
      expect(select2.getReal(1), 1.5, reason: 'persistence.database-abstraction#1');
      expect(select2.getTextOrNull(2), isNull,
          reason: 'persistence.database-abstraction#1');
      select2.finalizeStatement();
    });

    test('#2 step returns row while rows remain, done afterwards', () {
      db.run('create table t(v int)');
      db.run('insert into t(v) values (1)');
      db.run('insert into t(v) values (2)');

      final select = db.prepareStatement('select v from t order by v');
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#2');
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#2');
      expect(select.step(), StepResult.done,
          reason: 'persistence.database-abstraction#2');
      expect(select.step(), StepResult.done,
          reason: 'persistence.database-abstraction#2');
      select.finalizeStatement();

      // A non-SELECT statement executes and returns DONE.
      final insert = db.prepareStatement('insert into t(v) values (3)');
      expect(insert.step(), StepResult.done,
          reason: 'persistence.database-abstraction#2');
      insert.finalizeStatement();
      expect(db.queryInt('select count(*) from t'), 3,
          reason: 'persistence.database-abstraction#2');
    });

    test('#3 OrNull getters return null exactly on SQL NULL', () {
      db.run('create table nullable_demo(a int, b text, c real, d int)');
      final insert = db.prepareStatement(
          'insert into nullable_demo(a, b, c, d) values (?, ?, ?, ?)');
      insert.bindNull(1);
      insert.bindNull(2);
      insert.bindNull(3);
      insert.bindNull(4);
      insert.step();
      insert.finalizeStatement();

      final select = db.prepareStatement('select a, b, c, d from nullable_demo');
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#3');
      expect(select.getIntOrNull(0), isNull,
          reason: 'persistence.database-abstraction#3');
      expect(select.getTextOrNull(1), isNull,
          reason: 'persistence.database-abstraction#3');
      expect(select.getRealOrNull(2), isNull,
          reason: 'persistence.database-abstraction#3');
      expect(select.getLongOrNull(3), isNull,
          reason: 'persistence.database-abstraction#3');
      select.finalizeStatement();

      // Non-null values: the OrNull variants return the value, and the plain
      // variants return the driver's coerced value.
      db.run('create table coerce_demo(a, b, c)');
      db.run("insert into coerce_demo(a, b, c) values ('42', 3.7, 5)");
      final select2 = db.prepareStatement('select a, b, c from coerce_demo');
      expect(select2.step(), StepResult.row,
          reason: 'persistence.database-abstraction#3');
      expect(select2.getTextOrNull(0), '42',
          reason: 'persistence.database-abstraction#3');
      expect(select2.getInt(0), 42,
          reason: 'persistence.database-abstraction#3');
      expect(select2.getRealOrNull(1), 3.7,
          reason: 'persistence.database-abstraction#3');
      expect(select2.getInt(1), 3,
          reason: 'persistence.database-abstraction#3');
      expect(select2.getReal(2), 5.0,
          reason: 'persistence.database-abstraction#3');
      expect(select2.getText(2), '5',
          reason: 'persistence.database-abstraction#3');
      select2.finalizeStatement();
    });

    test('#4 reset rewinds the statement and clears all bindings', () {
      db.run('create table reset_demo(v int)');
      final insert = db.prepareStatement('insert into reset_demo(v) values (?)');

      insert.bindInt(1, 10);
      insert.step();
      insert.reset();

      insert.bindInt(1, 20);
      insert.step();
      insert.reset();

      insert.bindInt(1, 30);
      insert.step();
      insert.finalizeStatement();

      final select = db.prepareStatement('select v from reset_demo order by v');
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#4');
      expect(select.getInt(0), 10, reason: 'persistence.database-abstraction#4');
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#4');
      expect(select.getInt(0), 20, reason: 'persistence.database-abstraction#4');
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#4');
      expect(select.getInt(0), 30, reason: 'persistence.database-abstraction#4');
      expect(select.step(), StepResult.done,
          reason: 'persistence.database-abstraction#4');
      select.finalizeStatement();

      // reset() also clears the bindings: an unbound parameter is SQL NULL.
      final insert2 = db.prepareStatement('insert into reset_demo(v) values (?)');
      insert2.bindInt(1, 40);
      insert2.step();
      insert2.reset();
      insert2.step();
      insert2.finalizeStatement();
      expect(db.queryInt('select count(*) from reset_demo where v is null'), 1,
          reason: 'persistence.database-abstraction#4');

      // reset() rewinds a SELECT, so it can be stepped from the top again.
      final select2 = db.prepareStatement('select v from reset_demo order by v');
      expect(select2.step(), StepResult.row,
          reason: 'persistence.database-abstraction#4');
      select2.reset();
      expect(select2.step(), StepResult.row,
          reason: 'persistence.database-abstraction#4');
      expect(select2.getIntOrNull(0), isNull,
          reason: 'persistence.database-abstraction#4');
      select2.finalizeStatement();
    });

    test('#5 finalize releases the statement and any open cursor', () {
      db.run('create table t(v int)');
      db.run('insert into t(v) values (1)');
      db.run('insert into t(v) values (2)');
      db.run('insert into t(v) values (3)');

      final select = db.prepareStatement('select v from t');
      expect(select.step(), StepResult.row,
          reason: 'persistence.database-abstraction#5');

      // While the cursor is open, sqlite refuses to drop the table.
      expect(() => db.run('drop table t'), throwsA(anything),
          reason: 'persistence.database-abstraction#5');

      select.finalizeStatement();

      // Once finalized, the cursor is gone and the table can be dropped.
      db.run('drop table t');
      expect(db.queryInt("select count(*) from sqlite_master where name = 't'"), 0,
          reason: 'persistence.database-abstraction#5');

      // The statement itself is released and can no longer be used.
      expect(() => select.step(), throwsA(isA<StateError>()),
          reason: 'persistence.database-abstraction#5');
    });

    test('#6 run(sql) prepares, steps exactly once, then finalizes', () {
      final spy = SpyDatabase(db);
      spy.run('create table t(v int)');
      spy.run('insert into t(v) values (1)');
      spy.run('insert into t(v) values (2)');
      spy.run('insert into t(v) values (3)');
      spy.events.clear();

      spy.run('select v from t order by v');
      expect(spy.events, ['prepare:select v from t order by v', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#6');
      expect(spy.events.where((e) => e == 'step').length, 1,
          reason: 'persistence.database-abstraction#6');
    });

    test('#7 run(sql, bind) applies the binding lambda, steps once, finalizes', () {
      final spy = SpyDatabase(db);
      spy.run('create table ext_demo(v int)');
      spy.events.clear();

      spy.run('insert into ext_demo(v) values (?)', (stmt) => stmt.bindInt(1, 99));
      expect(spy.events, [
        'prepare:insert into ext_demo(v) values (?)',
        'bindInt(1,99)',
        'step',
        'finalize',
      ], reason: 'persistence.database-abstraction#7');
      expect(db.queryInt('select v from ext_demo'), 99,
          reason: 'persistence.database-abstraction#7');
    });

    test('#8 queryInt / queryLong prepare, step once, read column 0, finalize', () {
      db.run('create table t(a int, b int)');
      db.run('insert into t(a, b) values (11, 22)');

      final spy = SpyDatabase(db);
      expect(spy.queryInt('select a, b from t'), 11,
          reason: 'persistence.database-abstraction#8');
      expect(spy.events, ['prepare:select a, b from t', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#8');

      spy.events.clear();
      expect(spy.queryLong('select b, a from t'), 22,
          reason: 'persistence.database-abstraction#8');
      expect(spy.events, ['prepare:select b, a from t', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#8');
    });

    test('#9 query binds params as TEXT at i+1 and calls block once per row', () {
      db.run('create table t(name text, age int)');
      db.run("insert into t(name, age) values ('Alice', 30)");
      db.run("insert into t(name, age) values ('Bob', 25)");
      db.run("insert into t(name, age) values ('Carol', 35)");

      final names = <String>[];
      final spy = SpyDatabase(db);
      spy.query('select name from t where age > ? order by name', ['28'],
          (stmt) => names.add(stmt.getText(0)));
      expect(names, ['Alice', 'Carol'],
          reason: 'persistence.database-abstraction#9');
      expect(spy.events, [
        'prepare:select name from t where age > ? order by name',
        'bindText(1,28)',
        'step',
        'step',
        'step',
        'finalize',
      ], reason: 'persistence.database-abstraction#9');

      // Multiple params are bound at 1, 2, ... in order.
      spy.events.clear();
      final found = <String>[];
      spy.query('select name from t where age > ? and age < ?', ['26', '34'],
          (stmt) => found.add(stmt.getText(0)));
      expect(found, ['Alice'], reason: 'persistence.database-abstraction#9');
      expect(spy.events.sublist(1, 3), ['bindText(1,26)', 'bindText(2,34)'],
          reason: 'persistence.database-abstraction#9');

      // With zero rows the block is never called.
      var called = false;
      db.query('select name from t where age > ?', ['100'], (_) => called = true);
      expect(called, isFalse, reason: 'persistence.database-abstraction#9');
    });

    test('#10 querySingle returns the first row, or null when empty', () {
      db.run('create table t(v int)');
      db.run('insert into t(v) values (42)');
      db.run('insert into t(v) values (99)');

      final spy = SpyDatabase(db);
      expect(spy.querySingle('select v from t order by v', const [],
              (stmt) => stmt.getInt(0)),
          42,
          reason: 'persistence.database-abstraction#10');
      expect(spy.events, ['prepare:select v from t order by v', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#10');

      db.run('create table u(name text, score int)');
      db.run("insert into u(name, score) values ('Alice', 90)");
      db.run("insert into u(name, score) values ('Bob', 80)");
      spy.events.clear();
      expect(
          spy.querySingle('select score from u where name = ?', ['Alice'],
              (stmt) => stmt.getInt(0)),
          90,
          reason: 'persistence.database-abstraction#10');
      expect(spy.events, [
        'prepare:select score from u where name = ?',
        'bindText(1,Alice)',
        'step',
        'finalize',
      ], reason: 'persistence.database-abstraction#10');
      expect(
          db.querySingle('select score from u where name = ?', ['Nobody'],
              (stmt) => stmt.getInt(0)),
          isNull,
          reason: 'persistence.database-abstraction#10');
    });

    test('#11 nested queries on the same Database instance', () {
      db.run('create table parents(id int, name text)');
      db.run('create table children(parent_id int, name text)');
      db.run("insert into parents(id, name) values (1, 'Alice')");
      db.run("insert into parents(id, name) values (2, 'Bob')");
      db.run("insert into children(parent_id, name) values (1, 'Charlie')");
      db.run("insert into children(parent_id, name) values (1, 'Diana')");
      db.run("insert into children(parent_id, name) values (2, 'Eve')");

      final result = <String, List<String>>{};
      db.query('select id, name from parents order by id', const [], (parent) {
        final parentId = parent.getInt(0);
        final parentName = parent.getText(1);
        final kids = <String>[];
        db.query('select name from children where parent_id = ? order by name',
            ['$parentId'], (child) => kids.add(child.getText(0)));
        result[parentName] = kids;
      });

      expect(result['Alice'], ['Charlie', 'Diana'],
          reason: 'persistence.database-abstraction#11');
      expect(result['Bob'], ['Eve'],
          reason: 'persistence.database-abstraction#11');
    });

    test('#12 begin runs the literal BEGIN and commit the literal COMMIT', () {
      db.run('create table t(v int)');
      final spy = SpyDatabase(db);
      spy.begin();
      expect(spy.events, ['prepare:BEGIN', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#12');
      spy.events.clear();
      spy.run('insert into t(v) values (1)');
      spy.run('insert into t(v) values (2)');
      spy.events.clear();
      spy.commit();
      expect(spy.events, ['prepare:COMMIT', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#12');
      expect(db.queryInt('select count(*) from t'), 2,
          reason: 'persistence.database-abstraction#12');
    });

    test('#13 last_insert_rowid via queryLong is strictly increasing', () {
      db.run('create table rowid_demo(id integer primary key autoincrement, v text)');
      db.run("insert into rowid_demo(v) values ('first')");
      final id1 = db.queryLong('select last_insert_rowid()');
      db.run("insert into rowid_demo(v) values ('second')");
      final id2 = db.queryLong('select last_insert_rowid()');
      db.run("insert into rowid_demo(v) values ('third')");
      final id3 = db.queryLong('select last_insert_rowid()');
      expect(id1 > 0, isTrue, reason: 'persistence.database-abstraction#13');
      expect(id2 > id1, isTrue, reason: 'persistence.database-abstraction#13');
      expect(id3 > id2, isTrue, reason: 'persistence.database-abstraction#13');
      expect(db.queryLong('select id from rowid_demo where v = \'second\''), id2,
          reason: 'persistence.database-abstraction#13');
    });

    test('#14 Database exposes only prepareStatement and close', () {
      // MinimalDatabase implements Database with exactly two members; this file
      // would not compile if the abstract class declared anything else.
      final minimal = MinimalDatabase(db);
      minimal.run('create table t(v int)');
      minimal.run('insert into t(v) values (?)', (stmt) => stmt.bindInt(1, 5));
      expect(minimal.queryInt('select v from t'), 5,
          reason: 'persistence.database-abstraction#14');
      expect(minimal.queryLong('select v from t'), 5,
          reason: 'persistence.database-abstraction#14');
      minimal.setVersion(3);
      expect(minimal.getVersion(), 3,
          reason: 'persistence.database-abstraction#14');
      minimal.begin();
      minimal.run('insert into t(v) values (6)');
      minimal.commit();
      final seen = <int>[];
      minimal.query('select v from t order by v', const [],
          (stmt) => seen.add(stmt.getInt(0)));
      expect(seen, [5, 6], reason: 'persistence.database-abstraction#14');
      expect(
          minimal.querySingle('select v from t order by v', const [],
              (stmt) => stmt.getInt(0)),
          5,
          reason: 'persistence.database-abstraction#14');
    });

    test('#15 query binds 1-based TEXT params and steps until DONE', () {
      db.run('create table t(id int, name text)');
      db.run("insert into t(id, name) values (1, 'Alice')");
      db.run("insert into t(id, name) values (2, 'Bob')");

      final names = <String>[];
      final spy = SpyDatabase(db);
      spy.query('select name from t where id >= ? order by id', ['1'],
          (stmt) => names.add(stmt.getText(0)));
      expect(names, ['Alice', 'Bob'],
          reason: 'persistence.database-abstraction#15');
      // One step per row, plus the final step that returns DONE, then finalize.
      expect(spy.events.where((e) => e == 'step').length, 3,
          reason: 'persistence.database-abstraction#15');
      expect(spy.events.last, 'finalize',
          reason: 'persistence.database-abstraction#15');
      expect(spy.events[1], 'bindText(1,1)',
          reason: 'persistence.database-abstraction#15');

      var called = false;
      db.query('select name from t where id = ?', ['999'], (_) => called = true);
      expect(called, isFalse, reason: 'persistence.database-abstraction#15');
    });

    test('#16 querySingle binds the same way and returns first row or null', () {
      db.run('create table t(id int, name text)');
      db.run("insert into t(id, name) values (1, 'Alice')");
      db.run("insert into t(id, name) values (2, 'Bob')");

      final spy = SpyDatabase(db);
      expect(
          spy.querySingle('select name from t where id = ?', ['2'],
              (stmt) => stmt.getText(0)),
          'Bob',
          reason: 'persistence.database-abstraction#16');
      expect(spy.events[1], 'bindText(1,2)',
          reason: 'persistence.database-abstraction#16');
      expect(spy.events.where((e) => e == 'step').length, 1,
          reason: 'persistence.database-abstraction#16');
      expect(
          db.querySingle('select name from t order by id', const [],
              (stmt) => stmt.getText(0)),
          'Alice',
          reason: 'persistence.database-abstraction#16');
      expect(
          db.querySingle('select name from t where id = ?', ['42'],
              (stmt) => stmt.getText(0)),
          isNull,
          reason: 'persistence.database-abstraction#16');
    });

    test('#17 run prepares/steps once/finalizes; begin BEGIN; commit COMMIT', () {
      final spy = SpyDatabase(db);
      spy.run('create table t(v int)');
      expect(spy.events, ['prepare:create table t(v int)', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#17');
      spy.events.clear();
      spy.begin();
      spy.run('insert into t(v) values (1)');
      spy.run('insert into t(v) values (2)');
      spy.commit();
      expect(spy.events, [
        'prepare:BEGIN', 'step', 'finalize',
        'prepare:insert into t(v) values (1)', 'step', 'finalize',
        'prepare:insert into t(v) values (2)', 'step', 'finalize',
        'prepare:COMMIT', 'step', 'finalize',
      ], reason: 'persistence.database-abstraction#17');
      expect(db.queryInt('select count(*) from t'), 2,
          reason: 'persistence.database-abstraction#17');
    });

    test('#18 getVersion / setVersion use PRAGMA user_version', () {
      final spy = SpyDatabase(db);
      spy.setVersion(0);
      expect(spy.events, ['prepare:PRAGMA user_version = 0', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#18');
      spy.events.clear();
      expect(spy.getVersion(), 0, reason: 'persistence.database-abstraction#18');
      expect(spy.events, ['prepare:PRAGMA user_version', 'step', 'finalize'],
          reason: 'persistence.database-abstraction#18');

      spy.events.clear();
      spy.setVersion(25);
      expect(spy.events.first, 'prepare:PRAGMA user_version = 25',
          reason: 'persistence.database-abstraction#18');
      expect(db.getVersion(), 25, reason: 'persistence.database-abstraction#18');
    });

    test('#19 throwing getters and nullable getters both exist', () {
      db.run('create table t(a int, b int, c real, d text)');
      db.run("insert into t(a, b, c, d) values (1, 2, 3.5, 'four')");
      db.run('insert into t(a, b, c, d) values (null, null, null, null)');

      final stmt = db.prepareStatement('select a, b, c, d from t order by rowid');
      expect(stmt.step(), StepResult.row,
          reason: 'persistence.database-abstraction#19');
      expect(stmt.getInt(0), 1, reason: 'persistence.database-abstraction#19');
      expect(stmt.getLong(1), 2, reason: 'persistence.database-abstraction#19');
      expect(stmt.getReal(2), 3.5, reason: 'persistence.database-abstraction#19');
      expect(stmt.getText(3), 'four', reason: 'persistence.database-abstraction#19');
      expect(stmt.getIntOrNull(0), 1, reason: 'persistence.database-abstraction#19');
      expect(stmt.getLongOrNull(1), 2, reason: 'persistence.database-abstraction#19');
      expect(stmt.getRealOrNull(2), 3.5,
          reason: 'persistence.database-abstraction#19');
      expect(stmt.getTextOrNull(3), 'four',
          reason: 'persistence.database-abstraction#19');

      expect(stmt.step(), StepResult.row,
          reason: 'persistence.database-abstraction#19');
      expect(stmt.getIntOrNull(0), isNull,
          reason: 'persistence.database-abstraction#19');
      expect(stmt.getLongOrNull(1), isNull,
          reason: 'persistence.database-abstraction#19');
      expect(stmt.getRealOrNull(2), isNull,
          reason: 'persistence.database-abstraction#19');
      expect(stmt.getTextOrNull(3), isNull,
          reason: 'persistence.database-abstraction#19');
      // getText on a NULL column throws, mirroring the Kotlin NPE.
      expect(() => stmt.getText(3), throwsA(isA<StateError>()),
          reason: 'persistence.database-abstraction#19');
      stmt.finalizeStatement();
    });

    test('#20 opener opens an existing file read-write so migrations can run', () {
      final dir = Directory.systemTemp.createTempSync('uhabits_opener');
      final path = '${dir.path}/uhabits.db';
      try {
        // Create a file to import, using the raw driver.
        final created = Sqlite3Database(sqlite.sqlite3.open(path));
        created.run('create table t(v int)');
        created.setVersion(21);
        created.close();

        const opener = Sqlite3DatabaseOpener();
        final opened = opener.open(path);
        // Read-write: a migration-style write succeeds on the imported file.
        opened.run('alter table t add column w int');
        opened.setVersion(22);
        expect(opened.getVersion(), 22,
            reason: 'persistence.database-abstraction#20');
        opened.close();

        final reopened = opener.open(path);
        expect(reopened.getVersion(), 22,
            reason: 'persistence.database-abstraction#20');
        reopened.close();

        // OPEN_READWRITE does not create: a missing file is an error.
        expect(() => opener.open('${dir.path}/missing.db'), throwsA(anything),
            reason: 'persistence.database-abstraction#20');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('#18 test helper stamps user_version 8 and migrates up', () {
      final migrated = openMigratedDatabase();
      expect(migrated.getVersion(), databaseVersion,
          reason: 'persistence.database-abstraction#18');
      expect(
          migrated.queryInt(
              "select count(*) from sqlite_master where type = 'table' and name = 'Habits'"),
          1,
          reason: 'persistence.database-abstraction#18');
      expect(migrated.queryInt('select count(*) from Habits'), 0,
          reason: 'persistence.database-abstraction#18');
      migrated.close();

      final partial = openMigratedDatabase(version: 16);
      expect(partial.getVersion(), 16,
          reason: 'persistence.database-abstraction#18');
      partial.close();
    });
  });
}

/// A [Database] implemented with exactly the two members the abstract class
/// declares — the compile-time proof for rule #14.
class MinimalDatabase implements Database {
  MinimalDatabase(this._delegate);

  final Database _delegate;

  @override
  PreparedStatement prepareStatement(String sql) =>
      _delegate.prepareStatement(sql);

  @override
  void close() => _delegate.close();
}

/// Records every call the extension functions make, so tests can assert the
/// exact prepare / bind / step / finalize sequence.
class SpyDatabase implements Database {
  SpyDatabase(this._delegate);

  final Database _delegate;
  final List<String> events = [];

  @override
  PreparedStatement prepareStatement(String sql) {
    events.add('prepare:$sql');
    return SpyStatement(_delegate.prepareStatement(sql), events);
  }

  @override
  void close() {
    events.add('close');
    _delegate.close();
  }
}

class SpyStatement implements PreparedStatement {
  SpyStatement(this._delegate, this._events);

  final PreparedStatement _delegate;
  final List<String> _events;

  @override
  StepResult step() {
    _events.add('step');
    return _delegate.step();
  }

  @override
  int getInt(int index) => _delegate.getInt(index);

  @override
  int getLong(int index) => _delegate.getLong(index);

  @override
  double getReal(int index) => _delegate.getReal(index);

  @override
  String getText(int index) => _delegate.getText(index);

  @override
  int? getIntOrNull(int index) => _delegate.getIntOrNull(index);

  @override
  int? getLongOrNull(int index) => _delegate.getLongOrNull(index);

  @override
  double? getRealOrNull(int index) => _delegate.getRealOrNull(index);

  @override
  String? getTextOrNull(int index) => _delegate.getTextOrNull(index);

  @override
  void bindInt(int index, int value) {
    _events.add('bindInt($index,$value)');
    _delegate.bindInt(index, value);
  }

  @override
  void bindLong(int index, int value) {
    _events.add('bindLong($index,$value)');
    _delegate.bindLong(index, value);
  }

  @override
  void bindReal(int index, double value) {
    _events.add('bindReal($index,$value)');
    _delegate.bindReal(index, value);
  }

  @override
  void bindText(int index, String value) {
    _events.add('bindText($index,$value)');
    _delegate.bindText(index, value);
  }

  @override
  void bindNull(int index) {
    _events.add('bindNull($index)');
    _delegate.bindNull(index);
  }

  @override
  void reset() {
    _events.add('reset');
    _delegate.reset();
  }

  @override
  void finalizeStatement() {
    _events.add('finalize');
    _delegate.finalizeStatement();
  }
}
