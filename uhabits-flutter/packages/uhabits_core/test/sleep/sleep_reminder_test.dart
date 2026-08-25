import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_goal.dart';
import 'package:uhabits_core/src/sleep/sleep_reminder.dart';
import 'package:uhabits_core/src/time/date_utils.dart';

/// Lie down at 23:00, get up at 07:00, be asked at 08:00.
const SleepGoal goal = SleepGoal(bedMinutes: 1380, wakeMinutes: 420);

int startOfDay(int day) => (day + 10957) * DateUtils.dayLength;

int at(int day, int minutes) => startOfDay(day) + minutes * 60000;

int localMinutes(int millis, int offset) {
  final int total = (millis ~/ 60000) + offset;
  final int r = total % 1440;
  return r < 0 ? r + 1440 : r;
}

int dayOf(int millis, int offset) =>
    ((millis + offset * 60000) ~/ DateUtils.dayLength) - 10957;

void main() {
  group('when it fires', () {
    test('an hour after the target wake time', () {
      final int prompt = nextSleepPromptMillis(
        goal: goal,
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 300), // 05:00
        todaysNightRecorded: false,
      );
      expect(localMinutes(prompt, 0), 480, reason: 'sleep.reminder#1');
      expect(dayOf(prompt, 0), 9000, reason: 'sleep.reminder#1');
    });

    test('the delay is a setting, not a constant', () {
      final int prompt = nextSleepPromptMillis(
        goal: goal.copyWith(promptAfterWakeMinutes: 150),
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 300),
        todaysNightRecorded: false,
      );
      expect(localMinutes(prompt, 0), 570, reason: 'sleep.reminder#1');
    });

    test('past today, it is tomorrow', () {
      final int prompt = nextSleepPromptMillis(
        goal: goal,
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 600), // 10:00, well past 08:00
        todaysNightRecorded: false,
      );
      expect(dayOf(prompt, 0), 9001, reason: 'sleep.reminder#1');
      expect(localMinutes(prompt, 0), 480, reason: 'sleep.reminder#1');
    });

    test('exactly on the hour counts as past', () {
      final int prompt = nextSleepPromptMillis(
        goal: goal,
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 480),
        todaysNightRecorded: false,
      );
      expect(dayOf(prompt, 0), 9001, reason: 'sleep.reminder#1');
    });

    test('a delay crossing midnight wraps', () {
      // Getting up at 23:30 and asked an hour later is 00:30 the next day.
      final int prompt = nextSleepPromptMillis(
        goal: goal.copyWith(wakeMinutes: 1410),
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 60),
        todaysNightRecorded: false,
      );
      expect(localMinutes(prompt, 0), 30, reason: 'sleep.reminder#1');
    });
  });

  group('when the night is already there', () {
    test('nothing is asked today', () {
      final int prompt = nextSleepPromptMillis(
        goal: goal,
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 300),
        todaysNightRecorded: true,
      );
      expect(dayOf(prompt, 0), 9001, reason: 'sleep.reminder#3');
    });

    test('and tomorrow is still asked at the same time', () {
      final int prompt = nextSleepPromptMillis(
        goal: goal,
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 300),
        todaysNightRecorded: true,
      );
      expect(localMinutes(prompt, 0), 480, reason: 'sleep.reminder#3');
    });
  });

  group('it travels with the goal', () {
    test('a drifting goal takes the prompt with it', () {
      // The goal still lives three hours east of where the person is, so the
      // prompt is three hours earlier by the local clock.
      final int home = nextSleepPromptMillis(
        goal: goal,
        effectiveOffsetMinutes: 0,
        nowMillis: at(9000, 60),
        todaysNightRecorded: false,
      );
      final int drifted = nextSleepPromptMillis(
        goal: goal,
        effectiveOffsetMinutes: 180,
        nowMillis: at(9000, 60),
        todaysNightRecorded: false,
      );
      expect(drifted - home, -180 * 60000, reason: 'sleep.reminder#2');
    });

    test('a non-zero offset is handled at all', () {
      // Every reminder test in the port pins a zero offset, which is the one
      // offset where a mistake in the conversion cannot show.
      for (final int offset in <int>[-480, -240, 60, 330, 720]) {
        final int prompt = nextSleepPromptMillis(
          goal: goal,
          effectiveOffsetMinutes: offset,
          nowMillis: at(9000, 60) - offset * 60000,
          todaysNightRecorded: false,
        );
        expect(localMinutes(prompt, offset), 480,
            reason: 'sleep.reminder#2 (offset $offset)');
        // The time of day alone does not pin this down: reading "now" in the
        // wrong frame lands on the right hour of the wrong day, which is only
        // visible as a prompt more than a day away.
        final int now = at(9000, 60) - offset * 60000;
        expect(prompt, greaterThan(now),
            reason: 'sleep.reminder#2 (offset $offset)');
        expect(prompt - now, lessThanOrEqualTo(DateUtils.dayLength),
            reason: 'sleep.reminder#2 (offset $offset)');
      }
    });
  });

  group('always ahead', () {
    test('whatever the hour, the answer is in the future', () {
      for (var minute = 0; minute < 1440; minute += 7) {
        final int now = at(9000, minute);
        final int prompt = nextSleepPromptMillis(
          goal: goal,
          effectiveOffsetMinutes: 0,
          nowMillis: now,
          todaysNightRecorded: false,
        );
        expect(prompt, greaterThan(now), reason: 'sleep.reminder#1');
        expect(prompt - now, lessThanOrEqualTo(DateUtils.dayLength),
            reason: 'sleep.reminder#1');
      }
    });
  });
}
