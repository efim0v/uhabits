import 'package:test/test.dart';
import 'package:uhabits_core/src/sleep/sleep_episode.dart';
import 'package:uhabits_core/src/sleep/sleep_episode_merger.dart';
import 'package:uhabits_core/src/sleep/sleep_segment.dart';

/// An exact UTC midnight, so a test can name times in plain minutes.
const int midnight = 1756080000000;

SleepSegment seg(
  int startMinutes,
  int endMinutes,
  SleepSegmentKind kind, {
  String source = 'watch',
}) =>
    SleepSegment(
      startMillis: midnight + startMinutes * 60000,
      endMillis: midnight + endMinutes * 60000,
      kind: kind,
      sourceId: source,
    );

const SleepSegmentKind core = SleepSegmentKind.asleepCore;
const SleepSegmentKind deep = SleepSegmentKind.asleepDeep;
const SleepSegmentKind rem = SleepSegmentKind.asleepRem;
const SleepSegmentKind unspecified = SleepSegmentKind.asleepUnspecified;
const SleepSegmentKind inBed = SleepSegmentKind.inBed;
const SleepSegmentKind awake = SleepSegmentKind.awake;


/// The night, out of everything the window holds.
///
/// Production does not ask for "the night" — `SleepSync` splits a window into
/// episodes and decides per day which one wins. This is the same measure,
/// spelled out here so the tests below can talk about one night at a time.
SleepEpisode? mainEpisode(
  List<SleepSegment> segments, {
  required int mergeGapMinutes,
  required int utcOffsetMinutes,
}) {
  final List<SleepEpisode> episodes = splitIntoEpisodes(
    segments,
    mergeGapMinutes: mergeGapMinutes,
    utcOffsetAt: (_) => utcOffsetMinutes,
  );
  if (episodes.isEmpty) return null;
  return episodes.reduce((a, b) => b.asleepMinutes > a.asleepMinutes ? b : a);
}

void main() {
  group('segment kinds', () {
    test('every asleep kind counts as sleep and nothing else does', () {
      for (final kind in <SleepSegmentKind>[core, deep, rem, unspecified]) {
        expect(kind.isAsleep, isTrue, reason: 'sleep.merge#5');
      }
      expect(inBed.isAsleep, isFalse, reason: 'sleep.merge#5');
      expect(awake.isAsleep, isFalse, reason: 'sleep.merge#5');
    });
  });

  group('choosing a source', () {
    test('the source with the most sleep wins', () {
      // A watch and a third party app both record the night; only one of them
      // may describe it.
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 60, core, source: 'phone'),
          seg(0, 420, core, source: 'watch'),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.sourceId, 'watch', reason: 'sleep.merge#1');
      expect(episode.asleepMinutes, 420, reason: 'sleep.merge#1');
    });

    test('the loser contributes nothing at all', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 420, core, source: 'watch'),
          seg(0, 600, inBed, source: 'phone'),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      // The phone's in-bed span must not widen the watch's night.
      expect(episode.bedStartMillis, midnight, reason: 'sleep.merge#1');
      expect(episode.wakeEndMillis, midnight + 420 * 60000,
          reason: 'sleep.merge#1');
      expect(episode.derivedFromAsleep, isTrue, reason: 'sleep.merge#1');
    });

    test('ties are broken deterministically by source id', () {
      // Two sources with identical sleep must not let query order decide.
      for (final order in <List<String>>[
        <String>['bbb', 'aaa'],
        <String>['aaa', 'bbb'],
      ]) {
        final episode = mainEpisode(
          <SleepSegment>[
            seg(0, 60, core, source: order[0]),
            seg(0, 60, core, source: order[1]),
          ],
          mergeGapMinutes: 60,
          utcOffsetMinutes: 0,
        )!;
        expect(episode.sourceId, 'aaa', reason: 'sleep.merge#2');
      }
    });
  });

  group('chaining', () {
    test('a gap at the threshold merges', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 120, core),
          seg(180, 420, core), // exactly sixty minutes apart
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 360, reason: 'sleep.merge#3');
    });

    test('one minute more splits', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 120, core),
          seg(181, 420, core), // sixty one minutes apart
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 239, reason: 'sleep.merge#3');
    });

    test('the chain with the most sleep wins, not the widest', () {
      // The two measures are made to disagree on purpose. The broken night
      // spans 295 minutes but holds only 120 of sleep; the solid one spans
      // 200 and holds all 200. Choosing by span would pick the broken night.
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 30, core),
          seg(85, 115, core),
          seg(175, 205, core),
          seg(265, 295, core),
          seg(400, 600, core),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 200, reason: 'sleep.merge#4');
      expect(episode.bedStartMillis, midnight + 400 * 60000,
          reason: 'sleep.merge#4');
      expect(episode.inBedMinutes, 200, reason: 'sleep.merge#4');
    });

    test('a daytime nap loses to the night', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 400, core), // the night
          seg(840, 900, core), // an hour in the afternoon
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 400, reason: 'sleep.merge#4');
    });

    test('asleep minutes measure the sleep, not the span it covers', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 120, core),
          seg(150, 300, deep),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      // The span is three hundred minutes; the sleep is two hundred and
      // seventy.
      expect(episode.asleepMinutes, 270, reason: 'sleep.merge#5');
      expect(episode.inBedMinutes, 300, reason: 'sleep.merge#5');
    });

    test('an awake stretch never counts as sleep', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 120, core),
          seg(120, 150, awake),
          seg(150, 300, core),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 270, reason: 'sleep.merge#5');
    });

    test('all four asleep kinds add up together', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 60, core),
          seg(60, 120, deep),
          seg(120, 180, rem),
          seg(180, 240, unspecified),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 240, reason: 'sleep.merge#5');
    });

    test('segments arriving out of order are handled', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(150, 300, core),
          seg(0, 120, core),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 270, reason: 'sleep.merge#3');
      expect(episode.bedStartMillis, midnight, reason: 'sleep.merge#3');
    });

    test('a segment nested in a longer one does not cut the chain short', () {
      // The chain end must track the furthest end reached, not the end of the
      // segment that happened to come last. Otherwise the chain would appear
      // to stop at 120 and the 340 stretch would start a second night.
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 300, core),
          seg(60, 120, deep),
          seg(340, 500, core),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.wakeEndMillis, midnight + 500 * 60000,
          reason: 'sleep.merge#3');
      expect(episode.asleepMinutes, 460, reason: 'sleep.merge#5');
    });

    test('overlapping sleep counts each minute once', () {
      // A whole-night sample beside a stage breakdown would otherwise add up
      // to more sleep than the night is long.
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 420, unspecified),
          seg(60, 120, deep),
          seg(200, 260, rem),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, 420, reason: 'sleep.merge#5');
      expect(episode.asleepMinutes,
          lessThanOrEqualTo(episode.inBedMinutes), reason: 'sleep.merge#5');
    });

    test('sleep never exceeds the time in bed', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 480, inBed),
          seg(0, 300, core),
          seg(100, 200, deep),
          seg(280, 460, rem),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.asleepMinutes, lessThanOrEqualTo(episode.inBedMinutes),
          reason: 'sleep.merge#5');
      expect(episode.asleepMinutes, 460, reason: 'sleep.merge#5');
    });
  });

  group('boundaries', () {
    test('in-bed boundaries win over the asleep chain', () {
      // In bed at midnight, asleep at 03:00, up at 08:00.
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 480, inBed),
          seg(180, 480, core),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.bedStartMillis, midnight, reason: 'sleep.merge#6');
      expect(episode.wakeEndMillis, midnight + 480 * 60000,
          reason: 'sleep.merge#6');
      expect(episode.asleepMinutes, 300, reason: 'sleep.merge#6');
      expect(episode.derivedFromAsleep, isFalse, reason: 'sleep.merge#6');
    });

    test('without in-bed data the chain provides the boundaries', () {
      final episode = mainEpisode(
        <SleepSegment>[seg(180, 480, core)],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.bedStartMillis, midnight + 180 * 60000,
          reason: 'sleep.merge#6');
      expect(episode.wakeEndMillis, midnight + 480 * 60000,
          reason: 'sleep.merge#6');
      expect(episode.derivedFromAsleep, isTrue, reason: 'sleep.merge#6');
    });

    test('an in-bed span that misses the chain is ignored', () {
      // An afternoon lie-down must not become the night's bedtime.
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 400, core),
          seg(800, 900, inBed),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.bedStartMillis, midnight, reason: 'sleep.merge#6');
      expect(episode.derivedFromAsleep, isTrue, reason: 'sleep.merge#6');
    });

    test('several in-bed spans give the outermost boundaries', () {
      final episode = mainEpisode(
        <SleepSegment>[
          seg(0, 200, inBed),
          seg(200, 480, inBed),
          seg(60, 460, core),
        ],
        mergeGapMinutes: 60,
        utcOffsetMinutes: 0,
      )!;
      expect(episode.bedStartMillis, midnight, reason: 'sleep.merge#6');
      expect(episode.wakeEndMillis, midnight + 480 * 60000,
          reason: 'sleep.merge#6');
    });
  });

  group('nothing to merge', () {
    test('no segments at all', () {
      expect(
        mainEpisode(const <SleepSegment>[],
            mergeGapMinutes: 60, utcOffsetMinutes: 0),
        isNull,
        reason: 'sleep.merge#4',
      );
    });

    test('in-bed without sleep is not a night', () {
      expect(
        mainEpisode(<SleepSegment>[seg(0, 480, inBed)],
            mergeGapMinutes: 60, utcOffsetMinutes: 0),
        isNull,
        reason: 'sleep.merge#4',
      );
    });

    test('awake only is not a night', () {
      expect(
        mainEpisode(<SleepSegment>[seg(0, 480, awake)],
            mergeGapMinutes: 60, utcOffsetMinutes: 0),
        isNull,
        reason: 'sleep.merge#4',
      );
    });
  });

  group('the offset travels with the night', () {
    test('is carried onto the episode', () {
      final episode = mainEpisode(
        <SleepSegment>[seg(0, 420, core)],
        mergeGapMinutes: 60,
        utcOffsetMinutes: -240,
      )!;
      expect(episode.utcOffsetMinutes, -240, reason: 'sleep.merge#7');
    });
  });
}
