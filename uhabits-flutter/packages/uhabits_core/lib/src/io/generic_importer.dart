/// Port of
/// uhabits-core/src/commonMain/kotlin/org/isoron/uhabits/core/io/GenericImporter.kt
/// and of
/// uhabits-android/src/main/java/org/isoron/uhabits/tasks/ImportDataTask.kt
/// (plus its one-method factory, `ImportDataTaskFactory.kt`).
///
/// `ImportDataTask` is an Android class, but everything it does — begin a
/// transaction, dispatch to the importer, map the outcome onto one of three
/// result codes, commit either way — is pure Dart. The one platform detail is
/// `android.util.Log.e("ImportDataTask", "Import failed", e)`, which becomes a
/// [Logger] obtained from the injected [Logging]: the message and the
/// exception are logged as two calls, since [Logger.error] takes one or the
/// other. The Android binding of [Logging] belongs to the app package.
library;

import 'dart:async';

import '../database/database.dart';
import '../models/model_factory.dart';
import '../models/sqlite/sql_model_factory.dart';
import '../tasks/task_runner.dart';
import 'abstract_importer.dart';
import 'files.dart';
import 'logging.dart';

/// A GenericImporter decides which implementation of [AbstractImporter] is able
/// to handle a given file and delegates to it the task of importing the data.
///
/// The four constructor arguments are typed [AbstractImporter] rather than
/// `LoopDBImporter`, `RewireDBImporter`, `TickmateDBImporter` and
/// `HabitBullCSVImporter`, because those four classes belong to their own
/// slices; the parameter *names* keep the wiring order visible, and
/// [importers] is the ordered list every dispatch walks.
class GenericImporter extends AbstractImporter {
  GenericImporter(
    AbstractImporter loopDBImporter,
    AbstractImporter rewireDBImporter,
    AbstractImporter tickmateDBImporter,
    AbstractImporter habitBullCSVImporter,
  ) : importers = <AbstractImporter>[
          loopDBImporter,
          rewireDBImporter,
          tickmateDBImporter,
          habitBullCSVImporter,
        ];

  /// `var importers: List<AbstractImporter>`: reassignable in Kotlin, so not
  /// `final` here.
  List<AbstractImporter> importers;

  @override
  Future<bool> canHandle(UserFile file) async {
    for (final importer in importers) {
      if (await importer.canHandle(file)) {
        return true;
      }
    }
    return false;
  }

  /// Note that this walks the same list and imports through EVERY importer
  /// that claims the file — it does not stop at the first match, so a file
  /// recognised by two importers is imported twice — and that it re-probes
  /// each importer, opening the file a second time.
  @override
  Future<void> importHabitsFromFile(UserFile file) async {
    for (final importer in importers) {
      if (await importer.canHandle(file)) {
        await importer.importHabitsFromFile(file);
      }
    }
  }
}

/// Port of `ImportDataTask.Listener`, a Kotlin `fun interface`. Dart has no
/// nested types, so it is top-level, like `TaskRunnerListener`.
abstract interface class ImportDataTaskListener {
  void onImportDataFinished(int result);
}

/// The logger tag `ImportDataTask` passes to `Log.e`.
const String importDataTaskLoggerName = 'ImportDataTask';

/// `Log.e("ImportDataTask", "Import failed", e)`.
const String importFailedMessage = 'Import failed';

/// Port of `ImportDataTask`.
class ImportDataTask extends Task {
  ImportDataTask(
    this.importer,
    ModelFactory modelFactory,
    this.file,
    this.listener, {
    Logging? logging,
  })  : modelFactory = modelFactory as SQLModelFactory,
        _logger =
            (logging ?? StandardLogging()).getLogger(importDataTaskLoggerName);

  static const int failed = 3;
  static const int notRecognized = 2;
  static const int success = 1;

  final GenericImporter importer;

  /// `modelFactory as SQLModelFactory`: a non-SQL model factory throws at
  /// construction, exactly as the Kotlin cast does.
  final SQLModelFactory modelFactory;

  final UserFile file;

  final ImportDataTaskListener listener;

  final Logger _logger;

  int _result = 0;

  /// The result code the task reached; `private var result = 0` in Kotlin.
  int get result => _result;

  @override
  Future<void> doInBackground() async {
    modelFactory.database.begin();
    try {
      if (await importer.canHandle(file)) {
        await importer.importHabitsFromFile(file);
        _result = success;
        modelFactory.database.commit();
      } else {
        _result = notRecognized;
        modelFactory.database.commit();
      }
      // `catch (e: Exception)`, and note that it is NOT `on Exception catch`.
      // Java's `Exception` sits above `RuntimeException`, so Kotlin's clause
      // takes every parse accident an importer can commit —
      // `HabitBullCSVImporter.parseDate` doing `parts[2].toInt()` on a date
      // such as "2015-01" throws IndexOutOfBoundsException, and the catch
      // still sets FAILED and commits. Dart splits that hierarchy the other
      // way: the same accidents are `Error`s (RangeError, StateError,
      // TypeError, ArgumentError), not `Exception`s, so `on Exception` would
      // let them escape — past `onPostExecute`, so the user is told nothing,
      // and past the commit, so the database is left inside the open
      // transaction and the next write behaves unpredictably
      // (`audit7.a-failed-import-shows-no-error#1`). A bare `catch` is the
      // clause that covers what Kotlin's covers; the same choice was already
      // made for `catch (e: Exception)` in `HabitBullCSVImporter.canHandle`.
      // It also sweeps up Dart's `OutOfMemoryError`/`StackOverflowError`,
      // which map onto java.lang.Error and which Kotlin would rethrow —
      // neither is recoverable, and rethrowing them here would reinstate
      // exactly the open transaction this rule is about.
    } catch (e, stackTrace) {
      _result = failed;
      _logger.error(importFailedMessage);
      _logger.error(e, stackTrace);
      // On failure, commit anyway to close the transaction
      try {
        modelFactory.database.commit();
      } catch (_) {}
    }
  }

  @override
  void onPostExecute() {
    listener.onImportDataFinished(_result);
  }
}

/// Port of `ImportDataTaskFactory`.
class ImportDataTaskFactory {
  ImportDataTaskFactory(this.importer, this.modelFactory, {this.logging});

  final GenericImporter importer;
  final ModelFactory modelFactory;
  final Logging? logging;

  ImportDataTask create(UserFile file, ImportDataTaskListener listener) =>
      ImportDataTask(importer, modelFactory, file, listener, logging: logging);
}
