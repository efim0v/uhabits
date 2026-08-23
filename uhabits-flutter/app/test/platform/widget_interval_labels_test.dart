/// `audit5.target-widget-s-interval-labels-are`: the five row labels on the
/// Target home-screen widget.
///
/// Upstream they are ordinary translatable resources —
/// `TargetCardView.intervalToLabel(resources, interval)` resolves
/// `R.string.today`, `R.string.week`, `R.string.month`, `R.string.quarter` and
/// `R.string.year` — so a widget drawn in the launcher's process picks the
/// device language up from the resource table before any code runs, in all 45
/// shipped locales and under the Android 13 per-app language override. The port
/// had them as Kotlin `when` literals ("Today", "Week", …) and as Swift
/// literals in `TargetCardState.labels`, which no translation can reach.
///
/// ## The mechanism, and why this one
///
/// The same one `audit.android-widget-chrome-text-is-hard` and
/// `audit4.ios-every-string-the-widget-surface` already established: mirror the
/// ARB catalogue into `res/values*/strings.xml` on Android and into
/// `ios/HabitsWidget/*.lproj/Localizable.strings` on iOS, and have the widget
/// code name a key rather than a sentence.
///
/// The published document is the other candidate and it loses here for the
/// same reason it lost there. A row label is not data about a habit: the
/// widget process already knows which windows it is drawing, and the only
/// thing it lacks is the user's language — which Android and iOS both resolve
/// themselves, per-app-language included, without asking the app. Putting the
/// five words in every per-widget document would also freeze them at publish
/// time: change the phone's language and every widget would keep the old words
/// until the app next ran.
///
/// ## What is asserted
///
/// That neither `intervalToLabel` implementation contains an English sentence,
/// that both name the five keys, that the English resource is the ARB's own
/// text, and that every locale the ARB translates carries the mirror — because
/// a key with no table entry is not English on iOS, it is the key itself.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Locating the source sets
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory androidRes =
    Directory('${appDir.path}/android/app/src/main/res');
final Directory widgetKotlinDir = Directory(
    '${appDir.path}/android/app/src/main/kotlin/org/isoron/uhabits/widgets');
final Directory iosWidgetDir = Directory('${appDir.path}/ios/HabitsWidget');
final Directory arbDir = Directory('${appDir.path}/lib/l10n');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/ios/HabitsWidget/TargetWidget.swift')
          .existsSync()) {
        return candidate;
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('app/ not found from ${Directory.current.path}');
}

String widgetKotlin(String name) =>
    File('${widgetKotlinDir.path}/$name').readAsStringSync();

String swift(String name) =>
    File('${iosWidgetDir.path}/$name').readAsStringSync();

/// [source] with its comments stripped, so an assertion about what the code
/// does cannot be satisfied — or defeated — by prose that merely quotes the
/// thing. Same helper, same reason, as widget_strings_test.dart.
String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

Map<String, String> androidStrings(String relative) => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'<string\s+name="([^"]+)"[^>]*>(.*?)</string>',
        dotAll: true,
      ).allMatches(File('${androidRes.path}/$relative').readAsStringSync()))
        m.group(1)!: _unescape(m.group(2)!),
    };

String _unescape(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAllMapped(RegExp(r'\\(.)'), (Match m) => m.group(1)!);

bool hasRes(String relative) =>
    File('${androidRes.path}/$relative').existsSync();

/// The ARB locale tag of every `app_*.arb`.
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
/// test/platform/widget_strings_test.dart and
/// test/platform/launcher_icon_test.dart already share.
String qualifierFor(String tag) {
  if (tag == 'en') return 'values';
  final List<String> parts = tag.split('_');
  final String lang =
      <String, String>{'id': 'in', 'he': 'iw'}[parts.first] ?? parts.first;
  if (parts.length == 1) return 'values-$lang';
  if (parts[1].length == 4) return 'values-b+$lang+${parts[1]}';
  return 'values-$lang-r${parts[1].toUpperCase()}';
}

/// Apple's identifiers are hyphenated, the ARB file names are not.
String lproj(String tag) => tag.replaceAll('_', '-');

Map<String, String> stringsTable(String tag) => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
        multiLine: true,
      ).allMatches(
          File('${iosWidgetDir.path}/${lproj(tag)}.lproj/Localizable.strings')
              .readAsStringSync()))
        m.group(1)!: m
            .group(2)!
            .replaceAllMapped(RegExp(r'\\(.)'), (Match e) => e.group(1)!),
    };

bool hasTable(String tag) =>
    File('${iosWidgetDir.path}/${lproj(tag)}.lproj/Localizable.strings')
        .existsSync();

// ---------------------------------------------------------------------------
// The five labels
// ---------------------------------------------------------------------------

/// The resource name each interval resolves to, keyed by the `when` branch it
/// is reached through. These are upstream's own resource names, unchanged.
const Map<String, String> intervalResources = <String, String>{
  '1': 'today',
  '7': 'week',
  '30': 'month',
  '91': 'quarter',
  'else': 'year',
};

/// The ARB key each resource is mirrored from. They happen to be spelled the
/// same, and that is worth pinning: `R.string.today` is `app_*.arb`'s `today`.
const Map<String, String> arbKeys = <String, String>{
  'today': 'today',
  'week': 'week',
  'month': 'month',
  'quarter': 'quarter',
  'year': 'year',
};

const String rule1 =
    'audit5.target-widget-s-interval-labels-are#1 — In the Kotlin app: '
    '`intervalToLabel(resources, interval)` resolves `R.string.today`, '
    '`R.string.week`, `R.string.month`, `R.string.quarter`, `R.string.year`, '
    'so the row labels on the Target widget appear in the device language '
    '(all 45 shipped locales, including the Android 13 per-app language).';

void main() {
  group('audit5.target-widget-s-interval-labels-are', () {
    // -------------------------------------------------------------------
    // Android: the Kotlin names resources
    // -------------------------------------------------------------------

    test('#1 intervalToLabel resolves R.string ids, not English literals', () {
      final String widget = withoutComments(widgetKotlin('TargetWidget.kt'));
      final String body =
          widget.substring(widget.indexOf('fun intervalToLabel'));

      for (final String literal in <String>[
        '"Today"',
        '"Week"',
        '"Month"',
        '"Quarter"',
        '"Year"',
      ]) {
        expect(body, isNot(contains(literal)),
            reason: '$rule1 A literal is what makes the row label '
                'untranslatable: the widget is drawn in the launcher\'s '
                'process, where the Flutter ARB bundle is unreachable and the '
                'resource table is the only thing that speaks the user\'s '
                'language.');
      }

      expect(
        <String, String?>{
          for (final MapEntry<String, String> e in intervalResources.entries)
            e.key: RegExp('(?<![0-9])${RegExp.escape(e.key)} -> '
                    r'resources\.getString\(R\.string\.(\w+)\)')
                .firstMatch(body)
                ?.group(1),
        },
        intervalResources,
        reason: '$rule1 The five branches keep upstream\'s own mapping: 1 -> '
            'R.string.today, 7 -> R.string.week, 30 -> R.string.month, 91 -> '
            'R.string.quarter, anything else -> R.string.year.',
      );
    });

    test('#1 the id is resolved against the widget\'s own resources', () {
      final String widget = withoutComments(widgetKotlin('TargetWidget.kt'));

      expect(
        widget,
        contains('fun intervalToLabel(resources: Resources, interval: Int)'),
        reason: '$rule1 Upstream\'s signature is '
            '`intervalToLabel(resources, interval)`; a resource id only '
            'becomes the device language when something resolves it, and the '
            'Resources handed in are the launcher-process ones the widget is '
            'being inflated with.',
      );
      expect(
        widget,
        contains('resources.getString('),
        reason: '$rule1 Naming an id and never calling getString on it leaves '
            'the label empty, not translated.',
      );
      expect(
        widget,
        contains('intervalToLabel(context.resources, it.interval)'),
        reason: '$rule1 `refreshData` is where upstream passes '
            '`context.resources`, and the context is the widget\'s.',
      );
    });

    // -------------------------------------------------------------------
    // Android: the resources exist and are the ARB's
    // -------------------------------------------------------------------

    test('#1 the English resources carry the ARB\'s own words', () {
      final Map<String, String> defaults = androidStrings('values/strings.xml');
      final Map<String, Object?> en = arb('en');

      expect(
        <String, String?>{
          for (final String name in arbKeys.keys) name: defaults[name],
        },
        <String, String>{
          'today': 'Today',
          'week': 'Week',
          'month': 'Month',
          'quarter': 'Quarter',
          'year': 'Year',
        },
        reason: '$rule1 The five names and the five values are upstream\'s '
            'res/values/strings.xml, unchanged.',
      );
      for (final MapEntry<String, String> e in arbKeys.entries) {
        expect(defaults[e.key], en[e.value],
            reason: '$rule1 values/strings.xml disagrees with app_en.arb for '
                '${e.key}; the app and the widget must say one word.');
      }
    });

    test('#1 every locale the ARB translates is mirrored', () {
      int localized = 0;
      for (final String tag in arbTags()) {
        final Map<String, Object?> messages = arb(tag);
        final String dir = qualifierFor(tag);
        bool any = false;
        for (final MapEntry<String, String> e in arbKeys.entries) {
          final Object? value = messages[e.value];
          if (value == null) continue;
          any = true;
          expect(hasRes('$dir/strings.xml'), isTrue,
              reason: '$rule1 Missing $dir/strings.xml for ARB "$tag".');
          expect(androidStrings('$dir/strings.xml')[e.key], value,
              reason: '$rule1 $dir disagrees with app_$tag.arb for ${e.key}.');
        }
        if (any) localized++;
      }
      expect(localized, greaterThan(40),
          reason: '$rule1 "all 45 shipped locales" is the whole translated '
              'set, not a sample.');

      // Two spot checks in two scripts, so the mirror is proved to carry
      // translations rather than copies of the template.
      expect(androidStrings('values-de/strings.xml')['quarter'], 'Quartal',
          reason: rule1);
      expect(androidStrings('values-ru/strings.xml')['week'], 'Неделя',
          reason: rule1);
    });

    // -------------------------------------------------------------------
    // iOS: the same five labels, the same way
    // -------------------------------------------------------------------

    test('#1 the WidgetKit labels are keys, not English literals', () {
      final String source = withoutComments(swift('TargetWidget.swift'));
      final String body = source.substring(source.indexOf('var labels:'));

      for (final String literal in <String>[
        'return "Today"',
        'return "Week"',
        'return "Month"',
        'return "Quarter"',
        'return "Year"',
      ]) {
        expect(body, isNot(contains(literal)),
            reason: '$rule1 The iOS Target widget draws the same five rows '
                'and had the same five English literals; a WidgetKit extension '
                'resolves its own bundle\'s .lproj tables, so it can carry the '
                'translation exactly as Android does.');
      }

      for (final String key in arbKeys.keys) {
        expect(body, contains('NSLocalizedString("$key"'),
            reason: '$rule1 The label is measured and drawn as a String, so '
                'the lookup has to happen here: `Text(String)` renders text '
                'verbatim, and the Canvas never sees a LocalizedStringKey.');
      }
    });

    test('#1 every widget .strings table carries the five keys', () {
      for (final String tag in arbTags().where(hasTable)) {
        final Map<String, String> table = stringsTable(tag);
        final Map<String, Object?> messages = arb(tag);
        for (final MapEntry<String, String> e in arbKeys.entries) {
          expect(table[e.key], isNotNull,
              reason: '$rule1 ${lproj(tag)}.lproj is missing "${e.key}". A key '
                  'with no table entry does not fall back to English on iOS — '
                  'the user is shown the key itself.');
          final Object? translation = messages[e.value];
          if (translation == null) continue;
          expect(table[e.key], translation,
              reason: '$rule1 ${lproj(tag)}.lproj disagrees with app_$tag.arb '
                  'for ${e.key}.');
        }
      }

      // The English table is the fallback every untranslated locale lands on,
      // and it has to agree with what Android shows.
      final Map<String, String> en = stringsTable('en');
      final Map<String, String> android = androidStrings('values/strings.xml');
      for (final String key in arbKeys.keys) {
        expect(en[key], android[key],
            reason: '$rule1 The two widget surfaces must not drift: "$key" is '
                'one word on both platforms.');
      }

      expect(stringsTable('de')['quarter'], 'Quartal', reason: rule1);
      expect(stringsTable('ja')['year'], '年', reason: rule1);
    });
  });
}
