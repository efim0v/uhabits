import '../database/database.dart';
import 'habit_definition.dart';

/// Where the mark lives.
///
/// The presence of a row is the only thing that makes a habit computed. Not a
/// third `HabitType`: adding one produces no compile error anywhere, every
/// `if (isNumerical)` falls to its else, and the habit is quietly scored as a
/// yes/no one. Not a column on `Habits`: three independent column lists and
/// the schema parity tests would have to move.
class DefinitionRepository {
  DefinitionRepository(this._db);

  final Database _db;

  HabitDefinition? forHabit(int habitId) => _db.querySingle<HabitDefinition?>(
        'select kind, committed_from, payload from HabitDefinitions '
        'where habit = ?',
        <String>['$habitId'],
        (stmt) {
          final ComputedKind? kind = ComputedKind.fromWire(stmt.getText(0));
          if (kind == null) return null;
          return HabitDefinition(
            kind: kind,
            committedFrom: _realCommitmentDay(stmt.getIntOrNull(1)),
            payload: HabitDefinition.decodePayload(stmt.getText(2)),
          );
        },
      );

  /// [day], unless it is a day nobody could have committed on.
  ///
  /// The column holds a `daysSince2000`, so 0 is 2000-01-01 — the first day
  /// the type can express, years before anything that writes this table
  /// existed — and it is also exactly what an unset integer looks like.
  /// Nothing on the way in rejects it: `DefinitionImporter` copies whatever
  /// the other device's file held, the table has no `CHECK`, and a database
  /// can be hand-edited. Taken as a real day it would start every recompute
  /// window at the epoch and tell the person they have kept a habit for a
  /// quarter of a century — the streak is the damage here, not the size of
  /// the loop.
  ///
  /// Refused where the row is read rather than where it is used, for the same
  /// reason [ComputedKind.fromWire] answers null to a kind it does not know:
  /// a value this build cannot use is nothing to hand out, and one answer to
  /// one question beats every later reader remembering to check. It also
  /// stops the import carrying the bad value onward, since the import reads
  /// through here.
  ///
  /// Only the day is dropped; the kind and the payload are kept. The habit is
  /// still an abstinence habit, it just falls back to the ported window
  /// (`computed.commitment#3`, `computed.commitment#6`). A day in the future
  /// is left alone: `Habit.recompute` already clamps the window to it.
  static int? _realCommitmentDay(int? day) =>
      day == null || day > 0 ? day : null;

  /// Whether anything outside the app may write this habit's days.
  ///
  /// Deliberately not `forHabit(habitId) != null`. [forHabit] answers "what do
  /// I compute this with", and a kind this build does not know is nothing it
  /// can compute with — so it answers null. This answers "may something
  /// outside write here", and a kind this build does not know has to answer
  /// no: a habit whose definition came from a newer build would otherwise be
  /// writable from a widget and clearable by randomise, and randomise is
  /// `originalEntries.clear()`. The row is what makes a habit computed
  /// (`computed.definition#9`).
  bool isComputed(int habitId) =>
      _db.querySingle<bool>(
        'select 1 from HabitDefinitions where habit = ?',
        <String>['$habitId'],
        (stmt) => true,
      ) ??
      false;

  void save(int habitId, HabitDefinition definition) {
    _db.run(
      'insert into HabitDefinitions (habit, kind, committed_from, payload) '
      'values (?, ?, ?, ?) '
      'on conflict(habit) do update set '
      ' kind = excluded.kind, '
      ' committed_from = excluded.committed_from, '
      ' payload = excluded.payload',
      (stmt) {
        stmt.bindInt(1, habitId);
        stmt.bindText(2, definition.kind.wireName);
        final int? from = definition.committedFrom;
        if (from == null) {
          stmt.bindNull(3);
        } else {
          stmt.bindInt(3, from);
        }
        stmt.bindText(4, definition.encodedPayload);
      },
    );
  }

  void remove(int habitId) => _db.run(
        'delete from HabitDefinitions where habit = ?',
        (stmt) => stmt.bindInt(1, habitId),
      );

  List<int> habitIdsOfKind(ComputedKind kind) {
    final List<int> result = <int>[];
    _db.query(
      'select habit from HabitDefinitions where kind = ? order by habit',
      <String>[kind.wireName],
      (stmt) => result.add(stmt.getInt(0)),
    );
    return result;
  }
}
