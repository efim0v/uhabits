/// `audit.android-widget-chrome-text-is-hard`: the text a home-screen widget
/// shows when it cannot draw a habit.
///
/// Upstream every one of those labels is a translatable Android string resource
/// — `habit_not_found` and the five `*_stack_widget` empty-state labels — so a
/// widget in the launcher's process picks the device language up from the
/// resource table, with no app process involved. The port had them as Kotlin
/// `const val`s and inline `android:text` literals, which no translation can
/// reach.
///
/// **The mechanism chosen, and why.** The widget process cannot read the
/// Flutter ARB files, so the strings have to arrive another way. There were two
/// candidates: Android string resources mirrored from the ARB, or the published
/// data contract (`WidgetData`'s per-widget JSON document). Resources win on
/// three counts:
///
///  1. Two of the three error labels are drawn precisely when there is no
///     document to read — `WidgetNotConfiguredException` *is* "no document",
///     and `UnknownSchemaException` is "a document this build cannot parse". A
///     string that travels inside the document is unavailable in the only case
///     it is needed.
///  2. The five stack labels are `android:text` on a `TextView` inside a
///     `RemoteViews` layout. That attribute takes a resource reference or a
///     literal and nothing else; there is no code path that could substitute a
///     runtime string into an empty view the launcher inflates.
///  3. Android already resolves the right translation itself, including the
///     Android 13 per-app language override, before any code runs — and this
///     project already mirrors ARB into `values*/strings.xml` for the launcher
///     label, under the contract in test/platform/launcher_icon_test.dart. This
///     is the same mirror, widened by six strings.
///
/// So the assertions below are the two halves of that contract: the Kotlin and
/// the layouts name resources rather than literals, and every `values*` mirror
/// agrees with the ARB it was generated from.
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

String widgetKotlin(String name) => File(
      '${androidMain.path}/kotlin/org/isoron/uhabits/widgets/$name',
    ).readAsStringSync();

/// [source] with its comments stripped, so an assertion about what the code
/// does cannot be satisfied — or defeated — by prose that merely names the
/// thing. Same helper, same reason, as android_widgets_test.dart.
String withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// The `<string name="...">value</string>` pairs of a strings file, with
/// Android's backslash escapes undone.
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

/// The `values*` directory an ARB tag maps to — the same mapping
/// test/platform/launcher_icon_test.dart uses, because it is the same mirror.
String qualifierFor(String tag) {
  if (tag == 'en') return 'values';
  final List<String> parts = tag.split('_');
  final String lang =
      <String, String>{'id': 'in', 'he': 'iw'}[parts.first] ?? parts.first;
  if (parts.length == 1) return 'values-$lang';
  if (parts[1].length == 4) return 'values-b+$lang+${parts[1]}';
  return 'values-$lang-r${parts[1].toUpperCase()}';
}

/// The ARB key each mirrored Android resource name comes from.
const Map<String, String> mirrored = <String, String>{
  'habit_not_found': 'habitNotFound',
  'checkmark_stack_widget': 'checkmarkStackWidget',
  'frequency_stack_widget': 'frequencyStackWidget',
  'score_stack_widget': 'scoreStackWidget',
  'history_stack_widget': 'historyStackWidget',
  'streaks_stack_widget': 'streaksStackWidget',
};

/// The stack layout each `StackWidgetType` inflates, keyed by the type.
const Map<String, String> stackLayouts = <String, String>{
  'CHECKMARK': 'checkmark_stackview_widget',
  'FREQUENCY': 'frequency_stackview_widget',
  'SCORE': 'score_stackview_widget',
  'HISTORY': 'history_stackview_widget',
  'STREAKS': 'streak_stackview_widget',
  'TARGET': 'target_stackview_widget',
};

/// The `android:text` of the single `TextView` in a stack layout.
String? layoutText(String layout) => RegExp(r'android:text="([^"]*)"')
    .firstMatch(res('layout/$layout.xml'))
    ?.group(1);

const String rule1 =
    'audit.android-widget-chrome-text-is-hard#1 — In the Kotlin app: '
    '`habit_not_found` is a normal translatable resource and is translated in '
    '41 of the 47 locale directories (e.g. values-ru-rRU "Привычка удалена / '
    'не найдена", values-de-rDE "Gewohnheit gelöscht / nicht gefunden"), so a '
    'widget whose habit was deleted shows the message in the device language. '
    'The five stack-widget empty-state labels are likewise translated in '
    'values-da-rDK, values-hu-rHU, values-in-rID, values-sv-rSE and '
    'values-uk-rUA.';

const String rule2 =
    'audit.android-widget-chrome-text-is-hard#2 — The port must do the same. '
    'Today it does this instead: BaseWidgetProvider.kt hard-codes `const val '
    'HABIT_NOT_FOUND = "Habit deleted / not found"`, and '
    'res/layout/*_stackview_widget.xml inline android:text="Checkmark Stack '
    'Widget" etc. (with a comment claiming "this project has no strings.xml" — '
    'it does). The port also adds two more English-only widget strings of its '
    'own, NOT_CONFIGURED and UPDATE_REQUIRED, plus HabitPickerDialog.PROMPT. '
    'Result: every non-English user sees English text on the home screen '
    'wherever a widget cannot render a habit.';

void main() {
  group('audit.android-widget-chrome-text-is-hard', () {
    // -------------------------------------------------------------------
    // The Kotlin side: no literals left
    // -------------------------------------------------------------------

    test('#2 the error widget labels are string resources, not const vals', () {
      final String provider = withoutComments(widgetKotlin('BaseWidgetProvider.kt'));

      expect(
        provider,
        isNot(contains('"Habit deleted / not found"')),
        reason: '$rule2 The literal is what makes the label untranslatable.',
      );
      expect(
        provider,
        isNot(contains('"Open Loop Habit Tracker to set up this widget"')),
        reason: rule2,
      );
      expect(
        provider,
        isNot(contains('"Update Loop Habit Tracker to show this widget"')),
        reason: rule2,
      );

      // …and each exception picks a resource id instead.
      expect(
        provider,
        contains('is HabitNotFoundException -> R.string.habit_not_found'),
        reason: '$rule1 $rule2',
      );
      expect(
        provider,
        contains(
            'is WidgetNotConfiguredException -> R.string.widget_not_configured'),
        reason: rule2,
      );
      expect(
        provider,
        contains('is UnknownSchemaException -> R.string.widget_update_required'),
        reason: rule2,
      );
      // The id is resolved against the widget's own Context, which is what
      // makes the launcher's locale — and the Android 13 per-app language —
      // decide the text.
      expect(
        provider,
        contains('context.getString(label)'),
        reason: '$rule1 $rule2 A resource id only becomes the device language '
            'when something resolves it against a Context.',
      );
    });

    test('#2 the picker prompt is a string resource too', () {
      final String dialog = withoutComments(
        File('${androidMain.path}/kotlin/org/isoron/uhabits/widgets/'
                'activities/HabitPickerDialog.kt')
            .readAsStringSync(),
      );

      expect(
        dialog,
        isNot(contains('"Choose a habit in Loop Habit Tracker…"')),
        reason: rule2,
      );
      expect(
        dialog,
        contains('getString(R.string.widget_picker_prompt)'),
        reason: '$rule2 HabitPickerDialog.PROMPT is one of the port\'s own '
            'English-only widget strings; it becomes a resource with the rest.',
      );
    });

    // -------------------------------------------------------------------
    // The layouts: no literals left either
    // -------------------------------------------------------------------

    test('#1 #2 every stack layout names a resource, target bug included', () {
      expect(
        <String, String?>{
          for (final MapEntry<String, String> e in stackLayouts.entries)
            e.key: layoutText(e.value),
        },
        <String, String>{
          'CHECKMARK': '@string/checkmark_stack_widget',
          'FREQUENCY': '@string/frequency_stack_widget',
          'SCORE': '@string/score_stack_widget',
          'HISTORY': '@string/history_stack_widget',
          'STREAKS': '@string/streaks_stack_widget',
          // Upstream's target layout points at R.string.streaks_stack_widget.
          // Reproduced, not corrected — and now reproduced through the same
          // resource, so the bug is translated too.
          'TARGET': '@string/streaks_stack_widget',
        },
        reason: '$rule1 $rule2',
      );
    });

    // -------------------------------------------------------------------
    // The resources exist, and say what upstream says
    // -------------------------------------------------------------------

    test('#1 #2 the English resources carry upstream\'s exact wording', () {
      final Map<String, String> defaults = androidStrings('values/strings.xml');

      expect(
        <String, String?>{
          for (final String name in mirrored.keys) name: defaults[name],
        },
        <String, String>{
          'habit_not_found': 'Habit deleted / not found',
          'checkmark_stack_widget': 'Checkmark Stack Widget',
          'frequency_stack_widget': 'Frequency Stack Widget',
          'score_stack_widget': 'Score Stack Widget',
          'history_stack_widget': 'History Stack Widget',
          'streaks_stack_widget': 'Streaks Stack Widget',
        },
        reason: '$rule1 $rule2 The six names and the six values are upstream\'s '
            'res/values/strings.xml, unchanged.',
      );

      // The three the port adds have no upstream counterpart and no ARB entry,
      // so English is all there is — but they are resources, so a translator
      // can reach them and the widget process resolves them the same way.
      expect(
        <String, String?>{
          'widget_not_configured': defaults['widget_not_configured'],
          'widget_update_required': defaults['widget_update_required'],
          'widget_picker_prompt': defaults['widget_picker_prompt'],
        },
        <String, String>{
          'widget_not_configured':
              'Open Loop Habit Tracker to set up this widget',
          'widget_update_required':
              'Update Loop Habit Tracker to show this widget',
          'widget_picker_prompt': 'Choose a habit in Loop Habit Tracker…',
        },
        reason: rule2,
      );

      // The English resource and the ARB are one value, exactly as the launcher
      // label already is.
      final Map<String, Object?> en = arb('en');
      for (final MapEntry<String, String> e in mirrored.entries) {
        expect(defaults[e.key], en[e.value],
            reason: '$rule2 values/strings.xml disagrees with app_en.arb for '
                '${e.key}.');
      }
    });

    test('#1 habit_not_found is mirrored into every locale the ARB has it in',
        () {
      int localized = 0;
      for (final String tag in arbTags()) {
        final Object? value = arb(tag)['habitNotFound'];
        if (value == null) continue;
        localized++;
        final String dir = qualifierFor(tag);
        expect(hasRes('$dir/strings.xml'), isTrue,
            reason: '$rule1 Missing $dir/strings.xml for ARB "$tag".');
        expect(androidStrings('$dir/strings.xml')['habit_not_found'], value,
            reason: '$rule1 $dir disagrees with app_$tag.arb.');
      }
      expect(localized, greaterThan(40),
          reason: '$rule1 "translated in 41 of the 47 locale directories" is '
              'the whole translated set, not a sample.');

      // The two the rule names, in both scripts, so the assertion is not
      // vacuous for locales whose translation happens to equal English.
      expect(androidStrings('values-ru/strings.xml')['habit_not_found'],
          'Привычка удалена / не найдена', reason: rule1);
      expect(androidStrings('values-de/strings.xml')['habit_not_found'],
          'Gewohnheit gelöscht / nicht gefunden', reason: rule1);
    });

    test('#1 the five stack labels are mirrored wherever upstream has them',
        () {
      // Upstream translates them in exactly five locale directories; the ARB
      // carries the same five (values-in-rID is ARB "id", values-uk-rUA "uk").
      const List<String> tags = <String>['da', 'hu', 'id', 'sv', 'uk'];
      for (final String tag in tags) {
        final Map<String, Object?> messages = arb(tag);
        final String dir = qualifierFor(tag);
        final Map<String, String> strings = androidStrings('$dir/strings.xml');
        for (final MapEntry<String, String> e in mirrored.entries) {
          if (e.key == 'habit_not_found') continue;
          expect(messages[e.value], isNotNull,
              reason: '$rule1 app_$tag.arb should translate ${e.value}.');
          expect(strings[e.key], messages[e.value],
              reason: '$rule1 $dir disagrees with app_$tag.arb for ${e.key}.');
        }
      }

      // A spot check that is not English, so the mirror is proved to carry a
      // translation rather than a copy of the template.
      expect(androidStrings('values-sv/strings.xml')['checkmark_stack_widget'],
          'Stapelwidget med kryssruta', reason: rule1);
      expect(androidStrings('values-da/strings.xml')['streaks_stack_widget'],
          'Uafbrudt række stakkontrol', reason: rule1);

      // …and nowhere else: a locale the ARB does not translate them in must not
      // grow an invented translation.
      expect(androidStrings('values-de/strings.xml')['checkmark_stack_widget'],
          isNull,
          reason: '$rule1 Only the five directories upstream translates carry '
              'the stack labels; the rest fall back to values/.');
    });
  });
}
