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
      // A row of nothing is read as nothing. `save` refuses one — the floor of
      // one is its guard (`computed.lapses#2`) — and that refusal is right
      // where it stands: a caller passing zero is a mistake in code, and code
      // can be fixed. A file cannot. Left to throw here it would not protect
      // the database either, because the import catches and commits anyway:
      // this habit would keep only the lapses before the bad row, every habit
      // after it would be dropped, no definition would be attached, and the
      // next attempt would break on the same row for ever.
      //
      // Nor is the answer to round it up to one, which would invent a lapse
      // and break a streak that was never broken. A zero asserts nothing, and
      // the absent row is already how this journal spells that.
      if (lapse.value < LapseRepository.minimumAmount) continue;
      // `save` with its named amount, rather than three positional ints past
      // it: the same one door, so that a floor raised there is raised here.
      _destination.save(destinationHabitId, lapse.key, amount: lapse.value);
    }
  }
}
