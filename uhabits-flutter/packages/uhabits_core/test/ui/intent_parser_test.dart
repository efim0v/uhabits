/// Ported from
/// uhabits-android/src/main/java/org/isoron/uhabits/intents/IntentParser.kt
/// together with the pieces of
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/time/Dates.kt that
/// its timestamp validation leans on.
///
/// Upstream has no Kotlin test for IntentParser, so these assertions are
/// derived from the parity ledger rules; every `expect` carries the rule id it
/// exercises.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/models/habit.dart';
import 'package:uhabits_core/src/models/habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_habit_list.dart';
import 'package:uhabits_core/src/models/memory/memory_model_factory.dart';
import 'package:uhabits_core/src/test/habit_fixtures.dart';
import 'package:uhabits_core/src/time/local_date.dart';
import 'package:uhabits_core/src/ui/intent_parser.dart';

/// The action strings the widget/reminder receivers put on these intents. They
/// are irrelevant to the parser itself, which never looks at the action, but
/// the fixtures set them so the intents look like the real ones.
const String actionAddRepetition = 'org.isoron.uhabits.ACTION_ADD_REPETITION';
const String actionToggleRepetition =
    'org.isoron.uhabits.ACTION_TOGGLE_REPETITION';

void main() {
  late MemoryHabitList habitList;
  late HabitFixtures fixtures;
  late Habit habit;
  late IntentParser parser;
  late int todayMillis;

  setUp(() {
    setToday(LocalDate.ymd(2015, 1, 25));
    todayMillis = getToday().unixTime;
    final modelFactory = MemoryModelFactory();
    habitList = modelFactory.buildHabitList();
    fixtures = HabitFixtures(modelFactory, habitList);
    habit = fixtures.createEmptyHabit();
    habitList.add(habit);
    parser = IntentParser(habitList);
  });

  tearDown(resetToday);

  Intent checkmarkIntent({
    Uri? data,
    String action = actionAddRepetition,
    int? timestamp,
  }) {
    final intent = Intent(action: action, data: data);
    if (timestamp != null) intent.putExtra('timestamp', timestamp);
    return intent;
  }

  group('parseCheckmarkIntent', () {
    test('rejects an intent with no data uri', () {
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent()),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'uri is null')),
        reason: 'intents.parser-validation#1',
      );
      expect(
        () => parser.parseCheckmarkIntent(
            checkmarkIntent(timestamp: todayMillis)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'uri is null')),
        reason: 'intents.parser-validation#1: the uri is checked before the '
            'timestamp, so a perfectly valid timestamp does not save it',
      );
    });

    test('resolves the habit from the id embedded in the data uri', () {
      final second = fixtures.createEmptyHabit(name: 'Run', position: 1);
      habitList.add(second);

      final data = parser
          .parseCheckmarkIntent(checkmarkIntent(data: Uri.parse(habit.uriString)));
      expect(data.habit, same(habit), reason: 'intents.parser-validation#2');

      final secondData = parser.parseCheckmarkIntent(
          checkmarkIntent(data: Uri.parse(second.uriString)));
      expect(secondData.habit, same(second),
          reason: 'intents.parser-validation#2');
      expect(parseContentUriId(Uri.parse(second.uriString)), second.id,
          reason: 'intents.parser-validation#2: the habit id is the last path '
              'segment of the content uri');
    });

    test('rejects an intent whose habit is not on the list', () {
      final uri = Uri.parse(habit.uriString);
      // The notification was posted while the habit still existed; by the time
      // the user taps the action, the habit is gone.
      habitList.remove(habit);

      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(data: uri)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'habit not found')),
        reason: 'intents.parser-validation#2',
      );
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(
            data: Uri.parse('content://org.isoron.uhabits/habit/9999'))),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'habit not found')),
        reason: 'intents.parser-validation#2',
      );
    });

    test('the habit is resolved before the timestamp is validated', () {
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(
          data: Uri.parse('content://org.isoron.uhabits/habit/9999'),
          timestamp: todayMillis + LocalDate.millisPerDay,
        )),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'habit not found')),
        reason: 'intents.parser-validation#2',
      );
    });
  });

  group('parseDate', () {
    test('defaults to today when the intent carries no timestamp', () {
      final data = parser.parseCheckmarkIntent(
          checkmarkIntent(data: Uri.parse(habit.uriString)));
      expect(data.date, LocalDate.ymd(2015, 1, 25),
          reason: 'intents.parser-validation#3');
      expect(data.date.unixTime, todayMillis,
          reason: 'intents.parser-validation#3');
    });

    test('snaps a mid-day timestamp down to local midnight', () {
      for (final offset in <int>[
        1,
        3600 * 1000,
        13 * 3600 * 1000,
        LocalDate.millisPerDay - 1,
      ]) {
        final data = parser.parseCheckmarkIntent(checkmarkIntent(
          data: Uri.parse(habit.uriString),
          timestamp: todayMillis + offset,
        ));
        expect(data.date, LocalDate.ymd(2015, 1, 25),
            reason: 'intents.parser-validation#3: LocalDate.fromUnixTime('
                '$todayMillis + $offset).unixTime normalizes to midnight');
        expect(data.date.unixTime, todayMillis,
            reason: 'intents.parser-validation#3');
      }
    });

    test('accepts a past timestamp', () {
      final yesterday = LocalDate.ymd(2015, 1, 24);
      final data = parser.parseCheckmarkIntent(checkmarkIntent(
        data: Uri.parse(habit.uriString),
        timestamp: yesterday.unixTime,
      ));
      expect(data.date, yesterday, reason: 'intents.parser-validation#3');

      final lastYear = LocalDate.ymd(2014, 3, 9);
      final oldData = parser.parseCheckmarkIntent(checkmarkIntent(
        data: Uri.parse(habit.uriString),
        timestamp: lastYear.unixTime + 7 * 3600 * 1000,
      ));
      expect(oldData.date, lastYear, reason: 'intents.parser-validation#3');
    });

    test('rejects a future timestamp', () {
      final tomorrow = LocalDate.ymd(2015, 1, 26);
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(
          data: Uri.parse(habit.uriString),
          timestamp: tomorrow.unixTime,
        )),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'timestamp is not valid')),
        reason: 'intents.parser-validation#3',
      );
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(
          data: Uri.parse(habit.uriString),
          timestamp: tomorrow.unixTime + 3600 * 1000,
        )),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'timestamp is not valid')),
        reason: 'intents.parser-validation#3',
      );
    });

    test('rejects a timestamp that normalizes to before the unix epoch', () {
      // -1 ms falls on 1969-12-31, whose midnight is -86400000.
      expect(LocalDate.fromUnixTime(-1).unixTime, -LocalDate.millisPerDay,
          reason: 'intents.parser-validation#3');
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(
          data: Uri.parse(habit.uriString),
          timestamp: -1,
        )),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'timestamp is not valid')),
        reason: 'intents.parser-validation#3',
      );
      // A pre-2000 date is still fine as long as it is on or after 1970.
      final oldDate = LocalDate.ymd(1999, 12, 31);
      expect(
        parser
            .parseCheckmarkIntent(checkmarkIntent(
              data: Uri.parse(habit.uriString),
              timestamp: oldDate.unixTime,
            ))
            .date,
        oldDate,
        reason: 'intents.parser-validation#3: only a NEGATIVE normalized '
            'timestamp is rejected, not merely a pre-2000 one',
      );
    });

    test('accepts the first day of the unix epoch but not the day before', () {
      final epochDay = LocalDate.fromUnixTime(0);
      expect(epochDay.unixTime, 0, reason: 'intents.parser-validation#3');
      final data = parser.parseCheckmarkIntent(checkmarkIntent(
        data: Uri.parse(habit.uriString),
        timestamp: LocalDate.millisPerDay - 1,
      ));
      expect(data.date, epochDay,
          reason: 'intents.parser-validation#3: the normalized value is 0, '
              'which is not < 0, so it passes validation');
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(
          data: Uri.parse(habit.uriString),
          timestamp: -LocalDate.millisPerDay,
        )),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'timestamp is not valid')),
        reason: 'intents.parser-validation#3',
      );
    });
  });

  group('consequences of the timestamp window', () {
    test('a notification action tapped for a future date is rejected', () {
      // The widget posted tomorrow's checkmark intent; tapping it today must
      // not write a checkmark into the future.
      expect(
        () => parser.parseCheckmarkIntent(checkmarkIntent(
          action: actionToggleRepetition,
          data: Uri.parse(habit.uriString),
          timestamp: LocalDate.ymd(2015, 1, 26).unixTime,
        )),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'timestamp is not valid')),
        reason: 'intents.parser-validation#4',
      );
    });

    test("yesterday's reminder answered after midnight writes to yesterday",
        () {
      // The reminder fired on 2015-01-24 and carried that day's timestamp; the
      // user answers it at 00:30 on 2015-01-25.
      final intent = checkmarkIntent(
        action: actionToggleRepetition,
        data: Uri.parse(habit.uriString),
        timestamp: LocalDate.ymd(2015, 1, 24).unixTime,
      );
      final data = parser.parseCheckmarkIntent(intent);
      expect(data.date, LocalDate.ymd(2015, 1, 24),
          reason: 'intents.parser-validation#4');
      expect(data.date.isOlderThan(getToday()), isTrue,
          reason: 'intents.parser-validation#4');
    });
  });

  group('copyIntentData', () {
    test('copies the data uri and the timestamp extra', () {
      final source = checkmarkIntent(
        data: Uri.parse(habit.uriString),
        timestamp: LocalDate.ymd(2015, 1, 20).unixTime,
      );
      final destination = Intent();
      parser.copyIntentData(source, destination);

      expect(destination.data, source.data,
          reason: 'intents.parser-validation#5');
      expect(destination.getLongExtra('timestamp', -1),
          LocalDate.ymd(2015, 1, 20).unixTime,
          reason: 'intents.parser-validation#5');
    });

    test("falls back to today's unixTime when the source has no timestamp", () {
      final source = checkmarkIntent(data: Uri.parse(habit.uriString));
      final destination = Intent();
      parser.copyIntentData(source, destination);

      expect(destination.data, Uri.parse(habit.uriString),
          reason: 'intents.parser-validation#5');
      expect(destination.getLongExtra('timestamp', -1), todayMillis,
          reason: 'intents.parser-validation#5');
    });

    test('copies a null data uri as null and overwrites the destination', () {
      final source = checkmarkIntent(timestamp: todayMillis);
      final destination = Intent(data: Uri.parse(habit.uriString));
      destination.putExtra('timestamp', 12345);
      parser.copyIntentData(source, destination);

      expect(destination.data, isNull, reason: 'intents.parser-validation#5');
      expect(destination.getLongExtra('timestamp', -1), todayMillis,
          reason: 'intents.parser-validation#5');
    });
  });

  group('LocalDate unix time arithmetic', () {
    test('unixTime is the 2000 epoch plus whole days', () {
      expect(LocalDate.ymd(2000, 1, 1).unixTime, 946684800000,
          reason: 'intents.parser-validation#6');
      expect(LocalDate(0).unixTime, 946684800000,
          reason: 'intents.parser-validation#6');
      expect(LocalDate(1).unixTime, 946684800000 + 86400000,
          reason: 'intents.parser-validation#6');
      expect(LocalDate(-1).unixTime, 946684800000 - 86400000,
          reason: 'intents.parser-validation#6');
      for (final days in <int>[-10957, -400, -1, 0, 1, 5504, 100000]) {
        expect(LocalDate(days).unixTime, 946684800000 + days * 86400000,
            reason: 'intents.parser-validation#6');
      }
    });

    test('fromUnixTime uses floor division on both sides of the epoch', () {
      int expectedDays(int millis) {
        final diff = millis - 946684800000;
        return diff >= 0
            ? diff ~/ 86400000
            : (diff - 86400000 + 1) ~/ 86400000;
      }

      for (final millis in <int>[
        0,
        -1,
        1,
        946684800000,
        946684800000 - 1,
        946684800000 + 1,
        946684800000 + 86399999,
        946684800000 - 86400000,
        946684800000 - 86400001,
        1422144000000,
        -12345678901234,
      ]) {
        expect(LocalDate.fromUnixTime(millis).daysSince2000,
            expectedDays(millis),
            reason: 'intents.parser-validation#6');
      }

      expect(LocalDate.fromUnixTime(946684800000 - 1).daysSince2000, -1,
          reason: 'intents.parser-validation#6: floor division rounds down, '
              'so one millisecond before the epoch is the previous day');
      expect(LocalDate.fromUnixTime(0).daysSince2000, -10957,
          reason: 'intents.parser-validation#6');
      expect(LocalDate.fromUnixTime(0).unixTime, 0,
          reason: 'intents.parser-validation#6');
    });
  });

  group('IntentParser wiring', () {
    test('the parser resolves habits against the list it was given', () {
      final otherList = MemoryHabitList();
      final otherParser = IntentParser(otherList);
      expect(
        () => otherParser.parseCheckmarkIntent(
            checkmarkIntent(data: Uri.parse(habit.uriString))),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'habit not found')),
        reason: 'intents.parser-validation#7: the parser takes the HabitList '
            'as its single constructor argument',
      );

      final HabitList asHabitList = habitList;
      expect(IntentParser(asHabitList).habits, same(habitList),
          reason: 'intents.parser-validation#7');
    });

    test('CheckmarkIntentData has mutable habit and date fields', () {
      final second = fixtures.createEmptyHabit(name: 'Run', position: 1);
      habitList.add(second);
      final data = parser.parseCheckmarkIntent(
          checkmarkIntent(data: Uri.parse(habit.uriString)));

      expect(data.habit, same(habit), reason: 'intents.parser-validation#7');
      expect(data.date, getToday(), reason: 'intents.parser-validation#7');

      data.habit = second;
      data.date = LocalDate.ymd(2015, 1, 20);
      expect(data.habit, same(second), reason: 'intents.parser-validation#7');
      expect(data.date, LocalDate.ymd(2015, 1, 20),
          reason: 'intents.parser-validation#7');
    });
  });
}
