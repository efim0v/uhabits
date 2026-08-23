/// `audit4.harness-blind-spots#3`: the native declarations that carry
/// behaviour, read from the files that ship them.
///
/// ## Why this file exists
///
/// A journey drives the Flutter tree. It can prove a screen is reachable and it
/// can prove what the app published; it can say nothing at all about a string
/// in `Runner.entitlements`, an attribute on `<application>`, or a `<key>` in
/// `Info.plist`. Nine of the twenty defects the fourth audit found live exactly
/// there, both blockers included: the iOS App Group was never named, so every
/// iOS widget was permanently empty, and nothing in the repository would have
/// noticed.
///
/// What makes those declarations dangerous is not that they are hard — each is
/// one line — but that they are *silent*. Deleting `android:label` from a
/// receiver still compiles. Removing an App Group from an entitlements file
/// still builds. Dropping a URL scheme from `Info.plist` still runs. The
/// failure appears on a device, in another process, to a user.
///
/// So this file is the inventory. Every declaration below is one the port
/// depends on, and every assertion reads the shipped file and compares a value
/// against the Dart or Kotlin constant that has to agree with it. Nothing here
/// asserts that a file merely mentions something — that would pass for a
/// comment and prove nothing.
///
/// ## What is covered where
///
/// The four declarations `audit4.harness-blind-spots#3` names each have a
/// feature test of their own — app/test/platform/ios_app_group_test.dart,
/// ios_widget_links_test.dart, widget_launcher_names_test.dart — which is where
/// the *behaviour* behind them is argued. This file is deliberately the other
/// thing: one place that holds the whole set, so that a declaration cannot go
/// missing without a test naming it going red, and so that adding a new one has
/// an obvious home.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';
import 'package:uhabits/state/widget_link.dart';

// ---------------------------------------------------------------------------
// Reading the source sets
// ---------------------------------------------------------------------------

final Directory androidMain =
    _find('android/app/src/main', 'AndroidManifest.xml');
final Directory iosDir = _find('ios', 'Runner/Info.plist');

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

String androidSource(String relative) =>
    File('${androidMain.path}/$relative').readAsStringSync();

String iosSource(String relative) =>
    File('${iosDir.path}/$relative').readAsStringSync();

/// The first capturing group of [pattern] in [source], or a failure naming the
/// file — a declaration that vanished must not surface as a null dereference.
String capture(String source, RegExp pattern, {required String what}) {
  final RegExpMatch? match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: '$what: no match for ${pattern.pattern}');
  return match!.group(1)!;
}

/// The `<string>` values of the `<array>` that follows `<key>[key]</key>` in a
/// property list.
///
/// The plists in this source set are hand-written and shallow, so a scan is
/// enough; pulling in a plist parser would buy nothing.
List<String> plistStringArray(String plist, String key) {
  final int keyAt = plist.indexOf('<key>$key</key>');
  if (keyAt < 0) return const <String>[];
  final int open = plist.indexOf('<array>', keyAt);
  final int close = plist.indexOf('</array>', open);
  if (open < 0 || close < 0) return const <String>[];
  return RegExp(r'<string>([^<]*)</string>')
      .allMatches(plist.substring(open, close))
      .map((RegExpMatch m) => m.group(1)!)
      .toList();
}

/// Every `<receiver …>` block of the manifest, attributes only.
List<Map<String, String>> manifestReceivers(String manifest) {
  final List<Map<String, String>> receivers = <Map<String, String>>[];
  for (final RegExpMatch match
      in RegExp(r'<receiver\b([\s\S]*?)(?:/>|>)').allMatches(manifest)) {
    final String block = match.group(1)!;
    final Map<String, String> attributes = <String, String>{};
    for (final RegExpMatch attribute
        in RegExp(r'([\w:]+)="([^"]*)"').allMatches(block)) {
      attributes[attribute.group(1)!] = attribute.group(2)!;
    }
    receivers.add(attributes);
  }
  return receivers;
}

void main() {
  group('audit4.harness-blind-spots#3', () {
    // -------------------------------------------------------------------
    // The App Group
    // -------------------------------------------------------------------

    test('the App Group id is declared in four files and they all agree', () {
      // `HomeWidget.setAppGroupId` is answered by the iOS plugin with error -7
      // ("AppGroupId not set") unless this string was handed to it, and the
      // extension reads `UserDefaults(suiteName:)` on the same string. Four
      // declarations, no compiler between them.
      final String dart = HomeWidgetPlugin.iosAppGroupId;
      final String swift = capture(
        iosSource('HabitsWidget/WidgetData.swift'),
        RegExp(r'static let appGroupId = "([^"]*)"'),
        what: 'ios/HabitsWidget/WidgetData.swift',
      );
      final List<String> runner = plistStringArray(
        iosSource('Runner/Runner.entitlements'),
        'com.apple.security.application-groups',
      );
      final List<String> extension = plistStringArray(
        iosSource('HabitsWidget/HabitsWidget.entitlements'),
        'com.apple.security.application-groups',
      );

      expect(dart, 'group.org.isoron.uhabits',
          reason: 'audit4.harness-blind-spots#3 — the App Group id shared by '
              'the app and the extension is a declaration that carries '
              'behaviour: without it every saveWidgetData lands in the app\'s '
              'own defaults and all six iOS widgets stay blank.');
      expect(swift, dart,
          reason: 'audit4.harness-blind-spots#3: the extension reads the suite '
              'the app writes');
      expect(runner, contains(dart),
          reason: 'audit4.harness-blind-spots#3: and the app is entitled to it');
      expect(extension, contains(dart),
          reason: 'audit4.harness-blind-spots#3: and so is the extension');
    });

    // -------------------------------------------------------------------
    // The URL scheme
    // -------------------------------------------------------------------

    test('the widget URL scheme is registered on iOS and spelled the same in '
        'all three sources', () {
      final List<String> schemes = plistStringArray(
        iosSource('Runner/Info.plist'),
        'CFBundleURLSchemes',
      );
      final String kotlin = capture(
        androidSource('kotlin/org/isoron/uhabits/widgets/WidgetIntents.kt'),
        RegExp(r'const val SCHEME = "([^"]*)"'),
        what: 'android/.../widgets/WidgetIntents.kt',
      );
      final String authority = capture(
        androidSource('kotlin/org/isoron/uhabits/widgets/WidgetIntents.kt'),
        RegExp(r'const val AUTHORITY = "([^"]*)"'),
        what: 'android/.../widgets/WidgetIntents.kt',
      );

      expect(schemes, contains(WidgetLink.scheme),
          reason: 'audit4.harness-blind-spots#3 — the scheme the widgets tap '
              'into. iOS delivers a widget URL to the app only if '
              'CFBundleURLTypes registers it, so an unregistered scheme makes '
              'every tap on every iOS widget do nothing at all — and nothing '
              'in Dart fails.');
      expect(kotlin, WidgetLink.scheme,
          reason: 'audit4.harness-blind-spots#3: the Android widgets build '
              'their links with the same scheme WidgetLink.parse accepts');
      expect(authority, WidgetLink.authority,
          reason: 'audit4.harness-blind-spots#3: and the same authority, which '
              'is what tells a widget link from any other link');
    });

    // -------------------------------------------------------------------
    // The widget labels
    // -------------------------------------------------------------------

    test('every widget receiver labels itself with a string resource that '
        'exists', () {
      final List<Map<String, String>> receivers =
          manifestReceivers(androidSource('AndroidManifest.xml'));
      final List<Map<String, String>> widgets = receivers
          .where((Map<String, String> r) =>
              (r['android:name'] ?? '').contains('.widgets.'))
          .toList();
      final String strings = androidSource('res/values/strings.xml');
      // A leading dot is resolved against the module's namespace, which is the
      // package the bridge names in `qualifiedAndroidName`.
      final String namespace = capture(
        File('${androidMain.parent.parent.path}/build.gradle.kts')
            .readAsStringSync(),
        RegExp(r'namespace = "([^"]*)"'),
        what: 'android/app/build.gradle.kts',
      );
      String qualified(String name) =>
          name.startsWith('.') ? '$namespace$name' : name;

      expect(
        widgets
            .map((Map<String, String> r) => qualified(r['android:name']!))
            .toList(),
        <String>[
          for (final String provider in HomeWidgetBridge.providerNames)
            '${HomeWidgetBridge.androidProviderPackage}.$provider',
        ],
        reason: 'audit4.harness-blind-spots#3 — one receiver per widget kind, '
            'named exactly as the bridge refreshes them: a provider the '
            'manifest does not declare is a widget the launcher never offers, '
            'and a name that drifts is an updateWidget call that reaches '
            'nothing.',
      );
      for (final Map<String, String> widget in widgets) {
        final String? label = widget['android:label'];
        expect(label, isNotNull,
            reason: 'audit4.harness-blind-spots#3 — the name a widget has in '
                'the launcher gallery. ${widget['android:name']} declares '
                'none.');
        expect(label, startsWith('@string/'),
            reason: 'audit4.harness-blind-spots#3: a literal here is 43 '
                'translations lost, because the gallery is drawn by the '
                'launcher in the user\'s language');
        final String name = label!.substring('@string/'.length);
        expect(strings, contains('<string name="$name">'),
            reason: 'audit4.harness-blind-spots#3: and the resource it names '
                'has to exist, or the gallery entry is blank');
      }
    });

    // -------------------------------------------------------------------
    // The per-app language declaration
    // -------------------------------------------------------------------

    test('the per-app language declaration and its resource stand or fall '
        'together', () {
      // `android:localeConfig="@xml/locales_config"` is what puts the app in
      // the Android 13+ per-app language picker, and it is two declarations
      // that only work as a pair: the attribute names a resource, and the
      // resource lists the locales. Either one alone is inert — an attribute
      // pointing at nothing fails to build, and a resource nobody points at is
      // dead weight the picker never reads.
      //
      // Whether the pair should be there at all is
      // `audit4.android-localeconfig-is-dropped-so-the`, which owns the
      // manifest and the resource; what is asserted here is the invariant that
      // outlives it, and it is what catches half of the pair silently
      // disappearing.
      final String manifest = androidSource('AndroidManifest.xml');
      final RegExpMatch? attribute =
          RegExp(r'android:localeConfig="@xml/(\w+)"').firstMatch(manifest);
      final Directory xml = Directory('${androidMain.path}/res/xml');
      final List<File> configs = xml
          .listSync()
          .whereType<File>()
          .where((File file) =>
              file.path.endsWith('.xml') &&
              file.readAsStringSync().contains('<locale-config'))
          .toList();

      if (attribute != null) {
        final File named = File('${xml.path}/${attribute.group(1)}.xml');
        expect(named.existsSync(), isTrue,
            reason: 'audit4.harness-blind-spots#3 — <application '
                'android:localeConfig="@xml/${attribute.group(1)}"> names a '
                'resource that has to exist: the whole per-app language '
                'mechanism is that file.');
        expect(
          RegExp(r'<locale\b').allMatches(named.readAsStringSync()).length,
          greaterThan(1),
          reason: 'audit4.harness-blind-spots#3: and it has to list the '
              'locales, because the picker offers exactly what it names',
        );
      } else {
        expect(configs, isEmpty,
            reason: 'audit4.harness-blind-spots#3 — a locale-config resource '
                'exists (${configs.map((File f) => f.path).join(", ")}) but no '
                '<application android:localeConfig> points at it, so Android '
                'never reads it and the app is absent from the per-app '
                'language picker. The two are one declaration in two files.');
      }
    });
  });
}
