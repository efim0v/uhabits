/// `computed.lifecycle#2` — deleting or archiving a habit withdraws the
/// morning question a computed sleep habit has armed with the system;
/// un-archiving does not, because the next sync arms it again.
library;

// Commands are reached by their `src` path, exactly as
// lib/state/app_scope.dart and other app tests reach them.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/computed_habit_hooks.dart';
import 'package:uhabits_core/src/commands/archive_habits_command.dart';
import 'package:uhabits_core/src/commands/create_habit_command.dart';
import 'package:uhabits_core/src/commands/delete_habits_command.dart';
import 'package:uhabits_core/src/commands/unarchive_habits_command.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late List<int> cancelled;
  late ComputedHabitHooks hooks;
  late HabitList list;

  setUp(() {
    cancelled = <int>[];
    hooks = ComputedHabitHooks(
      cancelPrompt: (Habit h) => cancelled.add(h.id!),
    );
    list = MemoryHabitList();
  });

  Habit habitWith(int id) => MemoryModelFactory().buildHabit()..id = id;

  test('deleting a habit withdraws its question', () {
    final Habit habit = habitWith(7);
    hooks.onCommandFinished(DeleteHabitsCommand(list, <Habit>[habit]));
    expect(cancelled, <int>[7], reason: 'computed.lifecycle#2');
  });

  test('archiving one does too', () {
    final Habit habit = habitWith(8);
    hooks.onCommandFinished(ArchiveHabitsCommand(list, <Habit>[habit]));
    expect(cancelled, <int>[8], reason: 'computed.lifecycle#2');
  });

  test('un-archiving does not, because the sync arms it again', () {
    final Habit habit = habitWith(9);
    hooks.onCommandFinished(UnarchiveHabitsCommand(list, <Habit>[habit]));
    expect(cancelled, isEmpty, reason: 'computed.lifecycle#2');
  });

  test('an ordinary command withdraws nothing', () {
    hooks.onCommandFinished(
      CreateHabitCommand(MemoryModelFactory(), list, habitWith(10)),
    );
    expect(cancelled, isEmpty, reason: 'computed.lifecycle#2');
  });
}
