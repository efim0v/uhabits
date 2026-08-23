/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/RewireDBImporter.kt,
/// plus `isSQLite3File` from
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/utils/FileExtensions.kt.
library;

import 'dart:convert';

import '../database/database.dart';
import '../models/entry.dart';
import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_list.dart';
import '../models/model_factory.dart';
import '../models/reminder.dart';
import '../models/weekday_list.dart';
import '../time/local_date.dart';
import 'files.dart';
import 'habit_bull_csv_importer.dart' show AbstractImporter;

/// Port of `org.isoron.uhabits.core.utils.isSQLite3File`.
///
/// ```kotlin
/// suspend fun isSQLite3File(file: UserFile): Boolean {
///     if (!file.exists()) return false
///     val header = file.readBytes(16)
///     return header.decodeToString().startsWith("SQLite format 3")
/// }
/// ```
///
/// Kotlin's `ByteArray.decodeToString()` replaces malformed sequences rather
/// than throwing, which is what `allowMalformed: true` does here.
///
/// It lives in this file because this slice may only create the three importer
/// files; `TickmateDBImporter` and `LoopDBImporter` should import it from here
/// until a shared `lib/src/utils/file_extensions.dart` exists.
Future<bool> isSQLite3File(UserFile file) async {
  if (!await file.exists()) return false;
  final header = await file.readBytes(16);
  return utf8
      .decode(header, allowMalformed: true)
      .startsWith('SQLite format 3');
}

/// Class that imports database files exported by Rewire.
class RewireDBImporter extends AbstractImporter {
  RewireDBImporter(this.habitList, this.modelFactory, this.opener);

  final HabitList habitList;

  final ModelFactory modelFactory;

  final DatabaseOpener opener;

  @override
  Future<bool> canHandle(UserFile file) async {
    if (!await isSQLite3File(file)) return false;
    final db = opener.open(file.pathString);
    final count = db.querySingle(
      "select count(*) from SQLITE_MASTER where name='CHECKINS' or name='UNIT'",
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

  void _createHabits(Database db) {
    db.query(
      'select _id, name, description, schedule, '
      'active_days, repeating_count, days, period '
      'from habits',
      const <String>[],
      (stmt) {
        final id = stmt.getInt(0);
        final name = stmt.getText(1);
        final description = stmt.getTextOrNull(2) ?? '';
        final schedule = stmt.getInt(3);
        final activeDays = stmt.getTextOrNull(4);
        final repeatingCount = stmt.getInt(5);
        final days = stmt.getInt(6);
        final periodIndex = stmt.getInt(7);

        final habit = modelFactory.buildHabit();
        habit.name = name;
        habit.description = description;
        const periods = <int>[7, 31, 365];
        int numerator;
        int denominator;
        switch (schedule) {
          case 0:
            numerator = activeDays!.split(',').length;
            denominator = 7;
          case 1:
            numerator = days;
            denominator = periods[periodIndex];
          case 2:
            numerator = 1;
            denominator = repeatingCount;
          default:
            // Kotlin: `throw IllegalStateException()`.
            throw StateError('');
        }
        habit.frequency = Frequency(numerator, denominator);
        habitList.add(habit);
        _createReminder(db, habit, id);
        _createCheckmarks(db, habit, id);
      },
    );
  }

  void _createCheckmarks(Database db, Habit habit, int rewireHabitId) {
    db.query(
      'select distinct date from checkins where habit_id=? and type=2',
      <String>[rewireHabitId.toString()],
      (stmt) {
        final dateStr = stmt.getText(0);
        final year = int.parse(dateStr.substring(0, 4));
        final month = int.parse(dateStr.substring(4, 6));
        final day = int.parse(dateStr.substring(6, 8));
        habit.originalEntries
            .add(Entry(LocalDate.ymd(year, month, day), Entry.yesManual));
      },
    );
  }

  void _createReminder(Database db, Habit habit, int rewireHabitId) {
    final reminder = db.querySingle<Reminder?>(
      'select time, active_days from reminders where habit_id=? limit 1',
      <String>[rewireHabitId.toString()],
      (stmt) {
        final rewireReminder = stmt.getInt(0);
        if (rewireReminder <= 0 || rewireReminder >= 1440) return null;
        final reminderDays = List<bool>.filled(7, false);
        final activeDaysStr = stmt.getText(1).split(',');
        for (final d in activeDaysStr) {
          // Rewire uses Monday = 0 while WeekdayList uses Sunday = 0.
          final idx = (int.parse(d) + 1) % 7;
          reminderDays[idx] = true;
        }
        final hour = rewireReminder ~/ 60;
        final minute = rewireReminder % 60;
        return Reminder(hour, minute, WeekdayList.fromArray(reminderDays));
      },
    );
    if (reminder != null) {
      habit.reminder = reminder;
      habitList.updateOne(habit);
    }
  }
}
