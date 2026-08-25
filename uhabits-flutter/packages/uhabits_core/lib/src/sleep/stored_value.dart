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

/// The share of a night below which the calendar barely tints a cell.
///
/// Everything under it is a bad night, and telling one bad night from another
/// by eye is not worth the range it would cost.
const double dimmedBelowPercent = 50;

/// How strongly a night of [storedValue] colours its calendar cell, in `[0,1]`.
///
/// The original paints a numerical cell with the habit's colour when the day
/// met its target and one flat grey when it did not. For a habit whose whole
/// value is a percentage that throws away everything it measures: a night at
/// 95 and a night at 20 come out the same shade, and only an exact 100 is ever
/// coloured at all.
///
/// The scale is deliberately not linear. Nights cluster: someone keeping a
/// sleep goal lands between 60 and 95 almost every night, and a linear ramp
/// would squeeze that whole range into four shades nobody can tell apart while
/// spending half its range on scores that never occur. So the bottom half of
/// the percentage gets a sixth of the range and the top half gets the rest —
/// the difference between 70 and 90 becomes plain, and the difference between
/// 10 and 30 stops mattering, which is honest, because both are bad nights.
double cellIntensityOf(int storedValue) {
  if (storedValue <= 0) return 0;
  final double percent =
      (storedValue.clamp(0, maxStoredValue) / maxStoredValue) * 100;
  if (percent <= dimmedBelowPercent) {
    return 0.08 + (percent / dimmedBelowPercent) * 0.17;
  }
  return 0.25 +
      ((percent - dimmedBelowPercent) / (100 - dimmedBelowPercent)) * 0.75;
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
