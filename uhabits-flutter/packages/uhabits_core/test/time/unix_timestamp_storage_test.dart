/// `time.unix-conversion#5` — the one rule of the Unix-conversion feature that
/// is about persistence rather than arithmetic: every `Repetitions.timestamp`
/// in the database is the UTC-midnight value produced by `LocalDate.unixTime`,
/// and reading a row back applies no timezone conversion either.
///
/// The Kotlin side of this is `SQLiteEntryList.add`, which writes
/// `entry.timestamp.unixTime`, and `_loadRecords`, which reads it back with
/// `LocalDate.fromUnixTime`. Neither consults a `TimeZone`.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/database/database.dart';
import 'package:uhabits_core/src/database/entry_repository.dart';
import 'package:uhabits_core/src/models/entry.dart';
import 'package:uhabits_core/src/models/sqlite/sqlite_entry_list.dart';
import 'package:uhabits_core/src/time/local_date.dart';

import '../helpers/test_database.dart';

void main() {
  late Database db;
  late EntryRepository repo;
  late SQLiteEntryList entries;
  late int habitId;

  setUp(() {
    db = openMigratedDatabase();
    db.run(
      "insert into Habits(name, freq_num, freq_den, color, position, archived, type) "
      "values ('Test', 1, 1, 0, 0, 0, 0)",
    );
    habitId = db.queryLong('select last_insert_rowid()');
    repo = EntryRepository(db);
    entries = SQLiteEntryList(repo)..habitId = habitId;
  });

  tearDown(() => db.close());

  /// Reads the raw timestamp column, untouched by any model class.
  List<int> rawTimestamps() {
    final stmt = db.prepareStatement(
      'select timestamp from Repetitions where habit = $habitId order by timestamp asc',
    );
    final result = <int>[];
    while (stmt.step() == StepResult.row) {
      result.add(stmt.getLong(0));
    }
    stmt.finalizeStatement();
    return result;
  }

  group('time.unix-conversion', () {
    // Spans a leap day, a year boundary and a pre-2000 date, so a timezone
    // shift of even one hour would move at least one of them to another day.
    final dates = <LocalDate>[
      LocalDate.ymd(1999, 12, 31),
      LocalDate.ymd(2000, 1, 1),
      LocalDate.ymd(2016, 2, 29),
      LocalDate.ymd(2020, 9, 3),
      LocalDate.ymd(2024, 12, 31),
    ];

    test('#5 stored timestamps are UTC midnight of the entry date', () {
      for (final date in dates) {
        entries.add(Entry(date, Entry.yesManual));
      }

      final stored = rawTimestamps();
      expect(stored.length, dates.length,
          reason: 'time.unix-conversion#5 — one row per entry');

      for (var i = 0; i < dates.length; i++) {
        final date = dates[i];
        expect(stored[i], date.unixTime,
            reason: 'time.unix-conversion#5 — the stored timestamp is exactly '
                'LocalDate.unixTime for ${date.toCSVString()}');
        expect(stored[i], LocalDate.epoch2000Millis + date.daysSince2000 * LocalDate.millisPerDay,
            reason: 'time.unix-conversion#5 — it is the pure day-number '
                'arithmetic, with no clock or zone involved');
        expect(
          stored[i],
          DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch,
          reason: 'time.unix-conversion#5 — the value is UTC midnight of that '
              'calendar day, not local midnight',
        );
        expect(stored[i] % LocalDate.millisPerDay, 0,
            reason: 'time.unix-conversion#5 — a whole number of days since the '
                'Unix epoch, so no timezone offset was folded in');
      }
    });

    test('#5 rows read back to the same dates, with no conversion', () {
      for (final date in dates) {
        entries.add(Entry(date, Entry.yesManual));
      }

      final reloaded = SQLiteEntryList(repo)..habitId = habitId;
      for (final date in dates) {
        expect(reloaded.get(date).value, Entry.yesManual,
            reason: 'time.unix-conversion#5 — reading applies no timezone '
                'conversion, so ${date.toCSVString()} round-trips unchanged');
      }
      expect(
        reloaded.getKnown().map((e) => e.date).toList(),
        dates.reversed.toList(),
        reason: 'time.unix-conversion#5 — every stored timestamp maps back '
            'through LocalDate.fromUnixTime to the date it was written for',
      );
    });

    test('#5 a raw row written by an older version reads back verbatim', () {
      // Rows inserted by the importer or by a migration carry the same
      // UTC-midnight value; nothing in the read path shifts them.
      const timestamp = 946684800000 + 5 * 86400000;
      repo.insert(
        EntryData(habitId: habitId, timestamp: timestamp, value: Entry.skip),
      );

      final reloaded = SQLiteEntryList(repo)..habitId = habitId;
      expect(reloaded.get(LocalDate.ymd(2000, 1, 6)).value, Entry.skip,
          reason: 'time.unix-conversion#5 — a raw UTC-midnight timestamp is '
              'interpreted as that calendar day with no zone adjustment');
      expect(rawTimestamps(), [timestamp],
          reason: 'time.unix-conversion#5 — the row is stored verbatim');
    });
  });
}
