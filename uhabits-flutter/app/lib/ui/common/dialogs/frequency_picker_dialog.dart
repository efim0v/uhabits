/// Port of uhabits-android/.../activities/common/dialogs/FrequencyPickerDialog.kt
/// and uhabits-android/src/main/res/layout/frequency_picker_dialog.xml.
///
/// Five mutually exclusive rows, a Save button and nothing else. The rules the
/// implementation follows verbatim live under `frequency-picker.options`,
/// `frequency-picker.populate-from-frequency` and
/// `frequency-picker.save-and-validation` in docs/parity/FEATURES.md; the
/// arithmetic — including the clamp that turns "7 times per week" into "every
/// day" — is reproduced here rather than delegated, because upstream keeps it
/// in the dialog too.
///
/// Two things the Android version does that a Flutter dialog cannot:
///
///  * `populateViews()` runs on every `onResume`, not only on first show
///    (`frequency-picker.options#9`). There is no resume here; the state is
///    derived once, in [State.initState], from the frequency passed in.
///  * clicking a radio calls `requestFocus()` on the radio *and*
///    `setSelection(text.length)` on the row's first field
///    (`frequency-picker.options#6`). Both happen below: the caret moves
///    without the field taking focus, exactly as upstream, so no keyboard
///    opens.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';

/// The five rows, in layout order (`frequency-picker.options#2`).
enum FrequencyRow {
  everyDay,
  everyXDays,
  xTimesPerWeek,
  xTimesPerMonth,
  xTimesPerYDays,
}

/// The geometry of frequency_picker_dialog.xml, in logical pixels.
class FrequencyPickerMetrics {
  FrequencyPickerMetrics._();

  /// `android:layout_height="48dp"` on every row, `gravity="center_vertical"`
  /// (`frequency-picker.options#3`).
  static const double rowHeight = 48.0;

  /// `android:layout_width="50dp"` / `android:layout_height="40dp"` on every
  /// number field, with 8dp start and end margins.
  static const double fieldWidth = 50.0;

  static const double fieldHeight = 40.0;

  static const double fieldMargin = 8.0;

  /// `paddingTop`/`paddingStart`/`paddingEnd` of the root LinearLayout.
  static const EdgeInsets contentPadding = EdgeInsets.only(
    top: 16,
    left: 16,
    right: 16,
  );
}

/// Shows the frequency picker and completes with the chosen frequency.
///
/// Completes with null when the dialog is dismissed by tapping outside or
/// pressing back: there is no cancel button, and dismissing leaves the
/// frequency unchanged (`frequency-picker.options#8`).
///
/// [frequency] defaults to `Frequency.daily`, which is the (1, 1) of the
/// Kotlin no-arg constructor (`frequency-picker.options#1`).
Future<core.Frequency?> showFrequencyPickerDialog(
  BuildContext context, {
  core.Frequency frequency = core.Frequency.daily,
}) {
  return showDialog<core.Frequency>(
    context: context,
    builder: (context) => FrequencyPickerDialog(frequency: frequency),
  );
}

/// The dialog itself, exposed for tests and for screens that manage their own
/// route.
class FrequencyPickerDialog extends StatefulWidget {
  const FrequencyPickerDialog({
    super.key,
    this.frequency = core.Frequency.daily,
  });

  final core.Frequency frequency;

  /// Which row an existing frequency opens on
  /// (`frequency-picker.populate-from-frequency#2` .. `#6`).
  ///
  /// Note the order of the tests: the month row wins first, so a 1/31 habit
  /// opens as "1 times per month" even though 31 is never written back.
  static FrequencyRow rowFor(int numerator, int denominator) {
    if (denominator == 30 || denominator == 31) {
      return FrequencyRow.xTimesPerMonth;
    }
    if (numerator == 1) {
      return denominator == 1 ? FrequencyRow.everyDay : FrequencyRow.everyXDays;
    }
    return denominator == 7
        ? FrequencyRow.xTimesPerWeek
        : FrequencyRow.xTimesPerYDays;
  }

  /// The literal words around a number field.
  ///
  /// `addBeforeAfterText` splits the localized format string on the substring
  /// "%d" and inserts one trimmed TextView per part
  /// (`frequency-picker.options#5`). ARB messages are generated as functions
  /// rather than format strings, so the same split is done by formatting the
  /// message with sentinels that cannot occur in the surrounding words and
  /// splitting on those. The result always has `sentinels.length + 1` entries,
  /// even for a translation that dropped a placeholder.
  static List<String> splitAround(String formatted, List<String> sentinels) {
    final parts = <String>[];
    var rest = formatted;
    for (final sentinel in sentinels) {
      final at = rest.indexOf(sentinel);
      if (at < 0) {
        parts.add(rest.trim());
        rest = '';
        continue;
      }
      parts.add(rest.substring(0, at).trim());
      rest = rest.substring(at + sentinel.length);
    }
    parts.add(rest.trim());
    return parts;
  }

  /// Stand-ins for the two "%d" of the Android format strings.
  static const int firstSentinel = 987654321;

  static const int secondSentinel = 123456789;

  @override
  State<FrequencyPickerDialog> createState() => _FrequencyPickerDialogState();
}

class _FrequencyPickerDialogState extends State<FrequencyPickerDialog> {
  /// Nullable so that the "no radio at all is checked" state upstream can
  /// reach `Save`, where the month row is the `else` fallback
  /// (`frequency-picker.save-and-validation#6`). [initState] always selects
  /// one, so it is only reachable by a caller building the widget directly.
  FrequencyRow? _selected;

  /// The hard-coded placeholder texts of the layout
  /// (`frequency-picker.options#4`), which rows that were not selected keep
  /// (`frequency-picker.populate-from-frequency#8`).
  late final Map<FrequencyRow, TextEditingController> _controllers = {
    FrequencyRow.everyXDays: TextEditingController(text: '3'),
    FrequencyRow.xTimesPerWeek: TextEditingController(text: '3'),
    FrequencyRow.xTimesPerMonth: TextEditingController(text: '10'),
    FrequencyRow.xTimesPerYDays: TextEditingController(text: '3'),
  };

  /// The second field of the "x times in y days" row.
  late final TextEditingController _yDaysDenominator = TextEditingController(
    text: '14',
  );

  late final Map<FrequencyRow, FocusNode> _radioNodes = {
    for (final row in FrequencyRow.values) row: FocusNode(),
  };

  late final Map<FrequencyRow, FocusNode> _fieldNodes = {
    for (final row in FrequencyRow.values.skip(1)) row: FocusNode(),
  };

  late final FocusNode _yDaysDenominatorNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Giving focus to any number field checks that row's radio; the two-field
    // row is checked by focusing either field
    // (`frequency-picker.options#7`).
    _fieldNodes.forEach((row, node) => node.addListener(() => _onFocus(row)));
    _yDaysDenominatorNode.addListener(
      () => _onFocus(FrequencyRow.xTimesPerYDays),
    );
    _populateViews();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _yDaysDenominator.dispose();
    for (final node in _radioNodes.values) {
      node.dispose();
    }
    for (final node in _fieldNodes.values) {
      node.dispose();
    }
    _yDaysDenominatorNode.dispose();
    super.dispose();
  }

  /// `populateViews()`.
  void _populateViews() {
    final numerator = widget.frequency.numerator;
    final denominator = widget.frequency.denominator;
    final row = FrequencyPickerDialog.rowFor(numerator, denominator);
    _selected = row;
    switch (row) {
      case FrequencyRow.everyDay:
        // No field is written.
        break;
      case FrequencyRow.everyXDays:
        _setField(row, '$denominator');
        break;
      case FrequencyRow.xTimesPerWeek:
      case FrequencyRow.xTimesPerMonth:
        _setField(row, '$numerator');
        break;
      case FrequencyRow.xTimesPerYDays:
        _setField(row, '$numerator');
        _setText(_yDaysDenominator, '$denominator');
        break;
    }
  }

  void _setField(FrequencyRow row, String text) =>
      _setText(_controllers[row]!, text);

  /// `setText` followed by `selectInputField`, which places the caret at the
  /// end of the field (`frequency-picker.populate-from-frequency#7`).
  void _setText(TextEditingController controller, String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onFocus(FrequencyRow row) {
    final node = row == FrequencyRow.xTimesPerYDays
        ? [_fieldNodes[row]!, _yDaysDenominatorNode]
        : [_fieldNodes[row]!];
    if (!node.any((it) => it.hasFocus)) return;
    if (_selected == row) return;
    setState(() => _selected = row);
  }

  /// `check(view)`: uncheck all, check the clicked one, move focus to it, and
  /// for rows 2-5 move the caret to the end of that row's first number field
  /// (`frequency-picker.options#6`).
  void _check(FrequencyRow row) {
    setState(() => _selected = row);
    _radioNodes[row]!.requestFocus();
    final controller = _controllers[row];
    if (controller != null) _setText(controller, controller.text);
  }

  /// `onSaveClicked()` (`frequency-picker.save-and-validation#1` .. `#8`).
  void _onSave() {
    var numerator = 1;
    var denominator = 1;
    final everyXDays = _controllers[FrequencyRow.everyXDays]!.text;
    final perWeek = _controllers[FrequencyRow.xTimesPerWeek]!.text;
    final perMonth = _controllers[FrequencyRow.xTimesPerMonth]!.text;
    final perYDaysX = _controllers[FrequencyRow.xTimesPerYDays]!.text;
    final perYDaysY = _yDaysDenominator.text;

    if (_selected == FrequencyRow.everyDay) {
      // NOP (`frequency-picker.save-and-validation#2`).
    } else if (_selected == FrequencyRow.everyXDays) {
      if (everyXDays.isNotEmpty) denominator = int.parse(everyXDays);
    } else if (_selected == FrequencyRow.xTimesPerWeek) {
      // Both fields move together: an empty field leaves (1, 1), not (1, 7)
      // (`frequency-picker.save-and-validation#4`).
      if (perWeek.isNotEmpty) {
        numerator = int.parse(perWeek);
        denominator = 7;
      }
    } else if (_selected == FrequencyRow.xTimesPerYDays) {
      if (perYDaysX.isNotEmpty && perYDaysY.isNotEmpty) {
        numerator = int.parse(perYDaysX);
        denominator = int.parse(perYDaysY);
      }
    } else {
      // The month row is the `else` branch: it also catches "no radio checked"
      // (`frequency-picker.save-and-validation#6`), and it writes 30, never 31.
      if (perMonth.isNotEmpty) {
        numerator = int.parse(perMonth);
        denominator = 30;
      }
    }

    // `frequency-picker.save-and-validation#7`.
    if (numerator >= denominator || numerator < 1) {
      numerator = 1;
      denominator = 1;
    }
    Navigator.of(context).pop(core.Frequency(numerator, denominator));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    const first = '${FrequencyPickerDialog.firstSentinel}';
    const second = '${FrequencyPickerDialog.secondSentinel}';
    final everyXDays = FrequencyPickerDialog.splitAround(
      l10n.everyXDays(FrequencyPickerDialog.firstSentinel),
      const [first],
    );
    final perWeek = FrequencyPickerDialog.splitAround(
      l10n.xTimesPerWeek(FrequencyPickerDialog.firstSentinel),
      const [first],
    );
    final perMonth = FrequencyPickerDialog.splitAround(
      l10n.xTimesPerMonth(FrequencyPickerDialog.firstSentinel),
      const [first],
    );
    final perYDays = FrequencyPickerDialog.splitAround(
      l10n.xTimesPerYDays(
        FrequencyPickerDialog.firstSentinel,
        FrequencyPickerDialog.secondSentinel,
      ),
      const [first, second],
    );

    return AlertDialog(
      contentPadding: FrequencyPickerMetrics.contentPadding,
      // The Kotlin dialog manages the group by hand — `check()` unchecks all
      // five and checks the clicked one (`frequency-picker.options#6`) — which
      // is exactly what a [RadioGroup] whose value can be null does.
      content: RadioGroup<FrequencyRow>(
        groupValue: _selected,
        onChanged: (row) {
          if (row != null) _check(row);
        },
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _row(FrequencyRow.everyDay, <Widget>[Text(l10n.everyDay)]),
              _row(FrequencyRow.everyXDays, <Widget>[
                Text(everyXDays[0]),
                _field(FrequencyRow.everyXDays, maxLength: 3),
                Text(everyXDays[1]),
              ]),
              _row(FrequencyRow.xTimesPerWeek, <Widget>[
                Text(perWeek[0]),
                _field(FrequencyRow.xTimesPerWeek, maxLength: 1),
                Text(perWeek[1]),
              ]),
              _row(FrequencyRow.xTimesPerMonth, <Widget>[
                Text(perMonth[0]),
                _field(FrequencyRow.xTimesPerMonth, maxLength: 2),
                Text(perMonth[1]),
              ]),
              _row(FrequencyRow.xTimesPerYDays, <Widget>[
                Text(perYDays[0]),
                _field(FrequencyRow.xTimesPerYDays, maxLength: 3),
                Text(perYDays[1]),
                _field(
                  FrequencyRow.xTimesPerYDays,
                  maxLength: 3,
                  controller: _yDaysDenominator,
                  focusNode: _yDaysDenominatorNode,
                  keySuffix: '_denominator',
                ),
                Text(perYDays[2]),
              ]),
            ],
          ),
        ),
      ),
      // A single positive button labelled "Save" and NO cancel button
      // (`frequency-picker.options#8`).
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('frequency_save'),
          onPressed: _onSave,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Widget _row(FrequencyRow row, List<Widget> children) {
    return SizedBox(
      height: FrequencyPickerMetrics.rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Radio<FrequencyRow>(
            key: ValueKey<String>('frequency_radio_${row.name}'),
            value: row,
            focusNode: _radioNodes[row],
          ),
          ...children.where((child) {
            // `addBeforeAfterText` trims each part, and an empty part still
            // becomes a zero-width TextView; skipping it keeps the row from
            // gaining a stray gap.
            return child is! Text || (child.data ?? '').isNotEmpty;
          }),
        ],
      ),
    );
  }

  Widget _field(
    FrequencyRow row, {
    required int maxLength,
    TextEditingController? controller,
    FocusNode? focusNode,
    String keySuffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FrequencyPickerMetrics.fieldMargin,
      ),
      child: SizedBox(
        width: FrequencyPickerMetrics.fieldWidth,
        height: FrequencyPickerMetrics.fieldHeight,
        child: TextField(
          key: ValueKey<String>('frequency_field_${row.name}$keySuffix'),
          controller: controller ?? _controllers[row],
          focusNode: focusNode ?? _fieldNodes[row],
          textAlign: TextAlign.center,
          // `android:inputType="number"` plus `android:maxLength`
          // (`frequency-picker.options#4`), which is why a non-numeric value is
          // impossible and only an empty field has to be handled
          // (`frequency-picker.save-and-validation#10`).
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
        ),
      ),
    );
  }
}
