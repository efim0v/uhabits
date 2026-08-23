/// Widget tests for the calendar heat-map editor.
///
/// The Kotlin being reproduced is
/// uhabits-android/.../activities/common/dialogs/HistoryEditorDialog.kt, its
/// caller `ShowHabitActivity.Screen.showHistoryEditorDialog`, and the core
/// presenter both of them lean on,
/// uhabits-core/.../ui/screens/habits/show/views/HistoryCard.kt.
///
/// Every expectation cites the rule it pins, from docs/parity/FEATURES.md.
library;

// uhabits_core exports neither lib/src/ui nor lib/src/commands yet.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/history_editor_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/theme/app_theme.dart' show appThemeData;
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/screens/habits/show/views/history_card.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  // A Sunday, the same date the Android chart goldens were captured on.
  final today = core.LocalDate.ymd(2015, 1, 25);

  late core.MemoryModelFactory factory;
  late core.HabitList habitList;
  late _RecordingCommandRunner commandRunner;
  late MemoryStorage storage;
  late Preferences preferences;

  setUp(() {
    core.setToday(today);
    // The slot is process-wide upstream too; a leftover route from the
    // previous test belongs to a tree that no longer exists.
    HistoryEditorDialog.currentDialog = null;
    factory = core.MemoryModelFactory();
    habitList = factory.buildHabitList();
    commandRunner = _RecordingCommandRunner(
      CoroutineTaskRunner(
        mainDispatcher: const UnconfinedTestDispatcher(),
        ioDispatcher: const UnconfinedTestDispatcher(),
      ),
    );
    storage = MemoryStorage();
    preferences = Preferences(storage);
  });

  tearDown(core.resetToday);

  core.Habit addHabit({
    String name = 'Meditate',
    core.PaletteColor color = const core.PaletteColor(7),
    core.HabitType type = core.HabitType.yesNo,
    double targetValue = 0.0,
    core.NumericalHabitType targetType = core.NumericalHabitType.atLeast,
    List<core.Entry> entries = const <core.Entry>[],
  }) {
    final habit = factory.buildHabit()
      ..name = name
      ..color = color
      ..type = type
      ..targetValue = targetValue
      ..targetType = targetType;
    for (final entry in entries) {
      habit.originalEntries.add(entry);
    }
    habitList.add(habit);
    habit.recompute();
    return habit;
  }

  // ---------------------------------------------------------------------------
  // Pumping the dialog.
  // ---------------------------------------------------------------------------

  /// The app whose only button opens the editor, the way the History card's
  /// Edit button does (`history-editor.dialog#14`).
  Widget wrap({
    required int habitId,
    core.Theme? theme,
    OnDateClickedListener? listener,
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
  }) {
    return MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: appThemeData(theme ?? core.LightTheme()),
      navigatorObservers: observers,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('edit'),
              onPressed: () => showHistoryEditorDialog(
                context,
                habitId: habitId,
                habitList: habitList,
                commandRunner: commandRunner,
                preferences: preferences,
                listener: listener,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openEditor(
    WidgetTester tester, {
    required int habitId,
    core.Theme? theme,
    OnDateClickedListener? listener,
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
  }) async {
    // pumpWidget updates the tree in place, so an editor opened earlier in the
    // same test would still be covering the button.
    if (HistoryEditorDialog.currentDialog != null) {
      HistoryEditorDialog.clearCurrentDialog();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(
      wrap(
        habitId: habitId,
        theme: theme,
        listener: listener,
        observers: observers,
      ),
    );
    await tester.tap(find.byKey(const Key('edit')));
    await tester.pumpAndSettle();
  }

  final chartFinder = find.descendant(
    of: find.byType(HistoryEditorDialog),
    matching: find.byType(CoreView),
  );

  /// The live chart inside the open dialog.
  HistoryChart chartOf(WidgetTester tester) =>
      tester.widget<CoreView>(chartFinder).view as HistoryChart;

  /// The global position of the centre of the calendar cell at [col], [row],
  /// using the geometry `HistoryChart.draw` computes: an 8-row grid — one
  /// header row plus seven weekday rows — inside the chart's padding.
  Offset cellAt(WidgetTester tester, {int col = 0, int row = 1}) {
    const padding = HistoryEditorDialog.chartPadding;
    final size = tester.getSize(chartFinder);
    final square = _rint((size.height - 2 * padding) / 8.0);
    return tester.getTopLeft(chartFinder) +
        Offset(padding + (col + 0.5) * square, padding + (row + 0.5) * square);
  }

  // ---------------------------------------------------------------------------

  group('history-editor.dialog', () {
    testWidgets('#1 #14 the habit is looked up by id, and a missing one throws',
        (tester) async {
      final habit = addHabit(color: const core.PaletteColor(3));

      expect(
        HistoryEditorDialog.habitOf(habitList, habit.id!),
        same(habit),
        reason: 'history-editor.dialog#1',
      );
      expect(
        () => HistoryEditorDialog.habitOf(habitList, habit.id! + 99),
        throwsA(anything),
        reason: 'history-editor.dialog#1',
      );

      await openEditor(tester, habitId: habit.id!);

      expect(
        find.byType(HistoryEditorDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#14',
      );
      // The dialog resolved *that* habit: the chart wears its colour.
      expect(
        chartOf(tester).paletteColor,
        const core.PaletteColor(3),
        reason: 'history-editor.dialog#1',
      );
    });

    testWidgets('#14 the route carries the "historyEditor" tag',
        (tester) async {
      final habit = addHabit();
      final names = <String?>[];
      await openEditor(
        tester,
        habitId: habit.id!,
        observers: <NavigatorObserver>[_RouteNameObserver(names)],
      );

      expect(
        HistoryEditorDialog.tag,
        'historyEditor',
        reason: 'history-editor.dialog#14',
      );
      expect(
        names,
        contains('historyEditor'),
        reason: 'history-editor.dialog#14',
      );
    });

    testWidgets('#2 #15 the window is as wide as the screen and 350dp tall',
        (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);

      expect(
        HistoryEditorDialog.maxHeight,
        350.0,
        reason: 'history-editor.dialog#2',
      );
      // The test surface is 800x600, so the height is the 350dp cap.
      expect(
        tester.getSize(chartFinder),
        const Size(800, 350),
        reason: 'history-editor.dialog#2',
      );
    });

    testWidgets('#2 #15 a screen shorter than 350dp caps the dialog instead',
        (tester) async {
      tester.view.physicalSize = const Size(400, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);

      expect(
        tester.getSize(chartFinder),
        const Size(400, 240),
        reason: 'history-editor.dialog#2',
      );
    });

    test('#3 the chart is built empty, OFF by default, padded by 10', () {
      final habit = addHabit(
        color: const core.PaletteColor(5),
        entries: <core.Entry>[core.Entry(today, core.Entry.yesManual)],
      );
      // pref_first_weekday = 2 is Monday.
      storage.putString('pref_first_weekday', '2');

      final chart = HistoryEditorDialog.buildChart(
        habit: habit,
        preferences: preferences,
        theme: core.DarkTheme(),
        dateFormatter: _StubFormatter(),
      );

      expect(
        chart.firstWeekday,
        core.DayOfWeek.monday,
        reason: 'history-editor.dialog#3',
      );
      expect(
        chart.paletteColor,
        const core.PaletteColor(5),
        reason: 'history-editor.dialog#3',
      );
      expect(chart.series, isEmpty, reason: 'history-editor.dialog#3');
      expect(
        chart.defaultSquare,
        Square.off,
        reason: 'history-editor.dialog#3',
      );
      expect(
        chart.notesIndicators,
        isEmpty,
        reason: 'history-editor.dialog#3',
      );
      expect(chart.today, today, reason: 'history-editor.dialog#3');
      expect(chart.padding, 10.0, reason: 'history-editor.dialog#3');
      expect(
        chart.theme,
        isA<core.DarkTheme>(),
        reason: 'history-editor.dialog#3',
      );
    });

    testWidgets('#3 #15 the mounted chart takes the locale date formatter',
        (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);

      final chart = chartOf(tester);
      expect(
        chart.dateFormatter.shortWeekdayNameOf(core.DayOfWeek.sunday),
        'Sun',
        reason: 'history-editor.dialog#3',
      );
      expect(chart.padding, 10.0, reason: 'history-editor.dialog#15');
    });

    testWidgets('#4 the chart follows the app theme', (tester) async {
      final habit = addHabit();

      await openEditor(tester, habitId: habit.id!, theme: core.DarkTheme());
      expect(
        chartOf(tester).theme,
        isA<core.DarkTheme>(),
        reason: 'history-editor.dialog#4',
      );

      await openEditor(
        tester,
        habitId: habit.id!,
        theme: core.PureBlackTheme(),
      );
      expect(
        chartOf(tester).theme,
        isA<core.PureBlackTheme>(),
        reason: 'history-editor.dialog#4',
      );
    });

    testWidgets('#5 it registers with the command runner while it is open',
        (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);

      expect(
        commandRunner.added,
        hasLength(1),
        reason: 'history-editor.dialog#5',
      );
      expect(
        commandRunner.removed,
        isEmpty,
        reason: 'history-editor.dialog#5',
      );

      Navigator.of(tester.element(find.byType(HistoryEditorDialog))).pop();
      await tester.pumpAndSettle();

      expect(
        commandRunner.removed,
        equals(commandRunner.added),
        reason: 'history-editor.dialog#5',
      );
    });

    testWidgets('#5 it refreshes as soon as it opens', (tester) async {
      final habit = addHabit(
        entries: <core.Entry>[
          core.Entry(today, core.Entry.yesManual),
          core.Entry(today.minus(1), core.Entry.no),
        ],
      );
      await openEditor(tester, habitId: habit.id!);

      // Created with an empty series (#3), yet already filled on the first
      // frame: the equivalent of onResume's immediate refreshData().
      final chart = chartOf(tester);
      expect(chart.series, isNotEmpty, reason: 'history-editor.dialog#5');
      expect(chart.series.first, Square.on, reason: 'history-editor.dialog#5');
    });

    testWidgets('#6 a finished command rebuilds the chart state',
        (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);

      expect(
        chartOf(tester).series,
        <Square>[Square.off],
        reason: 'history-editor.dialog#6',
      );

      commandRunner.run(
        CreateRepetitionCommand(
          habitList,
          habit,
          today,
          core.Entry.yesManual,
          '',
        ),
      );
      await tester.pump();

      expect(
        chartOf(tester).series,
        <Square>[Square.on],
        reason: 'history-editor.dialog#6',
      );
    });

    testWidgets('#7 the state is built with a LightTheme even in dark mode',
        (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!, theme: core.DarkTheme());

      expect(
        HistoryEditorDialog.buildState(
          habit: habit,
          preferences: preferences,
        ).theme,
        isA<core.LightTheme>(),
        reason: 'history-editor.dialog#7',
      );
      expect(
        chartOf(tester).theme,
        isA<core.DarkTheme>(),
        reason: 'history-editor.dialog#7',
      );
    });

    test('#8 numerical squares follow the target', () {
      final atLeast = addHabit(
        type: core.HabitType.numerical,
        targetValue: 2.0,
        entries: <core.Entry>[
          core.Entry(today, 3000),
          core.Entry(today.minus(1), 1000),
          core.Entry(today.minus(2), core.Entry.skip),
          core.Entry(today.minus(3), core.Entry.unknown),
        ],
      );

      expect(
        HistoryEditorDialog.buildState(habit: atLeast, preferences: preferences)
            .series,
        <Square>[Square.on, Square.grey, Square.hatched, Square.off],
        reason: 'history-editor.dialog#8',
      );

      final atMost = addHabit(
        name: 'Smoke',
        type: core.HabitType.numerical,
        targetValue: 2.0,
        targetType: core.NumericalHabitType.atMost,
        entries: <core.Entry>[
          core.Entry(today, 1000),
          core.Entry(today.minus(1), 3000),
        ],
      );
      expect(
        HistoryEditorDialog.buildState(habit: atMost, preferences: preferences)
            .series,
        <Square>[Square.on, Square.grey],
        reason: 'history-editor.dialog#8',
      );
    });

    test('#8 yes/no squares follow the entry value', () {
      final habit = addHabit(
        entries: <core.Entry>[
          core.Entry(today, core.Entry.yesManual),
          core.Entry(today.minus(1), core.Entry.skip),
          // today - 2 is left out entirely: inside the interval it reads back
          // as UNKNOWN, which is OFF, exactly like the explicit NO below.
          core.Entry(today.minus(3), core.Entry.no),
        ],
      );

      expect(
        HistoryEditorDialog.buildState(habit: habit, preferences: preferences)
            .series,
        <Square>[Square.on, Square.hatched, Square.off, Square.off],
        reason: 'history-editor.dialog#8',
      );
    });

    test('#9 a note lights the indicator of its own day', () {
      final habit = addHabit(
        entries: <core.Entry>[
          core.Entry(today, core.Entry.yesManual, notes: 'hello'),
          core.Entry(today.minus(1), core.Entry.no),
        ],
      );

      expect(
        HistoryEditorDialog.buildState(habit: habit, preferences: preferences)
            .notesIndicators,
        <bool>[true, false],
        reason: 'history-editor.dialog#9',
      );
    });

    testWidgets('#10 #16 a second editor dismisses the first', (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);
      final first = HistoryEditorDialog.currentDialog;
      expect(first, isNotNull, reason: 'history-editor.dialog#10');

      // The Edit button is underneath the open dialog, so the second editor is
      // requested from its context rather than by tapping it.
      unawaited(
        showHistoryEditorDialog(
          tester.element(find.byKey(const Key('edit'))),
          habitId: habit.id!,
          habitList: habitList,
          commandRunner: commandRunner,
          preferences: preferences,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(HistoryEditorDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#16',
      );
      expect(
        first!.isActive,
        isFalse,
        reason: 'history-editor.dialog#16',
      );
      expect(
        HistoryEditorDialog.currentDialog,
        isNot(same(first)),
        reason: 'history-editor.dialog#10',
      );
    });

    testWidgets('#10 dismissing clears the slot', (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);

      Navigator.of(tester.element(find.byType(HistoryEditorDialog))).pop();
      await tester.pumpAndSettle();

      expect(
        find.byType(HistoryEditorDialog),
        findsNothing,
        reason: 'history-editor.dialog#10',
      );
      expect(
        HistoryEditorDialog.currentDialog,
        isNull,
        reason: 'history-editor.dialog#10',
      );
    });

    testWidgets('#10 #16 the editor stays alive under the entry popup',
        (tester) async {
      final habit = addHabit(type: core.HabitType.numerical, targetValue: 1.0);
      await openEditor(tester, habitId: habit.id!);

      await tester.tapAt(cellAt(tester));
      await tester.pumpAndSettle();

      expect(
        find.byType(NumberDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#11',
      );
      expect(
        find.byType(HistoryEditorDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#10',
      );
      expect(
        HistoryEditorDialog.currentDialog,
        isNotNull,
        reason: 'history-editor.dialog#10',
      );
    });

    testWidgets('#11 a numerical habit opens the number popup on either press',
        (tester) async {
      final habit = addHabit(type: core.HabitType.numerical, targetValue: 1.0);

      await openEditor(tester, habitId: habit.id!);
      await tester.tapAt(cellAt(tester));
      await tester.pumpAndSettle();
      expect(
        find.byType(NumberDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#11',
      );

      await tester.tap(find.byKey(const ValueKey<String>('number_save_button')));
      await tester.pumpAndSettle();

      await tester.longPressAt(cellAt(tester));
      await tester.pumpAndSettle();
      expect(
        find.byType(NumberDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#11',
      );
    });

    testWidgets('#11 a yes/no habit opens the checkmark popup on a short press',
        (tester) async {
      final habit = addHabit();
      preferences.isShortToggleEnabled = false;

      await openEditor(tester, habitId: habit.id!);
      await tester.tapAt(cellAt(tester));
      await tester.pumpAndSettle();

      expect(
        find.byType(CheckmarkDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#11',
      );
      expect(
        habit.originalEntries.getKnown(),
        isEmpty,
        reason: 'history-editor.dialog#11',
      );
    });

    testWidgets('#11 a long press toggles instead when short toggle is off',
        (tester) async {
      final habit = addHabit();
      preferences.isShortToggleEnabled = false;

      await openEditor(tester, habitId: habit.id!);
      await tester.longPressAt(cellAt(tester));
      await tester.pumpAndSettle();

      expect(
        find.byType(CheckmarkDialog),
        findsNothing,
        reason: 'history-editor.dialog#11',
      );
      expect(
        habit.originalEntries.getKnown().map((e) => e.value).toList(),
        <int>[core.Entry.yesManual],
        reason: 'history-editor.dialog#11',
      );
    });

    testWidgets('#11 short toggle swaps the two press lengths', (tester) async {
      final habit = addHabit();
      preferences.isShortToggleEnabled = true;

      await openEditor(tester, habitId: habit.id!);
      await tester.tapAt(cellAt(tester));
      await tester.pumpAndSettle();

      expect(
        find.byType(CheckmarkDialog),
        findsNothing,
        reason: 'history-editor.dialog#11',
      );
      expect(
        habit.originalEntries.getKnown().map((e) => e.value).toList(),
        <int>[core.Entry.yesManual],
        reason: 'history-editor.dialog#11',
      );

      await tester.longPressAt(cellAt(tester));
      await tester.pumpAndSettle();
      expect(
        find.byType(CheckmarkDialog),
        findsOneWidget,
        reason: 'history-editor.dialog#11',
      );
    });

    testWidgets('#6 #11 a toggle from inside the dialog updates the grid live',
        (tester) async {
      final habit = addHabit();
      preferences.isShortToggleEnabled = true;
      await openEditor(tester, habitId: habit.id!);

      final before = List<Square>.of(chartOf(tester).series);
      await tester.tapAt(cellAt(tester));
      await tester.pumpAndSettle();

      final after = chartOf(tester).series;
      expect(
        after.length,
        greaterThan(before.length),
        reason: 'history-editor.dialog#6',
      );
      // Newest first: the last square is the day that was just toggled.
      expect(after.last, Square.on, reason: 'history-editor.dialog#6');
    });

    testWidgets('#12 every date click buzzes first', (tester) async {
      final feedback = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            feedback.add(call.arguments as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final habit = addHabit(type: core.HabitType.numerical, targetValue: 1.0);
      await openEditor(tester, habitId: habit.id!);
      await tester.tapAt(cellAt(tester));
      await tester.pumpAndSettle();

      // HapticFeedbackConstants.VIRTUAL_KEY is what Flutter's lightImpact maps
      // to on Android.
      expect(
        feedback,
        <String>['HapticFeedbackType.lightImpact'],
        reason: 'history-editor.dialog#12',
      );
    });

    testWidgets("#17 the caller's presenter receives the presses",
        (tester) async {
      final habit = addHabit();
      final listener = _RecordingListener();

      await openEditor(tester, habitId: habit.id!, listener: listener);
      expect(
        chartOf(tester).onDateClickedListener,
        same(listener),
        reason: 'history-editor.dialog#17',
      );

      await tester.tapAt(cellAt(tester));
      await tester.pumpAndSettle();
      expect(
        listener.shortPresses,
        hasLength(1),
        reason: 'history-editor.dialog#17',
      );

      await tester.longPressAt(cellAt(tester));
      await tester.pumpAndSettle();
      expect(
        listener.longPresses,
        equals(listener.shortPresses),
        reason: 'history-editor.dialog#17',
      );
      // Row 1, column 0 is the oldest cell of the grid, well before today.
      expect(
        listener.shortPresses.single.isOlderThan(today),
        isTrue,
        reason: 'history-editor.dialog#17',
      );
    });

    testWidgets('#17 without a listener it drives its own HistoryCardPresenter',
        (tester) async {
      final habit = addHabit();
      await openEditor(tester, habitId: habit.id!);

      expect(
        chartOf(tester).onDateClickedListener,
        isA<HistoryCardPresenter>(),
        reason: 'history-editor.dialog#17',
      );
    });
  });
}

/// `kotlin.math.round` / `Math.rint`, the rounding `HistoryChart.draw` uses to
/// size a square: ties go to the even number.
double _rint(double x) {
  final floor = x.floorToDouble();
  final fraction = x - floor;
  if (fraction > 0.5) return floor + 1.0;
  if (fraction < 0.5) return floor;
  return floor % 2.0 == 0.0 ? floor : floor + 1.0;
}

/// A [CommandRunner] that remembers who subscribed, so `onResume`'s
/// `addListener` and `onPause`'s `removeListener` can be observed.
class _RecordingCommandRunner extends CommandRunner {
  _RecordingCommandRunner(super.taskRunner);

  final List<CommandRunnerListener> added = <CommandRunnerListener>[];
  final List<CommandRunnerListener> removed = <CommandRunnerListener>[];

  @override
  void addListener(CommandRunnerListener l) {
    added.add(l);
    super.addListener(l);
  }

  @override
  void removeListener(CommandRunnerListener l) {
    removed.add(l);
    super.removeListener(l);
  }
}

/// Stands in for the History card's presenter.
class _RecordingListener extends OnDateClickedListener {
  final List<core.LocalDate> shortPresses = <core.LocalDate>[];
  final List<core.LocalDate> longPresses = <core.LocalDate>[];

  @override
  void onDateShortPress(core.LocalDate date) => shortPresses.add(date);

  @override
  void onDateLongPress(core.LocalDate date) => longPresses.add(date);
}

class _RouteNameObserver extends NavigatorObserver {
  _RouteNameObserver(this.names);

  final List<String?> names;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }
}

class _StubFormatter implements core.LocalDateFormatter {
  @override
  String shortMonthName(core.LocalDate date) => 'Jan';

  @override
  String shortWeekdayName(core.LocalDate date) => 'Sun';

  @override
  String longMonthName(core.LocalDate date) => 'January';

  @override
  String shortWeekdayNameOf(core.DayOfWeek weekday) => 'Sun';

  @override
  String longWeekdayNameOf(core.DayOfWeek weekday) => 'Sunday';
}
