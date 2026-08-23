/// Port of the button panels on the main screen:
///
///  * uhabits-android/.../habits/list/views/ButtonPanelView.kt
///  * uhabits-android/.../habits/list/views/CheckmarkPanelView.kt
///  * uhabits-android/.../habits/list/views/NumberPanelView.kt
///
/// The three Kotlin classes are collapsed into one widget because
/// HabitCardView already treats them as one slot: it builds both panels and
/// then hides whichever does not match `habit.isNumerical`. A single
/// [EntryPanel] with an [EntryPanel.isNumerical] flag renders the same thing
/// with one subtree instead of two.
///
/// The buttons themselves are *not* redrawn here. `CheckmarkButton` and
/// `NumberButton` are already ported as core [core.View]s, so each cell is a
/// [CoreView] painting the core view onto a [FlutterCanvas]. What stays in the
/// widget layer is exactly what ButtonPanelView owned upstream: how many cells
/// there are, which date each one stands for, which way round they are laid
/// out, and which callback a tap or a long press reaches.
///
/// Known gaps against the Android buttons, all of them inherited from the core
/// views rather than introduced here:
///
///  * `CheckmarkButton` paints a check or a cross and nothing else — Android
///    also has glyphs for SKIP and (when question marks are enabled) UNKNOWN,
///    and it strokes YES_AUTO as an outline. A YES_AUTO day therefore shows a
///    solid low-contrast check here, not a hollow one.
///  * `NumberButton` compares `value >= threshold` unconditionally, so an
///    at-most habit colours the wrong days. [targetType] is accepted and
///    forwarded nowhere for that reason; it is here so the call sites are
///    already correct when the core view grows the branch.
///  * neither core view draws the notes indicator. `drawNotesIndicator` does
///    exist in core, but its radius is a bare `8.0` in *device* pixels
///    (documented as such upstream), which would be a 16-logical-pixel blob on
///    a 48-logical-pixel Flutter button. Calling it would look wrong, and
///    scaling it here would be inventing a value, so [notes] is carried
///    through to the callbacks and not yet painted.
library;

// The core package does not export lib/src/ui/views or lib/src/preferences
// yet; until it does, these are the documented import paths.
// ignore_for_file: implementation_imports

import 'package:flutter/widgets.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/ui/views/checkmark_button.dart' as core_views;
import 'package:uhabits_core/src/ui/views/number_button.dart' as core_views;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../core_view.dart';

/// Kotlin: `(LocalDate, Int, String) -> Unit`, the `onToggle` of
/// CheckmarkPanelView. [value] is the value the entry is moving *to*, already
/// advanced by [core.Entry.nextToggleValue].
typedef EntryToggleCallback = void Function(
  core.LocalDate date,
  int value,
  String notes,
);

/// Kotlin: `(LocalDate) -> Unit`, the `onEdit` of both panels.
typedef EntryEditCallback = void Function(core.LocalDate date);

/// A row of entry buttons, one per visible date, newest first.
///
/// [values] and [notes] are indexed the way HabitCardListCache hands them out:
/// index 0 is today, index 1 is yesterday, and so on. [dataOffset] counts how
/// many days the panel has been scrolled into the past, so the button at
/// position `i` stands for `today - (i + dataOffset)` and reads
/// `values[i + dataOffset]`. Indices past the end of [values] fall back the way
/// the Kotlin panels do: UNKNOWN for a checkmark, 0.0 for a measurement.
class EntryPanel extends StatelessWidget {
  const EntryPanel({
    required this.values,
    required this.color,
    required this.theme,
    required this.preferences,
    this.notes = const <String>[],
    this.isNumerical = false,
    this.unit = '',
    this.targetType = core.NumericalHabitType.atLeast,
    this.targetValue = 0.0,
    this.buttonCount = 5,
    this.dataOffset = 0,
    this.onToggle,
    this.onEdit,
    super.key,
  });

  /// Raw [core.Entry] values. Numerical habits store the measurement times
  /// 1000, which this widget divides out before handing it to the core view —
  /// the same `values.map { it / 1000.0 }` HabitCardView does.
  final List<int> values;

  final List<String> notes;

  /// The habit's colour, already resolved against the theme.
  final core.Color color;

  final core.Theme theme;

  /// Read for [core.Preferences.isCheckmarkSequenceReversed],
  /// [core.Preferences.isShortToggleEnabled], [core.Preferences.isSkipEnabled]
  /// and [core.Preferences.areQuestionMarksEnabled]. The panel only reads them;
  /// nothing here writes a preference.
  final core.Preferences preferences;

  final bool isNumerical;

  final String unit;

  /// Accepted but unused — see the library comment.
  final core.NumericalHabitType targetType;

  final double targetValue;

  final int buttonCount;

  final int dataOffset;

  /// Fires only for non-numerical habits, exactly as in Kotlin: NumberPanelView
  /// has no `onToggle` at all.
  final EntryToggleCallback? onToggle;

  final EntryEditCallback? onEdit;

  /// The key of the button standing for [date], so callers and tests can reach
  /// one cell without depending on its position in the row (which
  /// [core.Preferences.isCheckmarkSequenceReversed] flips).
  static Key buttonKey(core.LocalDate date) =>
      ValueKey<String>('entryButton:${date.daysSince2000}');

  @override
  Widget build(BuildContext context) {
    final today = core.getToday();
    final buttons = <Widget>[
      for (var index = 0; index < buttonCount; index++) _buildButton(today, index),
    ];

    // ButtonPanelView.inflateButtons: the buttons are built newest-first and
    // then added in reverse when the preference is set.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          preferences.isCheckmarkSequenceReversed ? buttons.reversed.toList() : buttons,
    );
  }

  Widget _buildButton(core.LocalDate today, int index) {
    final offset = index + dataOffset;
    final date = today.minus(offset);
    final note = offset < notes.length ? notes[offset] : '';
    final key = buttonKey(date);
    final size = theme.checkmarkButtonSize;

    if (isNumerical) {
      // NumberPanelView.setupButtons: out of range is 0.0, not UNKNOWN.
      final value = offset < values.length ? values[offset] / 1000.0 : 0.0;
      // NumberButtonView answers both gestures with onEdit.
      void edit() => onEdit?.call(date);
      return EntryButton(
        key: key,
        size: size,
        view: core_views.NumberButton(color, value, targetValue, unit, theme),
        onTap: edit,
        onLongPress: edit,
      );
    }

    final value =
        offset < values.length ? values[offset] : core.Entry.unknown;

    void toggle() {
      // CheckmarkButtonView.performToggle: the button advances its own value
      // and reports the new one. The command that persists it belongs to the
      // caller.
      final next = core.Entry.nextToggleValue(
        value,
        isSkipEnabled: preferences.isSkipEnabled,
        areQuestionMarksEnabled: preferences.areQuestionMarksEnabled,
      );
      onToggle?.call(date, next, note);
    }

    void edit() => onEdit?.call(date);

    // CheckmarkButtonView.onClick / onLongClick: the preference decides which
    // gesture toggles and which one opens the editor.
    final shortToggle = preferences.isShortToggleEnabled;
    return EntryButton(
      key: key,
      size: size,
      view: core_views.CheckmarkButton(value, color, theme),
      onTap: shortToggle ? toggle : edit,
      onLongPress: shortToggle ? edit : toggle,
    );
  }
}

/// One cell of an [EntryPanel]: a core [core.View] painted into a square of
/// [size] logical pixels.
///
/// Android sizes both button views from `R.dimen.checkmarkWidth` /
/// `checkmarkHeight`, both 48dp; the same 48 is [core.Theme.checkmarkButtonSize],
/// which is what [EntryPanel] passes.
class EntryButton extends StatelessWidget {
  const EntryButton({
    required this.view,
    required this.size,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final core.View view;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CoreView(view: view, onTap: onTap, onLongPress: onLongPress),
    );
  }
}
