import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/sleep/stored_value.dart';

void main() {
  group('habit type', () {
    test('stays a two element enum', () {
      // A sleep habit is a numerical habit that has a sleep goal. Adding a
      // third entry here would contradict models.habit-type-enums#1, a parity
      // rule that is closed by tests, and would force those tests to assert
      // something the ledger does not say.
      expect(HabitType.values.length, 2, reason: 'sleep.habit-type#1');
      expect(HabitType.values.map((t) => t.value), <int>[0, 1],
          reason: 'sleep.habit-type#1');
      expect(() => HabitType.fromInt(2), throwsStateError,
          reason: 'sleep.habit-type#1');
    });

    test('a sleep habit is persisted as a numerical habit', () {
      expect(sleepHabitType, HabitType.numerical,
          reason: 'sleep.habit-type#1');
      expect(sleepHabitType.value, 1, reason: 'sleep.habit-type#1');
      expect(sleepHabitType.csvName, 'NUMERICAL',
          reason: 'sleep.habit-type#1');
    });
  });

  group('stored value', () {
    test('a score is stored as percent times one thousand', () {
      expect(storedValueOf(0.87), 87000, reason: 'sleep.habit-type#3');
      expect(storedValueOf(1.0), maxStoredValue, reason: 'sleep.habit-type#3');
      expect(storedValueOf(0.5), 50000, reason: 'sleep.habit-type#3');
      expect(storedValueOf(0.868318), 86832, reason: 'sleep.habit-type#3');
    });

    test('reserved values collapse to zero rather than becoming a skip', () {
      // 0.003% lands exactly on Entry.skip. Left alone, the worst night a
      // person can have would read as "not applicable" and lift the score
      // instead of sinking it.
      expect(minStoredValue, greaterThan(Entry.skip),
          reason: 'sleep.stored-value#1');
      for (final reserved in <int>[Entry.yesAuto, Entry.yesManual, Entry.skip]) {
        expect(storedValueOf(reserved / maxStoredValue), 0,
            reason: 'sleep.stored-value#1');
      }
      expect(storedValueOf(minStoredValue / maxStoredValue), minStoredValue,
          reason: 'sleep.stored-value#1');
    });

    test('values above the maximum are clamped', () {
      expect(storedValueOf(1.5), maxStoredValue,
          reason: 'sleep.stored-value#2');
      expect(storedValueOf(double.infinity), maxStoredValue,
          reason: 'sleep.stored-value#2');
    });

    test('zero stays zero and never becomes a sentinel', () {
      expect(storedValueOf(0), 0, reason: 'sleep.stored-value#3');
      expect(storedValueOf(-0.1), 0, reason: 'sleep.stored-value#3');
      expect(storedValueOf(double.nan), 0, reason: 'sleep.stored-value#3');
      expect(storedValueOf(0), isNot(Entry.skip),
          reason: 'sleep.stored-value#3');
    });

    test('every producible value is either zero or unambiguous', () {
      // Sweeping the whole range is cheap and proves the property rather than
      // sampling it: no input may produce 1, 2 or 3.
      for (var i = 0; i <= maxStoredValue; i += 1) {
        final value = storedValueOf(i / maxStoredValue);
        expect(value == 0 || value >= minStoredValue, isTrue,
            reason: 'sleep.stored-value#1');
      }
    });
  });
}
