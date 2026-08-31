/// Путь целиком, на одном файле базы: завёл → срыв → отмена → счётчик →
/// перезапуск → копия → восстановление → удаление.
///
/// Каждое звено проверено поодиночке. Ни один из тех тестов не закрывает scope
/// и не открывает его заново на том же файле — то есть ни один не отвечает на
/// вопрос, ради которого всё это писалось: то же ли увидит человек завтра
/// утром.
///
/// Два обстоятельства, без которых файл был бы зелёным по случайности.
///
/// **Диспетчер здесь настоящий.** `AppScope.open` зовётся без
/// `UnconfinedTestDispatcher`, то есть с `AsyncDispatcher` — тем же, что на
/// телефоне: команда уходит в очередь и на следующей строке ещё не выполнена.
/// Строку `await scope.taskRunner.awaitAll()` после `save()` нельзя убрать —
/// без неё привычки в списке ещё нет. Именно этой разницей однажды и вышла
/// ошибка: определение, записанное «следующей строкой», зеленело во всех
/// тестах и молча не делало ничего на устройстве
/// (`app/lib/state/edit_habit_model.dart`, комментарий над регистрацией
/// слушателя).
///
/// **Сегодня здесь настоящее.** `AppScope.open` сам стамповывает день
/// (`setToday(computeToday(...))`), перетирая любой `setToday` из `setUp`, —
/// поэтому день берётся у него, а не назначается тестом — перезапуск здесь тот
/// же, что на телефоне, вместе со стамповкой дня. Часы при этом пинятся
/// (`setUp`): день назначает `AppScope.open`, но из чего он его считает, решает
/// тест, и оба открытия считают из одного и того же.
///
/// Чего файл **не** достаёт, и это сказано прямо: пальца. Карточка вида в
/// диалоге типов (`EditHabitScreen.abstinenceTypeCardKey`), жест по ячейке и
/// диалог величины — виджеты, и они проверены своими тестами
/// (`app/test/ui/abstinence/`, `app/test/ui/habits/list/abstinence_cell_test
/// .dart`). Здесь путь начинается с `EditHabitModel` — модели, которую тот
/// диалог строит, — и срыв идёт через `setLapseDay`, единственную дверь, в
/// которую пишет жест. Ниже этой двери — всё настоящее.
library;

// Команды, диспетчеры и файлы ядра достаются по `src`-пути, ровно как это
// делает lib/state.
// ignore_for_file: implementation_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/app_database.dart';
import 'package:uhabits/platform/flutter_files.dart';
import 'package:uhabits/state/app_scope.dart';
import 'package:uhabits/state/edit_habit_model.dart';
import 'package:uhabits/ui/habits/abstinence/abstinence_gestures.dart';
import 'package:uhabits/ui/settings/data_actions.dart' show buildGenericImporter;
import 'package:uhabits_core/src/io/files.dart';
import 'package:uhabits_core/src/time/date_utils.dart';
import 'package:uhabits_core/uhabits_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final TimeZone Function() realZone = getDefaultTimeZone;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('uhabits_abstinence_life');
    // Часы пинятся, а день — нет. `AppScope.open` стамповывает его сам,
    // `setToday(computeToday(...))`, и в этом весь смысл здешнего перезапуска:
    // день приходит оттуда же, откуда на телефоне. Но `computeToday` читает
    // эти два хука, и если прогон переедет местную полночь между двумя
    // открытиями, второй scope проснётся в другом дне, чем первый, — тест
    // упадёт один раз и потом навсегда будет считаться зыбким. Зона пинится
    // вместе с часами: восточнее UTC+12 полдень по Гринвичу уже завтра.
    DateUtils.setFixedTimeZone(const FixedTimeZone(0));
    getDefaultTimeZone = () => const FixedTimeZone(0);
    systemCurrentTimeMillis =
        () => (9000 + 10957) * 86400000 + 12 * 3600000;
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    systemCurrentTimeMillis = defaultCurrentTimeMillis;
    getDefaultTimeZone = realZone;
    DateUtils.setFixedTimeZone(null);
    resetToday();
  });

  /// Открывает scope на файле так, как его открывает приложение.
  ///
  /// Без тестовых диспетчеров: см. заголовок файла. Отсюда и `await`:
  /// `AppScope.open` ставит в очередь два обновления кэша списка (сеттеры
  /// порядка в конструкторе `HabitCardListAdapter`), и с настоящим
  /// диспетчером они выполняются не на этом стеке, а следующим кадром. На
  /// телефоне этот кадр проходит сам; здесь его надо провести руками, иначе
  /// задача доберётся до базы уже после `close()`.
  Future<AppScope> openScope(String path) async {
    final AppScope scope = AppScope.open(AppDatabase.openAndMigrate(path));
    await scope.taskRunner.awaitAll();
    return scope;
  }

  /// Закрывает scope, дав очереди опустеть.
  ///
  /// `AppScope.close` зовёт `cache.cancelTasks()`, но `_RefreshTask` смотрит
  /// на свой флаг только внутри цикла — после `fetchHabits()` и `getToday()`.
  /// На телефоне это ничего не стоит: там процесс уходит целиком. Здесь файл
  /// открывается снова, и задача, оставшаяся от прошлой жизни, читала бы
  /// закрытую базу.
  Future<void> closeScope(AppScope scope) async {
    await scope.taskRunner.awaitAll();
    scope.close();
  }

  /// Привычка-воздержание, собранная руками: числовая `atMost` с целью 0,
  /// строка `HabitDefinitions` с днём обязательства, и `attachDefinition` +
  /// `recompute` сразу после сохранения — та же сборка, что в
  /// `abstinence_hooks_test.dart`.
  Habit makeAbstinence(AppScope scope, {required int committedFrom}) {
    final Habit habit = scope.modelFactory.buildHabit()
      ..name = 'Sober'
      ..type = HabitType.numerical
      ..targetType = NumericalHabitType.atMost
      ..targetValue = 0
      ..unit = '';
    scope.habitList.add(habit);
    scope.definitions.save(
      habit.id!,
      HabitDefinition(
        kind: ComputedKind.abstinence,
        committedFrom: committedFrom,
      ),
    );
    attachDefinition(habit, scope.definitions);
    habit.recompute();
    return habit;
  }

  /// Копия базы — побайтовый файл, а не выгрузка: ровно то, что кладёт себе в
  /// облако человек. Зовётся на **закрытой** базе.
  ///
  /// `LocalUserFile` поверх пути — потому что импортёр принимает `UserFile`, а
  /// не строку.
  UserFile backupOf(String path) {
    final String backup = '${tempDir.path}/backup.db';
    File(path).copySync(backup);
    return LocalUserFile(backup);
  }

  test('everything is where it was after a restart', () async {
    final String path = '${tempDir.path}/habits.db';
    final AppScope first = await openScope(path);
    final int today = getToday().daysSince2000;
    final Habit habit = makeAbstinence(first, committedFrom: today - 40);
    setLapseDay(
      first,
      habit: habit,
      date: getToday().minus(3),
      lapsed: true,
    );
    final int days = daysWithoutLapse(habit);
    final double score = habit.scores[getToday()].value;
    // Сторожа для сторожей. Обе проверки после перезапуска спрашивают «то же
    // ли самое», и сами по себе они одинаково зелены на верном ответе и на
    // двух одинаковых неверных: два нуля равны друг другу не хуже двух двоек,
    // а два портовых балла — не хуже двух делённых. Эти две строки говорят,
    // что именно будет сравниваться.
    expect(days, 2,
        reason: 'computed.streak#4 — два чистых дня после срыва, а не ноль');
    expect(score, lessThan(0.9),
        reason: 'computed.lapse-score#11 — деление включено ещё до закрытия');
    final String uuid = habit.uuid!;
    await closeScope(first);

    final AppScope second = await openScope(path);
    addTearDown(() => closeScope(second));
    final Habit again = second.habitList.getByUUID(uuid)!;

    expect(again.definition?.committedFrom, today - 40,
        reason: 'computed.commitment#5');
    expect(second.lapses.lastDay(again.id!), getToday().minus(3).daysSince2000,
        reason: 'computed.lapses#6');
    expect(daysWithoutLapse(again), days, reason: 'computed.streak#4');
    expect(again.scores[getToday()].value, closeTo(score, 1e-12),
        reason: 'computed.lapse-score#12 — иначе деление живёт только до '
            'перезапуска');
  });

  test('the whole path holds: commit, lapse, undo, restart, restore, delete',
      () async {
    final String path = '${tempDir.path}/habits.db';

    // 1. Завёл — через настоящий редактор, а не руками.
    AppScope scope = await openScope(path);
    final int today = getToday().daysSince2000;
    final EditHabitModel model =
        EditHabitModel(scope: scope, computed: ComputedKind.abstinence);
    addTearDown(model.dispose);
    model.nameController.text = 'Sober';
    model.setCommittedFrom(today - 40);
    expect(model.save(), isTrue);
    // Команда ушла в очередь настоящего диспетчера, и до этой строки привычки
    // в списке нет. Убрать её нельзя — и в этом весь смысл: строка стоит там
    // же, где на телефоне стоит кадр ожидания.
    await scope.taskRunner.awaitAll();
    Habit habit = scope.habitList.getByPosition(0);
    final String uuid = habit.uuid!;

    // 2. Счётчик существует до первой записи — ради этого весь раздел серий.
    // Сорок он показывает только если определение прикрепилось к живой
    // привычке уже при сохранении: написанное «следующей строкой» после
    // `run(command)`, оно на настоящем диспетчере не пишется вовсе, окно
    // пересчёта начинается сегодняшним днём, и счёт становится нулём.
    expect(daysWithoutLapse(habit), 40,
        reason: 'computed.streak#4, computed.commitment#7');

    // 3. Срыв и 4. отмена.
    setLapseDay(scope, habit: habit, date: getToday(), lapsed: true);
    expect(daysWithoutLapse(habit), 0, reason: 'computed.streak#5');
    setLapseDay(scope, habit: habit, date: getToday(), lapsed: false);
    expect(daysWithoutLapse(habit), 40,
        reason: 'computed.abstinence-sync#2 — отмена возвращает и счётчик');

    // 5. Настоящий срыв, три дня назад, и балл, который он оставил.
    setLapseDay(scope, habit: habit, date: getToday().minus(3), lapsed: true);
    final double score = habit.scores[getToday()].value;
    expect(score, lessThan(0.9),
        reason: 'computed.lapse-score#12 — деление пополам включено на живой '
            'привычке, а не только в юнит-тесте');

    // 6. Перезапуск.
    await closeScope(scope);
    scope = await openScope(path);
    habit = scope.habitList.getByUUID(uuid)!;
    expect(habit.scores[getToday()].value, closeTo(score, 1e-12),
        reason: 'computed.lapse-score#12');
    expect(daysWithoutLapse(habit), 2, reason: 'computed.streak#4');

    // 7. Копия и 8. восстановление на пустое устройство.
    // Копия снимается с закрытого файла: открытая база держит журнал WAL, и
    // побайтовая копия под ней — копия половины.
    await closeScope(scope);
    final UserFile backup = backupOf(path);
    final AppScope fresh = await openScope('${tempDir.path}/other.db');
    addTearDown(() => closeScope(fresh));
    // `userDataDir` обязателен: в продакшне это `directories.filesDir`
    // (`app/lib/ui/settings/data_actions.dart` —
    // `FlutterFileOpener(userDataDir: directories.filesDir)`), здесь — тот же
    // временный каталог, в котором лежит копия.
    await buildGenericImporter(
      scope: fresh,
      fileOpener: FlutterFileOpener(userDataDir: tempDir.path),
    ).importHabitsFromFile(backup);

    final Habit restored = fresh.habitList.getByUUID(uuid)!;
    // Устройство пусто, поэтому восстановленная привычка получает тот же
    // идентификатор, под которым журнал лежит в файле. Значит **перекладку**
    // журнала на новый идентификатор этот тест не проверяет — она проверена
    // на непустом устройстве в
    // `app/test/state/computed_guard_wiring_test.dart`. Здесь проверяется, что
    // журнал вообще переехал.
    expect(fresh.lapses.lastDay(restored.id!), getToday().minus(3).daysSince2000,
        reason: 'computed.backup#4');
    expect(restored.definition?.committedFrom, today - 40,
        reason: 'computed.commitment#5 — определение прикрепляется и после '
            'восстановления, а не только на старте');
    expect(restored.scores.halvesOnLapse, isTrue,
        reason: 'computed.lapse-score#11');
    expect(daysWithoutLapse(restored), 2, reason: 'computed.streak#4');

    // 9. Удаление — и ни строки под этим идентификатором.
    final int id = restored.id!;
    fresh.habitList.remove(restored);
    expect(fresh.lapses.firstDay(id), isNull, reason: 'computed.lifecycle#6');
    expect(fresh.definitions.forHabit(id), isNull,
        reason: 'computed.lifecycle#6');
  });

  test('the level is earned, halved and earned again', () async {
    final String path = '${tempDir.path}/habits.db';
    final AppScope scope = await openScope(path);
    addTearDown(() => closeScope(scope));
    final int today = getToday().daysSince2000;
    final Habit habit = makeAbstinence(scope, committedFrom: today - 30);

    expect(habit.scores[getToday()].value, closeTo(0.5, 0.02),
        reason: 'computed.lapse-score#14 — месяц есть половина');

    setLapseDay(scope, habit: habit, date: getToday(), lapsed: true);

    expect(habit.scores[getToday()].value, closeTo(0.25, 0.02),
        reason: 'computed.lapse-score#3 — срыв делит пополам, а не обнуляет: '
            'иначе месяц воздержания стоил бы столько же, сколько ничего');
  });
}
