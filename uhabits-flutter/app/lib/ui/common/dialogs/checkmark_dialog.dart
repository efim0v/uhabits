/// Port of uhabits-android/.../activities/common/dialogs/CheckmarkDialog.kt
/// and the `booleanButtons` half of
/// uhabits-android/src/main/res/layout/checkmark_popup.xml.
///
/// A borderless popup with a notes field on top and a row of four
/// FontAwesome buttons below. The four buttons are the four end states —
/// YES_MANUAL, SKIP, NO, UNKNOWN — offered directly rather than cycled
/// (`models.entry-values#10`); `Entry.nextToggleValue` is only used when the
/// short-toggle preference bypasses this dialog altogether.
///
/// The dialog runs no command. It hands back the value and the notes and the
/// caller decides what to do with them — upstream that is
/// `CreateRepetitionCommand`, plus the confetti the list screen fires when the
/// value changed to YES_MANUAL (`checkmark-dialog.popup#11`).
///
/// Two Android details that do not survive the crossing:
///
///  * `onDismiss()` "always fires last, regardless of how the dialog closed"
///    (`checkmark-dialog.popup#10`). A `Future` is that callback: the caller
///    resumes exactly once, after the dialog is gone.
///  * the "dismiss whatever is tracked as current first" half of
///    `dismissCurrentAndShow` (`checkmark-dialog.popup#15`) belongs to
///    `dialogs.single-current-dialog` and is not this file's business; the tag
///    it is shown under survives as the route name, the way
///    `HistoryEditorDialog` keeps its own.
library;

import 'package:flutter/material.dart';
// Preferences are not re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

/// The geometry of checkmark_popup.xml, in logical pixels
/// (`checkmark-dialog.popup#2`).
class EntryPopupMetrics {
  EntryPopupMetrics._();

  static const double minWidth = 208.0;

  static const double minHeight = 128.0;

  /// `android:layout_height="48dp"` on both button rows.
  static const double buttonRowHeight = 48.0;

  /// `@drawable/checkmark_dialog_bg`: a 5dp-rounded rectangle with a 2dp
  /// stroke.
  static const double cornerRadius = 5.0;

  static const double borderWidth = 2.0;

  /// `android:padding="4dp"` on the notes field.
  static const EdgeInsets notesPadding = EdgeInsets.all(4);
}

/// What the dialog reports: the entry value and the trimmed notes, the pair
/// `onToggle(value, notes)` carries upstream.
class CheckmarkDialogResult {
  const CheckmarkDialogResult(this.value, this.notes);

  /// One of [core.Entry.yesManual], [core.Entry.skip], [core.Entry.no] or
  /// [core.Entry.unknown] (`checkmark-dialog.popup#7`).
  final int value;

  /// Already trimmed.
  final String notes;

  @override
  bool operator ==(Object other) =>
      other is CheckmarkDialogResult &&
      other.value == value &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(value, notes);

  @override
  String toString() => 'CheckmarkDialogResult(value=$value, notes=$notes)';
}

/// Shows the yes/no entry popup and completes with the value the user chose.
///
/// Completes with null when the dialog is dismissed without a choice *and* the
/// notes were left alone. When the notes were edited and the dialog is
/// dismissed by tapping outside or pressing back, it completes with the
/// ORIGINAL value and the new notes, so the edit is not lost
/// (`checkmark-dialog.popup#9`).
///
/// [color] is the habit's colour already resolved against the current theme —
/// `theme.colorOf(habit.color)` — matching the resolved ARGB the Android
/// arguments carry (`checkmark-dialog.popup#1`).
Future<CheckmarkDialogResult?> showCheckmarkDialog(
  BuildContext context, {
  required int value,
  required String notes,
  required core.Color color,
  required core.Preferences preferences,
}) async {
  final draft = NotesDraft(notes);
  final result = await showDialog<CheckmarkDialogResult>(
    context: context,
    routeSettings: const RouteSettings(name: CheckmarkDialog.tag),
    builder: (context) => CheckmarkDialog(
      value: value,
      notes: notes,
      color: color,
      preferences: preferences,
      draft: draft,
    ),
  );
  if (result != null) return result;
  final current = draft.notes.trim();
  if (current != notes) return CheckmarkDialogResult(value, current);
  return null;
}

/// Carries the notes text out of a dialog that was dismissed without a save
/// action, which is the only way `onDismiss`'s "notes changed" branch can be
/// reached through a `Future`-shaped API.
class NotesDraft {
  NotesDraft(this.notes);

  String notes;
}

/// The popup itself, exposed for tests and for screens that manage their own
/// route.
class CheckmarkDialog extends StatefulWidget {
  const CheckmarkDialog({
    super.key,
    required this.value,
    required this.notes,
    required this.color,
    required this.preferences,
    this.draft,
  });

  /// The fragment tag `ListHabitsScreen` and `ShowHabitActivity` show the
  /// popup under, reused here as the route name
  /// (`checkmark-dialog.popup#15`).
  static const String tag = 'checkmarkDialog';

  final int value;

  final String notes;

  final core.Color color;

  final core.Preferences preferences;

  /// Written on every keystroke so [showCheckmarkDialog] can recover the text
  /// after a dismissal. Null when the widget is hosted directly.
  final NotesDraft? draft;

  @override
  State<CheckmarkDialog> createState() => _CheckmarkDialogState();
}

class _CheckmarkDialogState extends State<CheckmarkDialog> {
  late final TextEditingController _notes = TextEditingController(
    text: widget.notes,
  )..addListener(() => widget.draft?.notes = _notes.text);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// `onClick(v)`: report the value with the trimmed notes and dismiss
  /// (`checkmark-dialog.popup#7`).
  void _report(int value) {
    Navigator.of(context).pop(CheckmarkDialogResult(value, _notes.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = coreThemeOf(context);
    final habitColor = toFlutterColor(widget.color);
    // ?attr/contrast60 is @color/grey_500 in every theme, which is the core
    // theme's mediumContrastTextColor (`checkmark-dialog.popup#4`).
    final dim = toFlutterColor(theme.mediumContrastTextColor);

    return Dialog(
      // `dialog.window.setBackgroundDrawableResource(android.R.color.transparent)`
      // plus `@drawable/checkmark_dialog_bg` on the root LinearLayout.
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: EntryPopupMetrics.minWidth,
          minHeight: EntryPopupMetrics.minHeight,
          maxWidth: EntryPopupMetrics.minWidth,
        ),
        decoration: BoxDecoration(
          color: toFlutterColor(theme.cardBackgroundColor),
          borderRadius: BorderRadius.circular(EntryPopupMetrics.cornerRadius),
          border: Border.all(
            color: toFlutterColor(theme.lowContrastTextColor),
            width: EntryPopupMetrics.borderWidth,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Padding(
                padding: EntryPopupMetrics.notesPadding,
                child: TextField(
                  key: const ValueKey<String>('checkmark_notes'),
                  controller: _notes,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n.notes,
                  ),
                  // Pressing the IME action returns the ORIGINAL value with the
                  // trimmed notes (`checkmark-dialog.popup#8`).
                  onSubmitted: (_) => _report(widget.value),
                ),
              ),
            ),
            Divider(
              height: EntryPopupMetrics.borderWidth,
              thickness: EntryPopupMetrics.borderWidth,
              color: toFlutterColor(theme.lowContrastTextColor),
            ),
            SizedBox(
              height: EntryPopupMetrics.buttonRowHeight,
              child: Row(
                children: <Widget>[
                  _button(
                    name: 'yes',
                    glyph: core.FontAwesome.check,
                    color: habitColor,
                    onTap: () => _report(core.Entry.yesManual),
                  ),
                  // GONE unless the preference is on
                  // (`checkmark-dialog.popup#5`).
                  if (widget.preferences.isSkipEnabled)
                    _button(
                      name: 'skip',
                      glyph: core.FontAwesome.skipped,
                      color: habitColor,
                      onTap: () => _report(core.Entry.skip),
                    ),
                  _button(
                    name: 'no',
                    glyph: core.FontAwesome.times,
                    color: dim,
                    onTap: () => _report(core.Entry.no),
                  ),
                  if (widget.preferences.areQuestionMarksEnabled)
                    _button(
                      name: 'unknown',
                      glyph: core.FontAwesome.question,
                      color: dim,
                      onTap: () => _report(core.Entry.unknown),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One `CheckmarkPopupBtn`: equal weight, centred, FontAwesome typeface
  /// (`checkmark-dialog.popup#3`).
  Widget _button({
    required String name,
    required String glyph,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        key: ValueKey<String>('checkmark_${name}_button'),
        onTap: onTap,
        child: Center(
          child: Text(
            glyph,
            style: TextStyle(fontFamily: 'FontAwesome', color: color),
          ),
        ),
      ),
    );
  }
}
