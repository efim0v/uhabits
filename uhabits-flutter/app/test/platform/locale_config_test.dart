/// `audit4.android-13-per-app-language-picker` and
/// `audit4.android-localeconfig-is-dropped-so-the`: the Android 13+ per-app
/// language picker.
///
/// ## Why this is a file test and not a journey
///
/// The picker is not a screen this app draws. It is Settings ▸ Apps ▸ Loop
/// Habit Tracker ▸ Language, rendered by the *system*, and an app appears in it
/// for exactly one reason: `<application android:localeConfig="@xml/…">` names
/// a `<locale-config>` resource. Nothing in the Flutter tree can observe that,
/// and nothing in the Flutter tree can substitute for it — a
/// `MaterialApp.supportedLocales` list decides which translation the app picks
/// once Android has told it what the locale *is*; it cannot make Android offer
/// the choice in the first place (`audit4.android-localeconfig-is-dropped-so-
/// the#1`). So the declaration is read from the file that ships it, which is
/// what `audit4.harness-blind-spots#3` asks for.
///
/// ## The record this corrects
///
/// The port previously treated the missing attribute as a *deliberate*
/// substitution: `app/test/platform/manifest_components_test.dart` asserted
/// `android:localeConfig` was absent "because MaterialApp.supportedLocales
/// replaced it", `app/test/l10n/localization_inventory_test.dart` asserted the
/// manifest contained no such string at all, and the manifest itself carried a
/// comment saying so. That reading of `platform-glue.locale-config#1` was
/// wrong, and `platform-glue.locale-config#10` is why it mattered: there is
/// deliberately no in-app language row, so the system picker is the *only* way
/// a user can run this app in a language other than the phone's. Dropping the
/// attribute did not move that capability somewhere else; it deleted it. All
/// three records are corrected alongside this file.
///
/// ## What the resource has to contain
///
/// Upstream's `res/xml/locales_config.xml` lists 44 locales and
/// `platform-glue.locale-config#2` pins the count. The port's list is not a
/// copy of it: the catalogue here is the ARB set, `#3` records the four
/// locales upstream forgot (gu, is, ka, ml) as a bug to fix rather than
/// reproduce, and `#4`/`#5` record two more spellings that do not survive the
/// move to Dart. So what is asserted is the invariant behind the number — the
/// picker offers exactly the translations that ship — with the Android
/// resource-qualifier spellings `#5` says must be preserved.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Reading the Android source set
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
  throw StateError('Could not find $suffix (looking for $marker).');
}

String androidSource(String path) =>
    File('${androidMain.path}/$path').readAsStringSync();

/// The `<application …>` opening tag, attributes only.
///
/// Comments are stripped first: this manifest documents itself at length, and
/// the prose mentions `<application>` before the element does.
Map<String, String> applicationAttributes() {
  final String manifest = androidSource('AndroidManifest.xml')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final int start = manifest.indexOf('<application');
  expect(start, isNot(-1), reason: 'the manifest has an <application> element');
  final int end = manifest.indexOf('>', start);
  final String open = manifest.substring(start, end);
  return <String, String>{
    for (final RegExpMatch m
        in RegExp(r'([\w:]+)\s*=\s*"([^"]*)"').allMatches(open))
      m.group(1)!: m.group(2)!,
  };
}

/// The ARB tags that ship, e.g. `en`, `pt_BR`, `sr_Latn`.
List<String> arbTags() => arbDir
    .listSync()
    .whereType<File>()
    .map((File f) => f.uri.pathSegments.last)
    .where((String n) => n.startsWith('app_') && n.endsWith('.arb'))
    .map((String n) => n.substring(4, n.length - 4))
    .toList()
  ..sort();

/// The BCP-47 tag a supported [Locale] is written as in `locales_config.xml`.
///
/// `platform-glue.locale-config#5`: Android still resolves Indonesian and
/// Hebrew resources under the deprecated `in` and `iw` subtags, and the port's
/// `res/values-in/` and `res/values-iw/` directories use them — so the locale
/// the picker offers has to be spelled the same way, or the launcher label and
/// the widget names fall back to English for the one locale the user chose.
String androidLocaleTag(Locale locale) {
  const Map<String, String> deprecated = <String, String>{
    'id': 'in',
    'he': 'iw',
  };
  final String language =
      deprecated[locale.languageCode] ?? locale.languageCode;
  return <String?>[language, locale.scriptCode, locale.countryCode]
      .whereType<String>()
      .join('-');
}

void main() {
  // -----------------------------------------------------------------------
  // The manifest attribute
  // -----------------------------------------------------------------------

  group('audit4.android-localeconfig-is-dropped-so-the', () {
    const String rule =
        'audit4.android-localeconfig-is-dropped-so-the#1 — Because the '
        'application element names a localeConfig, Android 13+ lists Loop '
        'Habit Tracker under Settings > System > Languages > App languages and '
        'lets the user pick any declared locale for this app alone — a Spanish '
        'UI on an English phone, say. locales_config.xml is the entire '
        'mechanism: the ledger\'s own platform-glue.locale-config#10 records '
        'that preferences.xml deliberately has no in-app language row '
        'precisely because language selection is delegated to that system '
        'picker. The launcher label and the widget names follow the chosen '
        'locale too, since both are string resources.';

    test('#1 <application> names a localeConfig', () {
      expect(applicationAttributes()['android:localeConfig'],
          '@xml/locales_config',
          reason: '$rule Without the attribute the resource is inert and the '
              'app never appears in the picker.');
    });

    test('#1 the resource it names is a <locale-config>', () {
      final File resource =
          File('${androidMain.path}/res/xml/locales_config.xml');
      expect(resource.existsSync(), isTrue,
          reason: '$rule The attribute points at res/xml/locales_config.xml; '
              'an attribute naming a missing resource does not even build.');
      expect(resource.readAsStringSync(), contains('<locale-config'),
          reason: '$rule The root element is what Android parses.');
    });

    test('#1 the launcher label and the widget names follow the picked locale',
        () {
      // The last sentence of the rule. Both are string resources, so a locale
      // the picker offers must have a resource directory behind it — otherwise
      // choosing it leaves the home screen and the widget gallery in English.
      // `gu` is the one exception and it is a deliberate one: its ARB
      // translates almost nothing, so no values-gu is generated and Android
      // falls back to values/ for the handful of names while the Flutter UI
      // still shows the Gujarati strings that do exist.
      for (final String tag in localeTags()) {
        if (tag == 'en' || tag == 'gu') continue;
        final String qualifier = tag.contains('-')
            ? (tag.split('-')[1].length == 4
                ? 'values-b+${tag.split('-')[0]}+${tag.split('-')[1]}'
                : 'values-${tag.split('-')[0]}-r${tag.split('-')[1]}')
            : 'values-$tag';
        expect(
          File('${androidMain.path}/res/$qualifier/strings.xml').existsSync(),
          isTrue,
          reason: '$rule Missing res/$qualifier/strings.xml for the "$tag" '
              'entry of locales_config.xml.',
        );
      }
    });
  });

  // -----------------------------------------------------------------------
  // The list itself
  // -----------------------------------------------------------------------

  group('audit4.android-13-per-app-language-picker', () {
    const String rule =
        'audit4.android-13-per-app-language-picker#1 — Because the manifest '
        'points at locales_config.xml, Android 13+ shows Settings ▸ Apps ▸ '
        'Loop Habit Tracker ▸ Language, letting the user run the app in any of '
        'the 44 listed languages independently of the system language. Rule '
        '#10 records that this is the *only* way to change the app\'s '
        'language: there is deliberately no in-app language row.';

    test('#1 it starts at "en"', () {
      expect(localeTags().first, 'en',
          reason: '$rule platform-glue.locale-config#2: the list starts with '
              '"en", the default resource set, exactly as upstream\'s does.');
    });

    test('#1 the picker offers exactly the translations that ship', () {
      final List<String> offered = localeTags();
      final List<String> shipped = L10n.supportedLocales
          .map(androidLocaleTag)
          .toList()
        ..sort();

      expect(offered.toSet(), shipped.toSet(),
          reason: '$rule A locale in the picker with no translation behind it '
              'is a language the user can select and never see; a translation '
              'with no entry is one they cannot reach at all, which is exactly '
              'the bug platform-glue.locale-config#3 records upstream.');
      expect(offered, hasLength(arbTags().length),
          reason: '$rule One entry per shipped ARB, with nothing left over.');
      expect(offered.length, greaterThan(44),
          reason: '$rule Upstream lists 44; the port lists more because '
              'platform-glue.locale-config#3 says the four locales upstream '
              'forgot (gu, is, ka, ml) are a bug to fix, not to reproduce.');
    });

    test('#1 the deprecated Android subtags are preserved', () {
      // platform-glue.locale-config#5. The Dart list canonicalises to `id` and
      // `he`; the Android resource qualifiers cannot, and the picker entry has
      // to agree with the qualifier or the localized launcher label and widget
      // names are lost for those two locales.
      expect(localeTags(), containsAll(<String>['in', 'iw']), reason: rule);
      expect(localeTags(), isNot(contains('id')), reason: rule);
      expect(localeTags(), isNot(contains('he')), reason: rule);
    });

    test('#1 the entries are ordered and unique', () {
      final List<String> offered = localeTags();
      expect(offered.toSet(), hasLength(offered.length),
          reason: '$rule A repeated <locale> is a duplicate row in the system '
              'picker.');
      final List<String> rest = offered.sublist(1);
      expect(rest, orderedEquals(<String>[...rest]..sort()),
          reason: '$rule "en" first and the rest sorted, the way the XML was.');
    });
  });
}

/// The `android:name` of every `<locale>` in `res/xml/locales_config.xml`, in
/// file order.
List<String> localeTags() {
  final File resource = File('${androidMain.path}/res/xml/locales_config.xml');
  if (!resource.existsSync()) return const <String>[];
  return RegExp(r'<locale\s+android:name="([^"]+)"')
      .allMatches(resource.readAsStringSync())
      .map((RegExpMatch m) => m.group(1)!)
      .toList();
}
