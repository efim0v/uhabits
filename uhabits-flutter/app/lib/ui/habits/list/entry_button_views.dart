/// The two entry-cell drawings of the habit list screen.
///
/// Port of
/// uhabits-android/src/main/java/org/isoron/uhabits/activities/habits/list/views/CheckmarkButtonView.kt
/// and .../NumberButtonView.kt (their `Drawer` inner classes), plus the shared
/// `View.drawNotesIndicator` from
/// uhabits-android/src/main/java/org/isoron/uhabits/utils/ViewExtensions.kt.
///
/// These are *not* the KMP core views of the same name. `CheckmarkButton` and
/// `NumberButton` in `uhabits_core` are the smaller drawings the shared code
/// uses (`charts-canvas-theming.checkmark-button-core`,
/// `.number-button-core`); the Android views below are the ones the shipping
/// list screen puts on screen, and they add the SKIP and question-mark glyphs,
/// the hollow YES_AUTO check, the low-contrast unset colour, the AT_MOST
/// branch, the unit trimming and the notes indicator.
///
/// They are still `core.View`s drawn on a `core.Canvas`, so the panel hosts
/// them through the same [CoreView] every other chart goes through.
///
/// Two things do not survive the canvas abstraction literally:
///
///  * Android anchors `Canvas.drawText` on the *baseline*, and both drawers
///    convert a rect centre into one by nudging the rect down (0.4·em for the
///    checkmark, 0.5·em for a unitless number). `core.Canvas.drawText` anchors
///    on the glyph's visual centre instead (`charts-canvas-theming.canvas-api#6`),
///    which is what that nudge was computing, so the nudge is not repeated
///    here. Relative offsets — the 1.3·em between a number and its unit — are
///    kept exactly.
///  * `Paint.Style.STROKE` has no counterpart on `core.Canvas`, so the
///    stroked half of the YES_AUTO check goes through the app-side
///    [TextOutlineCanvas] capability, and falls back to a filled glyph on a
///    canvas that does not offer it.
library;

// The core package does not re-export lib/src/ui/views or lib/src/gui/view.
// ignore_for_file: implementation_imports

import 'package:flutter/painting.dart' show TextScaler;
import 'package:uhabits_core/src/ui/views/number_button.dart' as core_views;
import 'package:uhabits_core/src/ui/views/ring.dart' as core_ring;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../platform/flutter_canvas.dart' show TextOutlineCanvas;

/// `R.dimen.smallTextSize` — the size the number paint and the plain glyphs
/// are drawn at.
const double smallTextSize = 14.0;

/// `R.dimen.smallerTextSize` — the question mark and the unit label.
const double smallerTextSize = 12.0;

/// The size a YES_AUTO check is drawn at (`list-habits.checkmark-button-rendering#4`).
const double yesAutoTextSize = 13.0;

/// `paint.strokeWidth = 5f` for the hollow YES_AUTO check.
const double yesAutoStrokeWidth = 5.0;

/// `canvas.drawCircle(width - cy, cy, 8f, pNotesIndicator)`.
///
/// The radius is a bare `8f` in *device* pixels upstream, which is why the dot
/// does not scale with density; a Flutter logical pixel is the unit this
/// canvas speaks, so the literal is kept as-is
/// (`charts-canvas-theming.notes-indicator#2`).
const double notesIndicatorRadius = core_ring.notesIndicatorRadius;

/// `View.drawNotesIndicator(pNotesIndicator, canvas, color, size, notes)`.
///
/// Upstream this is one `fun View.drawNotesIndicator(...)` extension shared by
/// both drawers, and it stays one function here: the body lives in the core
/// package next to the other notes indicator, and this is the keyword-argument
/// spelling the two call sites below use
/// (`charts-canvas-theming.notes-indicator#3`).
void drawNotesIndicator(
  core.Canvas canvas, {
  required core.Color color,
  required double size,
  required String notes,
}) =>
    core_ring.drawNotesIndicator(canvas, color, size, notes);

/// Port of `CheckmarkButtonView.Drawer`.
class CheckmarkButtonView extends core.View {
  CheckmarkButtonView({
    required this.value,
    required this.color,
    required this.theme,
    this.notes = '',
    this.areQuestionMarksEnabled = false,
    this.textScaler = TextScaler.noScaling,
  });

  /// A [core.Entry] value: SKIP(3), YES_MANUAL(2), YES_AUTO(1), NO(0) or
  /// UNKNOWN(-1).
  final int value;

  /// The habit's colour, already resolved through the theme.
  final core.Color color;

  final core.Theme theme;

  final String notes;

  /// `preferences.areQuestionMarksEnabled`.
  final bool areQuestionMarksEnabled;

  /// The OS font-size / accessibility text-scale setting
  /// (`audit4.check-mark-cell-glyphs-no-longer#1`).
  ///
  /// The three sizes this drawer paints with are **sp**, not dp: upstream sets
  /// them through `sp(12f)` / `sp(13f)` / `sp(14f)`, i.e.
  /// `InterfaceUtils.spToPixels`, which converts against the *scaled* density
  /// (`platform-glue.dimension-utils#2`). A Flutter logical pixel is already a
  /// dp, so the one conversion the port still owes is the font-scale one — and
  /// nothing below `core.Canvas` consults the ambient scaler the way a `Text`
  /// widget does. `EntryPanel` passes `MediaQuery.textScalerOf(context)` here,
  /// so the check, cross, skip and question-mark glyphs of every habit row grow
  /// and shrink with the setting again.
  ///
  /// [core_views.NumberButton] deliberately gets none: upstream sizes
  /// `NumberButtonView` from `getDimension` / `dim(...)`, never `sp(...)`.
  ///
  /// Defaults to [TextScaler.noScaling] — fontScale 1, where sp and dp agree.
  final TextScaler textScaler;

  /// `paint.color = when (value) { ... }`
  /// (`list-habits.checkmark-button-rendering#2`).
  core.Color get glyphColor {
    switch (value) {
      case core.Entry.yesManual:
      case core.Entry.yesAuto:
      case core.Entry.skip:
        return color;
      case core.Entry.no:
        return areQuestionMarksEnabled
            ? theme.mediumContrastTextColor
            : theme.lowContrastTextColor;
      default:
        return theme.lowContrastTextColor;
    }
  }

  /// `val id = when (value) { ... }`
  /// (`list-habits.checkmark-button-rendering#3`).
  String get glyph {
    switch (value) {
      case core.Entry.skip:
        return core.FontAwesome.skipped;
      case core.Entry.no:
        return core.FontAwesome.times;
      case core.Entry.unknown:
        return areQuestionMarksEnabled
            ? core.FontAwesome.question
            : core.FontAwesome.times;
      default:
        return core.FontAwesome.check;
    }
  }

  /// `paint.textSize = when { ... }`, each branch through `sp(...)`
  /// (`list-habits.checkmark-button-rendering#4`,
  /// `audit4.check-mark-cell-glyphs-no-longer#1`).
  double get fontSize {
    if (glyph == core.FontAwesome.question) {
      return textScaler.scale(smallerTextSize);
    }
    if (value == core.Entry.yesAuto) return textScaler.scale(yesAutoTextSize);
    return textScaler.scale(smallTextSize);
  }

  @override
  void draw(core.Canvas canvas) {
    final label = glyph;
    canvas.setFont(core.Font.fontAwesome);
    canvas.setFontSize(fontSize);
    canvas.setColor(glyphColor);

    // `val em = paint.measureText("m")`, taken under the paint the glyph is
    // about to be drawn with.
    final em = canvas.measureText('m');
    final x = canvas.getWidth() / 2.0;
    final y = canvas.getHeight() / 2.0;

    if (value == core.Entry.yesAuto) {
      // `paint.strokeWidth = 5f; paint.style = STROKE`, then the same glyph
      // re-drawn filled in the card background colour on top
      // (`list-habits.checkmark-button-rendering#5`).
      canvas.setStrokeWidth(yesAutoStrokeWidth);
      if (canvas is TextOutlineCanvas) {
        (canvas as TextOutlineCanvas).drawTextOutline(label, x, y);
      } else {
        canvas.drawText(label, x, y);
      }
      canvas.setColor(theme.cardBackgroundColor);
      canvas.setStrokeWidth(0.0);
      canvas.drawText(label, x, y);
    } else {
      // `paint.strokeWidth = 0f; paint.style = FILL`
      // (`list-habits.checkmark-button-rendering#6`).
      canvas.setStrokeWidth(0.0);
      canvas.drawText(label, x, y);
    }

    drawNotesIndicator(canvas, color: color, size: em, notes: notes);
  }
}

/// Port of `NumberButtonView.Drawer`.
///
/// Extends the core [core_views.NumberButton] so that a cell is still a
/// `NumberButton` to everything that inspects one; only [draw] is replaced.
class NumberButtonView extends core_views.NumberButton {
  NumberButtonView({
    required core.Color color,
    required double value,
    required double threshold,
    required String units,
    required core.Theme theme,
    this.targetType = core.NumericalHabitType.atLeast,
    this.notes = '',
    this.areQuestionMarksEnabled = false,
  }) : super(color, value, threshold, units, theme);

  /// `habit.targetType`.
  final core.NumericalHabitType targetType;

  final String notes;

  /// `preferences.areQuestionMarksEnabled`.
  final bool areQuestionMarksEnabled;

  /// `Entry.SKIP.toDouble() / 1000` — exactly 0.003.
  static const double skipValue = core.Entry.skip / 1000.0;

  /// `val activeColor = when { ... }` (`list-habits.number-button#3`).
  core.Color get activeColor {
    if (value < 0.0) return theme.lowContrastTextColor;
    if (targetType == core.NumericalHabitType.atLeast && value >= threshold) {
      return color;
    }
    if (targetType == core.NumericalHabitType.atMost && value <= threshold) {
      return color;
    }
    return theme.mediumContrastTextColor;
  }

  /// The four label branches, in order (`list-habits.number-button#4`).
  ({String label, core.Font font, double size}) get labelSpec {
    if (value == skipValue) {
      return (
        label: core.FontAwesome.skipped,
        font: core.Font.fontAwesome,
        size: smallTextSize,
      );
    }
    if (value >= 0) {
      return (
        label: value.toShortStringAndroid(),
        font: core.Font.bold,
        size: smallTextSize,
      );
    }
    if (areQuestionMarksEnabled) {
      return (
        label: core.FontAwesome.question,
        font: core.Font.fontAwesome,
        size: smallerTextSize,
      );
    }
    return (label: '0', font: core.Font.bold, size: smallTextSize);
  }

  /// `while (trimmedUnits.length > 2 && pUnit.measureText(trimmedUnits) >
  /// maxUnitsWidth) { trimmedUnits = trimmedUnits.dropLast(2) + "…" }`
  /// (`list-habits.number-button#9`).
  ///
  /// [measure] is the unit paint's `measureText`, i.e. 12sp in the normal
  /// condensed face.
  static String trimUnits(
    String units,
    double maxWidth,
    double Function(String) measure,
  ) {
    var trimmed = units;
    while (trimmed.length > 2 && measure(trimmed) > maxWidth) {
      trimmed = '${trimmed.substring(0, trimmed.length - 2)}…';
    }
    return trimmed;
  }

  @override
  void draw(core.Canvas canvas) {
    final width = canvas.getWidth();
    final height = canvas.getHeight();

    // `em = pNumber.measureText("m")` is computed once, in the Drawer's init
    // block, while the number paint still carries smallTextSize.
    canvas.setFont(core.Font.bold);
    canvas.setFontSize(smallTextSize);
    final em = canvas.measureText('m');

    final spec = labelSpec;
    canvas.setColor(activeColor);
    canvas.setFont(spec.font);
    canvas.setFontSize(spec.size);
    canvas.setStrokeWidth(0.0);

    if (units.trim().isEmpty) {
      // "Draw number without units" (`list-habits.number-button#7`).
      canvas.drawText(spec.label, width / 2, height / 2);
    } else {
      canvas.drawText(spec.label, width / 2, height / 2);

      // "Draw units" (`list-habits.number-button#8`, `#12`).
      canvas.setFont(core.Font.regular);
      canvas.setFontSize(smallerTextSize);
      final trimmed = trimUnits(units, width * 0.9, canvas.measureText);
      canvas.drawText(trimmed, width / 2, height / 2 + 1.3 * em);
    }

    drawNotesIndicator(canvas, color: color, size: em, notes: notes);
  }
}
