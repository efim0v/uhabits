import '../time/local_date.dart';

/// Port of uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Entry.kt
class Entry {
  const Entry(this.date, this.value, {this.notes = ''});

  /// The habit is not applicable on this date.
  static const int skip = 3;

  /// The user explicitly checked the habit.
  static const int yesManual = 2;

  /// The user did not perform the habit, but was not expected to, given the
  /// habit's frequency.
  static const int yesAuto = 1;

  /// The user was expected to perform the habit and did not.
  static const int no = 0;

  /// No data available for this date.
  static const int unknown = -1;

  final LocalDate date;

  /// For numerical habits this holds the measured amount multiplied by 1000.
  final int value;

  final String notes;

  /// Convenience for callers holding a raw day number rather than a LocalDate.
  Entry.raw(int daysSince2000, this.value, {this.notes = ''})
      : date = LocalDate(daysSince2000);

  String get formattedValue {
    switch (value) {
      case yesManual:
        return 'YES_MANUAL';
      case yesAuto:
        return 'YES_AUTO';
      case no:
        return 'NO';
      case skip:
        return 'SKIP';
      case unknown:
        return 'UNKNOWN';
      default:
        return value.toString();
    }
  }

  Entry copyWith({LocalDate? date, int? value, String? notes}) =>
      Entry(date ?? this.date, value ?? this.value, notes: notes ?? this.notes);

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.date == date &&
      other.value == value &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(date, value, notes);

  @override
  String toString() => 'Entry(date=$date, value=$value, notes=$notes)';

  /// The next value when the user taps a boolean checkmark.
  static int nextToggleValue(
    int value, {
    required bool isSkipEnabled,
    required bool areQuestionMarksEnabled,
  }) {
    switch (value) {
      case yesAuto:
        return yesManual;
      case yesManual:
        return isSkipEnabled ? skip : no;
      case skip:
        return no;
      case no:
        return areQuestionMarksEnabled ? unknown : yesManual;
      case unknown:
        return yesManual;
      default:
        return yesManual;
    }
  }
}
