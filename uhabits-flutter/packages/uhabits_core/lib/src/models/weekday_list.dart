/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/WeekdayList.kt
///
/// A set of weekdays, bit-packed into a single integer for storage.
///
/// The index convention used throughout the app is
/// 0 = Saturday, 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday,
/// 5 = Thursday, 6 = Friday — that is, index
/// `(date.dayOfWeek.daysSinceSunday + 1) % 7`.
class WeekdayList {
  /// Builds the list from a packed integer: bit `i` set means weekday `i` is
  /// included. Bits above bit 6 are ignored.
  WeekdayList(int packedList) : _weekdays = List<bool>.filled(7, false) {
    var current = 1;
    for (var i = 0; i <= 6; i++) {
      if (packedList & current != 0) _weekdays[i] = true;
      current = current << 1;
    }
  }

  /// Builds the list from an array of booleans, copied to exactly length 7
  /// (padding with false or truncating).
  WeekdayList.fromArray(List<bool> weekdays)
      : _weekdays = List<bool>.generate(
            7, (i) => i < weekdays.length && weekdays[i]);

  static final WeekdayList everyDay = WeekdayList(127);

  final List<bool> _weekdays;

  bool get isEmpty {
    for (final d in _weekdays) {
      if (d) return false;
    }
    return true;
  }

  List<bool> toArray() => List<bool>.of(_weekdays);

  int toInteger() {
    var packedList = 0;
    var current = 1;
    for (var i = 0; i <= 6; i++) {
      if (_weekdays[i]) packedList = packedList | current;
      current = current << 1;
    }
    return packedList;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WeekdayList) return false;
    for (var i = 0; i <= 6; i++) {
      if (_weekdays[i] != other._weekdays[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_weekdays);

  @override
  String toString() => '{weekdays: [${_weekdays.join(',')}]}';
}
