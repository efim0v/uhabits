/// Widget tests for the habit card row and its entry button panel.
///
/// These pin the behaviour HabitCardViewTest, CheckmarkPanelViewTest and
/// NumberPanelViewTest pin on the Android side: which date each button stands
/// for (including under `dataOffset`), which gesture toggles and which one
/// edits, and that the card renders the habit in its own colour.
///
/// Every `expect` carries the parity-ledger rule id it exercises. Two rule
/// families are only *partly* reachable from here and are cited only for the
/// clauses this port actually implements:
///
///  * `list-habits.checkmark-button-rendering` and `list-habits.number-button`
///    describe the Android `CheckmarkButtonView` / `NumberButtonView`. The
///    Flutter cells paint the *core* KMP `CheckmarkButton` / `NumberButton`
///    instead, which is a smaller drawing (no SKIP or UNKNOWN glyph, no
///    hollow YES_AUTO, no notes indicator, no AT_MOST branch, no unit
///    trimming). Only the geometry and the gesture rules are cited.
///  * `list-habits.entry-panels#2` and `#3` are phrased as RecyclerView
///    child-recycling concerns. A Flutter panel is rebuilt from its arguments
///    and recycles nothing, so what is cited here is the observable half of
///    each rule: which buttons exist after a new `buttonCount`, and which
///    dates and values they carry after a new `dataOffset`.
///  * the entry-panels rule about the panel registering itself as a
///    `Preferences` listener while attached has no counterpart here: the
///    screen reads the preference and passes it down, so the panel subscribes
///    to nothing. It is left uncited on purpose.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/core_view.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart' as core;
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/ui/views/number_button.dart' as core_views;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late core.LocalDate today;
  late core.Preferences preferences;
  late core.Theme theme;

  setUp(() {
    today = core.LocalDate.ymd(2020, 1, 15);
    core.setToday(today);
    preferences = core.Preferences(core.MemoryStorage());
    theme = core.LightTheme();
  });

  tearDown(core.resetToday);

  core.Habit buildHabit({
    String name = 'Meditate',
    core.PaletteColor color = const core.PaletteColor(7),
    core.HabitType type = core.HabitType.yesNo,
    String unit = '',
    double targetValue = 0.0,
    core.Frequency frequency = core.Frequency.daily,
    bool isArchived = false,
  }) {
    final habit = core.MemoryModelFactory().buildHabit();
    habit.name = name;
    habit.color = color;
    habit.type = type;
    habit.unit = unit;
    habit.targetValue = targetValue;
    habit.frequency = frequency;
    habit.isArchived = isArchived;
    return habit;
  }

  Future<void> pumpCard(
    WidgetTester tester, {
    required core.Habit habit,
    List<int> values = const <int>[],
    List<String> notes = const <String>[],
    double score = 0.5,
    int buttonCount = 5,
    int dataOffset = 0,
    bool isSelected = false,
    EntryToggleCallback? onToggle,
    EntryEditCallback? onEdit,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: HabitCard(
                habit: habit,
                score: score,
                values: values,
                notes: notes,
                theme: theme,
                preferences: preferences,
                buttonCount: buttonCount,
                dataOffset: dataOffset,
                isSelected: isSelected,
                onToggle: onToggle,
                onEdit: onEdit,
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The core [core.View] one entry cell paints.
  core.View viewAt(WidgetTester tester, core.LocalDate date) => tester
      .widget<CoreView>(
        find.descendant(
          of: find.byKey(EntryPanel.buttonKey(date)),
          matching: find.byType(CoreView),
        ),
      )
      .view;

  /// Replays one entry cell onto a recording canvas of its own 48x48 size.
  _RecordingCanvas drawButton(WidgetTester tester, core.LocalDate date) {
    final canvas = _RecordingCanvas(width: 48, height: 48);
    viewAt(tester, date).draw(canvas);
    return canvas;
  }

  group('HabitCard', () {
    testWidgets('renders the habit name in its palette colour', (tester) async {
      await pumpCard(tester, habit: buildHabit());

      final label = tester.widget<Text>(find.text('Meditate'));
      // PaletteColor(7) is green; LightTheme resolves it to 0x388E3C.
      expect(label.style?.color, const Color(0xFF388E3C),
          reason: 'list-habits.habit-card#4');
    });

    testWidgets('draws an archived habit in the medium contrast colour',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(isArchived: true));

      final label = tester.widget<Text>(find.text('Meditate'));
      // copyAttributesFrom(): archived habits use ?attr/contrast60.
      expect(label.style?.color, const Color(0xFF9E9E9E),
          reason: 'list-habits.habit-card#4');
      // The ring is drawn in the same colour, not in the habit's own.
      final ring = tester.widget<HabitCard>(find.byType(HabitCard));
      expect(ring.activeColor, theme.mediumContrastTextColor,
          reason: 'list-habits.habit-card#4');
    });

    testWidgets('#1 the row is a ring, then the label, then the panel',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), buttonCount: 3);

      final ring = tester.getRect(find.byType(CoreView).first);
      final label = tester.getRect(find.text('Meditate'));
      final panel = tester.getRect(find.byType(EntryPanel));

      expect(ring.right, lessThanOrEqualTo(label.left),
          reason: 'list-habits.habit-card#1');
      expect(label.right, lessThanOrEqualTo(panel.left),
          reason: 'list-habits.habit-card#1');
      // The label takes the slack: `LinearLayout.LayoutParams(0, WRAP, 1f)`.
      expect(label.width, greaterThan(panel.width),
          reason: 'list-habits.habit-card#1');
    });

    testWidgets('#3 the label is two lines at most, ellipsized at the end',
        (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(name: 'A very long habit name that will not fit'),
      );

      final label = tester.widget<Text>(
        find.text('A very long habit name that will not fit'),
      );
      expect(label.maxLines, 2, reason: 'list-habits.habit-card#3');
      expect(label.overflow, TextOverflow.ellipsis,
          reason: 'list-habits.habit-card#3');
    });

    testWidgets('shows one entry button per visible date, newest first',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);

      expect(find.byType(EntryButton), findsNWidgets(5),
          reason: 'list-habits.entry-panels#1');
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(EntryPanel.buttonKey(today.minus(i))), findsOneWidget,
            reason: 'list-habits.entry-panels#4');
      }

      // Newest on the left, oldest on the right.
      final first = tester.getCenter(find.byKey(EntryPanel.buttonKey(today)));
      final last =
          tester.getCenter(find.byKey(EntryPanel.buttonKey(today.minus(4))));
      expect(first.dx, lessThan(last.dx),
          reason: 'list-habits.entry-panels#7');

      // 48 logical pixels apart, matching R.dimen.checkmarkWidth.
      final second =
          tester.getCenter(find.byKey(EntryPanel.buttonKey(today.minus(1))));
      expect(second.dx - first.dx, theme.checkmarkButtonSize,
          reason: 'list-habits.screen-layout#5');
    });

    testWidgets('#1 the panel is exactly 48dp per button, 48dp high',
        (tester) async {
      for (final count in <int>[0, 1, 5]) {
        await pumpCard(tester, habit: buildHabit(), buttonCount: count);
        expect(
          tester.getSize(find.byType(EntryPanel)),
          Size(48.0 * count, count == 0 ? 0.0 : 48.0),
          reason: 'list-habits.entry-panels#1',
        );
      }

      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);
      for (var i = 0; i < 5; i++) {
        expect(
          tester.getSize(find.byKey(EntryPanel.buttonKey(today.minus(i)))),
          const Size(48, 48),
          reason: 'list-habits.screen-layout#5',
        );
      }
    });

    testWidgets('lays the buttons out oldest first when the sequence is reversed',
        (tester) async {
      preferences.isCheckmarkSequenceReversed = true;
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);

      final newest = tester.getCenter(find.byKey(EntryPanel.buttonKey(today)));
      final oldest =
          tester.getCenter(find.byKey(EntryPanel.buttonKey(today.minus(4))));
      expect(oldest.dx, lessThan(newest.dx),
          reason: 'list-habits.entry-panels#8 and '
              'settings.preferences.checkmark-reverse-order#5 — '
              'ButtonPanelView.inflateButtons() adds the freshly created '
              'buttons in reversed order when the flag is true');

      // It re-inflates whenever onCheckmarkSequenceChanged() fires: the panel
      // reads the preference on every build, so the natural order comes back.
      preferences.isCheckmarkSequenceReversed = false;
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);
      expect(
        tester.getCenter(find.byKey(EntryPanel.buttonKey(today))).dx,
        lessThan(
          tester.getCenter(find.byKey(EntryPanel.buttonKey(today.minus(4)))).dx,
        ),
        reason: 'settings.preferences.checkmark-reverse-order#5 — in natural '
            'order the newest button is leftmost again',
      );
    });

    testWidgets('long press toggles the entry to its next value', (tester) async {
      final toggles = <List<Object>>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.no, core.Entry.yesManual],
        notes: const <String>['note today', ''],
        onToggle: (date, value, notes) => toggles.add(<Object>[date, value, notes]),
      );

      // isShortToggleEnabled defaults to false, so the long press is the one
      // that toggles.
      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      expect(toggles, <List<Object>>[
        <Object>[today, core.Entry.yesManual, 'note today'],
      ], reason: 'list-habits.checkmark-button#5 and '
          'settings.preferences.short-toggle#3 — with the flag false a long '
          'press performs the toggle');
      // performToggle() reports the next value together with the notes it was
      // handed, and the notes for that date are passed through unchanged.
      expect(toggles.single[2], 'note today',
          reason: 'list-habits.checkmark-button#8');
      expect(toggles.single[1], core.Entry.yesManual,
          reason: 'list-habits.checkmark-button-rendering#11');
    });

    testWidgets('tap opens the editor when short toggle is disabled',
        (tester) async {
      final edited = <core.LocalDate>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.no],
        onEdit: edited.add,
        onToggle: (_, _, _) => fail('a tap must not toggle'),
      );

      await tester.tap(find.byKey(EntryPanel.buttonKey(today.minus(2))));
      await tester.pumpAndSettle();

      expect(edited, <core.LocalDate>[today.minus(2)],
          reason: 'list-habits.checkmark-button#5 and '
              'settings.preferences.short-toggle#3 — with the flag false a '
              'single tap only opens the editor');
      expect(preferences.isShortToggleEnabled, isFalse,
          reason: 'list-habits.checkmark-button-rendering#10');
    });

    testWidgets('short toggle swaps the two gestures', (tester) async {
      preferences.isShortToggleEnabled = true;
      final toggles = <int>[];
      final edited = <core.LocalDate>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.no],
        onToggle: (_, value, _) => toggles.add(value),
        onEdit: edited.add,
      );

      await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();
      expect(toggles, <int>[core.Entry.yesManual],
          reason: 'list-habits.checkmark-button#6 and '
              'settings.preferences.short-toggle#3 — CheckmarkButtonView '
              'routes a single tap to the toggle action when the flag is '
              'true');
      expect(edited, isEmpty,
          reason: 'list-habits.checkmark-button#6 and '
              'settings.preferences.short-toggle#3');

      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();
      expect(edited, <core.LocalDate>[today],
          reason: 'list-habits.checkmark-button-rendering#10');
    });

    testWidgets('the toggle value comes from Entry.nextToggleValue and the '
        'preferences', (tester) async {
      preferences.isSkipEnabled = true;
      final toggles = <int>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.yesManual],
        onToggle: (_, value, _) => toggles.add(value),
      );

      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      // YES_MANUAL -> SKIP once skips are enabled, instead of NO.
      expect(toggles, <int>[core.Entry.skip],
          reason: 'list-habits.checkmark-button#4');
    });

    testWidgets('#3 the whole toggle cycle, under every preference pair',
        (tester) async {
      Future<int> next(int from) async {
        final toggles = <int>[];
        await pumpCard(
          tester,
          habit: buildHabit(),
          values: <int>[from],
          onToggle: (_, value, _) => toggles.add(value),
        );
        await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
        await tester.pumpAndSettle();
        return toggles.single;
      }

      // Both off: YES_MANUAL -> NO -> YES_MANUAL.
      expect(await next(core.Entry.yesManual), core.Entry.no,
          reason: 'list-habits.checkmark-button#3');
      expect(await next(core.Entry.no), core.Entry.yesManual,
          reason: 'list-habits.checkmark-button#3');
      expect(await next(core.Entry.yesAuto), core.Entry.yesManual,
          reason: 'list-habits.checkmark-button#2');

      // Skips on: YES_MANUAL -> SKIP -> NO.
      preferences.isSkipEnabled = true;
      expect(await next(core.Entry.yesManual), core.Entry.skip,
          reason: 'list-habits.checkmark-button#3');
      expect(await next(core.Entry.skip), core.Entry.no,
          reason: 'list-habits.checkmark-button#2');

      // …and question marks too: NO -> UNKNOWN -> YES_MANUAL.
      preferences.areQuestionMarksEnabled = true;
      expect(await next(core.Entry.no), core.Entry.unknown,
          reason: 'list-habits.checkmark-button#3');
      expect(await next(core.Entry.unknown), core.Entry.yesManual,
          reason: 'list-habits.checkmark-button#3');
    });

    testWidgets('an entry past the end of the values list reads as UNKNOWN',
        (tester) async {
      preferences.areQuestionMarksEnabled = true;
      final toggles = <int>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.yesManual],
        onToggle: (_, value, _) => toggles.add(value),
      );

      await tester.longPress(find.byKey(EntryPanel.buttonKey(today.minus(3))));
      await tester.pumpAndSettle();

      // UNKNOWN -> YES_MANUAL.
      expect(toggles, <int>[core.Entry.yesManual],
          reason: 'list-habits.entry-panels#5');
    });

    testWidgets('#5 a number cell past the end of the values reads as 0.0',
        (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(
          name: 'Read',
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 100,
        ),
        values: <int>[200000],
      );

      final beyond =
          viewAt(tester, today.minus(3)) as core_views.NumberButton;
      expect(beyond.value, 0.0, reason: 'list-habits.entry-panels#5');
    });

    testWidgets('dataOffset shifts the dates and the values together',
        (tester) async {
      final toggles = <List<Object>>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        dataOffset: 3,
        values: <int>[
          core.Entry.yesManual,
          core.Entry.yesManual,
          core.Entry.yesManual,
          core.Entry.no,
        ],
        notes: const <String>['', '', '', 'four days ago'],
        onToggle: (date, value, notes) => toggles.add(<Object>[date, value, notes]),
      );

      // NumberPanelViewTest.testEdit_withOffset: button 0 stands for day 3.
      expect(find.byKey(EntryPanel.buttonKey(today.minus(3))), findsOneWidget,
          reason: 'list-habits.entry-panels#4');
      expect(find.byKey(EntryPanel.buttonKey(today.minus(5))), findsOneWidget,
          reason: 'list-habits.entry-panels#4');
      expect(find.byKey(EntryPanel.buttonKey(today.minus(6))), findsOneWidget,
          reason: 'list-habits.entry-panels#4');
      expect(find.byKey(EntryPanel.buttonKey(today)), findsNothing,
          reason: 'list-habits.entry-panels#4');

      await tester.longPress(find.byKey(EntryPanel.buttonKey(today.minus(3))));
      await tester.pumpAndSettle();

      expect(toggles, <List<Object>>[
        <Object>[today.minus(3), core.Entry.yesManual, 'four days ago'],
      ], reason: 'list-habits.entry-panels#5');
      // notes[i + dataOffset], not notes[i].
      expect(toggles.single[2], 'four days ago',
          reason: 'list-habits.entry-panels#6');
    });

    testWidgets('#6 notes past the end of the array read as the empty string',
        (tester) async {
      final toggles = <List<Object>>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.no],
        notes: const <String>['only today'],
        onToggle: (date, value, notes) => toggles.add(<Object>[date, value, notes]),
      );

      await tester.longPress(find.byKey(EntryPanel.buttonKey(today.minus(2))));
      await tester.pumpAndSettle();

      expect(toggles.single[2], '', reason: 'list-habits.entry-panels#6');
    });

    testWidgets('a numerical habit answers both gestures with onEdit',
        (tester) async {
      final edited = <core.LocalDate>[];
      await pumpCard(
        tester,
        habit: buildHabit(
          name: 'Read',
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 100,
        ),
        values: <int>[200000, 0, 150000],
        onEdit: edited.add,
        onToggle: (_, _, _) => fail('a numerical habit never toggles'),
      );

      await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(EntryPanel.buttonKey(today.minus(1))));
      await tester.pumpAndSettle();

      expect(edited, <core.LocalDate>[today, today.minus(1)],
          reason: 'list-habits.number-button#1');
      expect(edited.length, 2, reason: 'list-habits.number-button#13');
    });

    testWidgets('#5 yes/no habits get checkmark cells, numerical ones numbers',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), values: <int>[core.Entry.no]);
      expect(viewAt(tester, today), isNot(isA<core_views.NumberButton>()),
          reason: 'list-habits.habit-card#5');
      expect(tester.widget<EntryPanel>(find.byType(EntryPanel)).isNumerical,
          isFalse,
          reason: 'list-habits.habit-card#5');

      await pumpCard(
        tester,
        habit: buildHabit(type: core.HabitType.numerical, unit: 'pages'),
        values: <int>[200000],
      );
      expect(viewAt(tester, today), isA<core_views.NumberButton>(),
          reason: 'list-habits.habit-card#5');
      expect(tester.widget<EntryPanel>(find.byType(EntryPanel)).isNumerical,
          isTrue,
          reason: 'list-habits.habit-card#5');
    });

    testWidgets('#6 the number cells divide the cached values by 1000',
        (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 100,
        ),
        values: <int>[200000, 0, 150500],
      );

      expect((viewAt(tester, today) as core_views.NumberButton).value, 200.0,
          reason: 'list-habits.habit-card#6');
      expect(
        (viewAt(tester, today.minus(1)) as core_views.NumberButton).value,
        0.0,
        reason: 'list-habits.habit-card#6',
      );
      expect(
        (viewAt(tester, today.minus(2)) as core_views.NumberButton).value,
        150.5,
        reason: 'list-habits.habit-card#6',
      );
    });

    testWidgets('#7 the threshold is the target divided by the denominator',
        (tester) async {
      // `HabitCardListView.bindCardView` overwrites the threshold that
      // `HabitCardView.habit =` had set to the bare targetValue.
      await pumpCard(
        tester,
        habit: buildHabit(
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 300,
          frequency: core.Frequency(3, 7),
        ),
        values: <int>[200000],
      );

      final button = viewAt(tester, today) as core_views.NumberButton;
      expect(button.threshold, closeTo(300 / 7, 1e-9),
          reason: 'list-habits.habit-card#7');
      expect(button.threshold, isNot(300.0),
          reason: 'list-habits.habit-card#7');

      // A daily habit divides by 1, so the bare target survives there.
      await pumpCard(
        tester,
        habit: buildHabit(
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 300,
        ),
        values: <int>[200000],
      );
      expect((viewAt(tester, today) as core_views.NumberButton).threshold, 300.0,
          reason: 'list-habits.habit-card#7');
    });

    testWidgets('#10 the unit reaches every number cell', (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 100,
        ),
        values: <int>[200000, 100000],
        buttonCount: 2,
      );

      for (var i = 0; i < 2; i++) {
        final button =
            viewAt(tester, today.minus(i)) as core_views.NumberButton;
        expect(button.units, 'pages', reason: 'list-habits.habit-card#10');
        expect(button.color, theme.colorOf(const core.PaletteColor(7)),
            reason: 'list-habits.habit-card#10');
      }
    });

    testWidgets('#10 rebuilding after a model change re-reads the habit',
        (tester) async {
      final habit = buildHabit();
      await pumpCard(tester, habit: habit, values: <int>[core.Entry.no]);
      expect(find.text('Meditate'), findsOneWidget,
          reason: 'list-habits.habit-card#10');

      habit.name = 'Meditate twice';
      habit.color = const core.PaletteColor(11);
      await pumpCard(tester, habit: habit, values: <int>[core.Entry.no]);

      expect(find.text('Meditate twice'), findsOneWidget,
          reason: 'list-habits.habit-card#10');
      expect(
        tester.widget<Text>(find.text('Meditate twice')).style?.color,
        _toFlutterColor(theme.colorOf(const core.PaletteColor(11))),
        reason: 'list-habits.habit-card#10',
      );
    });

    testWidgets('the row reports taps and long presses of its own',
        (tester) async {
      var taps = 0;
      var longPresses = 0;
      await pumpCard(
        tester,
        habit: buildHabit(),
        onTap: () => taps++,
        onLongPress: () => longPresses++,
      );

      await tester.tap(find.text('Meditate'));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.longPress(find.text('Meditate'));
      await tester.pumpAndSettle();
      expect(longPresses, 1);
    });

    testWidgets('a gesture on an entry button does not reach the row',
        (tester) async {
      var taps = 0;
      var longPresses = 0;
      final edited = <core.LocalDate>[];
      final toggles = <int>[];
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.no],
        onEdit: edited.add,
        onToggle: (_, value, _) => toggles.add(value),
        onTap: () => taps++,
        onLongPress: () => longPresses++,
      );

      await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      expect(edited, <core.LocalDate>[today]);
      expect(toggles, <int>[core.Entry.yesManual]);
      // `onLongClick` returns true, so the long press is consumed by the
      // button and never becomes a row long press.
      expect(taps, 0, reason: 'list-habits.checkmark-button#7');
      expect(longPresses, 0, reason: 'list-habits.checkmark-button#7');
    });

    testWidgets('#13 a number cell consumes its long press too', (tester) async {
      var longPresses = 0;
      final edited = <core.LocalDate>[];
      await pumpCard(
        tester,
        habit: buildHabit(
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 100,
        ),
        values: <int>[200000],
        onEdit: edited.add,
        onLongPress: () => longPresses++,
      );

      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      expect(edited, <core.LocalDate>[today],
          reason: 'list-habits.number-button#13');
      expect(longPresses, 0, reason: 'list-habits.number-button#13');
    });

    testWidgets('the panel sits flush against the inner right edge',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);

      final card = tester.getRect(find.byType(HabitCard));
      final oldest = tester.getRect(find.byKey(EntryPanel.buttonKey(today)));
      final newest =
          tester.getRect(find.byKey(EntryPanel.buttonKey(today.minus(4))));

      // 3dp of card padding on the right, and five 48dp buttons before it.
      expect(newest.right, card.right - 3,
          reason: 'list-habits.habit-card#8');
      expect(newest.right - oldest.left, theme.checkmarkButtonSize * 5,
          reason: 'list-habits.entry-panels#1');
    });

    testWidgets('#8 3dp of padding on three sides, 1dp of elevation',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);

      final card = tester.getRect(find.byType(HabitCard));
      final material = tester.getRect(
        find.descendant(of: find.byType(HabitCard), matching: find.byType(Material)).first,
      );
      // setPadding(3, 0, 3, 3): no top padding at all.
      expect(material.left - card.left, 3.0,
          reason: 'list-habits.habit-card#8');
      expect(card.right - material.right, 3.0,
          reason: 'list-habits.habit-card#8');
      expect(material.top - card.top, 0.0,
          reason: 'list-habits.habit-card#8');
      expect(card.bottom - material.bottom, 3.0,
          reason: 'list-habits.habit-card#8');

      final inner = tester.widget<Material>(
        find.descendant(of: find.byType(HabitCard), matching: find.byType(Material)).first,
      );
      expect(inner.elevation, 1.0, reason: 'list-habits.habit-card#8');
      expect(inner.color, _toFlutterColor(theme.cardBackgroundColor),
          reason: 'list-habits.habit-card#8');
      expect(inner.shape, isNull, reason: 'list-habits.habit-card#8');
    });

    testWidgets('#8 a selected row swaps the ripple for the selected box',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), isSelected: true);

      final inner = tester.widget<Material>(
        find.descendant(of: find.byType(HabitCard), matching: find.byType(Material)).first,
      );
      // res/drawable/selected_box.xml: a filled rect under a 2dp stroke,
      // replacing res/drawable/ripple.xml's ?attr/cardBgColor.
      expect(inner.color, isNot(_toFlutterColor(theme.cardBackgroundColor)),
          reason: 'list-habits.selection-mode#10');
      expect(inner.shape, isA<Border>(),
          reason: 'list-habits.selection-mode#10');
      expect((inner.shape! as Border).top.width, 2.0,
          reason: 'list-habits.habit-card#8');
    });

    testWidgets('the score ring is 15dp wide, 8dp in from the card padding',
        (tester) async {
      await pumpCard(tester, habit: buildHabit());

      final card = tester.getRect(find.byType(HabitCard));
      // The ring is the first CoreView in the row; the rest are entry buttons.
      final ring = tester.getRect(find.byType(CoreView).first);

      expect(ring.width, 15, reason: 'list-habits.habit-card#2');
      expect(ring.height, 15, reason: 'list-habits.habit-card#2');
      // 3dp of card padding plus the ring's own 8dp margin.
      expect(ring.left, card.left + 3 + 8,
          reason: 'list-habits.habit-card#2');
    });

    testWidgets('#2 the ring sweep is the cached score, quantised to 1/16',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), score: 0.5);

      final canvas = _RecordingCanvas(width: 15, height: 15);
      tester.widget<CoreView>(find.byType(CoreView).first).view.draw(canvas);

      final arc = canvas.opsNamed('fillArc').first;
      // Ring.draw sweeps `-360 * percentage` from 90 degrees, and the ring
      // itself is `dp(3)` thick.
      expect(arc.args[4], closeTo(-180.0, 1e-9),
          reason: 'list-habits.habit-card#2');
    });
  });

  // -------------------------------------------------------------------------
  // The two core button views, as hosted by the panel. Only the geometry and
  // the gestures are this port's; the richer Android drawing is not.
  // -------------------------------------------------------------------------
  group('entry panels, revisited', () {
    testWidgets('#2 a new buttonCount changes the row, the same one does not',
        (tester) async {
      final habit = buildHabit();
      await pumpCard(tester, habit: habit, buttonCount: 5);
      expect(find.byType(EntryButton), findsNWidgets(5),
          reason: 'list-habits.entry-panels#2');
      final before = tester.element(find.byKey(EntryPanel.buttonKey(today)));

      // Rebuilding with the same count leaves the row exactly as it was: the
      // element behind today's cell is the very same one.
      await pumpCard(tester, habit: habit, buttonCount: 5);
      expect(find.byType(EntryButton), findsNWidgets(5),
          reason: 'list-habits.entry-panels#2 — setting the same value again '
              'is a no-op');
      expect(tester.element(find.byKey(EntryPanel.buttonKey(today))),
          same(before),
          reason: 'list-habits.entry-panels#2');

      await pumpCard(tester, habit: habit, buttonCount: 3);
      expect(find.byType(EntryButton), findsNWidgets(3),
          reason: 'list-habits.entry-panels#2 — a different value re-creates '
              'the buttons');
      expect(find.byKey(EntryPanel.buttonKey(today.minus(4))), findsNothing,
          reason: 'list-habits.entry-panels#2');
    });

    testWidgets('#3 a new dataOffset re-binds the same number of buttons',
        (tester) async {
      final habit = buildHabit();
      const List<int> values = <int>[2, 0, 2, 0, 2, 0, 2, 0];
      await pumpCard(tester, habit: habit, values: values, dataOffset: 0);
      expect(find.byType(EntryButton), findsNWidgets(5),
          reason: 'list-habits.entry-panels#3');
      final firstDates = <core.LocalDate>[
        for (var i = 0; i < 5; i++) today.minus(i),
      ];
      for (final date in firstDates) {
        expect(find.byKey(EntryPanel.buttonKey(date)), findsOneWidget,
            reason: 'list-habits.entry-panels#3');
      }

      await pumpCard(tester, habit: habit, values: values, dataOffset: 3);

      expect(find.byType(EntryButton), findsNWidgets(5),
          reason: 'list-habits.entry-panels#3 — the count is unchanged: only '
              'the binding moved');
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(EntryPanel.buttonKey(today.minus(i + 3))),
            findsOneWidget,
            reason: 'list-habits.entry-panels#3 and #4 — button i now stands '
                'for today.minus(i + dataOffset)');
      }
      expect(find.byKey(EntryPanel.buttonKey(today)), findsNothing,
          reason: 'list-habits.entry-panels#3');

      // Setting the same offset again changes nothing.
      final before = tester.element(
        find.byKey(EntryPanel.buttonKey(today.minus(3))),
      );
      await pumpCard(tester, habit: habit, values: values, dataOffset: 3);
      expect(tester.element(find.byKey(EntryPanel.buttonKey(today.minus(3)))),
          same(before),
          reason: 'list-habits.entry-panels#3 — setting the same value again '
              'is a no-op');
    });

    testWidgets('#10 the number panel carries threshold, unit and colour; the '
        'checkmark panel carries the colour only', (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 100,
          color: const core.PaletteColor(11),
          frequency: core.Frequency.daily,
        ),
        values: <int>[200000],
      );

      final number = viewAt(tester, today) as core_views.NumberButton;
      expect(number.threshold, 100.0,
          reason: 'list-habits.entry-panels#10 — the threshold reaches every '
              'button');
      expect(number.units, 'pages',
          reason: 'list-habits.entry-panels#10 — and so does the unit');
      expect(number.color, theme.colorOf(const core.PaletteColor(11)),
          reason: 'list-habits.entry-panels#10 — and the colour');
      expect(number.value, 200.0,
          reason: 'list-habits.entry-panels#10 — values arrive divided by '
              '1000');

      // The checkmark panel propagates colour only: its core view takes a
      // value, a colour and a theme, and nothing else.
      await pumpCard(
        tester,
        habit: buildHabit(color: const core.PaletteColor(11)),
        values: <int>[core.Entry.yesManual],
      );
      final glyph = drawButton(tester, today).opsNamed('drawText').single;
      expect(glyph.color, theme.colorOf(const core.PaletteColor(11)),
          reason: 'list-habits.entry-panels#10 — the checkmark panel '
              'propagates the colour');
      // `targetType` is accepted by the panel and forwarded nowhere, because
      // the core NumberButton has no AT_MOST branch yet.
      expect(
        tester
            .widgetList<EntryPanel>(find.byType(EntryPanel))
            .single
            .targetType,
        core.NumericalHabitType.atLeast,
        reason: 'list-habits.entry-panels#10',
      );
    });

    testWidgets('checkmark-button-rendering#9 a cell is 48dp square whatever '
        'the row is given', (tester) async {
      final habit = buildHabit();
      await pumpCard(tester, habit: habit, values: <int>[core.Entry.yesManual]);
      expect(theme.checkmarkButtonSize, 48.0,
          reason: 'list-habits.checkmark-button-rendering#9 — '
              'R.dimen.checkmarkWidth / checkmarkHeight');
      expect(tester.getSize(find.byKey(EntryPanel.buttonKey(today))),
          const Size(48, 48),
          reason: 'list-habits.checkmark-button-rendering#9');

      // A row too narrow for five 48dp cells still measures each of them at
      // exactly 48dp: onMeasure ignores the incoming spec.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 120,
                child: HabitCard(
                  habit: habit,
                  score: 0.5,
                  values: const <int>[core.Entry.yesManual],
                  notes: const <String>[],
                  theme: theme,
                  preferences: preferences,
                  buttonCount: 5,
                  dataOffset: 0,
                  isSelected: false,
                ),
              ),
            ),
          ),
        ),
      );
      // The row overflows rather than shrinking its cells, exactly as the
      // Android panel does.
      tester.takeException();
      expect(tester.getSize(find.byKey(EntryPanel.buttonKey(today))),
          const Size(48, 48),
          reason: 'list-habits.checkmark-button-rendering#9 — regardless of '
              'the incoming measure spec');
    });
  });

  group('entry cells', () {
    test('#1 the entry value constants', () {
      expect(core.Entry.skip, 3, reason: 'list-habits.checkmark-button#1');
      expect(core.Entry.yesManual, 2, reason: 'list-habits.checkmark-button#1');
      expect(core.Entry.yesAuto, 1, reason: 'list-habits.checkmark-button#1');
      expect(core.Entry.no, 0, reason: 'list-habits.checkmark-button#1');
      expect(core.Entry.unknown, -1, reason: 'list-habits.checkmark-button#1');
    });

    testWidgets('#1 a checkmark cell is a 48dp canvas with one centred glyph',
        (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.yesManual],
      );

      expect(
        tester.getSize(find.byKey(EntryPanel.buttonKey(today))),
        const Size(48, 48),
        reason: 'list-habits.checkmark-button-rendering#1',
      );

      final canvas = drawButton(tester, today);
      final glyphs = canvas.opsNamed('drawText');
      expect(glyphs, hasLength(1),
          reason: 'list-habits.checkmark-button-rendering#1');
      expect(glyphs.single.font, core.Font.fontAwesome,
          reason: 'list-habits.checkmark-button-rendering#1');
      expect(glyphs.single.args, <double>[24.0, 24.0],
          reason: 'list-habits.checkmark-button-rendering#1');
      expect(glyphs.single.text, core.FontAwesome.check,
          reason: 'list-habits.checkmark-button-rendering#1');
    });

    testWidgets('#12 a new value repaints the cell', (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(),
        values: <int>[core.Entry.yesManual],
      );
      final checked = drawButton(tester, today).opsNamed('drawText').single;

      await pumpCard(tester, habit: buildHabit(), values: <int>[core.Entry.no]);
      final unchecked = drawButton(tester, today).opsNamed('drawText').single;

      expect(unchecked.text, isNot(checked.text),
          reason: 'list-habits.checkmark-button-rendering#12');
      expect(unchecked.color, isNot(checked.color),
          reason: 'list-habits.checkmark-button-rendering#12');

      // …and so does a new colour.
      await pumpCard(
        tester,
        habit: buildHabit(color: const core.PaletteColor(11)),
        values: <int>[core.Entry.yesManual],
      );
      expect(
        drawButton(tester, today).opsNamed('drawText').single.color,
        isNot(checked.color),
        reason: 'list-habits.checkmark-button-rendering#12',
      );
    });

    testWidgets('#2 #11 a number cell is 48dp square too', (tester) async {
      await pumpCard(
        tester,
        habit: buildHabit(
          type: core.HabitType.numerical,
          unit: 'pages',
          targetValue: 100,
        ),
        values: <int>[200000],
      );

      expect(
        tester.getSize(find.byKey(EntryPanel.buttonKey(today))),
        const Size(48, 48),
        reason: 'list-habits.number-button#2',
      );
      expect(theme.checkmarkButtonSize, 48.0,
          reason: 'list-habits.number-button#11');
    });

    testWidgets('#14 a new value, threshold, unit or colour repaints the cell',
        (tester) async {
      core.Habit numerical({
        double targetValue = 100,
        String unit = 'pages',
        core.PaletteColor color = const core.PaletteColor(7),
      }) =>
          buildHabit(
            type: core.HabitType.numerical,
            unit: unit,
            targetValue: targetValue,
            color: color,
          );

      await pumpCard(tester, habit: numerical(), values: <int>[200000]);
      final first = viewAt(tester, today) as core_views.NumberButton;

      await pumpCard(tester, habit: numerical(), values: <int>[50000]);
      expect((viewAt(tester, today) as core_views.NumberButton).value,
          isNot(first.value),
          reason: 'list-habits.number-button#14');

      await pumpCard(
        tester,
        habit: numerical(targetValue: 25),
        values: <int>[200000],
      );
      expect((viewAt(tester, today) as core_views.NumberButton).threshold,
          isNot(first.threshold),
          reason: 'list-habits.number-button#14');

      await pumpCard(
        tester,
        habit: numerical(unit: 'chapters'),
        values: <int>[200000],
      );
      expect((viewAt(tester, today) as core_views.NumberButton).units,
          isNot(first.units),
          reason: 'list-habits.number-button#14');

      await pumpCard(
        tester,
        habit: numerical(color: const core.PaletteColor(11)),
        values: <int>[200000],
      );
      expect((viewAt(tester, today) as core_views.NumberButton).color,
          isNot(first.color),
          reason: 'list-habits.number-button#14');
    });
  });
}

/// The core [core.Color] carries normalised channels; `dart:ui` wants bytes.
Color _toFlutterColor(core.Color color) => Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );

class _Op {
  _Op(
    this.name,
    this.args, {
    this.text,
    required this.color,
    required this.font,
    required this.fontSize,
  });

  final String name;
  final List<double> args;
  final String? text;
  final core.Color color;
  final core.Font font;
  final double fontSize;

  @override
  String toString() => '$name(${text == null ? '' : '"$text", '}$args)';
}

/// A [core.Canvas] that logs every call with the sticky paint state it was
/// made under, the same fake the core view tests drive their views against.
class _RecordingCanvas extends core.Canvas {
  _RecordingCanvas({required this.width, required this.height});

  final double width;
  final double height;
  final List<_Op> ops = <_Op>[];

  core.Color _color = core.Color.BLACK;
  core.Font _font = core.Font.regular;
  double _fontSize = 12.0;

  List<_Op> opsNamed(String name) =>
      ops.where((op) => op.name == name).toList();

  void _record(String name, List<double> args, {String? text}) {
    ops.add(_Op(name, args,
        text: text, color: _color, font: _font, fontSize: _fontSize));
  }

  @override
  double getWidth() => width;

  @override
  double getHeight() => height;

  @override
  void setColor(core.Color color) => _color = color;

  @override
  void setFont(core.Font font) => _font = font;

  @override
  void setFontSize(double size) => _fontSize = size;

  @override
  void setStrokeWidth(double size) {}

  @override
  void setTextAlign(core.TextAlign align) {}

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      _record('drawLine', <double>[x1, y1, x2, y2]);

  @override
  void drawText(String text, double x, double y) =>
      _record('drawText', <double>[x, y], text: text);

  @override
  void fillRect(double x, double y, double w, double h) =>
      _record('fillRect', <double>[x, y, w, h]);

  @override
  void drawRect(double x, double y, double w, double h) =>
      _record('drawRect', <double>[x, y, w, h]);

  @override
  void fillRoundRect(double x, double y, double w, double h, double radius) =>
      _record('fillRoundRect', <double>[x, y, w, h, radius]);

  @override
  void fillCircle(double cx, double cy, double radius) =>
      _record('fillCircle', <double>[cx, cy, radius]);

  @override
  void fillArc(
    double cx,
    double cy,
    double radius,
    double startAngle,
    double swipeAngle,
  ) =>
      _record('fillArc', <double>[cx, cy, radius, startAngle, swipeAngle]);

  @override
  double measureText(String text) => text.length * _fontSize * 0.6;

  @override
  core.Image toImage() => throw UnsupportedError('not recorded');
}
