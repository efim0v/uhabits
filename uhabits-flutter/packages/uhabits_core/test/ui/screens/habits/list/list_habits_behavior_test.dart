/// Ported from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/ui/screens/habits/list/ListHabitsBehavior.kt,
/// .../list/HintList.kt and .../list/HintListFactory.kt, together with their
/// Kotlin tests
/// (uhabits-core/src/commonTest/.../ui/screens/habits/list/ListHabitsBehaviorTest.kt
/// and .../list/HintListTest.kt).
///
/// Every `expect` carries the parity-ledger rule id it exercises.
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/hint_list.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/list_habits_behavior.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// One `screen.showConfetti(color, x, y)` call.
class _Confetti {
  _Confetti(this.color, this.x, this.y);

  final PaletteColor color;
  final double x;
  final double y;
}

/// Stands in for the Flutter widget layer. Every method appends to the shared
/// ordering [log] so the tests can assert the interleaving of screen calls and
/// command dispatches.
class _FakeScreen implements ListHabitsBehaviorScreen {
  _FakeScreen(this.log);

  final List<String> log;

  final List<Habit> habitScreens = <Habit>[];
  int introCount = 0;
  final List<ListHabitsBehaviorMessage> messages =
      <ListHabitsBehaviorMessage>[];
  final List<String> bugReports = <String>[];
  final List<String> sentFiles = <String>[];
  final List<_Confetti> confetti = <_Confetti>[];

  int numberPopupCount = 0;
  double? numberPopupValue;
  String? numberPopupNotes;
  NumberPickerCallback? numberPopupCallback;

  int checkmarkPopupCount = 0;
  int? checkmarkPopupValue;
  String? checkmarkPopupNotes;
  PaletteColor? checkmarkPopupColor;
  CheckMarkDialogCallback? checkmarkPopupCallback;

  @override
  void showHabitScreen(Habit h) {
    log.add('showHabitScreen');
    habitScreens.add(h);
  }

  @override
  void showIntroScreen() {
    log.add('showIntroScreen');
    introCount++;
  }

  @override
  void showMessage(ListHabitsBehaviorMessage m) {
    log.add('message:${m.name}');
    messages.add(m);
  }

  @override
  void showNumberPopup(
    double value,
    String notes,
    NumberPickerCallback callback,
  ) {
    log.add('showNumberPopup');
    numberPopupCount++;
    numberPopupValue = value;
    numberPopupNotes = notes;
    numberPopupCallback = callback;
  }

  @override
  void showCheckmarkPopup(
    int selectedValue,
    String notes,
    PaletteColor color,
    CheckMarkDialogCallback callback,
  ) {
    log.add('showCheckmarkPopup');
    checkmarkPopupCount++;
    checkmarkPopupValue = selectedValue;
    checkmarkPopupNotes = notes;
    checkmarkPopupColor = color;
    checkmarkPopupCallback = callback;
  }

  @override
  void showSendBugReportToDeveloperScreen(String log_) {
    log.add('showSendBugReportToDeveloperScreen');
    bugReports.add(log_);
  }

  @override
  void showSendFileScreen(String filename) {
    log.add('showSendFileScreen');
    sentFiles.add(filename);
  }

  @override
  void showConfetti(PaletteColor color, double x, double y) {
    log.add('confetti');
    confetti.add(_Confetti(color, x, y));
  }
}

class _FakeDirFinder implements ListHabitsBehaviorDirFinder {
  _FakeDirFinder(this.dir);

  final UserFile dir;
  int callCount = 0;

  @override
  UserFile getCSVOutputDir() {
    callCount++;
    return dir;
  }
}

class _FakeBugReporter implements ListHabitsBehaviorBugReporter {
  _FakeBugReporter(this.log);

  final List<String> log;

  String report = 'hello';
  Object? throwOnGet;
  int dumpCount = 0;

  @override
  void dumpBugReportToFile() {
    log.add('bug.dump');
    dumpCount++;
  }

  @override
  String getBugReport() {
    log.add('bug.get');
    final t = throwOnGet;
    if (t != null) throw t;
    return report;
  }
}

/// A [MemoryHabitList] that records the calls [ListHabitsBehavior] makes
/// straight onto the model, bypassing [CommandRunner].
class _SpyHabitList extends MemoryHabitList {
  _SpyHabitList(this.log);

  final List<String> log;

  int repairCount = 0;
  int resortCount = 0;
  final List<List<Habit>> reorders = <List<Habit>>[];

  @override
  void repair() {
    log.add('repair');
    repairCount++;
    super.repair();
  }

  @override
  void reorder(Habit from, Habit to) {
    log.add('reorder');
    reorders.add(<Habit>[from, to]);
    super.reorder(from, to);
  }

  /// Deliberately kept out of the ordering [log]: `resort` fires on every
  /// `add`, which would drown the interleavings the tests care about.
  @override
  void resort() {
    resortCount++;
    super.resort();
  }
}

class _LoggingCommandListener implements CommandRunnerListener {
  _LoggingCommandListener(this.log);

  final List<String> log;
  final List<Command> commands = <Command>[];

  @override
  void onCommandFinished(Command command) {
    log.add('command');
    commands.add(command);
  }
}

class _TaskLog implements TaskRunnerListener {
  final List<Task> started = <Task>[];

  @override
  void onTaskStarted(Task task) {
    started.add(task);
  }

  @override
  void onTaskFinished(Task task) {}
}

/// Stands in for `org.isoron.uhabits.core.tasks.ExportCSVTask`, which lives in
/// `tasks/` and is not part of this slice: it swallows every failure and
/// reports a null filename from `onPostExecute`.
class _FakeExportTask extends Task {
  _FakeExportTask(this.log, this.filename, this.listener);

  final List<String> log;
  final String? filename;
  final ExportCsvListener listener;

  @override
  FutureOr<void> doInBackground() {
    log.add('export.background');
  }

  @override
  void onPostExecute() {
    listener(filename);
  }
}

/// `BaseUnitTest.setUp` plus `ListHabitsBehaviorTest.setUp`, bundled so a test
/// that needs a second, differently populated list can build one.
class _Harness {
  _Harness() {
    commandListener = _LoggingCommandListener(log);
    modelFactory = MemoryModelFactory();
    habitList = _SpyHabitList(log);
    fixtures = HabitFixtures(modelFactory, habitList);
    taskRunner = CoroutineTaskRunner(
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
    taskRunner.addListener(taskLog);
    commandRunner = CommandRunner(taskRunner);
    commandRunner.addListener(commandListener);
    prefs = Preferences(storage);
    screen = _FakeScreen(log);
    dirFinder = _FakeDirFinder(LocalUserFile('/tmp/uhabits-csv-out'));
    bugReporter = _FakeBugReporter(log);
    behavior = ListHabitsBehavior(
      habitList,
      dirFinder,
      taskRunner,
      screen,
      commandRunner,
      prefs,
      bugReporter,
      exportCsvTaskFactory: (
        HabitList list,
        List<Habit> selected,
        UserFile outputDir,
        ExportCsvListener listener,
      ) {
        exportListArg = list;
        exportSelectedArg = selected;
        exportOutputDirArg = outputDir;
        exportTaskCount++;
        return _FakeExportTask(log, exportFilename, listener);
      },
    );
  }

  final List<String> log = <String>[];
  late final _LoggingCommandListener commandListener;
  final _TaskLog taskLog = _TaskLog();
  final MemoryStorage storage = MemoryStorage();

  late final MemoryModelFactory modelFactory;
  late final _SpyHabitList habitList;
  late final HabitFixtures fixtures;
  late final TaskRunner taskRunner;
  late final CommandRunner commandRunner;
  late final Preferences prefs;
  late final _FakeScreen screen;
  late final _FakeDirFinder dirFinder;
  late final _FakeBugReporter bugReporter;
  late final ListHabitsBehavior behavior;

  /// What the stand-in export task reports back to the behavior.
  String? exportFilename = '/tmp/uhabits-csv-out/Loop Habits CSV.zip';
  int exportTaskCount = 0;
  HabitList? exportListArg;
  List<Habit>? exportSelectedArg;
  UserFile? exportOutputDirArg;

  /// Drops the ordering entries produced by the fixtures, keeping the
  /// commands actually dispatched by the behavior visible.
  void resetLog() {
    log.clear();
    commandListener.commands.clear();
  }
}

/// A [PreferencesStorage] that records every write, so that
/// `list-habits.hints#4` ("returns null without touching preferences") can be
/// asserted.
class _RecordingStorage extends MemoryStorage {
  final List<String> writes = <String>[];

  @override
  void putInt(String key, int value) {
    writes.add('putInt($key, $value)');
    super.putInt(key, value);
  }

  @override
  void putLong(String key, int value) {
    writes.add('putLong($key, $value)');
    super.putLong(key, value);
  }
}

void main() {
  late _Harness h;
  late Habit habit1;
  late Habit habit2;
  late LocalDate today;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    h = _Harness();
    // ListHabitsBehaviorTest.setUp: a short yes/no habit and a numerical one.
    habit1 = h.fixtures.createShortHabit();
    habit2 = h.fixtures.createNumericalHabit();
    h.habitList.add(habit1);
    h.habitList.add(habit2);
    today = getToday();
    h.resetLog();
  });

  tearDown(resetToday);

  // -------------------------------------------------------------------------
  // list-habits.toggle-from-row
  // -------------------------------------------------------------------------
  group('list-habits.toggle-from-row', () {
    test('onToggle runs CreateRepetitionCommand and only then the confetti',
        () {
      h.behavior.onToggle(habit1, today, Entry.yesManual, 'note', 12.0, 34.0);

      expect(
        h.commandListener.commands.single,
        isA<CreateRepetitionCommand>()
            .having((c) => c.habitList, 'habitList', same(h.habitList))
            .having((c) => c.habit, 'habit', same(habit1))
            .having((c) => c.date, 'date', today)
            .having((c) => c.value, 'value', Entry.yesManual)
            .having((c) => c.notes, 'notes', 'note'),
        reason: 'list-habits.toggle-from-row#1 — onToggle runs '
            'CreateRepetitionCommand(habitList, habit, date, value, notes)',
      );
      expect(
        h.log,
        <String>['command', 'confetti'],
        reason: 'list-habits.toggle-from-row#5 — the command runs FIRST and '
            'only then showConfetti is called',
      );
      expect(
        h.screen.confetti.single.color,
        habit1.color,
        reason: 'list-habits.toggle-from-row#1 — confetti uses habit.color',
      );
      expect(
        <double>[h.screen.confetti.single.x, h.screen.confetti.single.y],
        <double>[12.0, 34.0],
        reason: 'list-habits.toggle-from-row#1 — confetti is shown at (x, y)',
      );
    });

    test('onToggle shows confetti if and only if the value is YES_MANUAL', () {
      for (final value in <int>[Entry.no, Entry.skip, Entry.unknown]) {
        h.screen.confetti.clear();
        h.behavior.onToggle(habit1, today, value, '', 1.0, 2.0);
        expect(
          h.screen.confetti,
          isEmpty,
          reason: 'list-habits.toggle-from-row#1 and '
              'settings.preferences.disable-animations#5 — no confetti for '
              'value $value, only for YES_MANUAL(2)',
        );
      }
      h.behavior.onToggle(habit1, today, Entry.yesAuto, '', 1.0, 2.0);
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.toggle-from-row#5 and '
            'settings.preferences.disable-animations#5 — YES_AUTO(1) is not '
            'YES_MANUAL(2), so no confetti',
      );
      h.screen.confetti.clear();
      h.behavior.onToggle(habit1, today, Entry.yesManual, '', 1.0, 2.0);
      expect(
        h.screen.confetti.length,
        1,
        reason: 'settings.preferences.disable-animations#5 — onToggle asks '
            'for the confetti only when the new value is YES_MANUAL. Whether '
            'the burst is then drawn is the screen\'s decision, not the '
            "presenter's",
      );
    });

    test('the command writes the entry, recomputes and resorts', () {
      expect(
        habit1.isCompletedToday(),
        isTrue,
        reason: 'list-habits.toggle-from-row#2 — precondition: the short habit '
            'fixture is checked today',
      );
      final resortsBefore = h.habitList.resortCount;

      h.behavior.onToggle(habit1, today, Entry.no, '', 0.0, 0.0);

      expect(
        habit1.originalEntries.get(today).value,
        Entry.no,
        reason: 'list-habits.toggle-from-row#2 — the entry is added to the '
            "habit's original entries",
      );
      expect(
        habit1.isCompletedToday(),
        isFalse,
        reason: 'list-habits.toggle-from-row#2 — the derived (computed) '
            'entries are recomputed',
      );
      expect(
        h.habitList.resortCount,
        greaterThan(resortsBefore),
        reason: 'list-habits.toggle-from-row#2 — the habit list is re-sorted',
      );
    });

    test('onEdit reads computedEntries and branches on the habit type', () {
      h.behavior.onEdit(habit2, today, 0.0, 0.0);
      expect(
        <int>[h.screen.numberPopupCount, h.screen.checkmarkPopupCount],
        <int>[1, 0],
        reason: 'list-habits.toggle-from-row#6 — a NUMERICAL habit takes the '
            'number-popup branch',
      );
      expect(
        h.screen.numberPopupValue,
        habit2.computedEntries.get(today).value / 1000.0,
        reason: 'list-habits.toggle-from-row#6 — onEdit reads '
            'habit.computedEntries.get(date)',
      );

      h.behavior.onEdit(habit1, today, 0.0, 0.0);
      expect(
        <int>[h.screen.numberPopupCount, h.screen.checkmarkPopupCount],
        <int>[1, 1],
        reason: 'list-habits.toggle-from-row#6 — a YES_NO habit takes the '
            'checkmark-popup branch',
      );
      expect(
        h.screen.checkmarkPopupValue,
        habit1.computedEntries.get(today).value,
        reason: 'list-habits.toggle-from-row#6 — onEdit reads '
            'habit.computedEntries.get(date)',
      );
    });

    test('NUMERICAL branch: popup args, scaling, confetti, then command', () {
      h.behavior.onEdit(habit2, today, 7.0, 8.0);

      expect(
        h.screen.numberPopupValue,
        0.1,
        reason: 'list-habits.toggle-from-row#7 — the number popup is '
            'pre-filled with entry.value / 1000.0 (fixture value 100)',
      );
      expect(
        h.screen.numberPopupNotes,
        habit2.computedEntries.get(today).notes,
        reason: 'list-habits.toggle-from-row#7 — the number popup is '
            'pre-filled with entry.notes',
      );

      h.screen.numberPopupCallback!.onNumberPicked(100.0, 'ran far');

      expect(
        habit2.computedEntries.get(today).value,
        100000,
        reason: 'list-habits.toggle-from-row#7 — value = '
            '(newValue * 1000).roundToInt(), so 100.0 stores 100000',
      );
      expect(
        h.commandListener.commands.single,
        isA<CreateRepetitionCommand>()
            .having((c) => c.value, 'value', 100000)
            .having((c) => c.notes, 'notes', 'ran far')
            .having((c) => c.habit, 'habit', same(habit2)),
        reason: 'list-habits.toggle-from-row#7 — CreateRepetitionCommand('
            'habitList, habit, date, value, newNotes) is run',
      );
      expect(
        h.log,
        <String>['showNumberPopup', 'confetti', 'command'],
        reason: 'list-habits.toggle-from-row#10 — in the numerical branch the '
            'confetti check happens BEFORE the command dispatch',
      );
      expect(
        h.screen.confetti.single.color,
        habit2.color,
        reason: 'list-habits.toggle-from-row#7 — confetti uses habit.color at '
            '(x, y)',
      );
      expect(
        <double>[h.screen.confetti.single.x, h.screen.confetti.single.y],
        <double>[7.0, 8.0],
        reason: 'list-habits.toggle-from-row#7 — confetti is shown at (x, y)',
      );
    });

    test('NUMERICAL branch: no confetti when the value did not change', () {
      h.behavior.onEdit(habit2, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPicked(0.1, '');

      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.toggle-from-row#7 — no confetti when '
            'newValue == oldValue',
      );
      expect(
        h.commandListener.commands.length,
        1,
        reason: 'list-habits.toggle-from-row#7 — the command still runs when '
            'the value did not change',
      );
    });

    test('NUMERICAL branch: no confetti when the target is not reached', () {
      h.behavior.onEdit(habit2, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPicked(1.0, '');

      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.toggle-from-row#7 — AT_LEAST habit with target '
            '2.0: 1.0 is below target, so no confetti',
      );
    });

    test('NUMERICAL branch: AT_MOST habits celebrate when at or below target',
        () {
      final atMost =
          h.fixtures.createEmptyNumericalHabit(NumericalHabitType.atMost);
      h.habitList.add(atMost);
      h.resetLog();

      h.behavior.onEdit(atMost, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPicked(1.0, '');
      expect(
        h.screen.confetti.length,
        1,
        reason: 'list-habits.toggle-from-row#7 — AT_MOST habit with target '
            '2.0: 1.0 <= 2.0, so confetti',
      );

      h.screen.confetti.clear();
      h.behavior.onEdit(atMost, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPicked(5.0, '');
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.toggle-from-row#7 — AT_MOST habit with target '
            '2.0: 5.0 is above target, so no confetti',
      );
    });

    test('YES_NO branch: popup args, confetti, then command', () {
      final empty = h.fixtures.createEmptyHabit(name: 'Meditate');
      h.habitList.add(empty);
      h.resetLog();

      h.behavior.onEdit(empty, today, 5.0, 6.0);

      expect(
        <Object?>[
          h.screen.checkmarkPopupValue,
          h.screen.checkmarkPopupNotes,
          h.screen.checkmarkPopupColor,
        ],
        <Object?>[Entry.unknown, '', empty.color],
        reason: 'list-habits.toggle-from-row#8 — the checkmark popup is '
            'pre-filled with entry.value, entry.notes and habit.color',
      );

      h.screen.checkmarkPopupCallback!.onNotesSaved(Entry.yesManual, 'done');

      expect(
        h.log,
        <String>['showCheckmarkPopup', 'confetti', 'command'],
        reason: 'list-habits.toggle-from-row#8 — confetti when '
            'newValue != entry.value && newValue == YES_MANUAL, then the '
            'command runs',
      );
      expect(
        h.commandListener.commands.single,
        isA<CreateRepetitionCommand>()
            .having((c) => c.value, 'value', Entry.yesManual)
            .having((c) => c.notes, 'notes', 'done')
            .having((c) => c.habit, 'habit', same(empty)),
        reason: 'list-habits.toggle-from-row#8 — CreateRepetitionCommand('
            'habitList, habit, date, newValue, newNotes) is run',
      );
    });

    test('YES_NO branch: no confetti when the value is unchanged or not YES',
        () {
      final empty = h.fixtures.createEmptyHabit(name: 'Meditate');
      h.habitList.add(empty);
      h.resetLog();

      h.behavior.onEdit(empty, today, 0.0, 0.0);
      h.screen.checkmarkPopupCallback!.onNotesSaved(Entry.unknown, '');
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.toggle-from-row#8 — newValue == entry.value, so '
            'no confetti',
      );

      h.behavior.onEdit(empty, today, 0.0, 0.0);
      h.screen.checkmarkPopupCallback!.onNotesSaved(Entry.skip, '');
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.toggle-from-row#8 — SKIP(3) is not YES_MANUAL(2), '
            'so no confetti',
      );
    });

    test('dismissing either popup runs no command', () {
      h.behavior.onEdit(habit2, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPickerDismissed();
      h.behavior.onEdit(habit1, today, 0.0, 0.0);
      h.screen.checkmarkPopupCallback!.onNotesDismissed();

      expect(
        h.commandListener.commands,
        isEmpty,
        reason: 'list-habits.toggle-from-row#9 — dismissing either popup '
            'without confirming runs no command',
      );
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.toggle-from-row#9 — a dismissed popup shows no '
            'confetti either',
      );
    });

    test('the toggle path dispatches the command before the confetti', () {
      h.behavior.onToggle(habit1, today, Entry.yesManual, '', 1.0, 1.0);
      expect(
        h.log,
        <String>['command', 'confetti'],
        reason: 'list-habits.toggle-from-row#10 — in the toggle path the '
            'confetti check happens AFTER the command dispatch',
      );
    });

    test('reorder and repair bypass CommandRunner entirely', () {
      h.behavior.onReorderHabit(habit2, habit1);
      h.behavior.onRepairDB();

      expect(
        h.commandListener.commands,
        isEmpty,
        reason: 'list-habits.toggle-from-row#11 — reorder and repair dispatch '
            'no command, so no CommandRunner listener is notified',
      );
      expect(
        h.habitList.reorders.single,
        <Habit>[habit2, habit1],
        reason: 'list-habits.toggle-from-row#11 — reordering calls '
            'habitList.reorder(from, to) directly on a background task',
      );
      expect(
        h.habitList.repairCount,
        1,
        reason: 'list-habits.toggle-from-row#11 — DB repair calls '
            'habitList.repair() directly',
      );
      expect(
        h.taskLog.started.length,
        2,
        reason: 'list-habits.toggle-from-row#11 — both go through '
            'taskRunner.execute',
      );
    });
  });

  // -------------------------------------------------------------------------
  // list-habits.drag-reorder
  // -------------------------------------------------------------------------
  group('list-habits.drag-reorder', () {
    test('the persistent reorder moves the habit and renumbers positions', () {
      final g = _Harness();
      final a = g.fixtures.createEmptyHabit(name: 'A', position: 0);
      final b = g.fixtures.createEmptyHabit(name: 'B', position: 1);
      final c = g.fixtures.createEmptyHabit(name: 'C', position: 2);
      g.habitList.add(a);
      g.habitList.add(b);
      g.habitList.add(c);

      g.behavior.onReorderHabit(c, a);

      expect(
        g.habitList.toList().map((Habit x) => x.name).toList(),
        <String>['C', 'A', 'B'],
        reason: "list-habits.drag-reorder#6 — the 'from' habit moves to the "
            "index currently occupied by the 'to' habit",
      );
      expect(
        <int>[c.position, a.position, b.position],
        <int>[0, 1, 2],
        reason: 'list-habits.drag-reorder#6 — after the move every position is '
            'reassigned to the habit index, starting at 0',
      );
    });

    test('reordering a sorted list throws', () {
      final g = _Harness();
      final a = g.fixtures.createEmptyHabit(name: 'A', position: 0);
      final b = g.fixtures.createEmptyHabit(name: 'B', position: 1);
      g.habitList.add(a);
      g.habitList.add(b);
      g.habitList.primaryOrder = HabitListOrder.byNameDesc;

      expect(
        () => g.behavior.onReorderHabit(a, b),
        throwsA(isA<StateError>()),
        reason: 'list-habits.drag-reorder#8 — the model requires '
            'primaryOrder == BY_POSITION',
      );
    });

    test('reordering with a habit outside the list throws', () {
      final g = _Harness();
      final a = g.fixtures.createEmptyHabit(name: 'A', position: 0);
      final b = g.fixtures.createEmptyHabit(name: 'B', position: 1);
      final orphan = g.fixtures.createEmptyHabit(name: 'Z', position: 9);
      g.habitList.add(a);
      g.habitList.add(b);

      expect(
        () => g.behavior.onReorderHabit(orphan, b),
        throwsA(isA<ArgumentError>()),
        reason: "list-habits.drag-reorder#8 — the 'from' habit must be present "
            'in the list',
      );
      expect(
        () => g.behavior.onReorderHabit(a, orphan),
        throwsA(isA<ArgumentError>()),
        reason: "list-habits.drag-reorder#8 — the 'to' habit must be present "
            'in the list',
      );
    });
  });

  // -------------------------------------------------------------------------
  // list-habits.entry-edit-popup-boolean
  // -------------------------------------------------------------------------
  group('list-habits.entry-edit-popup-boolean', () {
    test('the popup receives the entry value, the notes and the colour', () {
      final date = today.minus(1);
      final entry = habit1.computedEntries.get(date);

      h.behavior.onEdit(habit1, date, 0.0, 0.0);

      expect(
        h.screen.checkmarkPopupValue,
        entry.value,
        reason: 'list-habits.entry-edit-popup-boolean#1 — the popup is passed '
            'the current entry value',
      );
      expect(
        h.screen.checkmarkPopupNotes,
        entry.notes,
        reason: 'list-habits.entry-edit-popup-boolean#1 — the popup is passed '
            'the current notes',
      );
      expect(
        h.screen.checkmarkPopupColor,
        habit1.color,
        reason: 'list-habits.entry-edit-popup-boolean#1 — the popup is passed '
            'the habit colour',
      );
    });

    test('saving runs CreateRepetitionCommand', () {
      final empty = h.fixtures.createEmptyHabit(name: 'Meditate');
      h.habitList.add(empty);
      final resortsBefore = h.habitList.resortCount;
      h.resetLog();

      h.behavior.onEdit(empty, today, 0.0, 0.0);
      h.screen.checkmarkPopupCallback!.onNotesSaved(Entry.yesManual, 'note');

      expect(
        h.commandListener.commands.single,
        isA<CreateRepetitionCommand>()
            .having((c) => c.habitList, 'habitList', same(h.habitList))
            .having((c) => c.habit, 'habit', same(empty))
            .having((c) => c.date, 'date', today)
            .having((c) => c.value, 'value', Entry.yesManual)
            .having((c) => c.notes, 'notes', 'note'),
        reason: 'list-habits.entry-edit-popup-boolean#8 — saving runs '
            'CreateRepetitionCommand(habitList, habit, date, value, notes)',
      );
      expect(
        empty.originalEntries.get(today).value,
        Entry.yesManual,
        reason: 'list-habits.entry-edit-popup-boolean#8 — the entry is added '
            "to the habit's original entries",
      );
      expect(
        empty.computedEntries.get(today).value,
        Entry.yesManual,
        reason: 'list-habits.entry-edit-popup-boolean#8 — the habit is '
            'recomputed',
      );
      expect(
        h.habitList.resortCount,
        greaterThan(resortsBefore),
        reason: 'list-habits.entry-edit-popup-boolean#8 — the list is resorted',
      );
    });

    test('confetti only for a changed value that is exactly YES_MANUAL', () {
      final empty = h.fixtures.createEmptyHabit(name: 'Meditate');
      h.habitList.add(empty);
      h.resetLog();

      h.behavior.onEdit(empty, today, 0.0, 0.0);
      h.screen.checkmarkPopupCallback!.onNotesSaved(Entry.yesManual, '');
      expect(
        h.screen.confetti.length,
        1,
        reason: 'list-habits.entry-edit-popup-boolean#9 — UNKNOWN -> '
            'YES_MANUAL is a change to YES_MANUAL, so confetti',
      );

      h.screen.confetti.clear();
      h.behavior.onEdit(empty, today, 0.0, 0.0);
      h.screen.checkmarkPopupCallback!.onNotesSaved(Entry.yesManual, '');
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.entry-edit-popup-boolean#9 — the value is already '
            'YES_MANUAL, so it did not change and there is no confetti',
      );

      h.screen.confetti.clear();
      h.behavior.onEdit(empty, today, 0.0, 0.0);
      h.screen.checkmarkPopupCallback!.onNotesSaved(Entry.no, '');
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.entry-edit-popup-boolean#9 — the new value is not '
            'exactly YES_MANUAL, so there is no confetti',
      );
    });
  });

  // -------------------------------------------------------------------------
  // list-habits.entry-edit-popup-numeric
  // -------------------------------------------------------------------------
  group('list-habits.entry-edit-popup-numeric', () {
    test('the popup receives entry.value / 1000.0 and the notes', () {
      h.behavior.onEdit(habit2, today, 0.0, 0.0);

      expect(
        h.screen.numberPopupValue,
        0.1,
        reason: 'list-habits.entry-edit-popup-numeric#1 — oldValue = '
            'entry.value / 1000.0, a Double (fixture value 100)',
      );
      expect(
        h.screen.numberPopupNotes,
        habit2.computedEntries.get(today).notes,
        reason: 'list-habits.entry-edit-popup-numeric#1 — the popup is passed '
            'the current notes',
      );
    });

    test('saving scales the picked value by 1000 and rounds it', () {
      h.behavior.onEdit(habit2, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPicked(100.0, '');

      expect(
        h.commandListener.commands.single,
        isA<CreateRepetitionCommand>().having((c) => c.value, 'value', 100000),
        reason: 'list-habits.entry-edit-popup-numeric#3 — value = '
            'round(newValue * 1000), so picking 100.0 stores 100000',
      );
      expect(
        habit2.computedEntries.get(today).value,
        100000,
        reason: 'list-habits.entry-edit-popup-numeric#3 — the scaled integer '
            'is what CreateRepetitionCommand writes',
      );
    });

    test('confetti follows the target type and the target value', () {
      // AT_LEAST, target 2.0, old value 0.1.
      h.behavior.onEdit(habit2, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPicked(2.0, '');
      expect(
        h.screen.confetti.length,
        1,
        reason: 'list-habits.entry-edit-popup-numeric#9 — AT_LEAST and '
            'newValue >= targetValue, with newValue != oldValue',
      );

      h.screen.confetti.clear();
      h.behavior.onEdit(habit2, today, 0.0, 0.0);
      h.screen.numberPopupCallback!.onNumberPicked(2.0, '');
      expect(
        h.screen.confetti,
        isEmpty,
        reason: 'list-habits.entry-edit-popup-numeric#9 — newValue == oldValue '
            'now, so no confetti even though the target is met',
      );
    });
  });

  // -------------------------------------------------------------------------
  // list-habits.data-io-actions
  // -------------------------------------------------------------------------
  group('list-habits.data-io-actions', () {
    test('onExportCSV exports every habit into the CSV output dir', () {
      final archived = h.fixtures.createEmptyHabit(name: 'Archived');
      archived.isArchived = true;
      h.habitList.add(archived);
      h.resetLog();

      h.behavior.onExportCSV();

      expect(
        h.exportSelectedArg,
        h.habitList.toList(),
        reason: 'list-habits.data-io-actions#2 — the export receives '
            'habitList.toList(), i.e. ALL habits, not a selection or filter',
      );
      expect(
        h.exportSelectedArg!.length,
        3,
        reason: 'list-habits.data-io-actions#2 — the archived habit is '
            'exported too',
      );
      expect(
        h.exportOutputDirArg,
        same(h.dirFinder.dir),
        reason: 'list-habits.data-io-actions#2 — the output directory comes '
            'from dirFinder.getCSVOutputDir()',
      );
      expect(
        h.taskLog.started.length,
        1,
        reason: 'list-habits.data-io-actions#2 — the export runs on a '
            'background task',
      );
      expect(
        h.screen.sentFiles,
        <String>['/tmp/uhabits-csv-out/Loop Habits CSV.zip'],
        reason: 'list-habits.data-io-actions#2 — on success the share-file '
            'screen is opened with the produced filename',
      );
      expect(
        h.screen.messages,
        isEmpty,
        reason: 'list-habits.data-io-actions#2 — no message is shown when the '
            'export succeeds',
      );
    });

    test('onExportCSV shows COULD_NOT_EXPORT when no file was produced', () {
      h.exportFilename = null;

      h.behavior.onExportCSV();

      expect(
        h.screen.messages,
        <ListHabitsBehaviorMessage>[ListHabitsBehaviorMessage.couldNotExport],
        reason: 'list-habits.data-io-actions#2 — on failure the message '
            'COULD_NOT_EXPORT is shown',
      );
      expect(
        h.screen.sentFiles,
        isEmpty,
        reason: 'list-habits.data-io-actions#2 — no share-file screen when the '
            'export failed',
      );
    });

    test('onExportCSV is the all-habits entry point (io.export-csv-entry-points)',
        () {
      final archived = h.fixtures.createEmptyHabit(name: 'Archived');
      archived.isArchived = true;
      h.habitList.add(archived);
      h.resetLog();

      h.behavior.onExportCSV();

      expect(
        h.exportSelectedArg,
        h.habitList.toList(),
        reason: 'io.export-csv-entry-points#1 — ListHabitsBehavior.onExportCSV '
            'exports habitList.toList() as the selected habits, i.e. the '
            'full, currently filtered list',
      );
      expect(
        h.exportListArg,
        same(h.habitList),
        reason: 'io.export-csv-entry-points#1 — the habit list handed to the '
            'task is the injected one, which is what carries the filter',
      );
      expect(
        h.exportOutputDirArg,
        same(h.dirFinder.dir),
        reason: 'io.export-csv-entry-points#1 — the destination is '
            'dirFinder.getCSVOutputDir()',
      );
      expect(
        h.taskLog.started.length,
        1,
        reason: 'io.export-csv-entry-points#3 — the export runs on the '
            'TaskRunner, in the background',
      );
      expect(
        h.log,
        containsAllInOrder(<String>['export.background', 'showSendFileScreen']),
        reason: 'io.export-csv-entry-points#3 — a non-null filename opens the '
            'share-file screen, after the background work',
      );
      expect(
        h.screen.sentFiles,
        <String>['/tmp/uhabits-csv-out/Loop Habits CSV.zip'],
        reason: 'io.export-csv-entry-points#3 — screen.showSendFileScreen is '
            'called with the filename the task reported',
      );
      expect(
        h.screen.messages,
        isEmpty,
        reason: 'io.export-csv-entry-points#3 — no message on success',
      );

      // The other half of #3: a null filename.
      h.exportFilename = null;
      h.screen.sentFiles.clear();
      h.behavior.onExportCSV();
      expect(
        h.screen.sentFiles,
        isEmpty,
        reason: 'io.export-csv-entry-points#3 — a null filename opens no '
            'share-file screen',
      );
      expect(
        h.screen.messages,
        <ListHabitsBehaviorMessage>[ListHabitsBehaviorMessage.couldNotExport],
        reason: 'io.export-csv-entry-points#3 — on null the behavior calls '
            'screen.showMessage(COULD_NOT_EXPORT)',
      );
    });

    test('onRepairDB repairs the list and then reports it', () {
      h.behavior.onRepairDB();

      expect(
        h.habitList.repairCount,
        1,
        reason: 'list-habits.data-io-actions#3 — onRepairDB runs '
            'habitList.repair(); persistence.repair-db-action#1 — the '
            '"Repair database" settings entry lands here (the preference row '
            'itself is Android res/xml)',
      );
      expect(
        h.log,
        <String>['repair', 'message:databaseRepaired'],
        reason: 'persistence.repair-db-action#1 and '
            'settings.screen.database-category#16 — repair() runs on a '
            'background task and DATABASE_REPAIRED is shown afterwards',
      );
      expect(
        h.taskLog.started.length,
        1,
        reason: 'persistence.repair-db-action#1 — exactly one background task',
      );
      expect(
        h.log,
        <String>['repair', 'message:databaseRepaired'],
        reason: 'list-habits.data-io-actions#3 — the repair runs on the '
            'background task and the DATABASE_REPAIRED message follows it',
      );
      expect(
        h.taskLog.started.length,
        1,
        reason: 'list-habits.data-io-actions#3 — the repair runs on a '
            'background task',
      );
    });

    test('onSendBugReport dumps, reads, then opens the email screen', () {
      h.bugReporter.report = 'hello';

      h.behavior.onSendBugReport();

      expect(
        h.log,
        <String>['bug.dump', 'bug.get', 'showSendBugReportToDeveloperScreen'],
        reason: 'list-habits.data-io-actions#4 and io.bug-report-dump#2 — '
            'onSendBugReport() first calls bugReporter.dumpBugReportToFile(), '
            'then bugReporter.getBugReport(), and on success opens the '
            'send-email screen with that text',
      );
      expect(
        h.screen.bugReports,
        <String>['hello'],
        reason: 'list-habits.data-io-actions#4 — the log is passed as the '
            'email body',
      );
    });

    test('onSendBugReport reports COULD_NOT_GENERATE_BUG_REPORT on failure',
        () {
      h.bugReporter.throwOnGet = Exception('boom');

      h.behavior.onSendBugReport();

      expect(
        h.screen.bugReports,
        isEmpty,
        reason: 'list-habits.data-io-actions#4 — nothing is sent when reading '
            'the report throws',
      );
      expect(
        h.screen.messages,
        <ListHabitsBehaviorMessage>[
          ListHabitsBehaviorMessage.couldNotGenerateBugReport,
        ],
        reason: 'list-habits.data-io-actions#4 and io.bug-report-dump#2 — on '
            'Exception the behavior prints the stack trace and shows '
            'COULD_NOT_GENERATE_BUG_REPORT',
      );
      expect(
        h.bugReporter.dumpCount,
        1,
        reason: 'list-habits.data-io-actions#4 — the dump still happened',
      );
    });

    test('the Message enum has exactly six values, in order', () {
      expect(
        ListHabitsBehaviorMessage.values,
        <ListHabitsBehaviorMessage>[
          ListHabitsBehaviorMessage.couldNotExport,
          ListHabitsBehaviorMessage.importSuccessful,
          ListHabitsBehaviorMessage.importFailed,
          ListHabitsBehaviorMessage.databaseRepaired,
          ListHabitsBehaviorMessage.couldNotGenerateBugReport,
          ListHabitsBehaviorMessage.fileNotRecognized,
        ],
        reason: 'list-habits.data-io-actions#7 and '
            'settings.screen.database-category#14 — COULD_NOT_EXPORT, '
            'IMPORT_SUCCESSFUL, IMPORT_FAILED, DATABASE_REPAIRED, '
            'COULD_NOT_GENERATE_BUG_REPORT, FILE_NOT_RECOGNIZED',
      );
      expect(
        ListHabitsBehaviorMessage.values.length,
        6,
        reason: 'settings.screen.database-category#14 — exactly six values',
      );
    });
  });

  // -------------------------------------------------------------------------
  // settings.intro.first-run-trigger, and the two preferences it moves:
  // settings.preferences.first-run-and-launch-count and
  // settings.preferences.hints
  // -------------------------------------------------------------------------
  group('settings.intro.first-run-trigger', () {
    test('#1 #2 onStartup increments the launch count before it looks at '
        'isFirstRun', () {
      expect(h.prefs.launchCount, 0,
          reason: 'settings.preferences.first-run-and-launch-count#5');
      expect(h.prefs.isFirstRun, isTrue,
          reason: 'settings.intro.first-run-trigger#2');

      h.behavior.onStartup();

      expect(h.prefs.launchCount, 1,
          reason: 'settings.preferences.first-run-and-launch-count#5 — '
              'incrementLaunchCount() runs FIRST, so launch_count is already '
              '1 during the first-run branch');
      expect(h.screen.introCount, 1,
          reason: 'settings.intro.first-run-trigger#1 — the intro is launched '
              'from onStartup(), and from nowhere else');
    });

    test('#3 #5 onFirstRun clears isFirstRun and seeds the hint before the '
        'intro is shown', () {
      h.behavior.onStartup();

      expect(
        h.log,
        <String>['showIntroScreen'],
        reason: 'settings.intro.first-run-trigger#3 — the order is '
            'isFirstRun = false, updateLastHint(-1, today), '
            'screen.showIntroScreen()',
      );
      expect(h.prefs.isFirstRun, isFalse,
          reason: 'settings.intro.first-run-trigger#5 — isFirstRun is cleared '
              'BEFORE the intro is shown, so killing the app during the intro '
              'means it is never shown again');
      expect(h.prefs.lastHintNumber, -1,
          reason: 'settings.preferences.hints#5 — onFirstRun() calls '
              'updateLastHint(-1, getToday())');
      expect(h.prefs.lastHintDate, today,
          reason: 'settings.preferences.hints#5 — the hint timestamp is '
              "today's");
      expect(h.prefs.launchCount, 1,
          reason: 'settings.preferences.first-run-and-launch-count#6');
    });

    test('#4 the presenter asks the screen for the intro, with no arguments',
        () {
      h.behavior.onFirstRun();

      expect(h.screen.introCount, 1,
          reason: 'settings.intro.first-run-trigger#4 — showIntroScreen() '
              'takes no parameters, matching IntentFactory.startIntroActivity('
              'context) starting IntroActivity with no extras');
    });

    test('#5 #6 a second startup shows nothing, and so does a startup with '
        'isFirstRun already false', () {
      h.behavior.onStartup();
      h.behavior.onStartup();

      expect(h.screen.introCount, 1,
          reason: 'settings.intro.first-run-trigger#5 — once isFirstRun is '
              'cleared the intro never comes back');
      expect(h.prefs.launchCount, 2,
          reason: 'settings.preferences.first-run-and-launch-count#5 — the '
              'launch count is still incremented unconditionally');

      final fresh = _Harness();
      // BaseUserInterfaceTest.setUp bypasses the intro exactly this way.
      fresh.prefs.isFirstRun = false;
      fresh.behavior.onStartup();

      expect(fresh.screen.introCount, 0,
          reason: 'settings.intro.first-run-trigger#6 — setting '
              'prefs.isFirstRun = false in setup is what makes the '
              'instrumentation tests skip the intro');
      expect(fresh.prefs.launchCount, 1,
          reason: 'settings.intro.first-run-trigger#2 — the launch count is '
              'incremented before isFirstRun is even read');
      expect(fresh.prefs.lastHintNumber, -1,
          reason: 'settings.preferences.hints#5 — no first run, so nothing '
              'seeded the hint: last_hint_number keeps its -1 default');
      expect(fresh.prefs.lastHintDate, isNull,
          reason: 'settings.preferences.hints#5 — and no hint timestamp was '
              'written');
    });
  });

  // -------------------------------------------------------------------------
  // list-habits.hints
  // -------------------------------------------------------------------------
  // -------------------------------------------------------------------------
  // list-habits.startup-lifecycle — the part of ListHabitsActivity that lives
  // in the presenter. The Android lifecycle itself (onResume/onPause, the
  // POST_NOTIFICATIONS flow, the ACTION_EDIT intent, the auto-backup and the
  // widget refresh) is not this class's, and is not ported here.
  // -------------------------------------------------------------------------
  group('list-habits.startup-lifecycle', () {
    test('#1 onStartup always increments the launch count, then branches on '
        'isFirstRun', () {
      expect(h.prefs.launchCount, 0,
          reason: 'list-habits.startup-lifecycle#1');

      h.behavior.onStartup();
      expect(h.prefs.launchCount, 1,
          reason: 'list-habits.startup-lifecycle#1');
      expect(h.screen.introCount, 1,
          reason: 'list-habits.startup-lifecycle#1 — isFirstRun defaults to '
              'true, so the first-run flow ran');

      // A second startup still counts, and no longer branches.
      h.behavior.onStartup();
      expect(h.prefs.launchCount, 2,
          reason: 'list-habits.startup-lifecycle#1');
      expect(h.screen.introCount, 1,
          reason: 'list-habits.startup-lifecycle#1');

      // …and a launch that was never a first run counts all the same.
      final fresh = _Harness();
      fresh.prefs.isFirstRun = false;
      fresh.behavior.onStartup();
      expect(fresh.prefs.launchCount, 1,
          reason: 'list-habits.startup-lifecycle#1');
      expect(fresh.screen.introCount, 0,
          reason: 'list-habits.startup-lifecycle#1');
    });

    test('#2 the first-run flow clears the flag, seeds the hint and shows the '
        'intro', () {
      h.behavior.onFirstRun();

      expect(h.prefs.isFirstRun, isFalse,
          reason: 'list-habits.startup-lifecycle#2');
      expect(h.prefs.lastHintNumber, -1,
          reason: 'list-habits.startup-lifecycle#2 — updateLastHint(-1, today)');
      expect(h.prefs.lastHintDate, today,
          reason: 'list-habits.startup-lifecycle#2');
      expect(h.log, <String>['showIntroScreen'],
          reason: 'list-habits.startup-lifecycle#2 — the intro is the last of '
              'the three steps');

      // hints#9: seeding the timestamp with today is exactly what keeps
      // shouldShow() false for the rest of the first day.
      final hints = HintList(h.prefs, listHabitsHints);
      expect(hints.shouldShow(), isFalse,
          reason: 'list-habits.hints#9 — lastHintDate == today');

      setToday(today.plus(1));
      expect(hints.shouldShow(), isTrue,
          reason: 'list-habits.hints#9 — and lets the first hint appear the '
              'next day');
      expect(hints.pop(), listHabitsHints[0],
          reason: 'list-habits.hints#9 — starting from hints[0], because the '
              'seeded number was -1');
    });
  });

  group('list-habits.hints', () {
    late Preferences prefs;
    late _RecordingStorage storage;

    setUp(() {
      storage = _RecordingStorage();
      prefs = Preferences(storage);
    });

    test('the screen has exactly two hints, in order', () {
      expect(
        listHabitsHints,
        <String>[
          'To rearrange the entries, press-and-hold on the name of the habit, '
              'then drag it to the correct place.',
          'You can see more days by putting your phone in landscape mode.',
        ],
        reason: 'list-habits.hints#1 — the hint list contains exactly two '
            'strings, hint_drag then hint_landscape',
      );
    });

    test('shouldShow is true only for a non-null date before today', () {
      final list = HintList(prefs, <String>['hint1', 'hint2', 'hint3']);

      expect(
        list.shouldShow(),
        isFalse,
        reason: 'list-habits.hints#2 — lastHintDate is null, so shouldShow is '
            'false',
      );

      prefs.updateLastHint(0, today);
      expect(
        list.shouldShow(),
        isFalse,
        reason: 'list-habits.hints#2 — lastHintDate equals today, so '
            'shouldShow is false',
      );

      prefs.updateLastHint(0, today.minus(1));
      expect(
        list.shouldShow(),
        isTrue,
        reason: 'list-habits.hints#2 — lastHintDate is strictly earlier than '
            'today, so shouldShow is true',
      );
    });

    test('lastHintDate is null when the stored timestamp is negative', () {
      expect(
        prefs.lastHintDate,
        isNull,
        reason: 'list-habits.hints#3 — last_hint_timestamp defaults to -1, so '
            'lastHintDate is null',
      );

      storage.putLong('last_hint_timestamp', -5);
      expect(
        prefs.lastHintDate,
        isNull,
        reason: 'list-habits.hints#3 — a negative stored unix time means '
            '"never set"',
      );

      prefs.updateLastHint(0, today);
      expect(
        prefs.lastHintDate,
        today,
        reason: 'list-habits.hints#3 — a non-negative stored unix time yields '
            'the date',
      );
    });

    test('pop walks the list once and then returns null forever', () {
      final list = HintList(prefs, <String>['hint1', 'hint2', 'hint3']);

      expect(
        prefs.lastHintNumber,
        -1,
        reason: 'list-habits.hints#4 — last_hint_number defaults to -1',
      );
      expect(
        list.pop(),
        'hint1',
        reason: 'list-habits.hints#5 — the first ever pop returns hints[0]',
      );
      expect(
        prefs.lastHintNumber,
        0,
        reason: 'list-habits.hints#5 — the first ever pop records number 0',
      );
      expect(
        prefs.lastHintDate,
        today,
        reason: 'list-habits.hints#4 — pop persists updateLastHint(next, '
            'today)',
      );
      expect(
        list.pop(),
        'hint2',
        reason: 'list-habits.hints#4 — next = lastHintNumber + 1',
      );
      expect(
        list.pop(),
        'hint3',
        reason: 'list-habits.hints#4 — next = lastHintNumber + 1',
      );

      storage.writes.clear();
      expect(
        list.pop(),
        isNull,
        reason: 'list-habits.hints#5 — once all hints have been shown pop() '
            'returns null forever',
      );
      expect(
        storage.writes,
        isEmpty,
        reason: 'list-habits.hints#4 — when next >= hints.size, pop() returns '
            'null WITHOUT touching preferences',
      );
      expect(
        list.pop(),
        isNull,
        reason: 'list-habits.hints#5 — and it keeps returning null',
      );
    });

    test('the factory builds a HintList over the shared preferences', () {
      final factory = HintListFactory(prefs);
      final list = factory.create(<String>['only']);

      expect(
        list.pop(),
        'only',
        reason: 'list-habits.hints#4 — HintListFactory.create(hints) builds a '
            'HintList backed by the injected Preferences',
      );
      expect(
        prefs.lastHintNumber,
        0,
        reason: 'list-habits.hints#4 — the factory-built list writes through '
            'to the same Preferences',
      );
    });
  });
}
