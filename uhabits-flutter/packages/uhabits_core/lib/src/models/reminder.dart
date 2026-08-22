import 'weekday_list.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/Reminder.kt
///
/// An immutable value: the time of day a habit's reminder fires, plus the set
/// of weekdays it fires on. The Kotlin data class does not validate [hour] or
/// [minute]; they are documented as 0..23 and 0..59 respectively.
class Reminder {
  const Reminder(this.hour, this.minute, this.days);

  final int hour;

  final int minute;

  final WeekdayList days;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.hour == hour &&
      other.minute == minute &&
      other.days == days;

  @override
  int get hashCode => Object.hash(hour, minute, days);

  @override
  String toString() => 'Reminder(hour=$hour, minute=$minute, days=$days)';
}
