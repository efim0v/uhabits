import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_time_format.dart';
import 'sleep_card.dart';

/// The goal, as the editor asks for it.
///
/// Five plain fields, and the model's own shape behind a fold. The weights and
/// the half credit points decide what the percentage means, so moving them
/// makes today's number incomparable with last month's — which is why they are
/// not on the first screen. They are offered all the same: a goal made of
/// three weighted parts is not a goal until the person can say what the parts
/// are worth to them.
class SleepGoalFields extends StatefulWidget {
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
  State<SleepGoalFields> createState() => _SleepGoalFieldsState();
}

class _SleepGoalFieldsState extends State<SleepGoalFields> {
  bool _advancedOpen = false;

  core.Theme get theme => widget.theme;
  core.SleepGoal get goal => widget.goal;
  ValueChanged<core.SleepGoal> get onChanged => widget.onChanged;

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
        _Row(
          theme: theme,
          label: l10n.sleepHomeTimezone,
          value: _formatOffset(context, goal.homeUtcOffsetMinutes),
          onTap: _pickHomeOffset,
        ),
        // The model's own shape. Behind a fold because changing it changes
        // what every past percentage meant, not because it is unimportant.
        ExpansionTile(
          key: const Key('sleep.advanced'),
          title: Text(
            l10n.sleepAdvanced,
            style: TextStyle(
              fontSize: 14,
              color: toFlutterColor(theme.mediumContrastTextColor),
            ),
          ),
          initiallyExpanded: _advancedOpen,
          onExpansionChanged: (bool open) =>
              setState(() => _advancedOpen = open),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          children: <Widget>[
            _weight(context, l10n.sleepWeightSleep, goal.weightSleep,
                (double v) => onChanged(goal.copyWith(weightSleep: v))),
            _weight(context, l10n.sleepWeightBed, goal.weightBed,
                (double v) => onChanged(goal.copyWith(weightBed: v))),
            _weight(context, l10n.sleepWeightWake, goal.weightWake,
                (double v) => onChanged(goal.copyWith(weightWake: v))),
            _Row(
              theme: theme,
              label: l10n.sleepHalfCreditTime,
              value: l10n.sleepMinutesShort(goal.halfCreditTimeMinutes),
              onTap: () => _pickDuration(
                context,
                current: goal.halfCreditTimeMinutes,
                apply: (int m) =>
                    onChanged(goal.copyWith(halfCreditTimeMinutes: m)),
              ),
            ),
            _Row(
              theme: theme,
              label: l10n.sleepHalfCreditSleep,
              value: l10n.sleepMinutesShort(goal.halfCreditSleepMinutes),
              onTap: () => _pickDuration(
                context,
                current: goal.halfCreditSleepMinutes,
                apply: (int m) =>
                    onChanged(goal.copyWith(halfCreditSleepMinutes: m)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A weight, as a slider from nothing to everything.
  ///
  /// Only the ratios matter — the goal rescales them — so the scale is
  /// deliberately unlabelled beyond its own number.
  Widget _weight(
    BuildContext context,
    String label,
    double value,
    ValueChanged<double> apply,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: toFlutterColor(theme.mediumContrastTextColor),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Slider(
              value: value.clamp(0.0, 1.0),
              divisions: 20,
              label: value.toStringAsFixed(2),
              onChanged: apply,
            ),
          ),
        ],
      ),
    );
  }

  String _formatOffset(BuildContext context, int minutes) {
    final L10n l10n = L10n.of(context);
    final int abs = minutes.abs();
    return l10n.sleepTimezoneOffset(
      minutes < 0 ? '-' : '+',
      (abs ~/ 60).toString().padLeft(2, '0'),
      (abs % 60).toString().padLeft(2, '0'),
    );
  }

  /// The home zone is offered as a list of the offsets that exist, rather than
  /// as a free number: an offset of seventeen minutes is not a place.
  Future<void> _pickHomeOffset() async {
    const List<int> offsets = <int>[
      -720, -660, -600, -570, -540, -480, -420, -360, -300, -240, -210, -180,
      -120, -60, 0, 60, 120, 180, 210, 240, 270, 300, 330, 345, 360, 390, 420,
      480, 525, 540, 570, 600, 630, 660, 720, 765, 780, 840,
    ];
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final int offset in offsets)
              ListTile(
                title: Text(_formatOffset(context, offset)),
                selected: offset == goal.homeUtcOffsetMinutes,
                onTap: () => Navigator.of(context).pop(offset),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(goal.copyWith(homeUtcOffsetMinutes: picked));
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
