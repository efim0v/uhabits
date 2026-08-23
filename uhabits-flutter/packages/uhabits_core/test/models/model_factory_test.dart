import 'package:test/test.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/entry_list.dart';
import 'package:uhabits_core/src/models/frequency.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/habit_type.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/models/model_factory.dart';
import 'package:uhabits_core/src/models/palette_color.dart';
import 'package:uhabits_core/src/models/score_list.dart';
import 'package:uhabits_core/src/models/sqlite/sql_model_factory.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_entry_list.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_habit_list.dart';
import 'package:uhabits_core/src/models/streak_list.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

/// The offsets and values baked into HabitFixtures.createLongNumericalHabit.
const _longNumericalTimes = <int>[
  0, 5, 9, 15, 17, 21, 23, 27, 28, 35, 41, 45, 47, 53, 56, 62, 70, 73, 78, //
  83, 86, 94, 101, 106, 113, 114, 120, 126, 130, 133, 141, 143, 148, 151, 157,
  164, 166, 171, 173, 176, 179, 183, 191, 259, 264, 268, 270, 275, 282, 284,
  289, 295, 302, 306, 310, 315, 323, 325, 328, 335, 343, 349, 351, 353, 357,
  359, 360, 367, 372, 376, 380, 385, 393, 400, 404, 412, 415, 418, 422, 425,
  433, 437, 444, 449, 455, 460, 462, 465, 470, 471, 479, 481, 485, 489, 494,
  495, 500, 501, 503, 507,
];

const _longNumericalValues = <int>[
  230, 306, 148, 281, 134, 285, 104, 158, 325, 236, 303, 210, 118, 124, //
  301, 201, 156, 376, 347, 367, 396, 134, 160, 381, 155, 354, 231, 134, 164,
  354, 236, 398, 199, 221, 208, 397, 253, 276, 214, 341, 299, 221, 353, 250,
  341, 168, 374, 205, 182, 217, 297, 321, 104, 237, 294, 110, 136, 229, 102,
  271, 250, 294, 158, 319, 379, 126, 282, 155, 288, 159, 215, 247, 207, 226,
  244, 158, 371, 219, 272, 228, 350, 153, 356, 279, 394, 202, 213, 214, 112,
  248, 139, 245, 165, 256, 370, 187, 208, 231, 341, 312,
];

/// The day offsets baked into HabitFixtures.createLongHabit.
const _longHabitMarks = <int>[
  0, 1, 3, 5, 7, 8, 9, 10, 12, 14, 15, 17, 19, 20, 26, 27, //
  28, 50, 51, 52, 53, 54, 58, 60, 63, 65, 70, 71, 72, 73, 74, 75, 80,
  81, 83, 89, 90, 91, 95, 102, 103, 108, 109, 120,
];

/// A factory that only supplies the five abstract methods, so that the
/// inherited (default) buildHabit() can be observed wiring them together.
class _RecordingModelFactory extends ModelFactory {
  final List<EntryList> computed = <EntryList>[];
  final List<EntryList> original = <EntryList>[];
  final List<ScoreList> scores = <ScoreList>[];
  final List<StreakList> streaks = <StreakList>[];
  final List<HabitList> habitLists = <HabitList>[];

  @override
  EntryList buildComputedEntries() {
    final result = EntryList();
    computed.add(result);
    return result;
  }

  @override
  EntryList buildOriginalEntries() {
    final result = EntryList();
    original.add(result);
    return result;
  }

  @override
  HabitList buildHabitList() {
    final result = MemoryHabitList();
    habitLists.add(result);
    return result;
  }

  @override
  ScoreList buildScoreList() {
    final result = ScoreList();
    scores.add(result);
    return result;
  }

  @override
  StreakList buildStreakList() {
    final result = StreakList();
    streaks.add(result);
    return result;
  }
}

void main() {
  late MemoryModelFactory modelFactory;
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;

  setUp(() {
    // models.test-fixtures#7: BaseUnitTest pins 'today' before every test.
    setToday(LocalDate.ymd(2015, 1, 25));
    modelFactory = MemoryModelFactory();
    habitList = modelFactory.buildHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
  });

  tearDown(resetToday);

  group('ModelFactory', () {
    test('declares the five build methods plus a default buildHabit', () {
      // models.model-factory#1
      expect(modelFactory, isA<ModelFactory>(),
          reason: 'models.model-factory#1');
      expect(modelFactory.buildComputedEntries(), isA<EntryList>(),
          reason: 'models.model-factory#1');
      expect(modelFactory.buildOriginalEntries(), isA<EntryList>(),
          reason: 'models.model-factory#1');
      expect(modelFactory.buildHabitList(), isA<MemoryHabitList>(),
          reason: 'models.model-factory#1');
      expect(modelFactory.buildScoreList(), isA<ScoreList>(),
          reason: 'models.model-factory#1');
      expect(modelFactory.buildStreakList(), isA<StreakList>(),
          reason: 'models.model-factory#1');
      expect(modelFactory.buildHabit(), isA<Habit>(),
          reason: 'models.model-factory#1');
    });

    test('buildHabit wires in freshly built collaborators', () {
      final habit = modelFactory.buildHabit();
      final other = modelFactory.buildHabit();

      expect(identical(habit.scores, other.scores), isFalse,
          reason: 'models.model-factory#2');
      expect(identical(habit.streaks, other.streaks), isFalse,
          reason: 'models.model-factory#2');
      expect(identical(habit.originalEntries, other.originalEntries), isFalse,
          reason: 'models.model-factory#2');
      expect(identical(habit.computedEntries, other.computedEntries), isFalse,
          reason: 'models.model-factory#2');
      expect(identical(habit.originalEntries, habit.computedEntries), isFalse,
          reason: 'models.model-factory#2');

      // Freshly built lists are empty.
      expect(habit.originalEntries.getKnown(), isEmpty,
          reason: 'models.model-factory#2');
      expect(habit.computedEntries.getKnown(), isEmpty,
          reason: 'models.model-factory#2');
    });

    test('the default buildHabit is inherited and calls the four builders', () {
      // models.model-factory#1: an implementor supplies only the five abstract
      // methods; buildHabit() comes from the interface itself.
      final recording = _RecordingModelFactory();
      final habit = recording.buildHabit();

      expect(recording.scores.length, 1, reason: 'models.model-factory#1');
      expect(recording.streaks.length, 1, reason: 'models.model-factory#1');
      expect(recording.original.length, 1, reason: 'models.model-factory#1');
      expect(recording.computed.length, 1, reason: 'models.model-factory#1');
      expect(recording.habitLists, isEmpty, reason: 'models.model-factory#1');

      expect(identical(habit.scores, recording.scores.single), isTrue,
          reason: 'models.model-factory#2');
      expect(identical(habit.streaks, recording.streaks.single), isTrue,
          reason: 'models.model-factory#2');
      expect(
          identical(habit.originalEntries, recording.original.single), isTrue,
          reason: 'models.model-factory#2');
      expect(identical(habit.computedEntries, recording.computed.single), isTrue,
          reason: 'models.model-factory#2');
    });

    test('buildHabit leaves every other field at its declared default', () {
      final habit = modelFactory.buildHabit();

      expect(habit.color, const PaletteColor(8),
          reason: 'models.model-factory#2');
      expect(habit.description, '', reason: 'models.model-factory#2');
      expect(habit.frequency, Frequency.daily,
          reason: 'models.model-factory#2');
      expect(habit.id, isNull, reason: 'models.model-factory#2');
      expect(habit.isArchived, isFalse, reason: 'models.model-factory#2');
      expect(habit.name, '', reason: 'models.model-factory#2');
      expect(habit.position, 0, reason: 'models.model-factory#2');
      expect(habit.question, '', reason: 'models.model-factory#2');
      expect(habit.reminder, isNull, reason: 'models.model-factory#2');
      expect(habit.targetType, NumericalHabitType.atLeast,
          reason: 'models.model-factory#2');
      expect(habit.targetValue, 0.0, reason: 'models.model-factory#2');
      expect(habit.type, HabitType.yesNo, reason: 'models.model-factory#2');
      expect(habit.unit, '', reason: 'models.model-factory#2');
    });

    test('buildHabit generates a fresh uuid for every habit', () {
      final first = modelFactory.buildHabit();
      final second = modelFactory.buildHabit();

      expect(first.uuid, isNotNull, reason: 'models.model-factory#2');
      expect(second.uuid, isNotNull, reason: 'models.model-factory#2');
      expect(first.uuid, isNot(second.uuid),
          reason: 'models.model-factory#2');
    });

    test('MemoryModelFactory returns plain in-memory collaborators', () {
      // models.model-factory#3: plain EntryList / ScoreList / StreakList, and
      // a MemoryHabitList — no subclasses.
      expect(modelFactory.buildComputedEntries().runtimeType, EntryList,
          reason: 'models.model-factory#3');
      expect(modelFactory.buildOriginalEntries().runtimeType, EntryList,
          reason: 'models.model-factory#3');
      expect(modelFactory.buildScoreList().runtimeType, ScoreList,
          reason: 'models.model-factory#3');
      expect(modelFactory.buildStreakList().runtimeType, StreakList,
          reason: 'models.model-factory#3');
      expect(modelFactory.buildHabitList().runtimeType, MemoryHabitList,
          reason: 'models.model-factory#3');
      expect(
        identical(modelFactory.buildHabitList(), modelFactory.buildHabitList()),
        isFalse,
        reason: 'models.model-factory#3',
      );
    });

    test('SQLModelFactory backs only the original entries with SQLite', () {
      final db = openMigratedDatabase();
      addTearDown(db.close);
      final sqlFactory = SQLModelFactory(db);

      // models.model-factory#4: originalEntries is a SQLiteEntryList wired to
      // the factory's one entry repository...
      final original = sqlFactory.buildOriginalEntries();
      expect(original.runtimeType, SQLiteEntryList,
          reason: 'models.model-factory#4');
      expect(
        identical(
            (original as SQLiteEntryList).repository, sqlFactory.entryRepository),
        isTrue,
        reason: 'models.model-factory#4',
      );
      // ...and every original list shares that single repository.
      final second = sqlFactory.buildOriginalEntries() as SQLiteEntryList;
      expect(identical(second, original), isFalse,
          reason: 'models.model-factory#4');
      expect(identical(second.repository, original.repository), isTrue,
          reason: 'models.model-factory#4');

      // computedEntries is a plain in-memory EntryList, never database backed.
      final computed = sqlFactory.buildComputedEntries();
      expect(computed.runtimeType, EntryList,
          reason: 'models.model-factory#4');
      expect(computed, isNot(isA<SQLiteEntryList>()),
          reason: 'models.model-factory#4');

      // buildHabit() wires exactly that pair onto the habit.
      final habit = sqlFactory.buildHabit();
      expect(habit.originalEntries.runtimeType, SQLiteEntryList,
          reason: 'models.model-factory#4');
      expect(habit.computedEntries.runtimeType, EntryList,
          reason: 'models.model-factory#4');
      expect(
        identical((habit.originalEntries as SQLiteEntryList).repository,
            sqlFactory.entryRepository),
        isTrue,
        reason: 'models.model-factory#4',
      );

      // The rest of the factory is unchanged from the in-memory one, except
      // the habit list, which reads the Habits table.
      expect(sqlFactory.buildScoreList().runtimeType, ScoreList,
          reason: 'models.model-factory#4');
      expect(sqlFactory.buildStreakList().runtimeType, StreakList,
          reason: 'models.model-factory#4');
      expect(sqlFactory.buildHabitList().runtimeType, SQLiteHabitList,
          reason: 'models.model-factory#4');
    });
  });

  group('HabitFixtures', () {
    test('today is pinned to 2015-01-25 before every test', () {
      expect(getToday(), LocalDate.ymd(2015, 1, 25),
          reason: 'models.test-fixtures#7');
      expect(getToday().year, 2015, reason: 'models.test-fixtures#7');
      expect(getToday().month, 1, reason: 'models.test-fixtures#7');
      expect(getToday().day, 25, reason: 'models.test-fixtures#7');
    });

    test('createEmptyHabit uses the documented defaults', () {
      final habit = fixtures.createEmptyHabit();

      expect(habit.name, 'Meditate', reason: 'models.test-fixtures#1');
      expect(habit.color, const PaletteColor(3),
          reason: 'models.test-fixtures#1');
      expect(habit.position, 0, reason: 'models.test-fixtures#1');
      expect(habit.question, 'Did you meditate this morning?',
          reason: 'models.test-fixtures#1');
      expect(habit.frequency, Frequency.daily,
          reason: 'models.test-fixtures#1');
      expect(habit.originalEntries.getKnown(), isEmpty,
          reason: 'models.test-fixtures#1');
      expect(habit.computedEntries.getKnown(), isEmpty,
          reason: 'models.test-fixtures#1');
    });

    test('createEmptyHabit accepts name, color and position overrides', () {
      final habit = fixtures.createEmptyHabit(
        name: 'Exercise',
        color: const PaletteColor(7),
        position: 5,
      );

      expect(habit.name, 'Exercise', reason: 'models.test-fixtures#1');
      expect(habit.color, const PaletteColor(7),
          reason: 'models.test-fixtures#1');
      expect(habit.position, 5, reason: 'models.test-fixtures#1');
      expect(habit.question, 'Did you meditate this morning?',
          reason: 'models.test-fixtures#1');
      expect(habit.frequency, Frequency.daily,
          reason: 'models.test-fixtures#1');
    });

    test('createEmptyNumericalHabit builds an entry-less numerical habit', () {
      for (final targetType in NumericalHabitType.values) {
        final habit = fixtures.createEmptyNumericalHabit(targetType);

        expect(habit.type, HabitType.numerical,
            reason: 'models.test-fixtures#2');
        expect(habit.isNumerical, isTrue, reason: 'models.test-fixtures#2');
        expect(habit.name, 'Run', reason: 'models.test-fixtures#2');
        expect(habit.question, 'How many miles did you run today?',
            reason: 'models.test-fixtures#2');
        expect(habit.unit, 'miles', reason: 'models.test-fixtures#2');
        expect(habit.targetType, targetType,
            reason: 'models.test-fixtures#2');
        expect(habit.targetValue, 2.0, reason: 'models.test-fixtures#2');
        expect(habit.color, const PaletteColor(1),
            reason: 'models.test-fixtures#2');
        expect(habit.originalEntries.getKnown(), isEmpty,
            reason: 'models.test-fixtures#2');
        expect(habit.computedEntries.getKnown(), isEmpty,
            reason: 'models.test-fixtures#2');
      }
    });

    test('createNumericalHabit adds eight values and recomputes', () {
      final habit = fixtures.createNumericalHabit();
      final today = getToday();

      expect(habit.type, HabitType.numerical,
          reason: 'models.test-fixtures#3');
      expect(habit.name, 'Run', reason: 'models.test-fixtures#3');
      expect(habit.question, 'How many miles did you run today?',
          reason: 'models.test-fixtures#3');
      expect(habit.unit, 'miles', reason: 'models.test-fixtures#3');
      expect(habit.targetType, NumericalHabitType.atLeast,
          reason: 'models.test-fixtures#3');
      expect(habit.targetValue, 2.0, reason: 'models.test-fixtures#3');
      expect(habit.color, const PaletteColor(1),
          reason: 'models.test-fixtures#3');

      const times = <int>[0, 1, 3, 5, 7, 8, 9, 10];
      const values = <int>[100, 200, 300, 400, 500, 600, 700, 800];
      final known = habit.originalEntries.getKnown();
      expect(known.length, times.length, reason: 'models.test-fixtures#3');
      for (var i = 0; i < times.length; i++) {
        final entry = habit.originalEntries.get(today.minus(times[i]));
        expect(entry.value, values[i], reason: 'models.test-fixtures#3');
      }

      // recompute() ran: numerical habits copy the original entries over.
      expect(habit.computedEntries.getKnown().length, times.length,
          reason: 'models.test-fixtures#3');
      expect(habit.computedEntries.get(today).value, 100,
          reason: 'models.test-fixtures#3');
      expect(habit.scores[today].value, greaterThan(0.0),
          reason: 'models.test-fixtures#3');
    });

    test('createLongHabit marks 44 days at 3/7 and recomputes', () {
      final habit = fixtures.createLongHabit();
      final today = getToday();

      expect(habit.name, 'Meditate', reason: 'models.test-fixtures#4');
      expect(habit.question, 'Did you meditate this morning?',
          reason: 'models.test-fixtures#4');
      expect(habit.frequency, Frequency(3, 7),
          reason: 'models.test-fixtures#4');
      expect(habit.color, const PaletteColor(4),
          reason: 'models.test-fixtures#4');
      expect(habit.type, HabitType.yesNo, reason: 'models.test-fixtures#4');

      final known = habit.originalEntries.getKnown();
      expect(known.length, _longHabitMarks.length,
          reason: 'models.test-fixtures#4');
      // Verbatim reproduction of the Kotlin marks array.
      expect(
        known.map((e) => today.daysUntil(e.date) * -1).toList(),
        _longHabitMarks.toList()..sort(),
        reason: 'models.test-fixtures#8',
      );
      for (final mark in _longHabitMarks) {
        expect(habit.originalEntries.get(today.minus(mark)).value,
            Entry.yesManual,
            reason: 'models.test-fixtures#4');
      }

      // recompute() ran: the 3/7 frequency fills gaps with YES_AUTO.
      expect(habit.computedEntries.get(today).value, Entry.yesManual,
          reason: 'models.test-fixtures#4');
      expect(habit.computedEntries.get(today.minus(2)).value, Entry.yesAuto,
          reason: 'models.test-fixtures#4');
      expect(habit.scores[today].value, greaterThan(0.0),
          reason: 'models.test-fixtures#4');
    });

    test('createShortHabit writes ten consecutive days with notes', () {
      final habit = fixtures.createShortHabit();
      final today = getToday();

      expect(habit.name, 'Wake up early', reason: 'models.test-fixtures#5');
      expect(habit.question, 'Did you wake up before 6am?',
          reason: 'models.test-fixtures#5');
      expect(habit.frequency, Frequency(2, 3),
          reason: 'models.test-fixtures#5');

      const expectedValues = <int>[
        Entry.yesManual,
        Entry.no,
        Entry.no,
        Entry.yesManual,
        Entry.yesManual,
        Entry.yesManual,
        Entry.no,
        Entry.no,
        Entry.yesManual,
        Entry.yesManual,
      ];
      const expectedNotes = <String>[
        '',
        'Sick',
        'Forgot to do it, really',
        '',
        '',
        '',
        '"Vacation"',
        '',
        '',
        '',
      ];

      expect(habit.originalEntries.getKnown().length, 10,
          reason: 'models.test-fixtures#5');
      for (var i = 0; i < expectedValues.length; i++) {
        final entry = habit.originalEntries.get(today.minus(i));
        expect(entry.value, expectedValues[i],
            reason: 'models.test-fixtures#5');
        expect(entry.notes, expectedNotes[i],
            reason: 'models.test-fixtures#5');
      }
      // The eleventh day back was never written.
      expect(habit.originalEntries.get(today.minus(10)).value, Entry.unknown,
          reason: 'models.test-fixtures#5');
      expect(habit.scores[today].value, greaterThan(0.0),
          reason: 'models.test-fixtures#5');
    });

    test('createLongNumericalHabit builds 100 entries from the reference', () {
      final reference = LocalDate.ymd(2014, 6, 1);
      final habit = fixtures.createLongNumericalHabit(reference);

      expect(habit.type, HabitType.numerical,
          reason: 'models.test-fixtures#6');
      expect(habit.name, 'Walk', reason: 'models.test-fixtures#6');
      expect(habit.question, 'How many steps did you walk today?',
          reason: 'models.test-fixtures#6');
      expect(habit.unit, 'steps', reason: 'models.test-fixtures#6');
      expect(habit.targetType, NumericalHabitType.atLeast,
          reason: 'models.test-fixtures#6');
      expect(habit.targetValue, 100.0, reason: 'models.test-fixtures#6');
      expect(habit.color, const PaletteColor(1),
          reason: 'models.test-fixtures#6');
      expect(habit.originalEntries.getKnown().length, 100,
          reason: 'models.test-fixtures#6');

      // Verbatim reproduction of the Kotlin times/values arrays.
      expect(_longNumericalTimes.length, 100,
          reason: 'models.test-fixtures#8');
      expect(_longNumericalValues.length, 100,
          reason: 'models.test-fixtures#8');
      for (var i = 0; i < _longNumericalTimes.length; i++) {
        final entry =
            habit.originalEntries.get(reference.minus(_longNumericalTimes[i]));
        expect(entry.value, _longNumericalValues[i],
            reason: 'models.test-fixtures#8');
      }

      // recompute() ran.
      expect(habit.computedEntries.getKnown().length, 100,
          reason: 'models.test-fixtures#6');
      expect(habit.computedEntries.get(reference).value, 230,
          reason: 'models.test-fixtures#6');
    });

    test('every fixture is a distinct habit with its own collaborators', () {
      final first = fixtures.createEmptyHabit();
      final second = fixtures.createEmptyHabit();

      expect(identical(first, second), isFalse,
          reason: 'models.test-fixtures#8');
      expect(first.uuid, isNot(second.uuid),
          reason: 'models.test-fixtures#8');
      expect(identical(first.originalEntries, second.originalEntries), isFalse,
          reason: 'models.test-fixtures#8');
      // In-memory fixtures are never auto-added to the habit list; only the
      // SQLite-backed ones are.
      expect(habitList.size(), 0, reason: 'models.test-fixtures#8');
    });
  });
}
