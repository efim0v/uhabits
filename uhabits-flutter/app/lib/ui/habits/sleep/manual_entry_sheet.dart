import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../../platform/device_time_format.dart';
import 'manual_entry.dart';
import 'sleep_card.dart';

/// Collects a night the person types in.
///
/// Returns the night, or null when they backed out.
Future<ManualNight?> showManualEntrySheet(
  BuildContext context, {
  required core.Theme theme,
  required int day,
  required core.SleepGoal goal,
  int utcOffsetMinutes = 0,
  ManualNight? initial,
}) {
  return showModalBottomSheet<ManualNight>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => ManualEntrySheet(
      theme: theme,
      day: day,
      goal: goal,
      utcOffsetMinutes: utcOffsetMinutes,
      initial: initial,
    ),
  );
}

class ManualEntrySheet extends StatefulWidget {
  /// The skip toggle, so a test can reach it without depending on its wording.
  static const Key skipToggleKey = Key('sleep.manualEntry.skip');

  const ManualEntrySheet({
    required this.theme,
    required this.day,
    required this.goal,
    this.utcOffsetMinutes = 0,
    this.initial,
    super.key,
  });

  final core.Theme theme;
  final int day;
  final core.SleepGoal goal;
  final int utcOffsetMinutes;
  final ManualNight? initial;

  @override
  State<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<ManualEntrySheet> {
  late int _bedMinutes;
  late int _wakeMinutes;
  int? _asleepMinutes;
  late bool _skipped;
  late int _utcOffsetMinutes;
  bool _timesEdited = false;

  @override
  void initState() {
    super.initState();
    // Opening on the goal rather than on nothing: most nights are near it, so
    // the common case is two taps of confirmation instead of four of entry.
    _bedMinutes = widget.initial?.bedMinutes ?? widget.goal.bedMinutes;
    _wakeMinutes = widget.initial?.wakeMinutes ?? widget.goal.wakeMinutes;
    _asleepMinutes = widget.initial?.asleepMinutes;
    _skipped = widget.initial?.skipped ?? false;
    // The frame the night was recorded in, not the one the phone is in now.
    // Dropping it re-anchors both instants on today's offset, which moves a
    // night recorded elsewhere — or merely before a daylight saving change —
    // by that difference, and overwrites what the watch measured.
    _utcOffsetMinutes =
        widget.initial?.utcOffsetMinutes ?? widget.utcOffsetMinutes;
  }

  ManualNight get _night => ManualNight(
        day: widget.day,
        bedMinutes: _bedMinutes,
        wakeMinutes: _wakeMinutes,
        asleepMinutes: _asleepMinutes,
        utcOffsetMinutes: _utcOffsetMinutes,
        skipped: _skipped,
        timesEdited: _timesEdited,
      );

  Future<void> _pick({required bool bedtime}) async {
    final int current = bedtime ? _bedMinutes : _wakeMinutes;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      _timesEdited = true;
      final int minutes = picked.hour * 60 + picked.minute;
      if (bedtime) {
        _bedMinutes = minutes;
      } else {
        _wakeMinutes = minutes;
      }
      // The default follows the two times until the person overrides it.
      if (_asleepMinutes != null &&
          _asleepMinutes! > _night.inBedMinutes) {
        _asleepMinutes = _night.inBedMinutes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ManualNight night = _night;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.sleepEnterNight,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: toFlutterColor(widget.theme.highContrastTextColor),
              ),
            ),
            const SizedBox(height: 16),
            _Field(
              theme: widget.theme,
              label: l10n.sleepBedtime,
              value: formatDeviceTime(context, minuteOfDay: _bedMinutes),
              onTap: () => _pick(bedtime: true),
            ),
            _Field(
              theme: widget.theme,
              label: l10n.sleepWakeTime,
              value: formatDeviceTime(context, minuteOfDay: _wakeMinutes),
              onTap: () => _pick(bedtime: false),
            ),
            _Field(
              theme: widget.theme,
              label: l10n.sleepActuallyAsleep,
              value: formatDurationMinutes(
                  _asleepMinutes ?? night.inBedMinutes),
              onTap: _pickAsleep,
            ),
            // Below the times rather than instead of them: a night on a
            // plane still has a bedtime and a waking, and both are worth
            // recording. What it has no bearing on is whether the goal is
            // being kept.
            SwitchListTile(
              key: ManualEntrySheet.skipToggleKey,
              contentPadding: EdgeInsets.zero,
              value: _skipped,
              onChanged: (bool value) => setState(() => _skipped = value),
              title: Text(
                l10n.sleepSkipThisDay,
                style: TextStyle(
                  fontSize: 14,
                  color: toFlutterColor(widget.theme.mediumContrastTextColor),
                ),
              ),
              subtitle: Text(
                l10n.sleepSkipExplained,
                style: TextStyle(
                  fontSize: 12,
                  color: toFlutterColor(widget.theme.lowContrastTextColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_night),
              child: Text(l10n.sleepEnterNight),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAsleep() async {
    final int current = _asleepMinutes ?? _night.inBedMinutes;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      // A duration, not a time of day: the twenty-four hour dial is the one
      // that reads as hours and minutes rather than as a clock.
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _timesEdited = true;
      _asleepMinutes = picked.hour * 60 + picked.minute;
    });
  }
}

class _Field extends StatelessWidget {
  const _Field({
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
      contentPadding: EdgeInsets.zero,
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
