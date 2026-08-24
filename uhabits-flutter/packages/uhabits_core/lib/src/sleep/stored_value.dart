import '../models/entry.dart';
import '../models/habit_type.dart';

/// Upper bound of a day's stored value: 100 percent times one thousand.
///
/// Sleep habits reuse the numerical convention of `amount * 1000`, which is
/// what lets the existing score, streak, calendar and chart code work on them
/// unchanged.
const int maxStoredValue = 100000;

/// Smallest non-zero value a sleep habit may store.
///
/// [Entry.yesAuto], [Entry.yesManual] and [Entry.skip] occupy 1, 2 and 3. A
/// night scoring 0.003 percent would land exactly on [Entry.skip] and read as
/// "not applicable", lifting the score instead of sinking it. Collapsing that
/// whole band to zero keeps every producible value unambiguous.
const int minStoredValue = Entry.skip + 1;

/// Converts a completion ratio in `[0, 1]` into a day's stored value.
int storedValueOf(double score) {
  if (score.isNaN || score <= 0) return 0;
  if (score >= 1) return maxStoredValue;
  final int value = (score * maxStoredValue).round();
  if (value < minStoredValue) return 0;
  if (value > maxStoredValue) return maxStoredValue;
  return value;
}

/// How a sleep habit is persisted.
///
/// There is deliberately no third [HabitType]. The parity rule
/// `models.habit-type-enums#1` states the enum has exactly two entries and is
/// closed by tests; a third would force those tests to assert something the
/// ledger does not say. A sleep habit is a numerical habit that has a sleep
/// goal, and the presence of that goal is the only thing distinguishing it.
const HabitType sleepHabitType = HabitType.numerical;

/// Target value of a sleep habit: the day's percentage, out of 100.
const double sleepTargetValue = 100;

/// Unit shown for a sleep habit's daily value.
const String sleepUnit = '%';
