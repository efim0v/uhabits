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

    testWidgets('#4 a short last row is padded so the grid stays rectangular', (
      tester,
    ) async {
      // The vendored picker takes its colours as an array; 19 of them leave
      // the last row one short.
      await _pumpHosted(
        tester,
        (context) => const ColorPickerDialog(paletteSize: 19),
      );

      expect(
        _swatch(18),
        findsOneWidget,
        reason: 'color-picker.dialog#4 — the last colour there is',
      );
      expect(
        _swatch(19),
        findsNothing,
        reason: 'color-picker.dialog#4 — and nothing beyond it',
      );

      final blank = find.byKey(const ValueKey<String>('color_swatch_blank_19'));
      expect(
        blank,
        findsOneWidget,
        reason: 'color-picker.dialog#4 — the hole is filled with a blank view',
      );
      expect(
        tester.getSize(blank),
        tester.getSize(_swatch(18)),
        reason: 'color-picker.dialog#4 — of the same size',
      );
      // Row 4 is even, so it reads left to right and the blank sits last.
      expect(
        tester.getCenter(blank).dx,
        greaterThan(tester.getCenter(_swatch(18)).dx),
        reason: 'color-picker.dialog#4',
      );
      expect(
        tester.getCenter(blank).dy,
        tester.getCenter(_swatch(18)).dy,
        reason: 'color-picker.dialog#4 — the grid stays rectangular',
      );
    });

    testWidgets('#6 pressing or focusing a swatch darkens it', (tester) async {
      expect(
        ColorPickerDialog.pressedValueMultiplier,
        0.70,
        reason: 'color-picker.dialog#6',
      );

      const red = Color(0xFFD32F2F);
      final darkened = HSVColor.fromColor(ColorPickerDialog.darken(red));
      final original = HSVColor.fromColor(red);
      // The drawable works in 8-bit channels, so the round trip back out of
      // the Color is only accurate to 1/255.
      expect(
        darkened.value,
        closeTo(original.value * 0.70, 1 / 255),
        reason: 'color-picker.dialog#6 — the HSV value component is '
            'multiplied by 0.70',
      );
      expect(
        [darkened.hue, darkened.saturation],
        [closeTo(original.hue, 1.0), closeTo(original.saturation, 1 / 255)],
        reason: 'color-picker.dialog#6 — hue and saturation are left alone',
      );

      await _open(tester, (context) => showColorPickerDialog(context));
      final ink = tester.widget<InkWell>(
        find.descendant(of: _swatch(0), matching: find.byType(InkWell)),
      );
      final swatch = _swatchColor(tester, 0)!;
      expect(
        ink.highlightColor,
        ColorPickerDialog.darken(swatch),
        reason: 'color-picker.dialog#6 — pressed',
      );
      expect(
        ink.focusColor,
        ColorPickerDialog.darken(swatch),
        reason: 'color-picker.dialog#6 — focused',
      );
    });

    testWidgets('#10 the index round trip cannot fail', (tester) async {
      // Android hands the picker raw ARGB and converts back with
      // palette.indexOf(argb), which yields PaletteColor(-1) whenever the
      // colour is not in the current themed palette. This port passes the
      // index itself — the ledger's own note asks for it — so the tapped
      // swatch always comes back as its own index, in either theme.
      var result = await _open<core.PaletteColor>(
        tester,
        (context) => showColorPickerDialog(context),
      );
      await tester.tap(_swatch(13));
      await tester.pumpAndSettle();
      expect(
        result.value,
        const core.PaletteColor(13),
        reason: 'color-picker.dialog#10',
      );

      result = await _open<core.PaletteColor>(
        tester,
        (context) => showColorPickerDialog(context),
        theme: appThemeData(core.DarkTheme()),
      );
      await tester.tap(_swatch(13));
      await tester.pumpAndSettle();
      expect(
        result.value,
        const core.PaletteColor(13),
        reason: 'color-picker.dialog#10 — the dark palette has entirely '
            'different ARGB values, and the round trip still holds',
      );
      expect(
        result.value,
        isNot(const core.PaletteColor(-1)),
        reason: 'color-picker.dialog#10 — PaletteColor(-1) is unreachable',
      );
    });

    testWidgets('#11 the grid is there from the first frame, so no spinner '
        'ever shows', (tester) async {
      await _open(
        tester,
        (context) => showColorPickerDialog(context),
        settle: false,
      );

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'color-picker.dialog#11 — the colours are known '
            'synchronously, so the large progress spinner never stands in for '
            'the grid',
      );
      for (var i = 0; i < 20; i++) {
        expect(
          _swatch(i),
          findsOneWidget,
          reason: 'color-picker.dialog#11 — the palette is set up-front',
        );
      }
      await tester.pumpAndSettle();
    });

    testWidgets('#12 the palette and the selection survive a configuration '
        'change', (tester) async {
      await _open(
        tester,
        (context) => showColorPickerDialog(
          context,
          selected: const core.PaletteColor(5),
        ),
      );
      final before = [for (var i = 0; i < 20; i++) _swatchColor(tester, i)];

      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1200, 1800);
      await tester.pumpAndSettle();

      expect(
        [for (var i = 0; i < 20; i++) _swatchColor(tester, i)],
        before,
        reason: 'color-picker.dialog#12 — the colour array survives, as the '
            '"palette" instance-state key makes it survive upstream',
      );
      expect(
        find.descendant(of: _swatch(5), matching: find.byIcon(Icons.check)),
        findsOneWidget,
        reason: 'color-picker.dialog#12 — and so does "selected_color"',
      );
    });

    testWidgets('#13 the swatches keep palette order, never HSV order', (
      tester,
    ) async {
      await _open(tester, (context) => showColorPickerDialog(context));

      final theme = core.LightTheme();
      final order = [for (var i = 0; i < 20; i++) _swatchColor(tester, i)];
      expect(
        order,
        [for (var i = 0; i < 20; i++) toFlutterColor(theme.color(i))],
        reason: 'color-picker.dialog#13 — the grid is filled straight from the '
            'palette; HsvColorComparator is dead upstream and is not ported',
      );

      // What the unused comparator would have produced, for contrast.
      final byHue = [...order]
        ..sort(
          (a, b) => HSVColor.fromColor(
            a!,
          ).hue.compareTo(HSVColor.fromColor(b!).hue),
        );
      expect(
        order,
        isNot(byHue),
        reason: 'color-picker.dialog#13 — sorting would visibly reorder the '
            'grid, and it does not happen',
      );
    });

    testWidgets('palette-source#2 the light palette, entry by entry', (
      tester,
    ) async {
      await _open(tester, (context) => showColorPickerDialog(context));

      // @array/lightPalette resolved through res/values/material_colors.xml:
      // red_700, deep_orange_700, orange_700, amber_800, yellow_800, lime_700,
      // light_green_600, green_700, teal_600, cyan_600, light_blue_600,
      // blue_700, indigo_700, deep_purple_600, purple_600, pink_600,
      // brown_700, grey_800, grey_600, grey_500.
      expect(
        [for (var i = 0; i < 20; i++) _swatchColor(tester, i)],
        _colors(const <int>[
          0xD32F2F, 0xE64A19, 0xF57C00, 0xFF8F00, 0xF9A825,
          0xAFB42B, 0x7CB342, 0x388E3C, 0x00897B, 0x00ACC1,
          0x039BE5, 0x1976D2, 0x303F9F, 0x5E35B1, 0x8E24AA,
          0xD81B60, 0x5D4037, 0x424242, 0x757575, 0x9E9E9E,
        ]),
        reason: 'color-picker.palette-source#2',
      );
    });

    testWidgets('palette-source#3 the dark palette, entry by entry', (
      tester,
    ) async {
      await _open(
        tester,
        (context) => showColorPickerDialog(context),
        theme: appThemeData(core.DarkTheme()),
      );

      // @array/darkPalette: red_200, deep_orange_200, orange_200, amber_100,
      // yellow_200, lime_200, light_green_200, green_A200, teal_200, cyan_200,
      // light_blue_200, blue_300, indigo_200, deep_purple_200, purple_200,
      // pink_200, brown_200, grey_100, grey_300, grey_500.
      expect(
        [for (var i = 0; i < 20; i++) _swatchColor(tester, i)],
        _colors(const <int>[
          0xEF9A9A, 0xFFAB91, 0xFFCC80, 0xFFECB3, 0xFFF59D,
          0xE6EE9C, 0xC5E1A5, 0x69F0AE, 0x80CBC4, 0x80DEEA,
          0x81D4FA, 0x64B5F6, 0x9FA8DA, 0xB39DDB, 0xCE93D8,
          0xF48FB1, 0xBCAAA4, 0xF5F5F5, 0xE0E0E0, 0x9E9E9E,
        ]),
        reason: 'color-picker.palette-source#3',
      );
      // grey_500 closes both arrays; nothing else is shared at that index.
      expect(
        core.DarkTheme().color(19),
        core.LightTheme().color(19),
        reason: 'color-picker.palette-source#3',
      );
    });

    test('palette-source#4 #5 the fixed palette ignores the theme', () {
      const fixed = <String>[
        '#D32F2F', '#E64A19', '#F57C00', '#FF8F00', '#F9A825',
        '#AFB42B', '#7CB342', '#388E3C', '#00897B', '#00ACC1',
        '#039BE5', '#1976D2', '#303F9F', '#5E35B1', '#8E24AA',
        '#D81B60', '#5D4037', '#303030', '#757575', '#aaaaaa',
      ];
      expect(
        [for (var i = 0; i < 20; i++) core.PaletteColor(i).toCsvColor()],
        fixed,
        reason: 'color-picker.palette-source#4',
      );
      expect(
        [
          for (var i = 0; i < 20; i++)
            core.PaletteColor(i).toFixedAndroidColor(),
        ],
        [
          for (final hex in fixed)
            0xFF000000 | int.parse(hex.substring(1), radix: 16),
        ],
        reason: 'color-picker.palette-source#5 — the same 20 fixed values',
      );

      // Index 17 is grey_800 in the light theme and grey_100 in the dark one,
      // yet the CSV colour is #303030 in both: the mapping is theme-free.
      expect(
        core.PaletteColor(17).toCsvColor(),
        '#303030',
        reason: 'color-picker.palette-source#4',
      );
      expect(
        toFlutterColor(core.LightTheme().color(17)),
        isNot(const Color(0xFF303030)),
        reason: 'color-picker.palette-source#4',
      );
      expect(
        () => core.PaletteColor(20).toCsvColor(),
        throwsRangeError,
        reason: 'color-picker.palette-source#4 — index out of range throws',
      );
      expect(
        () => core.PaletteColor(-1).toFixedAndroidColor(),
        throwsRangeError,
        reason: 'color-picker.palette-source#5',
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

    testWidgets('#9 populateViews runs again on a resume, not only on the '
        'first show', (tester) async {
      // The dialog is hosted directly so the test can reconfigure it, which is
      // the closest a Flutter dialog gets to Android's onResume.
      final resumes = ValueNotifier<int>(0);
      addTearDown(resumes.dispose);
      await _pumpHosted(
        tester,
        (context) => ValueListenableBuilder<int>(
          valueListenable: resumes,
          builder: (context, _, _) =>
              FrequencyPickerDialog(frequency: core.Frequency(3, 7)),
        ),
      );

      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerWeek,
        reason: 'frequency-picker.options#9',
      );

      // The user checks something else...
      await tester.tap(_radio(FrequencyRow.everyDay));
      await tester.pumpAndSettle();
      expect(
        _checkedRow(tester),
        FrequencyRow.everyDay,
        reason: 'frequency-picker.options#9',
      );

      // ... and the next resume re-derives the row from the numerator and the
      // denominator the dialog was built with, throwing that choice away.
      resumes.value++;
      await tester.pumpAndSettle();
      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerWeek,
        reason: 'frequency-picker.options#9',
      );
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerWeek),
        '3',
        reason: 'frequency-picker.options#9 — the field is repopulated too',
      );
    });
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

    testWidgets('#1 all five radios are cleared and exactly one is checked', (
      tester,
    ) async {
      final frequencies = <core.Frequency>[
        core.Frequency(1, 1),
        core.Frequency(1, 5),
        core.Frequency(3, 7),
        core.Frequency(1, 31),
        core.Frequency(5, 30),
        core.Frequency(3, 14),
      ];
      for (final frequency in frequencies) {
        await _openFrequency(tester, frequency);

        final radios = tester
            .widgetList<Radio<FrequencyRow>>(find.byType(Radio<FrequencyRow>))
            .toList();
        expect(
          radios.length,
          FrequencyRow.values.length,
          reason: 'frequency-picker.populate-from-frequency#1 — five radios',
        );
        final checked = _checkedRow(tester);
        expect(
          checked,
          isNotNull,
          reason: 'frequency-picker.populate-from-frequency#1 — exactly one '
              'row is selected for $frequency',
        );
        expect(
          radios.where((radio) => radio.value == checked).length,
          1,
          reason: 'frequency-picker.populate-from-frequency#1 — the other four '
              'are left unchecked for $frequency',
        );

        // Back to an empty screen before the next frequency.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
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

    testWidgets('#1 the result starts at (1, 1) and only the checked branch '
        'touches it', (tester) async {
      // Opened on "3 times in 14 days", so that row carries 3 and 14 while the
      // three other fields keep their 3 / 3 / 10 placeholders. Checking the
      // day row must ignore every one of them.
      var result = await _openFrequency(tester, core.Frequency(3, 14));
      expect(
        _checkedRow(tester),
        FrequencyRow.xTimesPerYDays,
        reason: 'frequency-picker.save-and-validation#1',
      );
      await tester.tap(_radio(FrequencyRow.everyDay));
      await tester.pumpAndSettle();
      await _save(tester);
      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#1 — the untouched '
            'numerator and denominator are the 1 and 1 Save starts from',
      );

      // The week branch, and only it: the month field still reads 10 and the
      // day field still reads 3, and neither reaches the result.
      result = await _openFrequency(tester, core.Frequency(3, 14));
      await tester.tap(_radio(FrequencyRow.xTimesPerWeek));
      await tester.pumpAndSettle();
      await tester.enterText(_field(FrequencyRow.xTimesPerWeek), '4');
      expect(
        _fieldText(tester, FrequencyRow.xTimesPerMonth),
        '10',
        reason: 'frequency-picker.save-and-validation#1',
      );
      await _save(tester);
      expect(
        result.value,
        core.Frequency(4, 7),
        reason: 'frequency-picker.save-and-validation#1 — exactly one branch '
            'is applied',
      );
    });

    testWidgets('#10 a field cannot hold anything but digits, and an empty '
        'one falls back to (1, 1)', (tester) async {
      final result = await _openFrequency(tester, core.Frequency(1, 1));
      await tester.tap(_radio(FrequencyRow.everyXDays));
      await tester.pumpAndSettle();

      // android:inputType="number": letters and separators never land.
      await tester.enterText(_field(FrequencyRow.everyXDays), 'ab.c-9');
      await tester.pumpAndSettle();
      expect(
        _fieldText(tester, FrequencyRow.everyXDays),
        '9',
        reason: 'frequency-picker.save-and-validation#10 — non-numeric content '
            'is impossible',
      );

      // An empty field, on the other hand, is possible.
      await tester.enterText(_field(FrequencyRow.everyXDays), '');
      await tester.pumpAndSettle();
      expect(
        _fieldText(tester, FrequencyRow.everyXDays),
        '',
        reason: 'frequency-picker.save-and-validation#10',
      );
      await _save(tester);
      expect(
        result.value,
        core.Frequency(1, 1),
        reason: 'frequency-picker.save-and-validation#10 — an empty field is '
            'handled by the rules above',
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

    testWidgets('#8 the ticks survive a configuration change', (tester) async {
      // Saturday only, plus a Monday the user ticks by hand.
      final result = await _openWeekdays(tester, core.WeekdayList(1));
      await tester.tap(_weekday(2));
      await tester.pumpAndSettle();

      List<bool?> ticks() => <bool?>[
        for (var i = 0; i < 7; i++)
          tester.widget<CheckboxListTile>(_weekday(i)).value,
      ];
      expect(
        ticks(),
        [true, false, true, false, false, false, false],
        reason: 'weekday-picker.dialog#8',
      );

      // Rotate. Android restores the BooleanArray from the "selectedDays"
      // instance-state key; here the same array lives in the dialog's State,
      // which the relayout does not throw away.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(1200, 1800);
      await tester.pumpAndSettle();

      expect(
        ticks(),
        [true, false, true, false, false, false, false],
        reason: 'weekday-picker.dialog#8 — the checked array is preserved '
            'across a configuration change',
      );

      // And it is that array the positive button reports.
      await tester.tap(find.byKey(const ValueKey<String>('weekday_ok')));
      await tester.pumpAndSettle();
      expect(
        result.value,
        core.WeekdayList(1 | 4),
        reason: 'weekday-picker.dialog#8',
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
        reason: 'checkmark-dialog.popup#3 and '
            'list-habits.entry-edit-popup-boolean#2 — the popup offers the four '
            'end states as glyph buttons',
      );
      expect(
        find.byKey(const ValueKey<String>('checkmark_no_button')),
        findsOneWidget,
        reason: 'checkmark-dialog.popup#3 and '
            'list-habits.entry-edit-popup-boolean#2 — the popup offers the four '
            'end states as glyph buttons',
      );
      expect(
        find.byKey(const ValueKey<String>('checkmark_skip_button')),
        findsNothing,
        reason: 'checkmark-dialog.popup#5, '
            'list-habits.entry-edit-popup-boolean#3 and '
            'settings.preferences.skip-enabled#4 — CheckmarkDialog hides its '
            'skip button when isSkipEnabled is false',
      );
      expect(
        find.byKey(const ValueKey<String>('checkmark_unknown_button')),
        findsNothing,
        reason: 'checkmark-dialog.popup#5, '
            'list-habits.entry-edit-popup-boolean#3 and '
            'settings.preferences.question-marks#6 — and its unknown button '
            'when areQuestionMarksEnabled is false',
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
      ], reason: 'checkmark-dialog.popup#3, '
          'list-habits.entry-edit-popup-boolean#2, '
          'list-habits.entry-edit-popup-boolean#3, '
          'settings.preferences.skip-enabled#4 and '
          'settings.preferences.question-marks#6 — turning the two '
          'preferences on is what reveals the skip and unknown buttons');

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
        reason: 'checkmark-dialog.popup#3 and '
            'list-habits.entry-edit-popup-boolean#2 — the popup offers the four '
            'end states as glyph buttons',
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
        reason: 'checkmark-dialog.popup#4 and '
            'list-habits.entry-edit-popup-boolean#4',
      );
      expect(
        _glyphColor(tester, 'skip'),
        toFlutterColor(habitColor),
        reason: 'checkmark-dialog.popup#4 and '
            'list-habits.entry-edit-popup-boolean#4',
      );
      expect(
        _glyphColor(tester, 'no'),
        dim,
        reason: 'checkmark-dialog.popup#4 and '
            'list-habits.entry-edit-popup-boolean#4',
      );
      expect(
        _glyphColor(tester, 'unknown'),
        dim,
        reason: 'checkmark-dialog.popup#4 and '
            'list-habits.entry-edit-popup-boolean#4',
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
        reason: 'checkmark-dialog.popup#6 and '
            'list-habits.entry-edit-popup-boolean#2 — the notes field is '
            'prefilled with the current notes',
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
          reason: 'checkmark-dialog.popup#7 and '
              'list-habits.entry-edit-popup-boolean#5 — Yes saves '
              'YES_MANUAL(2), No saves NO(0), Skip saves SKIP(3), Unknown '
              'saves UNKNOWN(-1), with the notes trimmed',
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
        reason: 'checkmark-dialog.popup#8 and '
            'list-habits.entry-edit-popup-boolean#6 — the editor action saves '
            'with the ORIGINAL value and the trimmed notes',
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
        reason: 'checkmark-dialog.popup#9 and '
            'list-habits.entry-edit-popup-boolean#7 — a dismissal still saves '
            'the original value when the trimmed notes differ',
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
      expect(result.value, isNull,
          reason: 'checkmark-dialog.popup#9 and '
              'list-habits.entry-edit-popup-boolean#7 — unchanged notes write '
              'nothing at all');
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

    testWidgets('#1 colour, value and notes are all carried by the popup', (
      tester,
    ) async {
      const habitColor = core.Color.fromRgb(0x8E24AA);
      final result = await _openCheckmark(
        tester,
        value: core.Entry.skip,
        notes: 'ran 5k',
        color: habitColor,
      );

      // "notes": the existing note, pre-filled. There is no way to leave it
      // out — the argument is required, so the non-null assertion that crashes
      // upstream is unrepresentable here.
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('checkmark_notes')),
            )
            .controller!
            .text,
        'ran 5k',
        reason: 'checkmark-dialog.popup#1',
      );
      // "color": an ARGB already resolved through the current theme.
      expect(
        _glyphColor(tester, 'yes'),
        toFlutterColor(habitColor),
        reason: 'checkmark-dialog.popup#1 — the colour arrives resolved, not '
            'as a palette index',
      );
      // "value": the existing entry value, which the IME action hands back.
      // Re-entering the same text only connects the input; the note is
      // untouched.
      await tester.enterText(
        find.byKey(const ValueKey<String>('checkmark_notes')),
        'ran 5k',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        result.value,
        const CheckmarkDialogResult(core.Entry.skip, 'ran 5k'),
        reason: 'checkmark-dialog.popup#1',
      );
    });

    testWidgets('#10 every way out reports back, and only once the popup is '
        'gone', (tester) async {
      // A button.
      var result = await _openCheckmark(tester, value: core.Entry.no);
      await tester.tap(
        find.byKey(const ValueKey<String>('checkmark_yes_button')),
      );
      await tester.pumpAndSettle();
      expect(result.completed, isTrue, reason: 'checkmark-dialog.popup#10');
      expect(
        find.byType(CheckmarkDialog),
        findsNothing,
        reason: 'checkmark-dialog.popup#10 — onDismiss fires last',
      );

      // The IME action.
      result = await _openCheckmark(tester, value: core.Entry.no);
      await tester.enterText(
        find.byKey(const ValueKey<String>('checkmark_notes')),
        '',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result.completed, isTrue, reason: 'checkmark-dialog.popup#10');

      // A dismissal that changed the notes.
      result = await _openCheckmark(tester, value: core.Entry.no, notes: 'a');
      await tester.enterText(
        find.byKey(const ValueKey<String>('checkmark_notes')),
        'b',
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(result.completed, isTrue, reason: 'checkmark-dialog.popup#10');

      // A dismissal that changed nothing at all: still reported.
      result = await _openCheckmark(tester, value: core.Entry.no, notes: 'a');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(
        result.completed,
        isTrue,
        reason: 'checkmark-dialog.popup#10 — onDismiss() always fires, '
            'regardless of how the dialog closed',
      );
      expect(result.value, isNull, reason: 'checkmark-dialog.popup#10');
    });

    testWidgets('#12 the popup does not force the keyboard open', (
      tester,
    ) async {
      await _openCheckmark(tester, value: core.Entry.no, notes: 'a');

      final notes = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('checkmark_notes')),
      );
      expect(
        notes.autofocus,
        isFalse,
        reason: 'checkmark-dialog.popup#12 — unlike NumberDialog, nothing '
            'here asks for focus',
      );
      expect(
        tester.binding.focusManager.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
        reason: 'checkmark-dialog.popup#12 — no text field takes focus when '
            'the popup opens, so no soft keyboard comes up',
      );
    });

    testWidgets('#13 #14 four glyph buttons over a free-text notes field', (
      tester,
    ) async {
      final preferences = Preferences(MemoryStorage())
        ..isSkipEnabled = true
        ..areQuestionMarksEnabled = true;
      const habitColor = core.Color.fromRgb(0x00897B);

      // #13: the four values the four buttons stand for.
      const buttons = <String, int>{
        'yes': core.Entry.yesManual,
        'no': core.Entry.no,
        'skip': core.Entry.skip,
        'unknown': core.Entry.unknown,
      };
      expect(
        [core.Entry.yesManual, core.Entry.no, core.Entry.skip],
        [2, 0, 3],
        reason: 'checkmark-dialog.popup#13',
      );
      expect(core.Entry.unknown, -1, reason: 'checkmark-dialog.popup#13');

      for (final entry in buttons.entries) {
        final result = await _openCheckmark(
          tester,
          value: core.Entry.no,
          color: habitColor,
          preferences: preferences,
        );
        expect(
          find.byKey(const ValueKey<String>('checkmark_notes')),
          findsOneWidget,
          reason: 'checkmark-dialog.popup#13 — plus a free-text notes field',
        );
        await tester.enterText(
          find.byKey(const ValueKey<String>('checkmark_notes')),
          'note',
        );
        await tester.tap(
          find.byKey(ValueKey<String>('checkmark_${entry.key}_button')),
        );
        await tester.pumpAndSettle();
        expect(
          result.value,
          CheckmarkDialogResult(entry.value, 'note'),
          reason: 'checkmark-dialog.popup#13 — the ${entry.key} button',
        );
      }

      // #14: the tints and the typeface.
      await _openCheckmark(
        tester,
        value: core.Entry.no,
        color: habitColor,
        preferences: preferences,
      );
      final dim = toFlutterColor(core.LightTheme().mediumContrastTextColor);
      expect(
        [for (final name in buttons.keys) _glyphColor(tester, name)],
        [
          toFlutterColor(habitColor),
          dim,
          toFlutterColor(habitColor),
          dim,
        ],
        reason: 'checkmark-dialog.popup#14 — Yes and Skip take the habit '
            'colour, No and Unknown contrast60',
      );
      expect(
        [for (final name in buttons.keys) _glyphFont(tester, name)],
        ['FontAwesome', 'FontAwesome', 'FontAwesome', 'FontAwesome'],
        reason: 'checkmark-dialog.popup#14 — all four use the FontAwesome '
            'typeface',
      );
    });

    testWidgets('#15 the popup route carries the "checkmarkDialog" tag', (
      tester,
    ) async {
      final names = <String?>[];
      await _openCheckmark(
        tester,
        value: core.Entry.no,
        observers: <NavigatorObserver>[_RouteNameObserver(names)],
      );

      expect(
        CheckmarkDialog.tag,
        'checkmarkDialog',
        reason: 'checkmark-dialog.popup#15',
      );
      expect(
        names,
        contains('checkmarkDialog'),
        reason: 'checkmark-dialog.popup#15 — the popup is shown with tag '
            '"checkmarkDialog", reused here as the route name',
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
        reason: 'number-dialog.popup#4 and '
            'list-habits.entry-edit-popup-numeric#2 — "0" below 0.01, '
            "DecimalFormat('#.##') above it",
      );
      expect(
        NumberDialog.formatValue(core.Entry.skip / 1000.0, 'en'),
        '0',
        reason: 'number-dialog.popup#4',
      );
    });

    testWidgets('#4 the field opens on the formatted value', (tester) async {
      await _openNumber(tester, value: 12.345);

      expect(_numberValue(tester), '12.35',
          reason: 'number-dialog.popup#4 and '
              'list-habits.entry-edit-popup-numeric#2');
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
        reason: 'number-dialog.popup#3, '
            'list-habits.entry-edit-popup-numeric#6 and '
            'settings.preferences.skip-enabled#4 — NumberDialog hides '
            'skipBtnNumber under the same condition',
      );
      expect(
        find.byKey(const ValueKey<String>('number_unknown_button')),
        findsNothing,
        reason: 'number-dialog.popup#3, '
            'list-habits.entry-edit-popup-numeric#6 and '
            'settings.preferences.question-marks#6 — and unknownBtnNumber '
            'when question marks are off',
      );
    });

    testWidgets('#5 #16 the keypad accepts digits and the decimal separator '
        'only', (tester) async {
      await _openNumber(tester, value: 1.0);

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '1a2.5x',
      );
      await tester.pump();

      expect(_numberValue(tester), '12.5',
          reason: 'number-dialog.popup#5 and number-dialog.popup#16 — the key '
              "listener is restricted to 0-9 plus the locale's decimal "
              'separator. The second clause of number-dialog.popup#16 — '
              'switching inputType to TYPE_CLASS_TEXT on SwiftKey and Samsung '
              'keyboards so the separator key appears — is Android '
              'input-method sniffing with no Flutter counterpart');
    });

    testWidgets('#1 the dialog takes exactly colour, value and notes', (
      tester,
    ) async {
      // `arguments` upstream: "color" (Int ARGB), "value" (Double, already
      // divided by 1000) and "notes" (String). All three are required here.
      final dialog = NumberDialog(
        value: 12.345,
        notes: 'a note',
        color: const core.Color.fromRgb(0xD32F2F),
        preferences: Preferences(MemoryStorage()),
      );
      expect(dialog.value, 12.345, reason: 'number-dialog.popup#1');
      expect(dialog.notes, 'a note', reason: 'number-dialog.popup#1');
      expect(dialog.color, const core.Color.fromRgb(0xD32F2F),
          reason: 'number-dialog.popup#1');

      // And the value really is the entry value divided by 1000: the raw
      // 12345 opens the field on 12.35.
      await _openNumber(tester, value: 12345 / 1000.0, notes: 'a note');
      expect(_numberValue(tester), '12.35', reason: 'number-dialog.popup#1');
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey<String>('number_notes')))
            .controller!
            .text,
        'a note',
        reason: 'number-dialog.popup#1',
      );
    });

    testWidgets('#15 Save reports the amount and the notes, and nothing else', (
      tester,
    ) async {
      final result = await _openNumber(tester, value: 1.0);

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '2.5',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('number_save_button')),
      );
      await tester.pumpAndSettle();

      expect(result.value, const NumberDialogResult(2.5, ''),
          reason: 'number-dialog.popup#15 — `view.saveBtn.getCenter()` is '
              'computed in Kotlin save() and never used; the port has no '
              'counterpart, so the result carries the amount and the notes '
              'and no coordinates at all');
      expect(result.value!.toString(), 'NumberDialogResult(value=2.5, notes=)',
          reason: 'number-dialog.popup#15 — those two fields are the whole of '
              'what the dialog reports');
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
        reason: 'number-dialog.popup#8 and '
            'list-habits.entry-edit-popup-numeric#7 — pressing Enter in the '
            'value field saves',
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
        reason: 'number-dialog.popup#9 and '
            'list-habits.entry-edit-popup-numeric#6 — the Skip shortcut fills '
            'the field with Entry.SKIP / 1000 and saves',
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
        reason: 'number-dialog.popup#10 and '
            'list-habits.entry-edit-popup-numeric#6 — and the Unknown '
            'shortcut with Entry.UNKNOWN / 1000',
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
        reason: 'number-dialog.popup#11 and '
            'list-habits.entry-edit-popup-numeric#4 — an empty value field is '
            'stored as Entry.UNKNOWN / 1000',
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
        reason: 'number-dialog.popup#12 and '
            'list-habits.entry-edit-popup-numeric#8 — dismissing without '
            'saving still writes the entry when the trimmed notes changed, '
            'keeping the original value',
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
        reason: 'number-dialog.popup#5 and '
            'list-habits.entry-edit-popup-numeric#10 — the decimal separator '
            'accepted by the value field follows the current locale',
      );
    });

    testWidgets('unparseable input leaves the value unchanged', (tester) async {
      final result = await _openNumber(tester, value: 7.0);

      // The keypad filter lets the separator through with no digit anywhere,
      // and NumberFormat.parse then throws — `save()` swallows it and keeps the
      // value the popup opened on.
      //
      // This used to type "1.2.3", which is not unparseable at all:
      // `java.text.NumberFormat.parse` reads the prefix "1.2" and stops, so the
      // assertion pinned the port's discard rather than the rule
      // (`audit7.numeric-entry-popup-throws-away-a#1`). Corrected, not
      // loosened — the rule still says exactly what it said, and the input now
      // really is one Java refuses.
      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '..',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('number_save_button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.value,
        const NumberDialogResult(7.0, ''),
        reason: 'list-habits.entry-edit-popup-numeric#5 — unparseable input '
            'leaves the value unchanged',
      );
    });

    testWidgets('a parsable prefix is what gets saved', (tester) async {
      final result = await _openNumber(tester, value: 7.0);

      await tester.enterText(
        find.byKey(const ValueKey<String>('number_value')),
        '1.2.3',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('number_save_button')),
      );
      await tester.pumpAndSettle();

      expect(
        result.value,
        const NumberDialogResult(1.2, ''),
        reason: 'audit7.numeric-entry-popup-throws-away-a#1 and '
            'list-habits.entry-edit-popup-numeric#5 — a stray second separator '
            'ends the parse; it does not cancel it',
      );
    });

    testWidgets('#7 the value field takes focus as soon as the popup opens', (
      tester,
    ) async {
      await _openNumber(tester, value: 7.0);

      final value = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('number_value')),
      );
      expect(
        value.autofocus,
        isTrue,
        reason: 'number-dialog.popup#7 — the field requests focus and the soft '
            'keyboard comes up with it; the synthetic ACTION_DOWN/ACTION_UP '
            'pair Android needs 250ms after creation has no equivalent here',
      );
      expect(
        value.focusNode?.hasFocus,
        isTrue,
        reason: 'number-dialog.popup#7 — the keyboard is open on the value '
            'field, not on the notes field',
      );
      expect(
        value.focusNode?.hasPrimaryFocus,
        isTrue,
        reason: 'number-dialog.popup#7 — the keyboard lands on the value '
            'field, not on the notes field above it',
      );
    });

    testWidgets('#18 the popup route carries the "numberDialog" tag', (
      tester,
    ) async {
      final names = <String?>[];
      await _openNumber(
        tester,
        value: 7.0,
        observers: <NavigatorObserver>[_RouteNameObserver(names)],
      );

      expect(
        NumberDialog.tag,
        'numberDialog',
        reason: 'number-dialog.popup#18',
      );
      expect(
        names,
        contains('numberDialog'),
        reason: 'number-dialog.popup#18 — the popup is shown with tag '
            '"numberDialog", reused here as the route name',
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

    testWidgets('#1 a plain alert built around a quantity', (tester) async {
      // One dialog addresses one habit...
      await _open(
        tester,
        (context) => showConfirmDeleteDialog(context, quantity: 1),
      );
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'confirm-delete.dialog#1 — a plain AlertDialog: a title, a '
            'message and two buttons, nothing custom',
      );
      expect(
        find.text('Delete habit?'),
        findsOneWidget,
        reason: 'confirm-delete.dialog#1',
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // ... or many, from the same widget and the same quantity argument.
      await _open(
        tester,
        (context) => showConfirmDeleteDialog(context, quantity: 12),
      );
      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'confirm-delete.dialog#1',
      );
      expect(
        find.text('Delete habits?'),
        findsOneWidget,
        reason: 'confirm-delete.dialog#1 — the quantity is what lets one '
            'dialog address one habit or many',
      );
      expect(
        tester.widget<ConfirmDeleteDialog>(find.byType(ConfirmDeleteDialog))
            .quantity,
        12,
        reason: 'confirm-delete.dialog#1',
      );
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
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
  bool settle = true,
}) async {
  final result = _Result<T>();
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      navigatorObservers: observers,
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
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // One frame only: the first the dialog route ever paints.
    await tester.pump();
  }
  return result;
}

/// Hosts a dialog widget directly, without a route, so a test can rebuild it
/// under its own control.
Future<void> _pumpHosted(
  WidgetTester tester,
  WidgetBuilder builder, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: theme,
      home: Scaffold(body: Center(child: Builder(builder: builder))),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opaque Flutter colours from the RGB triples of res/values/material_colors.
List<Color> _colors(List<int> rgb) =>
    [for (final value in rgb) Color(0xFF000000 | value)];

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
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) => _open<CheckmarkDialogResult>(
  tester,
  (context) => showCheckmarkDialog(
    context,
    value: value,
    notes: notes,
    color: color,
    preferences: preferences ?? Preferences(MemoryStorage()),
  ),
  observers: observers,
);

String? _glyphFont(WidgetTester tester, String name) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(ValueKey<String>('checkmark_${name}_button')),
        matching: find.byType(Text),
      ),
    )
    .style
    ?.fontFamily;

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
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
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
  observers: observers,
);

String _numberValue(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const ValueKey<String>('number_value')))
    .controller!
    .text;

/// Records the name of every route that is pushed, so a test can assert the
/// fragment tag a dialog is shown under.
class _RouteNameObserver extends NavigatorObserver {
  _RouteNameObserver(this.names);

  final List<String?> names;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }
}
