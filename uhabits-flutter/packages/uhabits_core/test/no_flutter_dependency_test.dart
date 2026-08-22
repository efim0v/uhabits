import 'dart:io';

import 'package:test/test.dart';

/// The core package must stay pure Dart: its tests run under `dart test` in
/// seconds without an emulator, and the same code is meant to run later in a
/// background sync isolate and in a parity-checking CLI.
void main() {
  test('no library imports Flutter', () {
    final offenders = <String>[];
    final lib = Directory('lib');
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.readAsStringSync().contains('package:flutter/')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'uhabits_core must not depend on Flutter');
  });

  test('pubspec declares no Flutter dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('flutter:'), isFalse,
        reason: 'a Flutter dependency would drag the SDK into core tests');
  });
}
