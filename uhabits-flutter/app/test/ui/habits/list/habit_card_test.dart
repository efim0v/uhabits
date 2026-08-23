/// Widget tests for the habit card row and its entry button panel.
///
/// These pin the behaviour HabitCardViewTest, CheckmarkPanelViewTest and
/// NumberPanelViewTest pin on the Android side: which date each button stands
/// for (including under `dataOffset`), which gesture toggles and which one
/// edits, and that the card renders the habit in its own colour.
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
    bool isArchived = false,
  }) {
    final habit = core.MemoryModelFactory().buildHabit();
    habit.name = name;
    habit.color = color;
    habit.type = type;
    habit.unit = unit;
    habit.targetValue = targetValue;
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

  group('HabitCard', () {
    testWidgets('renders the habit name in its palette colour', (tester) async {
      await pumpCard(tester, habit: buildHabit());

      final label = tester.widget<Text>(find.text('Meditate'));
      // PaletteColor(7) is green; LightTheme resolves it to 0x388E3C.
      expect(label.style?.color, const Color(0xFF388E3C));
    });

    testWidgets('draws an archived habit in the medium contrast colour',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(isArchived: true));

      final label = tester.widget<Text>(find.text('Meditate'));
      // copyAttributesFrom(): archived habits use ?attr/contrast60.
      expect(label.style?.color, const Color(0xFF9E9E9E));
    });

    testWidgets('shows one entry button per visible date, newest first',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);

      expect(find.byType(EntryButton), findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(EntryPanel.buttonKey(today.minus(i))), findsOneWidget);
      }

      // Newest on the left, oldest on the right.
      final first = tester.getCenter(find.byKey(EntryPanel.buttonKey(today)));
      final last =
          tester.getCenter(find.byKey(EntryPanel.buttonKey(today.minus(4))));
      expect(first.dx, lessThan(last.dx));

      // 48 logical pixels apart, matching R.dimen.checkmarkWidth.
      final second =
          tester.getCenter(find.byKey(EntryPanel.buttonKey(today.minus(1))));
      expect(second.dx - first.dx, theme.checkmarkButtonSize);
    });

    testWidgets('lays the buttons out oldest first when the sequence is reversed',
        (tester) async {
      preferences.isCheckmarkSequenceReversed = true;
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);

      final newest = tester.getCenter(find.byKey(EntryPanel.buttonKey(today)));
      final oldest =
          tester.getCenter(find.byKey(EntryPanel.buttonKey(today.minus(4))));
      expect(oldest.dx, lessThan(newest.dx));
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
      ]);
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

      expect(edited, <core.LocalDate>[today.minus(2)]);
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
      expect(toggles, <int>[core.Entry.yesManual]);
      expect(edited, isEmpty);

      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();
      expect(edited, <core.LocalDate>[today]);
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
      expect(toggles, <int>[core.Entry.skip]);
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
      expect(toggles, <int>[core.Entry.yesManual]);
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
      await tester.longPress(find.byKey(EntryPanel.buttonKey(today.minus(3))));
      await tester.pumpAndSettle();

      expect(toggles, <List<Object>>[
        <Object>[today.minus(3), core.Entry.yesManual, 'four days ago'],
      ]);
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

      expect(edited, <core.LocalDate>[today, today.minus(1)]);
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
      expect(taps, 0);
      expect(longPresses, 0);
    });

    testWidgets('the panel sits flush against the inner right edge',
        (tester) async {
      await pumpCard(tester, habit: buildHabit(), buttonCount: 5);

      final card = tester.getRect(find.byType(HabitCard));
      final oldest = tester.getRect(find.byKey(EntryPanel.buttonKey(today)));
      final newest =
          tester.getRect(find.byKey(EntryPanel.buttonKey(today.minus(4))));

      // 3dp of card padding on the right, and five 48dp buttons before it.
      expect(newest.right, card.right - 3);
      expect(newest.right - oldest.left, theme.checkmarkButtonSize * 5);
    });

    testWidgets('the score ring is 15dp wide, 8dp in from the card padding',
        (tester) async {
      await pumpCard(tester, habit: buildHabit());

      final card = tester.getRect(find.byType(HabitCard));
      // The ring is the first CoreView in the row; the rest are entry buttons.
      final ring = tester.getRect(find.byType(CoreView).first);

      expect(ring.width, 15);
      expect(ring.height, 15);
      // 3dp of card padding plus the ring's own 8dp margin.
      expect(ring.left, card.left + 3 + 8);
    });
  });
}
