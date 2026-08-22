import 'habit.dart';
import 'habit_matcher.dart';
import 'model_observable.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitList.kt
///
/// An ordered collection of [Habit]s.
///
/// Kotlin declares this as `abstract class HabitList : Iterable<Habit>`, so the
/// Dart port extends [Iterable] and leaves `iterator` to the implementations.
abstract class HabitList extends Iterable<Habit> {
  /// Creates a new HabitList.
  ///
  /// Depending on the implementation, this list can either be empty or be
  /// populated by some pre-existing habits, for example, from a certain
  /// database.
  HabitList();

  /// Kotlin's `protected constructor(filter: HabitMatcher)`, used by the
  /// filtered (child) lists.
  HabitList.filtered(this.filter);

  final ModelObservable observable = ModelObservable();

  /// Kotlin declares this `internal set`; Dart has no `internal`, so the field
  /// is writable but only the list implementations are meant to touch it.
  HabitMatcher filter = const HabitMatcher(isArchivedAllowed: true);

  /// Inserts a new habit in the list.
  ///
  /// If the id of the habit is null, the list will assign it a new id, which
  /// is guaranteed to be unique in the scope of the list. If id is not null,
  /// the caller should make sure that the list does not already contain
  /// another habit with same id, otherwise an exception will be thrown.
  ///
  /// Throws [ArgumentError] if the habit is already on the list.
  void add(Habit habit);

  /// Returns the habit with specified id, or null if none exist.
  Habit? getById(int id);

  /// Returns the habit with specified UUID, or null if none exist.
  Habit? getByUUID(String? uuid);

  /// Returns the habit that occupies a certain position.
  ///
  /// Throws when the position is invalid.
  Habit getByPosition(int position);

  /// Returns the list of habits that match a given condition.
  HabitList getFiltered(HabitMatcher? matcher);

  HabitListOrder get primaryOrder;

  set primaryOrder(HabitListOrder value);

  HabitListOrder get secondaryOrder;

  set secondaryOrder(HabitListOrder value);

  /// Returns the index of the given habit in the list, or -1 if the list does
  /// not contain the habit.
  int indexOf(Habit h);

  @override
  bool get isEmpty => size() == 0;

  /// Removes the given habit from the list.
  ///
  /// If the given habit is not in the list, does nothing.
  void remove(Habit h);

  /// Removes all the habits from the list.
  void removeAll() {
    final copy = toList();
    for (final h in copy) {
      remove(h);
    }
    observable.notifyListeners();
  }

  /// Changes the position of a habit in the list.
  ///
  /// [from] is the habit that should be moved; [to] is the habit that
  /// currently occupies the desired position.
  void reorder(Habit from, Habit to);

  void repair() {}

  /// Returns the number of habits in this list.
  int size();

  /// Notifies the list that a certain list of habits has been modified.
  ///
  /// Depending on the implementation, this operation might trigger a write to
  /// disk, or do nothing at all. To make sure that the habits get persisted,
  /// this operation must be called.
  void update(List<Habit> habits);

  /// Notifies the list that a certain habit has been modified.
  ///
  /// Kotlin overloads `update`; Dart has no overloads, so the single-habit
  /// version keeps a distinct name. See [update] for more details.
  void updateOne(Habit habit) {
    update(<Habit>[habit]);
  }

  /// Returns the list of habits in CSV format. There is one line for each
  /// habit, containing the fields name, description, frequency numerator,
  /// frequency denominator and color.
  String writeCSV() {
    final sb = StringBuffer();
    const header = <String>[
      'Position',
      'Name',
      'Type',
      'Question',
      'Description',
      'FrequencyNumerator',
      'FrequencyDenominator',
      'Color',
      'Unit',
      'Target Type',
      'Target Value',
      'Archived?'
    ];
    sb.write(_csvLine(header));
    for (final habit in this) {
      final numerator = habit.frequency.numerator;
      final denominator = habit.frequency.denominator;
      final cols = <String>[
        // Kotlin: format("%03d", indexOf(habit) + 1)
        (indexOf(habit) + 1).toString().padLeft(3, '0'),
        habit.name,
        habit.type.csvName,
        habit.question,
        habit.description,
        numerator.toString(),
        denominator.toString(),
        habit.color.toCsvColor(),
        habit.isNumerical ? habit.unit : '',
        habit.isNumerical ? habit.targetType.csvName : '',
        // Kotlin: format("%.1f", habit.targetValue)
        habit.isNumerical ? habit.targetValue.toStringAsFixed(1) : '',
        habit.isArchived.toString(),
      ];
      sb.write(_csvLine(cols));
    }
    return sb.toString();
  }

  void resort();
}

/// Port of the nested Kotlin enum `HabitList.Order`. Dart has no nested
/// classes, so the name is flattened.
enum HabitListOrder {
  byNameAsc,
  byNameDesc,
  byColorAsc,
  byColorDesc,
  byScoreAsc,
  byScoreDesc,
  byStatusAsc,
  byStatusDesc,
  byPosition,
}

/// Port of `csvLine` from
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Strings.kt.
///
/// Private to this library: `io.csv-line-writer` is its own parity feature and
/// gets its own shared home when that slice lands.
String _csvLine(List<String> fields) {
  return '${fields.map((field) {
    if (field.codeUnits.any((c) =>
        c == 0x2c /* , */ ||
        c == 0x22 /* " */ ||
        c == 0x0a /* \n */ ||
        c == 0x0d /* \r */)) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }).join(',')}\n';
}
