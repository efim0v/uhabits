/// The timezone a sleep goal is currently living in, day by day.
///
/// A goal follows local time, but not at once: it catches up at a fixed rate,
/// the way a body adapts. Which raises the question of where the goal is on
/// any given day — and that answer must be derived, never stored. Stored, it
/// would depend on when the app happened to be opened, and history would stop
/// being recomputable.
///
/// [observedByDay] holds the offset actually recorded for each night, keyed by
/// `daysSince2000`. Days without a night inherit the nearest earlier
/// observation, falling back to [homeOffsetMinutes].
///
/// The step is driven by the *previous* day's observation. A body does not
/// adapt within the night it lands, so the first night in a new timezone is
/// still judged against the old one.
Map<int, int> effectiveOffsets({
  required int firstDay,
  required int lastDay,
  required Map<int, int> observedByDay,
  required int homeOffsetMinutes,
  required int ratePerDayMinutes,
}) {
  final result = <int, int>{};
  if (lastDay < firstDay) return result;

  final int rate = ratePerDayMinutes.abs();
  int current = homeOffsetMinutes;
  int lastObserved = observedByDay[firstDay] ?? homeOffsetMinutes;
  result[firstDay] = current;

  for (var day = firstDay + 1; day <= lastDay; day++) {
    current += (lastObserved - current).clamp(-rate, rate);
    result[day] = current;
    lastObserved = observedByDay[day] ?? lastObserved;
  }
  return result;
}
