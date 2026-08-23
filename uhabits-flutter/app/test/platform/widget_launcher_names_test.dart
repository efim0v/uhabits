/// `audit3.home-screen-widget-names-in-the#1`: the name a home-screen widget
/// has in the launcher's widget gallery.
///
/// Upstream each of the six `<receiver>` blocks carries
/// `android:label="@string/checkmark"` … `"@string/target"`, and every one of
/// those six names is translated in all 44 `values-*/strings.xml`. The picker
/// therefore lists "Häkchen, Verlauf, Wertung, Serien, Häufigkeit, Ziel" on a
/// German device, and follows the Android 13 per-app language setting like
/// every other label. The port had six English literals in the manifest, so 43
/// translations the ARB already carries never reached the launcher.
///
/// The mechanism is the one this project already uses for the launcher label
/// and the widget chrome text — mirror the ARB into `values*/strings.xml` —
/// and for the same reason: the widget gallery is drawn by the launcher, in
/// another process, before any Dart runs. See
/// test/platform/widget_strings_test.dart, whose helpers this file repeats.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Reading the source set
// ---------------------------------------------------------------------------

final Directory androidMain =
    _find('android/app/src/main', 'AndroidManifest.xml');
final Directory arbDir = _find('lib/l10n', 'app_en.arb');

Directory _find(String suffix, String marker) {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', 'app/']) {
      final Directory candidate = Directory('${dir.path}/$prefix$suffix');
      if (File('${candidate.path}/$marker').existsSync()) return candidate;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('$suffix not found from ${Directory.current.path}');
}

String manifest() =>
    File('${androidMain.path}/AndroidManifest.xml').readAsStringSync();

String res(String relative) =>
    File('${androidMain.path}/res/$relative').readAsStringSync();

bool hasRes(String relative) =>
    File('${androidMain.path}/res/$relative').existsSync();

Map<String, String> androidStrings(String relative) => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'<string\s+name="([^"]+)"[^>]*>(.*?)</string>',
        dotAll: true,
      ).allMatches(res(relative)))
        m.group(1)!: _unescape(m.group(2)!),
    };

String _unescape(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAllMapped(RegExp(r'\\(.)'), (Match m) => m.group(1)!);

List<String> arbTags() => arbDir
    .listSync()
    .whereType<File>()
    .map((File f) => f.uri.pathSegments.last)
    .where((String n) => n.startsWith('app_') && n.endsWith('.arb'))
    .map((String n) => n.substring(4, n.length - 4))
    .toList()
  ..sort();

Map<String, Object?> arb(String tag) => jsonDecode(
      File('${arbDir.path}/app_$tag.arb').readAsStringSync(),
    ) as Map<String, Object?>;

/// The `values*` directory an ARB tag maps to — the mapping
/// test/platform/launcher_icon_test.dart and test/platform/widget_strings_test.dart
/// already use, because this is the same mirror.
String qualifierFor(String tag) {
  if (tag == 'en') return 'values';
  final List<String> parts = tag.split('_');
  final String lang =
      <String, String>{'id': 'in', 'he': 'iw'}[parts.first] ?? parts.first;
  if (parts.length == 1) return 'values-$lang';
  if (parts[1].length == 4) return 'values-b+$lang+${parts[1]}';
  return 'values-$lang-r${parts[1].toUpperCase()}';
}

/// The `<receiver>` blocks of the manifest, keyed by their simple class name.
Map<String, String> receivers() {
  final Map<String, String> result = <String, String>{};
  for (final RegExpMatch m
      in RegExp(r'<receiver\b([\s\S]*?)>', multiLine: true)
          .allMatches(manifest())) {
    final String head = m.group(1)!;
    final String? name =
        RegExp(r'android:name="([^"]+)"').firstMatch(head)?.group(1);
    if (name == null) continue;
    result[name.split('.').last] = head;
  }
  return result;
}

String? labelOf(String receiverHead) =>
    RegExp(r'android:label="([^"]+)"').firstMatch(receiverHead)?.group(1);

/// The launcher label of each provider: the resource name it must point at,
/// and the ARB key that resource is mirrored from.
const Map<String, (String, String)> providers = <String, (String, String)>{
  'CheckmarkWidgetProvider': ('checkmark', 'checkmark'),
  'HistoryWidgetProvider': ('history', 'history'),
  'ScoreWidgetProvider': ('score', 'score'),
  'StreakWidgetProvider': ('streaks', 'streaks'),
  'FrequencyWidgetProvider': ('frequency', 'frequency'),
  'TargetWidgetProvider': ('target', 'target'),
};

const String rule =
    'audit3.home-screen-widget-names-in-the#1 — In the Kotlin app: Each widget '
    'provider\'s launcher label is a localized string resource, so on a German '
    'device the widget picker lists "Häkchen, Verlauf, Wertung, Serien, '
    'Häufigkeit, Ziel"; Russian gets "Галочка, История, Результат, Рекорды, '
    'Частота, Цель"; Japanese "チェック, 履歴, スコア, 連続記録, 頻度, 目標". '
    'The names change with the Android 13 per-app language setting like every '
    'other label.';

void main() {
  group('audit3.home-screen-widget-names-in-the', () {
    test('#1 every receiver labels itself with a string resource', () {
      final Map<String, String> blocks = receivers();

      for (final MapEntry<String, (String, String)> e in providers.entries) {
        expect(blocks.containsKey(e.key), isTrue,
            reason: '$rule ${e.key} is not declared at all.');
        expect(labelOf(blocks[e.key]!), '@string/${e.value.$1}',
            reason: '$rule A literal cannot be translated; only a resource '
                'reference is resolved by the launcher, in the launcher\'s '
                'own locale.');
      }
    });

    test('#1 the English resources carry upstream\'s exact wording, and the '
        'ARB agrees', () {
      final Map<String, String> defaults = androidStrings('values/strings.xml');
      final Map<String, Object?> en = arb('en');

      expect(
        <String, String?>{
          for (final (String name, _) in providers.values) name: defaults[name],
        },
        <String, String>{
          'checkmark': 'Checkmark',
          'history': 'History',
          'score': 'Score',
          'streaks': 'Streaks',
          'frequency': 'Frequency',
          'target': 'Target',
        },
        reason: '$rule These six names and values are upstream\'s '
            'res/values/strings.xml, unchanged.',
      );
      for (final (String name, String key) in providers.values) {
        expect(defaults[name], en[key],
            reason: '$rule values/strings.xml disagrees with app_en.arb for '
                '$name.');
      }
    });

    test('#1 every locale the ARB translates them in has them mirrored', () {
      int localized = 0;
      for (final String tag in arbTags()) {
        if (tag == 'en') continue;
        final Map<String, Object?> messages = arb(tag);
        final String dir = qualifierFor(tag);
        Map<String, String>? strings;
        for (final (String name, String key) in providers.values) {
          final Object? value = messages[key];
          if (value == null) continue;
          expect(hasRes('$dir/strings.xml'), isTrue,
              reason: '$rule Missing $dir/strings.xml for ARB "$tag".');
          strings ??= androidStrings('$dir/strings.xml');
          expect(strings[name], value,
              reason: '$rule $dir disagrees with app_$tag.arb for $name.');
        }
        if (strings != null) localized++;
      }

      expect(localized, greaterThan(40),
          reason: '$rule "losing 43 translations" is the whole translated set, '
              'not a sample.');
    });

    test('#1 the three the rule names, in their own scripts', () {
      expect(
        <String>[
          for (final (String name, _) in providers.values)
            androidStrings('values-de/strings.xml')[name]!,
        ],
        <String>['Häkchen', 'Verlauf', 'Wertung', 'Serien', 'Häufigkeit', 'Ziel'],
        reason: rule,
      );
      expect(
        <String>[
          for (final (String name, _) in providers.values)
            androidStrings('values-ru/strings.xml')[name]!,
        ],
        <String>['Галочка', 'История', 'Результат', 'Рекорды', 'Частота', 'Цель'],
        reason: rule,
      );
      expect(
        <String>[
          for (final (String name, _) in providers.values)
            androidStrings('values-ja/strings.xml')[name]!,
        ],
        <String>['チェック', '履歴', 'スコア', '連続記録', '頻度', '目標'],
        reason: rule,
      );
    });
  });
}
