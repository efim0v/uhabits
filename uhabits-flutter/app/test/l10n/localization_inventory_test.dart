/// The localization inventory, asserted against the ARB files that carry it.
///
/// Upstream this lives in 48 `res/values*/strings.xml` files plus
/// `constants.xml`, `fontawesome.xml` and `pickers.xml`. The port carries the
/// translatable half as one ARB per locale under `lib/l10n/` and the rest as
/// Dart constants, which is what the ledger's own notes call for: "the 365
/// fontawesome glyphs and the 10 URLs should stay as constants, not localized
/// resources", and "ARB has no array concept; each array becomes an explicit
/// ordered list of message ids in Dart".
///
/// The rules here are counting rules — how many locales, how many keys, which
/// plural categories, which locale is how complete. They are checkable exactly
/// as stated, by reading the files, and they are worth checking: a translation
/// import that silently drops a key, or a template edit that orphans forty
/// translations, is invisible in every other test in this repository. That last
/// one is not hypothetical — see the `overview` note under rule 2 below.
///
/// The last group covers `platform-glue.rtl-layout`, which belongs here because
/// in Flutter the text direction is a consequence of the locale rather than a
/// manifest flag: shipping `ar`, `fa` and `he` is what turns the mirroring on.
///
/// Not asserted here, and left uncited on purpose:
///
///  - rule 11 of `platform-glue.localization-inventory` (which locales
///    translate the `hints` string-array). ARB has no arrays, so the array's
///    per-locale translation status has no counterpart to check.
///  - rule 15 (`pickers.xml`): those 21 resources are dimensions and floats of
///    the Android date-time picker widget, which the port does not use.
///  - rule 8 of `platform-glue.locale-config` (instrumentation forcing en/US):
///    there is no instrumentation harness.
///  - rule 3 of `platform-glue.rtl-layout` (the third factor of
///    `HeaderView.updateScrollDirection`). The first two — the base -1 and the
///    flip from `isCheckmarkSequenceReversed` — are asserted in
///    test/ui/habits/list/list_header_test.dart under
///    `list-habits.header-scrolling#4`. The RTL factor is deliberately absent
///    from `ListHeader._scrollDirection`, and correctly so *given* rule 4's
///    gap: the drawn strip does not mirror under an RTL locale, so flipping
///    the drag would move it against its own columns. The two belong to one
///    fix, described under rule 4 below and reported with this slice.
///  - rule 6 (mirroring is partial by design, because some paddings use
///    Left/Right rather than Start/End). The Flutter distinction is
///    `EdgeInsets` versus `EdgeInsetsDirectional` and the port uses the
///    non-directional one throughout; asserting today's choice per widget
///    would pin a set of paddings that ought to be free to change.
library;

// The preferences and the header view live outside uhabits_core's public
// barrel, and are imported by path exactly as lib/ imports them.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/l10n/app_localizations.dart';
import 'package:uhabits/platform/file_preferences_storage.dart';
import 'package:uhabits/ui/about/about_screen.dart';
import 'package:uhabits/ui/habits/list/entry_panel.dart';
import 'package:uhabits/ui/habits/list/list_header.dart';
import 'package:uhabits/ui/settings/settings_screen.dart';
import 'package:uhabits_core/src/gui/font_awesome.dart';
import 'package:uhabits_core/src/preferences/memory_storage.dart';
import 'package:uhabits_core/src/preferences/preferences.dart' as core;
import 'package:uhabits_core/src/ui/views/habit_list_header.dart';
import 'package:uhabits_core/uhabits_core.dart' as core;

// ---------------------------------------------------------------------------
// Reading the ARB set
// ---------------------------------------------------------------------------

/// `lib/l10n`, found by walking up from the test's working directory.
final Directory arbDir = _findArbDir();

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

/// Every ARB keyed by its locale tag: `en`, `pt_BR`, `sr_Latn`, ...
final Map<String, Map<String, Object?>> arbs = <String, Map<String, Object?>>{
  for (final File file in arbDir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.arb')))
    file.uri.pathSegments.last
            .replaceFirst('app_', '')
            .replaceFirst('.arb', ''):
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
};

final Map<String, Object?> template = arbs['en']!;

/// The message ids of one ARB: everything that is not an `@`-prefixed
/// attribute block or the `@@locale` marker.
Set<String> messagesOf(Map<String, Object?> arb) =>
    arb.keys.where((String k) => !k.startsWith('@')).toSet();

/// The message ids the template declares as ICU plurals.
final Set<String> pluralKeys = messagesOf(template)
    .where((String k) => '${template[k]}'.contains(', plural,'))
    .toSet();

/// The plural categories one ARB actually spells out, across all its plurals.
Set<String> pluralCategoriesOf(Map<String, Object?> arb) {
  final RegExp category = RegExp(r'(?:^|[}\s])(zero|one|two|few|many|other)\s*\{');
  return <String>{
    for (final String key in arb.keys.where(pluralKeys.contains))
      ...category
          .allMatches('${arb[key]}')
          .map((RegExpMatch m) => m.group(1)!),
  };
}

/// How many plain (non-plural) messages a locale translates. This is what
/// upstream counted as `<string>` entries in that locale's `strings.xml`.
int stringCountOf(String locale) =>
    messagesOf(arbs[locale]!).difference(pluralKeys).length;

/// How many of the six plurals a locale translates — upstream's plural count.
int pluralCountOf(String locale) =>
    messagesOf(arbs[locale]!).intersection(pluralKeys).length;


// ---------------------------------------------------------------------------
// RTL instrumentation
// ---------------------------------------------------------------------------

/// A [core.Canvas] that remembers where things were drawn instead of drawing
/// them. Used to read back the geometry of the custom-drawn header strip,
/// which is the one part of the screen Flutter's `Directionality` cannot
/// mirror on its own.
class RecordingCanvas extends core.Canvas {
  RecordingCanvas(this._width, this._height);

  final double _width;
  final double _height;

  /// The x of every `drawText` call, in call order.
  final List<double> textX = <double>[];

  /// The centre x of every `fillCircle` call.
  final List<double> circleX = <double>[];

  /// Every `drawLine`, as `x1->x2`.
  final List<String> lines = <String>[];

  @override
  double getWidth() => _width;

  @override
  double getHeight() => _height;

  @override
  void drawText(String text, double x, double y) => textX.add(x);

  @override
  void fillCircle(double centerX, double centerY, double radius) =>
      circleX.add(centerX);

  @override
  void drawLine(double x1, double y1, double x2, double y2) =>
      lines.add('$x1->$x2');

  @override
  void setColor(core.Color color) {}

  @override
  void setFont(core.Font font) {}

  @override
  void setFontSize(double size) {}

  @override
  void setStrokeWidth(double size) {}

  @override
  void setTextAlign(core.TextAlign align) {}

  @override
  void fillRect(double x, double y, double width, double height) {}

  @override
  void drawRect(double x, double y, double width, double height) {}

  @override
  void fillRoundRect(
    double x,
    double y,
    double width,
    double height,
    double cornerRadius,
  ) {}

  @override
  void fillArc(
    double centerX,
    double centerY,
    double radius,
    double startAngle,
    double swipeAngle,
  ) {}

  @override
  double measureText(String text) => text.length * 6.0;

  @override
  core.Image toImage() => throw UnimplementedError();
}

void main() {
  // =======================================================================
  // platform-glue.localization-inventory
  // =======================================================================

  group('platform-glue.localization-inventory', () {
    test('#1 every upstream locale directory has exactly one ARB, and the '
        'delegate offers all of them', () {
      // Upstream's 47 translated `values-*` directories, in its own spelling,
      // mapped onto the tag this port files them under. Four names move:
      // `in`/`iw` are the deprecated ISO codes Android resource resolution
      // needs and Dart's Locale does not (see locale-config#5), and the two
      // Serbian scripts are spelled by script rather than by the country that
      // used to stand in for one.
      const Map<String, String> upstreamLocales = <String, String>{
        'af-ZA': 'af', 'ar-SA': 'ar', 'bg-BG': 'bg', 'ca-ES': 'ca',
        'cs-CZ': 'cs', 'da-DK': 'da', 'de-DE': 'de', 'el-GR': 'el',
        'eo-UY': 'eo', 'es-ES': 'es', 'eu-ES': 'eu', 'fa-IR': 'fa',
        'fi-FI': 'fi', 'fr-FR': 'fr', 'gu-IN': 'gu', 'hi-IN': 'hi',
        'hr-HR': 'hr', 'hu-HU': 'hu', 'hy-AM': 'hy', 'in-ID': 'id',
        'is-IS': 'is', 'it-IT': 'it', 'iw-IL': 'he', 'ja-JP': 'ja',
        'ka-GE': 'ka', 'ko-KR': 'ko', 'ml-IN': 'ml', 'nl-NL': 'nl',
        'no-NO': 'no', 'pl-PL': 'pl', 'pt-BR': 'pt_BR', 'pt-PT': 'pt_PT',
        'ro-RO': 'ro', 'ru-RU': 'ru', 'sk-SK': 'sk', 'sl-SI': 'sl',
        'sr-CS': 'sr_Latn', 'sr-SP': 'sr', 'sv-SE': 'sv', 'ta-IN': 'ta',
        'te-IN': 'te', 'tr-TR': 'tr', 'ug-CN': 'ug', 'uk-UA': 'uk',
        'vi-VN': 'vi', 'zh-CN': 'zh_CN', 'zh-TW': 'zh_TW',
      };

      expect(upstreamLocales, hasLength(47),
          reason: 'platform-glue.localization-inventory#1 — There are 47 '
              'translated locale resource directories plus the default `values` '
              'directory. Each locale directory contains exactly one file: '
              'strings.xml.');
      for (final String tag in upstreamLocales.values) {
        expect(arbs.containsKey(tag), isTrue,
            reason: 'platform-glue.localization-inventory#1: $tag is carried');
      }
      expect(arbs.containsKey('en'), isTrue,
          reason: 'platform-glue.localization-inventory#1: plus the default '
              'set, which is the ARB template');

      // Exactly one file per locale: the ARB set is keyed by tag, so a second
      // file for a locale could not have survived the map above.
      expect(
        arbDir
            .listSync()
            .whereType<File>()
            .where((File f) => f.path.endsWith('.arb'))
            .length,
        arbs.length,
        reason: 'platform-glue.localization-inventory#1: one ARB per locale',
      );

      // The two extras are the generic fallbacks Flutter resolves a
      // region-less `pt` or `zh` device to; upstream had no equivalent because
      // Android falls back through the resource qualifier chain instead.
      expect(
        arbs.keys.toSet().difference(upstreamLocales.values.toSet()),
        <String>{'en', 'pt', 'zh'},
        reason: 'platform-glue.localization-inventory#1: nothing else is '
            'carried',
      );

      // Every ARB is offered by the delegate, and nothing is offered that has
      // no ARB behind it.
      final Set<String> offered = L10n.supportedLocales
          .map((Locale l) => <String?>[
                l.languageCode,
                l.scriptCode,
                l.countryCode,
              ].whereType<String>().join('_'))
          .toSet();
      expect(offered, arbs.keys.toSet(),
          reason: 'platform-glue.localization-inventory#1: the delegate offers '
              'exactly the locales that have an ARB');
    });

    test('#2 the template is the whole inventory, and no translation defines '
        'a key it does not have', () {
      final Set<String> messages = messagesOf(template);

      expect(messages.length - pluralKeys.length, 187,
          reason: 'platform-glue.localization-inventory#2 — The default '
              'res/values/strings.xml contains 195 named resources: 188 '
              '<string>, 6 <plurals>, and 1 <string-array> ("hints"). The port '
              'carries 187 plain messages: the string-array became two message '
              'ids that were already strings, and the empty '
              'title_activity_show_habit label has no counterpart in a Flutter '
              'app (see rule 3).');
      expect(pluralKeys, hasLength(6),
          reason: 'platform-glue.localization-inventory#2: 6 plurals');

      // "No translated locale defines any key that does not exist in the
      // default file (zero obsolete keys)."
      //
      // This assertion found a real one: 46 translations carried `overview`
      // while the English template had lost it, so `L10n.overview` did not
      // exist and the habit detail screen titled its Overview card "Habit
      // strength". The template was repaired; see the slice notes.
      for (final MapEntry<String, Map<String, Object?>> arb in arbs.entries) {
        expect(
          messagesOf(arb.value).difference(messages),
          isEmpty,
          reason: 'platform-glue.localization-inventory#2: ${arb.key} defines '
              'no key the template does not have',
        );
      }
    });

    test('#3 no message is the empty string', () {
      expect(
        <String>[
          for (final String key in messagesOf(template))
            if ('${template[key]}'.isEmpty) key,
        ],
        isEmpty,
        reason: 'platform-glue.localization-inventory#3 — Exactly one string is '
            'marked translatable="false" in strings.xml: '
            'title_activity_show_habit (an empty string used as the '
            'ShowHabitActivity label). A Flutter route has no Activity label to '
            'blank out, so the port carries no such message — and, with it '
            'gone, no message in the template is empty.',
      );
    });

    test('#4 the messages a fully translated locale still shows in English',
        () {
      // Upstream's list of ten, minus title_activity_show_habit (rule 3).
      const Set<String> untranslated = <String>{
        'checkmarkStackWidget',
        'frequencyStackWidget',
        'historyStackWidget',
        'scoreStackWidget',
        'streaksStackWidget',
        'prefAnimationsDescription',
        'prefAnimationsTitle',
        'search',
        'skipDay',
      };

      for (final String locale in <String>['ru', 'de', 'fr', 'ja', 'zh_CN']) {
        expect(
          messagesOf(template)
              .difference(pluralKeys)
              .difference(messagesOf(arbs[locale]!)),
          untranslated,
          reason: 'platform-glue.localization-inventory#4 — 10 strings are '
              'never translated in any complete locale, so a fully translated '
              'locale has 178 strings: checkmark_stack_widget, '
              'frequency_stack_widget, history_stack_widget, '
              'score_stack_widget, streaks_stack_widget, '
              'pref_animations_description, pref_animations_title, search, '
              'skip_day, title_activity_show_habit. ($locale)',
        );
        expect(stringCountOf(locale), 178,
            reason: 'platform-glue.localization-inventory#4: which leaves 178 '
                '($locale)');
      }

      // 187 template messages minus the nine leaves exactly 178.
      expect(messagesOf(template).difference(pluralKeys).length - 9, 178,
          reason: 'platform-glue.localization-inventory#4');
    });

    test('#5 the six plural keys, and the template\'s two categories', () {
      expect(
        pluralKeys,
        <String>{
          'toastHabitsChanged',
          'toastHabitsDeleted',
          'toastHabitsArchived',
          'toastHabitsUnarchived',
          'deleteHabitsTitle',
          'deleteHabitsMessage',
        },
        reason: 'platform-glue.localization-inventory#5 — There are exactly 6 '
            'plurals keys: toast_habits_changed, toast_habits_deleted, '
            'toast_habits_archived, toast_habits_unarchived, '
            'delete_habits_title, delete_habits_message. The default locale '
            'defines only quantity="one" and quantity="other" for each.',
      );
      expect(pluralCategoriesOf(template), <String>{'one', 'other'},
          reason: 'platform-glue.localization-inventory#5: the template spells '
              'out one and other, and nothing else');
      for (final String key in pluralKeys) {
        expect('${template[key]}', startsWith('{count, plural,'),
            reason: 'platform-glue.localization-inventory#5: $key is an ICU '
                'plural over `count`');
      }
    });

    test('#6 the six ICU categories, with zero only in Arabic', () {
      final Set<String> used = <String>{
        for (final Map<String, Object?> arb in arbs.values)
          ...pluralCategoriesOf(arb),
      };

      expect(
        used,
        <String>{'zero', 'one', 'two', 'few', 'many', 'other'},
        reason: 'platform-glue.localization-inventory#6 — Across all locales '
            'the plural quantity classes used are: other, one, few, many, two, '
            'zero. Only values-ar-rSA uses quantity="zero"; ARB must therefore '
            'support zero/one/two/few/many/other for Arabic and the Slavic '
            'locales. The raw tallies upstream quotes do not carry over '
            'unchanged: the port ships two locales Android did not need '
            '(generic pt and zh) and the template itself is one of the ARBs, so '
            'what is asserted is the set of classes and which locale needs '
            'which.',
      );

      expect(
        <String>[
          for (final MapEntry<String, Map<String, Object?>> arb in arbs.entries)
            if (pluralCategoriesOf(arb.value).contains('zero')) arb.key,
        ],
        <String>['ar'],
        reason: 'platform-glue.localization-inventory#6: only Arabic uses zero',
      );
      expect(pluralCategoriesOf(arbs['ar']!),
          <String>{'zero', 'one', 'two', 'few', 'many', 'other'},
          reason: 'platform-glue.localization-inventory#6: and Arabic uses all '
              'six');

      // The Slavic locales are why `few` and `many` have to exist at all.
      for (final String locale in <String>['ru', 'pl', 'uk', 'cs', 'sk']) {
        expect(pluralCategoriesOf(arbs[locale]!),
            containsAll(<String>['one', 'few', 'many', 'other']),
            reason: 'platform-glue.localization-inventory#6: $locale needs few '
                'and many');
      }
      expect(pluralCategoriesOf(arbs['sl']!), contains('two'),
          reason: 'platform-glue.localization-inventory#6: Slovenian is the '
              'other locale with a dual');
    });

    test('#7 the six format-bearing messages and their placeholders', () {
      Set<String> placeholdersOf(String key) => RegExp(r'\{(\w+)\}')
          .allMatches('${template[key]}')
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();

      final Map<String, Set<String>> formatted = <String, Set<String>>{
        for (final String key in messagesOf(template).difference(pluralKeys))
          if (placeholdersOf(key).isNotEmpty) key: placeholdersOf(key),
      };

      expect(
        formatted,
        <String, Set<String>>{
          'versionN': <String>{'p1'},
          'everyXDays': <String>{'p1'},
          'everyXWeeks': <String>{'p1'},
          'xTimesPerWeek': <String>{'p1'},
          'xTimesPerMonth': <String>{'p1'},
          'xTimesPerYDays': <String>{'p1', 'p2'},
        },
        reason: 'platform-glue.localization-inventory#7 — There are exactly 6 '
            'format-bearing strings, all positional-free Java format '
            'specifiers: version_n = "Version %s"; every_x_days = "Every %d '
            'days"; every_x_weeks = "Every %d weeks"; x_times_per_week = "%d '
            'times per week"; x_times_per_month = "%d times per month"; '
            'x_times_per_y_days = "%d times in %d days" (TWO arguments, '
            'order-sensitive — must become named placeholders in ARB).',
      );

      expect(template['versionN'], 'Version {p1}',
          reason: 'platform-glue.localization-inventory#7: %s became {p1}');
      expect(template['xTimesPerYDays'], '{p1} times in {p2} days',
          reason: 'platform-glue.localization-inventory#7: the two arguments '
              'are named, so a translation may reorder them without swapping '
              'their meaning');

      // Every translation of the two-argument message keeps both names.
      for (final MapEntry<String, Map<String, Object?>> arb in arbs.entries) {
        final Object? value = arb.value['xTimesPerYDays'];
        if (value == null) continue;
        expect('$value', allOf(contains('{p1}'), contains('{p2}')),
            reason: 'platform-glue.localization-inventory#7: ${arb.key} keeps '
                'both placeholders');
      }
    });

    test('#8 the messages that carried a literal percent are not messages any '
        'more', () {
      // Upstream marks nine resources formatted="false" because a literal `%`
      // would otherwise be read as a format specifier. Five are the stack
      // widget names; four are URLs in constants.xml.
      for (final String key in <String>[
        'checkmarkStackWidget',
        'frequencyStackWidget',
        'scoreStackWidget',
        'historyStackWidget',
        'streaksStackWidget',
      ]) {
        expect(template[key], isNotNull,
            reason: 'platform-glue.localization-inventory#8 — Five strings '
                'carry formatted="false" in strings.xml '
                '(checkmark_stack_widget, frequency_stack_widget, '
                'score_stack_widget, history_stack_widget, '
                'streaks_stack_widget) and four in constants.xml (feedbackURL, '
                'privacyPolicyURL, codeContributorsURL, syncBaseURL) because '
                'they contain literal % characters or are URL-encoded. ARB has '
                'no format flag: a message is a format string only when it '
                'declares placeholders, so these five need no marking. ($key)');
        expect(RegExp(r'\{\w+\}').hasMatch('${template[key]}'), isFalse,
            reason: 'platform-glue.localization-inventory#8: $key declares no '
                'placeholder, so nothing in it is interpreted');
      }

      // The four URL-encoded ones are Dart constants, out of the ARB entirely,
      // which is the only way a literal % survives untouched.
      expect(AboutLinks.sendFeedback.toString(), contains('%20'),
          reason: 'platform-glue.localization-inventory#8: feedbackURL is '
              'URL-encoded and lives outside the message catalogue');
      for (final String key in messagesOf(template)) {
        expect('${template[key]}', isNot(contains('://')),
            reason: 'platform-glue.localization-inventory#8: no URL is a '
                'message ($key)');
      }
    });

    test('#9 translation completeness by locale', () {
      const Map<String, int> expected = <String, int>{
        'af': 22, 'gu': 2, 'ug': 12, 'te': 36, 'hy': 66, 'no': 120,
        'eo': 135, 'is': 146, 'pt_PT': 162, 'hr': 167, 'sr_Latn': 171,
        'ro': 172, 'eu': 176, 'ca': 177, 'da': 177,
        'hu': 183, 'id': 183, 'sv': 183, 'uk': 183,
      };

      for (final MapEntry<String, int> entry in expected.entries) {
        expect(stringCountOf(entry.key), entry.value,
            reason: 'platform-glue.localization-inventory#9 — Translation '
                'completeness by locale (count of <string> entries present): '
                'af-ZA 22, gu-IN 2, ug-CN 12, te-IN 36, hy-AM 66, no-NO 120, '
                'eo-UY 135, is-IS 146, pt-PT 162, hr-HR 167, sr-CS 171, ro-RO '
                '172, eu-ES 176, ca-ES 177, da-DK 177, '
                'hu-HU/in-ID/sv-SE/uk-UA 183 (they additionally translate the 5 '
                'stack-widget strings), and all remaining locales 178. '
                '(${entry.key})');
      }

      // The four at 183 are exactly the ones that translate the stack-widget
      // strings, which is why they sit above the 178 everyone else has.
      for (final String locale in <String>['hu', 'id', 'sv', 'uk']) {
        expect(
          messagesOf(arbs[locale]!),
          containsAll(<String>[
            'checkmarkStackWidget',
            'frequencyStackWidget',
            'historyStackWidget',
            'scoreStackWidget',
            'streaksStackWidget',
          ]),
          reason: 'platform-glue.localization-inventory#9: $locale translates '
              'the five stack-widget strings',
        );
      }

      for (final String locale in arbs.keys) {
        if (locale == 'en' || expected.containsKey(locale)) continue;
        expect(stringCountOf(locale), 178,
            reason: 'platform-glue.localization-inventory#9: all remaining '
                'locales 178 ($locale)');
      }
    });

    test('#10 plural coverage by locale is uneven', () {
      const Map<String, int> expected = <String, int>{
        'af': 0, 'eo': 0, 'gu': 0, 'hy': 0, 'no': 0, 'pt_PT': 0, 'te': 0,
        'ug': 0, 'ro': 1, 'is': 2, 'hr': 3, 'ca': 4,
      };

      for (final MapEntry<String, int> entry in expected.entries) {
        expect(pluralCountOf(entry.key), entry.value,
            reason: 'platform-glue.localization-inventory#10 — Plural coverage '
                'by locale is uneven: af-ZA, eo-UY, gu-IN, hy-AM, no-NO, '
                'pt-PT, te-IN and ug-CN define 0 plurals; ro-RO defines 1; '
                'is-IS 2; hr-HR 3; ca-ES 4; every other locale defines all 6. '
                '(${entry.key})');
      }

      for (final String locale in arbs.keys) {
        if (expected.containsKey(locale)) continue;
        expect(pluralCountOf(locale), 6,
            reason: 'platform-glue.localization-inventory#10: every other '
                'locale defines all 6 ($locale)');
      }
    });

    test('#12 an untranslated message falls back to the default value, per '
        'key', () {
      // Afrikaans translates 22 of 187 messages. The generated delegate is
      // still total: it answers every getter, with the template's value
      // wherever the ARB is silent. That is exactly what
      // tools:ignore="MissingTranslation" bought upstream — a build that does
      // not fail, and a runtime that falls back key by key rather than locale
      // by locale.
      final Map<String, Object?> af = arbs['af']!;
      final Set<String> translated = messagesOf(af);

      expect(translated.length, lessThan(messagesOf(template).length),
          reason: 'platform-glue.localization-inventory#12 — The default '
              'strings.xml root element carries tools:ignore='
              '"MissingTranslation", so missing translations do not fail the '
              'build; at runtime Android falls back to the default (English) '
              'value per key.');

      final L10n afL10n = lookupL10n(const Locale('af'));
      expect(afL10n.search, template['search'],
          reason: 'platform-glue.localization-inventory#12: `search` is '
              'untranslated everywhere, so Afrikaans answers with the English '
              'value');
      expect(translated.contains('search'), isFalse,
          reason: 'platform-glue.localization-inventory#12: and it really is '
              'absent from the Afrikaans ARB');
      expect(afL10n.overview, af['overview'],
          reason: 'platform-glue.localization-inventory#12: a key it does '
              'translate still answers in Afrikaans');
      expect(afL10n.overview, isNot(template['overview']),
          reason: 'platform-glue.localization-inventory#12: the fallback is '
              'per key, not per locale');
    });

    test('#13 the FontAwesome glyphs are constants, never messages', () {
      expect(FontAwesome.coreGlyphs, isNotEmpty,
          reason: 'platform-glue.localization-inventory#13 — '
              'res/values/fontawesome.xml holds 365 <string> resources, every '
              'one marked translatable="false" — they are FontAwesome glyph '
              'codepoints and must NOT be exported to ARB.');

      final Set<String> glyphs = <String>{
        ...FontAwesome.coreGlyphs.values,
        ...FontAwesome.androidGlyphs.values,
      };
      for (final Map<String, Object?> arb in arbs.values) {
        for (final String key in messagesOf(arb)) {
          expect(glyphs.contains('${arb[key]}'), isFalse,
              reason: 'platform-glue.localization-inventory#13: no message is a '
                  'glyph ($key)');
        }
      }
      // And no message id looks like one either.
      expect(
        messagesOf(template).where((String k) => k.startsWith('fa')),
        isEmpty,
        reason: 'platform-glue.localization-inventory#13: no fa_* key survived '
            'into the ARB',
      );
    });

    test('#14 the URLs and the feedback address are constants, never messages',
        () {
      final List<String> urls = <String>[
        SettingsScreen.helpUrl,
        SettingsScreen.rateAppUrl,
        AboutLinks.rateApp.toString(),
        AboutLinks.sendFeedback.toString(),
        AboutLinks.helpTranslate.toString(),
        AboutLinks.viewSourceCode.toString(),
        AboutLinks.privacyPolicy.toString(),
        AboutLinks.codeContributors.toString(),
      ];

      expect(urls, everyElement(isNotEmpty),
          reason: 'platform-glue.localization-inventory#14 — '
              'res/values/constants.xml holds 10 URL/email <string> resources '
              '(helpURL, playStoreURL, feedbackURL, privacyPolicyURL, '
              'codeContributorsURL, sourceCodeURL, translateURL, bugReportTo, '
              'bugReportSubject, syncBaseURL) plus 7 arrays. The port carries '
              'them as Dart constants on the two screens that open them, which '
              'is what the ledger note asks for; syncBaseURL has no consumer '
              'because sync is not ported, and bugReportTo/bugReportSubject '
              'belong to the bug-report path.');

      for (final String url in urls) {
        for (final MapEntry<String, Map<String, Object?>> arb in arbs.entries) {
          expect(messagesOf(arb.value).any((String k) => '${arb.value[k]}' == url),
              isFalse,
              reason: 'platform-glue.localization-inventory#14: $url is not a '
                  'message in ${arb.key}');
        }
      }
    });
  });

  // =======================================================================
  // platform-glue.locale-config
  // =======================================================================

  group('platform-glue.locale-config', () {
    /// The tags the delegate offers, in its own order.
    List<String> tags() => L10n.supportedLocales
        .map((Locale l) => <String?>[l.languageCode, l.scriptCode, l.countryCode]
            .whereType<String>()
            .join('_'))
        .toList();

    test('#1 supportedLocales is what replaced locales_config.xml', () {
      expect(L10n.supportedLocales, isNotEmpty,
          reason: 'platform-glue.locale-config#1 — '
              'android:localeConfig="@xml/locales_config" enables the Android '
              '13+ per-app language picker in system settings. A Flutter app '
              'has no per-locale resource tree for that file to point at: the '
              'catalogue is the ARB set and the picker is whatever '
              'MaterialApp.supportedLocales says, which is this list.');

      final File manifest = File(
        '${arbDir.parent.parent.path}/android/app/src/main/AndroidManifest.xml',
      );
      expect(manifest.readAsStringSync(), isNot(contains('localeConfig')),
          reason: 'platform-glue.locale-config#1: so the manifest declares '
              'none');
    });

    test('#2 the list starts at "en" and carries every locale that ships', () {
      expect(tags(), contains('en'),
          reason: 'platform-glue.locale-config#2 — locales_config.xml lists '
              'exactly 44 <locale> entries, starting with "en" (which has no '
              'values-en directory; it is the default resource set). Here "en" '
              'is the template ARB and the list is generated from the ARB set, '
              'so it cannot drift from what ships: 50 entries, not 44, because '
              'the four locales upstream forgot are included (rule 3) and the '
              'generic pt/zh fallbacks exist.');
      expect(tags(), hasLength(arbs.length),
          reason: 'platform-glue.locale-config#2: one entry per shipped '
              'locale, with nothing left over');
      expect(tags(), orderedEquals(<String>[...tags()]..sort()),
          reason: 'platform-glue.locale-config#2: and the list is ordered, the '
              'way the XML was');
    });

    test('#3 gu, is, ka and ml are selectable, unlike upstream', () {
      for (final String tag in <String>['gu', 'is', 'ka', 'ml']) {
        expect(tags(), contains(tag),
            reason: 'platform-glue.locale-config#3 — Four locales have '
                'translated resource directories but are MISSING from '
                'locales_config, so users cannot select them from the system '
                'per-app language picker even though the translations ship: '
                'gu-IN, is-IS, ka-GE, ml-IN. The ledger records this as a bug '
                'to fix rather than reproduce, and the port cannot reproduce it '
                'anyway: the delegate\'s list is generated from the ARB files, '
                'so a shipped translation is always selectable. ($tag)');
        expect(arbs.containsKey(tag), isTrue,
            reason: 'platform-glue.locale-config#3: and its ARB ships ($tag)');
      }
    });

    test('#4 Slovenian resolves, because there is no region to mismatch', () {
      expect(tags(), contains('sl'),
          reason: 'platform-glue.locale-config#4 — locales_config declares '
              '"sl-SL", but the resource directory is values-sl-rSI — the '
              'region subtag does not match, so the Slovenian entry in the '
              'picker does not resolve to the shipped Slovenian resources. The '
              'port files Slovenian under the bare language subtag, so there is '
              'no second spelling that could disagree with the first.');
      expect(tags().where((String t) => t.startsWith('sl')), <String>['sl'],
          reason: 'platform-glue.locale-config#4: exactly one Slovenian entry');
      expect(arbs['sl']!['@@locale'], 'sl',
          reason: 'platform-glue.locale-config#4: and the ARB agrees with it');
    });

    test('#5 the deprecated ISO codes are gone, because Dart does not use them',
        () {
      expect(tags(), containsAll(<String>['id', 'he']),
          reason: 'platform-glue.locale-config#5 — Deprecated ISO codes are '
              'used throughout and must be preserved for Android resource '
              'resolution: "in-ID" for Indonesian (not id-ID) and "iw-IL" for '
              'Hebrew (not he-IL). Nothing here resolves an Android resource '
              'qualifier: `Locale` and `intl` both canonicalise to the modern '
              'subtags, so preserving the old ones would be the way to lose '
              'the translation, not to keep it.');
      expect(tags(), isNot(contains('in')),
          reason: 'platform-glue.locale-config#5');
      expect(tags(), isNot(contains('iw')),
          reason: 'platform-glue.locale-config#5');
      expect(arbs['id']!['@@locale'], 'id',
          reason: 'platform-glue.locale-config#5');
      expect(arbs['he']!['@@locale'], 'he',
          reason: 'platform-glue.locale-config#5');
    });

    test('#6 both Serbian scripts, both Chinese scripts, both Portuguese '
        'variants', () {
      expect(tags(), containsAll(<String>['sr', 'sr_Latn']),
          reason: 'platform-glue.locale-config#6 — Both Serbian scripts ship '
              'separately: sr-CS (Latin) and sr-SP (Cyrillic); both Chinese '
              'scripts ship separately: zh-CN (Simplified) and zh-TW '
              '(Traditional); both Portuguese variants ship: pt-BR and pt-PT. '
              'The Serbian pair is spelled by script here rather than by the '
              'country Android used to stand in for one.');
      expect(tags(), containsAll(<String>['zh_CN', 'zh_TW']),
          reason: 'platform-glue.locale-config#6');
      expect(tags(), containsAll(<String>['pt_BR', 'pt_PT']),
          reason: 'platform-glue.locale-config#6');

      // Each pair really is two different translations, not one duplicated.
      for (final List<String> pair in <List<String>>[
        <String>['sr', 'sr_Latn'],
        <String>['zh_CN', 'zh_TW'],
        <String>['pt_BR', 'pt_PT'],
      ]) {
        expect(arbs[pair[0]], isNot(arbs[pair[1]]),
            reason: 'platform-glue.locale-config#6: ${pair[0]} and ${pair[1]} '
                'are separate translations, not one filed twice');
      }
      expect(arbs['zh_CN']!['mainActivityTitle'], '习惯',
          reason: 'platform-glue.locale-config#6: zh_CN is Simplified');
      expect(arbs['zh_TW']!['mainActivityTitle'], '習慣',
          reason: 'platform-glue.locale-config#6: zh_TW is Traditional');
      expect(arbs['sr']!['mainActivityTitle'], 'Навике',
          reason: 'platform-glue.locale-config#6: sr is the Cyrillic one');
      expect(arbs['sr_Latn']!['mainActivityTitle'], 'Navike',
          reason: 'platform-glue.locale-config#6: sr_Latn is the Latin one');
    });

    testWidgets('#7 the four RTL locales ship, and the app really mirrors for '
        'them', (WidgetTester tester) async {
      for (final String tag in <String>['ar', 'fa', 'he', 'ug']) {
        expect(tags(), contains(tag),
            reason: 'platform-glue.locale-config#7 — RTL support is enabled '
                'application-wide (android:supportsRtl="true") for ar-SA, '
                'fa-IR, iw-IL and ug-CN. Flutter has no opt-in: the '
                'localizations delegates resolve the text direction from the '
                'locale, so shipping the locale is what enables the mirroring. '
                '($tag)');
      }

      // Not a claim about a list of language codes — the app is actually built
      // in each locale and asked which way it lays out.
      Future<TextDirection> directionOf(String tag) async {
        late TextDirection observed;
        await tester.pumpWidget(WidgetsApp(
          locale: Locale(tag),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          color: const Color(0xFF000000),
          builder: (BuildContext context, Widget? child) {
            observed = Directionality.of(context);
            return const SizedBox.shrink();
          },
        ));
        await tester.pumpAndSettle();
        return observed;
      }

      for (final MapEntry<String, TextDirection> expected
          in <String, TextDirection>{
        'ar': TextDirection.rtl,
        'fa': TextDirection.rtl,
        'he': TextDirection.rtl,
        'en': TextDirection.ltr,
        'ru': TextDirection.ltr,
      }.entries) {
        expect(await directionOf(expected.key), expected.value,
            reason: 'platform-glue.locale-config#7: the app lays out '
                '${expected.key} ${expected.value.name}');
      }

      // KNOWN GAP, reported with this slice: Uyghur is written in a
      // Perso-Arabic script and Android mirrors it, but Flutter's own
      // `GlobalWidgetsLocalizations` does not list `ug` among the
      // right-to-left languages, so this app lays it out left-to-right. Three
      // of the rule's four locales hold; the fourth needs a
      // `LocalizationsDelegate<WidgetsLocalizations>` of our own in front of
      // the global one, which is implementation this slice does not add. The
      // current direction is deliberately NOT asserted here: pinning it would
      // turn the fix into a test failure.
      expect(arbs.containsKey('ug'), isTrue,
          reason: 'platform-glue.locale-config#7: the Uyghur translation does '
              'ship — what is missing is the mirroring, see the comment above');
    });

    test('#9 the locale list holds the names locales_config spells out', () {
      // Every entry of locales_config.xml the rule names, in the port's
      // spelling. `in-ID` and `iw-IL` move to `id`/`he`; see rule 5.
      const List<String> declared = <String>[
        'en', 'af', 'ar', 'bg', 'ca', 'cs', 'da', 'de', 'el', 'eo', 'es',
        'eu', 'fa', 'fi', 'fr', 'hi', 'hr', 'hu', 'hy', 'id', 'it', 'he',
        'ja', 'ko', 'nl', 'no', 'pl', 'pt_BR',
      ];

      expect(tags(), containsAll(declared),
          reason: 'platform-glue.locale-config#9 — res/xml/locales_config.xml '
              'declares the supported per-app locales, starting with "en" and '
              'including af-ZA, ar-SA, bg-BG, ca-ES, cs-CZ, da-DK, de-DE, '
              'el-GR, eo-UY, es-ES, eu-ES, fa-IR, fi-FI, fr-FR, hi-IN, hr-HR, '
              'hu-HU, hy-AM, in-ID, it-IT, iw-IL, ja-JP, ko-KR, nl-NL, no-NO, '
              'pl-PL, pt-BR and the remaining entries of that file.');

      // "and the remaining entries of that file" — every other locale that has
      // an ARB is offered too, which is the property the rule is really after.
      expect(tags().toSet(), arbs.keys.toSet(),
          reason: 'platform-glue.locale-config#9: and the remaining entries');
    });

    test('#10 no setting selects the language; the platform does', () {
      // `FilePreferencesStorage.xmlDefaults` is this port's `preferences.xml`:
      // the set of keys the settings screen declares and seeds on a fresh
      // install. A language row would have to leave a key in it.
      final Iterable<String> languageKeys =
          FilePreferencesStorage.xmlDefaults.keys.where((String key) =>
              key.contains('lang') ||
              key.contains('locale') ||
              key.contains('translat'));

      expect(languageKeys, isEmpty,
          reason: 'platform-glue.locale-config#10 — There is no in-app '
              'language-selection row in preferences.xml; language selection '
              'is delegated entirely to the Android 13+ per-app language '
              'system setting driven by this locale-config. The port keeps the '
              'delegation: nothing in the settings store names a language, and '
              'MaterialApp is built without a `locale:` argument, so the '
              'locale Flutter resolves from the platform against '
              'L10n.supportedLocales is the one that wins.');
      expect(
        messagesOf(template).where((String key) =>
            key.toLowerCase().contains('language') &&
            !'${template[key]}'.contains('Help translate')),
        isEmpty,
        reason: 'platform-glue.locale-config#10: and the catalogue has no '
            'message for such a row either',
      );
    });

    test('#11 the two Development strings are hard-coded English, everywhere '
        'else is a message', () {
      final Set<String> englishValues = <String>{
        for (final String key in messagesOf(template)) '${template[key]}',
      };

      for (final String literal in <String>[
        'Development',
        'Enable developer mode',
      ]) {
        expect(englishValues, isNot(contains(literal)),
            reason: 'platform-glue.locale-config#11 — All user-facing settings '
                'strings are localized resources except the Development '
                'category title "Development" and its row title "Enable '
                'developer mode", which are hard-coded English in '
                'preferences.xml. The port reproduces that exactly: both live '
                'as Dart string literals in lib/ui/settings/settings_screen.dart '
                'and neither has a message id, so they stay English in all 50 '
                'locales. This is a parity pin, not an endorsement — localizing '
                'them would be a deliberate deviation. ($literal)');
      }

      // The rest of the settings screen is localized, which is what makes the
      // exception an exception.
      expect(
        messagesOf(template),
        containsAll(<String>[
          'settings',
          'prefToggleTitle',
          'prefSkipTitle',
          'prefMidnightDelayTitle',
          'stickyNotifications',
          'usePureBlack',
          'widgetOpacityTitle',
          'reverseDays',
          'reminderSound',
        ]),
        reason: 'platform-glue.locale-config#11: every other settings string '
            'is a localized message',
      );
    });
  });

  // =======================================================================
  // platform-glue.localized-arrays
  // =======================================================================

  group('platform-glue.localized-arrays', () {
    test('#6 the hints array survives as exactly two ordered message ids', () {
      expect(
        <String>[
          for (final String key in <String>['hintDrag', 'hintLandscape'])
            '${template[key]}',
        ],
        <String>[
          'To rearrange the entries, press-and-hold on the name of the habit, '
              'then drag it to the correct place.',
          'You can see more days by putting your phone in landscape mode.',
        ],
        reason: 'platform-glue.localized-arrays#6 — string-array "hints" '
            'contains exactly 2 items, referencing @string/hint_drag and '
            '@string/hint_landscape. ARB has no array concept, so the array '
            'became these two message ids in this order; nothing else in the '
            'catalogue belongs to it.',
      );

      expect(
        messagesOf(template).where((String k) => k.startsWith('hint')).toSet(),
        <String>{'hintTitle', 'hintDrag', 'hintLandscape'},
        reason: 'platform-glue.localized-arrays#6: the two members plus the '
            'dialog title that introduces them — and no third member',
      );
    });
  });

  // =======================================================================
  // platform-glue.rtl-layout
  // =======================================================================

  group('platform-glue.rtl-layout', () {
    // The entry panel reads the process-global "today" while it builds, the
    // way every screen does after `AppScope.boot` has stamped it.
    setUp(() => core.setToday(core.LocalDate(9000)));
    tearDown(core.resetToday);

    /// An app in [tag] wrapping [child], with the real delegates installed so
    /// the text direction is resolved the way the shipping app resolves it.
    Future<void> pumpLocalized(
      WidgetTester tester,
      String tag,
      Widget child,
    ) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(tag),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: child,
      ));
      await tester.pumpAndSettle();
    }

    /// A row of two boxes; the returned pair is (x of `first`, x of `second`).
    Widget probeRow() => Row(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            SizedBox(key: ValueKey<String>('first'), width: 20, height: 20),
            SizedBox(key: ValueKey<String>('second'), width: 20, height: 20),
          ],
        );

    double xOf(WidgetTester tester, String key) =>
        tester.getCenter(find.byKey(ValueKey<String>(key))).dx;

    testWidgets('#1 an app in an RTL locale mirrors its layout, with no flag '
        'to set', (WidgetTester tester) async {
      await pumpLocalized(tester, 'en', probeRow());
      expect(xOf(tester, 'first'), lessThan(xOf(tester, 'second')),
          reason: 'platform-glue.rtl-layout#1: left to right in English');

      for (final String tag in <String>['ar', 'fa', 'he']) {
        await pumpLocalized(tester, tag, probeRow());
        expect(xOf(tester, 'first'), greaterThan(xOf(tester, 'second')),
            reason: 'platform-glue.rtl-layout#1 — AndroidManifest <application '
                'android:supportsRtl="true"> — every screen mirrors '
                'automatically under an RTL locale. Four of the 44 locales in '
                'locales_config.xml are RTL: ar-SA, fa-IR, iw-IL (Hebrew) and '
                'ug-CN. Flutter has no manifest flag to turn this on: the '
                'localization delegates resolve a text direction from the '
                'locale and every directional widget follows it, so the '
                'mirroring is on for every screen the moment the locale ships. '
                '($tag)');
      }

      // KNOWN GAP, the same one locale-config#7 records: Flutter's
      // GlobalWidgetsLocalizations does not count `ug` among the
      // right-to-left languages, so the fourth of the rule's four locales
      // lays out left-to-right here. The current direction is deliberately
      // not asserted — pinning it would turn the fix into a failure.
      expect(arbs.containsKey('ug'), isTrue,
          reason: 'platform-glue.rtl-layout#1: the Uyghur translation ships; '
              'what is missing is its mirroring');
    });

    testWidgets('#2 the direction is a property of the subtree, not of the '
        'locale', (WidgetTester tester) async {
      // An English app with an explicitly right-to-left subtree inside it.
      await pumpLocalized(
        tester,
        'en',
        Directionality(textDirection: TextDirection.rtl, child: probeRow()),
      );
      expect(xOf(tester, 'first'), greaterThan(xOf(tester, 'second')),
          reason: 'platform-glue.rtl-layout#2 — RTL is detected per view, not '
              'from the Locale: InterfaceUtils.isLayoutRtl(view) returns '
              'ViewCompat.getLayoutDirection(view) == '
              'ViewCompat.LAYOUT_DIRECTION_RTL, exposed as the extension '
              'View.isRTL(). `Directionality.of(context)` is the same thing: '
              'an inherited property of the subtree, which the locale merely '
              'seeds. A subtree may override it, and everything below follows '
              'the override rather than the locale.');

      // And the other way round: an Arabic app with a left-to-right subtree.
      await pumpLocalized(
        tester,
        'ar',
        Directionality(textDirection: TextDirection.ltr, child: probeRow()),
      );
      expect(xOf(tester, 'first'), lessThan(xOf(tester, 'second')),
          reason: 'platform-glue.rtl-layout#2: the override wins in both '
              'directions, so nothing reads the locale to decide');
    });

    test('#4 the custom-drawn strip mirrors about the checkmark band, not '
        'about the canvas', () {
      const int buttonCount = 5;
      final core.Theme theme = core.LightTheme();
      final double column = theme.checkmarkButtonSize;
      final double stripWidth = buttonCount * column;
      // Wider than the strip, the way the real header is: the habit names
      // occupy everything to the left of the band.
      const double canvasWidth = 400.0;

      final core.View header = HabitListHeader(
        core.LocalDate(9000),
        buttonCount,
        theme,
        IntlLocalDateFormatter(),
      );

      final RecordingCanvas plain = RecordingCanvas(canvasWidth, column);
      header.draw(plain);

      final RecordingCanvas mirrored = RecordingCanvas(canvasWidth, column);
      MirroredView(header, stripWidth: stripWidth).draw(mirrored);

      const String rule =
          'platform-glue.rtl-layout#4 — HeaderView\'s Drawer positions each '
          'date column from the right edge (canvas.width - dp(3)) and then, '
          'when isRTL(), mirrors the rect horizontally with rect.set('
          'canvas.width - rect.right, rect.top, canvas.width - rect.left, '
          'rect.bottom) — this manual mirror exists because the header is '
          'custom-drawn, whereas the entry buttons below it are a LinearLayout '
          '(ButtonPanelView) that Android mirrors automatically. The same '
          'split survives here, and for the same reason: a CoreView paints '
          'onto a Canvas that no Directionality reaches, so the strip carries '
          'its own mirror (MirroredView) while the entry row below it is a '
          'Row that Flutter mirrors for free.';

      expect(plain.textX, isNotEmpty, reason: rule);
      expect(mirrored.textX, hasLength(plain.textX.length), reason: rule);

      // Both the plain and the mirrored strip stay inside the right-aligned
      // band. Mirroring about the canvas instead — the literal
      // `canvas.width - x` of the Kotlin — would slide the dates left, over
      // the habit names.
      for (final double x in <double>[...plain.textX, ...mirrored.textX]) {
        expect(x, greaterThanOrEqualTo(canvasWidth - stripWidth - column),
            reason: '$rule The band starts at ${canvasWidth - stripWidth}.');
        expect(x, lessThanOrEqualTo(canvasWidth), reason: rule);
      }

      // It really is a reflection about the axis `2*width - stripWidth`: each
      // column lands exactly as far from one edge of the band as it stood
      // from the other.
      expect(mirrored.textX, isNot(orderedEquals(plain.textX)),
          reason: '$rule The mirror moved the columns.');
      for (int i = 0; i < plain.textX.length; i++) {
        expect(
          mirrored.textX[i],
          closeTo(2 * canvasWidth - stripWidth - plain.textX[i], 0.001),
          reason: '$rule Draw call \$i lands on its own reflection.',
        );
      }

      // The hairline and the background are NOT mirrored: they span the whole
      // header, and travelling with the strip would drag them off the canvas.
      expect(mirrored.lines, orderedEquals(plain.lines),
          reason: '$rule Only the per-column primitives move; the background '
              'and the bottom hairline span the whole width and stay put.');

      // KNOWN GAP, reported with this slice: the mirror above is driven by
      // `isCheckmarkSequenceReversed` only. `Directionality` never reaches a
      // Canvas, so under an RTL locale the strip keeps its left-to-right
      // column order while the entry rows underneath it — plain Rows — are
      // mirrored by the framework, and the dates stop lining up with the
      // buttons they label. Closing it means feeding the ambient direction
      // into `ListHeader` and composing it with the preference, exactly as
      // `updateScrollDirection` composes its three factors (rule 3). Neither
      // the current column order nor the current drag direction is asserted
      // here: pinning them would turn that fix into a failure.
    });

    testWidgets('#5 the reversed preference and the automatic mirror compose',
        (WidgetTester tester) async {
      final core.Theme theme = core.LightTheme();
      const int buttonCount = 3;

      /// The x of each entry button, today first, under [tag] and [reversed].
      Future<List<double>> columnsOf(String tag, {required bool reversed}) async {
        final core.Preferences preferences = core.Preferences(MemoryStorage());
        preferences.isCheckmarkSequenceReversed = reversed;
        await pumpLocalized(
          tester,
          tag,
          Center(
            child: EntryPanel(
              values: List<int>.filled(10, core.Entry.unknown),
              color: theme.color(11),
              theme: theme,
              preferences: preferences,
              buttonCount: buttonCount,
            ),
          ),
        );
        final core.LocalDate today = core.getToday();
        return <double>[
          for (int i = 0; i < buttonCount; i++)
            tester
                .getCenter(find.byKey(EntryPanel.buttonKey(today.minus(i))))
                .dx,
        ];
      }

      const String rule =
          'platform-glue.rtl-layout#5 — ButtonPanelView adds its buttons in '
          'reversed order when Preferences.isCheckmarkSequenceReversed; being '
          'a LinearLayout it is then mirrored again by the system in RTL, so '
          'the effective column order is the composition of both. A Row is the '
          'LinearLayout here and Flutter mirrors it for the same reason '
          'Android does, so both halves compose exactly as upstream: the '
          'preference reverses the children, the direction reverses the row, '
          'and the two together cancel.';

      // today is index 0 of the returned list; "leftmost" means its x is the
      // smallest of the three.
      List<double> columns = await columnsOf('en', reversed: false);
      expect(columns.first, lessThan(columns.last),
          reason: '$rule LTR, not reversed: today is leftmost.');

      columns = await columnsOf('en', reversed: true);
      expect(columns.first, greaterThan(columns.last),
          reason: '$rule LTR, reversed: the preference alone flips it.');

      columns = await columnsOf('ar', reversed: false);
      expect(columns.first, greaterThan(columns.last),
          reason: '$rule RTL, not reversed: the direction alone flips it, with '
              'no code of ours involved.');

      columns = await columnsOf('ar', reversed: true);
      expect(columns.first, lessThan(columns.last),
          reason: '$rule RTL and reversed: the two flips compose back to the '
              'left-to-right order, which is the composition the rule is about '
              'and the one a port is most likely to get wrong.');
    });
  });
}
