import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the guard.
///
/// Three audits found 48 defects of one shape: a class implemented, tested and
/// never wired. They survived because every widget test here builds its own
/// subject and hands it its collaborators, so the wiring itself is never
/// exercised. The journeys next to this file exist to close that hole — and
/// they only do so while they keep starting where the application starts.
///
/// This test fails if a journey drifts back into assembling its own screens,
/// or if the shared launcher stops being `main()`.
void main() {
  final directory = Directory('test/journeys');
  final journeys = directory
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_journey_test.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// Drops the lines that only talk about code: doc comments, ordinary
  /// comments, and the `reason:` strings that name these very classes.
  String codeOf(File file) => file
      .readAsLinesSync()
      .where((line) {
        final trimmed = line.trimLeft();
        // A `reason:` often runs over several lines; its continuations start
        // with the opening quote of the next fragment.
        return !trimmed.startsWith('//') &&
            !trimmed.startsWith("'") &&
            !trimmed.startsWith('"') &&
            !line.contains('reason:');
      })
      .join('\n');

  test('journeys exist', () {
    expect(journeys, isNotEmpty,
        reason: 'verify.integration-harness#2 — the port needs tests that '
            'start from the application entry point');
  });

  test('the shared launcher is main(), verbatim', () {
    // Every journey delegates its launch to this one place, so this is where
    // "starts at the entry point" is actually enforced.
    final harness = codeOf(File('${directory.path}/journey.dart'));
    expect(harness, contains('AppScope.boot()'),
        reason: 'verify.integration-harness#2 — the launcher must boot the '
            'application the way main() does, not assemble a scope itself');
    expect(harness, contains('UhabitsApp(scope:'),
        reason: 'verify.integration-harness#2 — the launcher must pump the '
            'real application widget, so an unreachable capability fails the '
            'journey that needs it');
  });

  for (final journey in journeys) {
    final name = journey.uri.pathSegments.last;
    final code = codeOf(journey);

    test('$name launches through the shared harness', () {
      expect(code, contains("import 'journey.dart';"),
          reason: 'verify.integration-harness#2 — a journey that launches the '
              'app its own way can quietly stop launching it the way main() '
              'does');
    });

    test('$name supplies no screen of its own', () {
      // Constructing a screen means handing it its collaborators, which is
      // exactly the blindness these journeys exist to remove.
      const forbidden = <String>[
        'HabitListScreen(',
        'ShowHabitScreen(',
        'EditHabitScreen(',
        'SettingsScreen(',
        'AboutScreen(',
        'IntroScreen(',
      ];
      final built = forbidden.where(code.contains).toList();
      expect(built, isEmpty,
          reason: 'verify.integration-harness#2 — $name constructs $built '
              'instead of reaching it through the app; a screen built by the '
              'test proves nothing about whether a user can get to it');
    });
  }
}
