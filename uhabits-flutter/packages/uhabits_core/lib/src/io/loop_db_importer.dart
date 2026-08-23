/// Imports data from database files exported by Loop Habit Tracker.
///
/// Ported line by line from
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/LoopDBImporter.kt`,
/// together with the two collaborators it reaches for that have no Dart home
/// yet: the `suspend` variant of `Database.migrateTo` (see [migrateToAsync])
/// and `isSQLite3File` from
/// `uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/utils/FileExtensions.kt`.
///
/// Kotlin makes this an `AbstractImporter` subclass and injects it with
/// `me.tatarka.inject`; there is no Dart port of either yet, so [LoopDBImporter]
/// stands alone and takes its six collaborators as named arguments, in the
/// Kotlin declaration order.
library;

import '../commands/command_runner.dart';
import '../commands/create_habit_command.dart';
import '../commands/edit_habit_command.dart';
import '../database/database.dart';
import '../database/habit_repository.dart';
import '../database/migrations.g.dart';
import '../database/sql_parser.dart';
import '../models/entry.dart';
import '../models/habit_list.dart';
import '../models/model_factory.dart';
import '../models/sqlite/sqlite_habit_list.dart';
import '../time/local_date.dart';
import 'files.dart';
import 'logging.dart';
import 'printf.dart';

/// The `suspend fun Database.migrateTo` of
/// `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Database.kt`.
///
/// `lib/src/database/database.dart` already carries the synchronous half of
/// that extension, whose loader is a plain `String Function(int)`. Loading a
/// migration from a [ResourceFile] is asynchronous here (Kotlin: `suspend`), so
/// the importer needs the awaiting variant. The name differs only because two
/// extension members called `migrateTo` on `Database` would be ambiguous at
/// every call site that imports both files; the body is the same, statement for
/// statement.
extension AsyncDatabaseMigration on Database {
  Future<void> migrateToAsync(
    int targetVersion,
    Future<String> Function(int version) loadMigrationSql, {
    SqlScriptParser parse = SQLParser.parse,
  }) async {
    final currentVersion = getVersion();
    if (currentVersion >= targetVersion) return;
    for (var v = currentVersion + 1; v <= targetVersion; v++) {
      final commands = parse(await loadMigrationSql(v));
      for (final cmd in commands) {
        run(cmd);
      }
      setVersion(v);
    }
  }
}

class LoopDBImporter {
  LoopDBImporter({
    required this.habitList,
    required this.modelFactory,
    required this.opener,
    required this.runner,
    required Logging logging,
    required this.fileOpener,
  }) : logger = logging.getLogger('LoopDBImporter');

  final HabitList habitList;

  final ModelFactory modelFactory;

  final DatabaseOpener opener;

  /// Held for parity with the Kotlin constructor. The commands this importer
  /// issues are executed directly — `CreateHabitCommand(...).run()` — never
  /// handed to the runner, so nothing here touches it.
  final CommandRunner runner;

  final FileOpener fileOpener;

  final Logger logger;

  Future<bool> canHandle(UserFile file) async {
    if (!await _isSQLite3File(file)) return false;
    final db = opener.open(file.pathString);
    var canHandle = true;
    final count = db.querySingle<int>(
      "select count(*) from SQLITE_MASTER where name='Habits' or name='Repetitions'",
      const <String>[],
      (it) => it.getInt(0),
    );
    if (count == null || count != 2) {
      logger.error('Cannot handle file: tables not found');
      canHandle = false;
    }
    if (db.getVersion() > databaseVersion) {
      logger.error('Cannot handle file: incompatible version: '
          '${db.getVersion()} > $databaseVersion');
      canHandle = false;
    }
    db.close();
    return canHandle;
  }

  /// Reads [file] into [habitList].
  ///
  /// The file is migrated to the current schema first, in place: the user's
  /// uploaded copy is modified before a single row is read.
  Future<void> importHabitsFromFile(UserFile file) async {
    final db = opener.open(file.pathString);
    await db.migrateToAsync(databaseVersion, (version) async {
      final filename = format('%02d.sql', version);
      return (await fileOpener.openResourceFile('migrations/$filename').lines())
          .join('\n');
    });

    final habitDataList = loadHabits(db);
    for (final habitData in habitDataList) {
      var habit = habitList.getByUUID(habitData.uuid);

      if (habit == null) {
        // Both `copy(id = …)` calls below are inert in practice: the commands
        // hand the habit to `Habit.copyFrom`, which never copies the id. They
        // are kept because they are what upstream writes.
        habit = modelFactory.buildHabit();
        final imported = _copy(habitData, id: null);
        SQLiteHabitList.copyTo(imported, habit);
        CreateHabitCommand(modelFactory, habitList, habit).run();
      } else {
        final modified = modelFactory.buildHabit();
        SQLiteHabitList.copyTo(_copy(habitData, id: habit.id), modified);
        EditHabitCommand(habitList, habit.id!, modified).run();
      }

      habit = habitList.getByUUID(habitData.uuid)!;
      final entries = habit.originalEntries;

      db.query(
        'SELECT timestamp, value, notes FROM Repetitions WHERE habit = ? '
        'ORDER BY timestamp DESC',
        // Kotlin: `habitData.id.toString()`, on a nullable Long — a row with a
        // NULL id is looked up with the literal text "null", as it is here.
        <String>['${habitData.id}'],
        (stmt) {
          final timestamp = stmt.getLongOrNull(0);
          if (timestamp == null) return;
          final value = stmt.getIntOrNull(1);
          if (value == null) return;
          final notes = stmt.getTextOrNull(2) ?? '';
          final date = LocalDate.fromUnixTime(timestamp);
          final existing = entries.get(date);
          final existingValue = existing.value;
          final existingNotes = existing.notes;
          if (existingValue != value || existingNotes != notes) {
            entries.add(Entry(date, value, notes: notes));
          }
        },
      );
      habit.recompute();
    }
    habitList.resort();
    db.close();
  }

  /// Reads every row of the `Habits` table.
  ///
  /// Kotlin declares this private; it is public here so that the column
  /// defaults can be asserted directly, without importing a whole database.
  static List<HabitData> loadHabits(Database db) {
    final result = <HabitData>[];
    db.query(
      'SELECT id, name, description, question, freq_num, freq_den, color, '
      'position, reminder_hour, reminder_min, reminder_days, highlight, '
      'archived, type, target_value, target_type, unit, uuid '
      'FROM Habits ORDER BY position',
      const <String>[],
      (stmt) {
        result.add(
          HabitData(
            id: stmt.getLongOrNull(0),
            name: stmt.getTextOrNull(1) ?? '',
            description: stmt.getTextOrNull(2) ?? '',
            question: stmt.getTextOrNull(3) ?? '',
            freqNum: stmt.getIntOrNull(4) ?? 1,
            freqDen: stmt.getIntOrNull(5) ?? 1,
            color: stmt.getIntOrNull(6) ?? 0,
            position: stmt.getIntOrNull(7) ?? 0,
            reminderHour: stmt.getIntOrNull(8),
            reminderMin: stmt.getIntOrNull(9),
            reminderDays: stmt.getIntOrNull(10) ?? 0,
            highlight: stmt.getIntOrNull(11) ?? 0,
            archived: stmt.getIntOrNull(12) ?? 0,
            type: stmt.getIntOrNull(13) ?? 0,
            targetValue: stmt.getRealOrNull(14) ?? 0.0,
            targetType: stmt.getIntOrNull(15) ?? 0,
            unit: stmt.getTextOrNull(16) ?? '',
            uuid: stmt.getTextOrNull(17),
          ),
        );
      },
    );
    return result;
  }
}

/// Kotlin's `HabitData.copy(id = …)`. `HabitData` is a `data class` there and a
/// plain mutable class here, so the copy is written out; every other column is
/// carried over unchanged, and the row held by the caller is never mutated.
HabitData _copy(HabitData data, {required int? id}) => HabitData(
      id: id,
      name: data.name,
      description: data.description,
      question: data.question,
      freqNum: data.freqNum,
      freqDen: data.freqDen,
      color: data.color,
      position: data.position,
      reminderHour: data.reminderHour,
      reminderMin: data.reminderMin,
      reminderDays: data.reminderDays,
      highlight: data.highlight,
      archived: data.archived,
      type: data.type,
      targetValue: data.targetValue,
      targetType: data.targetType,
      unit: data.unit,
      uuid: data.uuid,
    );

/// `uhabits-core/.../utils/FileExtensions.kt`.
///
/// Private here because `io.sqlite-magic-detection` belongs to another slice:
/// when the shared helper lands, this copy goes away.
Future<bool> _isSQLite3File(UserFile file) async {
  if (!await file.exists()) return false;
  final header = await file.readBytes(16);
  return String.fromCharCodes(header).startsWith('SQLite format 3');
}
