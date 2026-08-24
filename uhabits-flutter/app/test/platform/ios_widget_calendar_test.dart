/// The iOS widget extension must not do day arithmetic through the device's
/// civil calendar.
///
/// Every date in this port is a proleptic-Gregorian day number:
/// `org.isoron.platform.time.LocalDate` is integer arithmetic over
/// `daysSince2000`, and the bridge serialises it as a Gregorian ISO string.
/// The Android host reads it back through
/// `GregorianCalendar(TimeZone.getTimeZone("GMT"))` — explicitly pinned, for
/// exactly this reason.
///
/// `Calendar.current` is the user's Settings > General > Language & Region >
/// Calendar choice. On a device set to Buddhist — the default for the Thailand
/// region — `2026-08-24` is read back as BE 2026 = CE 1483, so the roll-forward
/// shifts every array roughly 198,000 days past its own end and every widget
/// goes permanently blank; a tap is stamped `2569-08-24`, which the queue
/// refuses as later than today and silently drops.
///
/// `audit17.ios-widgets-do-day-arithmetic-in-the-device-calendar#1`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String rule =
    'audit17.ios-widgets-do-day-arithmetic-in-the-device-calendar#1 — the wire '
    'format is a Gregorian day number, so the extension has to read and write '
    'it with a Gregorian calendar, not with whichever one the device is set '
    'to.';

void main() {
  test('no widget source reaches for Calendar.current', () {
    final Directory dir = Directory('ios/HabitsWidget');
    final List<File> sources = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(sources, isNotEmpty, reason: '$rule The sources have to be found.');

    final List<String> offenders = <String>[];
    for (final File source in sources) {
      final List<String> lines = source.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final String line = lines[i];
        // Prose about the defect is allowed; code is not.
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) {
          continue;
        }
        if (line.contains('Calendar.current')) {
          offenders.add('${source.uri.pathSegments.last}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: '$rule ${offenders.join(', ')} — use the pinned Gregorian '
            'calendar instead, the way the Android host pins '
            'GregorianCalendar(TimeZone.getTimeZone("GMT")).');
  });

  test('the pinned calendar is Gregorian and in UTC', () {
    final String source =
        File('ios/HabitsWidget/WidgetData.swift').readAsStringSync();
    expect(source, contains('Calendar(identifier: .gregorian)'),
        reason: '$rule The identifier has to be stated, not inherited.');
    expect(source, contains(RegExp(r'timeZone\s*=\s*TimeZone\(secondsFromGMT: 0\)')),
        reason: '$rule …and the zone too: the bridge writes the day the app '
            'computed, and a widget that re-derives it in local time can land '
            'on the day either side of it.');
  });

  test('date names still follow the device locale', () {
    // The pinning is about arithmetic, not about language: upstream builds
    // `JavaLocalDateFormatter(Locale.getDefault())`, so the weekday and month
    // words remain the device's.
    final String source =
        File('ios/HabitsWidget/DateNames.swift').readAsStringSync();
    expect(source, contains('Locale.current'),
        reason: '$rule Pinning the calendar must not translate the app into '
            'English.');
  });
}
