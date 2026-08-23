/// `audit.the-habit-list-has-no-vertical`: the habit list's vertical scrollbar.
///
/// Upstream the habit list is the one view in the app that asks for a
/// scrollbar, and it asks for it through a style whose only job is that:
/// `HabitCardListView(context, null, R.attr.scrollableRecyclerViewStyle)` picks
/// up `<style name="ScrollableRecyclerViewStyle" parent="android:Widget">` with
/// `<item name="android:scrollbars">vertical</item>`. Flutter's default
/// `ScrollBehavior` draws no scrollbar on Android or iOS, so the port had no
/// position indicator at all.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart';

const String rule1 =
    'audit.the-habit-list-has-no-vertical#1 — In the Kotlin app: The habit '
    'list RecyclerView is constructed with a style whose only job is to turn '
    'on `android:scrollbars="vertical"`, so scrolling a long habit list shows '
    'the platform fading scrollbar thumb on the right edge — the app\'s one '
    'deliberate scrollbar (no other scrolling view declares one).';

const String rule2 =
    'audit.the-habit-list-has-no-vertical#2 — The port must do the same. Today '
    'it does this instead: Nothing — the string "Scrollbar" appears nowhere in '
    'app/lib or packages/uhabits_core/lib. The list in '
    'app/lib/ui/habits/list/habit_list_screen.dart is a plain scrollable, and '
    'Flutter\'s default ScrollBehavior draws no scrollbar on Android/iOS, so a '
    'user with many habits gets no position indicator.';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_list_scrollbar');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope({PreferencesStorage? preferencesStorage}) {
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
      preferencesStorage: preferencesStorage,
    );
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  void addHabit(AppScope scope, String name) {
    final habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    habit.recompute();
  }

  Future<void> pumpScreen(WidgetTester tester, AppScope scope) async {
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

  HabitListModel modelOf(WidgetTester tester) => Provider.of<HabitListModel>(
        tester.element(find.byType(Scaffold)),
        listen: false,
      );

  /// The one [Scrollbar] wrapping the habit card list.
  Finder scrollbarOverList() => find.ancestor(
        of: find.byKey(HabitListScreen.habitCardListKey),
        matching: find.byType(Scrollbar),
      );

  group('audit.the-habit-list-has-no-vertical', () {
    testWidgets('#1 #2 the habit card list is wrapped in a Scrollbar',
        (tester) async {
      final scope = openScope();
      for (int i = 0; i < 20; i++) {
        addHabit(scope, 'Habit $i');
      }
      await pumpScreen(tester, scope);

      expect(scrollbarOverList(), findsOneWidget, reason: '$rule1 $rule2');

      // The platform fading thumb, not a permanently pinned one: upstream's
      // `android:scrollbars="vertical"` is the default fading RecyclerView
      // scrollbar, which appears while the list moves and fades out after.
      final Scrollbar bar = tester.widget<Scrollbar>(scrollbarOverList());
      expect(bar.thumbVisibility, isNot(isTrue), reason: rule1);
    });

    testWidgets('#1 #2 the scrollbar and the list share one controller, so the '
        'thumb tracks the list', (tester) async {
      final scope = openScope();
      for (int i = 0; i < 20; i++) {
        addHabit(scope, 'Habit $i');
      }
      await pumpScreen(tester, scope);

      final ScrollController? controller =
          tester.widget<Scrollbar>(scrollbarOverList()).controller;
      expect(controller, isNotNull,
          reason: '$rule2 A Scrollbar with no controller cannot be dragged: '
              'the thumb has no position to write to.');
      expect(controller!.hasClients, isTrue,
          reason: '$rule2 The controller has to be the list\'s own, or the '
              'thumb tracks nothing.');

      // Scrolling the list moves the very position the scrollbar reads.
      final double before = controller.offset;
      await tester.drag(
        find.byKey(HabitListScreen.habitCardListKey),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(before), reason: rule1);
    });

    testWidgets('#1 #2 the scrollbar survives the sorted (non-reorderable) '
        'list too', (tester) async {
      final scope = openScope();
      for (int i = 0; i < 20; i++) {
        addHabit(scope, 'Habit $i');
      }
      await pumpScreen(tester, scope);

      // BY_POSITION is the default primary order, so the list starts as a
      // ReorderableListView; any other order swaps in a plain ListView.
      expect(find.byType(ReorderableListView), findsOneWidget, reason: rule2);
      expect(scrollbarOverList(), findsOneWidget, reason: rule2);

      modelOf(tester).menu.onSortByName();
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing, reason: rule2);
      expect(scrollbarOverList(), findsOneWidget,
          reason: '$rule1 $rule2 The style is on the list view itself, so it '
              'applies whichever adapter order is in force.');
      expect(tester.widget<Scrollbar>(scrollbarOverList()).controller?.hasClients,
          isTrue, reason: rule2);
    });

    testWidgets('#1 it is the only one: the header scroller gets no scrollbar',
        (tester) async {
      final scope = openScope();
      for (int i = 0; i < 20; i++) {
        addHabit(scope, 'Habit $i');
      }
      await pumpScreen(tester, scope);

      expect(find.byType(Scrollbar), findsOneWidget,
          reason: '$rule1 "the app\'s one deliberate scrollbar (no other '
              'scrolling view declares one)".');
      expect(
        find.descendant(
          of: find.byType(ListHeader),
          matching: find.byType(Scrollbar),
        ),
        findsNothing,
        reason: '$rule1 The header is the other scroller on this screen and it '
            'declares none.',
      );
    });
  });
}
