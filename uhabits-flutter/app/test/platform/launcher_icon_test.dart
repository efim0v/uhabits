/// `app-identity.launcher-icon`: the icon and the label the launcher shows.
///
/// Every rule of this feature is a statement about files in
/// `android/app/src/main/res` and about the manifest that names them. None of
/// it can execute in `flutter test` — a launcher icon is resolved by the
/// system launcher, in another process — so, exactly as
/// test/platform/android_widgets_test.dart does for the widget providers, each
/// assertion below extracts a value from the source set and compares it.
///
/// The one thing the port adds beyond copying assets is the label. Upstream
/// ships `main_activity_title` in 48 `values*/strings.xml` files; this port
/// keeps its translations in ARB, which the launcher cannot read, so the
/// launcher label is mirrored into Android string resources — one per ARB that
/// carries it — and the test below is what keeps the two in step.
///
/// Not asserted: the iOS side. `Runner/Assets.xcassets/AppIcon.appiconset` has
/// no counterpart in these five rules, which are all Android resource
/// qualifiers, and iOS has neither an adaptive icon nor a monochrome layer.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Reading the source set
// ---------------------------------------------------------------------------

final Directory androidMain = _find('android/app/src/main', 'AndroidManifest.xml');
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

String res(String relative) =>
    File('${androidMain.path}/res/$relative').readAsStringSync();

bool hasRes(String relative) =>
    File('${androidMain.path}/res/$relative').existsSync();

String get manifest => File('${androidMain.path}/AndroidManifest.xml')
    .readAsStringSync();

/// The manifest with every `<!-- ... -->` block removed, so a comment naming an
/// attribute cannot be mistaken for the attribute.
String get manifestBody =>
    manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// The attributes of the opening tag of `<element>`, optionally the one whose
/// `android:name` is [named].
Map<String, String> openTag(String element, {String? named}) {
  for (final RegExpMatch tag
      in RegExp('<$element\\b([^>]*)>', dotAll: true).allMatches(manifestBody)) {
    final Map<String, String> attributes = <String, String>{
      for (final RegExpMatch a
          in RegExp(r'([\w:]+)="([^"]*)"').allMatches(tag.group(1)!))
        a.group(1)!: a.group(2)!,
    };
    if (named == null || attributes['android:name'] == named) return attributes;
  }
  throw StateError('<$element${named == null ? '' : ' name=$named'}> not found');
}

/// The `<string name="...">value</string>` pairs of a strings file, with
/// Android's backslash escapes undone.
Map<String, String> androidStrings(String relative) => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'<string\s+name="([^"]+)"\s*>(.*?)</string>',
        dotAll: true,
      ).allMatches(res(relative)))
        m.group(1)!: _unescape(m.group(2)!),
    };

String _unescape(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAllMapped(RegExp(r'\\(.)'), (Match m) => m.group(1)!);

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

/// The `values*` directory an ARB tag maps to.
///
/// Android resource qualifiers still use the deprecated ISO codes for
/// Indonesian and Hebrew (`platform-glue.locale-config#5`), and BCP-47 form
/// when a script subtag is involved.
String qualifierFor(String tag) {
  if (tag == 'en') return 'values';
  final List<String> parts = tag.split('_');
  final String lang =
      <String, String>{'id': 'in', 'he': 'iw'}[parts.first] ?? parts.first;
  if (parts.length == 1) return 'values-$lang';
  if (parts[1].length == 4) return 'values-b+$lang+${parts[1]}';
  return 'values-$lang-r${parts[1].toUpperCase()}';
}

void main() {
  group('app-identity.launcher-icon', () {
    test('#1 the launcher shows "Habits", not "Loop Habit Tracker"', () {
      const String rule =
          'app-identity.launcher-icon#1 — AndroidManifest <application> '
          'declares android:icon="@mipmap/ic_launcher" and '
          'android:label="@string/main_activity_title"; the home-screen/'
          'launcher entry is therefore labelled "Habits" (localized per '
          'locale), NOT the store/about name "Loop Habit Tracker" '
          '(@string/app_name). ListHabitsActivity and the .MainActivity alias '
          'repeat the same label.';

      final Map<String, String> application = openTag('application');
      expect(application['android:icon'], '@mipmap/ic_launcher', reason: rule);
      expect(application['android:label'], '@string/main_activity_title',
          reason: rule);
      expect(openTag('activity', named: '.MainActivity')['android:label'],
          '@string/main_activity_title',
          reason: '$rule The launcher activity repeats the label, as '
              'ListHabitsActivity and the .MainActivity alias do.');
      expect(manifestBody, isNot(contains('@string/app_name')),
          reason: '$rule Nothing in the manifest is labelled with the store '
              'name.');

      final Map<String, String> defaults = androidStrings('values/strings.xml');
      expect(defaults['main_activity_title'], 'Habits', reason: rule);
      expect(defaults['app_name'], 'Loop Habit Tracker',
          reason: '$rule The two are distinct strings, and only the first one '
              'is the launcher label.');
      expect(defaults['main_activity_title'], isNot(defaults['app_name']),
          reason: rule);

      // The Dart side answers with the same two strings, so the launcher and
      // the app agree.
      final Map<String, Object?> en = arb('en');
      expect(defaults['main_activity_title'], en['mainActivityTitle'],
          reason: '$rule The Android resource and the ARB carry one value.');
      expect(defaults['app_name'], en['appName'], reason: rule);
    });

    test('#1 the label is localized, so it follows the per-app language', () {
      const String rule =
          'app-identity.launcher-icon#1 — the label is "Habits" localized per '
          'locale: both main_activity_title and app_name are translated '
          'strings, so the launcher label changes with the Android 13 per-app '
          'language setting. The port keeps its translations in ARB, which no '
          'launcher can read, so every ARB that translates the title also has '
          'an Android string resource — that mirroring is what this asserts.';

      int localized = 0;
      for (final String tag in arbTags()) {
        final Map<String, Object?> messages = arb(tag);
        final Object? title = messages['mainActivityTitle'];
        if (title == null) continue; // e.g. gu translates almost nothing.
        localized++;
        final String dir = qualifierFor(tag);
        expect(hasRes('$dir/strings.xml'), isTrue,
            reason: '$rule Missing $dir/strings.xml for ARB "$tag".');
        expect(androidStrings('$dir/strings.xml')['main_activity_title'], title,
            reason: '$rule $dir disagrees with app_$tag.arb.');
      }
      expect(localized, greaterThan(40),
          reason: '$rule The whole translated set is mirrored, not a sample.');

      // A spot check in both scripts, so the assertion is not vacuous for
      // locales whose title happens to equal the English one.
      expect(androidStrings('values-de/strings.xml')['main_activity_title'],
          'Gewohnheiten', reason: rule);
      expect(androidStrings('values-ja/strings.xml')['main_activity_title'],
          '習慣', reason: rule);
    });

    test('#2 the adaptive icon: flat #1976D2 background, foreground, '
        'monochrome', () {
      const String rule =
          'app-identity.launcher-icon#2 — On API 26+ @mipmap/ic_launcher '
          'resolves to mipmap-anydpi-v26/ic_launcher.xml, an <adaptive-icon> '
          'with: background = flat colour @color/ic_launcher_background = '
          '#1976D2, foreground = @mipmap/ic_launcher_foreground, monochrome = '
          '@mipmap/ic_launcher_monochrome.';

      final String xml = res('mipmap-anydpi-v26/ic_launcher.xml');
      expect(xml, contains('<adaptive-icon'), reason: rule);
      expect(
        RegExp(r'<background\s+android:drawable="([^"]+)"').firstMatch(xml)!.group(1),
        '@color/ic_launcher_background',
        reason: rule,
      );
      expect(
        RegExp(r'<foreground\s+android:drawable="([^"]+)"').firstMatch(xml)!.group(1),
        '@mipmap/ic_launcher_foreground',
        reason: rule,
      );
      expect(
        RegExp(r'<monochrome\s+android:drawable="([^"]+)"').firstMatch(xml)!.group(1),
        '@mipmap/ic_launcher_monochrome',
        reason: rule,
      );
      expect(
        RegExp(r'<color\s+name="ic_launcher_background"\s*>([^<]+)</color>')
            .firstMatch(res('values/colors.xml'))!
            .group(1),
        '#1976D2',
        reason: '$rule The background really is a flat colour, not a drawable.',
      );
    });

    test('#3 the monochrome layer exists, which is what themed icons need',
        () {
      const String rule =
          'app-identity.launcher-icon#3 — The <monochrome> layer is what makes '
          'the icon participate in Android 13+ themed icons (CHANGELOG 2.1.0, '
          '"Add support for Android 13 themed icons", #1497); a port that '
          'ships only a colour icon silently loses that behaviour. '
          'Adaptive-icon support itself dates to CHANGELOG 1.7.8.';

      expect(res('mipmap-anydpi-v26/ic_launcher.xml'), contains('<monochrome'),
          reason: rule);
      for (final String density in <String>[
        'mdpi',
        'hdpi',
        'xhdpi',
        'xxhdpi',
        'xxxhdpi',
      ]) {
        expect(hasRes('mipmap-$density/ic_launcher_monochrome.png'), isTrue,
            reason: '$rule The layer the XML names has to exist at $density, '
                'or the reference does not resolve.');
      }
    });

    test('#4 five densities for the two layers, four for the legacy bitmap',
        () {
      const String rule =
          'app-identity.launcher-icon#4 — ic_launcher_foreground.png and '
          'ic_launcher_monochrome.png ship at all five densities (mdpi, hdpi, '
          'xhdpi, xxhdpi, xxxhdpi); the legacy square ic_launcher.png ships '
          'only at mdpi, xhdpi, xxhdpi and xxxhdpi (hdpi is absent, so '
          'pre-API-26 hdpi devices get a rescaled bitmap).';

      const List<String> all = <String>[
        'mdpi',
        'hdpi',
        'xhdpi',
        'xxhdpi',
        'xxxhdpi',
      ];
      for (final String density in all) {
        expect(hasRes('mipmap-$density/ic_launcher_foreground.png'), isTrue,
            reason: '$rule foreground at $density');
        expect(hasRes('mipmap-$density/ic_launcher_monochrome.png'), isTrue,
            reason: '$rule monochrome at $density');
      }
      expect(
        <String>[
          for (final String d in all)
            if (hasRes('mipmap-$d/ic_launcher.png')) d,
        ],
        <String>['mdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'],
        reason: '$rule The hdpi gap is upstream\'s and is reproduced rather '
            'than filled in.',
      );
    });

    test('#5 no round icon and no shortcuts', () {
      const String rule =
          'app-identity.launcher-icon#5 — No android:roundIcon and no '
          '<shortcuts> are declared, so launchers get no round variant and the '
          'app exposes no static/dynamic app shortcuts.';

      expect(manifestBody, isNot(contains('android:roundIcon')), reason: rule);
      expect(manifestBody, isNot(contains('android.app.shortcuts')),
          reason: rule);
      expect(hasRes('xml/shortcuts.xml'), isFalse, reason: rule);
      for (final String density in <String>[
        'mdpi',
        'hdpi',
        'xhdpi',
        'xxhdpi',
        'xxxhdpi',
      ]) {
        expect(hasRes('mipmap-$density/ic_launcher_round.png'), isFalse,
            reason: '$rule …and no round bitmap ships either ($density).');
      }
      expect(hasRes('mipmap-anydpi-v26/ic_launcher_round.xml'), isFalse,
          reason: rule);
    });
  });
}
