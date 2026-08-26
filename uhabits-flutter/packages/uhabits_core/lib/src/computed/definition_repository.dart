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
            committedFrom: stmt.getIntOrNull(1),
            payload: HabitDefinition.decodePayload(stmt.getText(2)),
          );
        },
      );

  bool isComputed(int habitId) => forHabit(habitId) != null;

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
