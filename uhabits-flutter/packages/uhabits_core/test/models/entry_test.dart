import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart';
import 'package:uhabits_core/src/ui/views/history_chart.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// A [HistoryCardScreen] that records every dialog the presenter asks for and
/// keeps the callback it was handed, so the test can answer as the dialog.
class _RecordingHistoryScreen implements HistoryCardScreen {
  final List<String> log = <String>[];

  int? checkmarkValue;
  String? checkmarkNotes;
  PaletteColor? checkmarkColor;
  CheckMarkDialogCallback? checkmarkCallback;

  @override
  void showHistoryEditorDialog(OnDateClickedListener listener) =>
      log.add('editor');

  @override
  void showFeedback() => log.add('feedback');

  @override
  void showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) =>
      log.add('number');

  @override
  void showCheckmarkPopup(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  ) {
    log.add('checkmark');
    checkmarkValue = selectedValue;
    checkmarkNotes = notes;
    checkmarkColor = color;
    checkmarkCallback = callback;
  }
}

/// Ported from uhabits-core/src/commonTest/kotlin/org/isoron/uhabits/core/models/EntryTest.kt
void main() {
  group('models.entry-values', () {
    test('#1 immutable value object of date, value and notes', () {
      final a = Entry(LocalDate(0), Entry.yesManual, notes: 'n');
      final b = Entry(LocalDate(0), Entry.yesManual, notes: 'n');
      expect(a, b, reason: 'models.entry-values#1');
      expect(a.notes, 'n', reason: 'models.entry-values#1');
      expect(Entry(LocalDate(0), Entry.yesManual).notes, '',
          reason: 'models.entry-values#1');
      expect(a == Entry(LocalDate(1), Entry.yesManual, notes: 'n'), isFalse,
          reason: 'models.entry-values#1');
    });

    test('#2 the five reserved values', () {
      expect(Entry.skip, 3, reason: 'models.entry-values#2');
      expect(Entry.yesManual, 2, reason: 'models.entry-values#2');
      expect(Entry.yesAuto, 1, reason: 'models.entry-values#2');
      expect(Entry.no, 0, reason: 'models.entry-values#2');
      expect(Entry.unknown, -1, reason: 'models.entry-values#2');
    });

    test('#5 formattedValue names the reserved values', () {
      expect(Entry(LocalDate(0), Entry.yesManual).formattedValue, 'YES_MANUAL',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.yesAuto).formattedValue, 'YES_AUTO',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.no).formattedValue, 'NO',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.skip).formattedValue, 'SKIP',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), Entry.unknown).formattedValue, 'UNKNOWN',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), 2000).formattedValue, '2000',
          reason: 'models.entry-values#5');
      expect(Entry(LocalDate(0), 3000).formattedValue, '3000',
          reason: 'models.entry-values#5');
    });

    test('#3 #7 reserved value semantics', () {
      // SKIP: not applicable. YES_MANUAL: user checked it. YES_AUTO: not
      // performed but not expected, given the frequency. NO: expected and not
      // performed. UNKNOWN: no data.
      expect(
          [Entry.skip, Entry.yesManual, Entry.yesAuto, Entry.no, Entry.unknown],
          [3, 2, 1, 0, -1],
          reason: 'models.entry-values#3 models.entry-values#7');
    });

    test('#4 numerical values are stored multiplied by 1000', () {
      final entry = Entry.raw(0, 2000);
      expect(entry.value / 1000.0, 2.0, reason: 'models.entry-values#4');
      expect(Entry.raw(0, 1500).value / 1000.0, 1.5,
          reason: 'models.entry-values#4');
    });

    test('#8 formattedValue renders unreserved integers as decimals', () {
      expect(Entry.raw(0, 12345).formattedValue, '12345',
          reason: 'models.entry-values#8');
    });

    test('#6 a numerical value of 3 is indistinguishable from SKIP', () {
      // Upstream bug, reproduced deliberately. See docs/parity/DEVIATIONS.md
      // before changing this.
      expect(Entry(LocalDate(0), 3).formattedValue, 'SKIP',
          reason: 'models.entry-values#6');
    });

    test('#10 the checkmark dialog writes an end state directly; the cycle only '
        'runs when the short-toggle preference bypasses the dialog', () {
      // The dialog itself is an Android view; what is ported — and what this
      // asserts — is the presenter seam it talks to.
      setToday(LocalDate.ymd(2015, 1, 25));
      addTearDown(resetToday);
      final today = getToday();

      final factory = MemoryModelFactory();
      final habitList = factory.buildHabitList();
      final habit = factory.buildHabit()..name = 'Meditate';
      habitList.add(habit);

      final storage = MemoryStorage();
      final prefs = Preferences(storage)
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;
      final commandRunner = CommandRunner(CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      ));
      final screen = _RecordingHistoryScreen();
      final presenter = HistoryCardPresenter(
        commandRunner: commandRunner,
        habit: habit,
        habitList: habitList,
        preferences: prefs,
        screen: screen,
      );

      // Short toggle off (the default): a press opens the dialog instead of
      // cycling, pre-filled with the current value.
      expect(prefs.isShortToggleEnabled, isFalse,
          reason: 'models.entry-values#10 and '
              'settings.preferences.short-toggle#4 — HistoryCard branches on '
              'preferences.isShortToggleEnabled exactly as the list buttons '
              'do: with it off a short press opens the editor');
      presenter.onDateShortPress(today);
      expect(screen.log, ['feedback', 'checkmark'],
          reason: 'models.entry-values#10 and '
              'settings.preferences.short-toggle#4');
      expect(screen.checkmarkValue, Entry.unknown,
          reason: 'models.entry-values#10');

      // Every one of the four end states the dialog offers is stored verbatim.
      // Cycling from UNKNOWN would have produced YES_MANUAL for all four.
      for (final chosen in <int>[
        Entry.yesManual,
        Entry.skip,
        Entry.no,
        Entry.unknown,
      ]) {
        screen.checkmarkCallback!.onNotesSaved(chosen, 'note');
        expect(habit.originalEntries.get(today).value, chosen,
            reason: 'models.entry-values#10 (chose $chosen)');
        expect(habit.originalEntries.get(today).notes, 'note',
            reason: 'models.entry-values#10 (chose $chosen)');
      }

      // Turning the preference on swaps the two gestures: the short press now
      // bypasses the dialog and runs nextToggleValue instead.
      prefs.isShortToggleEnabled = true;
      commandRunner.run(
          CreateRepetitionCommand(habitList, habit, today, Entry.yesManual, ''));
      screen.log.clear();

      presenter.onDateShortPress(today);
      expect(screen.log, ['feedback'],
          reason: 'models.entry-values#10 and '
              'settings.preferences.short-toggle#4 — with the preference on '
              'the short press toggles instead of opening the dialog');
      expect(
        habit.originalEntries.get(today).value,
        Entry.nextToggleValue(
          Entry.yesManual,
          isSkipEnabled: true,
          areQuestionMarksEnabled: true,
        ),
        reason: 'models.entry-values#10',
      );
      expect(habit.originalEntries.get(today).value, Entry.skip,
          reason: 'models.entry-values#10');

      // ...and the long press is the one that now opens the dialog.
      screen.log.clear();
      presenter.onDateLongPress(today);
      expect(screen.log, ['feedback', 'checkmark'],
          reason: 'models.entry-values#10 and '
              'settings.preferences.short-toggle#4 — and the long press is '
              'the one that now opens the history editor');
      expect(screen.checkmarkValue, Entry.skip,
          reason: 'models.entry-values#10 and '
              'settings.preferences.short-toggle#4');
    });
  });

  group('models.entry-toggle-cycle', () {
    int next(int value, {bool skip = false, bool unknown = false}) =>
        Entry.nextToggleValue(value,
            isSkipEnabled: skip, areQuestionMarksEnabled: unknown);

    test('#2 YES_AUTO always becomes YES_MANUAL', () {
      expect(next(Entry.yesAuto), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#2');
      expect(next(Entry.yesAuto, skip: true, unknown: true), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#2');
    });

    test('#3 YES_MANUAL becomes SKIP only when skip is enabled', () {
      expect(next(Entry.yesManual, skip: true), Entry.skip,
          reason: 'models.entry-toggle-cycle#3');
      expect(next(Entry.yesManual, skip: false), Entry.no,
          reason: 'models.entry-toggle-cycle#3');
    });

    test('#4 SKIP always becomes NO', () {
      expect(next(Entry.skip, skip: true, unknown: true), Entry.no,
          reason: 'models.entry-toggle-cycle#4');
      expect(next(Entry.skip), Entry.no,
          reason: 'models.entry-toggle-cycle#4');
    });

    test('#5 NO becomes UNKNOWN only when question marks are enabled', () {
      expect(next(Entry.no, unknown: true), Entry.unknown,
          reason: 'models.entry-toggle-cycle#5');
      expect(next(Entry.no, unknown: false), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#5');
    });

    test('#6 UNKNOWN always becomes YES_MANUAL', () {
      expect(next(Entry.unknown, skip: true, unknown: true), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#6');
    });

    test('#7 any other value becomes YES_MANUAL', () {
      expect(next(2000, skip: true, unknown: true), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#7');
    });

    test('#1 #9 nextToggleValue is a pure total function', () {
      for (final value in [-5, -1, 0, 1, 2, 3, 2000]) {
        final first = next(value, skip: true, unknown: true);
        final second = next(value, skip: true, unknown: true);
        expect(first, second,
            reason: 'models.entry-toggle-cycle#1 models.entry-values#9');
      }
    });

    test('#8 full cycle with skip and question marks enabled', () {
      var v = Entry.yesManual;
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.skip, reason: 'models.entry-toggle-cycle#8');
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.no, reason: 'models.entry-toggle-cycle#8');
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.unknown, reason: 'models.entry-toggle-cycle#8');
      v = next(v, skip: true, unknown: true);
      expect(v, Entry.yesManual, reason: 'models.entry-toggle-cycle#8');
    });

    test('#9 cycle with both disabled is YES_MANUAL to NO and back', () {
      expect(next(Entry.yesManual), Entry.no,
          reason: 'models.entry-toggle-cycle#9');
      expect(next(Entry.no), Entry.yesManual,
          reason: 'models.entry-toggle-cycle#9');
    });

    test('#10 the two flags are the pref_skip_enabled and pref_unknown_enabled '
        'preferences, both defaulting to false', () {
      final storage = MemoryStorage();
      final prefs = Preferences(storage);

      // Nothing stored: both default to false, so the cycle is the short one.
      expect(prefs.isSkipEnabled, isFalse,
          reason: 'models.entry-toggle-cycle#10');
      expect(prefs.areQuestionMarksEnabled, isFalse,
          reason: 'models.entry-toggle-cycle#10');
      expect(
        next(Entry.yesManual,
            skip: prefs.isSkipEnabled,
            unknown: prefs.areQuestionMarksEnabled),
        Entry.no,
        reason: 'models.entry-toggle-cycle#10',
      );

      // Those exact key strings are what the getters read.
      storage.putBoolean('pref_skip_enabled', true);
      expect(prefs.isSkipEnabled, isTrue,
          reason: 'models.entry-toggle-cycle#10');
      storage.putBoolean('pref_unknown_enabled', true);
      expect(prefs.areQuestionMarksEnabled, isTrue,
          reason: 'models.entry-toggle-cycle#10');
      expect(
        next(Entry.yesManual,
            skip: prefs.isSkipEnabled,
            unknown: prefs.areQuestionMarksEnabled),
        Entry.skip,
        reason: 'models.entry-toggle-cycle#10',
      );
      expect(
        next(Entry.no,
            skip: prefs.isSkipEnabled,
            unknown: prefs.areQuestionMarksEnabled),
        Entry.unknown,
        reason: 'models.entry-toggle-cycle#10',
      );

      // ...and what the setters write back to.
      final writeStorage = MemoryStorage();
      final writePrefs = Preferences(writeStorage)
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;
      expect(writeStorage.getBoolean('pref_skip_enabled', false), isTrue,
          reason: 'models.entry-toggle-cycle#10');
      expect(writeStorage.getBoolean('pref_unknown_enabled', false), isTrue,
          reason: 'models.entry-toggle-cycle#10');
      expect(writePrefs.isSkipEnabled, isTrue,
          reason: 'models.entry-toggle-cycle#10');
      expect(writePrefs.areQuestionMarksEnabled, isTrue,
          reason: 'models.entry-toggle-cycle#10');
    });
  });
}
