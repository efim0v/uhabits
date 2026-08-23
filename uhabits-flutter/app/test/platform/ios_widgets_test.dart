/// `audit3.ios-ships-only-three-of-the`: which home-screen widgets the iOS
/// bundle offers.
///
/// ## Why a test reads files instead of running code
///
/// `app/ios/HabitsWidget/` is a WidgetKit extension. Its `WidgetBundle` is read
/// by the system when the user opens the widget gallery, in another process,
/// before any Dart exists; a `TimelineProvider` runs inside `chronod`. None of
/// that can execute under `flutter test`. So this file does for the iOS source
/// set exactly what test/platform/android_widgets_test.dart does for the
/// Android one and test/platform/ios_bundle_test.dart does for `ios/Runner`:
/// it extracts *values* from the files that ship — the bundle body, each
/// widget's `kind`, its gallery name, the intent it is configured by, and the
/// Xcode target that compiles it — and compares them against the side that
/// already says what the answer is.
///
/// Every expectation here is anchored on the other platform rather than on a
/// literal typed twice: the six `kind` strings come from
/// `HomeWidgetBridge.providerNames` (which is what the app reloads by name),
/// and the six gallery labels come from `android/app/src/main/res/values/
/// strings.xml` (which is what the launcher shows). The two platforms
/// therefore cannot drift apart without a failure here.
///
/// ## What this file deliberately does not claim
///
/// The rendering is out of reach — a `Canvas` inside a widget extension is
/// drawn by WidgetKit, and nothing in this repository can rasterise it. What
/// the charts draw is pinned on the Dart side, by the card tests of the habit
/// screen the Swift is a port of; what is pinned here is that the widget
/// exists, is installable, is fed the right habit and is built into the
/// product.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/home_widget_bridge.dart';

// ---------------------------------------------------------------------------
// Locating the source sets
// ---------------------------------------------------------------------------

final Directory appDir = _findApp();
final Directory widgetDir = Directory('${appDir.path}/ios/HabitsWidget');
final Directory androidRes =
    Directory('${appDir.path}/android/app/src/main/res');

Directory _findApp() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    for (final String prefix in <String>['', '/app']) {
      final Directory candidate = Directory('${dir.path}$prefix');
      if (File('${candidate.path}/ios/HabitsWidget/HabitsWidgetBundle.swift')
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

String swift(String name) =>
    File('${widgetDir.path}/$name').readAsStringSync();

String get pbxproj =>
    File('${appDir.path}/ios/Runner.xcodeproj/project.pbxproj')
        .readAsStringSync();

/// The English `Localizable.strings` table of the widget extension, which is
/// where the gallery names and descriptions live now.
Map<String, String> englishTable() => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;',
        multiLine: true,
      ).allMatches(
          File('${widgetDir.path}/en.lproj/Localizable.strings')
              .readAsStringSync()))
        m.group(1)!: m
            .group(2)!
            .replaceAllMapped(RegExp(r'\\(.)'), (Match e) => e.group(1)!),
    };

/// The English text of one key, or a failure naming the key — never a silent
/// null that turns into a passing test.
String english(String key) {
  final String? value = englishTable()[key];
  if (value == null) fail('en.lproj/Localizable.strings has no "$key"');
  return value;
}

/// The `<string name="...">value</string>` pairs of the Android resource file
/// whose values are the launcher labels of the same six widgets.
Map<String, String> androidStrings() => <String, String>{
      for (final RegExpMatch m in RegExp(
        r'<string\s+name="([^"]+)"\s*>(.*?)</string>',
        dotAll: true,
      ).allMatches(
          File('${androidRes.path}/values/strings.xml').readAsStringSync()))
        m.group(1)!: m.group(2)!,
    };

/// The first capture of [pattern] in [source], or a failure that names what
/// was being looked for — never a silent null that turns into a passing test.
String capture(String source, RegExp pattern, {required String what}) {
  final RegExpMatch? match = pattern.firstMatch(source);
  if (match == null) fail('$what: no match for ${pattern.pattern}');
  return match.group(1)!;
}

/// The text of one top-level Swift declaration: from its header line to the
/// start of the next top-level declaration, so that an assertion about one
/// struct cannot be satisfied by the contents of the next one.
String declaration(String source, String header) {
  final int start = source.indexOf(header);
  if (start < 0) fail('$header is not declared');
  final int next = source.indexOf(
    RegExp(r'^(struct|extension|enum|protocol|final class|class) ',
        multiLine: true),
    start + header.length,
  );
  return source.substring(start, next < 0 ? source.length : next);
}

// ---------------------------------------------------------------------------
// Reading the widget extension
// ---------------------------------------------------------------------------

/// The struct names listed in `HabitsWidgetBundle.body`, in order.
///
/// This is the list the system reads to populate the widget gallery: a
/// `Widget` that compiles but is not named here is a widget the user cannot
/// install.
List<String> bundleBody() {
  final String source = swift('HabitsWidgetBundle.swift');
  final int start = source.indexOf('var body: some Widget {');
  if (start < 0) fail('HabitsWidgetBundle has no `var body: some Widget`');
  final int end = source.indexOf('\n    }', start);
  final String body = source.substring(start, end);
  return RegExp(r'^\s*(\w+)\(\)\s*$', multiLine: true)
      .allMatches(body)
      .map((RegExpMatch m) => m.group(1)!)
      .toList();
}

/// One `Widget` struct, read out of the file named after it.
class IosWidget {
  IosWidget(this.structName) : source = swift('$structName.swift');

  final String structName;
  final String source;

  /// `static let kind = "…"` — the string `WidgetCenter.reloadTimelines`
  /// addresses, deliberately spelled like the Android provider class.
  String get kind => capture(source, RegExp(r'static let kind = "([^"]+)"'),
      what: '$structName.kind');

  /// The name shown in the widget gallery, the counterpart of `android:label`
  /// on the provider's receiver.
  ///
  /// It is a `LocalizedStringKey` rather than a literal since
  /// `audit4.ios-every-string-the-widget-surface#1` — the gallery has to read
  /// "Häkchen" on a German phone, the way the launcher does — so the name is
  /// resolved through the extension's own English table here. The comparison
  /// the tests below make is unchanged: the gallery name is still the Android
  /// label, it just travels through `en.lproj/Localizable.strings` on the way.
  /// The table itself, and its 46 translations, are asserted in
  /// test/platform/ios_widget_strings_test.dart.
  String get displayName => english(capture(
      source,
      RegExp(r'\.configurationDisplayName\(LocalizedStringKey\("([^"]*)"\)\)'),
      what: '$structName.configurationDisplayName'));

  /// The gallery's one-line explanation, likewise a key.
  String get description => english(capture(
      source, RegExp(r'\.description\(LocalizedStringKey\("([^"]*)"\)\)'),
      what: '$structName.description'));

  /// `intent: X.self` — the configuration the user edits, i.e. the iOS
  /// counterpart of the provider's configure activity.
  String get intent => capture(source, RegExp(r'intent: (\w+)\.self'),
      what: '$structName intent');

  /// The families of `.supportedFamilies([…])`, without their leading dot.
  List<String> get supportedFamilies =>
      capture(source, RegExp(r'\.supportedFamilies\(\[([^\]]*)\]\)'),
              what: '$structName.supportedFamilies')
          .split(',')
          .map((String s) => s.trim().replaceFirst('.', ''))
          .where((String s) => s.isNotEmpty)
          .toList();

  /// The expression `GraphWidgetView` is given as its title, for the five
  /// widgets built on the graph shell.
  String get graphTitle => capture(
      source, RegExp(r'GraphWidgetView\(title: ([^)]*)\)'),
      what: '$structName graph title');
}

/// The provider name each widget struct answers to, keyed by struct.
///
/// `HomeWidgetBridge.providerNames` is the order Android declares them in and
/// the order the bridge reloads them in; the struct that implements each one
/// is named after it minus the `Provider` suffix, which is the convention the
/// three widgets that already shipped follow.
String structFor(String providerName) =>
    providerName.replaceFirst('Provider', '');

/// The Android `strings.xml` key whose value is that widget's launcher label
/// (`widgets.registration#1`).
const Map<String, String> labelKeys = <String, String>{
  'CheckmarkWidgetProvider': 'checkmark',
  'HistoryWidgetProvider': 'history',
  'ScoreWidgetProvider': 'score',
  'StreakWidgetProvider': 'streaks',
  'FrequencyWidgetProvider': 'frequency',
  'TargetWidgetProvider': 'target',
};

// ---------------------------------------------------------------------------

void main() {
  const String rule =
      'audit3.ios-ships-only-three-of-the#1 — In the Kotlin app: Six widget '
      'providers are registered and user-installable, each with its own '
      'preview image and its own configure activity (BooleanHabitPickerDialog '
      'for Streaks, NumericalHabitPickerDialog for Target). A user can place a '
      'Streaks, Frequency or Target widget on the home screen.';

  group('audit3.ios-ships-only-three-of-the', () {
    test('#1 the bundle offers all six widgets, not three', () {
      final List<String> body = bundleBody();

      expect(
        body.length,
        HomeWidgetBridge.providerNames.length,
        reason: '$rule The WidgetBundle body is the whole gallery: '
            '${HomeWidgetBridge.providerNames.length} providers are '
            'installable on Android, so ${body.length} entries here means the '
            'missing ones cannot be placed on a home screen at all. Found: '
            '$body.',
      );

      expect(
        body.map((String struct) => IosWidget(struct).kind).toList(),
        HomeWidgetBridge.providerNames,
        reason: '$rule Each entry declares the `kind` the app reloads by name. '
            'HomeWidgetBridge.providerNames is the list the bridge pushes to '
            'WidgetCenter, and a reload for a kind no bundle declares is a '
            'no-op — which is exactly how the three missing widgets went '
            'unnoticed.',
      );
    });

    test('#1 each of the six is a file of its own, compiled into the '
        'extension', () {
      for (final String provider in HomeWidgetBridge.providerNames) {
        final String struct = structFor(provider);
        expect(File('${widgetDir.path}/$struct.swift').existsSync(), isTrue,
            reason: '$rule app/ios/HabitsWidget/$struct.swift is where the '
                '$provider widget lives.');

        // A Swift file that is not in the target's Sources build phase is a
        // file on disk that never ships: the struct simply does not exist in
        // the built extension, and the gallery entry disappears with it.
        expect(pbxproj, contains('$struct.swift in Sources'),
            reason: '$rule $struct.swift has to be in the '
                'HabitsWidgetExtension target\'s Sources build phase.');
        expect(pbxproj, contains('path = $struct.swift;'),
            reason: '$rule …and referenced by the project, or Xcode cannot '
                'find it.');
      }
    });

    test('#1 the gallery shows the same six names the launcher does', () {
      final Map<String, String> strings = androidStrings();

      for (final String provider in HomeWidgetBridge.providerNames) {
        final IosWidget widget = IosWidget(structFor(provider));
        final String label = strings[labelKeys[provider]]!;

        expect(widget.displayName, label,
            reason: '$rule The Android receiver for $provider is labelled '
                '"$label" (@string/${labelKeys[provider]}), which is the name '
                'the widget gallery shows; iOS spells the same thing '
                '`configurationDisplayName`.');
        expect(widget.description, isNotEmpty,
            reason: '$rule iOS shows a description under the name in the '
                'gallery, where Android shows the preview image '
                '(widgets.registration#5). Whichever it is, the entry has to '
                'say what the widget is.');
        expect(widget.supportedFamilies, containsAll(<String>['systemSmall']),
            reason: '$rule A widget declaring no family the user can pick is '
                'not installable, which is the state this rule is about.');
      }
    });

    test('#1 the Streaks widget can only be pointed at a yes-or-no habit', () {
      final IosWidget streak = IosWidget('StreakWidget');
      final String selection = swift('HabitSelection.swift');

      expect(streak.intent, isNot('SelectHabitIntent'),
          reason: '$rule Streaks is configured by BooleanHabitPickerDialog, '
              'not the unfiltered HabitPickerDialog (widgets.registration#6, '
              'widgets.streak#5), so its intent cannot be the one the '
              'unfiltered widgets use.');

      // The filtering itself: the query that feeds the picker drops every
      // numerical habit, the way `shouldHideNumerical()` does upstream.
      final String entity = capture(
          declaration(selection, 'struct ${streak.intent}'),
          RegExp(r'var habit: (\w+)\?'),
          what: '${streak.intent} habit parameter');
      final String queryBody = declaration(selection, 'struct ${entity}Query');
      expect(queryBody, contains('!\$0.isNumerical'),
          reason: '$rule widgets.streak#5 — The Streak widget\'s configure '
              'activity is BooleanHabitPickerDialog, so numerical habits can '
              'never be chosen for it. On iOS the picker is the entity query, '
              'so the query is where the filter has to be.');
    });

    test('#1 the Target widget can only be pointed at a measurable habit', () {
      final IosWidget target = IosWidget('TargetWidget');
      final String selection = swift('HabitSelection.swift');

      expect(target.intent, isNot('SelectHabitIntent'),
          reason: '$rule Target is configured by NumericalHabitPickerDialog '
              '(widgets.registration#6, widgets.target#8).');

      final String entity = capture(
          declaration(selection, 'struct ${target.intent}'),
          RegExp(r'var habit: (\w+)\?'),
          what: '${target.intent} habit parameter');
      final String queryBody = declaration(selection, 'struct ${entity}Query');
      expect(
        queryBody.contains('\$0.isNumerical'),
        isTrue,
        reason: '$rule widgets.target#8 — The Target widget\'s configure '
            'activity is NumericalHabitPickerDialog, so boolean habits can '
            'never be chosen for it.',
      );
      expect(queryBody.contains('!\$0.isNumerical'), isFalse,
          reason: '$rule …and the filter is the other way round from the '
              'Streak one.');
    });

    test('#1 the three new widgets are the graph shell, titled with the habit '
        'name', () {
      for (final String struct in <String>[
        'StreakWidget',
        'FrequencyWidget',
        'TargetWidget',
      ]) {
        final IosWidget widget = IosWidget(struct);
        expect(widget.graphTitle, 'habit.name',
            reason: '$rule widgets.streak#1/#2, widgets.frequency#1/#2, '
                'widgets.target#1/#2 — each of the three is a GraphWidgetView '
                'wrapping its chart, and the widget title is habit.name.');
        for (final String state in <String>['noHabits', 'deleted']) {
          expect(widget.source, contains('case .$state'),
              reason: '$rule A widget whose habit was deleted draws '
                  '"Habit deleted / not found" (widgets.error-states#1); one '
                  'with nothing published says so. The three that shipped '
                  'handle both, and a new widget that does not would render '
                  'an empty card instead.');
        }
      }
    });

    test('#1 nothing claims a kind twice, and every kind is reachable', () {
      final List<String> kinds = bundleBody()
          .map((String struct) => IosWidget(struct).kind)
          .toList();
      expect(kinds.toSet().length, kinds.length,
          reason: '$rule Two widgets sharing a kind would make the app\'s '
              'reload address both and the gallery show one.');
      expect(kinds.toSet(), HomeWidgetBridge.providerNames.toSet(),
          reason: '$rule widgets.updater#3: the bridge reloads exactly these '
              'six names.');
    });
  });
}
