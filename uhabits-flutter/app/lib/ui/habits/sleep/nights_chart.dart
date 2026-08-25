import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_time_format.dart';
import 'sleep_card.dart';

/// A fortnight of nights, as bars against the goal.
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
    this.visibleDays = 14,
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
  final int visibleDays;

  /// Nothing is drawn outside this window of the clock.
  ///
  /// Bedtimes cluster in the evening and wake times in the morning, so a full
  /// twenty-four hours would spend two thirds of the height on emptiness.
  static const int windowStartMinutes = 20 * 60;
  static const int windowMinutes = 15 * 60;

  static const double dayWidth = 22;
  static const double chartHeight = 158;
  static const double gutterWidth = 44;

  /// Where a time of day sits in the window, as a fraction of the height.
  ///
  /// Times before the window's start belong to the following evening, so they
  /// wrap forward rather than clamping to the top.
  static double? verticalFraction(int minuteOfDay) {
    int offset = minuteOfDay - windowStartMinutes;
    if (offset < 0) offset += 1440;
    if (offset > windowMinutes) return null;
    return offset / windowMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final int firstDay = lastDay - visibleDays + 1;

    return SleepCard(
      theme: theme,
      title: l10n.sleepNights,
      child: SizedBox(
        height: chartHeight + 22,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: gutterWidth,
              height: chartHeight,
              child: _Gutter(theme: theme, goal: goal),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: SizedBox(
                  width: dayWidth * visibleDays,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: chartHeight,
                        child: Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: _TargetBand(
                                theme: theme,
                                goal: goal,
                                effectiveOffsets: effectiveOffsets,
                                firstDay: firstDay,
                                lastDay: lastDay,
                              ),
                            ),
                            Positioned.fill(
                              child: Row(
                                children: <Widget>[
                                  for (int day = firstDay;
                                      day <= lastDay;
                                      day++)
                                    Expanded(
                                      child: _dayColumn(day),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayColumn(int day) {
    if (skippedDays.contains(day)) {
      return SkippedDayMark(theme: theme, day: day);
    }
    final core.SleepEpisode? episode = nights[day];
    if (episode == null) return const SizedBox.shrink();

    final int offset = effectiveOffsets[day] ?? goal.homeUtcOffsetMinutes;
    final core.SleepBreakdown? breakdown = core.scoreNight(episode, goal, offset);
    if (breakdown == null) return const SizedBox.shrink();

    final double? top = verticalFraction(breakdown.bedMinutes);
    final double? bottom = verticalFraction(breakdown.wakeMinutes);
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
    return CustomPaint(
      painter: _HatchPainter(toFlutterColor(theme.contrast20)),
      child: const SizedBox.expand(),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}

/// The target window, drawn behind the bars.
///
/// One rectangle per day rather than a single stripe: while the goal is
/// catching up with a new timezone it moves an hour a night, and a straight
/// band would quietly misrepresent what the days were judged against.
class _TargetBand extends StatelessWidget {
  const _TargetBand({
    required this.theme,
    required this.goal,
    required this.effectiveOffsets,
    required this.firstDay,
    required this.lastDay,
  });

  final core.Theme theme;
  final core.SleepGoal goal;
  final Map<int, int> effectiveOffsets;
  final int firstDay;
  final int lastDay;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int day = firstDay; day <= lastDay; day++)
          Expanded(child: _bandFor(day)),
      ],
    );
  }

  Widget _bandFor(int day) {
    // The band is where the goal is, which during an adaptation is not where
    // the device's clock is. The shift between the two is exactly the drift.
    final int drift =
        (effectiveOffsets[day] ?? goal.homeUtcOffsetMinutes) -
            goal.homeUtcOffsetMinutes;
    final double? top =
        NightsChart.verticalFraction((goal.bedMinutes + drift) % 1440);
    final double? bottom =
        NightsChart.verticalFraction((goal.wakeMinutes + drift) % 1440);
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

/// The two goal times, written down the left edge.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.theme, required this.goal});

  final core.Theme theme;
  final core.SleepGoal goal;

  @override
  Widget build(BuildContext context) {
    final double? bed = NightsChart.verticalFraction(goal.bedMinutes);
    final double? wake = NightsChart.verticalFraction(goal.wakeMinutes);
    final TextStyle style = TextStyle(
      fontSize: 10,
      color: toFlutterColor(theme.mediumContrastTextColor),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        return Stack(
          children: <Widget>[
            if (bed != null)
              Positioned(
                top: (bed * height - 6).clamp(0.0, height - 12),
                right: 6,
                child: Text(
                  formatDeviceTime(context, minuteOfDay: goal.bedMinutes),
                  style: style,
                ),
              ),
            if (wake != null)
              Positioned(
                top: (wake * height - 6).clamp(0.0, height - 12),
                right: 6,
                child: Text(
                  formatDeviceTime(context, minuteOfDay: goal.wakeMinutes),
                  style: style,
                ),
              ),
          ],
        );
      },
    );
  }
}
