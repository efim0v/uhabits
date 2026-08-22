import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/habit_repository.dart';

import '../helpers/test_database.dart';

/// Ported from
/// `uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/database/HabitRepositoryTest.kt`,
/// against
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/HabitRepository.kt`.
///
/// The Kotlin test only covers insert/update/delete/findAll/execSQL happy
/// paths; the extra tests here pin down the SQL text, the bind indexes and the
/// statement caching that the feature rules call out.
void main() {
  group('persistence.habit-repository', () {
    late _RecordingDatabase db;
    late HabitRepository repo;

    setUp(() {
      db = _RecordingDatabase(openMigratedDatabase());
      repo = HabitRepository(db);
    });

    tearDown(() {
      db.close();
    });

    test('#1 HabitData default values', () {
      final data = HabitData();
      expect(data.id, isNull, reason: 'persistence.habit-repository#1');
      expect(data.name, '', reason: 'persistence.habit-repository#1');
      expect(data.description, '', reason: 'persistence.habit-repository#1');
      expect(data.question, '', reason: 'persistence.habit-repository#1');
      expect(data.freqNum, 1, reason: 'persistence.habit-repository#1');
      expect(data.freqDen, 1, reason: 'persistence.habit-repository#1');
      expect(data.color, 0, reason: 'persistence.habit-repository#1');
      expect(data.position, 0, reason: 'persistence.habit-repository#1');
      expect(data.reminderHour, isNull,
          reason: 'persistence.habit-repository#1');
      expect(data.reminderMin, isNull, reason: 'persistence.habit-repository#1');
      expect(data.reminderDays, 0, reason: 'persistence.habit-repository#1');
      expect(data.highlight, 0, reason: 'persistence.habit-repository#1');
      expect(data.archived, 0, reason: 'persistence.habit-repository#1');
      expect(data.type, 0, reason: 'persistence.habit-repository#1');
      expect(data.targetValue, 0.0, reason: 'persistence.habit-repository#1');
      expect(data.targetType, 0, reason: 'persistence.habit-repository#1');
      expect(data.unit, '', reason: 'persistence.habit-repository#1');
      expect(data.uuid, isNull, reason: 'persistence.habit-repository#1');
    });

    test('#2 findAll SQL text and position ordering', () {
      repo.insert(HabitData(name: 'Third', position: 2));
      repo.insert(HabitData(name: 'First', position: 0));
      repo.insert(HabitData(name: 'Second', position: 1));

      final all = repo.findAll();

      expect(
        _collapse(db.statementFor('SELECT id').sql),
        'SELECT id, name, description, question, freq_num, freq_den, color, '
            'position, reminder_hour, reminder_min, reminder_days, highlight, '
            'archived, type, target_value, target_type, unit, uuid '
            'FROM Habits ORDER BY position',
        reason: 'persistence.habit-repository#2',
      );
      expect(all.map((d) => d.name).toList(), ['First', 'Second', 'Third'],
          reason: 'persistence.habit-repository#2');
      expect(all.map((d) => d.position).toList(), [0, 1, 2],
          reason: 'persistence.habit-repository#2');
    });

    test('#3 findAll resets its cached statement before stepping', () {
      repo.insert(HabitData(name: 'A', position: 0));
      expect(repo.findAll().length, 1,
          reason: 'persistence.habit-repository#3');

      repo.insert(HabitData(name: 'B', position: 1));
      final second = repo.findAll();
      expect(second.map((d) => d.name).toList(), ['A', 'B'],
          reason: 'persistence.habit-repository#3');

      final selects =
          db.statements.where((s) => s.sql.contains('SELECT id')).toList();
      expect(selects.length, 1,
          reason: 'persistence.habit-repository#3');
      expect(selects.single.log.first, 'reset',
          reason: 'persistence.habit-repository#3');
      expect(selects.single.log.where((e) => e == 'reset').length, 2,
          reason: 'persistence.habit-repository#3');
    });

    test('#4 findAll on an empty table returns an empty list', () {
      expect(repo.findAll(), isEmpty,
          reason: 'persistence.habit-repository#4');
      expect(repo.findAll().length, 0,
          reason: 'persistence.habit-repository#4');
    });

    test('#5 insert without id uses the 17-column statement and '
        'last_insert_rowid', () {
      final data = HabitData(
        name: 'Wake up early',
        description: 'Before 6am',
        question: 'Did you wake up early?',
        color: 3,
        uuid: 'abc-123',
      );
      db.clear();
      final id = repo.insert(data);

      expect(id > 0, isTrue, reason: 'persistence.habit-repository#5');
      expect(
        _collapse(db.statementFor('INSERT INTO Habits(name').sql),
        'INSERT INTO Habits(name, description, question, freq_num, freq_den, '
            'color, position, reminder_hour, reminder_min, reminder_days, '
            'highlight, archived, type, target_value, target_type, unit, uuid) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        reason: 'persistence.habit-repository#5',
      );
      expect(db.preparedSql, contains('SELECT last_insert_rowid()'),
          reason: 'persistence.habit-repository#5');

      final all = repo.findAll();
      expect(all.single.id, id, reason: 'persistence.habit-repository#5');
      expect(all.single.name, 'Wake up early',
          reason: 'persistence.habit-repository#5');

      final second = repo.insert(HabitData(name: 'B', position: 1));
      expect(second, id + 1, reason: 'persistence.habit-repository#5');
    });

    test('#6 insert with an explicit id uses the 18-column statement and '
        'returns data.id', () {
      db.clear();
      final returned = repo.insert(HabitData(id: 12300, name: 'Explicit'));

      expect(returned, 12300, reason: 'persistence.habit-repository#6');
      expect(
        _collapse(db.statementFor('INSERT INTO Habits(id').sql),
        'INSERT INTO Habits(id, name, description, question, freq_num, '
            'freq_den, color, position, reminder_hour, reminder_min, '
            'reminder_days, highlight, archived, type, target_value, '
            'target_type, unit, uuid) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        reason: 'persistence.habit-repository#6',
      );
      expect(db.preparedSql, isNot(contains('SELECT last_insert_rowid()')),
          reason: 'persistence.habit-repository#6');
      expect(db.statementFor('INSERT INTO Habits(id').log.take(3).toList(),
          ['reset', 'long:1=12300', 'text:2=Explicit'],
          reason: 'persistence.habit-repository#6');

      final stored = repo.findAll().single;
      expect(stored.id, 12300, reason: 'persistence.habit-repository#6');
      expect(stored.name, 'Explicit', reason: 'persistence.habit-repository#6');
    });

    test('#7 update rewrites every column and binds id at parameter 18', () {
      final data = HabitData(name: 'Exercise', freqNum: 1, freqDen: 2, color: 5);
      data.id = repo.insert(data);

      // A column that the caller never touches is still overwritten by the
      // stale in-memory value.
      repo.execSQL('update Habits set color = 99');
      expect(repo.findAll().single.color, 99,
          reason: 'persistence.habit-repository#7');

      db.clear();
      data.name = 'Exercise daily';
      data.freqDen = 1;
      repo.update(data);

      expect(
        _collapse(db.statementFor('UPDATE Habits').sql),
        'UPDATE Habits SET name=?, description=?, question=?, freq_num=?, '
            'freq_den=?, color=?, position=?, reminder_hour=?, '
            'reminder_min=?, reminder_days=?, highlight=?, archived=?, '
            'type=?, target_value=?, target_type=?, unit=?, uuid=? '
            'WHERE id=?',
        reason: 'persistence.habit-repository#7',
      );
      expect(db.statementFor('UPDATE Habits').log.last, 'step',
          reason: 'persistence.habit-repository#7');
      expect(db.statementFor('UPDATE Habits').log,
          contains('long:18=${data.id}'),
          reason: 'persistence.habit-repository#7');

      final updated = repo.findAll().single;
      expect(updated.name, 'Exercise daily',
          reason: 'persistence.habit-repository#7');
      expect(updated.freqDen, 1, reason: 'persistence.habit-repository#7');
      expect(updated.color, 5, reason: 'persistence.habit-repository#7');

      expect(() => repo.update(HabitData(name: 'no id')),
          throwsA(isA<TypeError>()),
          reason: 'persistence.habit-repository#7');
    });

    test('#8 delete removes the Habits row only, never its Repetitions', () {
      final idA = repo.insert(HabitData(name: 'A', position: 0));
      final idB = repo.insert(HabitData(name: 'B', position: 1));
      final idC = repo.insert(HabitData(name: 'C', position: 2));
      repo.execSQL(
          'insert into Repetitions(habit, timestamp, value) '
          'values ($idB, 100, 2)');
      repo.execSQL(
          'insert into Repetitions(habit, timestamp, value) '
          'values ($idC, 200, 2)');

      db.clear();
      // Migration 22 leaves `pragma foreign_keys=ON` on the connection, so a
      // habit that still owns Repetitions rows cannot be deleted at all: proof
      // that delete() issues no cascading DELETE of its own.
      expect(
          () => repo.delete(idB),
          throwsA(predicate<Object>(
              (e) => e.toString().contains('FOREIGN KEY constraint failed'))),
          reason: 'persistence.habit-repository#8');
      expect(_collapse(db.statementFor('DELETE FROM Habits').sql),
          'DELETE FROM Habits WHERE id = ?',
          reason: 'persistence.habit-repository#8');
      expect(db.preparedSql.where((s) => s.contains('Repetitions')), isEmpty,
          reason: 'persistence.habit-repository#8');

      db.inner.run('pragma foreign_keys=OFF');
      repo.delete(idB);

      final remaining = repo.findAll();
      expect(remaining.map((d) => d.name).toList(), ['A', 'C'],
          reason: 'persistence.habit-repository#8');
      expect(remaining.map((d) => d.id).toList(), [idA, idC],
          reason: 'persistence.habit-repository#8');
      expect(_countRepetitions(db.inner, idB), 1,
          reason: 'persistence.habit-repository#8');
    });

    test('#9 binding rules for nullable, real and plain columns', () {
      db.clear();
      repo.insert(HabitData(
        name: 'No reminder',
        description: 'desc',
        question: 'q?',
        freqNum: 3,
        freqDen: 7,
        color: 5,
        position: 42,
        reminderDays: 0,
        highlight: 1,
        archived: 1,
        type: 1,
        targetValue: 12.5,
        targetType: 1,
        unit: 'minutes',
      ));

      expect(db.statementFor('INSERT INTO Habits(name').log, [
        'reset',
        'text:1=No reminder',
        'text:2=desc',
        'text:3=q?',
        'int:4=3',
        'int:5=7',
        'int:6=5',
        'int:7=42',
        'null:8',
        'null:9',
        'int:10=0',
        'int:11=1',
        'int:12=1',
        'int:13=1',
        'real:14=12.5',
        'int:15=1',
        'text:16=minutes',
        'null:17',
        'step',
      ], reason: 'persistence.habit-repository#9');

      expect(_typeOf(db.inner, 'reminder_hour'), 'null',
          reason: 'persistence.habit-repository#9');
      expect(_typeOf(db.inner, 'reminder_min'), 'null',
          reason: 'persistence.habit-repository#9');
      expect(_typeOf(db.inner, 'uuid'), 'null',
          reason: 'persistence.habit-repository#9');
      expect(_typeOf(db.inner, 'target_value'), 'real',
          reason: 'persistence.habit-repository#9');
      expect(_typeOf(db.inner, 'name'), 'text',
          reason: 'persistence.habit-repository#9');
      expect(_typeOf(db.inner, 'freq_num'), 'integer',
          reason: 'persistence.habit-repository#9');

      final loaded = repo.findAll().single;
      expect(loaded.reminderHour, isNull,
          reason: 'persistence.habit-repository#9');
      expect(loaded.reminderMin, isNull,
          reason: 'persistence.habit-repository#9');
      expect(loaded.uuid, isNull, reason: 'persistence.habit-repository#9');
      expect(loaded.targetValue, 12.5,
          reason: 'persistence.habit-repository#9');

      loaded.reminderHour = 8;
      loaded.reminderMin = 30;
      loaded.reminderDays = 127;
      loaded.uuid = 'u-1';
      db.clear();
      repo.update(loaded);

      expect(db.statementFor('UPDATE Habits').log.sublist(0, 18), [
        'reset',
        'text:1=No reminder',
        'text:2=desc',
        'text:3=q?',
        'int:4=3',
        'int:5=7',
        'int:6=5',
        'int:7=42',
        'int:8=8',
        'int:9=30',
        'int:10=127',
        'int:11=1',
        'int:12=1',
        'int:13=1',
        'real:14=12.5',
        'int:15=1',
        'text:16=minutes',
        'text:17=u-1',
      ], reason: 'persistence.habit-repository#9');

      final reloaded = repo.findAll().single;
      expect(reloaded.reminderHour, 8,
          reason: 'persistence.habit-repository#9');
      expect(reloaded.reminderMin, 30,
          reason: 'persistence.habit-repository#9');
      expect(reloaded.reminderDays, 127,
          reason: 'persistence.habit-repository#9');
      expect(reloaded.uuid, 'u-1', reason: 'persistence.habit-repository#9');
    });

    test('#10 every field survives an insert + findAll round trip', () {
      final original = HabitData(
        name: 'Meditate',
        description: '10 minutes of mindfulness',
        question: 'Did you meditate today?',
        freqNum: 3,
        freqDen: 7,
        color: 5,
        position: 42,
        reminderHour: 7,
        reminderMin: 30,
        reminderDays: 127,
        highlight: 0,
        archived: 1,
        type: 1,
        targetValue: 10.5,
        targetType: 1,
        unit: 'minutes',
        uuid: '550e8400-e29b-41d4-a716-446655440000',
      );
      original.id = repo.insert(original);

      final loaded = repo.findAll().single;
      expect(loaded.id, original.id, reason: 'persistence.habit-repository#10');
      expect(loaded.name, original.name,
          reason: 'persistence.habit-repository#10');
      expect(loaded.description, original.description,
          reason: 'persistence.habit-repository#10');
      expect(loaded.question, original.question,
          reason: 'persistence.habit-repository#10');
      expect(loaded.freqNum, original.freqNum,
          reason: 'persistence.habit-repository#10');
      expect(loaded.freqDen, original.freqDen,
          reason: 'persistence.habit-repository#10');
      expect(loaded.color, original.color,
          reason: 'persistence.habit-repository#10');
      expect(loaded.position, original.position,
          reason: 'persistence.habit-repository#10');
      expect(loaded.reminderHour, original.reminderHour,
          reason: 'persistence.habit-repository#10');
      expect(loaded.reminderMin, original.reminderMin,
          reason: 'persistence.habit-repository#10');
      expect(loaded.reminderDays, original.reminderDays,
          reason: 'persistence.habit-repository#10');
      expect(loaded.highlight, original.highlight,
          reason: 'persistence.habit-repository#10');
      expect(loaded.archived, original.archived,
          reason: 'persistence.habit-repository#10');
      expect(loaded.type, original.type,
          reason: 'persistence.habit-repository#10');
      expect(loaded.targetValue, original.targetValue,
          reason: 'persistence.habit-repository#10');
      expect(loaded.targetValue, isA<double>(),
          reason: 'persistence.habit-repository#10');
      expect(loaded.targetType, original.targetType,
          reason: 'persistence.habit-repository#10');
      expect(loaded.unit, original.unit,
          reason: 'persistence.habit-repository#10');
      expect(loaded.uuid, original.uuid,
          reason: 'persistence.habit-repository#10');
      expect(loaded.uuid, isA<String>(),
          reason: 'persistence.habit-repository#10');
    });

    test('#11 execSQL runs raw statements, with and without bindings', () {
      repo.insert(HabitData(name: 'A', position: 0));
      repo.insert(HabitData(name: 'B', position: 1));
      final idC = repo.insert(HabitData(name: 'C', position: 2));

      // The bulk position shift SQLiteHabitList issues on reorder.
      repo.execSQL('update Habits set position = position + 1 '
          'where position >= 0 and position < 2');

      final shifted = repo.findAll();
      expect(shifted.map((d) => d.position).toList(), [1, 2, 2],
          reason: 'persistence.habit-repository#11');

      // The bound form.
      repo.execSQL('delete from Habits where id = ?',
          (stmt) => stmt.bindLong(1, idC));
      expect(repo.findAll().map((d) => d.name).toList(), ['A', 'B'],
          reason: 'persistence.habit-repository#11');

      // The bulk delete SQLiteHabitList issues on removeAll().
      repo.execSQL('delete from habits');
      expect(repo.findAll(), isEmpty,
          reason: 'persistence.habit-repository#11');
    });
  });
}

String _collapse(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();

String _typeOf(Database db, String column) =>
    db.querySingle('select typeof($column) from Habits', const [],
        (stmt) => stmt.getText(0))!;

int _countRepetitions(Database db, int habitId) =>
    db.queryInt('select count(*) from Repetitions where habit = $habitId');

/// A [Database] that records the SQL it prepares and every call made on the
/// statements it hands out, so the tests can assert the exact SQL text and
/// bind indexes the repository uses.
class _RecordingDatabase implements Database {
  _RecordingDatabase(this.inner);

  final Database inner;
  final List<String> preparedSql = <String>[];
  final List<_RecordingStatement> statements = <_RecordingStatement>[];

  @override
  PreparedStatement prepareStatement(String sql) {
    preparedSql.add(sql);
    final stmt = _RecordingStatement(inner.prepareStatement(sql), sql);
    statements.add(stmt);
    return stmt;
  }

  @override
  void close() => inner.close();

  /// The most recent statement whose SQL contains [fragment], with its call
  /// log cleared of everything before the last [clear].
  _RecordingStatement statementFor(String fragment) =>
      statements.lastWhere((s) => s.sql.contains(fragment));

  /// Forgets the SQL prepared so far and clears every statement's call log.
  void clear() {
    preparedSql.clear();
    for (final stmt in statements) {
      stmt.log.clear();
    }
  }
}

class _RecordingStatement implements PreparedStatement {
  _RecordingStatement(this.inner, this.sql);

  final PreparedStatement inner;
  final String sql;
  final List<String> log = <String>[];

  @override
  StepResult step() {
    log.add('step');
    return inner.step();
  }

  @override
  void reset() {
    log.add('reset');
    inner.reset();
  }

  @override
  void bindInt(int index, int value) {
    log.add('int:$index=$value');
    inner.bindInt(index, value);
  }

  @override
  void bindLong(int index, int value) {
    log.add('long:$index=$value');
    inner.bindLong(index, value);
  }

  @override
  void bindReal(int index, double value) {
    log.add('real:$index=$value');
    inner.bindReal(index, value);
  }

  @override
  void bindText(int index, String value) {
    log.add('text:$index=$value');
    inner.bindText(index, value);
  }

  @override
  void bindNull(int index) {
    log.add('null:$index');
    inner.bindNull(index);
  }

  @override
  void finalizeStatement() => inner.finalizeStatement();

  @override
  int getInt(int index) => inner.getInt(index);

  @override
  int getLong(int index) => inner.getLong(index);

  @override
  double getReal(int index) => inner.getReal(index);

  @override
  String getText(int index) => inner.getText(index);

  @override
  int? getIntOrNull(int index) => inner.getIntOrNull(index);

  @override
  int? getLongOrNull(int index) => inner.getLongOrNull(index);

  @override
  double? getRealOrNull(int index) => inner.getRealOrNull(index);

  @override
  String? getTextOrNull(int index) => inner.getTextOrNull(index);
}
