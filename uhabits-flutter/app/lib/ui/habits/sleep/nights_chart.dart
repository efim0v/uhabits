import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_time_format.dart';
import '../../habits/list/list_header.dart' show IntlLocalDateFormatter;
import 'sleep_card.dart';

/// Every night on record, as bars against the goal.
///
/// Days run left to right and time runs top to bottom — the orientation every
/// other chart in the app uses. A sleep chart is more often drawn the other way
/// round, but a screen where one chart reads sideways is a screen that has to
/// be re-read at every block.
class NightsChart extends StatelessWidget {
  const NightsChart({
    required this.theme,
    required this.color,
    required this.nights,
    required this.skippedDays,
    required this.goal,
    required this.effectiveOffsets,
    required this.lastDay,
    required this.firstDay,
    super.key,
  });

  final core.Theme theme;

  /// The habit's colour, used for a night that scored well.
  final core.Color color;

  /// Nights by day, as `daysSince2000`.
  final Map<int, core.SleepEpisode> nights;

  /// Days the person marked as not applicable.
  final Set<int> skippedDays;

  final core.SleepGoal goal;

  /// Where the goal was living on each day, which is what the target band is
  /// drawn from. During an adaptation the band is a staircase, not a stripe.
  final Map<int, int> effectiveOffsets;

  final int lastDay;

  /// How many days fit on screen before the strip has to be scrolled.
  /// The oldest night the strip reaches. Everything from here to [lastDay] is
  /// scrollable, so the strip is as long as the history is.
  final int firstDay;


  /// Wide enough for a weekday and a date under each bar. The strip scrolls,
  /// so the cost of the extra width is three fewer nights on screen at once,
  /// not three fewer nights.
  static const double dayWidth = 30;
  static const double chartHeight = 158;
  static const double gutterWidth = 44;

  /// Room for the two label rows below the strip.
  static const double labelHeight = 30;

  /// The slice of the clock this strip draws, wide enough for every night in
  /// it.
  SleepWindow get window => SleepWindow.covering(goal: goal, nights: nights);

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final int dayCount = lastDay - firstDay + 1;
    final SleepWindow visible = window;
    final core.LocalDateFormatter formatter =
        IntlLocalDateFormatter.of(context);

    return SleepCard(
      theme: theme,
      title: l10n.sleepNights,
      child: SizedBox(
        height: chartHeight + labelHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: gutterWidth,
              height: chartHeight,
              child: _Gutter(theme: theme, goal: goal, window: visible),
            ),
            Expanded(
              // Built on demand rather than all at once: the strip is as long
              // as the history, and a year of nights is a year of widgets.
              // `reverse` makes index 0 the most recent night, so it opens on
              // last night and grows backwards — which is both the order a
              // person reads it in and the order the list wants to build it.
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: dayCount < 1 ? 0 : dayCount,
                itemBuilder: (BuildContext context, int index) => SizedBox(
                  width: dayWidth,
                  child: _dayStack(lastDay - index, formatter, visible),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One night: its slice of the target band, whatever was recorded over it,
  /// and the date it belongs to.
  ///
  /// Self-contained on purpose. The band used to be a single layer stretched
  /// behind every column, which cannot be built lazily; it was always drawn a
  /// day at a time anyway, because a goal adapting to a new timezone makes it
  /// a staircase rather than a stripe.
  Widget _dayStack(
      int day, core.LocalDateFormatter formatter, SleepWindow visible) {
    return Column(
      children: <Widget>[
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: _TargetBandSegment(
                  theme: theme,
                  goal: goal,
                  offsetMinutes:
                      effectiveOffsets[day] ?? goal.homeUtcOffsetMinutes,
                  window: visible,
                ),
              ),
              if (skippedDays.contains(day))
                Positioned.fill(child: SkippedDayMark(theme: theme, day: day)),
              Positioned.fill(child: _dayColumn(day, visible)),
              // The seam between one night and the next. Barely there on
              // purpose: enough to read the strip as a row of days rather
              // than as one drawing, and not enough to compete with it.
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 1,
                child: ColoredBox(
                  color: toFlutterColor(theme.lowContrastTextColor)
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: labelHeight,
          child: _DayLabel(
            theme: theme,
            day: day,
            formatter: formatter,
            isLast: day == lastDay,
          ),
        ),
      ],
    );
  }

  /// What was recorded for [day], over whatever the day itself says.
  ///
  /// A skipped day still shows its night when there is one: skipping is a
  /// judgement about whether the day counts, not a claim that nothing
  /// happened. It used to replace the bar, so a night on a plane vanished the
  /// moment it was excused.
  Widget _dayColumn(int day, SleepWindow visible) {
    final core.SleepEpisode? episode = nights[day];
    if (episode == null) return const SizedBox.shrink();

    final int offset = effectiveOffsets[day] ?? goal.homeUtcOffsetMinutes;
    final core.SleepBreakdown? breakdown = core.scoreNight(episode, goal, offset);
    if (breakdown == null) return const SizedBox.shrink();

    final double? top = visible.fractionOf(breakdown.bedMinutes);
    final double? bottom = visible.fractionOf(breakdown.wakeMinutes);
    if (top == null || bottom == null || bottom <= top) {
      return const SizedBox.shrink();
    }

    return NightBar(
      theme: theme,
      color: color,
      day: day,
      topFraction: top,
      bottomFraction: bottom,
      score: breakdown.total,
      isLast: day == lastDay,
    );
  }
}

/// One night, as a bar from bedtime down to wake time.
class NightBar extends StatelessWidget {
  const NightBar({
    required this.theme,
    required this.color,
    required this.day,
    required this.topFraction,
    required this.bottomFraction,
    required this.score,
    required this.isLast,
    super.key,
  });

  final core.Theme theme;
  final core.Color color;

  /// `daysSince2000`, so a test can say which column it found.
  final int day;

  final double topFraction;
  final double bottomFraction;
  final double score;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        return Stack(
          children: <Widget>[
            Positioned(
              top: topFraction * height,
              height: (bottomFraction - topFraction) * height,
              left: 3,
              right: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: score < 0.5
                      ? const Color(0xFFF59E0B)
                      : toFlutterColor(color),
                  borderRadius: BorderRadius.circular(5),
                  border: isLast
                      ? Border.all(
                          color: toFlutterColor(theme.highContrastTextColor),
                          width: 1.5,
                        )
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A day the person marked as not applicable.
///
/// Hatched rather than blank: an empty column already means "no data", and a
/// deliberate skip is not the same thing as a night that went unrecorded.
class SkippedDayMark extends StatelessWidget {
  const SkippedDayMark({required this.theme, required this.day, super.key});

  final core.Theme theme;
  final int day;

  @override
  Widget build(BuildContext context) {
    // One filled cell, edge to edge, standing exactly on its own day.
    //
    // It was diagonal hatching, and diagonals do not stop at a column: the
    // strokes of one skipped day ran on into its neighbours, so three excused
    // days read as a week of them. A day is a rectangle, so the mark for a day
    // is a rectangle.
    final Color fill = toFlutterColor(theme.mediumContrastTextColor);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill.withValues(alpha: 0.18),
        border: Border.symmetric(
          vertical: BorderSide(color: fill.withValues(alpha: 0.45)),
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
class _TargetBandSegment extends StatelessWidget {
  const _TargetBandSegment({
    required this.theme,
    required this.goal,
    required this.offsetMinutes,
    required this.window,
  });

  final core.Theme theme;
  final core.SleepGoal goal;

  /// Where the goal was living on this night.
  final int offsetMinutes;

  final SleepWindow window;

  @override
  Widget build(BuildContext context) {
    // The band is where the goal is, which during an adaptation is not where
    // the device's clock is. The shift between the two is exactly the drift.
    final int drift = offsetMinutes - goal.homeUtcOffsetMinutes;
    final double? top = window.fractionOf((goal.bedMinutes + drift) % 1440);
    final double? bottom = window.fractionOf((goal.wakeMinutes + drift) % 1440);
    if (top == null || bottom == null || bottom <= top) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        return Stack(
          children: <Widget>[
            Positioned(
              top: top * height,
              height: (bottom - top) * height,
              left: 0,
              right: 0,
              child: ColoredBox(
                color: toFlutterColor(theme.contrast20).withValues(alpha: 0.45),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The date a column belongs to: weekday over day of month, as the habit list
/// writes its own header.
///
/// Without it the strip is a row of bars a person has to count along to place.
class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.theme,
    required this.day,
    required this.formatter,
    required this.isLast,
  });

  final core.Theme theme;
  final int day;
  final core.LocalDateFormatter formatter;

  /// Last night is named in full contrast; the rest recede.
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final core.LocalDate date = core.LocalDate(day);
    final core.Color colour =
        isLast ? theme.highContrastTextColor : theme.mediumContrastTextColor;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          formatter.shortWeekdayName(date).toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: toFlutterColor(colour),
          ),
        ),
        Text(
          '${date.day}',
          maxLines: 1,
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
            color: toFlutterColor(colour),
          ),
        ),
      ],
    );
  }
}

/// The two goal times, written down the left edge.
/// The clock, written down the left edge.
///
/// Four readings at most: the two ends of the window and the two the goal
/// names. The ends say how far the strip reaches, which is the only way to
/// tell a bar that nearly touches the top from one that was cut off there;
/// the goal says what the band across the middle is.
///
/// Where two would collide, the end wins. A goal time an hour from the edge is
/// already obvious from the band, and two readings printed over each other are
/// worse than one.
class _Gutter extends StatelessWidget {
  const _Gutter({
    required this.theme,
    required this.goal,
    required this.window,
  });

  final core.Theme theme;
  final core.SleepGoal goal;
  final SleepWindow window;

  /// How much of the height two labels need between them, as a fraction.
  static const double _minGap = 0.11;

  @override
  Widget build(BuildContext context) {
    final int endMinutes = (window.startMinutes + window.spanMinutes) % 1440;

    // In order of precedence, so the greedy pass below keeps the ends.
    final List<(double, int)> wanted = <(double, int)>[
      (0, window.startMinutes),
      (1, endMinutes),
      if (window.fractionOf(goal.bedMinutes) case final double f) (f, goal.bedMinutes),
      if (window.fractionOf(goal.wakeMinutes) case final double f) (f, goal.wakeMinutes),
    ];

    final List<(double, int)> kept = <(double, int)>[];
    for (final (double fraction, int minute) in wanted) {
      final bool collides =
          kept.any((k) => (k.$1 - fraction).abs() < _minGap);
      if (!collides) kept.add((fraction, minute));
    }

    final TextStyle style = TextStyle(
      fontSize: 10,
      color: toFlutterColor(theme.mediumContrastTextColor),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        return Stack(
          children: <Widget>[
            for (final (double fraction, int minute) in kept)
              Positioned(
                top: (fraction * height - 6).clamp(0.0, height - 12),
                right: 6,
                child: Text(
                  formatDeviceTime(context, minuteOfDay: minute),
                  style: style,
                ),
              ),
          ],
        );
      },
    );
  }
}
class SleepWindow {
  const SleepWindow({required this.startMinutes, required this.spanMinutes});

  /// Minute of day at the top edge.
  final int startMinutes;

  /// How much of the clock the height covers, in minutes.
  final int spanMinutes;

  /// Breathing room above the earliest bedtime and below the latest waking.
  static const int padMinutes = 60;

  /// The shortest window holding [goal] and every night of [nights].
  ///
  /// Measured as signed offsets from the goal's bedtime, so the arithmetic
  /// never has to care that midnight is in the middle of a night. A night is
  /// an arc from bed forwards to waking, which keeps a night contiguous even
  /// when it crosses the top of the clock.
  static SleepWindow covering({
    required core.SleepGoal goal,
    required Map<int, core.SleepEpisode> nights,
  }) {
    int earliest = -padMinutes;
    int latest = _forward(goal.bedMinutes, goal.wakeMinutes) + padMinutes;

    for (final core.SleepEpisode episode in nights.values) {
      final int bed = core.localMinutesOf(
          episode.bedStartMillis, episode.utcOffsetMinutes);
      final int wake = core.localMinutesOf(
          episode.wakeEndMillis, episode.utcOffsetMinutes);
      final int relBed = _signedFrom(goal.bedMinutes, bed);
      final int relWake = relBed + _forward(bed, wake);
      if (relBed - padMinutes < earliest) earliest = relBed - padMinutes;
      if (relWake + padMinutes > latest) latest = relWake + padMinutes;

    }

    final int span = latest - earliest;
    if (span >= 1440) {
      // Everything at once. Nothing can fall outside a whole day, which is the
      // property that matters more than the wasted height.
      return SleepWindow(startMinutes: goal.bedMinutes % 1440, spanMinutes: 1440);
    }
    return SleepWindow(
      startMinutes: (goal.bedMinutes + earliest) % 1440,
      spanMinutes: span,
    );
  }

  /// Where a time of day sits in the window, as a fraction of the height, or
  /// null when it falls outside.
  double? fractionOf(int minuteOfDay) {
    final int offset = _forward(startMinutes, minuteOfDay);
    if (offset > spanMinutes) return null;
    return offset / spanMinutes;
  }

  /// Minutes from [from] forwards to [to], going the way a clock goes.
  static int _forward(int from, int to) {
    final int d = (to - from) % 1440;
    return d < 0 ? d + 1440 : d;
  }

  /// Minutes from [origin] to [m], signed, in `(-720, 720]`.
  static int _signedFrom(int origin, int m) {
    final int d = _forward(origin, m);
    return d > 720 ? d - 1440 : d;
  }

  @override
  bool operator ==(Object other) =>
      other is SleepWindow &&
      other.startMinutes == startMinutes &&
      other.spanMinutes == spanMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, spanMinutes);

  @override
  String toString() => 'SleepWindow($startMinutes, +$spanMinutes)';
}
