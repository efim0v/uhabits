/// Every field the index document publishes has to reach the iOS extension.
///
/// The index is the only document a WidgetKit widget ever opens: an iOS widget
/// has no widget id, so it resolves its habit out of the index's `habits`
/// catalogue. A field that lives only on the per-widget-id document is
/// therefore invisible on iOS — and that asymmetry has now produced three
/// separate defects: `audit5.checkmark-home-screen-widget-never-draws`,
/// `audit15.ios-home-screen-widgets-never-roll` and
/// `audit16.widget-opacity-never-reaches-ios`. Each time, the Dart side
/// published something correct and the Swift side never declared it, and
/// nothing in the suite compared the two.
///
/// This test compares them. It is deliberately structural rather than a list
/// of known fields: a field added to the index tomorrow either shows up in the
/// Swift or shows up here.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String rule =
    'audit16.index-fields-must-reach-the-extension#1 — the index document is '
    'the whole contract between the app and the WidgetKit extension, so a '
    'field it carries that the Swift never reads is a preference the user can '
    'set and the widget cannot honour.';

/// Fields that are genuinely Android-only, with the reason. Anything else the
/// index publishes must appear in the Swift.
const Map<String, String> androidOnlyFields = <String, String>{
  // The Android provider maps a widget id to its document; iOS resolves the
  // habit out of `habits` instead, so the binding table means nothing to it.
  'widgets': 'the widget-id binding table, which iOS has no widget id for',
  // The provider class names AppWidgetManager dispatches on.
  'providers': 'the AppWidgetProvider class names',
};

void main() {
  test('every published index field is declared by the Swift', () {
    final String dart =
        File('lib/platform/home_widget_bridge.dart').readAsStringSync();
    final int start = dart.indexOf('Map<String, Object?> buildIndexDocument(');
    expect(start, greaterThan(0), reason: '$rule The builder has to be found.');
    // The map literal ends at the first `};` after the opening brace.
    final int end = dart.indexOf('\n    };', start);
    expect(end, greaterThan(start), reason: rule);
    final String body = dart.substring(start, end);

    // Top-level keys of the returned map: `'name':` at exactly six spaces of
    // indentation, which is the map's own level.
    final Set<String> published = RegExp(r"\n      '([A-Za-z]+)':")
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toSet();
    expect(published.length, greaterThan(5),
        reason: '$rule If this stops matching, the test is measuring nothing.');

    final String swift =
        File('ios/HabitsWidget/WidgetData.swift').readAsStringSync();

    final List<String> unreachable = <String>[];
    for (final String field in published) {
      if (androidOnlyFields.containsKey(field)) continue;
      // The Swift decodes the index with named properties, so the field's name
      // has to appear as one.
      if (!swift.contains(RegExp('let $field\\s*:'))) unreachable.add(field);
    }

    expect(unreachable, isEmpty,
        reason: '$rule ${unreachable.join(', ')} reach the launcher on Android '
            'and stop at the boundary on iOS. Either declare the field in '
            'WidgetIndex and use it, or — if it really is Android-only — say '
            'so in androidOnlyFields with the reason, so the next reader can '
            'tell a decision from an oversight.');
  });

  test('the Android-only list stays honest', () {
    final String dart =
        File('lib/platform/home_widget_bridge.dart').readAsStringSync();
    for (final MapEntry<String, String> entry in androidOnlyFields.entries) {
      expect(dart, contains("'${entry.key}':"),
          reason: '$rule ${entry.key} is excused here but no longer published '
              'at all; an exemption for a field that does not exist hides the '
              'next one that does.');
    }
  });
}
