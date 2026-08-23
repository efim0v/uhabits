/// Port of uhabits-android/.../activities/common/dialogs/WeekdayPickerDialog.kt.
///
/// A titled multi-choice list of the seven weekdays. The labels are the long
/// weekday names taken in Saturday-first order, which is the order
/// [core.WeekdayList] packs its bits in — index 0 is Saturday
/// (`weekday-picker.dialog#2`).
///
/// The dialog reports nothing until a button is pressed
/// (`weekday-picker.dialog#4`), returns whatever is ticked — including nothing
/// at all (`weekday-picker.dialog#9`) — and reports nothing when cancelled or
/// dismissed (`weekday-picker.dialog#6`, `#7`). Substituting
/// `WeekdayList.everyDay` for an empty result is the caller's job, exactly as
/// in EditHabitActivity.
///
/// Not ported: the instance-state round trip through the "selectedDays" key
/// (`weekday-picker.dialog#8`), which has no Flutter analogue.
library;

import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../habits/list/list_header.dart' show IntlLocalDateFormatter;

/// Shows the weekday picker and completes with the days that were ticked.
///
/// Completes with null when the dialog is cancelled or dismissed.
///
/// [selected] is required because `setSelectedDays` must be called before the
/// dialog is created or the checked array is null
/// (`weekday-picker.dialog#3`) — here that crash is unrepresentable.
Future<core.WeekdayList?> showWeekdayPickerDialog(
  BuildContext context, {
  required core.WeekdayList selected,
}) {
  return showDialog<core.WeekdayList>(
    context: context,
    builder: (context) => WeekdayPickerDialog(selected: selected),
  );
}

/// The dialog itself, exposed for tests and for screens that manage their own
/// route.
class WeekdayPickerDialog extends StatefulWidget {
  const WeekdayPickerDialog({super.key, required this.selected});

  final core.WeekdayList selected;

  /// The seven weekdays in the order the list shows them, which is also the
  /// order [core.WeekdayList] indexes them: Saturday, Sunday, Monday, ...,
  /// Friday (`weekday-picker.dialog#2`).
  static List<core.DayOfWeek> get weekdays =>
      core.getWeekdaySequence(core.DayOfWeek.saturday);

  @override
  State<WeekdayPickerDialog> createState() => _WeekdayPickerDialogState();
}

class _WeekdayPickerDialogState extends State<WeekdayPickerDialog> {
  /// `selectedDays`, the local array the checkboxes flip
  /// (`weekday-picker.dialog#4`).
  late final List<bool> _selectedDays = widget.selected.toArray();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // android.R.string.yes / android.R.string.cancel are platform strings, not
    // app resources, so the platform's own localizations provide them
    // (`weekday-picker.dialog#5`, `#6`).
    final materialL10n = MaterialLocalizations.of(context);
    final formatter = IntlLocalDateFormatter.of(context);
    final weekdays = WeekdayPickerDialog.weekdays;

    return AlertDialog(
      // R.string.select_weekdays = "Select days" (`weekday-picker.dialog#1`).
      title: Text(l10n.selectWeekdays),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < weekdays.length; i++)
              CheckboxListTile(
                key: ValueKey<String>('weekday_$i'),
                value: _selectedDays[i],
                title: Text(formatter.longWeekdayNameOf(weekdays[i])),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (checked) =>
                    setState(() => _selectedDays[i] = checked ?? false),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('weekday_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        TextButton(
          key: const ValueKey<String>('weekday_ok'),
          onPressed: () => Navigator.of(
            context,
          ).pop(core.WeekdayList.fromArray(_selectedDays)),
          child: Text(materialL10n.okButtonLabel),
        ),
      ],
    );
  }
}
