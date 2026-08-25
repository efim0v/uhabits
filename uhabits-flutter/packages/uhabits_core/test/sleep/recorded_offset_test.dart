/// Which clock a night is dated by.
///
/// A night belongs to the clock the person was living by, not to the clock of
/// whichever device reads it afterwards. Getting this wrong is not a display
/// fault: the offset decides which day the night is filed under, what the goal
/// is compared against, and what the drift model believes about a trip — so a
/// fortnight slept in Tokyo used to rewrite itself the moment the plane landed
/// in Berlin.
library;

import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_episode_merger.dart';
import 'package:uhabits_core/src/sleep/sleep_segment.dart';

const int hour = 3600000;

/// A night from [bed] to [wake], as instants, optionally saying which zone the
/// recording device was keeping.
List<SleepSegment> night({
  required int bed,
  required int wake,
  int? recordedOffset,
  String source = 'watch',
}) =>
    <SleepSegment>[
      SleepSegment(
        startMillis: bed,
        endMillis: wake,
        kind: SleepSegmentKind.asleepUnspecified,
        sourceId: source,
        utcOffsetMinutes: recordedOffset,
      ),
    ];

/// The reading device, wherever it happens to be.
int readingIn(int offsetMinutes) => offsetMinutes;

void main() {
  const int bed = 1787616000000;
  final int wake = bed + 8 * hour;

  group('when the source says which zone it was in', () {
    test('that is the offset the night keeps', () {
      final List<SleepEpisode> episodes = splitIntoEpisodes(
        night(bed: bed, wake: wake, recordedOffset: 540),
        mergeGapMinutes: 60,
        utcOffsetAt: (_) => readingIn(120),
      );

      expect(episodes.single.utcOffsetMinutes, 540,
          reason: 'sleep.timezone#7 — Tokyo, read in Berlin');
    });

    test('the reading device cannot overrule it', () {
      // The same night, read from three different places, comes out the same.
      for (final int here in <int>[-480, 0, 120, 330]) {
        final List<SleepEpisode> episodes = splitIntoEpisodes(
          night(bed: bed, wake: wake, recordedOffset: 540),
          mergeGapMinutes: 60,
          utcOffsetAt: (_) => readingIn(here),
        );
        expect(episodes.single.utcOffsetMinutes, 540,
            reason: 'sleep.timezone#7 — read from $here');
      }
    });
  });

  group('when it does not', () {
    test('the reading device is the answer of last resort', () {
      final List<SleepEpisode> episodes = splitIntoEpisodes(
        night(bed: bed, wake: wake),
        mergeGapMinutes: 60,
        utcOffsetAt: (_) => readingIn(120),
      );

      expect(episodes.single.utcOffsetMinutes, 120,
          reason: 'sleep.timezone#7 — nothing better to go on');
    });
  });

  group('a night that crosses a change', () {
    test('takes the offset of the stretch it woke in', () {
      // Asleep at 23:00 in one zone, awake at 07:00 in the next: the clocks
      // moved, or the plane landed. Waking is the moment that names the day.
      final List<SleepSegment> segments = <SleepSegment>[
        SleepSegment(
          startMillis: bed,
          endMillis: bed + 3 * hour,
          kind: SleepSegmentKind.asleepUnspecified,
          sourceId: 'watch',
          utcOffsetMinutes: 540,
        ),
        SleepSegment(
          startMillis: bed + 3 * hour,
          endMillis: wake,
          kind: SleepSegmentKind.asleepUnspecified,
          sourceId: 'watch',
          utcOffsetMinutes: 600,
        ),
      ];

      final List<SleepEpisode> episodes = splitIntoEpisodes(
        segments,
        mergeGapMinutes: 60,
        utcOffsetAt: (_) => readingIn(120),
      );

      expect(episodes.single.utcOffsetMinutes, 600,
          reason: 'sleep.timezone#7');
    });

    test('a stretch with no offset does not blank the one that has it', () {
      final List<SleepSegment> segments = <SleepSegment>[
        SleepSegment(
          startMillis: bed,
          endMillis: bed + 3 * hour,
          kind: SleepSegmentKind.asleepUnspecified,
          sourceId: 'watch',
          utcOffsetMinutes: 540,
        ),
        SleepSegment(
          startMillis: bed + 3 * hour,
          endMillis: wake,
          kind: SleepSegmentKind.asleepUnspecified,
          sourceId: 'watch',
        ),
      ];

      final List<SleepEpisode> episodes = splitIntoEpisodes(
        segments,
        mergeGapMinutes: 60,
        utcOffsetAt: (_) => readingIn(120),
      );

      expect(episodes.single.utcOffsetMinutes, 540,
          reason: 'sleep.timezone#7 — half a night is better than none');
    });
  });
}
