/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/HabitsCSVExporter.kt
/// and of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/tasks/ExportCSVTask.kt
/// with its one-method listener from `ExportCSVListener.kt`.
///
/// The task lives here rather than under `lib/src/tasks/` because the parity
/// slice that owns `io.export-csv-task` owns this file and no other; the Kotlin
/// names are kept verbatim so the port stays traceable.
///
/// Exact file names, header rows, column order and number formatting are the
/// contract: users diff these files against spreadsheets, and the reference
/// output is checked into uhabits-core/assets/test/csv_export/.
library;

import 'dart:io';
import 'dart:typed_data';

import '../computed/lapse_repository.dart';
import '../models/entry_list.dart';
import '../models/habit.dart';
import '../models/habit_list.dart';
import '../sleep/sleep_episode.dart';
import '../sleep/sleep_session_repository.dart';
import '../tasks/task_runner.dart';
import '../time/local_date.dart';
import 'csv.dart';
import 'files.dart';
import 'printf.dart';
import 'zip.dart';

/// Exports the application data to CSV files inside a ZIP archive.
class HabitsCSVExporter {
  HabitsCSVExporter(
    this.allHabits,
    this.selectedHabits, {
    this.sleepRepository,
    this.lapseRepository,
  });

  final HabitList allHabits;

  final List<Habit> selectedHabits;

  /// The nights, when this build has any to export.
  ///
  /// Optional so that a database with no sleep habit produces exactly the
  /// archive the original produces, byte for byte: a file the original never
  /// writes must not appear in an archive that has nothing to put in it.
  final SleepSessionRepository? sleepRepository;

  /// The journal of lapses, when this build has one to export.
  ///
  /// Optional for the same reason [sleepRepository] is: a database with no
  /// abstinence habit must produce exactly the archive the original produces,
  /// byte for byte. A file the original never writes must not appear in an
  /// archive that has nothing to put in it.
  final LapseRepository? lapseRepository;

  final String _delimiter = ',';

  /// Kotlin returns `ByteArray`; `ZipWriter.toBytes()` is a `Future` here, so
  /// the whole method is async, exactly as the Kotlin `suspend fun` is.
  Future<Uint8List> writeArchive() async {
    final zip = ZipWriter();
    zip.addEntry('Habits.csv', allHabits.writeCSV());
    for (final h in selectedHabits) {
      final dirName = habitDirName(h);
      zip.addEntry('${dirName}Scores.csv', _writeScores(h));
      zip.addEntry('${dirName}Checkmarks.csv', _writeEntries(h.computedEntries));
    }
    zip.addEntry('Scores.csv', _writeMultipleHabitsScores());
    zip.addEntry('Checkmarks.csv', _writeMultipleHabitsCheckmarks());
    final String? sessions = _writeSleepSessions();
    if (sessions != null) zip.addEntry('SleepSessions.csv', sessions);
    final String? lapses = _writeLapses();
    if (lapses != null) zip.addEntry('Lapses.csv', lapses);
    return zip.toBytes();
  }

  /// The nights of every selected sleep habit, or null when there are none.
  ///
  /// The percentages themselves are already in Checkmarks.csv, where they read
  /// as an ordinary numerical habit. This file is what those percentages were
  /// computed from, which is the part that cannot be reconstructed.
  String? _writeSleepSessions() {
    final SleepSessionRepository? repository = sleepRepository;
    if (repository == null) return null;

    final rows = StringBuffer();
    var any = false;
    for (final Habit habit in selectedHabits) {
      final int? id = habit.id;
      if (id == null || repository.goalFor(id) == null) continue;
      final int? from = repository.firstDay(id);
      final int? to = repository.lastDay(id);
      if (from == null || to == null) continue;

      final Map<int, SleepEpisode> nights = repository.range(id, from, to);
      for (final int day in nights.keys.toList()..sort()) {
        final SleepEpisode night = nights[day]!;
        any = true;
        rows.write(<String>[
          habit.name,
          LocalDate(day).toString(),
          '${night.bedStartMillis}',
          '${night.wakeEndMillis}',
          '${night.asleepMinutes}',
          '${night.utcOffsetMinutes}',
          night.derivedFromAsleep ? '1' : '0',
          night.sourceId,
        ].join(_delimiter));
        rows.write('\n');
      }
    }
    if (!any) return null;

    return <String>[
      <String>[
        'Habit',
        'Day',
        'BedStart',
        'WakeEnd',
        'AsleepMinutes',
        'UtcOffset',
        'DerivedFromAsleep',
        'Source',
      ].join(_delimiter),
      '\n',
      rows.toString(),
    ].join();
  }

  /// The lapses of every selected abstinence habit, or null when there are
  /// none.
  ///
  /// A file of its own rather than a column in `Habits.csv`: the habits of the
  /// original have no journal, and an empty table in every archive would be a
  /// tax on everybody for the sake of a few. `Checkmarks.csv` already carries
  /// the day values these were computed into; what cannot be reconstructed
  /// from those is the amount as it was measured, in the unit the commitment
  /// names.
  ///
  /// Written exactly as [_writeSleepSessions] is written, down to printing the
  /// day with `LocalDate.toString()`: two `Day` columns in one archive that
  /// disagree about what a day looks like would be two formats for one word.
  /// The fields go in raw, unquoted, for the same reason the sleep rows and
  /// the combined header do — upstream never quotes them, and a habit name
  /// holding a comma corrupts the row. Reproduced deliberately.
  String? _writeLapses() {
    final LapseRepository? repository = lapseRepository;
    if (repository == null) return null;

    final rows = StringBuffer();
    var any = false;
    for (final Habit habit in selectedHabits) {
      final int? id = habit.id;
      if (id == null) continue;
      final int? from = repository.firstDay(id);
      final int? to = repository.lastDay(id);
      if (from == null || to == null) continue;

      final Map<int, int> amounts = repository.range(id, from, to);
      for (final int day in amounts.keys.toList()..sort()) {
        any = true;
        rows.write(<String>[
          habit.name,
          LocalDate(day).toString(),
          '${amounts[day]}',
        ].join(_delimiter));
        rows.write('\n');
      }
    }
    if (!any) return null;

    return <String>[
      <String>['Habit', 'Day', 'Amount'].join(_delimiter),
      '\n',
      rows.toString(),
    ].join();
  }

  /// `format("%03d", allHabits.indexOf(h) + 1) + " " + sane.trim() + "/"`.
  ///
  /// Private in Kotlin; kept visible here only because Dart has no way for the
  /// test to reach a private member, and the folder name is part of the
  /// contract.
  String habitDirName(Habit h) {
    final sane = _sanitizeFilename(h.name);
    return '${format('%03d', allHabits.indexOf(h) + 1)} ${sane.trim()}/';
  }

  /// Removes every character outside `[ a-zA-Z0-9._-]`, then truncates to at
  /// most 100 characters. The truncation happens BEFORE the `.trim()` that
  /// [habitDirName] applies, so a cut that lands on a space loses it.
  String _sanitizeFilename(String name) {
    final s = name.replaceAll(RegExp(r'[^ a-zA-Z0-9._-]+'), '');
    return s.substring(0, s.length < 100 ? s.length : 100);
  }

  String _writeScores(Habit habit) {
    final sb = StringBuffer();
    final today = getToday();
    var oldest = today;
    final known = habit.computedEntries.getKnown();
    if (known.isNotEmpty) oldest = known[known.length - 1].date;
    sb.write(csvLine(<String>['Date', 'Score']));
    for (final s in habit.scores.getByInterval(oldest, today)) {
      sb.write(csvLine(
          <String>[s.date.toCSVString(), format('%.4f', s.value)]));
    }
    return sb.toString();
  }

  String _writeEntries(EntryList entries) {
    final sb = StringBuffer();
    sb.write(csvLine(<String>['Date', 'Value', 'Notes']));
    for (final entry in entries.getKnown()) {
      sb.write(csvLine(<String>[
        entry.date.toCSVString(),
        entry.formattedValue,
        entry.notes,
      ]));
    }
    return sb.toString();
  }

  String _writeMultipleHabitsScores() {
    final sb = StringBuffer();
    _writeMultipleHabitsHeader(sb);
    final timeframe = _getTimeframe();
    final oldest = timeframe[0];
    final newest = getToday();
    final scores = selectedHabits
        .map((it) => it.scores.getByInterval(oldest, newest))
        .toList();
    final days = oldest.daysUntil(newest);
    for (var i = 0; i <= days; i++) {
      final date = newest.minus(i).toCSVString();
      sb.write(date);
      sb.write(_delimiter);
      for (var j = 0; j < selectedHabits.length; j++) {
        final score = format('%.4f', scores[j][i].value);
        sb.write(score);
        sb.write(_delimiter);
      }
      sb.write('\n');
    }
    return sb.toString();
  }

  String _writeMultipleHabitsCheckmarks() {
    final sb = StringBuffer();
    _writeMultipleHabitsHeader(sb);
    final timeframe = _getTimeframe();
    final oldest = timeframe[0];
    final newest = getToday();
    final checkmarks = selectedHabits
        .map((it) => it.computedEntries.getByInterval(oldest, newest))
        .toList();
    final days = oldest.daysUntil(newest);
    for (var i = 0; i <= days; i++) {
      final date = newest.minus(i).toCSVString();
      sb.write(date);
      sb.write(_delimiter);
      for (var j = 0; j < selectedHabits.length; j++) {
        sb.write(checkmarks[j][i].formattedValue);
        sb.write(_delimiter);
      }
      sb.write('\n');
    }
    return sb.toString();
  }

  /// The header of both combined files: `Date,` then every selected habit name
  /// followed by a comma, then a newline.
  ///
  /// The names go in RAW — upstream never quotes them — so a habit name holding
  /// a comma or a double quote corrupts the header. Reproduced verbatim.
  void _writeMultipleHabitsHeader(StringBuffer sb) {
    sb.write('Date$_delimiter');
    for (final habit in selectedHabits) {
      sb.write(habit.name);
      sb.write(_delimiter);
    }
    sb.write('\n');
  }

  /// `[oldest, newest]` over the ORIGINAL entries of the selected habits.
  ///
  /// Habits with no known original entry are skipped, so when none of them has
  /// any, `oldest` keeps the sentinel `LocalDate(1000000)` and the callers'
  /// loops never run. `newest` is computed but unused by both callers, which
  /// take `getToday()` instead; that is upstream behaviour, kept as is.
  List<LocalDate> _getTimeframe() {
    var oldest = LocalDate(1000000);
    var newest = LocalDate(0);
    for (final habit in selectedHabits) {
      final entries = habit.originalEntries.getKnown();
      if (entries.isEmpty) continue;
      final currNew = entries[0].date;
      final currOld = entries[entries.length - 1].date;
      oldest = currOld.isOlderThan(oldest) ? currOld : oldest;
      newest = currNew.isNewerThan(newest) ? currNew : newest;
    }
    return <LocalDate>[oldest, newest];
  }
}

/// Port of `ExportCSVListener`, a Kotlin `fun interface`.
abstract interface class ExportCSVListener {
  void onExportCSVFinished(String? archiveFilename);
}

/// Port of `ExportCSVTask`.
class ExportCSVTask implements Task {
  ExportCSVTask(
    this._habitList,
    this._selectedHabits,
    this._outputDir,
    this._listener, {
    SleepSessionRepository? sleepRepository,
    LapseRepository? lapseRepository,
  })  : _sleepRepository = sleepRepository,
        _lapseRepository = lapseRepository;

  final HabitList _habitList;
  final List<Habit> _selectedHabits;
  final UserFile _outputDir;
  final ExportCSVListener _listener;

  /// Optional, so that a caller with nothing to add produces exactly the
  /// archive the original produces.
  final SleepSessionRepository? _sleepRepository;

  final LapseRepository? _lapseRepository;

  String? _archiveFilename;

  @override
  Future<void> doInBackground() async {
    try {
      final exporter = HabitsCSVExporter(
        _habitList,
        _selectedHabits,
        sleepRepository: _sleepRepository,
        lapseRepository: _lapseRepository,
      );
      final bytes = await exporter.writeArchive();
      final date = getToday().toCSVString();
      final zipFile = _outputDir.resolve('Loop Habits CSV $date.zip');
      await zipFile.writeBytes(bytes);
      _archiveFilename = zipFile.pathString;
    }
    // Kotlin catches `Exception`, which covers IllegalArgumentException,
    // IndexOutOfBoundsException and friends. Their Dart counterparts are
    // `Error` subtypes rather than `Exception`s, so the catch has to be
    // untyped for the two languages to swallow the same failures.
    catch (e, stackTrace) {
      // `e.printStackTrace()`.
      stderr.writeln(e);
      stderr.writeln(stackTrace);
    }
  }

  @override
  void onPostExecute() {
    _listener.onExportCSVFinished(_archiveFilename);
  }

  @override
  void cancel() {}

  @override
  bool isCanceled() => false;

  @override
  void onAttached(TaskRunner runner) {}

  @override
  void onPreExecute() {}

  @override
  void onProgressUpdate(int currentPosition) {}
}
