/// Заведение привычки-воздержания: модель формы.
///
/// Арифметика вида живёт в ядре. Здесь проверяется ровно то, что делает
/// редактор: какой вид он несёт, какие поля предлагает и что кладёт в базу,
/// когда человек нажимает «Сохранить».
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late AppScope scope;

  setUp(() {
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    setToday(LocalDate(9000));
    database = Sqlite3Database.memory();
    database.setVersion(8);
    database.migrateTo(appDatabaseVersion, (int v) => migrationSqlFor(v) ?? '');
    applyConnectionSettings(database);
    scope = AppScope.open(
      database,
      mainDispatcher: const UnconfinedTestDispatcher(),
      ioDispatcher: const UnconfinedTestDispatcher(),
    );
  });

  tearDown(() {
    scope.close();
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  test('the chooser carries a kind, not a sleep flag', () {
    final EditHabitModel abstinence =
        EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
    expect(abstinence.computedKind, ComputedKind.abstinence,
        reason: 'computed.create#2 — the editor is opened with a kind, and a '
            'boolean cannot name the second one');
    expect(abstinence.isAbstinence, isTrue, reason: 'computed.create#2');
    expect(abstinence.isSleep, isFalse,
        reason: 'computed.create#2 — the two kinds are not each other');
    expect(abstinence.isComputed, isTrue, reason: 'computed.create#2');

    final EditHabitModel sleep =
        EditHabitModel(scope: scope, computed: ComputedKind.sleep);
    expect(sleep.isSleep, isTrue,
        reason: 'computed.create#2 — the sleep path is the same path');
    expect(sleep.isAbstinence, isFalse, reason: 'computed.create#2');

    final EditHabitModel plain = EditHabitModel(scope: scope);
    expect(plain.computedKind, isNull, reason: 'computed.create#2');
    expect(plain.isComputed, isFalse, reason: 'computed.create#2');
  });
}
