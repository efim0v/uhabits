// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/edit/edit_habit_screen.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
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
      expect(find.text('Habits'), findsOneWidget);
    });

    testWidgets('shows the empty state when there are no habits',
        (tester) async {
      await tester.pumpWidget(wrap(openScope()));
      await tester.pumpAndSettle();
      expect(find.text('You have no active habits'), findsOneWidget);
      expect(find.text(FontAwesome.starHalfO), findsOneWidget);
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

      expect(find.text("You're all done for today!"), findsOneWidget);
      expect(find.text(FontAwesome.umbrellaBeach), findsOneWidget);
      expect(find.text('Meditate'), findsNothing);
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
      expect(modelOf(tester).buttonCount, 11);
    });
  });
}
