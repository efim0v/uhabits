/// Repetitions table access.
///
/// Ported line by line from
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/database/EntryRepository.kt`.
///
/// Every statement is prepared lazily and cached for the life of the
/// repository (Kotlin `by lazy`), and `reset()` before each use, so repeated
/// calls re-execute against current data.
library;

import 'database.dart';

/// One row of the `Repetitions` table.
///
/// Kotlin: `data class EntryData`. Mutable, exactly as upstream — the
/// [id] field is what `SQLiteEntryList` writes the generated id back into.
class EntryData {
  EntryData({
    this.id,
    this.habitId,
    this.timestamp = 0,
    this.value = 0,
    this.notes = '',
  });

  int? id;
  int? habitId;
  int timestamp;
  int value;
  String notes;

  @override
  bool operator ==(Object other) =>
      other is EntryData &&
      other.id == id &&
      other.habitId == habitId &&
      other.timestamp == timestamp &&
      other.value == value &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(id, habitId, timestamp, value, notes);

  @override
  String toString() => 'EntryData(id=$id, habitId=$habitId, '
      'timestamp=$timestamp, value=$value, notes=$notes)';
}

/// Reads and writes [EntryData] rows.
class EntryRepository {
  EntryRepository(this.db);

  final Database db;

  late final PreparedStatement _findAllByHabitStmt = db.prepareStatement(
    'SELECT id, habit, timestamp, value, notes FROM Repetitions WHERE habit = ? ORDER BY timestamp DESC',
  );

  late final PreparedStatement _insertStmt = db.prepareStatement(
    'INSERT INTO Repetitions(habit, timestamp, value, notes) VALUES (?, ?, ?, ?)',
  );

  late final PreparedStatement _deleteByHabitAndTimestampStmt =
      db.prepareStatement(
    'DELETE FROM Repetitions WHERE habit = ? AND timestamp = ?',
  );

  late final PreparedStatement _deleteByHabitStmt = db.prepareStatement(
    'DELETE FROM Repetitions WHERE habit = ?',
  );

  /// All entries of [habitId], newest first.
  ///
  /// A NULL `notes` column — every row written before schema 25 — reads back
  /// as the empty string, because `getText` on a NULL column throws.
  List<EntryData> findAllByHabitId(int habitId) {
    _findAllByHabitStmt.reset();
    _findAllByHabitStmt.bindLong(1, habitId);
    final results = <EntryData>[];
    while (_findAllByHabitStmt.step() == StepResult.row) {
      results.add(
        EntryData(
          id: _findAllByHabitStmt.getLong(0),
          habitId: _findAllByHabitStmt.getLong(1),
          timestamp: _findAllByHabitStmt.getLong(2),
          value: _findAllByHabitStmt.getInt(3),
          notes: _findAllByHabitStmt.getTextOrNull(4) ?? '',
        ),
      );
    }
    return results;
  }

  /// Inserts [data] and returns the generated id.
  ///
  /// `data.id` is not bound — the id always comes from the database — and
  /// `data.habitId` must be non-null: Kotlin's `data.habitId!!` throws an NPE,
  /// Dart's `!` a null-check [TypeError].
  int insert(EntryData data) {
    _insertStmt.reset();
    _insertStmt.bindLong(1, data.habitId!);
    _insertStmt.bindLong(2, data.timestamp);
    _insertStmt.bindInt(3, data.value);
    _insertStmt.bindText(4, data.notes);
    _insertStmt.step();
    return db.queryLong('SELECT last_insert_rowid()');
  }

  void deleteByHabitIdAndTimestamp(int habitId, int timestamp) {
    _deleteByHabitAndTimestampStmt.reset();
    _deleteByHabitAndTimestampStmt.bindLong(1, habitId);
    _deleteByHabitAndTimestampStmt.bindLong(2, timestamp);
    _deleteByHabitAndTimestampStmt.step();
  }

  void deleteByHabitId(int habitId) {
    _deleteByHabitStmt.reset();
    _deleteByHabitStmt.bindLong(1, habitId);
    _deleteByHabitStmt.step();
  }

  /// Escape hatch for arbitrary SQL; runs one statement through [Database.run].
  void execSQL(String sql) => db.run(sql);
}
