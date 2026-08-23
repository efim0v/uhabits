/// Port of the palette picker:
///
///  * uhabits-android/.../activities/common/dialogs/ColorPickerDialog.kt
///  * uhabits-android/.../activities/common/dialogs/ColorPickerDialogFactory.kt
///  * the vendored uhabits-android/.../com/android/colorpicker/{ColorPickerDialog,
///    ColorPickerPalette,ColorPickerSwatch,ColorStateDrawable}.java
///  * uhabits-android/src/main/res/layout/{color_picker_dialog,color_picker_swatch}.xml
///  * uhabits-android/src/main/res/values/pickers.xml (the swatch dimensions
///    and the two non-translatable content descriptions)
///
/// The one deliberate departure is the one the parity ledger asks for
/// (`color-picker.dialog`, Notes): Android hands the vendored picker an array
/// of raw ARGB values and converts the tapped colour back with
/// `palette.indexOf(argb)`, which yields `PaletteColor(-1)` whenever the
/// themed palette does not contain that exact colour (`color-picker.dialog#10`).
/// This port passes the palette *index* around instead, so the round trip
/// cannot fail and `#10`'s failure mode simply does not exist.
///
/// Not ported, on purpose:
///
///  * the progress spinner that stands in for the grid until the colours
///    arrive (`color-picker.dialog#11`) — the palette is known synchronously
///    here, so the grid is on screen from the first frame and the spinner
///    would never be visible;
///  * `com.android.colorpicker.HsvColorComparator`, dead upstream
///    (`color-picker.dialog#13`): the swatches are laid out in palette order,
///    never sorted;
///  * the instance-state round trip (`color-picker.dialog#12`), which has no
///    Flutter analogue: the dialog is rebuilt from its arguments, so the
///    palette and the selected colour survive a configuration change without
///    a Bundle.
library;

// `Color` below is Flutter's; the core one is only ever reached through the
// `core` prefix, so there is nothing to hide.
import 'package:flutter/material.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// The geometry of `SIZE_SMALL` (`color-picker.dialog#2`), from
/// res/values/pickers.xml: `color_swatch_small` = 48dp, with
/// `color_swatch_margins_small` = 4dp on every side.
class ColorPickerMetrics {
  ColorPickerMetrics._();

  static const double swatchSize = 48.0;

  static const double swatchMargin = 4.0;

  /// `ColorPickerDialogFactory.create` passes `columns = 4`
  /// (`color-picker.dialog#1`).
  static const int columns = 4;

  /// The palette is 20 entries long in every theme
  /// (`color-picker.palette-source#2`, `#3`), which at four columns is five
  /// rows with none left over (`color-picker.dialog#3`).
  static const int paletteSize = 20;
}

/// Shows the palette grid and completes with the colour the user tapped.
///
/// Completes with null when the dialog is dismissed without a choice
/// (`color-picker.dialog#9`); there is no OK button to wait for, a tap on a
/// swatch is the answer (`color-picker.dialog#8`).
///
/// [selected] is the habit's current colour: its swatch is the one carrying
/// the checkmark. Pass null for "nothing selected", which is what an ARGB that
/// is not in the palette used to produce.
Future<core.PaletteColor?> showColorPickerDialog(
  BuildContext context, {
  core.PaletteColor? selected,
}) {
  return showDialog<core.PaletteColor>(
    context: context,
    builder: (context) => ColorPickerDialog(selected: selected),
  );
}

/// The dialog itself, exposed so it can be hosted directly by a test or by a
/// screen that manages its own route.
class ColorPickerDialog extends StatelessWidget {
  const ColorPickerDialog({
    super.key,
    this.selected,
    this.paletteSize = ColorPickerMetrics.paletteSize,
  });

  final core.PaletteColor? selected;

  /// How many colours the grid holds.
  ///
  /// `ColorPickerDialog.newInstance` takes the palette as an `IntArray`, so a
  /// shorter one is representable; the app always hands over the full 20, and
  /// the only thing a shorter one changes is that the last row needs padding
  /// (`color-picker.dialog#4`).
  final int paletteSize;

  /// `ColorStateDrawable` multiplies the colour's HSV value component by 0.70
  /// while the swatch is pressed or focused (`color-picker.dialog#6`).
  static const double pressedValueMultiplier = 0.70;

  static Color darken(Color color) {
    final hsv = HSVColor.fromColor(color);
    return hsv.withValue(hsv.value * pressedValueMultiplier).toColor();
  }

  /// The palette index shown at row [row], column [column] of the grid.
  ///
  /// `ColorPickerPalette.drawPalette` fills the table in serpentine order:
  /// a swatch is appended to the row on even-numbered rows and inserted at
  /// position 0 on odd-numbered ones, so odd rows read right to left
  /// (`color-picker.dialog#3`).
  static int paletteIndexAt(int row, int column) {
    final columns = ColorPickerMetrics.columns;
    final isReversed = row.isOdd;
    final positionInRow = isReversed ? columns - 1 - column : column;
    return row * columns + positionInRow;
  }

  /// The 1-based index `ColorPickerPalette.setSwatchDescription` puts in the
  /// content description: the swatch's place in natural reading order, which
  /// on a reversed row is `((rowNumber + 1) * columns) - rowElements`
  /// (`color-picker.dialog#7`).
  static int accessibilityIndexAt(int row, int column) =>
      row * ColorPickerMetrics.columns + column + 1;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = coreThemeOf(context);
    const columns = ColorPickerMetrics.columns;
    final rows = (paletteSize / columns).ceil();

    return AlertDialog(
      // R.string.color_picker_default_title = "Change color"
      // (`color-picker.dialog#1`).
      title: Text(l10n.colorPickerDefaultTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var row = 0; row < rows; row++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var column = 0; column < columns; column++)
                    _swatchAt(context, theme, row, column),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _swatchAt(
    BuildContext context,
    core.Theme theme,
    int row,
    int column,
  ) {
    final index = paletteIndexAt(row, column);

    // "Create blank views to fill the row if the last row has not been
    // filled" (`color-picker.dialog#4`). With 20 colours and 4 columns this
    // never runs, but a shorter palette keeps the grid rectangular.
    if (index >= paletteSize) {
      return _BlankSwatch(key: ValueKey<String>('color_swatch_blank_$index'));
    }

    final isSelected = selected?.paletteIndex == index;
    return _ColorSwatch(
      key: ValueKey<String>('color_swatch_$index'),
      color: toFlutterColor(theme.color(index)),
      isSelected: isSelected,
      // res/values/pickers.xml declares both strings translatable="false", so
      // they are literals here rather than L10n keys.
      semanticsLabel: isSelected
          ? 'Color ${accessibilityIndexAt(row, column)} selected'
          : 'Color ${accessibilityIndexAt(row, column)}',
      onTap: () => Navigator.of(context).pop(core.PaletteColor(index)),
    );
  }
}

/// One circular swatch: a filled circle, plus a checkmark when it is the
/// current colour (`color-picker.dialog#5`).
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final Color color;

  final bool isSelected;

  final String semanticsLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: isSelected,
      child: Padding(
        padding: const EdgeInsets.all(ColorPickerMetrics.swatchMargin),
        child: SizedBox(
          width: ColorPickerMetrics.swatchSize,
          height: ColorPickerMetrics.swatchSize,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              // Pressed and focused both darken the swatch
              // (`color-picker.dialog#6`).
              highlightColor: ColorPickerDialog.darken(color),
              focusColor: ColorPickerDialog.darken(color),
              onTap: onTap,
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color:
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    )
                  : const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// `ColorPickerPalette.createBlankSpace` — an empty view of the same size.
class _BlankSwatch extends StatelessWidget {
  const _BlankSwatch({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(ColorPickerMetrics.swatchMargin),
    child: SizedBox(
      width: ColorPickerMetrics.swatchSize,
      height: ColorPickerMetrics.swatchSize,
    ),
  );
}
