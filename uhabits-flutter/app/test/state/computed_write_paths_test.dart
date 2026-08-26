/// `computed.write-paths` — the widget, the notification action and the
/// staged tap queue all reach entries through `WidgetBehavior`'s five
/// methods, and every one of them funnels into `WidgetBehavior.setValue`
/// (`onAddRepetition`, `onRemoveRepetition`, `onToggleRepetition`, and the
/// increment/decrement pair). A computed habit's day is not entered by a
/// person, so none of those five may write one — the next recompute would
/// silently overwrite whatever they wrote.
///
/// Harness copied from `app/test/state/widget_checkmark_tap_test.dart`: it
/// already builds `WidgetBehavior` with a real `AppScope` (so
/// `scope.definitions` is a real `DefinitionRepository`), a habit list and a
/// silent notification tray. Every widget write funnels through
/// `WidgetBehavior.setValue`, so the three entry points below are tested
/// through the three methods that reach it.
library;

// The core's models are reached by their `src` path, exactly as lib/state
// does.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/widget_sync.dart' show WidgetBehavior;
import 'package:uhabits_core/src/computed/habit_definition.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/notification_tray.dart';

void main() {
  late Directory tempDir;
  late AppScope scope;
  late WidgetBehavior behavior;
  late Habit habit;
  late Habit ordinary;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 26));
    tempDir = Directory.systemTemp.createTempSync('uhabits_computed_write');
    scope = AppScope.open(
      AppDatabase.openAndMigrate('${tempDir.path}/habits.db'),
    );
    scope.preferences.isFirstRun = false;

    habit = scope.modelFactory.buildHabit()..name = 'Sleep';
    scope.habitList.add(habit);
    habit.recompute();

    ordinary = scope.modelFactory.buildHabit()..name = 'Meditate';
    scope.habitList.add(ordinary);
    ordinary.recompute();

    behavior = WidgetBehavior(
      habitList: scope.habitList,
      commandRunner: scope.commandRunner,
      notificationTray: NotificationTray(
        scope.taskRunner,
        scope.commandRunner,
        scope.preferences,
        _SilentTray(),
      ),
      preferences: scope.preferences,
      isComputed: (int id) => scope.definitions.isComputed(id),
    );
  });

  tearDown(() {
    scope.close();
    tempDir.deleteSync(recursive: true);
  });

  test('a widget tap cannot mark a computed habit done', () async {
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    habit.originalEntries.add(Entry(LocalDate(9000), 89763));

    behavior.onAddRepetition(habit, LocalDate(9000));
    await pumpEventQueue();

    expect(habit.originalEntries.get(LocalDate(9000)).value, 89763,
        reason: 'computed.write-paths#1');
  });

  test('nor undo one', () async {
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    habit.originalEntries.add(Entry(LocalDate(9000), 89763));

    behavior.onRemoveRepetition(habit, LocalDate(9000));
    await pumpEventQueue();

    expect(habit.originalEntries.get(LocalDate(9000)).value, 89763,
        reason: 'computed.write-paths#1');
  });

  test('nor toggle one', () async {
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));
    habit.originalEntries.add(Entry(LocalDate(9000), 89763));

    behavior.onToggleRepetition(habit, LocalDate(9000));
    await pumpEventQueue();

    expect(habit.originalEntries.get(LocalDate(9000)).value, 89763,
        reason: 'computed.write-paths#1');
  });

  test('an ordinary habit is written exactly as before', () async {
    behavior.onAddRepetition(ordinary, LocalDate(9000));
    await pumpEventQueue();

    expect(ordinary.originalEntries.get(LocalDate(9000)).value,
        Entry.yesManual,
        reason: 'computed.write-paths#2 — nothing about the ported widget '
            'behaviour moves');
  });
}

/// A tray backend that posts nothing: `WidgetBehavior` cancels a notification
/// on every write, and there is no platform here to cancel one on.
class _SilentTray implements SystemTray {
  @override
  void log(String msg) {}

  @override
  void removeNotification(int notificationId) {}

  @override
  void showNotification(
    Habit habit,
    int notificationId,
    LocalDate date,
    int reminderTime,
  ) {}
}
