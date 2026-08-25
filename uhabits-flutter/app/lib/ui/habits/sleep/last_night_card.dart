import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_time_format.dart';
import 'sleep_card.dart';

/// Last night, and what it was worth.
///
/// The percentage is the number the day's entry holds; the three components
/// below it are why. Showing them is the point — a single number that cannot
/// be argued with is a number nobody learns anything from.
class LastNightCard extends StatelessWidget {
  const LastNightCard({
    required this.theme,
    required this.breakdown,
    required this.habitScore,
    required this.streakDays,
    super.key,
  });

  final core.Theme theme;

  /// Null when there is no night on record for the most recent day.
  final core.SleepBreakdown? breakdown;

  /// The habit's accumulated score, in `[0, 1]`.
  final double habitScore;

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final core.SleepBreakdown? night = breakdown;

    return SleepCard(
      theme: theme,
      title: l10n.sleepLastNight,
      child: night == null
          ? Text(
              l10n.sleepNoData,
              style: TextStyle(
                fontSize: 15,
                color: toFlutterColor(theme.mediumContrastTextColor),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _headline(context, night),
                const SizedBox(height: 14),
                _components(context, night),
                const SizedBox(height: 10),
                Text(
                  _explain(l10n, night),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: toFlutterColor(theme.mediumContrastTextColor),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _headline(BuildContext context, core.SleepBreakdown night) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          '${(night.total * 100).round()}',
          style: TextStyle(
            fontSize: 42,
            height: 1,
            fontWeight: FontWeight.w300,
            color: toFlutterColor(theme.highContrastTextColor),
          ),
        ),
        Text(
          '%',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w300,
            color: toFlutterColor(theme.highContrastTextColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${(habitScore * 100).round()}% · $streakDays',
            style: TextStyle(
              fontSize: 12,
              color: toFlutterColor(theme.mediumContrastTextColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _components(BuildContext context, core.SleepBreakdown night) {
    final L10n l10n = L10n.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _Component(
            theme: theme,
            label: l10n.sleepBedtime,
            value: formatDeviceTime(context, minuteOfDay: night.bedMinutes),
            score: night.scoreBed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Component(
            theme: theme,
            label: l10n.sleepWakeTime,
            value: formatDeviceTime(context, minuteOfDay: night.wakeMinutes),
            score: night.scoreWake,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Component(
            theme: theme,
            label: l10n.sleepDuration,
            value: formatDurationMinutes(night.asleepMinutes),
            score: night.scoreSleep,
          ),
        ),
      ],
    );
  }

  /// Says in words which component cost the most.
  ///
  /// New for this port: nothing else in the app comments on a result. It earns
  /// its place because the model here is not self-evident — three components
  /// combined geometrically — and a person who cannot see why a good night
  /// scored 70 will conclude the number is arbitrary.
  String _explain(L10n l10n, core.SleepBreakdown night) {
    if (night.total >= 0.95) return l10n.sleepPerfectNight;
    switch (night.weakest) {
      case core.SleepComponent.sleep:
        return l10n.sleepWeakestSleep;
      case core.SleepComponent.bed:
        return l10n.sleepWeakestBed;
      case core.SleepComponent.wake:
        return l10n.sleepWeakestWake;
    }
  }
}

class _Component extends StatelessWidget {
  const _Component({
    required this.theme,
    required this.label,
    required this.value,
    required this.score,
  });

  final core.Theme theme;
  final String label;
  final String value;
  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: toFlutterColor(theme.contrast20)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: toFlutterColor(theme.mediumContrastTextColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: toFlutterColor(theme.highContrastTextColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${(score * 100).round()}%',
            style: TextStyle(fontSize: 12, color: scoreColor(theme, score)),
          ),
        ],
      ),
    );
  }
}
