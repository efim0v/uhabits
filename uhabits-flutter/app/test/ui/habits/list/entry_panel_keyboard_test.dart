/// `audit10.the-check-mark-grid-cannot-be-reached-or#1`: the check-mark grid
/// is operable from a hardware keyboard or D-pad.
///
/// Upstream `CheckmarkButtonView` and `NumberButtonView` are plain `View`s
/// whose init block runs `setOnClickListener(this)` /
/// `setOnLongClickListener(this)`. That sets `CLICKABLE`, and with
/// `targetSdk = 36` (>= 26) `View.focusable` defaults to `FOCUSABLE_AUTO`,
/// which resolves to focusable for a clickable view — so every cell is a Tab /
/// D-pad stop, and `KeyEvent.isConfirmKey` (DPAD_CENTER, ENTER, NUMPAD_ENTER,
/// SPACE) runs `performClick()`, i.e. the same `onClick` branch a tap takes.
///
/// Everything is driven through the habit list the app builds for itself: a
/// cell that no traversal ever reaches is precisely the defect, so the focus
/// node has to be found in the live tree rather than handed to an
/// [EntryPanel] this test constructed.
library;

import 'dart:io';

import 'package:flutter/material.dart';
// `Theme` and `Color` are both names uhabits_core exports too.
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits_core/uhabits_core.dart';

const String focusRule =
    'audit11.focusing-one-check-mark-cell-paints#1 — In the Kotlin app: the '
    'default focus highlight is drawn by View.onDrawForeground on the view\'s '
    'OWN primary focus (isFocused()), never on hasFocus(), and HabitCardView '
    'is not focusable at all — HabitCardListView.bindCardView binds the row '
    'with setOnTouchListener and never setOnClickListener. So walking a habit '
    'row with a keyboard or D-pad tints exactly one 48dp cell at a time and '
    'never the row behind it.';

const String rule = 'audit10.the-check-mark-grid-cannot-be-reached-or#1 — In '
    'the Kotlin app: each cell of the check-mark grid registers '
    'setOnClickListener/setOnLongClickListener in its init block, which makes '
    'it clickable and therefore focusable under FOCUSABLE_AUTO, so a keyboard '
    'or D-pad walks the row cell by cell and a confirm key (ENTER, '
    'NUMPAD_ENTER, SPACE, DPAD_CENTER) runs performClick() — the same branch a '
    'tap takes.';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_grid_keyboard');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final scope =
        AppScope.open(AppDatabase.openAndMigrate('${tempDir.path}/habits.db'));
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(
    AppScope scope,
    String name, {
    HabitType type = HabitType.yesNo,
  }) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = type
      ..color = const PaletteColor(8);
    if (type == HabitType.numerical) {
      habit.unit = 'steps';
      habit.targetValue = 100.0;
    }
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Future<void> pumpList(WidgetTester tester, AppScope scope) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder cellOf(String habit, LocalDate date) => find.descendant(
        of: find.ancestor(
          of: find.text(habit),
          matching: find.byType(HabitCard),
        ),
        matching: find.byKey(EntryPanel.buttonKey(date)),
      );

  /// The focus node the traversal would land on when it reaches [cell].
  ///
  /// Found by geometry rather than by widget type, so the assertion is about
  /// the cell being *reachable* rather than about how it was made reachable.
  FocusNode? focusOver(WidgetTester tester, Finder cell) {
    final Rect rect = tester.getRect(cell);
    for (final FocusNode node
        in tester.binding.focusManager.rootScope.traversalDescendants) {
      if (node.rect == rect) return node;
    }
    return null;
  }

  int entryOf(Habit habit, LocalDate date) =>
      habit.computedEntries.get(date).value;

  group('audit10.the-check-mark-grid-cannot-be-reached-or', () {
    testWidgets('#1 every cell of the row is a traversal stop', (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      final today = getToday();

      for (var back = 0; back < 3; back++) {
        final date = today.minus(back);
        expect(focusOver(tester, cellOf('Meditate', date)), isNotNull,
            reason: '$rule (column $back)');
      }
    });

    testWidgets('#1 ENTER on a focused cell runs the click branch',
        (tester) async {
      final scope = openScope();
      // pref_short_toggle on, so onClick is performToggle rather than the
      // notes editor — the branch whose loss the report is about.
      scope.preferences.isShortToggleEnabled = true;
      final habit = addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      final today = getToday();

      expect(entryOf(habit, today), Entry.unknown, reason: rule);

      focusOver(tester, cellOf('Meditate', today))!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(entryOf(habit, today), Entry.yesManual, reason: rule);
    });

    testWidgets('#1 SPACE is a confirm key too', (tester) async {
      final scope = openScope();
      scope.preferences.isShortToggleEnabled = true;
      final habit = addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      final today = getToday();

      focusOver(tester, cellOf('Meditate', today))!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(entryOf(habit, today), Entry.yesManual,
          reason: '$rule KeyEvent.isConfirmKey lists KEYCODE_SPACE alongside '
              'DPAD_CENTER and the two ENTERs.');
    });

    testWidgets('#1 a numerical cell opens its editor from the keyboard',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Steps', type: HabitType.numerical);
      await pumpList(tester, scope);
      final today = getToday();

      focusOver(tester, cellOf('Steps', today))!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget,
          reason: '$rule NumberButtonView answers onClick with onEdit, so the '
              'confirm key opens the number popup.');
    });
  });

  group('audit11.focusing-one-check-mark-cell-paints', () {
    /// The `_RenderInkFeatures` layer of the card's own `Material` — the one
    /// `Material.of` hands the row's `InkWell`.
    ///
    /// It paints its ink features first and then its whole subtree, so one
    /// walk over its recording sees both the row-wide `InkHighlight` and the
    /// focused cell's own `DecoratedBox`. Counting the rects tinted with
    /// `Theme.focusColor` is therefore exactly the question Android answers
    /// with "one".
    RenderObject inkLayerOf(WidgetTester tester, Finder card) {
      RenderObject? found;
      void visit(RenderObject node) {
        if (found != null) return;
        if (node.runtimeType.toString() == '_RenderInkFeatures') {
          found = node;
          return;
        }
        node.visitChildren(visit);
      }

      visit(tester.renderObject(card));
      return found ?? (throw StateError('no ink layer inside the habit card'));
    }

    int focusTints(RenderObject ink, material.Color color) {
      var count = 0;
      expect(ink, paints..everything((Symbol method, List<dynamic> arguments) {
        if (method == #drawRect && arguments.length > 1) {
          final Object? paint = arguments[1];
          // `Paint.color` round-trips through a 32-bit int, so its channels
          // come back a few float ULPs away from the theme's own Color and
          // `==` says no; the packed value is what both agree on.
          if (paint is Paint && paint.color.toARGB32() == color.toARGB32()) {
            count++;
          }
        }
        return true;
      }));
      return count;
    }

    /// Widget tests run with `FocusHighlightMode.touch`, under which
    /// `InkResponse.updateFocusHighlights` paints nothing at all — which is
    /// why no existing test could see this. A hardware keyboard flips the mode
    /// on its first key; the strategy does it up front.
    void useTraditionalFocusHighlights() {
      final FocusHighlightStrategy previous =
          FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    }

    Finder cardOf(String habit) => find.ancestor(
          of: find.text(habit),
          matching: find.byType(HabitCard),
        );

    testWidgets('#1 a focused cell tints only itself, never the row',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      useTraditionalFocusHighlights();
      final today = getToday();

      final material.Color focusColor =
          material.Theme.of(tester.element(cardOf('Meditate'))).focusColor;

      focusOver(tester, cellOf('Meditate', today))!.requestFocus();
      await tester.pumpAndSettle();

      expect(focusTints(inkLayerOf(tester, cardOf('Meditate')), focusColor),
          1,
          reason: '$focusRule One tint, and it is the cell\'s own — a second '
              'rect of the same colour is the row\'s InkWell reacting to '
              'hasFocus, which is true for any descendant.');
    });

    testWidgets('#1 the row still shows its own highlight when it holds focus',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpList(tester, scope);
      useTraditionalFocusHighlights();

      final material.Color focusColor =
          material.Theme.of(tester.element(cardOf('Meditate'))).focusColor;
      expect(focusTints(inkLayerOf(tester, cardOf('Meditate')), focusColor),
          0,
          reason: '$focusRule Nothing is focused yet.');

      focusOver(
        tester,
        find.descendant(of: cardOf('Meditate'), matching: find.byType(InkWell)),
      )!
          .requestFocus();
      await tester.pumpAndSettle();

      expect(focusTints(inkLayerOf(tester, cardOf('Meditate')), focusColor),
          1,
          reason: '$focusRule The port keeps the row focusable on purpose so '
              'that Enter opens the detail screen (a recorded deviation); '
              'suppressing the descendant flood must not take the row\'s own '
              'indicator with it.');
    });
  });
}
