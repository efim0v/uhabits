/// Converting a wall-clock reading back to the instant it names.
///
/// A sleep goal is written in wall-clock time — in bed at 23:05, up at 06:45 —
/// so every instant the feature computes starts life as a local reading. The
/// zone answers `getOffset` for a UTC instant, and asking it at the local
/// reading instead is wrong by exactly one hour for the hour after a change:
/// long enough to arm the morning question against the wrong night.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/local_instant.dart';
import 'package:uhabits_core/src/time/date_utils.dart';

const int hour = 3600000;

/// Europe/Moscow never changes; Europe/London does. This is the second.
///
/// Clocks go forward one hour at [changeAt], a UTC instant.
class _SpringForward extends TimeZone {
  const _SpringForward(this.changeAt);

  final int changeAt;

  @override
  int getOffset(int utcMillis) => utcMillis >= changeAt ? 2 * hour : hour;
}

void main() {
  // 2026-03-29 01:00 UTC, which is when the European clocks go forward.
  const int changeAt = 1774746000000;
  const _SpringForward zone = _SpringForward(changeAt);

  test('a reading far from the change is the plain subtraction', () {
    // Midnight local, two days before: offset is one hour on both readings.
    const int local = changeAt - 48 * hour + hour;
    expect(utcInstantOfLocal(local, zone), local - hour,
        reason: 'sleep.time#1');
  });

  test('a reading from the last hour before the change is not', () {
    // Half an hour before the clocks go forward: the instant is still on the
    // old offset, but its local reading has already passed the moment of the
    // change, so a lookup taken at that reading answers with the new one.
    const int instant = changeAt - hour ~/ 2;
    const int local = instant + hour;
    expect(utcInstantOfLocal(local, zone), instant, reason: 'sleep.time#1');
    expect(
      local - zone.getOffset(local),
      instant - hour,
      reason: 'sleep.time#1 — the check is only worth making because the '
          'single lookup puts this one an hour early',
    );
  });

  test('every reading round-trips through the zone', () {
    // The instant it names reads back as the local time it came from, which
    // is the whole definition. Stepped through the day of the change.
    for (int step = -12; step <= 12; step++) {
      // Local 02:00 to 03:00 on the day of the change is a reading no instant
      // has: the clocks step over it.
      if (step == 0) continue;
      final int local = changeAt + hour + step * hour;
      final int utc = utcInstantOfLocal(local, zone);
      expect(utc + zone.getOffset(utc), local,
          reason: 'sleep.time#1 — step $step');
    }
  });

  test('a zone with no change is unaffected', () {
    const FixedTimeZone fixed = FixedTimeZone(5 * hour);
    expect(utcInstantOfLocal(1770000000000, fixed), 1770000000000 - 5 * hour,
        reason: 'sleep.time#1');
  });
}
