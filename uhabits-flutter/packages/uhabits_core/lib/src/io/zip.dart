/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Zip.kt and of its
/// JVM actual in uhabits-core/src/jvmMain/java/org/isoron/platform/io/Zip.kt,
/// which wraps `java.util.zip.ZipOutputStream` / `ZipInputStream`. The JS
/// actual wraps JSZip with type `uint8array` and compression `DEFLATE`, and
/// skips entries whose `dir` flag is true when reading — this port does the
/// same.
///
/// The core cannot take a third-party archive dependency, so the ZIP container
/// is written and parsed here, byte by byte, over the raw deflate codec that
/// `dart:io` already exposes (`ZLibCodec(raw: true)` is exactly the stream
/// format ZIP compression method 8 wants). Only the subset the CSV export
/// needs is implemented: no Zip64, no encryption, no data descriptors, no
/// archive comment.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ZipEntry {
  ZipEntry(this.name, this.content);

  final String name;
  final String content;

  @override
  String toString() => 'ZipEntry($name)';
}

/// Reads a ZIP archive held entirely in memory.
class ZipReader {
  ZipReader(this.bytes);

  final Uint8List bytes;

  /// The entries of the archive, in stored order, with their bytes decoded as
  /// UTF-8. Directory entries are skipped.
  Future<List<ZipEntry>> entries() async {
    final result = <ZipEntry>[];
    final data = ByteData.sublistView(bytes);
    final eocd = _findEndOfCentralDirectory(data);
    final count = data.getUint16(eocd + 10, Endian.little);
    var offset = data.getUint32(eocd + 16, Endian.little);

    for (var i = 0; i < count; i++) {
      if (data.getUint32(offset, Endian.little) != _centralHeaderSignature) {
        throw const FormatException('Corrupt ZIP: bad central directory header');
      }
      final method = data.getUint16(offset + 10, Endian.little);
      final compressedSize = data.getUint32(offset + 20, Endian.little);
      final uncompressedSize = data.getUint32(offset + 24, Endian.little);
      final nameLength = data.getUint16(offset + 28, Endian.little);
      final extraLength = data.getUint16(offset + 30, Endian.little);
      final commentLength = data.getUint16(offset + 32, Endian.little);
      final externalAttributes = data.getUint32(offset + 38, Endian.little);
      final localOffset = data.getUint32(offset + 42, Endian.little);
      final name = _decodeUtf8(
          bytes.sublist(offset + 46, offset + 46 + nameLength));
      offset += 46 + nameLength + extraLength + commentLength;

      // JSZip marks an entry as `dir` when its name ends with '/' or the
      // MS-DOS directory attribute is set.
      final isDirectory =
          name.endsWith('/') || (externalAttributes & 0x10) != 0;
      if (isDirectory) continue;

      final content = _readEntryData(
        data: data,
        localOffset: localOffset,
        method: method,
        compressedSize: compressedSize,
        uncompressedSize: uncompressedSize,
      );
      result.add(ZipEntry(name, _decodeUtf8(content)));
    }
    return result;
  }

  Uint8List _readEntryData({
    required ByteData data,
    required int localOffset,
    required int method,
    required int compressedSize,
    required int uncompressedSize,
  }) {
    if (data.getUint32(localOffset, Endian.little) != _localHeaderSignature) {
      throw const FormatException('Corrupt ZIP: bad local file header');
    }
    final nameLength = data.getUint16(localOffset + 26, Endian.little);
    final extraLength = data.getUint16(localOffset + 28, Endian.little);
    final start = localOffset + 30 + nameLength + extraLength;
    final raw = bytes.sublist(start, start + compressedSize);
    if (uncompressedSize == 0) return Uint8List(0);
    switch (method) {
      case _methodStored:
        return raw;
      case _methodDeflated:
        return Uint8List.fromList(_deflate.decode(raw));
      default:
        throw FormatException('Unsupported ZIP compression method: $method');
    }
  }

  int _findEndOfCentralDirectory(ByteData data) {
    if (bytes.length < 22) {
      throw const FormatException('Not a ZIP archive: too short');
    }
    // The record is 22 bytes plus a comment of at most 64KB.
    final lowest = bytes.length - 22 - 0xFFFF;
    for (var i = bytes.length - 22; i >= 0 && i >= lowest; i--) {
      if (data.getUint32(i, Endian.little) == _endOfCentralDirectorySignature) {
        return i;
      }
    }
    throw const FormatException(
        'Not a ZIP archive: end of central directory not found');
  }
}

/// Writes a ZIP archive in memory. Created empty; every [addEntry] appends one
/// deflated entry; [toBytes] closes the archive and returns its bytes.
class ZipWriter {
  /// [modifiedAt] is the time every entry is stamped with, defaulting to now.
  ///
  /// `ZipOutputStream.putNextEntry` stamps an entry whose time was never set —
  /// which is every entry `ZipWriter.addEntry` creates upstream — with
  /// `System.currentTimeMillis()`, so the files inside an export carry the
  /// moment of export (`feedback.zip-entries-have-no-timestamp#1`). It is a
  /// parameter only so that a test can pin it.
  ZipWriter({DateTime? modifiedAt})
      : _modifiedAt = modifiedAt ?? DateTime.now();

  final DateTime _modifiedAt;

  final List<_PendingEntry> _entries = <_PendingEntry>[];
  Uint8List? _bytes;
  bool _closed = false;

  /// Appends one deflated entry whose bytes are the UTF-8 encoding of
  /// [content]. [name] may contain '/' to express folders; no separate
  /// directory entries are created.
  void addEntry(String name, String content) {
    if (_closed) {
      // `ZipOutputStream.putNextEntry` after `close()` throws IOException.
      throw StateError('ZipWriter is closed');
    }
    final uncompressed = utf8.encode(content);
    _entries.add(_PendingEntry(
      nameBytes: utf8.encode(name),
      compressed: Uint8List.fromList(_deflate.encode(uncompressed)),
      uncompressedSize: uncompressed.length,
      crc: _crc32(uncompressed),
    ));
  }

  /// Closes the stream and returns the complete archive bytes.
  Future<Uint8List> toBytes() async {
    _closed = true;
    return _bytes ??= _build();
  }

  Uint8List _build() {
    final out = BytesBuilder(copy: true);
    final offsets = <int>[];
    for (final entry in _entries) {
      offsets.add(out.length);
      _writeLocalHeader(out, entry);
      out.add(entry.compressed);
    }
    final centralStart = out.length;
    for (var i = 0; i < _entries.length; i++) {
      _writeCentralHeader(out, _entries[i], offsets[i]);
    }
    final centralSize = out.length - centralStart;
    _writeEndOfCentralDirectory(out, _entries.length, centralSize, centralStart);
    return out.takeBytes();
  }

  /// [_modifiedAt] as an MS-DOS packed time: hour, minute, and seconds in
  /// units of two.
  int get _dosTime =>
      (_modifiedAt.hour << 11) |
      (_modifiedAt.minute << 5) |
      (_modifiedAt.second ~/ 2);

  /// [_modifiedAt] as an MS-DOS packed date, whose epoch is 1980. A date the
  /// format cannot express is clamped to its ends rather than wrapped, which
  /// is what `ZipEntry.setTime` does with `javaToDosTime`.
  int get _dosDate {
    final year = _modifiedAt.year.clamp(1980, 2107);
    if (year != _modifiedAt.year) {
      return year == 1980 ? (0 << 9) | (1 << 5) | 1 : (127 << 9) | (12 << 5) | 31;
    }
    return ((year - 1980) << 9) | (_modifiedAt.month << 5) | _modifiedAt.day;
  }

  void _writeLocalHeader(BytesBuilder out, _PendingEntry entry) {
    _writeUint32(out, _localHeaderSignature);
    _writeUint16(out, 20); // version needed to extract
    _writeUint16(out, _flagUtf8Names);
    _writeUint16(out, _methodDeflated);
    _writeUint16(out, _dosTime);
    _writeUint16(out, _dosDate);
    _writeUint32(out, entry.crc);
    _writeUint32(out, entry.compressed.length);
    _writeUint32(out, entry.uncompressedSize);
    _writeUint16(out, entry.nameBytes.length);
    _writeUint16(out, 0); // extra field length
    out.add(entry.nameBytes);
  }

  void _writeCentralHeader(
      BytesBuilder out, _PendingEntry entry, int localOffset) {
    _writeUint32(out, _centralHeaderSignature);
    _writeUint16(out, 20); // version made by
    _writeUint16(out, 20); // version needed to extract
    _writeUint16(out, _flagUtf8Names);
    _writeUint16(out, _methodDeflated);
    _writeUint16(out, _dosTime);
    _writeUint16(out, _dosDate);
    _writeUint32(out, entry.crc);
    _writeUint32(out, entry.compressed.length);
    _writeUint32(out, entry.uncompressedSize);
    _writeUint16(out, entry.nameBytes.length);
    _writeUint16(out, 0); // extra field length
    _writeUint16(out, 0); // file comment length
    _writeUint16(out, 0); // disk number start
    _writeUint16(out, 0); // internal file attributes
    _writeUint32(out, 0); // external file attributes
    _writeUint32(out, localOffset);
    out.add(entry.nameBytes);
  }

  void _writeEndOfCentralDirectory(
      BytesBuilder out, int count, int centralSize, int centralOffset) {
    _writeUint32(out, _endOfCentralDirectorySignature);
    _writeUint16(out, 0); // number of this disk
    _writeUint16(out, 0); // disk with the central directory
    _writeUint16(out, count);
    _writeUint16(out, count);
    _writeUint32(out, centralSize);
    _writeUint32(out, centralOffset);
    _writeUint16(out, 0); // archive comment length
  }
}

class _PendingEntry {
  _PendingEntry({
    required this.nameBytes,
    required this.compressed,
    required this.uncompressedSize,
    required this.crc,
  });

  final List<int> nameBytes;
  final Uint8List compressed;
  final int uncompressedSize;
  final int crc;
}

const int _localHeaderSignature = 0x04034b50;
const int _centralHeaderSignature = 0x02014b50;
const int _endOfCentralDirectorySignature = 0x06054b50;
const int _methodStored = 0;
const int _methodDeflated = 8;

/// General purpose bit 11: the name and comment are UTF-8 encoded.
const int _flagUtf8Names = 0x0800;

/// Raw deflate: no zlib header or trailer, which is what ZIP method 8 stores.
final ZLibCodec _deflate = ZLibCodec(raw: true);

/// `decodeToString()` in Kotlin replaces malformed input rather than throwing.
String _decodeUtf8(List<int> bytes) =>
    const Utf8Decoder(allowMalformed: true).convert(bytes);

void _writeUint16(BytesBuilder out, int value) {
  out.addByte(value & 0xFF);
  out.addByte((value >> 8) & 0xFF);
}

void _writeUint32(BytesBuilder out, int value) {
  out.addByte(value & 0xFF);
  out.addByte((value >> 8) & 0xFF);
  out.addByte((value >> 16) & 0xFF);
  out.addByte((value >> 24) & 0xFF);
}

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
