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
/// The cells paint [CheckmarkButtonView] and [NumberButtonView] — the ports of
/// the *Android* button views, not the smaller KMP ones in `uhabits_core` — so
/// the SKIP and question-mark glyphs, the hollow YES_AUTO check, the AT_MOST
/// colouring, the unit trimming and the notes indicator are all present.
library;

// The core package does not export lib/src/ui/views or lib/src/preferences
// yet; until it does, these are the documented import paths.
// ignore_for_file: implementation_imports

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../core_view.dart';
import 'entry_button_views.dart';

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

/// Reports which cell was just pressed, together with the centre of that cell
/// in the panel's own coordinates.
///
/// Kotlin: `HabitCardView.getRelativeButtonLocation(date)`, which reads
/// `panel.x + button.x + button.width / 2` and `button.height / 2` straight off
/// the laid-out children. The panel computes the same point analytically —
/// every cell is [core.Theme.checkmarkButtonSize] wide and the row has no
/// spacing — so the caller does not need a key per button.
typedef EntryPressedCallback = void Function(
  core.LocalDate date,
  Offset centerInPanel,
);

/// A row of entry buttons, one per visible date, newest first.
///
/// [values] and [notes] are indexed the way HabitCardListCache hands them out:
/// index 0 is today, index 1 is yesterday, and so on. [dataOffset] counts how
/// many days the panel has been scrolled into the past, so the button at
/// position `i` stands for `today - (i + dataOffset)` and reads
/// `values[i + dataOffset]`. Indices past the end of [values] fall back the way
/// the Kotlin panels do: UNKNOWN for a checkmark, 0.0 for a measurement.
class EntryPanel extends StatefulWidget {
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
    this.onPressed,
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

  /// `habit.targetType`; the number cells colour an at-most day the other way
  /// round (`list-habits.number-button#3`).
  final core.NumericalHabitType targetType;

  final double targetValue;

  final int buttonCount;

  final int dataOffset;

  /// Fires only for non-numerical habits, exactly as in Kotlin: NumberPanelView
  /// has no `onToggle` at all.
  final EntryToggleCallback? onToggle;

  final EntryEditCallback? onEdit;

  /// Fires for every gesture that reaches a cell, before [onToggle] / [onEdit].
  /// `HabitCardView` uses it to place the ripple hotspot.
  final EntryPressedCallback? onPressed;

  /// The key of the button standing for [date], so callers and tests can reach
  /// one cell without depending on its position in the row (which
  /// [core.Preferences.isCheckmarkSequenceReversed] flips).
  static Key buttonKey(core.LocalDate date) =>
      ValueKey<String>('entryButton:${date.daysSince2000}');

  @override
  State<EntryPanel> createState() => _EntryPanelState();
}

class _EntryPanelState extends State<EntryPanel> {
  /// `CheckmarkButtonView.value`, the field `performToggle()` writes before it
  /// reports anything to the presenter (`list-habits.toggle-from-row#4`).
  ///
  /// Keyed by [core.LocalDate.daysSince2000]. A rebind clears it, exactly as
  /// `ButtonPanelView.setupButtons` overwrites `button.value` on every refresh.
  final Map<int, int> _optimisticValues = <int, int>{};

  late final _PanelPreferencesListener _preferencesListener;

  @override
  void initState() {
    super.initState();
    // `ButtonPanelView.onAttachedToWindow`: the panel listens to the
    // preferences while it is attached, and re-inflates its buttons when the
    // checkmark sequence flips (`list-habits.entry-panels#9`).
    _preferencesListener = _PanelPreferencesListener(_onCheckmarkSequenceChanged);
    widget.preferences.addListener(_preferencesListener);
  }

  @override
  void didUpdateWidget(EntryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.preferences, widget.preferences)) {
      oldWidget.preferences.removeListener(_preferencesListener);
      widget.preferences.addListener(_preferencesListener);
    }
    // `HabitCardListView.bindCardView` pushes the cached values back into every
    // button, which is what discards an optimistic value once the command has
    // been through the cache.
    _optimisticValues.clear();
  }

  @override
  void dispose() {
    // `ButtonPanelView.onDetachedFromWindow`.
    widget.preferences.removeListener(_preferencesListener);
    super.dispose();
  }

  void _onCheckmarkSequenceChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final today = core.getToday();
    final buttons = <Widget>[
      for (var index = 0; index < widget.buttonCount; index++)
        _buildButton(today, index),
    ];

    // ButtonPanelView.inflateButtons: the buttons are built newest-first and
    // then added in reverse when the preference is set.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.preferences.isCheckmarkSequenceReversed
          ? buttons.reversed.toList()
          : buttons,
    );
  }

  /// `HabitCardView.getRelativeButtonLocation`, in panel coordinates: the
  /// horizontal centre of the cell that ended up at [position] in the row, and
  /// `button.height / 2` vertically.
  Offset _centerOf(int position) {
    final size = widget.theme.checkmarkButtonSize;
    return Offset((position + 0.5) * size, size / 2);
  }

  Widget _buildButton(core.LocalDate today, int index) {
    final offset = index + widget.dataOffset;
    final date = today.minus(offset);
    final note = offset < widget.notes.length ? widget.notes[offset] : '';
    final key = EntryPanel.buttonKey(date);
    final size = widget.theme.checkmarkButtonSize;
    final position = widget.preferences.isCheckmarkSequenceReversed
        ? widget.buttonCount - 1 - index
        : index;
    void reportPress() =>
        widget.onPressed?.call(date, _centerOf(position));

    if (widget.isNumerical) {
      // NumberPanelView.setupButtons: out of range is 0.0, not UNKNOWN.
      final value =
          offset < widget.values.length ? widget.values[offset] / 1000.0 : 0.0;
      // NumberButtonView answers both gestures with onEdit.
      void edit() {
        reportPress();
        widget.onEdit?.call(date);
      }

      return EntryButton(
        key: key,
        size: size,
        view: NumberButtonView(
          color: widget.color,
          value: value,
          threshold: widget.targetValue,
          units: widget.unit,
          theme: widget.theme,
          targetType: widget.targetType,
          notes: note,
          areQuestionMarksEnabled:
              widget.preferences.areQuestionMarksEnabled,
        ),
        onTap: edit,
        onLongPress: edit,
      );
    }

    final stored =
        offset < widget.values.length ? widget.values[offset] : core.Entry.unknown;
    final value = _optimisticValues[date.daysSince2000] ?? stored;

    void toggle() {
      // CheckmarkButtonView.performToggle: the button advances its own value
      // and reports the new one. The command that persists it belongs to the
      // caller.
      final next = core.Entry.nextToggleValue(
        value,
        isSkipEnabled: widget.preferences.isSkipEnabled,
        areQuestionMarksEnabled: widget.preferences.areQuestionMarksEnabled,
      );
      reportPress();
      // `value = Entry.nextToggleValue(...)` runs *before* `onToggle(...)`, and
      // the setter invalidates, so the cell repaints with the new value whether
      // or not the command ever comes back.
      setState(() => _optimisticValues[date.daysSince2000] = next);
      widget.onToggle?.call(date, next, note);
      // `performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)`, the last
      // thing performToggle does. The argument-less `HapticFeedback.vibrate()`
      // is that same constant: the Android embedder answers
      // HapticFeedbackType.STANDARD with LONG_PRESS
      // (`audit3.toggling-a-check-mark-on-the#1`).
      HapticFeedback.vibrate();
    }

    void edit() {
      reportPress();
      widget.onEdit?.call(date);
    }

    // CheckmarkButtonView.onClick / onLongClick: the preference decides which
    // gesture toggles and which one opens the editor.
    final shortToggle = widget.preferences.isShortToggleEnabled;
    return EntryButton(
      key: key,
      size: size,
      view: CheckmarkButtonView(
        value: value,
        color: widget.color,
        theme: widget.theme,
        notes: note,
        areQuestionMarksEnabled: widget.preferences.areQuestionMarksEnabled,
        // `paint.textSize = sp(...)`: the glyph sizes are sp, so they follow
        // the OS font-size / accessibility text-scale setting
        // (`audit4.check-mark-cell-glyphs-no-longer#1`). This is the same
        // scaler a `Text` widget would read, and depending on it here is what
        // repaints the row when the user moves the slider.
        textScaler: MediaQuery.textScalerOf(context),
      ),
      onTap: shortToggle ? toggle : edit,
      onLongPress: shortToggle ? edit : toggle,
    );
  }
}

/// `Preferences.Listener`, narrowed to the one callback ButtonPanelView
/// overrides.
class _PanelPreferencesListener extends core.PreferencesListener {
  _PanelPreferencesListener(this._onChanged);

  final VoidCallback _onChanged;

  @override
  void onCheckmarkSequenceChanged() => _onChanged();
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
