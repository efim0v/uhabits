import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_locale.dart';
import '../../../state/app_scope.dart';
import 'last_night_card.dart';
import 'manual_entry.dart';
import 'manual_entry_sheet.dart';
import 'nights_chart.dart';
import 'skip_range.dart';
import 'stability_card.dart';
import 'suggestion_card.dart';

/// How many days the skip counter looks back over.
const int skipWindowDays = 30;

/// How many nights the stability figures are drawn from.
const int stabilityWindowDays = 14;

/// The fewest nights worth reporting a spread from.
const int stabilityMinNights = 4;

/// The blocks a sleep habit adds to the top of its screen.
///
/// A function rather than a widget: it produces the same list of cards the
/// ported column produces, and wrapping them in a container of its own would
/// put a seam between the two halves of one screen.
///
/// [onChanged] is how the screen that owns these cards learns it has to
/// repaint. A function has no `setState` of its own, and every block here can
/// change what the others show: marking a range of nights as skipped moves the
/// spread, applying a suggested goal rescores the whole strip, and granting
/// access to the health store fills in nights that were not there a moment
/// ago. Required rather than optional, so that a block added later cannot
/// quietly write and leave the screen showing what was true before.
List<Widget> buildSleepSection(
  BuildContext context, {
  required AppScope scope,
  required core.Habit habit,
  required core.SleepGoal goal,
  required core.Theme theme,
  required VoidCallback onChanged,
}) {
  final int id = habit.id!;
  final int today = scope.sleepSync.today().daysSince2000;

  // The strip reaches back to the first night on record, so that is the window
  // the whole section reads. Nothing else here is hurt by seeing more than it
  // needs: the spread and the counter pick their own days out of it.
  final int chartFirstDay = _chartFirstDay(scope, id, today);
  final Map<int, core.SleepEpisode> nights =
      scope.sleepRepository.range(id, chartFirstDay, today);
  final Map<int, int> offsets = core.effectiveOffsets(
    firstDay: scope.sleepRepository.firstDay(id) ?? today,
    lastDay: today,
    observedByDay: scope.sleepRepository.observedOffsets(
      id,
      scope.sleepRepository.firstDay(id) ?? today,
      today,
    ),
    homeOffsetMinutes: goal.homeUtcOffsetMinutes,
    ratePerDayMinutes: goal.adaptationMinutesPerDay,
  );

  final Set<int> skipped = <int>{
    for (var day = chartFirstDay; day <= today; day++)
      if (habit.originalEntries.get(core.LocalDate(day)).value ==
          core.Entry.skip)
        day,
  };

  // The most recent night there is, which is usually last night but is
  // whatever the watch last uploaded when it is not.
  final int? latestDay = nights.keys.isEmpty
      ? null
      : nights.keys.reduce((int a, int b) => a > b ? a : b);
  final core.SleepBreakdown? lastNight = latestDay == null
      ? null
      : core.scoreNight(
          nights[latestDay]!,
          goal,
          offsets[latestDay] ?? goal.homeUtcOffsetMinutes,
        );

  final int? lastSkipped = lastSkippedDay(
    habit,
    today: today,
    windowDays: skipWindowDays,
  );

  final core.TimezoneSkipSuggestion? travel = core.suggestSkipForTimezone(
    nights,
  );
  final core.GoalSuggestion? suggestedGoal = core.suggestGoal(
    stabilityNights(nights, skipped, today),
    goal,
  );

  return <Widget>[
    // Suggestions come first, because a person who is about to read a bad
    // fortnight should see the offer to set a trip aside before they read it.
    if (travel != null)
      SuggestionCard(
        theme: theme,
        message: L10n.of(context).sleepSuggestSkip,
        applyLabel: L10n.of(context).sleepMarkSkipped,
        onApply: () {
          SkipRange(travel.fromDay, travel.toDay).applyTo(habit);
          _wrote(scope, habit, onChanged);
        },
        onDismiss: () {},
      )
    else if (suggestedGoal != null)
      SuggestionCard(
        theme: theme,
        message: goalSuggestionMessage(context, suggestedGoal),
        applyLabel: L10n.of(context).sleepSuggestApply,
        onApply: () {
          _applyGoalSuggestion(
            scope: scope,
            habit: habit,
            goal: goal,
            suggestion: suggestedGoal,
          );
          _wrote(scope, habit, onChanged);
        },
        onDismiss: () {},
      ),
    LastNightCard(
      theme: theme,
      breakdown: lastNight,
      habitScore: habit.scores[core.LocalDate(today)].value,
      streakDays: _currentStreakDays(habit, today),
      // Always for today, which is the night most likely to be missing or
      // wrong. An older night is edited from the history like any other.
      //
      // Only where there is a store to be refused by. On a platform with none
      // the card would otherwise blame a refusal that never happened, and
      // offer to ask again — an offer that does nothing when taken up.
      healthDenied:
          scope.sleepSync.source.hasHealthStore && !scope.sleepSourceAuthorized,
      onRequestAccess: !scope.sleepSync.source.hasHealthStore
          ? null
          : () async {
              await scope.sleepSync.source.requestAuthorization();
              // The sync is what re-reads the answer into
              // `sleepSourceAuthorized`, and it also brings in the nights the
              // refusal was hiding. Without the repaint the card goes on
              // offering access that has been granted.
              await scope.syncSleepHabits();
              onChanged();
            },
      onEnterByHand: () => enterNightByHand(
        context,
        scope: scope,
        habit: habit,
        goal: goal,
        day: today,
        theme: theme,
        onChanged: onChanged,
      ),
    ),
    NightsChart(
      theme: theme,
      color: theme.color(habit.color.paletteIndex),
      nights: nights,
      skippedDays: skipped,
      goal: goal,
      effectiveOffsets: offsets,
      lastDay: today,
      firstDay: chartFirstDay,
    ),
    StabilityCard(
      theme: theme,
      stability: core.computeStability(
        stabilityNights(nights, skipped, today),
        minNights: stabilityMinNights,
      ),
    ),
    SkipCard(
      theme: theme,
      skippedDays: skippedDayCount(
        habit,
        today: today,
        windowDays: skipWindowDays,
      ),
      windowDays: skipWindowDays,
      lastSkippedLabel: lastSkipped == null
          ? null
          : _formatDay(context, lastSkipped),
      onMark: () =>
          _markRange(context, scope: scope, habit: habit, onChanged: onChanged),
    ),
  ];
}

/// Everything in this file that writes sleep data ends here.
///
/// Two things always follow a write, and neither is optional: the rest of the
/// app is told — the habit list keeps its own copy of every value — and the
/// screen that made the change repaints.
void _wrote(AppScope scope, core.Habit habit, VoidCallback onChanged) {
  scope.onSleepDataChanged(habit.id!);
  onChanged();
}

/// The oldest night the strip reaches.
///
/// The first night on record, so the strip is as long as the history. A habit
/// with nothing recorded yet still gets a fortnight of empty columns rather
/// than a blank card: an empty strip with its goal band and its dates says
/// "nothing here yet" where a void says nothing at all.
int _chartFirstDay(AppScope scope, int habitId, int today) {
  final int? first = scope.sleepRepository.firstDay(habitId);
  final int fallback = today - stabilityWindowDays + 1;
  if (first == null) return fallback;
  return first < fallback ? first : fallback;
}

/// The nights the spread and the goal suggestion are measured from.
///
/// Skips are left out on purpose: one week of travel would otherwise inflate
/// the spread for a fortnight after it, and say the person is erratic when
/// what they were was away. The same list feeds the goal suggestion, so a
/// trip cannot drag the suggested bedtime after it either.
///
/// Public so that the exclusion is testable. It was a rule with nowhere to
/// assert it, which is how a rule quietly stops holding.
List<core.SleepEpisode> stabilityNights(
  Map<int, core.SleepEpisode> nights,
  Set<int> skipped,
  int today, {
  int windowDays = stabilityWindowDays,
}) {
  return <core.SleepEpisode>[
    for (var day = today - windowDays + 1; day <= today; day++)
      if (!skipped.contains(day) && nights.containsKey(day)) nights[day]!,
  ];
}

int _currentStreakDays(core.Habit habit, int today) {
  final List<core.Streak> streaks = habit.streaks.getBest(1);
  if (streaks.isEmpty) return 0;
  final core.Streak last = streaks.first;
  return last.end.daysSince2000 >= today - 1 ? last.length : 0;
}

String _formatDay(BuildContext context, int day) {
  final DateTime date = DateTime.utc(2000, 1, 1).add(Duration(days: day));
  return intl.DateFormat.MMMd(
    resolveDateLocaleName(DeviceLocale.nameOf(context)),
  ).format(date);
}

Future<void> _markRange(
  BuildContext context, {
  required AppScope scope,
  required core.Habit habit,
  required VoidCallback onChanged,
}) async {
  final int today = scope.sleepSync.today().daysSince2000;
  final DateTime origin = DateTime.utc(2000, 1, 1);
  final DateTimeRange? picked = await showDateRangePicker(
    context: context,
    firstDate: origin,
    lastDate: origin.add(Duration(days: today)),
    currentDate: origin.add(Duration(days: today)),
  );
  if (picked == null) return;

  SkipRange(
    picked.start.difference(origin).inDays,
    picked.end.difference(origin).inDays,
  ).applyTo(habit);
  _wrote(scope, habit, onChanged);
}

/// Opens the sheet for a night and stores what comes back.
///
/// The night is stored as a manual one, which the repository then protects
/// from being overwritten by a later read from the platform.
Future<void> enterNightByHand(
  BuildContext context, {
  required AppScope scope,
  required core.Habit habit,
  required core.SleepGoal goal,
  required int day,
  required core.Theme theme,
  required VoidCallback onChanged,
}) async {
  final int offset = scope.sleepSync.currentOffsetMinutes();
  final ManualNight? night = await showManualEntrySheet(
    context,
    theme: theme,
    day: day,
    goal: goal,
    utcOffsetMinutes: offset,
  );
  if (night == null) return;

  final core.SleepEpisode episode = night.toEpisode();
  scope.sleepRepository.upsert(habit.id!, day, episode, manual: true);
  scope.sleepSync.recomputeDays(habit, day, day);
  _wrote(scope, habit, onChanged);
  // Also written back to the platform, so a night typed in here shows up in
  // the health app the rest of the data comes from.
  await scope.sleepSync.source.writeSession(
    episode.bedStartMillis,
    episode.wakeEndMillis,
  );
}

/// Moves the goal to what the recent nights suggest, and rescores everything.
///
/// Only ever reached from a tap: the suggestion itself changes nothing.
void _applyGoalSuggestion({
  required AppScope scope,
  required core.Habit habit,
  required core.SleepGoal goal,
  required core.GoalSuggestion suggestion,
}) {
  final core.SleepGoal moved = goal.copyWith(
    bedMinutes: suggestion.bedMinutes,
    wakeMinutes: suggestion.wakeMinutes,
  );
  scope.sleepRepository.saveGoal(habit.id!, moved);
  // A different goal makes every past night worth something different.
  scope.sleepSync.recomputeAll(habit);
  // Announcing it is the caller's, through [_wrote]: one seam, or the rule
  // has two homes and they will disagree.
}
