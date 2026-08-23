/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/show/views/HistoryCard.kt
///
/// Two things live here: the pure `buildState`, which turns the computed
/// entries into one [Square] per day, and the interactive half — the presenter
/// is itself the chart's [OnDateClickedListener], so a tap on a calendar cell
/// lands in this class and leaves again either as a dialog request on
/// [HistoryCardScreen] or as a [CreateRepetitionCommand].
library;

import '../../../../../commands/command_runner.dart';
import '../../../../../commands/create_repetition_command.dart';
import '../../../../../gui/theme.dart';
import '../../../../../models/entry.dart';
import '../../../../../models/habit.dart';
import '../../../../../models/habit_list.dart';
import '../../../../../models/habit_type.dart';
import '../../../../../models/palette_color.dart';
import '../../../../../preferences/preferences.dart';
import '../../../../../time/local_date.dart';
import '../../../../views/history_chart.dart';
import '../../list/list_habits_behavior.dart'
    show CheckMarkDialogCallback, NumberPickerCallback;

/// Port of the Kotlin `data class HistoryCardState`.
class HistoryCardState {
  const HistoryCardState({
    required this.color,
    required this.firstWeekday,
    required this.series,
    required this.defaultSquare,
    required this.notesIndicators,
    required this.theme,
    required this.today,
  });

  final PaletteColor color;

  final DayOfWeek firstWeekday;

  /// One square per day of `[oldest known entry, today]`, newest first.
  final List<Square> series;

  /// Used for every grid cell past the end of [series]; always [Square.off].
  final Square defaultSquare;

  final List<bool> notesIndicators;

  final Theme theme;

  final LocalDate today;

  @override
  bool operator ==(Object other) =>
      other is HistoryCardState &&
      other.color == color &&
      other.firstWeekday == firstWeekday &&
      _listEquals(other.series, series) &&
      other.defaultSquare == defaultSquare &&
      _listEquals(other.notesIndicators, notesIndicators) &&
      other.theme == theme &&
      other.today == today;

  @override
  int get hashCode => Object.hash(
        color,
        firstWeekday,
        Object.hashAll(series),
        defaultSquare,
        Object.hashAll(notesIndicators),
        theme,
        today,
      );

  @override
  String toString() => 'HistoryCardState(color=$color, '
      'firstWeekday=$firstWeekday, series=$series, '
      'defaultSquare=$defaultSquare, notesIndicators=$notesIndicators, '
      'theme=$theme, today=$today)';
}

/// Port of the nested Kotlin interface `HistoryCardPresenter.Screen`. Every
/// member is a dialog or a haptic buzz, so the whole interface belongs to the
/// widget layer.
abstract interface class HistoryCardScreen {
  void showHistoryEditorDialog(OnDateClickedListener listener);

  /// Haptic feedback; fired for every accepted press, before anything else.
  void showFeedback();

  void showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  );

  void showCheckmarkPopup(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  );
}

class HistoryCardPresenter extends OnDateClickedListener {
  HistoryCardPresenter({
    required this.commandRunner,
    required this.habit,
    required this.habitList,
    required this.preferences,
    required this.screen,
  });

  final CommandRunner commandRunner;

  final Habit habit;

  final HabitList habitList;

  final Preferences preferences;

  final HistoryCardScreen screen;

  /// Numerical habits ignore the short-toggle preference entirely: both press
  /// lengths open the number popup.
  @override
  void onDateLongPress(LocalDate date) {
    screen.showFeedback();
    if (habit.isNumerical) {
      _showNumberPopup(date);
    } else {
      if (preferences.isShortToggleEnabled) {
        _showCheckmarkPopup(date);
      } else {
        _toggle(date);
      }
    }
  }

  @override
  void onDateShortPress(LocalDate date) {
    screen.showFeedback();
    if (habit.isNumerical) {
      _showNumberPopup(date);
    } else {
      if (preferences.isShortToggleEnabled) {
        _toggle(date);
      } else {
        _showCheckmarkPopup(date);
      }
    }
  }

  void _showCheckmarkPopup(LocalDate date) {
    final entry = habit.computedEntries.get(date);
    screen.showCheckmarkPopup(
      entry.value,
      entry.notes,
      habit.color,
      _CheckMarkCallback((int newValue, String newNotes) {
        commandRunner.run(
          CreateRepetitionCommand(habitList, habit, date, newValue, newNotes),
        );
      }),
    );
  }

  /// The existing notes are carried over unchanged: toggling never clears a
  /// note.
  void _toggle(LocalDate date) {
    final entry = habit.computedEntries.get(date);
    final nextValue = Entry.nextToggleValue(
      entry.value,
      isSkipEnabled: preferences.isSkipEnabled,
      areQuestionMarksEnabled: preferences.areQuestionMarksEnabled,
    );
    commandRunner.run(
      CreateRepetitionCommand(habitList, habit, date, nextValue, entry.notes),
    );
  }

  void _showNumberPopup(LocalDate date) {
    final entry = habit.computedEntries.get(date);
    final oldValue = entry.value;
    screen.showNumberPopup(
      oldValue / 1000.0,
      entry.notes,
      _NumberCallback((double newValue, String newNotes) {
        final thousands = _roundToInt(newValue * 1000);
        commandRunner.run(
          CreateRepetitionCommand(habitList, habit, date, thousands, newNotes),
        );
      }),
    );
  }

  void onClickEditButton() {
    screen.showHistoryEditorDialog(this);
  }

  static HistoryCardState buildState({
    required Habit habit,
    required DayOfWeek firstWeekday,
    required Theme theme,
  }) {
    final today = getToday();
    final known = habit.computedEntries.getKnown();
    final oldest = known.isEmpty ? today : known.last.date;
    final entries = habit.computedEntries.getByInterval(oldest, today);

    final List<Square> series;
    if (habit.isNumerical) {
      // The order of these branches is the contract: UNKNOWN wins over
      // everything, then SKIP, and only then is the target consulted. A SKIP
      // is stored as the value 3, i.e. 0.003 — which would otherwise satisfy
      // every AT_MOST target.
      series = entries.map((Entry it) {
        if (it.value == Entry.unknown) return Square.off;
        if (it.value == Entry.skip) return Square.hatched;
        if (habit.targetType == NumericalHabitType.atMost &&
            it.value / 1000.0 <= habit.targetValue) {
          return Square.on;
        }
        if (habit.targetType == NumericalHabitType.atLeast &&
            it.value / 1000.0 >= habit.targetValue) {
          return Square.on;
        }
        return Square.grey;
      }).toList();
    } else {
      series = entries.map((Entry it) {
        switch (it.value) {
          case Entry.yesManual:
            return Square.on;
          case Entry.yesAuto:
            return Square.dimmed;
          case Entry.skip:
            return Square.hatched;
          default:
            // Both NO (0) and UNKNOWN (-1) land here.
            return Square.off;
        }
      }).toList();
    }

    final notesIndicators =
        entries.map((Entry it) => it.notes != '').toList();

    return HistoryCardState(
      color: habit.color,
      firstWeekday: firstWeekday,
      today: today,
      theme: theme,
      series: series,
      defaultSquare: Square.off,
      notesIndicators: notesIndicators,
    );
  }
}

/// Kotlin `Double.roundToInt()`: half away from zero, unlike `kotlin.math.round`
/// (and unlike Dart's own `round()` only in that Dart's already matches). Kept
/// explicit so the rounding rule is visible at the call site.
int _roundToInt(double value) => value.round();

class _NumberCallback extends NumberPickerCallback {
  _NumberCallback(this._onPicked);

  final void Function(double newValue, String notes) _onPicked;

  @override
  void onNumberPicked(double newValue, String notes) =>
      _onPicked(newValue, notes);
}

class _CheckMarkCallback extends CheckMarkDialogCallback {
  _CheckMarkCallback(this._onSaved);

  final void Function(int value, String notes) _onSaved;

  @override
  void onNotesSaved(int value, String notes) => _onSaved(value, notes);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
