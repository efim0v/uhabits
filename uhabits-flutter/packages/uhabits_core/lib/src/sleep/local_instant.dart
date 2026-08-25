import '../time/date_utils.dart';

/// The UTC instant whose reading on the local clock is [localMillis].
///
/// [TimeZone.getOffset] takes a UTC instant — daylight saving is already
/// folded into its answer — so the offset cannot be looked up at a local
/// value. For most of the year the two agree and the mistake is invisible;
/// within an hour of a change the lookup lands on the wrong side of it and
/// everything computed from it is an hour out. A sleep goal is a wall-clock
/// time, so every one of its instants is a local reading, and an hour is the
/// difference between asking about last night and asking about the one before.
///
/// The first guess is at most one change away from the answer, so refining it
/// once with an instant that is already that close is exact — except inside
/// the changed hour itself, where a local reading either names two instants or
/// none, and no exact answer exists.
int utcInstantOfLocal(int localMillis, TimeZone zone) {
  final int guess = localMillis - zone.getOffset(localMillis);
  return localMillis - zone.getOffset(guess);
}
