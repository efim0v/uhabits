/// `ListHabitsScreen` as a `CommandRunner.Listener`: one toast per finished
/// command, and nothing at all for the commands the mapping does not name.
///
/// Ported from
/// uhabits-android/.../activities/habits/list/ListHabitsScreen.kt
/// (`onAttached`, `onDetached`, `onCommandFinished`, `getExecuteString`) and
/// from `ViewExtensions.showMessage`, which is a `Snackbar.LENGTH_SHORT` with
/// no action button.
///
/// Rules: `commands.listener-list-habits-toasts`, plus the three per-command
/// rules that say the same thing from the command's side
/// (`commands.archive-habits#9`, `commands.unarchive-habits#7`,
/// `commands.change-habit-color#8`), the delete-confirmation copy of
/// `commands.no-undo-redo#3`, and the editor's create/edit branch,
/// `commands.edit-habit#10`.
library;

// The commands and the preferences are reached by their `src` path, exactly as
// lib/state/app_scope.dart reaches them.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits/ui/common/dialogs/confirm_delete_dialog.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_command_toasts.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/change_habit_color_command.dart';
import 'package:uhabits_core/src/commands/command.dart';
import 'package:uhabits_core/src/commands/command_runner.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/edit_habit_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  late Directory tempDir;
  late L10n l10n;
  final scopes = <AppScope>[];
  var nextDatabase = 0;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l10n = await L10n.delegate.load(const Locale('en'));
  });

  setUp(() {
    core.resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_command_toasts');
    nextDatabase = 0;
  });

  tearDown(() {
    for (final scope in scopes) {
      try {
        scope.close();
      } on Object {
        // Already closed.
      }
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
    core.resetToday();
  });

  AppScope openScope({Dispatcher dispatcher = const AsyncDispatcher()}) {
    final path = '${tempDir.path}/habits${nextDatabase++}.db';
    final scope = AppScope.open(
      AppDatabase.openAndMigrate(path),
      databasePath: path,
      mainDispatcher: dispatcher,
      ioDispatcher: dispatcher,
    );
    // `BaseUserInterfaceTest.setUp`: `prefs.isFirstRun = false`. A scope over an
    // empty preference store IS a first run, and a first run now opens the intro
    // on top of the habit list (`verify.intro-never-shown`) — which is
    // test/ui/intro/intro_wiring_test.dart's subject, not this file's.
    scope.preferences.isFirstRun = false;
    scopes.add(scope);
    return scope;
  }

  core.Habit addHabit(AppScope scope, String name) {
    final habit = scope.modelFactory.buildHabit()..name = name;
    scope.habitList.add(habit);
    habit.recompute();
    return habit;
  }

  Widget wrap(AppScope scope) => MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Provider<AppScope>.value(
          value: scope,
          child: const HabitListScreen(),
        ),
      );

  /// Lets a shown snackbar time out, so no pending timer outlives the test.
  Future<void> dismissSnackBars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  // =======================================================================
  // commands.listener-list-habits-toasts — the mapping itself
  // =======================================================================

  group('commands.listener-list-habits-toasts', () {
    test('#3 every named command maps to its string, with the documented '
        'quantity', () {
      final list = core.MemoryModelFactory().buildHabitList();
      final factory = core.MemoryModelFactory();
      core.Habit habit(String name) => factory.buildHabit()..name = name;
      final one = <core.Habit>[habit('a')];
      final two = <core.Habit>[habit('a'), habit('b')];

      expect(getExecuteString(l10n, ArchiveHabitsCommand(list, one)),
          'Habit archived',
          reason: 'commands.listener-list-habits-toasts#3 — '
              'ArchiveHabitsCommand -> R.plurals.toast_habits_archived with '
              'quantity = command.selected.size');
      expect(getExecuteString(l10n, ArchiveHabitsCommand(list, two)),
          'Habits archived',
          reason: 'commands.archive-habits#9 — the quantity really is '
              'command.selected.size: two habits give the plural form');

      expect(
          getExecuteString(
              l10n, ChangeHabitColorCommand(list, one, const core.PaletteColor(4))),
          'Habit changed',
          reason: 'commands.listener-list-habits-toasts#3 — '
              'ChangeHabitColorCommand -> R.plurals.toast_habits_changed');
      expect(
          getExecuteString(
              l10n, ChangeHabitColorCommand(list, two, const core.PaletteColor(4))),
          'Habits changed',
          reason: 'commands.change-habit-color#8 — with quantity = '
              'command.selected.size');

      expect(
          getExecuteString(
              l10n, CreateHabitCommand(factory, list, habit('c'))),
          'Habit created',
          reason: 'commands.listener-list-habits-toasts#3 — '
              'CreateHabitCommand -> R.string.toast_habit_created, a plain '
              'string and not a plural');

      expect(getExecuteString(l10n, DeleteHabitsCommand(list, one)),
          'Habit deleted',
          reason: 'commands.listener-list-habits-toasts#3 — '
              'DeleteHabitsCommand -> R.plurals.toast_habits_deleted');
      expect(getExecuteString(l10n, DeleteHabitsCommand(list, two)),
          'Habits deleted',
          reason: 'commands.listener-list-habits-toasts#3 — with quantity = '
              'command.selected.size');

      expect(getExecuteString(l10n, UnarchiveHabitsCommand(list, one)),
          'Habit unarchived',
          reason: 'commands.listener-list-habits-toasts#3 — '
              'UnarchiveHabitsCommand -> R.plurals.toast_habits_unarchived');
      expect(getExecuteString(l10n, UnarchiveHabitsCommand(list, two)),
          'Habits unarchived',
          reason: 'commands.unarchive-habits#7 — with quantity = '
              'command.selected.size');
    });

    test('#3 EditHabitCommand hard-codes the quantity to 1', () {
      final factory = core.MemoryModelFactory();
      final list = factory.buildHabitList();
      final modified = factory.buildHabit()..name = 'Meditate';

      expect(getExecuteString(l10n, EditHabitCommand(list, 7, modified)),
          'Habit changed',
          reason: 'commands.listener-list-habits-toasts#3 — EditHabitCommand '
              '-> R.plurals.toast_habits_changed with quantity hard-coded to 1');
      expect(getExecuteString(l10n, EditHabitCommand(list, 7, modified)),
          l10n.toastHabitsChanged(1),
          reason: 'commands.listener-list-habits-toasts#3 — the singular form, '
              'whatever the edit touched');
      expect(l10n.toastHabitsChanged(1), isNot(l10n.toastHabitsChanged(2)),
          reason: 'commands.listener-list-habits-toasts#3 — and the two '
              'quantities really are different strings, so hard-coding 1 is '
              'observable');
    });

    test('#4 CreateRepetitionCommand falls into the else -> null branch', () {
      core.setToday(core.LocalDate.ymd(2015, 1, 25));
      final factory = core.MemoryModelFactory();
      final list = factory.buildHabitList();
      final habit = factory.buildHabit()..name = 'Meditate';
      list.add(habit);

      expect(
        getExecuteString(
          l10n,
          CreateRepetitionCommand(
            list,
            habit,
            core.getToday(),
            core.Entry.yesManual,
            '',
          ),
        ),
        isNull,
        reason: 'commands.listener-list-habits-toasts#4 — ticking a checkmark '
            'never produces a toast',
      );
      expect(getExecuteString(l10n, _UnknownCommand()), isNull,
          reason: 'commands.listener-list-habits-toasts#2 — a null result '
              'means no feedback at all');
    });

    testWidgets('#1 the screen subscribes while mounted and unsubscribes when '
        'it goes away', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      scope.commandRunner
          .run(ArchiveHabitsCommand(scope.habitList, <core.Habit>[habit]));
      await tester.pumpAndSettle();
      expect(find.text('Habit archived'), findsOneWidget,
          reason: 'commands.listener-list-habits-toasts#1 — onAttached() '
              '(ListHabitsActivity.onResume) subscribes to the command runner');
      await dismissSnackBars(tester);

      // onPause: the activity goes away and takes the subscription with it.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();

      scope.commandRunner
          .run(UnarchiveHabitsCommand(scope.habitList, <core.Habit>[habit]));
      await tester.pumpAndSettle();
      expect(find.text('Habit unarchived'), findsNothing,
          reason: 'commands.listener-list-habits-toasts#1 — onDetached() '
              '(onPause) unsubscribes, so toasts appear only while the habit '
              'list screen is in the foreground');
      expect(habit.isArchived, isFalse,
          reason: 'commands.listener-list-habits-toasts#1 — the command still '
              'ran; only the feedback is gone');
    });

    testWidgets('#2/#5 a non-null string is shown as a message, and it carries '
        'no action button', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      scope.commandRunner.run(
        ChangeHabitColorCommand(
          scope.habitList,
          <core.Habit>[habit],
          const core.PaletteColor(4),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget,
          reason: 'commands.listener-list-habits-toasts#2 — '
              'onCommandFinished computes getExecuteString(command) and, if '
              'non-null, shows it as a message');
      expect(find.text('Habit changed'), findsOneWidget,
          reason: 'commands.change-habit-color#8 — the message is '
              'R.plurals.toast_habits_changed');
      expect(find.byType(SnackBarAction), findsNothing,
          reason: 'commands.listener-list-habits-toasts#5 — none of these '
              "toasts carries an action button; there is no 'UNDO' affordance "
              'on any of them');
      await dismissSnackBars(tester);
    });

    testWidgets('#4 ticking a checkmark shows nothing at all', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      scope.commandRunner.run(
        CreateRepetitionCommand(
          scope.habitList,
          habit,
          core.getToday(),
          core.Entry.yesManual,
          '',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing,
          reason: 'commands.listener-list-habits-toasts#4 — '
              'CreateRepetitionCommand falls into the else -> null branch');
      expect(habit.originalEntries.get(core.getToday()).value,
          core.Entry.yesManual,
          reason: 'commands.listener-list-habits-toasts#4 — the command did '
              'run; it simply produces no feedback');
    });
  });

  // =======================================================================
  // commands.no-undo-redo#3 — the delete-confirmation copy
  // =======================================================================

  group('commands.no-undo-redo', () {
    test('#3 the confirmation says the deletion cannot be undone', () {
      expect(
        l10n.deleteHabitsMessage(1),
        'The habit will be permanently deleted. This action cannot be undone.',
        reason: 'commands.no-undo-redo#3 — the quantity=one form of the '
            'delete-confirmation plural',
      );
      expect(
        l10n.deleteHabitsMessage(2),
        'The habits will be permanently deleted. This action cannot be undone.',
        reason: 'commands.no-undo-redo#3 — the quantity=other form',
      );
      expect(l10n.deleteHabitsMessage(1), contains('cannot be undone'),
          reason: 'commands.no-undo-redo#3 — deletion is irreversible and the '
              'UI says so');
    });

    testWidgets('#3 the confirmation dialog shows that copy and offers no undo',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(body: ConfirmDeleteDialog(quantity: 1)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'The habit will be permanently deleted. This action cannot be undone.',
        ),
        findsOneWidget,
        reason: 'commands.no-undo-redo#3 — the string really is what the '
            'delete confirmation shows',
      );
      expect(find.text('Undo'), findsNothing,
          reason: 'commands.no-undo-redo#3 — and nothing next to it offers to '
              'undo the deletion');
    });
  });

  // =======================================================================
  // commands.edit-habit#10 — which command the editor dispatches
  // =======================================================================

  group('commands.edit-habit', () {
    test('#10 habitId >= 0 selects EditHabitCommand, habitId < 0 selects '
        'CreateHabitCommand', () {
      final scope = openScope(dispatcher: const UnconfinedTestDispatcher());
      final existing = addHabit(scope, 'Meditate');
      final probe = _ProbeListener();
      scope.commandRunner.addListener(probe);

      final create = EditHabitModel(scope: scope);
      expect(create.habitId, -1,
          reason: 'commands.edit-habit#10 — the editor starts at '
              '`var habitId = -1L`, which is the CREATE branch');
      create.nameController.text = 'Run';
      expect(create.save(), isTrue);
      expect(probe.finished.single, isA<CreateHabitCommand>(),
          reason: 'commands.edit-habit#10 — habitId < 0 selects '
              'CreateHabitCommand');

      probe.finished.clear();
      final edit = EditHabitModel(scope: scope, habitId: existing.id);
      expect(edit.habitId >= 0, isTrue,
          reason: 'commands.edit-habit#10 — an id handed in through the '
              '"habitId" extra is >= 0');
      edit.nameController.text = 'Meditate more';
      expect(edit.save(), isTrue);
      expect(probe.finished.single, isA<EditHabitCommand>(),
          reason: 'commands.edit-habit#10 — habitId >= 0 selects '
              'EditHabitCommand');
      expect((probe.finished.single as EditHabitCommand).habitId, existing.id,
          reason: 'commands.edit-habit#10 — and it carries that very id');
      expect(scope.habitList.getById(existing.id!)!.name, 'Meditate more',
          reason: 'commands.edit-habit#10 — the edit branch really edited the '
              'existing habit rather than creating a second one');
      expect(scope.habitList.size(), 2,
          reason: 'commands.edit-habit#10 — one habit was created by the first '
              'branch, none by the second');
    });
  });
}

/// A command type `getExecuteString` does not name.
class _UnknownCommand implements Command {
  @override
  void run() {}
}

class _ProbeListener implements CommandRunnerListener {
  final List<Command> finished = <Command>[];

  @override
  void onCommandFinished(Command command) => finished.add(command);
}
