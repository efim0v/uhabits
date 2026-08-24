/// `settings.theme.system-night-window-background`, asserted against the
/// Android resource set that carries it.
///
/// This feature is not about the in-app theme preference (that is
/// `settings.theme.theme-modes`, asserted in test/ui/theme/app_theme_test.dart)
/// and not about the chart palettes. It is about the window Android paints
/// *before any app code runs*: the resource-qualifier path. In a Flutter app
/// that window is the `LaunchTheme` / `NormalTheme` pair in
/// `android/app/src/main/res/values*/styles.xml`, and `values-night` is
/// selected by the same `-night` qualifier upstream used — the OS dark-mode
/// setting, which is independent of `pref_theme`.
///
/// None of it can execute here: there is no Android runtime in `flutter test`
/// and no resource resolver. What can be checked is the declaration, which is
/// what the rules are actually about, and the same approach
/// test/platform/android_widgets_test.dart takes for the widget providers:
/// parse the file, extract the value, compare it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Reading the source set
// ---------------------------------------------------------------------------

final Directory androidMain = _findAndroidMain();

Directory _findAndroidMain() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String suffix in <String>[
      'android/app/src/main',
      'app/android/app/src/main',
    ]) {
      final Directory candidate = Directory('${dir.path}/$suffix');
      if (File('${candidate.path}/AndroidManifest.xml').existsSync()) {
        return candidate;
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('android/app/src/main not found from ${Directory.current.path}');
}

String androidSource(String relative) =>
    File('${androidMain.path}/$relative').readAsStringSync();

/// The Flutter app directory, i.e. `android/app/src/main`'s four-times parent.
final Directory appDir =
    androidMain.parent.parent.parent.parent;

String iosSource(String relative) =>
    File('${appDir.path}/ios/$relative').readAsStringSync();

/// The `<color key="backgroundColor" .../>` element of a storyboard's root
/// `<view key="view" ...>`, as an attribute map.
Map<String, String> rootViewBackground(String storyboard) {
  final RegExpMatch? view =
      RegExp(r'<view key="view"[^>]*>(.*?)</view>', dotAll: true)
          .firstMatch(storyboard);
  if (view == null) throw StateError('no root <view key="view"> found');
  final RegExpMatch? color =
      RegExp(r'<color key="backgroundColor"([^>]*)/>').firstMatch(view.group(1)!);
  if (color == null) throw StateError('no backgroundColor on the root view');
  return <String, String>{
    for (final RegExpMatch m
        in RegExp(r'(\w[\w-]*)="([^"]*)"').allMatches(color.group(1)!))
      m.group(1)!: m.group(2)!,
  };
}

/// The `<item name="...">value</item>` pairs of one `<style>` block.
Map<String, String> styleItems(String xml, String styleName) {
  final RegExpMatch? block = RegExp(
    '<style\\s+name="$styleName"[^>]*>(.*?)</style>',
    dotAll: true,
  ).firstMatch(xml);
  if (block == null) throw StateError('style $styleName not found');
  return <String, String>{
    for (final RegExpMatch m in RegExp(
      r'<item\s+name="([^"]+)"[^>]*>([^<]*)</item>',
    ).allMatches(block.group(1)!))
      m.group(1)!: m.group(2)!.trim(),
  };
}

/// The `parent="..."` of one `<style>` block.
String styleParent(String xml, String styleName) => RegExp(
      '<style\\s+name="$styleName"\\s+parent="([^"]+)"',
    ).firstMatch(xml)!.group(1)!;

/// The `<color name="...">value</color>` pairs of a colours file.
Map<String, String> colors(String xml) => <String, String>{
      for (final RegExpMatch m
          in RegExp(r'<color\s+name="([^"]+)"\s*>([^<]*)</color>').allMatches(xml))
        m.group(1)!: m.group(2)!.trim(),
    };

/// Every `res/` directory carrying a configuration qualifier.
List<String> qualifiedResourceDirs() => Directory('${androidMain.path}/res')
    .listSync()
    .whereType<Directory>()
    .map((Directory d) => d.uri.pathSegments[d.uri.pathSegments.length - 2])
    .where((String name) => name.contains('-'))
    .toList()
  ..sort();

void main() {
  late String lightStyles;
  late String nightStyles;
  late String manifest;

  setUpAll(() {
    lightStyles = androidSource('res/values/styles.xml');
    nightStyles = androidSource('res/values-night/styles.xml');
    manifest = androidSource('AndroidManifest.xml');
  });

  group('settings.theme.system-night-window-background', () {
    test('#1 the window background is one colour token, grey_200 by day and '
        'grey_900 by night', () {
      const String rule =
          'settings.theme.system-night-window-background#1 — The '
          'manifest-level theme is @style/AppBaseTheme (the light theme). It '
          'sets android:colorBackground=@color/color_background, and '
          'color_background is @color/grey_200 in values/colors.xml but '
          '@color/grey_900 in values-night/colors.xml — the only -night '
          'qualified resource file in the whole app. A Flutter app names its '
          'pre-Dart window theme LaunchTheme/NormalTheme instead of '
          'AppBaseTheme, but the mechanism and the two colours are the same.';

      expect(styleItems(lightStyles, 'LaunchTheme')['android:colorBackground'],
          '@color/color_background', reason: rule);
      expect(styleItems(lightStyles, 'NormalTheme')['android:colorBackground'],
          '@color/color_background', reason: rule);

      final Map<String, String> light = colors(androidSource('res/values/colors.xml'));
      final Map<String, String> night =
          colors(androidSource('res/values-night/colors.xml'));

      expect(light['color_background'], '@color/grey_200', reason: rule);
      expect(light['grey_200'], '#EEEEEE',
          reason: '$rule grey_200 of material_colors.xml.');
      expect(night['color_background'], '@color/grey_900', reason: rule);
      expect(light['grey_900'], '#212121', reason: rule);
      expect(night.keys, <String>['color_background'],
          reason: '$rule values-night overrides that one colour and nothing '
              'else, exactly as upstream\'s values-night/colors.xml does.');

      // The activity really is themed by these styles: LaunchTheme on the
      // activity, NormalTheme through the embedding's meta-data.
      expect(manifest, contains('android:theme="@style/LaunchTheme"'),
          reason: '$rule The theme is declared on the launcher activity.');
      expect(manifest, contains('android:resource="@style/NormalTheme"'),
          reason: '$rule …and NormalTheme takes over once the process is up.');
    });

    test('#2 the -night qualifier is the only selector, and it is the system '
        'setting', () {
      const String rule =
          'settings.theme.system-night-window-background#2 — The -night '
          'qualifier follows the SYSTEM dark-mode setting, which is '
          'independent of the app\'s own theme preference (automatic/light/'
          'dark). So the window background painted at launch, before an '
          'activity runs AndroidThemeSwitcher, is dark whenever the system is '
          'dark.';

      expect(qualifiedResourceDirs(), contains('values-night'), reason: rule);
      expect(
        qualifiedResourceDirs().where((String d) => d.contains('night')),
        <String>['values-night'],
        reason: '$rule Only one night-qualified directory exists, so nothing '
            'else in the resource set can disagree with it.',
      );

      // The in-app preference is a key in the settings file, invisible to the
      // resource resolver: no Android resource can branch on it.
      for (final FileSystemEntity entity
          in Directory('${androidMain.path}/res').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.xml')) continue;
        expect(entity.readAsStringSync(), isNot(contains('pref_theme')),
            reason: '$rule Nothing in res/ mentions pref_theme — the two '
                'settings cannot be the same one (${entity.path}).');
      }
    });

    test('#3 no splash screen API and no separate splash theme', () {
      const String rule =
          'settings.theme.system-night-window-background#3 — Consequence to '
          'preserve: with the in-app theme forced to Light while the system is '
          'in dark mode, launch briefly shows a grey_900 window and then flips '
          'to the light theme once the activity applies it (and symmetrically '
          'for the opposite combination). There is no androidx SplashScreen '
          'API in use and no dedicated splash theme.';

      // The launch window and the running window paint the same token, so the
      // brief pre-Dart frame is grey_900 exactly when the system is dark —
      // whatever pref_theme says.
      expect(
        androidSource('res/drawable-v21/launch_background.xml'),
        contains('?android:colorBackground'),
        reason: '$rule The launch drawable is the theme background itself.',
      );
      expect(
        androidSource('res/drawable/launch_background.xml'),
        contains('@color/color_background'),
        reason: '$rule …and the pre-21 variant names the same qualified '
            'colour rather than a hard-coded white.',
      );

      // No androidx.core.splashscreen, and none of its attributes.
      final String gradle = File('${androidMain.parent.parent.path}/build.gradle.kts')
          .readAsStringSync();
      expect(gradle, isNot(contains('splashscreen')), reason: rule);
      for (final String xml in <String>[lightStyles, nightStyles]) {
        expect(xml, isNot(contains('postSplashScreenTheme')), reason: rule);
        expect(xml, isNot(contains('windowSplashScreenBackground')),
            reason: rule);
      }

      // "no dedicated splash theme": the two styles that exist are the launch
      // window and the running window, and nothing else.
      expect(
        RegExp(r'<style\s+name="([^"]+)"')
            .allMatches(lightStyles)
            .map((RegExpMatch m) => m.group(1)!)
            .toList(),
        <String>['LaunchTheme', 'NormalTheme'],
        reason: rule,
      );
    });

    test('#4 force-dark is opted out of, on every style', () {
      const String rule =
          'settings.theme.system-night-window-background#4 — AppBaseTheme also '
          'sets android:forceDarkAllowed=false (tools:targetApi=q), so Android '
          'never auto-darkens any screen on API 29+; every dark appearance '
          'must come from the app\'s own theme definitions.';

      for (final MapEntry<String, String> entry in <String, String>{
        'values': lightStyles,
        'values-night': nightStyles,
      }.entries) {
        for (final String style in <String>['LaunchTheme', 'NormalTheme']) {
          expect(styleItems(entry.value, style)['android:forceDarkAllowed'],
              'false',
              reason: '$rule (${entry.key}/$style)');
        }
        expect(entry.value, contains('tools:targetApi="q"'),
            reason: '$rule The attribute is guarded for API 29, exactly as '
                'upstream declares it (${entry.key}).');
        expect(entry.value, contains('xmlns:tools='),
            reason: '$rule …which needs the tools namespace declared '
                '(${entry.key}).');
      }
    });

    test('#5 the dark styles are full themes, not overlays on the light ones',
        () {
      const String rule =
          'settings.theme.system-night-window-background#5 — commit 7e993e17 '
          're-parented AppBaseThemeDark from '
          'ThemeOverlay.MaterialComponents.Dark.ActionBar to '
          'Theme.MaterialComponents.NoActionBar, so the dark theme is now a '
          'full theme rather than an overlay — dark styling no longer inherits '
          'any light-theme attributes it does not override.';

      for (final String style in <String>['LaunchTheme', 'NormalTheme']) {
        final String parent = styleParent(nightStyles, style);
        expect(parent, isNot(contains('ThemeOverlay')),
            reason: '$rule ($style) An overlay parent is exactly what the '
                'commit removed.');
        expect(parent, '@android:style/Theme.Black.NoTitleBar',
            reason: '$rule ($style) The night parent is a full dark platform '
                'theme; the day parent is Theme.Light.NoTitleBar.');
        expect(styleParent(lightStyles, style),
            '@android:style/Theme.Light.NoTitleBar', reason: rule);

        // "no longer inherits any light-theme attributes it does not
        // override": every attribute the light style sets is set again in the
        // night one, so nothing is left to fall through.
        expect(
          styleItems(nightStyles, style).keys.toSet(),
          containsAll(styleItems(lightStyles, style).keys),
          reason: '$rule ($style) The night style restates every attribute '
              'rather than relying on the light one.',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // The iOS half of the same feature.
  // -------------------------------------------------------------------------
  //
  // The rules above are about the window painted before any app code runs, and
  // Android is only one of the two hosts that paints one. On iOS that window is
  // `UILaunchStoryboardName`, and the thing that plays `-night`'s part is an
  // asset-catalog colour with a `luminosity: dark` appearance — both follow the
  // OS appearance and nothing else, which is what makes them the same rule.
  // Flutter's stock LaunchScreen.storyboard hard-codes opaque white, so the
  // whole of `await AppScope.boot()` — database open plus migrations — was
  // spent on a white screen before cutting to a dark UI.
  //
  // Like the Android assertions, none of this can execute: a launch storyboard
  // is rendered by the system before the process is up, and a Dart widget test
  // begins after that window is gone. So the expectations are DERIVED from the
  // Android resource set that already carries the answer, the way
  // test/platform/ios_bundle_test.dart derives its icon and locale
  // expectations, so the two platforms cannot drift apart again.
  group('audit21.ios-launch-window-follows-the-system-appearance', () {
    const String rule =
        'audit21.ios-launch-window-follows-the-system-appearance#1 — In the '
        'Kotlin app: the window painted before any app code runs is themed by '
        'android:colorBackground=@color/color_background, and color_background '
        'is grey_200 (#EEEEEE) in values/ and grey_900 (#212121) in '
        'values-night/ — the shipped fix for "Fix splash screen background '
        'color in dark mode" (2.2.0, issue #1888). The -night qualifier '
        'follows the OS dark-mode setting, so a dark-mode user never sees a '
        'light flash at launch. A port has to carry that to every host that '
        'paints a launch window, iOS included.';

    late String launchScreen;
    late Map<String, String> lightColors;
    late Map<String, String> nightColors;

    setUpAll(() {
      launchScreen = iosSource('Runner/Base.lproj/LaunchScreen.storyboard');
      lightColors = colors(androidSource('res/values/colors.xml'));
      nightColors = colors(androidSource('res/values-night/colors.xml'));
    });

    test('#1 the launch window names an appearance-aware colour, not white',
        () {
      final Map<String, String> background = rootViewBackground(launchScreen);

      expect(background['name'], 'LaunchBackground',
          reason: '$rule A named asset-catalog colour is the only thing in a '
              'launch storyboard that can vary with the system appearance; a '
              'literal one cannot, whatever its value.');
      for (final String component in <String>[
        'red',
        'green',
        'blue',
        'white',
      ]) {
        expect(background.containsKey(component), isFalse,
            reason: '$rule …so no literal component may remain '
                '($component=${background[component]}). Flutter\'s stock '
                'storyboard is red=1 green=1 blue=1 alpha=1: opaque white in '
                'every appearance.');
      }
    });

    test('#1 the colour set carries the two Android values, light and dark',
        () {
      final File contents = File('${appDir.path}/ios/Runner/Assets.xcassets/'
          'LaunchBackground.colorset/Contents.json');
      expect(contents.existsSync(), isTrue,
          reason: '$rule The storyboard names it; the catalogue has to define '
              'it.');

      final Map<String, dynamic> json =
          jsonDecode(contents.readAsStringSync()) as Map<String, dynamic>;
      final List<dynamic> entries = json['colors'] as List<dynamic>;

      String? hexOf(Map<String, dynamic>? entry) {
        if (entry == null) return null;
        final Map<String, dynamic> components =
            (entry['color'] as Map<String, dynamic>)['components']
                as Map<String, dynamic>;
        String byte(String key) {
          final String raw = components[key] as String;
          final int value = raw.startsWith('0x')
              ? int.parse(raw.substring(2), radix: 16)
              : (double.parse(raw) * 255).round();
          return value.toRadixString(16).padLeft(2, '0').toUpperCase();
        }

        return '#${byte('red')}${byte('green')}${byte('blue')}';
      }

      Map<String, dynamic>? entryFor(String? appearance) {
        for (final dynamic raw in entries) {
          final Map<String, dynamic> entry = raw as Map<String, dynamic>;
          final List<dynamic> appearances =
              (entry['appearances'] as List<dynamic>?) ?? <dynamic>[];
          final bool isDark = appearances.any((dynamic a) =>
              (a as Map<String, dynamic>)['appearance'] == 'luminosity' &&
              a['value'] == 'dark');
          if (appearance == 'dark' ? isDark : !isDark) return entry;
        }
        return null;
      }

      // The expectations are the Android resource set's, resolved through
      // material_colors.xml, so the two hosts cannot drift.
      final String day = lightColors[
          lightColors['color_background']!.replaceFirst('@color/', '')]!;
      final String night = lightColors[
          nightColors['color_background']!.replaceFirst('@color/', '')]!;

      expect(hexOf(entryFor(null)), day,
          reason: '$rule The Any appearance is grey_200, what '
              'values/colors.xml resolves color_background to.');
      expect(hexOf(entryFor('dark')), night,
          reason: '$rule …and the dark one is grey_900, what '
              'values-night/colors.xml resolves it to. Without a '
              'luminosity/dark entry the set is a repainted white: still one '
              'colour in both appearances.');
    });

    test('#1 nothing overrides the system appearance for the bundle', () {
      // An appearance-aware colour follows the OS setting and nothing else —
      // which is exactly what the -night qualifier does, and why the in-app
      // theme preference is not part of this rule (with Dark chosen while the
      // system is light, Android also paints grey_200 and then flips:
      // settings.theme.system-night-window-background#3). A
      // UIUserInterfaceStyle in Info.plist would freeze the whole bundle to
      // one appearance and take the launch window with it.
      expect(iosSource('Runner/Info.plist'),
          isNot(contains('UIUserInterfaceStyle')), reason: rule);
      expect(iosSource('Runner/Info.plist'),
          contains('<key>UILaunchStoryboardName</key>'),
          reason: '$rule …and the storyboard asserted above really is the '
              'launch window.');
    });

    test('#1 the window under the Flutter view is the same colour', () {
      // Main.storyboard is the FlutterViewController's own view: the surface
      // the first frame is drawn onto. Stock Flutter leaves it white too.
      final Map<String, String> background =
          rootViewBackground(iosSource('Runner/Base.lproj/Main.storyboard'));
      expect(background['name'], 'LaunchBackground',
          reason: '$rule The two windows are one continuous surface to the '
              'user; a white one under a dark launch screen would flash at '
              'the hand-off instead of before it.');
    });
  });
}
