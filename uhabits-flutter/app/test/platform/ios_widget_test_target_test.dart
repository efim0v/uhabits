/// The iOS widget extension has to be executable by tests, not only readable.
///
/// For eighteen audit passes the extension was guarded by Dart tests that read
/// its Swift as text. Those can assert that a field is declared or that a
/// pattern is absent; they cannot see an off-by-one, a day computed in the
/// wrong zone, or an alpha applied to the wrong colour — and each of those
/// three reached the user. So the sources are compiled into the RunnerTests
/// bundle and the arithmetic is executed there.
///
/// This file pins the arrangement from the Dart side: `flutter test` cannot run
/// XCTest, but it can insist that the target, the cases and the runner still
/// exist. `audit18.the-widget-extension-must-be-executable-by-tests#1`, and the
/// local-day rule the executed cases cover,
/// `audit18.widget-today-must-be-the-local-day#1`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String targetRule =
    'audit18.the-widget-extension-must-be-executable-by-tests#1 — a guard that '
    'cannot fail on a logic error is not a guard.';

const String dayRule =
    'audit18.widget-today-must-be-the-local-day#1 — the day an instant belongs '
    "to is the LOCAL civil day: getLocalTime() adds the zone's offset and only "
    'then is the value floored.';

void main() {
  test('the widget sources are compiled into the test bundle', () {
    final String project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    // The Sources phase of the RunnerTests target.
    // The phase's own definition, not the reference to it in buildPhases.
    final int phase =
        project.indexOf('331C807D294A63A400263BE5 /* Sources */ = {');
    expect(phase, greaterThan(0), reason: targetRule);
    final String body =
        project.substring(phase, project.indexOf('};', phase));

    for (final String name in <String>[
      'WidgetData.swift',
      'CheckmarkWidget.swift',
      'StreakWidget.swift',
      'WidgetArithmeticTests.swift',
    ]) {
      expect(body, contains(name),
          reason: '$targetRule $name has to be in the bundle, or the cases '
              'that exercise it cannot compile.');
    }
  });

  test('the cases exist and the runner can run them', () {
    final File cases = File('ios/RunnerTests/WidgetArithmeticTests.swift');
    expect(cases.existsSync(), isTrue, reason: targetRule);
    final String source = cases.readAsStringSync();

    final int count = RegExp(r'\n    func test').allMatches(source).length;
    expect(count, greaterThanOrEqualTo(8),
        reason: '$targetRule The arithmetic that reached the user broken — the '
            "wire format's round trip, the roll-forward's shift, the day "
            'boundary, the card colour — is what these have to cover.');

    final File runner = File('../tool/swift_tests.sh');
    expect(runner.existsSync(), isTrue,
        reason: '$targetRule It needs a booted simulator, which is why it is '
            'its own script rather than part of close_features.sh.');
  });

  test('the day boundary is executed in a named time zone', () {
    final String source =
        File('ios/RunnerTests/WidgetArithmeticTests.swift').readAsStringSync();
    expect(source, contains('secondsFromGMT: -4 * 3600'),
        reason: '$dayRule West of GMT is where the defect showed: the card '
            'un-ticked in the evening and the tap was dropped.');
    expect(source, contains('secondsFromGMT: 9 * 3600'),
        reason: '$dayRule …and east of it the roll came late.');

    final String widget =
        File('ios/HabitsWidget/WidgetData.swift').readAsStringSync();
    expect(widget, contains('zone.secondsFromGMT(for: now)'),
        reason: "$dayRule The offset is added before the floor, which is what "
            'getLocalTime() does.');
  });
}
