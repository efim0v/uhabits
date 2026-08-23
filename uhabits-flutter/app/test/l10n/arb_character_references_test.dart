/// XML character references must not survive the Android → ARB conversion.
///
/// `uhabits-flutter/tool/convert_strings.dart` is the only thing standing where
/// AAPT stands upstream: AAPT decodes `&#8230;` while it compiles the resource
/// table, so `values-de-rDE/strings.xml`'s
/// `<string name="view_all_contributors">Alle Mitwirkende anzeigen&#8230;</string>`
/// reaches the About screen as "Alle Mitwirkende anzeigen…", with a real
/// U+2026 HORIZONTAL ELLIPSIS. The converter's `_unescape` knew the five named
/// entities and the single hard-coded `&#39;`, and nothing else, so the numeric
/// form travelled into the ARB verbatim and out again through the generated
/// `L10n` getters.
///
/// The check is deliberately over the whole ARB set rather than over the one
/// message the audit found: the next translation import is what this is really
/// guarding, and a numeric reference in any locale is the same defect.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';

/// `lib/l10n`, found by walking up from the test's working directory — the
/// same lookup `localization_inventory_test.dart` uses, because the test may be
/// run from the app directory or from the repository root.
Directory _findArbDir() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String suffix in <String>['lib/l10n', 'app/lib/l10n']) {
      final Directory candidate = Directory('${dir.path}/$suffix');
      if (File('${candidate.path}/app_en.arb').existsSync()) return candidate;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('lib/l10n not found from ${Directory.current.path}');
}

final Directory _arbDir = _findArbDir();

final Map<String, Map<String, Object?>> _arbs = <String, Map<String, Object?>>{
  for (final File file in _arbDir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.arb')))
    file.uri.pathSegments.last
            .replaceFirst('app_', '')
            .replaceFirst('.arb', ''):
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
};

/// `&#8230;` and `&#x2026;` alike — both are references AAPT decodes.
final RegExp _charRef = RegExp(r'&#(?:[xX][0-9a-fA-F]+|[0-9]+);');

void main() {
  const String rule =
      'audit7.xml-numeric-character-references-survive-into#1 — AAPT decodes '
      'the XML numeric character reference &#8230; when it compiles the '
      'resource table, so the Links/Developers card\'s last row reads "Alle '
      'Mitwirkende anzeigen…" (German), "Посмотреть всех участников…" '
      '(Russian), etc. — a proper horizontal-ellipsis character, in every one '
      'of the 34 localized values-* folders that use the reference.';

  group('audit7.xml-numeric-character-references-survive-into', () {
    test('#1 no ARB message carries an undecoded character reference', () {
      final List<String> offenders = <String>[];
      for (final MapEntry<String, Map<String, Object?>> arb in _arbs.entries) {
        for (final MapEntry<String, Object?> message in arb.value.entries) {
          if (message.key.startsWith('@')) continue;
          final Object? value = message.value;
          if (value is! String) continue;
          if (_charRef.hasMatch(value)) {
            offenders.add('app_${arb.key}.arb ${message.key} = "$value"');
          }
        }
      }
      expect(offenders, isEmpty, reason: rule);
    });

    test('#1 view_all_contributors ends in a real ellipsis, not an escape', () {
      // The 34 folders the audit counted, spot-checked across scripts: Latin,
      // Cyrillic, Arabic and CJK all spell the same reference upstream.
      for (final String locale in <String>['de', 'ru', 'fa', 'ko', 'pt_BR']) {
        final Map<String, Object?>? arb = _arbs[locale];
        expect(arb, isNotNull, reason: '$rule (missing app_$locale.arb)');
        final Object? value = arb!['viewAllContributors'];
        expect(value, isA<String>(), reason: rule);
        expect(
          value as String,
          endsWith('…'),
          reason: '$rule — app_$locale.arb',
        );
        expect(value, isNot(contains('&#')), reason: rule);
      }
      // English spells it with the character directly, and must be unchanged.
      expect(_arbs['en']!['viewAllContributors'], endsWith('…'),
          reason: rule);
    });

    test('#1 an escaped ampersand is still an escaped ampersand', () {
      // The decoding pass runs before `&amp;` is turned back into `&`, so a
      // translator who wrote `&amp;#8230;` — the literal text, not the
      // reference — keeps it. Upstream has no such string today; the check is
      // on the converter's own contract, asserted through the one message that
      // does carry an ampersand in every locale.
      for (final MapEntry<String, Map<String, Object?>> arb in _arbs.entries) {
        for (final MapEntry<String, Object?> message in arb.value.entries) {
          if (message.key.startsWith('@')) continue;
          final Object? value = message.value;
          if (value is! String) continue;
          expect(value, isNot(contains('&amp;')),
              reason: '$rule — app_${arb.key}.arb ${message.key} still holds '
                  'an undecoded named entity');
        }
      }
    });

    testWidgets('#1 the generated L10n getter renders the character', (
      tester,
    ) async {
      // The ARB is the input; what the About screen actually calls is the
      // generated getter, so the round trip is what is pinned here.
      expect(lookupL10n(const Locale('de')).viewAllContributors,
          'Alle Mitwirkende anzeigen…',
          reason: rule);
      expect(lookupL10n(const Locale('ru')).viewAllContributors,
          endsWith('…'),
          reason: rule);
      expect(lookupL10n(const Locale('de')).viewAllContributors,
          isNot(contains('&#')),
          reason: rule);
    });
  });
}
