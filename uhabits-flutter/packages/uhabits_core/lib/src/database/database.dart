/// Database and PreparedStatement abstraction.
///
/// Ported line by line from
/// `uhabits-core/src/commonMain/kotlin/org/isoron/platform/io/Database.kt`.
///
/// Naming note: Kotlin's `PreparedStatement.finalize()` is called
/// [PreparedStatement.finalizeStatement] here, because `finalize` collides with
/// Dart/VM finalization conventions and reads as a lifecycle hook rather than
/// an explicit release.
library;

import 'sql_parser.dart';

/// Result of stepping a [PreparedStatement].
///
/// Kotlin: `enum class StepResult { ROW, DONE }`.
enum StepResult { row, done }

/// A compiled SQL statement.
///
/// Column getters are 0-indexed (`getInt(0)` reads the first selected column);
/// bind parameters are 1-indexed (`bindInt(1, v)` binds the first `?`).
abstract class PreparedStatement {
  /// Advances the statement one row.
  ///
  /// Returns [StepResult.row] while rows remain and [StepResult.done]
  /// afterwards. A statement that produces no rows executes and returns
  /// [StepResult.done].
  StepResult step();

  int getInt(int index);

  int getLong(int index);

  double getReal(int index);

  String getText(int index);

  int? getIntOrNull(int index);

  int? getLongOrNull(int index);

  double? getRealOrNull(int index);

  String? getTextOrNull(int index);

  void bindInt(int index, int value);

  void bindLong(int index, int value);

  void bindReal(int index, double value);

  void bindText(int index, String value);

  void bindNull(int index);

  /// Rewinds the statement and clears all bindings, so it can be re-bound and
  /// re-stepped.
  void reset();

  /// Releases the statement and any open cursor.
  ///
  /// Kotlin name: `finalize()`.
  void finalizeStatement();
}

/// A SQL database connection.
///
/// Deliberately exposes nothing but [prepareStatement] and [close]; every query
/// helper is an extension (see [DatabaseExtensions]), exactly as in Kotlin.
abstract class Database {
  PreparedStatement prepareStatement(String sql);

  void close();
}

/// Opens a [Database] stored at a given path.
abstract class DatabaseOpener {
  Database open(String path);
}

/// Signature of the callback that supplies the SQL script for one migration.
typedef MigrationSqlLoader = String Function(int version);

/// Signature of the function that splits a SQL script into single statements.
typedef SqlScriptParser = List<String> Function(String script);

/// The Kotlin extension functions on `Database`.
///
/// Kotlin's `vararg params: String` becomes an explicit `List<String> params`
/// positional argument; pass `const []` when the statement has no parameters.
extension DatabaseExtensions on Database {
  /// Prepares [sql], applies [bind] if given, steps exactly ONCE, then
  /// finalizes. It does not drain multi-row results.
  void run(String sql, [void Function(PreparedStatement stmt)? bind]) {
    final stmt = prepareStatement(sql);
    if (bind != null) bind(stmt);
    stmt.step();
    stmt.finalizeStatement();
  }

  int queryInt(String sql) {
    final stmt = prepareStatement(sql);
    stmt.step();
    final value = stmt.getInt(0);
    stmt.finalizeStatement();
    return value;
  }

  int queryLong(String sql) {
    final stmt = prepareStatement(sql);
    stmt.step();
    final value = stmt.getLong(0);
    stmt.finalizeStatement();
    return value;
  }

  int getVersion() {
    return queryInt('PRAGMA user_version');
  }

  void setVersion(int v) {
    run('PRAGMA user_version = $v');
  }

  void begin() {
    run('BEGIN');
  }

  void commit() {
    run('COMMIT');
  }

  /// Binds each entry of [params] as TEXT at index `i + 1`, then invokes
  /// [block] once per row until [StepResult.done], then finalizes.
  void query(
    String sql,
    List<String> params,
    void Function(PreparedStatement stmt) block,
  ) {
    final stmt = prepareStatement(sql);
    for (var i = 0; i < params.length; i++) {
      stmt.bindText(i + 1, params[i]);
    }
    while (stmt.step() == StepResult.row) {
      block(stmt);
    }
    stmt.finalizeStatement();
  }

  /// Binds [params] as TEXT, steps once, and returns `block(stmt)` when a row
  /// exists or null when the result set is empty, then finalizes.
  T? querySingle<T>(
    String sql,
    List<String> params,
    T Function(PreparedStatement stmt) block,
  ) {
    final stmt = prepareStatement(sql);
    for (var i = 0; i < params.length; i++) {
      stmt.bindText(i + 1, params[i]);
    }
    final result = stmt.step() == StepResult.row ? block(stmt) : null;
    stmt.finalizeStatement();
    return result;
  }

  /// Applies migrations up to [targetVersion], one version at a time.
  ///
  /// Returns immediately when the database is already at or past
  /// [targetVersion]. For each version, the SQL script comes from
  /// [loadMigrationSql] — asset loading is intentionally left to the caller,
  /// as in Kotlin — is split into statements by [parse], run one by one, and
  /// then `user_version` is stamped.
  void migrateTo(
    int targetVersion,
    MigrationSqlLoader loadMigrationSql, {
    SqlScriptParser parse = SQLParser.parse,
  }) {
    final currentVersion = getVersion();
    if (currentVersion >= targetVersion) return;
    for (var v = currentVersion + 1; v <= targetVersion; v++) {
      final commands = parse(loadMigrationSql(v));
      for (final cmd in commands) {
        run(cmd);
      }
      setVersion(v);
    }
  }
}
