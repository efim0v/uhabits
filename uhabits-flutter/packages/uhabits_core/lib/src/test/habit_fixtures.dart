import '../models/entry.dart';
import '../models/entry_list.dart';
import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_list.dart';
import '../models/habit_type.dart';
import '../models/model_factory.dart';
import '../models/palette_color.dart';
import '../models/sqlite/sqlite_entry_list.dart';
import '../time/local_date.dart';

/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/test/HabitFixtures.kt
///
/// This ships in the production source set, exactly as it does in Kotlin: the
/// Android instrumentation tests build fixtures from the installed app, so the
/// class cannot live under `test/`.
///
/// Every fixture must stay byte-for-byte faithful to the Kotlin original — the
/// expected score and streak vectors in the ported tests are derived from these
/// exact dates and values.
class HabitFixtures {
  HabitFixtures(this._modelFactory, this._habitList);

  final ModelFactory _modelFactory;

  final HabitList _habitList;

  static const List<bool> _nonDailyHabitChecks = <bool>[
    true, false, false, true, true, true, false, false, true, true, //
  ];

  static const List<String> _nonDailyHabitNotes = <String>[
    '', 'Sick', 'Forgot to do it, really', '', '', '', '"Vacation"', '', '', '',
  ];

  Habit createEmptyHabit({
    String name = 'Meditate',
    PaletteColor color = const PaletteColor(3),
    int position = 0,
  }) {
    final habit = _modelFactory.buildHabit();
    habit.name = name;
    habit.question = 'Did you meditate this morning?';
    habit.color = color;
    habit.position = position;
    habit.frequency = Frequency.daily;
    _saveIfSqlite(habit);
    return habit;
  }

  Habit createEmptyNumericalHabit(NumericalHabitType targetType) {
    final habit = _modelFactory.buildHabit();
    habit.type = HabitType.numerical;
    habit.name = 'Run';
    habit.question = 'How many miles did you run today?';
    habit.unit = 'miles';
    habit.targetType = targetType;
    habit.targetValue = 2.0;
    habit.color = const PaletteColor(1);
    _saveIfSqlite(habit);
    return habit;
  }

  Habit createLongHabit() {
    final habit = createEmptyHabit();
    habit.frequency = Frequency(3, 7);
    habit.color = const PaletteColor(4);
    final today = getToday();
    const marks = <int>[
      0, 1, 3, 5, 7, 8, 9, 10, 12, 14, 15, 17, 19, 20, 26, 27, //
      28, 50, 51, 52, 53, 54, 58, 60, 63, 65, 70, 71, 72, 73, 74, 75, 80,
      81, 83, 89, 90, 91, 95, 102, 103, 108, 109, 120,
    ];
    for (final mark in marks) {
      habit.originalEntries.add(Entry(today.minus(mark), Entry.yesManual));
    }
    habit.recompute();
    return habit;
  }

  Habit createNumericalHabit() {
    final habit = _modelFactory.buildHabit();
    habit.type = HabitType.numerical;
    habit.name = 'Run';
    habit.question = 'How many miles did you run today?';
    habit.unit = 'miles';
    habit.targetType = NumericalHabitType.atLeast;
    habit.targetValue = 2.0;
    habit.color = const PaletteColor(1);
    _saveIfSqlite(habit);
    final today = getToday();
    const times = <int>[0, 1, 3, 5, 7, 8, 9, 10];
    const values = <int>[100, 200, 300, 400, 500, 600, 700, 800];
    for (var i = 0; i < times.length; i++) {
      final timestamp = today.minus(times[i]);
      habit.originalEntries.add(Entry(timestamp, values[i]));
    }
    habit.recompute();
    return habit;
  }

  Habit createLongNumericalHabit(LocalDate reference) {
    final habit = _modelFactory.buildHabit();
    habit.type = HabitType.numerical;
    habit.name = 'Walk';
    habit.question = 'How many steps did you walk today?';
    habit.unit = 'steps';
    habit.targetType = NumericalHabitType.atLeast;
    habit.targetValue = 100.0;
    habit.color = const PaletteColor(1);
    _saveIfSqlite(habit);
    const times = <int>[
      0, 5, 9, 15, 17, 21, 23, 27, 28, 35, 41, 45, 47, 53, 56, 62, 70, 73, 78,
      83, 86, 94, 101, 106, 113, 114, 120, 126, 130, 133, 141, 143, 148, 151,
      157, 164,
      166, 171, 173, 176, 179, 183, 191, 259, 264, 268, 270, 275, 282, 284,
      289, 295,
      302, 306, 310, 315, 323, 325, 328, 335, 343, 349, 351, 353, 357, 359,
      360, 367,
      372, 376, 380, 385, 393, 400, 404, 412, 415, 418, 422, 425, 433, 437,
      444, 449,
      455, 460, 462, 465, 470, 471, 479, 481, 485, 489, 494, 495, 500, 501,
      503, 507,
    ];
    const values = <int>[
      230, 306, 148, 281, 134, 285, 104, 158, 325, 236, 303, 210, 118, 124,
      301, 201, 156, 376, 347, 367, 396, 134, 160, 381, 155, 354, 231, 134,
      164, 354,
      236, 398, 199, 221, 208, 397, 253, 276, 214, 341, 299, 221, 353, 250,
      341, 168,
      374, 205, 182, 217, 297, 321, 104, 237, 294, 110, 136, 229, 102, 271,
      250, 294,
      158, 319, 379, 126, 282, 155, 288, 159, 215, 247, 207, 226, 244, 158,
      371, 219,
      272, 228, 350, 153, 356, 279, 394, 202, 213, 214, 112, 248, 139, 245,
      165, 256,
      370, 187, 208, 231, 341, 312,
    ];
    for (var i = 0; i < times.length; i++) {
      final timestamp = reference.minus(times[i]);
      habit.originalEntries.add(Entry(timestamp, values[i]));
    }
    habit.recompute();
    return habit;
  }

  Habit createShortHabit() {
    final habit = _modelFactory.buildHabit();
    habit.name = 'Wake up early';
    habit.question = 'Did you wake up before 6am?';
    habit.frequency = Frequency(2, 3);
    _saveIfSqlite(habit);
    var timestamp = getToday();
    for (var i = 0; i < _nonDailyHabitChecks.length; i++) {
      var value = Entry.no;
      if (_nonDailyHabitChecks[i]) value = Entry.yesManual;
      habit.originalEntries
          .add(Entry(timestamp, value, notes: _nonDailyHabitNotes[i]));
      timestamp = timestamp.minus(1);
    }
    habit.recompute();
    return habit;
  }

  /// Kotlin: `if (habit.originalEntries !is SQLiteEntryList) return;
  /// habitList.add(habit)`. Database-backed entry lists write themselves
  /// through, so those fixtures must also be registered in the habit list;
  /// in-memory ones are handed back unregistered.
  void _saveIfSqlite(Habit habit) {
    if (!_isSqliteBacked(habit.originalEntries)) return;
    _habitList.add(habit);
  }

  /// Kotlin: `habit.originalEntries !is SQLiteEntryList`, negated.
  ///
  /// A habit built by `SQLModelFactory` gets an [SQLiteEntryList] for its
  /// original entries; a habit built by `MemoryModelFactory` gets a plain
  /// [EntryList].
  bool _isSqliteBacked(EntryList entries) => entries is SQLiteEntryList;
}
