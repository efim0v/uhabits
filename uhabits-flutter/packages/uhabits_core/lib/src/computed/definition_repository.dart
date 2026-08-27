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

  /// [day], unless it is a day nobody chose.
  ///
  /// The column holds a `daysSince2000`, and 0 is exactly what an unset
  /// integer column reads as — a default, a value copied out of a row that was
  /// never written, a field some other tool filled with nothing. The date
  /// itself is not the problem: `LocalDate` handles the epoch and the days
  /// before it, counting back four hundred years for a negative number. What
  /// is impossible is the choosing. Nothing in this app has ever offered
  /// 2000-01-01, or any day before it, as a day to commit on, so a row
  /// carrying one came from a file rather than from a person:
  /// `DefinitionImporter` copies whatever the other device's file held, the
  /// table has no `CHECK`, and a database can be hand-edited. Taken as a real
  /// day it starts every recompute window at the epoch and tells the person
  /// they have kept the habit for twenty-six years — the streak is the damage
  /// here, not the size of the loop.
  ///
  /// Refused on the way out as well as on the way in ([save] throws), because
  /// the two answer different dangers: [save] refuses a caller's mistake,
  /// which is code and can be fixed, while this refuses a file, which cannot.
  /// A row already in the database was written by some earlier build, another
  /// device or another program, and it is here — where the row is read, two
  /// lines below where [ComputedKind.fromWire] refuses a kind this build does
  /// not know — that a value nothing can use stops being handed out. It is
  /// also what keeps the import from carrying the bad value onward, since the
  /// import reads through here and writes back what it read.
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

  /// Writes [definition] down, replacing whatever this habit had.
  ///
  /// Refuses a commitment day at or before the epoch rather than storing one
  /// [_realCommitmentDay] would then quietly drop on the way back out: a
  /// caller's choice that disappears between the write and the next read is
  /// worse than one that never lands. See [_realCommitmentDay] for why such a
  /// day is nobody's choice (`computed.commitment#6`).
  void save(int habitId, HabitDefinition definition) {
    final int? committedFrom = definition.committedFrom;
    if (committedFrom != null && committedFrom <= 0) {
      throw ArgumentError.value(
        committedFrom,
        'committedFrom',
        'no one commits on a day at or before the epoch; '
            '0 is an unset integer, not a decision',
      );
    }
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
