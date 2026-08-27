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

  // Zero is 1, 2 and 3's neighbour and is not one of them. `storedValueOf`
  // collapses every score below `minStoredValue` to exactly zero
  // (`sleep.stored-value#3`), so a night that scored nothing arrives here as 0
  // and has to be written down. The freeze this class guards against is a zero
  // written for a day with *no* data — which is what a null `storedValue`
  // means (`computed.day-write#3`) — and not a measured zero, which the next
  // sync over the same night overwrites like any other value. The two tests
  // are apart on purpose: one refuses the zero loudly and the other drops it
  // quietly, and each has to fail through its own assertion.
  test('a measured zero is not refused', () {
    expect(() => writer.write(habit, 9000, Entry.no), returnsNormally,
        reason: 'computed.day-write#2');
  });

  test('a measured zero is written down', () {
    writer.write(habit, 9000, Entry.no);
    expect(valueOn(9000), Entry.no, reason: 'computed.day-write#2');
  });

  group('a run of days', () {
    late List<int> announced;

    setUp(() {
      setToday(LocalDate(9000));
      announced = <int>[];
    });

    tearDown(resetToday);

    DayWriter announcingWriter() =>
        DayWriter(onChanged: (int id) => announced.add(id));

    test('is announced once, not once per day', () {
      final bool changed = announcingWriter().writeDays(habit, <int, int?>{
        8998: 40000,
        8999: 50000,
        9000: 60000,
      });

      expect(changed, isTrue, reason: 'computed.freshness#2');
      expect(announced, <int>[1], reason: 'computed.freshness#2');
    });

    test('announces nothing when nothing changed', () {
      announcingWriter().writeDays(habit, <int, int?>{9000: null});

      expect(announced, isEmpty, reason: 'computed.freshness#3');
    });

    test('recomputes before it announces', () {
      // What is told redraws from the habit, and on a test dispatcher it
      // redraws on this very stack. `computedEntries` is empty until
      // `recompute()` fills it, so reading it inside the callback is reading
      // the order the two happen in.
      int? seen;
      DayWriter(onChanged: (_) {
        seen = habit.computedEntries.get(LocalDate(9000)).value;
      }).writeDays(habit, <int, int?>{9000: 60000});

      expect(seen, 60000, reason: 'computed.freshness#4');
    });

    test('a habit that was never saved is refused before anything is written',
        () {
      // The announcement carries the id, and a habit with no id has none. The
      // first assertion holds either way; the second is the one that matters,
      // and it is why the id is read on the way in rather than on the way out.
      final Habit unsaved = MemoryModelFactory().buildHabit();

      expect(
          () => DayWriter(onChanged: (_) {})
              .writeDays(unsaved, <int, int?>{9000: 60000}),
          throwsA(isA<TypeError>()),
          reason: 'a door that cannot announce must not write either');
      expect(unsaved.originalEntries.get(LocalDate(9000)).value, Entry.unknown,
          reason: 'failing on the way out would leave the day written and '
              'nobody told');
    });
  });

  group('taking a computed day back', () {
    setUp(() => setToday(LocalDate(9000)));
    tearDown(resetToday);

    test('returns the day to silence and keeps the note', () {
      // Без этой двери отмена срыва невозможна: `write(habit, day, null)`
      // означает «сказать нечего» и оставляет вчерашние 45000 лежать в дне,
      // который человек только что отменил. У `EntryList` удаления отдельного
      // дня нет — только `add` и `clear`.
      habit.originalEntries
          .add(Entry(LocalDate(9000), 45000, notes: 'третий день'));

      expect(const DayWriter().clear(habit, 9000), isTrue,
          reason: 'computed.day-write#8');
      expect(habit.originalEntries.get(LocalDate(9000)).value, Entry.unknown,
          reason: 'computed.day-write#8');
      expect(habit.originalEntries.get(LocalDate(9000)).notes, 'третий день',
          reason: 'computed.day-write#8 — заметка человека остаётся');
    });

    // Split in two against the brief's single body. Dropping the skip guard
    // makes `clear` answer `true`, which is the first assertion — so the one
    // that matters, that the skip is still there afterwards, would never have
    // run under the very mutation it exists to catch.
    test('does not say it took a skip off', () {
      habit.originalEntries.add(Entry(LocalDate(9000), Entry.skip));

      expect(const DayWriter().clear(habit, 9000), isFalse,
          reason: 'computed.day-write#8');
    });

    test('does not take a skip off', () {
      habit.originalEntries.add(Entry(LocalDate(9000), Entry.skip));

      const DayWriter().clear(habit, 9000);

      expect(habit.originalEntries.get(LocalDate(9000)).value, Entry.skip,
          reason: 'computed.day-write#8 — пропуск есть отметка человека '
              '(`computed.day-write#4`)');
    });

    test('a day that was already silent is not written again', () {
      expect(const DayWriter().clear(habit, 9000), isFalse,
          reason: 'computed.day-write#8');
    });

    test('a habit that was never saved is refused before the day is cleared',
        () {
      // The same invariant as [writeDays], on the other method: the id is
      // read first, so a door that cannot announce leaves the day exactly as
      // it found it.
      final Habit unsaved = MemoryModelFactory().buildHabit();
      unsaved.originalEntries.add(Entry(LocalDate(9000), 45000));

      expect(() => DayWriter(onChanged: (_) {}).clear(unsaved, 9000),
          throwsA(isA<TypeError>()),
          reason: 'a door that cannot announce must not write either');
      expect(unsaved.originalEntries.get(LocalDate(9000)).value, 45000,
          reason: 'failing on the way out would leave the day cleared and '
              'nobody told');
    });

    test('announces the same way a write does, once and after the recompute',
        () {
      habit.originalEntries.add(Entry(LocalDate(9000), 45000));
      habit.recompute();
      final List<int> announced = <int>[];

      DayWriter(onChanged: announced.add).clear(habit, 9000);

      expect(announced, <int>[1], reason: 'computed.freshness#2');
      expect(habit.computedEntries.get(LocalDate(9000)).value, Entry.unknown,
          reason: 'computed.freshness#4 — объявлять день, которого ещё не '
              'пересчитали, значит объявлять прежнее значение');
    });
  });
}
