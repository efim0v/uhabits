/// Widget tests for the numerical entry popup.
///
/// The companion of `dialogs_test.dart`, which pins the popup's shape and its
/// happy path. This file is about the arithmetic behind it: the locale decimal
/// separator, the x1000 storage convention, and what an empty or malformed
/// entry does.
///
/// Kotlin source: uhabits-android/.../activities/common/dialogs/NumberDialog.kt
/// — `save()` and `fixDecimalSeparator()` — plus the `numberButtons` row of
/// uhabits-android/src/main/res/layout/checkmark_popup.xml. Every expectation
/// cites the parity rule it pins, from docs/parity/FEATURES.md.
library;

import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/ui/common/dialogs/number_dialog.dart';
// Preferences are not re-exported from uhabits_core.dart yet.
// ignore_for_file: implementation_imports
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

void main() {
  group('number-dialog.popup — the locale decimal separator', () {
    test('#4 #5 the initial text is written with the locale symbols', () {
      // `DecimalFormat("#.##")` reads its separator from the same
      // `DecimalFormatSymbols.getInstance()` the key listener does, so the
      // text the field opens on is always typeable in that locale.
      expect(
        NumberDialog.formatValue(12.345, 'en'),
        '12.35',
        reason: 'number-dialog.popup#4',
      );
      expect(
        NumberDialog.formatValue(12.345, 'de'),
        '12,35',
        reason:
            'number-dialog.popup#4 and number-dialog.popup#5 — German '
            'formats and accepts the comma',
      );
      expect(
        NumberDialog.formatValue(12.345, 'fr'),
        '12,35',
        reason: 'number-dialog.popup#4',
      );
      // Persian is the one shipped locale whose digits are not ASCII: its
      // zero digit is U+06F0 and its separator U+066B.
      expect(
        NumberDialog.formatValue(12.345, 'fa'),
        '۱۲٫۳۵',
        reason:
            'number-dialog.popup#4 — DecimalFormat uses the locale digits, '
            'not just the locale separator',
      );
    });

    testWidgets('#5 #16 a foreign separator cannot be typed', (tester) async {
      // `DigitsKeyListener.getInstance("0123456789,")` under a German locale
      // simply drops the period, exactly as the filter does here — the amount
      // the user meant to be 12.5 becomes 125.
      final result = await _openNumber(
        tester,
        value: 1.0,
        locale: const Locale('de'),
      );

      await _type(tester, '12.5');
      expect(
        _fieldText(tester),
        '125',
        reason:
            'number-dialog.popup#5 and number-dialog.popup#16 — the key '
            "listener accepts 0-9 plus the locale's decimal separator and "
            'nothing else',
      );

      await _tapSave(tester);
      expect(
        result.value!.value,
        closeTo(125.0, 1e-9),
        reason: 'number-dialog.popup#11 — and that is what save() parses',
      );
    });

    testWidgets('#5 #11 the locale separator is the one that parses', (
      tester,
    ) async {
      final result = await _openNumber(
        tester,
        value: 1.0,
        locale: const Locale('de'),
      );

      await _type(tester, '12,5');
      await _tapSave(tester);

      expect(
        result.value!.value,
        closeTo(12.5, 1e-9),
        reason:
            'number-dialog.popup#5, number-dialog.popup#11 and '
            'list-habits.entry-edit-popup-numeric#10 — save() parses with the '
            'locale-aware NumberFormat.getInstance()',
      );
      expect(
        _stored(result.value!.value),
        12500,
        reason: 'number-dialog.popup#13 and number-dialog.popup#17',
      );
    });

    testWidgets('#4 #11 a Persian amount survives the round trip', (
      tester,
    ) async {
      final result = await _openNumber(
        tester,
        value: 12.345,
        locale: const Locale('fa'),
      );

      // Opened on the Persian rendering of 12.35...
      expect(_fieldText(tester), '۱۲٫۳۵', reason: 'number-dialog.popup#4');
      // ...and saving it untouched parses those same digits back.
      await _tapSave(tester);

      expect(
        result.value!.value,
        closeTo(12.35, 1e-9),
        reason:
            'number-dialog.popup#11 — NumberFormat.getInstance() reads the '
            'locale digits it wrote',
      );
      expect(
        _stored(result.value!.value),
        12350,
        reason: 'number-dialog.popup#13 and number-dialog.popup#17',
      );
    });
  });

  group('audit9.number-popup-follows-the-device-locale', () {
    const String rule =
        'audit9.number-popup-follows-the-device-locale#1 — In the Kotlin app: '
        'NumberDialog prefills with DecimalFormat("#.##"), builds the field\'s '
        'DigitsKeyListener alphabet from '
        'DecimalFormatSymbols.getInstance().decimalSeparator and parses on save '
        'with NumberFormat.getInstance(). All three read Locale.getDefault(), '
        'the DEVICE locale including its region, so on Español (México) — '
        'where the decimal separator is "." and the group separator "," — the '
        'popup opens on "1.5", accepts the "." key and saves 1.5.';

    testWidgets('#1 a Mexican device gets the Mexican separators', (
      tester,
    ) async {
      // The app ships no es_MX translation, so the tree resolves to bare `es`,
      // whose separator is the comma. The popup must not follow it there.
      final result = await _openNumber(
        tester,
        value: 1.5,
        locale: const Locale('es', 'MX'),
      );

      expect(
        _fieldText(tester),
        '1.5',
        reason: '$rule The prefill uses the device separator, not `es`\'s '
            'comma.',
      );

      await _type(tester, '1.5');
      expect(
        _fieldText(tester),
        '1.5',
        reason:
            '$rule …and the key listener accepts it, rather than dropping '
            'the period the user always types.',
      );

      await _tapSave(tester);
      expect(
        result.value!.value,
        closeTo(1.5, 1e-9),
        reason:
            '$rule NumberFormat.getInstance() on es_MX reads "1.5" as one and '
            'a half; on bare `es` the period is a GROUP separator and the '
            'same text silently saves fifteen.',
      );
      expect(
        _stored(result.value!.value),
        1500,
        reason: '$rule …which is 1500 in storage, not 15000.',
      );
    });

    testWidgets('#1 a British device keeps the English separators', (
      tester,
    ) async {
      final result = await _openNumber(
        tester,
        value: 1.5,
        locale: const Locale('en', 'GB'),
      );

      expect(_fieldText(tester), '1.5', reason: rule);
      await _tapSave(tester);
      expect(
        _stored(result.value!.value),
        1500,
        reason: rule,
      );
    });

    testWidgets('#1 the UI language still comes from the resolved locale', (
      tester,
    ) async {
      // The half that must NOT move: es_MX has no translation of its own, so
      // the buttons keep speaking the `es` the delegates resolved.
      await _openNumber(tester, value: 1.5, locale: const Locale('es', 'MX'));

      final BuildContext context = tester.element(find.byType(NumberDialog));
      expect(
        Localizations.localeOf(context),
        const Locale('es'),
        reason:
            '$rule Android resolves resources separately from '
            'Locale.getDefault() and falls back to the language it ships.',
      );
    });
  });

  group('number-dialog.popup — every locale the app ships', () {
    test('#4 #5 #9 #10 no shipped locale can throw out of the popup', () {
      // `DecimalFormatSymbols.getInstance()` and `NumberFormat.getInstance()`
      // cannot fail; `intl` throws ArgumentError for a locale it has no number
      // data for. Since the popup formats in `didChangeDependencies` and reads
      // the separator in `build`, an unresolved locale would take the whole
      // screen down rather than degrade.
      for (final locale in L10n.supportedLocales) {
        final name = NumberDialog.resolveLocale(locale.toString());
        final parser = intl.NumberFormat.decimalPattern(name);

        expect(
          NumberDialog.formatValue(12.345, name),
          isNotEmpty,
          reason: 'number-dialog.popup#4 — for $locale',
        );
        expect(
          parser.parse(NumberDialog.formatValue(12.345, name)),
          closeTo(12.35, 1e-9),
          reason:
              'number-dialog.popup#4 and number-dialog.popup#11 — for '
              '$locale',
        );
        // The two shortcuts write a formatted amount into the field and let
        // save() read it straight back, so their round trip has to be exact in
        // every locale — including the ones that format the minus sign as
        // U+2212 (Swedish, Finnish, Croatian, Slovenian, Basque, Norwegian).
        expect(
          _stored(
            parser
                .parse(NumberDialog.formatReserved(core.Entry.skip, name))
                .toDouble(),
          ),
          core.Entry.skip,
          reason: 'number-dialog.popup#9 — for $locale',
        );
        expect(
          _stored(
            parser
                .parse(NumberDialog.formatReserved(core.Entry.unknown, name))
                .toDouble(),
          ),
          core.Entry.unknown,
          reason: 'number-dialog.popup#10 — for $locale',
        );
      }
    });

    test('#4 #5 a locale intl has no data for degrades to the root locale', () {
      // Esperanto and Uyghur ship translations but have no CLDR number
      // symbols in `intl`. Java would fall back to the root locale here.
      expect(
        NumberDialog.resolveLocale('eo'),
        NumberDialog.rootLocaleName,
        reason:
            'number-dialog.popup#5 — NumberFormat.getInstance() degrades '
            'to the root locale instead of failing',
      );
      expect(
        NumberDialog.resolveLocale('ug'),
        NumberDialog.rootLocaleName,
        reason: 'number-dialog.popup#5',
      );
      expect(
        NumberDialog.formatValue(12.345, 'eo'),
        '12.35',
        reason:
            'number-dialog.popup#4 — the root locale uses ASCII digits and '
            'a period',
      );
      // A locale intl does know is left alone, region and script included.
      expect(
        NumberDialog.resolveLocale('pt_BR'),
        'pt_BR',
        reason: 'number-dialog.popup#5',
      );
      expect(
        NumberDialog.resolveLocale('sr_Latn'),
        'sr_Latn',
        reason: 'number-dialog.popup#5',
      );
    });

    testWidgets('#4 #5 #11 the popup opens and saves in Esperanto', (
      tester,
    ) async {
      // `flutter_localizations` has no MaterialLocalizations for `eo` either,
      // so the stock delegate list cannot even build a MaterialApp in it; that
      // gap belongs to the app shell, not to this popup, and is stubbed out
      // here so the arithmetic can be exercised on its own.
      final result = await _openNumber(
        tester,
        value: 12.345,
        locale: const Locale('eo'),
        delegates: _anyLocaleDelegates,
      );

      expect(
        _fieldText(tester),
        '12.35',
        reason:
            'number-dialog.popup#4 — the fallback separator is the root '
            "locale's period",
      );

      await _type(tester, '2,5');
      expect(
        _fieldText(tester),
        '25',
        reason:
            'number-dialog.popup#5 — and its accepted key is the period, '
            'so the comma is rejected like any other character',
      );

      await _type(tester, '2.5');
      await _tapSave(tester);

      expect(
        result.value!.value,
        closeTo(2.5, 1e-9),
        reason: 'number-dialog.popup#11',
      );
    });
  });

  group('number-dialog.popup — the x1000 storage convention', () {
    testWidgets('#13 #17 a typed amount scales by a thousand', (tester) async {
      final result = await _openNumber(tester, value: 1.0);

      await _type(tester, '2.5');
      await _tapSave(tester);

      expect(
        _stored(result.value!.value),
        2500,
        reason:
            'number-dialog.popup#13 and number-dialog.popup#17 — the '
            'caller converts the reported Double with (value * 1000)'
            '.roundToInt() before running CreateRepetitionCommand',
      );
    });

    testWidgets('#13 #17 a whole number scales exactly', (tester) async {
      final result = await _openNumber(tester, value: 1.0);

      await _type(tester, '100');
      await _tapSave(tester);

      expect(
        _stored(result.value!.value),
        100000,
        reason:
            'number-dialog.popup#13, number-dialog.popup#17 and '
            'list-habits.entry-edit-popup-numeric#3 — picking 100.0 stores '
            '100000',
      );
    });

    testWidgets(
      '#1 #4 #13 an untouched popup rewrites the entry it opened on',
      (tester) async {
        // In goes `entry.value / 1000.0`, out comes a Double the caller scales
        // back up. The round trip is the identity only down to the hundredth
        // `DecimalFormat("#.##")` prints: 12345 comes back as 12350, and
        // anything under 10 opens on the literal "0" and comes back as 0. Both
        // are upstream behaviour, and both are silent — the popup rewrites the
        // entry on Save whether or not the user touched the field.
        for (final entry in <(int, int)>[
          (0, 0),
          (1, 0),
          (9, 0),
          (500, 500),
          (2500, 2500),
          (12345, 12350),
          (100000, 100000),
        ]) {
          final result = await _openNumber(tester, value: entry.$1 / 1000.0);
          await _tapSave(tester);
          expect(
            _stored(result.value!.value),
            entry.$2,
            reason:
                'number-dialog.popup#1, number-dialog.popup#4 and '
                'number-dialog.popup#13 — for the stored value ${entry.$1}',
          );
        }
      },
    );

    testWidgets('#9 #13 Skip stores 3 and keeps the notes', (tester) async {
      final preferences = Preferences(MemoryStorage())..isSkipEnabled = true;
      final result = await _openNumber(
        tester,
        value: 1.0,
        preferences: preferences,
      );

      await tester.enterText(_notes, '  after  ');
      await tester.tap(_button('skip'));
      await tester.pumpAndSettle();

      expect(
        _stored(result.value!.value),
        core.Entry.skip,
        reason:
            'number-dialog.popup#9, number-dialog.popup#13 and '
            'number-dialog.popup#17 — 0.003 scales back to SKIP',
      );
      expect(
        result.value!.notes,
        'after',
        reason:
            'number-dialog.popup#11 — the shortcut goes through save(), '
            'which reports the trimmed notes',
      );
    });

    testWidgets('#10 #13 the question mark stores -1', (tester) async {
      final preferences = Preferences(MemoryStorage())
        ..areQuestionMarksEnabled = true;
      final result = await _openNumber(
        tester,
        value: 1.0,
        preferences: preferences,
      );

      await tester.tap(_button('unknown'));
      await tester.pumpAndSettle();

      expect(
        _stored(result.value!.value),
        core.Entry.unknown,
        reason:
            'number-dialog.popup#10, number-dialog.popup#13 and '
            'number-dialog.popup#17 — -0.001 scales back to UNKNOWN',
      );
    });
  });

  group('number-dialog.popup — empty and malformed entries', () {
    testWidgets('#11 an empty field stores UNKNOWN', (tester) async {
      final result = await _openNumber(tester, value: 7.0);

      await _type(tester, '');
      await _tapSave(tester);

      expect(
        _stored(result.value!.value),
        core.Entry.unknown,
        reason:
            'number-dialog.popup#11 and '
            'list-habits.entry-edit-popup-numeric#4 — an empty field yields '
            'Entry.UNKNOWN / 1000.0, which scales back to -1',
      );
    });

    testWidgets('#5 #11 a field emptied by the filter stores UNKNOWN', (
      tester,
    ) async {
      // Letters never reach the field, so replacing the amount with them
      // leaves it empty — the same place Android lands, since the key listener
      // rejects every character and the selection is replaced by nothing.
      final result = await _openNumber(tester, value: 7.0);

      await _type(tester, 'abc');
      expect(_fieldText(tester), '', reason: 'number-dialog.popup#5');

      await _tapSave(tester);
      expect(
        _stored(result.value!.value),
        core.Entry.unknown,
        reason: 'number-dialog.popup#11',
      );
    });

    testWidgets('#11 a second separator saves the parsable prefix', (
      tester,
    ) async {
      // The key listener does not count separators, so "1.2.3" is reachable.
      // It is NOT unparseable: `NumberFormat.parse(String)` reads from the
      // start and stops at the first character it cannot use, so Java returns
      // 1.2 and throws only when it could read nothing at all.
      //
      // This assertion used to demand 7.0 — the day's previous amount — and so
      // pinned the port's own defect rather than Kotlin's behaviour. It is
      // corrected here, not loosened: the expected value is what Java's parser
      // returns for this exact string.
      final result = await _openNumber(tester, value: 7.0);

      await _type(tester, '1.2.3');
      await _tapSave(tester);

      expect(
        result.value!.value,
        closeTo(1.2, 1e-9),
        reason:
            'audit7.numeric-entry-popup-throws-away-a#1 and '
            'number-dialog.popup#11 — java.text.NumberFormat.parse is lenient '
            'and stops at the stray second separator, so the amount saved is '
            'the prefix "1.2", not the previous value',
      );
      expect(
        _stored(result.value!.value),
        1200,
        reason:
            'audit7.numeric-entry-popup-throws-away-a#1, '
            'number-dialog.popup#13 and number-dialog.popup#17 — so the entry '
            'is rewritten with what the user actually typed',
      );
    });

    testWidgets('#11 the same leniency in a comma-decimal locale', (
      tester,
    ) async {
      // The filter accepts the comma and rejects the period under `de`, so
      // "1,2,3" is the German spelling of the same accident.
      final result = await _openNumber(
        tester,
        value: 7.0,
        locale: const Locale('de'),
      );

      await _type(tester, '1,2,3');
      expect(
        _fieldText(tester),
        '1,2,3',
        reason:
            'number-dialog.popup#5 — DigitsKeyListener("0123456789,") lets '
            'every one of these through',
      );

      await _tapSave(tester);
      expect(
        result.value!.value,
        closeTo(1.2, 1e-9),
        reason:
            'audit7.numeric-entry-popup-throws-away-a#1 — the second decimal '
            'separator ends the parse in German exactly as it does in English',
      );
    });

    testWidgets('#11 trailing junk after a whole number is dropped, not the '
        'number', (tester) async {
      final result = await _openNumber(tester, value: 7.0);

      await _type(tester, '12.');
      await _tapSave(tester);
      expect(result.value!.value, closeTo(12.0, 1e-9),
          reason: 'audit7.numeric-entry-popup-throws-away-a#1');

      final second = await _openNumber(tester, value: 7.0);
      await _type(tester, '12..5');
      await _tapSave(tester);
      expect(
        second.value!.value,
        closeTo(12.0, 1e-9),
        reason:
            'audit7.numeric-entry-popup-throws-away-a#1 — Java reads "12.", '
            'stops at the second separator and never sees the 5',
      );
    });

    testWidgets('#11 a lone separator leaves the value unchanged', (
      tester,
    ) async {
      final result = await _openNumber(tester, value: 7.0);

      await _type(tester, '.');
      expect(
        _fieldText(tester),
        '.',
        reason: 'number-dialog.popup#5 — the separator is an accepted key',
      );

      await _tapSave(tester);
      expect(
        result.value!.value,
        7.0,
        reason:
            'number-dialog.popup#11 — a field with no digits in it is not '
            'empty, so it goes through the parser and fails there',
      );
    });

    testWidgets('#11 partial amounts still parse', (tester) async {
      // Java accepts both of these, and so must the port: a trailing separator
      // is what a half-typed decimal looks like.
      for (final entry in <(String, double)>[
        ('5.', 5.0),
        ('.5', 0.5),
        ('007', 7.0),
      ]) {
        final result = await _openNumber(tester, value: 1.0);
        await _type(tester, entry.$1);
        await _tapSave(tester);

        expect(
          result.value!.value,
          closeTo(entry.$2, 1e-9),
          reason: 'number-dialog.popup#11 — "${entry.$1}"',
        );
      }
    });

    testWidgets('#11 an unchanged malformed field cannot corrupt the entry', (
      tester,
    ) async {
      // The worst case for the storage convention: a value that survives the
      // parse failure must still scale back to the integer it came from. The
      // string has to be one Java really refuses — no digit before the stop —
      // because "9.." is not one of those: it yields 9. (This test used to use
      // "9..", and so asserted the very discard the audit found.)
      final result = await _openNumber(tester, value: 12345 / 1000.0);

      await _type(tester, '..');
      await _tapSave(tester);

      expect(
        _stored(result.value!.value),
        12345,
        reason:
            'number-dialog.popup#11, number-dialog.popup#13 and '
            'number-dialog.popup#17',
      );

      final second = await _openNumber(tester, value: 12345 / 1000.0);
      await _type(tester, '9..');
      await _tapSave(tester);
      expect(
        _stored(second.value!.value),
        9000,
        reason:
            'audit7.numeric-entry-popup-throws-away-a#1 — "9.." has a '
            'parsable prefix, so Java saves 9 and the old 12.345 is gone',
      );
    });

    test('#11 the parser is Java-lenient, prefix by prefix', () {
      // The unit-level statement of the same rule: what
      // `NumberFormat.getInstance().parse(String)` returns for every string
      // the field can hold, including the ones `intl` refuses outright.
      for (final entry in <(String, String, double?)>[
        // (locale, typed text, what java.text.NumberFormat.parse returns)
        ('en', '12', 12.0),
        ('en', '1.2', 1.2),
        ('en', '1.2.3', 1.2),
        ('en', '12..5', 12.0),
        ('en', '9..', 9.0),
        ('en', '5.', 5.0),
        ('en', '.5', 0.5),
        ('en', '007', 7.0),
        // Nothing readable at index 0 — the one case Java throws on, and the
        // only one that keeps the day's previous amount.
        ('en', '.', null),
        ('en', '..', null),
        ('de', '1,2,3', 1.2),
        ('de', '1,2', 1.2),
        ('de', '1,2,', 1.2),
        ('de', ',', null),
        // Persian digits: the same walk, over a non-ASCII numbering system.
        ('fa', '۱٫۲٫۳', 1.2),
        ('fa', '٫', null),
      ]) {
        expect(
          NumberDialog.parseAmount(entry.$2, entry.$1),
          entry.$3 == null ? isNull : closeTo(entry.$3!, 1e-9),
          reason:
              'audit7.numeric-entry-popup-throws-away-a#1 — '
              '"${entry.$2}" in ${entry.$1}',
        );
      }
    });

    test('#11 the leniency holds in every locale the app ships', () {
      // The stray separator is reachable in all 48 of them, because every one
      // of them has its own accepted separator key and none of them counts
      // how many are typed. This also pins that the shortening walk never
      // escapes as something other than a FormatException.
      for (final locale in L10n.supportedLocales) {
        final name = NumberDialog.resolveLocale(locale.toString());
        final format = intl.NumberFormat.decimalPattern(name);
        final sep = format.symbols.DECIMAL_SEP;
        final typed =
            '${NumberDialog.formatValue(1.2, name)}$sep${format.format(3)}';

        expect(
          NumberDialog.parseAmount(typed, name),
          closeTo(1.2, 1e-9),
          reason:
              'audit7.numeric-entry-popup-throws-away-a#1 — "$typed" for '
              '$locale keeps its parsable prefix',
        );
        expect(
          NumberDialog.parseAmount(sep, name),
          isNull,
          reason:
              'audit7.numeric-entry-popup-throws-away-a#1 and '
              'number-dialog.popup#11 — a separator on its own is the '
              'ParseException case, in $locale as anywhere else',
        );
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// `(value * 1000).roundToInt()`, the conversion the caller applies to whatever
/// the popup reports (`number-dialog.popup#13`, `#17`). Kotlin's `roundToInt`
/// is `floor(x + 0.5)`, which is what `ListHabitsBehavior` uses.
int _stored(double value) => (value * 1000 + 0.5).floor();

final Finder _value = find.byKey(const ValueKey<String>('number_value'));

final Finder _notes = find.byKey(const ValueKey<String>('number_notes'));

Finder _button(String name) =>
    find.byKey(ValueKey<String>('number_${name}_button'));

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_value).controller!.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_value, text);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(_button('save'));
  await tester.pumpAndSettle();
}

class _Result {
  NumberDialogResult? value;

  bool completed = false;
}

/// `DefaultMaterialLocalizations` for any locale at all.
///
/// `GlobalMaterialLocalizations` covers neither Esperanto nor Uyghur, so a
/// MaterialApp cannot be built in them with the stock delegate list. That is a
/// gap in the app shell; this stub keeps it out of the way of the popup's own
/// number handling.
class _AnyLocaleMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocaleMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(_AnyLocaleMaterialLocalizationsDelegate old) => false;
}

/// The Cupertino half of the same stub.
class _AnyLocaleCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<cupertino.CupertinoLocalizations> {
  const _AnyLocaleCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<cupertino.CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<cupertino.CupertinoLocalizations>(
        const cupertino.DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(_AnyLocaleCupertinoLocalizationsDelegate old) => false;
}

const List<LocalizationsDelegate<dynamic>> _anyLocaleDelegates =
    <LocalizationsDelegate<dynamic>>[
      L10n.delegate,
      _AnyLocaleMaterialLocalizationsDelegate(),
      _AnyLocaleCupertinoLocalizationsDelegate(),
      DefaultWidgetsLocalizations.delegate,
    ];

Future<_Result> _openNumber(
  WidgetTester tester, {
  required double value,
  String notes = '',
  core.Color color = const core.Color.fromRgb(0xD32F2F),
  Preferences? preferences,
  Locale locale = const Locale('en'),
  List<LocalizationsDelegate<dynamic>>? delegates,
}) async {
  final result = _Result();
  // `locale` is the DEVICE locale: on Android the two are one setting, and
  // `DecimalFormatSymbols.getInstance()` reads `Locale.getDefault()` while the
  // strings come from resource resolution
  // (`audit9.number-popup-follows-the-device-locale#1`).
  tester.platformDispatcher.localesTestValue = <Locale>[locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: delegates ?? L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result.value = await showNumberDialog(
                  context,
                  value: value,
                  notes: notes,
                  color: color,
                  preferences: preferences ?? Preferences(MemoryStorage()),
                );
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
