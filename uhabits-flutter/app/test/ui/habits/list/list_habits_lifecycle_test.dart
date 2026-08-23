/// Tests for `ListHabitsActivity`'s resume path, its POST_NOTIFICATIONS gate,
/// its ACTION_EDIT intent and the crash handler it installs.
///
/// The Kotlin activity does all four in one place; the port spreads them
/// across the objects that have the matching lifetimes — [HabitListModel]
/// (`attach` / `detach`), [ReminderPermissionGate] and the app shell — so each
/// is driven here through the object that owns it.
library;

// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/main.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/habit_list_model.dart';
import 'package:uhabits/state/reminder_permission_gate.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/habit_list_screen.dart';
import 'package:uhabits/ui/habits/list/list_habits_root_view.dart';
import 'package:uhabits_core/src/commands/create_repetition_command.dart';
import 'package:uhabits_core/src/reminders/reminder_scheduler.dart';
// `Intent` collides with the Flutter Actions one.
import 'package:uhabits_core/src/ui/intent_parser.dart' as core;
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Directory tempDir;
  final scopes = <AppScope>[];

  setUp(() {
    resetToday();
    tempDir = Directory.systemTemp.createTempSync('uhabits_list_lifecycle');
  });

  tearDown(() {
    for (final scope in scopes) {
      scope.close();
    }
    scopes.clear();
    tempDir.deleteSync(recursive: true);
  });

  AppScope openScope() {
    final scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scopes.add(scope);
    return scope;
  }

  Habit addHabit(AppScope scope, String name, {Reminder? reminder}) {
    final habit = scope.modelFactory.buildHabit()..name = name;
    if (reminder != null) habit.reminder = reminder;
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

  HabitListModel modelOf(WidgetTester tester) => Provider.of<HabitListModel>(
        tester.element(find.byType(Scaffold)),
        listen: false,
      );

  group('list-habits.startup-lifecycle', () {
    testWidgets('#3 a resume refreshes the adapter, re-registers it with the '
        'command runner and repaints the root view', (tester) async {
      // The remaining clauses of the rule belong to objects with the
      // *application's* lifetime rather than this screen's, and are covered by
      // their own features: the midnight timer and the POST_NOTIFICATIONS gate
      // (`reminders.app-start-and-permission`), the auto-backup
      // (`io.auto-backup`), the widget refresh (`widgets.updater`) and the
      // pure-black restart (`settings.theme.pure-black`). The last clause,
      // parseIntents(), is #8 below.
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final today = getToday();
      final model = modelOf(tester);
      // `onPause`: the cache stops following the command runner.
      model.detach();
      scope.commandRunner.run(
        CreateRepetitionCommand(scope.habitList, habit, today, Entry.yesManual, ''),
      );
      await tester.pumpAndSettle();
      expect(scope.adapter.bindCardView(0), isNull,
          reason: 'list-habits.startup-lifecycle#3');

      // `onResume`: `adapter.refresh()` and `screen.onAttached()`.
      model.attach();
      await tester.pumpAndSettle();

      expect(scope.adapter.bindCardView(0), isNotNull,
          reason: 'list-habits.startup-lifecycle#3 — the adapter is refreshed');
      expect(scope.cache.getCheckmarks(habit.id!).first, Entry.yesManual,
          reason: 'list-habits.startup-lifecycle#3 — and the cache caught up '
              'with the command it missed');

      // …and a command run *after* the resume reaches the cache, so the
      // listener really is registered again.
      scope.commandRunner.run(
        CreateRepetitionCommand(scope.habitList, habit, today, Entry.no, ''),
      );
      await tester.pumpAndSettle();
      expect(scope.cache.getCheckmarks(habit.id!).first, Entry.no,
          reason: 'list-habits.startup-lifecycle#3');
      // `rootView.postInvalidate()`: the strip is redrawn from the current day.
      expect(find.byKey(EntryPanel.buttonKey(today)), findsOneWidget,
          reason: 'list-habits.startup-lifecycle#3');
    });

    testWidgets('#8 an ACTION_EDIT intent opens that entry\'s popup once, with '
        'no confetti', (tester) async {
      final scope = openScope();
      final habit = addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final model = modelOf(tester);
      final date = getToday().minus(2);
      model
        ..detach()
        // `onNewIntent(intent)` -> `setIntent(intent)`.
        ..pendingIntent = core.Intent(
          action: HabitListModel.actionEdit,
          extras: <String, Object?>{
            'habit': habit.id,
            'timestamp': date.unixTime,
          },
        )
        // `onResume` ends with `parseIntents()`.
        ..attach();
      await tester.pumpAndSettle();

      expect(find.byType(CheckmarkDialog), findsOneWidget,
          reason: 'list-habits.startup-lifecycle#8');
      // (0f, 0f) suppresses the burst.
      expect(
        tester
            .state<ConfettiOverlayState>(find.byType(ConfettiOverlay))
            .parties,
        isEmpty,
        reason: 'list-habits.startup-lifecycle#8 and list-habits.confetti#1',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('checkmark_yes_button')),
      );
      await tester.pumpAndSettle();
      expect(habit.computedEntries.get(date).value, Entry.yesManual,
          reason: 'list-habits.startup-lifecycle#8 — the popup was opened for '
              'the day the intent named');

      // `intent = null`: a second resume handles nothing.
      expect(model.pendingIntent, isNull,
          reason: 'list-habits.startup-lifecycle#8');
      model
        ..detach()
        ..attach();
      await tester.pumpAndSettle();
      expect(find.byType(CheckmarkDialog), findsNothing,
          reason: 'list-habits.startup-lifecycle#8 — handled exactly once');
    });

    testWidgets('#8 any other action is dropped without opening anything',
        (tester) async {
      final scope = openScope();
      addHabit(scope, 'Meditate');
      await tester.pumpWidget(wrap(scope));
      await tester.pumpAndSettle();

      final model = modelOf(tester);
      model
        ..detach()
        ..pendingIntent = core.Intent(action: 'android.intent.action.MAIN')
        ..attach();
      await tester.pumpAndSettle();

      expect(find.byType(CheckmarkDialog), findsNothing,
          reason: 'list-habits.startup-lifecycle#8');
      expect(model.pendingIntent, isNull,
          reason: 'list-habits.startup-lifecycle#8 — cleared either way');
    });

    test('#5 reminders are only scheduled when a habit has one, and the '
        'permission is asked for at most once', () async {
      final scope = openScope();
      final scheduler = _RecordingScheduler(scope.habitList);

      // No habit has a reminder: nothing is scheduled and nothing is asked.
      final permissions = _FakePermissions();
      var gate = ReminderPermissionGate(
        scheduler: scheduler,
        permissions: permissions,
      );
      expect(await gate.onResume(), isFalse,
          reason: 'list-habits.startup-lifecycle#5');
      expect(scheduler.scheduleAllCount, 0,
          reason: 'list-habits.startup-lifecycle#5');
      expect(permissions.requestCount, 0,
          reason: 'list-habits.startup-lifecycle#5');

      addHabit(scope, 'Meditate', reminder: Reminder(8, 0, WeekdayList.everyDay));
      expect(scheduler.hasHabitsWithReminders(), isTrue,
          reason: 'list-habits.startup-lifecycle#5');

      // API < 33: scheduled directly, with no permission dance at all.
      permissions.needsRuntime = false;
      gate = ReminderPermissionGate(
        scheduler: scheduler,
        permissions: permissions,
      );
      expect(await gate.onResume(), isTrue,
          reason: 'list-habits.startup-lifecycle#5');
      expect(scheduler.scheduleAllCount, 1,
          reason: 'list-habits.startup-lifecycle#5');
      expect(permissions.requestCount, 0,
          reason: 'list-habits.startup-lifecycle#5');

      // API >= 33, already granted: scheduled, still nothing asked.
      permissions
        ..needsRuntime = true
        ..granted = true;
      gate = ReminderPermissionGate(
        scheduler: scheduler,
        permissions: permissions,
      );
      expect(await gate.onResume(), isTrue,
          reason: 'list-habits.startup-lifecycle#5');
      expect(scheduler.scheduleAllCount, 2,
          reason: 'list-habits.startup-lifecycle#5');
      expect(permissions.requestCount, 0,
          reason: 'list-habits.startup-lifecycle#5');

      // API >= 33, denied: asked exactly once per activity instance, and
      // nothing further happens.
      permissions
        ..granted = false
        ..answer = false;
      gate = ReminderPermissionGate(
        scheduler: scheduler,
        permissions: permissions,
      );
      expect(await gate.onResume(), isFalse,
          reason: 'list-habits.startup-lifecycle#5');
      expect(permissions.requestCount, 1,
          reason: 'list-habits.startup-lifecycle#5');
      expect(gate.permissionAlreadyRequested, isTrue,
          reason: 'list-habits.startup-lifecycle#5');
      expect(scheduler.scheduleAllCount, 2,
          reason: 'list-habits.startup-lifecycle#5 — a denial schedules '
              'nothing');

      // The resume the dismissal itself triggers must not ask again.
      expect(await gate.onResume(), isFalse,
          reason: 'list-habits.startup-lifecycle#5');
      expect(permissions.requestCount, 1,
          reason: 'list-habits.startup-lifecycle#5 — guarded against the '
              'infinite onResume loop');
    });

    testWidgets('#9 the app shell installs the uncaught exception handler',
        (tester) async {
      final before = FlutterError.onError;
      addTearDown(() => FlutterError.onError = before);

      final scope = openScope();
      addHabit(scope, 'Meditate');
      await tester.pumpWidget(UhabitsApp(scope: scope));
      await tester.pumpAndSettle();

      // `Thread.setDefaultUncaughtExceptionHandler(BaseExceptionHandler(this))`:
      // the previous handler is captured and chained onto, not discarded, so
      // what is observable is that the slot no longer holds what it did.
      expect(FlutterError.onError, isNot(same(before)),
          reason: 'list-habits.startup-lifecycle#9');
      expect(FlutterError.onError, isNotNull,
          reason: 'list-habits.startup-lifecycle#9');
    });
  });
}

/// A [ReminderScheduler] that counts what it was asked to do.
class _RecordingScheduler implements ReminderScheduler {
  _RecordingScheduler(this._habits);

  final HabitList _habits;

  int scheduleAllCount = 0;

  @override
  bool hasHabitsWithReminders() {
    for (final habit in _habits) {
      if (habit.hasReminder()) return true;
    }
    return false;
  }

  @override
  void scheduleAll() => scheduleAllCount++;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePermissions implements NotificationPermissions {
  bool needsRuntime = true;
  bool granted = true;
  bool answer = true;
  int requestCount = 0;

  @override
  Future<bool> get needsRuntimePermission async => needsRuntime;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requestCount++;
    return answer;
  }
}
