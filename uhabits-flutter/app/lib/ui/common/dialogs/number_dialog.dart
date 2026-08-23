/// Port of uhabits-android/.../activities/common/dialogs/NumberDialog.kt
/// and the `numberButtons` half of
/// uhabits-android/src/main/res/layout/checkmark_popup.xml.
///
/// The same borderless popup as [CheckmarkDialog] — the shell constants come
/// from that file, because upstream both dialogs inflate the same layout — with
/// a decimal amount instead of the four state buttons: a numeric field, then
/// Save, then Skip, then the FontAwesome question mark
/// (`number-dialog.popup#2`).
///
/// The dialog runs no command. It reports the amount in *display* units, and
/// the caller multiplies by 1000 and rounds before issuing
/// `CreateRepetitionCommand` (`number-dialog.popup#13`, `#17`).
///
/// Android details that do not cross:
///
///  * the SwiftKey/Samsung input-method sniffing (`number-dialog.popup#6`) and
///    the synthetic touch pair that forces the keyboard open
///    (`number-dialog.popup#7`) are Android-specific; the field simply
///    autofocuses here;
///  * `view.saveBtn.getCenter()` is dead code upstream
///    (`number-dialog.popup#15`) and is not ported;
///  * the "dismiss whatever is tracked as current first" half of
///    `dismissCurrentAndShow` (`number-dialog.popup#18`) belongs to
///    `dialogs.single-current-dialog`; the tag it is shown under survives as
///    the route name, the way `HistoryEditorDialog` keeps its own.
///
/// Java's `NumberFormat.parse` is lenient and stops at the first character it
/// cannot read, while `intl`'s insists on consuming the whole string and throws
/// otherwise. That difference is *not* invisible here, as this comment used to
/// claim: the field's `FilteringTextInputFormatter.allow(RegExp('[0-9<sep>]'))`
/// places no limit on how many separators are typed, exactly as Android's
/// `DigitsKeyListener.getInstance("0123456789" + separator)` does not, so
/// "1.2.3" is reachable on both sides — and where Java saves 1.2, `intl` threw
/// and the popup wrote the day's PREVIOUS amount back
/// (`audit7.numeric-entry-popup-throws-away-a#1`). The leniency is reproduced
/// deliberately in [NumberDialog.parseAmount]; only the case Java itself throws
/// on — nothing readable at all — still keeps the original value
/// (`number-dialog.popup#11`).
///
/// The other `intl`-versus-Java gap is locale coverage, and it is not a
/// narrowing but a crash: see [NumberDialog.resolveLocale].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
// Preferences are not re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/uhabits_core.dart' as core;

import '../../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'checkmark_dialog.dart' show EntryPopupMetrics, NotesDraft;

/// What the dialog reports: the amount in display units and the trimmed notes.
class NumberDialogResult {
  const NumberDialogResult(this.value, this.notes);

  /// The measurement the user typed, already divided by 1000 the way the
  /// argument arrives (`number-dialog.popup#1`). Skip is 0.003 and unknown is
  /// -0.001, which round back to [core.Entry.skip] and [core.Entry.unknown]
  /// (`number-dialog.popup#9`, `#10`).
  final double value;

  /// Already trimmed.
  final String notes;

  @override
  bool operator ==(Object other) =>
      other is NumberDialogResult &&
      other.value == value &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(value, notes);

  @override
  String toString() => 'NumberDialogResult(value=$value, notes=$notes)';
}

/// Shows the numerical entry popup and completes with the amount entered.
///
/// Completes with null when the dialog is dismissed without saving *and* the
/// notes were left alone; when the notes were edited it completes with the
/// ORIGINAL value and the new notes (`number-dialog.popup#12`).
///
/// [value] is the existing entry value already divided by 1000.
Future<NumberDialogResult?> showNumberDialog(
  BuildContext context, {
  required double value,
  required String notes,
  required core.Color color,
  required core.Preferences preferences,
}) async {
  final draft = NotesDraft(notes);
  final result = await showDialog<NumberDialogResult>(
    context: context,
    routeSettings: const RouteSettings(name: NumberDialog.tag),
    builder: (context) => NumberDialog(
      value: value,
      notes: notes,
      color: color,
      preferences: preferences,
      draft: draft,
    ),
  );
  if (result != null) return result;
  final current = draft.notes.trim();
  if (current != notes) return NumberDialogResult(value, current);
  return null;
}

/// The popup itself, exposed for tests and for screens that manage their own
/// route.
class NumberDialog extends StatefulWidget {
  const NumberDialog({
    super.key,
    required this.value,
    required this.notes,
    required this.color,
    required this.preferences,
    this.draft,
  });

  /// The fragment tag `ListHabitsScreen` and `ShowHabitActivity` show the
  /// popup under, reused here as the route name (`number-dialog.popup#18`).
  static const String tag = 'numberDialog';

  final double value;

  final String notes;

  /// The habit's colour, resolved against the current theme.
  ///
  /// It is accepted because the Android arguments carry it
  /// (`number-dialog.popup#1`), and it is as invisible here as it is there:
  /// `NumberDialog.onCreateDialog` tints `yesBtn` and `noBtn`, both of which
  /// live in the `booleanButtons` row that stays GONE for a numerical habit.
  /// Only the question-mark button is tinted, and it uses contrast60.
  final core.Color color;

  final core.Preferences preferences;

  /// Written on every keystroke so [showNumberDialog] can recover the text
  /// after a dismissal. Null when the widget is hosted directly.
  final NotesDraft? draft;

  /// The locale actually used to format and parse the amount.
  ///
  /// `DecimalFormatSymbols.getInstance()` and `NumberFormat.getInstance()`
  /// cannot fail: a locale the JDK has no data for silently degrades to the
  /// root locale, which uses ASCII digits, `.` as the decimal separator and
  /// `-` as the minus sign. `intl` is stricter and throws `ArgumentError` for
  /// a locale it has no number symbols for — and two of the locales this app
  /// ships translations for, Esperanto (`eo`) and Uyghur (`ug`), are exactly
  /// that. Left unresolved, opening the popup in either one throws out of
  /// `build`, so every format in this file is built through here
  /// (`number-dialog.popup#4`, `#5`, `#11`, `#16`).
  ///
  /// `Intl.verifiedLocale` already walks the CLDR fallbacks, keeping the
  /// region and script of a locale it does know (`pt_BR`, `sr_Latn`) and
  /// falling back to the bare language for one it does not. [rootLocaleName]
  /// stands in for Java's root locale when even that finds nothing.
  static String? resolveLocale(String? localeName) => intl.Intl.verifiedLocale(
    localeName,
    intl.NumberFormat.localeExists,
    onFailure: (_) => rootLocaleName,
  );

  /// The stand-in for Java's root locale: ASCII digits, `.` and `-`.
  static const String rootLocaleName = 'en';

  /// The initial text of the value field (`number-dialog.popup#4`).
  ///
  /// Anything below 0.01 shows as the literal "0", which is why UNKNOWN
  /// (-0.001) and SKIP (0.003) both open as "0".
  ///
  /// Java formats with `DecimalFormat("#.##")`; the pattern here forces the
  /// leading zero that Java prints anyway, so 0.5 stays "0.5", 12.345 becomes
  /// "12.35" and 15.0 becomes "15".
  static String formatValue(double value, [String? localeName]) {
    if (value < 0.01) return '0';
    return intl.NumberFormat('0.##', resolveLocale(localeName)).format(value);
  }

  /// `DecimalFormat("#.###").format(Entry.SKIP / 1000.0)` and its UNKNOWN twin
  /// (`number-dialog.popup#9`, `#10`).
  static String formatReserved(int entryValue, [String? localeName]) =>
      intl.NumberFormat(
        '0.###',
        resolveLocale(localeName),
      ).format(entryValue / 1000.0);

  /// `NumberFormat.getInstance().parse(text)`, leniency included
  /// (`number-dialog.popup#11`,
  /// `audit7.numeric-entry-popup-throws-away-a#1`).
  ///
  /// Java parses from index 0 and stops at the first character it cannot use,
  /// returning whatever it read up to there; it raises `ParseException` only
  /// when it could read nothing at all. Returns null in exactly that case, so
  /// the caller keeps the value it started with.
  static double? parseAmount(String text, [String? localeName]) =>
      parseAmountWith(
        intl.NumberFormat.decimalPattern(resolveLocale(localeName)),
        text,
      );

  /// [parseAmount] against a format that is already built.
  ///
  /// The leniency is reproduced as "the longest prefix this format accepts",
  /// which is the same answer Java's character walk gives over the alphabet the
  /// field can hold — digits and the locale decimal separator, and nothing else
  /// (`number-dialog.popup#5`, `#16`). Java stops at the second separator; so
  /// does this, because every prefix that still contains it is refused.
  static double? parseAmountWith(intl.NumberFormat format, String text) {
    for (int end = text.length; end > 0; end--) {
      try {
        return format.parse(text.substring(0, end)).toDouble();
      } on FormatException {
        // This is the character Java would have stopped at. Try the prefix
        // that ends before it.
      }
    }
    return null;
  }

  @override
  State<NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<NumberDialog> {
  late final TextEditingController _notes = TextEditingController(
    text: widget.notes,
  )..addListener(() => widget.draft?.notes = _notes.text);

  final TextEditingController _value = TextEditingController();

  final FocusNode _valueNode = FocusNode();

  /// Resolved in [didChangeDependencies], where the ambient locale is known,
  /// and put through [NumberDialog.resolveLocale] so it is a locale `intl`
  /// really has number symbols for.
  String? _localeName;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // `android:selectAllOnFocus="true"` on the value field.
    _valueNode.addListener(() {
      if (!_valueNode.hasFocus) return;
      _value.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _value.text.length,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _localeName = NumberDialog.resolveLocale(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    _value.text = NumberDialog.formatValue(widget.value, _localeName);
  }

  @override
  void dispose() {
    _notes.dispose();
    _value.dispose();
    _valueNode.dispose();
    super.dispose();
  }

  /// `NumberFormat.getInstance()` — the grouping decimal format of the current
  /// locale, which is both what `save()` parses with and where the field's
  /// accepted separator comes from (`number-dialog.popup#5`, `#11`).
  ///
  /// Built once: `_localeName` is fixed in [didChangeDependencies], which runs
  /// before the first [build].
  late final intl.NumberFormat _parser = intl.NumberFormat.decimalPattern(
    _localeName,
  );

  /// `save()` (`number-dialog.popup#11`).
  void _save() {
    var value = widget.value;
    final text = _value.text;
    if (text.isEmpty) {
      value = core.Entry.unknown / 1000.0;
    } else {
      // `numberFormat.parse(valueStr)!!.toDouble()`, which reads as far as it
      // can and throws only when that is nowhere
      // (`audit7.numeric-entry-popup-throws-away-a#1`).
      final parsed = NumberDialog.parseAmountWith(_parser, text);
      // NOP on null — the original value survives, as it does past a
      // ParseException.
      if (parsed != null) value = parsed;
    }
    Navigator.of(context).pop(NumberDialogResult(value, _notes.text.trim()));
  }

  /// The Skip and question-mark buttons write a reserved amount into the field
  /// and then save.
  void _saveReserved(int entryValue) {
    _value.text = NumberDialog.formatReserved(entryValue, _localeName);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = coreThemeOf(context);
    // ?attr/contrast60 (`number-dialog.popup#2`, via CheckmarkDialog's #4).
    final dim = toFlutterColor(theme.mediumContrastTextColor);
    final separator = _parser.symbols.DECIMAL_SEP;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: EntryPopupMetrics.minWidth,
          minHeight: EntryPopupMetrics.minHeight,
          maxWidth: EntryPopupMetrics.minWidth,
        ),
        // The same `@drawable/checkmark_dialog_bg` the boolean popup uses —
        // one layout, one drawable: `<solid ?attr/contrast0>` with a 2dp
        // `<stroke ?contrast40>`
        // (`audit8.entry-popups-paint-themselves-cardbgcolor-over#1`).
        decoration: BoxDecoration(
          color: toFlutterColor(theme.contrast0),
          borderRadius: BorderRadius.circular(EntryPopupMetrics.cornerRadius),
          border: Border.all(
            color: toFlutterColor(theme.contrast40),
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
                  key: const ValueKey<String>('number_notes'),
                  controller: _notes,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: l10n.notes,
                  ),
                  // The IME action inside the notes field also saves
                  // (`number-dialog.popup#8`).
                  onSubmitted: (_) => _save(),
                ),
              ),
            ),
            // `@drawable/checkmark_dialog_divider`: `<solid ?contrast40>`
            // (`audit8.entry-popups-paint-themselves-cardbgcolor-over#1`).
            Divider(
              height: EntryPopupMetrics.borderWidth,
              thickness: EntryPopupMetrics.borderWidth,
              color: toFlutterColor(theme.contrast40),
            ),
            SizedBox(
              height: EntryPopupMetrics.buttonRowHeight,
              child: Row(
                children: <Widget>[
                  Expanded(
                    // `android:layout_weight="2"` on the value field.
                    flex: 2,
                    child: TextField(
                      key: const ValueKey<String>('number_value'),
                      controller: _value,
                      focusNode: _valueNode,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      // The keypad accepts digits and the locale decimal
                      // separator only (`number-dialog.popup#5`, `#16`) —
                      // literally `DigitsKeyListener.getInstance("0123456789" +
                      // separator)`, so ASCII digits even where the locale
                      // formats with its own (Persian). No minus sign: upstream
                      // has none either, which is why the UNKNOWN shortcut has
                      // to write "-0.001" into the controller itself.
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp('[0-9${RegExp.escape(separator)}]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      // ENTER inside the value field saves
                      // (`number-dialog.popup#8`).
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  _textButton(
                    name: 'save',
                    // NumericalPopupBtn is textAllCaps.
                    label: l10n.save.toUpperCase(),
                    onTap: _save,
                  ),
                  // GONE unless the preference is on
                  // (`number-dialog.popup#3`).
                  if (widget.preferences.isSkipEnabled)
                    _textButton(
                      name: 'skip',
                      label: l10n.skipDay.toUpperCase(),
                      onTap: () => _saveReserved(core.Entry.skip),
                    ),
                  if (widget.preferences.areQuestionMarksEnabled)
                    _textButton(
                      name: 'unknown',
                      label: core.FontAwesome.question,
                      fontFamily: 'FontAwesome',
                      color: dim,
                      onTap: () => _saveReserved(core.Entry.unknown),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One `NumericalPopupBtn`: wrap_content with 12dp side padding, bold,
  /// centred.
  Widget _textButton({
    required String name,
    required String label,
    required VoidCallback onTap,
    String? fontFamily,
    Color? color,
  }) {
    return InkWell(
      key: ValueKey<String>('number_${name}_button'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: fontFamily,
              color: color,
              fontWeight: fontFamily == null ? FontWeight.bold : null,
            ),
          ),
        ),
      ),
    );
  }
}
