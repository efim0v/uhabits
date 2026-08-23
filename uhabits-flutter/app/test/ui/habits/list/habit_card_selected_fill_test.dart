/// `audit.a-selected-habit-row-is-filled`.
///
/// `HabitCardView.updateBackground` swaps the inner frame between
/// `@drawable/ripple` (solid `?cardBgColor`) and `@drawable/selected_box`,
/// whose fill is `?highlightedBackgroundColor` under a 2dp grey_500 stroke.
/// The port has the token — `Theme.highlightedBackgroundColor` — but the card
/// painted `headerBackgroundColor` instead, which moves the selected row the
/// wrong way in both dark themes.
library;

// The core package does not export lib/src/preferences yet.
// ignore_for_file: implementation_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart' as core;
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late core.Preferences preferences;

  setUp(() {
    core.setToday(core.LocalDate.ymd(2020, 1, 15));
    preferences = core.Preferences(core.MemoryStorage());
  });

  tearDown(core.resetToday);

  Color flutter(core.Color color) => Color.fromARGB(
        (color.alpha * 255).round(),
        (color.red * 255).round(),
        (color.green * 255).round(),
        (color.blue * 255).round(),
      );

  Future<Material> pumpSelectedCard(
    WidgetTester tester,
    core.Theme theme, {
    bool isSelected = true,
  }) async {
    final habit = core.MemoryModelFactory().buildHabit()
      ..name = 'Meditate'
      ..color = const core.PaletteColor(7);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: HabitCard(
                habit: habit,
                score: 0.5,
                values: const <int>[],
                notes: const <String>[],
                theme: theme,
                preferences: preferences,
                buttonCount: 5,
                dataOffset: 0,
                isSelected: isSelected,
              ),
            ),
          ),
        ),
      ),
    );

    return tester.widget<Material>(
      find
          .descendant(of: find.byType(HabitCard), matching: find.byType(Material))
          .first,
    );
  }

  group('the selected row fill', () {
    testWidgets('is highlightedBackgroundColor in the light theme',
        (tester) async {
      final theme = core.LightTheme();
      final material = await pumpSelectedCard(tester, theme);

      expect(
        material.color,
        flutter(theme.highlightedBackgroundColor),
        reason: 'audit.a-selected-habit-row-is-filled#1: selected_box.xml is '
            '<solid android:color="?highlightedBackgroundColor"/> — @color/grey_100 '
            '(#F5F5F5) in AppBaseTheme. '
            'audit.a-selected-habit-row-is-filled#2: the port must do the same '
            'instead of painting headerBackgroundColor (#eeeeee).',
      );
    });

    testWidgets('is grey_800 in the dark theme, lighter than the card',
        (tester) async {
      final theme = core.DarkTheme();
      final material = await pumpSelectedCard(tester, theme);

      expect(
        material.color,
        flutter(theme.highlightedBackgroundColor),
        reason: 'audit.a-selected-habit-row-is-filled#1: in the dark theme '
            '?highlightedBackgroundColor is @color/grey_800 (#424242) against a '
            '#303030 card, so a selected row visibly lightens. '
            'audit.a-selected-habit-row-is-filled#2: the port used '
            'headerBackgroundColor (#212121), so the row went darker than the '
            'card — the opposite of upstream.',
      );
      expect(
        material.color,
        isNot(flutter(theme.headerBackgroundColor)),
        reason: 'audit.a-selected-habit-row-is-filled#2: headerBackgroundColor '
            'is the stale token the port used on the strength of a comment '
            'claiming highlightedBackgroundColor had not been ported',
      );
    });

    testWidgets('is black in the pure-black theme, carried by the stroke alone',
        (tester) async {
      final theme = core.PureBlackTheme();
      final material = await pumpSelectedCard(tester, theme);

      expect(
        material.color,
        flutter(theme.highlightedBackgroundColor),
        reason: 'audit.a-selected-habit-row-is-filled#1: in pure black '
            '?highlightedBackgroundColor is @color/black, i.e. the selection is '
            'carried by the grey_500 stroke alone. '
            'audit.a-selected-habit-row-is-filled#2: the port lit the row up to '
            '#212121 instead, because headerBackgroundColor is grey_900 there.',
      );
      expect(
        material.color,
        flutter(theme.cardBackgroundColor),
        reason: 'audit.a-selected-habit-row-is-filled#1: black on black — only '
            'the 2dp stroke distinguishes a selected pure-black row',
      );
    });

    testWidgets('an unselected row keeps cardBgColor in every theme',
        (tester) async {
      for (final theme in <core.Theme>[
        core.LightTheme(),
        core.DarkTheme(),
        core.PureBlackTheme(),
      ]) {
        final material =
            await pumpSelectedCard(tester, theme, isSelected: false);
        expect(
          material.color,
          flutter(theme.cardBackgroundColor),
          reason: 'audit.a-selected-habit-row-is-filled#1: '
              'HabitCardView.updateBackground(false) restores '
              '@drawable/ripple, a solid ?cardBgColor. '
              'audit.a-selected-habit-row-is-filled#2: only the selected fill '
              'changes.',
        );
      }
    });
  });
}
