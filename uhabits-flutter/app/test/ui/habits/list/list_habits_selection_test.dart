/// Widget tests for the contextual action bar and for drag-and-drop
/// reordering.
///
/// Port target:
/// uhabits-android/.../habits/list/ListHabitsSelectionMenu.kt with
/// `res/menu/list_habits_selection.xml`, and the `ItemTouchHelper` half of
/// uhabits-android/.../habits/list/views/HabitCardListView.kt. Both presenters
/// behind them — `ListHabitsSelectionMenuBehavior` and
/// `HabitCardListController` — are already ported and tested in core, so what
/// is asserted here is the menu resource, the visibility rules, the developer
/// "notify" item and the drag plumbing.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/l10n/app_localizations_en.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
import 'package:uhabits/ui/common/dialogs/confirm_delete_dialog.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_command_toasts.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/list/list_habits_selection_menu.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/edit_habit_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_list_selection');
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
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(
    AppScope scope,
    String name, {
    bool isArchived = false,
    bool withReminder = false,
  }) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..isArchived = isArchived;
    if (withReminder) habit.reminder = Reminder(8, 0, WeekdayList.everyDay);
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
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

  ListHabitsSelectionMenu barOf(WidgetTester tester) =>
      tester.widget<ListHabitsSelectionMenu>(
        find.byType(ListHabitsSelectionMenu),
      );

  Finder itemFinder(String id) =>
      find.byKey(ListHabitsSelectionMenuItems.keyOf(id));

  /// Long-presses a row and lets the contextual bar appear.
  Future<void> selectRow(WidgetTester tester, String name) async {
    await tester.longPress(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> openOverflow(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('listHabitsSelection.overflowMenu')),
    );
    await tester.pumpAndSettle();
  }

  group('list-habits.selection-menu-actions', () {
    testWidgets('#1 the six items, in the order the menu resource declares '
        'them', (tester) async {
      // Developer mode on, so the notify item is offered too.
      final storage = MemoryStorage()..putBoolean('pref_developer', true);
      final scope = openScope(preferencesStorage: storage);
      addHabit(scope, 'Meditate');
      await pumpScreen(tester, scope);

      expect(find.byType(ListHabitsSelectionMenu), findsNothing,
          reason: 'list-habits.selection-menu-actions#1 — no selection, no '
              'contextual bar');
      expect(find.byType(ListHabitsMenu), findsOneWidget,
          reason: 'list-habits.selection-menu-actions#1');

      await selectRow(tester, 'Meditate');

      expect(find.byType(ListHabitsSelectionMenu), findsOneWidget,
          reason: 'list-habits.selection-menu-actions#1');
      expect(find.byType(ListHabitsMenu), findsNothing,
          reason: 'list-habits.selection-menu-actions#1 — the action mode '
              'replaces the toolbar');
      expect(ListHabitsSelectionMenuItems.all, <String>[
        'action_edit_habit',
        'action_color',
        'action_archive_habit',
        'action_unarchive_habit',
        'action_delete',
        'action_notify',
      ], reason: 'list-habits.selection-menu-actions#1');

      // The two items with an icon sit on the bar, Edit before Change color.
      expect(itemFinder(ListHabitsSelectionMenuItems.edit), findsOneWidget,
          reason: 'list-habits.selection-menu-actions#1');
      expect(itemFinder(ListHabitsSelectionMenuItems.color), findsOneWidget,
          reason: 'list-habits.selection-menu-actions#1');
      expect(
        tester.getRect(itemFinder(ListHabitsSelectionMenuItems.edit)).left,
        lessThan(
          tester.getRect(itemFinder(ListHabitsSelectionMenuItems.color)).left,
        ),
        reason: 'list-habits.selection-menu-actions#1',
      );

      // …and the `showAsAction="never"` ones follow, in declaration order.
      // Archive and Unarchive are mutually exclusive for a non-empty
      // selection, so only one of the two is ever on screen at a time
      // (`list-habits.selection-menu-actions#2`).
      await openOverflow(tester);
      expect(barOf(tester).isVisible(ListHabitsSelectionMenuItems.archive),
          isTrue,
          reason: 'list-habits.selection-menu-actions#1 — nothing selected is '
              'archived');
      expect(barOf(tester).isVisible(ListHabitsSelectionMenuItems.unarchive),
          isFalse,
          reason: 'list-habits.selection-menu-actions#1');
      var previousTop = double.negativeInfinity;
      for (final id in <String>[
        ListHabitsSelectionMenuItems.archive,
        ListHabitsSelectionMenuItems.unarchive,
        ListHabitsSelectionMenuItems.delete,
        ListHabitsSelectionMenuItems.notify,
      ]) {
        if (!barOf(tester).isVisible(id)) {
          expect(itemFinder(id), findsNothing,
              reason: 'list-habits.selection-menu-actions#1 — $id');
          continue;
        }
        expect(itemFinder(id), findsOneWidget,
            reason: 'list-habits.selection-menu-actions#1 — $id');
        final top = tester.getRect(itemFinder(id)).top;
        expect(top, greaterThan(previousTop),
            reason: 'list-habits.selection-menu-actions#1 — $id is out of '
                'order');
        previousTop = top;
      }
      final l10n = L10n.of(tester.element(find.byType(Scaffold)));
      expect(barOf(tester).titleOf(ListHabitsSelectionMenuItems.edit, l10n),
          'Edit', reason: 'list-habits.selection-menu-actions#1');
      expect(barOf(tester).titleOf(ListHabitsSelectionMenuItems.color, l10n),
          'Change color', reason: 'list-habits.selection-menu-actions#1');
      expect(barOf(tester).titleOf(ListHabitsSelectionMenuItems.notify, l10n),
          'Reminder', reason: 'list-habits.selection-menu-actions#1');
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
    });

    testWidgets('#9 notify shows today\'s notification for every selected '
        'habit and keeps the selection', (tester) async {
      final storage = MemoryStorage()..putBoolean('pref_developer', true);
      final scope = openScope(preferencesStorage: storage);
      // The tray drops a habit with no reminder, so both carry one.
      addHabit(scope, 'Meditate', withReminder: true);
      addHabit(scope, 'Run', withReminder: true);
      await pumpScreen(tester, scope);

      final tray = _RecordingSystemTray();
      final model = modelOf(tester)
        ..notificationTray = NotificationTray(
          scope.taskRunner,
          scope.commandRunner,
          scope.preferences,
          tray,
        );

      await selectRow(tester, 'Meditate');
      await tester.longPress(find.text('Run'));
      await tester.pumpAndSettle();
      expect(model.selected, hasLength(2),
          reason: 'list-habits.selection-menu-actions#9');

      await openOverflow(tester);
      await tester.tap(itemFinder(ListHabitsSelectionMenuItems.notify));
      await tester.pumpAndSettle();
      await scope.taskRunner.awaitAll();
      await tester.pumpAndSettle();

      expect(tray.shown.map((n) => n.habit.name).toSet(),
          <String>{'Meditate', 'Run'},
          reason: 'list-habits.selection-menu-actions#9 and '
              'notifications.dev-test-action#2 — tapping it calls '
              'notificationTray.show(h, getToday(), 0) for every selected '
              'habit');
      for (final shown in tray.shown) {
        expect(shown.date, getToday(),
            reason: 'list-habits.selection-menu-actions#9 and '
                'notifications.dev-test-action#2 — date = today');
        expect(shown.reminderTime, 0,
            reason: 'list-habits.selection-menu-actions#9 and '
                'notifications.dev-test-action#2 — reminderTime = 0');
      }
      // …and unlike every other item, the selection is left alone.
      expect(model.selected, hasLength(2),
          reason: 'list-habits.selection-menu-actions#9');
      expect(find.byType(ListHabitsSelectionMenu), findsOneWidget,
          reason: 'list-habits.selection-menu-actions#9');
    });

    testWidgets('#9 the notify item is hidden unless pref_developer is set',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpScreen(tester, scope);
      await selectRow(tester, 'Meditate');

      expect(modelOf(tester).scope.preferences.isDeveloper, isFalse,
          reason: 'list-habits.selection-menu-actions#9 and '
              'notifications.dev-test-action#1 — the visibility of '
              'action_notify equals preferences.isDeveloper (key '
              '"pref_developer", default false)');
      expect(barOf(tester).isVisible(ListHabitsSelectionMenuItems.notify),
          isFalse,
          reason: 'list-habits.selection-menu-actions#9 and '
              'notifications.dev-test-action#1');
      await openOverflow(tester);
      expect(itemFinder(ListHabitsSelectionMenuItems.notify), findsNothing,
          reason: 'list-habits.selection-menu-actions#9 and '
              'notifications.dev-test-action#4 — the same gating hides the '
              'item completely for non-developer users');
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
    });

    testWidgets('#4 delete asks about exactly the habits that are selected',
        (tester) async {
      // `confirm-delete.dialog#8`, the other call site: the list passes the
      // size of the selection, so the same dialog addresses one habit or many.
      final scope = openScope();
      addHabit(scope, 'Meditate');
      addHabit(scope, 'Run');
      await pumpScreen(tester, scope);

      await selectRow(tester, 'Meditate');
      await openOverflow(tester);
      await tester.tap(itemFinder(ListHabitsSelectionMenuItems.delete));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ConfirmDeleteDialog>(find.byType(ConfirmDeleteDialog))
            .quantity,
        1,
        reason: 'confirm-delete.dialog#8 — the habit-list selection menu '
            'passes the number of selected habits',
      );
      expect(find.text('Delete habit?'), findsOneWidget,
          reason: 'confirm-delete.dialog#8');
      await tester.tap(find.byKey(const ValueKey<String>('confirm_delete_no')));
      await tester.pumpAndSettle();

      // …and with both rows selected it is the plural, from the same argument.
      await selectRow(tester, 'Run');
      expect(modelOf(tester).selected, hasLength(2),
          reason: 'confirm-delete.dialog#8');
      await openOverflow(tester);
      await tester.tap(itemFinder(ListHabitsSelectionMenuItems.delete));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ConfirmDeleteDialog>(find.byType(ConfirmDeleteDialog))
            .quantity,
        2,
        reason: 'confirm-delete.dialog#8 — the number of selected habits, not '
            'a constant',
      );
      expect(find.text('Delete habits?'), findsOneWidget,
          reason: 'confirm-delete.dialog#8');
      await tester.tap(find.byKey(const ValueKey<String>('confirm_delete_no')));
      await tester.pumpAndSettle();
      expect(scope.habitList.size(), 2,
          reason: 'confirm-delete.dialog#8 — and "No" left both alone');
    });

    testWidgets('#9 turning developer mode on brings the notify item back',
        (tester) async {
      // The other half of `notifications.dev-test-action#1` and `#4`: the item
      // is not merely absent by default, its presence *is* the preference.
      final storage = MemoryStorage()..putBoolean('pref_developer', true);
      final scope = openScope(preferencesStorage: storage);
      addHabit(scope, 'Meditate');
      await pumpScreen(tester, scope);
      await selectRow(tester, 'Meditate');

      expect(modelOf(tester).scope.preferences.isDeveloper, isTrue,
          reason: 'notifications.dev-test-action#1 — the menu item '
              'R.id.action_notify has visibility == preferences.isDeveloper');
      expect(barOf(tester).isVisible(ListHabitsSelectionMenuItems.notify),
          isTrue,
          reason: 'notifications.dev-test-action#1');
      await openOverflow(tester);
      expect(itemFinder(ListHabitsSelectionMenuItems.notify), findsOneWidget,
          reason: 'notifications.dev-test-action#4 — the gating is the only '
              'thing that hides it');
      await tester.tapAt(const Offset(400, 500));
      await tester.pumpAndSettle();
    });

    test('#10 the message each command produces', () {
      final l10n = L10nEn();
      final scope = openScope();
      final one = addHabit(scope, 'Meditate');
      final two = addHabit(scope, 'Run');
      final single = <Habit>[one];
      final pair = <Habit>[one, two];

      expect(
        getExecuteString(l10n, ArchiveHabitsCommand(scope.habitList, single)),
        'Habit archived',
        reason: 'list-habits.selection-menu-actions#10',
      );
      expect(
        getExecuteString(l10n, ArchiveHabitsCommand(scope.habitList, pair)),
        'Habits archived',
        reason: 'list-habits.selection-menu-actions#10 — the quantity is '
            'command.selected.size',
      );
      expect(
        getExecuteString(l10n, UnarchiveHabitsCommand(scope.habitList, single)),
        'Habit unarchived',
        reason: 'list-habits.selection-menu-actions#10',
      );
      expect(
        getExecuteString(l10n, UnarchiveHabitsCommand(scope.habitList, pair)),
        'Habits unarchived',
        reason: 'list-habits.selection-menu-actions#10',
      );
      expect(
        getExecuteString(l10n, DeleteHabitsCommand(scope.habitList, single)),
        'Habit deleted',
        reason: 'list-habits.selection-menu-actions#10',
      );
      expect(
        getExecuteString(l10n, DeleteHabitsCommand(scope.habitList, pair)),
        'Habits deleted',
        reason: 'list-habits.selection-menu-actions#10',
      );
      expect(
        getExecuteString(
          l10n,
          ChangeHabitColorCommand(
            scope.habitList,
            single,
            const PaletteColor(3),
          ),
        ),
        'Habit changed',
        reason: 'list-habits.selection-menu-actions#10',
      );
      expect(
        getExecuteString(
          l10n,
          ChangeHabitColorCommand(scope.habitList, pair, const PaletteColor(3)),
        ),
        'Habits changed',
        reason: 'list-habits.selection-menu-actions#10',
      );
      expect(
        getExecuteString(
          l10n,
          CreateHabitCommand(scope.modelFactory, scope.habitList, one),
        ),
        'Habit created',
        reason: 'list-habits.selection-menu-actions#10 — not a plural',
      );
      expect(
        getExecuteString(
          l10n,
          EditHabitCommand(scope.habitList, one.id!, two),
        ),
        'Habit changed',
        reason: 'list-habits.selection-menu-actions#10 — always quantity 1',
      );
      // Everything else is silent.
      expect(
        getExecuteString(
          l10n,
          CreateRepetitionCommand(
            scope.habitList,
            one,
            LocalDate.ymd(2020, 1, 15),
            Entry.yesManual,
            '',
          ),
        ),
        isNull,
        reason: 'list-habits.selection-menu-actions#10',
      );
    });

    testWidgets('#11 the message is a short snackbar, and is dropped when '
        'there is nowhere to show it', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await pumpScreen(tester, scope);

      scope.commandRunner.run(ArchiveHabitsCommand(scope.habitList, <Habit>[habit]));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget,
          reason: 'list-habits.selection-menu-actions#11');
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(milliseconds: 4000),
          reason: 'list-habits.selection-menu-actions#11 — '
              'Snackbar.LENGTH_SHORT');
      expect(snackBar.action, isNull,
          reason: 'list-habits.selection-menu-actions#11 — no action button');
      expect(find.text('Habit archived'), findsOneWidget,
          reason: 'list-habits.selection-menu-actions#11');
      await tester.pumpAndSettle();

      // `catch (e: IllegalArgumentException) { return }`: with no
      // ScaffoldMessenger to attach to, the message is silently dropped.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );
      showListHabitsMessage(
        tester.element(find.byType(SizedBox)),
        'Habit archived',
      );
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: 'list-habits.selection-menu-actions#11');
      expect(find.byType(SnackBar), findsNothing,
          reason: 'list-habits.selection-menu-actions#11');
    });
  });

  group('list-habits.drag-reorder', () {
    testWidgets('#1 #3 the touch helper is attached only while the adapter is '
        'sortable', (tester) async {
      final scope = openScope();
      addHabit(scope, 'A');
      addHabit(scope, 'B');
      await pumpScreen(tester, scope);

      // BY_POSITION is the default primary order.
      expect(modelOf(tester).isSortable, isTrue,
          reason: 'list-habits.drag-reorder#1');
      expect(find.byType(ReorderableListView), findsOneWidget,
          reason: 'list-habits.drag-reorder#1');
      // `isLongPressDragEnabled() == false`: the helper never starts a drag by
      // itself, so there are no built-in handles.
      expect(
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .buildDefaultDragHandles,
        isFalse,
        reason: 'list-habits.drag-reorder#3',
      );
      // `getMovementFlags` allows UP or DOWN only.
      expect(
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .scrollDirection,
        Axis.vertical,
        reason: 'list-habits.drag-reorder#3',
      );

      // Any other primary order takes the helper away again.
      modelOf(tester).menu.onSortByName();
      await tester.pumpAndSettle();
      expect(modelOf(tester).isSortable, isFalse,
          reason: 'list-habits.drag-reorder#1');
      expect(find.byType(ReorderableListView), findsNothing,
          reason: 'list-habits.drag-reorder#1 — a sorted list cannot be '
              'dragged');
      expect(find.byKey(HabitListScreen.habitCardListKey), findsOneWidget,
          reason: 'list-habits.drag-reorder#1');
    });

    testWidgets('#2 a long press selects the row and starts the drag',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'A');
      addHabit(scope, 'B');
      await pumpScreen(tester, scope);

      // `NormalMode.startDrag` runs `startSelection`, which is the very same
      // path `onItemLongClick` takes — so one long press does both.
      final gesture = await tester.startGesture(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(modelOf(tester).selected.map((h) => h.name), <String>['A'],
          reason: 'list-habits.drag-reorder#2');
      expect(find.byType(ListHabitsSelectionMenu), findsOneWidget,
          reason: 'list-habits.drag-reorder#2 — and the contextual bar is up');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('#4 dropping a row reorders the habits and renumbers their '
        'positions', (tester) async {
      final scope = openScope();
      for (final name in <String>['A', 'B', 'C']) {
        addHabit(scope, name);
      }
      await pumpScreen(tester, scope);
      expect(
        <int>[0, 1, 2].map((i) => scope.habitList.getByPosition(i).name),
        <String>['A', 'B', 'C'],
        reason: 'list-habits.drag-reorder#4',
      );

      final rowHeight = tester.getSize(find.byType(HabitCard).first).height;
      final gesture = await tester.startGesture(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(Offset(0, rowHeight / 2));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // `onMove` -> `controller.drop(from, to)` -> `habitList.reorder`, which
      // renumbers every position from 0.
      expect(
        <int>[0, 1, 2].map((i) => scope.habitList.getByPosition(i).name),
        <String>['B', 'C', 'A'],
        reason: 'list-habits.drag-reorder#4',
      );
      for (var i = 0; i < 3; i++) {
        expect(scope.habitList.getByPosition(i).position, i,
            reason: 'list-habits.drag-reorder#6');
      }
    });

    testWidgets('#9 a horizontal swipe on a row does nothing at all',
        (tester) async {
      final scope = openScope();
      for (final name in <String>['A', 'B', 'C']) {
        addHabit(scope, name);
      }
      await pumpScreen(tester, scope);

      // `isItemViewSwipeEnabled() == false`, and `onSwiped` is empty anyway.
      await tester.fling(find.text('A'), const Offset(400, 0), 2000);
      await tester.pumpAndSettle();
      await tester.fling(find.text('A'), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.text('A'), findsOneWidget,
          reason: 'list-habits.drag-reorder#9');
      expect(scope.habitList.size(), 3, reason: 'list-habits.drag-reorder#9');
      expect(
        <int>[0, 1, 2].map((i) => scope.habitList.getByPosition(i).name),
        <String>['A', 'B', 'C'],
        reason: 'list-habits.drag-reorder#9 — no removal and no reorder',
      );
      expect(modelOf(tester).selected, isEmpty,
          reason: 'list-habits.drag-reorder#9');
    });
  });
}

/// A [SystemTray] that records what it was asked to post.
class _RecordingSystemTray implements SystemTray {
  final List<({Habit habit, LocalDate date, int reminderTime})> shown =
      <({Habit habit, LocalDate date, int reminderTime})>[];

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {
    shown.add((habit: habit, date: date, reminderTime: reminderTime));
  }

  @override
  void log(String msg) {}
}
