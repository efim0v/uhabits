/// Entries in an exported archive must carry the export time.
///
/// `ZipWriter.addEntry` upstream is
/// `zos.putNextEntry(java.util.zip.ZipEntry(name))`, and `ZipOutputStream`
/// stamps an entry whose time was never set with `System.currentTimeMillis()`:
///
///   if (e.xdostime == -1) { e.setTime(System.currentTimeMillis()); }
///
/// so every CSV inside "Loop Habits CSV <date>.zip" is dated at the moment of
/// export. The port wrote literal zeros into both header fields, and a zero
/// MS-DOS date is month 0 / day 0, which extractors render as 1979-11-30 or
/// 1980-01-01 (`feedback.zip-entries-have-no-timestamp#1`).
library;

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:uhabits_core/src/io/zip.dart';

const String rule =
    'feedback.zip-entries-have-no-timestamp#1 — extracted files must be dated '
    'at the export, the way ZipOutputStream dates them.';

/// The little-endian 16-bit value at [offset].
int _uint16(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

void main() {
  test('the local header carries the export time in MS-DOS form', () async {
    final writer = ZipWriter(modifiedAt: DateTime(2026, 8, 24, 13, 46, 52));
    writer.addEntry('Habits.csv', 'Position,Name\n1,Meditate\n');
    final bytes = await writer.toBytes();

    // Local header: signature(4) version(2) flags(2) method(2) time(2) date(2)
    final time = _uint16(bytes, 10);
    final date = _uint16(bytes, 12);

    expect(date >> 9, 2026 - 1980, reason: '$rule year');
    expect((date >> 5) & 0xF, 8, reason: '$rule month');
    expect(date & 0x1F, 24, reason: '$rule day');
    expect(time >> 11, 13, reason: '$rule hour');
    expect((time >> 5) & 0x3F, 46, reason: '$rule minute');
    expect(time & 0x1F, 26,
        reason: '$rule MS-DOS stores seconds in units of two');
  });

  test('the central directory repeats it', () async {
    final writer = ZipWriter(modifiedAt: DateTime(2026, 8, 24, 13, 46, 52));
    writer.addEntry('Habits.csv', 'x');
    final bytes = await writer.toBytes();

    final localTime = _uint16(bytes, 10);
    final localDate = _uint16(bytes, 12);

    // Find the central header signature: 'P' 'K' 0x01 0x02.
    var i = 0;
    while (!(bytes[i] == 0x50 &&
        bytes[i + 1] == 0x4B &&
        bytes[i + 2] == 0x01 &&
        bytes[i + 3] == 0x02)) {
      i++;
    }
    // Central header: signature(4) madeBy(2) needed(2) flags(2) method(2)
    // time(2) date(2)
    expect(_uint16(bytes, i + 12), localTime,
        reason: '$rule The two copies have to agree, or extractors disagree '
            'about the date depending on which one they read.');
    expect(_uint16(bytes, i + 14), localDate, reason: rule);
  });

  test('a date before the MS-DOS epoch clamps instead of wrapping', () async {
    final writer = ZipWriter(modifiedAt: DateTime(1970, 1, 1));
    writer.addEntry('Habits.csv', 'x');
    final bytes = await writer.toBytes();
    final date = _uint16(bytes, 12);

    expect(date >> 9, 0, reason: '$rule 1980 is the earliest date the format '
        'can express; a negative year would wrap into a nonsense date.');
    expect((date >> 5) & 0xF, 1, reason: rule);
    expect(date & 0x1F, 1, reason: rule);
  });

  test('the archive still reads back', () async {
    final writer = ZipWriter(modifiedAt: DateTime(2026, 8, 24, 13, 46, 52));
    writer.addEntry('Habits.csv', 'Position,Name\n1,Meditate\n');
    final entries = await ZipReader(await writer.toBytes()).entries();
    expect(entries.single.content, 'Position,Name\n1,Meditate\n',
        reason: '$rule A stamped header must still be a valid header.');
  });
}
