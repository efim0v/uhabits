// Converts the Android resource strings of uhabits-android into Flutter ARB
// files, for all locales at once.
//
// Android and ICU disagree about almost everything in a format string, so the
// interesting work is the translation between them:
//   %1$s / %2$d  ->  {p1} / {p2}          (positional)
//   %s / %d      ->  {p1}, {p2}, ...      (implicitly positional, in order)
//   <plurals>    ->  {count, plural, ...}
//   '            ->  ''                   (only in messages containing braces,
//                                          where ICU would treat it as escaping)
//
// Usage: dart tool/convert_strings.dart
import 'dart:convert';
import 'dart:io';

final _stringTag = RegExp(
    r'<string\s+name="([^"]+)"([^>]*)>(.*?)</string>',
    dotAll: true);
final _pluralsTag = RegExp(
    r'<plurals\s+name="([^"]+)"[^>]*>(.*?)</plurals>',
    dotAll: true);
final _pluralItem = RegExp(
    r'<item\s+quantity="([^"]+)"\s*>(.*?)</item>',
    dotAll: true);
final _positionalArg = RegExp(r'%(\d+)\$([sd])');
final _plainArg = RegExp(r'%([sd])');

/// Android quantity keywords that ICU also understands.
const _icuPluralKeywords = {'zero', 'one', 'two', 'few', 'many', 'other'};

/// Messages the English template must declare even though `values/strings.xml`
/// no longer does.
///
/// `overview` is still translated in 46 `values-*` folders — it is the title of
/// the show screen's first card — but the default file dropped it, so a
/// straight conversion produces a template without it and gen-l10n emits no
/// `L10n.overview` at all. The English text below is the one the string had
/// before it was lost (`platform-glue.localization-inventory#2`); a real
/// translation always wins, because the loop below writes over anything set
/// here.
const _templateAdditions = <String, String>{'overview': 'Overview'};

void main(List<String> args) {
  final repoRoot = Directory.current.parent.path;
  final resDir = Directory('$repoRoot/uhabits-android/src/main/res');
  if (!resDir.existsSync()) {
    stderr.writeln('Android resources not found at ${resDir.path}');
    exit(2);
  }

  final valueDirs = resDir
      .listSync()
      .whereType<Directory>()
      .where((d) => d.uri.pathSegments[d.uri.pathSegments.length - 2]
          .startsWith('values'))
      .toList();

  // Decide the Flutter locale name for each Android values-* directory. When a
  // language appears with exactly one region, the region is dropped, because
  // Flutter resolves app_de.arb for de_DE, de_AT and de_CH alike — keeping the
  // region would leave those users on English.
  final byLanguage = <String, List<String>>{};
  final dirLocale = <String, _Locale>{};
  for (final dir in valueDirs) {
    final name = dir.path.split(Platform.pathSeparator).last;
    final locale = _parseLocale(name);
    if (locale == null) continue;
    dirLocale[dir.path] = locale;
    byLanguage.putIfAbsent(locale.language, () => []).add(locale.region ?? '');
  }

  var written = 0;
  var totalMessages = 0;
  final outDir = Directory('$repoRoot/uhabits-flutter/app/lib/l10n');
  outDir.createSync(recursive: true);

  for (final entry in dirLocale.entries) {
    final file = File('${entry.key}/strings.xml');
    if (!file.existsSync()) continue;
    final locale = entry.value;
    final isTemplate = locale.language == 'en' && locale.region == null;
    final dirName = entry.key.split(Platform.pathSeparator).last;
    final regions = byLanguage[locale.language]!.toSet();
    final suffix = _localeOverrides[dirName] ??
        ((regions.length > 1 && locale.region != null)
            ? '${locale.language}_${locale.region}'
            : locale.language);

    final messages = _parse(file.readAsStringSync());
    if (messages.isEmpty) continue;
    totalMessages += messages.length;

    final arb = <String, Object?>{'@@locale': suffix};
    if (isTemplate) {
      // Keys 46 translations define and the English `values/strings.xml` has
      // lost. gen-l10n generates a getter only for what the template declares,
      // so without these the translations are orphaned and every locale falls
      // back to a wrong string — which is exactly what happened to the show
      // screen's Overview card before the template was repaired by hand. The
      // repair lives here now, so that regenerating does not undo it.
      arb.addAll(_templateAdditions);
    }
    for (final message in messages) {
      arb[message.key] = message.value;
      if (isTemplate && message.placeholders.isNotEmpty) {
        arb['@${message.key}'] = {
          'placeholders': {
            for (final p in message.placeholders)
              p.name: {'type': p.type},
          },
        };
      }
    }

    void write(String name) {
      final copy = Map<String, Object?>.of(arb)..['@@locale'] = name;
      File('${outDir.path}/app_$name.arb').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(copy)}\n');
      written++;
    }

    write(suffix);

    // A regional file alone is not enough: Flutter resolves pt_AO through the
    // base pt, and refuses to generate at all when the base is missing.
    if (_localeOverrides[dirName] == null &&
        regions.length > 1 &&
        locale.region != null &&
        _baseRegion[locale.language] == locale.region) {
      write(locale.language);
    }
  }

  stdout.writeln('Wrote $written ARB files with $totalMessages messages '
      'to ${outDir.path}');
}

class _Locale {
  _Locale(this.language, this.region);
  final String language;
  final String? region;
}

/// Android carries Java's pre-1.7 language codes; ICU and Flutter use the
/// modern ones, and Flutter canonicalises the filename before comparing it with
/// @@locale, so emitting the legacy code fails generation outright.
const Map<String, String> _legacyLanguageCodes = {
  'in': 'id', // Indonesian
  'iw': 'he', // Hebrew
  'ji': 'yi', // Yiddish
};

/// Android resource directories whose Flutter locale cannot be derived
/// mechanically. Serbian is the awkward one: Android encodes the script in the
/// region, so values-sr-rCS is Latin and values-sr-rSP is Cyrillic.
const Map<String, String> _localeOverrides = {
  'values-sr-rCS': 'sr_Latn',
  'values-sr-rSP': 'sr',
};

/// When a language ships several regions, Flutter still wants a base file to
/// fall back on. This picks which region supplies it.
const Map<String, String> _baseRegion = {
  'pt': 'BR',
  'zh': 'CN',
};

_Locale? _parseLocale(String dirName) {
  if (dirName == 'values') return _Locale('en', null);
  if (!dirName.startsWith('values-')) return null;
  final rest = dirName.substring('values-'.length);
  // Skip qualifiers that are not locales (values-night, values-v21, ...).
  final match = RegExp(r'^([a-z]{2,3})(?:-r([A-Z]{2}))?$').firstMatch(rest);
  if (match == null) return null;
  final language = match.group(1)!;
  final region = match.group(2);
  return _Locale(
    _legacyLanguageCodes[language] ?? language,
    region,
  );
}

class _Placeholder {
  _Placeholder(this.name, this.type);
  final String name;
  final String type;
}

class _Message {
  _Message(this.key, this.value, this.placeholders);
  final String key;
  final String value;
  final List<_Placeholder> placeholders;
}

List<_Message> _parse(String xml) {
  final messages = <_Message>[];

  for (final match in _stringTag.allMatches(xml)) {
    final attributes = match.group(2) ?? '';
    if (attributes.contains('translatable="false"')) continue;
    final key = _dartKey(match.group(1)!);
    final converted = _convertPlaceholders(_unescape(match.group(3)!));
    messages.add(_Message(key, converted.text, converted.placeholders));
  }

  for (final match in _pluralsTag.allMatches(xml)) {
    final key = _dartKey(match.group(1)!);
    final branches = <String, String>{};
    final placeholders = <_Placeholder>[];
    for (final item in _pluralItem.allMatches(match.group(2)!)) {
      final quantity = item.group(1)!;
      if (!_icuPluralKeywords.contains(quantity)) continue;
      // Inside a plural branch the count is referenced as {count}, not {p1}.
      final converted = _convertPlaceholders(_unescape(item.group(2)!),
          firstArgName: 'count');
      branches[quantity] = converted.text;
      for (final p in converted.placeholders) {
        if (!placeholders.any((existing) => existing.name == p.name)) {
          placeholders.add(p);
        }
      }
    }
    if (branches.isEmpty) continue;
    branches.putIfAbsent('other', () => branches.values.first);
    final body = branches.entries
        .map((e) => '${e.key} {${e.value}}')
        .join(' ');
    messages.add(_Message(key, '{count, plural, $body}', [
      _Placeholder('count', 'num'),
      ...placeholders.where((p) => p.name != 'count'),
    ]));
  }

  return messages;
}

class _Converted {
  _Converted(this.text, this.placeholders);
  final String text;
  final List<_Placeholder> placeholders;
}

_Converted _convertPlaceholders(String input, {String? firstArgName}) {
  final placeholders = <_Placeholder>[];
  var index = 0;

  String nameFor(int position, String conversion) {
    final name =
        (position == 1 && firstArgName != null) ? firstArgName : 'p$position';
    final type = conversion == 'd' ? 'int' : 'String';
    if (!placeholders.any((p) => p.name == name)) {
      placeholders.add(_Placeholder(name, type));
    }
    return name;
  }

  var text = input.replaceAllMapped(_positionalArg, (m) {
    final position = int.parse(m.group(1)!);
    return '{${nameFor(position, m.group(2)!)}}';
  });

  text = text.replaceAllMapped(_plainArg, (m) {
    index++;
    return '{${nameFor(index, m.group(1)!)}}';
  });

  // ICU treats a single quote as an escape character in messages that contain
  // placeholders, so "user's" would silently swallow the following text.
  if (text.contains('{')) {
    text = text.replaceAll("'", "''");
  }

  return _Converted(text, placeholders);
}

String _dartKey(String androidName) {
  final parts = androidName.split('_');
  return parts.first +
      parts
          .skip(1)
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join();
}

String _unescape(String raw) => _decodeCharRefs(raw
        .trim()
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'"))
    // Last, so that `&amp;#8230;` — an escaped ampersand followed by text —
    // stays the literal "&#8230;" the translator wrote instead of becoming an
    // ellipsis. The numeric pass above cannot see through "&amp;" either,
    // because that string contains no "&#" sequence.
    .replaceAll('&amp;', '&');

/// An XML numeric character reference: `&#8230;` or `&#x2026;`.
///
/// AAPT decodes these while it compiles the resource table, so what the Android
/// app renders is the character, never the escape. 34 of the translated
/// `values-*/strings.xml` files spell the ellipsis of `view_all_contributors`
/// this way (`audit7.xml-numeric-character-references-survive-into#1`), and the
/// named-entity list above cannot reach them: `&#8230;` is not `&hellip;`.
final _charRef = RegExp(r'&#(?:[xX]([0-9a-fA-F]+)|([0-9]+));');

/// The `&#NNNN;` half of what AAPT does to a string resource.
///
/// This subsumes `&#39;`, which the named list used to carry as a special case.
/// A reference that is not a valid Unicode scalar value is left alone rather
/// than throwing: AAPT would not have accepted it either, so the literal text
/// is the honest thing to carry across.
String _decodeCharRefs(String raw) =>
    raw.replaceAllMapped(_charRef, (match) {
      final hex = match.group(1);
      final int code = hex != null
          ? int.parse(hex, radix: 16)
          : int.parse(match.group(2)!);
      if (code <= 0 || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) {
        return match.group(0)!;
      }
      return String.fromCharCode(code);
    });
