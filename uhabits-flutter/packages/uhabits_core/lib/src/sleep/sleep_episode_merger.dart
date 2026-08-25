import 'sleep_episode.dart';
import 'sleep_segment.dart';

/// Every night in a window, one episode per chain of sleep.
///
/// The same rules as [mergeSegments] — one source, chains across short
/// awakenings, in-bed boundaries where there are any — applied across a span
/// of days rather than a single night. Sharing the implementation is the point:
/// a second copy of these rules would be carried forward in one place and not
/// the other.
///
/// [utcOffsetAt] gives the offset in force at an instant, so a window that
/// crosses a flight or a daylight saving change describes each night in the
/// offset that night actually had.
List<SleepEpisode> splitIntoEpisodes(
  List<SleepSegment> segments, {
  required int mergeGapMinutes,
  required int Function(int instantMillis) utcOffsetAt,
}) {
  if (segments.isEmpty) return const <SleepEpisode>[];

  final _SourceGroup? group = _bestSource(segments);
  if (group == null) return const <SleepEpisode>[];

  final List<SleepSegment> asleep =
      group.segments.where((s) => s.kind.isAsleep).toList()
        ..sort((a, b) => a.startMillis.compareTo(b.startMillis));
  if (asleep.isEmpty) return const <SleepEpisode>[];

  return <SleepEpisode>[
    for (final _Chain chain in _chains(asleep, mergeGapMinutes))
      _episodeFrom(chain, group, utcOffsetAt),
  ];
}

/// Builds the episode a chain describes, taking its boundaries from the in-bed
/// stretches that overlap it when there are any.
SleepEpisode _episodeFrom(
  _Chain chain,
  _SourceGroup group,
  int Function(int) utcOffsetAt,
) {
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
    // The offset of the moment the person woke, which is the moment that
    // decides which day the night belongs to.
    utcOffsetMinutes: utcOffsetAt(wakeEnd),
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

/// Groups sleep into chains across short awakenings.
///
/// Chains are what nights are made of. Which chain wins, where there has to be
/// a winner, is decided by how much sleep it holds — not how wide it is: three
/// scattered half hours spanning four hours are not a better night than five
/// unbroken ones, and a daytime nap must never win over the night.
List<_Chain> _chains(List<SleepSegment> asleep, int mergeGapMinutes) {
  final chains = <_Chain>[_Chain(asleep.first)];
  for (final segment in asleep.skip(1)) {
    final int gapMinutes = (segment.startMillis - chains.last.end) ~/ 60000;
    if (gapMinutes <= mergeGapMinutes) {
      chains.last.add(segment);
    } else {
      chains.add(_Chain(segment));
    }
  }
  return chains;
}
