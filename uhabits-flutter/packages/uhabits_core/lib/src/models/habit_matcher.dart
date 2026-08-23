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

  /// Kotlin's `String.contains(other, ignoreCase = true)`.
  ///
  /// Not `haystack.toLowerCase().contains(needle.toLowerCase())`: Kotlin folds
  /// *per character*, through `Char.equals(other, ignoreCase = true)` —
  /// `toUpper(a) == toUpper(b) || toLower(toUpper(a)) == toLower(toUpper(b))`
  /// — over every alignment of the needle, which is `regionMatchesImpl`. The
  /// uppercase step is what makes the fold work for the characters whose
  /// lowercase forms are not unique: 'ı' (U+0131, Turkish dotless i) and 'i'
  /// both uppercase to 'I', and 'Σ', 'σ' and 'ς' (Greek final sigma) all
  /// uppercase to 'Σ'. Lowercasing both sides once loses exactly those,
  /// so "yazi" would not find "Yazı" (`models.habit-matcher#5`,
  /// `audit8.habit-search-folds-case-differently-from#1`).
  ///
  /// It case-folds *only*: accents survive the fold, so "mediter" still does
  /// not find "Méditer", and — because the comparison is one UTF-16 unit
  /// against one UTF-16 unit — neither side can grow or shrink, so "STRASSE"
  /// does not find "Straße".
  static bool _containsIgnoreCase(String haystack, String needle) {
    final int n = needle.length;
    if (n == 0) return true;
    for (int start = 0; start + n <= haystack.length; start++) {
      bool matched = true;
      for (int i = 0; i < n; i++) {
        if (!_charEqualsIgnoreCase(
            haystack.codeUnitAt(start + i), needle.codeUnitAt(i))) {
          matched = false;
          break;
        }
      }
      if (matched) return true;
    }
    return false;
  }

  /// Kotlin's `Char.equals(other, ignoreCase = true)`.
  static bool _charEqualsIgnoreCase(int a, int b) {
    if (a == b) return true;
    final int upperA = _uppercaseChar(a);
    final int upperB = _uppercaseChar(b);
    if (upperA == upperB) return true;
    return _lowercaseChar(upperA) == _lowercaseChar(upperB);
  }

  /// Kotlin's `Char.uppercaseChar()`: the simple, single-character uppercase
  /// mapping. A character whose uppercase form is a *string* ('ß' → "SS", the
  /// 'ﬁ' ligature → "FI") has no single-character mapping and stays as it is,
  /// which is why the fold can never change a string's length.
  static int _uppercaseChar(int unit) => _mapChar(unit, upper: true);

  /// Kotlin's `Char.lowercaseChar()`.
  static int _lowercaseChar(int unit) => _mapChar(unit, upper: false);

  static int _mapChar(int unit, {required bool upper}) {
    // A lone surrogate is half of a character and has no case of its own; it
    // compares by identity, exactly as in Kotlin, where the fold also runs on
    // UTF-16 units.
    if (unit >= 0xD800 && unit <= 0xDFFF) return unit;
    final String c = String.fromCharCode(unit);
    final String mapped = upper ? c.toUpperCase() : c.toLowerCase();
    return mapped.length == 1 ? mapped.codeUnitAt(0) : unit;
  }

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
