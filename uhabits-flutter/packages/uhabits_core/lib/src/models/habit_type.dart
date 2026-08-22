/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitType.kt
/// and .../models/NumericalHabitType.kt.
///
/// The [value] of each entry is persisted in the database and must not change.
/// Dart enum names are lowerCamelCase, so [csvName] carries the Kotlin
/// `.name` string, which HabitList.toCsvString() writes verbatim.
enum HabitType {
  yesNo(0, 'YES_NO'),
  numerical(1, 'NUMERICAL');

  const HabitType(this.value, this.csvName);

  final int value;

  /// The Kotlin enum entry name, used verbatim in CSV export.
  final String csvName;

  static HabitType fromInt(int value) {
    switch (value) {
      case 0:
        return HabitType.yesNo;
      case 1:
        return HabitType.numerical;
      default:
        throw StateError('Unknown HabitType value: $value');
    }
  }
}

enum NumericalHabitType {
  atLeast(0, 'AT_LEAST'),
  atMost(1, 'AT_MOST');

  const NumericalHabitType(this.value, this.csvName);

  final int value;

  /// The Kotlin enum entry name, used verbatim in CSV export.
  final String csvName;

  static NumericalHabitType fromInt(int value) {
    switch (value) {
      case 0:
        return NumericalHabitType.atLeast;
      case 1:
        return NumericalHabitType.atMost;
      default:
        throw StateError('Unknown NumericalHabitType value: $value');
    }
  }
}
