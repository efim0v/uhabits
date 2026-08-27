import '../database/database.dart';
import 'lapse_repository.dart';

/// Carries an abstinence habit's journal of lapses across a restore.
///
/// A backup is a byte-for-byte copy, so the rows are always in the file. What
/// loses them is the import: habits are matched by uuid and given whatever id
/// this device has free, while every lapse is filed under the id the *other*
/// device used. Nothing rewrites those, so without this the restored habit
/// comes back with its commitment day and an empty history behind it — which
/// reads as a clean run since the day it was made, and is the most flattering
/// possible lie.
///
/// Reads go through a [LapseRepository] pointed at the source file rather than
/// through SQL of its own, exactly as `SleepImporter` does: the schema is
/// stated once, and a column added to it cannot be forgotten here.
class LapseImporter {
  const LapseImporter(this._destination);

  final LapseRepository _destination;

  /// Moves every lapse belonging to [sourceHabitId] in [source] onto
  /// [destinationHabitId] here.
  ///
  /// Answers silently for a habit that has no journal, which is nearly all of
  /// them.
  void importFor(Database source, int? sourceHabitId, int destinationHabitId) {
    if (sourceHabitId == null) return;
    final LapseRepository origin = LapseRepository(source);

    final int? from = origin.firstDay(sourceHabitId);
    final int? to = origin.lastDay(sourceHabitId);
    if (from == null || to == null) return;

    for (final MapEntry<int, int> lapse
        in origin.range(sourceHabitId, from, to).entries) {
      // `save` with its named amount, rather than three positional ints past
      // it: it is the one door carrying the guard that a lapse is at least one
      // (`computed.lapses#2`). A file holding a zero is refusing to say
      // anything, and it is refused loudly rather than restored as a lapse of
      // nothing.
      _destination.save(destinationHabitId, lapse.key, amount: lapse.value);
    }
  }
}
