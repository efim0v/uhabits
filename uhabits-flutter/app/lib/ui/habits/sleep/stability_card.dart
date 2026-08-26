import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import 'sleep_card.dart';

/// How regular the last fortnight was.
///
/// Three numbers rather than a score: a spread in minutes is a quantity a
/// person can act on — "half an hour either side" means something — where a
/// regularity percentage would have to be learned before it meant anything.
class StabilityCard extends StatelessWidget {
  const StabilityCard({
    required this.theme,
    required this.stability,
    super.key,
  });

  final core.Theme theme;

  /// Null when too few nights are on record to say anything.
  final core.SleepStability? stability;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final core.SleepStability? value = stability;

    return SleepCard(
      theme: theme,
      title: l10n.sleepStability,
      child: value == null
          ? Text(
              l10n.sleepNoData,
              style: TextStyle(
                fontSize: 15,
                color: toFlutterColor(theme.mediumContrastTextColor),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _Figure(
                    theme: theme,
                    label: l10n.sleepBedtime,
                    value: l10n.sleepSpreadMinutes(
                        value.bedSpreadMinutes.round().toString()),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    theme: theme,
                    label: l10n.sleepWakeTime,
                    value: l10n.sleepSpreadMinutes(
                        value.wakeSpreadMinutes.round().toString()),
                  ),
                ),
                Expanded(
                  child: _Figure(
                    theme: theme,
                    label: l10n.sleepDuration,
                    value: formatDurationMinutes(
                        value.meanAsleepMinutes.round()),
                  ),
                ),
              ],
            ),
    );
  }
}
class _Figure extends StatelessWidget {
  const _Figure({
    required this.theme,
    required this.label,
    required this.value,
  });

  final core.Theme theme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: toFlutterColor(theme.highContrastTextColor),
          ),
        ),
      ],
    );
  }
}
