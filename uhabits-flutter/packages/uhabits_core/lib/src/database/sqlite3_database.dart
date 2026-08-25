/// [Database] implemented over `package:sqlite3`.
///
/// The Kotlin equivalents are
/// `uhabits-core/src/jvmMain/java/org/isoron/platform/io/JavaDatabase.kt` and
/// `uhabits-android/src/main/java/org/isoron/uhabits/database/AndroidDatabase.kt`.
/// Neither of those drivers exposes raw `sqlite3_step`, so both emulate it with
/// a cursor; `package:sqlite3` does the same through
/// `PreparedStatement.iterateWith`, which is what this file builds on.
library;

import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'database.dart';

/// The driver's own error type, re-exported so that a caller can tell "this
/// file is not a readable database" from every other kind of failure without
/// taking a direct dependency on `package:sqlite3`.
///
/// It is the port's stand-in for `android.database.sqlite.SQLiteException` and
/// its `SQLiteDatabaseCorruptException` subclass, which are what the Android
/// framework raises for SQLITE_NOTADB and SQLITE_CORRUPT.
export 'package:sqlite3/sqlite3.dart' show SqliteException;

/// The path that opens a private, temporary, in-memory database.
const String inMemoryPath = ':memory:';

/// A [PreparedStatement] backed by a `package:sqlite3` statement.
///
/// Bindings are buffered in [_bindings] (a list of exactly `parameterCount`
/// slots) and applied when the statement is next stepped, because the driver
/// binds and steps in one call. An unbound slot is SQL NULL, matching sqlite.
class Sqlite3PreparedStatement implements PreparedStatement {
  Sqlite3PreparedStatement(sqlite.PreparedStatement stmt)
      : _stmt = stmt,
        _bindings = List<Object?>.filled(stmt.parameterCount, null);

  final sqlite.PreparedStatement _stmt;
  final List<Object?> _bindings;
  sqlite.IteratingCursor? _cursor;
  bool _finalized = false;

  @override
  StepResult step() {
    _ensureNotFinalized();
    final cursor =
        _cursor ??= _stmt.iterateWith(sqlite.StatementParameters(_bindings));
    return cursor.moveNext() ? StepResult.row : StepResult.done;
  }

  @override
  int getInt(int index) => _toInt(_rawValue(index));

  @override
  int getLong(int index) => _toInt(_rawValue(index));

  @override
  double getReal(int index) => _toReal(_rawValue(index));

  @override
  String getText(int index) => _toText(_rawValue(index), index);

  @override
  int? getIntOrNull(int index) {
    final value = _rawValue(index);
    return value == null ? null : _toInt(value);
  }

  @override
  int? getLongOrNull(int index) {
    final value = _rawValue(index);
    return value == null ? null : _toInt(value);
  }

  @override
  double? getRealOrNull(int index) {
    final value = _rawValue(index);
    return value == null ? null : _toReal(value);
  }

  @override
  String? getTextOrNull(int index) {
    final value = _rawValue(index);
    return value == null ? null : _toText(value, index);
  }

  @override
  void bindInt(int index, int value) => _bind(index, value);

  @override
  void bindLong(int index, int value) => _bind(index, value);

  @override
  void bindReal(int index, double value) => _bind(index, value);

  @override
  void bindText(int index, String value) => _bind(index, value);

  @override
  void bindNull(int index) => _bind(index, null);

  @override
  void reset() {
    _ensureNotFinalized();
    _cursor = null;
    _stmt.reset();
    for (var i = 0; i < _bindings.length; i++) {
      _bindings[i] = null;
    }
  }

  @override
  void finalizeStatement() {
    if (_finalized) return;
    _finalized = true;
    _cursor = null;
    _stmt.dispose();
  }

  void _bind(int index, Object? value) {
    _ensureNotFinalized();
    if (index < 1 || index > _bindings.length) {
      throw RangeError.range(index, 1, _bindings.length, 'index',
          'Statement has ${_bindings.length} parameter(s): ${_stmt.sql}');
    }
    _bindings[index - 1] = value;
  }

  void _ensureNotFinalized() {
    if (_finalized) {
      throw StateError('Tried to operate on a finalized prepared statement');
    }
  }

  Object? _rawValue(int index) {
    _ensureNotFinalized();
    final cursor = _cursor;
    if (cursor == null) {
      throw StateError('No current row: step() must return StepResult.row '
          'before reading column $index');
    }
    return cursor.current.columnAt(index);
  }

  /// Mirrors the coercion the JDBC and Android drivers apply: a NULL column
  /// reads as 0, and a textual or real column is converted.
  static int _toInt(Object? value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
    }
    return 0;
  }

  static double _toReal(Object? value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is BigInt) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Kotlin's `getText` is declared non-null but returns the driver's platform
  /// type, so a NULL column throws an NPE there. This throws too; callers that
  /// tolerate NULL use [getTextOrNull].
  static String _toText(Object? value, int index) {
    if (value == null) {
      throw StateError('Column $index is NULL; use getTextOrNull instead');
    }
    if (value is String) return value;
    return value.toString();
  }
}

/// A [Database] backed by a `package:sqlite3` connection.
class Sqlite3Database implements Database {
  Sqlite3Database(this._db);

  /// A fresh, private in-memory database.
  factory Sqlite3Database.memory() =>
      Sqlite3Database(sqlite.sqlite3.openInMemory());

  final sqlite.Database _db;

  /// The underlying driver handle, for code that needs driver-specific APIs.
  sqlite.Database get raw => _db;

  @override
  PreparedStatement prepareStatement(String sql) =>
      Sqlite3PreparedStatement(_db.prepare(sql));

  @override
  void close() => _db.dispose();
}

/// Opens database files read-write, without creating them.
///
/// The Kotlin counterpart is `AndroidDatabaseOpener`, which calls
/// `SQLiteDatabase.openDatabase(path, null, OPEN_READWRITE)`: an imported file
/// must be writable, since migrations are applied to it in place, and a missing
/// file is an error rather than a fresh database.
class Sqlite3DatabaseOpener implements DatabaseOpener {
  const Sqlite3DatabaseOpener();

  /// The schema version at which migration 22 turned foreign keys on.

  @override
  Database open(String path) {
    final database = path == inMemoryPath
        ? Sqlite3Database.memory()
        : Sqlite3Database(
            sqlite.sqlite3.open(path, mode: sqlite.OpenMode.readWrite),
          );

    applyConnectionSettings(database);
    return database;
  }
}

/// The first schema version whose data satisfies the foreign keys.
const int _foreignKeysEnabledSince = 22;

/// Applies the per-connection settings a Loop database needs.
///
/// `pragma foreign_keys` is per-connection and defaults to OFF, so the one
/// inside 22.sql only covers the connection that ran the upgrade. Every later
/// connection has to set it again — see `persistence.migration-v22#6`.
///
/// It is deliberately NOT set on databases older than 22: those still hold the
/// orphaned rows that migration 22 exists to delete, and enforcing constraints
/// before that cleanup would make the upgrade fail.
///
/// Lives here, apart from the opener, because tests build databases without
/// going through it and a connection that quietly skipped this would enforce
/// nothing — including the cascades the sleep tables rely on.
void applyConnectionSettings(Database database) {
  if (database.getVersion() >= _foreignKeysEnabledSince) {
    database.run('pragma foreign_keys=ON');
  }
}
