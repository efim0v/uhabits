import 'sleep_episode.dart';
import 'sleep_segment.dart';

/// Reduces the raw stretches recorded for one night to a single episode.
///
/// Returns null when there is no sleep among them: a night with nothing but
/// time in bed is not a night that can be scored.
SleepEpisode? mergeSegments(
  List<SleepSegment> segments, {
  required int mergeGapMinutes,
  required int utcOffsetMinutes,
}) {
  if (segments.isEmpty) return null;

  final _SourceGroup? group = _bestSource(segments);
  if (group == null) return null;

  final List<SleepSegment> asleep =
      group.segments.where((s) => s.kind.isAsleep).toList()
        ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
  if (asleep.isEmpty) return null;

  final _Chain chain = _bestChain(asleep, mergeGapMinutes);

  // Only in-bed stretches that overlap the sleep describe this night. An
  // afternoon lie-down must not become the night's bedtime.
  final Iterable<SleepSegment> inBed = group.segments
      .where((s) => s.kind == SleepSegmentKind.inBed)
      .where((s) => s.endMillis > chain.start && s.startMillis < chain.end);

  final int bedStart = inBed.isEmpty
      ? chain.start
      : inBed.map((s) => s.startMillis).reduce((a, b) => a < b ? a : b);
  final int wakeEnd = inBed.isEmpty
      ? chain.end
      : inBed.map((s) => s.endMillis).reduce((a, b) => a > b ? a : b);

  return SleepEpisode(
    bedStartMillis: bedStart,
    wakeEndMillis: wakeEnd,
    asleepMinutes: chain.asleepMinutes,
    utcOffsetMinutes: utcOffsetMinutes,
    derivedFromAsleep: inBed.isEmpty,
    sourceId: group.sourceId,
  );
}

class _SourceGroup {
  const _SourceGroup(this.sourceId, this.segments);

  final String sourceId;
  final List<SleepSegment> segments;
}

/// Picks the one source that describes this night.
///
/// A watch and a third party app routinely record the same hours; taking both
/// would double the night. The source that recorded the most sleep wins, and
/// an exact tie is broken by source id so that the answer never depends on the
/// order the samples came back in.
_SourceGroup? _bestSource(List<SleepSegment> segments) {
  final bySource = <String, List<SleepSegment>>{};
  for (final segment in segments) {
    (bySource[segment.sourceId] ??= <SleepSegment>[]).add(segment);
  }

  _SourceGroup? best;
  var bestTotal = -1;
  for (final sourceId in bySource.keys.toList()..sort()) {
    final List<SleepSegment> group = bySource[sourceId]!;
    final int total = asleepMinutesOf(group);
    if (total > bestTotal) {
      bestTotal = total;
      best = _SourceGroup(sourceId, group);
    }
  }
  return best;
}

/// How long the person was asleep across [segments], counting each minute
/// once.
///
/// The measure of the union, not the sum of the lengths. Sources can emit
/// overlapping stretches — a whole-night sample beside a stage breakdown, a
/// stage restated — and adding those up yields more sleep than the night is
/// long, which is not a quantity anybody wants scored. On the disjoint
/// stretches that Apple normally writes, the two agree exactly.
int asleepMinutesOf(Iterable<SleepSegment> segments) {
  final List<SleepSegment> asleep = segments
      .where((s) => s.kind.isAsleep)
      .toList()
    ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
  if (asleep.isEmpty) return 0;

  var totalMillis = 0;
  int spanStart = asleep.first.startMillis;
  int spanEnd = asleep.first.endMillis;
  for (final segment in asleep.skip(1)) {
    if (segment.startMillis > spanEnd) {
      totalMillis += spanEnd - spanStart;
      spanStart = segment.startMillis;
      spanEnd = segment.endMillis;
    } else if (segment.endMillis > spanEnd) {
      spanEnd = segment.endMillis;
    }
  }
  totalMillis += spanEnd - spanStart;
  return totalMillis ~/ 60000;
}

class _Chain {
  _Chain(SleepSegment first)
      : start = first.startMillis,
        end = first.endMillis,
        segments = <SleepSegment>[first];

  final int start;
  int end;
  final List<SleepSegment> segments;

  int get asleepMinutes => asleepMinutesOf(segments);

  void add(SleepSegment segment) {
    segments.add(segment);
    // Track the furthest end, not the latest segment's end: stretches can
    // overlap, and a short one nested inside a long one must not cut the
    // chain short and split the night in two.
    if (segment.endMillis > end) end = segment.endMillis;
  }
}

/// Groups sleep into chains across short awakenings and returns the one
/// holding the most sleep.
///
/// Most, not widest: three scattered half hours spanning four hours are not a
/// better night than five unbroken ones, and a daytime nap must never win over
/// the night.
_Chain _bestChain(List<SleepSegment> asleep, int mergeGapMinutes) {
  final chains = <_Chain>[_Chain(asleep.first)];
  for (final segment in asleep.skip(1)) {
    final int gapMinutes = (segment.startMillis - chains.last.end) ~/ 60000;
    if (gapMinutes <= mergeGapMinutes) {
      chains.last.add(segment);
    } else {
      chains.add(_Chain(segment));
    }
  }
  return chains.reduce((a, b) => b.asleepMinutes > a.asleepMinutes ? b : a);
}
