import '../models/entry.dart';
import '../models/habit.dart';
import '../models/habit_list.dart';
import '../time/local_date.dart';
import 'command.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/commands/CreateRepetitionCommand.kt
///
/// The Kotlin declaration is, in full:
///
/// ```kotlin
/// data class CreateRepetitionCommand(
///     val habitList: HabitList,
///     val habit: Habit,
///     val date: LocalDate,
///     val value: Int,
///     val notes: String
/// ) : Command {
///     override fun run() {
///         val entries = habit.originalEntries
///         entries.add(Entry(date, value, notes))
///         habit.recompute()
///         habitList.resort()
///     }
/// }
/// ```
///
/// By far the highest-frequency command: every checkmark tap, widget tap and
/// notification action goes through it.
///
/// Despite the name it is an upsert, not an insert. `EntryList.add` stores by
/// date in a hash map, so an entry that already exists for [date] is *replaced*
/// — value and notes both. There is no delete-repetition command either: an
/// entry is 'removed' by writing [Entry.no] (0) or [Entry.unknown] (-1) for
/// that date.
///
/// For YES_NO habits [value] is one of the `Entry` constants (UNKNOWN = -1,
/// NO = 0, YES_AUTO = 1, YES_MANUAL = 2, SKIP = 3). For NUMERICAL habits it is
/// the user value in thousandths — the call sites compute
/// `(userValue * 1000).roundToInt()` before constructing the command.
///
/// Kotlin declares it as a `data class`, whose component order is habitList,
/// habit, date, value, notes; listeners rely on `component2` being [habit] to
/// refresh a single habit rather than the whole list. The Dart port keeps that
/// positional order in the constructor and exposes the same five read-only
/// fields.
class CreateRepetitionCommand implements Command {
  CreateRepetitionCommand(
    this.habitList,
    this.habit,
    this.date,
    this.value,
    this.notes,
  );

  final HabitList habitList;

  final Habit habit;

  final LocalDate date;

  final int value;

  /// May be the empty string, and is stored verbatim. Callers that only change
  /// the value pass through the existing `entry.notes`, so notes are preserved.
  final String notes;

  /// Exactly three steps, in order:
  ///
  /// 1. `habit.originalEntries.add(Entry(date, value, notes))` — the write is
  ///    always to `originalEntries`, never to `computedEntries`.
  /// 2. `habit.recompute()` — regenerates `computedEntries` and, from it, the
  ///    scores and streaks.
  /// 3. `habitList.resort()` — needed even though no habit field changed,
  ///    because the BY_SCORE and BY_STATUS orderings depend on today's entry
  ///    value.
  ///
  /// It deliberately does NOT call `habitList.update(...)`, so no habit row is
  /// written; only the repetitions table changes.
  @override
  void run() {
    final entries = habit.originalEntries;
    entries.add(Entry(date, value, notes: notes));
    habit.recompute();
    habitList.resort();
  }
}
