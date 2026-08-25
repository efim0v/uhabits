import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_time_format.dart';
import 'sleep_card.dart';

/// Something the app noticed, offered rather than done.
///
/// Both suggestions the sleep habit makes — set these travel days aside, move
/// the goal to where you actually sleep — end here, because both have the same
/// shape and the same rule: the app proposes, the person decides. A single
/// card is what keeps that rule in one place instead of two.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    required this.theme,
    required this.message,
    required this.applyLabel,
    required this.onApply,
    required this.onDismiss,
    super.key,
  });

  final core.Theme theme;
  final String message;
  final String applyLabel;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    return Padding(
      padding: SleepCard.margin,
      child: Material(
        elevation: SleepCard.elevation,
        color: toFlutterColor(theme.cardBackgroundColor),
        child: Padding(
          padding: SleepCard.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: toFlutterColor(theme.highContrastTextColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: onDismiss,
                    child: Text(l10n.sleepSuggestDismiss),
                  ),
                  const SizedBox(width: 4),
                  TextButton(onPressed: onApply, child: Text(applyLabel)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wording for a goal the recent nights suggest.
String goalSuggestionMessage(
  BuildContext context,
  core.GoalSuggestion suggestion,
) {
  final L10n l10n = L10n.of(context);
  final int? bed = suggestion.bedMinutes;
  if (bed != null) {
    return l10n.sleepSuggestGoalBed(
        formatDeviceTime(context, minuteOfDay: bed));
  }
  return l10n.sleepSuggestGoalWake(
      formatDeviceTime(context, minuteOfDay: suggestion.wakeMinutes!));
}
