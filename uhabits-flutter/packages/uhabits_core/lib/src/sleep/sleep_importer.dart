import '../database/database.dart';
import 'sleep_episode.dart';
import 'sleep_goal.dart';
import 'sleep_session_repository.dart';

/// Carries a habit's sleep goal and its recorded nights out of an imported
/// file and into this device's database.
///
/// A backup is a byte-for-byte copy of the database, so the nights are always
/// in the file. What loses them is the import: habits are matched by uuid and
/// given whatever id this device has free, while every sleep row is filed
/// under the id the *other* device used. Nothing rewrites those, so without
/// this the rows land in the imported file's tables, are never read, and the
/// restored habit shows a year of nights as zeros — the sort of loss that is
/// only discovered long after the backup it could have been recovered from was
/// rotated away.
///
/// Reads go through a [SleepSessionRepository] pointed at the source file
/// rather than through SQL of their own: the schema is stated once, and a
/// column added to it cannot be forgotten here.
class SleepImporter {
  const SleepImporter(this._destination);

  final SleepSessionRepository _destination;

  /// Moves everything belonging to [sourceHabitId] in [source] onto
  /// [destinationHabitId] here.
  ///
  /// Answers silently for a habit that has no sleep data, which is nearly all
  /// of them.
  void importFor(Database source, int? sourceHabitId, int destinationHabitId) {
    if (sourceHabitId == null) return;
    // The clock is never read: this repository only reads.
    final SleepSessionRepository origin =
        SleepSessionRepository(source, () => 0);

    final SleepGoal? goal = origin.goalFor(sourceHabitId);
    if (goal != null) _destination.saveGoal(destinationHabitId, goal);

    final int? from = origin.firstDay(sourceHabitId);
    final int? to = origin.lastDay(sourceHabitId);
    if (from == null || to == null) return;

    for (final MapEntry<int, SleepEpisode> night
        in origin.range(sourceHabitId, from, to).entries) {
      // Whether the night was entered by hand travels with it. It decides
      // more than provenance: a night from a health store never replaces one
      // a person typed, here as everywhere else, so importing a watch's
      // reading cannot overwrite a correction made on this device.
      _destination.upsert(
        destinationHabitId,
        night.key,
        night.value,
        manual: origin.isManual(sourceHabitId, night.key),
      );
    }
  }
}
