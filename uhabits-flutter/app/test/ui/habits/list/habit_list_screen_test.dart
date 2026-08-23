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

      // EmptyListView is a centred column: the 40sp glyph over the message,
      // both in ?attr/contrast60.
      final dim = _toFlutterColor(LightTheme().mediumContrastTextColor);
      final icon = tester.widget<Text>(find.text(FontAwesome.starHalfO));
      final message = tester.widget<Text>(find.text('You have no active habits'));
      expect(icon.style?.fontSize, 40.0,
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

      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
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
      await tester.drag(find.byType(ListView), const Offset(0, -600));
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
}

/// Same rounding as `FlutterCanvas.setColor` and `core.Color.toInt`.
ui.Color _toFlutterColor(gui.Color color) => ui.Color.fromARGB(
      (color.alpha * 255).round().clamp(0, 255),
      (color.red * 255).round().clamp(0, 255),
      (color.green * 255).round().clamp(0, 255),
      (color.blue * 255).round().clamp(0, 255),
    );
