/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/TickmateDBImporter.kt.
library;

import '../database/database.dart';
import '../models/entry.dart';
import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_list.dart';
import '../models/model_factory.dart';
import '../time/local_date.dart';
import 'files.dart';
import 'habit_bull_csv_importer.dart' show AbstractImporter;
import 'rewire_db_importer.dart' show isSQLite3File;

/// Class that imports data from database files exported by Tickmate.
class TickmateDBImporter extends AbstractImporter {
  TickmateDBImporter(this.habitList, this.modelFactory, this.opener);

  final HabitList habitList;

  final ModelFactory modelFactory;

  final DatabaseOpener opener;

  @override
  Future<bool> canHandle(UserFile file) async {
    if (!await isSQLite3File(file)) return false;
    final db = opener.open(file.pathString);
    final count = db.querySingle(
      "select count(*) from SQLITE_MASTER where name='tracks' "
      "or name='track2groups'",
      const <String>[],
      (stmt) => stmt.getInt(0),
    );
    db.close();
    return count == 2;
  }

  @override
  Future<void> importHabitsFromFile(UserFile file) async {
    final db = opener.open(file.pathString);
    db.begin();
    _createHabits(db);
    db.commit();
    db.close();
  }

  void _createCheckmarks(Database db, Habit habit, int tickmateTrackId) {
    db.query(
      'select distinct year, month, day from ticks where _track_id=?',
      <String>[tickmateTrackId.toString()],
      (stmt) {
        final year = stmt.getInt(0);
        final month = stmt.getInt(1);
        final day = stmt.getInt(2);
        // Tickmate months are 0-based.
        habit.originalEntries
            .add(Entry(LocalDate.ymd(year, month + 1, day), Entry.yesManual));
      },
    );
  }

  void _createHabits(Database db) {
    db.query(
      'select _id, name, description from tracks',
      const <String>[],
      (stmt) {
        final id = stmt.getInt(0);
        final name = stmt.getText(1);
        final description = stmt.getTextOrNull(2) ?? '';
        final habit = modelFactory.buildHabit();
        habit.name = name;
        habit.description = description;
        habit.frequency = Frequency.daily;
        habitList.add(habit);
        _createCheckmarks(db, habit, id);
      },
    );
  }
}
