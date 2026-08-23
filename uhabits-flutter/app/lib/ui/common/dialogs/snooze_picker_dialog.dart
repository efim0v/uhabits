/// Port of uhabits-android/.../notifications/SnoozeDelayPickerActivity.kt,
/// with the two parallel arrays it reads from res/values/constants.xml
/// (`snooze_picker_names` and `snooze_picker_values`).
///
/// Upstream this is a whole activity: a translucent, single-instance,
/// excluded-from-recents `FragmentActivity` that a notification action starts
/// with `FLAG_ACTIVITY_NEW_TASK`, whose only content is an `AlertDialog`
/// listing eight snooze delays. Everything about it that is Android — the
/// intent that carries `habit.uriString` and the `ACTION_CLOSE_SYSTEM_DIALOGS`
/// broadcast that collapses the shade (`reminders.snooze-picker-ui#1`), the
/// manifest attributes (`#10`), the suppressed activity transition (`#8`) and
/// the `KeyguardManager.requestDismissKeyguard` call that makes the picker
/// usable over the lock screen (`#9`, `#13`) — has no Flutter counterpart and
/// is left to whatever native shim eventually launches the app; what survives
/// is the dialog itself, which is what this file is.
///
/// Two upstream details worth keeping in mind:
///
///  * `dialog.listView.onItemClickListener = this` *replaces* the listener the
///    `AlertDialog` installs for `setItems`, so a tap does not dismiss the
///    dialog by itself. Only `finish()` takes it off screen. That is why
///    tapping "Custom..." leaves the list standing behind the time picker, and
///    why cancelling the time picker drops the user back onto the list
///    (`reminders.snooze-picker-ui#6`).
///  * the activity finishes the moment a delay is picked, so the caller — not
///    this dialog — is what turns the answer into
///    `reminderScheduler.snoozeReminder(habit, minutes)` plus
///    `notificationTray.cancel(habit)` (`reminders.snooze-picker-ui#12`,
///    which `ReminderController` owns).
library;

import 'dart:async';

import 'package:flutter/material.dart';
// DateUtils is not re-exported from uhabits_core.dart, and Flutter's material
// library exports a DateUtils of its own, so this one is imported prefixed.
// ignore: implementation_imports
import 'package:uhabits_core/src/time/date_utils.dart' as core_time;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// What the user picked, which is exactly the split
/// `SnoozeDelayPickerActivity` makes between the two `ReminderController`
/// entry points.
sealed class SnoozeChoice {
  const SnoozeChoice();
}

/// An item whose value is >= 0: `onSnoozeDelayPicked(habit, minutes)`
/// (`reminders.snooze-picker-ui#5`, `#12`).
final class SnoozeDelay extends SnoozeChoice {
  const SnoozeDelay(this.minutes);

  final int minutes;

  @override
  bool operator ==(Object other) =>
      other is SnoozeDelay && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;

  @override
  String toString() => 'SnoozeDelay($minutes)';
}

/// The "Custom..." item, once a time came back from the radial picker:
/// `onSnoozeTimePicked(habit, hour, minute)`
/// (`reminders.snooze-picker-ui#6`).
final class SnoozeUntilTime extends SnoozeChoice {
  const SnoozeUntilTime(this.hour, this.minute);

  final int hour;

  final int minute;

  @override
  bool operator ==(Object other) =>
      other is SnoozeUntilTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'SnoozeUntilTime($hour, $minute)';
}

/// Shows the snooze delay picker and completes with what the user picked.
///
/// Completes with null — without showing anything — when [habit] is null,
/// which is the port of `if (habit == null) finish()`: upstream the habit is
/// looked up from the intent's URI and a miss closes the activity before the
/// dialog is ever built (`reminders.snooze-picker-ui#2`).
///
/// Completes with null as well when the dialog is dismissed by a back press or
/// a tap outside (`reminders.snooze-picker-ui#7`).
Future<SnoozeChoice?> showSnoozePickerDialog(
  BuildContext context, {
  required core.Habit? habit,
}) {
  if (habit == null) return Future<SnoozeChoice?>.value();
  return showDialog<SnoozeChoice>(
    context: context,
    builder: (context) => SnoozePickerDialog(habit: habit),
  );
}

/// The dialog itself, exposed for tests and for callers that manage their own
/// route.
class SnoozePickerDialog extends StatelessWidget {
  const SnoozePickerDialog({super.key, required this.habit});

  /// The habit the picker was opened for. Only its colour is read here — the
  /// answer travels back to the caller, which already holds the habit
  /// (`reminders.snooze-picker-ui#12`).
  final core.Habit habit;

  /// `R.array.snooze_picker_values`, in order
  /// (`reminders.snooze-picker-ui#11`). The array is
  /// `translatable="false"`, so it is a constant here rather than an ARB
  /// message (`reminders.snooze-picker-ui#14`).
  static const List<int> values = <int>[15, 30, 60, 120, 240, 480, 1440, -1];

  /// The sentinel that means "pick a custom time"; upstream the test is
  /// `snoozeValues[position] >= 0`, so any negative value would do
  /// (`reminders.snooze-picker-ui#11`).
  static const int customValue = -1;

  /// Identifies the [Theme] that carries the habit's colour into the radial
  /// picker (`reminders.snooze-picker-ui#6`).
  static const Key timePickerThemeKey = ValueKey<String>(
    'snooze_time_picker_theme',
  );

  /// `R.array.snooze_picker_names`, which is a list of `@string/interval_*`
  /// references and therefore localizable
  /// (`reminders.snooze-picker-ui#4`, `#14`).
  static List<String> names(L10n l10n) => <String>[
    l10n.interval15Minutes,
    l10n.interval30Minutes,
    l10n.interval1Hour,
    l10n.interval2Hour,
    l10n.interval4Hour,
    l10n.interval8Hour,
    l10n.interval24Hour,
    l10n.intervalCustom,
  ];

  /// What `Calendar.getInstance()` seeds the radial picker with: the current
  /// `HOUR_OF_DAY` and `MINUTE` (`reminders.snooze-picker-ui#6`).
  ///
  /// [localTime] defaults to `DateUtils.getLocalTime()`, the core clock, so
  /// that a test can pin it the same way every other time-dependent port does.
  static TimeOfDay initialTime([int? localTime]) {
    final now = localTime ?? core_time.DateUtils.getLocalTime();
    final millisIntoDay = now % core_time.DateUtils.dayLength;
    return TimeOfDay(
      hour: millisIntoDay ~/ core_time.DateUtils.hourLength,
      minute:
          (millisIntoDay % core_time.DateUtils.hourLength) ~/
          core_time.DateUtils.minuteLength,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final labels = names(l10n);

    return SimpleDialog(
      // R.string.select_snooze_delay = "Select snooze delay"
      // (`reminders.snooze-picker-ui#4`).
      title: Text(l10n.selectSnoozeDelay),
      children: <Widget>[
        for (var i = 0; i < values.length; i++)
          SimpleDialogOption(
            key: ValueKey<String>('snooze_item_$i'),
            onPressed: () => _onItemClick(context, i),
            child: Text(labels[i]),
          ),
      ],
    );
  }

  /// `onItemClick`: a value of >= 0 answers straight away, anything below it
  /// opens the time picker instead
  /// (`reminders.snooze-picker-ui#5`, `#6`).
  void _onItemClick(BuildContext context, int position) {
    final minutes = values[position];
    if (minutes >= 0) {
      Navigator.of(context).pop(SnoozeDelay(minutes));
    } else {
      unawaited(_showTimePicker(context));
    }
  }

  /// `showTimePicker()`: a radial picker on the current time, in 24-hour mode
  /// iff the platform says so, tinted with the habit's colour as resolved by
  /// the theme now on screen — `LightTheme` by day, `DarkTheme` at night
  /// (`reminders.snooze-picker-ui#3`, `#6`).
  ///
  /// Nothing happens when the picker is cancelled: upstream only the picked
  /// callback calls `finish()`, so the list stays up.
  Future<void> _showTimePicker(BuildContext context) async {
    final navigator = Navigator.of(context);
    final use24HourFormat = MediaQuery.alwaysUse24HourFormatOf(context);
    final tint = toFlutterColor(coreThemeOf(context).colorOf(habit.color));
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime(),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          key: timePickerThemeKey,
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: tint),
          ),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(alwaysUse24HourFormat: use24HourFormat),
            child: child!,
          ),
        );
      },
    );
    if (picked == null) return;
    navigator.pop(SnoozeUntilTime(picked.hour, picked.minute));
  }
}
