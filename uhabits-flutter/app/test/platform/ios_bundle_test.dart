/// `verify.ios-localizations-missing` and `verify.ios-icon-and-label`: what the
/// iOS application bundle declares about itself.
///
/// Both features are statements about files that only Xcode and iOS ever read —
/// `ios/Runner/Info.plist`, the `.lproj` resource directories beside it, and
/// `ios/Runner/Assets.xcassets/AppIcon.appiconset`. None of it can execute in
/// `flutter test`: a bundle's localization list is consulted by
/// `NSLocale.preferredLanguages` before Dart starts, and a launcher icon is
/// drawn by SpringBoard in another process. So, exactly as
/// test/platform/launcher_icon_test.dart does for the Android source set, every
/// assertion below extracts a value from the iOS source set and compares it —
/// against the ARB catalogue and against the Android resources that already say
/// what the answer is.
///
/// The two Android-side halves of these rules are already asserted elsewhere:
/// test/l10n/localization_inventory_test.dart for the locale catalogue and
/// test/platform/launcher_icon_test.dart for the adaptive icon and the label.
/// This file is the iOS mirror of both, and it deliberately reads the *Android*
/// resources for the values it expects, so the two platforms cannot drift.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Locating the source sets
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory iosRunner = Directory('${appDir.path}/ios/Runner');
final Directory arbDir = Directory('${appDir.path}/lib/l10n');
final Directory androidRes =
    Directory('${appDir.path}/android/app/src/main/res');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', 'app/']) {
      final Directory candidate = Directory('${dir.path}/$prefix'.replaceAll(
        RegExp(r'/$'),
        '',
      ));
      if (File('${candidate.path}/ios/Runner/Info.plist').existsSync() &&
          File('${candidate.path}/lib/l10n/app_en.arb').existsSync()) {
        return candidate;
      }
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('app/ not found from ${Directory.current.path}');
}

// ---------------------------------------------------------------------------
// The ARB catalogue — the port's replacement for res/values-*/ and for
// locales_config.xml
// ---------------------------------------------------------------------------

/// The ARB locale tag of every `app_*.arb`, sorted.
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

/// The BCP-47 language identifier iOS uses for an ARB tag: `pt_BR` is `pt-BR`,
/// `sr_Latn` is `sr-Latn`. Apple's identifiers are hyphenated, Dart's `Locale`
/// and the ARB file names are not.
String iosTag(String arbTag) => arbTag.replaceAll('_', '-');

/// The same identifier, derived from the delegate's list rather than from the
/// file names, so the two sources can be cross-checked.
String iosTagOfLocale(Locale locale) => <String?>[
      locale.languageCode,
      locale.scriptCode,
      locale.countryCode,
    ].whereType<String>().join('-');

// ---------------------------------------------------------------------------
// Reading the iOS source set
// ---------------------------------------------------------------------------

Map<String, Object?> get infoPlist =>
    parsePlist(File('${iosRunner.path}/Info.plist').readAsStringSync())
        as Map<String, Object?>;

String get pbxproj =>
    File('${appDir.path}/ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();

/// The `knownRegions = ( … );` list of the Xcode project.
List<String> knownRegions() {
  final Match m =
      RegExp(r'knownRegions = \(([^)]*)\);', dotAll: true).firstMatch(pbxproj)!;
  return m
      .group(1)!
      .split(',')
      .map((String s) => s.trim().replaceAll('"', ''))
      .where((String s) => s.isNotEmpty)
      .toList();
}

/// The `"key" = "value";` pairs of a `.strings` file.
Map<String, String> stringsFile(File file) => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
        multiLine: true,
      ).allMatches(file.readAsStringSync()))
        m.group(1)!: m
            .group(2)!
            .replaceAllMapped(RegExp(r'\\(.)'), (Match e) => e.group(1)!),
    };

/// The `<string name="...">value</string>` pairs of an Android strings file.
Map<String, String> androidStrings(String relative) => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'<string\s+name="([^"]+)"\s*>(.*?)</string>',
        dotAll: true,
      ).allMatches(File('${androidRes.path}/$relative').readAsStringSync()))
        m.group(1)!: m
            .group(2)!
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .replaceAllMapped(RegExp(r'\\(.)'), (Match e) => e.group(1)!),
    };

/// `@color/ic_launcher_background` — the flat blue the Android adaptive icon
/// is built on, and therefore the field colour the iOS icon has to be.
int androidLauncherBackground() {
  final String hex = RegExp(
    r'<color\s+name="ic_launcher_background"\s*>#([0-9A-Fa-f]{6})</color>',
  ).firstMatch(File('${androidRes.path}/values/colors.xml').readAsStringSync())!
      .group(1)!;
  return 0xFF000000 | int.parse(hex, radix: 16);
}

// ---------------------------------------------------------------------------
// A very small XML property-list reader
// ---------------------------------------------------------------------------

class _Tok {
  _Tok(this.name, this.close, this.selfClose, this.text);
  final String name;
  final bool close;
  final bool selfClose;

  /// The character data that preceded this tag, i.e. the content of the
  /// element this tag closes.
  final String text;
}

List<_Tok> _tokenize(String xml) {
  final List<_Tok> out = <_Tok>[];
  int last = 0;
  for (final Match m in RegExp(r'<[^>]+>').allMatches(xml)) {
    final String text = xml.substring(last, m.start);
    last = m.end;
    final String raw = m.group(0)!;
    if (raw.startsWith('<?') || raw.startsWith('<!')) continue;
    out.add(_Tok(
      RegExp(r'[A-Za-z]+').firstMatch(raw)!.group(0)!,
      raw.startsWith('</'),
      raw.endsWith('/>'),
      _unescapeXml(text.trim()),
    ));
  }
  return out;
}

String _unescapeXml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

Object? parsePlist(String xml) {
  final List<_Tok> toks = _tokenize(xml);
  int i = 0;
  while (i < toks.length && !(toks[i].name == 'plist' && !toks[i].close)) {
    i++;
  }
  if (i == toks.length) throw StateError('no <plist> element');
  final _PlistReader reader = _PlistReader(toks)..i = i + 1;
  return reader.value();
}

class _PlistReader {
  _PlistReader(this.toks);
  final List<_Tok> toks;
  int i = 0;

  Object? value() {
    final _Tok tok = toks[i];
    if (tok.selfClose) {
      i++;
      switch (tok.name) {
        case 'true':
          return true;
        case 'false':
          return false;
        default:
          return null;
      }
    }
    switch (tok.name) {
      case 'dict':
        i++;
        final Map<String, Object?> map = <String, Object?>{};
        while (!(toks[i].close && toks[i].name == 'dict')) {
          i++; // past <key>
          final String key = toks[i].text; // </key> carries the text
          i++; // past </key>
          map[key] = value();
        }
        i++; // past </dict>
        return map;
      case 'array':
        i++;
        final List<Object?> list = <Object?>[];
        while (!(toks[i].close && toks[i].name == 'array')) {
          list.add(value());
        }
        i++;
        return list;
      default:
        i++; // past the opening tag
        final String text = toks[i].text; // the closing tag carries the text
        i++;
        if (tok.name == 'integer') return int.parse(text);
        if (tok.name == 'real') return double.parse(text);
        return text;
    }
  }
}

// ---------------------------------------------------------------------------
// A very small PNG reader — enough for 8-bit RGB/RGBA, non-interlaced, which is
// what an app-icon asset is
// ---------------------------------------------------------------------------

class Png {
  Png(this.width, this.height, this.hasAlpha, this._rgba);
  final int width;
  final int height;
  final bool hasAlpha;
  final Uint8ListLike _rgba;

  /// 0xAARRGGBB at (x, y).
  int at(int x, int y) {
    final int o = (y * width + x) * 4;
    return (_rgba[o + 3] << 24) |
        (_rgba[o] << 16) |
        (_rgba[o + 1] << 8) |
        _rgba[o + 2];
  }
}

typedef Uint8ListLike = List<int>;

Png decodePng(File file) {
  final List<int> bytes = file.readAsBytesSync();
  const List<int> signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  for (int i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      throw StateError('${file.path} is not a PNG');
    }
  }

  int be32(int o) =>
      (bytes[o] << 24) | (bytes[o + 1] << 16) | (bytes[o + 2] << 8) | bytes[o + 3];

  int width = 0;
  int height = 0;
  int depth = 0;
  int colorType = 0;
  final List<int> idat = <int>[];
  int p = 8;
  while (p + 8 <= bytes.length) {
    final int length = be32(p);
    final String type = String.fromCharCodes(bytes.sublist(p + 4, p + 8));
    final int dataStart = p + 8;
    if (type == 'IHDR') {
      width = be32(dataStart);
      height = be32(dataStart + 4);
      depth = bytes[dataStart + 8];
      colorType = bytes[dataStart + 9];
      if (bytes[dataStart + 12] != 0) {
        throw StateError('${file.path}: interlaced PNG is not supported');
      }
    } else if (type == 'IDAT') {
      idat.addAll(bytes.sublist(dataStart, dataStart + length));
    } else if (type == 'IEND') {
      break;
    }
    p = dataStart + length + 4;
  }
  if (depth != 8 || (colorType != 2 && colorType != 6)) {
    throw StateError('${file.path}: only 8-bit RGB/RGBA PNGs are supported '
        '(depth $depth, colour type $colorType)');
  }

  final int channels = colorType == 6 ? 4 : 3;
  final List<int> raw = ZLibCodec().decode(idat);
  final int stride = width * channels;
  final List<int> out = List<int>.filled(width * height * 4, 255);
  final List<int> prior = List<int>.filled(stride, 0);
  final List<int> line = List<int>.filled(stride, 0);

  int q = 0;
  for (int y = 0; y < height; y++) {
    final int filter = raw[q++];
    for (int x = 0; x < stride; x++) {
      final int value = raw[q + x];
      final int a = x >= channels ? line[x - channels] : 0;
      final int b = prior[x];
      final int c = x >= channels ? prior[x - channels] : 0;
      int recon;
      switch (filter) {
        case 0:
          recon = value;
        case 1:
          recon = value + a;
        case 2:
          recon = value + b;
        case 3:
          recon = value + ((a + b) >> 1);
        case 4:
          final int pa = (b - c).abs();
          final int pb = (a - c).abs();
          final int pc = (a + b - 2 * c).abs();
          recon = value + (pa <= pb && pa <= pc ? a : (pb <= pc ? b : c));
        default:
          throw StateError('${file.path}: unknown PNG filter $filter');
      }
      line[x] = recon & 0xFF;
    }
    q += stride;
    for (int x = 0; x < width; x++) {
      final int o = (y * width + x) * 4;
      out[o] = line[x * channels];
      out[o + 1] = line[x * channels + 1];
      out[o + 2] = line[x * channels + 2];
      out[o + 3] = channels == 4 ? line[x * channels + 3] : 255;
    }
    prior.setAll(0, line);
  }
  return Png(width, height, colorType == 6, out);
}

/// The entries of an `.appiconset` `Contents.json`.
List<Map<String, Object?>> appIconImages() {
  final Map<String, Object?> contents = jsonDecode(
    File('${iosRunner.path}/Assets.xcassets/AppIcon.appiconset/Contents.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;
  return (contents['images']! as List<Object?>).cast<Map<String, Object?>>();
}

File appIconFile(String name) =>
    File('${iosRunner.path}/Assets.xcassets/AppIcon.appiconset/$name');

// ---------------------------------------------------------------------------

void main() {
  group('verify.ios-localizations-missing', () {
    test('#1/#2 Info.plist declares every locale the app ships', () {
      const String rule =
          'verify.ios-localizations-missing#1 — In the Kotlin app: a device set '
          'to French, Russian, Arabic, Japanese … resolves the matching '
          '`values-*` resource set, and Android 13+ additionally offers a '
          'per-app language picker driven by locales_config.xml. All 47 '
          'translations are reachable by an ordinary user. '
          'verify.ios-localizations-missing#2 — The port must do the same. '
          'Today: on iOS the app bundle contains only `Base.lproj` and '
          'Info.plist names no `CFBundleLocalizations` key, so '
          '`NSLocale.preferredLanguages` — which iOS filters against the '
          "bundle's declared localizations — reports only the development "
          'region. Flutter therefore hands `MaterialApp` an English locale no '
          'matter what the device is set to, and every one of the 47 '
          'translations is compiled into the binary but can never be displayed.';

      final Object? declared = infoPlist['CFBundleLocalizations'];
      expect(declared, isA<List<Object?>>(),
          reason: '$rule Info.plist has no CFBundleLocalizations array, so iOS '
              'believes the bundle is localized only for the development '
              'region.');

      final List<String> localizations =
          (declared! as List<Object?>).cast<String>();
      expect(localizations.length, greaterThan(40),
          reason: '$rule The whole catalogue is declared, not a sample — '
              'Android reaches all of it through values-*.');
      expect(localizations, contains('en'),
          reason: '$rule The development region is part of the list.');
      for (final String tag in <String>['fr', 'ru', 'ar', 'ja', 'zh', 'de']) {
        expect(localizations, contains(tag),
            reason: '$rule A device set to "$tag" must resolve the "$tag" '
                'translation, exactly as values-$tag does on Android.');
      }
    });

    test('#2 the declared list is generated from the ARB set, so the two '
        'cannot drift', () {
      const String rule =
          'verify.ios-localizations-missing#2 — The port must do the same. '
          'Today: on Android this works — `L10n.supportedLocales` is generated '
          'from the 50 ARB files and the platform reports the system locale. '
          'The generated app/lib/l10n/app_localizations.dart carries the '
          'instruction to fix this verbatim in its own header ("## iOS '
          'Applications … edit Info.plist … This list should be consistent '
          'with the languages listed in the L10n.supportedLocales property") '
          'and it was not acted on.';

      final List<String> localizations =
          (infoPlist['CFBundleLocalizations']! as List<Object?>).cast<String>();

      expect(localizations..sort(), arbTags().map(iosTag).toList()..sort(),
          reason: '$rule Every app_*.arb is declared and nothing else is.');
      expect(
        localizations.toSet(),
        L10n.supportedLocales.map(iosTagOfLocale).toSet(),
        reason: '$rule "This list should be consistent with the languages '
            'listed in the L10n.supportedLocales property" — the header of '
            'the generated delegate, quoted.',
      );

      // The region-qualified and script-qualified tags are written the way
      // Apple writes them, or iOS will not match a device set to them.
      expect(localizations, containsAll(<String>['pt-BR', 'pt-PT', 'zh-CN']),
          reason: "\$rule Apple's identifiers are hyphenated; the ARB file "
              'names are not.');
      expect(localizations, contains('sr-Latn'),
          reason: '$rule …and a script subtag is a subtag, not a country.');
      expect(localizations.any((String t) => t.contains('_')), isFalse,
          reason: '$rule No ARB-style underscore survives into the plist.');
    });

    test('#1 the per-app language picker: iOS needs the bundle localized to '
        'offer one', () {
      const String rule =
          'verify.ios-localizations-missing#1 — Android 13+ additionally '
          'offers a per-app language picker driven by locales_config.xml. All '
          '47 translations are reachable by an ordinary user. '
          'verify.ios-localizations-missing#2 — The port must do the same.';

      // iOS shows Settings ▸ <app> ▸ Language only when the bundle declares
      // more than one localization, and it lists exactly those localizations.
      final List<String> localizations =
          (infoPlist['CFBundleLocalizations']! as List<Object?>).cast<String>();
      expect(localizations.length, greaterThan(1), reason: rule);
      expect(localizations.toSet().length, localizations.length,
          reason: '$rule The picker would show a duplicate entry.');

      // Android's own half of the same rule, so the two platforms agree on
      // what "all of them" means.
      expect(
        localizations.length,
        arbTags().length,
        reason: '$rule Both platforms are driven by the one ARB catalogue.',
      );
    });
  });

  group('verify.ios-icon-and-label', () {
    test('#1/#2 the home screen says "Habits", not "Uhabits" and not the '
        'store name', () {
      const String rule =
          'verify.ios-icon-and-label#1 — In the Kotlin app: the launcher shows '
          'the blue Loop mark … under the localized label "Habits" (which '
          'changes with the per-app language setting), deliberately not the '
          'store name "Loop Habit Tracker". '
          'verify.ios-icon-and-label#2 — The port must do the same. Today: the '
          'iOS side was never touched: the home screen shows the default '
          'Flutter logo that `flutter create` generated, labelled "Uhabits" — '
          'neither the app name nor the launcher name the ledger specifies.';

      final Map<String, Object?> plist = infoPlist;
      final String label = androidStrings('values/strings.xml')['main_activity_title']!;
      final String appName = androidStrings('values/strings.xml')['app_name']!;

      expect(plist['CFBundleDisplayName'], label,
          reason: '$rule CFBundleDisplayName is the home-screen label; the '
              'Android resource says it is "$label".');
      expect(plist['CFBundleDisplayName'], isNot('Uhabits'),
          reason: '$rule "Uhabits" is neither the app name nor the launcher '
              'name.');
      expect(plist['CFBundleDisplayName'], isNot(appName),
          reason: '$rule The launcher label stays distinct from the store '
              'name.');
      expect(plist['CFBundleName'], label,
          reason: '$rule CFBundleName is the short name iOS falls back to '
              '(Settings, the app switcher); "uhabits" is not a name this app '
              'answers to anywhere.');
      expect(plist['CFBundleName'], isNot('uhabits'), reason: rule);

      // The Dart side answers with the same two strings.
      expect(label, arb('en')['mainActivityTitle'], reason: rule);
      expect(appName, arb('en')['appName'], reason: rule);
    });

    test('#1 the label is localized, so it follows the per-app language', () {
      const String rule =
          'verify.ios-icon-and-label#1 — the launcher shows … the localized '
          'label "Habits" (which changes with the per-app language setting). '
          'verify.ios-icon-and-label#2 — The port must do the same. Today: the '
          'iOS side was never touched. On iOS the launcher label is localized '
          'by shipping CFBundleDisplayName in per-locale InfoPlist.strings, '
          'the exact counterpart of the values-*/strings.xml mirroring that '
          'test/platform/launcher_icon_test.dart already asserts for Android.';

      final List<String> regions = knownRegions();
      int localized = 0;
      for (final String tag in arbTags()) {
        final Object? title = arb(tag)['mainActivityTitle'];
        if (title == null) continue; // gu translates almost nothing.
        localized++;
        final File strings =
            File('${iosRunner.path}/${iosTag(tag)}.lproj/InfoPlist.strings');
        expect(strings.existsSync(), isTrue,
            reason: '$rule Missing ${iosTag(tag)}.lproj/InfoPlist.strings for '
                'ARB "$tag".');
        expect(stringsFile(strings)['CFBundleDisplayName'], title,
            reason: '$rule ${iosTag(tag)}.lproj disagrees with app_$tag.arb.');
        expect(regions, contains(iosTag(tag)),
            reason: '$rule A .lproj Xcode does not know about is not copied '
                'into the bundle: knownRegions has to name ${iosTag(tag)}.');
        expect(pbxproj, contains('${iosTag(tag)}.lproj/InfoPlist.strings'),
            reason: '$rule …and the file has to be referenced by the project, '
                'or it is a file on disk that never ships.');
      }
      expect(localized, greaterThan(40),
          reason: '$rule The whole translated set is mirrored, not a sample.');

      expect(pbxproj, contains('InfoPlist.strings in Resources'),
          reason: '$rule The variant group is in the Runner target\'s '
              'Resources build phase.');

      // A spot check in both scripts, matching launcher_icon_test.dart's.
      expect(
        stringsFile(File('${iosRunner.path}/de.lproj/InfoPlist.strings'))[
            'CFBundleDisplayName'],
        'Gewohnheiten',
        reason: rule,
      );
      expect(
        stringsFile(File('${iosRunner.path}/ja.lproj/InfoPlist.strings'))[
            'CFBundleDisplayName'],
        '習慣',
        reason: rule,
      );
    });

    test('#2 the app icon is the Loop mark on #1976D2, not the stock Flutter '
        'logo', () {
      const String rule =
          'verify.ios-icon-and-label#2 — The port must do the same. Today: '
          'uhabits-flutter/app/ios/Runner/Assets.xcassets/AppIcon.appiconset/ '
          '— all sizes are the stock Flutter logo; Icon-App-1024x1024@1x.png '
          'is the blue Flutter mark. '
          'verify.ios-icon-and-label#1 — the launcher shows the blue Loop '
          'mark … background = flat colour @color/ic_launcher_background = '
          '#1976D2 with a white foreground.';

      final int background = androidLauncherBackground();
      expect(background, 0xFF1976D2,
          reason: '$rule The colour comes from the Android resource, so the '
              'two platforms cannot drift.');

      final Png marketing = decodePng(appIconFile('Icon-App-1024x1024@1x.png'));
      expect(marketing.width, 1024, reason: rule);
      expect(marketing.height, 1024, reason: rule);

      for (final List<int> corner in <List<int>>[
        <int>[0, 0],
        <int>[1023, 0],
        <int>[0, 1023],
        <int>[1023, 1023],
      ]) {
        expect(
          marketing.at(corner[0], corner[1]),
          background,
          reason: '$rule The icon is a full-bleed #1976D2 field — the stock '
              'Flutter icon is white at (${corner[0]}, ${corner[1]}).',
        );
      }

      // The white Loop mark is actually drawn on that field.
      int white = 0;
      for (int y = 256; y < 768; y += 4) {
        for (int x = 256; x < 768; x += 4) {
          final int argb = marketing.at(x, y);
          if (((argb >> 16) & 0xFF) > 240 &&
              ((argb >> 8) & 0xFF) > 240 &&
              (argb & 0xFF) > 240) {
            white++;
          }
        }
      }
      expect(white, greaterThan(512),
          reason: '$rule The white foreground mark occupies the centre of the '
              'icon, as mipmap-*/ic_launcher_foreground.png does on Android.');

      expect(marketing.hasAlpha, isFalse,
          reason: '$rule An iOS app icon carries no alpha channel; the '
              'rounded corners are the system\'s, not the asset\'s.');
    });

    test('#2 every size the asset catalogue promises is present and correct',
        () {
      const String rule =
          'verify.ios-icon-and-label#2 — The port must do the same. Today: the '
          'iOS side was never touched — all sizes in '
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/ are the stock '
          'Flutter logo. Regenerating one size and leaving the rest is the '
          'same defect one bucket smaller, so every entry of Contents.json is '
          'checked, exactly as launcher_icon_test.dart#4 checks all five '
          'Android densities.';

      final int background = androidLauncherBackground();
      final List<Map<String, Object?>> images = appIconImages();
      expect(images, isNotEmpty, reason: rule);

      for (final Map<String, Object?> image in images) {
        final String name = image['filename']! as String;
        final double size = double.parse((image['size']! as String).split('x')[0]);
        final int scale =
            int.parse((image['scale']! as String).replaceAll('x', ''));
        final int pixels = (size * scale).round();

        final File file = appIconFile(name);
        expect(file.existsSync(), isTrue,
            reason: '$rule Contents.json names $name.');
        final Png png = decodePng(file);
        expect(<int>[png.width, png.height], <int>[pixels, pixels],
            reason: '$rule $name is declared ${image['size']} @$scale, so it '
                'is $pixels×$pixels.');
        expect(png.at(0, 0), background,
            reason: '$rule $name is the Loop icon too, not the stock logo.');
        expect(png.hasAlpha, isFalse,
            reason: '$rule $name carries no alpha channel.');
      }
    });
  });
}
