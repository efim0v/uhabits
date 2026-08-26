import '../database/database.dart';
import 'definition_repository.dart';
import 'habit_definition.dart';

/// Carries the mark that makes a habit computed across a restore.
///
/// A backup is a byte-for-byte copy, so the row is always in the file. What
/// loses it is the import: habits are matched by uuid and given whatever id
/// this device has free, while the definition is filed under the id the other
/// device used. Without this the restored habit comes back an ordinary one,
/// and the loss is only noticed long after the backup has rotated away.
class DefinitionImporter {
  const DefinitionImporter(this._destination);

  final DefinitionRepository _destination;

  void importFor(Database source, int? sourceHabitId, int destinationHabitId) {
    if (sourceHabitId == null) return;
    final HabitDefinition? definition =
        DefinitionRepository(source).forHabit(sourceHabitId);
    if (definition == null) return;
    _destination.save(destinationHabitId, definition);
  }
}
