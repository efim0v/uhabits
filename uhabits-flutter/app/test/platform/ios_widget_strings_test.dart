/// `audit4.ios-every-string-the-widget-surface`: the text an iOS home-screen
/// widget shows.
///
/// Android names its six widgets with `android:label="@string/checkmark"` and
/// friends, and draws a deleted habit's card with `R.string.habit_not_found`;
/// all seven are ordinary string resources, translated in 44 locale
/// directories, and the launcher resolves them in its own process before any
/// code runs. The iOS extension had the same seven strings as English Swift
/// literals — `.configurationDisplayName("Checkmark")`,
/// `WidgetPlaceholder.habitNotFound = "Habit deleted / not found"` — which no
/// translation can reach. A German user with a German phone got a German app,
/// a German launcher label, and a widget gallery reading "Checkmark, History,
/// Score…".
///
/// ## The mechanism, and why this one
///
/// The strings are `.lproj/Localizable.strings` tables inside the widget
/// extension, keyed and mirrored from the ARB catalogue — the same mirror that
/// already produces `res/values*/strings.xml` for the Android widgets
/// (test/platform/widget_strings_test.dart) and `Runner/*.lproj/
/// InfoPlist.strings` for the launcher label (test/platform/ios_bundle_test.
/// dart). Two candidates were rejected for the same reason they were rejected
/// on Android: the published document cannot carry them, because the widget
/// gallery is read before the app has ever run and the "no habit" card is
/// drawn precisely when there is no document; and the app's own bundle is not
/// reachable from an extension's `Bundle.main`.
///
/// A missing key in a `.strings` table does not fall back to English — the
/// user is shown the key — so every generated table carries every key, with
/// the English text wherever the ARB has no translation.
///
/// ## What is asserted
///
/// That the Swift names keys rather than sentences, that a table exists for
/// every locale the ARB translates, that its values are the ARB's, that the
/// English table says what Android says, and that the tables are actually
/// compiled into the extension — a `.strings` file that is not in the target's
/// Resources build phase is a file on disk that never ships.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Locating the source sets
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory widgetDir = Directory('${appDir.path}/ios/HabitsWidget');
final Directory arbDir = Directory('${appDir.path}/lib/l10n');
final Directory androidRes =
    Directory('${appDir.path}/android/app/src/main/res');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/ios/HabitsWidget/WidgetCard.swift')
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

String swift(String name) => File('${widgetDir.path}/$name').readAsStringSync();

String get pbxproj =>
    File('${appDir.path}/ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();

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

/// The `.lproj` directory name for an ARB tag: Apple's identifiers are
/// hyphenated, the ARB file names are not. Same mapping as
/// test/platform/ios_bundle_test.dart.
String lproj(String tag) => tag.replaceAll('_', '-');

/// The `"key" = "value";` pairs of a `.strings` file.
Map<String, String> stringsTable(String tag) => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
        multiLine: true,
      ).allMatches(
          File('${widgetDir.path}/${lproj(tag)}.lproj/Localizable.strings')
              .readAsStringSync()))
        m.group(1)!: m
            .group(2)!
            .replaceAllMapped(RegExp(r'\\(.)'), (Match e) => e.group(1)!),
    };

bool hasTable(String tag) =>
    File('${widgetDir.path}/${lproj(tag)}.lproj/Localizable.strings')
        .existsSync();

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

// ---------------------------------------------------------------------------
// The seven strings the widget surface shows, and where each comes from
// ---------------------------------------------------------------------------

/// The `.strings` key of each widget's gallery name, and the ARB key it is
/// mirrored from. The Android resource has the ARB key's own name.
const Map<String, String> widgetNameKeys = <String, String>{
  'CheckmarkWidget': 'checkmark',
  'HistoryWidget': 'history',
  'ScoreWidget': 'score',
  'StreakWidget': 'streaks',
  'FrequencyWidget': 'frequency',
  'TargetWidget': 'target',
};

/// Every key a table has to carry, mapped to the ARB key it is translated
/// from — or null when there is no translation anywhere and English is all
/// there is, exactly like `widget_not_configured` on Android.
const Map<String, String?> tableKeys = <String, String?>{
  'widget_name_checkmark': 'checkmark',
  'widget_name_history': 'history',
  'widget_name_score': 'score',
  'widget_name_streaks': 'streaks',
  'widget_name_frequency': 'frequency',
  'widget_name_target': 'target',
  'habit_not_found': 'habitNotFound',
  'widget_description_checkmark': null,
  'widget_description_history': null,
  'widget_description_score': null,
  'widget_description_streaks': null,
  'widget_description_frequency': null,
  'widget_description_target': null,
  'widget_not_configured': null,
  'widget_error_drawing': null,
  // The Target card's five row labels. Upstream they are
  // `R.string.today`/`week`/`month`/`quarter`/`year`, resolved by
  // `TargetCardView.intervalToLabel(resources, interval)`; the iOS widget had
  // them as Swift literals until
  // `audit5.target-widget-s-interval-labels-are#1`. They keep Android's own
  // resource names, so the two mirrors of one ARB entry are spelled alike.
  'today': 'today',
  'week': 'week',
  'month': 'month',
  'quarter': 'quarter',
  'year': 'year',
};

const String rule =
    'audit4.ios-every-string-the-widget-surface#1 — In the Kotlin app: The '
    'widget gallery lists localized names ("Häkchen, Verlauf, Wertung…" in '
    'German) and a deleted habit\'s card reads the localized `habit_not_found`; '
    'both follow the Android 13 per-app language setting.';

void main() {
  group('audit4.ios-every-string-the-widget-surface', () {
    test('#1 the gallery entries name keys, not English sentences', () {
      for (final MapEntry<String, String> entry in widgetNameKeys.entries) {
        final String source = swift('${entry.key}.swift');

        expect(
          source,
          contains(
              '.configurationDisplayName(LocalizedStringKey("widget_name_'
              '${entry.value}"))'),
          reason: '$rule ${entry.key} spelled its gallery name as an English '
              'Swift literal, which no translation can reach. The Android '
              'receiver names @string/${entry.value} instead.',
        );
        expect(
          source,
          contains('.description(LocalizedStringKey("widget_description_'
              '${entry.value}"))'),
          reason: '$rule The one-line gallery description is the other half '
              'of the entry the user reads.',
        );
      }
    });

    test('#1 the error cards are keys too', () {
      final String card = swift('WidgetCard.swift');

      expect(card, contains('LocalizedStringKey("habit_not_found")'),
          reason: '$rule `habit_not_found` is translated in 44 locale '
              'directories on Android; on iOS it was the literal "Habit '
              'deleted / not found".');
      expect(card, contains('LocalizedStringKey("widget_not_configured")'),
          reason: '$rule The "open Loop Habit Tracker to set up this widget" '
              'card is the one an unconfigured widget shows, and it is a '
              'resource on Android.');
      expect(card, contains('LocalizedStringKey("widget_error_drawing")'),
          reason: '$rule …and so is the catch-all error card.');

      for (final String literal in <String>[
        '"Habit deleted / not found"',
        '"Error drawing widget"',
        '"Open Loop Habit Tracker to set up this widget"',
      ]) {
        expect(card, isNot(contains(literal)),
            reason: '$rule A literal left behind is a string no locale can '
                'override.');
      }

      expect(card, contains('let message: LocalizedStringKey'),
          reason: '$rule The label view has to take the key, or the lookup '
              'never happens: `Text(String)` renders the text verbatim while '
              '`Text(LocalizedStringKey)` resolves it against the bundle.');
    });

    test('#1 every locale the ARB translates ships a table', () {
      int translated = 0;
      for (final String tag in arbTags()) {
        final Map<String, Object?> messages = arb(tag);
        final bool any = tableKeys.values
            .whereType<String>()
            .any((String key) => messages[key] != null);
        if (!any) {
          // Nothing to say in this language; iOS falls back to en.lproj, the
          // way a values-gu with no widget strings falls back to values/.
          continue;
        }
        translated++;
        expect(hasTable(tag), isTrue,
            reason: '$rule app_$tag.arb translates the widget surface but '
                'ios/HabitsWidget/${lproj(tag)}.lproj/Localizable.strings does '
                'not exist, so that language shows English on the home screen.');

        final Map<String, String> table = stringsTable(tag);
        expect(table.keys.toSet(), tableKeys.keys.toSet(),
            reason: '$rule A key missing from a `.strings` table does not fall '
                'back to English — iOS shows the key itself — so every table '
                'carries every key.');
        for (final MapEntry<String, String?> key in tableKeys.entries) {
          final Object? translation =
              key.value == null ? null : messages[key.value];
          if (translation == null) continue;
          expect(table[key.key], translation,
              reason: '$rule ${lproj(tag)}.lproj disagrees with app_$tag.arb '
                  'for ${key.key}.');
        }
      }
      expect(translated, greaterThan(40),
          reason: '$rule "the 43 translations Android now has" is the whole '
              'set, not a sample.');
    });

    test('#1 the English table is the text Android shows', () {
      final Map<String, String> table = stringsTable('en');
      final Map<String, String> android =
          androidStrings('values/strings.xml');

      for (final MapEntry<String, String> entry in widgetNameKeys.entries) {
        expect(table['widget_name_${entry.value}'], android[entry.value],
            reason: '$rule The gallery name and the launcher label are one '
                'string; ${entry.key} must not drift from '
                '@string/${entry.value}.');
      }
      expect(table['habit_not_found'], android['habit_not_found'],
          reason: rule);
      expect(table['widget_not_configured'], android['widget_not_configured'],
          reason: rule);
      for (final String key in tableKeys.keys) {
        expect(table[key], isNotEmpty, reason: '$rule $key has no English '
            'text, so every locale that falls back to it shows nothing.');
      }
    });

    test('#1 a translation really is a translation', () {
      // Two spot checks in two scripts, so the mirror is proved to carry
      // translations rather than copies of the template.
      expect(stringsTable('de')['widget_name_checkmark'], 'Häkchen',
          reason: '$rule The rule names this one: "Häkchen, Verlauf, '
              'Wertung…".');
      expect(stringsTable('de')['widget_name_history'], 'Verlauf',
          reason: rule);
      expect(stringsTable('de')['widget_name_score'], 'Wertung', reason: rule);
      expect(stringsTable('ru')['habit_not_found'],
          'Привычка удалена / не найдена', reason: rule);
    });

    test('#1 the tables are compiled into the widget extension', () {
      final String project = pbxproj;

      // The variant group, and one file reference per locale.
      expect(project, contains('/* Localizable.strings */'),
          reason: '$rule A `.strings` file the project does not reference is a '
              'file Xcode never copies.');
      for (final String tag in arbTags().where(hasTable)) {
        expect(project, contains('path = ${lproj(tag)}.lproj/Localizable.strings'),
            reason: '$rule ${lproj(tag)}.lproj is on disk but not in the '
                'project, so that language never reaches the device.');
      }

      // …and the group is in the extension's own Resources phase. Anything
      // else — the app target's phase, say — puts the table in the wrong
      // bundle, where the extension cannot see it.
      final RegExpMatch? target = RegExp(
        r'/\* HabitsWidgetExtension \*/ = \{[\s\S]*?buildPhases = \(([\s\S]*?)\);',
      ).firstMatch(project);
      expect(target, isNotNull, reason: '$rule no HabitsWidgetExtension target');
      final String phaseId = RegExp(r'(\w{24}) /\* Resources \*/')
          .firstMatch(target!.group(1)!)!
          .group(1)!;
      final String phase = RegExp(
        '$phaseId /\\* Resources \\*/ = \\{[\\s\\S]*?files = \\(([\\s\\S]*?)\\);',
      ).firstMatch(project)!.group(1)!;
      expect(phase, contains('Localizable.strings in Resources'),
          reason: '$rule The extension\'s Resources build phase is what puts '
              'the tables inside HabitsWidgetExtension.appex.');
    });
  });
}
