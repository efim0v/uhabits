/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitBullCSVImporter.kt
/// and of the two-method base class in
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/AbstractImporter.kt.
///
/// Kotlin's members are `suspend`; here they return `Future`, because
/// [UserFile] is asynchronous in Dart.
library;

import '../models/entry.dart';
import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_list.dart';
import '../models/habit_type.dart';
import '../models/model_factory.dart';
import '../time/local_date.dart';
import 'csv.dart';
import 'files.dart';
import 'logging.dart';

/// Port of `AbstractImporter`.
///
/// ```kotlin
/// abstract class AbstractImporter {
///     abstract suspend fun canHandle(file: UserFile): Boolean
///     abstract suspend fun importHabitsFromFile(file: UserFile)
/// }
/// ```
///
/// It lives in this file, rather than in one of its own, because this slice may
/// only create the three importer files; `GenericImporter`, which is the only
/// other thing that needs it, belongs to the `io.importer-dispatch` slice and
/// should import the class from here rather than declare a second copy.
abstract class AbstractImporter {
  Future<bool> canHandle(UserFile file);

  Future<void> importHabitsFromFile(UserFile file);
}

/// Class that imports data from HabitBull CSV files.
class HabitBullCSVImporter extends AbstractImporter {
  HabitBullCSVImporter(this.habitList, this.modelFactory, Logging logging)
      : logger = logging.getLogger(habitBullCSVImporterLoggerName);

  final HabitList habitList;

  final ModelFactory modelFactory;

  final Logger logger;

  @override
  Future<bool> canHandle(UserFile file) async {
    try {
      final lines = await file.lines();
      if (lines.isEmpty) return false;
      return lines[0].startsWith('HabitName,HabitDescription,HabitCategory');
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> importHabitsFromFile(UserFile file) async {
    final lines = await file.lines();
    // Kotlin uses a HashMap, which has no defined iteration order; a Dart Map
    // preserves insertion order. Only the recompute loop below iterates it, and
    // the order in which habits are recomputed is not observable.
    final map = <String, Habit>{};
    for (final line in lines) {
      final cols = parseCsvLine(line);
      if (cols.length < 6) continue;
      final name = cols[0];
      if (name == 'HabitName') continue;
      final description = cols[1];
      // Note that the date is parsed before the habit is created, so a broken
      // date on a habit's first line aborts the import without creating it.
      final date = _parseDate(cols[3]);
      var h = map[name];
      if (h == null) {
        h = modelFactory.buildHabit();
        h.name = name;
        h.description = description;
        h.frequency = Frequency.daily;
        habitList.add(h);
        map[name] = h;
        logger.info(creatingHabitMessage(name));
      }
      final notes = cols[5];
      final value = _parseInt(cols[4]);
      switch (value) {
        case 0:
          h.originalEntries.add(Entry(date, Entry.no, notes: notes));
        case 1:
          h.originalEntries.add(Entry(date, Entry.yesManual, notes: notes));
        default:
          if (value > 1 && h.type != HabitType.numerical) {
            logger.info(foundNumericalValueMessage(value));
            h.type = HabitType.numerical;
          }
          h.originalEntries.add(Entry(date, value * 1000, notes: notes));
      }
    }

    map.forEach((_, habit) => habit.recompute());
  }

  LocalDate _parseDate(String rawValue) {
    if (rawValue.contains('-')) {
      final parts = rawValue.split('-');
      return LocalDate.ymd(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }
    if (rawValue.contains('/')) {
      final parts = rawValue.split('/');
      return LocalDate.ymd(
          int.parse(parts[2]), int.parse(parts[0]), int.parse(parts[1]));
    }
    throw Exception('Unrecognized date format: $rawValue');
  }

  /// `rawValue.toInt()`, falling back to 0.
  ///
  /// Kotlin's `String.toInt()` parses a 32-bit `Int`, so a value such as
  /// `-2150000000` — which habitbull2.csv contains — throws
  /// NumberFormatException and becomes 0. Dart's integers are 64 bits wide, so
  /// the range check has to be explicit.
  int _parseInt(String rawValue) {
    final value = int.tryParse(rawValue);
    if (value == null || value < _intMin || value > _intMax) {
      logger.error(couldNotParseIntMessage(rawValue));
      return 0;
    }
    return value;
  }

  /// `Int.MIN_VALUE`.
  static const int _intMin = -2147483648;

  /// `Int.MAX_VALUE`.
  static const int _intMax = 2147483647;
}
