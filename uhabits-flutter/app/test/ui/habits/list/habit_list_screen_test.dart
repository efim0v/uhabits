// ignore_for_file: implementation_imports

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_card.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_menu.dart';
import 'package:uhabits/ui/habits/list/list_habits_root_view.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/gui/color.dart' as gui;
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];
  final databases = <Database>[];

  setUp(() {
    // Nothing may read the model before startup has stamped today; clearing it
    // here is what makes that assertion real for every test below.
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_habit_list_screen');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    for (final database in databases) {
      database.close();
    }
    databases.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope({PreferencesStorage? preferencesStorage, String name = 'habits.db'}) {
    final database = AppDatabase.openAndMigrate('${tempDir.path}/$name');
    final scope = AppScope.open(
      database,
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

  /// A second connection to the same file, with no scope around it: enough to
  /// prove that a write reached the disk, and free of the task runner whose
  /// pending refreshes a widget test would trip over.
  HabitList reopen([String name = 'habits.db']) {
    final database = AppDatabase.openAndMigrate('${tempDir.path}/$name');
    databases.add(database);
    return SQLModelFactory(database).buildHabitList();
  }

  Habit addHabit(
    AppScope scope,
    String name, {
    PaletteColor color = const PaletteColor(8),
  }) {
    final habit = scope.modelFactory.buildHabit()
      ..name = name
      ..color = color;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Widget wrap(AppScope scope) {
    return MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Provider<AppScope>.value(
        value: scope,
        child: const HabitListScreen(),
      ),
    );
  }

  /// Pumps the screen on a surface exactly [width] logical pixels wide, which
  /// is what `ListHabitsRootView.onSizeChanged` reacts to.
  Future<void> pumpAtWidth(
    WidgetTester tester,
    AppScope scope,
    double width,
  ) async {
    await tester.binding.setSurfaceSize(Size(width, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(scope));
    await tester.pumpAndSettle();
  }

  HabitListModel modelOf(WidgetTester tester) =>
      Provider.of<HabitListModel>(tester.element(find.byType(Scaffold)), listen: false);

  group('startup', () {
    test('stamps today before anything reads the model', () {
      expect(getToday, throwsStateError);
      final scope = openScope();
      expect(getToday(), computeToday(scope.preferences.midnightDelayHours, 0));
    });

    test('exposes an sqlite-backed habit list and a command runner', () {
      final scope = openScope();
      expect(scope.habitList.isEmpty, isTrue);
      addHabit(scope, 'Meditate');
      expect(scope.habitList.size(), 1);
      // The habit really landed in the database, not only in memory.
      expect(reopen().getByPosition(0).name, 'Meditate');
    });
  });

  group('habit list screen', () {
    testWidgets('shows the toolbar title', (tester) async {
      await tester.pumpWidget(wrap(openScope()));
      await tester.pumpAndSettle();
      expect(find.text('Habits'), findsOneWidget,
          reason: 'list-habits.screen-layout#2');

      // `rootView.setupToolbar(color = PaletteColor(17))`, elevation dp(2).
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.elevation, 2.0, reason: 'list-habits.screen-layout#2');
      expect(
        bar.backgroundColor,
        _toFlutterColor(LightTheme().colorOf(const PaletteColor(17))),
        reason: 'list-habits.screen-layout#2',
      );
      // Home-as-up is off: the list screen is the root of the stack.
      expect(bar.automaticallyImplyLeading && Navigator.of(
        tester.element(find.byType(AppBar)),
      ).canPop(), isFalse, reason: 'list-habits.screen-layout#2');
    });

    testWidgets('shows the empty state when there are no habits',
        (tester) async {
      await tester.pumpWidget(wrap(openScope()));
      await tester.pumpAndSettle();
      expect(find.text('You have no active habits'), findsOneWidget,
          reason: 'list-habits.empty-state#2');
      expect(find.text(FontAwesome.starHalfO), findsOneWidget,
          reason: 'list-habits.empty-state#2');

      // EmptyListView is a centred column: the glyph over the message, both in
      // ?attr/contrast60.
      final dim = _toFlutterColor(LightTheme().mediumContrastTextColor);
      final icon = tester.widget<Text>(find.text(FontAwesome.starHalfO));
      final message = tester.widget<Text>(find.text('You have no active habits'));
      // `textSize = sp(40f)`, where `sp()` already returns pixels and the
      // one-argument `TextView.textSize` setter converts a second time: the
      // glyph the Android user sees is twice the 40 it is declared at
      // (`audit4.empty-list-star-beach-icon-is#1`).
      expect(icon.style?.fontSize, 80.0,
          reason: 'list-habits.empty-state#5');
      expect(icon.style?.color, dim, reason: 'list-habits.empty-state#5');
      expect(message.style?.color, dim, reason: 'list-habits.empty-state#5');
      // 20dp of padding between them (`setPadding(0, dp(20f), 0, 0)`).
      final iconRect = tester.getRect(find.text(FontAwesome.starHalfO));
      final messageRect =
          tester.getRect(find.text('You have no active habits'));
      expect(messageRect.top - iconRect.bottom, 20.0,
          reason: 'list-habits.empty-state#5');
    });

    testWidgets('shows the done state when the filter hides every habit',
        (tester) async {
      final storage = MemoryStorage()..putBoolean('pref_show_completed', false);
      final scope = openScope(preferencesStorage: storage);
      final habit = addHabit(scope, 'Meditate');
      habit.originalEntries.add(Entry(getToday(), Entry.yesManual));
      habit.recompute();
      // The three steps of CreateRepetitionCommand.run; the resort is what
      // makes the filtered list re-evaluate the matcher.
      scope.habitList.resort();

      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      expect(find.text("You're all done for today!"), findsOneWidget,
          reason: 'list-habits.empty-state#3');
      expect(find.text(FontAwesome.umbrellaBeach), findsOneWidget,
          reason: 'list-habits.empty-state#3');
      expect(find.text('Meditate'), findsNothing,
          reason: 'list-habits.empty-state#3');
      // The item count is 0 but the unfiltered list is not empty: it is the
      // difference between the two that picks the "done" branch.
      expect(modelOf(tester).itemCount, 0,
          reason: 'list-habits.empty-state#3');
      expect(modelOf(tester).hasNoHabit, isFalse,
          reason: 'list-habits.empty-state#3');
      expect(find.text('You have no active habits'), findsNothing,
          reason: 'list-habits.empty-state#3');
    });

    testWidgets('#4 #1 a habit hides the empty view, and removing it brings '
        'it back', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      expect(modelOf(tester).itemCount, 1,
          reason: 'list-habits.empty-state#4');
      expect(find.text('You have no active habits'), findsNothing,
          reason: 'list-habits.empty-state#4');
      expect(find.text("You're all done for today!"), findsNothing,
          reason: 'list-habits.empty-state#4');
      expect(find.text(FontAwesome.starHalfO), findsNothing,
          reason: 'list-habits.empty-state#4');

      // `updateEmptyView()` runs off the adapter's ModelObservable, so a
      // removal re-evaluates it without the screen being rebuilt by hand.
      scope.habitList.remove(habit);
      scope.adapter.refresh();
      await tester.pumpAndSettle();

      expect(find.text('You have no active habits'), findsOneWidget,
          reason: 'list-habits.empty-state#1');
    });

    testWidgets('renders one row per habit', (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      addHabit(scope, 'Wake up early', color: const PaletteColor(11));

      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      expect(find.text('Meditate'), findsOneWidget);
      expect(find.text('Wake up early'), findsOneWidget);
      expect(find.text('You have no active habits'), findsNothing);
    });

    testWidgets('picks up a habit added while the screen is attached',
        (tester) async {
      final scope = openScope();
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final template = scope.modelFactory.buildHabit()..name = 'Run';
      modelOf(tester).createHabit(template);
      await tester.pumpAndSettle();

      expect(scope.habitList.size(), 1);
      expect(find.text('Run'), findsOneWidget);
    });

    testWidgets('the floating action button creates a habit', (tester) async {
      final scope = openScope();
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      // Adding a habit is a toolbar item with showAsAction="always", as in
      // res/menu/list_habits.xml. The Android app has no floating action
      // button at all.
      final addHabit =
          find.byKey(ListHabitsMenuItems.keyOf(ListHabitsMenuItems.createHabit));
      expect(addHabit, findsOneWidget);
      await tester.tap(addHabit);
      await tester.pumpAndSettle();

      // The button opens the habit type chooser first, exactly as
      // ListHabitsScreen does before starting EditHabitActivity
      // (habit-type-dialog.select-type#1).
      await tester.tap(find.text('Yes or No'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Meditate');
      // The toolbar Save button is upper-cased, as in the Android layout.
      await tester.tap(find.byKey(EditHabitScreen.saveButtonKey));
      await tester.pumpAndSettle();

      expect(scope.habitList.size(), 1);
      expect(scope.habitList.getByPosition(0).name, 'Meditate');
      expect(find.text('Meditate'), findsOneWidget);
    });

    testWidgets('a toggle is dispatched as a CreateRepetitionCommand',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');

      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      modelOf(tester).onToggle(habit, today, Entry.yesManual, '');
      await tester.pumpAndSettle();

      expect(habit.originalEntries.get(today).value, Entry.yesManual);
      expect(habit.computedEntries.get(today).value, Entry.yesManual);

      // It went through the command runner, so it is on disk too.
      expect(
        reopen().getByPosition(0).originalEntries.get(today).value,
        Entry.yesManual,
      );
    });

    testWidgets('a long press on an entry button toggles it', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      // The default preferences leave isShortToggleEnabled false, so it is the
      // long press that toggles and the tap that opens the editor.
      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      expect(habit.computedEntries.get(today).value, Entry.yesManual);
    });

    testWidgets('tapping a row asks the presenter for the habit screen',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      Habit? shown;
      modelOf(tester).onShowHabitScreen = (habit) => shown = habit;
      await tester.tap(find.text('Meditate'));
      await tester.pumpAndSettle();

      expect(shown?.name, 'Meditate');
    });

    testWidgets('draws one header column per visible checkmark button',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      // 800 logical pixels wide in the test harness: the label takes
      // max(800 / 3, 160) = 266.67, leaving (800 - 266.67) / 48 = 11 buttons.
      expect(modelOf(tester).buttonCount, 11,
          reason: 'list-habits.screen-layout#3');
    });
  });

  // -------------------------------------------------------------------------
  // ListHabitsRootView.getCheckmarkCount / onSizeChanged
  // -------------------------------------------------------------------------
  group('visible column count', () {
    /// `labelWidth = max(width / 3, 160dp)`,
    /// `visibleCount = min(60, max(0, floor((width - labelWidth) / 48dp)))`.
    int expected(double width) {
      final labelWidth = width / 3 < 160 ? 160.0 : width / 3;
      final buttons = ((width - labelWidth) / 48).floor();
      return buttons < 0 ? 0 : (buttons > 60 ? 60 : buttons);
    }

    testWidgets('#3 #5 the column formula, at several widths', (tester) async {
      for (final width in <double>[100, 160, 240, 400, 800, 1600, 3000]) {
        final scope = openScope(name: 'habits_$width.db');
        addHabit(scope, 'Meditate');
        await pumpAtWidth(tester, scope, width);

        final header = tester.widget<ListHeader>(find.byType(ListHeader));
        expect(header.buttonCount, expected(width),
            reason: 'list-habits.screen-layout#3');
        // …and the rows get the very same count.
        expect(
          tester.widget<HabitCard>(find.byType(HabitCard)).buttonCount,
          header.buttonCount,
          reason: 'list-habits.screen-layout#4',
        );
        expect(header.effectiveMaxDataOffset, 60 - header.buttonCount,
            reason: 'list-habits.screen-layout#4');
      }
    });

    testWidgets('#3 the count is clamped to MAX_CHECKMARK_COUNT = 60',
        (tester) async {
      // 60 columns need 60 * 48 = 2880 px past the label, and the label is a
      // third of the width, so anything from 4320 px up saturates.
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpAtWidth(tester, scope, 5000);

      expect(ListHeader.maxCheckmarkCount, 60,
          reason: 'list-habits.screen-layout#3');
      expect(tester.widget<ListHeader>(find.byType(ListHeader)).buttonCount, 60,
          reason: 'list-habits.screen-layout#3');
      expect(
        tester.widget<ListHeader>(find.byType(ListHeader)).effectiveMaxDataOffset,
        0,
        reason: 'list-habits.screen-layout#4',
      );
    });

    testWidgets('#5 the label never drops below 160dp, and buttons are 48dp',
        (tester) async {
      // At 240 px a third would be 80, so the 160dp floor bites: 240 - 160 =
      // 80 px is one 48dp button and change.
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await pumpAtWidth(tester, scope, 240);

      expect(tester.widget<ListHeader>(find.byType(ListHeader)).buttonCount, 1,
          reason: 'list-habits.screen-layout#5');
      expect(ListHeader.columnWidth, 48.0,
          reason: 'list-habits.screen-layout#5');
      expect(
        tester.getSize(find.byKey(EntryPanel.buttonKey(getToday()))),
        const Size(48, 48),
        reason: 'list-habits.screen-layout#5',
      );
    });

    testWidgets('#9 a row built after a scroll gets the current dataOffset',
        (tester) async {
      final scope = openScope();
      for (var i = 0; i < 30; i++) {
        addHabit(scope, 'Habit $i');
      }
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      // Drag the header two columns into the past.
      final start = tester.getCenter(find.byType(ListHeader));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-120, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(EntryPanel.buttonKey(today)), findsNothing,
          reason: 'list-habits.header-scrolling#9');

      // Scroll the list so rows that were never built come on screen; they
      // must already be showing the scrolled dates, not today.
      await tester.drag(
          find.byKey(HabitListScreen.habitCardListKey), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.byKey(EntryPanel.buttonKey(today)), findsNothing,
          reason: 'list-habits.header-scrolling#9');
      for (final card in tester.widgetList<HabitCard>(find.byType(HabitCard))) {
        expect(card.dataOffset, 2,
            reason: 'list-habits.header-scrolling#9');
      }
    });

    testWidgets('#4 detaching cancels the refresh and stops following '
        'commands', (tester) async {
      // `ListHabitsActivity.onPause` also pauses the midnight timer and
      // dismisses the visible dialog; the model unregisters from the timer
      // instead of pausing it, and dialog dismissal is the route's business.
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      final before = List<int>.of(scope.cache.getCheckmarks(habit.id!));

      modelOf(tester).detach();
      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          today,
          Entry.yesManual,
          '',
        ),
      );
      await tester.pumpAndSettle();

      expect(scope.cache.getCheckmarks(habit.id!), before,
          reason: 'list-habits.startup-lifecycle#4: the cache is no longer a '
              'CommandRunner listener once the screen is detached');
      expect(scope.adapter.bindCardView(0), isNull,
          reason: 'list-habits.startup-lifecycle#4: and nothing binds a row '
              'any more');
    });

    testWidgets('#7 at midnight the list refreshes and the strip repaints',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      expect(find.byKey(EntryPanel.buttonKey(today)), findsOneWidget,
          reason: 'list-habits.startup-lifecycle#7');

      // `MidnightTimer._notifyListeners`: stamp the new today, then tell the
      // listeners. The adapter is one of them and refreshes the whole cache.
      setToday(today.plus(1));
      scope.adapter.atMidnight();
      await tester.pumpAndSettle();

      expect(find.byKey(EntryPanel.buttonKey(today.plus(1))), findsOneWidget,
          reason: 'list-habits.startup-lifecycle#7');
      expect(
        tester.widget<ListHeader>(find.byType(ListHeader)).today ?? getToday(),
        today.plus(1),
        reason: 'list-habits.startup-lifecycle#7 and '
            'list-habits.header-dates#13 — the midnight listener forces the '
            'strip to repaint',
      );
    });

    testWidgets('header-dates#13 the midnight listener is registered on '
        'attach and removed on detach', (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');

      // Android registers the listener from HeaderView.onAttachedToWindow and
      // drops it in onDetachedFromWindow. Here the strip is a pure function of
      // the `today` it is handed, so the subscription lives one level up, on
      // the adapter the screen attaches — but the observable contract is the
      // same: attached means subscribed, detached means not.
      expect(scope.midnightTimer.removeListener(scope.adapter), isFalse,
          reason: 'list-habits.header-dates#13 — nothing is registered before '
              'the screen is attached');

      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      expect(scope.midnightTimer.removeListener(scope.adapter), isTrue,
          reason: 'list-habits.header-dates#13 — registered on attach');
      // …put it back, so detach has something to remove.
      scope.midnightTimer.addListener(scope.adapter);

      modelOf(tester).detach();
      await tester.pumpAndSettle();

      expect(scope.midnightTimer.removeListener(scope.adapter), isFalse,
          reason: 'list-habits.header-dates#13 — and removed on detach');
    });
  });

  // -------------------------------------------------------------------------
  // ListHabitsScreen.showCheckmarkPopup / showNumberPopup
  // -------------------------------------------------------------------------
  group('entry edit popups', () {
    testWidgets('a tap on a yes/no cell opens the CheckmarkDialog',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: 'list-habits.entry-edit-popup-boolean#2');
      expect(find.byKey(const ValueKey<String>('checkmark_notes')),
          findsOneWidget,
          reason: 'list-habits.entry-edit-popup-boolean#2');

      await tester.tap(
        find.byKey(const ValueKey<String>('checkmark_yes_button')),
      );
      await tester.pumpAndSettle();

      // The dialog's value is dispatched through CreateRepetitionCommand.
      expect(habit.computedEntries.get(today).value, Entry.yesManual,
          reason: 'list-habits.entry-edit-popup-boolean#5');
    });

    testWidgets('the notes typed into the popup are saved with the entry',
        (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('checkmark_notes')),
        '  after breakfast  ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('checkmark_no_button')),
      );
      await tester.pumpAndSettle();

      expect(habit.computedEntries.get(today).value, Entry.no,
          reason: 'list-habits.entry-edit-popup-boolean#5');
      expect(habit.computedEntries.get(today).notes, 'after breakfast',
          reason: 'list-habits.entry-edit-popup-boolean#5');
    });

    testWidgets('a tap on a numerical cell opens the NumberDialog',
        (tester) async {
      final scope = openScope();
      final habit = scope.modelFactory.buildHabit()
        ..name = 'Read'
        ..type = HabitType.numerical
        ..unit = 'pages'
        ..targetValue = 100;
      scope.habitList.add(habit);
      habit.recompute();

      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      await tester.tap(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      expect(find.byType(NumberDialog), findsOneWidget,
          reason: 'list-habits.entry-edit-popup-numeric#2');
      // An unset entry opens on "0" (`number-dialog.popup#4`).
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('number_value')),
            )
            .controller!
            .text,
        '0',
        reason: 'list-habits.entry-edit-popup-numeric#2',
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '100',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // round(100.0 * 1000) — `list-habits.entry-edit-popup-numeric#3`.
      expect(habit.computedEntries.get(today).value, 100000,
          reason: 'list-habits.entry-edit-popup-numeric#7');
    });
  });

  // -------------------------------------------------------------------------
  // ListHabitsRootView: the stack, the window insets and the confetti origin
  // -------------------------------------------------------------------------
  group('root view', () {
    /// The screen under a window that reports [padding] as its system insets.
    Future<void> pumpWithPadding(
      WidgetTester tester,
      AppScope scope,
      EdgeInsets padding,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(padding: padding),
            child: Provider<AppScope>.value(
              value: scope,
              child: const HabitListScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('#1 the children are stacked in the order the root view adds '
        'them', (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final root = tester.getRect(find.byType(HabitListScreen));
      final bar = tester.getRect(find.byType(AppBar));
      final header = tester.getRect(find.byType(ListHeader));
      final list = tester.getRect(find.byKey(HabitListScreen.habitCardListKey));
      final progress = tester.getRect(find.byType(TaskProgressBar));
      final hint = tester.getRect(find.byType(HintView));
      final confetti = tester.getRect(find.byType(ConfettiOverlay));

      // `addAtTop(tbar)` then `addBelow(header, tbar)`.
      expect(header.top, bar.bottom, reason: 'list-habits.screen-layout#1');
      // `addBelow(listView, header, height = MATCH_PARENT)`.
      expect(list.top, header.bottom, reason: 'list-habits.screen-layout#1');
      expect(list.bottom, root.bottom, reason: 'list-habits.screen-layout#1');
      // The empty view is GONE while there are rows, so it takes no space.
      expect(tester.getSize(find.byType(EmptyListView)), Size.zero,
          reason: 'list-habits.screen-layout#1');
      // `addBelow(progressBar, header) { it.topMargin = dp(-6f) }`.
      expect(progress.top, header.bottom - 6,
          reason: 'list-habits.screen-layout#1');
      // `addAtBottom(hintView)`.
      expect(hint.bottom, root.bottom, reason: 'list-habits.screen-layout#1');
      // `addAtTop(konfettiView)` with translationZ 10: it covers the whole
      // root, toolbar included, and is painted last.
      expect(confetti, root, reason: 'list-habits.screen-layout#1');
    });

    testWidgets('#1 the empty view occupies the same area as the list',
        (tester) async {
      // `addBelow(llEmpty, header, height = MATCH_PARENT)`: once it is
      // VISIBLE it covers exactly the rectangle the RecyclerView covers.
      final scope = openScope(name: 'empty.db');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      expect(find.text('You have no active habits'), findsOneWidget,
          reason: 'list-habits.screen-layout#1');
      expect(tester.getRect(find.byType(EmptyListView)),
          tester.getRect(find.byKey(HabitListScreen.habitCardListKey)),
          reason: 'list-habits.screen-layout#1');
    });

    testWidgets('#7 left and right window insets become root padding over a '
        'black background', (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      const inset = EdgeInsets.only(left: 24, right: 12, top: 40, bottom: 16);
      await pumpWithPadding(tester, scope, inset);

      final screen = tester.getRect(find.byType(HabitListScreen));
      final scaffold = tester.getRect(find.byType(Scaffold).first);
      expect(scaffold.left - screen.left, 24.0,
          reason: 'list-habits.screen-layout#7');
      expect(screen.right - scaffold.right, 12.0,
          reason: 'list-habits.screen-layout#7');
      // No vertical padding on the root: the toolbar takes the top inset.
      expect(scaffold.top, screen.top,
          reason: 'list-habits.screen-layout#7');
      expect(scaffold.bottom, screen.bottom,
          reason: 'list-habits.screen-layout#7');

      // `view.background = ColorDrawable(Color.BLACK)`.
      final painted = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(HabitListScreen),
          matching: find.byType(ColoredBox),
        ).first,
      );
      expect(painted.color, const ui.Color(0xFF000000),
          reason: 'list-habits.screen-layout#7');

      // `applyToolbarInsets`: the toolbar grows by the top inset instead of
      // being pushed down.
      final bar = tester.getRect(find.byType(AppBar));
      expect(bar.top, screen.top, reason: 'list-habits.screen-layout#7');
      expect(bar.height, kToolbarHeight + 40,
          reason: 'list-habits.screen-layout#7');
    });

    testWidgets('#8 the bottom systemBars inset is added to the last card, '
        'once', (tester) async {
      final scope = openScope();
      for (var i = 0; i < 3; i++) {
        addHabit(scope, 'Habit $i');
      }
      await pumpWithPadding(
        tester,
        scope,
        const EdgeInsets.only(bottom: 32),
      );

      // The default primary order is BY_POSITION, so the list is the sortable
      // one (`list-habits.drag-reorder#1`).
      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      final padding = list.padding!;
      // Exactly the inset and nothing else: the 88 that used to be added on
      // top of it was clearance for a floating action button neither app has
      // (`audit4.habit-list-keeps-88dp-of-dead#1`).
      expect(padding.bottom, 32.0,
          reason: 'list-habits.screen-layout#8');
      expect(padding.top, 0.0, reason: 'list-habits.screen-layout#8');

      // …and exactly once: `insetDecorationsAdded` guards the second call.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpWithPadding(
        tester,
        scope,
        const EdgeInsets.only(bottom: 32),
      );
      expect(
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .padding!
            .bottom,
        32.0,
        reason: 'list-habits.screen-layout#8',
      );
    });

    testWidgets('#5 the burst starts at the centre of the tapped button, less '
        'the left window inset', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      const inset = EdgeInsets.only(left: 24);
      await pumpWithPadding(tester, scope, inset);

      final today = getToday();
      final button = tester.getRect(find.byKey(EntryPanel.buttonKey(today)));
      // isShortToggleEnabled is false, so the long press is the toggle, and
      // UNKNOWN -> YES_MANUAL is the value that fires confetti.
      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pump();

      expect(habit.computedEntries.get(today).value, Entry.yesManual,
          reason: 'list-habits.confetti#5');
      final overlay =
          tester.state<ConfettiOverlayState>(find.byType(ConfettiOverlay));
      expect(overlay.parties, hasLength(1),
          reason: 'list-habits.confetti#5');
      final origin = overlay.parties.single.position;
      // The window position of the button centre…
      expect(origin.dx, closeTo(button.center.dx - 24, 0.001),
          reason: 'list-habits.confetti#5 — less the display-cutout left safe '
              'inset, which the root already carried away as padding');
      expect(origin.dy, closeTo(button.center.dy, 0.001),
          reason: 'list-habits.confetti#5');
      await tester.pumpAndSettle();
    });

    testWidgets('#1 a toggle to NO fires no burst at all', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      habit.originalEntries.add(Entry(getToday(), Entry.yesManual));
      habit.recompute();
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      await tester.longPress(find.byKey(EntryPanel.buttonKey(today)));
      await tester.pumpAndSettle();

      expect(habit.computedEntries.get(today).value, Entry.no,
          reason: 'list-habits.toggle-from-row#1');
      expect(
        tester
            .state<ConfettiOverlayState>(find.byType(ConfettiOverlay))
            .parties,
        isEmpty,
        reason: 'list-habits.toggle-from-row#1 — showConfetti only runs for '
            'YES_MANUAL',
      );
    });

    testWidgets('header-scrolling#8 the scroll state survives a restart',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await tester.pumpWidget(
        MaterialApp(
          restorationScopeId: 'app',
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Provider<AppScope>.value(
            value: scope,
            child: const HabitListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final today = getToday();
      // Three columns into the past.
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(ListHeader)));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-144, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.widget<HabitCard>(find.byType(HabitCard)).dataOffset, 3,
          reason: 'list-habits.header-scrolling#8');
      expect(find.byKey(EntryPanel.buttonKey(today)), findsNothing,
          reason: 'list-habits.header-scrolling#8');

      // `onSaveInstanceState` writes the header's scroller state and the card
      // list's dataOffset into the saved instance state; the restore puts both
      // back.
      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      expect(tester.widget<ListHeader>(find.byType(ListHeader)).dataOffset, 3,
          reason: 'list-habits.header-scrolling#8 — the header came back on '
              'the column it was left on');
      expect(tester.widget<HabitCard>(find.byType(HabitCard)).dataOffset, 3,
          reason: 'list-habits.header-scrolling#8 — and so did the list');
      expect(find.byKey(EntryPanel.buttonKey(today)), findsNothing,
          reason: 'list-habits.header-scrolling#8');
      expect(find.byKey(EntryPanel.buttonKey(today.minus(3))), findsOneWidget,
          reason: 'list-habits.header-scrolling#8');
    });

  });
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
ui.Color _toFlutterColor(gui.Color color) => ui.Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
