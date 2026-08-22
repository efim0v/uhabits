import 'habit.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/models/HabitMatcher.kt
///
/// The predicate a habit list filters by: which habits the user is currently
/// allowed to see. Kotlin declares it as a `data class` with all-default
/// parameters, so it is an immutable value — every field is final here and
/// [==]/[hashCode] compare by value.
class HabitMatcher {
  const HabitMatcher({
    this.isArchivedAllowed = false,
    this.isReminderRequired = false,
    this.isCompletedAllowed = true,
    this.isEnteredAllowed = true,
    this.searchQuery = '',
  });

  /// When false, archived habits never match.
  final bool isArchivedAllowed;

  /// When true, only habits carrying a reminder match.
  final bool isReminderRequired;

  /// When false, habits already completed today never match.
  final bool isCompletedAllowed;

  /// When false, habits with any entry for today never match.
  final bool isEnteredAllowed;

  /// Free-text filter over the habit's name, question and description. The
  /// empty string (and any string that trims to it) disables the filter.
  final String searchQuery;

  /// Kotlin's `HabitMatcher.WITH_ALARM`: every habit with a reminder,
  /// archived ones included. Used by the reminder scheduler.
  static const HabitMatcher withAlarm = HabitMatcher(
    isArchivedAllowed: true,
    isReminderRequired: true,
  );

  bool matches(Habit habit) {
    if (!isArchivedAllowed && habit.isArchived) return false;
    if (isReminderRequired && !habit.hasReminder()) return false;
    if (!isCompletedAllowed && habit.isCompletedToday()) return false;
    if (!isEnteredAllowed && habit.isEnteredToday()) return false;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.trim();
      if (q.isNotEmpty &&
          !_containsIgnoreCase(habit.name, q) &&
          !_containsIgnoreCase(habit.question, q) &&
          !_containsIgnoreCase(habit.description, q)) {
        return false;
      }
    }
    return true;
  }

  /// Kotlin's `String.contains(other, ignoreCase = true)`. It case-folds only:
  /// accents survive the fold, so "mediter" does not find "Méditer".
  static bool _containsIgnoreCase(String haystack, String needle) =>
      haystack.toLowerCase().contains(needle.toLowerCase());

  @override
  bool operator ==(Object other) =>
      other is HabitMatcher &&
      other.isArchivedAllowed == isArchivedAllowed &&
      other.isReminderRequired == isReminderRequired &&
      other.isCompletedAllowed == isCompletedAllowed &&
      other.isEnteredAllowed == isEnteredAllowed &&
      other.searchQuery == searchQuery;

  @override
  int get hashCode => Object.hash(
        isArchivedAllowed,
        isReminderRequired,
        isCompletedAllowed,
        isEnteredAllowed,
        searchQuery,
      );

  @override
  String toString() => 'HabitMatcher('
      'isArchivedAllowed=$isArchivedAllowed, '
      'isReminderRequired=$isReminderRequired, '
      'isCompletedAllowed=$isCompletedAllowed, '
      'isEnteredAllowed=$isEnteredAllowed, '
      'searchQuery=$searchQuery)';
}
