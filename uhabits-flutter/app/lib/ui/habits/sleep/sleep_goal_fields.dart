import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_time_format.dart';
import 'sleep_card.dart';

/// The goal, as the editor asks for it.
///
/// Three fields, and nothing else. The weights and the half credit points are
/// part of the model rather than part of the goal: a person who moved them
/// would be scored against a different question from the one they set, and
/// their own history would stop comparing with itself.
class SleepGoalFields extends StatelessWidget {
  const SleepGoalFields({
    required this.theme,
    required this.goal,
    required this.onChanged,
    super.key,
  });

  final core.Theme theme;
  final core.SleepGoal goal;
  final ValueChanged<core.SleepGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Row(
          theme: theme,
          label: l10n.sleepTargetBedtime,
          value: formatDeviceTime(context, minuteOfDay: goal.bedMinutes),
          onTap: () => _pickTime(
            context,
            current: goal.bedMinutes,
            apply: (int m) => onChanged(goal.copyWith(bedMinutes: m)),
          ),
        ),
        _Row(
          theme: theme,
          label: l10n.sleepTargetWakeTime,
          value: formatDeviceTime(context, minuteOfDay: goal.wakeMinutes),
          onTap: () => _pickTime(
            context,
            current: goal.wakeMinutes,
            apply: (int m) => onChanged(goal.copyWith(wakeMinutes: m)),
          ),
        ),
        _Row(
          theme: theme,
          label: l10n.sleepMinimumSleep,
          value: formatDurationMinutes(goal.minSleepMinutes),
          onTap: () => _pickDuration(
            context,
            current: goal.minSleepMinutes,
            apply: (int m) => onChanged(goal.copyWith(minSleepMinutes: m)),
          ),
        ),
        _Row(
          theme: theme,
          label: l10n.sleepAdaptationRate,
          value: l10n.sleepAdaptationPerDay(goal.adaptationMinutesPerDay),
          onTap: () => _pickDuration(
            context,
            current: goal.adaptationMinutesPerDay,
            apply: (int m) =>
                onChanged(goal.copyWith(adaptationMinutesPerDay: m)),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(
    BuildContext context, {
    required int current,
    required ValueChanged<int> apply,
  }) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null) apply(picked.hour * 60 + picked.minute);
  }

  Future<void> _pickDuration(
    BuildContext context, {
    required int current,
    required ValueChanged<int> apply,
  }) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      // A length of time, not a moment: the twenty-four hour dial is the one
      // that reads as hours and minutes.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) apply(picked.hour * 60 + picked.minute);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final core.Theme theme;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: toFlutterColor(theme.mediumContrastTextColor),
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: toFlutterColor(theme.highContrastTextColor),
        ),
      ),
      onTap: onTap,
    );
  }
}
