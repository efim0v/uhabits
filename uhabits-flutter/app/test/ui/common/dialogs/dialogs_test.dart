/// Widget tests for the six shared pickers.
///
/// Every expectation cites the parity rule it pins, from
/// docs/parity/FEATURES.md. The Kotlin sources being reproduced are
/// uhabits-android/.../activities/common/dialogs/{ColorPickerDialog,
/// FrequencyPickerDialog,WeekdayPickerDialog,NumberDialog,CheckmarkDialog,
/// ConfirmDeleteDialog}.kt plus the vendored com/android/colorpicker package.
library;

// The core Color is only reached through the `core` prefix; Flutter's wins.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/common/dialogs/checkmark_dialog.dart';
import 'package:uhabits/ui/common/dialogs/color_picker_dialog.dart';
import 'package:uhabits/ui/common/dialogs/confirm_delete_dialog.dart';
import 'package:uhabits/ui/common/dialogs/frequency_picker_dialog.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
import 'package:uhabits/ui/common/dialogs/weekday_picker_dialog.dart';
import 'package:uhabits/ui/theme/app_theme.dart';
// Preferences are not re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  group('color-picker.dialog', () {
    testWidgets('#1 titled "Change color" and showing the whole palette', (
      tester,
    ) async {
      await _open(tester, (context) => showColorPickerDialog(context));

      expect(
        find.text('Change color'),
        findsOneWidget,
        reason: 'color-picker.dialog#1',
      );
      for (var i = 0; i < 20; i++) {
        expect(
          find.byKey(ValueKey<String>('color_swatch_$i')),
          findsOneWidget,
          reason: 'color-picker.dialog#1',
        );
      }
    });

    testWidgets('#1 #2 48dp swatches with 4dp margins, four to a row', (
      tester,
    ) async {
      await _open(tester, (context) => showColorPickerDialog(context));

      // 48dp of swatch plus 4dp of margin on each side.
      expect(
        tester.getSize(_swatch(0)),
        const Size(56, 56),
        reason: 'color-picker.dialog#2',
      );
      expect(
        ColorPickerMetrics.swatchSize,
        48.0,
        reason: 'color-picker.dialog#2',
      );
      expect(
        ColorPickerMetrics.swatchMargin,
        4.0,
        reason: 'color-picker.dialog#2',
      );

      // Four columns: 0..3 share a row, 4 starts the next one.
      final first = tester.getCenter(_swatch(0));
      expect(
        tester.getCenter(_swatch(3)).dy,
        first.dy,
        reason: 'color-picker.dialog#1',
      );
      expect(
        tester.getCenter(_swatch(4)).dy,
        greaterThan(first.dy),
        reason: 'color-picker.dialog#1',
      );
    });

    test('#3 the grid is filled in serpentine order', () {
      // Even rows read left to right, odd rows right to left.
      expect(
        [for (var c = 0; c < 4; c++) ColorPickerDialog.paletteIndexAt(0, c)],
        [0, 1, 2, 3],
        reason: 'color-picker.dialog#3',
      );
      expect(
        [for (var c = 0; c < 4; c++) ColorPickerDialog.paletteIndexAt(1, c)],
        [7, 6, 5, 4],
        reason: 'color-picker.dialog#3',
      );
      expect(
        [for (var c = 0; c < 4; c++) ColorPickerDialog.paletteIndexAt(4, c)],
        [16, 17, 18, 19],
        reason: 'color-picker.dialog#3',
      );
    });

    testWidgets('#3 the second row really is laid out backwards', (
      tester,
    ) async {
      await _open(tester, (context) => showColorPickerDialog(context));

      final four = tester.getCenter(_swatch(4));
      final seven = tester.getCenter(_swatch(7));
      expect(seven.dy, four.dy, reason: 'color-picker.dialog#3');
      expect(seven.dx, lessThan(four.dx), reason: 'color-picker.dialog#3');
    });

    testWidgets('#5 only the selected swatch carries a checkmark', (
      tester,
    ) async {
      await _open(
        tester,
        (context) => showColorPickerDialog(
          context,
          selected: const core.PaletteColor(11),
        ),
      );

      expect(
        find.byIcon(Icons.check),
        findsOneWidget,
        reason: 'color-picker.dialog#5',
      );
      expect(
        find.descendant(of: _swatch(11), matching: find.byIcon(Icons.check)),
        findsOneWidget,
        reason: 'color-picker.dialog#5',
      );
    });

    testWidgets('#7 descriptions follow reading order, not insertion order', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _open(
        tester,
        (context) => showColorPickerDialog(
          context,
          selected: const core.PaletteColor(0),
        ),
      );

      // Row 1 is inserted backwards, so colour 7 is the fifth swatch a reader
      // meets and colour 4 the eighth.
      expect(
        find.bySemanticsLabel('Color 5'),
        findsOneWidget,
        reason: 'color-picker.dialog#7',
      );
      expect(
        find.bySemanticsLabel('Color 8'),
        findsOneWidget,
        reason: 'color-picker.dialog#7',
      );
      expect(
        find.bySemanticsLabel('Color 1 selected'),
        findsOneWidget,
        reason: 'color-picker.dialog#7',
      );
      handle.dispose();
    });

    testWidgets(
      '#8 tapping a swatch reports it and closes, with no OK button',
      (tester) async {
        final result = await _open<core.PaletteColor>(
          tester,
          (context) => showColorPickerDialog(context),
        );

        expect(
          find.widgetWithText(TextButton, 'OK'),
          findsNothing,
          reason: 'color-picker.dialog#8',
        );
        await tester.tap(_swatch(13));
        await tester.pumpAndSettle();

        expect(
          result.value,
          const core.PaletteColor(13),
          reason: 'color-picker.dialog#8',
        );
        expect(
          find.byType(ColorPickerDialog),
          findsNothing,
          reason: 'color-picker.dialog#8',
        );
      },
    );

    testWidgets('#9 dismissing without a tap reports nothing', (tester) async {
      final result = await _open<core.PaletteColor>(
        tester,
        (context) => showColorPickerDialog(context),
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue, reason: 'color-picker.dialog#9');
      expect(result.value, isNull, reason: 'color-picker.dialog#9');
    });

    testWidgets('palette-source#1 the swatches are the themed palette', (
      tester,
    ) async {
      await _open(tester, (context) => showColorPickerDialog(context));
      expect(
        _swatchColor(tester, 0),
        toFlutterColor(core.LightTheme().color(0)),
        reason: 'color-picker.palette-source#1',
      );

      await _open(
        tester,
        (context) => showColorPickerDialog(context),
        theme: appThemeData(core.DarkTheme()),
      );
      expect(
        _swatchColor(tester, 0),
        toFlutterColor(core.DarkTheme().color(0)),
        reason: 'color-picker.palette-source#1',
      );
      expect(
        core.DarkTheme().color(0),
        isNot(core.LightTheme().color(0)),
        reason: 'color-picker.palette-source#1',
      );
    });
  });

  group('frequency-picker.options', () {
    testWidgets('#1 the default frequency is (1, 1)', (tester) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));

      expect(
        core.Frequency.daily.numerator,
        1,
        reason: 'frequency-picker.options#1',
      );
      expect(
        core.Frequency.daily.denominator,
        1,
        reason: 'frequency-picker.options#1',
      );
      expect(
        _checkedRow(tester),
        FrequencyRow.everyDay,
        reason: 'frequency-picker.options#1',
      );
    });

    testWidgets('#2 exactly five rows, in order', (tester) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));

      expect(
        find.byType(Radio<FrequencyRow>),
        findsNWidgets(5),
        reason: 'frequency-picker.options#2',
      );
      final tops = <double>[
        for (final row in FrequencyRow.values)
          tester.getTopLeft(_radio(row)).dy,
      ];
      expect(
        tops,
        orderedEquals(<double>[...tops]..sort()),
        reason: 'frequency-picker.options#2',
      );
      expect(
        find.text('Every day'),
        findsOneWidget,
        reason: 'frequency-picker.options#2',
      );
    });

    testWidgets('#3 every row is 48dp tall', (tester) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));

      for (final row in FrequencyRow.values) {
        final box = find.ancestor(
          of: _radio(row),
          matching: find.byType(SizedBox),
        );
        expect(
          tester.getSize(box.first).height,
          48.0,
          reason: 'frequency-picker.options#3',
        );
      }
      expect(
        FrequencyPickerMetrics.rowHeight,
        48.0,
        reason: 'frequency-picker.options#3',
      );
    });

    testWidgets('#4 the placeholder texts are 3 / 3 / 10 / 3 / 14', (
      tester,
    ) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));

      expect(
        _fieldText(tester, FrequencyRow.everyXDays),
        '3',
        reason: 'frequency-picker.options#4',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerWeek),
        '3',
        reason: 'frequency-picker.options#4',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerMonth),
        '10',
        reason: 'frequency-picker.options#4',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerYDays),
        '3',
        reason: 'frequency-picker.options#4',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerYDays, denominator: true),
        '14',
        reason: 'frequency-picker.options#4',
      );
    });

    testWidgets('#4 the fields take digits only, up to their maxLength', (
      tester,
    ) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));

      // maxLength 1 on the times-per-week field. The field has to be emptied
      // first: like Android's LengthFilter, Flutter's limiter keeps the old
      // text when the field is already full.
      await tester.enterText(_field(FrequencyRow.xTimesPerWeek), '');
      await tester.pump();
      await tester.enterText(_field(FrequencyRow.xTimesPerWeek), '456');
      await tester.pump();
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerWeek),
        '4',
        reason: 'frequency-picker.options#4',
      );

      // maxLength 2 on the times-per-month field, and inputType=number.
      await tester.enterText(_field(FrequencyRow.xTimesPerMonth), '');
      await tester.pump();
      await tester.enterText(_field(FrequencyRow.xTimesPerMonth), '12x3');
      await tester.pump();
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerMonth),
        '12',
        reason: 'frequency-picker.options#4',
      );
    });

    testWidgets('#5 the words around each field come from the format string', (
      tester,
    ) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));

      // "Every %d days" -> ["Every", "days"].
      expect(
        find.text('Every'),
        findsOneWidget,
        reason: 'frequency-picker.options#5',
      );
      // "%d times in %d days" -> ["", "times in", "days"]; the empty leading
      // part draws nothing.
      expect(
        find.text('times in'),
        findsOneWidget,
        reason: 'frequency-picker.options#5',
      );
      expect(
        find.text('days'),
        findsNWidgets(2),
        reason: 'frequency-picker.options#5',
      );
      expect(
        find.text('times per week'),
        findsOneWidget,
        reason: 'frequency-picker.options#5',
      );
      expect(
        find.text('times per month'),
        findsOneWidget,
        reason: 'frequency-picker.options#5',
      );
    });

    test('#5 splitting keeps one part more than there are placeholders', () {
      expect(
        FrequencyPickerDialog.splitAround('Every 42 days', const ['42']),
        ['Every', 'days'],
        reason: 'frequency-picker.options#5',
      );
      expect(
        FrequencyPickerDialog.splitAround('7 times in 42 days', const [
          '7',
          '42',
        ]),
        ['', 'times in', 'days'],
        reason: 'frequency-picker.options#5',
      );
    });

    testWidgets('#6 clicking a radio unchecks the others', (tester) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));
      expect(
        _checkedRow(tester),
        FrequencyRow.everyDay,
        reason: 'frequency-picker.options#6',
      );

      await tester.tap(_radio(FrequencyRow.xTimesPerMonth));
      await tester.pumpAndSettle();

      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerMonth,
        reason: 'frequency-picker.options#6',
      );
    });

    testWidgets('#7 focusing a number field checks that row', (tester) async {
      await _open(tester, (context) => showFrequencyPickerDialog(context));

      // Focusing the *second* field of the two-field row checks it too.
      await tester.tap(_field(FrequencyRow.xTimesPerYDays, denominator: true));
      await tester.pumpAndSettle();

      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerYDays,
        reason: 'frequency-picker.options#7',
      );
    });

    testWidgets(
      '#8 one Save button, no cancel, and dismissing changes nothing',
      (tester) async {
        final result = await _open<core.Frequency>(
          tester,
          (context) => showFrequencyPickerDialog(context),
        );

        expect(
          find.widgetWithText(TextButton, 'Save'),
          findsOneWidget,
          reason: 'frequency-picker.options#8',
        );
        expect(
          find.byType(TextButton),
          findsOneWidget,
          reason: 'frequency-picker.options#8',
        );

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(result.completed, isTrue, reason: 'frequency-picker.options#8');
        expect(result.value, isNull, reason: 'frequency-picker.options#8');
      },
    );
  });

  group('frequency-picker.populate-from-frequency', () {
    test('#2 .. #6 the row an existing frequency opens on', () {
      expect(
        FrequencyPickerDialog.rowFor(2, 30),
        FrequencyRow.xTimesPerMonth,
        reason: 'frequency-picker.populate-from-frequency#2',
      );
      expect(
        FrequencyPickerDialog.rowFor(1, 31),
        FrequencyRow.xTimesPerMonth,
        reason: 'frequency-picker.populate-from-frequency#2',
      );
      expect(
        FrequencyPickerDialog.rowFor(1, 1),
        FrequencyRow.everyDay,
        reason: 'frequency-picker.populate-from-frequency#3',
      );
      expect(
        FrequencyPickerDialog.rowFor(1, 5),
        FrequencyRow.everyXDays,
        reason: 'frequency-picker.populate-from-frequency#4',
      );
      expect(
        FrequencyPickerDialog.rowFor(3, 7),
        FrequencyRow.xTimesPerWeek,
        reason: 'frequency-picker.populate-from-frequency#5',
      );
      expect(
        FrequencyPickerDialog.rowFor(5, 20),
        FrequencyRow.xTimesPerYDays,
        reason: 'frequency-picker.populate-from-frequency#6',
      );
    });

    testWidgets('#2 a 1/31 habit opens as "1 times per month"', (tester) async {
      await _openFrequency(tester, core.Frequency(1, 31));

      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerMonth,
        reason: 'frequency-picker.populate-from-frequency#2',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerMonth),
        '1',
        reason: 'frequency-picker.populate-from-frequency#2',
      );
    });

    testWidgets('#4 every X days writes the denominator', (tester) async {
      await _openFrequency(tester, core.Frequency(1, 5));

      expect(
        _checkedRow(tester),
        FrequencyRow.everyXDays,
        reason: 'frequency-picker.populate-from-frequency#4',
      );
      expect(
        _fieldText(tester, FrequencyRow.everyXDays),
        '5',
        reason: 'frequency-picker.populate-from-frequency#4',
      );
    });

    testWidgets('#5 x times per week writes the numerator', (tester) async {
      await _openFrequency(tester, core.Frequency(5, 7));

      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerWeek,
        reason: 'frequency-picker.populate-from-frequency#5',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerWeek),
        '5',
        reason: 'frequency-picker.populate-from-frequency#5',
      );
    });

    testWidgets('#6 #7 x times in y days writes both, caret at the end', (
      tester,
    ) async {
      await _openFrequency(tester, core.Frequency(5, 20));

      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerYDays,
        reason: 'frequency-picker.populate-from-frequency#6',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerYDays),
        '5',
        reason: 'frequency-picker.populate-from-frequency#6',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerYDays, denominator: true),
        '20',
        reason: 'frequency-picker.populate-from-frequency#6',
      );

      final controller = tester
          .widget<TextField>(_field(FrequencyRow.xTimesPerYDays))
          .controller!;
      expect(
        controller.selection.baseOffset,
        1,
        reason: 'frequency-picker.populate-from-frequency#7',
      );
    });

    testWidgets('#8 rows that were not selected keep their placeholders', (
      tester,
    ) async {
      await _openFrequency(tester, core.Frequency(1, 5));

      expect(
        _fieldText(tester, FrequencyRow.xTimesPerWeek),
        '3',
        reason: 'frequency-picker.populate-from-frequency#8',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerMonth),
        '10',
        reason: 'frequency-picker.populate-from-frequency#8',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerYDays),
        '3',
        reason: 'frequency-picker.populate-from-frequency#8',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerYDays, denominator: true),
        '14',
        reason: 'frequency-picker.populate-from-frequency#8',
      );
    });
  });

  group('frequency-picker.save-and-validation', () {
    testWidgets('#2 every day saves (1, 1)', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(1, 5));
      await tester.tap(_radio(FrequencyRow.everyDay));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#2',
      );
    });

    testWidgets('#3 every X days saves (1, X)', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.everyXDays));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.everyXDays), '9');
      await _save(tester);

      expect(
        result.value,
        core.Frequency(1, 9),
        reason: 'frequency-picker.save-and-validation#3',
      );
    });

    testWidgets('#3 an empty every-X-days field leaves (1, 1)', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.everyXDays));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.everyXDays), '');
      await _save(tester);

      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#3',
      );
    });

    testWidgets('#4 x times per week saves (x, 7)', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.xTimesPerWeek));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerWeek), '4');
      await _save(tester);

      expect(
        result.value,
        core.Frequency(4, 7),
        reason: 'frequency-picker.save-and-validation#4',
      );
    });

    testWidgets('#4 an empty week field saves (1, 1), not (1, 7)', (
      tester,
    ) async {
      final result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.xTimesPerWeek));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerWeek), '');
      await _save(tester);

      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#4',
      );
      expect(
        result.value,
        isNot(core.Frequency(1, 7)),
        reason: 'frequency-picker.save-and-validation#4',
      );
    });

    testWidgets('#5 x times in y days needs both fields', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.xTimesPerYDays));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerYDays), '5');
      await tester.enterText(
        _field(FrequencyRow.xTimesPerYDays, denominator: true),
        '',
      );
      await _save(tester);

      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#5',
      );
    });

    testWidgets('#5 both fields present saves (x, y)', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.xTimesPerYDays));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerYDays), '5');
      await tester.enterText(
        _field(FrequencyRow.xTimesPerYDays, denominator: true),
        '20',
      );
      await _save(tester);

      expect(
        result.value,
        core.Frequency(5, 20),
        reason: 'frequency-picker.save-and-validation#5',
      );
    });

    testWidgets('#6 the month row writes 30, never 31', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(2, 31));
      await _save(tester);

      expect(
        result.value,
        core.Frequency(2, 30),
        reason: 'frequency-picker.save-and-validation#6',
      );
    });

    testWidgets('#7 the clamp collapses anything at or above 1/1', (
      tester,
    ) async {
      // 7 times per week -> (1, 1).
      var result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.xTimesPerWeek));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerWeek), '7');
      await _save(tester);
      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#7',
      );

      // 0 times per week -> (1, 1).
      result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.xTimesPerWeek));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerWeek), '0');
      await _save(tester);
      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#7',
      );

      // 30 times per month -> (1, 1).
      result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.xTimesPerMonth));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerMonth), '30');
      await _save(tester);
      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#7',
      );

      // Every 1 days -> (1, 1).
      result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.everyXDays));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.everyXDays), '1');
      await _save(tester);
      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#7',
      );
    });

    testWidgets('#8 saving dismisses the dialog', (tester) async {
      await _openFrequency(tester, core.Frequency(1, 1));
      await _save(tester);

      expect(
        find.byType(FrequencyPickerDialog),
        findsNothing,
        reason: 'frequency-picker.save-and-validation#8',
      );
    });
  });

  group('weekday-picker.dialog', () {
    testWidgets('#1 #2 titled "Select days", Saturday first', (tester) async {
      await _openWeekdays(tester, core.WeekdayList(0));

      expect(
        find.text('Select days'),
        findsOneWidget,
        reason: 'weekday-picker.dialog#1',
      );
      expect(
        find.byType(CheckboxListTile),
        findsNWidgets(7),
        reason: 'weekday-picker.dialog#1',
      );
      expect(
        [
          for (var i = 0; i < 7; i++)
            (tester.widget<CheckboxListTile>(_weekday(i)).title! as Text).data,
        ],
        [
          'Saturday',
          'Sunday',
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
        ],
        reason: 'weekday-picker.dialog#2',
      );
    });

    testWidgets('#3 the initial ticks come from the WeekdayList', (
      tester,
    ) async {
      // Bits 0 and 2: Saturday and Monday.
      await _openWeekdays(tester, core.WeekdayList(1 | 4));

      expect(
        [
          for (var i = 0; i < 7; i++)
            tester.widget<CheckboxListTile>(_weekday(i)).value,
        ],
        [true, false, true, false, false, false, false],
        reason: 'weekday-picker.dialog#3',
      );
    });

    testWidgets('#4 #5 ticking reports nothing until the positive button', (
      tester,
    ) async {
      final result = await _openWeekdays(tester, core.WeekdayList(0));

      await tester.tap(_weekday(1));
      await tester.pumpAndSettle();
      expect(result.completed, isFalse, reason: 'weekday-picker.dialog#4');
      expect(
        tester.widget<CheckboxListTile>(_weekday(1)).value,
        isTrue,
        reason: 'weekday-picker.dialog#4',
      );

      await tester.tap(find.byKey(const ValueKey<String>('weekday_ok')));
      await tester.pumpAndSettle();
      expect(
        result.value,
        core.WeekdayList(2),
        reason: 'weekday-picker.dialog#5',
      );
    });

    testWidgets('#6 cancel reports nothing', (tester) async {
      final result = await _openWeekdays(tester, core.WeekdayList(127));

      await tester.tap(_weekday(3));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('weekday_cancel')));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue, reason: 'weekday-picker.dialog#6');
      expect(result.value, isNull, reason: 'weekday-picker.dialog#6');
    });

    testWidgets('#7 dismissing reports nothing', (tester) async {
      final result = await _openWeekdays(tester, core.WeekdayList(127));

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(result.value, isNull, reason: 'weekday-picker.dialog#7');
    });

    testWidgets('#9 an all-unselected list is returned as it is', (
      tester,
    ) async {
      final result = await _openWeekdays(tester, core.WeekdayList(0));

      await tester.tap(find.byKey(const ValueKey<String>('weekday_ok')));
      await tester.pumpAndSettle();

      expect(result.value!.isEmpty, isTrue, reason: 'weekday-picker.dialog#9');
      expect(
        result.value,
        isNot(core.WeekdayList.everyDay),
        reason: 'weekday-picker.dialog#9',
      );
    });
  });

  group('checkmark-dialog.popup', () {
    testWidgets('#3 #5 only YES and NO by default, in layout order', (
      tester,
    ) async {
      await _openCheckmark(tester, value: core.Entry.no);

      expect(
        find.byKey(const ValueKey<String>('checkmark_yes_button')),
        findsOneWidget,
        reason: 'checkmark-dialog.popup#3',
      );
      expect(
        find.byKey(const ValueKey<String>('checkmark_no_button')),
        findsOneWidget,
        reason: 'checkmark-dialog.popup#3',
      );
      expect(
        find.byKey(const ValueKey<String>('checkmark_skip_button')),
        findsNothing,
        reason: 'checkmark-dialog.popup#5',
      );
      expect(
        find.byKey(const ValueKey<String>('checkmark_unknown_button')),
        findsNothing,
        reason: 'checkmark-dialog.popup#5',
      );
    });

    testWidgets('#3 #5 the preferences reveal SKIP and UNKNOWN', (
      tester,
    ) async {
      final preferences = Preferences(MemoryStorage())
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;
      await _openCheckmark(
        tester,
        value: core.Entry.no,
        preferences: preferences,
      );

      final glyphs = <String>[
        for (final name in ['yes', 'skip', 'no', 'unknown'])
          tester
              .widget<Text>(
                find.descendant(
                  of: find.byKey(ValueKey<String>('checkmark_${name}_button')),
                  matching: find.byType(Text),
                ),
              )
              .data!,
      ];
      expect(glyphs, [
        core.FontAwesome.check,
        core.FontAwesome.skipped,
        core.FontAwesome.times,
        core.FontAwesome.question,
      ], reason: 'checkmark-dialog.popup#3');

      // Left to right: YES, SKIP, NO, UNKNOWN.
      final xs = <double>[
        for (final name in ['yes', 'skip', 'no', 'unknown'])
          tester
              .getCenter(
                find.byKey(ValueKey<String>('checkmark_${name}_button')),
              )
              .dx,
      ];
      expect(
        xs,
        orderedEquals(<double>[...xs]..sort()),
        reason: 'checkmark-dialog.popup#3',
      );
    });

    testWidgets('#4 YES and SKIP take the habit colour, NO and UNKNOWN dim', (
      tester,
    ) async {
      final preferences = Preferences(MemoryStorage())
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;
      const habitColor = core.Color.fromRgb(0x1976D2);
      await _openCheckmark(
        tester,
        value: core.Entry.no,
        color: habitColor,
        preferences: preferences,
      );

      final dim = toFlutterColor(core.LightTheme().mediumContrastTextColor);
      expect(
        _glyphColor(tester, 'yes'),
        toFlutterColor(habitColor),
        reason: 'checkmark-dialog.popup#4',
      );
      expect(
        _glyphColor(tester, 'skip'),
        toFlutterColor(habitColor),
        reason: 'checkmark-dialog.popup#4',
      );
      expect(
        _glyphColor(tester, 'no'),
        dim,
        reason: 'checkmark-dialog.popup#4',
      );
      expect(
        _glyphColor(tester, 'unknown'),
        dim,
        reason: 'checkmark-dialog.popup#4',
      );
    });

    testWidgets('#2 a 208dp-wide popup with the notes field on top', (
      tester,
    ) async {
      await _openCheckmark(tester, value: core.Entry.no);

      expect(
        tester.getSize(find.byType(CheckmarkDialog)).width,
        greaterThanOrEqualTo(208.0),
        reason: 'checkmark-dialog.popup#2',
      );
      expect(
        tester
            .getCenter(find.byKey(const ValueKey<String>('checkmark_notes')))
            .dy,
        lessThan(
          tester
              .getCenter(
                find.byKey(const ValueKey<String>('checkmark_yes_button')),
              )
              .dy,
        ),
        reason: 'checkmark-dialog.popup#2',
      );
    });

    testWidgets('#6 the notes field is pre-filled', (tester) async {
      await _openCheckmark(tester, value: core.Entry.no, notes: 'went well');

      expect(
        find.text('went well'),
        findsOneWidget,
        reason: 'checkmark-dialog.popup#6',
      );
    });

    testWidgets('#7 each button returns its own value with trimmed notes', (
      tester,
    ) async {
      final preferences = Preferences(MemoryStorage())
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;

      for (final pair in <List<Object>>[
        ['yes', core.Entry.yesManual],
        ['skip', core.Entry.skip],
        ['no', core.Entry.no],
        ['unknown', core.Entry.unknown],
      ]) {
        final result = await _openCheckmark(
          tester,
          value: core.Entry.unknown,
          preferences: preferences,
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('checkmark_notes')),
          '  spaced  ',
        );
        await tester.tap(
          find.byKey(ValueKey<String>('checkmark_${pair[0]}_button')),
        );
        await tester.pumpAndSettle();

        expect(
          result.value,
          CheckmarkDialogResult(pair[1] as int, 'spaced'),
          reason: 'checkmark-dialog.popup#7',
        );
        expect(
          find.byType(CheckmarkDialog),
          findsNothing,
          reason: 'checkmark-dialog.popup#7',
        );
      }
    });

    testWidgets('#8 the IME action keeps the original value', (tester) async {
      final result = await _openCheckmark(
        tester,
        value: core.Entry.skip,
        notes: 'before',
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('checkmark_notes')),
        ' after ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        result.value,
        const CheckmarkDialogResult(core.Entry.skip, 'after'),
        reason: 'checkmark-dialog.popup#8',
      );
    });

    testWidgets('#9 a dismissal with edited notes still reports them', (
      tester,
    ) async {
      final result = await _openCheckmark(
        tester,
        value: core.Entry.yesManual,
        notes: 'before',
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('checkmark_notes')),
        ' after ',
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(
        result.value,
        const CheckmarkDialogResult(core.Entry.yesManual, 'after'),
        reason: 'checkmark-dialog.popup#9',
      );
    });

    testWidgets('#9 a dismissal with untouched notes reports nothing', (
      tester,
    ) async {
      final result = await _openCheckmark(
        tester,
        value: core.Entry.yesManual,
        notes: 'before',
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue, reason: 'checkmark-dialog.popup#9');
      expect(result.value, isNull, reason: 'checkmark-dialog.popup#9');
    });

    testWidgets('entry-values#10 the four end states are offered directly', (
      tester,
    ) async {
      final preferences = Preferences(MemoryStorage())
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;

      // The cycle would send NO to UNKNOWN; the dialog sends it wherever the
      // user points instead.
      expect(
        core.Entry.nextToggleValue(
          core.Entry.no,
          isSkipEnabled: true,
          areQuestionMarksEnabled: true,
        ),
        core.Entry.unknown,
        reason: 'models.entry-values#10',
      );

      final result = await _openCheckmark(
        tester,
        value: core.Entry.no,
        preferences: preferences,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('checkmark_yes_button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.value!.value,
        core.Entry.yesManual,
        reason: 'models.entry-values#10',
      );
    });
  });

  group('number-dialog.popup', () {
    test('#4 the initial text of the value field', () {
      expect(
        NumberDialog.formatValue(0.5, 'en'),
        '0.5',
        reason: 'number-dialog.popup#4',
      );
      expect(
        NumberDialog.formatValue(12.345, 'en'),
        '12.35',
        reason: 'number-dialog.popup#4',
      );
      expect(
        NumberDialog.formatValue(15.0, 'en'),
        '15',
        reason: 'number-dialog.popup#4',
      );
      // UNKNOWN and SKIP are both below 0.01, so both open as "0".
      expect(
        NumberDialog.formatValue(core.Entry.unknown / 1000.0, 'en'),
        '0',
        reason: 'number-dialog.popup#4',
      );
      expect(
        NumberDialog.formatValue(core.Entry.skip / 1000.0, 'en'),
        '0',
        reason: 'number-dialog.popup#4',
      );
    });

    testWidgets('#4 the field opens on the formatted value', (tester) async {
      await _openNumber(tester, value: 12.345);

      expect(_numberValue(tester), '12.35', reason: 'number-dialog.popup#4');
    });

    testWidgets('#2 #3 value, Save, Skip, question mark — in that order', (
      tester,
    ) async {
      final preferences = Preferences(MemoryStorage())
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;
      await _openNumber(tester, value: 1.0, preferences: preferences);

      final xs = <double>[
        tester.getCenter(find.byKey(const ValueKey<String>('number_value'))).dx,
        for (final name in ['save', 'skip', 'unknown'])
          tester
              .getCenter(find.byKey(ValueKey<String>('number_${name}_button')))
              .dx,
      ];
      expect(
        xs,
        orderedEquals(<double>[...xs]..sort()),
        reason: 'number-dialog.popup#2',
      );
    });

    testWidgets('#3 Skip and the question mark are hidden by default', (
      tester,
    ) async {
      await _openNumber(tester, value: 1.0);

      expect(
        find.byKey(const ValueKey<String>('number_save_button')),
        findsOneWidget,
        reason: 'number-dialog.popup#2',
      );
      expect(
        find.byKey(const ValueKey<String>('number_skip_button')),
        findsNothing,
        reason: 'number-dialog.popup#3',
      );
      expect(
        find.byKey(const ValueKey<String>('number_unknown_button')),
        findsNothing,
        reason: 'number-dialog.popup#3',
      );
    });

    testWidgets('#5 the keypad accepts digits and the decimal separator only', (
      tester,
    ) async {
      await _openNumber(tester, value: 1.0);

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '1a2.5x',
      );
      await tester.pump();

      expect(_numberValue(tester), '12.5', reason: 'number-dialog.popup#5');
    });

    testWidgets('#8 ENTER in the value field saves', (tester) async {
      final result = await _openNumber(tester, value: 1.0, notes: 'n');

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '2.5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        result.value,
        const NumberDialogResult(2.5, 'n'),
        reason: 'number-dialog.popup#8',
      );
    });

    testWidgets('#9 Skip saves 0.003', (tester) async {
      final preferences = Preferences(MemoryStorage())..isSkipEnabled = true;
      final result = await _openNumber(
        tester,
        value: 1.0,
        preferences: preferences,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('number_skip_button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.value!.value,
        closeTo(0.003, 1e-9),
        reason: 'number-dialog.popup#9',
      );
      expect(
        (result.value!.value * 1000).round(),
        core.Entry.skip,
        reason: 'number-dialog.popup#9',
      );
    });

    testWidgets('#10 the question mark saves -0.001', (tester) async {
      final preferences = Preferences(MemoryStorage())
        ..areQuestionMarksEnabled = true;
      final result = await _openNumber(
        tester,
        value: 1.0,
        preferences: preferences,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('number_unknown_button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.value!.value,
        closeTo(-0.001, 1e-9),
        reason: 'number-dialog.popup#10',
      );
      expect(
        (result.value!.value * 1000).round(),
        core.Entry.unknown,
        reason: 'number-dialog.popup#10',
      );
    });

    testWidgets('#11 an empty field saves UNKNOWN, and notes are trimmed', (
      tester,
    ) async {
      final result = await _openNumber(tester, value: 7.0);

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('number_notes')),
        '  note  ',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('number_save_button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.value!.value,
        closeTo(-0.001, 1e-9),
        reason: 'number-dialog.popup#11',
      );
      expect(result.value!.notes, 'note', reason: 'number-dialog.popup#11');
      expect(
        find.byType(NumberDialog),
        findsNothing,
        reason: 'number-dialog.popup#11',
      );
    });

    testWidgets('#12 a dismissal with edited notes keeps the old value', (
      tester,
    ) async {
      final result = await _openNumber(tester, value: 7.0, notes: 'before');

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_notes')),
        ' after ',
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(
        result.value,
        const NumberDialogResult(7.0, 'after'),
        reason: 'number-dialog.popup#12',
      );
    });

    testWidgets('#12 a dismissal with untouched notes reports nothing', (
      tester,
    ) async {
      final result = await _openNumber(tester, value: 7.0, notes: 'before');

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue, reason: 'number-dialog.popup#12');
      expect(result.value, isNull, reason: 'number-dialog.popup#12');
    });

    testWidgets('#5 #11 the locale decimal separator is honoured', (
      tester,
    ) async {
      final result = await _openNumber(
        tester,
        value: 1.0,
        locale: const Locale('fr'),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '2,5',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('number_save_button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.value!.value,
        closeTo(2.5, 1e-9),
        reason: 'number-dialog.popup#5',
      );
    });
  });

  group('confirm-delete.dialog', () {
    testWidgets('#2 #3 the singular strings for one habit', (tester) async {
      await _open(
        tester,
        (context) => showConfirmDeleteDialog(context, quantity: 1),
      );

      expect(
        find.text('Delete habit?'),
        findsOneWidget,
        reason: 'confirm-delete.dialog#2',
      );
      expect(
        find.text(
          'The habit will be permanently deleted. This action cannot be undone.',
        ),
        findsOneWidget,
        reason: 'confirm-delete.dialog#3',
      );
    });

    testWidgets('#2 #3 the plural strings for many', (tester) async {
      await _open(
        tester,
        (context) => showConfirmDeleteDialog(context, quantity: 3),
      );

      expect(
        find.text('Delete habits?'),
        findsOneWidget,
        reason: 'confirm-delete.dialog#2',
      );
      expect(
        find.text(
          'The habits will be permanently deleted. This action cannot be undone.',
        ),
        findsOneWidget,
        reason: 'confirm-delete.dialog#3',
      );
    });

    testWidgets('#4 Yes confirms', (tester) async {
      final result = await _open<bool>(
        tester,
        (context) => showConfirmDeleteDialog(context, quantity: 1),
      );

      expect(
        find.widgetWithText(TextButton, 'Yes'),
        findsOneWidget,
        reason: 'confirm-delete.dialog#4',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Yes'));
      await tester.pumpAndSettle();

      expect(result.value, isTrue, reason: 'confirm-delete.dialog#4');
    });

    testWidgets('#5 No does nothing at all', (tester) async {
      final result = await _open<bool>(
        tester,
        (context) => showConfirmDeleteDialog(context, quantity: 2),
      );

      expect(
        find.widgetWithText(TextButton, 'No'),
        findsOneWidget,
        reason: 'confirm-delete.dialog#5',
      );
      await tester.tap(find.widgetWithText(TextButton, 'No'));
      await tester.pumpAndSettle();

      expect(result.value, isFalse, reason: 'confirm-delete.dialog#5');
      expect(
        find.byType(ConfirmDeleteDialog),
        findsNothing,
        reason: 'confirm-delete.dialog#5',
      );
    });

    testWidgets('#6 dismissing does not confirm', (tester) async {
      final result = await _open<bool>(
        tester,
        (context) => showConfirmDeleteDialog(context, quantity: 1),
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(result.completed, isTrue, reason: 'confirm-delete.dialog#6');
      expect(result.value, isFalse, reason: 'confirm-delete.dialog#6');
    });
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Where the awaited value of a dialog lands.
class _Result<T> {
  T? value;

  /// True once the future returned by the show function completed, which is
  /// the Flutter stand-in for the Android `onDismiss()` callback.
  bool completed = false;
}

/// Pumps a one-button app, taps the button and lets [show] open its dialog.
Future<_Result<T>> _open<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext context) show, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  final result = _Result<T>();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.value = await show(context);
                result.completed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Finder _swatch(int index) =>
    find.byKey(ValueKey<String>('color_swatch_$index'));

Color? _swatchColor(WidgetTester tester, int index) {
  final material = tester.widget<Material>(
    find.descendant(of: _swatch(index), matching: find.byType(Material)),
  );
  return material.color;
}

Finder _radio(FrequencyRow row) =>
    find.byKey(ValueKey<String>('frequency_radio_${row.name}'));

Finder _field(FrequencyRow row, {bool denominator = false}) => find.byKey(
  ValueKey<String>(
    'frequency_field_${row.name}${denominator ? '_denominator' : ''}',
  ),
);

String _fieldText(
  WidgetTester tester,
  FrequencyRow row, {
  bool denominator = false,
}) => tester
    .widget<TextField>(_field(row, denominator: denominator))
    .controller!
    .text;

FrequencyRow? _checkedRow(WidgetTester tester) => tester
    .widget<RadioGroup<FrequencyRow>>(find.byType(RadioGroup<FrequencyRow>))
    .groupValue;

Future<_Result<core.Frequency>> _openFrequency(
  WidgetTester tester,
  core.Frequency frequency,
) => _open<core.Frequency>(
  tester,
  (context) => showFrequencyPickerDialog(context, frequency: frequency),
);

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('frequency_save')));
  await tester.pumpAndSettle();
}

Finder _weekday(int index) => find.byKey(ValueKey<String>('weekday_$index'));

Future<_Result<core.WeekdayList>> _openWeekdays(
  WidgetTester tester,
  core.WeekdayList selected,
) => _open<core.WeekdayList>(
  tester,
  (context) => showWeekdayPickerDialog(context, selected: selected),
);

Future<_Result<CheckmarkDialogResult>> _openCheckmark(
  WidgetTester tester, {
  required int value,
  String notes = '',
  core.Color color = const core.Color.fromRgb(0xD32F2F),
  Preferences? preferences,
}) => _open<CheckmarkDialogResult>(
  tester,
  (context) => showCheckmarkDialog(
    context,
    value: value,
    notes: notes,
    color: color,
    preferences: preferences ?? Preferences(MemoryStorage()),
  ),
);

Color? _glyphColor(WidgetTester tester, String name) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey<String>('checkmark_${name}_button')),
        matching: find.byType(Text),
      ),
    )
    .style
    ?.color;

Future<_Result<NumberDialogResult>> _openNumber(
  WidgetTester tester, {
  required double value,
  String notes = '',
  core.Color color = const core.Color.fromRgb(0xD32F2F),
  Preferences? preferences,
  Locale locale = const Locale('en'),
}) => _open<NumberDialogResult>(
  tester,
  (context) => showNumberDialog(
    context,
    value: value,
    notes: notes,
    color: color,
    preferences: preferences ?? Preferences(MemoryStorage()),
  ),
  locale: locale,
);

String _numberValue(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey<String>('number_value')))
    .controller!
    .text;
