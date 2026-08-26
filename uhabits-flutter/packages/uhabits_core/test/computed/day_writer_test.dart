import 'package:test/test.dart';
import 'package:uhabits_core/src/computed/day_writer.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/time/local_date.dart';

void main() {
  const DayWriter writer = DayWriter();
  late Habit habit;

  setUp(() => habit = MemoryModelFactory().buildHabit()..id = 1);

  int valueOn(int day) => habit.originalEntries.get(LocalDate(day)).value;

  test('a value is written', () {
    expect(writer.write(habit, 9000, 89763), isTrue,
        reason: 'computed.day-write#2');
    expect(valueOn(9000), 89763, reason: 'computed.day-write#2');
  });

  test('nothing to say writes nothing at all', () {
    // Not a zero: an absent day is absent, and a written zero freezes it —
    // data arriving later can no longer heal it.
    expect(writer.write(habit, 9000, null), isFalse,
        reason: 'computed.day-write#3');
    expect(valueOn(9000), Entry.unknown, reason: 'computed.day-write#3');
  });

  test('a skipped day is left alone', () {
    habit.originalEntries.add(Entry(LocalDate(9000), Entry.skip));
    expect(writer.write(habit, 9000, 89763), isFalse,
        reason: 'computed.day-write#4');
    expect(valueOn(9000), Entry.skip, reason: 'computed.day-write#4');
  });

  test('the note is kept', () {
    habit.originalEntries.add(Entry(LocalDate(9000), 0, notes: 'kept'));
    writer.write(habit, 9000, 89763);
    expect(habit.originalEntries.get(LocalDate(9000)).notes, 'kept',
        reason: 'computed.day-write#1');
  });

  test('an unchanged value is not rewritten', () {
    writer.write(habit, 9000, 89763);
    expect(writer.write(habit, 9000, 89763), isFalse,
        reason: 'computed.day-write#5 — every write is a DELETE and an INSERT');
  });

  test('a value that would land on a sentinel is refused', () {
    // 1, 2 and 3 mean yesAuto, yesManual and skip. A computed day that landed
    // on one would read as something a person did.
    for (final int sentinel in <int>[Entry.yesAuto, Entry.yesManual, Entry.skip]) {
      expect(() => writer.write(habit, 9000, sentinel), throwsArgumentError,
          reason: 'computed.day-write#6');
    }
  });
}
