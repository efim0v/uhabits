/// Свод воздержания, собранный приложением.
///
/// Арифметика свода проверена в ядре, на чистом Dart. Здесь проверяется
/// проводка, и только она: что `AppScope` собрал свод тем самым журналом,
/// который сам же отдаёт наружу, и тем самым объявляющим писателем, что у сна.
///
/// Без этого файла оба поля доказаны одним компилятором. `scope.lapses` и
/// `scope.abstinence` сходятся ровно в одном вызове `AppScope.open`; свод,
/// собранный с молчащим `const DayWriter()`, скомпилировался бы, позеленел бы
/// во всех тестах ядра — и клал бы дни на диск, пока список показывает
/// прежнее.
library;

// Core models and the task runner are reached by their `src` path, exactly as
// lib/state does.
// ignore_for_file: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/src/ui/screens/habits/list/habit_card_list_cache.dart';
import 'package:uhabits_core/uhabits_core.dart';

/// Считает, сколько раз списку сказали перерисовать строку.
class RecordingCacheListener extends HabitCardListCacheListener {
  int changes = 0;

  @override
  void onItemChanged(int position) => changes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const HabitDefinition definition = HabitDefinition(
    kind: ComputedKind.abstinence,
    committedFrom: 8990,
  );

  late Database database;
  late AppScope scope;
  late RecordingCacheListener listener;
  late Habit quit;

  setUp(() {
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
    scope.preferences.isFirstRun = false;

    quit = scope.modelFactory.buildHabit()
      ..name = 'No smoking'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0
      ..unit = '';
    scope.habitList.add(quit);
    scope.definitions.save(quit.id!, definition);
    attachDefinition(quit, scope.definitions);
    quit.recompute();

    listener = RecordingCacheListener();
    scope.cache.setListener(listener);
    scope.cache.onAttached();
    listener.changes = 0;
  });

  tearDown(() {
    scope.close();
    resetToday();
  });

  test('a tap lands in the scope\'s own journal, and the list is told once',
      () {
    scope.abstinence.setLapse(quit, LocalDate(9000), true);

    expect(scope.lapses.forDay(quit.id!, 9000), 1,
        reason: 'computed.abstinence-sync#1 — свод пишет в тот журнал, что '
            'лежит на scope, а не в какой-то свой');
    expect(quit.originalEntries.get(LocalDate(9000)).value, 1000,
        reason: 'computed.abstinence-sync#1');
    expect(listener.changes, 1,
        reason: 'computed.freshness#2 — свод собран объявляющим писателем, '
            'иначе запись есть, а строка списка показывает прежнее');
  });

  test('and the sweep rescores from what that journal already holds', () {
    scope.lapses.save(quit.id!, 8995, amount: 45);

    expect(scope.abstinence.recomputeAll(quit, definition), isTrue,
        reason: 'computed.abstinence-sync#5');
    expect(quit.originalEntries.get(LocalDate(8995)).value, 45000,
        reason: 'computed.abstinence-sync#5 — журнал, в который пишет '
            'приложение, есть журнал, из которого считает свод');
    expect(listener.changes, 1, reason: 'computed.freshness#2');
  });

  test('taking the tap back empties the journal and quiets the day', () {
    scope.abstinence.setLapse(quit, LocalDate(9000), true);
    listener.changes = 0;

    scope.abstinence.setLapse(quit, LocalDate(9000), false);

    expect(scope.lapses.forDay(quit.id!, 9000), isNull,
        reason: 'computed.abstinence-sync#2');
    expect(quit.originalEntries.get(LocalDate(9000)).value, Entry.unknown,
        reason: 'computed.abstinence-sync#2');
    expect(listener.changes, 1,
        reason: 'computed.freshness#2 — отмена меняет строку списка ровно так '
            'же, как запись');
  });
}
