/// The guards are on instances, so they are only as good as their wiring.
///
/// `WidgetBehavior` and `ShowHabitMenuPresenter` both take "is this habit
/// computed" as a constructor argument rather than reaching for a repository:
/// the behaviour needs the answer, not the table. That makes every guard a
/// property of the object that was built, and a construction site that forgets
/// the argument builds an object with no guard at all — which is how the widget
/// tap door came to be open on `main.dart`'s `WidgetBehavior` while the plan
/// named only `AppScope`'s.
///
/// `WidgetBehavior` is app-side, so its argument is now required and the
/// compiler is the test. The ported core presenter's cannot be — its
/// constructor is the Kotlin one, and four ported test files build it without
/// anything of ours. The app has exactly one site of it, and this file is what
/// stands in for the compiler there.
///
/// The restore below is the same thought a step further out. Every collaborator
/// that carries a computed habit's side tables across an import is optional on
/// `LoopDBImporter` — the core's own tests build it without them — so the whole
/// of "a restored habit is still an abstinence habit" hangs on two lines in
/// `buildGenericImporter` and the attachment that follows the import. Asserting
/// that the builder returned a non-null importer would prove none of it: it is
/// green with both lines gone. So the test restores a real backup file through
/// the real builder and reads what the app would read afterwards.
library;

// The core's models, the importer and its files are reached by their `src`
// path, exactly as lib/state and lib/ui do.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/show_habit_model.dart';
import 'package:uhabits/ui/settings/data_actions.dart' show buildGenericImporter;
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/tasks/task_runner.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  late Database database;
  late AppScope scope;
  late Directory tempDir;

  setUp(() {
    setToday(LocalDate(9000));
    tempDir = Directory.systemTemp.createTempSync('uhabits_guard_wiring');
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
  });

  tearDown(() {
    scope.close();
    resetToday();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Habit addHabit(String name) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = name
      ..type = HabitType.numerical
      ..unit = '%'
      ..targetValue = 100;
    scope.habitList.add(habit);
    habit.originalEntries.add(Entry(LocalDate(9000), 89763));
    habit.recompute();
    return habit;
  }

  ShowHabitModel modelFor(Habit habit) {
    final ShowHabitModel model =
        ShowHabitModel(scope: scope, habit: habit, theme: LightTheme());
    addTearDown(model.dispose);
    return model;
  }

  test('the habit screen builds its menu with the computed guard wired', () {
    // Randomise is `originalEntries.clear()`, which is `deleteByHabitId` in
    // SQLite: it would take the computed values and the person's own skips
    // with it, unrecoverably outside the sync's read window.
    final Habit habit = addHabit('Sleep');
    scope.definitions
        .save(habit.id!, const HabitDefinition(kind: ComputedKind.sleep));

    modelFor(habit).menuPresenter.onRandomize();

    expect(habit.originalEntries.get(LocalDate(9000)).value, 89763,
        reason: 'computed.lifecycle#3 — the screen the app really builds, not '
            'a presenter assembled by the test');
  });

  test('and randomises an ordinary habit as it always did', () {
    final Habit habit = addHabit('Meditate');

    modelFor(habit).menuPresenter.onRandomize();

    expect(habit.originalEntries.get(LocalDate(9000)).value, isNot(89763),
        reason: 'show-habit.randomize#2 — the check above is only worth '
            'making if randomise still does its work for everything else');
  });

  /// Копия, снятая той же сборкой: побайтовый файл базы, а не выгрузка.
  ///
  /// Пишется настоящей миграцией (`AppDatabase.openAndMigrate`), закрывается,
  /// копируется целиком — `File.copySync` и есть то, что делает «снять копию»,
  /// — и оборачивается в `LocalUserFile`, потому что импортёр принимает
  /// `UserFile`, а не путь.
  UserFile backupWithLapses({required String uuid}) {
    final String source = '${tempDir.path}/source.db';
    final Database db = AppDatabase.openAndMigrate(source);
    db.run("insert into Habits (id, name, uuid, description, freq_num, "
        "freq_den, color, position, archived, highlight, type, target_value, "
        "target_type, unit, question) "
        "values (1, 'Sober', '$uuid', '', 1, 1, 0, 0, 0, 0, 1, 0, 1, '', '')");
    DefinitionRepository(db).save(
      1,
      const HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: 8960,
      ),
    );
    LapseRepository(db)
      ..save(1, 8990, amount: 1)
      ..save(1, 9000, amount: 45)
      ..save(1, 9007, amount: 12);
    db.close();

    final String backup = '${tempDir.path}/backup.db';
    File(source).copySync(backup);
    return LocalUserFile(backup);
  }

  test('a restored abstinence habit comes back with its journal', () async {
    final UserFile file = backupWithLapses(uuid: 'abst-uuid');
    // Это устройство не пусто, поэтому восстановленная привычка получает не
    // тот идентификатор, под которым журнал лежит в файле.
    for (int i = 0; i < 4; i++) {
      scope.habitList.add(scope.modelFactory.buildHabit()..name = 'Mine $i');
    }

    // `userDataDir` у опенера обязателен и в тесте, и в продакшне. В продакшне
    // это `directories.filesDir` — `app/lib/ui/settings/data_actions.dart`,
    // `FlutterFileOpener(userDataDir: directories.filesDir)`; здесь тот же
    // временный каталог, в котором лежит копия.
    await buildGenericImporter(
      scope: scope,
      fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
    ).importHabitsFromFile(file);

    final Habit restored = scope.habitList.getByUUID('abst-uuid')!;
    expect(restored.id, isNot(1),
        reason: 'проверка стоит чего-то, только если идентификаторы разные');
    expect(scope.lapses.range(restored.id!, 8990, 9007),
        <int, int>{8990: 1, 9000: 45, 9007: 12},
        reason: 'computed.backup#4 — без проводки восстановление молча '
            'возвращает чистую историю, которой не было');
    expect(restored.definition?.committedFrom, 8960,
        reason: 'computed.commitment#5 — строка в базе и живая модель разные '
            'вещи: пересчёт читает поле, а не репозиторий');
    expect(restored.scores.halvesOnLapse, isTrue,
        reason: 'computed.lapse-score#11');
    // И прикрепить мало: пересчёт, который уже прошёл внутри импорта, шёл без
    // определения, и окно его начиналось сегодняшним днём.
    //
    // Про арифметику срывов эта единица не говорит ничего: 8960 — день до
    // первого из них, а записей привычки в файле нет вовсе, журнал лежит в нём
    // один. Проверяется здесь граница окна, и только она.
    expect(restored.scores[LocalDate(8960)].value, closeTo(1.0, 1e-6),
        reason: 'computed.commitment#1 — оценка существует со дня решения, а '
            'не с перезапуска приложения');
  });
}
